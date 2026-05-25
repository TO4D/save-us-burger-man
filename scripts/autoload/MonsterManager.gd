extends Node

signal health_changed(value: float, max_value: float)
signal defeated

const MAX_HEALTH := 300.0

var health := MAX_HEALTH
var damage_dealt := 0.0
var running := false


func reset() -> void:
	health = MAX_HEALTH
	damage_dealt = 0.0
	running = true
	health_changed.emit(health, MAX_HEALTH)


func stop() -> void:
	running = false


func apply_damage(amount: float) -> void:
	if not running or amount <= 0.0:
		return

	var previous_health := health
	health = maxf(health - amount, 0.0)
	damage_dealt += previous_health - health
	health_changed.emit(health, MAX_HEALTH)

	if health <= 0.0:
		running = false
		defeated.emit()
