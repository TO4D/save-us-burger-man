extends Node

enum Sfx {
	INGREDIENT_STACK,
	INGREDIENT_SLOT_FOCUS,
	INGREDIENT_SLOT_SELECT,
	WRONG_INGREDIENT,
	CUSTOMER_ENTER,
	BURGER_EAT,
}

enum Bgm {
	MAIN_MENU,
	CUTSCENE,
	INGAME,
}

const SFX_PATHS := {
	Sfx.INGREDIENT_STACK: "res://assets/audio/sfx/ingredient_stack.ogg",
	Sfx.INGREDIENT_SLOT_FOCUS: "res://assets/audio/sfx/ingredient_slot_focus.ogg",
	Sfx.INGREDIENT_SLOT_SELECT: "res://assets/audio/sfx/ingredient_slot_select.wav",
	Sfx.WRONG_INGREDIENT: "res://assets/audio/sfx/wrong_ingredient.wav",
	Sfx.CUSTOMER_ENTER: "res://assets/audio/sfx/customer_enter.wav",
	Sfx.BURGER_EAT: "res://assets/audio/sfx/burger_eat.wav",
}

const BGM_PATHS := {
	Bgm.MAIN_MENU: "res://assets/audio/bgm/main_menu.ogg",
	Bgm.CUTSCENE: "res://assets/audio/bgm/cutscene.ogg",
	Bgm.INGAME: "res://assets/audio/bgm/ingame.ogg",
}

var sfx_bus: StringName = &"Master"
var bgm_bus: StringName = &"Master"
var _bgm_player: AudioStreamPlayer
var _current_bgm: int = -1
var _missing_audio_paths: Dictionary = {}


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = bgm_bus
	add_child(_bgm_player)


func play_sfx(sfx: Sfx, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _load_stream(SFX_PATHS.get(sfx, ""))
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "SfxPlayer"
	player.stream = stream
	player.bus = sfx_bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_bgm(bgm: Bgm, volume_db: float = 0.0) -> void:
	if _current_bgm == bgm and _bgm_player.playing:
		return

	var stream := _load_stream(BGM_PATHS.get(bgm, ""))
	if stream == null:
		return

	_current_bgm = bgm
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = volume_db
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
