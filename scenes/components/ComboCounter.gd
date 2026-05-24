extends Control
class_name ComboCounter

const NORMAL_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const MILESTONE_COLOR := Color(1.0, 0.9, 0.35, 1.0)
const RESET_COLOR := Color(1.0, 0.45, 0.4, 1.0)
const STACK_POSITION_OFFSET := Vector2(0.0, -10.0)
const RANDOM_POSITION_OFFSET_RANGE := Vector2(5.0, 5.0)
const FADE_OUT_SECONDS := 0.18

@onready var value_label: Label = $ValueLabel

var _display_position: Vector2
var _visibility_tween: Tween = null
var _label_tween: Tween = null


func _ready() -> void:
	_display_position = global_position
	visible = false
	modulate.a = 0.0
	ComboManager.combo_changed.connect(_on_combo_changed)
	ComboManager.milestone_reached.connect(_on_milestone_reached)
	ComboManager.combo_reset.connect(_on_combo_reset)
	_on_combo_changed(ComboManager.combo)


func show_at_stack_position(stack_global_position: Vector2) -> void:
	var random_offset: Vector2 = Vector2(
		randf_range(-RANDOM_POSITION_OFFSET_RANGE.x, RANDOM_POSITION_OFFSET_RANGE.x),
		randf_range(-RANDOM_POSITION_OFFSET_RANGE.y, RANDOM_POSITION_OFFSET_RANGE.y)
	)
	_display_position = stack_global_position + STACK_POSITION_OFFSET + random_offset
	global_position = _display_position
	visible = true
	modulate.a = 1.0
	scale = Vector2(0.92, 0.92)
	_reset_visibility_tween()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visibility_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_visibility_tween.tween_callback(_hide_after_fade)


func _on_combo_changed(value: int) -> void:
	value_label.text = "%d Combo" % value
	value_label.modulate = NORMAL_COLOR if value > 0 else Color(0.9, 0.9, 0.9, 0.55)
	if value <= 0:
		_reset_visibility_tween()
		_reset_label_tween()
		modulate.a = 0.0
		visible = false


func _on_milestone_reached(value: int) -> void:
	_on_combo_changed(value)
	value_label.modulate = MILESTONE_COLOR
	_reset_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(value_label, "modulate", NORMAL_COLOR, 0.24)


func _on_combo_reset(previous_value: int) -> void:
	if previous_value <= 0:
		return

	global_position = _display_position
	visible = true
	modulate.a = 1.0
	value_label.modulate = RESET_COLOR
	_reset_visibility_tween()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "global_position:x", _display_position.x - 4.0, 0.035)
	_visibility_tween.tween_property(self, "global_position:x", _display_position.x + 4.0, 0.035)
	_visibility_tween.tween_property(self, "global_position:x", _display_position.x, 0.04)
	_visibility_tween.parallel().tween_property(value_label, "modulate", Color(0.9, 0.9, 0.9, 0.55), 0.18)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_visibility_tween.tween_callback(_hide_after_fade)


func _reset_visibility_tween() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null


func _reset_label_tween() -> void:
	if _label_tween != null and _label_tween.is_valid():
		_label_tween.kill()
	_label_tween = null


func _hide_after_fade() -> void:
	visible = false
	scale = Vector2.ONE
