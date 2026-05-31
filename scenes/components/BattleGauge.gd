extends Control
class_name BattleGauge

signal customer_attack_hit

const CUSTOMER_ATTACK_START_POSITION := Vector2(52.0, 65.0)
const SINGLE_CUSTOMER_TEXTURE := preload("res://assets/sprites/customers/16soldier.png")
const MULTI_CUSTOMER_TEXTURE := preload("res://assets/sprites/customers/16knight.png")

@export var distance_display_scale: float = 10.0
@export var monster_icon_update_interval: float = 0.5
@export var monster_hit_flash_duration: float = 0.06
@export var monster_damage_preview_duration: float = 1.0
@export var monster_walk_min_speed_scale: float = 1.0
@export var monster_walk_max_speed_scale: float = 2.0

@onready var bar: ProgressBar = $Bar
@onready var damage_preview: ColorRect = $Bar/DamagePreview
@onready var monster_icon: Node2D = $MonsterIcon
@onready var monster_walk_sprite: AnimatedSprite2D = $MonsterIcon/WalkSprite
@onready var monster_hit_sprite: Sprite2D = $MonsterIcon/HitSprite
@onready var monster_hit_flash_sprite: Sprite2D = $MonsterIcon/HitFlashSprite
#@onready var time_label: Label = $TimeLabel
@onready var stage_label: Label = $StageLabel
@onready var freeze_overlay: ColorRect = $FreezeOverlay

var pending_monster_icon_x: float = 310.0
var monster_icon_update_elapsed: float = 0.0
var customer_texture: Texture2D = SINGLE_CUSTOMER_TEXTURE
var monster_knockback_active: bool = false
var monster_hit_flash_token: int = 0
var last_monster_health_ratio: float = -1.0
var damage_preview_tween: Tween = null


func _ready() -> void:
	DistanceManager.distance_changed.connect(_on_distance_changed)
	DistanceManager.freeze_changed.connect(_on_freeze_changed)
	MonsterManager.health_changed.connect(_on_monster_health_changed)
	#GameRun.time_changed.connect(_on_time_changed)
	GameRun.stage_changed.connect(_on_stage_changed)
	_on_distance_changed(DistanceManager.distance, DistanceManager.MAX_DISTANCE)
	_on_monster_health_changed(MonsterManager.health, MonsterManager.MAX_HEALTH)
	_apply_monster_icon_position()
	_play_monster_walk()
	_on_freeze_changed(false, 0.0)


func _process(delta: float) -> void:
	if monster_knockback_active:
		return

	monster_icon_update_elapsed += delta
	if monster_icon_update_elapsed < monster_icon_update_interval:
		return

	monster_icon_update_elapsed = 0.0
	_apply_monster_icon_position()


func show_customer_queue(is_multi_customer: bool = false) -> void:
	customer_texture = MULTI_CUSTOMER_TEXTURE if is_multi_customer else SINGLE_CUSTOMER_TEXTURE


func play_customer_attack(restore_queue_at_end: bool = true) -> void:
	var attacker := _create_customer_icon()
	add_child(attacker)

	var target_position := Vector2(monster_icon.global_position.x + 6.0, attacker.global_position.y)
	var tween: Tween = create_tween()
	tween.tween_property(attacker, "global_position", target_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	var monster_hit_start_x := monster_icon.position.x
	_show_monster_hit()
	customer_attack_hit.emit()

	_bounce_attacker_away_and_free(attacker)
	var hit_tween: Tween = create_tween().set_parallel(true)
	var monster_hit_end_x := monster_icon.position.x
	monster_icon.position.x = monster_hit_start_x
	hit_tween.tween_property(monster_icon, "position:x", monster_hit_end_x, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	#hit_tween.tween_property(monster_icon, "scale", Vector2(1.25, 0.75), 0.08)
	await hit_tween.finished
	monster_icon.scale = Vector2.ONE
	_play_monster_walk()

	if restore_queue_at_end:
		show_customer_queue()


func play_ultimate_barrage(projectile_count: int = 6) -> void:
	for i in range(projectile_count):
		_spawn_ultimate_projectile(Vector2(34.0 + randf_range(-8.0, 8.0), 67.0 + randf_range(-4.0, 8.0)))
		await get_tree().create_timer(0.06).timeout


func _bounce_attacker_away(attacker: Sprite2D) -> void:
	var elapsed: float = 0.0
	var duration: float = 0.75
	var velocity: Vector2 = Vector2(randf_range(-180.0, -90.0), randf_range(-210.0, -120.0))
	var gravity: float = 620.0
	var angular_velocity: float = randf_range(-14.0, 14.0)

	while elapsed < duration and is_instance_valid(attacker):
		var delta: float = get_process_delta_time()
		elapsed += delta
		velocity.y += gravity * delta
		attacker.global_position += velocity * delta
		attacker.rotation += angular_velocity * delta
		attacker.modulate.a = maxf(0.0, 1.0 - elapsed / duration)
		await get_tree().process_frame


func _bounce_attacker_away_and_free(attacker: Sprite2D) -> void:
	await _bounce_attacker_away(attacker)
	if is_instance_valid(attacker):
		attacker.queue_free()


func _create_customer_icon() -> Sprite2D:
	var icon := Sprite2D.new()
	icon.texture = customer_texture
	icon.position = CUSTOMER_ATTACK_START_POSITION
	icon.modulate = Color.WHITE
	icon.scale = Vector2.ONE
	return icon


func _on_distance_changed(value: float, max_value: float) -> void:
	var ratio: float = value / max_value if max_value > 0.0 else 0.0
	pending_monster_icon_x = lerpf(48.0, 250.0, ratio)
	_update_monster_walk_speed()


func _on_monster_health_changed(value: float, max_value: float) -> void:
	var ratio: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	var previous_ratio := _get_damage_preview_right_ratio()
	if last_monster_health_ratio >= 0.0:
		previous_ratio = maxf(previous_ratio, last_monster_health_ratio)

	bar.value = ratio * 100.0
	if last_monster_health_ratio >= 0.0 and ratio < previous_ratio:
		_play_damage_preview(ratio, previous_ratio)
	elif ratio >= previous_ratio:
		_hide_damage_preview()

	last_monster_health_ratio = ratio


func _apply_monster_icon_position() -> void:
	monster_icon.position.x = pending_monster_icon_x


func refresh_monster_icon_position_immediately() -> void:
	monster_icon_update_elapsed = 0.0
	_apply_monster_icon_position()


func _play_damage_preview(current_ratio: float, previous_ratio: float) -> void:
	var bar_width := bar.size.x
	if bar_width <= 0.0:
		await get_tree().process_frame
		bar_width = bar.size.x

	var start_x := bar_width * current_ratio
	var start_width := bar_width * maxf(previous_ratio - current_ratio, 0.0)
	if start_width <= 0.0:
		_hide_damage_preview()
		return

	if damage_preview_tween != null and damage_preview_tween.is_valid():
		damage_preview_tween.kill()

	damage_preview.visible = true
	damage_preview.position = Vector2(start_x, 0.0)
	damage_preview.size = Vector2(start_width, bar.size.y)
	damage_preview_tween = create_tween()
	damage_preview_tween.tween_property(damage_preview, "size:x", 0.0, monster_damage_preview_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	damage_preview_tween.tween_callback(_finish_damage_preview)


func _hide_damage_preview() -> void:
	if damage_preview_tween != null and damage_preview_tween.is_valid():
		damage_preview_tween.kill()
	damage_preview_tween = null
	_finish_damage_preview()


func _finish_damage_preview() -> void:
	damage_preview.visible = false
	damage_preview.size = Vector2(0.0, damage_preview.size.y)


func _get_damage_preview_right_ratio() -> float:
	if not damage_preview.visible or bar.size.x <= 0.0:
		return 0.0
	return clampf((damage_preview.position.x + damage_preview.size.x) / bar.size.x, 0.0, 1.0)


func _show_monster_hit() -> void:
	monster_knockback_active = true
	monster_walk_sprite.stop()
	monster_walk_sprite.visible = false
	monster_hit_sprite.visible = true
	_flash_monster_hit()


func _play_monster_walk() -> void:
	monster_knockback_active = false
	monster_hit_flash_token += 1
	monster_hit_flash_sprite.visible = false
	monster_hit_sprite.visible = false
	monster_walk_sprite.visible = true
	_update_monster_walk_speed()
	if monster_walk_sprite.sprite_frames != null and monster_walk_sprite.sprite_frames.has_animation("walk"):
		monster_walk_sprite.play("walk")


func _flash_monster_hit() -> void:
	monster_hit_flash_token += 1
	var flash_token := monster_hit_flash_token
	monster_hit_flash_sprite.visible = true
	await get_tree().create_timer(monster_hit_flash_duration).timeout
	if flash_token != monster_hit_flash_token:
		return
	monster_hit_flash_sprite.visible = false


func _update_monster_walk_speed() -> void:
	var speed_ratio := inverse_lerp(DistanceManager.MIN_DECAY_PER_SECOND, DistanceManager.MAX_DECAY_PER_SECOND, DistanceManager.decay_per_second)
	speed_ratio = clampf(speed_ratio, 0.0, 1.0)
	monster_walk_sprite.speed_scale = lerpf(monster_walk_min_speed_scale, monster_walk_max_speed_scale, speed_ratio)


#func _on_time_changed(elapsed: float) -> void:
	#time_label.text = "TIME %02d" % int(floor(elapsed))


func _on_stage_changed(stage: int) -> void:
	stage_label.text = "STAGE %d" % stage
	_update_monster_walk_speed()


func _on_freeze_changed(active: bool, remaining: float) -> void:
	freeze_overlay.visible = active
	freeze_overlay.modulate.a = 0.22 if active else 0.0
	if active:
		stage_label.text = "STUN %.1f" % remaining
	else:
		stage_label.text = "STAGE %d" % GameRun.current_stage


func _spawn_ultimate_projectile(origin: Vector2) -> void:
	var projectile := Sprite2D.new()
	projectile.texture = customer_texture
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
