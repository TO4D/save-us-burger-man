extends Control
class_name SatietyGauge

@export var empty_gauge_modulate := Color(0.72, 0.72, 0.72, 1.0)
@export var filled_gauge_modulate := Color.WHITE

@onready var gauge_progress: TextureProgressBar = $GaugeProgress
@onready var gauge_frame: TextureRect = $GaugeFrame
@onready var percent_label: Label = $IconLabelWrapper/PercentLabel


func _ready() -> void:
	MonsterManager.satiety_changed.connect(_on_satiety_changed)
	_on_satiety_changed(MonsterManager.satiety, MonsterManager.MAX_SATIETY)


func _on_satiety_changed(value: float, max_value: float) -> void:
	var ratio := value / max_value if max_value > 0.0 else 0.0
	var percent := clampi(roundi(ratio * 100.0), 0, 100)

	gauge_progress.max_value = max_value
	gauge_progress.value = clampf(value, 0.0, max_value)
	percent_label.text = "%d%%" % percent

	var gauge_modulate := filled_gauge_modulate if value > 0.0 else empty_gauge_modulate
	gauge_progress.modulate = gauge_modulate
	gauge_frame.modulate = gauge_modulate
