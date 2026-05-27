extends Sprite2D
class_name MultiOrder

@onready var count_label: Label = $Count


func show_order_count(order_count: int) -> void:
	visible = order_count > 1
	count_label.text = "x%d" % order_count


func hide_order_count() -> void:
	visible = false
