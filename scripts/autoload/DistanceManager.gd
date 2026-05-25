extends Node

signal distance_changed(value: float, max_value: float)
signal game_over
signal freeze_changed(active: bool, remaining: float)

const MAX_DISTANCE := 100.0
const MAX_STAGE := 10
const MIN_DECAY_PER_SECOND := 1.75
const MAX_DECAY_PER_SECOND := 4.75

var distance := MAX_DISTANCE
var decay_per_second := 1.0
var running := false
var freeze_remaining := 0.0


func _process(delta: float) -> void:
	if not running:
		return

	if freeze_remaining > 0.0:
		freeze_remaining = max(freeze_remaining - delta, 0.0)
		freeze_changed.emit(freeze_remaining > 0.0, freeze_remaining)
		return

	distance = max(distance - decay_per_second * delta, 0.0)
	distance_changed.emit(distance, MAX_DISTANCE)

	if distance <= 0.0:
		running = false
		game_over.emit()


func reset() -> void:
	distance = MAX_DISTANCE
	running = true
	freeze_remaining = 0.0
	distance_changed.emit(distance, MAX_DISTANCE)
	freeze_changed.emit(false, freeze_remaining)


func stop() -> void:
	running = false
	freeze_remaining = 0.0
	freeze_changed.emit(false, freeze_remaining)


func set_stage(stage: int) -> void:
	var clamped_stage := clampi(stage, 1, MAX_STAGE)
	var stage_ratio := float(clamped_stage - 1) / float(MAX_STAGE - 1)
	decay_per_second = lerpf(MIN_DECAY_PER_SECOND, MAX_DECAY_PER_SECOND, stage_ratio)


func recover(amount: float) -> void:
	distance = min(distance + amount, MAX_DISTANCE)
	distance_changed.emit(distance, MAX_DISTANCE)


func freeze(duration: float) -> void:
	freeze_remaining = maxf(freeze_remaining, duration)
	freeze_changed.emit(freeze_remaining > 0.0, freeze_remaining)
