extends Node

signal panel_changed(new_panel_name: String)

enum PanelType { START, ORDER, GAME_OVER, VICTORY }

var panels: Dictionary = {}
var current_panel: Control = null

func register_panels(panel_layer: CanvasLayer) -> void:
	panels[PanelType.START] = panel_layer.get_node("StartPanel")
	panels[PanelType.ORDER] = panel_layer.get_node("OrderPanel")
	panels[PanelType.GAME_OVER] = panel_layer.get_node("GameOverPanel")
	panels[PanelType.VICTORY] = panel_layer.get_node("VictoryPanel")
	
	for p in panels.values():
		p.visible = false
	show_panel(PanelType.START)
	

func show_panel(panel: PanelType, data: Dictionary = {}) -> void:
	if current_panel:
		current_panel.visible = false
		if current_panel.has_method("on_hide"):
			current_panel.on_hide()
	current_panel = panels[panel]
	current_panel.visible = true
	if current_panel.has_method("on_show"):
		current_panel.on_show(data)
	panel_changed.emit(PanelType.keys()[panel])
	print("[PanelManager] 패널 전환: ", PanelType.keys()[panel])
