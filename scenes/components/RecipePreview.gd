extends Control
class_name RecipePreview

@export var background_padding: Vector2 = Vector2(5.0, 5.0)
@export var icon_size: Vector2 = Vector2(36.0, 18.0)
@export var icon_overlap: float = 5.0

@onready var background: NinePatchRect = $RecipeDisplayBackground
@onready var items_root: Control = $ItemsRoot

var recipe: Recipe = null
var ingredients_visible: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_recipe()


func set_recipe(value: Recipe) -> void:
	recipe = value
	_render_recipe()


func clear_recipe() -> void:
	recipe = null
	_render_recipe()


func set_ingredients_visible(value: bool) -> void:
	ingredients_visible = value
	if is_node_ready():
		items_root.visible = ingredients_visible


func _render_recipe() -> void:
	if not is_node_ready():
		return

	items_root.visible = ingredients_visible

	for child in items_root.get_children():
		child.queue_free()

	if recipe == null or recipe.ingredients.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		background.visible = false
		return

	var ingredient_count := recipe.ingredients.size()
	var step_y := maxf(icon_size.y - icon_overlap, 1.0)
	var content_size := Vector2(
		icon_size.x + 34,
		icon_size.y + step_y * float(maxi(ingredient_count - 1, 0))
	)
	var total_size := Vector2(
		content_size.x + background_padding.x * 2.0,
		content_size.y + background_padding.y * 2.0
	)

	custom_minimum_size = total_size
	size = total_size
	background.visible = true
	background.position = Vector2.ZERO
	background.size = total_size
	items_root.position = Vector2(background_padding.x, background_padding.y)
	items_root.size = content_size

	for i in range(ingredient_count):
		var ingredient: Ingredient = recipe.ingredients[i]
		var icon := TextureRect.new()
		icon.texture = ingredient.preview_icon_sprite if ingredient.preview_icon_sprite != null else ingredient.icon_sprite if ingredient.icon_sprite != null else ingredient.sprite
		icon.position = Vector2(0.0, content_size.y - icon_size.y - step_y * float(i))
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items_root.add_child(icon)
