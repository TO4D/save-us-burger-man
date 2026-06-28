extends Control

signal resume_pressed
signal tutorial_pressed
signal skip_intro_pressed
signal main_menu_pressed
signal settings_pressed
signal quit_pressed

enum MenuMode { GAMEPLAY, INTRO_CUTSCENE }

@onready var resume_button: Button = $Dim/Panel/Margin/Rows/ResumeButton
@onready var tutorial_button: Button = $Dim/Panel/Margin/Rows/TutorialButton
@onready var main_menu_button: Button = $Dim/Panel/Margin/Rows/MainMenuButton
@onready var settings_button: Button = $Dim/Panel/Margin/Rows/SettingsButton
@onready var quit_button: Button = $Dim/Panel/Margin/Rows/QuitButton

var menu_mode := MenuMode.GAMEPLAY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(func(): resume_pressed.emit())
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	main_menu_button.pressed.connect(func(): main_menu_pressed.emit())
	settings_button.pressed.connect(func(): settings_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())


func set_menu_mode(value: MenuMode) -> void:
	menu_mode = value
	if is_node_ready():
		_apply_menu_mode()


func set_gameplay_mode() -> void:
	set_menu_mode(MenuMode.GAMEPLAY)


func set_intro_cutscene_mode() -> void:
	set_menu_mode(MenuMode.INTRO_CUTSCENE)


func on_show() -> void:
	_apply_menu_mode()
	resume_button.grab_focus()


func _on_tutorial_button_pressed() -> void:
	if menu_mode == MenuMode.INTRO_CUTSCENE:
		skip_intro_pressed.emit()
	else:
		tutorial_pressed.emit()


func _apply_menu_mode() -> void:
	var is_intro_cutscene := menu_mode == MenuMode.INTRO_CUTSCENE
	tutorial_button.text = "Skip Intro" if is_intro_cutscene else "Tutorial"
	quit_button.visible = not is_intro_cutscene
	quit_button.focus_mode = Control.FOCUS_NONE if is_intro_cutscene else Control.FOCUS_ALL

	resume_button.focus_neighbor_top = NodePath("../SettingsButton") if is_intro_cutscene else NodePath("../QuitButton")
	resume_button.focus_neighbor_bottom = NodePath("../TutorialButton")
	tutorial_button.focus_neighbor_top = NodePath("../ResumeButton")
	tutorial_button.focus_neighbor_bottom = NodePath("../MainMenuButton")
	main_menu_button.focus_neighbor_top = NodePath("../TutorialButton")
	main_menu_button.focus_neighbor_bottom = NodePath("../SettingsButton")
	settings_button.focus_neighbor_top = NodePath("../MainMenuButton")
	settings_button.focus_neighbor_bottom = NodePath("../ResumeButton") if is_intro_cutscene else NodePath("../QuitButton")
	quit_button.focus_neighbor_top = NodePath("../SettingsButton")
	quit_button.focus_neighbor_bottom = NodePath("../ResumeButton")
