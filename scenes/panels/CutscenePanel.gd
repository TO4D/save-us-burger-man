extends Control

signal cutscene_finished

@export var cutscene_images: Array[Texture2D] = []

@onready var scene_image: TextureRect = $Center/SceneFrame/SceneImage
@onready var progress_label: Label = $Footer/ProgressLabel
@onready var next_button: Button = $Footer/NextButton

var _current_index := 0


func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)


func on_show(_data: Dictionary = {}) -> void:
	_current_index = 0
	_show_current_scene()


func _show_current_scene() -> void:
	var scene_count := cutscene_images.size()
	if scene_count == 0:
		push_warning("CutscenePanel has no cutscene images assigned.")
		cutscene_finished.emit()
		return

	scene_image.texture = cutscene_images[_current_index]
	progress_label.text = "%d / %d" % [_current_index + 1, scene_count]
	next_button.text = "Start" if _current_index == scene_count - 1 else "Next"


func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= cutscene_images.size():
		cutscene_finished.emit()
		return

	_show_current_scene()
