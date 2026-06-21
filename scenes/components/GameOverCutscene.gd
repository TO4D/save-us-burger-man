extends Control

signal finished

const ANIMATION_NAME := &"default"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_sprite_to_screen)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.sprite_frames.set_animation_loop(ANIMATION_NAME, false)
	hide()


func play_cutscene() -> void:
	show()
	_fit_sprite_to_screen()
	animated_sprite.stop()
	animated_sprite.animation = ANIMATION_NAME
	animated_sprite.frame = 0
	animated_sprite.play()


func reset() -> void:
	animated_sprite.stop()
	animated_sprite.frame = 0
	hide()


func _fit_sprite_to_screen() -> void:
	if not is_node_ready():
		return

	var texture := animated_sprite.sprite_frames.get_frame_texture(ANIMATION_NAME, 0)
	if texture == null:
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	animated_sprite.position = size * 0.5
	animated_sprite.scale = Vector2(size.x / texture_size.x, size.y / texture_size.y)


func _on_animation_finished() -> void:
	animated_sprite.stop()
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(ANIMATION_NAME) - 1
	finished.emit()
