extends Control

signal order_completed(success: bool)

const READY_OVERLAY_SECONDS := 2.0
const GO_OVERLAY_SECONDS := 0.6
const COMPLETED_BURGER_DISPLAY_SECONDS := 0.2
const DOMA_SLIDE_SECONDS := 0.15
const DOMA_ENTRY_SECONDS := 0.35
const PERFECT_BURGER_HALO_COLOR := Color(1.0, 0.88, 0.25, 0.9)
const NORMAL_BURGER_HALO_COLOR := Color(1.0, 1.0, 1.0, 0.588)
const PERFECT_BURGER_HALO_OUTLINE_SIZE := 1.5
const NORMAL_BURGER_HALO_OUTLINE_SIZE := 1.5
const PERFECT_BURGER_HALO_GLOW_SIZE := 4.0
const NORMAL_BURGER_HALO_GLOW_SIZE := 4.0
const PERFECT_BURGER_HALO_GLOW_STRENGTH := 0.38
const NORMAL_BURGER_HALO_GLOW_STRENGTH := 0.25
const DOMA_SLIDE_DISTANCE := 240.0
const STACK_VIEWPORT_SIZE := Vector2(180.0, 174.0)
const STACK_CAMERA_DEFAULT_POSITION := STACK_VIEWPORT_SIZE * 0.5
const STACK_CAMERA_TOP_MARGIN := 78.0
const STACK_CAMERA_TWEEN_SECONDS := 0.16
const STACK_CAMERA_RETURN_DELAY_SECONDS := 0.3
const STACK_CAMERA_RETURN_SECONDS := 0.3
const ULTIMATE_AUTO_STACK_DELAY_SECONDS := 0.01
const ULTIMATE_STACK_SPEED_MULTIPLIER := 2.0
const MONSTER_ULTIMATE_DELAY_MIN_SECONDS := 2.0
const MONSTER_ULTIMATE_DELAY_MAX_SECONDS := 5.0
const MONSTER_ULTIMATE_RETRY_DELAY_SECONDS := 1.0
const MONSTER_SLOT_EXIT_SECONDS := 0.16
const MONSTER_SLOT_RETURN_SECONDS := 0.42
const MONSTER_SLOT_SHUFFLE_WAIT_SECONDS := 0.5
const ORDER_PROGRESS_ICON_SIZE := Vector2(16.0, 16.0)
const ORDER_PROGRESS_FILL_TEXTURE := preload("res://assets/sprites/ui/order_icon.1.png")
const ORDER_PROGRESS_EMPTY_TEXTURE := preload("res://assets/sprites/ui/order_icon.2.png")
const STORE_LIGHT_ON_TEXTURE := preload("res://assets/sprites/store/light_on.png")
const STORE_LIGHT_OFF_TEXTURE := preload("res://assets/sprites/store/light_off.png")
const STORE_LIGHT_FAIL_TEXTURE := preload("res://assets/sprites/store/light_fail.png")
const COMPLETED_BURGER_HALO_SHADER := preload("res://resources/vfx/completed_burger_halo.gdshader")
const BLACKOUT_WARNING_STEP_SECONDS := 0.2
const BLACKOUT_WARNING_PAUSE_SECONDS := 0.6
const RESULT_LABEL_FLASH_SECONDS := 0.2
const RESULT_LABEL_FLASH_INTERVAL_SECONDS := 0.12
const RESULT_LABEL_FLASH_COUNT := 2
const RESULT_LABEL_FLASH_COLOR := Color.WHITE

enum Phase { IDLE, CUSTOMER_ENTERING, PLAYING, SERVING, CUSTOMER_EXITING, COMPLETE }

var current_phase: Phase = Phase.IDLE
var customer: Dictionary = {}
var recipes: Array = []
var current_recipe: Recipe = null
var current_recipe_index: int = 0
var current_step: int = 0
var fullness: float = 0.0
var knockback: float = 0.0
var round_token: int = 0
var doma_home_position: Vector2 = Vector2.ZERO
var is_mobile_input: bool = false
var mistake_count: int = 0
var order_started_at_msec: int = 0
var result_rank_tween: Tween = null
var result_label_flash_tween: Tween = null
var stack_landing_token: int = 0
var pending_stack_landing_tokens: Array[int] = []
var stack_camera_tween: Tween = null
var ready_go_active: bool = false
var blackout_event_active: bool = false
var blackout_used_for_customer: bool = false
var ultimate_active: bool = false
var monster_ultimate_active: bool = false
var monster_ultimate_schedule_token: int = 0
var foreground_slot_home_position: Vector2 = Vector2.ZERO
var ingredient_slots_home_position: Vector2 = Vector2.ZERO
var monster_slot_tween: Tween = null
var persistent_slot_ingredients: Array[Ingredient] = []
var gameplay_locked := false

@onready var battle_gauge: BattleGauge = $BattleGauge
@onready var recipe_display_stack: RecipeDisplayStack = $PlayArea/RecipeDisplayStack
@onready var stack_viewport_container: SubViewportContainer = $PlayArea/PlateArea/StackViewportContainer
@onready var stack_viewport: SubViewport = $PlayArea/PlateArea/StackViewportContainer/StackViewport
@onready var plate_stack_scene: Node2D = $PlayArea/PlateArea/StackViewportContainer/StackViewport/PlateStackScene
@onready var stack_camera: Camera2D = $PlayArea/PlateArea/StackViewportContainer/StackViewport/PlateStackScene/StackCamera
@onready var sprite_doma: Sprite2D = $PlayArea/PlateArea/StackViewportContainer/StackViewport/PlateStackScene/SpriteDoma
@onready var burger_stack: BurgerStack = $PlayArea/PlateArea/StackViewportContainer/StackViewport/PlateStackScene/BurgerStack
@onready var order_progress_dots: VBoxContainer = $PlayArea/PlateArea/OrderProgressDots
@onready var ingredient_slots: IngredientSlotGrid = $IngredientSlots
@onready var result_rank: Control = $ResultRank
@onready var result_label: Control = $ResultRank/Result_Label
@onready var result_label_shadow: Label = $ResultRank/Result_Label/shadow
@onready var result_label_text: Label = $ResultRank/Result_Label/text
@onready var result_time_label: Control = $ResultRank/Result_time_Label
@onready var result_time_label_shadow: Label = $ResultRank/Result_time_Label/shadow
@onready var result_time_label_text: Label = $ResultRank/Result_time_Label/text
@onready var blackout_overlay: ColorRect = $BlackoutOverlay
@onready var combo_counter: ComboCounter = $ComboCounter
@onready var foreground_slot: TextureRect = $Foreground_slot
@onready var multi_order: MultiOrder = $MultiOrder
@onready var ready_go_overlay: ColorRect = $ReadyGoOverlay
@onready var ultimate_overlay: UltimateOverlay = $UltimateOverlay
@onready var monster_ultimate_overlay: MonsterUltimateOverlay = $MonsterUltimateOverlay
@onready var ready_go_label: Label = $ReadyGoOverlay/Label
@onready var store_light: TextureRect = $StoreLight
@onready var ultimate_bell: UltimateBell = $UltimateBell

var result_label_shadow_settings: LabelSettings
var result_label_text_settings: LabelSettings
var result_label_shadow_color: Color
var result_label_text_color: Color


func _ready() -> void:
	_setup_result_label_flash()
	doma_home_position = sprite_doma.position
	foreground_slot_home_position = foreground_slot.position
	ingredient_slots_home_position = ingredient_slots.position
	is_mobile_input = OS.has_feature("mobile")
	UltimateManager.triggered.connect(_on_ultimate_triggered)
	UltimateManager.ready_changed.connect(_on_ultimate_ready_changed)
	MonsterManager.ultimate_threshold_reached.connect(_on_monster_ultimate_threshold_reached)
	GameRun.blackout_requested.connect(_on_blackout_requested)
	GameRun.run_started.connect(_on_run_started)
	burger_stack.ingredient_landed.connect(_on_stack_ingredient_landed)
	ingredient_slots.ingredient_picked.connect(_on_ingredient_picked)
	_reset_stack_camera()
	_sync_player_controls()



func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE:
		return

	if key_event.pressed and (ready_go_active or ultimate_active or monster_ultimate_active):
		get_viewport().set_input_as_handled()
		return

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_Z and _can_trigger_ultimate() and UltimateManager.trigger():
		get_viewport().set_input_as_handled()


func on_show(data: Dictionary = {}) -> void:
	gameplay_locked = false
	round_token += 1
	customer = data.get("customer", {})
	recipes = customer.get("recipes", [])
	fullness = customer.get("fullness", 0.0) as float
	knockback = customer.get("knockback", 0.0) as float
	multi_order.hide_order_count()
	if recipes.is_empty():
		push_error("[OrderPanel] No recipes provided.")
		return

	current_recipe_index = 0
	current_step = 0
	mistake_count = 0
	order_started_at_msec = 0
	blackout_event_active = false
	blackout_used_for_customer = false
	ultimate_active = false
	monster_ultimate_active = false
	monster_ultimate_schedule_token += 1
	pending_stack_landing_tokens.clear()
	blackout_overlay.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	_hide_result_rank()
	burger_stack.clear_stack()
	_reset_stack_camera()
	_setup_ingredient_slots(false)
	_reset_doma()
	_reset_ingredient_slot_panel_position()
	sprite_doma.visible = false
	_setup_order_progress_dots()
	_sync_player_controls()
	var token := round_token
	if data.get("show_ready_go", false):
		await _run_ready_go_overlay(token)
		if token != round_token:
			return
	_start_order(token)

func _on_run_started() -> void:
	var ingredients := GameState.get_slot_ingredients(1)
	var original_order := ingredients.duplicate()
	ingredients.shuffle()
	for _attempt in range(4):
		if ingredients != original_order:
			break
		ingredients.shuffle()
	persistent_slot_ingredients = ingredients

func on_hide() -> void:
	round_token += 1
	current_phase = Phase.IDLE
	if blackout_event_active:
		GameRun.complete_blackout()
	blackout_event_active = false
	blackout_used_for_customer = false
	ultimate_active = false
	monster_ultimate_active = false
	monster_ultimate_schedule_token += 1
	blackout_overlay.visible = false
	store_light.texture = STORE_LIGHT_ON_TEXTURE
	multi_order.hide_order_count()
	_hide_result_rank()
	recipe_display_stack.clear_recipes()
	_clear_order_progress_dots()
	ingredient_slots.set_interaction_enabled(false)
	ingredient_slots.clear_slots()
	burger_stack.clear_stack()
	_reset_stack_camera()
	pending_stack_landing_tokens.clear()
	_reset_doma()
	_reset_ingredient_slot_panel_position()
	ready_go_active = false
	ready_go_overlay.visible = false
	ultimate_overlay.cancel()
	monster_ultimate_overlay.cancel()
	GameRun.set_start_blocked(false)
	_sync_player_controls()


func _start_order(token: int) -> void:
	current_phase = Phase.CUSTOMER_ENTERING
	current_recipe = recipes[0]

	_display_current_recipes()
	await _enter_doma_from_right()
	if token != round_token:
		return
	multi_order.show_order_count(recipes.size())
	_start_play(token)

func _start_play(token: int) -> void:
	if token != round_token:
		return
	current_phase = Phase.PLAYING
	order_started_at_msec = Time.get_ticks_msec()
	_setup_ingredient_slots(true)
	_sync_player_controls()
	_schedule_monster_ultimate_if_pending(token)


func _on_blackout_requested() -> void:
	if not _can_start_blackout():
		GameRun.reject_blackout_request()
		return

	if not GameRun.accept_blackout_request():
		return

	blackout_event_active = true
	blackout_used_for_customer = true
	_sync_player_controls()
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
	_sync_player_controls()


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
	ready_go_overlay.modulate.a = 1.0
	ready_go_label.scale = Vector2.ONE
	ready_go_label.text = "Ready..."
	ready_go_overlay.visible = true
	_sync_player_controls()
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
	GameRun.set_start_blocked(false)
	_sync_player_controls()


func _setup_ingredient_slots(enabled: bool) -> void:
	var stage: int = customer.get("stage", 1) as int
	var ingredients: Array[Ingredient] = GameState.get_slot_ingredients(stage)
	if not persistent_slot_ingredients.is_empty():
		ingredients = _merge_persistent_slot_ingredients(ingredients)
	ingredient_slots.configure(ingredients, is_mobile_input, enabled)


func _on_ingredient_picked(ingredient: Ingredient) -> void:
	if gameplay_locked or ready_go_active or ultimate_active or monster_ultimate_active or current_phase != Phase.PLAYING or current_recipe == null:
		return

	var expected: Ingredient = current_recipe.ingredients[current_step]
	if ingredient.id != expected.id:
		mistake_count += 1
		pending_stack_landing_tokens.clear()
		ComboManager.reset_combo()
		_show_wrong_input_feedback()
		return

	_queue_stack_ingredient(ingredient)
	_update_stack_camera()
	current_step += 1
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
	if not ultimate_active:
		UltimateManager.add_gauge_for_combo(ComboManager.combo)
	combo_counter.show_at_fixed_position()


func _wait_for_pending_stack_landings() -> void:
	while not pending_stack_landing_tokens.is_empty():
		await burger_stack.ingredient_landed
		await get_tree().process_frame


func _finish_current_burger() -> void:
	current_phase = Phase.SERVING
	_sync_player_controls()
	await _wait_for_pending_stack_landings()
	var completion_was_perfect := mistake_count == 0
	_play_recipe_completion_feedback(round_token)

	await _slide_completed_burger_left(completion_was_perfect)
	await _play_burger_throw_attack(_fullness_per_burger(), _knockback_per_burger(), completion_was_perfect)
	await recipe_display_stack.complete_current_recipe()
	current_recipe_index += 1
	_update_order_progress_dots()

	if current_recipe_index >= recipes.size():
		current_phase = Phase.COMPLETE
		_sync_player_controls()
		order_completed.emit(true)
		return

	current_recipe = recipes[current_recipe_index]
	current_step = 0
	recipe_display_stack.set_current_step(current_step)
	burger_stack.clear_stack()
	await _enter_doma_from_right()
	current_phase = Phase.PLAYING
	_setup_ingredient_slots(true)
	_sync_player_controls()
	_schedule_monster_ultimate_if_pending(round_token)


func _setup_order_progress_dots() -> void:
	_clear_order_progress_dots()
	order_progress_dots.visible = not recipes.is_empty()

	if recipes.size() <= 1:
		return

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
	_sync_player_controls()
	order_completed.emit(false)


func _play_burger_throw_attack(fullness_amount: float, attack_knockback: float, completion_was_perfect: bool) -> void:
	var hit_monster := func() -> void:
		AudioManager.play_sfx(AudioManager.Sfx.ATTACK)
		MonsterManager.add_satiety(fullness_amount)
		print("[OrderPanel] Burger served fullness=%.1f, monster satiety=%.1f/%.1f" % [fullness_amount, MonsterManager.satiety, MonsterManager.MAX_SATIETY])
		DistanceManager.recover(attack_knockback)
	battle_gauge.burger_attack_hit.connect(hit_monster, CONNECT_ONE_SHOT)
	await battle_gauge.play_burger_attack(attack_knockback, completion_was_perfect)


func _fullness_per_burger() -> float:
	var burger_count := maxi(recipes.size(), 1)
	return fullness / float(burger_count)


func _knockback_per_burger() -> float:
	var burger_count := maxi(recipes.size(), 1)
	return knockback / float(burger_count)


func _show_wrong_input_feedback() -> void:
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


func _show_result_rank(is_perfect: bool) -> void:
	result_label.visible = true
	result_time_label.visible = true
	_set_result_time_label_text(_get_order_elapsed_seconds())
	_set_result_label_text("PERFECT" if is_perfect else "GREAT")
	if is_perfect:
		_start_result_label_flash()
	else:
		_stop_result_label_flash()

	if result_rank_tween != null and result_rank_tween.is_valid():
		result_rank_tween.kill()

	result_rank.visible = true
	result_rank.pivot_offset = result_rank.size * 0.5
	result_rank.scale = Vector2(1.2, 1.2)
	result_rank.modulate.a = 0.0
	result_rank_tween = create_tween().set_parallel(true)
	result_rank_tween.tween_property(result_rank, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_rank_tween.tween_property(result_rank, "modulate:a", 1.0, 0.08)


func _play_recipe_completion_feedback(_token: int) -> void:
	if current_recipe_index + 1 < recipes.size():
		AudioManager.play_sfx(AudioManager.Sfx.ORDER_SUCCESS)
		return

	var completion_was_perfect := mistake_count == 0
	AudioManager.play_sfx(AudioManager.Sfx.ORDER_SUCCESS_PERFECT if completion_was_perfect else AudioManager.Sfx.ORDER_SUCCESS)
	_show_result_rank(completion_was_perfect)


func _hide_result_rank() -> void:
	if result_rank_tween != null and result_rank_tween.is_valid():
		result_rank_tween.kill()
	result_rank_tween = null
	_stop_result_label_flash()
	result_rank.visible = false
	result_rank.scale = Vector2.ONE
	result_rank.modulate.a = 1.0
	_hide_result_rank_images()


func _hide_result_rank_images() -> void:
	result_label.visible = false
	result_time_label.visible = false


func _setup_result_label_flash() -> void:
	result_label_shadow_settings = _duplicate_label_settings(result_label_shadow)
	result_label_text_settings = _duplicate_label_settings(result_label_text)
	result_label_shadow_color = result_label_shadow_settings.font_color
	result_label_text_color = result_label_text_settings.font_color


func _duplicate_label_settings(label: Label) -> LabelSettings:
	if label.label_settings != null:
		var copied_settings := label.label_settings.duplicate() as LabelSettings
		label.label_settings = copied_settings
		return copied_settings

	var new_settings := LabelSettings.new()
	new_settings.font_color = label.get_theme_color("font_color")
	label.label_settings = new_settings
	return new_settings


func _set_result_label_text(value: String) -> void:
	result_label_shadow.text = value
	result_label_text.text = value


func _set_result_time_label_text(elapsed_seconds: float) -> void:
	var value := "%.2fs" % elapsed_seconds
	result_time_label_shadow.text = value
	result_time_label_text.text = value


func _get_order_elapsed_seconds() -> float:
	if order_started_at_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - order_started_at_msec) / 1000.0


func _start_result_label_flash() -> void:
	_stop_result_label_flash()
	_set_result_label_flash_color(RESULT_LABEL_FLASH_COLOR)
	result_label_flash_tween = create_tween().set_loops(RESULT_LABEL_FLASH_COUNT)
	result_label_flash_tween.tween_property(result_label_text_settings, "font_color", result_label_text_color, RESULT_LABEL_FLASH_SECONDS)
	result_label_flash_tween.parallel().tween_property(result_label_shadow_settings, "font_color", result_label_shadow_color, RESULT_LABEL_FLASH_SECONDS)
	result_label_flash_tween.tween_interval(RESULT_LABEL_FLASH_INTERVAL_SECONDS)
	result_label_flash_tween.tween_callback(_set_result_label_flash_color.bind(RESULT_LABEL_FLASH_COLOR))
	result_label_flash_tween.finished.connect(_restore_result_label_colors)


func _stop_result_label_flash() -> void:
	if result_label_flash_tween != null and result_label_flash_tween.is_valid():
		result_label_flash_tween.kill()
	result_label_flash_tween = null
	_restore_result_label_colors()


func _set_result_label_flash_color(color: Color) -> void:
	result_label_shadow_settings.font_color = color
	result_label_text_settings.font_color = color


func _restore_result_label_colors() -> void:
	if result_label_shadow_settings != null:
		result_label_shadow_settings.font_color = result_label_shadow_color
	if result_label_text_settings != null:
		result_label_text_settings.font_color = result_label_text_color


func _on_ultimate_triggered() -> void:
	if not _can_run_ultimate():
		return

	# 필살기 연출
	#battle_gauge.play_ultimate_barrage()

	_run_ultimate_sequence(round_token)


func _on_ultimate_ready_changed(ready: bool) -> void:
	if ready:
		AudioManager.play_sfx(AudioManager.Sfx.ULTIMATE_CHARGED)


func _on_monster_ultimate_threshold_reached() -> void:
	if not visible:
		return

	_schedule_monster_ultimate_if_pending(round_token)


func _queue_stack_ingredient(ingredient: Ingredient) -> int:
	stack_landing_token += 1
	pending_stack_landing_tokens.append(stack_landing_token)
	var speed_multiplier := ULTIMATE_STACK_SPEED_MULTIPLIER if ultimate_active else 1.0
	burger_stack.add_ingredient(ingredient, stack_landing_token, speed_multiplier)
	return stack_landing_token


func _wait_for_stack_landing(token: int) -> void:
	while pending_stack_landing_tokens.has(token):
		await burger_stack.ingredient_landed
		await get_tree().process_frame


func _run_ultimate_sequence(token: int) -> void:
	ultimate_active = true
	_sync_player_controls()
	AudioManager.play_sfx_while_paused(AudioManager.Sfx.ULTIMATE)
	await ultimate_overlay.play_once()
	if token != round_token:
		ultimate_active = false
		return
	await _auto_complete_current_recipe(token)
	ultimate_active = false
	if token != round_token:
		return
	_sync_player_controls()


func _run_monster_ultimate_sequence(token: int) -> void:
	monster_ultimate_active = true
	DistanceManager.hold_freeze()
	_sync_player_controls()
	await monster_ultimate_overlay.play_once()
	if token != round_token:
		DistanceManager.release_freeze()
		monster_ultimate_active = false
		return
	await _run_monster_slot_shuffle_effect(token)
	DistanceManager.release_freeze()
	monster_ultimate_active = false
	if token != round_token:
		return
	_sync_player_controls()


func _schedule_monster_ultimate_if_pending(token: int, delay_seconds: float = -1.0) -> void:
	if token != round_token or not MonsterManager.ultimate_pending:
		return
	if current_phase != Phase.PLAYING:
		return

	monster_ultimate_schedule_token += 1
	var schedule_token := monster_ultimate_schedule_token
	var wait_seconds := delay_seconds
	if wait_seconds < 0.0:
		wait_seconds = randf_range(MONSTER_ULTIMATE_DELAY_MIN_SECONDS, MONSTER_ULTIMATE_DELAY_MAX_SECONDS)

	_wait_then_try_monster_ultimate(token, schedule_token, wait_seconds)


func _wait_then_try_monster_ultimate(token: int, schedule_token: int, delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if token != round_token or schedule_token != monster_ultimate_schedule_token:
		return
	if not MonsterManager.ultimate_pending:
		return

	if not _can_run_monster_ultimate():
		_schedule_monster_ultimate_if_pending(token, MONSTER_ULTIMATE_RETRY_DELAY_SECONDS)
		return

	if not MonsterManager.consume_ultimate_pending():
		return

	await _run_monster_ultimate_sequence(token)
	_schedule_monster_ultimate_if_pending(token)


func _can_run_monster_ultimate() -> bool:
	return visible and current_phase == Phase.PLAYING and current_recipe != null and not ready_go_active and not ultimate_active and not monster_ultimate_active and not blackout_event_active


func _run_monster_slot_shuffle_effect(token: int) -> void:
	_reset_monster_slot_tween()
	var offscreen_offset := Vector2(0.0, size.y - foreground_slot_home_position.y + foreground_slot.size.y + 24.0)
	var foreground_exit_position := foreground_slot_home_position + offscreen_offset
	var slots_exit_position := ingredient_slots_home_position + offscreen_offset

	monster_slot_tween = create_tween().set_parallel(true)
	monster_slot_tween.tween_property(foreground_slot, "position", foreground_exit_position, MONSTER_SLOT_EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	monster_slot_tween.tween_property(ingredient_slots, "position", slots_exit_position, MONSTER_SLOT_EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await monster_slot_tween.finished
	if token != round_token:
		return

	ingredient_slots.shuffle_visible_ingredients()
	persistent_slot_ingredients = ingredient_slots.get_visible_ingredients()
	await get_tree().create_timer(MONSTER_SLOT_SHUFFLE_WAIT_SECONDS).timeout
	if token != round_token:
		return

	monster_slot_tween = create_tween().set_parallel(true)
	monster_slot_tween.tween_property(foreground_slot, "position", foreground_slot_home_position, MONSTER_SLOT_RETURN_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	monster_slot_tween.tween_property(ingredient_slots, "position", ingredient_slots_home_position, MONSTER_SLOT_RETURN_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await monster_slot_tween.finished
	monster_slot_tween = null


func _reset_ingredient_slot_panel_position() -> void:
	_reset_monster_slot_tween()
	foreground_slot.position = foreground_slot_home_position
	ingredient_slots.position = ingredient_slots_home_position


func _reset_monster_slot_tween() -> void:
	if monster_slot_tween != null and monster_slot_tween.is_valid():
		monster_slot_tween.kill()
	monster_slot_tween = null


func _merge_persistent_slot_ingredients(source_ingredients: Array[Ingredient]) -> Array[Ingredient]:
	var merged: Array[Ingredient] = []
	for saved_ingredient in persistent_slot_ingredients:
		if source_ingredients.has(saved_ingredient):
			merged.append(saved_ingredient)

	for ingredient in source_ingredients:
		if not merged.has(ingredient):
			merged.append(ingredient)

	return merged


func _auto_complete_current_recipe(token: int) -> void:
	if current_recipe == null:
		return

	for ingredient_index in range(current_step, current_recipe.ingredients.size()):
		if token != round_token or current_phase != Phase.PLAYING:
			return

		var ingredient: Ingredient = current_recipe.ingredients[ingredient_index]
		var landing_token := _queue_stack_ingredient(ingredient)
		_update_stack_camera()
		current_step += 1
		recipe_display_stack.set_current_step(current_step)
		await _wait_for_stack_landing(landing_token)
		if ingredient_index + 1 < current_recipe.ingredients.size():
			await get_tree().create_timer(ULTIMATE_AUTO_STACK_DELAY_SECONDS).timeout

	if token != round_token:
		return

	_update_order_progress_dots(current_recipe_index + 1)
	await _finish_current_burger()


func _sync_player_controls() -> void:
	var controls_enabled := visible and current_phase == Phase.PLAYING and not gameplay_locked and not ready_go_active and not ultimate_active and not monster_ultimate_active
	ingredient_slots.set_process_unhandled_input(controls_enabled)
	ingredient_slots.set_interaction_enabled(controls_enabled)
	if is_instance_valid(ultimate_bell):
		ultimate_bell.set_trigger_enabled(_can_trigger_ultimate())


func set_gameplay_locked(locked: bool) -> void:
	gameplay_locked = locked
	_sync_player_controls()


func _can_trigger_ultimate() -> bool:
	return visible and current_phase == Phase.PLAYING and current_recipe != null and not gameplay_locked and not ready_go_active and not ultimate_active and not monster_ultimate_active and not blackout_event_active and UltimateManager.is_ready


func _can_run_ultimate() -> bool:
	return visible and current_phase == Phase.PLAYING and current_recipe != null and not gameplay_locked and not ready_go_active and not ultimate_active and not monster_ultimate_active and not blackout_event_active



func _update_stack_camera(animated: bool = true) -> void:
	var target_position := STACK_CAMERA_DEFAULT_POSITION
	var default_visible_top := STACK_CAMERA_DEFAULT_POSITION.y - STACK_VIEWPORT_SIZE.y * 0.5
	var stack_top_y := burger_stack.position.y - burger_stack.current_height
	var target_visible_top := stack_top_y - STACK_CAMERA_TOP_MARGIN

	if target_visible_top < default_visible_top:
		target_position.y = target_visible_top + STACK_VIEWPORT_SIZE.y * 0.5

	target_position.y = roundf(target_position.y)
	if stack_camera_tween != null and stack_camera_tween.is_valid():
		stack_camera_tween.kill()
	stack_camera_tween = null

	if not animated:
		stack_camera.position = target_position
		return

	stack_camera_tween = create_tween()
	stack_camera_tween.tween_property(stack_camera, "position", target_position, STACK_CAMERA_TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_stack_camera() -> void:
	if stack_camera_tween != null and stack_camera_tween.is_valid():
		stack_camera_tween.kill()
	stack_camera_tween = null
	stack_camera.position = STACK_CAMERA_DEFAULT_POSITION


func _return_stack_camera_to_default() -> void:
	if stack_camera.position.is_equal_approx(STACK_CAMERA_DEFAULT_POSITION):
		return

	if stack_camera_tween != null and stack_camera_tween.is_valid():
		stack_camera_tween.kill()

	if STACK_CAMERA_RETURN_DELAY_SECONDS > 0.0:
		await get_tree().create_timer(STACK_CAMERA_RETURN_DELAY_SECONDS).timeout

	stack_camera_tween = create_tween()
	stack_camera_tween.tween_property(stack_camera, "position", STACK_CAMERA_DEFAULT_POSITION, STACK_CAMERA_RETURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await stack_camera_tween.finished
	stack_camera_tween = null


func _slide_completed_burger_left(completion_was_perfect: bool) -> void:
	var sliding_group := Node2D.new()
	add_child(sliding_group)
	sliding_group.global_position = Vector2.ZERO

	var stack_snapshot := await _create_stack_viewport_snapshot()
	var halo_snapshot := await _create_burger_stack_halo_snapshot()
	sliding_group.add_child(stack_snapshot)
	stack_snapshot.global_position = stack_viewport_container.global_position
	sliding_group.add_child(halo_snapshot)
	halo_snapshot.global_position = stack_viewport_container.global_position
	_apply_completed_burger_halo(halo_snapshot, completion_was_perfect)
	sprite_doma.visible = false

	burger_stack.clear_stack()

	await get_tree().create_timer(COMPLETED_BURGER_DISPLAY_SECONDS).timeout

	if stack_camera_tween != null and stack_camera_tween.is_valid():
		stack_camera_tween.kill()

	var tween: Tween = create_tween().set_parallel(true)
	stack_camera_tween = tween
	tween.tween_property(sliding_group, "position:x", sliding_group.position.x - DOMA_SLIDE_DISTANCE, DOMA_SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(stack_camera, "position", STACK_CAMERA_DEFAULT_POSITION, STACK_CAMERA_RETURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	stack_camera_tween = null
	sliding_group.queue_free()


func _apply_completed_burger_halo(snapshot: Sprite2D, completion_was_perfect: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = COMPLETED_BURGER_HALO_SHADER
	material.set_shader_parameter("halo_color", PERFECT_BURGER_HALO_COLOR if completion_was_perfect else NORMAL_BURGER_HALO_COLOR)
	material.set_shader_parameter("outline_size", PERFECT_BURGER_HALO_OUTLINE_SIZE if completion_was_perfect else NORMAL_BURGER_HALO_OUTLINE_SIZE)
	material.set_shader_parameter("glow_size", PERFECT_BURGER_HALO_GLOW_SIZE if completion_was_perfect else NORMAL_BURGER_HALO_GLOW_SIZE)
	material.set_shader_parameter("glow_strength", PERFECT_BURGER_HALO_GLOW_STRENGTH if completion_was_perfect else NORMAL_BURGER_HALO_GLOW_STRENGTH)
	snapshot.material = material


func _create_stack_viewport_snapshot() -> Sprite2D:
	var viewport_size := Vector2(stack_viewport.size)
	var snapshot_viewport := SubViewport.new()
	snapshot_viewport.transparent_bg = true
	snapshot_viewport.size = stack_viewport.size
	snapshot_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(snapshot_viewport)

	var doma_copy := _copy_sprite_for_snapshot(sprite_doma)
	doma_copy.position = sprite_doma.position - stack_camera.position + viewport_size * 0.5
	snapshot_viewport.add_child(doma_copy)

	var stack_copy := Node2D.new()
	stack_copy.position = burger_stack.position - stack_camera.position + viewport_size * 0.5
	stack_copy.z_index = burger_stack.z_index
	snapshot_viewport.add_child(stack_copy)

	for child in burger_stack.get_children():
		var source_sprite := child as Sprite2D
		if source_sprite == null:
			continue
		stack_copy.add_child(_copy_sprite_for_snapshot(source_sprite))

	await RenderingServer.frame_post_draw
	var image := snapshot_viewport.get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	snapshot_viewport.queue_free()

	var snapshot := Sprite2D.new()
	snapshot.texture = texture
	snapshot.centered = false
	snapshot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return snapshot


func _copy_sprite_for_snapshot(source: Sprite2D) -> Sprite2D:
	var copied_sprite := Sprite2D.new()
	copied_sprite.texture = source.texture
	copied_sprite.centered = source.centered
	copied_sprite.offset = source.offset
	copied_sprite.position = source.position
	copied_sprite.scale = source.scale
	copied_sprite.rotation = source.rotation
	copied_sprite.modulate = source.modulate
	copied_sprite.flip_h = source.flip_h
	copied_sprite.flip_v = source.flip_v
	copied_sprite.z_index = source.z_index
	copied_sprite.texture_filter = source.texture_filter
	return copied_sprite


func _create_burger_stack_halo_snapshot() -> Sprite2D:
	var viewport_size := Vector2(stack_viewport.size)
	var halo_viewport := SubViewport.new()
	halo_viewport.transparent_bg = true
	halo_viewport.size = stack_viewport.size
	halo_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(halo_viewport)

	var stack_copy := Node2D.new()
	stack_copy.position = burger_stack.position - stack_camera.position + viewport_size * 0.5
	halo_viewport.add_child(stack_copy)

	for child in burger_stack.get_children():
		var source_sprite := child as Sprite2D
		if source_sprite == null:
			continue

		var copied_sprite := Sprite2D.new()
		copied_sprite.texture = source_sprite.texture
		copied_sprite.centered = source_sprite.centered
		copied_sprite.offset = source_sprite.offset
		copied_sprite.position = source_sprite.position
		copied_sprite.scale = source_sprite.scale
		copied_sprite.rotation = source_sprite.rotation
		copied_sprite.modulate = source_sprite.modulate
		copied_sprite.texture_filter = source_sprite.texture_filter
		stack_copy.add_child(copied_sprite)

	await RenderingServer.frame_post_draw
	var image := halo_viewport.get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	halo_viewport.queue_free()

	var snapshot := Sprite2D.new()
	snapshot.texture = texture
	snapshot.centered = false
	snapshot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return snapshot


func _display_current_recipes() -> void:
	recipe_display_stack.show_recipes(recipes.slice(current_recipe_index, recipes.size()))
	recipe_display_stack.set_current_step(current_step)


func _enter_doma_from_right() -> void:
	sprite_doma.visible = true
	sprite_doma.modulate.a = 1.0
	sprite_doma.position = doma_home_position + Vector2(DOMA_SLIDE_DISTANCE, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite_doma, "position", doma_home_position, DOMA_ENTRY_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _reset_doma() -> void:
	sprite_doma.visible = true
	sprite_doma.position = doma_home_position
	sprite_doma.modulate.a = 1.0


func _disable_slots() -> void:
	ingredient_slots.set_interaction_enabled(false)
