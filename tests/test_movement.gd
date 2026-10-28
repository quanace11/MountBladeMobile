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
