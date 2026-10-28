class_name Dir
extends RefCounted
## Bốn hướng đánh/đỡ, giống Mount & Blade.
## Với đòn chém: hướng là phía người chém kéo vũ khí về để lấy đà, theo hệ toạ độ của chính người chém.
## Với đỡ: hướng là phía đòn đến, theo hệ toạ độ của người đỡ.

const NONE := 0
const UP := 1
const THRUST := 2
const LEFT := 3
const RIGHT := 4

const NAMES := ["none", "up", "thrust", "left", "right"]


static func name_of(d: int) -> String:
	return NAMES[d] if d >= 0 and d < NAMES.size() else "?"


## Đổi vector trên màn hình (y hướng xuống) thành hướng: lên = UP, xuống = THRUST.
static func from_screen_vector(v: Vector2) -> int:
	if v == Vector2.ZERO:
		return NONE
	if absf(v.x) > absf(v.y):
		return RIGHT if v.x > 0.0 else LEFT
	return THRUST if v.y > 0.0 else UP


static func opposite_side(d: int) -> int:
	if d == LEFT:
		return RIGHT
	if d == RIGHT:
		return LEFT
	return d
