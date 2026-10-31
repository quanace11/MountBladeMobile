extends Control
## Menu chính: chọn trận, tướng, độ khó, cách điều khiển, đồ họa.

var _custom_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 32
	scroll.offset_right = -32
	scroll.offset_top = 16
	scroll.offset_bottom = -16
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "ĐẤU TƯỚNG"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	box.add_child(title)

	_row(box, "Trận", ConfigDB.matches, Game.match_id, func(id): Game.match_id = id)
	_row(box, "Nhân vật", ConfigDB.models, Game.player_model_id, func(id): Game.player_model_id = id)
	_row(box, "Tướng", ConfigDB.characters, Game.player_character_id, func(id): Game.player_character_id = id)
	_row(box, "Độ khó bot", ConfigDB.bots, Game.bot_id, func(id): Game.bot_id = id)
	_row(box, "Đồ họa", ConfigDB.qualities, Game.quality_id, func(id):
		Game.quality_id = id
		Game.apply_fps_cap(), [&"low", &"medium", &"high"])
	var modes := {}
	for m in ControlPrefs.Mode.values():
		modes[StringName(str(m))] = ControlPrefs.mode_name(m)
	_row(box, "Điều khiển", modes, StringName(str(Game.control_mode)), func(id):
		Game.control_mode = int(String(id))
		_custom_box.visible = Game.control_mode == ControlPrefs.Mode.CUSTOM, modes.keys())
	_build_custom(box)

	var fps := CheckButton.new()
	fps.text = "Khóa 30 fps (tiết kiệm pin)"
	fps.button_pressed = Game.fps_cap_30
	fps.add_theme_font_size_override("font_size", 22)
	fps.toggled.connect(func(on):
		Game.fps_cap_30 = on
		Game.apply_fps_cap())
	box.add_child(fps)

	var start := Button.new()
	start.text = "VÀO TRẬN"
	start.custom_minimum_size = Vector2(280, 72)
	start.add_theme_font_size_override("font_size", 30)
	start.pressed.connect(Game.start_match)
	box.add_child(start)

	var help := Label.new()
	help.text = "Tay trái: joystick di chuyển. Tay phải: giữ nút CHÉM và kéo về hướng muốn chém (lên = bổ, xuống = đâm, trái/phải = chém ngang), nhả để chém. Giữ nút ĐỠ và kéo về phía đòn đến. Tự xoay: kéo ngang chỗ trống bên phải để xoay người, chấm giữa màn hình là chỗ đang nhìn (đỏ = địch trong tầm chém).\nKhoá địch gần: tự quay về địch gần nhất, camera bám sau lưng.\nPC: WASD đi, Q/E xoay người, giữ I/J/K/L để gồng rồi nhả để chém, giữ phím mũi tên để đỡ."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	box.add_child(help)


## Các tuỳ chỉnh cho chế độ "Tự chỉnh". Chỉ hiện khi chọn chế độ đó.
func _build_custom(parent: Control) -> void:
	var c := Game.custom_controls
	_custom_box = VBoxContainer.new()
	_custom_box.add_theme_constant_override("separation", 10)
	_custom_box.visible = Game.control_mode == ControlPrefs.Mode.CUSTOM
	parent.add_child(_custom_box)
	_row(_custom_box, "Hướng mặt", {&"1": "Tự xoay (kéo)", &"0": "Khoá địch gần"}, &"1" if c.free_aim else &"0",
		func(id): c.free_aim = id == &"1", [&"1", &"0"])
	_row(_custom_box, "Kiểu chém", {&"1": "Nút CHÉM", &"0": "Vuốt cả vùng"}, &"1" if c.attack_button else &"0",
		func(id): c.attack_button = id == &"1", [&"1", &"0"])
	_row(_custom_box, "Cách đỡ (vuốt)", {&"0": "Nút ĐỠ", &"1": "Vuốt gấp khúc"}, StringName(str(c.block_scheme)),
		func(id): c.block_scheme = int(String(id)))
	_row(_custom_box, "Trợ ngắm", {&"1": "Bật", &"0": "Tắt"}, &"1" if c.aim_assist else &"0",
		func(id): c.aim_assist = id == &"1", [&"1", &"0"])
	_slider(_custom_box, "Độ nhạy xoay", 0.4, 2.5, 0.1, c.look_sensitivity, "x%.1f", func(v): c.look_sensitivity = v)
	_slider(_custom_box, "Camera xa", 2.5, 6.0, 0.1, c.camera_distance, "%.1f m", func(v): c.camera_distance = v)
	_slider(_custom_box, "Cỡ nút", 0.7, 1.4, 0.05, c.button_scale, "x%.2f", func(v): c.button_scale = v)


func _slider(parent: Control, label: String, lo: float, hi: float, step: float, value: float, fmt: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(320, 48)
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var v := Label.new()
	v.text = fmt % value
	v.add_theme_font_size_override("font_size", 22)
	row.add_child(v)
	s.value_changed.connect(func(x: float):
		v.text = fmt % x
		on_change.call(x))


## Một hàng nút chọn. options: id -> Resource có display_name, hoặc id -> String.
## order: thứ tự hiển thị các id (để trống thì xếp theo tên).
func _row(parent: Control, label: String, options: Dictionary, current: StringName, on_pick: Callable, order: Array = []) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	var group := ButtonGroup.new()
	var keys := order.filter(func(k): return options.has(k)) if not order.is_empty() else options.keys()
	if order.is_empty():
		keys.sort_custom(func(a, b): return String(a) < String(b))
	for id in keys:
		var opt = options[id]
		var b := Button.new()
		b.text = opt if opt is String else opt.display_name
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = StringName(id) == current
		b.custom_minimum_size = Vector2(150, 56)
		if opt is CharacterModel and opt.portrait:
			b.icon = opt.portrait
			b.expand_icon = true
			b.custom_minimum_size = Vector2(180, 200)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			# Viền vàng quanh nhân vật đang chọn.
			var sel := StyleBoxFlat.new()
			sel.bg_color = Color(0.1, 0.07, 0.05)
			sel.set_border_width_all(4)
			sel.border_color = Color(0.95, 0.75, 0.3)
			sel.set_corner_radius_all(4)
			b.add_theme_stylebox_override("pressed", sel)
			b.add_theme_stylebox_override("hover_pressed", sel)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): on_pick.call(StringName(id)))
		row.add_child(b)
