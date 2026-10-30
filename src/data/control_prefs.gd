class_name ControlPrefs
extends RefCounted
## Cách điều khiển của người chơi. Game giữ một bộ "tự chỉnh"; hai chế độ có sẵn dùng giá trị mặc định.

enum Mode { FREE, LOCK, CUSTOM }

## true: kéo màn hình để xoay người (kiểu Bannerlord). false: tự quay về địch gần nhất, camera bám theo người.
var free_aim := true
## true: chém bằng nút CHÉM ở góc phải. false: vuốt ở cả vùng bên phải (kiểu cũ).
var attack_button := true
## Cách đỡ khi chém bằng vuốt (nút ĐỠ hoặc vuốt gấp khúc). Kiểu nút CHÉM luôn đỡ bằng nút ĐỠ.
var block_scheme: int = InputConfig.BlockScheme.BUTTON
## Hệ số nhân độ nhạy xoay.
var look_sensitivity := 1.0
## Camera cách sau lưng bao xa (mét).
var camera_distance := 4.0
## Hệ số nhân cỡ nút CHÉM, ĐỠ.
var button_scale := 1.0
## Đang chém mà có địch gần tâm ngắm thì tự quay nhẹ về phía địch đó.
var aim_assist := false
## Tự đỡ đúng hướng (như tuỳ chọn "Block direction: Automatic" của Bannerlord): giữ nút ĐỠ là
## giơ đỡ về phía đòn đang tới, không cần kéo chọn hướng.
var auto_block := false

const KEYS := ["free_aim", "attack_button", "block_scheme", "look_sensitivity", "camera_distance", "button_scale", "aim_assist", "auto_block"]


static func preset(mode: int) -> ControlPrefs:
	var p := ControlPrefs.new()
	if mode == Mode.LOCK:
		p.free_aim = false
	return p


static func mode_name(mode: int) -> String:
	match mode:
		Mode.LOCK: return "Khoá địch gần"
		Mode.CUSTOM: return "Tự chỉnh"
	return "Tự xoay"


func save(cfg: ConfigFile, section: String) -> void:
	for k in KEYS:
		cfg.set_value(section, k, get(k))


func load_from(cfg: ConfigFile, section: String) -> void:
	for k in KEYS:
		set(k, cfg.get_value(section, k, get(k)))
