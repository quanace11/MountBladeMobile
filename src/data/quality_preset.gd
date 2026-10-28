class_name QualityPreset
extends Resource
## Preset đồ họa. Game tự hạ độ phân giải 3D khi fps tụt.

@export var id: StringName = &""
@export var display_name: String = ""
@export var target_fps: int = 60
## Độ phân giải 3D ban đầu (1.0 = đầy đủ).
@export var render_scale: float = 1.0
@export var min_render_scale: float = 0.6
## Bước hạ hoặc tăng độ phân giải mỗi lần điều chỉnh.
@export var render_scale_step: float = 0.05
@export var shadows_enabled: bool = true
@export var shadow_max_distance: float = 25.0
## Số cọc rào quanh đấu trường (vẽ bằng MultiMesh).
@export var arena_props: int = 48
@export var max_vfx: int = 12
