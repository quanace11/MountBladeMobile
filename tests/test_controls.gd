extends TestBase
## Chế độ điều khiển và trợ ngắm.


func test_presets() -> void:
	check(ControlPrefs.preset(ControlPrefs.Mode.FREE).free_aim, "Tự xoay: kéo để xoay người")
	check(not ControlPrefs.preset(ControlPrefs.Mode.LOCK).free_aim, "Khoá địch gần: tự quay về địch")
	check(ControlPrefs.preset(ControlPrefs.Mode.LOCK).attack_button, "hai chế độ có sẵn đều dùng nút CHÉM")


func test_custom_prefs_roundtrip() -> void:
	var p := ControlPrefs.new()
	p.free_aim = false
	p.camera_distance = 5.5
	p.aim_assist = true
	var cfg := ConfigFile.new()
	p.save(cfg, "c")
	var q := ControlPrefs.new()
	q.load_from(cfg, "c")
	check(not q.free_aim and q.aim_assist and is_equal_approx(q.camera_distance, 5.5), "lưu và đọc lại đủ tuỳ chỉnh")


## Người chơi nhìn lệch địch 20 độ, đang gồng: trợ ngắm bật thì quay về địch, tắt thì giữ hướng camera.
func _face_yaw_with_assist(on: bool) -> Array:
	var sim := make_sim()
	var me := sim.add_fighter(char_def("dao_tuong"), 0, Vector2.ZERO, 0.0)
	sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0, -2), 0.0)
	var touch := TouchController.new()
	touch.setup(load(CONFIG + "input/touch.tres"), InputConfig.BlockScheme.BUTTON)
	touch.attack_button_dir = Dir.RIGHT
	var cam_yaw := deg_to_rad(20.0)
	var src := PlayerCommandSource.new(touch, func() -> float: return cam_yaw)
	src.fighter_id = me
	src.aim_assist = on
	var c := src.get_command(sim.state)
	touch.free()
	return [c, cam_yaw]


func test_aim_assist_snaps_to_enemy_near_crosshair() -> void:
	var r := _face_yaw_with_assist(true)
	var c: FighterCommand = r[0]
	check_eq(c.attack_dir, Dir.RIGHT, "giữ nút CHÉM kéo phải là gồng phải")
	check(absf(c.face_yaw) < 0.01, "trợ ngắm quay về địch (yaw %.2f)" % c.face_yaw)
	r = _face_yaw_with_assist(false)
	check(is_equal_approx((r[0] as FighterCommand).face_yaw, r[1]), "tắt trợ ngắm thì giữ hướng camera")
