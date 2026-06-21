extends Control

signal back_pressed

const UI_FONT := preload("res://fonts/neodgm.ttf")

@onready var master_slider: HSlider = $Panel/Margin/Rows/MasterVolume/Slider
@onready var master_value_label: Label = $Panel/Margin/Rows/MasterVolume/Value
@onready var bgm_slider: HSlider = $Panel/Margin/Rows/BgmVolume/Slider
@onready var bgm_value_label: Label = $Panel/Margin/Rows/BgmVolume/Value
@onready var sfx_slider: HSlider = $Panel/Margin/Rows/SfxVolume/Slider
@onready var sfx_value_label: Label = $Panel/Margin/Rows/SfxVolume/Value
@onready var resolution_option: OptionButton = $Panel/Margin/Rows/Resolution/Option
@onready var back_button: Button = $Panel/Margin/Rows/BackButton

var _syncing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resolution_option.get_popup().add_theme_font_override("font", UI_FONT)
	_setup_resolution_options()
	master_slider.value_changed.connect(_on_master_volume_changed)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	back_button.pressed.connect(func(): back_pressed.emit())
	_sync_from_settings()


func on_show(_data: Dictionary = {}) -> void:
	_sync_from_settings()
	master_slider.grab_focus()


func _setup_resolution_options() -> void:
	resolution_option.clear()
	for i in range(GameSettings.RESOLUTIONS.size()):
		resolution_option.add_item(GameSettings.get_resolution_label(i), i)


func _sync_from_settings() -> void:
	_syncing = true
	master_slider.value = GameSettings.master_volume * 100.0
	bgm_slider.value = GameSettings.bgm_volume * 100.0
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	resolution_option.select(GameSettings.resolution_index)
	_update_volume_labels()
	_syncing = false


func _on_master_volume_changed(value: float) -> void:
	_update_volume_labels()
	if not _syncing:
		GameSettings.set_master_volume(value / 100.0)


func _on_bgm_volume_changed(value: float) -> void:
	_update_volume_labels()
	if not _syncing:
		GameSettings.set_bgm_volume(value / 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	_update_volume_labels()
	if not _syncing:
		GameSettings.set_sfx_volume(value / 100.0)


func _on_resolution_selected(index: int) -> void:
	if not _syncing:
		GameSettings.set_resolution_index(index)


func _update_volume_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value))
	bgm_value_label.text = "%d%%" % int(round(bgm_slider.value))
	sfx_value_label.text = "%d%%" % int(round(sfx_slider.value))
