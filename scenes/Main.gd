extends Node2D

const READY_OVERLAY_SECONDS := 2.0
const GO_OVERLAY_SECONDS := 0.6

@export_group("Debug")
@export var skip_intro_cutscene: bool = false
@export var skip_start_overlay: bool = false

@onready var start_overlay: ColorRect = $PanelLayer/StartOverlay
@onready var start_overlay_label: Label = $PanelLayer/StartOverlay/Label


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
	start_overlay.visible = false


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
	PanelManager.show_panel(PanelManager.PanelType.ORDER, {"customer": customer})


func _on_order_completed(success: bool, recovery: float) -> void:
	GameRun.on_order_completed(success, recovery)


func _on_run_failed(stats: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.GAME_OVER, stats)


func _on_run_victory(stats: Dictionary) -> void:
	PanelManager.show_panel(PanelManager.PanelType.VICTORY, stats)


func _begin_run_after_intro() -> void:
	if not skip_start_overlay:
		await _run_start_overlay()
	start_run()


func _run_start_overlay() -> void:
	start_overlay.modulate.a = 1.0
	start_overlay_label.scale = Vector2.ONE
	start_overlay_label.text = "Ready"
	start_overlay.visible = true
	await get_tree().create_timer(READY_OVERLAY_SECONDS).timeout

	start_overlay_label.text = "Go"
	start_overlay_label.scale = Vector2(1.18, 1.18)
	var tween: Tween = create_tween()
	tween.tween_property(start_overlay_label, "scale", Vector2.ONE, GO_OVERLAY_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(GO_OVERLAY_SECONDS).timeout
	start_overlay.visible = false
