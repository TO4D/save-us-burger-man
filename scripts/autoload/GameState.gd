extends Node

const INGREDIENT_RESOURCE_PATHS: Array[String] = [
	"res://resources/ingredients/bun_top.tres",
	"res://resources/ingredients/bun_bottom.tres",
	"res://resources/ingredients/patty.tres",
	"res://resources/ingredients/lettuce.tres",
	"res://resources/ingredients/cheese.tres",
	#"res://resources/ingredients/bacon.tres",
	#"res://resources/ingredients/hashbrown.tres",
	#"res://resources/ingredients/mushroom.tres",
	"res://resources/ingredients/onion.tres",
	#"res://resources/ingredients/pickle.tres",
	#"res://resources/ingredients/shrimp.tres",
	"res://resources/ingredients/tomato.tres",
]

const STAGE_INGREDIENT_COUNTS := {
	1: 4,
	2: 7,
	3: 7,
	4: 7,
	5: 7,
	#3: 8,
	#4: 12,
	#5: 15,
}

const PLACEHOLDER_INGREDIENTS := [
	{"id": "egg", "name": "Egg", "color": Color(1.0, 0.94, 0.72), "height": 14},
	{"id": "avocado", "name": "Avocado", "color": Color(0.45, 0.78, 0.24), "height": 12},
	{"id": "jalapeno", "name": "Jalapeno", "color": Color(0.08, 0.48, 0.16), "height": 10},
]

var _ingredient_cache: Array[Ingredient] = []


func get_stage_ingredients(stage: int) -> Array[Ingredient]:
	_ensure_ingredient_cache()
	var stage_key: int = clampi(stage, 1, 5)
	var count: int = STAGE_INGREDIENT_COUNTS.get(stage_key, 4) as int
	var result: Array[Ingredient] = []
	var visible_count: int = mini(count, _ingredient_cache.size())
	for i in range(visible_count):
		result.append(_ingredient_cache[i])
	return result


func get_slot_ingredients(stage: int = 1) -> Array[Ingredient]:
	return get_stage_ingredients(stage)


func _ensure_ingredient_cache() -> void:
	if not _ingredient_cache.is_empty():
		return

	for path in INGREDIENT_RESOURCE_PATHS:
		var ing := load(path) as Ingredient
		if ing != null:
			_ingredient_cache.append(ing)

	for data in PLACEHOLDER_INGREDIENTS:
		_ingredient_cache.append(_create_placeholder_ingredient(data))


func _create_placeholder_ingredient(data: Dictionary) -> Ingredient:
	var ing := Ingredient.new()
	ing.id = data["id"] as String
	ing.display_name = data["name"] as String
	ing.stack_height = data["height"] as int
	ing.sprite = _create_color_texture(data["color"] as Color)
	ing.icon_sprite = ing.sprite
	ing.preview_icon_sprite = ing.icon_sprite
	return ing


func _create_color_texture(color: Color) -> Texture2D:
	var image := Image.create(48, 18, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
