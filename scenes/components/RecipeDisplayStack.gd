extends Control
class_name RecipeDisplayStack

const RECIPE_PREVIEW_SCENE := preload("res://scenes/components/RecipePreview.tscn")

@export var stack_offset: Vector2 = Vector2(0.0, -5.0)
@export var entry_offset: Vector2 = Vector2(0.0, 42.0)
@export var exit_offset: Vector2 = Vector2(140.0, 0.0)
@export var entry_duration: float = 0.22
@export var exit_duration: float = 0.18
@export var rearrange_duration: float = 0.18
@export var stagger_delay: float = 0.1
@export var background_alpha_falloff: float = 0.08
@export var progress_label_height: float = 12.0
@export var progress_label_gap: float = 2.0

var _ticket_views: Array[RecipePreview] = []
var _recipes: Array = []
var _current_recipe_index: int = 0
var _animation_token: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_recipes(recipe_list: Array) -> void:
	clear_recipes()
	_recipes = recipe_list.duplicate()
	_current_recipe_index = 0
	var token := _animation_token

	_show_current_recipe()

	_prepare_entry_layout()
	_play_entry_sequence(token)


func clear_recipes() -> void:
	_animation_token += 1
	for ticket in _ticket_views:
		if is_instance_valid(ticket):
			if ticket.get_parent() == self:
				remove_child(ticket)
			ticket.queue_free()
	_ticket_views.clear()
	_recipes.clear()
	_current_recipe_index = 0


func set_current_step(step: int) -> void:
	for index in range(_ticket_views.size()):
		var ticket := _ticket_views[index]
		if is_instance_valid(ticket):
			ticket.set_active_step(step if index == 0 else -1)


func play_current_indicator_shake() -> void:
	if _ticket_views.is_empty():
		return

	var ticket := _ticket_views[0]
	if is_instance_valid(ticket):
		ticket.play_indicator_shake()


func complete_current_recipe() -> void:
	if _ticket_views.is_empty():
		return

	_animation_token += 1
	var token := _animation_token
	var ticket := _ticket_views[0]
	_ticket_views.remove_at(0)

	if is_instance_valid(ticket):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ticket, "position", ticket.position + exit_offset, exit_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		#tween.tween_property(ticket, "modulate:a", 0.0, exit_duration)
		await tween.finished
		if is_instance_valid(ticket):
			if ticket.get_parent() == self:
				remove_child(ticket)
			ticket.queue_free()

	_current_recipe_index += 1
	if _current_recipe_index < _recipes.size():
		_show_current_recipe()
		_prepare_entry_layout()
		_play_entry_sequence(token)
		return

	_position_tickets(true)


func _show_current_recipe() -> void:
	if _current_recipe_index < 0 or _current_recipe_index >= _recipes.size():
		return

	var ticket := RECIPE_PREVIEW_SCENE.instantiate() as RecipePreview
	add_child(ticket)
	ticket.set_recipe(_recipes[_current_recipe_index])
	_ticket_views.append(ticket)


func _play_entry_sequence(token: int) -> void:
	for index in range(_ticket_views.size()):
		if token != _animation_token:
			return

		var ticket := _ticket_views[index]
		if not is_instance_valid(ticket):
			continue

		var target_position := _get_ticket_position(ticket, index)


		var tween := create_tween().set_parallel(true)
		tween.tween_property(ticket, "position", target_position, entry_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		#tween.tween_property(ticket, "modulate:a", _get_ticket_alpha(index), entry_duration)
		tween.finished.connect(_on_ticket_entry_finished.bind(ticket))

		if index < _ticket_views.size() - 1:
			await get_tree().create_timer(stagger_delay).timeout


func _position_tickets(animated: bool) -> void:
	for index in range(_ticket_views.size()):
		var ticket := _ticket_views[index]
		if not is_instance_valid(ticket):
			continue

		var target_position := _get_ticket_position(ticket, index)
		var target_alpha := _get_ticket_alpha(index)
		ticket.z_index = _get_ticket_z_index(index)

		if animated:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(ticket, "position", target_position, rearrange_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			#tween.tween_property(ticket, "modulate:a", target_alpha, rearrange_duration)
		else:
			ticket.position = target_position
			#ticket.modulate.a = target_alpha

	_reorder_ticket_children()

func _prepare_entry_layout() -> void:
	for index in range(_ticket_views.size()):
		var ticket := _ticket_views[index]
		if not is_instance_valid(ticket):
			continue

		var target_position := _get_ticket_position(ticket, index)
		ticket.z_index = _get_ticket_z_index(index)
		ticket.position = target_position + entry_offset
		ticket.set_ingredients_visible(index == 0)

	_reorder_ticket_children()


func _reorder_ticket_children() -> void:
	for reverse_index in range(_ticket_views.size() - 1, -1, -1):
		var ticket := _ticket_views[reverse_index]
		if is_instance_valid(ticket):
			move_child(ticket, get_child_count() - 1)

func _get_ticket_position(ticket: RecipePreview, index: int) -> Vector2:
	var ticket_size := ticket.size
	if ticket_size == Vector2.ZERO:
		ticket_size = ticket.custom_minimum_size

	return Vector2(
		size.x - ticket_size.x + stack_offset.x * index,
		size.y - ticket_size.y + stack_offset.y * index
	)


func _get_ticket_z_index(index: int) -> int:
	return _ticket_views.size() - index


func _get_ticket_alpha(index: int) -> float:
	return clampf(1.0 - background_alpha_falloff * index, 0.72, 1.0)


func _on_ticket_entry_finished(ticket: RecipePreview) -> void:
	if is_instance_valid(ticket):
		ticket.set_ingredients_visible(true)
