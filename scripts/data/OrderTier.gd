extends Resource
class_name OrderTier

# 등급 식별
@export var tier_id: String = ""       # "tier_1", "tier_2", ...
@export var star_count: int = 1         # 별점 1~4

# 보상
@export var base_reward: int = 1    # 메모리 게임 기준 보상
# 스피드는 햄버거 개수만큼 곱해진다고 가정 (코드에서 처리)
@export var failure_reward_ratio: float = 0.1

# 레시피 구성
@export var min_recipe_length: int = 2  # 빵 사이 재료 수 최소
@export var max_recipe_length: int = 3  # 빵 사이 재료 수 최대

# 스피드 게임에서 햄버거 개수 범위 (메모리는 항상 1)
@export var speed_burger_count_min: int = 2
@export var speed_burger_count_max: int = 3
