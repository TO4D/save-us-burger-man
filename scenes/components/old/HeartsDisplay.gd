extends HBoxContainer

# heart texture (temp box)
@export var heart_full_color: Color = Color(0.9, 0.3, 0.4)  # 빨강
@export var heart_empty_color: Color = Color(0.5, 0.5, 0.5, 0.5)  # 회색
@export var heart_size: Vector2 = Vector2(20, 20)

var max_chances: int = 3
var hearts: Array[ColorRect] = []

func setup(max_c: int) -> void:
	max_chances = max_c
	# 기존 하트 제거
	for child in get_children():
		child.queue_free()
	hearts.clear()

	# 하트 새로 만들기
	for i in max_chances:
		var heart = ColorRect.new()
		heart.color = heart_full_color
		heart.custom_minimum_size = heart_size
		add_child(heart)
		hearts.append(heart)

func update_chances(remaining: int) -> void:
	for i in hearts.size():
		hearts[i].color = heart_full_color if i < remaining else heart_empty_color

	# 잃을 때 흔들림 효과
	if remaining < hearts.size() and remaining >= 0:
		var lost_heart = hearts[remaining]
		var tween = create_tween()
		tween.tween_property(lost_heart, "rotation", 0.2, 0.05)
		tween.tween_property(lost_heart, "rotation", -0.2, 0.05)
		tween.tween_property(lost_heart, "rotation", 0.0, 0.05)
