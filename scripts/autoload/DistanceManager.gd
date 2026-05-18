extends Node

signal distance_changed(value: float, max_value: float)
signal game_over

const MAX_DISTANCE := 100.0

var distance := MAX_DISTANCE
var decay_per_second := 1.0
var running := false


func _process(delta: float) -> void:
	if not running:
		return

	distance = max(distance - decay_per_second * delta, 0.0)
	distance_changed.emit(distance, MAX_DISTANCE)

	if distance <= 0.0:
		running = false
		game_over.emit()


func reset() -> void:
	distance = MAX_DISTANCE
	running = true
	distance_changed.emit(distance, MAX_DISTANCE)


func stop() -> void:
	running = false


func set_stage(stage: int) -> void:
	decay_per_second = 0.5 + float(clamp(stage, 1, 5)) * 0.5


func recover(amount: float) -> void:
	distance = min(distance + amount, MAX_DISTANCE)
	distance_changed.emit(distance, MAX_DISTANCE)
