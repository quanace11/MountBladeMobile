class_name GestureParser
extends RefCounted
## Đọc một nét vuốt ở vùng chiến đấu (tay phải).
## - Kéo thẳng: gồng theo hướng kéo; nhả tay: chém.
## - Kiểu CHEVRON: nét có góc gấp (^ < > v) là đỡ; hướng đỡ là phía đỉnh góc; giữ tay là giữ đỡ.
## Hướng trả về là hướng theo màn hình, cũng là hướng theo nhân vật vì camera ở sau lưng.

var cfg: InputConfig
var scheme: int = InputConfig.BlockScheme.BUTTON

var attack_dir: int = Dir.NONE
var block_dir: int = Dir.NONE
var active: bool = false

var _start := Vector2.ZERO
var _far := Vector2.ZERO
var _current := Vector2.ZERO
var _release_pending := false


func _init(p_cfg: InputConfig, p_scheme: int) -> void:
	cfg = p_cfg
	scheme = p_scheme


func touch_down(pos: Vector2) -> void:
	active = true
	_start = pos
	_far = pos
	_current = pos
	attack_dir = Dir.NONE
	block_dir = Dir.NONE


func touch_move(pos: Vector2) -> void:
	if not active:
		return
	_current = pos
	if block_dir != Dir.NONE:
		return
	# Điểm xa nhất theo hướng đi ban đầu: nét quay đầu tại đây là góc gấp.
	var axis := _far - _start
	if axis.length() < 0.001:
		_far = pos
	elif (pos - _start).dot(axis.normalized()) > axis.length():
		_far = pos
	var leg1 := _far - _start
	if leg1.length() < cfg.swipe_min_distance:
		return
	if scheme == InputConfig.BlockScheme.CHEVRON:
		var leg2 := pos - _far
		if leg2.length() >= cfg.chevron_min_second_leg:
			var turn := rad_to_deg(absf(leg1.angle_to(leg2)))
			if turn >= cfg.chevron_min_turn_deg:
				var apex := _far - (_start + pos) * 0.5
				block_dir = Dir.from_screen_vector(apex)
				attack_dir = Dir.NONE
				return
		attack_dir = Dir.from_screen_vector(leg1)
	else:
		attack_dir = Dir.from_screen_vector(pos - _start)


func touch_up(_pos: Vector2) -> void:
	active = false
	if block_dir != Dir.NONE:
		block_dir = Dir.NONE
	elif attack_dir != Dir.NONE:
		_release_pending = true


## Trả về true một lần sau khi người chơi nhả tay để chém; sau đó xóa hướng gồng.
func consume_release() -> bool:
	if not _release_pending:
		return false
	_release_pending = false
	return true


func clear_after_release() -> void:
	attack_dir = Dir.NONE


## Dùng cho lớp vẽ: điểm đầu và điểm hiện tại của nét.
func stroke() -> PackedVector2Array:
	return PackedVector2Array([_start, _far, _current]) if active else PackedVector2Array()
