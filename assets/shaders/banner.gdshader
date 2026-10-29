// Cờ bay trong gió: đỉnh gắn cột, đuôi cờ gợn sóng.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.7, 0.08, 0.05, 1.0);
uniform vec4 trim : source_color = vec4(0.9, 0.7, 0.2, 1.0);
uniform float wave = 0.12;
uniform float speed = 2.5;

void vertex() {
	float k = clamp(-VERTEX.x + 0.5, 0.0, 1.0);
	VERTEX.z += sin(TIME * speed + VERTEX.x * 5.0 + VERTEX.y * 2.0) * wave * k;
}

void fragment() {
	float border = step(0.9, UV.x) + step(UV.y, 0.06) + step(0.94, UV.y);
	ALBEDO = mix(color.rgb, trim.rgb, clamp(border, 0.0, 1.0));
	ROUGHNESS = 0.9;
}
