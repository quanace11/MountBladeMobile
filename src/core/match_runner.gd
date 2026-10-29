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
		v.setup(f, ConfigDB.poses, f.id == player_id)
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

	var audio := AudioDirector.new()
	add_child(audio)
	audio.setup(ConfigDB.audio)

	var qm := QualityManager.new()
	add_child(qm)
	qm.setup(quality)

	touch = TouchController.new()
	add_child(touch)
	touch.setup(ConfigDB.input, Game.block_scheme)

	var player_src := PlayerCommandSource.new(touch, func() -> float: return camera_rig.yaw)
	player_src.fighter_id = player_id
	sources.append(player_src)

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


func _process(delta: float) -> void:
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
		&"blocked", &"parried", &"guard_broken":
			vfx.sparks(_contact_point(e))
			_shake_if_player(e, ConfigDB.game.camera_shake_block)
		&"hit":
			vfx.blood(_contact_point(e))
			(views[e["target"]] as FighterView).flash()
			_shake_if_player(e, ConfigDB.game.camera_shake_hit)
		&"match_over":
			EventBus.match_over.emit(e["winner"])


func _contact_point(e: Dictionary) -> Vector3:
	var a := sim.state.get_fighter(e["id"])
	var t := sim.state.get_fighter(e["target"])
	var p := a.pos.lerp(t.pos, 0.7)
	return Vector3(p.x, 1.3, p.y)


func _shake_if_player(e: Dictionary, amount: float) -> void:
	if e.get("id", -1) == player_id or e.get("target", -1) == player_id:
		camera_rig.shake(amount)
