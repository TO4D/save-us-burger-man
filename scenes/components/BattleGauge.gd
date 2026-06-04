extends Control
class_name BattleGauge

signal burger_attack_hit

const BURGER_ATTACK_TEXTURE := preload("res://assets/sprites/ui/order_icon.1.png")
const DEFAULT_EATING_PARTICLE_SCENE := preload("res://resources/particles/Eating.tscn")

@export var distance_display_scale: float = 10.0
@export var monster_icon_update_interval: float = 0.5
@export var monster_eating_min_speed_scale: float = 1.0
@export var monster_eating_max_speed_scale: float = 2.0

@export_group("Monster Sprites")
@export var monster_idle_texture: Texture2D
@export var monster_eating_frames: SpriteFrames
@export var monster_eaten_texture: Texture2D
@export var monster_eating_animation_name: StringName = &"default"
@export var monster_knockback_pixel_scale: float = 1.0

@export_group("Monster Eating Particles")
@export var monster_eating_particle_scene: PackedScene = DEFAULT_EATING_PARTICLE_SCENE
@export var monster_eating_particle_offset: Vector2 = Vector2(0.0, -40.0)
@export var monster_eating_particle_cleanup_seconds: float = 2.4

@onready var shop_icon: Sprite2D = $ShopIcon
@onready var monster_icon: Node2D = $MonsterIcon
@onready var monster_eating_sprite: AnimatedSprite2D = $MonsterIcon/EatingSprite
@onready var monster_state_sprite: Sprite2D = $MonsterIcon/StateSprite
#@onready var time_label: Label = $TimeLabel
@onready var stage_label: Label = $StageLabel
@onready var freeze_overlay: ColorRect = $FreezeOverlay

var monster_start_position: Vector2 = Vector2.ZERO
var monster_target_position: Vector2 = Vector2.ZERO
var pending_monster_icon_position: Vector2 = Vector2.ZERO
var monster_icon_update_elapsed: float = 0.0
var monster_knockback_active: bool = false


func _ready() -> void:
	DistanceManager.distance_changed.connect(_on_distance_changed)
	DistanceManager.freeze_changed.connect(_on_freeze_changed)
	#GameRun.time_changed.connect(_on_time_changed)
	GameRun.stage_changed.connect(_on_stage_changed)
	$Bar.visible = false
	monster_start_position = monster_icon.position
	monster_target_position = shop_icon.position
	pending_monster_icon_position = monster_start_position
	_on_distance_changed(DistanceManager.distance, DistanceManager.MAX_DISTANCE)
	_apply_monster_icon_position()
	_set_monster_idle()
	_on_freeze_changed(false, 0.0)


func _process(delta: float) -> void:
	if monster_knockback_active:
		return

	monster_icon_update_elapsed += delta
	if monster_icon_update_elapsed < monster_icon_update_interval:
		return

	monster_icon_update_elapsed = 0.0
	_apply_monster_icon_position()


func play_burger_attack(knockback_amount: float = 0.0) -> void:
	var projectile := _create_burger_projectile()
	add_child(projectile)
	AudioManager.play_sfx(AudioManager.Sfx.FIRE_BURGER)

	var target_position := Vector2(monster_icon.global_position.x + 6.0, monster_icon.global_position.y - 110.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(projectile, "global_position", target_position, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "scale", Vector2(1.1, 1.1), 0.34)
	tween.tween_property(projectile, "rotation", TAU * 1.35, 0.34)
	await tween.finished

	monster_knockback_active = true
	_play_monster_eating_animation()
	burger_attack_hit.emit()
	await _wait_for_monster_eating_animation()
	_set_monster_eaten()

	var hit_tween: Tween = create_tween().set_parallel(true)
	var knockback_target := pending_monster_icon_position
	if knockback_target.is_equal_approx(monster_icon.position):
		knockback_target = monster_icon.position + Vector2(0.0, -knockback_amount * monster_knockback_pixel_scale)
	hit_tween.tween_property(monster_icon, "position", knockback_target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_tween.tween_property(projectile, "modulate:a", 0.0, 0.08)
	await hit_tween.finished

	monster_icon.scale = Vector2.ONE
	projectile.queue_free()
	_set_monster_idle()
	monster_knockback_active = false


func play_ultimate_barrage(projectile_count: int = 6) -> void:
	for i in range(projectile_count):
		_spawn_ultimate_projectile(Vector2(34.0 + randf_range(-8.0, 8.0), 67.0 + randf_range(-4.0, 8.0)))
		await get_tree().create_timer(0.06).timeout


func _create_burger_projectile() -> Sprite2D:
	var icon := Sprite2D.new()
	icon.texture = BURGER_ATTACK_TEXTURE
	icon.position = shop_icon.position
	icon.modulate = Color.WHITE
	icon.scale = Vector2(0.8, 0.8)
	return icon


func _on_distance_changed(value: float, max_value: float) -> void:
	var ratio: float = value / max_value if max_value > 0.0 else 0.0
	pending_monster_icon_position = monster_start_position.lerp(monster_target_position, 1.0 - ratio)
	_update_monster_eating_speed()


func _apply_monster_icon_position() -> void:
	monster_icon.position = pending_monster_icon_position


func _set_monster_idle() -> void:
	monster_eating_sprite.stop()
	monster_eating_sprite.visible = false
	monster_state_sprite.texture = monster_idle_texture
	monster_state_sprite.visible = true


func _play_monster_eating_animation() -> void:
	monster_state_sprite.visible = false
	monster_eating_sprite.visible = true
	monster_eating_sprite.sprite_frames = _one_shot_eating_frames()
	_spawn_monster_eating_particles()
	if monster_eating_sprite.sprite_frames != null and monster_eating_sprite.sprite_frames.has_animation(monster_eating_animation_name):
		monster_eating_sprite.play(monster_eating_animation_name)


func _wait_for_monster_eating_animation() -> void:
	if monster_eating_sprite.sprite_frames == null:
		return
	if not monster_eating_sprite.sprite_frames.has_animation(monster_eating_animation_name):
		return
	await monster_eating_sprite.animation_finished


func _set_monster_eaten() -> void:
	monster_eating_sprite.stop()
	monster_eating_sprite.visible = false
	monster_state_sprite.texture = monster_eaten_texture
	monster_state_sprite.visible = true


func _one_shot_eating_frames() -> SpriteFrames:
	if monster_eating_frames == null:
		return null

	var frames := monster_eating_frames.duplicate() as SpriteFrames
	if frames.has_animation(monster_eating_animation_name):
		frames.set_animation_loop(monster_eating_animation_name, false)
	return frames


func _spawn_monster_eating_particles() -> void:
	if monster_eating_particle_scene == null:
		return

	var particles_root := monster_eating_particle_scene.instantiate() as Node2D
	if particles_root == null:
		return

	add_child(particles_root)
	particles_root.global_position = monster_icon.global_position + monster_eating_particle_offset
	_play_particles_once(particles_root)
	_cleanup_particles_after_delay(particles_root)


func _play_particles_once(root: Node) -> void:
	for child in root.get_children():
		if child is GPUParticles2D:
			var particles := child as GPUParticles2D
			particles.one_shot = true
			particles.restart()
			particles.emitting = true
		_play_particles_once(child)


func _cleanup_particles_after_delay(particles_root: Node) -> void:
	await get_tree().create_timer(monster_eating_particle_cleanup_seconds).timeout
	if is_instance_valid(particles_root):
		particles_root.queue_free()


func _update_monster_eating_speed() -> void:
	var speed_ratio := inverse_lerp(DistanceManager.MIN_DECAY_PER_SECOND, DistanceManager.MAX_DECAY_PER_SECOND, DistanceManager.decay_per_second)
	speed_ratio = clampf(speed_ratio, 0.0, 1.0)
	monster_eating_sprite.speed_scale = lerpf(monster_eating_min_speed_scale, monster_eating_max_speed_scale, speed_ratio)


#func _on_time_changed(elapsed: float) -> void:
	#time_label.text = "TIME %02d" % int(floor(elapsed))


func _on_stage_changed(stage: int) -> void:
	stage_label.text = "STAGE %d" % stage
	_update_monster_eating_speed()


func _on_freeze_changed(active: bool, remaining: float) -> void:
	freeze_overlay.visible = active
	freeze_overlay.modulate.a = 0.22 if active else 0.0
	if active:
		stage_label.text = "STUN %.1f" % remaining if remaining > 0.0 else "STUN"
	else:
		stage_label.text = "STAGE %d" % GameRun.current_stage


func _spawn_ultimate_projectile(origin: Vector2) -> void:
	var projectile := Sprite2D.new()
	projectile.texture = BURGER_ATTACK_TEXTURE
	projectile.position = origin
	projectile.scale = Vector2(0.4, 0.4)
	add_child(projectile)

	var target_position := monster_icon.position + Vector2(randf_range(-8.0, 8.0), randf_range(-12.0, 12.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(projectile, "position", target_position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "scale", Vector2(0.8, 0.8), 0.18)
	await tween.finished

	var hit_tween := create_tween().set_parallel(true)
	hit_tween.tween_property(monster_icon, "scale", Vector2(1.15, 0.86), 0.05)
	hit_tween.tween_property(projectile, "modulate:a", 0.0, 0.08)
	await hit_tween.finished
	monster_icon.scale = Vector2.ONE
	projectile.queue_free()
