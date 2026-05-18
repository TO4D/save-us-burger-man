extends Control

const INGREDIENT_SLOT_SCENE = preload("res://scenes/components/IngredientSlot.tscn")
const SUCCESS_PARTICLE_SCENE = preload("res://resources/particles/success.tscn")
const SUCCESS_PARTICLE_POSITIONS := [
	Vector2(-50, 320),
	Vector2(300, 320)
]

enum Phase { IDLE, COUNTDOWN, PLAYING, SUCCESS, FAILURE }

var current_phase: Phase = Phase.IDLE
var minigame_constants: MinigameConstants
var current_tier: OrderTier
var pending_recipes: Array = []
var current_recipe: Recipe = null
var current_step: int = 0
var remaining_time: float = 0.0
var initial_time: float = 0.0
var pending_result_success: bool = false
var pending_result_reward: float = 0.0
var result_effect_run_id: int = 0

@onready var time_bar: ProgressBar = $HUD/TimeBar
@onready var time_label: Label = $HUD/TimeLabel
@onready var burger_count_label: Label = $HUD/BurgerCountLabel
@onready var current_recipe_display: VBoxContainer = $CurrentRecipeDisplay
@onready var burger_stack: Node2D = $PlateArea/BurgerStack
@onready var ingredient_slots: GridContainer = $IngredientSlots
@onready var preparation_ui: Control = $PreparationUI
@onready var preparation_status_label: Label = $PreparationUI/StatusLabel
@onready var countdown_label: Label = $PreparationUI/CountdownLabel
@onready var gameplay_status_label: Label = $GameplayStatusLabel
@onready var result_ui: Control = $ResultUI
@onready var result_label: Label = $ResultUI/ResultLabel
@onready var continue_button: Button = $ResultUI/ContinueButton
@onready var result_particles_layer: Node2D = $ResultUI/ParticlesLayer

signal minigame_finished(success: bool, reward: float)

func _process(delta: float) -> void:
	if current_phase != Phase.PLAYING:
		return

	remaining_time -= delta
	if remaining_time <= 0:
		remaining_time = 0
		_on_failure()
	_update_time_display()

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)

func on_show(data: Dictionary = {}) -> void:
	var recipes = data.get("recipes", [])
	var tier = data.get("tier", null)
	if recipes.size() == 0:
		push_error("[SpeedGame] No recipes were provided.")
		return
	_start_new_round(recipes, tier)

func _start_new_round(recipes: Array, tier: OrderTier) -> void:
	minigame_constants = load("res://resources/minigame_constants/default_constants.tres")
	current_tier = tier

	if minigame_constants == null or current_tier == null:
		push_error("[SpeedGame] Failed to load required resources.")
		return

	pending_recipes = recipes.duplicate()
	initial_time = minigame_constants.speed_initial_time
	remaining_time = initial_time
	pending_result_success = false
	pending_result_reward = 0.0
	result_effect_run_id += 1

	current_recipe = null
	gameplay_status_label.visible = false
	preparation_ui.visible = false
	countdown_label.visible = false
	_set_result_ui(false)
	_clear_children(current_recipe_display)
	_clear_children(result_particles_layer)
	burger_stack.clear_stack()
	_setup_ingredient_slots(false)
	_update_time_display()
	_update_burger_count_display()

	await _run_countdown()
	_start_play()

func _run_countdown() -> void:
	current_phase = Phase.COUNTDOWN
	preparation_ui.visible = true
	preparation_status_label.text = "준비..."
	countdown_label.visible = true
	gameplay_status_label.visible = false

	for n in [3, 2, 1]:
		countdown_label.text = str(n)
		countdown_label.scale = Vector2(1.5, 1.5)
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.3)
		await get_tree().create_timer(0.7).timeout

	countdown_label.text = "시작!"
	await get_tree().create_timer(0.4).timeout
	countdown_label.visible = false

func _start_play() -> void:
	current_phase = Phase.PLAYING
	preparation_ui.visible = false
	gameplay_status_label.visible = true
	gameplay_status_label.text = "재료를 순서대로 클릭!"
	_setup_ingredient_slots(true)
	_next_burger()

func _next_burger() -> void:
	if pending_recipes.size() == 0:
		_on_success()
		return

	current_recipe = pending_recipes.pop_front()
	current_step = 0
	burger_stack.clear_stack()
	_display_current_recipe()
	_update_burger_count_display()

func _display_current_recipe() -> void:
	_clear_children(current_recipe_display)

	for i in range(current_recipe.ingredients.size() - 1, -1, -1):
		var ing = current_recipe.ingredients[i]
		var icon = TextureRect.new()
		icon.texture = ing.sprite
		icon.custom_minimum_size = Vector2(15, 15)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		current_recipe_display.add_child(icon)

func _setup_ingredient_slots(enabled: bool) -> void:
	_clear_children(ingredient_slots)
	var slot_ingredients = GameState.get_slot_ingredients()
	for ing in slot_ingredients:
		var slot = INGREDIENT_SLOT_SCENE.instantiate()
		ingredient_slots.add_child(slot)
		slot.setup(ing, false)
		slot.disabled = not enabled
		if enabled:
			slot.ingredient_picked.connect(_on_ingredient_picked)

func _on_ingredient_picked(ingredient: Ingredient) -> void:
	if current_phase != Phase.PLAYING or current_recipe == null:
		return

	var expected = current_recipe.ingredients[current_step]
	if ingredient.id == expected.id:
		burger_stack.add_ingredient(ingredient)
		current_step += 1

		if current_step >= current_recipe.ingredients.size():
			remaining_time += minigame_constants.speed_bonus_per_burger
			initial_time = max(initial_time, remaining_time)
			await get_tree().create_timer(0.3).timeout
			_next_burger()
	else:
		_flash_red()

func _flash_red() -> void:
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

func _update_time_display() -> void:
	time_label.text = "%.1f초" % remaining_time
	if initial_time > 0:
		time_bar.value = (remaining_time / initial_time) * 100

func _update_burger_count_display() -> void:
	burger_count_label.text = "남은 주문: %d개" % pending_recipes.size()

func _on_success() -> void:
	current_phase = Phase.SUCCESS
	pending_result_success = true
	pending_result_reward = current_tier.base_reward * 2
	_disable_slots()
	_show_result("성공!")
	_play_success_particles()

func _on_failure() -> void:
	current_phase = Phase.FAILURE
	pending_result_success = false
	pending_result_reward = round(current_tier.base_reward * current_tier.failure_reward_ratio)
	_disable_slots()
	_show_result("실패..")

func _disable_slots() -> void:
	for child in ingredient_slots.get_children():
		if child is Button:
			child.disabled = true

func _show_result(message: String) -> void:
	preparation_ui.visible = false
	gameplay_status_label.visible = false
	result_label.text = message
	_set_result_ui(true)

func _set_result_ui(visible: bool) -> void:
	result_ui.visible = visible
	continue_button.disabled = not visible

func _play_success_particles() -> void:
	result_effect_run_id += 1
	for particle_position in SUCCESS_PARTICLE_POSITIONS:
		_spawn_success_particle(particle_position)

func _spawn_success_particle(particle_position: Vector2) -> void:
	var particle_root := SUCCESS_PARTICLE_SCENE.instantiate() as Node2D
	if particle_root == null:
		return
	particle_root.position = particle_position
	result_particles_layer.add_child(particle_root)

	var center_direction = Vector2(135, 0) - particle_position
	if center_direction == Vector2.ZERO:
		center_direction = Vector2.UP

	for child in particle_root.get_children():
		if child is GPUParticles2D:
			if child.process_material is ParticleProcessMaterial:
				var particle_material := child.process_material.duplicate() as ParticleProcessMaterial
				particle_material.direction = Vector3(center_direction.normalized().x, center_direction.normalized().y, 0.0)
				child.process_material = particle_material
			child.emitting = true

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particle_root):
		particle_root.queue_free()

func _on_continue_button_pressed() -> void:
	if current_phase != Phase.SUCCESS and current_phase != Phase.FAILURE:
		return

	result_effect_run_id += 1
	_clear_children(result_particles_layer)
	_set_result_ui(false)
	minigame_finished.emit(pending_result_success, pending_result_reward)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func on_hide() -> void:
	preparation_ui.visible = false
	gameplay_status_label.visible = false
	countdown_label.visible = false
	pending_result_success = false
	pending_result_reward = 0.0
	result_effect_run_id += 1
	_clear_children(result_particles_layer)
	_set_result_ui(false)
