class_name Mats
extends RefCounted
## Bộ nhớ đệm vật liệu dùng chung, để nhiều vật thể cùng vật liệu (đỡ tốn bộ nhớ và lệnh vẽ).

static var _cache: Dictionary = {}


static func color(c: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%.2f" % [c.to_html(), roughness, metallic]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = roughness
		m.metallic = metallic
		_cache[key] = m
	return _cache[key]


## Vật liệu PBR từ bộ texture "<prefix>_diff/_nor/_rough.jpg". triplanar: dán theo toạ độ thế giới.
static func pbr(prefix: String, uv_scale := 1.0, triplanar := false, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "p_%s_%.3f_%s_%s" % [prefix, uv_scale, triplanar, tint.to_html()]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(prefix + "_diff.jpg")
		m.albedo_color = tint
		var nor := prefix + "_nor.jpg"
		if ResourceLoader.exists(nor):
			m.normal_enabled = true
			m.normal_texture = load(nor)
		var rough := prefix + "_rough.jpg"
		if ResourceLoader.exists(rough):
			m.roughness_texture = load(rough)
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness = 1.0
		if triplanar:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * uv_scale
		else:
			m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache[key] = m
	return _cache[key]


static func shader(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
