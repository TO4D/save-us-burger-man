extends Button
class_name UltimateBell

@export var ready_gauge_modulate := Color.WHITE
@export var idle_gauge_modulate := Color(0.72, 0.72, 0.72, 1.0)
@export var empty_icon_texture: Texture2D = preload("res://assets/sprites/cook/gauge-star-empty.png")
@export var ready_icon_texture: Texture2D = preload("res://assets/sprites/cook/gauge-star-fill.png")

@onready var gauge_progress: TextureProgressBar = $GaugeProgress
@onready var gauge_frame: TextureRect = $GaugeFrame
@onready var star_icon: TextureRect = $StarIcon
@onready var glow_rect: ColorRect = $Glow

var _base_position: Vector2
var _trigger_enabled: bool = true


func _ready() -> void:
	_base_position = position
	pressed.connect(_on_pressed)
	UltimateManager.gauge_changed.connect(_on_gauge_changed)
	UltimateManager.ready_changed.connect(_on_ready_changed)
	UltimateManager.triggered.connect(_on_triggered)
	ComboManager.milestone_reached.connect(_on_combo_milestone)
	_on_gauge_changed(UltimateManager.gauge, UltimateManager.MAX_GAUGE)
	_on_ready_changed(UltimateManager.is_ready)


func set_trigger_enabled(enabled: bool) -> void:
	_trigger_enabled = enabled
	_apply_availability()


func _on_pressed() -> void:
	UltimateManager.trigger()


func _on_gauge_changed(value: int, max_value: int) -> void:
	gauge_progress.max_value = max_value
	gauge_progress.value = value


func _on_ready_changed(ready: bool) -> void:
	_apply_availability()
	gauge_progress.modulate = ready_gauge_modulate if ready else idle_gauge_modulate
	gauge_frame.modulate = ready_gauge_modulate if ready else idle_gauge_modulate
	star_icon.texture = ready_icon_texture if ready else empty_icon_texture
	glow_rect.visible = ready
	if ready:
		_play_ready_bob()


func _on_triggered() -> void:
	position = _base_position
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(glow_rect, "modulate:a", 0.0, 0.18)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.chain().tween_property(glow_rect, "modulate:a", 0.18, 0.01)


func _on_combo_milestone(_value: int) -> void:
	if UltimateManager.is_ready:
		return

	glow_rect.visible = true
	glow_rect.modulate.a = 0.28
	var tween := create_tween()
	tween.tween_property(glow_rect, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		if not UltimateManager.is_ready:
			glow_rect.visible = false
			glow_rect.modulate.a = 0.18
	)


func _play_ready_bob() -> void:
	position = _base_position
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y - 3.0, 0.08)
	tween.tween_property(self, "position:y", _base_position.y, 0.08)


func _apply_availability() -> void:
	disabled = not UltimateManager.is_ready or not _trigger_enabled
