extends Node2D
class_name BurgerProjectile

@onready var burger_icon: Sprite2D = $BurgerIcon
@onready var core_fire: Sprite2D = $CoreFire
@onready var fire_trail: GPUParticles2D = $FireTrail

const PERFECT_FIRE_COLOR := Color(0.9607843, 0.84705883, 0.3372549, 0.8)
const DEFAULT_FIRE_COLOR := Color(1.0, 1.0, 1.0, 0.8)

var perfect_effect_enabled: bool = false


func _ready() -> void:
	_apply_perfect_effect()


func configure(is_perfect: bool) -> void:
	perfect_effect_enabled = is_perfect
	if is_node_ready():
		_apply_perfect_effect()


func stop_trail() -> void:
	fire_trail.emitting = false


func _apply_perfect_effect() -> void:
	var fire_color := PERFECT_FIRE_COLOR if perfect_effect_enabled else DEFAULT_FIRE_COLOR
	core_fire.visible = true
	fire_trail.visible = true
	core_fire.modulate = fire_color
	fire_trail.modulate = fire_color
	fire_trail.emitting = false

	fire_trail.restart()
	fire_trail.emitting = true
