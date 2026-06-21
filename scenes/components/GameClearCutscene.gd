extends Control

signal finished

const BURP_COLUMNS := 3
const BURP_ROWS := 2
const BURP_FRAME_COUNT := 6
const WALK_COLUMNS := 4
const WALK_ROWS := 3
const WALK_FRAME_COUNT := 12

@export var burp_fps: float = 12.0
@export var before_burp_hold_seconds: float = 1.0
@export var burp_hold_seconds: float = 2.0
@export var walk_fps: float = 8.0
@export var walk_duration: float = 6.0
@export var walk_move_interval: float = 1.0
@export var monster_scale: Vector2 = Vector2(2.0, 2.0)
@export var exit_padding: float = 2.0
@export var burp_texture: Texture2D
@export var walk_texture: Texture2D

@onready var monster_sprite: Sprite2D = $MonsterSprite

var _sequence_token := 0
var _monster_start_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_monster_start_position = monster_sprite.position
	_reset_monster_visual()
	hide()


func play_cutscene() -> void:
	_sequence_token += 1
	var token := _sequence_token
	_reset_monster_visual()
	show()
	_play_sequence(token)


func reset() -> void:
	_sequence_token += 1
	_reset_monster_visual()
	hide()


func _play_sequence(token: int) -> void:
	await get_tree().create_timer(before_burp_hold_seconds).timeout
	if token != _sequence_token:
		return

	await _play_burp(token)
	if token != _sequence_token:
		return

	await get_tree().create_timer(burp_hold_seconds).timeout
	if token != _sequence_token:
		return

	await _play_walk_exit(token)
	if token != _sequence_token:
		return

	finished.emit()


func _play_burp(token: int) -> void:
	monster_sprite.texture = burp_texture
	monster_sprite.hframes = BURP_COLUMNS
	monster_sprite.vframes = BURP_ROWS
	monster_sprite.frame = 0
	var frame_duration := 1.0 / maxf(burp_fps, 0.01)
	for frame_index in range(BURP_FRAME_COUNT):
		if token != _sequence_token:
			return
		monster_sprite.frame = frame_index
		await get_tree().create_timer(frame_duration).timeout


func _play_walk_exit(token: int) -> void:
	monster_sprite.texture = walk_texture
	monster_sprite.hframes = WALK_COLUMNS
	monster_sprite.vframes = WALK_ROWS
	monster_sprite.frame = 0

	var frame_size := Vector2(40.0, 50.0) * monster_scale
	var exit_x := size.x + frame_size.x * 0.5 + exit_padding
	var frame_duration := 1.0 / maxf(walk_fps, 0.01)
	var move_interval := maxf(walk_move_interval, frame_duration)
	var start_x := monster_sprite.position.x
	var elapsed := 0.0
	var next_move_at := move_interval
	var frame_index := 0
	while token == _sequence_token and elapsed < walk_duration:
		monster_sprite.frame = frame_index % WALK_FRAME_COUNT
		frame_index += 1
		await get_tree().create_timer(frame_duration).timeout
		elapsed += frame_duration
		if elapsed >= next_move_at:
			var progress := minf(next_move_at / walk_duration, 1.0)
			monster_sprite.position.x = lerpf(start_x, exit_x, progress)
			next_move_at += move_interval

	if token == _sequence_token:
		monster_sprite.position.x = exit_x


func _reset_monster_visual() -> void:
	if not is_node_ready():
		return
	monster_sprite.texture = burp_texture
	monster_sprite.hframes = BURP_COLUMNS
	monster_sprite.vframes = BURP_ROWS
	monster_sprite.frame = 0
	monster_sprite.position = _monster_start_position
	monster_sprite.scale = monster_scale
