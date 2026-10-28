extends SceneTree
## Chạy thử cả game không cần màn hình: mở menu, vào trận 1 vs 3, để bot đánh người chơi đứng yên.
##   godot --headless --path . -s tests/smoke_match.gd

var _frames := 0
var _runner: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var game := root.get_node("Game")
	if _frames == 5:
		game.match_id = &"1v3"
		game.bot_id = &"hard"
		game.start_match()
	if _frames > 10 and _runner == null and current_scene.has_method("player"):
		_runner = current_scene
	if _runner and (_runner.sim.state.finished or _frames > 6000):
		var p = _runner.player()
		print("smoke ok: tick=%d finished=%s player_hp=%.0f" % [_runner.sim.state.tick, _runner.sim.state.finished, p.hp])
		quit(0)
	if _frames > 7000:
		printerr("smoke: không vào được trận")
		quit(1)
	return false
