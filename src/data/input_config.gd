class_name InputConfig
extends Resource
## Bố cục và ngưỡng điều khiển cảm ứng.

enum BlockScheme { BUTTON, CHEVRON }

@export var block_scheme: BlockScheme = BlockScheme.BUTTON
## Bán kính joystick di chuyển (px theo độ phân giải thiết kế 1280x720).
@export var joystick_radius: float = 110.0
## Vùng chết của joystick (0..1).
@export var joystick_deadzone: float = 0.15
## Phần màn hình bên trái dành cho joystick (0..1).
@export var left_zone_ratio: float = 0.45
## Kéo tối thiểu bao nhiêu px thì nhận là có hướng.
@export var swipe_min_distance: float = 40.0
## Nét gấp: góc rẽ tối thiểu (độ) để nhận là gấp khúc.
@export var chevron_min_turn_deg: float = 70.0
## Nét gấp: đoạn sau góc rẽ tối thiểu bao nhiêu px.
@export var chevron_min_second_leg: float = 30.0
## Nút ĐỠ: tâm theo tỉ lệ màn hình, bán kính px.
@export var block_button_center: Vector2 = Vector2(0.69, 0.83)
@export var block_button_radius: float = 75.0
## Nút CHÉM (sát góc phải dưới): giữ và kéo về hướng muốn chém, nhả để chém. Bấm không kéo là bổ.
## Đặt cách mép đủ xa để còn chỗ kéo về mọi hướng.
@export var attack_button_center: Vector2 = Vector2(0.885, 0.74)
@export var attack_button_radius: float = 85.0
## Mũi tên báo hướng đòn của địch. Mặc định tắt: người chơi đọc hướng từ động tác gồng.
@export var show_attack_hint: bool = false
## Tự ngắm với kiểu chém bằng vuốt: nửa phải, phần phía trên tỉ lệ này (0..1) là vùng kéo
## để xoay người/camera; phần dưới là vùng vuốt chém. Kiểu nút CHÉM: mọi chỗ trống bên phải đều kéo xoay được.
@export var look_zone_bottom_ratio: float = 0.5
## Độ nhạy xoay: độ quay được cho mỗi px kéo ngang (theo độ phân giải thiết kế 1280x720).
@export var look_sensitivity_deg: float = 0.3
## Tốc độ xoay bằng phím Q/E trên PC (độ/giây).
@export var key_turn_speed_deg: float = 160.0
## Phần trên cùng màn hình dành cho nút menu, không nhận điều khiển (0..1).
@export var ignore_top_ratio: float = 0.13
