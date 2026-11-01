shader_type spatial;
// Плейсхолдер-материал для серых комнат: сетка в мировых координатах на любой поверхности.
// Нужен, чтобы глазами читались скорость, высота и масштаб (на гладком сером этого не видно).

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform vec4 line_color : source_color = vec4(0.22, 0.22, 0.22, 1.0);
// Шаг сетки, метры.
uniform float cell_size = 2.0;
// Толщина линии, метры.
uniform float line_width = 0.06;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	// Расстояние до ближайшей линии сетки в метрах.
	vec2 dist = abs(fract(uv / cell_size - 0.5) - 0.5) * cell_size;
	float line = 1.0 - smoothstep(line_width * 0.5, line_width, min(dist.x, dist.y));
	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
