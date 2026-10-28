class_name MatchState
extends RefCounted
## Toàn bộ trạng thái một trận. Chụp và khôi phục được (cho replay và PvP sau này).

var tick: int = 0
var fighters: Array[FighterState] = []
var finished: bool = false
var winner_team: int = -1


func get_fighter(id: int) -> FighterState:
	for f in fighters:
		if f.id == id:
			return f
	return null


func alive_teams() -> Array[int]:
	var teams: Array[int] = []
	for f in fighters:
		if f.is_alive() and not teams.has(f.team):
			teams.append(f.team)
	return teams


func to_dict() -> Dictionary:
	var list := []
	for f in fighters:
		list.append(f.to_dict())
	return {"tick": tick, "fighters": list, "finished": finished, "winner": winner_team}


static func from_dict(d: Dictionary) -> MatchState:
	var s := MatchState.new()
	s.tick = int(d["tick"])
	for fd in d["fighters"]:
		s.fighters.append(FighterState.from_dict(fd))
	s.finished = bool(d["finished"])
	s.winner_team = int(d["winner"])
	return s
