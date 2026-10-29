// Đồi núi xa: cỏ ở chỗ thoải, đá ở chỗ dốc.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform float scale = 0.08;

varying vec3 world_pos;
varying float slope;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope = 1.0 - abs(NORMAL.y);
}

void fragment() {
	vec2 uv = world_pos.xz * scale;
	float t = smoothstep(0.25, 0.45, slope);
	ALBEDO = mix(texture(grass_albedo, uv).rgb * grass_tint.rgb, texture(rock_albedo, uv * 0.6).rgb, t);
	ROUGHNESS = 0.95;
}
