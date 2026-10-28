class_name VfxPool
extends Node3D
## Tia lửa khi đỡ, máu khi trúng. Tạo sẵn và dùng lại, không tạo mới giữa trận.

var _sparks: Array[CPUParticles3D] = []
var _blood: Array[CPUParticles3D] = []
var _next_spark := 0
var _next_blood := 0


func setup(max_vfx: int) -> void:
	var n := maxi(2, max_vfx / 2)
	for i in n:
		_sparks.append(_make(Color(1.0, 0.85, 0.4), 18, 5.0))
		_blood.append(_make(Color(0.6, 0.02, 0.02), 14, 2.5))


func _make(color: Color, amount: int, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	return p


func sparks(at: Vector3) -> void:
	_play(_sparks[_next_spark], at)
	_next_spark = (_next_spark + 1) % _sparks.size()


func blood(at: Vector3) -> void:
	_play(_blood[_next_blood], at)
	_next_blood = (_next_blood + 1) % _blood.size()


func _play(p: CPUParticles3D, at: Vector3) -> void:
	p.global_position = at
	p.restart()
	p.emitting = true
