class_name GameConfig
extends Resource
## Cấu hình chung của trận đấu.

## Số tick logic mỗi giây.
@export var tick_rate: int = 30
## Số bot được tấn công cùng lúc khi 1 vs nhiều.
@export var max_attackers_at_once: int = 1
@export var arena_radius: float = 14.0
## Khoảng cách xuất phát giữa người chơi và địch.
@export var spawn_distance: float = 6.0
## Khoảng nhìn để tự quay mặt về phía địch gần nhất.
@export var auto_face_range: float = 12.0
## Seed ngẫu nhiên (0 = ngẫu nhiên theo thời gian).
@export var rng_seed: int = 0
@export var camera_distance: float = 3.4
@export var camera_height: float = 2.1
@export var camera_shoulder_offset: float = 0.55
@export var camera_follow_speed: float = 8.0
@export var camera_shake_hit: float = 0.12
@export var camera_shake_block: float = 0.05
