extends Control

signal order_completed(success: bool, recovery: float)

const INGREDIENT_SLOT_SCENE = preload("res://scenes/components/IngredientSlot.tscn")
const EATING_PARTICLE_SCENE = preload("res://resources/particles/Eating.tscn")

const CUSTOMER_HUNGRY_TEXTURE = preload("res://assets/sprites/customers/knight1.png")
const CUSTOMER_FULL_TEXTURE = preload("res://assets/sprites/customers/knight2.png")
const BURGER_SERVE_DELAY_SECONDS := 0.4
const INGREDIENT_SLOT_GAP := 5
const INGREDIENT_SLOT_DEFAULT_SIZE := 50.0
const INGREDIENT_SLOT_COMPACT_SIZE := 42.0
const INGREDIENT_SLOTS_AREA_LEFT := 10.0
const INGREDIENT_SLOTS_AREA_RIGHT := -10.0

enum Phase { IDLE, CUSTOMER_ENTERING, PLAYING, SERVING, CUSTOMER_EXITING, COMPLETE }

var current_phase: Phase = Phase.IDLE
var customer: Dictionary = {}
var recipes: Array = []
var current_recipe: Recipe = null
var current_recipe_index: int = 0
var current_step: int = 0
var recovery: float = 0.0
var round_token: int = 0
var customer_sprite: Node2D = null

@onready var distance_gauge: DistanceGauge = $DistanceGauge
@onready var recipe_display: VBoxContainer = $PlayArea/RecipeDisplay
@onready var next_recipe_display: HBoxContainer = $PlayArea/NextRecipeDisplay
@onready var customer_area: Control = $PlayArea/CustomerArea
@onready var burger_stack: Node2D = $PlayArea/PlateArea/BurgerStack
@onready var ingredient_slots: GridContainer = $IngredientSlots
@onready var status_label: Label = $StatusLabel
@onready var blackout_overlay: ColorRect = $BlackoutOverlay
@onready var blackout_label: Label = $BlackoutOverlay/BlackoutLabel


func _ready() -> void:
	UltimateManager.triggered.connect(_on_ultimate_triggered)


func on_show(data: Dictionary = {}) -> void:
	round_token += 1
	customer = data.get("customer", {})
	recipes = customer.get("recipes", [])
	recovery = customer.get("recovery", 0.0) as float
	if recipes.is_empty():
		push_error("[OrderPanel] No recipes provided.")
		return

	current_recipe_index = 0
	current_step = 0
	blackout_overlay.visible = false
	burger_stack.clear_stack()
	_setup_ingredient_slots(false)
	_clear_customer()
	distance_gauge.show_customer_queue()
	_start_customer(round_token)


func on_hide() -> void:
	round_token += 1
	current_phase = Phase.IDLE
	blackout_overlay.visible = false
	_clear_children(recipe_display)
	_clear_children(next_recipe_display)
	_clear_children(ingredient_slots)
	burger_stack.clear_stack()
	_clear_customer()


func _start_customer(token: int) -> void:
	current_phase = Phase.CUSTOMER_ENTERING
	current_recipe = recipes[0]

	status_label.text = "New customer"
	_display_current_recipe()
	customer_sprite = _create_customer_sprite(false)
	customer_area.add_child(customer_sprite)
	customer_sprite.position = Vector2(150.0, 88.0)

	var tween: Tween = create_tween()
	tween.tween_property(customer_sprite, "position:x", 50.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if token != round_token:
		return
	_start_play(token)


func _start_play(token: int) -> void:
	current_phase = Phase.PLAYING
	status_label.text = "Tap ingredients in order"
	_setup_ingredient_slots(true)
	if customer.get("variants", []).has("blackout"):
		_schedule_blackout(token)


func _schedule_blackout(token: int) -> void:
	await get_tree().create_timer(1.5).timeout
	if token != round_token or current_phase != Phase.PLAYING:
		return
	blackout_label.text = "BLACKOUT!"
	blackout_overlay.color = Color(0, 0, 0, 0.25)
	blackout_overlay.visible = true
	await get_tree().create_timer(0.5).timeout
	if token != round_token or current_phase != Phase.PLAYING:
		return
	blackout_label.text = ""
	blackout_overlay.color = Color(0, 0, 0, 0.95)
	await get_tree().create_timer(3.0).timeout
	if token != round_token:
		return
	blackout_overlay.visible = false


func _setup_ingredient_slots(enabled: bool) -> void:
	_clear_children(ingredient_slots)
	var stage: int = customer.get("stage", 1) as int
	var ingredients: Array[Ingredient] = GameState.get_slot_ingredients(stage)
	var column_count := 5 if ingredients.size() >= 9 else 4
	var slot_size := INGREDIENT_SLOT_COMPACT_SIZE if column_count == 5 else INGREDIENT_SLOT_DEFAULT_SIZE
	ingredient_slots.columns = column_count
	ingredient_slots.add_theme_constant_override("h_separation", INGREDIENT_SLOT_GAP)
	ingredient_slots.add_theme_constant_override("v_separation", INGREDIENT_SLOT_GAP)
	_center_ingredient_slots_horizontally(ingredients.size(), column_count, slot_size)
	for ing in ingredients:
		var slot: IngredientSlot = INGREDIENT_SLOT_SCENE.instantiate() as IngredientSlot
		ingredient_slots.add_child(slot)
		slot.set_slot_size(slot_size)
		slot.setup(ing, false)
		slot.disabled = not enabled
		if enabled:
			slot.ingredient_picked.connect(_on_ingredient_picked)


func _center_ingredient_slots_horizontally(item_count: int, column_count: int, slot_size: float) -> void:
	var visible_columns := mini(item_count, column_count)
	var content_width := float(visible_columns) * slot_size + float(maxi(visible_columns - 1, 0)) * INGREDIENT_SLOT_GAP
	var parent_control := ingredient_slots.get_parent() as Control
	var parent_width := parent_control.size.x if parent_control != null else size.x
	var area_left := INGREDIENT_SLOTS_AREA_LEFT
	var area_right := parent_width + INGREDIENT_SLOTS_AREA_RIGHT
	var area_center := (area_left + area_right) * 0.5
	ingredient_slots.offset_left = area_center - content_width * 0.5
	ingredient_slots.offset_right = area_center + content_width * 0.5 - parent_width


func _on_ingredient_picked(ingredient: Ingredient) -> void:
	if current_phase != Phase.PLAYING or current_recipe == null:
		return

	var expected: Ingredient = current_recipe.ingredients[current_step]
	if ingredient.id != expected.id:
		ComboManager.reset_combo()
		_show_wrong_input_feedback()
		return

	ComboManager.add_combo()
	UltimateManager.add_gauge_for_combo(ComboManager.combo)
	burger_stack.add_ingredient(ingredient)
	current_step += 1
	status_label.text = "%d / %d" % [current_step, current_recipe.ingredients.size()]

	if current_step >= current_recipe.ingredients.size():
		_finish_current_burger()


func _finish_current_burger() -> void:
	current_phase = Phase.SERVING
	status_label.text = "Burger served"
	await get_tree().create_timer(BURGER_SERVE_DELAY_SECONDS).timeout
	var eat_position: Vector2 = await _fly_burger_to_customer()
	await _play_eating_particles(eat_position)
	current_recipe_index += 1

	if current_recipe_index >= recipes.size():
		await _exit_customer()
		_play_customer_attack_and_recover()
		current_phase = Phase.COMPLETE
		order_completed.emit(true, 0.0)
		return

	current_recipe = recipes[current_recipe_index]
	current_step = 0
	burger_stack.clear_stack()
	_display_current_recipe()
	status_label.text = "Next burger"
	current_phase = Phase.PLAYING
	_setup_ingredient_slots(true)


func _fail_customer() -> void:
	current_phase = Phase.COMPLETE
	_disable_slots()
	status_label.text = "Failed"
	order_completed.emit(false, 0.0)


func _play_customer_attack_and_recover() -> void:
	var recover_distance := func() -> void:
		DistanceManager.recover(recovery)
	distance_gauge.customer_attack_hit.connect(recover_distance, CONNECT_ONE_SHOT)
	distance_gauge.play_customer_attack(false)


func _show_wrong_input_feedback() -> void:
	status_label.text = "Wrong ingredient"
	var original_position: Vector2 = ingredient_slots.position
	var tween: Tween = create_tween()
	tween.tween_property(ingredient_slots, "position:x", original_position.x - 5.0, 0.04)
	tween.tween_property(ingredient_slots, "position:x", original_position.x + 5.0, 0.04)
	tween.tween_property(ingredient_slots, "position:x", original_position.x, 0.04)
	_flash_wrong_input()


func _flash_wrong_input() -> void:
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.0, 0.1, 0.05, 0.28)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func _on_ultimate_triggered(recovery_amount: float, freeze_duration: float) -> void:
	if not visible:
		return

	status_label.text = "Ultimate! +%d / %.1fs freeze" % [int(round(recovery_amount)), freeze_duration]
	distance_gauge.play_ultimate_barrage()


func _fly_burger_to_customer() -> Vector2:
	var flying_burger: Node2D = _snapshot_burger()
	add_child(flying_burger)
	flying_burger.global_position = burger_stack.global_position
	burger_stack.clear_stack()

	var target_position: Vector2 = customer_area.global_position + Vector2(50.0, 72.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(flying_burger, "global_position", target_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(flying_burger, "scale", Vector2(0.35, 0.35), 0.28)
	await tween.finished
	flying_burger.queue_free()
	return target_position


func _play_eating_particles(origin: Vector2) -> void:
	for i in range(3):
		_spawn_eating_particle(origin)
		await get_tree().create_timer(0.2).timeout


func _spawn_eating_particle(origin: Vector2) -> void:
	var eating_particle: Node2D = EATING_PARTICLE_SCENE.instantiate() as Node2D
	add_child(eating_particle)
	eating_particle.global_position = origin
	for child in eating_particle.get_children():
		if child is GPUParticles2D:
			child.emitting = true

	var particle: Label = Label.new()
	particle.text = "YUM"
	particle.add_theme_font_size_override("font_size", 14)
	particle.modulate = Color(1.0, 0.86, 0.25, 1.0)
	particle.global_position = origin + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 6.0))
	add_child(particle)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(particle, "global_position:y", particle.global_position.y - 18.0, 0.28)
	tween.tween_property(particle, "modulate:a", 0.0, 0.28)
	await tween.finished
	particle.queue_free()
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(eating_particle):
		eating_particle.queue_free()


func _exit_customer() -> void:
	current_phase = Phase.CUSTOMER_EXITING
	_set_customer_full()
	status_label.text = "Customer satisfied"
	await get_tree().create_timer(0.12).timeout
	if customer_sprite == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(customer_sprite, "position:x", -150.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	_clear_customer()


func _snapshot_burger() -> Node2D:
	var root: Node2D = Node2D.new()
	for child in burger_stack.get_children():
		var snapshot_child: Node = child.duplicate()
		root.add_child(snapshot_child)
	return root


func _display_current_recipe() -> void:
	_display_recipe(current_recipe, recipe_display, Vector2(36, 18))
	_display_next_recipes()


func _display_recipe(recipe: Recipe, parent: VBoxContainer, icon_size: Vector2) -> void:
	_clear_children(parent)
	for i in range(recipe.ingredients.size() - 1, -1, -1):
		var ing: Ingredient = recipe.ingredients[i]
		var icon: TextureRect = TextureRect.new()
		icon.texture = ing.sprite
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(icon)


func _display_next_recipes() -> void:
	_clear_children(next_recipe_display)
	for i in range(current_recipe_index + 1, recipes.size()):
		var preview: VBoxContainer = VBoxContainer.new()
		preview.custom_minimum_size = Vector2(28, 70)
		preview.add_theme_constant_override("separation", 0)
		next_recipe_display.add_child(preview)
		_display_recipe(recipes[i], preview, Vector2(18, 10))


func _create_customer_sprite(full: bool) -> Node2D:
	#var root: Node2D = Node2D.new()
	#root.name = "CustomerSprite"
#
	#var body: Polygon2D = Polygon2D.new()
	#body.name = "Body"
	#body.polygon = PackedVector2Array([
		#Vector2(-28, 44),
		#Vector2(28, 44),
		#Vector2(22, -10),
		#Vector2(-22, -10),
	#])
	#body.color = Color(0.25, 0.46, 0.82) if not full else Color(0.28, 0.68, 0.38)
	#root.add_child(body)
#
	#var head: Polygon2D = Polygon2D.new()
	#head.name = "Head"
	#head.polygon = PackedVector2Array([
		#Vector2(-22, -8),
		#Vector2(22, -8),
		#Vector2(22, -48),
		#Vector2(-22, -48),
	#])
	#head.color = Color(0.95, 0.72, 0.48)
	#root.add_child(head)
#
	#var face: Label = Label.new()
	#face.name = "Face"
	#face.text = ":)" if full else ":("
	#face.position = Vector2(-12, -42)
	#face.size = Vector2(40, 28)
	#root.add_child(face)
	

	#return root
	
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "CustomerSprite"
	sprite.texture = CUSTOMER_FULL_TEXTURE if full else CUSTOMER_HUNGRY_TEXTURE
	return sprite


func _set_customer_full() -> void:
	#if customer_sprite == null:
		#return
	#var body: Polygon2D = customer_sprite.get_node_or_null("Body") as Polygon2D
	#if body != null:
		#body.color = Color(0.28, 0.68, 0.38)
	#var face: Label = customer_sprite.get_node_or_null("Face") as Label
	#if face != null:
		#face.text = ":)"
	var sprite := customer_sprite as Sprite2D
	if sprite != null:
		sprite.texture = CUSTOMER_FULL_TEXTURE


func _clear_customer() -> void:
	if customer_sprite != null and is_instance_valid(customer_sprite):
		customer_sprite.queue_free()
	customer_sprite = null


func _disable_slots() -> void:
	for child in ingredient_slots.get_children():
		if child is Button:
			child.disabled = true


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
