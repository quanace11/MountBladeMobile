class_name LiveDirector
extends Node
## Chạy luật LIVE trong một ván: gọi lính từ hàng chờ ra sân, hồi máu cho người chơi bằng tim,
## dọn xác, tính điểm hạ địch, quyết định hết ván và sang ván mới.
## Phe Xanh: người chơi + lính người xem. Phe Đỏ: tướng Đỏ (bot) + lính người xem.
## Người chơi chết thì Đỏ thắng ván, hạ tướng Đỏ thì Xanh thắng ván.
##
## Thử không cần TikTok (PC): 1 / 2 = người xem giả bình luận vào phe Xanh / Đỏ,
## 3 / 4 / 5 = quà 1 / 10 / 100 xu cho phe Đỏ (giữ Shift: cho phe Xanh), 6 = 20 tim.

signal round_over(winner: int)

const BLUE := LiveQueue.BLUE
const RED := LiveQueue.RED

var runner: MatchRunner
var cfg: LiveConfig
var queue: LiveQueue
var red_general_id: int = -1
## id tướng -> user người xem điều khiển.
var owners: Dictionary = {}
## id tướng -> thời gian xác đã nằm (giây).
var _corpses: Dictionary = {}
var finished := false
var winner := -1
## Đếm ngược sang ván mới (giây).
var restart_in := 0.0
var _fake_n := 0
var _keys_down: Dictionary = {}


func setup(p_runner: MatchRunner) -> void:
	runner = p_runner
	cfg = ConfigDB.live
	queue = Live.queue
	queue.end_round(-1)
	var keys := ConfigDB.sorted_keys(ConfigDB.characters)
	var base: CharacterDef = ConfigDB.characters[keys[keys.size() - 1]]
	var def := unit_def(base, cfg.red_general_hp_mult, cfg.red_color)
	var half := ConfigDB.game.spawn_distance * 0.5
	red_general_id = runner.spawn_fighter(def, RED, Vector2(0, -half), FighterState.yaw_from_direction(Vector2(0, 1)),
		_bot(cfg.red_general_bot), "Tướng Đỏ")
	EventBus.sim_event.connect(_on_event)


func _exit_tree() -> void:
	if EventBus.sim_event.is_connected(_on_event):
		EventBus.sim_event.disconnect(_on_event)


## Bản sao tướng gốc với máu nhân hp_mult và áo màu phe.
static func unit_def(base: CharacterDef, hp_mult: float, color: Color) -> CharacterDef:
	var d: CharacterDef = base.duplicate()
	d.max_hp = base.max_hp * hp_mult
	d.armor_color = color
	d.cape_color = color.darkened(0.35)
	return d


func _bot(id: StringName) -> BotProfile:
	var b: BotProfile = ConfigDB.bots.get(id)
	return b if b else Game.current_bot()


func _process(delta: float) -> void:
	_fake_input()
	if finished:
		restart_in -= delta
		if restart_in <= 0.0:
			set_process(false)
			Game.start_match()
		return
	_count_field()
	for side in [BLUE, RED]:
		while true:
			var e := queue.pop_next(side)
			if e.is_empty():
				break
			_spawn(e)
			_count_field()
	var p := runner.player()
	if p.is_alive():
		p.hp = minf(p.def.max_hp, p.hp + queue.take_heal(delta))
	for id in _corpses.keys():
		_corpses[id] += delta
		if _corpses[id] >= cfg.corpse_seconds:
			_corpses.erase(id)
			runner.remove_fighter(id)


func _count_field() -> void:
	var n: Array[int] = [0, 0]
	for f in runner.sim.state.fighters:
		if f.is_alive() and owners.has(f.id):
			n[f.team] += 1
	queue.field_count = n


func _spawn(e: Dictionary) -> void:
	var side: int = e["side"]
	var tier: int = e["tier"]
	var keys := ConfigDB.sorted_keys(ConfigDB.characters)
	var base: CharacterDef = ConfigDB.characters[keys[randi() % keys.size()]]
	var def := unit_def(base, cfg.tier_hp_mult[tier], cfg.blue_color if side == BLUE else cfg.red_color)
	# Ra ở mép sân phía phe mình, lệch ngang ngẫu nhiên, quay mặt vào giữa.
	var dir := 1.0 if side == BLUE else -1.0
	var pos := Vector2(randf_range(-6.0, 6.0), dir * cfg.spawn_distance)
	var label := "%s · %s" % [e["nick"], cfg.tier_names[tier]] if tier > 0 else str(e["nick"])
	var id := runner.spawn_fighter(def, side, pos, FighterState.yaw_from_direction(-pos.normalized()),
		_bot(StringName(cfg.tier_bots[tier])), label)
	owners[id] = e["user"]
	queue.unit_spawned(e["user"])


func _on_event(e: Dictionary) -> void:
	if e["type"] != &"died":
		return
	var id: int = e["id"]
	var by: int = e.get("by", -1)
	if owners.has(by):
		queue.add_kill(owners[by])
	if owners.has(id):
		queue.unit_gone(owners[id])
		owners.erase(id)
	if id != runner.player_id and id != red_general_id:
		_corpses[id] = 0.0
	if finished:
		return
	if id == runner.player_id:
		_finish(RED)
	elif id == red_general_id:
		_finish(BLUE)


func _finish(side: int) -> void:
	finished = true
	winner = side
	restart_in = cfg.round_restart_seconds
	queue.end_round(side)
	runner.sim.state.finished = true
	runner.sim.state.winner_team = side
	round_over.emit(side)


## Phím giả lập sự kiện LIVE để thử trên PC khi chưa nối TikTok.
func _fake_input() -> void:
	var red := not Input.is_key_pressed(KEY_SHIFT)
	if _pressed(KEY_1):
		_fake({"type": "comment", "text": "1"})
	if _pressed(KEY_2):
		_fake({"type": "comment", "text": "2"})
	for k in [[KEY_3, 1, "Hoa hồng"], [KEY_4, 10, "Kem"], [KEY_5, 100, "Mũ"]]:
		if _pressed(k[0]):
			var user := _fake({"type": "comment", "text": "2" if red else "1"}, false)
			Live.handle({"type": "gift", "user": user, "nick": user, "gift": k[2], "coins": k[1]})
	if _pressed(KEY_6):
		Live.handle({"type": "like", "user": "tim", "nick": "tim", "count": 20})


func _fake(e: Dictionary, show := true) -> String:
	_fake_n += 1
	var user := "nguoixem%d" % _fake_n
	e["user"] = user
	e["nick"] = user
	if show:
		Live.handle(e)
	else:
		# Chọn phe mà không xếp lượt miễn phí: quà ngay sau đó sẽ thay lượt này.
		Live.queue.sides[user] = Live.queue.parse_side(e["text"])
	return user


func _pressed(key: Key) -> bool:
	var down := Input.is_key_pressed(key)
	var was: bool = _keys_down.get(key, false)
	_keys_down[key] = down
	return down and not was
