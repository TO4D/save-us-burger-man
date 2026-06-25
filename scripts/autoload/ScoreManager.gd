extends Node

signal score_changed(score: int)
signal high_score_changed(high_score: int)

const POINTS_PER_INGREDIENT := 100
const PERFECT_BONUS_PER_INGREDIENT := 50
const POINTS_PER_COMBO := 10

var score := 0
var is_new_high_score := false


func reset_run() -> void:
	score = 0
	is_new_high_score = false
	score_changed.emit(score)


func add_completed_burger(ingredient_count: int, is_perfect: bool, combo: int) -> int:
	var safe_ingredient_count := maxi(ingredient_count, 0)
	var base_score := safe_ingredient_count * POINTS_PER_INGREDIENT
	var perfect_bonus := safe_ingredient_count * PERFECT_BONUS_PER_INGREDIENT if is_perfect else 0
	var combo_bonus := maxi(combo, 0) * POINTS_PER_COMBO
	var gained_score := base_score + perfect_bonus + combo_bonus

	score += gained_score
	score_changed.emit(score)
	return gained_score


func finish_run() -> bool:
	is_new_high_score = score > GameSettings.high_score
	if is_new_high_score:
		GameSettings.set_high_score(score)
		high_score_changed.emit(GameSettings.high_score)
	return is_new_high_score
