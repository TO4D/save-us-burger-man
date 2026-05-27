extends Control

signal order_completed(success: bool)

const EATING_PARTICLE_SCENE = preload("res://resources/particles/Eating.tscn")

const CUSTOMER_HUNGRY_TEXTURE = preload("res://assets/sprites/customers/knight1.png")
const CUSTOMER_FULL_TEXTURE = preload("res://assets/sprites/customers/knight2.png")
const BURGER_SERVE_DELAY_SECONDS := 0.35
const READY_OVERLAY_SECONDS := 2.0
const GO_OVERLAY_SECONDS := 0.6
const RESULT_RANK_DISPLAY_SECONDS := 0.55
const SCREEN_SHAKE_STEP_DURATION := 0.04
const ORDER_PROGRESS_ICON_SIZE := Vector2(16.0, 16.0)
const ORDER_PROGRESS_FILL_TEXTURE := preload("res://assets/sprites/ui/order_icon.1.png")
const ORDER_PROGRESS_EMPTY_TEXTURE := preload("res://assets/sprites/ui/order_icon.2.png")

enum Phase { IDLE, CUSTOMER_ENTERING, PLAYING, SERVING, CUSTOMER_EXITING, COMPLETE }

var current_phase: Phase = Phase.IDLE
var customer: Dictionary = {}
var recipes: Array = []
var current_recipe: Recipe = null
var current_recipe_index: int = 0
var current_step: int = 0
var damage: float = 0.0
var knockback: float = 0.0
var round_token: int = 0
var customer_sprite: Node2D = null
var screen_shake_elapsed: float = 0.0
var screen_shake_active: bool = false
var screen_shake_tween: Tween = null
var panel_home_position: Vector2 = Vector2.ZERO
var screen_shake_interval_seconds: float = 0.0
var screen_shake_offset: float = 0.0
var is_mobile_input: bool = false
var mistake_count: int = 0
var result_rank_tween: Tween = null
var stack_landing_token: int = 0
var pending_stack_landing_tokens: Array[int] = []
var ready_go_active: bool = false

@onready var battle_gauge: BattleGauge = $BattleGauge
@onready var recipe_display_stack: RecipeDisplayStack = $PlayArea/RecipeDisplayStack
@onready var customer_area: Control = $PlayArea/CustomerArea
@onready var burger_stack: BurgerStack = $PlayArea/PlateArea/BurgerStack
@onready var order_progress_dots: HBoxContainer = $PlayArea/PlateArea/OrderProgressDots
@onready var ingredient_slots: IngredientSlotGrid = $IngredientSlots
@onready var status_label: Label = $StatusLabel
@onready var result_rank: Control = $ResultRank
@onready var result_perfect: TextureRect = $ResultRank/Perfect
@onready var blackout_overlay: ColorRect = $BlackoutOverlay
@onready var blackout_label: Label = $BlackoutOverlay/BlackoutLabel
@onready var combo_counter: ComboCounter = $ComboCounter
@onready var multi_order: MultiOrder = $MultiOrder
@onready var ready_go_overlay: ColorRect = $ReadyGoOverlay
@onready var ready_go_label: Label = $ReadyGoOverlay/Label


func _ready() -> void:
	panel_home_position = position
	is_mobile_input = OS.has_feature("mobile")
	UltimateManager.triggered.connect(_on_ultimate_triggered)
	DistanceManager.distance_changed.connect(_on_distance_changed)
	burger_stack.ingredient_landed.connect(_on_stack_ingredient_landed)
	ingredient_slots.ingredient_picked.connect(_on_ingredient_picked)
	_on_distance_changed(DistanceManager.distance, DistanceManager.MAX_DISTANCE)


func _process(delta: float) -> void:
	if not visible or not screen_shake_active:
		return

	screen_shake_elapsed += delta
	if screen_shake_elapsed < screen_shake_interval_seconds:
		return

	screen_shake_elapsed = 0.0
	_play_screen_shake()


func _unhandled_input(event: InputEvent) -> void:
	if not ready_go_active:
		return
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.pressed:
		get_viewport().set_input_as_handled()


func on_show(data: Dictionary = {}) -> void:
	round_token += 1
	customer = data.get("customer", {})
	recipes = customer.get("recipes", [])
	damage = customer.get("damage", 0.0) as float
	knockback = customer.get("knockback", 0.0) as float
	multi_order.hide_order_count()
	if recipes.is_empty():
		push_error("[OrderPanel] No recipes provided.")
		return

	current_recipe_index = 0
	current_step = 0
	mistake_count = 0
	pending_stack_landing_tokens.clear()
	blackout_overlay.visible = false
	_hide_result_rank()
	burger_stack.clear_stack()
	_setup_ingredient_slots(false)
	_clear_customer()
	_reset_screen_shake_position()
	screen_shake_elapsed = 0.0
	_setup_order_progress_dots()
	_on_distance_changed(DistanceManager.distance, DistanceManager.MAX_DISTANCE)
	battle_gauge.show_customer_queue(customer.get("variants", []).has("multi"))
	var token := round_token
	if data.get("show_ready_go", false):
		await _run_ready_go_overlay(token)
		if token != round_token:
			return
	_start_customer(token)


func on_hide() -> void:
	round_token += 1
	current_phase = Phase.IDLE
	blackout_overlay.visible = false
	multi_order.hide_order_count()
	_hide_result_rank()
	recipe_display_stack.clear_recipes()
	_clear_order_progress_dots()
	ingredient_slots.set_interaction_enabled(false)
	ingredient_slots.clear_slots()
	burger_stack.clear_stack()
	pending_stack_landing_tokens.clear()
	_clear_customer()
	screen_shake_active = false
	ready_go_active = false
	ready_go_overlay.visible = false
	ingredient_slots.set_process_unhandled_input(true)
	GameRun.set_start_blocked(false)
	screen_shake_elapsed = 0.0
	_reset_screen_shake_position()


func _start_customer(token: int) -> void:
	current_phase = Phase.CUSTOMER_ENTERING
	current_recipe = recipes[0]

	status_label.text = "New customer"
	_display_current_recipes()
	customer_sprite = _create_customer_sprite(false)
	customer_area.add_child(customer_sprite)
	customer_sprite.position = Vector2(150.0, 88.0)

	var tween: Tween = create_tween()
	tween.tween_property(customer_sprite, "position:x", 50.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if token != round_token:
		return
	multi_order.show_order_count(recipes.size())
	_start_play(token)

func _start_play(token: int) -> void:
	if token != round_token:
		return
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


func _run_ready_go_overlay(token: int) -> void:
	ready_go_active = true
	GameRun.set_start_blocked(true)
	ingredient_slots.set_process_unhandled_input(false)
	ingredient_slots.set_interaction_enabled(false)
	ready_go_overlay.modulate.a = 1.0
	ready_go_label.scale = Vector2.ONE
	ready_go_label.text = "Ready..."
	ready_go_overlay.visible = true
	await get_tree().create_timer(READY_OVERLAY_SECONDS).timeout
	if token != round_token:
		return

	ready_go_label.text = "Go"
	ready_go_label.scale = Vector2(1.18, 1.18)
	var tween := create_tween()
	tween.tween_property(ready_go_label, "scale", Vector2.ONE, GO_OVERLAY_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(GO_OVERLAY_SECONDS).timeout
	if token != round_token:
		return

	ready_go_overlay.visible = false
	ready_go_active = false
	ingredient_slots.set_process_unhandled_input(true)
	GameRun.set_start_blocked(false)


func _setup_ingredient_slots(enabled: bool) -> void:
	var stage: int = customer.get("stage", 1) as int
	var ingredients: Array[Ingredient] = GameState.get_slot_ingredients(stage)
	ingredient_slots.configure(ingredients, is_mobile_input, enabled)


func _on_ingredient_picked(ingredient: Ingredient) -> void:
	if ready_go_active or current_phase != Phase.PLAYING or current_recipe == null:
		return

	var expected: Ingredient = current_recipe.ingredients[current_step]
	if ingredient.id != expected.id:
		mistake_count += 1
		pending_stack_landing_tokens.clear()
		ComboManager.reset_combo()
		_show_wrong_input_feedback()
		return

	stack_landing_token += 1
	pending_stack_landing_tokens.append(stack_landing_token)
	burger_stack.add_ingredient(ingredient, stack_landing_token)
	current_step += 1
	status_label.text = "%d / %d" % [current_step, current_recipe.ingredients.size()]
	recipe_display_stack.set_current_step(current_step)

	if current_step >= current_recipe.ingredients.size():
		_update_order_progress_dots(current_recipe_index + 1)
		_finish_current_burger()


func _on_stack_ingredient_landed(_stack_position: Vector2, token: int) -> void:
	var token_index: int = pending_stack_landing_tokens.find(token)
	if token_index < 0:
		return
	pending_stack_landing_tokens.remove_at(token_index)
	ComboManager.add_combo()
	UltimateManager.add_gauge_for_combo(ComboManager.combo)
	combo_counter.show_at_fixed_position()


func _finish_current_burger() -> void:
	current_phase = Phase.SERVING
	status_label.text = "Burger served"
	await get_tree().create_timer(BURGER_SERVE_DELAY_SECONDS).timeout
	var eat_position: Vector2 = await _fly_burger_to_customer()
	await _play_eating_particles(eat_position)
	await recipe_display_stack.complete_current_recipe()
	current_recipe_index += 1
	_update_order_progress_dots()

	if current_recipe_index >= recipes.size():
		_play_result_rank_display(round_token)
		await _exit_customer()
		_play_customer_attack()
		current_phase = Phase.COMPLETE
		order_completed.emit(true)
		return

	current_recipe = recipes[current_recipe_index]
	current_step = 0
	recipe_display_stack.set_current_step(current_step)
	burger_stack.clear_stack()
	status_label.text = "Next burger"
	current_phase = Phase.PLAYING
	_setup_ingredient_slots(true)


func _setup_order_progress_dots() -> void:
	_clear_order_progress_dots()
	order_progress_dots.visible = not recipes.is_empty()

	for i in range(recipes.size()):
		var icon := TextureRect.new()
		icon.custom_minimum_size = ORDER_PROGRESS_ICON_SIZE
		icon.size = ORDER_PROGRESS_ICON_SIZE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		order_progress_dots.add_child(icon)

	_update_order_progress_dots()


func _clear_order_progress_dots() -> void:
	for child in order_progress_dots.get_children():
		order_progress_dots.remove_child(child)
		child.queue_free()


func _update_order_progress_dots(completed_count: int = -1) -> void:
	var filled_count := current_recipe_index if completed_count < 0 else completed_count
	for index in range(order_progress_dots.get_child_count()):
		var icon := order_progress_dots.get_child(index) as TextureRect
		if icon == null:
			continue
		icon.texture = ORDER_PROGRESS_FILL_TEXTURE if index < filled_count else ORDER_PROGRESS_EMPTY_TEXTURE


func _fail_customer() -> void:
	current_phase = Phase.COMPLETE
	_disable_slots()
	status_label.text = "Failed"
	order_completed.emit(false)


func _play_customer_attack() -> void:
	var attack_damage := damage
	var attack_knockback := knockback
	var hit_monster := func() -> void:
		MonsterManager.apply_damage(attack_damage)
		DistanceManager.recover(attack_knockback)
		battle_gauge.refresh_monster_icon_position_immediately()
	battle_gauge.customer_attack_hit.connect(hit_monster, CONNECT_ONE_SHOT)
	battle_gauge.play_customer_attack(false)


func _show_wrong_input_feedback() -> void:
	status_label.text = "Wrong ingredient"
	recipe_display_stack.play_current_indicator_shake()
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


func _show_result_rank() -> void:
	if mistake_count > 0:
		return

	result_perfect.visible = true

	if result_rank_tween != null and result_rank_tween.is_valid():
		result_rank_tween.kill()

	result_rank.visible = true
	result_rank.pivot_offset = result_rank.size * 0.5
	result_rank.scale = Vector2(1.2, 1.2)
	result_rank.modulate.a = 0.0
	result_rank_tween = create_tween().set_parallel(true)
	result_rank_tween.tween_property(result_rank, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_rank_tween.tween_property(result_rank, "modulate:a", 1.0, 0.08)


func _play_result_rank_display(token: int) -> void:
	if mistake_count > 0:
		return

	_show_result_rank()
	await get_tree().create_timer(RESULT_RANK_DISPLAY_SECONDS).timeout
	if token != round_token:
		return
	_hide_result_rank()


func _hide_result_rank() -> void:
	if result_rank_tween != null and result_rank_tween.is_valid():
		result_rank_tween.kill()
	result_rank_tween = null
	result_rank.visible = false
	result_rank.scale = Vector2.ONE
	result_rank.modulate.a = 1.0
	_hide_result_rank_images()


func _hide_result_rank_images() -> void:
	result_perfect.visible = false


func _on_ultimate_triggered(recovery_amount: float, freeze_duration: float) -> void:
	if not visible:
		return

	status_label.text = "Ultimate! +%d / %.1fs freeze" % [int(round(recovery_amount)), freeze_duration]
	battle_gauge.play_ultimate_barrage()


func _on_distance_changed(value: float, _max_value: float) -> void:
	var distance_meters := value * battle_gauge.distance_display_scale
	var should_shake := false
	var next_interval := 0.0
	var next_offset := 0.0

	if distance_meters <= 200.0:
		should_shake = true
		next_interval = 1.0
		next_offset = 4.0
	elif distance_meters <= 500.0:
		should_shake = true
		next_interval = 1.0
		next_offset = 2.0
	elif distance_meters <= 800.0:
		should_shake = true
		next_interval = 2.0
		next_offset = 1.0

	if should_shake == screen_shake_active and is_equal_approx(next_interval, screen_shake_interval_seconds) and is_equal_approx(next_offset, screen_shake_offset):
		return

	screen_shake_active = should_shake
	screen_shake_interval_seconds = next_interval
	screen_shake_offset = next_offset
	screen_shake_elapsed = 0.0
	if not should_shake:
		_reset_screen_shake_position()


func _play_screen_shake() -> void:
	_reset_screen_shake_tween()
	position = panel_home_position
	screen_shake_tween = create_tween()
	screen_shake_tween.tween_property(self, "position:x", panel_home_position.x - screen_shake_offset, SCREEN_SHAKE_STEP_DURATION)
	screen_shake_tween.tween_property(self, "position:x", panel_home_position.x + screen_shake_offset, SCREEN_SHAKE_STEP_DURATION * 2.0)
	screen_shake_tween.tween_property(self, "position:x", panel_home_position.x, SCREEN_SHAKE_STEP_DURATION)


func _reset_screen_shake_position() -> void:
	_reset_screen_shake_tween()
	position = panel_home_position


func _reset_screen_shake_tween() -> void:
	if screen_shake_tween != null and screen_shake_tween.is_valid():
		screen_shake_tween.kill()
	screen_shake_tween = null


func _fly_burger_to_customer() -> Vector2:
	var flying_burger: Node2D = _snapshot_burger()
	add_child(flying_burger)
	flying_burger.global_position = burger_stack.global_position
	burger_stack.clear_stack()

	var target_position: Vector2 = customer_area.global_position + Vector2(50.0, 72.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(flying_burger, "global_position", target_position, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(flying_burger, "scale", Vector2(0.35, 0.35), 0.25)
	await tween.finished
	flying_burger.queue_free()
	return target_position


func _play_eating_particles(origin: Vector2) -> void:
	for i in range(2):
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


func _display_current_recipes() -> void:
	recipe_display_stack.show_recipes(recipes.slice(current_recipe_index, recipes.size()))
	recipe_display_stack.set_current_step(current_step)


func _create_customer_sprite(full: bool) -> Node2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "CustomerSprite"
	sprite.texture = CUSTOMER_FULL_TEXTURE if full else CUSTOMER_HUNGRY_TEXTURE
	return sprite


func _set_customer_full() -> void:
	var sprite := customer_sprite as Sprite2D
	if sprite != null:
		sprite.texture = CUSTOMER_FULL_TEXTURE


func _clear_customer() -> void:
	if customer_sprite != null and is_instance_valid(customer_sprite):
		customer_sprite.queue_free()
	customer_sprite = null


func _disable_slots() -> void:
	ingredient_slots.set_interaction_enabled(false)
