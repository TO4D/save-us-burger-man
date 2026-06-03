extends Node

signal satiety_changed(value: float, max_value: float)
signal satisfied

const MAX_SATIETY := 300.0

var satiety := 0.0
var total_fullness := 0.0
var running := false


func reset() -> void:
	satiety = 0.0
	total_fullness = 0.0
	running = true
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

	if satiety >= MAX_SATIETY:
		running = false
		satisfied.emit()
