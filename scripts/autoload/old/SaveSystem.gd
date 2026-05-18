extends Node

const SAVE_PATH: String = "user://savegame.dat"
const SAVE_VERSION: int = 1

# 저장 성공/실패 시그널 (필요 시 UI에서 활용)
signal save_completed(success: bool)
signal load_completed(success: bool)

func save_game() -> bool:
	var save_data = {
		"version": SAVE_VERSION,
		"money": GameState.money,
		"level": GameState.level,
		"unlocked_difficulties": GameState.unlocked_difficulties,
		"unlocked_ingredients": GameState.unlocked_ingredients,
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] 저장 파일 열기 실패: ", FileAccess.get_open_error())
		save_completed.emit(false)
		return false

	file.store_var(save_data)
	file.close()
	print("[SaveSystem] 저장 완료 (money: $", GameState.money, ", level: ", GameState.level, ")")
	save_completed.emit(true)
	return true
	
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveSystem] 저장 파일이 없음. 새 게임으로 시작.")
		load_completed.emit(false)
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveSystem] 저장 파일 읽기 실패: ", FileAccess.get_open_error())
		load_completed.emit(false)
		return false

	var save_data = file.get_var()
	file.close()

	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("[SaveSystem] 저장 파일이 손상되었습니다.")
		load_completed.emit(false)
		return false
	
	# 버전 체크
	var version = save_data.get("version", 0)
	if version != SAVE_VERSION:
		print("[SaveSystem] 버전 불일치 (", version, " → ", SAVE_VERSION, "). 마이그레이션 필요.")
		# MVP에서는 일단 그냥 로드. 추후 마이그레이션 로직 추가.
	
	# GameState로 복원
	GameState.money = save_data.get("money", 0.0)
	GameState.level = save_data.get("level", 1)
	GameState.unlocked_difficulties = save_data.get("unlocked_difficulties", [0])
	GameState.unlocked_ingredients = save_data.get(
		"unlocked_ingredients",
		["bun_top", "bun_bottom", "patty", "lettuce"]
	)
	
	print("[SaveSystem] 로드 완료 (money: $", GameState.money, ", level: ", GameState.level, ")")
	load_completed.emit(true)
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveSystem] 저장 파일 삭제됨")
