class_name TouchController
extends Node
## Nhận chạm đa điểm, chia ra: nửa trái là joystick di chuyển, nửa phải là vùng chiến đấu,
## và nút ĐỠ (khi dùng kiểu nút). Kết quả đọc qua move_vector(), combat, block_dir.

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


func setup(p_cfg: InputConfig, scheme: int) -> void:
	cfg = p_cfg
	combat = GestureParser.new(cfg, scheme)


func uses_block_button() -> bool:
	return combat.scheme == InputConfig.BlockScheme.BUTTON


func block_button_center() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	return cfg.block_button_center * size


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
	if uses_block_button() and block_index == -1 and pos.distance_to(block_button_center()) <= cfg.block_button_radius:
		block_index = index
		block_touch_pos = pos
		block_button_dir = Dir.UP
	elif pos.x < size.x * cfg.left_zone_ratio and joy_index == -1:
		joy_index = index
		joy_origin = pos
		joy_pos = pos
	elif combat_index == -1 and pos.x >= size.x * cfg.left_zone_ratio:
		combat_index = index
		combat.touch_down(pos)


func _on_move(index: int, pos: Vector2) -> void:
	if index == joy_index:
		joy_pos = pos
	elif index == combat_index:
		combat.touch_move(pos)
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
	elif index == block_index:
		block_index = -1
		block_button_dir = Dir.NONE


## Vector joystick theo màn hình, x sang phải, y xuống dưới, độ dài 0..1.
func move_vector() -> Vector2:
	if joy_index == -1:
		return Vector2.ZERO
	var v := (joy_pos - joy_origin) / cfg.joystick_radius
	v = v.limit_length(1.0)
	return Vector2.ZERO if v.length() < cfg.joystick_deadzone else v


func block_dir() -> int:
	if block_button_dir != Dir.NONE:
		return block_button_dir
	return combat.block_dir
