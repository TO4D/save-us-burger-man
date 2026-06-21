extends Node
class_name RecipeGenerator


static func generate_for_stage(stage: int) -> Recipe:
	var recipe := Recipe.new()
	var ingredients: Array[Ingredient] = []
	var pool := GameState.get_stage_ingredients(stage)

	var bottom := _find_ingredient(pool, "bun_bottom")
	if bottom != null:
		ingredients.append(bottom)

	var middle_pool: Array[Ingredient] = []
	for ing in pool:
		if ing.id != "bun_top" and ing.id != "bun_bottom":
			middle_pool.append(ing)

	var length := _get_middle_length(stage)
	for i in range(length):
		ingredients.append(middle_pool.pick_random())

	var top := _find_ingredient(pool, "bun_top")
	if top != null:
		ingredients.append(top)

	recipe.ingredients = ingredients
	return recipe


static func _get_middle_length(stage: int) -> int:
	match clamp(stage, 1, 10):
		1:
			return 3
		2:
			return randi_range(4, 7)
		3:
			return 3
		4:
			return randi_range(5, 10)
		5:
			return 4
		6:
			return randi_range(6, 14)
		7:
			return 5
		8:
			return randi_range(7, 16)
		9:
			return 6
		_:
			return randi_range(8, 20)


static func _find_ingredient(pool: Array[Ingredient], id: String) -> Ingredient:
	for ing in pool:
		if ing.id == id:
			return ing
	return null
