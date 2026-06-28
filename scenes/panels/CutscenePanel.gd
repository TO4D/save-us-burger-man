extends Control

signal cutscene_finished

const CUTSCENE_SIZE := Vector2(270.0, 270.0)
const SLIDE_DURATION := 0.45
const SHAKE_DELAY := 0.5
const SHAKE_DURATION := 1.0
const STOP_SCENE_SHAKE_DURATION := 0.3
const SHAKE_INTERVAL := 0.04
const SHAKE_STRENGTH := 4.0
const TWO_IMAGE_SCENE_SECOND_IMAGE_DELAY := 0.2

const OPENING_CUTSCENE_0 := preload("res://assets/sprites/cutscenes/opening_cutscene0.png")
const OPENING_CUTSCENE_1 := preload("res://assets/sprites/cutscenes/opening_cutscene1.png")
const OPENING_CUTSCENE_2 := preload("res://assets/sprites/cutscenes/opening_cutscene2.png")
const OPENING_CUTSCENE_2_1 := preload("res://assets/sprites/cutscenes/opening_cutscene2_1.png")
const OPENING_CUTSCENE_2_2 := preload("res://assets/sprites/cutscenes/opening_cutscene2_2.png")
const OPENING_CUTSCENE_3 := preload("res://assets/sprites/cutscenes/opening_cutscene3.png")
const OPENING_CUTSCENE_4 := preload("res://assets/sprites/cutscenes/opening_cutscene4.png")
const OPENING_CUTSCENE_5 := preload("res://assets/sprites/cutscenes/opening_cutscene5.png")
const OPENING_CUTSCENE_6 := preload("res://assets/sprites/cutscenes/opening_cutscene6.png")
const OPENING_CUTSCENE_7 := preload("res://assets/sprites/cutscenes/opening_cutscene7.png")
const VERSUS_IMAGE := preload("res://assets/sprites/ui/versus.png")
const SCENE_COUNT := 9

@onready var scene_image: TextureRect = $ImageRoot/SceneImage
@onready var overlay_image: TextureRect = $ImageRoot/OverlayImage
@onready var versus_image: TextureRect = $ImageRoot/VersusImage
@onready var next_button: Button = $Footer/NextButton

var _current_index := 0
var _sequence_token := 0
var _active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	next_button.pressed.connect(_on_next_pressed)


func on_show(_data: Dictionary = {}) -> void:
	_sequence_token += 1
	_current_index = 0
	_reset_visuals()
	_show_current_scene()
	next_button.grab_focus()


func on_hide() -> void:
	_sequence_token += 1
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()


func _show_current_scene() -> void:
	_sequence_token += 1
	var token := _sequence_token
	_reset_visuals()
	next_button.disabled = false

	match _current_index:
		0:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_0
			_play_first_scene_effect(token)
		1:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_1
		2:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_2
		3:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_2_1
		4:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_2_2
		5:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_3
			_play_stop_scene_effect(token)
		6:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_4
		7:
			next_button.text = "Next"
			scene_image.texture = OPENING_CUTSCENE_5
		8:
			next_button.text = "Start"
			_play_two_image_scene(OPENING_CUTSCENE_6, OPENING_CUTSCENE_7, token)


func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= SCENE_COUNT:
		cutscene_finished.emit()
		return

	_show_current_scene()


func _play_first_scene_effect(token: int) -> void:
	await get_tree().create_timer(SHAKE_DELAY).timeout
	if token != _sequence_token:
		return
	AudioManager.play_sfx(AudioManager.Sfx.WARNING_GROWL)
	await _shake_image(scene_image, token)


func _play_stop_scene_effect(token: int) -> void:
	AudioManager.play_sfx(AudioManager.Sfx.CUTSCENE_STOP)
	await _shake_image(scene_image, token, STOP_SCENE_SHAKE_DURATION)


func _play_two_image_scene(first_texture: Texture2D, second_texture: Texture2D, token: int) -> void:
	scene_image.texture = first_texture
	overlay_image.texture = second_texture
	scene_image.position = Vector2(-CUTSCENE_SIZE.x, _center_position().y)
	overlay_image.position = Vector2(size.x, _center_position().y)
	overlay_image.show()

	AudioManager.play_sfx(AudioManager.Sfx.ULTIMATE)
	await _slide_to(scene_image, _center_position())
	if token != _sequence_token:
		return

	await get_tree().create_timer(TWO_IMAGE_SCENE_SECOND_IMAGE_DELAY).timeout
	if token != _sequence_token:
		return

	overlay_image.position = Vector2(size.x, _center_position().y)
	AudioManager.play_sfx(AudioManager.Sfx.ULTIMATE)
	await _slide_to(overlay_image, _center_position())
	if token != _sequence_token:
		return

	_show_versus_image()
	_shake_images_forever(token)


func _slide_to(target: Control, end_position: Vector2) -> void:
	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(target, "position", end_position, SLIDE_DURATION)
	await _active_tween.finished


func _shake_image(target: Control, token: int, duration: float = SHAKE_DURATION) -> void:
	var origin := target.position
	var elapsed := 0.0
	while token == _sequence_token and elapsed < duration:
		target.position = origin + Vector2(
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH)
		)
		await get_tree().create_timer(SHAKE_INTERVAL).timeout
		elapsed += SHAKE_INTERVAL
	if token == _sequence_token:
		target.position = origin


func _shake_images_forever(token: int) -> void:
	var scene_origin := scene_image.position
	var overlay_origin := overlay_image.position
	while token == _sequence_token:
		scene_image.position = scene_origin + _random_shake_offset()
		overlay_image.position = overlay_origin + _random_shake_offset()
		await get_tree().create_timer(SHAKE_INTERVAL).timeout


func _random_shake_offset() -> Vector2:
	return Vector2(
		randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
		randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH)
	)


func _reset_visuals() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	scene_image.texture = null
	scene_image.size = CUTSCENE_SIZE
	scene_image.position = _center_position()
	scene_image.show()

	overlay_image.texture = null
	overlay_image.size = CUTSCENE_SIZE
	overlay_image.position = _center_position()
	overlay_image.hide()

	versus_image.texture = null
	versus_image.position = _center_position()
	versus_image.hide()


func _center_position() -> Vector2:
	return (size - CUTSCENE_SIZE) * 0.5


func _show_versus_image() -> void:
	versus_image.texture = VERSUS_IMAGE
	versus_image.size = VERSUS_IMAGE.get_size()
	versus_image.position = (size - versus_image.size) * 0.5
	versus_image.show()
