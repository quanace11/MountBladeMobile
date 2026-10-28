class_name SimContext
extends RefCounted
## Số liệu sim dùng chung trong một trận, đổi giây sang tick.

var rules: CombatRules
var config: GameConfig
var tick_rate: int = 30
var dt: float = 1.0 / 30.0


func _init(p_config: GameConfig, p_rules: CombatRules) -> void:
	config = p_config
	rules = p_rules
	tick_rate = maxi(1, p_config.tick_rate)
	dt = 1.0 / float(tick_rate)


## Đổi giây sang số tick, tối thiểu 1.
func ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * tick_rate))
