class_name AudioDirector
extends Node
## Nghe EventBus và phát âm thanh. Giới hạn số tiếng cùng lúc.
## AudioConfig để trống tiếng nào thì dùng tiếng tạo bằng code (SfxSynth).
##
## Va chạm có tiếng riêng theo chỗ vũ khí chạm vào (khóa "contact" của sự kiện):
## lưỡi chạm lưỡi "keng" ngân dài, chém vào cán "cộc", vào khiên "bộp", trúng thịt "xoẹt-phập",
## đâm trúng "phập", đòn chí mạng thêm tiếng xương gãy.

var cfg: AudioConfig
var _swing: AudioStream
var _block: AudioStream
var _parry: AudioStream
var _guard_break: AudioStream
var _hit: AudioStream
var _death: AudioStream
var _grunts: Array[AudioStream] = []
var _fall: AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
## Tiếng va chạm theo loại: &"blade", &"haft", &"shield", &"slash", &"stab", &"lethal" -> vài bản.
var _impacts: Dictionary = {}
var _task := -1

## Tiếng va chạm tạo bằng code tốn vài trăm mili giây, nên tạo ở luồng phụ một lần rồi giữ lại cho
## các trận sau. Lúc chưa tạo xong thì tạm dùng tiếng cũ.
static var _synth_cache: Dictionary = {}
static var _synth_mutex := Mutex.new()


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
	_death = cfg.death if cfg.death else SfxSynth.voice(330.0, 120.0, 0.85, 700.0, 1150.0, 9)
	# Vài tiếng rên khác nhau để không lặp đều.
	for k in 3:
		_grunts.append(SfxSynth.voice(190.0 + 25.0 * k, 120.0 + 10.0 * k, 0.24 + 0.04 * k, 520.0 + 60.0 * k, 1000.0, 6 + k))
	_fall = SfxSynth.body_fall()
	_setup_impacts()
	EventBus.sim_event.connect(_on_event)


func _setup_impacts() -> void:
	var from_cfg := {
		&"blade": cfg.clash_blade, &"haft": cfg.clash_haft, &"shield": cfg.clash_shield,
		&"slash": cfg.hit_slash, &"stab": cfg.hit_stab, &"lethal": cfg.hit_lethal,
	}
	var missing := false
	for key in from_cfg:
		if not (from_cfg[key] as Array).is_empty():
			_impacts[key] = from_cfg[key]
		else:
			missing = true
	if not missing:
		return
	_synth_mutex.lock()
	var cached := not _synth_cache.is_empty()
	_synth_mutex.unlock()
	if cached:
		_fill_from_cache()
	else:
		_task = WorkerThreadPool.add_task(_synth_impacts)


## Chạy ở luồng phụ.
func _synth_impacts() -> void:
	var s := {
		&"blade": [SfxSynth.blade_clash(1250.0, 21), SfxSynth.blade_clash(1080.0, 22)],
		&"haft": [SfxSynth.haft_hit(31), SfxSynth.haft_hit(32, 0.88)],
		&"shield": [SfxSynth.shield_hit(41), SfxSynth.shield_hit(42)],
		&"slash": [SfxSynth.flesh_slash(51), SfxSynth.flesh_slash(52)],
		&"stab": [SfxSynth.flesh_stab(61), SfxSynth.flesh_stab(62)],
		&"lethal": [SfxSynth.flesh_slash(71, true)],
	}
	_synth_mutex.lock()
	_synth_cache = s
	_synth_mutex.unlock()


func _fill_from_cache() -> void:
	_synth_mutex.lock()
	for key in _synth_cache:
		if not _impacts.has(key):
			_impacts[key] = _synth_cache[key]
	_synth_mutex.unlock()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_fill_from_cache()


## Đợi tạo xong tiếng va chạm (dùng trong test).
func wait_ready() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_fill_from_cache()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for p in _players:
		p.stop()
	if EventBus.sim_event.is_connected(_on_event):
		EventBus.sim_event.disconnect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"attack_released": _play(_swing, -6.0)
		&"dodge": _play(_swing, -4.0, 0.6)
		&"blocked": _play_impact(e.get("contact", &"haft"), 0.0, 1.0, _block)
		&"parried":
			# Đỡ hoàn hảo: va mạnh hơn, lưỡi ngân to.
			_play_impact(e.get("contact", &"blade"), 2.0, 1.0, _parry)
		&"guard_broken": _play_impact(e.get("contact", &"haft"), 3.0, 0.82, _guard_break)
		&"hit":
			var dmg := float(e.get("damage", 30.0))
			# Đòn nặng thì to hơn và trầm hơn một chút.
			var gain := clampf(lerpf(-4.0, 2.0, dmg / 40.0), -5.0, 3.0)
			var pitch := clampf(1.12 - dmg / 250.0, 0.9, 1.08)
			var kind := &"slash"
			if e.get("lethal", false):
				kind = &"lethal"
			elif int(e.get("dir", 0)) == Dir.THRUST:
				kind = &"stab"
			_play_impact(kind, gain, pitch, _hit)
			if not e.get("lethal", false):
				_play(_grunts[randi() % _grunts.size()], -5.0)
		&"died":
			_play(_death, -2.0)
			# Thân chạm đất sau khi khuỵu và đổ.
			get_tree().create_timer(0.75).timeout.connect(_play.bind(_fall, 0.0, 1.0))


## Phát một bản ngẫu nhiên của tiếng va chạm loại kind; chưa có thì phát tiếng dự phòng.
func _play_impact(kind: StringName, gain_db: float, pitch: float, fallback: AudioStream) -> void:
	var list: Array = _impacts.get(kind, [])
	if list.is_empty():
		_play(fallback, gain_db, pitch)
		return
	_play(list[randi() % list.size()], gain_db, pitch)


func _play(stream: AudioStream, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = cfg.volume_db + gain_db
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()
