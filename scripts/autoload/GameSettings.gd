extends Node

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const MASTER_BUS := &"Master"
const BGM_BUS := &"BGM"
const SFX_BUS := &"SFX"
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_BGM_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_RESOLUTION_INDEX := 2
const BASE_VIEWPORT_SIZE := Vector2i(270, 480)
const RESOLUTIONS := [
	{"label": "270 x 480", "size": Vector2i(270, 480)},
	{"label": "405 x 720", "size": Vector2i(405, 720)},
	{"label": "540 x 960", "size": Vector2i(540, 960)},
	{"label": "608 x 1080", "size": Vector2i(608, 1080)},
	{"label": "2K (1440 x 2560)", "size": Vector2i(1440, 2560)},
	{"label": "4K (2160 x 3840)", "size": Vector2i(2160, 3840)},
]

var master_volume := DEFAULT_MASTER_VOLUME
var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var resolution_index := DEFAULT_RESOLUTION_INDEX
var tutorial_completed := false
var high_score := 0


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	apply_all()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	bgm_volume = clampf(float(config.get_value("audio", "bgm_volume", DEFAULT_BGM_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	resolution_index = clampi(int(config.get_value("video", "resolution_index", DEFAULT_RESOLUTION_INDEX)), 0, RESOLUTIONS.size() - 1)
	tutorial_completed = bool(config.get_value("progress", "tutorial_completed", false))
	high_score = maxi(int(config.get_value("progress", "high_score", 0)), 0)

	if is_web_build():
		resolution_index = DEFAULT_RESOLUTION_INDEX


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "resolution_index", resolution_index)
	config.set_value("progress", "tutorial_completed", tutorial_completed)
	config.set_value("progress", "high_score", high_score)
	config.save(CONFIG_PATH)


func apply_all() -> void:
	apply_audio()
	apply_resolution()
	settings_changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()
	settings_changed.emit()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()
	settings_changed.emit()


func set_resolution_index(value: int) -> void:
	if is_web_build():
		return

	resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
	apply_resolution()
	save_settings()
	settings_changed.emit()


func complete_tutorial() -> void:
	if tutorial_completed:
		return

	tutorial_completed = true
	save_settings()


func set_high_score(value: int) -> void:
	high_score = maxi(value, 0)
	save_settings()
	settings_changed.emit()


func apply_audio() -> void:
	_ensure_audio_buses()
	_set_bus_volume(MASTER_BUS, master_volume)
	_set_bus_volume(BGM_BUS, bgm_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func apply_resolution() -> void:
	var resolution: Dictionary = RESOLUTIONS[resolution_index] as Dictionary
	var window_size: Vector2i = resolution["size"] as Vector2i
	var root_window: Window = get_window()
	root_window.content_scale_size = BASE_VIEWPORT_SIZE

	if OS.has_feature("editor") or is_web_build():
		return

	root_window.size = window_size

	var screen_id := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_id)
	var centered_position := Vector2i(
		maxi(int((screen_size.x - window_size.x) * 0.5), 0),
		maxi(int((screen_size.y - window_size.y) * 0.5), 0)
	)
	DisplayServer.window_set_position(centered_position)


func get_resolution_label(index: int) -> String:
	var safe_index := clampi(index, 0, RESOLUTIONS.size() - 1)
	var resolution: Dictionary = RESOLUTIONS[safe_index] as Dictionary
	return resolution["label"] as String


func is_web_build() -> bool:
	return OS.has_feature("web") or OS.get_name() == "Web"


func _ensure_audio_buses() -> void:
	_ensure_bus(BGM_BUS)
	_ensure_bus(SFX_BUS)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, MASTER_BUS)


func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	AudioServer.set_bus_mute(bus_index, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
