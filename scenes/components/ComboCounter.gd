extends Control
class_name ComboCounter

const NORMAL_COLOR := Color(0.0, 0.0, 0.0, 0.95)
const MILESTONE_COLOR := Color(1.0, 0.9, 0.35, 1.0)
const RESET_COLOR := Color(1.0, 0.45, 0.4, 1.0)

@onready var value_label: Label = $ValueLabel

var _base_position: Vector2


func _ready() -> void:
	_base_position = position
	ComboManager.combo_changed.connect(_on_combo_changed)
	ComboManager.milestone_reached.connect(_on_milestone_reached)
	ComboManager.combo_reset.connect(_on_combo_reset)
	_on_combo_changed(ComboManager.combo)


func _on_combo_changed(value: int) -> void:
	value_label.text = "x%d" % value
	value_label.modulate = NORMAL_COLOR if value > 0 else Color(0.9, 0.9, 0.9, 0.55)


func _on_milestone_reached(value: int) -> void:
	_on_combo_changed(value)
	scale = Vector2.ONE
	value_label.modulate = MILESTONE_COLOR
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(value_label, "modulate", NORMAL_COLOR, 0.24)


func _on_combo_reset(previous_value: int) -> void:
	if previous_value <= 0:
		return

	position = _base_position
	value_label.modulate = RESET_COLOR
	var tween := create_tween()
	tween.tween_property(self, "position:x", _base_position.x - 4.0, 0.035)
	tween.tween_property(self, "position:x", _base_position.x + 4.0, 0.035)
	tween.tween_property(self, "position:x", _base_position.x, 0.04)
	tween.parallel().tween_property(value_label, "modulate", Color(0.9, 0.9, 0.9, 0.55), 0.18)
