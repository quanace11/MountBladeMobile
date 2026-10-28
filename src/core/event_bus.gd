extends Node
## Kênh sự kiện toàn cục. Sim tạo sự kiện, MatchRunner phát ra đây; hình ảnh, âm thanh, UI lắng nghe.

## Mọi sự kiện của sim, dạng Dictionary có khóa "type".
signal sim_event(e: Dictionary)
signal match_started(runner: Node)
signal match_over(winner_team: int)
