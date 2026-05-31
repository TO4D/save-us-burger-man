extends TextureButton
class_name IngredientSlot

signal ingredient_picked(ingredient: Ingredient)

enum VisualState {
	NORMAL,
	FOCUSED,
	PRESSED,
	DISABLED,
}

var ingredient: Ingredient
var is_trap: bool = false
var interaction_enabled: bool = true
var _default_texture_normal: Texture2D
var _default_texture_focused: Texture2D
var _default_texture_pressed: Texture2D
var _default_texture_hover: Texture2D
var _pressed_visual_active: bool = false
var _pressed_visual_token: int = 0

@onready var visual: TextureRect = $Visual
@onready var focus_border: TextureRect = $FocusBorder


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self_modulate = Color(1, 1, 1, 0)
	_default_texture_normal = texture_normal
	_default_texture_focused = texture_focused if texture_focused != null else texture_hover
	_default_texture_pressed = texture_pressed
	_default_texture_hover = texture_hover
	pressed.connect(_on_pressed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_update_visuals)
	_update_visuals()


func set_slot_size(slot_size: float) -> void:
	var target_size := Vector2(slot_size, slot_size)
	custom_minimum_size = target_size
	size = target_size
	if visual != null:
		visual.size = target_size
	if focus_border != null:
		focus_border.size = target_size


func setup(ing: Ingredient, trap: bool = false) -> void:
	ingredient = ing
	is_trap = trap
	_pressed_visual_active = false
	visible = true
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_interaction_enabled(true)
	_update_visuals()


func clear_slot() -> void:
	_pressed_visual_token += 1
	_pressed_visual_active = false
	ingredient = null
	is_trap = false
	visible = false
	disabled = false
	if visual != null:
		visual.texture = _default_texture_normal
		visual.modulate = Color.WHITE
	if focus_border != null:
		focus_border.visible = false


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	_update_visuals()


func trigger_pick() -> void:
	_on_pressed()


func show_pressed_visual(duration: float = 0.06) -> void:
	_pressed_visual_token += 1
	var token := _pressed_visual_token
	_pressed_visual_active = true
	_update_visuals()
	await get_tree().create_timer(duration).timeout
	if token != _pressed_visual_token:
		return
	_pressed_visual_active = false
	_update_visuals()


func _resolve_visual_state() -> VisualState:
	if _pressed_visual_active:
		return VisualState.PRESSED
	if not interaction_enabled:
		return VisualState.DISABLED
	if has_focus():
		return VisualState.FOCUSED
	return VisualState.NORMAL


func _texture_for_state(state: VisualState) -> Texture2D:
	if ingredient == null:
		return _default_texture_normal

	var overlay := ingredient.icon_sprite if ingredient.icon_sprite != null else ingredient.sprite
	match state:
		VisualState.PRESSED:
			if ingredient.slot_button_pressed != null:
				return ingredient.slot_button_pressed
			return _compose_slot_texture(_default_texture_pressed, overlay)
		VisualState.FOCUSED:
			if ingredient.slot_button_focused != null:
				return ingredient.slot_button_focused
			if ingredient.slot_button_hover != null:
				return ingredient.slot_button_hover
			return _compose_slot_texture(_default_texture_focused, overlay)
		VisualState.DISABLED:
			if ingredient.slot_button_normal != null:
				return ingredient.slot_button_normal
			return _compose_slot_texture(_default_texture_normal, overlay)
		_:
			if ingredient.slot_button_normal != null:
				return ingredient.slot_button_normal
			return _compose_slot_texture(_default_texture_normal, overlay)


func _compose_slot_texture(base_texture: Texture2D, overlay_texture: Texture2D) -> Texture2D:
	if base_texture == null:
		return overlay_texture
	if overlay_texture == null:
		return base_texture

	var base_image := base_texture.get_image()
	var overlay_image := overlay_texture.get_image()
	if base_image == null or overlay_image == null:
		return base_texture

	var image := Image.create(base_image.get_width(), base_image.get_height(), false, Image.FORMAT_RGBA8)
	image.blit_rect(base_image, Rect2i(Vector2i.ZERO, base_image.get_size()), Vector2i.ZERO)

	var overlay_target_width := mini(overlay_image.get_width(), image.get_width() - 10)
	var overlay_target_height := mini(overlay_image.get_height(), image.get_height() - 10)
	var overlay_copy := overlay_image
	if overlay_copy.get_width() != overlay_target_width or overlay_copy.get_height() != overlay_target_height:
		overlay_copy = overlay_copy.duplicate()
		overlay_copy.resize(overlay_target_width, overlay_target_height, Image.INTERPOLATE_NEAREST)

	var destination := Vector2i(
		int((image.get_width() - overlay_copy.get_width()) * 0.5),
		int((image.get_height() - overlay_copy.get_height()) * 0.5)
	)
	image.blit_rect(overlay_copy, Rect2i(Vector2i.ZERO, overlay_copy.get_size()), destination)
	return ImageTexture.create_from_image(image)


func _update_visuals() -> void:
	if visual != null:
		var state := _resolve_visual_state()
		visual.texture = _texture_for_state(state)
		var tint := Color(0.7, 0.7, 0.7, 0.85) if is_trap else Color.WHITE
		tint.a = 1.0 if interaction_enabled else 0.72
		visual.modulate = tint
	if focus_border != null:
		focus_border.visible = has_focus()


func _on_pressed() -> void:
	if ingredient == null or not interaction_enabled:
		return
	AudioManager.play_sfx(AudioManager.Sfx.INGREDIENT_SLOT_SELECT)
	show_pressed_visual()
	ingredient_picked.emit(ingredient)


func _on_focus_entered() -> void:
	_update_visuals()
	if ingredient == null or not interaction_enabled:
		return
	AudioManager.play_sfx(AudioManager.Sfx.INGREDIENT_SLOT_FOCUS)
