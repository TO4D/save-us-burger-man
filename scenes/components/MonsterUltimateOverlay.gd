extends Control
class_name MonsterUltimateOverlay

signal playback_finished

const FEET_FRAMES := preload("res://resources/animations/monster_ultimate_feet.tres")
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const ANIMATION_NAME := &"default"
const SLIDE_OFFSCREEN_PADDING := 24.0
const SHAKE_TRIGGER_FRAME := 3

@export var intro_display_seconds: float = 0.5
@export var intro_slide_seconds: float = 0.24
@export var feet_slide_seconds: float = 0.18
@export var feet_hold_seconds: float = 0.5
@export var screen_shake_seconds: float = 1.0
@export var screen_shake_strength: float = 3.0
@export var screen_shake_interval: float = 0.04

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var intro_sprite: Sprite2D = $IntroSprite
@onready var feet_sprite: AnimatedSprite2D = $FeetSprite

var _was_tree_paused: bool = false
var _is_playing: bool = false
var _intro_home_position: Vector2 = Vector2.ZERO
var _feet_home_position: Vector2 = Vector2.ZERO
var _screen_home_position: Vector2 = Vector2.ZERO
var _screen_root: Control = null
var _intro_tween: Tween = null
var _feet_tween: Tween = null
var _shake_token: int = 0
var _shake_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	intro_sprite.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	feet_sprite.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	dim_overlay.color = OVERLAY_COLOR
	_assign_animation_frames()
	_intro_home_position = intro_sprite.position
	_feet_home_position = feet_sprite.position
	_screen_root = get_parent() as Control
	if _screen_root != null:
		_screen_home_position = _screen_root.position
	feet_sprite.frame_changed.connect(_on_feet_frame_changed)
	visible = false


func play_once() -> void:
	if _is_playing:
		await playback_finished
		return

	_is_playing = true
	visible = true
	intro_sprite.visible = true
	feet_sprite.visible = false
	intro_sprite.position = _offscreen_left_position(intro_sprite, _intro_home_position)
	feet_sprite.position = _offscreen_right_position(feet_sprite, _feet_home_position)
	feet_sprite.stop()
	feet_sprite.frame = 0
	_shake_token += 1
	_shake_started = false
	if _screen_root != null:
		_screen_home_position = _screen_root.position
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	_slide_to_home(intro_sprite, _intro_home_position, intro_slide_seconds, true)

	await get_tree().create_timer(intro_display_seconds, true).timeout
	if not _is_playing:
		return

	feet_sprite.visible = true
	_slide_to_home(feet_sprite, _feet_home_position, feet_slide_seconds, false)
	feet_sprite.play(ANIMATION_NAME)
	await feet_sprite.animation_finished
	_show_last_feet_frame()
	await get_tree().create_timer(feet_hold_seconds, true).timeout
	if not _is_playing:
		return
	_finish_playback()


func cancel() -> void:
	if not _is_playing:
		visible = false
		return

	_finish_playback()


func _assign_animation_frames() -> void:
	var frames := FEET_FRAMES.duplicate() as SpriteFrames
	if frames != null and frames.has_animation(ANIMATION_NAME):
		frames.set_animation_loop(ANIMATION_NAME, false)
	feet_sprite.sprite_frames = frames


func _slide_to_home(sprite: Node2D, home_position: Vector2, duration: float, is_intro: bool) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(sprite, "position", home_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_intro:
		_intro_tween = tween
	else:
		_feet_tween = tween


func _offscreen_left_position(sprite: Node2D, home_position: Vector2) -> Vector2:
	return Vector2(-_sprite_half_width(sprite) - SLIDE_OFFSCREEN_PADDING, home_position.y)


func _offscreen_right_position(sprite: Node2D, home_position: Vector2) -> Vector2:
	return Vector2(size.x + _sprite_half_width(sprite) + SLIDE_OFFSCREEN_PADDING, home_position.y)


func _sprite_half_width(sprite: Node2D) -> float:
	var texture := _sprite_texture(sprite)
	if texture == null:
		return 0.0
	return texture.get_width() * absf(sprite.scale.x) * 0.5


func _sprite_texture(sprite: Node2D) -> Texture2D:
	if sprite is Sprite2D:
		return (sprite as Sprite2D).texture
	if sprite is AnimatedSprite2D:
		return _first_feet_frame_texture()
	return null


func _first_feet_frame_texture() -> Texture2D:
	if feet_sprite.sprite_frames == null:
		return null
	if not feet_sprite.sprite_frames.has_animation(ANIMATION_NAME):
		return null
	if feet_sprite.sprite_frames.get_frame_count(ANIMATION_NAME) == 0:
		return null
	return feet_sprite.sprite_frames.get_frame_texture(ANIMATION_NAME, 0)


func _show_last_feet_frame() -> void:
	if feet_sprite.sprite_frames == null:
		return
	if not feet_sprite.sprite_frames.has_animation(ANIMATION_NAME):
		return

	var frame_count := feet_sprite.sprite_frames.get_frame_count(ANIMATION_NAME)
	if frame_count <= 0:
		return

	feet_sprite.stop()
	feet_sprite.visible = true
	feet_sprite.animation = ANIMATION_NAME
	feet_sprite.frame = frame_count - 1


func _on_feet_frame_changed() -> void:
	if not _is_playing or _shake_started:
		return
	if feet_sprite.frame != SHAKE_TRIGGER_FRAME:
		return

	_shake_started = true
	_shake_token += 1
	_play_screen_shake(_shake_token)


func _play_screen_shake(token: int) -> void:
	if _screen_root == null:
		return

	AudioManager.play_sfx_while_paused(AudioManager.Sfx.MONSTER_FOOTSTEP)
	var elapsed := 0.0
	var interval := maxf(screen_shake_interval, 0.01)
	while _is_playing and token == _shake_token and elapsed < screen_shake_seconds:
		_screen_root.position = _screen_home_position + Vector2(
			randf_range(-screen_shake_strength, screen_shake_strength),
			randf_range(-screen_shake_strength, screen_shake_strength)
		)
		await get_tree().create_timer(interval, true).timeout
		elapsed += interval

	if token == _shake_token:
		_restore_screen_position()


func _restore_screen_position() -> void:
	if _screen_root != null:
		_screen_root.position = _screen_home_position


func _finish_playback() -> void:
	_shake_token += 1
	_restore_screen_position()
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _feet_tween != null and _feet_tween.is_valid():
		_feet_tween.kill()
	_intro_tween = null
	_feet_tween = null
	feet_sprite.stop()
	intro_sprite.position = _intro_home_position
	feet_sprite.position = _feet_home_position
	intro_sprite.visible = false
	feet_sprite.visible = false
	visible = false
	_is_playing = false
	get_tree().paused = _was_tree_paused
	playback_finished.emit()
