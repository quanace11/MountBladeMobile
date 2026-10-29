class_name FighterCommand
extends RefCounted
## Lệnh một tướng gửi vào sim mỗi tick. Người chơi, bot và mạng đều tạo ra lệnh này.

## Hướng muốn đi trong thế giới (độ dài 0..1), trục x và z.
var move: Vector2 = Vector2.ZERO
## Hướng đang gồng (Dir). NONE = không gồng.
var attack_dir: int = Dir.NONE
## true ở tick người chơi nhả tay để chém.
var attack_release: bool = false
## Hướng đỡ (Dir). NONE = không đỡ.
var block_dir: int = Dir.NONE
## Người chơi tự ngắm: true thì tướng quay mặt về face_yaw thay vì tự nhìn địch gần nhất.
var has_face: bool = false
## Góc muốn quay mặt tới (cùng quy ước FighterState.yaw).
var face_yaw: float = 0.0


func to_dict() -> Dictionary:
	return {"m": [move.x, move.y], "a": attack_dir, "r": attack_release, "b": block_dir, "hf": has_face, "fy": face_yaw}


static func from_dict(d: Dictionary) -> FighterCommand:
	var c := FighterCommand.new()
	c.move = Vector2(d["m"][0], d["m"][1])
	c.attack_dir = int(d["a"])
	c.attack_release = bool(d["r"])
	c.block_dir = int(d["b"])
	c.has_face = bool(d.get("hf", false))
	c.face_yaw = float(d.get("fy", 0.0))
	return c
