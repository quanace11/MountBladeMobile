class_name CameraRig
extends Node3D
## Camera sau lưng, hơi cao, nhìn xa về phía trước (kiểu Bannerlord). Rung nhẹ khi có va chạm.
## Tự ngắm (free_look): người chơi xoay camera bằng turn(), nhân vật quay theo hướng camera.
## Khoá mục tiêu: camera đi theo hướng mặt của nhân vật.

var config: GameConfig
var target: FighterView
## Các tướng khác: camera tự kéo lại gần khi có người đứng chắn sau lưng người chơi.
var obstacles: Array = []
var camera: Camera3D
var yaw: float = 0.0
var free_look := true
## Khoảng lùi sau lưng (mét). Mặc định lấy từ GameConfig, người chơi chỉnh được.
var distance := 4.0

var _shake := 0.0
var _dist := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_config: GameConfig, p_target: FighterView) -> void:
	config = p_config
	target = p_target
	camera = Camera3D.new()
	camera.fov = config.camera_fov
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.make_current()
	yaw = target.rotation.y
	distance = config.camera_distance
	_dist = distance
	_place(1.0)


## Xoay camera (radian, dương là quay phải). Chỉ có tác dụng khi tự ngắm.
func turn(angle: float) -> void:
	if free_look:
		yaw = wrapf(yaw - angle, -PI, PI)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null:
		return
	var k := 1.0 - exp(-config.camera_follow_speed * delta)
	if not free_look:
		yaw = lerp_angle(yaw, target.rotation.y, k)
	_place(k)
	_shake = maxf(0.0, _shake - delta * 0.6)


func _place(k: float) -> void:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var base := target.global_position
	_dist = lerpf(_dist, _clear_distance(base, fwd), k)
	var want := base - fwd * _dist + right * config.camera_shoulder_offset + Vector3.UP * config.camera_height
	global_position = global_position.lerp(want, k)
	var look := base + Vector3.UP * config.camera_look_height + fwd * config.camera_look_ahead + right * config.camera_shoulder_offset * 0.5
	if _shake > 0.0:
		look += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake
	camera.look_at_from_position(global_position, look, Vector3.UP)


## Khoảng lùi camera lớn nhất mà không có tướng nào đứng chắn giữa camera và người chơi.
func _clear_distance(base: Vector3, fwd: Vector3) -> float:
	var best := distance
	for o in obstacles:
		var n := o as Node3D
		if n == null or n == target:
			continue
		var rel := n.global_position - base
		var behind := -rel.dot(fwd)
		if behind <= 0.2 or behind > distance + 0.6:
			continue
		var side := (rel + fwd * behind).length()
		if side < 0.9:
			best = minf(best, maxf(0.9, behind - 0.7))
	return best
