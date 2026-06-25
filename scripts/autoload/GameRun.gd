extends Node

signal run_started
signal customer_ready(customer: Dictionary)
signal stage_changed(stage: int)
signal run_failed(stats: Dictionary)
signal run_victory(stats: Dictionary)
signal time_changed(elapsed: float)
signal blackout_requested

const CUSTOMERS_PER_STAGE := 2
const MAX_STAGE := 10
const RECOVERY_PER_FULLNESS := 1.5
const FULLNESS_SINGLE := {
	1: 6.0,
	2: 8.0,
	3: 10.0,
	4: 12.0,
	5: 13.0,
	6: 14.0,
	7: 15.0,
	8: 16.0,
	9: 17.0,
	10: 18.0,
}
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
const BLACKOUT_ENABLED := false
const BLACKOUT_CHANCE_DISTANCE_80 := 0.9
const BLACKOUT_CHANCE_DISTANCE_60 := 0.01
const BLACKOUT_CHANCE_DISTANCE_40 := 0.02
const BLACKOUT_CHANCE_DISTANCE_20 := 0.04

var running := false
var elapsed_time := 0.0
var current_stage := 1
var served_customers := 0
var failed_customers := 0
var start_blocked := false
var _customer_index := 0
var _blackout_roll_elapsed := 0.0
var _blackout_cooldown_remaining := 0.0
var _blackout_active := false
var _blackout_request_pending := false


func _ready() -> void:
	DistanceManager.game_over.connect(_on_distance_game_over)
	MonsterManager.satisfied.connect(_on_monster_satisfied)


func _process(delta: float) -> void:
	if not running or start_blocked:
		return

	elapsed_time += delta
	time_changed.emit(elapsed_time)
	_update_blackout_roll(delta)


func start() -> void:
	randomize()
	running = true
	start_blocked = false
	elapsed_time = 0.0
	current_stage = 1
	served_customers = 0
	failed_customers = 0
	_customer_index = 0
	_reset_blackout_state()
	ComboManager.reset()
	UltimateManager.reset()
	ScoreManager.reset_run()
	DistanceManager.reset()
	MonsterManager.reset()
	DistanceManager.set_stage(current_stage)
	run_started.emit()
	stage_changed.emit(current_stage)
	time_changed.emit(elapsed_time)
	process_next_customer()


func set_start_blocked(blocked: bool) -> void:
	start_blocked = blocked
	if running:
		DistanceManager.running = not start_blocked


func process_next_customer() -> void:
	if not running:
		return

	_customer_index += 1
	var next_stage := _stage_for_customer(_customer_index)
	if next_stage != current_stage:
		current_stage = next_stage
		DistanceManager.set_stage(current_stage)
		stage_changed.emit(current_stage)

	customer_ready.emit(_create_customer(_customer_index, current_stage))


func on_order_completed(success: bool) -> void:
	if not running:
		return

	if success:
		served_customers += 1
	else:
		failed_customers += 1

	process_next_customer()


func abort() -> void:
	running = false
	start_blocked = false
	_reset_blackout_state()
	DistanceManager.stop()
	MonsterManager.stop()
	ComboManager.reset()
	UltimateManager.reset()


func _create_customer(index: int, stage: int) -> Dictionary:
	var burger_count := _burger_count_for_stage(stage)
	var fullness := _fullness_for(stage, burger_count)
	var recipes: Array[Recipe] = []
	for i in range(burger_count):
		recipes.append(RecipeGenerator.generate_for_stage(stage))

	var variants: Array[String] = []
	if burger_count > 1:
		variants.append("multi")

	return {
		"index": index,
		"stage": stage,
		"recipes": recipes,
		"variants": variants,
		"fullness": fullness,
		"knockback": _recovery_for(fullness),
	}


func _stage_for_customer(index: int) -> int:
	return mini(int(ceil(float(index) / float(CUSTOMERS_PER_STAGE))), MAX_STAGE)


func _burger_count_for_stage(_stage: int) -> int:
	return 1


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
	if not BLACKOUT_ENABLED:
		return

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


func _fullness_for(stage: int, burger_count: int) -> float:
	var base_fullness := FULLNESS_SINGLE.get(clampi(stage, 1, MAX_STAGE), 6.0) as float
	var multi_burger_bonus := 1.0 + 0.5 * float(maxi(burger_count - 1, 0))
	return roundf(base_fullness * multi_burger_bonus)


func _recovery_for(fullness: float) -> float:
	return fullness * RECOVERY_PER_FULLNESS


func _on_distance_game_over() -> void:
	if not running:
		return

	var is_new_high_score := ScoreManager.finish_run()
	var stats := _build_stats(is_new_high_score)
	running = false
	start_blocked = false
	_reset_blackout_state()
	MonsterManager.stop()
	ComboManager.reset()
	UltimateManager.reset()
	run_failed.emit(stats)


func _on_monster_satisfied() -> void:
	if not running:
		return

	var is_new_high_score := ScoreManager.finish_run()
	var stats := _build_stats(is_new_high_score)
	running = false
	start_blocked = false
	_reset_blackout_state()
	DistanceManager.stop()
	ComboManager.reset()
	UltimateManager.reset()
	run_victory.emit(stats)


func _build_stats(is_new_high_score: bool = false) -> Dictionary:
	return {
		"score": ScoreManager.score,
		"high_score": GameSettings.high_score,
		"is_new_high_score": is_new_high_score,
		"served": served_customers,
		"max_combo": ComboManager.max_combo,
		"failed": failed_customers,
		"stage": current_stage,
		"distance": DistanceManager.distance,
		"satiety": MonsterManager.satiety,
		"max_satiety": MonsterManager.MAX_SATIETY,
		"total_fullness": MonsterManager.total_fullness,
		"time": elapsed_time,
	}
