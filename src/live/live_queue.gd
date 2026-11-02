class_name LiveQueue
extends RefCounted
## Luật LIVE không dính tới mạng hay hình ảnh: người xem chọn phe, quà xếp hàng theo số xu,
## tim dồn thành máu hồi cho người chơi, điểm của từng người xem. Giữ nguyên qua các ván.

const BLUE := 0
const RED := 1

var cfg: LiveConfig
## user -> phe đã chọn.
var sides: Dictionary = {}
## Hàng chờ ra trận. Mỗi mục: {user, nick, side, coins, tier, seq}.
var queue: Array = []
## Người xem đang có lính trên sân (user -> số lính).
var on_field: Dictionary = {}
## Số lính trên sân mỗi phe, do LiveDirector cập nhật.
var field_count: Array[int] = [0, 0]
## Máu đang chờ hồi cho người chơi.
var pending_heal: float = 0.0
## user -> {nick, kills, coins}.
var scores: Dictionary = {}
var round_wins: Array[int] = [0, 0]

var _seq: int = 0
var _like_carry: int = 0


func _init(p_cfg: LiveConfig) -> void:
	cfg = p_cfg


## Bình luận. Trả về phe vừa chọn (BLUE/RED) hoặc -1 nếu bình luận không phải lệnh vào phe.
func on_comment(user: String, nick: String, text: String) -> int:
	var side := parse_side(text)
	if side < 0:
		return -1
	sides[user] = side
	_touch(user, nick)
	# Đổi phe thì lính đang chờ của người đó đi theo phe mới.
	for e in queue:
		if e["user"] == user:
			e["side"] = side
	if cfg.free_join_spawns and not has_unit(user):
		_push(user, nick, side, 0)
	return side


## Quà đã quy ra xu (số kim cương mỗi quà x số lần tặng liên tiếp). Trả về mục vừa vào hàng chờ.
func on_gift(user: String, nick: String, coins: int) -> Dictionary:
	_touch(user, nick)
	scores[user]["coins"] += coins
	if not sides.has(user):
		sides[user] = weaker_side()
	# Quà thay cho lượt miễn phí đang chờ (không cho một người vừa chờ miễn phí vừa chờ quà).
	for i in range(queue.size() - 1, -1, -1):
		if queue[i]["user"] == user and queue[i]["coins"] == 0:
			queue.remove_at(i)
	return _push(user, nick, sides[user], coins)


## Thả tim: cứ đủ likes_per_heal tim thì thêm heal_per_step máu chờ hồi.
func on_like(count: int) -> void:
	_like_carry += maxi(0, count)
	var steps := _like_carry / maxi(1, cfg.likes_per_heal)
	_like_carry -= steps * maxi(1, cfg.likes_per_heal)
	pending_heal = minf(cfg.max_pending_heal, pending_heal + steps * cfg.heal_per_step)


## Lấy lượng máu được hồi trong dt giây (giới hạn max_heal_per_second).
func take_heal(dt: float) -> float:
	var h := minf(pending_heal, cfg.max_heal_per_second * dt)
	pending_heal -= h
	return h


## Mục tiếp theo được ra trận cho phe side, hoặc {} nếu chưa tới lượt.
## Hàng chờ xếp theo xu giảm dần, cùng xu thì ai đến trước ra trước.
## Còn chỗ (dưới max_on_field) thì ra ngay; quà từ instant_coins xu thì ra luôn tới hard_cap_on_field.
func pop_next(side: int) -> Dictionary:
	var best := -1
	for i in queue.size():
		var e: Dictionary = queue[i]
		if e["side"] != side:
			continue
		if best < 0 or _before(e, queue[best]):
			best = i
	if best < 0:
		return {}
	var e: Dictionary = queue[best]
	var n := field_count[side]
	var ok: bool = n < cfg.max_on_field or (e["coins"] >= cfg.instant_coins and n < cfg.hard_cap_on_field)
	if not ok:
		return {}
	queue.remove_at(best)
	return e


func queued(side: int) -> int:
	var n := 0
	for e in queue:
		if e["side"] == side:
			n += 1
	return n


## Vị trí trong hàng chờ của phe (1 = ra tiếp theo), 0 nếu không có trong hàng.
func position_of(user: String) -> int:
	if not sides.has(user):
		return 0
	var mine := queue.filter(func(e): return e["side"] == sides[user])
	mine.sort_custom(_before)
	for i in mine.size():
		if mine[i]["user"] == user:
			return i + 1
	return 0


func unit_spawned(user: String) -> void:
	on_field[user] = int(on_field.get(user, 0)) + 1


func unit_gone(user: String) -> void:
	var n := int(on_field.get(user, 0)) - 1
	if n <= 0:
		on_field.erase(user)
	else:
		on_field[user] = n


func has_unit(user: String) -> bool:
	if on_field.has(user):
		return true
	for e in queue:
		if e["user"] == user:
			return true
	return false


func add_kill(user: String) -> void:
	if scores.has(user):
		scores[user]["kills"] += 1


## Hết ván: lính trên sân coi như đã dùng lượt, hàng chờ giữ lại cho ván sau.
func end_round(winner: int) -> void:
	if winner == BLUE or winner == RED:
		round_wins[winner] += 1
	on_field.clear()
	field_count = [0, 0]


## Bậc lính theo số xu.
func tier_for(coins: int) -> int:
	var t := 0
	for i in cfg.tier_min_coins.size():
		if coins >= cfg.tier_min_coins[i]:
			t = i
	return t


## Phe đang ít người hơn (trên sân + chờ). Người tặng quà mà chưa chọn phe thì vào phe này.
func weaker_side() -> int:
	var b := field_count[BLUE] + queued(BLUE)
	var r := field_count[RED] + queued(RED)
	return RED if r < b else BLUE


## Top n người xem theo khoá "kills" hoặc "coins". Mỗi mục: [nick, giá trị].
func top(key: String, n: int) -> Array:
	var list := []
	for u in scores:
		var s: Dictionary = scores[u]
		if s[key] > 0:
			list.append([s["nick"], s[key]])
	list.sort_custom(func(a, b): return a[1] > b[1])
	return list.slice(0, n)


func parse_side(text: String) -> int:
	var t := text.strip_edges().to_lower().replace(" ", "")
	if t in cfg.join_blue_words:
		return BLUE
	if t in cfg.join_red_words:
		return RED
	return -1


func _push(user: String, nick: String, side: int, coins: int) -> Dictionary:
	_seq += 1
	var e := {"user": user, "nick": nick, "side": side, "coins": coins, "tier": tier_for(coins), "seq": _seq}
	queue.append(e)
	return e


func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["coins"] != b["coins"]:
		return a["coins"] > b["coins"]
	return a["seq"] < b["seq"]


func _touch(user: String, nick: String) -> void:
	if not scores.has(user):
		scores[user] = {"nick": nick, "kills": 0, "coins": 0}
	elif nick != "":
		scores[user]["nick"] = nick
