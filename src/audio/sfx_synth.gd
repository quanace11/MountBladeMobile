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


static func _to_wav(data: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] / peak * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
