class_name BotProfile
extends Resource
## Độ khôn của bot. Bot dễ: phản xạ chậm, hay đỡ sai. Bot khó: ngược lại.

@export var id: StringName = &""
@export var display_name: String = ""
## Bot suy nghĩ bao nhiêu lần mỗi giây.
@export var think_hz: float = 10.0
## Thời gian từ lúc thấy đối thủ gồng tới lúc bot giơ thế đỡ (giây).
@export var reaction_time: float = 0.35
## Ngẫu nhiên thêm vào thời gian phản xạ (giây).
@export var reaction_jitter: float = 0.15
## Xác suất đỡ sai hướng.
@export var wrong_block_chance: float = 0.4
## Xác suất quên không đỡ.
@export var no_block_chance: float = 0.2
## Xác suất cố tình chờ đến sát lúc trúng mới đỡ (để đỡ hoàn hảo).
@export var parry_attempt_chance: float = 0.0
## Thời gian giữ gồng trước khi nhả, ngẫu nhiên trong khoảng này (giây).
@export var hold_windup_min: float = 0.0
@export var hold_windup_max: float = 0.3
## Nghỉ giữa hai lần tấn công (giây).
@export var attack_cooldown_min: float = 1.2
@export var attack_cooldown_max: float = 2.5
## Khoảng cách muốn đứng, tính theo tầm vũ khí.
@export var preferred_range_factor: float = 0.85
## Bot không tấn công khi thể lực dưới mức này.
@export var min_stamina_to_attack: float = 20.0
## Kiểu Mount & Blade: thấy đối thủ đang giơ đỡ thì chém vào phía không đỡ, với xác suất này.
@export var read_block_chance: float = 0.5
## Thấy đối thủ vừa chém hụt, vừa bị khựng (đang hở) mà mình trong tầm thì chém ngay, bỏ qua lúc nghỉ.
@export var punish_chance: float = 0.5
## Chém xong thì lùi lại giữ khoảng cách trong bao lâu (giây).
@export var retreat_after_attack: float = 0.5
## Thấy đối thủ gồng thì lùi ra khỏi tầm thay vì đỡ, với xác suất này.
@export var step_back_chance: float = 0.1
## Xác suất bot đổi hướng ngay khi đang gồng (đánh lừa).
@export var feint_chance: float = 0.0
