extends Node2D


func _ready() -> void:
	PanelManager.register_panels($PanelLayer)
	$PanelLayer/StartPanel.start_pressed.connect(start_run)
	$PanelLayer/OrderPanel.order_completed.connect(_on_order_completed)
	$PanelLayer/GameOverPanel.restart_pressed.connect(start_run)
	$PanelLayer/VictoryPanel.restart_pressed.connect(start_run)
	GameRun.customer_ready.connect(_on_customer_ready)
	GameRun.run_failed.connect(_on_run_failed)
	GameRun.run_victory.connect(_on_run_victory)


func start_run() -> void:
	GameRun.start()


func _on_customer_ready(customer: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.ORDER, {"customer": customer})


func _on_order_completed(success: bool, recovery: float) -> void:
	GameRun.on_order_completed(success, recovery)


func _on_run_failed(stats: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.GAME_OVER, stats)


func _on_run_victory(stats: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.VICTORY, stats)
