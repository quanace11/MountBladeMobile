class_name ArenaBuilder
extends RefCounted
## Dựng bãi đấu: bầu trời thật, nền đất pha cỏ, không rào chắn; nhà ngói, cây, đá rải xa
## ngoài vùng đánh nhau, đồi núi ở chân trời. Vật lặp lại (cọc, cây, đá) vẽ bằng MultiMesh để ít lệnh vẽ.

const GROUND_SHADER := "res://assets/shaders/ground.gdshader"
const TERRAIN_SHADER := "res://assets/shaders/terrain.gdshader"


static func build(parent: Node3D, cfg: GameConfig, q: QualityPreset, a: ArenaDef) -> DirectionalLight3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = a.seed
	var sun := _environment(parent, a, q)
	_ground(parent, cfg, a)
	var spots := _scatter_spots(a, q, rng)
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
		"arena_radius": a.dirt_radius,
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


## Chọn chỗ đặt nhà, cây, đá ngoài vùng đánh nhau, tránh chồng lên nhau.
static func _scatter_spots(a: ArenaDef, q: QualityPreset, rng: RandomNumberGenerator) -> Dictionary:
	var taken: Array = []
	var out := {"houses": [], "trees": [], "rocks": []}
	var plan := [["houses", roundi(a.house_count * q.scenery_density), 6.5], ["trees", roundi(a.tree_count * q.scenery_density), 2.5], ["rocks", roundi(a.rock_count * q.scenery_density), 1.5]]
	for p in plan:
		var placed := 0
		var tries := 0
		while placed < p[1] and tries < 400:
			tries += 1
			var ang := rng.randf() * TAU
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
