class_name PoseSet
extends Resource
## Tư thế tay cầm vũ khí của nhân vật vẽ tạm. Chỉ ảnh hưởng hình ảnh, không ảnh hưởng logic.
## Mỗi tư thế gồm vị trí bàn tay (mét, theo thân: x phải, y lên, -z trước)
## và góc vũ khí (độ, Euler). Vũ khí mặc định dựng thẳng theo trục +y từ bàn tay.

@export_group("Đứng")
@export var idle_pos := Vector3(0.32, 1.0, -0.3)
@export var idle_rot := Vector3(-30, 0, 0)
@export_group("Gồng")
@export var windup_up_pos := Vector3(0.15, 1.75, 0.1)
@export var windup_up_rot := Vector3(50, 0, 0)
@export var windup_left_pos := Vector3(-0.35, 1.35, 0.05)
@export var windup_left_rot := Vector3(-90, 110, 0)
@export var windup_right_pos := Vector3(0.45, 1.35, 0.05)
@export var windup_right_rot := Vector3(-90, -110, 0)
@export var windup_thrust_pos := Vector3(0.42, 1.05, 0.3)
@export var windup_thrust_rot := Vector3(-82, -5, 0)
@export_group("Chém")
@export var strike_up_pos := Vector3(0.1, 1.1, -0.55)
@export var strike_up_rot := Vector3(-75, 0, 0)
@export var strike_left_pos := Vector3(0.35, 1.2, -0.4)
@export var strike_left_rot := Vector3(-90, -60, 0)
@export var strike_right_pos := Vector3(-0.3, 1.2, -0.4)
@export var strike_right_rot := Vector3(-90, 60, 0)
@export var strike_thrust_pos := Vector3(0.2, 1.25, -0.7)
@export var strike_thrust_rot := Vector3(-88, 8, 0)
@export_group("Đỡ")
@export var block_up_pos := Vector3(0.45, 1.85, -0.35)
@export var block_up_rot := Vector3(0, 0, 90)
@export var block_left_pos := Vector3(-0.35, 1.1, -0.4)
@export var block_left_rot := Vector3(10, 0, 0)
@export var block_right_pos := Vector3(0.45, 1.1, -0.4)
@export var block_right_rot := Vector3(10, 0, 0)
@export var block_thrust_pos := Vector3(0.4, 1.05, -0.45)
@export var block_thrust_rot := Vector3(0, 0, 80)
@export_group("Khác")
@export var stagger_pos := Vector3(0.4, 1.1, 0.2)
@export var stagger_rot := Vector3(30, 0, -30)
## Tốc độ chuyển tư thế (càng lớn càng nhanh).
@export var blend_speed: float = 12.0
## Hệ số nhân tốc độ chuyển tư thế khi đang chém.
@export var strike_blend_mult: float = 3.0
## Thân trên xoay theo hướng gồng/chém (độ).
@export var chest_twist_deg: float = 24.0
## Thân trên ngả trước/sau khi bổ, khi bị khựng (độ).
@export var chest_lean_deg: float = 10.0
## Tay trái: tư thế khi cầm khiên (đứng, đỡ). Vị trí theo thân như bàn tay phải.
@export var shield_idle_pos := Vector3(-0.28, 1.12, -0.32)
@export var shield_block_pos := Vector3(-0.12, 1.38, -0.45)
## Tay trái cầm cán vũ khí hai tay: cách tay phải bao xa dọc cán (mét).
@export var two_hand_grip: float = 0.4
## Độ dài một sải chân (mét) và độ nhấc chân khi chạy.
@export var stride_length: float = 1.2
@export var foot_lift: float = 0.12
## Thời gian ngã khi chết (giây).
@export var death_fall_time: float = 0.6


## Trả về [vị trí, góc] cho tên tư thế, ví dụ "windup_left".
func get_pose(pose_name: String) -> Array:
	return [get(pose_name + "_pos"), get(pose_name + "_rot")]


static func pose_name(prefix: String, dir: int) -> String:
	match dir:
		Dir.UP: return prefix + "_up"
		Dir.LEFT: return prefix + "_left"
		Dir.RIGHT: return prefix + "_right"
		Dir.THRUST: return prefix + "_thrust"
	return "idle"
