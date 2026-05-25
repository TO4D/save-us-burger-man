extends Node2D

@export_group("Debug")
@export var skip_intro_cutscene: bool = false
@export var skip_start_overlay: bool = false

var show_ready_go_on_next_order := false


func _ready() -> void:
	PanelManager.register_panels($PanelLayer)
	$PanelLayer/StartPanel.start_pressed.connect(_on_start_pressed)
	$PanelLayer/CutscenePanel.cutscene_finished.connect(_on_cutscene_finished)
	$PanelLayer/OrderPanel.order_completed.connect(_on_order_completed)
	$PanelLayer/GameOverPanel.restart_pressed.connect(start_run)
	$PanelLayer/VictoryPanel.restart_pressed.connect(start_run)
	GameRun.customer_ready.connect(_on_customer_ready)
	GameRun.run_failed.connect(_on_run_failed)
	GameRun.run_victory.connect(_on_run_victory)


func start_run() -> void:
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
	PanelManager.show_panel(PanelManager.PanelType.GAME_OVER, stats)


func _on_run_victory(stats: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.VICTORY, stats)


func _begin_run_after_intro() -> void:
	show_ready_go_on_next_order = not skip_start_overlay
	start_run()
