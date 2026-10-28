extends SceneTree
## Chạy test không cần mở game:
##   godot --headless --path . -s tests/run_tests.gd
## Mỗi file test_*.gd trong tests/ là một lớp có các hàm bắt đầu bằng "test_".

var _failures: Array[String] = []
var _current := ""


func _initialize() -> void:
	var total := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var inst = script.new()
			inst.set_meta("runner", self)
			_current = file + "::" + name
			var before := _failures.size()
			inst.call(name)
			total += 1
			print(("  ok   " if _failures.size() == before else "  FAIL ") + _current)
	print("\n%d test, %d lỗi" % [total, _failures.size()])
	for f in _failures:
		printerr(f)
	quit(1 if _failures.size() > 0 else 0)


func fail(msg: String) -> void:
	_failures.append(_current + ": " + msg)
