extends SceneTree
## Ghép model có ảnh màu (không khung xương) vào khung xương của model đã rig.
## Hai file là cùng một tướng xuất từ Tripo: bản rig bị dựng lại lưới nên mất ảnh màu,
## bản có ảnh thì không có xương. Mỗi đỉnh của lưới có ảnh lấy trọng số xương từ
## vài đỉnh gần nhất của lưới đã rig (cùng hướng pháp tuyến), rồi lưu thành một cảnh mới.
## Chạy: godot --headless --path . -s tools/bake_textured_model.gd

const RIGGED := "res://assets/models/tuong/tuong.fbx"
const TEXTURED := "res://assets/models/tuong/tuongdau.fbx"
const OUT := "res://assets/models/tuong/tuong_textured.scn"
const NEIGHBOURS := 4
const CELL := 0.03


func _init() -> void:
	var tex_root: Node = (load(TEXTURED) as PackedScene).instantiate()
	var rig_root: Node3D = (load(RIGGED) as PackedScene).instantiate()
	var tex_mi := _mesh(tex_root)
	var rig_mi := _mesh(rig_root)
	var t: Array = tex_mi.mesh.surface_get_arrays(0)
	var r: Array = rig_mi.mesh.surface_get_arrays(0)
	var rv: PackedVector3Array = r[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = r[Mesh.ARRAY_NORMAL]
	var rb: PackedInt32Array = r[Mesh.ARRAY_BONES]
	var rw: PackedFloat32Array = r[Mesh.ARRAY_WEIGHTS]
	var per := rb.size() / rv.size()

	# Hai lưới lệch gốc toạ độ: khớp tâm hộp bao.
	var offset := _center(rig_mi.get_aabb()) - _center(tex_mi.get_aabb())
	var grid := {}
	for i in rv.size():
		var k := Vector3i((rv[i] / CELL).floor())
		if not grid.has(k):
			grid[k] = PackedInt32Array()
		grid[k].append(i)

	var tv: PackedVector3Array = t[Mesh.ARRAY_VERTEX]
	var tn: PackedVector3Array = t[Mesh.ARRAY_NORMAL]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(tv.size() * 4)
	weights.resize(tv.size() * 4)
	for i in tv.size():
		var q := tv[i] + offset
		tv[i] = q
		var near := _nearest(q, tn[i], rv, rn, grid)
		var acc := {}
		for pair in near:
			var j: int = pair[1]
			var w: float = 1.0 / (pair[0] + 0.005)
			for s in per:
				var bw: float = rw[j * per + s]
				if bw > 0.0:
					acc[rb[j * per + s]] = acc.get(rb[j * per + s], 0.0) + bw * w
		var top: Array = acc.keys()
		top.sort_custom(func(a, b): return acc[a] > acc[b])
		top = top.slice(0, 4)
		var sum := 0.0
		for b in top:
			sum += float(acc[b])
		for s in 4:
			bones[i * 4 + s] = top[s] if s < top.size() else 0
			weights[i * 4 + s] = acc[top[s]] / sum if s < top.size() else 0.0

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tv
	arrays[Mesh.ARRAY_NORMAL] = tn
	arrays[Mesh.ARRAY_TANGENT] = t[Mesh.ARRAY_TANGENT]
	arrays[Mesh.ARRAY_TEX_UV] = t[Mesh.ARRAY_TEX_UV]
	arrays[Mesh.ARRAY_INDEX] = t[Mesh.ARRAY_INDEX]
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rig_mi.mesh = mesh
	# Chép riêng Skin để cảnh mới không trỏ vào bên trong file fbx. Vật liệu do FighterView gán
	# (ảnh màu, ảnh pháp tuyến khai trong config/models/tuong.tres).
	rig_mi.skin = rig_mi.skin.duplicate()

	# Bỏ hoạt cảnh có sẵn: game tự uốn xương.
	for n in rig_root.find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	rig_root.scene_file_path = ""
	for n in rig_root.find_children("*", "", true, false):
		n.owner = rig_root
	var packed := PackedScene.new()
	packed.pack(rig_root)
	var err := ResourceSaver.save(packed, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT, " verts=", tv.size(), " err=", err)
	tex_root.free()
	rig_root.free()
	quit()


## NEIGHBOURS đỉnh gần nhất cùng hướng: mảng [khoảng cách, chỉ số].
func _nearest(q: Vector3, n: Vector3, rv: PackedVector3Array, rn: PackedVector3Array, grid: Dictionary) -> Array:
	var c := Vector3i((q / CELL).floor())
	for reach in [1, 2, 4]:
		var found: Array = []
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				for dz in range(-reach, reach + 1):
					var k := c + Vector3i(dx, dy, dz)
					if grid.has(k):
						for j in grid[k]:
							if rn[j].dot(n) > 0.0:
								found.append([q.distance_to(rv[j]), j])
		if found.size() >= NEIGHBOURS:
			found.sort_custom(func(a, b): return a[0] < b[0])
			return found.slice(0, NEIGHBOURS)
	return []


func _center(b: AABB) -> Vector3:
	return b.position + b.size * 0.5


func _mesh(n: Node) -> MeshInstance3D:
	return n.find_children("*", "MeshInstance3D", true, false)[0]
