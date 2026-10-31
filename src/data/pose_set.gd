class_name PoseSet
extends Resource
## Tư thế tay cầm vũ khí. Chỉ ảnh hưởng hình ảnh, không ảnh hưởng logic.
## Mỗi tư thế gồm vị trí bàn tay phải (mét, theo thân: x phải, y lên, -z trước)
## và góc vũ khí (độ, Euler YXZ). Vũ khí dựng theo trục +y từ bàn tay (phía lưỡi), lưỡi sắc quay về -x.
## Tay trái tự nắm chỗ cán gần vai trái nhất, nên cả hai tay luôn ở trên cán.
## Các góc được tính từ hướng lưỡi và hướng lưỡi sắc cho tiện chỉnh: gồng ngang thì lưỡi chĩa ra sau
## vai, chém xong lưỡi ở trước mặt phía bên kia; bổ thì lưỡi từ sau đầu vung qua đỉnh xuống trước mặt.

@export_group("Đứng")
@export var idle_pos := Vector3(0.22, 1.0, -0.12)
@export var idle_rot := Vector3(27, -90, 48)
@export_group("Gồng")
@export var windup_up_pos := Vector3(0.12, 1.62, 0.0)
@export var windup_up_rot := Vector3(0, -97, -60)
@export var windup_left_pos := Vector3(-0.12, 1.55, 0.05)
@export var windup_left_rot := Vector3(-38, 180, -27)
@export var windup_right_pos := Vector3(0.3, 1.5, 0.0)
@export var windup_right_rot := Vector3(40, 0, -30)
@export var windup_thrust_pos := Vector3(0.28, 1.12, 0.25)
@export var windup_thrust_rot := Vector3(0, -81, 81)
@export_group("Chém")
@export var strike_up_pos := Vector3(0.15, 1.15, -0.35)
@export var strike_up_rot := Vector3(0, -90, 110)
@export var strike_left_pos := Vector3(0.4, 1.2, -0.4)
@export var strike_left_rot := Vector3(81, -180, 49)
@export var strike_right_pos := Vector3(-0.05, 1.25, -0.45)
@export var strike_right_rot := Vector3(-81, 0, 49)
@export var strike_thrust_pos := Vector3(0.18, 1.25, -0.45)
@export var strike_thrust_rot := Vector3(0, -85, 87)
@export_group("Đỡ")
@export var block_up_pos := Vector3(0.3, 1.78, -0.3)
@export var block_up_rot := Vector3(0, 180, -87)
@export var block_left_pos := Vector3(-0.22, 1.42, -0.36)
@export var block_left_rot := Vector3(0, -90, 0)
@export var block_right_pos := Vector3(0.52, 1.38, -0.32)
@export var block_right_rot := Vector3(0, -90, 0)
@export var block_thrust_pos := Vector3(0.25, 1.0, -0.4)
@export var block_thrust_rot := Vector3(72, -90, 6)
@export_group("Khác")
@export var stagger_pos := Vector3(0.35, 1.1, 0.15)
@export var stagger_rot := Vector3(-13, -90, -18)
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
## Tay trái cầm cán vũ khí hai tay: cách tay phải ít nhất và nhiều nhất bao xa dọc cán (mét).
@export var two_hand_grip_min: float = 0.2
@export var two_hand_grip: float = 0.6
## Bước chân như người: chân chạm đất thì đứng yên trên đất (lùi lại đúng bằng tốc độ thân), chân nhấc
## thì vung lên phía trước theo vòng cung. Bàn chân đặt gót trước, nhón mũi khi rời đất.
## Đi bộ: chân chạm đất lâu (walk_duty phần chu kỳ), bước ngắn. Chạy: chạm đất ngắn, có lúc cả hai chân
## rời đất, bước dài, người đổ về trước, gối chùng hơn.
## Chân xa nhất trước/sau hông khi đi và khi chạy (mét).
@export var walk_foot_reach: float = 0.36
@export var run_foot_reach: float = 0.5
@export var walk_duty: float = 0.62
@export var run_duty: float = 0.38
## Tốc độ (m/s) coi là đi bộ hẳn và chạy hẳn; ở giữa thì pha trộn.
@export var walk_speed: float = 1.5
@export var run_speed: float = 4.0
## Độ nhấc chân khi đi và khi chạy (mét).
@export var foot_lift: float = 0.1
@export var run_foot_lift: float = 0.2
## Người đổ về trước khi chạy hết tốc (độ), hông hạ thấp khi chạy (mét).
@export var run_lean_deg: float = 9.0
@export var run_crouch: float = 0.05
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
