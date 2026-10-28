class_name TestBase
extends RefCounted
## Hàm tiện ích cho test.

const CONFIG := "res://config/"


func check(cond: bool, msg: String) -> void:
	if not cond:
		(get_meta("runner") as Object).call("fail", msg)


func check_eq(a, b, msg: String) -> void:
	check(a == b, "%s (được %s, mong đợi %s)" % [msg, str(a), str(b)])


func make_sim() -> MatchSim:
	var cfg: GameConfig = load(CONFIG + "game_config.tres")
	var rules: CombatRules = load(CONFIG + "combat_rules.tres")
	return MatchSim.new(cfg, rules)


func char_def(id: String) -> CharacterDef:
	return load(CONFIG + "characters/" + id + ".tres")


## Đặt hai tướng đối mặt nhau, cách nhau dist mét. Trả về [id_a, id_b].
func face_off(sim: MatchSim, a_def: String, b_def: String, dist: float) -> Array:
	var a := sim.add_fighter(char_def(a_def), 0, Vector2(0, 0), FighterState.yaw_from_direction(Vector2(0, 1)))
	var b := sim.add_fighter(char_def(b_def), 1, Vector2(0, dist), FighterState.yaw_from_direction(Vector2(0, -1)))
	return [a, b]


func cmd(attack: int = Dir.NONE, release: bool = false, block: int = Dir.NONE) -> FighterCommand:
	var c := FighterCommand.new()
	c.attack_dir = attack
	c.attack_release = release
	c.block_dir = block
	return c


## Chạy sim tới khi gặp sự kiện có type, tối đa max_ticks. Trả về sự kiện hoặc {}.
func run_until(sim: MatchSim, commands_fn: Callable, type: StringName, max_ticks: int = 90) -> Dictionary:
	for i in max_ticks:
		var events := sim.step(commands_fn.call(sim.state.tick + 1))
		for e in events:
			if e["type"] == type:
				return e
	return {}
