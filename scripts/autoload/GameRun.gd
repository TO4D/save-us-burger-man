extends Node

signal run_started
signal customer_ready(customer: Dictionary)
signal stage_changed(stage: int)
signal run_failed(stats: Dictionary)
signal run_victory(stats: Dictionary)
signal time_changed(elapsed: float)

const CUSTOMERS_PER_STAGE := 2
const MAX_STAGE := 10
const KNOCKBACK_PER_DAMAGE := 1.5
const DAMAGE_SINGLE := {
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

var running := false
var elapsed_time := 0.0
var current_stage := 1
var served_customers := 0
var failed_customers := 0
var start_blocked := false
var _customer_index := 0


func _ready() -> void:
	DistanceManager.game_over.connect(_on_distance_game_over)
	MonsterManager.defeated.connect(_on_monster_defeated)


func _process(delta: float) -> void:
	if not running or start_blocked:
		return

	elapsed_time += delta
	time_changed.emit(elapsed_time)


func start() -> void:
	randomize()
	running = true
	start_blocked = false
	elapsed_time = 0.0
	current_stage = 1
	served_customers = 0
	failed_customers = 0
	_customer_index = 0
	ComboManager.reset()
	UltimateManager.reset()
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
	DistanceManager.stop()
	MonsterManager.stop()
	ComboManager.reset()
	UltimateManager.reset()


func _create_customer(index: int, stage: int) -> Dictionary:
	var burger_count := _burger_count_for_stage(stage)
	var damage := _damage_for(stage, burger_count)
	var recipes: Array[Recipe] = []
	for i in range(burger_count):
		recipes.append(RecipeGenerator.generate_for_stage(stage))

	var variants: Array[String] = []
	if burger_count > 1:
		variants.append("multi")
	if _has_blackout(stage):
		variants.append("blackout")

	return {
		"index": index,
		"stage": stage,
		"recipes": recipes,
		"variants": variants,
		"damage": damage,
		"knockback": _knockback_for(damage),
	}


func _stage_for_customer(index: int) -> int:
	return mini(int(ceil(float(index) / float(CUSTOMERS_PER_STAGE))), MAX_STAGE)


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


func _has_blackout(stage: int) -> bool:
	match stage:
		1:
			return false
		2:
			return randf() < 0.02
		3:
			return randf() < 0.04
		4:
			return randf() < 0.06
		5:
			return randf() < 0.08
		6:
			return randf() < 0.10
		7:
			return randf() < 0.12
		8:
			return randf() < 0.14
		9:
			return randf() < 0.16
		_:
			return randf() < 0.18


func _damage_for(stage: int, burger_count: int) -> float:
	var base_damage := DAMAGE_SINGLE.get(clampi(stage, 1, MAX_STAGE), 6.0) as float
	var multi_burger_bonus := 1.0 + 0.5 * float(maxi(burger_count - 1, 0))
	return roundf(base_damage * multi_burger_bonus)


func _knockback_for(damage: float) -> float:
	return damage * KNOCKBACK_PER_DAMAGE


func _on_distance_game_over() -> void:
	if not running:
		return

	running = false
	start_blocked = false
	MonsterManager.stop()
	ComboManager.reset()
	UltimateManager.reset()
	run_failed.emit(_build_stats())


func _on_monster_defeated() -> void:
	if not running:
		return

	running = false
	start_blocked = false
	DistanceManager.stop()
	ComboManager.reset()
	UltimateManager.reset()
	run_victory.emit(_build_stats())


func _build_stats() -> Dictionary:
	return {
		"served": served_customers,
		"failed": failed_customers,
		"stage": current_stage,
		"distance": DistanceManager.distance,
		"monster_hp": MonsterManager.health,
		"monster_max_hp": MonsterManager.MAX_HEALTH,
		"damage_dealt": MonsterManager.damage_dealt,
		"time": elapsed_time,
	}
