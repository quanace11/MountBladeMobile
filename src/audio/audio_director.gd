class_name AudioDirector
extends Node
## Nghe EventBus và phát âm thanh. Giới hạn số tiếng cùng lúc.
## Chưa có file âm thanh: AudioConfig để trống thì không phát gì.

var cfg: AudioConfig
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func setup(p_cfg: AudioConfig) -> void:
	cfg = p_cfg
	for i in maxi(1, cfg.max_voices):
		var p := AudioStreamPlayer.new()
		p.volume_db = cfg.volume_db
		add_child(p)
		_players.append(p)
	EventBus.sim_event.connect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"attack_released": _play(cfg.swing)
		&"blocked", &"guard_broken": _play(cfg.block)
		&"parried": _play(cfg.parry)
		&"hit": _play(cfg.hit)
		&"died": _play(cfg.death)


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
