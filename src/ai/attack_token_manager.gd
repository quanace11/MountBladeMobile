class_name AttackTokenManager
extends RefCounted
## Phân lượt tấn công khi 1 vs nhiều: chỉ vài bot được ra đòn cùng lúc, số còn lại vây quanh chờ.

var max_holders: int = 1
var _holders: Array[int] = []


func _init(p_max: int) -> void:
	max_holders = maxi(1, p_max)


func has_token(id: int) -> bool:
	return _holders.has(id)


func request(id: int) -> bool:
	if _holders.has(id):
		return true
	if _holders.size() < max_holders:
		_holders.append(id)
		return true
	return false


func release(id: int) -> void:
	_holders.erase(id)


func is_full() -> bool:
	return _holders.size() >= max_holders
