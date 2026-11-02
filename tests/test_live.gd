extends TestBase
## Luật chế độ TikTok LIVE: chọn phe, hàng chờ theo xu, giới hạn trên sân, tim hồi máu.


func _queue() -> LiveQueue:
	return LiveQueue.new(load(CONFIG + "live.tres"))


func test_comment_joins_side_once() -> void:
	var q := _queue()
	check_eq(q.on_comment("a", "A", " 1 "), LiveQueue.BLUE, "bình luận 1 vào phe Xanh")
	check_eq(q.on_comment("b", "B", "Đỏ"), LiveQueue.RED, "bình luận Đỏ vào phe Đỏ")
	check_eq(q.on_comment("c", "C", "hello"), -1, "bình luận thường không vào phe")
	q.on_comment("a", "A", "1")
	check_eq(q.queued(LiveQueue.BLUE), 1, "bình luận lại không xếp thêm lượt")
	q.on_comment("a", "A", "2")
	check_eq(q.queued(LiveQueue.RED), 2, "đổi phe thì lượt chờ đổi theo")


func test_bigger_gift_spawns_first() -> void:
	var q := _queue()
	q.on_comment("a", "A", "2")
	q.on_comment("b", "B", "2")
	q.on_gift("a", "A", 1)
	q.on_gift("b", "B", 50)
	check_eq(q.pop_next(LiveQueue.RED)["user"], "b", "quà nhiều xu ra trước")
	check_eq(q.pop_next(LiveQueue.RED)["user"], "a", "rồi tới quà ít xu")
	check(q.pop_next(LiveQueue.RED).is_empty(), "hết hàng chờ")


func test_field_cap_and_instant_gift() -> void:
	var q := _queue()
	q.on_comment("a", "A", "2")
	q.on_comment("b", "B", "2")
	q.on_gift("a", "A", 1)
	q.field_count = [0, q.cfg.max_on_field]
	check(q.pop_next(LiveQueue.RED).is_empty(), "sân đầy thì quà nhỏ phải chờ")
	q.on_gift("b", "B", q.cfg.instant_coins)
	check_eq(q.pop_next(LiveQueue.RED)["user"], "b", "quà đủ xu ra ngay dù sân đầy")
	q.on_gift("b", "B", 500)
	q.field_count = [0, q.cfg.hard_cap_on_field]
	check(q.pop_next(LiveQueue.RED).is_empty(), "không vượt giới hạn cứng")


func test_gift_tiers() -> void:
	var q := _queue()
	check_eq(q.tier_for(0), 0, "miễn phí là lính")
	check_eq(q.tier_for(10), 1, "10 xu là lính tinh")
	check_eq(q.tier_for(250), 2, "nhiều xu là tướng")


func test_gift_replaces_free_slot_and_picks_weaker_side() -> void:
	var q := _queue()
	q.on_comment("a", "A", "1")
	q.on_comment("x", "X", "1")
	q.on_gift("a", "A", 5)
	check_eq(q.queued(LiveQueue.BLUE), 2, "quà thay lượt miễn phí, không thêm lượt thứ hai")
	var e := q.on_gift("new", "N", 1)
	check_eq(e["side"], LiveQueue.RED, "chưa chọn phe thì vào phe ít người hơn")


func test_likes_heal_with_rate_limit() -> void:
	var q := _queue()
	var c := q.cfg
	q.on_like(c.likes_per_heal * 2 + 3)
	check(is_equal_approx(q.pending_heal, c.heal_per_step * 2), "đủ tim mới thành máu")
	q.on_like(100000)
	check(q.pending_heal <= c.max_pending_heal, "không dồn quá nhiều máu")
	var h := q.take_heal(1.0)
	check(h <= c.max_heal_per_second + 0.001, "mỗi giây hồi có giới hạn")


func test_scores_and_round_end() -> void:
	var q := _queue()
	q.on_gift("a", "A", 30)
	q.add_kill("a")
	q.unit_spawned("a")
	q.end_round(LiveQueue.RED)
	check_eq(q.round_wins[LiveQueue.RED], 1, "tính ván thắng")
	check(not q.on_field.has("a"), "hết ván thì lính trên sân hết lượt")
	check_eq(q.top("kills", 3)[0][0], "A", "bảng hạ địch")
	check_eq(q.top("coins", 3)[0][1], 30, "bảng tặng quà")
