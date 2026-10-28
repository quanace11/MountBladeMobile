class_name FighterView
extends Node3D
## Hình ảnh một tướng, dựng tạm bằng khối hình (chưa có model).
## Chỉ đọc FighterState để chọn tư thế; không bao giờ ghi vào sim.

const S := FighterState.State

var fighter_id: int = 0
var def: CharacterDef
var poses: PoseSet
var is_player := false

var _body: Node3D
var _hand: Node3D
var _weapon: Node3D
var _arm: MeshInstance3D
var _leg_l: Node3D
var _leg_r: Node3D
var _armor_mat: StandardMaterial3D
var _flash := 0.0
var _walk_phase := 0.0
var _death_t := 0.0
var _last_state: FighterState

static var _mat_cache: Dictionary = {}


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


static func shared_mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), unshaded]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_cache[key] = m
	return _mat_cache[key]


func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


func _build() -> void:
	var s := def.height / 1.8
	_armor_mat = shared_mat(def.armor_color).duplicate()
	var cloth := shared_mat(def.cloth_color)
	var skin := shared_mat(def.skin_color)
	var dark := shared_mat(def.armor_color.darkened(0.45))
	var gold := shared_mat(Color(0.8, 0.62, 0.2))

	_body = Node3D.new()
	_body.scale = Vector3.ONE * s
	add_child(_body)

	# Vòng dưới chân: người chơi màu xanh, địch màu đỏ.
	var ring_col := Color(0.2, 0.8, 1.0, 0.45) if is_player else Color(1.0, 0.2, 0.15, 0.45)
	_mesh(_cyl(0.5, 0.5, 0.02, 16), shared_mat(ring_col, true), self, Vector3(0, 0.01, 0))

	# Chân.
	_leg_l = Node3D.new(); _leg_l.position = Vector3(-0.12, 0.9, 0); _body.add_child(_leg_l)
	_leg_r = Node3D.new(); _leg_r.position = Vector3(0.12, 0.9, 0); _body.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		_mesh(_cyl(0.08, 0.07, 0.8), cloth, leg, Vector3(0, -0.42, 0))
		_mesh(_box(Vector3(0.14, 0.08, 0.26)), dark, leg, Vector3(0, -0.86, -0.05))

	# Thân: giáp, váy giáp, đai, vai.
	_mesh(_cyl(0.24, 0.2, 0.6), _armor_mat, _body, Vector3(0, 1.22, 0))
	_mesh(_cyl(0.22, 0.32, 0.38, 10), dark, _body, Vector3(0, 0.8, 0))
	_mesh(_cyl(0.215, 0.215, 0.07), gold, _body, Vector3(0, 0.98, 0))
	_mesh(_box(Vector3(0.2, 0.08, 0.24)), _armor_mat, _body, Vector3(-0.3, 1.5, 0), Vector3(0, 0, 18))
	_mesh(_box(Vector3(0.2, 0.08, 0.24)), _armor_mat, _body, Vector3(0.3, 1.5, 0), Vector3(0, 0, -18))
	# Tay trái để yên cạnh người.
	_mesh(_cyl(0.06, 0.05, 0.55), cloth, _body, Vector3(-0.33, 1.2, -0.05), Vector3(10, 0, 8))

	# Đầu, mũ trụ, chóp mũ, tua đỏ.
	var head := SphereMesh.new(); head.radius = 0.13; head.height = 0.28; head.radial_segments = 10; head.rings = 6
	_mesh(head, skin, _body, Vector3(0, 1.66, 0))
	_mesh(_cyl(0.12, 0.17, 0.14, 10), dark, _body, Vector3(0, 1.78, 0))
	_mesh(_cyl(0.01, 0.1, 0.16, 8), gold, _body, Vector3(0, 1.92, 0))
	_mesh(_cyl(0.035, 0.0, 0.18, 6), shared_mat(Color(0.75, 0.08, 0.06)), _body, Vector3(0, 2.05, 0.02))
	# Râu đen kiểu tướng cổ.
	_mesh(_box(Vector3(0.12, 0.16, 0.05)), shared_mat(Color(0.06, 0.05, 0.05)), _body, Vector3(0, 1.55, -0.11))

	# Tay phải cầm vũ khí: _hand là bàn tay, cánh tay vẽ lại mỗi khung từ vai tới tay.
	_arm = _mesh(_cyl(0.06, 0.05, 1.0), cloth, _body)
	_hand = Node3D.new()
	_body.add_child(_hand)
	_weapon = _build_weapon(def.weapon)
	_hand.add_child(_weapon)

	if def.weapon.has_shield:
		var shield := _mesh(_cyl(0.32, 0.32, 0.05, 12), _armor_mat, _body, Vector3(-0.38, 1.2, -0.3), Vector3(90, 0, 0))
		_mesh(_cyl(0.07, 0.07, 0.06, 8), gold, shield, Vector3(0, -0.02, 0))


func _build_weapon(w: WeaponDef) -> Node3D:
	var root := Node3D.new()
	var shaft := shared_mat(w.shaft_color)
	var blade := shared_mat(w.blade_color)
	var below := w.shaft_length * 0.25
	var above := w.shaft_length - below
	_mesh(_cyl(0.025, 0.025, w.shaft_length, 6), shaft, root, Vector3(0, (above - below) * 0.5, 0))
	if w.has_shield or w.shaft_length < 0.5:
		# Kiếm: chuôi ngắn, đốc kiếm, lưỡi thẳng.
		_mesh(_box(Vector3(0.18, 0.03, 0.05)), shared_mat(Color(0.8, 0.62, 0.2)), root, Vector3(0, above, 0))
		_mesh(_box(Vector3(w.blade_width, w.blade_length, 0.015)), blade, root, Vector3(0, above + w.blade_length * 0.5, 0))
	elif w.blade_width > 0.1:
		# Đao: lưỡi to bản, hơi cong ra trước.
		_mesh(_box(Vector3(w.blade_width, w.blade_length, 0.02)), blade, root, Vector3(-0.03, above + w.blade_length * 0.5, 0), Vector3(0, 0, 6))
		_mesh(_cyl(0.05, 0.03, 0.06, 8), shared_mat(Color(0.75, 0.08, 0.06)), root, Vector3(0, above, 0))
	else:
		# Giáo: mũi nhọn, tua đỏ dưới mũi.
		_mesh(_cyl(0.0, w.blade_width, w.blade_length, 6), blade, root, Vector3(0, above + w.blade_length * 0.5, 0))
		_mesh(_cyl(0.06, 0.02, 0.12, 6), shared_mat(Color(0.75, 0.08, 0.06)), root, Vector3(0, above - 0.04, 0))
	return root


## alpha: vị trí giữa tick trước và tick hiện tại (0..1).
func sync(cur: FighterState, prev_pos: Vector2, prev_yaw: float, alpha: float, delta: float) -> void:
	_last_state = cur
	var p := prev_pos.lerp(cur.pos, alpha)
	position = Vector3(p.x, 0.0, p.y)
	rotation.y = lerp_angle(prev_yaw, cur.yaw, alpha)

	if cur.state == S.DEAD:
		_death_t = minf(1.0, _death_t + delta / maxf(0.01, poses.death_fall_time))
		_body.rotation.x = lerpf(0.0, deg_to_rad(80.0), ease(_death_t, 0.5))
		return

	_update_pose(cur, delta)
	_update_legs(cur, delta)
	_update_arm()

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
	_armor_mat.albedo_color = def.armor_color.lerp(Color(1, 1, 1), _flash)


func flash() -> void:
	_flash = 1.0


func _update_pose(cur: FighterState, delta: float) -> void:
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
	var q_from := _hand.quaternion
	var q_to := Basis.from_euler(target[1] * (PI / 180.0)).get_rotation_quaternion()
	_hand.quaternion = q_from.slerp(q_to, k)


func _update_legs(cur: FighterState, delta: float) -> void:
	var spd := cur.velocity.length()
	_walk_phase += spd * poses.steps_per_meter * TAU * delta
	var amp := deg_to_rad(poses.leg_swing_deg) * clampf(spd / maxf(0.1, def.move_speed), 0.0, 1.0)
	_leg_l.rotation.x = sin(_walk_phase) * amp
	_leg_r.rotation.x = -sin(_walk_phase) * amp


## Cánh tay phải: hình trụ nối vai tới bàn tay.
func _update_arm() -> void:
	var shoulder := Vector3(0.3, 1.45, 0.0)
	var hand := _hand.position
	var mid := (shoulder + hand) * 0.5
	var dir := hand - shoulder
	var length := dir.length()
	if length < 0.01:
		return
	var up := dir / length
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(up)
	_arm.transform = Transform3D(Basis(side, up * length, fwd), mid)


## Điểm trên đầu, dùng để đặt thanh máu.
func head_position() -> Vector3:
	return global_position + Vector3(0, def.height + 0.45, 0)
