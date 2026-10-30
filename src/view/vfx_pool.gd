class_name VfxPool
extends Node3D
## Đỡ: chớp sáng + tia lửa văng ở chỗ hai binh khí chạm nhau. Trúng: máu phụt theo hướng lưỡi
## vũ khí và vệt máu trên đất; chết: vũng máu loang dần dưới xác.
## Tạo sẵn và dùng lại, không tạo mới giữa trận. Không dùng đèn động: trên điện thoại (GL Compatibility)
## mỗi đèn bật lên bắt mọi vật quanh đó vẽ thêm một lượt, và lần đầu bật còn phải dịch lại shader (giật hình).

const FLASH_TIME := 0.18

var _sparks: Array[CPUParticles3D] = []
var _blood: Array[CPUParticles3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_t: Array[float] = []
var _flash_size: Array[float] = []
var _next_spark := 0
var _next_blood := 0
var _next_flash := 0
## Vệt máu trên đất: tấm phẳng dùng lại vòng tròn, mỗi tấm loang tới cỡ đích.
const SPLATS := 16
var _splats: Array[MeshInstance3D] = []
var _splat_size: Array[float] = []
var _splat_t: Array[float] = []
var _splat_time: Array[float] = []
var _next_splat := 0


func setup(max_vfx: int) -> void:
	var n := maxi(2, max_vfx / 2)
	for i in n:
		_sparks.append(_make_sparks())
		_blood.append(_make_blood())
		_flashes.append(_make_flash())
		_flash_t.append(0.0)
		_flash_size.append(1.0)
	var splat_mat := StandardMaterial3D.new()
	splat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splat_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splat_mat.albedo_color = Color(0.26, 0.0, 0.0, 0.9)
	# Vệt máu: đặc ở giữa, mép mờ nhanh.
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 1))
	sg.set_color(1, Color(1, 1, 1, 0))
	sg.add_point(0.7, Color(1, 1, 1, 0.9))
	var stex := GradientTexture2D.new()
	stex.gradient = sg
	stex.fill = GradientTexture2D.FILL_RADIAL
	stex.fill_from = Vector2(0.5, 0.5)
	stex.fill_to = Vector2(1.0, 0.5)
	stex.width = 64
	stex.height = 64
	splat_mat.albedo_texture = stex
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = splat_mat
	for i in SPLATS:
		var m := MeshInstance3D.new()
		m.mesh = plane
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_splats.append(m)
		_splat_size.append(0.0)
		_splat_t.append(1.0)
		_splat_time.append(1.0)


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


## Máu: giọt đỏ sẫm phụt thành tia theo hướng lưỡi vũ khí rồi rơi xuống.
func _make_blood() -> CPUParticles3D:
	var p := _make(Color(0.5, 0.01, 0.01), 26, 4.0)
	p.lifetime = 0.6
	p.spread = 28.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	(p.mesh as QuadMesh).size = Vector2(0.045, 0.045)
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



## Vẽ thử mỗi hiệu ứng một lần lúc vào trận (hạt bé tí, chớp sáng trong suốt, vệt máu bé tí) để shader
## được dịch sẵn, không bị khựng hình ở lần đỡ hay lần chém trúng đầu tiên. at: một điểm camera đang nhìn thấy.
func warm_up(at: Vector3) -> void:
	var played: Array[CPUParticles3D] = [_sparks[0], _blood[0]]
	var sizes := []
	for p in played:
		sizes.append(Vector2(p.scale_amount_min, p.scale_amount_max))
		p.scale_amount_min = 0.001
		p.scale_amount_max = 0.001
	clash(at, 1.0, Color(1, 1, 1, 0))
	blood(at)
	_splat_size[0] = 0.001
	_next_spark = 0
	_next_blood = 0
	_next_flash = 0
	_next_splat = 0
	await get_tree().create_timer(0.6).timeout
	for i in played.size():
		played[i].scale_amount_min = sizes[i].x
		played[i].scale_amount_max = sizes[i].y
	if _splat_size[0] <= 0.001:
		_splats[0].visible = false


## blow: hướng lưỡi vũ khí đi (thế giới). strength: theo sát thương.
func blood(at: Vector3, blow: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	var p := _blood[_next_blood]
	_next_blood = (_next_blood + 1) % _blood.size()
	p.direction = (blow.normalized() + Vector3(0, 0.45, 0)).normalized() if blow.length() > 0.01 else Vector3.UP
	p.amount = clampi(int(26 * strength), 10, 40)
	_play(p, at)
	# Máu bắn xuống đất phía sau người bị chém.
	var ground := at + blow.normalized() * 0.6
	splat(Vector2(ground.x, ground.z), randf_range(0.35, 0.6) * sqrt(strength), 0.25)


## Vệt máu trên đất ở pos (x, z), loang tới cỡ size (mét) trong grow giây.
func splat(pos: Vector2, size: float, grow: float) -> void:
	var i := _next_splat
	_next_splat = (_next_splat + 1) % SPLATS
	var m := _splats[i]
	# Mỗi vệt cao hơn vệt trước một chút để không nhấp nháy khi chồng lên nhau.
	m.position = Vector3(pos.x, 0.012 + 0.0004 * i, pos.y)
	m.rotation.y = randf() * TAU
	m.scale = Vector3(0.01, 1, 0.01)
	m.visible = true
	_splat_size[i] = size
	_splat_t[i] = 0.0
	_splat_time[i] = maxf(0.01, grow)
	(m as Node3D).set_meta("stretch", randf_range(0.7, 1.0))


func _play(p: CPUParticles3D, at: Vector3) -> void:
	p.global_position = at
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	for i in SPLATS:
		if _splat_t[i] >= 1.0:
			continue
		_splat_t[i] = minf(1.0, _splat_t[i] + delta / _splat_time[i])
		var s := _splat_size[i] * (1.0 - pow(1.0 - _splat_t[i], 3.0))
		_splats[i].scale = Vector3(s, 1, s * float(_splats[i].get_meta("stretch", 1.0)))
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
