extends Control
class_name DistanceGauge

signal customer_attack_hit

@export var attacker_texture: Texture2D

@onready var bar: ProgressBar = $Bar
@onready var monster_icon: Sprite2D = $MonsterIcon
@onready var current_customer_icon: Sprite2D = $CurrentCustomerIcon
@onready var queue_icon_a: Sprite2D = $QueueIconA
@onready var queue_icon_b: Sprite2D = $QueueIconB
@onready var time_label: Label = $TimeLabel
@onready var stage_label: Label = $StageLabel

var current_customer_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	current_customer_home = current_customer_icon.position
	DistanceManager.distance_changed.connect(_on_distance_changed)
	GameRun.time_changed.connect(_on_time_changed)
	GameRun.stage_changed.connect(_on_stage_changed)
	_on_distance_changed(DistanceManager.distance, DistanceManager.MAX_DISTANCE)


func show_customer_queue() -> void:
	queue_icon_a.visible = true
	queue_icon_b.visible = true
	current_customer_icon.visible = true
	current_customer_icon.position = current_customer_home
	current_customer_icon.modulate = Color.WHITE
	current_customer_icon.scale = Vector2.ONE


func play_customer_attack() -> void:
	var attacker: Sprite2D = current_customer_icon.duplicate() as Sprite2D
	if attacker == null:
		push_error("[DistanceGauge] CurrentCustomerIcon must be a Sprite2D.")
		return
		
	if attacker_texture != null:
		attacker.texture = attacker_texture

	add_child(attacker)
	attacker.global_position = current_customer_icon.global_position
	attacker.visible = true
	current_customer_icon.visible = false

	var target_position: Vector2 = monster_icon.global_position + Vector2(6.0, 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(attacker, "global_position", target_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "scale", Vector2(1.5, 1.5), 0.18)
	await tween.finished
	customer_attack_hit.emit()

	var hit_tween: Tween = create_tween().set_parallel(true)
	hit_tween.tween_property(monster_icon, "scale", Vector2(1.25, 0.75), 0.08)
	await hit_tween.finished
	monster_icon.scale = Vector2.ONE

	await _bounce_attacker_away(attacker)
	attacker.queue_free()

	show_customer_queue()


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


func _on_distance_changed(value: float, max_value: float) -> void:
	var ratio: float = value / max_value if max_value > 0.0 else 0.0
	bar.value = ratio * 100.0
	bar.modulate = Color(1.0, 0.25, 0.2) if ratio <= 0.3 else Color.WHITE
	monster_icon.position.x = lerpf(42.0, 210.0, ratio)


func _on_time_changed(remaining: float) -> void:
	time_label.text = "%02d" % int(ceil(remaining))


func _on_stage_changed(stage: int) -> void:
	stage_label.text = "STAGE %d" % stage
