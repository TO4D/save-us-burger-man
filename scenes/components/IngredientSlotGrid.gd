extends GridContainer
class_name IngredientSlotGrid

signal ingredient_picked(ingredient: Ingredient)

const MAX_INGREDIENT_SLOTS := 8
const SLOT_COLUMNS := 4

var ingredient_slot_nodes: Array[IngredientSlot] = []
var focused_slot_index: int = 0
var is_mobile_input: bool = false


func _ready() -> void:
	_initialize_slots()


func _input(event: InputEvent) -> void:
	if is_mobile_input or not visible:
		return
	if event.is_action_pressed("ingredient_move_left"):
		_move_slot_focus(Vector2i(-1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ingredient_move_right"):
		_move_slot_focus(Vector2i(1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ingredient_move_up"):
		_move_slot_focus(Vector2i(0, -1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ingredient_move_down"):
		_move_slot_focus(Vector2i(0, 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ingredient_select"):
		if _is_slot_index_visible(focused_slot_index):
			ingredient_slot_nodes[focused_slot_index].trigger_pick()
		get_viewport().set_input_as_handled()


func configure(ingredients: Array[Ingredient], mobile_input: bool, enabled: bool) -> void:
	is_mobile_input = mobile_input
	for index in range(ingredient_slot_nodes.size()):
		var slot := ingredient_slot_nodes[index]
		if index < ingredients.size():
			slot.setup(ingredients[index], false)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_mobile_input else Control.MOUSE_FILTER_IGNORE
		else:
			slot.clear_slot()

	set_interaction_enabled(enabled)
	focus_current_slot()


func clear_slots() -> void:
	for slot in ingredient_slot_nodes:
		slot.clear_slot()


func shuffle_visible_ingredients() -> void:
	var visible_slots: Array[IngredientSlot] = []
	var visible_ingredients: Array[Ingredient] = []
	var interaction_was_enabled := false
	for slot in ingredient_slot_nodes:
		if slot.visible and slot.ingredient != null:
			interaction_was_enabled = interaction_was_enabled or slot.interaction_enabled
			visible_slots.append(slot)
			visible_ingredients.append(slot.ingredient)

	if visible_ingredients.size() <= 1:
		return

	var original_ingredients := visible_ingredients.duplicate()
	visible_ingredients.shuffle()
	for _attempt in range(4):
		if visible_ingredients != original_ingredients:
			break
		visible_ingredients.shuffle()

	for index in range(visible_slots.size()):
		visible_slots[index].setup(visible_ingredients[index], false)
		visible_slots[index].mouse_filter = Control.MOUSE_FILTER_STOP if is_mobile_input else Control.MOUSE_FILTER_IGNORE

	set_interaction_enabled(interaction_was_enabled)
	focus_current_slot()


func get_visible_ingredients() -> Array[Ingredient]:
	var ingredients: Array[Ingredient] = []
	for slot in ingredient_slot_nodes:
		if slot.visible and slot.ingredient != null:
			ingredients.append(slot.ingredient)
	return ingredients


func set_interaction_enabled(enabled: bool) -> void:
	for slot in ingredient_slot_nodes:
		if slot.visible:
			slot.set_interaction_enabled(enabled)


func focus_current_slot() -> void:
	if is_mobile_input:
		return

	var available_slots := _get_visible_slot_indices()
	if available_slots.is_empty():
		return
	_sync_focused_slot_index_from_owner()
	if not _is_slot_index_visible(focused_slot_index):
		focused_slot_index = available_slots[0]
	ingredient_slot_nodes[focused_slot_index].grab_focus()


func _initialize_slots() -> void:
	columns = SLOT_COLUMNS
	var index := 0
	for child in get_children():
		var slot := child as IngredientSlot
		if slot == null:
			continue
		slot.ingredient_picked.connect(_on_slot_ingredient_picked)
		slot.focus_entered.connect(_on_slot_focus_entered.bind(index))
		slot.clear_slot()
		ingredient_slot_nodes.append(slot)
		index += 1

	if ingredient_slot_nodes.size() != MAX_INGREDIENT_SLOTS:
		push_warning("[IngredientSlotGrid] Expected %d ingredient slots, found %d." % [MAX_INGREDIENT_SLOTS, ingredient_slot_nodes.size()])


func _sync_focused_slot_index_from_owner() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return
	var owner_slot := focus_owner as IngredientSlot
	if owner_slot == null:
		return
	var index := ingredient_slot_nodes.find(owner_slot)
	if index >= 0:
		focused_slot_index = index


func _get_visible_slot_indices() -> Array[int]:
	var visible_indices: Array[int] = []
	for index in range(ingredient_slot_nodes.size()):
		if _is_slot_index_visible(index):
			visible_indices.append(index)
	return visible_indices


func _is_slot_index_visible(index: int) -> bool:
	return index >= 0 and index < ingredient_slot_nodes.size() and ingredient_slot_nodes[index].visible


func _move_slot_focus(direction: Vector2i) -> void:
	if not _is_slot_index_visible(focused_slot_index):
		focus_current_slot()
		return

	var row := int(focused_slot_index / SLOT_COLUMNS)
	var column := focused_slot_index % SLOT_COLUMNS
	var next_row := row + direction.y
	var next_column := column + direction.x
	if next_row < 0 or next_column < 0 or next_column >= SLOT_COLUMNS:
		return

	var next_index := next_row * SLOT_COLUMNS + next_column
	if not _is_slot_index_visible(next_index):
		return

	focused_slot_index = next_index
	ingredient_slot_nodes[focused_slot_index].grab_focus()


func _on_slot_focus_entered(index: int) -> void:
	focused_slot_index = index


func _on_slot_ingredient_picked(ingredient: Ingredient) -> void:
	ingredient_picked.emit(ingredient)
