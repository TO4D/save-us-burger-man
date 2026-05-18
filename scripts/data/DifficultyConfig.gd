extends Resource
class_name DifficultyConfig

@export var difficulty_name: String = "easy"
@export var difficulty_index: int = 0

# ingredient Pool
@export var ingredient_pool: Array[Ingredient] = []
@export var slot_pool: Array[Ingredient] = []

# reward
@export var base_reward: float = 1.0
@export var failure_reward_ratio: float = 0.1

# minigame parameter
@export var memory_show_time_base: float = 1.5
@export var memory_show_time_per_ingredient: float = 0.4
@export var memory_chances: int = 3

@export var speed_initial_time: float = 30.0
@export var speed_bonus_per_burger: float = 5.0

# recipe length
@export var min_recipe_length: int = 3
@export var max_recipe_length: int = 4
