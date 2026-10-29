class_name TouchOverlay
extends Control
## Vẽ joystick, nút CHÉM, nút ĐỠ và nét vuốt. Chỉ đọc TouchController.

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

	if touch.uses_block_button():
		var c := touch.block_button_center()
		var held := touch.block_index != -1
		_draw_button(c, cfg.block_button_radius, "ĐỠ", Color(0.2, 0.4, 0.9, 0.45 if held else 0.25))
		if held:
			_draw_dir_arrow(c, touch.block_button_dir, cfg.block_button_radius + 18, Color(0.5, 0.8, 1.0, 0.9))
		var a := touch.attack_button_center()
		var swinging := touch.combat_index != -1
		_draw_button(a, cfg.attack_button_radius, "CHÉM", Color(0.85, 0.35, 0.15, 0.5 if swinging else 0.28))
		if swinging:
			_draw_dir_arrow(a, touch.combat.attack_dir, cfg.attack_button_radius + 18, Color(1.0, 0.75, 0.3, 0.9))
		return

	var pts := touch.combat.stroke()
	if pts.size() == 3:
		var col := Color(0.5, 0.8, 1.0, 0.7) if touch.combat.block_dir != Dir.NONE else Color(1.0, 0.75, 0.3, 0.7)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), col, 6.0, true)
		draw_circle(pts[0], 10, col)

	draw_string(_font, Vector2(size.x * 0.62, size.y * 0.2), "Vùng chém: kéo để gồng, nhả để chém", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.25))


func _draw_button(c: Vector2, radius: float, label: String, fill: Color) -> void:
	draw_circle(c, radius, fill)
	draw_arc(c, radius, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	draw_string(_font, c + Vector2(-radius, 8), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 24, Color(1, 1, 1, 0.9))


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
