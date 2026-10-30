class_name MatchRunner
extends Node3D
## Ghép các tầng cho một trận: tạo sim, nguồn lệnh, hình ảnh, âm thanh, UI.
## Chạy sim theo tick cố định; hình ảnh nội suy giữa hai tick.

const MAX_STEPS_PER_FRAME := 5

var sim: MatchSim
var sources: Array[CommandSource] = []
var views: Dictionary = {}  # id -> FighterView
var player_id: int = -1
var camera_rig: CameraRig
var touch: TouchController
var player_src: PlayerCommandSource
var vfx: VfxPool
var hud: Hud

var _acc := 0.0
var _prev_pos: Dictionary = {}
var _prev_yaw: Dictionary = {}


func _ready() -> void:
	var cfg := ConfigDB.game
	var quality := Game.current_quality()
	sim = MatchSim.new(cfg, ConfigDB.rules)

	var md := Game.current_match()
	var half := cfg.spawn_distance * 0.5
	player_id = sim.add_fighter(Game.player_character(), 0, Vector2(0, half), FighterState.yaw_from_direction(Vector2(0, -1)))
	var n := md.enemy_characters.size()
	for i in n:
		var spread := (i - (n - 1) * 0.5) * 2.0
		sim.add_fighter(md.enemy_characters[i], 1, Vector2(spread, -half), FighterState.yaw_from_direction(Vector2(0, 1)))

	ArenaBuilder.build(self, cfg, quality, ConfigDB.arena)

	for f in sim.state.fighters:
		var v := FighterView.new()
		add_child(v)
		v.setup(f, ConfigDB.poses, f.id == player_id, Game.player_model() if f.id == player_id else null)
		views[f.id] = v
		_prev_pos[f.id] = f.pos
		_prev_yaw[f.id] = f.yaw
		v.sync(f, f.pos, f.yaw, 1.0, 0.0)

	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(cfg, views[player_id])
	camera_rig.obstacles = views.values()

	vfx = VfxPool.new()
	add_child(vfx)
	vfx.setup(quality.max_vfx)
	var fwd := Vector3(-sin(camera_rig.yaw), 0.0, -cos(camera_rig.yaw))
	vfx.warm_up(views[player_id].global_position + fwd * 3.0 + Vector3.UP)

	var audio := AudioDirector.new()
	add_child(audio)
	audio.setup(ConfigDB.audio)

	var qm := QualityManager.new()
	add_child(qm)
	qm.setup(quality)

	touch = TouchController.new()
	add_child(touch)
	touch.setup(ConfigDB.input, InputConfig.BlockScheme.BUTTON)

	player_src = PlayerCommandSource.new(touch, func() -> float: return camera_rig.yaw)
	player_src.fighter_id = player_id
	sources.append(player_src)
	apply_controls()

	var tokens := AttackTokenManager.new(cfg.max_attackers_at_once)
	var seed_base := cfg.rng_seed if cfg.rng_seed != 0 else int(Time.get_unix_time_from_system())
	for f in sim.state.fighters:
		if f.id != player_id:
			sources.append(BotBrain.new(f.id, Game.current_bot(), sim.ctx, tokens, seed_base + f.id))

	var ui := CanvasLayer.new()
	add_child(ui)
	var overlay := TouchOverlay.new()
	ui.add_child(overlay)
	overlay.setup(touch)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(self, qm)

	EventBus.sim_event.connect(_on_event)
	EventBus.match_started.emit(self)


func _exit_tree() -> void:
	if EventBus.sim_event.is_connected(_on_event):
		EventBus.sim_event.disconnect(_on_event)


## Áp cách điều khiển đang chọn (Game.controls()) cho camera, cảm ứng và lệnh người chơi.
func apply_controls() -> void:
	var p := Game.controls()
	camera_rig.free_look = p.free_aim
	camera_rig.distance = p.camera_distance
	touch.free_look = p.free_aim
	touch.attack_button = p.attack_button
	touch.button_scale = p.button_scale
	touch.look_mult = p.look_sensitivity
	touch.combat.scheme = p.block_scheme
	player_src.free_aim = p.free_aim
	player_src.aim_assist = p.aim_assist


func _process(delta: float) -> void:
	var turn := touch.consume_look() + KeyboardController.turn_axis() * deg_to_rad(ConfigDB.input.key_turn_speed_deg) * delta
	camera_rig.turn(turn)
	var dt := sim.ctx.dt
	_acc += delta
	var steps := 0
	while _acc >= dt and steps < MAX_STEPS_PER_FRAME:
		_tick()
		_acc -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_acc = 0.0
	var alpha := clampf(_acc / dt, 0.0, 1.0)
	for f in sim.state.fighters:
		(views[f.id] as FighterView).sync(f, _prev_pos[f.id], _prev_yaw[f.id], alpha, delta)


func _tick() -> void:
	for f in sim.state.fighters:
		_prev_pos[f.id] = f.pos
		_prev_yaw[f.id] = f.yaw
	var cmds := {}
	for s in sources:
		cmds[s.fighter_id] = s.get_command(sim.state)
	for e in sim.step(cmds):
		EventBus.sim_event.emit(e)


func player() -> FighterState:
	return sim.state.get_fighter(player_id)


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"blocked":
			vfx.clash(_clash_point(e))
			(views[e["target"]] as FighterView).jolt(1.0)
			_shake_if_player(e, ConfigDB.game.camera_shake_block)
		&"parried":
			vfx.clash(_clash_point(e), 1.8, Color(0.75, 0.9, 1.0))
			(views[e["target"]] as FighterView).jolt(0.6)
			_shake_if_player(e, ConfigDB.game.camera_shake_block * 1.5)
		&"guard_broken":
			vfx.clash(_clash_point(e), 1.4, Color(1.0, 0.55, 0.3))
			(views[e["target"]] as FighterView).jolt(1.6)
			_shake_if_player(e, ConfigDB.game.camera_shake_hit)
		&"hit":
			var blow := _blow_dir(e["id"], e["target"], int(e["dir"]))
			var strength := clampf(float(e.get("damage", 30.0)) / 30.0, 0.5, 2.0)
			vfx.blood(_contact_point(e), blow, strength)
			var tv := views[e["target"]] as FighterView
			tv.flash()
			tv.hit_react(blow, strength)
			_shake_if_player(e, ConfigDB.game.camera_shake_hit)
		&"died":
			var by: int = e.get("by", -1)
			var dead := sim.state.get_fighter(e["id"])
			var killer := sim.state.get_fighter(by)
			var blow := _blow_dir(by, e["id"], killer.attack_dir if killer else Dir.UP) if killer else Vector3.BACK
			(views[e["id"]] as FighterView).die(blow)
			# Vũng máu loang dần dưới chỗ thân ngã xuống.
			var at := dead.pos + Vector2(blow.x, blow.z).normalized() * 0.9
			vfx.splat(at, 1.6, 2.0)
		&"match_over":
			EventBus.match_over.emit(e["winner"])


## Hướng lưỡi vũ khí đi khi trúng (thế giới): từ người chém về người bị chém; chém ngang thì
## lệch thêm sang bên mà lưỡi quét tới (chém từ phải quét sang trái của người chém).
func _blow_dir(attacker_id: int, target_id: int, dir: int) -> Vector3:
	var a := sim.state.get_fighter(attacker_id)
	var t := sim.state.get_fighter(target_id)
	if a == null or t == null:
		return Vector3.BACK
	var v := (t.pos - a.pos).normalized()
	match dir:
		Dir.RIGHT: v -= a.right() * 0.9
		Dir.LEFT: v += a.right() * 0.9
	v = v.normalized()
	return Vector3(v.x, 0.0, v.y)


func _contact_point(e: Dictionary) -> Vector3:
	var a := sim.state.get_fighter(e["id"])
	var t := sim.state.get_fighter(e["target"])
	var p := a.pos.lerp(t.pos, 0.7)
	return Vector3(p.x, 1.3, p.y)


## Chỗ hai binh khí chạm nhau: sát người đỡ, cao theo hướng đòn.
func _clash_point(e: Dictionary) -> Vector3:
	var a := sim.state.get_fighter(e["id"])
	var t := sim.state.get_fighter(e["target"])
	var p := a.pos.lerp(t.pos, 0.6)
	var h := 1.4
	match int(e["dir"]):
		Dir.UP: h = 1.8
		Dir.THRUST: h = 1.15
	return Vector3(p.x, h, p.y)


func _shake_if_player(e: Dictionary, amount: float) -> void:
	if e.get("id", -1) == player_id or e.get("target", -1) == player_id:
		camera_rig.shake(amount)
