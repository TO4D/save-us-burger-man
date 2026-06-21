extends Node2D

@export_group("Debug")
@export var skip_intro_cutscene: bool = false
@export var skip_start_overlay: bool = false

enum SettingsReturnMode { MAIN_MENU, PAUSE_MENU }

var show_ready_go_on_next_order := false
var settings_return_mode := SettingsReturnMode.MAIN_MENU

@onready var start_panel = $PanelLayer/StartPanel
@onready var order_panel = $PanelLayer/OrderPanel
@onready var settings_panel = $PanelLayer/SettingsPanel
@onready var pause_menu = $PanelLayer/PauseMenu
@onready var game_over_cutscene = $PanelLayer/GameOverCutscene
@onready var game_clear_cutscene = $PanelLayer/GameClearCutscene

var pending_game_over_stats: Dictionary = {}
var pending_victory_stats: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	order_panel.process_mode = Node.PROCESS_MODE_PAUSABLE
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	PanelManager.register_panels($PanelLayer)
	start_panel.start_pressed.connect(_on_start_pressed)
	start_panel.settings_pressed.connect(_show_main_settings)
	start_panel.quit_pressed.connect(_quit_game)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	pause_menu.resume_pressed.connect(_resume_game)
	pause_menu.main_menu_pressed.connect(_return_to_main_menu)
	pause_menu.settings_pressed.connect(_show_pause_settings)
	pause_menu.quit_pressed.connect(_quit_game)
	$PanelLayer/CutscenePanel.cutscene_finished.connect(_on_cutscene_finished)
	game_over_cutscene.finished.connect(_on_game_over_cutscene_finished)
	game_clear_cutscene.finished.connect(_on_game_clear_cutscene_finished)
	order_panel.order_completed.connect(_on_order_completed)
	$PanelLayer/GameOverPanel.restart_pressed.connect(start_run)
	$PanelLayer/GameOverPanel.main_menu_pressed.connect(_return_to_main_menu)
	$PanelLayer/VictoryPanel.restart_pressed.connect(start_run)
	$PanelLayer/VictoryPanel.main_menu_pressed.connect(_return_to_main_menu)
	GameRun.customer_ready.connect(_on_customer_ready)
	GameRun.run_failed.connect(_on_run_failed)
	GameRun.run_victory.connect(_on_run_victory)
	settings_panel.visible = false
	pause_menu.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return

	if settings_panel.visible:
		_on_settings_back_pressed()
		get_viewport().set_input_as_handled()
		return

	if pause_menu.visible:
		_resume_game()
		get_viewport().set_input_as_handled()
		return

	if _can_pause_game():
		_pause_game()
		get_viewport().set_input_as_handled()


func start_run() -> void:
	settings_panel.visible = false
	pause_menu.visible = false
	pending_game_over_stats.clear()
	pending_victory_stats.clear()
	game_over_cutscene.reset()
	game_clear_cutscene.reset()
	order_panel.set_gameplay_locked(false)
	get_tree().paused = false
	GameRun.start()


func _on_start_pressed() -> void:
	if skip_intro_cutscene:
		_begin_run_after_intro()
		return
	PanelManager.show_panel(PanelManager.PanelType.CUTSCENE)


func _on_cutscene_finished() -> void:
	_begin_run_after_intro()


func _on_customer_ready(customer: Dictionary) -> void:
	var data := {
		"customer": customer,
		"show_ready_go": show_ready_go_on_next_order,
	}
	show_ready_go_on_next_order = false
	PanelManager.show_panel(PanelManager.PanelType.ORDER, data)


func _on_order_completed(success: bool) -> void:
	GameRun.on_order_completed(success)


func _on_run_failed(stats: Dictionary) -> void:
	pending_game_over_stats = stats
	order_panel.set_gameplay_locked(true)
	game_over_cutscene.play_cutscene()


func _on_game_over_cutscene_finished() -> void:
	PanelManager.show_panel(PanelManager.PanelType.GAME_OVER, pending_game_over_stats)


func _on_run_victory(stats: Dictionary) -> void:
	pending_victory_stats = stats
	order_panel.set_gameplay_locked(true)
	game_clear_cutscene.play_cutscene()


func _on_game_clear_cutscene_finished() -> void:
	PanelManager.show_panel(PanelManager.PanelType.VICTORY, pending_victory_stats)


func _begin_run_after_intro() -> void:
	show_ready_go_on_next_order = not skip_start_overlay
	start_run()


func _show_main_settings() -> void:
	settings_return_mode = SettingsReturnMode.MAIN_MENU
	settings_panel.visible = true
	if settings_panel.has_method("on_show"):
		settings_panel.on_show()


func _show_pause_settings() -> void:
	settings_return_mode = SettingsReturnMode.PAUSE_MENU
	get_tree().paused = true
	pause_menu.visible = false
	settings_panel.visible = true
	if settings_panel.has_method("on_show"):
		settings_panel.on_show()


func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	if settings_return_mode == SettingsReturnMode.PAUSE_MENU and get_tree().paused:
		pause_menu.visible = true
		pause_menu.on_show()
	else:
		start_panel.on_show()


func _pause_game() -> void:
	pause_menu.visible = true
	get_tree().paused = true
	pause_menu.on_show()


func _resume_game() -> void:
	settings_panel.visible = false
	pause_menu.visible = false
	get_tree().paused = false


func _return_to_main_menu() -> void:
	settings_panel.visible = false
	pause_menu.visible = false
	pending_game_over_stats.clear()
	pending_victory_stats.clear()
	game_over_cutscene.reset()
	game_clear_cutscene.reset()
	order_panel.set_gameplay_locked(false)
	get_tree().paused = false
	GameRun.abort()
	PanelManager.show_panel(PanelManager.PanelType.START)


func _quit_game() -> void:
	get_tree().quit()


func _can_pause_game() -> bool:
	return GameRun.running and PanelManager.current_panel == order_panel
