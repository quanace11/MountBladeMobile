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
