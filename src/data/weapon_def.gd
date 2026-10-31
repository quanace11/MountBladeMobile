class_name WeaponDef
extends Resource
## Thông số một loại vũ khí. Mọi thời gian tính bằng giây, sim tự đổi sang tick.

@export var id: StringName = &""
@export var display_name: String = ""
## Tầm đánh tính từ tâm người cầm (mét).
@export var reach: float = 1.6
## Nửa góc cung chém phía trước (độ). Địch nằm ngoài cung thì không trúng.
@export var arc_half_angle_deg: float = 50.0
## Thời gian gồng tối thiểu trước khi được chém.
@export var windup_time: float = 0.4
## Thời gian từ lúc nhả tới lúc lưỡi vũ khí chạm (lúc xét trúng).
@export var release_time: float = 0.15
## Thời gian thu vũ khí sau khi chém.
@export var recovery_time: float = 0.35
@export var damage_left: float = 22.0
@export var damage_right: float = 22.0
@export var damage_up: float = 26.0
@export var damage_thrust: float = 20.0
## Thể lực mất mỗi lần chém.
@export var attack_stamina_cost: float = 12.0
## Có khiên: giơ khiên đỡ được mọi hướng phía trước, giống Mount & Blade.
@export var has_shield: bool = false
## Màu lưỡi và cán khi vẽ tạm bằng khối hình.
@export var blade_color: Color = Color(0.8, 0.8, 0.85)
@export var shaft_color: Color = Color(0.35, 0.22, 0.12)
## Kích thước phần hiển thị (mét).
@export var shaft_length: float = 1.2
@export var blade_length: float = 0.6
@export var blade_width: float = 0.08
## Kiểu dáng riêng khi vẽ: &"thanh_long" (Thanh Long Yển Nguyệt Đao), &"xa_mau" (Trượng Bát Xà Mâu),
## để trống thì vẽ kiếm / đao / giáo thường theo kích thước.
@export var style: StringName = &""


func damage_for(dir: int) -> float:
	match dir:
		Dir.LEFT: return damage_left
		Dir.RIGHT: return damage_right
		Dir.UP: return damage_up
		Dir.THRUST: return damage_thrust
	return 0.0
