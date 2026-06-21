extends Control

signal restart_pressed
signal main_menu_pressed

@export var title_text := ""

@onready var title_label: Label = _get_content_node("TitleLabel") as Label
@onready var stats_label: Label = _get_content_node("StatsLabel") as Label
@onready var restart_button: Button = _get_content_node("RestartButton") as Button
@onready var main_menu_button: Button = _get_content_node("MainMenuButton") as Button

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
	stats_label.text = "Time: %s\nServed Burgers: %d\nMax Combo: %d" % [
		_format_time(data.get("time", 0.0) as float),
		data.get("served", 0),
		data.get("max_combo", 0),
	]
	restart_button.grab_focus()


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
