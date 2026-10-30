class_name KeyboardController
extends RefCounted
## Bàn phím để thử nhanh trên PC.
## WASD: đi. Q/E: xoay người. Space: lăn né. Giữ I/J/K/L: gồng trên/trái/đâm/phải, nhả để chém. Giữ phím mũi tên: đỡ theo hướng đó.

var _held_attack: int = Dir.NONE
var _release := false
var _space_down := false

const ATTACK_KEYS := {KEY_I: Dir.UP, KEY_K: Dir.THRUST, KEY_J: Dir.LEFT, KEY_L: Dir.RIGHT}
const BLOCK_KEYS := {KEY_UP: Dir.UP, KEY_DOWN: Dir.THRUST, KEY_LEFT: Dir.LEFT, KEY_RIGHT: Dir.RIGHT}


func move_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_key_pressed(KEY_D): v.x += 1.0
	if Input.is_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_key_pressed(KEY_S): v.y += 1.0
	return v.limit_length(1.0)


## -1 xoay trái, 1 xoay phải.
static func turn_axis() -> float:
	var v := 0.0
	if Input.is_key_pressed(KEY_Q): v -= 1.0
	if Input.is_key_pressed(KEY_E): v += 1.0
	return v


## true một lần mỗi lần ấn Space.
func consume_dodge() -> bool:
	var now := Input.is_key_pressed(KEY_SPACE)
	var pressed := now and not _space_down
	_space_down = now
	return pressed


func block_dir() -> int:
	for key in BLOCK_KEYS:
		if Input.is_key_pressed(key):
			return BLOCK_KEYS[key]
	return Dir.NONE


## Gọi mỗi tick: cập nhật hướng gồng và phát hiện nhả phím.
func poll_attack() -> void:
	var now := Dir.NONE
	for key in ATTACK_KEYS:
		if Input.is_key_pressed(key):
			now = ATTACK_KEYS[key]
			break
	if now == Dir.NONE and _held_attack != Dir.NONE:
		_release = true
	elif now != Dir.NONE:
		_held_attack = now


func attack_dir() -> int:
	return _held_attack


func consume_release() -> bool:
	if not _release:
		return false
	_release = false
	_held_attack = Dir.NONE
	return true
