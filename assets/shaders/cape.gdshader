// Áo choàng: đung đưa theo bước chạy, gốc gắn vai đứng yên.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.06, 0.05, 1.0);
uniform float sway = 0.0;
uniform float flutter = 0.03;

void vertex() {
	float k = clamp(0.5 - VERTEX.y, 0.0, 1.0);
	VERTEX.z += (sway + sin(TIME * 4.0 + VERTEX.y * 6.0) * flutter) * k * k;
}

void fragment() {
	ALBEDO = color.rgb * (0.75 + 0.25 * UV.y);
	ROUGHNESS = 0.92;
}
