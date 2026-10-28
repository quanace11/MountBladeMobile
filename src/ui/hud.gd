class_name Hud
extends Control
## Thanh máu, thể lực, fps, nút menu, đổi kiểu đỡ, màn hình kết thúc.

const S := FighterState.State

var runner: MatchRunner
var quality: QualityManager
var _font: Font
var _fps_label: Label
var _scheme_btn: Button
var _end_panel: PanelContainer
var _end_label: Label


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

	_scheme_btn = _button("")
	_scheme_btn.pressed.connect(_toggle_scheme)
	top.add_child(_scheme_btn)
	_update_scheme_label()

	_build_end_panel()
	EventBus.match_over.connect(_on_match_over)


func _exit_tree() -> void:
	if EventBus.match_over.is_connected(_on_match_over):
		EventBus.match_over.disconnect(_on_match_over)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _toggle_scheme() -> void:
	Game.block_scheme = InputConfig.BlockScheme.CHEVRON if Game.block_scheme == InputConfig.BlockScheme.BUTTON else InputConfig.BlockScheme.BUTTON
	runner.touch.combat.scheme = Game.block_scheme
	Game.save_settings()
	_update_scheme_label()


func _update_scheme_label() -> void:
	_scheme_btn.text = "Đỡ: nút" if Game.block_scheme == InputConfig.BlockScheme.BUTTON else "Đỡ: vuốt gấp"


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


func _on_match_over(winner_team: int) -> void:
	_end_label.text = "THẮNG!" if winner_team == 0 else "THUA"
	_end_panel.visible = true
	_end_panel.reset_size()
	_end_panel.position = (get_viewport_rect().size - _end_panel.size) * 0.5


func _process(_delta: float) -> void:
	_fps_label.text = "%d fps  ·  %d%%" % [Engine.get_frames_per_second(), roundi(quality.scale * 100.0)]
	queue_redraw()


func _draw() -> void:
	if runner == null:
		return
	var p := runner.player()
	_draw_bar(Vector2(24, 104), Vector2(320, 22), p.hp / p.def.max_hp, Color(0.8, 0.15, 0.1))
	_draw_bar(Vector2(24, 132), Vector2(320, 12), p.stamina / p.def.max_stamina, Color(0.95, 0.75, 0.2))
	draw_string(_font, Vector2(24, 96), p.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

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
		_draw_bar(sp - Vector2(50, -11), Vector2(100, 5), f.stamina / f.def.max_stamina, Color(0.95, 0.75, 0.2))
		if ConfigDB.input.show_attack_hint and f.state == S.WINDUP:
			_draw_hint(CombatResolver.required_block_dir(f, p))


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
