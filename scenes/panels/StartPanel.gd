extends Control

signal start_pressed
signal settings_pressed
signal quit_pressed

@onready var start_button: Button = $Center/Buttons/StartButton
@onready var settings_button: Button = $Center/Buttons/SettingsButton
@onready var credits_button: Button = $Center/Buttons/CreditsButton
@onready var quit_button: Button = $Center/Buttons/QuitButton
@onready var credits_popup: AcceptDialog = $CreditsPopup


func _ready() -> void:
	start_button.pressed.connect(func(): start_pressed.emit())
	settings_button.pressed.connect(func(): settings_pressed.emit())
	credits_button.pressed.connect(_show_credits)
	quit_button.pressed.connect(func(): quit_pressed.emit())


func _show_credits() -> void:
	credits_popup.popup_centered()
