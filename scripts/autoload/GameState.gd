extends Node

const INGREDIENT_RESOURCE_PATHS: Array[String] = [
	"res://resources/ingredients/bun_top.tres",
	"res://resources/ingredients/bun_bottom.tres",
	"res://resources/ingredients/patty.tres",
	"res://resources/ingredients/lettuce.tres",
	"res://resources/ingredients/cheese.tres",
	"res://resources/ingredients/bacon.tres",
	"res://resources/ingredients/onion.tres",
	"res://resources/ingredients/tomato.tres",
]

const STAGE_INGREDIENT_COUNTS := {
	1: 4,
	2: 8,
	3: 8,
	4: 8,
	5: 8,
	6: 8,
	7: 8,
	8: 8,
	9: 8,
	10: 8,
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
	ing.slot_button_normal = _create_slot_button_texture(Color(0.38, 0.30, 0.18), data["color"] as Color)
	ing.slot_button_focused = _create_slot_button_texture(Color(0.48, 0.40, 0.26), data["color"] as Color)
	ing.slot_button_pressed = _create_slot_button_texture(Color(0.30, 0.24, 0.14), data["color"] as Color)
	ing.slot_button_hover = _create_slot_button_texture(Color(0.52, 0.42, 0.26), data["color"] as Color)
	return ing


func _create_color_texture(color: Color) -> Texture2D:
	var image := Image.create(48, 18, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _create_slot_button_texture(base_color: Color, ingredient_color: Color) -> Texture2D:
	var image := Image.create(50, 50, false, Image.FORMAT_RGBA8)
	image.fill(base_color)
	image.fill_rect(Rect2i(4, 4, 42, 42), base_color.lightened(0.1))
	image.fill_rect(Rect2i(11, 17, 28, 16), ingredient_color)
	return ImageTexture.create_from_image(image)
