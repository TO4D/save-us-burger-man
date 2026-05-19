extends Control
class_name RecipePreview

@export var background_padding: Vector2 = Vector2(5.0, 5.0)
@export var icon_size: Vector2 = Vector2(36.0, 18.0)
@export var icon_overlap: float = 5.0
@export var count_label_height: float = 14.0
@export var count_label_gap: float = 4.0

@onready var background: NinePatchRect = $RecipeDisplayBackground
@onready var items_root: Control = $ItemsRoot
@onready var count_label: Label = $CountLabel

var recipe: Recipe = null
var recipe_index: int = 0
var recipe_total: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_recipe()


func set_recipe(value: Recipe) -> void:
	recipe = value
	_render_recipe()


func clear_recipe() -> void:
	recipe = null
	recipe_index = 0
	recipe_total = 0
	_render_recipe()


func set_recipe_progress(index: int, total: int) -> void:
	recipe_index = index
	recipe_total = total
	_render_recipe()


func _render_recipe() -> void:
	if not is_node_ready():
		return

	var previous_size := size

	for child in items_root.get_children():
		child.queue_free()

	if recipe == null or recipe.ingredients.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		position.y += previous_size.y
		background.visible = false
		count_label.text = ""
		return

	var ingredient_count := recipe.ingredients.size()
	var step_y := maxf(icon_size.y - icon_overlap, 1.0)
	var content_size := Vector2(
		icon_size.x,
		icon_size.y + step_y * float(maxi(ingredient_count - 1, 0))
	)
	var total_size := Vector2(
		content_size.x + background_padding.x * 2.0,
		content_size.y + background_padding.y * 2.0 + count_label_gap + count_label_height
	)

	custom_minimum_size = total_size
	size = total_size
	position.y -= total_size.y - previous_size.y
	background.visible = true
	background.position = Vector2.ZERO
	background.size = total_size
	items_root.position = Vector2(background_padding.x, background_padding.y)
	items_root.size = content_size
	count_label.position = Vector2(background_padding.x, total_size.y - background_padding.y - count_label_height)
	count_label.size = Vector2(content_size.x, count_label_height)
	count_label.text = "( %d / %d )" % [recipe_index, recipe_total] if recipe_total > 0 else ""

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
