class_name ArenaDef
extends Resource
## Đấu trường: texture, cảnh vật xung quanh. Số lượng cảnh vật nhân với scenery_density của preset đồ họa.

@export_group("Bầu trời và ánh sáng")
@export var sky_texture: Texture2D
@export var sky_energy: float = 1.0
@export var ambient_energy: float = 0.6
@export var sun_rotation_deg := Vector3(-42, -40, 0)
@export var sun_energy: float = 1.15
@export var sun_color := Color(1.0, 0.95, 0.86)

@export_group("Nền")
## Tiền tố bộ texture, ví dụ res://assets/textures/dry_ground_01 (sẽ nạp _diff, _nor, _rough).
@export var dirt_texture: String = ""
@export var grass_texture: String = ""
@export var grass_tint := Color(0.85, 0.95, 0.75)
@export var dirt_scale: float = 0.4
@export var grass_scale: float = 0.5
@export var ground_size: float = 260.0

@export_group("Hàng rào cọc")
@export var bark_texture: String = ""
@export var palisade_gap: float = 1.2
@export var log_radius: float = 0.17
@export var log_height_min: float = 2.6
@export var log_height_max: float = 3.2
## Cổng: góc (độ) và độ rộng (mét).
@export var gate_angle_deg: float = 90.0
@export var gate_width: float = 3.0

@export_group("Cảnh vật")
@export var wood_texture: String = ""
@export var roof_texture: String = ""
@export var wall_texture: String = ""
@export var stone_texture: String = ""
@export var rock_texture: String = ""
@export var house_count: int = 6
@export var tree_count: int = 24
@export var rock_count: int = 14
@export var banner_count: int = 6
@export var scenery_radius_min: float = 24.0
@export var scenery_radius_max: float = 48.0
@export var hill_radius_inner: float = 60.0
@export var hill_radius_outer: float = 140.0
@export var hill_height: float = 28.0
@export var seed: int = 7
