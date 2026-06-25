extends Control

signal start_pressed
signal tutorial_pressed
signal settings_pressed
signal quit_pressed

@onready var start_button: Button = $Center/Buttons/StartButton
@onready var tutorial_button: Button = $Center/Buttons/TutorialButton
@onready var settings_button: Button = $Center/Buttons/SettingsButton
@onready var credits_button: Button = $Center/Buttons/CreditsButton
@onready var quit_button: Button = $Center/Buttons/QuitButton
@onready var credits_overlay: Control = $CreditsOverlay
@onready var credits_close_button: Button = $CreditsOverlay/Dim/Panel/Margin/Rows/CloseButton
@onready var high_score_label_shadow: Label = $HighScoreLabel/shadow
@onready var high_score_label_text: Label = $HighScoreLabel/text


func _ready() -> void:
	GameSettings.settings_changed.connect(_update_high_score_label)
	start_button.pressed.connect(func(): start_pressed.emit())
	tutorial_button.pressed.connect(func(): tutorial_pressed.emit())
	settings_button.pressed.connect(func(): settings_pressed.emit())
	credits_button.pressed.connect(_show_credits)
	credits_close_button.pressed.connect(_hide_credits)
	quit_button.pressed.connect(func(): quit_pressed.emit())
	_update_high_score_label()

func _unhandled_input(event: InputEvent) -> void:
	if not credits_overlay.visible or event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_hide_credits()
		get_viewport().set_input_as_handled()

func on_show(_data: Dictionary = {}) -> void:
	credits_overlay.hide()
	_update_high_score_label()
	start_button.grab_focus()


func _update_high_score_label() -> void:
	var text := "Best %07d" % GameSettings.high_score
	if high_score_label_shadow != null:
		high_score_label_shadow.text = text
	if high_score_label_text != null:
		high_score_label_text.text = text


func _show_credits() -> void:
	credits_overlay.show()
	credits_close_button.grab_focus()


func _hide_credits() -> void:
	credits_overlay.hide()
	credits_button.grab_focus()
