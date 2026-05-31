extends Node2D
class_name BurgerStack

signal ingredient_landed(stack_global_position: Vector2, token: int)

const STACK_BASE_Y: int = 0
const STACK_EFFECT_SCENE := preload("res://resources/vfx/StackEffect.tscn")
const STACk_EFFECT_OFFSET_Y: float = 30.0

var current_height: int = 0
var stacked_ingredients: Array[Ingredient] = []

func add_ingredient(ing: Ingredient, token: int = 0) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = ing.sprite
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var sprite_width = ing.sprite.get_width()
	var sprite_height = ing.sprite.get_height()
	sprite.offset = Vector2(-floori(sprite_width / 2.0), -sprite_height)

	var target_y = STACK_BASE_Y - current_height - ing.stack_height + ing.stack_offset_y

	sprite.position = Vector2(0, target_y - 40)
	add_child(sprite)

	var tween = create_tween()
	var stack_global_position: Vector2 = to_global(Vector2(0.0, target_y - STACk_EFFECT_OFFSET_Y))
	tween.tween_property(sprite, "position:y", target_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_emit_ingredient_landed.bind(stack_global_position, token))
	#tween.tween_callback(_spawn_stack_effect.bind(Vector2(0.0, target_y - STACk_EFFECT_OFFSET_Y)))
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.05)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.07)

	current_height += ing.stack_height
	stacked_ingredients.append(ing)

func _emit_ingredient_landed(stack_global_position: Vector2, token: int) -> void:
	AudioManager.play_sfx(AudioManager.Sfx.INGREDIENT_STACK)
	ingredient_landed.emit(stack_global_position, token)

func _spawn_stack_effect(local_position: Vector2) -> void:
	var stack_effect := STACK_EFFECT_SCENE.instantiate() as AnimatedSprite2D
	var effect_parent := get_parent()
	if effect_parent == null:
		effect_parent = self

	effect_parent.add_child(stack_effect)
	stack_effect.global_position = to_global(local_position)
	stack_effect.animation_finished.connect(stack_effect.queue_free, CONNECT_ONE_SHOT)
	stack_effect.play()

func clear_stack() -> void:
	for child in get_children():
		child.queue_free()
	current_height = 0
	stacked_ingredients.clear()
