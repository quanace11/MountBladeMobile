class_name FighterView
extends Node3D
## Hình ảnh một tướng: thân người dựng bằng khối, tay chân có khớp (IK hai đoạn),
## giáp lá, mũ trụ, râu, áo choàng. Chỉ đọc FighterState, không bao giờ ghi vào sim.
## Có model 3D (CharacterModel) thì ẩn thân dựng bằng khối, uốn xương model theo cùng các khớp
## (SkinnedRig); vũ khí, khiên vẫn dựng bằng khối. Sim và config giữ nguyên.

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
var _jolt := 0.0
## Hướng cán (từ tay về phía lưỡi) và hướng lưỡi sắc, theo thân. Nội suy theo hướng chứ không theo góc
## Euler để vũ khí đi đúng đường vung.
var _shaft := Vector3.UP
var _edge := Vector3.LEFT
## Đang vung đòn: tiến độ 0..1 và tư thế lúc bắt đầu vung.
var _swing_t := 1.0
var _swing_from_pos := Vector3.ZERO
var _swing_from_shaft := Vector3.UP
var _swing_from_edge := Vector3.LEFT
var _swing_state := -1
## Tay trái nắm cán ở đâu (mét dọc cán tính từ tay phải, âm = phía đốc).
var _grip_t := -0.35
var _body_scale := Vector3.ONE
var _rig: SkinnedRig
var _model_mesh: MeshInstance3D
## Vật liệu của model; chớp sáng khi bị trúng bằng emission (không thêm lượt vẽ, không đổi shader).
var _model_mat: StandardMaterial3D
## Cổ chân của model cao hơn cổ chân thân khối bao nhiêu (mét).
var _rig_ankle_offset := 0.0
var _gait := 0.0
var _gait_amount := 0.0
## 0 = đi bộ, 1 = chạy hẳn.
var _run := 0.0
var _local_vel := Vector2.ZERO
var _death_t := 0.0
## Bị chém trúng (như Bannerlord): người giật theo hướng lưỡi vũ khí đi rồi hồi lại.
## (ngả, xoay, nghiêng) của thân trên (radian) và độ xô của cả người (mét, toạ độ thân).
var _react := Vector3.ZERO
var _react_push := Vector3.ZERO
## Hướng ngã khi chết (toạ độ thân: x phải, z sau).
var _fall_dir := Vector3(0, 0, 1)
## Vũ khí rơi khỏi tay khi chết.
var _dropped: Node3D
var _drop_vel := Vector3.ZERO
var _drop_spin := Vector3.ZERO
var _drop_landed := false
var _twist := 0.0
var _lean := 0.0


func setup(p_state: FighterState, p_poses: PoseSet, p_is_player: bool, model: CharacterModel = null) -> void:
	fighter_id = p_state.id
	def = p_state.def
	poses = p_poses
	is_player = p_is_player
	name = "Fighter%d" % fighter_id
	_build()
	if model:
		_attach_model(model)
	var p: Array = poses.get_pose("idle")
	_hand.position = p[0]
	_hand.rotation_degrees = p[1]
	_shaft = _hand.basis.y
	_edge = _hand.basis.x
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


## Gộp các khối hình con đứng yên với nhau thành một lưới, mỗi vật liệu một mặt. Mỗi khối là một
## lệnh vẽ (và thêm một lệnh nữa cho bóng), nên gộp lại đỡ cho điện thoại rất nhiều.
## recursive: gộp cả khối trong các nhóm con (nhóm con đứng yên). skip: vật liệu không gộp
## (ví dụ áo choàng, shader của nó dựa vào toạ độ riêng của tấm vải).
static func merge_meshes(group: Node3D, recursive := false, skip: Material = null) -> MeshInstance3D:
	var parts := {}
	_collect_meshes(group, Transform3D.IDENTITY, recursive, skip, parts)
	if parts.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for mat in parts:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var p: Array = parts[mat]
		arrays[Mesh.ARRAY_VERTEX] = p[0]
		arrays[Mesh.ARRAY_NORMAL] = p[1]
		arrays[Mesh.ARRAY_TANGENT] = p[2]
		arrays[Mesh.ARRAY_TEX_UV] = p[3]
		arrays[Mesh.ARRAY_INDEX] = p[4]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	group.add_child(mi)
	return mi


## Gom đỉnh của các khối vào parts (vật liệu -> [đỉnh, pháp tuyến, tiếp tuyến, uv, chỉ số]) rồi xoá khối.
static func _collect_meshes(n: Node3D, xf: Transform3D, recursive: bool, skip: Material, parts: Dictionary) -> void:
	for c in n.get_children():
		var m := c as MeshInstance3D
		if m and m.mesh and m.material_override != skip and m.mesh.get_surface_count() == 1:
			var t := xf * m.transform
			var nb := t.basis.inverse().transposed()
			var a := m.mesh.surface_get_arrays(0)
			var mat := m.material_override
			if not parts.has(mat):
				parts[mat] = [PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedVector2Array(), PackedInt32Array()]
			var p: Array = parts[mat]
			var verts: PackedVector3Array = p[0]
			var norms: PackedVector3Array = p[1]
			var tans: PackedFloat32Array = p[2]
			var uvs: PackedVector2Array = p[3]
			var idx: PackedInt32Array = p[4]
			var base := verts.size()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var tg = a[Mesh.ARRAY_TANGENT]
			var uv = a[Mesh.ARRAY_TEX_UV]
			for i in v.size():
				verts.append(t * v[i])
				norms.append((nb * nr[i]).normalized())
				if tg != null:
					var tt := (t.basis * Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])).normalized()
					tans.append_array([tt.x, tt.y, tt.z, tg[i * 4 + 3]])
				else:
					tans.append_array([1.0, 0.0, 0.0, 1.0])
				uvs.append(uv[i] if uv != null else Vector2.ZERO)
			var ix = a[Mesh.ARRAY_INDEX]
			if ix != null:
				for i in ix:
					idx.append(base + i)
			else:
				for i in v.size():
					idx.append(base + i)
			parts[mat] = [verts, norms, tans, uvs, idx]
			n.remove_child(m)
			m.free()
		elif recursive and c is Node3D and not (c is MeshInstance3D):
			_collect_meshes(c, xf * (c as Node3D).transform, true, skip, parts)
			if c.get_child_count() == 0:
				n.remove_child(c)
				c.free()


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
	_body_scale = Vector3.ONE * (def.height / 1.8)
	_body.scale = _body_scale
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
		# Hẹp hơn hai vai để nhìn từ sau vẫn thấy hai cánh tay.
		quad.size = Vector2(0.3, 0.95)
		_cape_mat = Mats.shader(CAPE, {"color": def.cape_color})
		_mi(quad, _cape_mat, _chest, Vector3(0, -0.1, 0.22), Vector3(-8, 0, 0))

	_build_head(skin, hair, metal, gold, red, leather)
	merge_meshes(_pelvis)
	merge_meshes(_chest, false, _cape_mat)
	merge_meshes(_head)

	for side in [-1, 1]:
		_upper_arm[side] = _mi(capsule(0.06, UPPER_ARM + 0.08), cloth, _body)
		_forearm[side] = _mi(capsule(0.054, FOREARM + 0.06), leather, _body)
		_hand_mesh[side] = _mi(box(Vector3(0.07, 0.1, 0.05)), skin, _body)
		_thigh[side] = _mi(capsule(0.075, THIGH + 0.1), cloth, _body)
		_shin[side] = _mi(capsule(0.06, SHIN + 0.08), leather, _body)
		_foot[side] = _mi(box(Vector3(0.1, 0.07, 0.25)), leather, _body)

	_hand = Node3D.new()
	_body.add_child(_hand)
	_weapon = _build_weapon(def.weapon, metal, gold, red)
	merge_meshes(_weapon)
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
		merge_meshes(_shield)


## Thay thân dựng bằng khối bằng model có khung xương. Không dùng được thì giữ thân khối.
func _attach_model(model: CharacterModel) -> void:
	if model.scene == null:
		return
	var root := model.scene.instantiate() as Node3D
	var rig := SkinnedRig.new()
	if root == null or not rig.setup(root, model.height):
		push_warning("Model không có khung xương chuẩn UE5, giữ thân dựng bằng khối")
		if root:
			root.free()
		return
	_rig = rig
	_hide_block_body(_body)
	root.transform = rig.to_body
	_body.add_child(root)
	_rig_ankle_offset = (rig.to_body * rig.skel.get_bone_global_rest(rig._leg[1][2]).origin).y - ANKLE_HEIGHT
	_cape_mat = null

	_model_mesh = _find_mesh(root)
	if _model_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = model.tint
		mat.albedo_texture = model.albedo
		mat.roughness = 0.55
		mat.metallic = 0.5 if model.albedo == null else 0.0
		if model.normal:
			mat.normal_enabled = true
			mat.normal_texture = model.normal
		# Chớp sáng khi bị chém trúng: bật emission sẵn (độ sáng 0) để lúc chớp không phải dịch shader mới.
		# Lớp phủ trong suốt thì phải vẽ lại cả model mỗi khung dù không chớp.
		mat.emission_enabled = true
		mat.emission = Color(1, 0.9, 0.85)
		mat.emission_energy_multiplier = 0.0
		for i in _model_mesh.mesh.get_surface_count():
			_model_mesh.set_surface_override_material(i, mat)
		_model_mat = mat


## Ẩn các khối hình của thân, chừa vũ khí và khiên.
func _hide_block_body(n: Node) -> void:
	for c in n.get_children():
		if c == _hand or c == _shield:
			continue
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
		_hide_block_body(c)


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


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
	# Vũ khí cán dài cầm gần giữa cán để tay trái nắm được cả phía đốc.
	var below := w.shaft_length * (0.25 if w.has_shield or w.shaft_length < 0.5 else 0.42)
	var above := w.shaft_length - below
	_mi(cyl(0.02, 0.022, w.shaft_length, 8), shaft, root, Vector3(0, (above - below) * 0.5, 0))
	if w.style == &"thanh_long":
		_build_thanh_long(w, root, above, below, blade, gold)
	elif w.style == &"xa_mau":
		_build_xa_mau(w, root, above, below, blade, gold, red)
	elif w.has_shield or w.shaft_length < 0.5:
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


## Thanh Long Yển Nguyệt Đao: lưỡi trăng khuyết to bản, sống có ngạnh, đầu rồng xanh ngậm chân lưỡi,
## đai đồng trên cán, mũi nhọn ở đốc. Lưỡi sắc quay về -x.
func _build_thanh_long(w: WeaponDef, root: Node3D, above: float, below: float, blade: Material, gold: Material) -> void:
	var k := w.blade_length / 0.82
	var outline := PackedVector2Array()
	for p in [Vector2(-0.05, 0), Vector2(-0.11, 0.14), Vector2(-0.145, 0.32), Vector2(-0.14, 0.5),
			Vector2(-0.1, 0.65), Vector2(-0.03, 0.76), Vector2(0.06, 0.82), Vector2(0.045, 0.7),
			Vector2(0.035, 0.56), Vector2(0.1, 0.5), Vector2(0.035, 0.44), Vector2(0.03, 0.24), Vector2(0.035, 0.0)]:
		outline.append(Vector2(p.x * k * 1.25, p.y * k))
	_mi(flat_mesh(outline, 0.014), blade, root, Vector3(0, above + 0.04, 0))
	var green := Mats.color(Color(0.1, 0.42, 0.22), 0.45, 0.6)
	# Đầu rồng: đầu dài hướng lên ngậm lưỡi, hai sừng, bờm gai phía sống.
	_mi(capsule(0.042, 0.17), green, root, Vector3(0.005, above + 0.02, 0), Vector3(0, 0, 8), Vector3(1, 1, 0.8))
	_mi(cyl(0.012, 0.03, 0.1, 6), green, root, Vector3(-0.02, above + 0.11, 0), Vector3(0, 0, 25))
	for z in [-1.0, 1.0]:
		_mi(cyl(0.0, 0.012, 0.09, 5), gold, root, Vector3(0.03, above + 0.08, 0.02 * z), Vector3(20 * z, 0, -40))
		_mi(sphere(0.01, 0.02), gold, root, Vector3(-0.015, above + 0.06, 0.035 * z))
	for i in 4:
		var mane := PrismMesh.new()
		mane.size = Vector3(0.05, 0.05, 0.01)
		_mi(mane, green, root, Vector3(0.045, above - 0.05 + i * 0.045, 0), Vector3(0, 0, -70))
	_mi(cyl(0.032, 0.032, 0.05, 10), gold, root, Vector3(0, above - 0.1, 0))
	for t in [0.3, 0.6]:
		_mi(cyl(0.026, 0.026, 0.03, 8), gold, root, Vector3(0, above - (above + below) * t, 0))
	_mi(cyl(0.0, 0.026, 0.14, 6), gold, root, Vector3(0, -below - 0.07, 0), Vector3(180, 0, 0))


## Trượng Bát Xà Mâu: mũi dài uốn lượn như thân rắn, cổ đồng, tua đỏ, cán đen.
func _build_xa_mau(w: WeaponDef, root: Node3D, above: float, below: float, blade: Material, gold: Material, red: Material) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var t := float(i) / n
		var y := t * w.blade_length
		var cx := 0.045 * sin(t * TAU * 1.5) * (1.0 - t * 0.6)
		var half := w.blade_width * 0.5 * (1.0 - t) * (0.75 + 0.25 * cos(t * TAU * 1.5))
		left.append(Vector2(cx - half, y))
		right.append(Vector2(cx + half, y))
	right.reverse()
	left.append_array(right)
	_mi(flat_mesh(left, 0.016), blade, root, Vector3(0, above + 0.03, 0))
	_mi(cyl(0.024, 0.03, 0.09, 8), gold, root, Vector3(0, above - 0.01, 0))
	_mi(sphere(0.034, 0.05), gold, root, Vector3(0, above - 0.07, 0))
	_mi(cyl(0.09, 0.015, 0.22, 8), red, root, Vector3(0, above - 0.18, 0), Vector3(180, 0, 0))
	_mi(cyl(0.024, 0.02, 0.06, 8), gold, root, Vector3(0, -below, 0))


## Tấm phẳng dày thickness theo đường viền (mặt phẳng xy, đều về hai phía z).
static func flat_mesh(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var tris := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := thickness * 0.5
	for side in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for i in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for o in order:
				var p := outline[tris[i + o]]
				st.add_vertex(Vector3(p.x, p.y, hz * side))
	# Viền: hướng pháp tuyến ra ngoài tuỳ chiều đường viền.
	var ccw := Geometry2D.is_polygon_clockwise(outline) == false
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var e := (b - a).normalized()
		var nrm := Vector3(e.y, -e.x, 0) if ccw else Vector3(-e.y, e.x, 0)
		st.set_normal(nrm)
		var q := [Vector3(a.x, a.y, hz), Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3(b.x, b.y, hz)]
		for j in ([0, 1, 2, 0, 2, 3] if ccw else [0, 2, 1, 0, 3, 2]):
			st.add_vertex(q[j])
	st.index()
	return st.commit()


# ---------------------------------------------------------------- cập nhật mỗi khung

## alpha: vị trí giữa tick trước và tick hiện tại (0..1).
func sync(cur: FighterState, prev_pos: Vector2, prev_yaw: float, alpha: float, delta: float) -> void:
	var p := prev_pos.lerp(cur.pos, alpha)
	position = Vector3(p.x, 0.0, p.y)
	rotation.y = lerp_angle(prev_yaw, cur.yaw, alpha)

	var rk := 1.0 - exp(-7.0 * delta)
	_react = _react.lerp(Vector3.ZERO, rk)
	_react_push = _react_push.lerp(Vector3.ZERO, rk)
	if cur.state == S.DEAD:
		_gait_amount = 0.0
		_update_gait(cur, delta)
		_update_death(delta)
	else:
		_update_roll(cur, alpha)
		_update_hand_pose(cur, delta)
		_update_torso(cur, delta)
		_update_gait(cur, delta)
	_update_limbs()

	_jolt = maxf(0.0, _jolt - delta * 6.0)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_armor_mat.set_shader_parameter("tint", def.armor_color.lerp(Color(1, 0.9, 0.85), _flash))
		if _model_mat:
			_model_mat.emission_energy_multiplier = _flash * 1.5


## Bị chém trúng: giáp chớp sáng.
func flash() -> void:
	_flash = 1.0


## Bị chém trúng: blow là hướng lưỡi vũ khí đi (toạ độ thế giới). Đòn từ trước thì ngửa ra sau,
## đòn ngang thì nghiêng, xoay người theo hướng chém, xô lùi nửa bước.
func hit_react(blow: Vector3, strength: float = 1.0) -> void:
	var l := global_transform.basis.inverse() * blow
	l.y = 0.0
	if l.length() < 0.001:
		return
	l = l.normalized()
	_react = Vector3(l.z * 0.5, -l.x * 0.35, -l.x * 0.4) * strength
	_react_push = l * 0.14 * strength


## Chết: khuỵu gối rồi đổ theo hướng đòn chém, vũ khí văng khỏi tay.
func die(blow: Vector3) -> void:
	var l := global_transform.basis.inverse() * blow
	l.y = 0.0
	_fall_dir = l.normalized() if l.length() > 0.01 else Vector3(0, 0, 1)
	_death_t = 0.0
	_drop_weapon()


func _drop_weapon() -> void:
	if _weapon == null or _dropped != null or get_parent() == null:
		return
	var g := _weapon.global_transform
	_weapon.get_parent().remove_child(_weapon)
	get_parent().add_child(_weapon)
	_weapon.global_transform = g
	_dropped = _weapon
	var side := Vector3(randf_range(-0.4, 0.4), 0, 0) + _fall_dir * 0.6
	_drop_vel = global_transform.basis * Vector3(side.x, 1.6, side.z)
	_drop_spin = Vector3(randf_range(2.0, 4.0), randf_range(-2.0, 2.0), randf_range(-3.0, 3.0))


## Ngã: 0..0,25 khuỵu gối, 0,25..1 đổ người (nhanh dần như rơi), sau đó nảy nhẹ khi chạm đất.
func _update_death(delta: float) -> void:
	_death_t += delta / maxf(0.01, poses.death_fall_time * 1.5)
	var buckle := smoothstep(0.0, 0.25, _death_t)
	var f := clampf((_death_t - 0.2) / 0.8, 0.0, 1.0)
	var angle := deg_to_rad(86.0) * f * f
	if _death_t > 1.0:
		angle -= deg_to_rad(6.0) * sin(PI * minf(1.0, (_death_t - 1.0) / 0.25)) * maxf(0.0, 1.0 - (_death_t - 1.0))
	var axis := Vector3.UP.cross(_fall_dir).normalized()
	_body.transform = Transform3D(Basis(axis, angle) * Basis.from_scale(_body_scale), Vector3(0, -0.12 * buckle * (1.0 - f), 0))
	_pelvis.position.y -= 0.32 * buckle * (1.0 - f * 0.6)
	_chest.rotation = Vector3(0.4 * buckle, 0.0, 0.0)
	_head.rotation = Vector3(0.5 * buckle, 0.0, 0.0)
	_hand.position = _hand.position.lerp(Vector3(0.28, 0.7, -0.15), 1.0 - exp(-6.0 * delta))
	_left_hand_target = _left_hand_target.lerp(Vector3(-0.28, 0.7, -0.1), 1.0 - exp(-6.0 * delta))
	if _dropped and not _drop_landed:
		_drop_vel.y -= 9.8 * delta
		_dropped.global_position += _drop_vel * delta
		_dropped.rotate_object_local(Vector3.RIGHT, _drop_spin.x * delta)
		_dropped.rotate_object_local(Vector3.FORWARD, _drop_spin.z * delta)
		if _dropped.global_position.y <= 0.06 and _drop_vel.y < 0.0:
			_drop_landed = true
			var p := _dropped.global_position
			# Nằm phẳng trên đất, giữ hướng xoay ngang hiện tại.
			_dropped.global_transform = Transform3D(Basis(Vector3.UP, _dropped.global_rotation.y) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(p.x, 0.06, p.z))


## Đỡ được đòn: tay cầm vũ khí bị đẩy lùi một chút rồi giữ lại thế đỡ, không chớp như bị trúng.
func jolt(amount: float) -> void:
	_jolt = maxf(_jolt, amount)


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
			speed *= 2.8
		S.STAGGER:
			if cur.recoil:
				# Đòn bị đỡ: vũ khí dội ngược về phía vừa vung tới, người không ngả như bị trúng.
				pose = PoseSet.pose_name("windup", cur.attack_dir)
				speed *= poses.strike_blend_mult
			else:
				pose = "stagger"
	var target: Array = poses.get_pose(pose)
	if cur.state == S.BLOCK and _jolt > 0.0:
		target = [target[0] + Vector3(0.0, -0.05, 0.14) * _jolt, target[1]]
	var tb := Basis.from_euler(target[1] * (PI / 180.0))
	if cur.state == S.RELEASE:
		_update_swing(cur, target[0], tb, delta)
	else:
		var k := 1.0 - exp(-speed * delta)
		_hand.position = _hand.position.lerp(target[0], k)
		_shaft = _turn_toward(_shaft, tb.y, k)
		_edge = _turn_toward(_edge, tb.x, k)
	_swing_state = cur.state
	_apply_hand_basis()

	var shield_target := poses.shield_block_pos if cur.state == S.BLOCK else poses.shield_idle_pos
	_left_hand_target = _left_hand_target.lerp(shield_target, 1.0 - exp(-poses.blend_speed * 1.6 * delta))


## Đường vung của từng hướng chém: lưỡi đi qua hướng này ở giữa đường (theo thân).
## Chém ngang thì quét vòng phía trước qua bên sườn, bổ thì vung qua đỉnh đầu, đâm thì đi thẳng.
static func _swing_via(dir: int) -> Vector3:
	match dir:
		Dir.UP: return Vector3(-0.05, 1.0, -0.15).normalized()
		Dir.RIGHT: return Vector3(1.0, 0.3, -0.25).normalized()
		Dir.LEFT: return Vector3(-1.0, 0.3, -0.25).normalized()
	return Vector3.ZERO


## Vung đòn: đi theo đường cố định từ tư thế gồng tới tư thế chém, nhanh dần, hết đường đúng lúc chạm.
func _update_swing(cur: FighterState, strike_pos: Vector3, strike: Basis, delta: float) -> void:
	if _swing_state != S.RELEASE:
		_swing_t = 0.0
		_swing_from_pos = _hand.position
		_swing_from_shaft = _shaft
		_swing_from_edge = _edge
	_swing_t = minf(1.0, _swing_t + delta / maxf(0.05, def.weapon.release_time))
	var e := _swing_t * _swing_t * (3.0 - 2.0 * _swing_t)
	var via := _swing_via(cur.attack_dir)
	if via == Vector3.ZERO:
		_shaft = _swing_from_shaft.slerp(strike.y, e)
	elif e < 0.5:
		_shaft = _swing_from_shaft.slerp(via, e * 2.0)
	else:
		_shaft = via.slerp(strike.y, e * 2.0 - 1.0)
	_edge = _swing_from_edge.slerp(strike.x, e)
	_hand.position = _swing_from_pos.lerp(strike_pos, e)


## Xoay hướng a về b một phần k; nếu đường ngắn nhất đi qua sau lưng thì vòng ra phía trước.
static func _turn_toward(a: Vector3, b: Vector3, k: float) -> Vector3:
	var mid := a + b
	if mid.length() < 0.2 or (mid.normalized().z > 0.35 and a.dot(b) < 0.0):
		b = (mid * 0.5 + Vector3(0, 0.3, -1.0)).normalized()
	return a.slerp(b, k).normalized()


func _apply_hand_basis() -> void:
	var y := _shaft.normalized()
	var x := (_edge - y * _edge.dot(y))
	x = x.normalized() if x.length() > 0.01 else y.cross(Vector3.BACK).normalized()
	_hand.basis = Basis(x, y, x.cross(y))


## Lăn né: cả người lộn một vòng quanh hông theo hướng lăn.
func _update_roll(cur: FighterState, alpha: float) -> void:
	if cur.state != S.DODGE:
		_body.transform = Transform3D(Basis.from_scale(_body_scale), _react_push)
		return
	var t := clampf((cur.state_ticks + alpha) / maxf(1.0, cur.state_duration), 0.0, 1.0)
	var d := Basis(Vector3.UP, -rotation.y) * Vector3(cur.dodge_dir.x, 0.0, cur.dodge_dir.y)
	var axis := Vector3.UP.cross(d)
	if axis.length() < 0.01:
		return
	var rot := Basis(axis.normalized(), TAU * ease(t, -1.6))
	var pivot := Vector3(0, 0.6, 0) * _body_scale
	# Hạ thấp người lúc đang lộn để không lơ lửng.
	var origin := pivot - rot * pivot - Vector3(0, 0.25 * sin(PI * t), 0)
	_body.transform = Transform3D(rot * Basis.from_scale(_body_scale), origin)


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
			lean = -ln * 0.4 + ln * 0.6 * _jolt
		S.STAGGER:
			if cur.recoil:
				match cur.attack_dir:
					Dir.LEFT: twist = tw * 0.6
					Dir.RIGHT: twist = -tw * 0.6
					Dir.UP: lean = ln * 0.5
			else:
				lean = ln * 1.5
	var k := 1.0 - exp(-poses.blend_speed * delta)
	_twist = lerpf(_twist, twist, k)
	_lean = lerpf(_lean, lean, k)
	_chest.rotation = Vector3(_lean + _react.x, _twist + _react.y, _react.z)
	_head.rotation = Vector3(-_lean * 0.5 + _react.x * 0.6, -_twist * 0.6, -_react.z * 0.3)


## Bước chân: tính theo vận tốc trong hệ toạ độ của nhân vật nên đi ngang, đi lùi đều đúng chân.
func _update_gait(cur: FighterState, delta: float) -> void:
	var right := Vector2(cos(rotation.y), -sin(rotation.y))
	var fwd := Vector2(-sin(rotation.y), -cos(rotation.y))
	_local_vel = _local_vel.lerp(Vector2(cur.velocity.dot(right), -cur.velocity.dot(fwd)), 1.0 - exp(-10.0 * delta))
	var spd := _local_vel.length()
	var k := 1.0 - exp(-8.0 * delta)
	_run = lerpf(_run, clampf(inverse_lerp(poses.walk_speed, poses.run_speed, spd), 0.0, 1.0), k)
	_gait_amount = lerpf(_gait_amount, clampf(spd / 0.8, 0.0, 1.0), k)
	# Một chu kỳ thân đi được một sải = hai bước. Chân chạm đất đi lùi 2*reach trong duty phần chu kỳ,
	# nên sải = 2*reach/duty thì bàn chân không trượt trên đất.
	var stride := 2.0 * _foot_reach() / _duty()
	_gait = fmod(_gait + spd / stride * TAU * delta, TAU * 64.0)
	# Hông thấp nhất lúc chân vừa tiếp đất (hai lần mỗi chu kỳ), cao nhất lúc chân kia vung qua.
	var bob := lerpf(0.025, 0.045, _run) * (0.5 + 0.5 * cos(2.0 * _gait - PI * _duty())) * _gait_amount
	_pelvis.position.y = HIP_HEIGHT - 0.03 - poses.run_crouch * _run * _gait_amount - bob
	# Chạy thì người đổ về trước.
	if cur.state != S.DEAD:
		_chest.rotation.x = _lean + _react.x - deg_to_rad(poses.run_lean_deg) * _run * _gait_amount * _forwardness()
	if _cape_mat:
		_cape_mat.set_shader_parameter("sway", clampf(-_local_vel.y * 0.07, -0.1, 0.4))


func _foot_reach() -> float:
	return lerpf(poses.walk_foot_reach, poses.run_foot_reach, _run)


func _duty() -> float:
	return lerpf(poses.walk_duty, poses.run_duty, _run)


## 1 khi chạy thẳng tới, 0 khi đi ngang hay đi lùi.
func _forwardness() -> float:
	return clampf(-_local_vel.y / maxf(0.1, _local_vel.length()), 0.0, 1.0)


## Một bàn chân tại pha u (0..1): [dọc hướng đi -1..1, độ nhấc 0..1, góc gập bàn chân (radian, dương = mũi nhấc lên)].
## Pha 0 là lúc gót vừa chạm đất ở phía trước.
func _foot_cycle(u: float) -> Array:
	var duty := _duty()
	if u < duty:
		var s := u / duty
		# Đặt gót, hạ cả bàn, rồi nhón mũi đẩy đi.
		var pitch := 0.3 * (1.0 - smoothstep(0.0, 0.2, s)) - 0.55 * smoothstep(0.65, 1.0, s)
		return [lerpf(1.0, -1.0, s), 0.0, pitch]
	var t := (u - duty) / (1.0 - duty)
	var e := t * t * (3.0 - 2.0 * t)
	# Vung chân: mũi chúc xuống lúc rời đất, nhấc lên chuẩn bị đặt gót.
	return [lerpf(-1.0, 1.0, e), sin(PI * minf(1.0, t * 1.15)), lerpf(-0.55, 0.3, smoothstep(0.3, 0.95, t))]


func _update_limbs() -> void:
	var move_dir := Vector3(_local_vel.x, 0, _local_vel.y)
	move_dir = move_dir.normalized() if move_dir.length() > 0.05 else Vector3(0, 0, -1)
	var reach := _foot_reach() * _gait_amount
	var lift := lerpf(poses.foot_lift, poses.run_foot_lift, _run) * _gait_amount

	var cycle := {}
	for side in [-1, 1]:
		cycle[side] = _foot_cycle(fposmod((_gait + (PI if side == 1 else 0.0)) / TAU, 1.0))
	# Hông xoay theo chân: chân nào đang ở trước thì hông bên đó đưa ra trước.
	_pelvis.rotation.y = -((cycle[-1][0] as float) - (cycle[1][0] as float)) * 0.06 * _gait_amount * _forwardness()
	var pelvis := _pelvis.transform
	var chest := pelvis * _chest.transform

	var feet := {}
	var knee_poles := {}
	var foot_pitch := {}
	for side in [-1, 1]:
		var c: Array = cycle[side]
		# Thế đứng thủ: chân trái trước, chân phải sau.
		var stance := Vector3(0.13 * side, ANKLE_HEIGHT, 0.1 * side * (1.0 - _gait_amount))
		var foot := stance + move_dir * (c[0] as float) * reach
		foot.y += (c[1] as float) * lift
		foot_pitch[side] = (c[2] as float) * _gait_amount
		var hip := pelvis * Vector3(HIP_JOINT.x * side, HIP_JOINT.y, HIP_JOINT.z)
		feet[side] = foot + Vector3(0, _rig_ankle_offset, 0)
		knee_poles[side] = Vector3(0.3 * side, 0, -1)
		var knee := _ik(hip, foot, THIGH, SHIN, knee_poles[side])
		_segment(_thigh[side], hip, knee)
		_segment(_shin[side], knee, foot)
		(_foot[side] as MeshInstance3D).position = foot + Vector3(0, -0.03, -0.06)
		(_foot[side] as MeshInstance3D).rotation = Vector3(foot_pitch[side], _pelvis.rotation.y * 0.5, 0)

	# Tay phải luôn nắm vũ khí.
	var r_sh := chest * Vector3(SHOULDER.x, SHOULDER.y, SHOULDER.z)
	_arm(1, r_sh, _hand.position, Vector3(0.4, -0.6, 0.5))

	# Tay trái: cầm khiên, hoặc nắm cán phía dưới tay phải.
	var l_sh := chest * Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	var l_target := _left_hand_target
	if _shield == null:
		# Tay trái nắm chỗ cán gần vai trái nhất (không sát tay phải), trượt dần dọc cán khi đổi thế.
		var y := _hand.basis.y.normalized()
		var t := clampf((l_sh - _hand.position).dot(y), -poses.two_hand_grip, poses.two_hand_grip)
		if absf(t) < poses.two_hand_grip_min:
			t = poses.two_hand_grip_min * (1.0 if t >= 0.0 else -1.0)
		_grip_t = lerpf(_grip_t, t, 0.35)
		if absf(_grip_t) < poses.two_hand_grip_min * 0.5:
			_grip_t = t
		l_target = _hand.position + y * _grip_t
	var l_hand := _arm(-1, l_sh, l_target, Vector3(-0.4, -0.6, 0.5))
	if _shield:
		_shield.position = l_hand + Vector3(0.02, 0.0, -0.06)
		_shield.rotation = Vector3(0.1, _twist * 0.5, 0.0)

	if _rig:
		_rig.pose(HIP_HEIGHT - _pelvis.position.y, _pelvis.rotation.y, _chest.rotation, _head.rotation,
			{1: _hand.position, -1: l_hand}, {1: Vector3(0.4, -0.6, 0.5), -1: Vector3(-0.4, -0.6, 0.5)}, feet, knee_poles, foot_pitch)


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
