extends Control

signal order_completed(success: bool)

const BURGER_SERVE_DELAY_SECONDS := 0.35
const STAGE_COMPLETE_PRESENTATION_SECONDS := 0.45
const BURGER_TRANSITION_SECONDS := 0.2
const READY_OVERLAY_SECONDS := 2.0
const GO_OVERLAY_SECONDS := 0.6
const RESULT_RANK_DISPLAY_SECONDS := 0.55
const SCREEN_SHAKE_STEP_DURATION := 0.04
const ORDER_PROGRESS_ICON_SIZE := Vector2(48.0, 48.0)
const ORDER_PROGRESS_TEXTURE := preload("res://assets/sprites/ui/order_icon_big.png")
const ORDER_PROGRESS_FILLED_ALPHA := 1.0
const ORDER_PROGRESS_EMPTY_ALPHA := 0.3
const STORE_LIGHT_ON_TEXTURE := preload("res://assets/sprites/store/light_on.png")
const STORE_LIGHT_OFF_TEXTURE := preload("res://assets/sprites/store/light_off.png")
const STORE_LIGHT_FAIL_TEXTURE := preload("res://assets/sprites/store/light_fail.png")
const PERFECT_SHINE_SCENE := preload("res://resources/particles/shine.tscn")
const NEXT_STAGE_HALO_SCENE := preload("res://resources/vfx/NextStageBurgerHalo.tscn")
const PERFECT_SHINE_INGREDIENT_ID := "bun_top"
const INTER_ORDER_SLIDE_DISTANCE := 320.0
const NEXT_STAGE_OVERLAY_TARGET_ALPHA := 144.0 / 255.0
const NEXT_STAGE_OVERLAY_FADE_SECONDS := 0.18
const BLACKOUT_WARNING_STEP_SECONDS := 0.2
const BLACKOUT_WARNING_PAUSE_SECONDS := 0.6

enum Phase { IDLE, ORDER_STARTING, PLAYING, SERVING, COMPLETE }

var current_phase: Phase = Phase.IDLE
var customer: Dictionary = {}
var recipes: Array = []
var current_recipe: Recipe = null
var current_recipe_index: int = 0
var current_step: int = 0
var medal_targets: Dictionary = {}
var round_token: int = 0
var screen_shake_elapsed: float = 0.0
var screen_shake_active: bool = false
var screen_shake_tween: Tween = null
var panel_home_position: Vector2 = Vector2.ZERO
var screen_shake_interval_seconds: float = 0.0
var screen_shake_offset: float = 0.0
var is_mobile_input: bool = false
var mistake_count: int = 0
var result_rank_tween: Tween = null
var next_stage_overlay_tween: Tween = null
var next_stage_halo: Node2D = null
var next_stage_halo_elapsed: float = 0.0
var stack_landing_token: int = 0
var pending_stack_landing_tokens: Array[int] = []
var perfect_shine_landing_tokens: Array[int] = []
var next_stage_overlay_landing_tokens: Array[int] = []
var ready_go_active: bool = false
var blackout_event_active: bool = false
var blackout_used_for_customer: bool = false
var timer_frozen: bool = false
var next_stage_overlay_active: bool = false
var recipe_display_home_position: Vector2 = Vector2.ZERO
var burger_stack_home_position: Vector2 = Vector2.ZERO
var cook_board_home_position: Vector2 = Vector2.ZERO

@onready var stage_timer_label: Label = $StageTimerLabel
@onready var medal_target_label: Label = $MedalTargetLabel
@onready var recipe_display_stack: RecipeDisplayStack = $PlayArea/RecipeDisplayStack
@onready var plate_area: Control = $PlayArea/PlateArea
@onready var cook_board: Sprite2D = $PlayArea/PlateArea/Cook_jori
@onready var burger_stack: BurgerStack = $PlayArea/PlateArea/BurgerStack
@onready var order_progress_dots: HBoxContainer = $PlayArea/OrderProgressDots
@onready var ingredient_slots: IngredientSlotGrid = $IngredientSlots
@onready var status_label: Label = $StatusLabel
@onready var result_rank: Control = $ResultRank
@onready var result_perfect: TextureRect = $ResultRank/Perfect
@onready var blackout_overlay: ColorRect = $BlackoutOverlay
@onready var combo_counter: ComboCounter = $ComboCounter
@onready var ready_go_overlay: ColorRect = $ReadyGoOverlay
@onready var ready_go_label: Label = $ReadyGoOverlay/Label
@onready var next_stage_overlay: ColorRect = $NextStageOverlay
@onready var store_light: TextureRect = $StoreLight


func _ready() -> void:
	panel_home_position = position
	recipe_display_home_position = recipe_display_stack.position
	burger_stack_home_position = burger_stack.position
	cook_board_home_position = cook_board.position
	is_mobile_input = OS.has_feature("mobile")
	UltimateManager.triggered.connect(_on_ultimate_triggered)
	GameRun.time_changed.connect(_on_time_changed)
	GameRun.blackout_requested.connect(_on_blackout_requested)
	burger_stack.ingredient_landed.connect(_on_stack_ingredient_landed)
	ingredient_slots.ingredient_picked.connect(_on_ingredient_picked)


func _process(delta: float) -> void:
	_animate_next_stage_halo(delta)

	if not visible or not screen_shake_active:
		return

	screen_shake_elapsed += delta
	if screen_shake_elapsed < screen_shake_interval_seconds:
		return

	screen_shake_elapsed = 0.0
	_play_screen_shake()


func _unhandled_input(event: InputEvent) -> void:
	if next_stage_overlay_active:
		_handle_next_stage_overlay_input(event)
		return

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
	medal_targets = customer.get("medal_targets", {}) as Dictionary
	if recipes.is_empty():
		push_error("[OrderPanel] No recipes provided.")
		return

	current_recipe_index = 0
	current_step = 0
	mistake_count = 0
	timer_frozen = false
	next_stage_overlay_active = false
	blackout_event_active = false
	blackout_used_for_customer = false
	pending_stack_landing_tokens.clear()
	perfect_shine_landing_tokens.clear()
	next_stage_overlay_landing_tokens.clear()
	_reset_next_stage_overlay_tween()
	_clear_next_stage_halo()
	blackout_overlay.visible = false
	next_stage_overlay.visible = false
	next_stage_overlay.color.a = 0.0
	medal_target_label.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	_hide_result_rank()
	burger_stack.clear_stack()
	_reset_stage_completion_positions()
	_setup_ingredient_slots(false)
	_reset_screen_shake_position()
	screen_shake_elapsed = 0.0
	_setup_order_progress_dots()
	_on_time_changed(GameRun.elapsed_time)
	var token := round_token
	if data.get("show_ready_go", false):
		await _run_ready_go_overlay(token)
		if token != round_token:
			return
	_start_order(token)


func on_hide() -> void:
	round_token += 1
	current_phase = Phase.IDLE
	if blackout_event_active:
		GameRun.complete_blackout()
	blackout_event_active = false
	blackout_used_for_customer = false
	blackout_overlay.visible = false
	medal_target_label.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	_hide_result_rank()
	recipe_display_stack.clear_recipes()
	_clear_order_progress_dots()
	ingredient_slots.set_interaction_enabled(false)
	ingredient_slots.clear_slots()
	burger_stack.clear_stack()
	pending_stack_landing_tokens.clear()
	perfect_shine_landing_tokens.clear()
	next_stage_overlay_landing_tokens.clear()
	_reset_next_stage_overlay_tween()
	_clear_next_stage_halo()
	_reset_stage_completion_positions()
	screen_shake_active = false
	timer_frozen = false
	next_stage_overlay_active = false
	ready_go_active = false
	ready_go_overlay.visible = false
	next_stage_overlay.visible = false
	next_stage_overlay.color.a = 0.0
	ingredient_slots.set_process_unhandled_input(true)
	GameRun.set_start_blocked(false)
	screen_shake_elapsed = 0.0
	_reset_screen_shake_position()


func _start_order(token: int) -> void:
	current_phase = Phase.ORDER_STARTING
	current_recipe = recipes[0]

	status_label.text = "New order"
	_display_current_recipes()
	if token != round_token:
		return
	_start_play(token)

func _start_play(token: int) -> void:
	if token != round_token:
		return
	current_phase = Phase.PLAYING
	status_label.text = "Tap ingredients in order"
	_setup_ingredient_slots(true)


func _on_blackout_requested() -> void:
	if not _can_start_blackout():
		GameRun.reject_blackout_request()
		return

	if not GameRun.accept_blackout_request():
		return

	blackout_event_active = true
	blackout_used_for_customer = true
	_run_blackout(round_token)


func _can_start_blackout() -> bool:
	if not visible:
		return false
	if current_phase != Phase.PLAYING:
		return false
	if ready_go_active or blackout_event_active or blackout_used_for_customer:
		return false
	return true


func _run_blackout(token: int) -> void:
	var warning_completed: bool = await _play_blackout_warning(token)
	if token != round_token or current_phase != Phase.PLAYING:
		_finish_blackout_event()
		return
	if not warning_completed:
		_finish_blackout_event()
		return

	store_light.texture = STORE_LIGHT_OFF_TEXTURE
	AudioManager.play_sfx(AudioManager.Sfx.LIGHT_OFF)
	blackout_overlay.color = Color(0, 0, 0, 0.95)
	blackout_overlay.visible = true
	await get_tree().create_timer(3.0).timeout
	if token != round_token:
		_finish_blackout_event()
		return
	blackout_overlay.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	AudioManager.play_sfx(AudioManager.Sfx.LIGHT_ON)
	_finish_blackout_event()


func _finish_blackout_event() -> void:
	if not blackout_event_active:
		return

	blackout_event_active = false
	blackout_overlay.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	GameRun.complete_blackout()


func _play_blackout_warning(token: int) -> bool:
	for i in range(2):
		AudioManager.play_sfx(AudioManager.Sfx.LIGHT_SPARK)
		for j in range(2):
			store_light.texture = STORE_LIGHT_FAIL_TEXTURE
			await get_tree().create_timer(BLACKOUT_WARNING_STEP_SECONDS).timeout
			if token != round_token or current_phase != Phase.PLAYING:
				return false

			store_light.texture = STORE_LIGHT_ON_TEXTURE
			await get_tree().create_timer(BLACKOUT_WARNING_STEP_SECONDS).timeout
			if token != round_token or current_phase != Phase.PLAYING:
				return false

		if i == 0:
			await get_tree().create_timer(BLACKOUT_WARNING_PAUSE_SECONDS).timeout
			if token != round_token or current_phase != Phase.PLAYING:
				return false

	return true


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


func _handle_next_stage_overlay_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_SPACE:
		return

	get_viewport().set_input_as_handled()
	next_stage_overlay_active = false
	_reset_next_stage_overlay_tween()
	_clear_next_stage_halo()
	next_stage_overlay.visible = false
	next_stage_overlay.color.a = 0.0
	GameRun.continue_to_next_stage()


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
		perfect_shine_landing_tokens.clear()
		next_stage_overlay_landing_tokens.clear()
		ComboManager.reset_combo()
		_show_wrong_input_feedback()
		return

	stack_landing_token += 1
	pending_stack_landing_tokens.append(stack_landing_token)
	if _should_play_perfect_shine_on_landing(ingredient):
		perfect_shine_landing_tokens.append(stack_landing_token)
	if _should_show_next_stage_overlay_on_landing(ingredient):
		next_stage_overlay_landing_tokens.append(stack_landing_token)
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
	var shine_token_index := perfect_shine_landing_tokens.find(token)
	if shine_token_index >= 0:
		perfect_shine_landing_tokens.remove_at(shine_token_index)
		_show_result_rank()
		_play_perfect_shine_behind_result_rank()
	var overlay_token_index := next_stage_overlay_landing_tokens.find(token)
	if overlay_token_index >= 0:
		next_stage_overlay_landing_tokens.remove_at(overlay_token_index)
		_show_next_stage_overlay(false)
	ComboManager.add_combo()
	UltimateManager.add_gauge_for_combo(ComboManager.combo)
	combo_counter.show_at_fixed_position()


func _should_play_perfect_shine_on_landing(ingredient: Ingredient) -> bool:
	if mistake_count > 0:
		return false
	if ingredient.id != PERFECT_SHINE_INGREDIENT_ID:
		return false
	var is_final_recipe := current_recipe_index + 1 >= recipes.size()
	var is_final_step := current_step + 1 >= current_recipe.ingredients.size()
	return is_final_recipe and is_final_step


func _should_show_next_stage_overlay_on_landing(ingredient: Ingredient) -> bool:
	if ingredient.id != PERFECT_SHINE_INGREDIENT_ID:
		return false
	if (customer.get("stage", 1) as int) >= GameRun.MAX_STAGE:
		return false
	var is_final_recipe := current_recipe_index + 1 >= recipes.size()
	var is_final_step := current_step + 1 >= current_recipe.ingredients.size()
	return is_final_recipe and is_final_step


func _wait_for_pending_stack_landings() -> void:
	while not pending_stack_landing_tokens.is_empty():
		await burger_stack.ingredient_landed
		await get_tree().process_frame


func _finish_current_burger() -> void:
	current_phase = Phase.SERVING
	status_label.text = "Burger complete"
	var is_final_recipe := current_recipe_index + 1 >= recipes.size()
	if is_final_recipe:
		_freeze_stage_timer()
		_disable_slots()

	await _wait_for_pending_stack_landings()
	if is_final_recipe:
		combo_counter.keep_visible()
	_play_recipe_completion_feedback(round_token)

	if is_final_recipe:
		status_label.text = "Stage complete"
		_show_medal_targets()
		await _play_stage_complete_presentation()
	else:
		status_label.text = "Burger served"
		await get_tree().create_timer(BURGER_SERVE_DELAY_SECONDS).timeout
		await _play_inter_order_burger_transition()
		await recipe_display_stack.complete_current_recipe()

	current_recipe_index += 1
	_update_order_progress_dots()

	if is_final_recipe:
		current_phase = Phase.COMPLETE
		customer["mistakes"] = mistake_count
		var should_show_next_stage_overlay := (customer.get("stage", 1) as int) < GameRun.MAX_STAGE
		order_completed.emit(true)
		if should_show_next_stage_overlay and visible:
			_show_next_stage_overlay(true)
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

	if recipes.size() <= 1:
		return

	for i in range(recipes.size()):
		var icon := TextureRect.new()
		icon.custom_minimum_size = ORDER_PROGRESS_ICON_SIZE
		icon.size = ORDER_PROGRESS_ICON_SIZE
		icon.texture = ORDER_PROGRESS_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
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
		icon.texture = ORDER_PROGRESS_TEXTURE
		icon.modulate.a = ORDER_PROGRESS_FILLED_ALPHA if index < filled_count else ORDER_PROGRESS_EMPTY_ALPHA


func _fail_customer() -> void:
	current_phase = Phase.COMPLETE
	_disable_slots()
	status_label.text = "Failed"
	order_completed.emit(false)


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


func _play_recipe_completion_feedback(token: int) -> void:
	if current_recipe_index + 1 < recipes.size() or mistake_count > 0:
		AudioManager.play_sfx(AudioManager.Sfx.ORDER_SUCCESS)
		return

	AudioManager.play_sfx(AudioManager.Sfx.ORDER_SUCCESS_PERFECT)
	if not result_rank.visible:
		_show_result_rank()
	if current_recipe_index + 1 >= recipes.size():
		return

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


func _on_time_changed(elapsed: float) -> void:
	if stage_timer_label == null:
		return
	if timer_frozen:
		return

	stage_timer_label.text = "%.3f" % elapsed


func _show_medal_targets() -> void:
	if medal_target_label == null:
		return

	medal_target_label.text = "Gold %.1fs\nSilver %.1fs\nBronze %.1fs" % [
		medal_targets.get("gold", 0.0),
		medal_targets.get("silver", 0.0),
		medal_targets.get("bronze", 0.0),
	]
	medal_target_label.visible = true


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


func _freeze_stage_timer() -> void:
	timer_frozen = true
	GameRun.set_start_blocked(true)
	stage_timer_label.text = "%.3f" % GameRun.elapsed_time


func _play_stage_complete_presentation() -> void:
	var recipe_exit_x := recipe_display_home_position.x + size.x + 120.0
	var burger_center_x := (global_position.x + size.x * 0.5) - plate_area.global_position.x
	var cook_board_center_x := burger_center_x - burger_stack_home_position.x + cook_board_home_position.x
	var tween := create_tween().set_parallel(true)
	tween.tween_property(recipe_display_stack, "position:x", recipe_exit_x, STAGE_COMPLETE_PRESENTATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(burger_stack, "position:x", burger_center_x, STAGE_COMPLETE_PRESENTATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cook_board, "position:x", cook_board_center_x, STAGE_COMPLETE_PRESENTATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func _play_perfect_shine_behind_result_rank() -> void:
	var shine := PERFECT_SHINE_SCENE.instantiate() as Node2D
	result_rank.add_child(shine)
	result_rank.move_child(shine, 0)
	shine.position = result_rank.size * 0.5
	shine.z_index = result_perfect.z_index - 1

	var particles := shine.get_node_or_null("GPUParticles2D") as GPUParticles2D
	if particles != null:
		particles.restart()
		particles.emitting = true

	var cleanup_delay := 1.6
	if particles != null:
		cleanup_delay = particles.lifetime + 0.4
	get_tree().create_timer(cleanup_delay).timeout.connect(_queue_free_if_valid.bind(shine), CONNECT_ONE_SHOT)


func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _play_inter_order_burger_transition() -> void:
	var outgoing := _snapshot_cook_and_burger()
	plate_area.add_child(outgoing)

	burger_stack.clear_stack()
	cook_board.position = cook_board_home_position + Vector2(INTER_ORDER_SLIDE_DISTANCE, 0.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(outgoing, "position:x", -INTER_ORDER_SLIDE_DISTANCE, BURGER_TRANSITION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(cook_board, "position", cook_board_home_position, BURGER_TRANSITION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	outgoing.queue_free()
	cook_board.position = cook_board_home_position


func _snapshot_cook_and_burger() -> Node2D:
	var root := Node2D.new()
	root.z_index = min(cook_board.z_index, burger_stack.z_index)

	var cook_snapshot := cook_board.duplicate() as Sprite2D
	root.add_child(cook_snapshot)
	cook_snapshot.position = cook_board.position

	var burger_snapshot := Node2D.new()
	root.add_child(burger_snapshot)
	burger_snapshot.position = burger_stack.position
	burger_snapshot.z_index = burger_stack.z_index
	for child in burger_stack.get_children():
		burger_snapshot.add_child(child.duplicate())

	return root


func _reset_stage_completion_positions() -> void:
	recipe_display_stack.position = recipe_display_home_position
	burger_stack.position = burger_stack_home_position
	cook_board.position = cook_board_home_position


func _show_next_stage_overlay(accept_input: bool = true) -> void:
	next_stage_overlay_active = next_stage_overlay_active or accept_input
	if next_stage_overlay.visible:
		return

	_show_next_stage_halo()
	_reset_next_stage_overlay_tween()
	next_stage_overlay.visible = true
	next_stage_overlay.color.a = 0.0
	next_stage_overlay_tween = create_tween()
	next_stage_overlay_tween.tween_property(next_stage_overlay, "color:a", NEXT_STAGE_OVERLAY_TARGET_ALPHA, NEXT_STAGE_OVERLAY_FADE_SECONDS)


func _reset_next_stage_overlay_tween() -> void:
	if next_stage_overlay_tween != null and next_stage_overlay_tween.is_valid():
		next_stage_overlay_tween.kill()
	next_stage_overlay_tween = null


func _show_next_stage_halo() -> void:
	_clear_next_stage_halo()
	next_stage_halo = NEXT_STAGE_HALO_SCENE.instantiate() as Node2D
	next_stage_halo.z_index = -1
	next_stage_halo.position = Vector2(0.0, -burger_stack.current_height * 0.5)
	next_stage_halo.scale = Vector2(0.65, 0.65)
	next_stage_halo.modulate.a = 0.0
	burger_stack.add_child(next_stage_halo)

	next_stage_halo_elapsed = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(next_stage_halo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(next_stage_halo, "modulate:a", 1.0, 0.12)


func _clear_next_stage_halo() -> void:
	if next_stage_halo != null and is_instance_valid(next_stage_halo):
		next_stage_halo.queue_free()
	next_stage_halo = null
	next_stage_halo_elapsed = 0.0


func _animate_next_stage_halo(delta: float) -> void:
	if next_stage_halo == null or not is_instance_valid(next_stage_halo):
		return

	next_stage_halo_elapsed += delta
	next_stage_halo.rotation += delta * 1.15
	if next_stage_halo_elapsed < 0.18:
		return
	var pulse := 1.0 + sin(next_stage_halo_elapsed * 4.2) * 0.055
	next_stage_halo.scale = Vector2(pulse, pulse)


func _display_current_recipes() -> void:
	recipe_display_stack.show_recipes(recipes.slice(current_recipe_index, recipes.size()))
	recipe_display_stack.set_current_step(current_step)


func _disable_slots() -> void:
	ingredient_slots.set_interaction_enabled(false)
