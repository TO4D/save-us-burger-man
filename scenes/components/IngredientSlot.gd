extends TextureButton
class_name IngredientSlot

signal ingredient_picked(ingredient: Ingredient)

var ingredient: Ingredient
var is_trap: bool = false

@onready var sprite: Sprite2D = $IngredientSprite
@onready var new_badge: Label = $NewBadge 

func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	pressed.connect(_on_pressed)


func set_slot_size(slot_size: float) -> void:
	var target_size := Vector2(slot_size, slot_size)
	custom_minimum_size = target_size
	size = target_size
	if sprite != null:
		sprite.position = Vector2(slot_size * 0.5, slot_size * 0.5)
		# sprite.scale = Vector2.ONE * (0.4 * slot_size / 50.0)
	if new_badge != null:
		new_badge.offset_right = slot_size
		new_badge.offset_bottom = slot_size * 0.46

func setup(ing: Ingredient, trap: bool = false) -> void:
	ingredient = ing
	is_trap = trap
	sprite.texture = ing.icon_sprite if ing.icon_sprite != null else ing.sprite
	modulate = Color(0.7, 0.7, 0.7, 0.85) if trap else Color.WHITE

func show_new_badge() -> void:
	new_badge.visible = true
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): new_badge.visible = false)

func _on_pressed() -> void:
	if ingredient == null:
		return
	ingredient_picked.emit(ingredient)
	
	# pressed animation
	#var tween = create_tween()
	#tween.tween_property(self, "scale", Vector2(0.95,0.95), 0.05)
	#tween.tween_property(self, "scale", Vector2.ONE, 0.05)
