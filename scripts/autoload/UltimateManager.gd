extends Node

signal gauge_changed(value: int, max_value: int)
signal ready_changed(ready: bool)
signal triggered()

const MAX_GAUGE := 144

var gauge: int = 0
var is_ready: bool = false


func add_gauge_for_combo(combo: int) -> void:
	if is_ready:
		return

	var gain := _gain_for_combo(combo)
	if gain <= 0:
		return

	gauge = mini(gauge + gain, MAX_GAUGE)
	_emit_gauge_state()


func trigger() -> bool:
	if not is_ready:
		return false

	reset()
	triggered.emit()
	return true


func reset() -> void:
	gauge = 0
	_emit_gauge_state()


func _gain_for_combo(combo: int) -> int:
	if combo >= 20:
		return 4
	if combo >= 10:
		return 3
	if combo >= 5:
		return 2
	return 1


func _emit_gauge_state() -> void:
	gauge_changed.emit(gauge, MAX_GAUGE)
	var next_ready := gauge >= MAX_GAUGE
	if next_ready != is_ready:
		is_ready = next_ready
		ready_changed.emit(is_ready)
