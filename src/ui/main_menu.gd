extends Control
## Menu chính: chọn trận, tướng, độ khó, kiểu đỡ, đồ họa.


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
	_row(box, "Tướng", ConfigDB.characters, Game.player_character_id, func(id): Game.player_character_id = id)
	_row(box, "Độ khó bot", ConfigDB.bots, Game.bot_id, func(id): Game.bot_id = id)
	_row(box, "Đồ họa", ConfigDB.qualities, Game.quality_id, func(id):
		Game.quality_id = id
		Game.apply_fps_cap(), [&"low", &"medium", &"high"])
	_row(box, "Cách đỡ", {&"0": "Nút ĐỠ", &"1": "Vuốt gấp khúc"}, StringName(str(Game.block_scheme)), func(id): Game.block_scheme = int(String(id)))

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
	help.text = "Tay trái: joystick di chuyển. Tay phải: kéo để gồng, nhả để chém (lên = bổ, xuống = đâm, trái/phải = chém ngang).\nĐỡ: giữ nút ĐỠ và kéo về phía đòn đến, hoặc vuốt nét gấp ^ < > v.\nPC: WASD đi, giữ I/J/K/L để gồng rồi nhả để chém, giữ phím mũi tên để đỡ."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	box.add_child(help)


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
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): on_pick.call(StringName(id)))
		row.add_child(b)
