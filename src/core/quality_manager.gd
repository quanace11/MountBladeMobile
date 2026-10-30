class_name QualityManager
extends Node
## Áp preset đồ họa và tự hạ/tăng độ phân giải 3D để giữ fps mục tiêu.
## Mỗi lần đổi độ phân giải là một lần tạo lại bộ đệm hình (khựng một chút), nên chỉ đổi khi fps
## tụt hẳn vài giây liền, và nếu vừa tăng lên đã phải hạ xuống thì chờ lâu hơn mới thử tăng lại.

## Mới vào trận fps còn thấp do đang nạp, chưa tính.
const GRACE_TIME := 3.0
## Số giây fps thấp liên tiếp mới hạ.
const BAD_TIME := 2.0
## Số giây fps tốt liên tiếp mới thử tăng; nhân đôi mỗi lần tăng lên rồi lại phải hạ.
const GOOD_TIME := 5.0
const GOOD_TIME_MAX := 60.0

var preset: QualityPreset
var scale: float = 1.0
var _timer := 0.0
var _age := 0.0
var _bad_time := 0.0
var _good_time := 0.0
var _good_needed := GOOD_TIME
var _since_raise := INF


func setup(p: QualityPreset) -> void:
	preset = p
	scale = p.render_scale
	_apply()


func _apply() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale


func _process(delta: float) -> void:
	_age += delta
	_timer += delta
	if _timer < 1.0:
		return
	_timer = 0.0
	_since_raise += 1.0
	if _age < GRACE_TIME:
		return
	var fps := Engine.get_frames_per_second()
	var target := Engine.max_fps if Engine.max_fps > 0 else preset.target_fps
	if fps < target * 0.9:
		_good_time = 0.0
		_bad_time += 1.0
		if _bad_time >= BAD_TIME and scale > preset.min_render_scale:
			scale = maxf(preset.min_render_scale, scale - preset.render_scale_step)
			_bad_time = 0.0
			if _since_raise < _good_needed:
				_good_needed = minf(GOOD_TIME_MAX, _good_needed * 2.0)
			_apply()
	elif fps >= target - 2:
		_bad_time = 0.0
		_good_time += 1.0
		if _good_time >= _good_needed and scale < preset.render_scale:
			scale = minf(preset.render_scale, scale + preset.render_scale_step)
			_good_time = 0.0
			_since_raise = 0.0
			_apply()
	else:
		_bad_time = 0.0
		_good_time = 0.0
