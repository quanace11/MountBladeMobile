class_name AudioDirector
extends Node
## Nghe EventBus và phát âm thanh. Giới hạn số tiếng cùng lúc.
## AudioConfig để trống tiếng nào thì dùng tiếng tạo bằng code (SfxSynth).

var cfg: AudioConfig
var _swing: AudioStream
var _block: AudioStream
var _parry: AudioStream
var _guard_break: AudioStream
var _hit: AudioStream
var _death: AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func setup(p_cfg: AudioConfig) -> void:
	cfg = p_cfg
	for i in maxi(1, cfg.max_voices):
		var p := AudioStreamPlayer.new()
		p.volume_db = cfg.volume_db
		add_child(p)
		_players.append(p)
	_swing = cfg.swing if cfg.swing else SfxSynth.whoosh()
	_block = cfg.block if cfg.block else SfxSynth.clang(880.0, 0.22)
	_parry = cfg.parry if cfg.parry else SfxSynth.clang(1250.0, 0.45, 7)
	_guard_break = cfg.block if cfg.block else SfxSynth.clang(520.0, 0.3, 11)
	_hit = cfg.hit if cfg.hit else SfxSynth.thud()
	_death = cfg.death if cfg.death else _hit
	EventBus.sim_event.connect(_on_event)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
	if EventBus.sim_event.is_connected(_on_event):
		EventBus.sim_event.disconnect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"attack_released": _play(_swing, -6.0)
		&"dodge": _play(_swing, -4.0, 0.6)
		&"blocked": _play(_block)
		&"parried": _play(_parry, 2.0)
		&"guard_broken": _play(_guard_break, 2.0)
		&"hit": _play(_hit)
		&"died": _play(_death, 0.0, 0.7)


func _play(stream: AudioStream, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = cfg.volume_db + gain_db
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()
