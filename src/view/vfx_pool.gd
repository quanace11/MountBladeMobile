class_name VfxPool
extends Node3D
## Đỡ: chớp sáng + tia lửa văng ở chỗ hai binh khí chạm nhau. Trúng: máu.
## Tạo sẵn và dùng lại, không tạo mới giữa trận.

const FLASH_TIME := 0.18

var _sparks: Array[CPUParticles3D] = []
var _blood: Array[CPUParticles3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_t: Array[float] = []
var _flash_size: Array[float] = []
var _light: OmniLight3D
var _light_t := 0.0
var _light_energy := 0.0
var _next_spark := 0
var _next_blood := 0
var _next_flash := 0


func setup(max_vfx: int) -> void:
	var n := maxi(2, max_vfx / 2)
	for i in n:
		_sparks.append(_make_sparks())
		_blood.append(_make(Color(0.6, 0.02, 0.02), 14, 2.5))
		_flashes.append(_make_flash())
		_flash_t.append(0.0)
		_flash_size.append(1.0)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.55)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)


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


## Tia lửa: hạt sáng cộng màu, văng mọi hướng, nguội dần từ trắng sang cam.
func _make_sparks() -> CPUParticles3D:
	var p := _make(Color.WHITE, 36, 7.0)
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.02, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.7, 0.2, 1.0))
	p.color_ramp = ramp
	var mesh := p.mesh as QuadMesh
	mesh.size = Vector2(0.035, 0.035)
	var mat := mesh.material as StandardMaterial3D
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return p


## Chớp sáng: một tấm tròn cộng màu luôn quay về camera, to ra rồi tắt rất nhanh.
func _make_flash() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = _radial_texture()
	quad.material = mat
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


var _radial: GradientTexture2D


func _radial_texture() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.18, Color(1, 1, 1, 0.95))
		g.add_point(0.45, Color(1, 1, 1, 0.25))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 64
		_radial.height = 64
	return _radial


## Hai binh khí va nhau. strength: 1 = đỡ thường, lớn hơn = đỡ hoàn hảo / phá thế.
func clash(at: Vector3, strength: float = 1.0, tint: Color = Color(1.0, 0.85, 0.55)) -> void:
	var p := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	p.amount = int(36 * strength)
	p.initial_velocity_max = 7.0 * sqrt(strength)
	_play(p, at)

	var i := _next_flash
	_next_flash = (_next_flash + 1) % _flashes.size()
	var f := _flashes[i]
	f.global_position = at
	((f.mesh as QuadMesh).material as StandardMaterial3D).albedo_color = tint
	f.visible = true
	_flash_t[i] = FLASH_TIME * (1.0 + 0.5 * (strength - 1.0))
	_flash_size[i] = 1.3 * strength

	_light.global_position = at
	_light.light_color = tint
	_light_energy = 2.5 * strength
	_light_t = 0.12
	_light.visible = true


func blood(at: Vector3) -> void:
	_play(_blood[_next_blood], at)
	_next_blood = (_next_blood + 1) % _blood.size()


func _play(p: CPUParticles3D, at: Vector3) -> void:
	p.global_position = at
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	for i in _flashes.size():
		if _flash_t[i] <= 0.0:
			continue
		_flash_t[i] -= delta
		var f := _flashes[i]
		if _flash_t[i] <= 0.0:
			f.visible = false
			continue
		var k := _flash_t[i] / FLASH_TIME
		f.scale = Vector3.ONE * _flash_size[i] * (1.4 - 0.6 * k)
		f.transparency = 1.0 - clampf(k, 0.0, 1.0)
	if _light_t > 0.0:
		_light_t -= delta
		_light.light_energy = _light_energy * maxf(0.0, _light_t / 0.12)
		if _light_t <= 0.0:
			_light.visible = false
