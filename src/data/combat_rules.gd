class_name CombatRules
extends Resource
## Luật chung của đánh và đỡ.

## Nửa góc phía trước mà người đỡ có thể chặn (độ). Đòn từ ngoài vùng này không đỡ được.
@export var block_half_angle_deg: float = 70.0
## Bắt đầu đỡ đúng hướng trong khoảng này trước lúc trúng thì là đỡ hoàn hảo.
@export var parry_window: float = 0.15
## Người chém bị khựng khi đòn bị đỡ thường.
@export var stagger_on_blocked: float = 0.35
## Người chém bị khựng khi bị đỡ hoàn hảo.
@export var stagger_on_parried: float = 0.8
## Người trúng đòn bị choáng, mất đòn đang gồng.
@export var hit_stun: float = 0.4
## Thể lực người đỡ mất = sát thương đòn × hệ số này.
@export var block_stamina_per_damage: float = 0.6
## Hết thể lực khi đỡ thì bị phá thế, khựng lâu.
@export var guard_break_stun: float = 1.0
## Đỡ hoàn hảo không tốn thể lực.
@export var parry_costs_stamina: bool = false
## Hệ số tốc độ di chuyển khi gồng, khi đỡ.
@export var move_mult_windup: float = 0.6
@export var move_mult_block: float = 0.5
## Hệ số tốc độ xoay người khi đang gồng hoặc đang chém.
@export var turn_mult_attack: float = 0.5
## Được hủy gồng để chuyển sang đỡ (như Mount & Blade).
@export var allow_windup_cancel_to_block: bool = true
## Thể lực bắt đầu hồi sau khi dùng (giây).
@export var stamina_regen_delay: float = 0.8
