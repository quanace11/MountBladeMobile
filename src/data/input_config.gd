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
@export var block_button_center: Vector2 = Vector2(0.62, 0.78)
@export var block_button_radius: float = 80.0
## Nút CHÉM (kiểu nút): giữ rồi kéo để gồng theo hướng kéo, nhả để chém. Tâm theo tỉ lệ màn hình, bán kính px.
@export var attack_button_center: Vector2 = Vector2(0.86, 0.7)
@export var attack_button_radius: float = 95.0
## Vùng nhận chạm của nút lớn hơn hình vẽ một chút để ngón cái dễ trúng.
@export var button_touch_slack: float = 1.25
## Chạm nhanh nút CHÉM (không kéo) thì chém theo hướng này.
@export_enum("none", "up", "thrust", "left", "right") var attack_tap_dir: int = 4
## Mũi tên báo hướng đòn của địch. Mặc định tắt: người chơi đọc hướng từ động tác gồng.
@export var show_attack_hint: bool = false
## Phần trên cùng màn hình dành cho nút menu, không nhận điều khiển (0..1).
@export var ignore_top_ratio: float = 0.13
