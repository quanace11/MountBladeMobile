extends TestBase
## Đọc thao tác vuốt.


func _parser(scheme: int) -> GestureParser:
	return GestureParser.new(load(CONFIG + "input/touch.tres"), scheme)


func _stroke(p: GestureParser, points: Array) -> void:
	p.touch_down(points[0])
	for i in range(1, points.size()):
		p.touch_move(points[i])


func test_straight_swipe_attacks_then_releases() -> void:
	var p := _parser(InputConfig.BlockScheme.BUTTON)
	_stroke(p, [Vector2(900, 400), Vector2(960, 405), Vector2(1020, 410)])
	check_eq(p.attack_dir, Dir.RIGHT, "kéo sang phải là gồng phải")
	p.touch_up(Vector2(1020, 410))
	check(p.consume_release(), "nhả tay là chém")
	check(not p.consume_release(), "chỉ chém một lần")


func test_chevron_up_blocks_up() -> void:
	var p := _parser(InputConfig.BlockScheme.CHEVRON)
	_stroke(p, [Vector2(900, 500), Vector2(940, 440), Vector2(980, 380), Vector2(1020, 440), Vector2(1060, 500)])
	check_eq(p.block_dir, Dir.UP, "nét ^ là đỡ trên")
	check_eq(p.attack_dir, Dir.NONE, "đang đỡ thì không gồng")
	p.touch_up(Vector2(1060, 500))
	check(not p.consume_release(), "nhả nét đỡ không phải là chém")


func test_chevron_left_blocks_left() -> void:
	var p := _parser(InputConfig.BlockScheme.CHEVRON)
	_stroke(p, [Vector2(1000, 300), Vector2(940, 360), Vector2(880, 420), Vector2(940, 480), Vector2(1000, 540)])
	check_eq(p.block_dir, Dir.LEFT, "nét < là đỡ trái")


func test_button_scheme_ignores_chevron() -> void:
	var p := _parser(InputConfig.BlockScheme.BUTTON)
	_stroke(p, [Vector2(900, 500), Vector2(940, 440), Vector2(980, 380), Vector2(1020, 440), Vector2(1060, 500)])
	check_eq(p.block_dir, Dir.NONE, "kiểu nút không đỡ bằng vuốt")


func test_button_scheme_tap_attacks_default_dir() -> void:
	var p := _parser(InputConfig.BlockScheme.BUTTON)
	p.touch_down(Vector2(1100, 490))
	p.touch_up(Vector2(1102, 491))
	check(p.consume_release(), "chạm nhanh nút CHÉM là chém")
	check_eq(p.attack_dir, p.cfg.attack_tap_dir, "chém theo hướng mặc định")


func test_chevron_scheme_tap_does_nothing() -> void:
	var p := _parser(InputConfig.BlockScheme.CHEVRON)
	p.touch_down(Vector2(1100, 490))
	p.touch_up(Vector2(1102, 491))
	check(not p.consume_release(), "kiểu vuốt: chạm nhanh không chém")
