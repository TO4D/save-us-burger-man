extends Node2D
class_name PopcornComboCounter

const FLASH_COLOR := Color.WHITE
const END_COLOR := Color("ffbb69ff")
const POP_VELOCITY := Vector2(18.0, -20.0)
const GRAVITY := 20
const LIFETIME_SECONDS := 0.4
const FLASH_SECONDS := 0.28

@onready var label_template: Control = $PopcornLabelTemplate
@onready var template_shadow: Label = $PopcornLabelTemplate/shadow
@onready var template_value_label: Label = $PopcornLabelTemplate/ValueLabel

var _base_text_color := Color.WHITE
var _base_shadow_color := Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	_base_text_color = _get_label_color(template_value_label, _base_text_color)
	_base_shadow_color = _get_label_color(template_shadow, _base_shadow_color)


func pop(value: int, spawn_global_position: Vector2) -> void:
	if value <= 0:
		return

	var item := label_template.duplicate() as Control
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.visible = true
	item.global_position = spawn_global_position - item.pivot_offset
	add_child(item)

	var shadow := item.get_node("shadow") as Label
	var text := item.get_node("ValueLabel") as Label
	var shadow_settings := _duplicate_label_settings(shadow, _base_shadow_color)
	var text_settings := _duplicate_label_settings(text, _base_text_color)
	var combo_text := "%d COMBO" % value

	shadow.text = combo_text
	text.text = combo_text

	shadow_settings.font_color = FLASH_COLOR
	text_settings.font_color = FLASH_COLOR

	var color_tween := create_tween()
	color_tween.tween_property(text_settings, "font_color", _base_text_color, FLASH_SECONDS)
	color_tween.parallel().tween_property(shadow_settings, "font_color", _base_shadow_color, FLASH_SECONDS)
	color_tween.tween_property(text_settings, "font_color", END_COLOR, FLASH_SECONDS)

	_run_pop_motion(item, POP_VELOCITY)


func _duplicate_label_settings(label: Label, fallback_color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	if label.label_settings != null:
		settings = label.label_settings.duplicate() as LabelSettings
	else:
		settings.font_color = fallback_color
	label.label_settings = settings
	return settings


func _get_label_color(label: Label, fallback_color: Color) -> Color:
	if label.label_settings != null:
		return label.label_settings.font_color
	return fallback_color


func _run_pop_motion(item: Control, initial_velocity: Vector2) -> void:
	var velocity := initial_velocity
	if randi() % 2 == 0:
		velocity.x = -velocity.x

	var elapsed := 0.0
	while elapsed < LIFETIME_SECONDS and is_instance_valid(item):
		var delta := get_process_delta_time()
		elapsed += delta
		velocity.y += GRAVITY * delta
		item.position += velocity * delta
		await get_tree().process_frame

	if is_instance_valid(item):
		item.queue_free()
