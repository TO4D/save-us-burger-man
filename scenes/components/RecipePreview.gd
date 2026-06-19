extends Control
class_name RecipePreview

const INDICATOR_TEXTURE := preload("res://assets/sprites/ui/indicator.png")

@export var background_padding: Vector2 = Vector2(5.0, 5.0)
#@export var icon_size: Vector2 = Vector2(36.0, 18.0)
@export var icon_size: Vector2 = Vector2(70.0, 22.0)
@export var icon_overlap: float = 5.0
@export var indicator_size: Vector2 = Vector2(8.0, 8.0)
@export var indicator_gap: float = 0.0
@export var indicator_shake_offset: float = 3.0
@export var indicator_shake_step_duration: float = 0.04
@export var completed_ingredient_modulate: Color = Color(1, 1, 1, 0.5)
@export var complete_modulate_alpha: float = 0.8
@export var sliding_window_start_step: int = 4

@onready var background: NinePatchRect = $RecipeDisplayBackground
@onready var items_root: Control = $ItemsRoot

var recipe: Recipe = null
var ingredients_visible: bool = true
var active_step: int = -1
var visible_height: float = 0.0
var _indicator_root: Control = null
var _indicator_shake_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_recipe()


func set_recipe(value: Recipe) -> void:
	recipe = value
	active_step = -1
	_render_recipe()


func clear_recipe() -> void:
	recipe = null
	active_step = -1
	_render_recipe()


func set_active_step(value: int) -> void:
	active_step = value
	_render_recipe()


func set_visible_height(value: float) -> void:
	visible_height = value
	_render_recipe()


func set_ingredients_visible(value: bool) -> void:
	ingredients_visible = value
	if is_node_ready():
		items_root.visible = ingredients_visible


func play_indicator_shake() -> void:
	if _indicator_root == null or not is_instance_valid(_indicator_root):
		return

	if _indicator_shake_tween != null and _indicator_shake_tween.is_valid():
		_indicator_shake_tween.kill()

	var original_position := _indicator_root.position
	_indicator_shake_tween = create_tween()
	_indicator_shake_tween.tween_property(_indicator_root, "position:x", original_position.x - indicator_shake_offset, indicator_shake_step_duration)
	_indicator_shake_tween.tween_property(_indicator_root, "position:x", original_position.x + indicator_shake_offset, indicator_shake_step_duration * 2.0)
	_indicator_shake_tween.tween_property(_indicator_root, "position:x", original_position.x, indicator_shake_step_duration)


func _render_recipe() -> void:
	if not is_node_ready():
		return

	items_root.visible = ingredients_visible

	if _indicator_shake_tween != null and _indicator_shake_tween.is_valid():
		_indicator_shake_tween.kill()
	_indicator_shake_tween = null
	_indicator_root = null

	for child in items_root.get_children():
		child.queue_free()

	if recipe == null or recipe.ingredients.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		background.visible = false
		modulate.a = 1.0
		return

	var ingredient_count := recipe.ingredients.size()
	var step_y := maxf(icon_size.y - icon_overlap, 1.0)
	var content_size := Vector2(
		icon_size.x,
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
	modulate.a = complete_modulate_alpha if active_step >= ingredient_count else 1.0
	items_root.position = Vector2(background_padding.x, background_padding.y + _get_sliding_window_offset(total_size, step_y))
	items_root.size = content_size

	for i in range(ingredient_count):
		var ingredient: Ingredient = recipe.ingredients[i]
		var icon_position := Vector2(0.0, content_size.y - icon_size.y - step_y * float(i))
		var icon := TextureRect.new()
		icon.texture = ingredient.preview_icon_sprite if ingredient.preview_icon_sprite != null else ingredient.sprite
		icon.position = icon_position
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < active_step:
			icon.modulate = completed_ingredient_modulate
		items_root.add_child(icon)

		if i == active_step:
			_add_indicators(icon_position)


func _get_sliding_window_offset(total_size: Vector2, step_y: float) -> float:
	if visible_height <= 0.0:
		return 0.0

	var overflow := total_size.y - visible_height
	if overflow <= 0.0:
		return 0.0

	var start_step := maxi(sliding_window_start_step, 1)
	if active_step < start_step:
		return 0.0

	var steps_past_anchor := active_step - start_step + 1
	return minf(step_y * float(steps_past_anchor), overflow)


func _add_indicators(icon_position: Vector2) -> void:
	_indicator_root = Control.new()
	_indicator_root.position = icon_position
	_indicator_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_root.add_child(_indicator_root)

	var indicator_y := (icon_size.y - indicator_size.y) * 0.5
	var left_indicator := _create_indicator()
	left_indicator.position = Vector2(-indicator_size.x - indicator_gap, indicator_y)
	_indicator_root.add_child(left_indicator)

	var right_indicator := _create_indicator()
	right_indicator.flip_h = true
	right_indicator.position = Vector2(icon_size.x + indicator_gap, indicator_y)
	_indicator_root.add_child(right_indicator)


func _create_indicator() -> TextureRect:
	var indicator := TextureRect.new()
	indicator.texture = INDICATOR_TEXTURE
	indicator.custom_minimum_size = indicator_size
	indicator.size = indicator_size
	indicator.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return indicator
