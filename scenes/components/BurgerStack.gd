extends Node2D

const STACK_BASE_Y: int = 0

var current_height: int = 0
var stacked_ingredients: Array[Ingredient] = []

func add_ingredient(ing: Ingredient) -> void:
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
	tween.tween_property(sprite, "position:y", target_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.05)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.07)

	current_height += ing.stack_height
	stacked_ingredients.append(ing)

func clear_stack() -> void:
	for child in get_children():
		child.queue_free()
	current_height = 0
	stacked_ingredients.clear()
