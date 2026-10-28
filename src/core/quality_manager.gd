class_name QualityManager
extends Node
## Áp preset đồ họa và tự hạ/tăng độ phân giải 3D để giữ fps mục tiêu.

var preset: QualityPreset
var scale: float = 1.0
var _timer := 0.0
var _good_time := 0.0


func setup(p: QualityPreset) -> void:
	preset = p
	scale = p.render_scale
	_apply()


func _apply() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 1.0:
		return
	_timer = 0.0
	var fps := Engine.get_frames_per_second()
	var target := Engine.max_fps if Engine.max_fps > 0 else preset.target_fps
	if fps < target - 5 and scale > preset.min_render_scale:
		scale = maxf(preset.min_render_scale, scale - preset.render_scale_step)
		_good_time = 0.0
		_apply()
	elif fps >= target - 1:
		_good_time += 1.0
		if _good_time >= 3.0 and scale < preset.render_scale:
			scale = minf(preset.render_scale, scale + preset.render_scale_step)
			_good_time = 0.0
			_apply()
