extends Control

signal finished

@onready var howto: Control = $howto
@onready var gui: Control = $gui
@onready var continue_button: Button = $ContinueButton

var current_page := 0


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)


func on_show() -> void:
	current_page = 0
	_update_page()
	continue_button.grab_focus()


func _on_continue_pressed() -> void:
	if current_page == 0:
		current_page = 1
		_update_page()
		continue_button.grab_focus()
		return

	finished.emit()


func _update_page() -> void:
	howto.visible = current_page == 0
	gui.visible = current_page == 1