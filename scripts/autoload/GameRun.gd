extends Node

signal run_started
signal customer_ready(customer: Dictionary)
signal stage_changed(stage: int)
signal run_failed(stats: Dictionary)
signal run_victory(stats: Dictionary)
signal time_changed(remaining: float)

const RUN_SECONDS := 60.0
const RECOVERY_SINGLE := {1: 6.0, 2: 8.0, 3: 10.0, 4: 12.0, 5: 15.0}
const RECOVERY_MULTI := {
	3: {2: 16.0},
	4: {2: 20.0, 3: 28.0},
	5: {2: 24.0, 3: 35.0},
}

var running := false
var remaining_time := RUN_SECONDS
var current_stage := 1
var served_customers := 0
var failed_customers := 0
var _customer_index := 0


func _ready() -> void:
	DistanceManager.game_over.connect(_on_distance_game_over)


func _process(delta: float) -> void:
	if not running:
		return

	remaining_time = max(remaining_time - delta, 0.0)
	time_changed.emit(remaining_time)

	if remaining_time <= 0.0:
		running = false
		DistanceManager.stop()
		run_victory.emit(_build_stats())


func start() -> void:
	randomize()
	running = true
	remaining_time = RUN_SECONDS
	current_stage = 1
	served_customers = 0
	failed_customers = 0
	_customer_index = 0
	DistanceManager.reset()
	DistanceManager.set_stage(current_stage)
	run_started.emit()
	stage_changed.emit(current_stage)
	time_changed.emit(remaining_time)
	process_next_customer()


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


func on_order_completed(success: bool, recovery: float) -> void:
	if not running:
		return

	if success:
		served_customers += 1
		if recovery > 0.0:
			DistanceManager.recover(recovery)
	else:
		failed_customers += 1

	process_next_customer()


func abort() -> void:
	running = false
	DistanceManager.stop()


func _create_customer(index: int, stage: int) -> Dictionary:
	var burger_count := _burger_count_for_stage(stage)
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
		"recovery": _recovery_for(stage, burger_count),
	}


func _stage_for_customer(index: int) -> int:
	if index <= 3:
		return 1
	if index <= 6:
		return 2
	if index <= 10:
		return 3
	if index <= 13:
		return 4
	return 5


func _burger_count_for_stage(stage: int) -> int:
	if stage < 3:
		return 1
	if stage == 3:
		return 2 if randf() < 0.3 else 1
	if stage == 4:
		if randf() < 0.5:
			return 2 + int(randf() < 0.35)
		return 1
	return 3


func _has_blackout(stage: int) -> bool:
	match stage:
		1:
			return false
		2:
			return randf() < 0.3
		3:
			return randf() < 0.4
		4:
			return randf() < 0.6
		_:
			return randf() < 0.8


func _recovery_for(stage: int, burger_count: int) -> float:
	if burger_count > 1 and RECOVERY_MULTI.has(stage):
		var multi_recovery: Dictionary = RECOVERY_MULTI[stage] as Dictionary
		return multi_recovery.get(burger_count, RECOVERY_SINGLE.get(stage, 6.0)) as float
	return RECOVERY_SINGLE.get(stage, 6.0) as float


func _on_distance_game_over() -> void:
	if not running:
		return

	running = false
	run_failed.emit(_build_stats())


func _build_stats() -> Dictionary:
	return {
		"served": served_customers,
		"failed": failed_customers,
		"stage": current_stage,
		"distance": DistanceManager.distance,
		"time": remaining_time,
	}
