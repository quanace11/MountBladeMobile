extends Node
## Autoload "Live": giữ kết nối tới cầu nối TikTok LIVE (tools/tiktok_bridge) và hàng chờ người xem
## qua các ván. Cầu nối gửi mỗi sự kiện một dòng JSON:
##   {"type": "comment", "user": "abc", "nick": "Tên", "text": "1"}
##   {"type": "gift", "user": "abc", "nick": "Tên", "gift": "Rose", "coins": 1}
##   {"type": "like", "user": "abc", "nick": "Tên", "count": 15}
##   {"type": "status", "text": "Đã vào LIVE của @abc"}

## Một dòng báo cho người xem thấy trên màn hình (ai vào phe nào, ai tặng gì).
signal feed(text: String, color: Color)

const BLUE_TEXT := Color(0.55, 0.75, 1.0)
const RED_TEXT := Color(1.0, 0.55, 0.5)

var queue: LiveQueue
var url: String = ""
## Trạng thái kết nối hiện lên HUD.
var status: String = "Chưa kết nối"
## Dòng trạng thái cầu nối gửi về (đã vào LIVE chưa, lỗi gì).
var bridge_status: String = ""
var _ws: WebSocketPeer
var _active := false
var _retry_in := 0.0


func _ready() -> void:
	queue = LiveQueue.new(ConfigDB.live)
	url = ConfigDB.live.bridge_url


## Bắt đầu nối tới cầu nối (gọi khi vào chế độ LIVE). Gọi lại khi đang nối thì không làm gì.
func start() -> void:
	_active = true
	if _ws == null:
		_connect()


func stop() -> void:
	_active = false
	if _ws:
		_ws.close()
	_ws = null
	status = "Chưa kết nối"


func is_connected_to_bridge() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _connect() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		status = "Không mở được %s" % url
		_retry_in = ConfigDB.live.reconnect_seconds
		return
	status = "Đang nối %s..." % url


func _process(delta: float) -> void:
	if not _active:
		return
	if _ws == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			status = "Đã nối cầu nối"
			while _ws.get_available_packet_count() > 0:
				var msg := _ws.get_packet().get_string_from_utf8()
				for line in msg.split("\n", false):
					var data = JSON.parse_string(line)
					if data is Dictionary:
						handle(data)
		WebSocketPeer.STATE_CLOSED:
			_ws = null
			status = "Mất kết nối, thử lại sau %d giây" % roundi(ConfigDB.live.reconnect_seconds)
			_retry_in = ConfigDB.live.reconnect_seconds


## Xử lý một sự kiện LIVE (từ cầu nối, hoặc giả lập bằng phím khi thử).
func handle(e: Dictionary) -> void:
	var user := str(e.get("user", ""))
	var nick := str(e.get("nick", user))
	if nick == "":
		nick = user
	match str(e.get("type", "")):
		"comment":
			if user == "":
				return
			var side := queue.on_comment(user, nick, str(e.get("text", "")))
			if side >= 0:
				feed.emit("%s vào phe %s" % [nick, side_name(side)], side_color(side))
		"gift":
			if user == "":
				return
			var coins := maxi(0, int(e.get("coins", 0)))
			var entry := queue.on_gift(user, nick, coins)
			var tier_name: String = ConfigDB.live.tier_names[entry["tier"]]
			var gift := str(e.get("gift", "quà"))
			feed.emit("%s tặng %s (%d xu) → %s phe %s" % [nick, gift, coins, tier_name, side_name(entry["side"])], side_color(entry["side"]))
		"like":
			queue.on_like(int(e.get("count", 0)))
		"status":
			bridge_status = str(e.get("text", ""))
			feed.emit(bridge_status, Color(0.9, 0.85, 0.6))


static func side_name(side: int) -> String:
	return "Xanh" if side == LiveQueue.BLUE else "Đỏ"


static func side_color(side: int) -> Color:
	return BLUE_TEXT if side == LiveQueue.BLUE else RED_TEXT
