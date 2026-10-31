class_name SfxSynth
extends RefCounted
## Tạo tiếng động bằng code khi chưa có file âm thanh: tiếng binh khí va nhau (keng),
## tiếng chém trúng (phập), tiếng vung vũ khí (vút). Chỉ chạy một lần lúc vào trận.

const RATE := 22050


## Kim loại va nhau: vài hoạ âm không điều hoà (như chuông) tắt dần, cộng tiếng gõ ngắn lúc chạm.
## base: tần số chính (Hz). ring: thời gian ngân (giây).
static func clang(base: float, ring: float, seed: int = 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ratios := [1.0, 1.47, 2.09, 2.76, 3.93, 5.40]
	var amps := [1.0, 0.55, 0.5, 0.4, 0.25, 0.18]
	var n := int(RATE * ring * 3.0)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in ratios.size():
			var f: float = base * ratios[j]
			# Hoạ âm cao tắt nhanh hơn; hai sóng lệch nhau một chút cho tiếng rung "ngân".
			var env := exp(-t / (ring / (1.0 + j * 0.6)))
			v += amps[j] * env * (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.004 * t))
		# Tiếng gõ lúc chạm: nhiễu đã lọc, rất ngắn.
		lp += (rng.randf_range(-1, 1) - lp) * 0.5
		v += lp * 1.6 * exp(-t / 0.006)
		# Tiếng đục của cán, khiên: sóng trầm tắt nhanh.
		v += 0.7 * sin(TAU * 140.0 * t) * exp(-t / 0.03)
		data[i] = v
	return _to_wav(data, 0.9)


## Chém trúng người: tiếng trầm đục cộng nhiễu ngắn.
static func thud(seed: int = 2) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(RATE * 0.28)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.12
		var f := 110.0 - 50.0 * minf(1.0, t / 0.1)
		data[i] = sin(TAU * f * t) * exp(-t / 0.07) + lp * 2.5 * exp(-t / 0.04)
	return _to_wav(data, 0.85)


## Tiếng người: chuỗi xung thanh môn (cao độ f0 trượt từ f_start xuống f_end), lọc qua hai
## formant để thành nguyên âm "ư/a", thêm hơi thở. Dùng cho tiếng rên khi trúng đòn và tiếng hét khi chết.
static func voice(f_start: float, f_end: float, dur: float, f1: float, f2: float, seed: int = 4) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	var r1 := [0.0, 0.0]
	var r2 := [0.0, 0.0]
	var c1 := _resonator(f1, 90.0)
	var c2 := _resonator(f2, 120.0)
	for i in n:
		var x := float(i) / n
		var f0 := lerpf(f_start, f_end, x * x) * (1.0 + 0.02 * sin(TAU * 5.5 * x * dur))
		phase = fmod(phase + f0 / RATE, 1.0)
		# Xung thanh môn: dốc lên rồi tắt nhanh, giàu hoạ âm như dây thanh.
		var src := (1.0 - phase) * (1.0 - phase) - 0.33 + rng.randf_range(-0.25, 0.25)
		var y1: float = src + c1[0] * r1[0] + c1[1] * r1[1]
		r1[1] = r1[0]; r1[0] = y1
		var y2: float = src + c2[0] * r2[0] + c2[1] * r2[1]
		r2[1] = r2[0]; r2[0] = y2
		var env := minf(1.0, x * dur / 0.02) * pow(1.0 - x, 1.5)
		data[i] = (y1 + 0.6 * y2) * env
	return _to_wav(data, 0.7)


static func _resonator(f: float, bw: float) -> Array:
	var r := exp(-PI * bw / RATE)
	return [2.0 * r * cos(TAU * f / RATE), -r * r]


## Thân người ngã xuống đất: tiếng đục trầm, giáp lá va lách cách.
static func body_fall(seed: int = 5) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(RATE * 0.5)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	var rattles := [0.0, 0.035, 0.07, 0.12]
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		var v := sin(TAU * 58.0 * t) * exp(-t / 0.09) * 1.4 + lp * 3.0 * exp(-t / 0.06)
		for k in rattles.size():
			var dt: float = t - rattles[k]
			if dt >= 0.0:
				v += 0.25 * sin(TAU * (1900.0 + 400.0 * k) * dt) * exp(-dt / 0.015)
		data[i] = v
	return _to_wav(data, 0.9)


## Vung vũ khí: nhiễu lọc, to dần rồi nhỏ dần, tần số quét lên rồi xuống.
static func whoosh(seed: int = 3) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dur := 0.28
	var n := int(RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var x := float(i) / n
		var shape := sin(PI * x)
		var cut := 0.05 + 0.25 * shape
		lp += (rng.randf_range(-1, 1) - lp) * cut
		lp2 += (lp - lp2) * cut
		data[i] = (lp - lp2) * shape * shape
	return _to_wav(data, 0.45)


static func _to_wav(data: PackedFloat32Array, gain: float, rate: int = RATE) -> AudioStreamWAV:
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] / peak * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


# ---------------------------------------------------------------------------------------------
# Tiếng va chạm kiểu phim: mỗi tiếng ghép từ vài lớp (cộng hưởng của vật bị chém, tiếng gõ lúc chạm,
# tiếng miết, tiếng đục trầm) rồi phủ chút tiếng vọng. Mỗi tiếng có vài bản (seed khác) để không lặp đều.
# Thuật toán giống hệt bản Python dùng để nghe thử: tools/sfx_preview.py.


## Lưỡi chém trúng lưỡi (kim loại chạm kim loại): "KEENG" ngân dài, có tiếng hai lưỡi miết "xiiing".
## base: tần số chính (Hz), lưỡi to thì trầm hơn.
static func blade_clash(base: float, seed: int = 21) -> AudioStreamWAV:
	var rate := 32000
	var rng := _rng(seed)
	var d := _buf(rate, 1.1)
	var ratios := [1.0, 1.58, 2.76, 3.47, 5.40, 6.93, 8.93]
	var decays := [0.85, 0.65, 0.5, 0.38, 0.24, 0.17, 0.11]
	var amps := [0.5, 0.3, 0.45, 0.3, 0.3, 0.2, 0.18]
	var fs := []
	for r in ratios:
		fs.append(base * r * rng.randf_range(0.97, 1.03))
	_add_modes(d, rate, 0, fs, decays, amps)
	# Mỗi hoạ âm thêm một bản lệch 0,35% cho tiếng ngân "rung rung" như lưỡi thép thật.
	var fs2 := []
	var amps2 := []
	for k in fs.size():
		fs2.append(fs[k] * 1.0035)
		amps2.append(amps[k] * 0.7)
	_add_modes(d, rate, 0, fs2, decays, amps2)
	_noise_burst(d, rate, rng, 0, 0.0025, 2.2)
	_band_noise(d, rate, rng, 0, 0.06, 3800.0, 3000.0, 1800.0, 2.0, 0.0005, 0.012)
	_band_noise(d, rate, rng, int(0.012 * rate), 0.26, 6500.0, 2600.0, 700.0, 1.8, 0.01, 0.09, 0.02)
	_sweep_sine(d, rate, 0, 260.0, 170.0, 0.02, 0.03, 0.5)
	d = _reverb(d, rate, 0.22, 0.5)
	return _to_wav(d, 0.9, rate)


## Chém trúng cán gỗ: "CỘC" khô, ngắn, thớ gỗ dập, kèm tiếng "cạch" nhỏ của lưỡi chém vào.
## pitch < 1: cán to, nặng hơn.
static func haft_hit(seed: int = 31, pitch: float = 1.0) -> AudioStreamWAV:
	var rate := 22050
	var rng := _rng(seed)
	var d := _buf(rate, 0.35)
	var wood := []
	for f in [380.0, 820.0, 1350.0, 2100.0, 3050.0]:
		wood.append(f * pitch * rng.randf_range(0.94, 1.06))
	_add_modes(d, rate, 0, wood, [0.07, 0.045, 0.03, 0.02, 0.012], [1.0, 0.7, 0.55, 0.4, 0.3])
	_noise_burst(d, rate, rng, 0, 0.0015, 2.0)
	_noise_burst(d, rate, rng, 0, 0.02, 1.2, false, 0.25)
	var tick := [2600.0 * rng.randf_range(0.94, 1.06), 4300.0 * rng.randf_range(0.94, 1.06), 6900.0 * rng.randf_range(0.94, 1.06)]
	_add_modes(d, rate, 0, tick, [0.09, 0.06, 0.04], [0.24, 0.16, 0.1])
	_sweep_sine(d, rate, 0, 150.0, 100.0, 0.02, 0.05, 0.8)
	for k in 4:
		_noise_burst(d, rate, rng, int(rng.randf_range(0.002, 0.022) * rate), 0.0008, rng.randf_range(0.6, 1.2))
	d = _reverb(d, rate, 0.14, 0.35)
	return _to_wav(d, 0.95, rate)


## Chém trúng khiên gỗ bọc da: "BỘP" trầm, dày như trống, vành sắt và đinh tán lách cách.
static func shield_hit(seed: int = 41) -> AudioStreamWAV:
	var rate := 22050
	var rng := _rng(seed)
	var d := _buf(rate, 0.5)
	var drum := []
	for f in [92.0, 150.0, 228.0, 310.0, 455.0, 640.0]:
		drum.append(f * rng.randf_range(0.93, 1.07))
	_add_modes(d, rate, 0, drum, [0.16, 0.11, 0.08, 0.06, 0.04, 0.03], [1.0, 0.8, 0.6, 0.45, 0.3, 0.2])
	_noise_burst(d, rate, rng, 0, 0.045, 2.2, false, 0.08)
	_noise_burst(d, rate, rng, 0, 0.012, 0.8, false, 0.3)
	_noise_burst(d, rate, rng, 0, 0.002, 1.2)
	_sweep_sine(d, rate, 0, 120.0, 70.0, 0.03, 0.09, 1.0)
	for k in 3:
		var at := int((0.002 + k * 0.035 + rng.randf_range(0.0, 0.015)) * rate)
		_add_modes(d, rate, at, [rng.randf_range(2600.0, 3800.0), rng.randf_range(4500.0, 5600.0)],
				[0.03, 0.02], [0.12 / (k + 1), 0.06 / (k + 1)])
	d = _reverb(d, rate, 0.16, 0.4)
	return _to_wav(d, 0.95, rate)


## Chém trúng người: "XOẸT-PHẬP". Lưỡi xé qua áo và thịt (nhiễu quét từ cao xuống), cú nện trầm,
## tiếng ướt, giáp lá lách cách. heavy: đòn chí mạng, thêm tiếng xương gãy và cú nện nặng hơn.
static func flesh_slash(seed: int = 51, heavy: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var rng := _rng(seed)
	var d := _buf(rate, 0.4)
	_band_noise(d, rate, rng, 0, 0.11, 4800.0 * rng.randf_range(0.9, 1.1), 1300.0, 1400.0, 2.4, 0.004, 0.05)
	_noise_burst(d, rate, rng, 0, 0.03, 0.5)
	_sweep_sine(d, rate, int(0.008 * rate), 95.0, 45.0, 0.04, 0.07, 1.2)
	_noise_burst(d, rate, rng, int(0.006 * rate), 0.06, 4.0, false, 0.06)
	_wet_grains(d, rate, rng, 14, 0.17, 250.0, 1000.0, 4.5)
	for k in 3:
		var at := int((0.002 + k * 0.016 + rng.randf_range(0.0, 0.01)) * rate)
		_add_modes(d, rate, at, [rng.randf_range(2400.0, 4200.0)], [rng.randf_range(0.012, 0.02)], [0.12])
	if heavy:
		for k in 6:
			_noise_burst(d, rate, rng, int((0.012 + rng.randf_range(0.0, 0.025)) * rate), 0.0012, rng.randf_range(0.8, 1.5))
		_sweep_sine(d, rate, int(0.01 * rate), 70.0, 38.0, 0.05, 0.11, 1.0)
	d = _reverb(d, rate, 0.1, 0.3)
	return _to_wav(d, 0.95, rate)


## Đâm trúng người: "PHẬP" sâu và ướt, ít tiếng xé hơn chém.
static func flesh_stab(seed: int = 61) -> AudioStreamWAV:
	var rate := 22050
	var rng := _rng(seed)
	var d := _buf(rate, 0.42)
	_band_noise(d, rate, rng, 0, 0.05, 2800.0, 1800.0, 1200.0, 1.6, 0.002, 0.016)
	_sweep_sine(d, rate, int(0.004 * rate), 80.0, 40.0, 0.05, 0.09, 1.4)
	_noise_burst(d, rate, rng, int(0.004 * rate), 0.09, 2.6, false, 0.05)
	_wet_grains(d, rate, rng, 18, 0.24, 200.0, 700.0, 6.5)
	d = _reverb(d, rate, 0.1, 0.3)
	return _to_wav(d, 0.95, rate)


# ----- các khối dựng tiếng -----

static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _buf(rate: int, dur: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(int(rate * dur))
	return d


## Cộng các hoạ âm tắt dần (mỗi cái là một sóng sin tắt theo hàm mũ), tính bằng bộ cộng hưởng
## hai cực cho nhanh, không gọi sin mỗi mẫu.
static func _add_modes(d: PackedFloat32Array, rate: int, start: int, freqs: Array, decays: Array, amps: Array) -> void:
	for j in freqs.size():
		var w := TAU * float(freqs[j]) / rate
		if w >= PI * 0.95:
			continue
		var tau: float = decays[j]
		var r := exp(-1.0 / (tau * rate))
		var c1 := 2.0 * r * cos(w)
		var c2 := -r * r
		var y := float(amps[j]) * sin(w)
		var yp := 0.0
		var end := mini(d.size(), start + int(tau * rate * 7.0))
		for i in range(start, end):
			d[i] += y
			var yn := c1 * y + c2 * yp
			yp = y
			y = yn


## Nhiễu tắt nhanh. hp: bỏ phần trầm (tiếng gõ "tách"); lp_a nhỏ: nhiễu trầm, đục.
static func _noise_burst(d: PackedFloat32Array, rate: int, rng: RandomNumberGenerator, start: int, tau: float,
		amp: float, hp: bool = true, lp_a: float = 1.0) -> void:
	var lp := 0.0
	var lp2 := 0.0
	var k := exp(-1.0 / (tau * rate))
	var env := amp
	var end := mini(d.size(), start + int(tau * rate * 7.0))
	for i in range(start, end):
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lp_a
		var v := lp
		if hp:
			lp2 += (lp - lp2) * 0.35
			v = lp - lp2
		d[i] += v * env
		env *= k


## Nhiễu lọc dải hẹp, tần số giữa quét từ f0 tới f1 (tiếng xé, tiếng miết).
## grain > 0: biên độ lổn nhổn như mài (hai lưỡi miết vào nhau).
static func _band_noise(d: PackedFloat32Array, rate: int, rng: RandomNumberGenerator, start: int, dur: float,
		f0: float, f1: float, bw: float, amp: float, attack: float, tau: float, grain: float = 0.0) -> void:
	var y1 := 0.0
	var y2 := 0.0
	var g := 0.0
	var n := int(dur * rate)
	var r := exp(-PI * bw / rate)
	var c1 := 0.0
	var c2 := -r * r
	var gain := 0.0
	for k in n:
		var i := start + k
		if i >= d.size():
			break
		# Đổi hệ số lọc mỗi 32 mẫu là đủ mượt, đỡ tốn exp/cos.
		if k % 32 == 0:
			var w := TAU * f0 * pow(f1 / f0, float(k) / n) / rate
			c1 = 2.0 * r * cos(w)
			gain = (1.0 - r) * 2.0 * sin(w)
		var y := gain * rng.randf_range(-1.0, 1.0) + c1 * y1 + c2 * y2
		y2 = y1
		y1 = y
		var t := float(k) / rate
		var env := minf(1.0, t / attack) * exp(-t / tau)
		if grain > 0.0:
			g += (absf(rng.randf_range(-1.0, 1.0)) - g) * grain
			env *= 0.4 + 1.6 * g
		d[i] += amp * y * env


## Sóng sin trầm tụt cao độ (cú nện vào người, vào khiên).
static func _sweep_sine(d: PackedFloat32Array, rate: int, start: int, f0: float, f1: float, glide: float,
		tau: float, amp: float, attack: float = 0.002) -> void:
	var ph := 0.0
	var end := mini(d.size(), start + int(tau * rate * 7.0))
	for i in range(start, end):
		var t := float(i - start) / rate
		var f := f1 + (f0 - f1) * exp(-t / glide)
		ph += TAU * f / rate
		d[i] += amp * sin(ph) * minf(1.0, t / attack) * exp(-t / tau)


## Tiếng ướt: nhiều hạt nhiễu rất ngắn lọc ở tần số trầm-vừa, dày lúc đầu rồi thưa dần.
static func _wet_grains(d: PackedFloat32Array, rate: int, rng: RandomNumberGenerator, count: int, t_max: float,
		f_lo: float, f_hi: float, amp: float) -> void:
	var r := exp(-PI * 180.0 / rate)
	for k in count:
		var u := rng.randf()
		var t0 := 0.004 + t_max * u * u
		var ln := rng.randf_range(0.006, 0.02)
		var w := TAU * rng.randf_range(f_lo, f_hi) / rate
		var c1 := 2.0 * r * cos(w)
		var c2 := -r * r
		var gain := (1.0 - r) * 2.0 * sin(w)
		var a := amp * (1.0 - 0.6 * u)
		var y1 := 0.0
		var y2 := 0.0
		var n := int(ln * rate)
		var s := int(t0 * rate)
		for m in n:
			var i := s + m
			if i >= d.size():
				break
			var y := gain * rng.randf_range(-1.0, 1.0) + c1 * y1 + c2 * y2
			y2 = y1
			y1 = y
			d[i] += a * y * sin(PI * m / n)


## Tiếng vọng ngắn (4 bộ lọc lược + 2 bộ thông tất kiểu Schroeder), nối thêm đuôi tail giây.
static func _reverb(d: PackedFloat32Array, rate: int, wet: float, tail: float) -> PackedFloat32Array:
	var n0 := d.size()
	d.resize(n0 + int(tail * rate))
	var n := d.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for c in [[29.7, 0.78], [37.1, 0.76], [41.1, 0.74], [43.7, 0.72]]:
		var size := int(float(c[0]) * rate / 1000.0)
		var fb: float = c[1]
		var line := PackedFloat32Array()
		line.resize(size)
		var p := 0
		var lp := 0.0
		for i in n:
			var y := line[p]
			lp += (y - lp) * 0.45
			line[p] = d[i] + lp * fb
			p = (p + 1) % size
			out[i] += y * 0.25
	for ms in [5.0, 1.7]:
		var size := int(float(ms) * rate / 1000.0)
		var line := PackedFloat32Array()
		line.resize(size)
		var p := 0
		for i in n:
			var b := line[p]
			var x := out[i]
			var y := -0.7 * x + b
			line[p] = x + 0.7 * y
			p = (p + 1) % size
			out[i] = y
	for i in n:
		d[i] += wet * out[i]
	return d
