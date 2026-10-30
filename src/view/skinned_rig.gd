class_name SkinnedRig
extends RefCounted
## Uốn xương của một model có khung xương chuẩn UE5 (pelvis, spine_0x, upperarm_r, thigh_l...)
## theo các khớp mà FighterView đã tính (tay cầm vũ khí, bước chân, xoay thân).
## Model không cần có sẵn hoạt cảnh: mỗi khung đặt lại tư thế gốc rồi xoay từng xương cho trúng khớp.
## Toạ độ "thân" là toạ độ của FighterView._body: x phải, y lên, -z trước, người cao 1,8 m.

var skel: Skeleton3D
## Đổi từ toạ độ thân sang toạ độ khung xương và ngược lại.
var to_skel: Transform3D
var to_body: Transform3D
## Model quay mặt về +z, game quay mặt về -z: xoay 180 độ quanh trục đứng.
var _flip := Basis(Vector3.UP, PI)

var _pelvis: int
var _spine: Array[int] = []
var _head: int
var _arm := {}  # side -> [upperarm, lowerarm, hand]
var _leg := {}  # side -> [thigh, calf, foot]
var _len := {}  # bone -> độ dài tới xương con, theo toạ độ khung xương


## model_height: chiều cao model trong file (đơn vị của file). Model được phóng cho cao 1,8 m.
func setup(model: Node3D, model_height: float) -> bool:
	skel = _find_skeleton(model)
	if skel == null:
		return false
	var s := 1.8 / maxf(0.01, model_height)
	to_body = Transform3D(_flip.scaled(Vector3.ONE * s), Vector3.ZERO)
	to_skel = to_body.affine_inverse()
	_pelvis = skel.find_bone("pelvis")
	for n in ["spine_02", "spine_03", "spine_04"]:
		var b := skel.find_bone(n)
		if b >= 0:
			_spine.append(b)
	_head = skel.find_bone("head")
	# Bên phải của nhân vật là side 1, bên trái là -1 (giống FighterView).
	for side in [1, -1]:
		var suf := "_r" if side == 1 else "_l"
		_arm[side] = [skel.find_bone("upperarm" + suf), skel.find_bone("lowerarm" + suf), skel.find_bone("hand" + suf)]
		_leg[side] = [skel.find_bone("thigh" + suf), skel.find_bone("calf" + suf), skel.find_bone("foot" + suf)]
	for chain in _arm.values() + _leg.values():
		if chain.has(-1):
			return false
		_len[chain[0]] = _rest_origin(chain[0]).distance_to(_rest_origin(chain[1]))
		_len[chain[1]] = _rest_origin(chain[1]).distance_to(_rest_origin(chain[2]))
	return _pelvis >= 0


## Một khung hình. Mọi vị trí theo toạ độ thân.
## pelvis_drop: hông hạ thấp bao nhiêu (mét); pelvis_yaw: hông xoay theo bước chân (radian).
## chest: (ngả, xoay) của thân trên; head: góc đầu bù lại.
## hands/feet: side -> vị trí cổ tay/cổ chân mong muốn, hoặc null để giữ nguyên.
## poles: side -> hướng khuỷu tay/đầu gối nên chĩa về (toạ độ thân).
func pose(pelvis_drop: float, pelvis_yaw: float, chest: Vector3, head: Vector3,
		hands: Dictionary, hand_poles: Dictionary, feet: Dictionary, knee_poles: Dictionary) -> void:
	skel.reset_bone_poses()
	var yaw := Basis(Vector3.UP, pelvis_yaw)
	skel.set_bone_pose_position(_pelvis, skel.get_bone_pose_position(_pelvis) + _parent_basis(_pelvis).inverse() * (to_skel.basis * Vector3(0, -pelvis_drop, 0)))
	_rotate_global(_pelvis, yaw)
	var per := _body_rot(Basis.from_euler(chest / maxf(1.0, _spine.size())))
	for b in _spine:
		_rotate_global(b, per)
	if _head >= 0:
		_rotate_global(_head, _body_rot(Basis.from_euler(head)))

	for side in hands:
		if hands[side] != null:
			_limb(_arm[side], to_skel * (hands[side] as Vector3), to_skel.basis * (hand_poles[side] as Vector3), false)
	for side in feet:
		if feet[side] != null:
			_limb(_leg[side], to_skel * (feet[side] as Vector3), to_skel.basis * (knee_poles[side] as Vector3), true)


## Vị trí một xương theo toạ độ thân (dùng để biết vai, hông đang ở đâu).
func bone_position(side: int, arm: bool) -> Vector3:
	var chain: Array = _arm[side] if arm else _leg[side]
	return to_body * skel.get_bone_global_pose(chain[0]).origin


func _limb(chain: Array, target: Vector3, pole: Vector3, keep_end_flat: bool) -> void:
	var a: int = chain[0]
	var b: int = chain[1]
	var end: int = chain[2]
	var end_rest := _global(end).basis
	var root := _global(a).origin
	var mid := FighterView._ik(root, target, _len[a], _len[b], pole)
	_aim(a, b, mid)
	_aim(b, end, target)
	if keep_end_flat:
		# Bàn chân giữ hướng như lúc đứng, không nghiêng theo ống chân.
		_set_global_basis(end, end_rest)


## Xoay xương sao cho xương con của nó nằm trên đường tới target.
func _aim(bone: int, child: int, target: Vector3) -> void:
	var g := _global(bone)
	var cur := _global(child).origin - g.origin
	var want := target - g.origin
	if cur.length() < 0.0001 or want.length() < 0.0001:
		return
	_set_global_basis(bone, Basis(Quaternion(cur.normalized(), want.normalized())) * g.basis)


func _rotate_global(bone: int, r: Basis) -> void:
	_set_global_basis(bone, r * _global(bone).basis)


func _set_global_basis(bone: int, basis: Basis) -> void:
	var local := _parent_basis(bone).inverse() * basis.orthonormalized()
	skel.set_bone_pose_rotation(bone, local.get_rotation_quaternion())


func _global(bone: int) -> Transform3D:
	return skel.get_bone_global_pose(bone)


func _parent_basis(bone: int) -> Basis:
	var p := skel.get_bone_parent(bone)
	return _global(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY


func _rest_origin(bone: int) -> Vector3:
	return skel.get_bone_global_rest(bone).origin


## Đổi một phép xoay theo trục của thân sang trục của khung xương.
func _body_rot(r: Basis) -> Basis:
	return _flip.inverse() * r * _flip


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null
