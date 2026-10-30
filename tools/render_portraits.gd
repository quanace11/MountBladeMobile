extends SceneTree
## Chụp ảnh chân dung cho nút chọn nhân vật: mỗi model trong config/models ra assets/models/<tên>/portrait.png.
## Cần màn hình (không chạy --headless):
##   godot --path . --rendering-driver opengl3 -s tools/render_portraits.gd

const SIZE := Vector2i(256, 320)

var _names: Array = []
var _view: FighterView
var _state: FighterState
var _cam: Camera3D
var _world: Node3D
var _frame := 0


func _initialize() -> void:
	for f in ResourceLoader.list_directory("res://config/models"):
		if f.ends_with(".tres"):
			_names.append(f.get_basename())
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.15, 0.11)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65, 0.6, 0.55)
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -25, 0)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30
	_world.add_child(_cam)
	_cam.make_current()
	_cam.look_at_from_position(Vector3(1.0, 1.35, -4.4), Vector3(0, 0.95, 0))


func _process(_d: float) -> bool:
	if _view == null:
		if _names.is_empty():
			quit(0)
			return false
		_state = FighterState.new()
		_state.def = load("res://config/characters/dao_tuong.tres")
		_state.hp = _state.def.max_hp
		_view = FighterView.new()
		_world.add_child(_view)
		_view.setup(_state, load("res://config/visual/poses.tres"), false,
			load("res://config/models/%s.tres" % _names[0]))
		_frame = 0
	_view.sync(_state, _state.pos, _state.yaw, 1.0, 0.1)
	_frame += 1
	if _frame == 12:
		var img := root.get_viewport().get_texture().get_image()
		var vp := img.get_size()
		var h := vp.y
		var w := h * SIZE.x / SIZE.y
		img = img.get_region(Rect2i((vp.x - w) / 2, 0, w, h))
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		var out := "res://assets/models/%s/portrait.png" % _names[0]
		img.save_png(out)
		print("đã lưu ", out)
		_view.queue_free()
		_view = null
		_names.pop_front()
	return false
