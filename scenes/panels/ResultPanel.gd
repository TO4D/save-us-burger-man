extends Control

signal restart_pressed
signal main_menu_pressed

@export var title_text := ""
@export var button_enable_delay := 0.0

@onready var title_label: Label = _get_content_node("TitleLabel") as Label
@onready var stats_label: Label = _get_content_node("StatsLabel") as Label
@onready var restart_button: Button = _get_content_node("RestartButton") as Button
@onready var main_menu_button: Button = _get_content_node("MainMenuButton") as Button

var _button_enable_sequence_id := 0

func _get_content_node(node_name: String) -> Node:
	var panel_node := get_node_or_null("Dim/Panel/Margin/Rows/" + node_name)
	if panel_node != null:
		return panel_node
	return get_node_or_null("Center/" + node_name)

func _ready() -> void:
	title_label.text = title_text
	restart_button.pressed.connect(func(): restart_pressed.emit())
	if main_menu_button != null:
		main_menu_button.pressed.connect(func(): main_menu_pressed.emit())


func on_show(data: Dictionary = {}) -> void:
	_button_enable_sequence_id += 1
	stats_label.text = "Time: %s\nServed Burgers: %d\nMax Combo: %d" % [
		_format_time(data.get("time", 0.0) as float),
		data.get("served", 0),
		data.get("max_combo", 0),
	]
	_set_buttons_disabled(button_enable_delay > 0.0)
	if button_enable_delay > 0.0:
		var sequence_id := _button_enable_sequence_id
		await get_tree().create_timer(button_enable_delay).timeout
		if sequence_id != _button_enable_sequence_id or not visible:
			return
		_set_buttons_disabled(false)
	restart_button.grab_focus()


func on_hide() -> void:
	_button_enable_sequence_id += 1
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	restart_button.disabled = disabled
	if main_menu_button != null:
		main_menu_button.disabled = disabled


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
