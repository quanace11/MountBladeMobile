class_name LiveHud
extends Control
## Lớp chữ cho chế độ TikTok LIVE: tỉ số hai phe, số lính trên sân và đang chờ, dòng báo người xem
## vào phe / tặng quà, trạng thái kết nối, hướng dẫn cho người xem, bảng điểm khi hết ván.

const FEED_TIME := 6.0
const FEED_KEEP := 7

var runner: MatchRunner
var _font: Font
## Mỗi dòng: [chữ, màu, thời gian còn lại].
var _feed: Array = []
var _heal_glow := 0.0


func setup(p_runner: MatchRunner) -> void:
	runner = p_runner
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Live.feed.connect(_on_feed)


func _exit_tree() -> void:
	if Live.feed.is_connected(_on_feed):
		Live.feed.disconnect(_on_feed)


func _on_feed(text: String, color: Color) -> void:
	_feed.push_front([text, color, FEED_TIME])
	if _feed.size() > FEED_KEEP:
		_feed.pop_back()


func _process(delta: float) -> void:
	for line in _feed:
		line[2] -= delta
	while not _feed.is_empty() and _feed.back()[2] <= 0.0:
		_feed.pop_back()
	_heal_glow = 1.0 if Live.queue.pending_heal > 0.0 else maxf(0.0, _heal_glow - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	if runner == null or runner.live == null:
		return
	var size := get_viewport_rect().size
	var q := Live.queue
	var cx := size.x * 0.5

	# Tỉ số ván và lính hai phe.
	_text(Vector2(cx - 300, 92), "XANH  %d" % q.round_wins[0], HORIZONTAL_ALIGNMENT_RIGHT, 260, 30, Live.BLUE_TEXT)
	_text(Vector2(cx - 40, 92), ":", HORIZONTAL_ALIGNMENT_CENTER, 80, 30, Color.WHITE)
	_text(Vector2(cx + 40, 92), "%d  ĐỎ" % q.round_wins[1], HORIZONTAL_ALIGNMENT_LEFT, 260, 30, Live.RED_TEXT)
	_text(Vector2(cx - 300, 120), "%d trên sân · %d chờ" % [q.field_count[0], q.queued(0)], HORIZONTAL_ALIGNMENT_RIGHT, 260, 18, Live.BLUE_TEXT)
	_text(Vector2(cx + 40, 120), "%d trên sân · %d chờ" % [q.field_count[1], q.queued(1)], HORIZONTAL_ALIGNMENT_LEFT, 260, 18, Live.RED_TEXT)

	# Đang hồi máu nhờ tim.
	if _heal_glow > 0.0:
		_text(Vector2(352, 122), "+ hồi máu nhờ tim", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, Color(1.0, 0.45, 0.6, _heal_glow))

	# Dòng báo người xem.
	var y := 300.0
	for line in _feed:
		var col: Color = line[1]
		col.a = clampf(float(line[2]), 0.0, 1.0)
		_text(Vector2(24, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, 520, 19, col)
		y += 25.0

	# Hướng dẫn cho người xem + trạng thái kết nối.
	var cfg := ConfigDB.live
	var help := "Bình luận %s vào phe Xanh, %s vào phe Đỏ · Quà từ %d xu ra trận ngay · Tim hồi máu cho tướng Xanh" % [
		cfg.join_blue_words[0], cfg.join_red_words[0], cfg.instant_coins]
	_text(Vector2(cx - 450, size.y - 14), help, HORIZONTAL_ALIGNMENT_CENTER, 900, 17, Color(1, 0.95, 0.8, 0.9))
	var st := Live.status
	if Live.bridge_status != "":
		st += " · " + Live.bridge_status
	var st_col := Color(0.6, 1.0, 0.6) if Live.is_connected_to_bridge() else Color(1.0, 0.7, 0.4)
	_text(Vector2(24, size.y - 40), st, HORIZONTAL_ALIGNMENT_LEFT, 700, 15, st_col)

	if runner.live.finished:
		_draw_round_over(size)


func _draw_round_over(size: Vector2) -> void:
	var d := runner.live
	var q := Live.queue
	var panel := Rect2(size * 0.5 - Vector2(320, 190), Vector2(640, 380))
	draw_rect(panel, Color(0.05, 0.03, 0.02, 0.82))
	var cx := panel.position.x
	var y := panel.position.y + 60
	var title := "PHE XANH THẮNG VÁN!" if d.winner == LiveQueue.BLUE else "PHE ĐỎ THẮNG VÁN!"
	_text(Vector2(cx, y), title, HORIZONTAL_ALIGNMENT_CENTER, 640, 40, Live.side_color(d.winner))
	y += 54
	var kills := q.top("kills", 3)
	var coins := q.top("coins", 3)
	_text(Vector2(cx + 30, y), "Hạ nhiều nhất", HORIZONTAL_ALIGNMENT_LEFT, 280, 22, Color(0.95, 0.75, 0.3))
	_text(Vector2(cx + 340, y), "Tặng nhiều nhất", HORIZONTAL_ALIGNMENT_LEFT, 280, 22, Color(0.95, 0.75, 0.3))
	for i in 3:
		y += 34
		if i < kills.size():
			_text(Vector2(cx + 30, y), "%d. %s  %d" % [i + 1, kills[i][0], kills[i][1]], HORIZONTAL_ALIGNMENT_LEFT, 290, 20, Color.WHITE)
		if i < coins.size():
			_text(Vector2(cx + 340, y), "%d. %s  %d xu" % [i + 1, coins[i][0], coins[i][1]], HORIZONTAL_ALIGNMENT_LEFT, 290, 20, Color.WHITE)
	y += 60
	_text(Vector2(cx, y), "Ván mới sau %d giây" % ceili(maxf(0.0, d.restart_in)), HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color(0.9, 0.9, 0.9))


func _text(pos: Vector2, s: String, align: HorizontalAlignment, width: float, font_size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, align, width, font_size, 4, Color(0, 0, 0, col.a * 0.75))
	draw_string(_font, pos, s, align, width, font_size, col)
