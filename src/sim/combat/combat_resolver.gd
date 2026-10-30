class_name CombatResolver
extends RefCounted
## Xét một đòn chém lúc lưỡi vũ khí chạm: trúng ai, bị đỡ, đỡ hoàn hảo hay trúng.

const S := FighterState.State


## Hướng người đỡ phải đỡ, theo hệ toạ độ của người đỡ.
## A chém từ bên phải của A, hai người đối mặt thì B thấy đòn đến từ bên trái của B.
static func required_block_dir(attacker: FighterState, defender: FighterState) -> int:
	var d := attacker.attack_dir
	if d != Dir.LEFT and d != Dir.RIGHT:
		return d
	var origin := attacker.right() * (1.0 if d == Dir.RIGHT else -1.0)
	return Dir.RIGHT if origin.dot(defender.right()) >= 0.0 else Dir.LEFT


static func angle_to(f: FighterState, point: Vector2) -> float:
	var to := point - f.pos
	if to.length() < 0.0001:
		return 0.0
	return absf(f.forward().angle_to(to.normalized()))


## Địch đầu tiên (gần nhất) nằm trong tầm và cung chém. Không có thì trả về null.
## Có ctx thì bỏ qua địch đang lăn trong lúc miễn trúng.
static func find_target(attacker: FighterState, fighters: Array[FighterState], ctx: SimContext = null) -> FighterState:
	var w := attacker.def.weapon
	var best: FighterState = null
	var best_dist := INF
	for t in fighters:
		if t == attacker or not t.is_alive() or t.team == attacker.team:
			continue
		if ctx and FighterSim.is_invulnerable(t, ctx):
			continue
		var dist := attacker.pos.distance_to(t.pos)
		if dist > w.reach + t.def.body_radius:
			continue
		if angle_to(attacker, t.pos) > deg_to_rad(w.arc_half_angle_deg):
			continue
		if dist < best_dist:
			best_dist = dist
			best = t
	return best


## Hệ số sát thương theo tốc độ lao vào nhau dọc hướng chém (như Mount & Blade):
## chạy tới khi chém thì mạnh hơn, vừa chém vừa lùi thì yếu hơn.
static func speed_bonus(attacker: FighterState, target: FighterState, rules: CombatRules) -> float:
	var to := target.pos - attacker.pos
	if to.length() < 0.001:
		return 1.0
	var closing := (attacker.velocity - target.velocity).dot(to.normalized())
	return clampf(1.0 + closing * rules.speed_bonus_per_mps, rules.speed_bonus_min, rules.speed_bonus_max)


## Bị chém trúng: mất đòn đang gồng/đang chém, khựng một lúc.
static func stun(target: FighterState, ctx: SimContext) -> void:
	target.attack_dir = Dir.NONE
	target.block_dir = Dir.NONE
	target.release_queued = false
	target.buffered_attack_dir = Dir.NONE
	target.set_state(S.STAGGER, ctx.ticks(ctx.rules.hit_stun))


## impacting: các tướng có đòn chạm trong cùng tick. Người bị trúng mà cũng đang có đòn chạm thì
## chưa khựng ngay (để đòn của họ vẫn được xét), mà được thêm vào stunned để khựng sau.
static func resolve_impact(attacker: FighterState, fighters: Array[FighterState], ctx: SimContext, tick: int, events: Array,
		impacting: Array[FighterState] = [], stunned: Array[FighterState] = []) -> void:
	var rules := ctx.rules
	var w := attacker.def.weapon
	var target := find_target(attacker, fighters, ctx)
	if target == null:
		events.append({"type": &"miss", "id": attacker.id, "dir": attacker.attack_dir})
		attacker.set_state(S.RECOVERY, ctx.ticks(w.recovery_time))
		return

	var dmg := w.damage_for(attacker.attack_dir) * speed_bonus(attacker, target, rules)
	var need := required_block_dir(attacker, target)
	var in_cone := angle_to(target, attacker.pos) <= deg_to_rad(rules.block_half_angle_deg)
	var dir_ok := target.block_dir == need or target.def.weapon.has_shield
	var base := {"id": attacker.id, "target": target.id, "dir": attacker.attack_dir, "need": need}

	if target.state == S.BLOCK and in_cone and dir_ok:
		var parried := tick - target.block_started_tick <= ctx.ticks(rules.parry_window)
		if parried:
			if rules.use_stamina and rules.parry_costs_stamina:
				target.stamina = maxf(0.0, target.stamina - dmg * rules.block_stamina_per_damage)
			attacker.set_state(S.STAGGER, ctx.ticks(rules.stagger_on_parried))
			attacker.recoil = true
			events.append(base.merged({"type": &"parried"}))
			return
		var cost := dmg * rules.block_stamina_per_damage if rules.use_stamina else 0.0
		target.stamina_wait = ctx.ticks(rules.stamina_regen_delay)
		if rules.use_stamina and target.stamina < cost:
			target.stamina = 0.0
			target.block_dir = Dir.NONE
			target.set_state(S.STAGGER, ctx.ticks(rules.guard_break_stun))
			attacker.set_state(S.RECOVERY, ctx.ticks(w.recovery_time))
			events.append(base.merged({"type": &"guard_broken"}))
			return
		target.stamina -= cost
		attacker.set_state(S.STAGGER, ctx.ticks(rules.stagger_on_blocked))
		attacker.recoil = true
		events.append(base.merged({"type": &"blocked"}))
		return

	target.hp = maxf(0.0, target.hp - dmg)
	attacker.set_state(S.RECOVERY, ctx.ticks(w.recovery_time))
	events.append(base.merged({"type": &"hit", "damage": dmg}))
	if target.hp <= 0.0:
		target.set_state(S.DEAD)
		events.append({"type": &"died", "id": target.id, "by": attacker.id})
	elif impacting.has(target):
		if not stunned.has(target):
			stunned.append(target)
	else:
		stun(target, ctx)
