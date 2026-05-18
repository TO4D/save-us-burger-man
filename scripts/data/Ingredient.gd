extends Resource
class_name Ingredient

@export var id: String = ""
@export var display_name: String = ""
@export var sprite: Texture2D
@export var icon_sprite: Texture2D
@export var stack_height: int = 32
@export var stack_offset_y: int = 0
@export var sound_on_place: AudioStream
@export var unlock_level: int = 0
