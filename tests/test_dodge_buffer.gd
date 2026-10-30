extends TestBase
## Nhớ lệnh chém bấm sớm, lăn né.


## A chém hụt (B ở xa), rồi nhả lệnh chém lần hai ngay lúc đang thu vũ khí: phải chém tiếp chứ không mất lệnh.
func test_attack_released_during_recovery_is_buffered() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 8.0)
	var a := sim.state.get_fighter(ids[0])
	var released := 0
	var sent_second := false
	for t in 90:
		var c := FighterCommand.new()
		if t == 0:
			c = cmd(Dir.RIGHT, true)
		elif a.state == FighterState.State.RECOVERY and not sent_second:
			c = cmd(Dir.UP, true)
			sent_second = true
		for e in sim.step({ids[0]: c}):
			if e["type"] == &"attack_released" and e["id"] == ids[0]:
				released += 1
	check(sent_second, "có lúc đang thu vũ khí")
	check_eq(released, 2, "lệnh chém bấm lúc đang thu vũ khí vẫn được chém")


func test_buffer_expires() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 8.0)
	var a := sim.state.get_fighter(ids[0])
	a.set_state(FighterState.State.STAGGER, sim.ctx.ticks(1.0))
	sim.step({ids[0]: cmd(Dir.UP, true)})
	var released := false
	for t in 60:
		for e in sim.step({}):
			if e["type"] == &"attack_started":
				released = true
	check(not released, "bấm quá sớm (trước khi hết khựng lâu) thì không tự chém")


func test_dodge_moves_and_avoids_hit() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var b := sim.state.get_fighter(ids[1])
	var start := b.pos
	var hit := false
	var missed := false
	for t in 40:
		var cb := FighterCommand.new()
		var a := sim.state.get_fighter(ids[0])
		# B lăn ngang đúng lúc A vừa nhả đòn.
		cb.dodge = a.state == FighterState.State.RELEASE and a.state_ticks == 1
		cb.move = Vector2(1, 0)
		for e in sim.step({ids[0]: cmd(Dir.UP, t == 0), ids[1]: cb}):
			if e["type"] == &"hit":
				hit = true
			if e["type"] == &"miss":
				missed = true
	check(not hit and missed, "đang lăn thì đòn chém hụt")
	check(b.pos.distance_to(start) > 2.0, "lăn đi được quãng dài (%.2f m)" % b.pos.distance_to(start))


func test_no_dodge_without_stamina() -> void:
	var sim := make_sim()
	_use_stamina(sim)
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 5.0)
	var a := sim.state.get_fighter(ids[0])
	a.stamina = 5.0
	var c := FighterCommand.new()
	c.dodge = true
	var events := sim.step({ids[0]: c})
	check(a.state != FighterState.State.DODGE, "hết thể lực thì không lăn")
	check(events.any(func(e): return e["type"] == &"no_stamina"), "báo hết thể lực")
