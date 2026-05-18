extends Resource
class_name MinigameConstants

# 공통
@export var failure_reward_ratio: float = 0.1  # 실패 시 최소 보상 비율 (실패한 경우만)

# 메모리 게임
@export var memory_show_time_base: float = 1.5
@export var memory_show_time_per_ingredient: float = 0.4
@export var memory_chances: int = 3

# 스피드 게임
@export var speed_initial_time: float = 30.0
@export var speed_bonus_per_burger: float = 5.0
