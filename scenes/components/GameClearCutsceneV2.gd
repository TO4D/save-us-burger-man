extends Control

signal finished

const READY_ANIMATION := &"ready"
const VOMIT_ANIMATION := &"default"

@export var slide_duration := 0.45
@export var sequence_gap := 1.0
@export var shake_duration := 1.5
@export var shake_interval := 0.04
@export var shake_strength := 3.0
@export var ready_shake_duration := 1.5
@export var vomit_move_duration := 0.8
@export var success_particle_scene: PackedScene
@export var success_particle_side_padding := 4.0
@export var success_particle_start_y_ratio := 0.1
@export var success_particle_target_y := 16.0
@export var success_particle_cleanup_seconds := 2.0
@export var stomach_texture_1: Texture2D
@export var stomach_texture_2: Texture2D
@export var mouth_texture_1: Texture2D
@export var mouth_texture_2: Texture2D

@onready var background: ColorRect = $Background
@onready var stomach: TextureRect = $Stomach
@onready var mouth: TextureRect = $Mouth
@onready var vomit_animation: AnimatedSprite2D = $VomitAnimation

var _sequence_token := 0
var _active_tween: Tween
var _vomit_target_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vomit_target_position = vomit_animation.position
	vomit_animation.sprite_frames.set_animation_loop(VOMIT_ANIMATION, true)
	vomit_animation.sprite_frames.set_animation_loop(READY_ANIMATION, false)
	_reset_visuals()
	hide()


func play_cutscene() -> void:
	_sequence_token += 1
	var token := _sequence_token
	_reset_visuals()
	show()
	_play_sequence(token)


func reset() -> void:
	_sequence_token += 1
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_reset_visuals()
	hide()


func _play_sequence(token: int) -> void:
	await _slide_in(stomach, Vector2(-stomach.size.x, 0.0), Vector2.ZERO)
	if token != _sequence_token:
		return
	await get_tree().create_timer(sequence_gap).timeout
	if token != _sequence_token:
		return

	var mouth_target := Vector2(0.0, size.y - mouth.size.y)
	await _slide_in(mouth, Vector2(size.x, mouth_target.y), mouth_target)
	if token != _sequence_token:
		return
	await get_tree().create_timer(sequence_gap).timeout
	if token != _sequence_token:
		return

	stomach.texture = stomach_texture_2
	mouth.texture = mouth_texture_2
	await _shake_images(token)
	if token != _sequence_token:
		return
	await _play_vomit_intro(token)


func _slide_in(target: Control, start_position: Vector2, end_position: Vector2) -> void:
	target.position = start_position
	target.show()
	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(target, "position", end_position, slide_duration)
	await _active_tween.finished


func _shake_images(token: int) -> void:
	var stomach_origin := stomach.position
	var mouth_origin := mouth.position
	var elapsed := 0.0
	while token == _sequence_token and elapsed < shake_duration:
		stomach.position = stomach_origin + _random_shake_offset()
		mouth.position = mouth_origin + _random_shake_offset()
		await get_tree().create_timer(shake_interval).timeout
		elapsed += shake_interval
	stomach.position = stomach_origin
	mouth.position = mouth_origin


func _play_vomit_intro(token: int) -> void:
	background.color = Color.BLACK
	stomach.hide()
	mouth.hide()
	vomit_animation.stop()
	vomit_animation.animation = READY_ANIMATION
	vomit_animation.frame = 0
	vomit_animation.position = size * 0.5
	vomit_animation.show()

	var center_position := vomit_animation.position
	var elapsed := 0.0
	while token == _sequence_token and elapsed < ready_shake_duration:
		vomit_animation.position = center_position + _random_shake_offset()
		await get_tree().create_timer(shake_interval).timeout
		elapsed += shake_interval
	if token != _sequence_token:
		return

	vomit_animation.position = center_position
	vomit_animation.play(VOMIT_ANIMATION)
	_play_success_particles()
	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(vomit_animation, "position", _vomit_target_position, vomit_move_duration)
	finished.emit()

func _play_success_particles() -> void:
	if success_particle_scene == null:
		return
	var target_position := Vector2(size.x * 0.5, success_particle_target_y)
	var start_y := size.y * success_particle_start_y_ratio
	_spawn_success_particle(Vector2(-success_particle_side_padding, start_y), target_position)
	_spawn_success_particle(Vector2(size.x + success_particle_side_padding, start_y), target_position)


func _spawn_success_particle(start_position: Vector2, target_position: Vector2) -> void:
	var particles_root := success_particle_scene.instantiate() as Node2D
	if particles_root == null:
		return
	add_child(particles_root)
	particles_root.z_index = 3
	particles_root.position = start_position
	var travel_direction := target_position - start_position
	particles_root.rotation = travel_direction.angle() + PI * 0.5
	_restart_particles_once(particles_root)
	_cleanup_particles_after_delay(particles_root)


func _restart_particles_once(root: Node) -> void:
	for child in root.get_children():
		if child is GPUParticles2D:
			var particles := child as GPUParticles2D
			particles.one_shot = true
			particles.restart()
			particles.emitting = true
		_restart_particles_once(child)


func _cleanup_particles_after_delay(particles_root: Node) -> void:
	await get_tree().create_timer(success_particle_cleanup_seconds).timeout
	if is_instance_valid(particles_root):
		particles_root.queue_free()

func _random_shake_offset() -> Vector2:
	return Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)


func _reset_visuals() -> void:
	if not is_node_ready():
		return
	background.color = Color(0.0, 0.0, 0.0, 0.65)
	stomach.texture = stomach_texture_1
	mouth.texture = mouth_texture_1
	_fit_width(stomach, stomach_texture_1)
	_fit_width(mouth, mouth_texture_1)
	stomach.position = Vector2(-stomach.size.x, 0.0)
	mouth.position = Vector2(size.x, size.y - mouth.size.y)
	stomach.hide()
	mouth.hide()
	vomit_animation.stop()
	vomit_animation.animation = READY_ANIMATION
	vomit_animation.frame = 0
	vomit_animation.position = _vomit_target_position
	vomit_animation.hide()


func _fit_width(target: TextureRect, texture: Texture2D) -> void:
	if texture == null or texture.get_width() <= 0:
		return
	target.size = Vector2(
		size.x,
		size.x * float(texture.get_height()) / float(texture.get_width())
	)
