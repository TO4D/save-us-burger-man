extends Control

signal start_pressed

@onready var start_button: Button = $Center/StartButton


func _ready() -> void:
	start_button.pressed.connect(func(): start_pressed.emit())
