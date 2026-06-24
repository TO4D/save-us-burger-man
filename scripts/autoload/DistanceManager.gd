extends Node

signal distance_changed(value: float, max_value: float)
signal game_over
signal freeze_changed(active: bool, remaining: float)

const MAX_DISTANCE := 100.0
const MAX_STAGE := 10
const MIN_DECAY_PER_SECOND := 1.75
const MAX_DECAY_PER_SECOND := 4.75
const UNFED_WARNING_SECONDS := 15.0
const UNFED_ACCEL_START_SECONDS := 20.0
const UNFED_ACCEL_RAMP_SECONDS := 5.0

var distance := MAX_DISTANCE
var decay_per_second := 1.0
var running := false
var freeze_remaining := 0.0
var freeze_hold_count := 0
var unfed_elapsed := 0.0
var unfed_warning_played := false


func _process(delta: float) -> void:
	if not running:
		return

	if freeze_hold_count > 0:
		return

	if freeze_remaining > 0.0:
		freeze_remaining = max(freeze_remaining - delta, 0.0)
		freeze_changed.emit(freeze_remaining > 0.0, freeze_remaining)
		return

	unfed_elapsed += delta
	if not unfed_warning_played and unfed_elapsed >= UNFED_WARNING_SECONDS:
		unfed_warning_played = true
		AudioManager.play_sfx(AudioManager.Sfx.WARNING_GROWL)

	var effective_decay := _current_decay_per_second()
	distance = max(distance - effective_decay * delta, 0.0)
	distance_changed.emit(distance, MAX_DISTANCE)

	if distance <= 0.0:
		running = false
		game_over.emit()


func reset() -> void:
	distance = MAX_DISTANCE
	running = true
	freeze_remaining = 0.0
	freeze_hold_count = 0
	unfed_elapsed = 0.0
	unfed_warning_played = false
	distance_changed.emit(distance, MAX_DISTANCE)
	freeze_changed.emit(false, freeze_remaining)


func stop() -> void:
	running = false
	freeze_remaining = 0.0
	freeze_hold_count = 0
	unfed_elapsed = 0.0
	unfed_warning_played = false
	freeze_changed.emit(false, freeze_remaining)


func set_stage(stage: int) -> void:
	var clamped_stage := clampi(stage, 1, MAX_STAGE)
	var stage_ratio := float(clamped_stage - 1) / float(MAX_STAGE - 1)
	decay_per_second = lerpf(MIN_DECAY_PER_SECOND, MAX_DECAY_PER_SECOND, stage_ratio)


func recover(amount: float) -> void:
	unfed_elapsed = 0.0
	unfed_warning_played = false
	distance = min(distance + amount, MAX_DISTANCE)
	distance_changed.emit(distance, MAX_DISTANCE)


func _current_decay_per_second() -> float:
	if unfed_elapsed < UNFED_ACCEL_START_SECONDS:
		return decay_per_second

	var accel_ratio := clampf(
		(unfed_elapsed - UNFED_ACCEL_START_SECONDS) / UNFED_ACCEL_RAMP_SECONDS,
		0.0,
		1.0
	)
	return lerpf(decay_per_second, MAX_DECAY_PER_SECOND, accel_ratio)


func freeze(duration: float) -> void:
	freeze_remaining = maxf(freeze_remaining, duration)
	freeze_changed.emit(freeze_remaining > 0.0, freeze_remaining)


func hold_freeze() -> void:
	freeze_hold_count += 1
	freeze_changed.emit(true, freeze_remaining)


func release_freeze() -> void:
	freeze_hold_count = maxi(freeze_hold_count - 1, 0)
	freeze_changed.emit(freeze_hold_count > 0 or freeze_remaining > 0.0, freeze_remaining)
