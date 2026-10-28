class_name ArenaBuilder
extends RefCounted
## Dựng đấu trường: bầu trời thật, nền đất pha cỏ, hàng rào cọc gỗ có cổng và chòi canh,
## nhà ngói, cây, đá, cờ, đồi núi xa. Vật lặp lại (cọc, cây, đá) vẽ bằng MultiMesh để ít lệnh vẽ.

const GROUND_SHADER := "res://assets/shaders/ground.gdshader"
const TERRAIN_SHADER := "res://assets/shaders/terrain.gdshader"
const BANNER_SHADER := "res://assets/shaders/banner.gdshader"


static func build(parent: Node3D, cfg: GameConfig, q: QualityPreset, a: ArenaDef) -> DirectionalLight3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = a.seed
	var sun := _environment(parent, a, q)
	_ground(parent, cfg, a)
	var gate := _palisade(parent, cfg, a, rng)
	_gate_towers(parent, cfg, gate, a)
	_banners(parent, cfg, a, gate)
	var spots := _scatter_spots(a, q, rng, gate)
	_houses(parent, a, spots["houses"], rng)
	_trees(parent, a, spots["trees"], rng)
	_rocks(parent, a, spots["rocks"], rng)
	_hills(parent, a, rng)
	return sun


static func _environment(parent: Node3D, a: ArenaDef, q: QualityPreset) -> DirectionalLight3D:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = a.sky_texture
	pano.energy_multiplier = a.sky_energy
	sky.sky_material = pano
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = a.ambient_energy
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	env.environment = e
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = a.sun_rotation_deg
	sun.light_energy = a.sun_energy
	sun.light_color = a.sun_color
	sun.shadow_enabled = q.shadows_enabled
	sun.directional_shadow_max_distance = q.shadow_max_distance
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	parent.add_child(sun)
	return sun


static func _ground(parent: Node3D, cfg: GameConfig, a: ArenaDef) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * a.ground_size
	ground.mesh = plane
	ground.material_override = Mats.shader(GROUND_SHADER, {
		"dirt_albedo": load(a.dirt_texture + "_diff.jpg"),
		"dirt_normal": load(a.dirt_texture + "_nor.jpg"),
		"dirt_rough": load(a.dirt_texture + "_rough.jpg"),
		"grass_albedo": load(a.grass_texture + "_diff.jpg"),
		"grass_normal": load(a.grass_texture + "_nor.jpg"),
		"grass_rough": load(a.grass_texture + "_rough.jpg"),
		"arena_radius": cfg.arena_radius + a.palisade_gap,
		"dirt_scale": a.dirt_scale,
		"grass_scale": a.grass_scale,
		"grass_tint": a.grass_tint,
	})
	parent.add_child(ground)


static func _multimesh(parent: Node3D, mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi


## Hàng rào cọc gỗ nhọn đầu quanh đấu trường, chừa một cổng. Trả về góc cổng (radian).
static func _palisade(parent: Node3D, cfg: GameConfig, a: ArenaDef, rng: RandomNumberGenerator) -> float:
	var r := cfg.arena_radius + a.palisade_gap
	var gate := deg_to_rad(a.gate_angle_deg)
	var gate_half := a.gate_width * 0.5 / r
	var count := int(TAU * r / (a.log_radius * 1.9))
	var bark := Mats.pbr(a.bark_texture, 1.0)
	var logs := []
	var tips := []
	for i in count:
		var ang := TAU * i / count
		if absf(wrapf(ang - gate, -PI, PI)) < gate_half:
			continue
		var h := rng.randf_range(a.log_height_min, a.log_height_max)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(cos(ang), 0, sin(ang)).cross(Vector3.UP), rng.randf_range(-0.03, 0.03))
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		logs.append(Transform3D(basis.scaled(Vector3(1, h, 1)), pos + Vector3(0, h * 0.5, 0)))
		tips.append(Transform3D(basis, pos + basis.y * h + Vector3(0, 0.18, 0)))
	var log_mesh := FighterView.cyl(a.log_radius, a.log_radius * 1.05, 1.0, 7)
	log_mesh.material = bark
	_multimesh(parent, log_mesh, logs)
	var tip_mesh := FighterView.cyl(0.0, a.log_radius, 0.36, 7)
	tip_mesh.material = bark
	_multimesh(parent, tip_mesh, tips)
	# Hai thanh ngang buộc cọc, nhìn từ trong đấu trường.
	var wood := Mats.pbr(a.wood_texture, 1.0)
	for y in [0.9, 2.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - a.log_radius - 0.12
		ring.outer_radius = r - a.log_radius
		ring.rings = 64
		ring.ring_segments = 4
		ring.material = wood
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.position.y = y
		parent.add_child(mi)
	return gate


## Hai chòi canh hai bên cổng: bốn cột, sàn, lan can, mái ngói.
static func _gate_towers(parent: Node3D, cfg: GameConfig, gate: float, a: ArenaDef) -> void:
	var wood := Mats.pbr(a.wood_texture, 1.0)
	var roof := Mats.pbr(a.roof_texture, 1.5)
	for side in [-1.0, 1.0]:
		var r := cfg.arena_radius + a.palisade_gap
		var ang: float = gate + side * (a.gate_width * 0.5 + 1.1) / r
		var tower := Node3D.new()
		tower.position = Vector3(cos(ang) * (r + 0.6), 0, sin(ang) * (r + 0.6))
		tower.rotation.y = -ang + PI * 0.5
		parent.add_child(tower)
		for cx in [-0.8, 0.8]:
			for cz in [-0.8, 0.8]:
				var post := MeshInstance3D.new()
				post.mesh = FighterView.cyl(0.11, 0.13, 5.2, 6)
				post.material_override = wood
				post.position = Vector3(cx, 2.6, cz)
				tower.add_child(post)
		var floor := MeshInstance3D.new()
		floor.mesh = FighterView.box(Vector3(2.0, 0.15, 2.0))
		floor.material_override = wood
		floor.position.y = 3.6
		tower.add_child(floor)
		for k in 4:
			var rail := MeshInstance3D.new()
			rail.mesh = FighterView.box(Vector3(2.0, 0.6, 0.08))
			rail.material_override = wood
			rail.position = Vector3(0, 4.0, 0).rotated(Vector3.UP, k * PI * 0.5) + Vector3(0, 0, 0.96).rotated(Vector3.UP, k * PI * 0.5)
			rail.rotation.y = k * PI * 0.5
			tower.add_child(rail)
		var cap := MeshInstance3D.new()
		var pyramid := FighterView.cyl(0.0, 1.75, 1.2, 4)
		cap.mesh = pyramid
		cap.material_override = roof
		cap.position.y = 5.8
		cap.rotation.y = PI * 0.25
		tower.add_child(cap)


static func _banners(parent: Node3D, cfg: GameConfig, a: ArenaDef, gate: float) -> void:
	var r := cfg.arena_radius + a.palisade_gap - 0.5
	var wood := Mats.color(Color(0.3, 0.2, 0.12), 0.8)
	var colors := [Color(0.7, 0.08, 0.05), Color(0.85, 0.65, 0.12)]
	for i in a.banner_count:
		var ang := gate + PI + (i - (a.banner_count - 1) * 0.5) * 0.45
		var base := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var pole := MeshInstance3D.new()
		pole.mesh = FighterView.cyl(0.04, 0.05, 5.0, 6)
		pole.material_override = wood
		pole.position = base + Vector3(0, 2.5, 0)
		parent.add_child(pole)
		var flag := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.6)
		quad.subdivide_width = 6
		flag.mesh = quad
		flag.material_override = Mats.shader(BANNER_SHADER, {"color": colors[i % 2]})
		flag.position = base + Vector3(0, 4.1, 0)
		flag.rotation.y = -ang
		flag.translate_object_local(Vector3(-0.5, 0, 0))
		parent.add_child(flag)


## Chọn chỗ đặt nhà, cây, đá ngoài hàng rào, tránh trước cổng và tránh chồng lên nhau.
static func _scatter_spots(a: ArenaDef, q: QualityPreset, rng: RandomNumberGenerator, gate: float) -> Dictionary:
	var taken: Array = []
	var out := {"houses": [], "trees": [], "rocks": []}
	var plan := [["houses", roundi(a.house_count * q.scenery_density), 6.5], ["trees", roundi(a.tree_count * q.scenery_density), 2.5], ["rocks", roundi(a.rock_count * q.scenery_density), 1.5]]
	for p in plan:
		var placed := 0
		var tries := 0
		while placed < p[1] and tries < 400:
			tries += 1
			var ang := rng.randf() * TAU
			if absf(wrapf(ang - gate, -PI, PI)) < 0.35:
				continue
			var rad := rng.randf_range(a.scenery_radius_min, a.scenery_radius_max)
			var pos := Vector2(cos(ang), sin(ang)) * rad
			var ok := true
			for t in taken:
				if pos.distance_to(t[0]) < t[1] + p[2]:
					ok = false
					break
			if not ok:
				continue
			taken.append([pos, p[2]])
			out[p[0]].append(pos)
			placed += 1
	return out


## Nhà tường trát vữa, nền đá, cột gỗ, mái ngói hai mái, quay mặt về đấu trường.
static func _houses(parent: Node3D, a: ArenaDef, spots: Array, rng: RandomNumberGenerator) -> void:
	var stone := Mats.pbr(a.stone_texture, 0.6, true)
	var wall := Mats.pbr(a.wall_texture, 0.5, true)
	var wood := Mats.pbr(a.wood_texture, 1.0)
	var roof := Mats.pbr(a.roof_texture, 2.0)
	for p in spots:
		var w := rng.randf_range(5.0, 7.5)
		var d := rng.randf_range(4.0, 5.0)
		var h := rng.randf_range(2.6, 3.2)
		var house := Node3D.new()
		house.position = Vector3(p.x, 0, p.y)
		house.rotation.y = atan2(p.x, p.y)
		parent.add_child(house)
		_part(house, FighterView.box(Vector3(w + 0.6, 0.5, d + 0.6)), stone, Vector3(0, 0.25, 0))
		_part(house, FighterView.box(Vector3(w, h, d)), wall, Vector3(0, 0.5 + h * 0.5, 0))
		for cx in [-w * 0.5, w * 0.5]:
			for cz in [-d * 0.5, d * 0.5]:
				_part(house, FighterView.cyl(0.13, 0.13, h, 6), wood, Vector3(cx, 0.5 + h * 0.5, cz))
		_part(house, FighterView.box(Vector3(w + 0.1, 0.18, 0.2)), wood, Vector3(0, 0.5 + h, -d * 0.5))
		# Cửa gỗ.
		_part(house, FighterView.box(Vector3(1.1, 2.0, 0.08)), wood, Vector3(0, 1.5, -d * 0.5 - 0.02))
		var prism := PrismMesh.new()
		prism.size = Vector3(d + 1.6, 1.9, w + 1.4)
		var roof_mi := _part(house, prism, roof, Vector3(0, 0.5 + h + 0.95, 0))
		roof_mi.rotation.y = PI * 0.5
		_part(house, FighterView.cyl(0.12, 0.12, w + 1.6, 6), wood, Vector3(0, 0.5 + h + 1.9, 0), Vector3(0, 0, 90))


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Cây: thân gỗ và ba tán lá tròn; tất cả thân một MultiMesh, tất cả tán một MultiMesh.
static func _trees(parent: Node3D, a: ArenaDef, spots: Array, rng: RandomNumberGenerator) -> void:
	var trunks := []
	var crowns := []
	for p in spots:
		var h := rng.randf_range(3.5, 6.0)
		var base := Vector3(p.x, 0, p.y)
		trunks.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), base + Vector3(0, h * 0.5, 0)))
		for k in 3:
			var s := rng.randf_range(1.4, 2.2)
			var off := Vector3(rng.randf_range(-0.8, 0.8), h + rng.randf_range(-0.4, 0.8), rng.randf_range(-0.8, 0.8))
			crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), base + off))
	var trunk := FighterView.cyl(0.14, 0.22, 1.0, 7)
	trunk.material = Mats.pbr(a.bark_texture, 1.0)
	_multimesh(parent, trunk, trunks)
	var crown := FighterView.sphere(1.0, 2.0)
	crown.radial_segments = 9
	crown.rings = 5
	crown.material = Mats.pbr(a.grass_texture, 0.6, true, Color(0.35, 0.5, 0.25))
	_multimesh(parent, crown, crowns)


## Đá: một khối cầu méo dùng chung, xoay và co giãn ngẫu nhiên.
static func _rocks(parent: Node3D, a: ArenaDef, spots: Array, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = a.seed
	noise.frequency = 1.6
	var base := FighterView.sphere(1.0, 2.0)
	base.radial_segments = 12
	base.rings = 7
	var st := SurfaceTool.new()
	st.create_from(base, 0)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + noise.get_noise_3dv(v) * 0.35)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.generate_normals()
	var rock := st.commit()
	rock.surface_set_material(0, Mats.pbr(a.rock_texture, 0.5, true))
	var xs := []
	for p in spots:
		var s := rng.randf_range(0.5, 1.6)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(s * 1.3, s * 0.7, s))
		xs.append(Transform3D(b, Vector3(p.x, s * 0.2, p.y)))
	_multimesh(parent, rock, xs)


## Vòng đồi núi xa bao quanh, cao dần ra ngoài; cỏ ở chỗ thoải, đá ở chỗ dốc.
static func _hills(parent: Node3D, a: ArenaDef, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = a.seed + 1
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	var seg := 96
	var rings := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in rings + 1:
		var t := float(j) / rings
		var r := lerpf(a.hill_radius_inner, a.hill_radius_outer, t)
		var row := []
		for i in seg:
			var ang := TAU * i / seg
			var x := cos(ang) * r
			var z := sin(ang) * r
			var h := a.hill_height * pow(t, 1.4) * (0.45 + 0.55 * (noise.get_noise_2d(x, z) * 0.5 + 0.5))
			row.append(Vector3(x, h - 0.3, z))
		pts.append(row)
	for j in rings:
		for i in seg:
			var i2 := (i + 1) % seg
			var p00: Vector3 = pts[j][i]
			var p10: Vector3 = pts[j][i2]
			var p01: Vector3 = pts[j + 1][i]
			var p11: Vector3 = pts[j + 1][i2]
			for v in [p00, p01, p10, p10, p01, p11]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = Mats.shader(TERRAIN_SHADER, {
		"grass_albedo": load(a.grass_texture + "_diff.jpg"),
		"rock_albedo": load(a.rock_texture + "_diff.jpg"),
		"grass_tint": a.grass_tint,
	})
	parent.add_child(mi)
