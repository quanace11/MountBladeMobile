extends TestBase
## Luật đánh và đỡ theo hướng.


func test_face_to_face_left_right_are_mirrored() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var a := sim.state.get_fighter(ids[0])
	var b := sim.state.get_fighter(ids[1])
	a.attack_dir = Dir.RIGHT
	check_eq(CombatResolver.required_block_dir(a, b), Dir.LEFT, "A chém từ phải thì B đỡ trái")
	a.attack_dir = Dir.LEFT
	check_eq(CombatResolver.required_block_dir(a, b), Dir.RIGHT, "A chém từ trái thì B đỡ phải")
	a.attack_dir = Dir.UP
	check_eq(CombatResolver.required_block_dir(a, b), Dir.UP, "Bổ trên thì đỡ trên")
	a.attack_dir = Dir.THRUST
	check_eq(CombatResolver.required_block_dir(a, b), Dir.THRUST, "Đâm thì đỡ đâm")


func _attack_vs_block(attack: int, block: int, b_def: String = "dao_tuong", dist: float = 1.5) -> Array:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", b_def, dist)
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(attack, t == 1), ids[1]: cmd(Dir.NONE, false, block)}
	var e := run_until(sim, fn, &"blocked")
	return [sim, ids, e]


func test_correct_block_takes_no_damage() -> void:
	var r := _attack_vs_block(Dir.RIGHT, Dir.LEFT)
	var sim: MatchSim = r[0]
	var b := sim.state.get_fighter(r[1][1])
	check(not (r[2] as Dictionary).is_empty(), "phải có sự kiện blocked")
	check_eq(b.hp, b.def.max_hp, "B không mất máu")
	check(b.stamina < b.def.max_stamina, "B mất thể lực khi đỡ")
	check_eq(sim.state.get_fighter(r[1][0]).state, FighterState.State.STAGGER, "A bị khựng")
	check(sim.state.get_fighter(r[1][0]).recoil, "A khựng vì bị đỡ (vũ khí dội lại), không phải vì trúng đòn")
	check_eq(b.state, FighterState.State.BLOCK, "B vẫn giữ thế đỡ, không bị khựng")


func test_wrong_block_takes_damage() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(Dir.RIGHT, t == 1), ids[1]: cmd(Dir.NONE, false, Dir.RIGHT)}
	var e := run_until(sim, fn, &"hit")
	var b := sim.state.get_fighter(ids[1])
	check(not e.is_empty(), "đỡ sai hướng phải trúng")
	check(b.hp < b.def.max_hp, "B mất máu")
	check(not b.recoil, "trúng đòn là khựng thường")


func test_parry_when_block_is_raised_late() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var fn := func(t: int) -> Dictionary:
		var a: FighterState = sim.state.get_fighter(ids[0])
		var late := a.state == FighterState.State.RELEASE
		return {ids[0]: cmd(Dir.UP, t == 1), ids[1]: cmd(Dir.NONE, false, Dir.UP if late else Dir.NONE)}
	var e := run_until(sim, fn, &"parried")
	check(not e.is_empty(), "giơ đỡ sát lúc trúng phải là đỡ hoàn hảo")


func test_out_of_range_misses() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 5.0)
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(Dir.LEFT, t == 1)}
	check(not run_until(sim, fn, &"miss").is_empty(), "ngoài tầm thì chém hụt")
	var b := sim.state.get_fighter(ids[1])
	check_eq(b.hp, b.def.max_hp, "B không mất máu")


func test_only_first_target_is_hit() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.2)
	var far := sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0.4, 1.9), 0.0)
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(Dir.RIGHT, t == 1)}
	var e := run_until(sim, fn, &"hit")
	check_eq(e.get("target", -1), ids[1], "trúng người gần nhất")
	var f := sim.state.get_fighter(far)
	check_eq(f.hp, f.def.max_hp, "người phía sau không bị trúng")


func test_attack_from_behind_cannot_be_blocked() -> void:
	var sim := make_sim()
	var a := sim.add_fighter(char_def("dao_tuong"), 0, Vector2(0, 0), FighterState.yaw_from_direction(Vector2(0, 1)))
	# B quay lưng lại A.
	var b := sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0, 1.5), FighterState.yaw_from_direction(Vector2(0, 1)))
	sim.ctx.config = sim.ctx.config.duplicate()
	sim.ctx.config.auto_face_range = 0.0
	var fn := func(t: int) -> Dictionary:
		return {a: cmd(Dir.UP, t == 1), b: cmd(Dir.NONE, false, Dir.UP)}
	check(not run_until(sim, fn, &"hit").is_empty(), "đòn sau lưng không đỡ được")


func test_guard_breaks_without_stamina() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	sim.state.get_fighter(ids[1]).stamina = 1.0
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(Dir.RIGHT, t == 1), ids[1]: cmd(Dir.NONE, false, Dir.LEFT)}
	check(not run_until(sim, fn, &"guard_broken").is_empty(), "hết thể lực thì bị phá thế")


func test_shield_blocks_any_direction() -> void:
	var r := _attack_vs_block(Dir.RIGHT, Dir.UP, "kiem_tuong")
	check(not (r[2] as Dictionary).is_empty(), "khiên đỡ được mọi hướng phía trước")


func test_hit_interrupts_windup() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "dao_tuong", 1.5)
	var fn := func(t: int) -> Dictionary:
		return {ids[0]: cmd(Dir.LEFT, t == 1), ids[1]: cmd(Dir.UP)}
	run_until(sim, fn, &"hit")
	var b := sim.state.get_fighter(ids[1])
	check_eq(b.state, FighterState.State.STAGGER, "trúng đòn thì mất đòn đang gồng")


func test_snapshot_roundtrip() -> void:
	var sim := make_sim()
	var ids := face_off(sim, "dao_tuong", "thuong_tuong", 1.5)
	for t in 5:
		sim.step({ids[0]: cmd(Dir.LEFT)})
	var d := sim.state.to_dict()
	var copy := MatchState.from_dict(d)
	check_eq(JSON.stringify(copy.to_dict()), JSON.stringify(d), "chụp rồi khôi phục phải giống hệt")
