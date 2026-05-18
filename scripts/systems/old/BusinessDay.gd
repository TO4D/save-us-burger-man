extends Node

enum TimeSlot { MORNING, LUNCH, EVENING }

# 시간대별 설정
const TIME_SLOT_CONFIG = {
	TimeSlot.MORNING: { "customers": 1, "memory_ratio": 0.7 },
	TimeSlot.LUNCH:   { "customers_min": 2, "customers_max": 6, "memory_ratio": 0.3 },
	TimeSlot.EVENING: { "customers": 1, "memory_ratio": 0.5 }
}

# OrderTier .tres 파일 경로 (등급 1~4)
const TIER_RESOURCE_PATHS: Array[String] = [
	"",  # 인덱스 0 자리 비움 (별점 1부터 시작)
	"res://resources/order_tiers/tier_1.tres",
	"res://resources/order_tiers/tier_2.tres",
	"res://resources/order_tiers/tier_3.tres",
	"res://resources/order_tiers/tier_4.tres",
]

# 영업 중 여부
var is_open: bool = false

# 손님 큐
var customer_queue: Array = []
var current_customer_index: int = 0

# 시간대별 매출 (정산용)
var revenue_by_slot: Dictionary = {}

signal time_slot_changed(slot: TimeSlot)
signal day_ended()
signal business_state_changed(is_open: bool)

func start_day() -> void:
	customer_queue = _generate_todays_customers()
	current_customer_index = 0
	revenue_by_slot = {
		TimeSlot.MORNING: 0,
		TimeSlot.LUNCH: 0,
		TimeSlot.EVENING: 0
	}
	GameState.reset_daily_stats()
	print("[BusinessDay] 영업 시작! 오늘 손님 ", customer_queue.size(), "명")
	
	is_open = true
	business_state_changed.emit(is_open)
	
func end_day() -> void:
	is_open = false
	business_state_changed.emit(is_open)
	day_ended.emit()

func _generate_todays_customers() -> Array:
	var customers = []
	for slot in TimeSlot.values():
		var config = TIME_SLOT_CONFIG[slot]
		var count = config.get("customers", 0)
		if count == 0:
			count = randi_range(config.customers_min, config.customers_max)

		for i in count:
			customers.append(_generate_one_customer(slot, config))
	return customers
	
func _generate_one_customer(slot: TimeSlot, slot_config: Dictionary) -> Dictionary:
	# 미니게임 종류 결정
	var minigame_type = "memory" if randf() < slot_config.memory_ratio else "speed"

	# 등급 결정 (진행도 기반 분포)
	var tier = _pick_tier_by_distribution()
	
	# 레시피 생성
	var recipes: Array[Recipe] = []
	if minigame_type == "memory":
		recipes.append(RecipeGenerator.generate(tier))
	else:
		# 스피드는 등급에 따라 햄버거 개수가 다름
		var burger_count = randi_range(tier.speed_burger_count_min, tier.speed_burger_count_max)
		for j in burger_count:
			recipes.append(RecipeGenerator.generate(tier))
	
	# 보상 미리 계산 (수락 결정에 표시될 금액)
	var reward = round(_calculate_reward(tier, minigame_type, recipes.size()))

	return {
		"time_slot": slot,
		"minigame_type": minigame_type,
		"tier": tier,
		"recipes": recipes,
		"reward": reward
	}
	
func _pick_tier_by_distribution() -> OrderTier:
	var distribution: Dictionary = GameState.get_tier_distribution()
	var roll = randf()
	var cumulative = 0.0

	for star_count in [1, 2, 3, 4]:
		cumulative += distribution.get(star_count, 0.0)
		if roll <= cumulative:
			return _load_tier(star_count)

	# 안전장치: 분포 합이 1.0이 안 되는 경우
	return _load_tier(1)

func _load_tier(star_count: int) -> OrderTier:
	if star_count < 1 or star_count >= TIER_RESOURCE_PATHS.size():
		push_error("[BusinessDay] 잘못된 star_count: ", star_count)
		return null
	return load(TIER_RESOURCE_PATHS[star_count]) as OrderTier
	
func _calculate_reward(tier: OrderTier, minigame_type: String, burger_count: int) -> float:
	if minigame_type == "memory":
		return tier.base_reward
	else:
		# 스피드는 햄버거 개수만큼 곱
		return tier.base_reward * burger_count
		

func get_next_customer() -> Dictionary:
	if current_customer_index >= customer_queue.size():
		return {}
	var customer = customer_queue[current_customer_index]
	current_customer_index += 1
	return customer

func is_day_over() -> bool:
	return current_customer_index >= customer_queue.size()

func record_revenue(amount: int, slot: TimeSlot) -> void:
	revenue_by_slot[slot] = revenue_by_slot.get(slot, 0) + amount
	

func get_current_customer_info() -> Dictionary:
	# 방금 가져온 손님 정보 다시 보기 (인덱스가 이미 증가했으니 -1)
	if current_customer_index == 0 or current_customer_index > customer_queue.size():
		return {}
	return customer_queue[current_customer_index - 1]
