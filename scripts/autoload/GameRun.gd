extends Node

signal run_started
signal customer_ready(customer: Dictionary)
signal stage_changed(stage: int)
signal run_failed(stats: Dictionary)
signal run_victory(stats: Dictionary)
signal time_changed(elapsed: float)
signal blackout_requested

const MAX_STAGE := 10
const MULTI_ORDER_CHANCE := {
	3: 0.30,
	4: 0.40,
	5: 0.45,
	6: 0.50,
	7: 0.60,
	8: 0.70,
	9: 0.80,
	10: 0.90,
}
const BLACKOUT_ROLL_INTERVAL_SECONDS := 5.0
const BLACKOUT_COOLDOWN_SECONDS := 30.0
const BLACKOUT_CHANCE_DISTANCE_80 := 0.9
const BLACKOUT_CHANCE_DISTANCE_60 := 0.01
const BLACKOUT_CHANCE_DISTANCE_40 := 0.02
const BLACKOUT_CHANCE_DISTANCE_20 := 0.04
const MEDAL_GOLD := "Gold"
const MEDAL_SILVER := "Silver"
const MEDAL_BRONZE := "Bronze"
const MEDAL_CLEAR := "Clear"

var running := false
var elapsed_time := 0.0
var total_time := 0.0
var current_stage := 1
var served_customers := 0
var failed_customers := 0
var earned_medals: Array[String] = []
var start_blocked := false
var _current_customer: Dictionary = {}
var _blackout_roll_elapsed := 0.0
var _blackout_cooldown_remaining := 0.0
var _blackout_active := false
var _blackout_request_pending := false


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if not running or start_blocked:
		return

	elapsed_time += delta
	total_time += delta
	time_changed.emit(elapsed_time)


func start() -> void:
	randomize()
	running = true
	start_blocked = false
	elapsed_time = 0.0
	total_time = 0.0
	current_stage = 1
	served_customers = 0
	failed_customers = 0
	earned_medals.clear()
	_current_customer = {}
	_reset_blackout_state()
	ComboManager.reset()
	UltimateManager.reset()
	DistanceManager.reset()
	DistanceManager.stop()
	MonsterManager.reset()
	MonsterManager.stop()
	run_started.emit()
	start_stage(current_stage)


func set_start_blocked(blocked: bool) -> void:
	start_blocked = blocked


func start_stage(stage: int) -> void:
	if not running:
		return

	current_stage = clampi(stage, 1, MAX_STAGE)
	elapsed_time = 0.0
	_reset_blackout_state()
	ComboManager.reset()
	_current_customer = _create_stage_order(current_stage)
	stage_changed.emit(current_stage)
	time_changed.emit(elapsed_time)
	customer_ready.emit(_current_customer)


func continue_to_next_stage() -> void:
	if running:
		return

	if current_stage >= MAX_STAGE:
		start()
		return

	running = true
	start_stage(current_stage + 1)


func on_order_completed(success: bool) -> void:
	if not running:
		return

	running = false
	start_blocked = false
	_reset_blackout_state()
	if success:
		served_customers += 1
		var stats := _build_stage_stats()
		earned_medals.append(stats.get("medal", MEDAL_CLEAR) as String)
		stats["medals"] = earned_medals.duplicate()
		if current_stage >= MAX_STAGE:
			run_victory.emit(stats)
	else:
		failed_customers += 1
		run_failed.emit(_build_stage_stats())


func abort() -> void:
	running = false
	start_blocked = false
	_reset_blackout_state()
	DistanceManager.stop()
	MonsterManager.stop()
	ComboManager.reset()
	UltimateManager.reset()


func _create_stage_order(stage: int) -> Dictionary:
	var burger_count := _burger_count_for_stage(stage)
	var recipes: Array[Recipe] = []
	for i in range(burger_count):
		recipes.append(RecipeGenerator.generate_for_stage(stage))

	var medal_targets := _medal_targets_for(recipes)
	var variants: Array[String] = []
	if burger_count > 1:
		variants.append("multi")

	return {
		"index": stage,
		"stage": stage,
		"recipes": recipes,
		"variants": variants,
		"medal_targets": medal_targets,
	}


func _burger_count_for_stage(stage: int) -> int:
	if stage < 3:
		return 1

	var multi_chance := MULTI_ORDER_CHANCE.get(stage, 0.0) as float
	if randf() >= multi_chance:
		return 1

	if stage <= 3:
		return 2
	if stage <= 5:
		return 3 if randf() < 0.35 else 2
	if stage <= 7:
		return 3 if randf() < 0.55 else 2
	if stage == 8:
		return 3
	if stage == 9:
		return 4 if randf() < 0.35 else 3
	return 4


func _medal_targets_for(recipes: Array[Recipe]) -> Dictionary:
	var ingredient_count := 0
	for recipe in recipes:
		ingredient_count += recipe.ingredients.size()

	var base_seconds := float(ingredient_count)
	return {
		"gold": snappedf(maxf(5.0, base_seconds * 0.80), 0.1),
		"silver": snappedf(maxf(8.0, base_seconds * 1.10), 0.1),
		"bronze": snappedf(maxf(11.0, base_seconds * 1.45), 0.1),
	}


func accept_blackout_request() -> bool:
	if not _blackout_request_pending or _blackout_active:
		return false

	_blackout_request_pending = false
	_blackout_active = true
	return true


func reject_blackout_request() -> void:
	_blackout_request_pending = false


func complete_blackout() -> void:
	if not _blackout_active:
		return

	_blackout_active = false
	_blackout_cooldown_remaining = BLACKOUT_COOLDOWN_SECONDS
	_blackout_roll_elapsed = 0.0


func _reset_blackout_state() -> void:
	_blackout_roll_elapsed = 0.0
	_blackout_cooldown_remaining = 0.0
	_blackout_active = false
	_blackout_request_pending = false


func _update_blackout_roll(delta: float) -> void:
	if _blackout_cooldown_remaining > 0.0:
		_blackout_cooldown_remaining = maxf(_blackout_cooldown_remaining - delta, 0.0)

	if _blackout_active or _blackout_request_pending or _blackout_cooldown_remaining > 0.0:
		return

	_blackout_roll_elapsed += delta
	if _blackout_roll_elapsed < BLACKOUT_ROLL_INTERVAL_SECONDS:
		return

	_blackout_roll_elapsed = 0.0
	var blackout_chance := _blackout_chance_for_distance()
	if blackout_chance <= 0.0:
		return
	if randf() >= blackout_chance:
		return

	_blackout_request_pending = true
	blackout_requested.emit()


func _blackout_chance_for_distance() -> float:
	var distance_ratio := DistanceManager.distance / DistanceManager.MAX_DISTANCE

	if distance_ratio <= 0.2:
		return BLACKOUT_CHANCE_DISTANCE_20
	elif distance_ratio <= 0.4:
		return BLACKOUT_CHANCE_DISTANCE_40
	elif distance_ratio <= 0.6:
		return BLACKOUT_CHANCE_DISTANCE_60
	elif distance_ratio <= 0.8:
		return BLACKOUT_CHANCE_DISTANCE_80

	return 0.0


func _medal_for_time(seconds: float, targets: Dictionary) -> String:
	if seconds <= (targets.get("gold", 0.0) as float):
		return MEDAL_GOLD
	if seconds <= (targets.get("silver", 0.0) as float):
		return MEDAL_SILVER
	if seconds <= (targets.get("bronze", 0.0) as float):
		return MEDAL_BRONZE
	return MEDAL_CLEAR


func _build_stage_stats() -> Dictionary:
	var targets := _current_customer.get("medal_targets", {}) as Dictionary
	return {
		"served": served_customers,
		"failed": failed_customers,
		"stage": current_stage,
		"time": elapsed_time,
		"total_time": total_time,
		"medal": _medal_for_time(elapsed_time, targets),
		"medal_targets": targets,
		"combo": ComboManager.combo,
		"perfect": _current_customer.get("mistakes", 0) == 0,
		"is_final_stage": current_stage >= MAX_STAGE,
		"medals": earned_medals.duplicate(),
	}
