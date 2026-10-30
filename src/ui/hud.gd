class_name Hud
extends Control
## Thanh máu, thể lực, fps, nút menu, đổi chế độ điều khiển, chấm tâm ngắm, màn hình kết thúc.

const S := FighterState.State

var runner: MatchRunner
var quality: QualityManager
var _font: Font
var _fps_label: Label
var _mode_btn: Button
var _end_panel: PanelContainer
var _end_label: Label
## Thanh thể lực nháy đỏ khi bấm chém/lăn mà không đủ thể lực.
var _stamina_flash := 0.0
## Viền đỏ khi bị chém trúng; máu thấp thì viền đỏ mờ luôn hiện.
var _hurt_flash := 0.0
var _vignette: GradientTexture2D
## Dòng báo như Bannerlord: "Gây 45 sát thương." dưới thanh máu, "A đã hạ B" ở góc phải trên.
## Mỗi dòng: [chữ, màu, thời gian còn lại].
var _damage_log: Array = []
var _kill_feed: Array = []
const LOG_TIME := 3.5


func setup(p_runner: MatchRunner, p_quality: QualityManager) -> void:
	runner = p_runner
	quality = p_quality
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 8
	top.add_theme_constant_override("separation", 12)
	add_child(top)

	var menu_btn := _button("Menu")
	menu_btn.pressed.connect(Game.back_to_menu)
	top.add_child(menu_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_fps_label)

	_mode_btn = _button("")
	_mode_btn.pressed.connect(_cycle_mode)
	top.add_child(_mode_btn)
	_update_mode_label()

	_build_end_panel()
	EventBus.match_over.connect(_on_match_over)
	EventBus.sim_event.connect(_on_sim_event)


func _exit_tree() -> void:
	if EventBus.match_over.is_connected(_on_match_over):
		EventBus.match_over.disconnect(_on_match_over)
	if EventBus.sim_event.is_connected(_on_sim_event):
		EventBus.sim_event.disconnect(_on_sim_event)


func _on_sim_event(e: Dictionary) -> void:
	var me := runner.player_id
	match e["type"]:
		&"no_stamina":
			if e["id"] == me:
				_stamina_flash = 1.0
		&"hit":
			var dmg := roundi(float(e.get("damage", 0.0)))
			if e["target"] == me:
				_hurt_flash = 1.0
				_push(_damage_log, "Nhận %d sát thương." % dmg, Color(1.0, 0.55, 0.5), 4)
			elif e["id"] == me:
				_push(_damage_log, "Gây %d sát thương." % dmg, Color(1.0, 0.95, 0.8), 4)
		&"died":
			var by := runner.sim.state.get_fighter(e.get("by", -1))
			var dead := runner.sim.state.get_fighter(e["id"])
			if dead == null:
				return
			var killer := "?" if by == null else ("Bạn" if by.id == me else by.def.display_name)
			var victim := "bạn" if dead.id == me else dead.def.display_name
			var col := Color(0.6, 1.0, 0.6) if by != null and by.team == runner.player().team else Color(1.0, 0.5, 0.45)
			_push(_kill_feed, "%s đã hạ %s" % [killer, victim], col, 5)


func _push(list: Array, text: String, color: Color, keep: int) -> void:
	list.push_front([text, color, LOG_TIME])
	if list.size() > keep:
		list.pop_back()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _cycle_mode() -> void:
	Game.control_mode = (Game.control_mode + 1) % ControlPrefs.Mode.size()
	runner.apply_controls()
	Game.save_settings()
	_update_mode_label()


func _update_mode_label() -> void:
	_mode_btn.text = ControlPrefs.mode_name(Game.control_mode)


func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.visible = false
	add_child(_end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_end_panel.add_child(box)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 44)
	box.add_child(_end_label)
	var again := _button("Đánh lại")
	again.pressed.connect(Game.start_match)
	box.add_child(again)
	var menu := _button("Về menu")
	menu.pressed.connect(Game.back_to_menu)
	box.add_child(menu)


## Chờ một lúc cho thấy người cuối cùng ngã xuống rồi mới hiện bảng kết thúc.
const END_PANEL_DELAY := 2.5


func _on_match_over(winner_team: int) -> void:
	await get_tree().create_timer(END_PANEL_DELAY).timeout
	if not is_inside_tree():
		return
	_end_label.text = "THẮNG!" if winner_team == 0 else "THUA"
	_end_panel.visible = true
	_end_panel.reset_size()
	_end_panel.position = (get_viewport_rect().size - _end_panel.size) * 0.5


func _process(delta: float) -> void:
	_stamina_flash = maxf(0.0, _stamina_flash - delta * 2.5)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.2)
	for list in [_damage_log, _kill_feed]:
		for line in list:
			line[2] -= delta
		while not list.is_empty() and list.back()[2] <= 0.0:
			list.pop_back()
	_fps_label.text = "%d fps  ·  %d%%" % [Engine.get_frames_per_second(), roundi(quality.scale * 100.0)]
	queue_redraw()


func _draw() -> void:
	if runner == null:
		return
	var p := runner.player()
	_draw_vignette(p)
	_draw_bar(Vector2(24, 104), Vector2(320, 22), p.hp / p.def.max_hp, Color(0.8, 0.15, 0.1))
	var stamina := runner.sim.ctx.rules.use_stamina
	if stamina:
		if _stamina_flash > 0.0:
			draw_rect(Rect2(Vector2(20, 128), Vector2(328, 20)), Color(1, 0.1, 0.05, _stamina_flash * 0.8))
		_draw_bar(Vector2(24, 132), Vector2(320, 12), p.stamina / p.def.max_stamina, Color(0.95, 0.75, 0.2))
	draw_string(_font, Vector2(24, 96), p.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	_draw_crosshair(p)
	_draw_log(_damage_log, Vector2(24, 172), HORIZONTAL_ALIGNMENT_LEFT)
	_draw_log(_kill_feed, Vector2(get_viewport_rect().size.x - 24, 96), HORIZONTAL_ALIGNMENT_RIGHT)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for f in runner.sim.state.fighters:
		if f.id == runner.player_id or not f.is_alive():
			continue
		var head: Vector3 = (runner.views[f.id] as FighterView).head_position()
		if cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		_draw_bar(sp - Vector2(50, 0), Vector2(100, 9), f.hp / f.def.max_hp, Color(0.85, 0.2, 0.15))
		if stamina:
			_draw_bar(sp - Vector2(50, -11), Vector2(100, 5), f.stamina / f.def.max_stamina, Color(0.95, 0.75, 0.2))
		if ConfigDB.input.show_attack_hint and f.state == S.WINDUP:
			_draw_hint(CombatResolver.required_block_dir(f, p))


## Chấm tâm khung nhìn: hướng người chơi đang quay mặt tới. Đỏ khi có địch trong tầm chém.
func _draw_crosshair(p: FighterState) -> void:
	var c := get_viewport_rect().size * 0.5
	var in_reach := p.is_alive() and CombatResolver.find_target(p, runner.sim.state.fighters) != null
	draw_circle(c, 7.0, Color(1, 1, 1, 0.75))
	draw_circle(c, 5.0, Color(0.9, 0.1, 0.05) if in_reach else Color(0, 0, 0, 0.9))


func _draw_bar(pos: Vector2, size: Vector2, ratio: float, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), col)


## Mũi tên báo hướng đòn (chỉ khi bật show_attack_hint trong config).
func _draw_hint(dir: int) -> void:
	var size := get_viewport_rect().size
	var c := size * 0.5
	var pos := c
	match dir:
		Dir.UP: pos = c + Vector2(0, -size.y * 0.3)
		Dir.THRUST: pos = c + Vector2(0, size.y * 0.15)
		Dir.LEFT: pos = c + Vector2(-size.x * 0.2, 0)
		Dir.RIGHT: pos = c + Vector2(size.x * 0.2, 0)
	draw_circle(pos, 18, Color(1, 0.2, 0.1, 0.7))


## Viền đỏ quanh màn hình: chớp khi bị trúng, mờ mờ khi còn dưới 35% máu.
func _draw_vignette(p: FighterState) -> void:
	var low := clampf(1.0 - p.hp / (p.def.max_hp * 0.35), 0.0, 1.0) * 0.45 if p.is_alive() else 0.0
	var a := maxf(_hurt_flash * 0.85, low)
	if a <= 0.01:
		return
	if _vignette == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.6, 0.0, 0.0, 0.0))
		g.set_color(1, Color(0.6, 0.0, 0.0, 0.9))
		g.add_point(0.55, Color(0.6, 0.0, 0.0, 0.0))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.05, 0.5)
		_vignette.width = 64
		_vignette.height = 64
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, get_viewport_rect().size), false, Color(1, 1, 1, a))


## Các dòng báo, dòng mới nhất ở trên, mờ dần trong giây cuối.
func _draw_log(list: Array, origin: Vector2, align: HorizontalAlignment) -> void:
	var y := origin.y
	for line in list:
		var col: Color = line[1]
		col.a = clampf(float(line[2]), 0.0, 1.0)
		var x := origin.x - 420.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else origin.x
		draw_string_outline(_font, Vector2(x, y), line[0], align, 420.0, 18, 4, Color(0, 0, 0, col.a * 0.7))
		draw_string(_font, Vector2(x, y), line[0], align, 420.0, 18, col)
		y += 24.0
