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
