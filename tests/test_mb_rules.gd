extends TestBase
## Luật theo Mount & Blade: chém trúng nhau cùng lúc, sát thương theo tốc độ, bot đọc thế đỡ.


func test_simultaneous_hits_both_land() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var hits := 0
	for t in 40:
		for e in sim.step({ids[0]: cmd(Dir.RIGHT, t == 0), ids[1]: cmd(Dir.LEFT, t == 0)}):
			if e["type"] == &"hit":
				hits += 1
	check_eq(hits, 2, "hai người chém trúng nhau cùng lúc thì cả hai đòn đều tính")
	for id in ids:
		var f := sim.state.get_fighter(id)
		check(f.hp < f.def.max_hp, "cả hai đều mất máu")


func test_hit_interrupts_attack() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var b := sim.state.get_fighter(ids[1])
	var b_released := false
	for t in 40:
		# B bắt đầu gồng sau A nên bị A chém trúng khi đang gồng.
		for e in sim.step({ids[0]: cmd(Dir.RIGHT, t == 0), ids[1]: cmd(Dir.UP, t == 10) if t >= 8 else cmd()}):
			if e["type"] == &"attack_released" and e["id"] == ids[1]:
				b_released = true
		if b.state == FighterState.State.STAGGER:
			break
	check(not b_released, "bị chém trúng khi đang gồng thì mất đòn")


func test_running_into_attack_hits_harder() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var a := sim.state.get_fighter(ids[0])
	var b := sim.state.get_fighter(ids[1])
	var rules := sim.ctx.rules
	a.velocity = Vector2(0, 3)
	var fwd := CombatResolver.speed_bonus(a, b, rules)
	a.velocity = Vector2(0, -2)
	var back := CombatResolver.speed_bonus(a, b, rules)
	a.velocity = Vector2.ZERO
	check(fwd > 1.15, "lao tới chém mạnh hơn (x%.2f)" % fwd)
	check(back < 0.9, "vừa lùi vừa chém yếu hơn (x%.2f)" % back)
	check_eq(CombatResolver.speed_bonus(a, b, rules), 1.0, "đứng yên thì bình thường")


func test_too_close_hits_with_the_hilt() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 0.6)
	var a := sim.state.get_fighter(ids[0])
	var b := sim.state.get_fighter(ids[1])
	var close := CombatResolver.sweet_spot(a, b, sim.ctx.rules)
	b.pos = Vector2(0, 1.7)
	var sweet := CombatResolver.sweet_spot(a, b, sim.ctx.rules)
	check(close <= 0.6, "đứng sát thì trúng cán đao, đau ít (x%.2f)" % close)
	check_eq(sweet, 1.0, "đúng tầm lưỡi đao thì đủ sát thương")


func _bot_vs_blocker(block: int) -> Dictionary:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.6)
	var hard: BotProfile = load(CONFIG + "ai/hard.tres").duplicate()
	hard.read_block_chance = 1.0
	var bot := BotBrain.new(ids[0], hard, sim.ctx, AttackTokenManager.new(1), 3)
	var counts := {}
	for t in sim.ctx.tick_rate * 20:
		var c := bot.get_command(sim.state)
		c.move = Vector2.ZERO
		# Chỉ đếm đòn ra khi đối thủ đang giơ đỡ (bị chém trúng, đang khựng thì không đỡ).
		var guarding := sim.state.get_fighter(ids[1]).state == FighterState.State.BLOCK
		for e in sim.step({ids[0]: c, ids[1]: cmd(Dir.NONE, false, block)}):
			if e["type"] == &"attack_started" and guarding:
				counts[e["dir"]] = counts.get(e["dir"], 0) + 1
	return counts


func test_bot_attacks_unguarded_side() -> void:
	var counts := _bot_vs_blocker(Dir.UP)
	check(not counts.is_empty(), "bot có tấn công")
	check(not counts.has(Dir.UP), "đối thủ đỡ trên thì bot không bổ từ trên (%s)" % counts)


func test_bot_waits_when_lane_blocked() -> void:
	var sim := make_sim()
	var hero := sim.add_fighter(char_def("dao_tuong"), 0, Vector2(0, 0), 0.0)
	var front := sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0, -1.0), 0.0)
	var back := sim.add_fighter(char_def("thuong_tuong"), 1, Vector2(0, -2.2), 0.0)
	var bot := BotBrain.new(back, load(CONFIG + "ai/hard.tres"), sim.ctx, AttackTokenManager.new(3), 4)
	# Đã qua lúc nghỉ đầu trận, đối thủ trong tầm giáo.
	sim.state.tick = 600
	var c := bot.get_command(sim.state)
	check_eq(c.attack_dir, Dir.NONE, "có đồng đội đứng chắn giữa bot và đối thủ thì bot không ra đòn")
	sim.state.get_fighter(front).pos = Vector2(3, -1.0)
	c = bot.get_command(sim.state)
	check(c.attack_dir != Dir.NONE, "đồng đội tránh ra thì bot ra đòn")
	sim.state.get_fighter(front).pos = Vector2(0, -1.0)
	c = bot.get_command(sim.state)
	check(c.move.x != 0.0, "bot vòng sang bên tìm chỗ trống")
	var _unused := [hero, front]


func test_can_block_right_after_own_attack() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 5.0)
	var a := sim.state.get_fighter(ids[0])
	for t in 40:
		sim.step({ids[0]: cmd(Dir.UP, t == 0)})
		if a.state == FighterState.State.RECOVERY:
			break
	check_eq(a.state, FighterState.State.RECOVERY, "đang thu đao sau cú chém hụt")
	sim.step({ids[0]: cmd(Dir.NONE, false, Dir.LEFT)})
	check_eq(a.state, FighterState.State.BLOCK, "đang thu đao vẫn giơ đỡ được ngay")
