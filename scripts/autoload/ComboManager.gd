extends Node

signal combo_changed(value: int)
signal milestone_reached(value: int)
signal combo_reset(previous_value: int)

const MILESTONES := [5, 10, 20]

var combo: int = 0
var max_combo: int = 0


func add_combo() -> void:
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_changed.emit(combo)
	if combo in MILESTONES:
		milestone_reached.emit(combo)


func reset_combo() -> void:
	if combo <= 0:
		return

	var previous_value := combo
	combo = 0
	combo_changed.emit(combo)
	combo_reset.emit(previous_value)


func reset(silent: bool = true) -> void:
	max_combo = 0
	if silent:
		combo = 0
		combo_changed.emit(combo)
		return

	reset_combo()
