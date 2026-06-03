extends Control
class_name UltimateOverlay

signal playback_finished

const ULTIMATE_FRAMES := preload("res://resources/animations/ultimate.tres")
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const ANIMATION_NAME := &"default"

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var animation_sprite: AnimatedSprite2D = $AnimationSprite

var _was_tree_paused: bool = false
var _is_playing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	animation_sprite.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	dim_overlay.color = OVERLAY_COLOR
	_assign_animation_frames()
	_apply_animation_layout()
	visible = false
	resized.connect(_apply_animation_layout)


func play_once() -> void:
	if _is_playing:
		await playback_finished
		return

	_is_playing = true
	visible = true
	_assign_animation_frames()
	_apply_animation_layout()
	animation_sprite.stop()
	animation_sprite.frame = 0
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	animation_sprite.play(ANIMATION_NAME)
	await animation_sprite.animation_finished
	_finish_playback()


func cancel() -> void:
	if not _is_playing:
		visible = false
		return

	_finish_playback()


func _assign_animation_frames() -> void:
	var frames := ULTIMATE_FRAMES.duplicate() as SpriteFrames
	if frames != null and frames.has_animation(ANIMATION_NAME):
		frames.set_animation_loop(ANIMATION_NAME, false)
	animation_sprite.sprite_frames = frames


func _apply_animation_layout() -> void:
	if animation_sprite == null:
		return

	var frame_texture := _first_frame_texture()
	if frame_texture == null:
		return

	var frame_size := frame_texture.get_size()
	if frame_size.x <= 0.0:
		return

	var scale_ratio := size.x / frame_size.x
	animation_sprite.position = size * 0.5
	animation_sprite.scale = Vector2.ONE * scale_ratio


func _first_frame_texture() -> Texture2D:
	if animation_sprite.sprite_frames == null:
		return null
	if not animation_sprite.sprite_frames.has_animation(ANIMATION_NAME):
		return null
	if animation_sprite.sprite_frames.get_frame_count(ANIMATION_NAME) == 0:
		return null
	return animation_sprite.sprite_frames.get_frame_texture(ANIMATION_NAME, 0)


func _finish_playback() -> void:
	animation_sprite.stop()
	visible = false
	_is_playing = false
	get_tree().paused = _was_tree_paused
	playback_finished.emit()
