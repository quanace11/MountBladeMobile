class_name FighterView
extends Node3D
## Hình ảnh một tướng: thân người dựng bằng khối, tay chân có khớp (IK hai đoạn),
## giáp lá, mũ trụ, râu, áo choàng. Chỉ đọc FighterState, không bao giờ ghi vào sim.
## Khi có model 3D thật chỉ cần thay lớp này; sim và config giữ nguyên.

const S := FighterState.State
const LAMELLAR := "res://assets/shaders/lamellar.gdshader"
const CAPE := "res://assets/shaders/cape.gdshader"
const TEX := "res://assets/textures/"

# Kích thước cơ thể cho người cao 1,8 m (mét).
const HIP_HEIGHT := 0.95
const CHEST_OFFSET := 0.12
const SHOULDER := Vector3(0.2, 0.36, 0.0)
const HIP_JOINT := Vector3(0.1, -0.02, 0.0)
const UPPER_ARM := 0.29
const FOREARM := 0.27
const THIGH := 0.46
const SHIN := 0.45
const ANKLE_HEIGHT := 0.08

var fighter_id: int = 0
var def: CharacterDef
var poses: PoseSet
var is_player := false

var _body: Node3D
var _pelvis: Node3D
var _chest: Node3D
var _head: Node3D
var _hand: Node3D
var _weapon: Node3D
var _shield: Node3D
var _cape_mat: ShaderMaterial
var _armor_mat: ShaderMaterial

var _upper_arm := {}
var _forearm := {}
var _hand_mesh := {}
var _thigh := {}
var _shin := {}
var _foot := {}
var _left_hand_target := Vector3.ZERO

var _flash := 0.0
var _gait := 0.0
var _gait_amount := 0.0
var _local_vel := Vector2.ZERO
var _death_t := 0.0
var _twist := 0.0
var _lean := 0.0


func setup(p_state: FighterState, p_poses: PoseSet, p_is_player: bool) -> void:
	fighter_id = p_state.id
	def = p_state.def
	poses = p_poses
	is_player = p_is_player
	name = "Fighter%d" % fighter_id
	_build()
	var p: Array = poses.get_pose("idle")
	_hand.position = p[0]
	_hand.rotation_degrees = p[1]
	_left_hand_target = poses.shield_idle_pos


# ---------------------------------------------------------------- dựng hình

func _mi(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	m.scale = scl
	parent.add_child(m)
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(top: float, bottom: float, h: float, sides := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


static func sphere(r: float, h: float, half := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if not half else r
	s.is_hemisphere = half
	s.radial_segments = 14
	s.rings = 7
	return s


func _build() -> void:
	var skin := Mats.color(def.skin_color, 0.6)
	var cloth := Mats.color(def.cloth_color, 0.95)
	var hair := Mats.color(def.hair_color, 0.7)
	var leather := Mats.pbr(TEX + "brown_leather", 2.0)
	var metal := Mats.color(Color(0.62, 0.62, 0.64), 0.32, 0.9)
	var gold := Mats.color(Color(0.78, 0.58, 0.2), 0.4, 0.8)
	var red := Mats.color(Color(0.7, 0.06, 0.05), 0.9)
	_armor_mat = Mats.shader(LAMELLAR, {"tint": def.armor_color, "lace": Color(0.78, 0.58, 0.22)})

	_body = Node3D.new()
	_body.scale = Vector3.ONE * (def.height / 1.8)
	add_child(_body)

	_pelvis = Node3D.new()
	_pelvis.position.y = HIP_HEIGHT
	_body.add_child(_pelvis)
	# Vạt áo dài, đai lưng, giáp đùi trước và sau.
	_mi(cyl(0.17, 0.27, 0.5, 12), cloth, _pelvis, Vector3(0, -0.2, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	_mi(cyl(0.185, 0.185, 0.07, 12), leather, _pelvis, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	_mi(box(Vector3(0.26, 0.34, 0.02)), _armor_mat, _pelvis, Vector3(0, -0.14, -0.17), Vector3(-8, 0, 0))
	_mi(box(Vector3(0.3, 0.34, 0.02)), _armor_mat, _pelvis, Vector3(0, -0.14, 0.16), Vector3(8, 0, 0))
	_mi(box(Vector3(0.02, 0.3, 0.2)), _armor_mat, _pelvis, Vector3(-0.2, -0.13, 0), Vector3(0, 0, -10))
	_mi(box(Vector3(0.02, 0.3, 0.2)), _armor_mat, _pelvis, Vector3(0.2, -0.13, 0), Vector3(0, 0, 10))

	_chest = Node3D.new()
	_chest.position.y = CHEST_OFFSET
	_pelvis.add_child(_chest)
	# Thân, giáp ngực lá, cổ áo, giáp vai.
	_mi(capsule(0.16, 0.5), cloth, _chest, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.15, 1, 0.8))
	_mi(cyl(0.21, 0.18, 0.4, 14), _armor_mat, _chest, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.05, 1, 0.78))
	_mi(cyl(0.09, 0.13, 0.06, 12), leather, _chest, Vector3(0, 0.41, 0))
	_mi(sphere(0.11, 0.11, true), _armor_mat, _chest, Vector3(-0.21, 0.37, 0), Vector3(0, 0, 25), Vector3(1.2, 0.8, 1.1))
	_mi(sphere(0.11, 0.11, true), _armor_mat, _chest, Vector3(0.21, 0.37, 0), Vector3(0, 0, -25), Vector3(1.2, 0.8, 1.1))
	# Gương hộ tâm.
	_mi(cyl(0.06, 0.06, 0.015, 16), gold, _chest, Vector3(0, 0.25, -0.16), Vector3(90, 0, 0))

	if def.cape_color.a > 0.01:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.44, 0.98)
		_cape_mat = Mats.shader(CAPE, {"color": def.cape_color})
		_mi(quad, _cape_mat, _chest, Vector3(0, -0.1, 0.22), Vector3(-8, 0, 0))

	_build_head(skin, hair, metal, gold, red, leather)

	for side in [-1, 1]:
		_upper_arm[side] = _mi(capsule(0.052, UPPER_ARM + 0.08), cloth, _body)
		_forearm[side] = _mi(capsule(0.046, FOREARM + 0.06), leather, _body)
		_hand_mesh[side] = _mi(box(Vector3(0.06, 0.1, 0.04)), skin, _body)
		_thigh[side] = _mi(capsule(0.075, THIGH + 0.1), cloth, _body)
		_shin[side] = _mi(capsule(0.06, SHIN + 0.08), leather, _body)
		_foot[side] = _mi(box(Vector3(0.1, 0.07, 0.25)), leather, _body)

	_hand = Node3D.new()
	_body.add_child(_hand)
	_weapon = _build_weapon(def.weapon, metal, gold, red)
	_hand.add_child(_weapon)

	if def.weapon.has_shield:
		_shield = Node3D.new()
		_body.add_child(_shield)
		var wood := Mats.pbr(TEX + "medieval_wood", 1.0)
		_mi(cyl(0.3, 0.3, 0.04, 20), wood, _shield, Vector3.ZERO, Vector3(90, 0, 0))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.28
		rim.outer_radius = 0.315
		rim.rings = 20
		rim.ring_segments = 4
		_mi(rim, metal, _shield, Vector3.ZERO, Vector3(90, 0, 0))
		_mi(sphere(0.07, 0.07, true), gold, _shield, Vector3(0, 0, -0.02), Vector3(-90, 0, 0))


func _build_head(skin: Material, hair: Material, metal: Material, gold: Material, red: Material, leather: Material) -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, 0.56, 0)
	_chest.add_child(_head)
	_mi(sphere(0.1, 0.24), skin, _head)
	_mi(box(Vector3(0.1, 0.06, 0.09)), skin, _head, Vector3(0, -0.08, -0.035))
	_mi(box(Vector3(0.025, 0.045, 0.035)), skin, _head, Vector3(0, -0.01, -0.105), Vector3(-10, 0, 0))
	var dark := Mats.color(Color(0.04, 0.03, 0.03), 0.5)
	for side in [-1, 1]:
		_mi(sphere(0.012, 0.012), dark, _head, Vector3(0.035 * side, 0.02, -0.092))
		_mi(box(Vector3(0.04, 0.008, 0.012)), hair, _head, Vector3(0.036 * side, 0.042, -0.095), Vector3(0, 0, -12 * side))
		_mi(box(Vector3(0.02, 0.05, 0.03)), skin, _head, Vector3(0.1 * side, 0.0, 0.0))
		# Ria mép rủ xuống hai bên.
		_mi(box(Vector3(0.05, 0.01, 0.012)), hair, _head, Vector3(0.025 * side, -0.045, -0.105), Vector3(0, 0, 25 * side))
	if def.beard_length > 0.0:
		_mi(cyl(0.05, 0.012, def.beard_length, 8), hair, _head, Vector3(0, -0.12 - def.beard_length * 0.5, -0.07), Vector3(-12, 0, 0), Vector3(1, 1, 0.6))
	# Mũ trụ: chóp tròn, vành, mũi nhọn, tua đỏ, mảnh che gáy.
	_mi(sphere(0.125, 0.125, true), metal, _head, Vector3(0, 0.035, 0.005))
	_mi(cyl(0.142, 0.142, 0.015, 18), gold, _head, Vector3(0, 0.035, 0.005))
	_mi(cyl(0.008, 0.03, 0.12, 8), gold, _head, Vector3(0, 0.21, 0.005))
	_mi(cyl(0.05, 0.004, 0.14, 8), red, _head, Vector3(0, 0.22, 0.02), Vector3(180, 0, 0))
	_mi(cyl(0.12, 0.155, 0.13, 14), leather, _head, Vector3(0, -0.04, 0.035), Vector3(-8, 0, 0), Vector3(1, 1, 0.85))


func _build_weapon(w: WeaponDef, metal: Material, gold: Material, red: Material) -> Node3D:
	var root := Node3D.new()
	var shaft := Mats.color(w.shaft_color, 0.7)
	var blade := Mats.color(w.blade_color, 0.28, 0.95)
	var below := w.shaft_length * 0.25
	var above := w.shaft_length - below
	_mi(cyl(0.02, 0.022, w.shaft_length, 8), shaft, root, Vector3(0, (above - below) * 0.5, 0))
	if w.has_shield or w.shaft_length < 0.5:
		# Kiếm: chuôi quấn da, đốc, lưỡi thẳng, mũi nhọn.
		_mi(box(Vector3(0.16, 0.025, 0.04)), gold, root, Vector3(0, above, 0))
		_mi(sphere(0.025, 0.04), gold, root, Vector3(0, -below, 0))
		var length := w.blade_length - 0.12
		_mi(box(Vector3(w.blade_width, length, 0.012)), blade, root, Vector3(0, above + length * 0.5, 0))
		var tip := PrismMesh.new()
		tip.size = Vector3(w.blade_width, 0.12, 0.012)
		_mi(tip, blade, root, Vector3(0, above + length + 0.06, 0))
	elif w.blade_width > 0.1:
		# Đao: lưỡi to bản cong, sống có gai, vòng đồng ở chân lưỡi, tua đỏ.
		var bl := w.blade_length
		_mi(box(Vector3(w.blade_width, bl * 0.75, 0.014)), blade, root, Vector3(-0.035, above + bl * 0.375, 0))
		var tip := PrismMesh.new()
		tip.size = Vector3(w.blade_width, bl * 0.3, 0.014)
		tip.left_to_right = 1.0
		_mi(tip, blade, root, Vector3(-0.035, above + bl * 0.75 + bl * 0.15, 0))
		_mi(box(Vector3(0.05, 0.12, 0.01)), metal, root, Vector3(0.05, above + bl * 0.35, 0), Vector3(0, 0, -30))
		_mi(cyl(0.045, 0.045, 0.06, 10), gold, root, Vector3(0, above, 0))
		_mi(cyl(0.07, 0.015, 0.16, 8), red, root, Vector3(0, above - 0.1, 0), Vector3(180, 0, 0))
		_mi(cyl(0.025, 0.012, 0.08, 8), gold, root, Vector3(0, -below, 0))
	else:
		# Giáo: mũi hình lá, cổ đồng, tua đỏ.
		var head := cyl(0.0, w.blade_width, w.blade_length, 4)
		_mi(head, blade, root, Vector3(0, above + w.blade_length * 0.5, 0), Vector3(0, 45, 0), Vector3(1, 1, 0.35))
		_mi(cyl(0.028, 0.024, 0.08, 8), gold, root, Vector3(0, above - 0.02, 0))
		_mi(cyl(0.08, 0.015, 0.2, 8), red, root, Vector3(0, above - 0.14, 0), Vector3(180, 0, 0))
	return root


# ---------------------------------------------------------------- cập nhật mỗi khung

## alpha: vị trí giữa tick trước và tick hiện tại (0..1).
func sync(cur: FighterState, prev_pos: Vector2, prev_yaw: float, alpha: float, delta: float) -> void:
	var p := prev_pos.lerp(cur.pos, alpha)
	position = Vector3(p.x, 0.0, p.y)
	rotation.y = lerp_angle(prev_yaw, cur.yaw, alpha)

	if cur.state == S.DEAD:
		_death_t = minf(1.0, _death_t + delta / maxf(0.01, poses.death_fall_time))
		_body.rotation.x = lerpf(0.0, deg_to_rad(82.0), ease(_death_t, 0.4))
		_gait_amount = 0.0
	else:
		_update_hand_pose(cur, delta)
		_update_torso(cur, delta)
	_update_gait(cur, delta)
	_update_limbs()

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_armor_mat.set_shader_parameter("tint", def.armor_color.lerp(Color(1, 0.9, 0.85), _flash))


func flash() -> void:
	_flash = 1.0


func _update_hand_pose(cur: FighterState, delta: float) -> void:
	var pose := "idle"
	var speed := poses.blend_speed
	match cur.state:
		S.WINDUP:
			pose = PoseSet.pose_name("windup", cur.attack_dir)
		S.RELEASE:
			pose = PoseSet.pose_name("strike", cur.attack_dir)
			speed *= poses.strike_blend_mult
		S.RECOVERY:
			pose = PoseSet.pose_name("strike", cur.attack_dir) if cur.state_ticks < 3 else "idle"
		S.BLOCK:
			pose = PoseSet.pose_name("block", cur.block_dir)
			speed *= 1.6
		S.STAGGER:
			pose = "stagger"
	var target: Array = poses.get_pose(pose)
	var k := 1.0 - exp(-speed * delta)
	_hand.position = _hand.position.lerp(target[0], k)
	var q_to := Basis.from_euler(target[1] * (PI / 180.0)).get_rotation_quaternion()
	_hand.quaternion = _hand.quaternion.slerp(q_to, k)

	var shield_target := poses.shield_block_pos if cur.state == S.BLOCK else poses.shield_idle_pos
	_left_hand_target = _left_hand_target.lerp(shield_target, 1.0 - exp(-poses.blend_speed * 1.6 * delta))


## Thân trên xoay theo hướng gồng/chém, ngả khi bổ hoặc bị khựng. Đầu giữ nhìn về trước.
func _update_torso(cur: FighterState, delta: float) -> void:
	var tw := deg_to_rad(poses.chest_twist_deg)
	var ln := deg_to_rad(poses.chest_lean_deg)
	var twist := 0.0
	var lean := 0.0
	match cur.state:
		S.WINDUP:
			match cur.attack_dir:
				Dir.LEFT: twist = tw
				Dir.RIGHT: twist = -tw
				Dir.THRUST: twist = -tw * 0.7
				Dir.UP: lean = ln
		S.RELEASE, S.RECOVERY:
			match cur.attack_dir:
				Dir.LEFT: twist = -tw * 0.8
				Dir.RIGHT: twist = tw * 0.8
				Dir.THRUST: twist = tw * 0.5; lean = -ln * 0.6
				Dir.UP: lean = -ln * 1.5
		S.BLOCK:
			lean = -ln * 0.4
		S.STAGGER:
			lean = ln * 1.5
	var k := 1.0 - exp(-poses.blend_speed * delta)
	_twist = lerpf(_twist, twist, k)
	_lean = lerpf(_lean, lean, k)
	_chest.rotation = Vector3(_lean, _twist, 0.0)
	_head.rotation = Vector3(-_lean * 0.5, -_twist * 0.6, 0.0)


## Bước chân: tính theo vận tốc trong hệ toạ độ của nhân vật nên đi ngang, đi lùi đều đúng chân.
func _update_gait(cur: FighterState, delta: float) -> void:
	var right := Vector2(cos(rotation.y), -sin(rotation.y))
	var fwd := Vector2(-sin(rotation.y), -cos(rotation.y))
	_local_vel = _local_vel.lerp(Vector2(cur.velocity.dot(right), -cur.velocity.dot(fwd)), 1.0 - exp(-10.0 * delta))
	var spd := _local_vel.length()
	_gait += spd / maxf(0.1, poses.stride_length) * TAU * delta
	_gait_amount = lerpf(_gait_amount, clampf(spd / maxf(0.1, def.move_speed), 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	_pelvis.position.y = HIP_HEIGHT - absf(sin(_gait)) * 0.035 * _gait_amount - 0.03
	_pelvis.rotation.y = sin(_gait) * 0.12 * _gait_amount
	if _cape_mat:
		_cape_mat.set_shader_parameter("sway", clampf(-_local_vel.y * 0.07, -0.1, 0.4))


func _update_limbs() -> void:
	var pelvis := _pelvis.transform
	var chest := pelvis * _chest.transform
	var move_dir := Vector3(_local_vel.x, 0, _local_vel.y)
	move_dir = move_dir.normalized() if move_dir.length() > 0.05 else Vector3(0, 0, -1)
	var half := poses.stride_length * 0.5 * _gait_amount

	for side in [-1, 1]:
		var phase := _gait + (PI if side == 1 else 0.0)
		# Thế đứng thủ: chân trái trước, chân phải sau.
		var stance := Vector3(0.13 * side, ANKLE_HEIGHT, 0.1 * side)
		var foot := stance + move_dir * sin(phase) * half
		foot.y += maxf(0.0, cos(phase)) * poses.foot_lift * _gait_amount
		var hip := pelvis * Vector3(HIP_JOINT.x * side, HIP_JOINT.y, HIP_JOINT.z)
		var knee := _ik(hip, foot, THIGH, SHIN, Vector3(0.15 * side, 0, -1))
		_segment(_thigh[side], hip, knee)
		_segment(_shin[side], knee, foot)
		(_foot[side] as MeshInstance3D).position = foot + Vector3(0, -0.03, -0.06)
		(_foot[side] as MeshInstance3D).rotation = Vector3(0, _pelvis.rotation.y * 0.5, 0)

	# Tay phải luôn nắm vũ khí.
	var r_sh := chest * Vector3(SHOULDER.x, SHOULDER.y, SHOULDER.z)
	_arm(1, r_sh, _hand.position, Vector3(0.4, -0.6, 0.5))

	# Tay trái: cầm khiên, hoặc nắm cán phía dưới tay phải.
	var l_sh := chest * Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	var l_target := _left_hand_target
	if _shield == null:
		var grip := _hand.transform * Vector3(0, -poses.two_hand_grip, 0)
		var limit := (UPPER_ARM + FOREARM) * 1.05
		l_target = grip if l_sh.distance_to(grip) <= limit else l_sh + (grip - l_sh).normalized() * limit * 0.9
	var l_hand := _arm(-1, l_sh, l_target, Vector3(-0.4, -0.6, 0.5))
	if _shield:
		_shield.position = l_hand + Vector3(0.02, 0.0, -0.06)
		_shield.rotation = Vector3(0.1, _twist * 0.5, 0.0)


## Đặt cánh tay theo IK; trả về vị trí bàn tay thực tế.
func _arm(side: int, shoulder: Vector3, target: Vector3, pole: Vector3) -> Vector3:
	var elbow := _ik(shoulder, target, UPPER_ARM, FOREARM, pole)
	var wrist := elbow + (target - elbow).limit_length(FOREARM)
	_segment(_upper_arm[side], shoulder, elbow)
	_segment(_forearm[side], elbow, wrist)
	var hand: MeshInstance3D = _hand_mesh[side]
	_segment(hand, wrist, wrist + (wrist - elbow).normalized() * 0.09)
	return wrist


## IK hai đoạn: trả về vị trí khớp giữa (khuỷu tay, đầu gối), uốn về phía pole.
static func _ik(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var to := target - root
	var d := clampf(to.length(), 0.01, (a + b) * 0.999)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var bend := (pole - dir * pole.dot(dir))
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.FORWARD
	return root + dir * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))


## Đặt một khối hình nối hai điểm (trục Y của khối chạy từ a tới b).
static func _segment(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var up := dir / length
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	m.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)


## Điểm trên đầu, dùng để đặt thanh máu.
func head_position() -> Vector3:
	return global_position + Vector3(0, def.height + 0.35, 0)
