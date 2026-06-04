extends Node

signal satiety_changed(value: float, max_value: float)
signal ultimate_threshold_reached
signal satisfied

const MAX_SATIETY := 600.0
const ULTIMATE_THRESHOLD_RATIOS: Array[float] = [0.4, 0.8]

var satiety := 0.0
var total_fullness := 0.0
var running := false
var ultimate_pending := false
var ultimate_pending_count := 0
var next_ultimate_threshold_index := 0


func reset() -> void:
	satiety = 0.0
	total_fullness = 0.0
	running = true
	ultimate_pending = false
	ultimate_pending_count = 0
	next_ultimate_threshold_index = 0
	satiety_changed.emit(satiety, MAX_SATIETY)


func stop() -> void:
	running = false


func add_satiety(amount: float) -> void:
	if not running or amount <= 0.0:
		return

	var previous_satiety := satiety
	satiety = minf(satiety + amount, MAX_SATIETY)
	total_fullness += satiety - previous_satiety
	satiety_changed.emit(satiety, MAX_SATIETY)

	_queue_reached_ultimates(previous_satiety, satiety)

	if satiety >= MAX_SATIETY:
		running = false
		satisfied.emit()


func consume_ultimate_pending() -> bool:
	if ultimate_pending_count <= 0:
		return false

	ultimate_pending_count -= 1
	ultimate_pending = ultimate_pending_count > 0
	return true


func _queue_reached_ultimates(previous_value: float, current_value: float) -> void:
	while next_ultimate_threshold_index < ULTIMATE_THRESHOLD_RATIOS.size():
		var threshold := MAX_SATIETY * ULTIMATE_THRESHOLD_RATIOS[next_ultimate_threshold_index]
		if previous_value >= threshold or current_value < threshold:
			break

		next_ultimate_threshold_index += 1
		ultimate_pending_count += 1
		ultimate_pending = true
		ultimate_threshold_reached.emit()
