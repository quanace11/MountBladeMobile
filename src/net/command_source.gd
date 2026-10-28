class_name CommandSource
extends RefCounted
## Nguồn lệnh cho một tướng. Hiện có người chơi (cảm ứng + bàn phím) và bot.
## Khi làm PvP chỉ cần thêm NetCommandSource nhận lệnh từ mạng.

var fighter_id: int = 0


## Gọi mỗi tick sim, trước MatchSim.step.
func get_command(_state: MatchState) -> FighterCommand:
	return FighterCommand.new()
