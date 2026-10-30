class_name PlayerCommandSource
extends CommandSource
## Gộp cảm ứng và bàn phím thành FighterCommand. Hướng đi đổi theo góc camera.
## Tự ngắm: nhân vật quay mặt theo hướng camera.

var touch: TouchController
var keyboard := KeyboardController.new()
## Trả về góc yaw hiện tại của camera.
var camera_yaw: Callable
var free_aim := true
## Đang chém mà có địch gần tâm ngắm thì quay nhẹ về phía địch đó.
var aim_assist := false
## Giữ ĐỠ thì tự giơ đỡ về phía đòn của địch đang chém mình.
var auto_block := true
## Trợ ngắm: chỉ hút về địch nằm trong góc này quanh tâm ngắm (độ).
const ASSIST_HALF_ANGLE_DEG := 35.0


func _init(p_touch: TouchController, p_camera_yaw: Callable) -> void:
	touch = p_touch
	camera_yaw = p_camera_yaw


func get_command(state: MatchState) -> FighterCommand:
	var c := FighterCommand.new()
	keyboard.poll_attack()

	var screen := touch.move_vector()
	if screen == Vector2.ZERO:
		screen = keyboard.move_vector()
	var yaw: float = camera_yaw.call()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	c.move = right * screen.x + fwd * (-screen.y)
	c.has_face = free_aim
	c.face_yaw = yaw

	# Gọi cả hai để bàn phím luôn cập nhật trạng thái phím.
	c.dodge = keyboard.consume_dodge()
	c.block_dir = touch.block_dir()
	if c.block_dir == Dir.NONE:
		c.block_dir = keyboard.block_dir()
	if auto_block and c.block_dir != Dir.NONE:
		var incoming := _incoming_block_dir(state)
		if incoming != Dir.NONE:
			c.block_dir = incoming

	var key_dir := keyboard.attack_dir()
	var released := touch.consume_release()
	if released != Dir.NONE:
		c.attack_dir = released
		c.attack_release = true
	elif keyboard.consume_release():
		c.attack_dir = key_dir
		c.attack_release = true
	else:
		c.attack_dir = touch.attack_dir() if touch.attack_dir() != Dir.NONE else key_dir

	if free_aim and aim_assist and c.attack_dir != Dir.NONE:
		_assist(c, state)
	return c


func _assist(c: FighterCommand, state: MatchState) -> void:
	var me := state.get_fighter(fighter_id)
	if me == null:
		return
	var aim := Vector2(-sin(c.face_yaw), -cos(c.face_yaw))
	var best_d := me.def.weapon.reach + 1.5
	for o in state.fighters:
		if o.team == me.team or not o.is_alive():
			continue
		var to := o.pos - me.pos
		var d := to.length()
		if d < 0.001 or d > best_d:
			continue
		if rad_to_deg(absf(aim.angle_to(to))) > ASSIST_HALF_ANGLE_DEG:
			continue
		best_d = d
		c.face_yaw = FighterState.yaw_from_direction(to / d)


## Hướng cần đỡ đòn của địch gần nhất đang gồng hoặc đang chém về phía mình; NONE nếu không có.
func _incoming_block_dir(state: MatchState) -> int:
	var me := state.get_fighter(fighter_id)
	if me == null:
		return Dir.NONE
	var best: FighterState = null
	var best_d := INF
	for o in state.fighters:
		if o.team == me.team or not o.is_alive() or o.attack_dir == Dir.NONE:
			continue
		if o.state != FighterState.State.WINDUP and o.state != FighterState.State.RELEASE:
			continue
		var d := o.pos.distance_to(me.pos)
		# Chỉ tính địch đang quay về phía mình và đủ gần để đòn tới.
		if d > o.def.weapon.reach + 1.5 or CombatResolver.angle_to(o, me.pos) > deg_to_rad(70.0):
			continue
		if d < best_d:
			best_d = d
			best = o
	return CombatResolver.required_block_dir(best, me) if best else Dir.NONE
