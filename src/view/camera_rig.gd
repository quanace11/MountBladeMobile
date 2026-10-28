class_name CameraRig
extends Node3D
## Camera sau vai, đi theo hướng mặt của người chơi. Rung nhẹ khi có va chạm.

var config: GameConfig
var target: FighterView
var camera: Camera3D
var yaw: float = 0.0

var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_config: GameConfig, p_target: FighterView) -> void:
	config = p_config
	target = p_target
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.make_current()
	yaw = target.rotation.y
	_place(1.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null:
		return
	var k := 1.0 - exp(-config.camera_follow_speed * delta)
	yaw = lerp_angle(yaw, target.rotation.y, k)
	_place(k)
	_shake = maxf(0.0, _shake - delta * 0.6)


func _place(k: float) -> void:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var base := target.global_position
	var want := base - fwd * config.camera_distance + right * config.camera_shoulder_offset + Vector3.UP * config.camera_height
	global_position = global_position.lerp(want, k)
	var look := base + Vector3.UP * 1.3 + fwd * 3.0 + right * config.camera_shoulder_offset * 0.5
	if _shake > 0.0:
		look += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake
	camera.look_at_from_position(global_position, look, Vector3.UP)
