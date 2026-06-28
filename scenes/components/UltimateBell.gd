extends Button
class_name UltimateBell

@export var ready_gauge_modulate := Color.WHITE
@export var idle_gauge_modulate := Color(0.72, 0.72, 0.72, 1.0)
@export var empty_icon_texture: Texture2D = preload("res://assets/sprites/cook/gauge-star-empty.png")
@export var ready_icon_texture: Texture2D = preload("res://assets/sprites/cook/gauge-star-fill.png")
@export var gauge_fill_texture: Texture2D = preload("res://assets/sprites/cook/gauge-fill.png")
@export var gauge_fill_blink_texture: Texture2D = preload("res://assets/sprites/cook/gauge-fill-blink.png")
@export_range(1, 120, 1) var ready_blink_interval_frames: int = 10

@onready var gauge_progress: TextureProgressBar = $GaugeProgress
@onready var gauge_frame: TextureRect = $GaugeFrame
#@onready var star_icon: TextureRect = $StarIcon
@onready var glow_rect: ColorRect = $Glow

var _base_position: Vector2
var _trigger_enabled: bool = true
var _ready_blink_frame: int = 0
var _showing_blink_texture: bool = false


func _ready() -> void:
	_base_position = position
	pressed.connect(_on_pressed)
	UltimateManager.gauge_changed.connect(_on_gauge_changed)
	UltimateManager.ready_changed.connect(_on_ready_changed)
	UltimateManager.triggered.connect(_on_triggered)
	ComboManager.milestone_reached.connect(_on_combo_milestone)
	_on_gauge_changed(UltimateManager.gauge, UltimateManager.MAX_GAUGE)
	_on_ready_changed(UltimateManager.is_ready)


func _process(_delta: float) -> void:
	_ready_blink_frame += 1
	if _ready_blink_frame < ready_blink_interval_frames:
		return

	_ready_blink_frame = 0
	_showing_blink_texture = not _showing_blink_texture
	gauge_progress.texture_progress = gauge_fill_blink_texture if _showing_blink_texture else gauge_fill_texture


func set_trigger_enabled(enabled: bool) -> void:
	_trigger_enabled = enabled
	_apply_availability()


func _on_pressed() -> void:
	UltimateManager.trigger()


func _on_gauge_changed(value: int, max_value: int) -> void:
	gauge_progress.max_value = max_value
	gauge_progress.value = value


func _on_ready_changed(is_ready: bool) -> void:
	_apply_availability()
	_set_ready_blinking(is_ready)
	gauge_progress.modulate = ready_gauge_modulate if is_ready else idle_gauge_modulate
	gauge_frame.modulate = ready_gauge_modulate if is_ready else idle_gauge_modulate
	#star_icon.texture = ready_icon_texture if is_ready else empty_icon_texture
	glow_rect.visible = is_ready


func _set_ready_blinking(enabled: bool) -> void:
	_ready_blink_frame = 0
	_showing_blink_texture = false
	gauge_progress.texture_progress = gauge_fill_texture
	set_process(enabled)


func _on_triggered() -> void:
	position = _base_position
	var tween := create_tween().set_parallel(true)
	#tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(glow_rect, "modulate:a", 0.0, 0.18)
	#tween.chain().tween_property(self, "scale", Vector2.ONE, 0.12)
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


func _apply_availability() -> void:
	disabled = not UltimateManager.is_ready or not _trigger_enabled
