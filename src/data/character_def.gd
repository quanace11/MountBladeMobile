class_name CharacterDef
extends Resource
## Thông số một vị tướng.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
## Thể lực hồi mỗi giây khi không đánh, không đỡ.
@export var stamina_regen: float = 18.0
## Tốc độ chạy (mét/giây).
@export var move_speed: float = 3.2
## Tốc độ xoay người (độ/giây).
@export var turn_speed_deg: float = 360.0
## Bán kính thân dùng để đẩy nhau ra.
@export var body_radius: float = 0.4
@export var weapon: WeaponDef
## Màu áo giáp và mũ khi vẽ tạm bằng khối hình.
@export var armor_color: Color = Color(0.6, 0.15, 0.1)
@export var cloth_color: Color = Color(0.15, 0.15, 0.15)
@export var skin_color: Color = Color(0.85, 0.66, 0.5)
@export var height: float = 1.8
