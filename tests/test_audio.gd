extends TestBase
## Tiếng tạo bằng code: có dữ liệu, đúng định dạng, không bị câm.


func _peak(w: AudioStreamWAV) -> int:
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	return peak


func test_synth_sounds_are_audible() -> void:
	for w in [SfxSynth.clang(880.0, 0.22), SfxSynth.thud(), SfxSynth.whoosh()]:
		check_eq(w.format, AudioStreamWAV.FORMAT_16_BITS, "16 bit")
		check(w.data.size() > SfxSynth.RATE * 0.2, "dài ít nhất 0,1 giây")
		check(_peak(w) > 10000, "đủ to")


func test_parry_rings_longer_than_block() -> void:
	check(SfxSynth.clang(1250.0, 0.45).data.size() > SfxSynth.clang(880.0, 0.22).data.size(), "đỡ hoàn hảo ngân lâu hơn")


func test_voice_and_body_fall_sounds() -> void:
	var grunt := SfxSynth.voice(200.0, 120.0, 0.25, 550.0, 1000.0)
	var cry := SfxSynth.voice(330.0, 120.0, 0.85, 700.0, 1150.0)
	var fall := SfxSynth.body_fall()
	for w in [grunt, cry, fall]:
		check((w as AudioStreamWAV).data.size() > 1000, "có dữ liệu âm thanh")
	check(cry.get_length() > grunt.get_length(), "tiếng hét khi chết dài hơn tiếng rên")


## Số lần đổi dấu mỗi giây trong 0,1 giây đầu: tiếng càng "chói" (nhiều tần số cao) thì càng lớn.
func _brightness(w: AudioStreamWAV) -> float:
	var n := int(w.mix_rate * 0.1)
	var c := 0
	var prev := w.data.decode_s16(0)
	for i in range(1, n):
		var v := w.data.decode_s16(i * 2)
		if (v < 0) != (prev < 0):
			c += 1
		prev = v
	return c / 0.1


func test_impact_sounds_are_audible() -> void:
	var all := [SfxSynth.blade_clash(1250.0), SfxSynth.haft_hit(), SfxSynth.shield_hit(),
			SfxSynth.flesh_slash(), SfxSynth.flesh_stab(), SfxSynth.flesh_slash(71, true)]
	for w in all:
		check_eq((w as AudioStreamWAV).format, AudioStreamWAV.FORMAT_16_BITS, "16 bit")
		check((w as AudioStreamWAV).get_length() > 0.25, "dài ít nhất 0,25 giây (có tiếng vọng)")
		check(_peak(w) > 10000, "đủ to")


func test_each_contact_sounds_different() -> void:
	var blade := SfxSynth.blade_clash(1250.0)
	var haft := SfxSynth.haft_hit()
	var shield := SfxSynth.shield_hit()
	var flesh := SfxSynth.flesh_slash()
	check(blade.get_length() > haft.get_length() and blade.get_length() > flesh.get_length(),
			"lưỡi chạm lưỡi ngân lâu hơn chém vào cán, vào thịt")
	check(_brightness(blade) > _brightness(haft) * 2.0, "lưỡi chạm lưỡi chói hơn hẳn tiếng gỗ")
	check(_brightness(haft) > _brightness(shield) * 1.5, "cán gỗ đanh hơn tiếng khiên trầm")
	check(SfxSynth.haft_hit(31).data != SfxSynth.haft_hit(32, 0.88).data, "các bản khác nhau để không lặp đều")


func test_heavy_weapon_swings_longer() -> void:
	check(SfxSynth.whoosh(13, 0.42, 0.55).get_length() > SfxSynth.whoosh().get_length(), "đao, giáo nặng vung lâu hơn kiếm")
