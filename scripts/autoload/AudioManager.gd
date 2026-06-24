extends Node

enum Sfx {
	INGREDIENT_STACK,
	INGREDIENT_SLOT_FOCUS,
	INGREDIENT_SLOT_SELECT,
	WRONG_INGREDIENT,
	CUSTOMER_ENTER,
	BURGER_EAT,
	LIGHT_OFF,
	LIGHT_ON,
	LIGHT_SPARK,
	ORDER_SUCCESS,
	ORDER_SUCCESS_PERFECT,
	ATTACK,
	FIRE_BURGER,
	ULTIMATE_CHARGED,
	ULTIMATE,
	MONSTER_FOOTSTEP,
	SLOT_OFF,
	GAME_OVER,
	GAME_CLEAR_DRUM,
	COUNTDOWN,
	START,
	WARNING_GROWL,
}

enum Bgm {
	MAIN_MENU,
	CUTSCENE,
	INGAME,
}

const SFX_PATHS := {
	Sfx.INGREDIENT_STACK: "res://assets/audio/sfx/ingredient_stack2.ogg",
	Sfx.INGREDIENT_SLOT_FOCUS: "res://assets/audio/sfx/ingredient_slot_focus2.ogg",
	Sfx.INGREDIENT_SLOT_SELECT: "res://assets/audio/sfx/ingredient_slot_select2.ogg",
	Sfx.WRONG_INGREDIENT: "res://assets/audio/sfx/wrong_ingredient.wav",
	Sfx.CUSTOMER_ENTER: "res://assets/audio/sfx/customer_enter.wav",
	Sfx.BURGER_EAT: "res://assets/audio/sfx/burger_eat.wav",
	Sfx.LIGHT_OFF: "res://assets/audio/sfx/light_off.ogg",
	Sfx.LIGHT_ON: "res://assets/audio/sfx/light_on.ogg",
	Sfx.LIGHT_SPARK: "res://assets/audio/sfx/light_spark.ogg",
	Sfx.ORDER_SUCCESS: "res://assets/audio/sfx/order_success.ogg",
	Sfx.ORDER_SUCCESS_PERFECT: "res://assets/audio/sfx/order_success_perfect.ogg",
	Sfx.ATTACK: "res://assets/audio/sfx/attack.ogg",
	Sfx.FIRE_BURGER: "res://assets/audio/sfx/fire_burger.ogg",
	Sfx.ULTIMATE_CHARGED: "res://assets/audio/sfx/ultimate_charge2.ogg",
	Sfx.ULTIMATE: "res://assets/audio/sfx/ultimate.ogg",
	Sfx.MONSTER_FOOTSTEP: "res://assets/audio/sfx/monster_footstep.ogg",
	Sfx.SLOT_OFF: "res://assets/audio/sfx/slot_off.ogg",
	Sfx.GAME_OVER: "res://assets/audio/sfx/gameover.ogg",
	Sfx.GAME_CLEAR_DRUM: "res://assets/audio/sfx/game_clear_drum.ogg",
	Sfx.COUNTDOWN: "res://assets/audio/sfx/count.ogg",
	Sfx.START: "res://assets/audio/sfx/start.ogg",
	Sfx.WARNING_GROWL: "res://assets/audio/sfx/warning_growl.ogg",
}

const BGM_PATHS := {
	Bgm.MAIN_MENU: "res://assets/audio/bgm/The_Mountains_Loop.ogg",
	Bgm.CUTSCENE: "res://assets/audio/bgm/none.ogg",
	Bgm.INGAME: "res://assets/audio/bgm/8Bit_DNA_Loop.ogg",
}

const BGM_VOLUME_OFFSETS_DB := {
	Bgm.MAIN_MENU: -8.0,
	Bgm.CUTSCENE: -10.0,
	Bgm.INGAME: -15.0,
}

var sfx_bus: StringName = &"SFX"
var bgm_bus: StringName = &"BGM"
var _bgm_player: AudioStreamPlayer
var _current_bgm: int = -1
var _missing_audio_paths: Dictionary = {}


func _ready() -> void:
	_ensure_audio_bus(bgm_bus)
	_ensure_audio_bus(sfx_bus)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = bgm_bus
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)


func play_sfx(sfx: Sfx, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _load_stream(SFX_PATHS.get(sfx, ""))
	if stream == null:
		return

	_play_stream(stream, volume_db, pitch_scale, Node.PROCESS_MODE_INHERIT)


func play_sfx_while_paused(sfx: Sfx, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _load_stream(SFX_PATHS.get(sfx, ""))
	if stream == null:
		return

	_play_stream(stream, volume_db, pitch_scale, Node.PROCESS_MODE_WHEN_PAUSED)


func play_bgm(bgm: Bgm, volume_db: float = 0.0) -> void:
	if _current_bgm == bgm and _bgm_player.playing:
		return

	var path: String = BGM_PATHS.get(bgm, "")
	var stream := _load_stream(path)
	if stream == null:
		stop_bgm()
		return

	_enable_loop(stream)
	_current_bgm = bgm
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = volume_db + BGM_VOLUME_OFFSETS_DB.get(bgm, 0.0)
	_bgm_player.play()


func stop_bgm() -> void:
	_current_bgm = -1
	_bgm_player.stop()


func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null

	var stream := load(path) as AudioStream
	if stream == null and not _missing_audio_paths.has(path):
		_missing_audio_paths[path] = true
		push_warning("[AudioManager] Audio file not found or invalid: %s" % path)
	return stream


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


func _play_stream(stream: AudioStream, volume_db: float, pitch_scale: float, process_mode_value: ProcessMode) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SfxPlayer"
	player.stream = stream
	player.bus = sfx_bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.process_mode = process_mode_value
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")
