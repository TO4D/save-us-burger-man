extends Control
class_name ComboCounter

const RESET_COLOR := Color(1.0, 0.45, 0.4, 1.0)
const FLASH_COLOR := Color.WHITE
const INACTIVE_COLOR := Color(0.9, 0.9, 0.9, 0.55)
const IDLE_DISPLAY_SECONDS := 5.0
const FADE_OUT_SECONDS := 0.18
const COMBO_FLASH_SECONDS := 0.4
const COMBO_SCALE_INTERVAL := 10
const COMBO_SCALE_MULTIPLIER := 1.25
const COMBO_SCALE_OUT_SECONDS := 0.1
const COMBO_SCALE_BACK_SECONDS := 0.2

@onready var value_label: Label = $ValueLabel

var _display_position: Vector2
var _label_base_scale: Vector2
var _visibility_tween: Tween = null
var _combo_flash_tween: Tween = null
var _combo_scale_tween: Tween = null
var _last_combo_value: int = 0
var _value_label_settings: LabelSettings
var _combo_text_color: Color


func _ready() -> void:
	_display_position = position
	_label_base_scale = value_label.scale
	if value_label.label_settings != null:
		_value_label_settings = value_label.label_settings.duplicate()
	else:
		_value_label_settings = LabelSettings.new()
		_value_label_settings.font_color = value_label.get_theme_color("font_color")
	value_label.label_settings = _value_label_settings
	_combo_text_color = _value_label_settings.font_color
	visible = false
	modulate.a = 0.0
	ComboManager.combo_changed.connect(_on_combo_changed)
	ComboManager.combo_reset.connect(_on_combo_reset)
	_last_combo_value = ComboManager.combo
	_on_combo_changed(ComboManager.combo)


func show_at_fixed_position() -> void:
	position = _display_position
	visible = true
	modulate.a = 1.0
	value_label.pivot_offset = value_label.size * 0.5
	value_label.scale = _label_base_scale
	_reset_visibility_tween()
	_visibility_tween = create_tween()
	_visibility_tween.tween_interval(IDLE_DISPLAY_SECONDS)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_visibility_tween.tween_callback(_hide_after_fade)


func _on_combo_changed(value: int) -> void:
	value_label.text = "%d COMBO" % value
	if value > _last_combo_value:
		_flash_combo_text()
		if value % COMBO_SCALE_INTERVAL == 0:
			_play_combo_scale_effect()
	else:
		_set_combo_text_color(_combo_text_color if value > 0 else INACTIVE_COLOR)
	_last_combo_value = value
	if value <= 0:
		_reset_visibility_tween()
		_reset_combo_flash_tween()
		_reset_combo_scale_tween()
		_set_combo_text_color(INACTIVE_COLOR)
		value_label.scale = _label_base_scale
		modulate.a = 0.0
		visible = false


func _on_combo_reset(previous_value: int) -> void:
	if previous_value <= 0:
		return

	position = _display_position
	visible = true
	modulate.a = 1.0
	value_label.scale = _label_base_scale
	_set_combo_text_color(RESET_COLOR)
	_reset_visibility_tween()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "position:x", _display_position.x - 4.0, 0.035)
	_visibility_tween.tween_property(self, "position:x", _display_position.x + 4.0, 0.035)
	_visibility_tween.tween_property(self, "position:x", _display_position.x, 0.04)
	_visibility_tween.parallel().tween_property(_value_label_settings, "font_color", INACTIVE_COLOR, 0.18)
	_visibility_tween.tween_interval(IDLE_DISPLAY_SECONDS)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_visibility_tween.tween_callback(_hide_after_fade)


func _reset_visibility_tween() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null


func _hide_after_fade() -> void:
	visible = false
	_reset_combo_scale_tween()
	value_label.scale = _label_base_scale


func _flash_combo_text() -> void:
	_reset_combo_flash_tween()
	_set_combo_text_color(FLASH_COLOR)
	_combo_flash_tween = create_tween()
	_combo_flash_tween.tween_property(_value_label_settings, "font_color", _combo_text_color, COMBO_FLASH_SECONDS)


func _set_combo_text_color(color: Color) -> void:
	_value_label_settings.font_color = color


func _play_combo_scale_effect() -> void:
	_reset_combo_scale_tween()
	value_label.pivot_offset = value_label.size * 0.5
	value_label.scale = _label_base_scale
	_combo_scale_tween = create_tween()
	_combo_scale_tween.tween_property(value_label, "scale", _label_base_scale * COMBO_SCALE_MULTIPLIER, COMBO_SCALE_OUT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_scale_tween.tween_property(value_label, "scale", _label_base_scale, COMBO_SCALE_BACK_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_combo_flash_tween() -> void:
	if _combo_flash_tween != null and _combo_flash_tween.is_valid():
		_combo_flash_tween.kill()
	_combo_flash_tween = null


func _reset_combo_scale_tween() -> void:
	if _combo_scale_tween != null and _combo_scale_tween.is_valid():
		_combo_scale_tween.kill()
	_combo_scale_tween = null
