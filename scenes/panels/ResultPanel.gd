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
	var stage := data.get("stage", 1) as int
	var time := data.get("time", 0.0) as float
	var targets := data.get("medal_targets", {}) as Dictionary
	var medal := data.get("medal", "Clear") as String
	var is_final_stage := data.get("is_final_stage", false) as bool

	if title_text == "" or title_text.begins_with("Stage"):
		title_label.text = "Stage %d Complete" % stage
	else:
		title_label.text = title_text
	stats_label.text = "Reward: %s\nTime: %.3fs\nGold %.1fs / Silver %.1fs / Bronze %.1fs\nCombo: %d\nPerfect: %s" % [
		medal,
		time,
		targets.get("gold", 0.0),
		targets.get("silver", 0.0),
		targets.get("bronze", 0.0),
		data.get("combo", 0),
		"YES" if data.get("perfect", false) else "NO",
	]
	restart_button.text = "Restart" if is_final_stage else "Next Stage"


func on_hide() -> void:
	title_label.text = title_text
