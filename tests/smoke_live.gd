extends SceneTree
## Chạy thử chế độ LIVE không cần màn hình hay TikTok: giả lập người xem vào phe, tặng quà, thả tim,
## để bot đánh người chơi đứng yên tới khi hết ván và sang ván mới.
##   godot --headless --path . -s tests/smoke_live.gd

var _frames := 0
var _runner: Node
var _runner_id := 0
var _spawned_max := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var game := root.get_node("Game")
	var live := root.get_node("Live")
	if _frames == 5:
		game.live_bridge_url = "ws://127.0.0.1:1"  # không có cầu nối: game vẫn phải chạy
		game.start_live()
	if _frames > 10 and current_scene and current_scene.has_method("player"):
		if _runner_id != 0 and current_scene.get_instance_id() != _runner_id:
			print("smoke live ok: sang ván mới, tỉ số %s, đông nhất %d tướng trên sân" % [str(live.queue.round_wins), _spawned_max])
			quit(0)
			return false
		_runner = current_scene
		_runner_id = current_scene.get_instance_id()
	if _frames == 20:
		for i in 4:
			live.handle({"type": "comment", "user": "x%d" % i, "nick": "Xanh %d" % i, "text": "1"})
			live.handle({"type": "comment", "user": "d%d" % i, "nick": "Đỏ %d" % i, "text": "2"})
		live.handle({"type": "gift", "user": "d9", "nick": "Đại gia", "gift": "Sư tử", "coins": 500})
		live.handle({"type": "like", "user": "t", "nick": "t", "count": 50})
	if _runner and is_instance_valid(_runner):
		_spawned_max = maxi(_spawned_max, _runner.sim.state.fighters.size())
	if _frames > 20000:
		printerr("smoke live: không hết ván / không sang ván mới")
		quit(1)
	return false
