extends Control

signal resume_pressed
signal main_menu_pressed
signal settings_pressed
signal quit_pressed

@onready var resume_button: Button = $Dim/Panel/Margin/Rows/ResumeButton
@onready var main_menu_button: Button = $Dim/Panel/Margin/Rows/MainMenuButton
@onready var settings_button: Button = $Dim/Panel/Margin/Rows/SettingsButton
@onready var quit_button: Button = $Dim/Panel/Margin/Rows/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(func(): resume_pressed.emit())
	main_menu_button.pressed.connect(func(): main_menu_pressed.emit())
	settings_button.pressed.connect(func(): settings_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())


func on_show() -> void:
	resume_button.grab_focus()
