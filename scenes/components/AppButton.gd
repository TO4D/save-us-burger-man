extends Button

const FOCUS_SOUND_DEBOUNCE_MSEC := 50

var _last_focus_sound_at := -FOCUS_SOUND_DEBOUNCE_MSEC


func _ready() -> void:
	mouse_entered.connect(_on_cursor_entered)
	focus_entered.connect(_on_cursor_entered)
	pressed.connect(_on_pressed)


func _on_cursor_entered() -> void:
	if disabled:
		return

	var now := Time.get_ticks_msec()
	if now - _last_focus_sound_at < FOCUS_SOUND_DEBOUNCE_MSEC:
		return

	_last_focus_sound_at = now
	_play_sfx(AudioManager.Sfx.INGREDIENT_SLOT_FOCUS)


func _on_pressed() -> void:
	if disabled:
		return
	_play_sfx(AudioManager.Sfx.INGREDIENT_SLOT_SELECT)


func _play_sfx(sfx: AudioManager.Sfx) -> void:
	if get_tree().paused:
		AudioManager.play_sfx_while_paused(sfx)
	else:
		AudioManager.play_sfx(sfx)
