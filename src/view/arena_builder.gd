class_name ArenaBuilder
extends RefCounted
## Dựng đấu trường tạm bằng khối hình: nền cát, vòng cọc rào (MultiMesh), núi xa, ánh sáng.


static func build(parent: Node3D, cfg: GameConfig, q: QualityPreset) -> DirectionalLight3D:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.7, 0.72, 0.7)
	sky_mat.ground_horizon_color = Color(0.6, 0.5, 0.38)
	sky_mat.ground_bottom_color = Color(0.3, 0.25, 0.2)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = q.shadows_enabled
	sun.directional_shadow_max_distance = q.shadow_max_distance
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	parent.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	ground.mesh = plane
	ground.material_override = FighterView.shared_mat(Color(0.42, 0.36, 0.25))
	parent.add_child(ground)

	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = cfg.arena_radius + 0.5
	disc.bottom_radius = cfg.arena_radius + 0.5
	disc.height = 0.04
	disc.radial_segments = 48
	floor_disc.mesh = disc
	floor_disc.position.y = 0.0
	floor_disc.material_override = FighterView.shared_mat(Color(0.5, 0.42, 0.3))
	parent.add_child(floor_disc)

	# Cọc rào quanh đấu trường: một MultiMesh, một lần vẽ.
	var post := CylinderMesh.new()
	post.top_radius = 0.1
	post.bottom_radius = 0.13
	post.height = 1.6
	post.radial_segments = 6
	post.material = FighterView.shared_mat(Color(0.38, 0.25, 0.14))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post
	mm.instance_count = q.arena_props
	var r := cfg.arena_radius + 1.0
	for i in q.arena_props:
		var a := TAU * i / q.arena_props
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(a) * r, 0.8, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)

	# Thanh ngang nối các cọc.
	var rail := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.05
	torus.outer_radius = r + 0.05
	torus.rings = 48
	torus.ring_segments = 4
	rail.mesh = torus
	rail.position.y = 1.2
	rail.material_override = post.material
	parent.add_child(rail)

	# Núi xa: vài khối nón, không đổ bóng.
	var mountain_mat := FighterView.shared_mat(Color(0.2, 0.3, 0.22))
	for i in 7:
		var m := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 14.0 + (i % 3) * 5.0
		cone.height = 12.0 + (i % 4) * 4.0
		cone.radial_segments = 6
		m.mesh = cone
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 7.0 + 0.3
		m.position = Vector3(cos(a) * 65.0, cone.height * 0.5 - 1.0, sin(a) * 65.0)
		m.material_override = mountain_mat
		parent.add_child(m)
	return sun
