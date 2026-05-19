extends Button
class_name UltimateBell

const READY_COLOR := Color(0.806, 0.699, 0.0, 1.0)
const IDLE_COLOR := Color(0.205, 0.205, 0.205, 1.0)
const DIM_COLOR := Color(0.46, 0.43, 0.39, 1.0)

@onready var fill_rect: TextureProgressBar = $Fill
@onready var glow_rect: TextureRect = $Glow
@onready var label: Label = $Label
@onready var gauge_label: Label = $GaugeLabel

var _base_position: Vector2


func _ready() -> void:
	_base_position = position
	pressed.connect(_on_pressed)
	UltimateManager.gauge_changed.connect(_on_gauge_changed)
	UltimateManager.ready_changed.connect(_on_ready_changed)
	UltimateManager.triggered.connect(_on_triggered)
	ComboManager.milestone_reached.connect(_on_combo_milestone)
	_on_gauge_changed(UltimateManager.gauge, UltimateManager.MAX_GAUGE)
	_on_ready_changed(UltimateManager.is_ready)


func _on_pressed() -> void:
	UltimateManager.trigger()


func _on_gauge_changed(value: int, max_value: int) -> void:
	var ratio := float(value) / float(max_value) if max_value > 0 else 0.0
	fill_rect.value = ratio * fill_rect.max_value
	gauge_label.text = "%d%%" % int(round(ratio * 100.0))


func _on_ready_changed(ready: bool) -> void:
	disabled = not ready
	label.modulate = READY_COLOR if ready else IDLE_COLOR
	gauge_label.modulate = READY_COLOR if ready else DIM_COLOR
	glow_rect.visible = ready
	if ready:
		_play_ready_bob()


func _on_triggered(_recovery_amount: float, _freeze_duration: float) -> void:
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
