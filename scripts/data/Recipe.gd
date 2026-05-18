extends Resource
class_name Recipe

@export var ingredients: Array[Ingredient] = []

func get_total_height() -> int:
	var h = 0
	for ing in ingredients:
		h += ing.stack_height
	return h
