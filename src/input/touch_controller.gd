class_name TouchController
extends Node
## Nhận chạm đa điểm. Nửa trái là joystick di chuyển. Nửa phải:
## - Kiểu nút (mặc định): nút CHÉM và nút ĐỠ sát góc phải dưới, giữ và kéo để chọn hướng;
##   khi tự ngắm thì mọi chỗ trống còn lại là vùng kéo để xoay người.
## - Kiểu vuốt: vùng vuốt chém (GestureParser), nút ĐỠ hoặc vuốt gấp khúc;
##   khi tự ngắm thì phần trên là vùng kéo để xoay người.
## Kết quả đọc qua move_vector(), attack_dir(), consume_release(), block_dir(), consume_look().

var cfg: InputConfig
var combat: GestureParser

## Joystick: tâm, vị trí ngón tay, chỉ số chạm (-1 = không chạm).
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_index: int = -1

var combat_index: int = -1
var block_index: int = -1
var block_button_dir: int = Dir.NONE
var block_touch_pos := Vector2.ZERO

## Chém bằng nút CHÉM thay vì vuốt cả vùng.
var attack_button := true
var attack_index: int = -1
var attack_button_dir: int = Dir.NONE
var attack_touch_pos := Vector2.ZERO
var _attack_release_dir: int = Dir.NONE
var _attack_down_ms: int = 0
## Giữ nút CHÉM mà chưa kéo quá khoảng này (ms) thì mới gồng bổ. Kéo ngay thì gồng thẳng
## theo hướng kéo, không phải gồng bổ rồi gồng lại từ đầu.
const ATTACK_DEFAULT_DELAY_MS := 150
## Hệ số cỡ nút, hệ số độ nhạy xoay (từ cài đặt người chơi).
var button_scale := 1.0
var look_mult := 1.0

## Bật vùng kéo xoay người (chế độ tự ngắm).
var free_look := true
var look_index: int = -1
var look_pos := Vector2.ZERO
var _look_accum := 0.0


func setup(p_cfg: InputConfig, scheme: int) -> void:
	cfg = p_cfg
	combat = GestureParser.new(cfg, scheme)


func uses_block_button() -> bool:
	return attack_button or combat.scheme == InputConfig.BlockScheme.BUTTON


func block_button_center() -> Vector2:
	return cfg.block_button_center * get_viewport().get_visible_rect().size


func block_button_radius() -> float:
	return cfg.block_button_radius * button_scale


func attack_button_center() -> Vector2:
	return cfg.attack_button_center * get_viewport().get_visible_rect().size


func attack_button_radius() -> float:
	return cfg.attack_button_radius * button_scale


func _input(event: InputEvent) -> void:
	if cfg == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_down(t.index, t.position)
		else:
			_on_up(t.index, t.position)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_move(d.index, d.position)


func _on_down(index: int, pos: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	if pos.y < size.y * cfg.ignore_top_ratio:
		return
	var right_side := pos.x >= size.x * cfg.left_zone_ratio
	if attack_button and attack_index == -1 and pos.distance_to(attack_button_center()) <= attack_button_radius():
		attack_index = index
		attack_touch_pos = pos
		attack_button_dir = Dir.NONE
		_attack_down_ms = Time.get_ticks_msec()
	elif uses_block_button() and block_index == -1 and pos.distance_to(block_button_center()) <= block_button_radius():
		block_index = index
		block_touch_pos = pos
		block_button_dir = Dir.UP
	elif not right_side:
		if joy_index == -1:
			joy_index = index
			joy_origin = pos
			joy_pos = pos
	elif free_look and look_index == -1 and (attack_button or pos.y < size.y * cfg.look_zone_bottom_ratio):
		look_index = index
		look_pos = pos
	elif not attack_button and combat_index == -1:
		combat_index = index
		combat.touch_down(pos)


func _on_move(index: int, pos: Vector2) -> void:
	if index == joy_index:
		joy_pos = pos
	elif index == combat_index:
		combat.touch_move(pos)
	elif index == look_index:
		# Đổi px màn hình thực về px thiết kế để độ nhạy giống nhau trên mọi máy.
		var k := 720.0 / maxf(1.0, get_viewport().get_visible_rect().size.y)
		_look_accum += (pos.x - look_pos.x) * k
		look_pos = pos
	elif index == attack_index:
		attack_touch_pos = pos
		var v := pos - attack_button_center()
		if v.length() >= cfg.swipe_min_distance * 0.5:
			attack_button_dir = Dir.from_screen_vector(v)
	elif index == block_index:
		block_touch_pos = pos
		var v := pos - block_button_center()
		if v.length() >= cfg.swipe_min_distance * 0.5:
			block_button_dir = Dir.from_screen_vector(v)


func _on_up(index: int, pos: Vector2) -> void:
	if index == joy_index:
		joy_index = -1
	elif index == combat_index:
		combat_index = -1
		combat.touch_up(pos)
	elif index == attack_index:
		attack_index = -1
		# Bấm rồi nhả không kéo là bổ.
		_attack_release_dir = attack_button_dir if attack_button_dir != Dir.NONE else Dir.UP
		attack_button_dir = Dir.NONE
	elif index == block_index:
		block_index = -1
		block_button_dir = Dir.NONE
	elif index == look_index:
		look_index = -1


## Góc xoay (radian, dương là quay phải) do kéo vùng xoay từ lần đọc trước.
func consume_look() -> float:
	var a := deg_to_rad(_look_accum * cfg.look_sensitivity_deg * look_mult)
	_look_accum = 0.0
	return a


## Vector joystick theo màn hình, x sang phải, y xuống dưới, độ dài 0..1.
func move_vector() -> Vector2:
	if joy_index == -1:
		return Vector2.ZERO
	var v := (joy_pos - joy_origin) / cfg.joystick_radius
	v = v.limit_length(1.0)
	return Vector2.ZERO if v.length() < cfg.joystick_deadzone else v


## Hướng đang gồng (nút CHÉM hoặc nét vuốt). NONE = không gồng.
func attack_dir() -> int:
	if attack_button_dir != Dir.NONE:
		return attack_button_dir
	if attack_index != -1 and Time.get_ticks_msec() - _attack_down_ms >= ATTACK_DEFAULT_DELAY_MS:
		return Dir.UP
	return combat.attack_dir


## Trả về hướng chém một lần sau khi người chơi nhả tay; NONE nếu chưa nhả.
func consume_release() -> int:
	if _attack_release_dir != Dir.NONE:
		var d := _attack_release_dir
		_attack_release_dir = Dir.NONE
		return d
	if combat.consume_release():
		var d := combat.attack_dir
		combat.clear_after_release()
		return d
	return Dir.NONE


func block_dir() -> int:
	if block_button_dir != Dir.NONE:
		return block_button_dir
	return combat.block_dir
