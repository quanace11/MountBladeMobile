// Giáp lá (lamellar): các hàng lá kim loại nhỏ xếp so le, buộc bằng dây.
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.6, 0.15, 0.1, 1.0);
uniform vec4 lace : source_color = vec4(0.75, 0.55, 0.2, 1.0);
uniform vec2 plates = vec2(28.0, 9.0);
uniform float metal = 0.55;

void fragment() {
	vec2 uv = UV * plates;
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(uv);
	float plate = smoothstep(0.0, 0.1, f.x) * smoothstep(1.0, 0.9, f.x) * smoothstep(0.0, 0.15, f.y);
	float cord = smoothstep(0.88, 0.95, f.y);
	vec3 c = mix(tint.rgb * 0.35, tint.rgb * (0.8 + 0.35 * f.y), plate);
	c = mix(c, lace.rgb, cord * 0.85);
	ALBEDO = c;
	METALLIC = metal * plate * (1.0 - cord);
	ROUGHNESS = mix(0.85, 0.38, plate);
}
