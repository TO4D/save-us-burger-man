extends Control

const INGREDIENT_SLOT_SCENE = preload("res://scenes/components/IngredientSlot.tscn")
const SUCCESS_PARTICLE_SCENE = preload("res://resources/particles/success.tscn")
const SUCCESS_PARTICLE_POSITIONS := [
	Vector2(-50, 320),
	Vector2(300, 320)
	]

enum Phase { IDLE, SHOWING_RECIPE, PLAYING, SUCCESS, FAILURE }

var current_phase: Phase = Phase.IDLE
var current_recipe: Recipe
var minigame_constants: MinigameConstants
var current_tier: OrderTier
var current_step: int = 0
var remaining_chances: int = 3
var recipe_show_total_time: float = 0.0
var recipe_show_remaining_time: float = 0.0
var pending_result_success: bool = false
var pending_result_reward: int = 0
var result_effect_run_id: int = 0

@onready var hearts_display: HBoxContainer = $HUD/HeartsDisplay
@onready var timer_bar: ProgressBar = $PreparationUI/TimerBar
@onready var preparation_ui: Control = $PreparationUI
@onready var ready_button: Button = $PreparationUI/ReadyButton
@onready var recipe_display: VBoxContainer = $PreparationUI/RecipeDisplay
@onready var burger_stack: Node2D = $PlateArea/BurgerStack
@onready var ingredient_slots: GridContainer = $IngredientSlots
@onready var preparation_status_label: Label = $PreparationUI/StatusLabel
@onready var gameplay_status_label: Label = $GameplayStatusLabel
@onready var result_ui: Control = $ResultUI
@onready var result_label: Label = $ResultUI/ResultLabel
@onready var continue_button: Button = $ResultUI/ContinueButton
@onready var result_particles_layer: Node2D = $ResultUI/ParticlesLayer

signal minigame_finished(success: bool, reward: int)

func _process(delta: float) -> void:
	if current_phase != Phase.SHOWING_RECIPE:
		return

	recipe_show_remaining_time = max(recipe_show_remaining_time - delta, 0.0)
	_update_recipe_timer_bar()

	if recipe_show_remaining_time <= 0.0:
		_start_play()

func _ready() -> void:
	ready_button.pressed.connect(_on_ready_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)

func on_show(data: Dictionary = {}) -> void:
	var recipes = data.get("recipes", [])
	var tier = data.get("tier", null)
	var recipe = recipes[0] if recipes.size() > 0 else null
	_start_new_round(recipe, tier)

func _start_new_round(recipe: Recipe, tier: OrderTier) -> void:
	minigame_constants = load("res://resources/minigame_constants/default_constants.tres")
	current_tier = tier

	if minigame_constants == null or current_tier == null:
		push_error("[MemoryGame] Failed to load required resources.")
		return

	current_recipe = recipe
	current_step = 0
	remaining_chances = minigame_constants.memory_chances
	recipe_show_total_time = 0.0
	recipe_show_remaining_time = 0.0
	pending_result_success = false
	pending_result_reward = 0
	result_effect_run_id += 1
	burger_stack.clear_stack()
	_clear_children(recipe_display)
	_clear_children(result_particles_layer)

	hearts_display.setup(remaining_chances)
	hearts_display.update_chances(remaining_chances)
	_set_result_ui(false)

	_show_recipe()

func _show_recipe() -> void:
	current_phase = Phase.SHOWING_RECIPE
	preparation_ui.visible = true
	preparation_status_label.text = "레시피를 외우세요"
	ready_button.visible = true
	ready_button.disabled = false
	gameplay_status_label.visible = false
	timer_bar.visible = true

	_clear_children(recipe_display)

	for i in range(current_recipe.ingredients.size() - 1, -1, -1):
		var ing = current_recipe.ingredients[i]
		var icon = TextureRect.new()
		icon.texture = ing.sprite
		icon.custom_minimum_size = Vector2(40, ing.stack_height)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		recipe_display.add_child(icon)

	_setup_ingredient_slots(false)

	recipe_show_total_time = minigame_constants.memory_show_time_base
	recipe_show_total_time += current_recipe.ingredients.size() * minigame_constants.memory_show_time_per_ingredient
	recipe_show_remaining_time = recipe_show_total_time
	_update_recipe_timer_bar()

func _on_ready_button_pressed() -> void:
	if current_phase == Phase.SHOWING_RECIPE:
		_start_play()

func _start_play() -> void:
	if current_phase != Phase.SHOWING_RECIPE:
		return

	current_phase = Phase.PLAYING
	preparation_ui.visible = false
	gameplay_status_label.visible = true
	gameplay_status_label.text = "재료를 순서대로 클릭하세요"
	timer_bar.visible = false
	recipe_show_remaining_time = 0.0
	_clear_children(recipe_display)
	_setup_ingredient_slots(true)

func _setup_ingredient_slots(enabled: bool) -> void:
	_clear_children(ingredient_slots)
	for ing in GameState.get_slot_ingredients():
		var slot = INGREDIENT_SLOT_SCENE.instantiate()
		ingredient_slots.add_child(slot)
		slot.setup(ing, false)
		slot.disabled = not enabled
		if enabled:
			slot.ingredient_picked.connect(_on_ingredient_picked)

func _on_ingredient_picked(ingredient: Ingredient) -> void:
	if current_phase != Phase.PLAYING:
		return

	var expected = current_recipe.ingredients[current_step]
	if ingredient.id == expected.id:
		burger_stack.add_ingredient(ingredient)
		current_step += 1

		if current_step >= current_recipe.ingredients.size():
			_on_success()
		else:
			gameplay_status_label.text = "%d / %d" % [current_step, current_recipe.ingredients.size()]
	else:
		remaining_chances -= 1
		hearts_display.update_chances(remaining_chances)
		_flash_red()

		if remaining_chances <= 0:
			_on_failure()

func _flash_red() -> void:
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

func _on_success() -> void:
	current_phase = Phase.SUCCESS
	pending_result_success = true
	pending_result_reward = current_tier.base_reward
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
	timer_bar.visible = false
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

func _update_recipe_timer_bar() -> void:
	if recipe_show_total_time <= 0.0:
		timer_bar.value = 0.0
		return

	timer_bar.value = (recipe_show_remaining_time / recipe_show_total_time) * 100.0

func on_hide() -> void:
	preparation_ui.visible = false
	gameplay_status_label.visible = false
	ready_button.visible = false
	timer_bar.visible = false
	recipe_show_total_time = 0.0
	recipe_show_remaining_time = 0.0
	pending_result_success = false
	pending_result_reward = 0
	result_effect_run_id += 1
	_clear_children(result_particles_layer)
	_set_result_ui(false)
	_clear_children(recipe_display)
