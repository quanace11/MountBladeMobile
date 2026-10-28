// Nền: đất nện trong đấu trường, cỏ bên ngoài, ranh giới lẫn vào nhau.
shader_type spatial;

uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float arena_radius = 14.0;
uniform float blend = 4.0;
uniform float dirt_scale = 0.4;
uniform float grass_scale = 0.5;
uniform vec4 grass_tint : source_color = vec4(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float wobble = texture(grass_albedo, p * 0.02).g - 0.5;
	float t = smoothstep(arena_radius - 1.0, arena_radius + blend, length(p) + wobble * 6.0);
	vec2 uv_d = p * dirt_scale;
	vec2 uv_g = p * grass_scale;
	ALBEDO = mix(texture(dirt_albedo, uv_d).rgb, texture(grass_albedo, uv_g).rgb * grass_tint.rgb, t);
	NORMAL_MAP = mix(texture(dirt_normal, uv_d).rgb, texture(grass_normal, uv_g).rgb, t);
	ROUGHNESS = mix(texture(dirt_rough, uv_d).r, texture(grass_rough, uv_g).r, t);
}
