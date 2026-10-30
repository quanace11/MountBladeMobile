class_name BotBrain
extends CommandSource
## Bot đọc MatchState rồi tạo FighterCommand giống hệt người chơi.
## Độ khôn lấy từ BotProfile: phản xạ, tỉ lệ đỡ sai, đỡ hoàn hảo, đánh lừa.
## Cách đánh theo Mount & Blade: chém vào phía đối thủ không đỡ, trừng phạt lúc đối thủ hở,
## chém xong lùi giữ khoảng cách, đôi khi lùi ra khỏi tầm thay vì đỡ. Khi đánh hội đồng,
## bot chỉ ra đòn khi không có ai đứng chắn giữa mình và đối thủ, bot khác vòng sang hai bên
## tìm chỗ trống, nên người chơi đứng sao cho địch dồn thành một hàng thì chỉ phải đỡ một người.

const S := FighterState.State

var profile: BotProfile
var ctx: SimContext
var tokens: AttackTokenManager
var rng := RandomNumberGenerator.new()

var _think_every: int = 3
var _last := FighterCommand.new()

# Phòng thủ: đòn đang nhắm vào bot.
var _threat_id: int = -1
var _threat_dir: int = Dir.NONE
var _react_tick: int = 0
var _plan_block: int = Dir.NONE
var _wait_for_release: bool = false

# Tấn công.
var _cooldown_until: int = 0
var _attack_dir: int = Dir.NONE
var _release_tick: int = 0
var _feint_tick: int = -1
var _strafe_sign: float = 1.0
var _strafe_until: int = 0
var _retreat_until: int = 0
## Lần đối thủ hở gần nhất đã cân nhắc trừng phạt (tick bắt đầu trạng thái hở của đối thủ).
var _punish_seen: int = -1
var _state: MatchState


func _init(p_id: int, p_profile: BotProfile, p_ctx: SimContext, p_tokens: AttackTokenManager, seed_value: int) -> void:
	fighter_id = p_id
	profile = p_profile
	ctx = p_ctx
	tokens = p_tokens
	rng.seed = seed_value
	_think_every = maxi(1, roundi(ctx.tick_rate / maxf(1.0, profile.think_hz)))
	_cooldown_until = ctx.ticks(rng.randf_range(profile.attack_cooldown_min, profile.attack_cooldown_max))


func get_command(state: MatchState) -> FighterCommand:
	var me := state.get_fighter(fighter_id)
	if me == null or not me.is_alive():
		tokens.release(fighter_id)
		return FighterCommand.new()
	if state.tick % _think_every != 0:
		var keep := FighterCommand.new()
		keep.move = _last.move
		keep.block_dir = _last.block_dir
		keep.attack_dir = _last.attack_dir
		return keep
	_last = _think(state, me)
	return _last


func _think(state: MatchState, me: FighterState) -> FighterCommand:
	var c := FighterCommand.new()
	var tick := state.tick
	_state = state
	var target := _nearest_enemy(state, me)
	if target == null:
		return c

	# --- Phòng thủ ---
	var threat := _find_threat(state, me)
	if threat == null:
		_threat_id = -1
	elif threat.id != _threat_id or threat.attack_dir != _threat_dir:
		_threat_id = threat.id
		_threat_dir = threat.attack_dir
		_decide_block(threat, me, tick)

	var blocking := false
	if threat != null and _plan_block != Dir.NONE:
		var ready := tick >= _react_tick
		if _wait_for_release:
			ready = ready and threat.state == S.RELEASE
		if ready:
			c.block_dir = _plan_block
			blocking = true

	# --- Tấn công ---
	if not blocking:
		_attack_logic(c, me, target, tick)

	# --- Di chuyển ---
	c.move = _movement(me, target, tick)
	return c


func _decide_block(threat: FighterState, me: FighterState, tick: int) -> void:
	_wait_for_release = false
	var roll := rng.randf()
	var reach := threat.def.weapon.reach + me.def.body_radius
	if rng.randf() < profile.step_back_chance and threat.state == S.WINDUP and me.pos.distance_to(threat.pos) > reach - 0.8:
		# Lùi ra khỏi tầm thay vì đỡ.
		_plan_block = Dir.NONE
		_retreat_until = tick + ctx.ticks(0.6)
		return
	if roll < profile.no_block_chance:
		_plan_block = Dir.NONE
		return
	var correct := CombatResolver.required_block_dir(threat, me)
	if rng.randf() < profile.wrong_block_chance:
		var others := [Dir.UP, Dir.THRUST, Dir.LEFT, Dir.RIGHT]
		others.erase(correct)
		_plan_block = others[rng.randi() % others.size()]
	else:
		_plan_block = correct
		_wait_for_release = rng.randf() < profile.parry_attempt_chance
	var react := profile.reaction_time + rng.randf_range(0.0, profile.reaction_jitter)
	_react_tick = tick + ctx.ticks(react)


func _attack_logic(c: FighterCommand, me: FighterState, target: FighterState, tick: int) -> void:
	var w := me.def.weapon
	var dist := me.pos.distance_to(target.pos)
	match me.state:
		S.IDLE:
			if _attack_dir != Dir.NONE:
				# Đòn trước đã xong hoặc bị ngắt.
				_finish_attack(tick)
			var in_reach := dist <= w.reach + target.def.body_radius
			var punish := in_reach and _should_punish(target)
			var rested := tick >= _cooldown_until or punish
			var can := rested and me.stamina >= maxf(profile.min_stamina_to_attack, w.attack_stamina_cost)
			if can and in_reach and _lane_clear(me, target) and tokens.request(fighter_id):
				_attack_dir = _choose_dir(me, target)
				var hold := ctx.ticks(w.windup_time)
				if not punish:
					hold += ctx.ticks(rng.randf_range(profile.hold_windup_min, profile.hold_windup_max))
				_release_tick = tick + hold
				_feint_tick = tick + hold / 2 if rng.randf() < profile.feint_chance else -1
				c.attack_dir = _attack_dir
		S.WINDUP:
			if _attack_dir == Dir.NONE:
				return
			if _feint_tick >= 0 and tick >= _feint_tick:
				_feint_tick = -1
				var others := [Dir.UP, Dir.THRUST, Dir.LEFT, Dir.RIGHT]
				others.erase(_attack_dir)
				_attack_dir = others[rng.randi() % others.size()]
				_release_tick = tick + ctx.ticks(w.windup_time)
			c.attack_dir = _attack_dir
			if tick >= _release_tick:
				c.attack_release = true
		S.RECOVERY, S.STAGGER, S.RELEASE:
			pass


func _finish_attack(tick: int) -> void:
	_attack_dir = Dir.NONE
	tokens.release(fighter_id)
	_cooldown_until = tick + ctx.ticks(rng.randf_range(profile.attack_cooldown_min, profile.attack_cooldown_max))
	_retreat_until = tick + ctx.ticks(profile.retreat_after_attack)


## Đối thủ đang hở (vừa chém xong, đang khựng): mỗi lần hở chỉ tung xúc xắc một lần.
func _should_punish(target: FighterState) -> bool:
	if target.state != S.RECOVERY and target.state != S.STAGGER:
		return false
	var opened := _state.tick - target.state_ticks
	if opened == _punish_seen:
		return false
	_punish_seen = opened
	return rng.randf() < profile.punish_chance


## Chọn hướng chém: đối thủ đang giơ đỡ thì chém vào phía không đỡ.
func _choose_dir(me: FighterState, target: FighterState) -> int:
	var all := [Dir.UP, Dir.THRUST, Dir.LEFT, Dir.RIGHT]
	if target.state == S.BLOCK and not target.def.weapon.has_shield and rng.randf() < profile.read_block_chance:
		var open := []
		for d in all:
			me.attack_dir = d
			if CombatResolver.required_block_dir(me, target) != target.block_dir:
				open.append(d)
		me.attack_dir = Dir.NONE
		if not open.is_empty():
			return open[rng.randi() % open.size()]
	return all[rng.randi() % 4]


## Không có ai đứng chắn giữa bot và đối thủ.
func _lane_clear(me: FighterState, target: FighterState) -> bool:
	var seg := target.pos - me.pos
	var len2 := seg.length_squared()
	if len2 < 0.0001:
		return true
	for o in _state.fighters:
		if o == me or o == target or not o.is_alive():
			continue
		var t := (o.pos - me.pos).dot(seg) / len2
		if t <= 0.05 or t >= 0.95:
			continue
		if (me.pos + seg * t).distance_to(o.pos) < o.def.body_radius + 0.25:
			return false
	return true


func _movement(me: FighterState, target: FighterState, tick: int) -> Vector2:
	var to := target.pos - me.pos
	var dist := to.length()
	if dist < 0.001:
		return Vector2.ZERO
	var dir := to / dist
	var want := me.def.weapon.reach * profile.preferred_range_factor
	var waiting := not tokens.has_token(fighter_id) and tokens.is_full()
	if waiting:
		# Chưa tới lượt: đứng vòng ngoài chờ.
		want += 1.5
	if tick < _retreat_until and me.state != S.WINDUP:
		# Vừa chém xong hoặc né đòn: lùi ra giữ khoảng cách.
		want = me.def.weapon.reach + target.def.weapon.reach * 0.5 + 0.6
	if tick >= _strafe_until:
		_strafe_sign = -1.0 if rng.randf() < 0.5 else 1.0
		_strafe_until = tick + ctx.ticks(rng.randf_range(1.0, 2.5))
	var side := Vector2(-dir.y, dir.x) * _strafe_sign * 0.35
	if not _lane_clear(me, target):
		# Có người chắn đường: vòng sang bên để tìm chỗ trống.
		side *= 2.5
	side += _spread(me) * 0.6
	if dist > want + 0.3:
		return (dir + side * 0.5).limit_length(1.0)
	if dist < want - 0.5:
		return (-dir + side).limit_length(1.0)
	return side


## Đẩy nhẹ ra xa đồng đội đứng quá gần để cả nhóm toả ra vây quanh.
func _spread(me: FighterState) -> Vector2:
	var push := Vector2.ZERO
	for o in _state.fighters:
		if o == me or o.team != me.team or not o.is_alive():
			continue
		var away := me.pos - o.pos
		var d := away.length()
		if d > 0.001 and d < 1.6:
			push += away / d * (1.6 - d)
	return push.limit_length(1.0)


func _nearest_enemy(state: MatchState, me: FighterState) -> FighterState:
	var best: FighterState = null
	var best_d := INF
	for o in state.fighters:
		if o.team == me.team or not o.is_alive():
			continue
		var d := me.pos.distance_to(o.pos)
		if d < best_d:
			best_d = d
			best = o
	return best


## Địch đang gồng hoặc đang chém mà bot nằm trong tầm và cung chém của nó.
func _find_threat(state: MatchState, me: FighterState) -> FighterState:
	var best: FighterState = null
	var best_d := INF
	for o in state.fighters:
		if o.team == me.team or not o.is_alive():
			continue
		if o.state != S.WINDUP and o.state != S.RELEASE:
			continue
		var w := o.def.weapon
		var d := o.pos.distance_to(me.pos)
		if d > w.reach + me.def.body_radius + 0.6:
			continue
		if CombatResolver.angle_to(o, me.pos) > deg_to_rad(w.arc_half_angle_deg + 15.0):
			continue
		if d < best_d:
			best_d = d
			best = o
	return best
