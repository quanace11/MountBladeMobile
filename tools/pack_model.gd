extends SceneTree
## Lưu model đã có khung xương (fbx) thành cảnh .scn gọn để đưa vào game mà không cần file fbx nặng:
## bỏ hoạt cảnh, bỏ hình biến dạng mặt, bỏ vật liệu (FighterView tự gán ảnh màu, ảnh pháp tuyến), chép lưới và Skin vào trong cảnh.
## Chạy: godot --headless --path . -s tools/pack_model.gd -- res://đường/dẫn/model.fbx res://đường/dẫn/model.scn

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("cần: <fbx vào> <scn ra>")
		quit(1)
		return
	var root: Node3D = (load(args[0]) as PackedScene).instantiate()
	for n in root.find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# Dựng lại lưới bỏ hình biến dạng mặt (blend shape, nặng hàng chục MB, game không dùng) rồi tạo lại LOD
		# để đứng xa thì vẽ ít tam giác hơn.
		var im := ImporterMesh.new()
		for i in mi.mesh.get_surface_count():
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(i))
		im.generate_lods(25.0, 60.0, [])
		mi.mesh = im.get_mesh()
		if mi.skin:
			mi.skin = mi.skin.duplicate()
	root.scene_file_path = ""
	for n in root.find_children("*", "", true, false):
		n.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	print("saved ", args[1], " err=", ResourceSaver.save(packed, args[1], ResourceSaver.FLAG_COMPRESS))
	root.free()
	quit()
