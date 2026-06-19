extends Node2D
class_name BurgerProjectile

@onready var burger_icon: Sprite2D = $BurgerIcon
@onready var core_fire: Sprite2D = $CoreFire
@onready var fire_trail: GPUParticles2D = $FireTrail

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
	core_fire.visible = perfect_effect_enabled
	fire_trail.visible = perfect_effect_enabled
	fire_trail.emitting = false

	if perfect_effect_enabled:
		fire_trail.restart()
		fire_trail.emitting = true
