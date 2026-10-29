extends TestBase
## Di chuyển kiểu Bannerlord: có quán tính, đi lùi và đi ngang chậm hơn.


func _speed_after(move: Vector2, ticks: int) -> float:
	var sim := make_sim()
	# Tướng nhìn về địch ở phía -z (yaw 0) trong suốt bài test.
	var id := sim.add_fighter(char_def("dao_tuong"), 0, Vector2.ZERO, 0.0)
	sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0, -9), 0.0)
	var c := FighterCommand.new()
	c.move = move
	for t in ticks:
		sim.step({id: c})
	return sim.state.get_fighter(id).velocity.length()


func test_accelerates_gradually() -> void:
	var def := char_def("dao_tuong")
	check(_speed_after(Vector2(0, -1), 1) < def.move_speed * 0.5, "tick đầu chưa đạt tốc độ tối đa")
	check(absf(_speed_after(Vector2(0, -1), 30) - def.move_speed) < 0.01, "sau 1 giây đạt tốc độ tối đa")


func test_backward_and_strafe_are_slower() -> void:
	var fwd := _speed_after(Vector2(0, -1), 30)
	var back := _speed_after(Vector2(0, 1), 30)
	var side := _speed_after(Vector2(1, 0), 30)
	check(back < side and side < fwd, "lùi < ngang < thẳng (%.2f, %.2f, %.2f)" % [back, side, fwd])


func test_free_aim_turns_to_command_not_nearest_enemy() -> void:
	var sim := make_sim()
	var id := sim.add_fighter(char_def("dao_tuong"), 0, Vector2.ZERO, 0.0)
	sim.add_fighter(char_def("dao_tuong"), 1, Vector2(0, -3), 0.0)
	var c := FighterCommand.new()
	c.has_face = true
	c.face_yaw = -PI * 0.5
	for t in 30:
		sim.step({id: c})
	var f := sim.state.get_fighter(id)
	check(absf(wrapf(f.yaw - c.face_yaw, -PI, PI)) < 0.01, "tự ngắm: quay mặt theo lệnh (yaw %.2f)" % f.yaw)
	c.has_face = false
	for t in 30:
		sim.step({id: c})
	check(absf(wrapf(f.yaw, -PI, PI)) < 0.01, "tắt tự ngắm: quay lại nhìn địch gần nhất (yaw %.2f)" % f.yaw)


func test_free_aim_turn_speed_is_limited() -> void:
	var sim := make_sim()
	var id := sim.add_fighter(char_def("dao_tuong"), 0, Vector2.ZERO, 0.0)
	var c := FighterCommand.new()
	c.has_face = true
	c.face_yaw = PI * 0.9
	sim.step({id: c})
	var step := deg_to_rad(char_def("dao_tuong").turn_speed_deg) * sim.ctx.dt
	check(absf(sim.state.get_fighter(id).yaw) <= step + 0.0001, "mỗi tick chỉ xoay tối đa theo turn_speed_deg")
