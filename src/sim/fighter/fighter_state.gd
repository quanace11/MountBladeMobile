class_name FighterState
extends RefCounted
## Trạng thái một tướng trong sim. Chỉ là dữ liệu, không có Node.

enum State { IDLE, WINDUP, RELEASE, RECOVERY, BLOCK, STAGGER, DEAD, DODGE }

var id: int = 0
var team: int = 0
var def: CharacterDef
## Vị trí trên mặt đất: x là trục X, y là trục Z của thế giới 3D.
var pos: Vector2 = Vector2.ZERO
## Góc quay quanh trục Y, cùng quy ước rotation.y của Godot.
var yaw: float = 0.0
var hp: float = 0.0
var stamina: float = 0.0
var state: int = State.IDLE
## Số tick đã ở trạng thái hiện tại.
var state_ticks: int = 0
## Số tick trạng thái hiện tại kéo dài (dùng cho STAGGER, RECOVERY).
var state_duration: int = 0
var attack_dir: int = Dir.NONE
var release_queued: bool = false
var block_dir: int = Dir.NONE
var block_started_tick: int = -1000
## Lệnh chém nhả lúc đang bận, chờ chém khi rảnh (NONE = không có) và tick hết hạn.
var buffered_attack_dir: int = Dir.NONE
var buffered_until: int = -1
## Hướng lăn né (độ dài 1) khi ở trạng thái DODGE.
var dodge_dir: Vector2 = Vector2.ZERO
## Đang khựng vì đòn mình bị đỡ (vũ khí bị dội lại), khác với khựng vì bị trúng đòn.
var recoil: bool = false
## Tick còn lại trước khi thể lực bắt đầu hồi.
var stamina_wait: int = 0
## Vận tốc tick vừa rồi, view dùng để chọn dáng chạy.
var velocity: Vector2 = Vector2.ZERO


func is_alive() -> bool:
	return state != State.DEAD


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


static func yaw_from_direction(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


func set_state(s: int, duration: int = 0) -> void:
	state = s
	state_ticks = 0
	state_duration = duration
	recoil = false


func to_dict() -> Dictionary:
	return {
		"id": id, "team": team, "def": def.resource_path if def else "",
		"pos": [pos.x, pos.y], "yaw": yaw, "hp": hp, "st": stamina,
		"state": state, "sticks": state_ticks, "sdur": state_duration,
		"adir": attack_dir, "rq": release_queued, "bdir": block_dir,
		"bstart": block_started_tick, "swait": stamina_wait, "rc": recoil,
		"bad": buffered_attack_dir, "bu": buffered_until, "dd": [dodge_dir.x, dodge_dir.y],
		"vel": [velocity.x, velocity.y],
	}


static func from_dict(d: Dictionary) -> FighterState:
	var f := FighterState.new()
	f.id = int(d["id"])
	f.team = int(d["team"])
	if String(d["def"]) != "":
		f.def = load(String(d["def"])) as CharacterDef
	f.pos = Vector2(d["pos"][0], d["pos"][1])
	f.yaw = float(d["yaw"])
	f.hp = float(d["hp"])
	f.stamina = float(d["st"])
	f.state = int(d["state"])
	f.state_ticks = int(d["sticks"])
	f.state_duration = int(d["sdur"])
	f.attack_dir = int(d["adir"])
	f.release_queued = bool(d["rq"])
	f.block_dir = int(d["bdir"])
	f.block_started_tick = int(d["bstart"])
	f.stamina_wait = int(d["swait"])
	f.recoil = bool(d.get("rc", false))
	f.buffered_attack_dir = int(d.get("bad", Dir.NONE))
	f.buffered_until = int(d.get("bu", -1))
	var dd: Array = d.get("dd", [0.0, 0.0])
	f.dodge_dir = Vector2(dd[0], dd[1])
	f.velocity = Vector2(d["vel"][0], d["vel"][1])
	return f
