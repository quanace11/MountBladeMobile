class_name MatchSim
extends RefCounted
## Vòng tick cố định của trận đấu. Nhận lệnh, cập nhật MatchState, trả về danh sách sự kiện.
## Không biết gì về hình ảnh, âm thanh hay cảm ứng.

var ctx: SimContext
var state: MatchState = MatchState.new()
var _next_id: int = 1


func _init(p_config: GameConfig, p_rules: CombatRules) -> void:
	ctx = SimContext.new(p_config, p_rules)


func add_fighter(def: CharacterDef, team: int, pos: Vector2, yaw: float) -> int:
	var f := FighterState.new()
	f.id = _next_id
	_next_id += 1
	f.team = team
	f.def = def
	f.pos = pos
	f.yaw = yaw
	f.hp = def.max_hp
	f.stamina = def.max_stamina
	state.fighters.append(f)
	return f.id


## Chạy một tick. commands: id -> FighterCommand. Tướng không có lệnh coi như đứng yên.
func step(commands: Dictionary) -> Array:
	var events: Array = []
	if state.finished:
		return events
	state.tick += 1
	var empty := FighterCommand.new()

	for f in state.fighters:
		var cmd: FighterCommand = commands.get(f.id, empty)
		FighterSim.apply_command(f, cmd, ctx, state.tick, events)

	for f in state.fighters:
		var cmd: FighterCommand = commands.get(f.id, empty)
		var target: FighterState = null if cmd.has_face else nearest_enemy(f, ctx.config.auto_face_range)
		FighterSim.move_and_face(f, cmd, target.pos if target else Vector2.ZERO, target != null, ctx)

	_separate_and_clamp()

	for f in state.fighters:
		FighterSim.advance_timers(f, ctx, events)

	# Xét mọi đòn chạm trong tick này cùng lúc: hai người chém trúng nhau cùng lúc thì cả hai
	# đòn đều tính (như Mount & Blade), không phải ai được xét trước thì ngắt đòn người kia.
	var impacting: Array[FighterState] = []
	for f in state.fighters:
		if FighterSim.is_impact_tick(f, ctx):
			impacting.append(f)
	var stunned: Array[FighterState] = []
	for f in impacting:
		CombatResolver.resolve_impact(f, state.fighters, ctx, state.tick, events, impacting, stunned)
	for f in stunned:
		if f.is_alive():
			CombatResolver.stun(f, ctx)

	var teams := state.alive_teams()
	if teams.size() <= 1:
		state.finished = true
		state.winner_team = teams[0] if teams.size() == 1 else -1
		events.append({"type": &"match_over", "winner": state.winner_team})
	return events


func nearest_enemy(f: FighterState, max_range: float) -> FighterState:
	var best: FighterState = null
	var best_d := max_range
	for o in state.fighters:
		if o.team == f.team or not o.is_alive():
			continue
		var d := f.pos.distance_to(o.pos)
		if d <= best_d:
			best_d = d
			best = o
	return best


func _separate_and_clamp() -> void:
	var list := state.fighters
	for i in list.size():
		var a := list[i]
		if not a.is_alive():
			continue
		for j in range(i + 1, list.size()):
			var b := list[j]
			if not b.is_alive():
				continue
			var min_d := a.def.body_radius + b.def.body_radius
			var delta := b.pos - a.pos
			var d := delta.length()
			if d < min_d:
				var n := delta / d if d > 0.0001 else Vector2.RIGHT
				var push := (min_d - d) * 0.5
				a.pos -= n * push
				b.pos += n * push
	var r := ctx.config.arena_radius
	for f in list:
		if f.pos.length() > r:
			f.pos = f.pos.normalized() * r
