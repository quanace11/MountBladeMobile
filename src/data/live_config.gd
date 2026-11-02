class_name LiveConfig
extends Resource
## Luật chế độ TikTok LIVE: người xem chọn phe, tặng quà để ra lính, thả tim hồi máu cho người chơi.
## Chỉnh trong config/live.tres.

## Địa chỉ cầu nối (tools/tiktok_bridge) mặc định. Đổi được trong menu, ví dụ khi chơi trên điện thoại
## thì điền địa chỉ máy tính trong mạng nhà: ws://192.168.1.10:21213.
@export var bridge_url: String = "ws://127.0.0.1:21213"
## Thử kết nối lại cầu nối sau bao nhiêu giây khi mất kết nối.
@export var reconnect_seconds: float = 3.0

## Bình luận để vào phe Xanh (phe người chơi) và phe Đỏ. So sánh không phân biệt hoa thường, bỏ dấu cách.
@export var join_blue_words: PackedStringArray = ["1", "xanh"]
@export var join_red_words: PackedStringArray = ["2", "do", "đỏ"]
## Bình luận vào phe (không tặng quà) cũng được ra một lính yếu, xếp cuối hàng chờ.
@export var free_join_spawns: bool = true

## Số lính tối đa mỗi phe đứng trên sân cùng lúc. Người đến sau xếp hàng chờ.
@export var max_on_field: int = 3
## Quà từ chừng này xu trở lên thì ra trận ngay, không phải chờ chỗ trống...
@export var instant_coins: int = 10
## ...nhưng mỗi phe không bao giờ quá chừng này lính trên sân.
@export var hard_cap_on_field: int = 6

## Bậc lính theo số xu của quà: bậc i khi xu >= tier_min_coins[i] (lấy bậc cao nhất đạt được).
## Bình luận miễn phí tính là 0 xu.
@export var tier_min_coins: PackedInt32Array = [0, 10, 100]
@export var tier_names: PackedStringArray = ["Lính", "Lính tinh", "Tướng"]
## Máu của lính so với tướng gốc trong config/characters.
@export var tier_hp_mult: PackedFloat32Array = [0.45, 0.75, 1.0]
## Độ khôn của bot theo bậc, tên file trong config/ai.
@export var tier_bots: PackedStringArray = ["easy", "easy", "hard"]

## Thả tim hồi máu cho người chơi: cứ likes_per_heal tim thì hồi heal_per_step máu...
@export var likes_per_heal: int = 10
@export var heal_per_step: float = 3.0
## ...nhưng mỗi giây hồi tối đa chừng này máu, để LIVE đông người thả tim cũng không bất tử.
@export var max_heal_per_second: float = 4.0
## Máu chờ hồi tối đa được dồn lại (tim thả quá nhiều thì bỏ phần thừa).
@export var max_pending_heal: float = 40.0

## Máu tướng phe Đỏ so với tướng gốc. Hạ tướng Đỏ là phe Xanh thắng ván.
@export var red_general_hp_mult: float = 1.3
@export var red_general_bot: StringName = &"hard"
## Màu áo giáp và áo choàng từng phe để dễ nhìn trên LIVE.
@export var blue_color: Color = Color(0.12, 0.3, 0.75)
@export var red_color: Color = Color(0.7, 0.1, 0.08)

## Lính mới ra đứng cách giữa sân bao xa, ở phía của phe mình (mét).
@export var spawn_distance: float = 11.0
## Xác nằm lại bao lâu rồi dọn đi (giây).
@export var corpse_seconds: float = 5.0
## Hết ván: hiện bảng điểm bao lâu rồi sang ván mới (giây).
@export var round_restart_seconds: float = 8.0
