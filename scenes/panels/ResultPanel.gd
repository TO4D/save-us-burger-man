extends Control

signal restart_pressed

@export var title_text := ""

@onready var title_label: Label = $Center/TitleLabel
@onready var stats_label: Label = $Center/StatsLabel
@onready var restart_button: Button = $Center/RestartButton


func _ready() -> void:
	title_label.text = title_text
	restart_button.pressed.connect(func(): restart_pressed.emit())


func on_show(data: Dictionary = {}) -> void:
	stats_label.text = "Served: %d\nStage: %d\nDamage: %d\nMonster HP: %d/%d\nDistance: %d\nTime: %ds" % [
		data.get("served", 0),
		data.get("stage", 1),
		roundi(data.get("damage_dealt", 0.0)),
		roundi(data.get("monster_hp", 0.0)),
		roundi(data.get("monster_max_hp", 300.0)),
		roundi(data.get("distance", 0.0)),
		roundi(data.get("time", 0.0)),
	]
