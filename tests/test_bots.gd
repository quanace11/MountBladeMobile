extends TestBase
## Bot đánh với bot cho tới khi trận kết thúc.


func _bot_match(n_enemies: int) -> MatchSim:
	var sim := make_sim()
	var tokens := AttackTokenManager.new(sim.ctx.config.max_attackers_at_once)
	var own_tokens := AttackTokenManager.new(1)
	var hard: BotProfile = load(CONFIG + "ai/hard.tres")
	var easy: BotProfile = load(CONFIG + "ai/easy.tres")
	var bots: Array[BotBrain] = []
	var hero := sim.add_fighter(char_def("dao_tuong"), 0, Vector2(0, -3), 0.0)
	bots.append(BotBrain.new(hero, hard, sim.ctx, own_tokens, 1))
	for i in n_enemies:
		var id := sim.add_fighter(char_def("thuong_tuong"), 1, Vector2(i * 1.5 - 1.0, 3), PI)
		bots.append(BotBrain.new(id, easy, sim.ctx, tokens, 10 + i))
	for t in sim.ctx.tick_rate * 300:
		var cmds := {}
		for b in bots:
			cmds[b.fighter_id] = b.get_command(sim.state)
		sim.step(cmds)
		if sim.state.finished:
			break
	return sim


func test_bot_1v1_finishes() -> void:
	var sim := _bot_match(1)
	check(sim.state.finished, "trận 1 vs 1 giữa hai bot phải kết thúc trong 5 phút")


func test_bot_1v3_finishes() -> void:
	var sim := _bot_match(3)
	check(sim.state.finished, "trận 1 vs 3 giữa các bot phải kết thúc trong 5 phút")
