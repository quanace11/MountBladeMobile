class_name TouchOverlay
extends Control
## Vẽ joystick, nút CHÉM, nút ĐỠ, nét vuốt và vùng kéo xoay người. Chỉ đọc TouchController.

var touch: TouchController
var _font: Font


func setup(p_touch: TouchController) -> void:
	touch = p_touch
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if touch == null or touch.cfg == null:
		return
	var cfg := touch.cfg
	var size := get_viewport_rect().size
	var white := Color(1, 1, 1, 0.35)

	# Joystick: khi chưa chạm thì vẽ mờ ở góc trái dưới để người chơi biết chỗ.
	var origin := touch.joy_origin if touch.joy_index != -1 else Vector2(size.x * 0.14, size.y * 0.74)
	draw_circle(origin, cfg.joystick_radius, Color(0, 0, 0, 0.18))
	draw_arc(origin, cfg.joystick_radius, 0, TAU, 40, white, 2.0)
	var knob := origin + touch.move_vector() * cfg.joystick_radius
	draw_circle(knob, cfg.joystick_radius * 0.38, Color(1, 1, 1, 0.45 if touch.joy_index != -1 else 0.2))

	if touch.attack_button:
		_draw_button(touch.attack_button_center(), touch.attack_button_radius(), "CHÉM", touch.attack_index != -1,
			touch.attack_button_dir, Color(0.85, 0.35, 0.1), Color(1.0, 0.75, 0.3, 0.9))
	if touch.uses_block_button():
		_draw_button(touch.block_button_center(), touch.block_button_radius(), "ĐỠ", touch.block_index != -1,
			touch.block_button_dir, Color(0.2, 0.4, 0.9), Color(0.5, 0.8, 1.0, 0.9))

	var pts := touch.combat.stroke()
	if pts.size() == 3:
		var col := Color(0.5, 0.8, 1.0, 0.7) if touch.combat.block_dir != Dir.NONE else Color(1.0, 0.75, 0.3, 0.7)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), col, 6.0, true)
		draw_circle(pts[0], 10, col)

	# Kiểu vuốt: vạch chia vùng xoay (trên) và vùng chém (dưới). Kiểu nút không cần chữ hướng dẫn.
	if not touch.attack_button:
		var x0 := size.x * cfg.left_zone_ratio
		var hint := Color(1, 1, 1, 0.25)
		if touch.free_look:
			var y := size.y * cfg.look_zone_bottom_ratio
			draw_dashed_line(Vector2(x0 + 20, y), Vector2(size.x - 20, y), Color(1, 1, 1, 0.12), 2.0, 12.0)
			draw_string(_font, Vector2(size.x * 0.62, size.y * 0.2), "Kéo ngang để xoay người", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hint)
			draw_string(_font, Vector2(size.x * 0.62, y + 24), "Vùng chém: kéo để gồng, nhả để chém", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hint)
		else:
			draw_string(_font, Vector2(size.x * 0.62, size.y * 0.2), "Vùng chém: kéo để gồng, nhả để chém", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hint)


## Nút tròn giữ-và-kéo: khi giữ thì sáng lên và có mũi tên chỉ hướng đang chọn.
func _draw_button(c: Vector2, r: float, label: String, held: bool, dir: int, fill: Color, arrow: Color) -> void:
	draw_circle(c, r, Color(fill, 0.5 if held else 0.28))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	draw_string(_font, c + Vector2(-r, 8), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color(1, 1, 1, 0.9))
	if held:
		_draw_dir_arrow(c, dir, r + 18, arrow)


func _draw_dir_arrow(center: Vector2, dir: int, dist: float, col: Color) -> void:
	var v := Vector2.ZERO
	match dir:
		Dir.UP: v = Vector2.UP
		Dir.THRUST: v = Vector2.DOWN
		Dir.LEFT: v = Vector2.LEFT
		Dir.RIGHT: v = Vector2.RIGHT
	if v == Vector2.ZERO:
		return
	var tip := center + v * dist
	var side := Vector2(-v.y, v.x) * 12.0
	draw_colored_polygon(PackedVector2Array([tip, tip - v * 18.0 + side, tip - v * 18.0 - side]), col)
