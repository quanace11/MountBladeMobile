class_name PlayerCommandSource
extends CommandSource
## Gộp cảm ứng và bàn phím thành FighterCommand. Hướng đi đổi theo góc camera.

var touch: TouchController
var keyboard := KeyboardController.new()
## Trả về góc yaw hiện tại của camera.
var camera_yaw: Callable


func _init(p_touch: TouchController, p_camera_yaw: Callable) -> void:
	touch = p_touch
	camera_yaw = p_camera_yaw


func get_command(_state: MatchState) -> FighterCommand:
	var c := FighterCommand.new()
	keyboard.poll_attack()

	var screen := touch.move_vector()
	if screen == Vector2.ZERO:
		screen = keyboard.move_vector()
	var yaw: float = camera_yaw.call()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	c.move = right * screen.x + fwd * (-screen.y)

	c.block_dir = touch.block_dir()
	if c.block_dir == Dir.NONE:
		c.block_dir = keyboard.block_dir()

	var g := touch.combat
	var key_dir := keyboard.attack_dir()
	if g.consume_release():
		c.attack_dir = g.attack_dir
		c.attack_release = true
		g.clear_after_release()
	elif keyboard.consume_release():
		c.attack_dir = key_dir
		c.attack_release = true
	else:
		c.attack_dir = g.attack_dir if g.attack_dir != Dir.NONE else key_dir
	return c
