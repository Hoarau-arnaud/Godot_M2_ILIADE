shader_type spatial;
render_mode specular_disabled;
uniform bool arcade_palette = false;
uniform bool presentation_cached = false;
uniform sampler2D presentation_map : filter_linear, repeat_disable;
varying vec3 local_normal;
void vertex() { local_normal = normalize(VERTEX); }

void fragment() {
	vec2 p = UV * vec2(28.0, 18.0);
	vec3 pattern;
	if (presentation_cached) {
		pattern = texture(presentation_map, UV).rgb;
	} else {
		float continents = sin(p.x + sin(p.y * 1.4) * 2.0) * cos(p.y + sin(p.x * 0.45));
		pattern = vec3(smoothstep(0.16, 0.5, continents), smoothstep(0.62, 0.9, sin(p.x * 1.7 + p.y * 0.8 + sin(p.y))), 0.5 + 0.5 * sin(p.x * 0.65 + sin(p.y * 0.7)));
	}
	float land = pattern.r;
	float clouds = pattern.g;
	vec3 ocean = vec3(0.035, 0.105, 0.2);
	vec3 surface = mix(ocean, vec3(0.13, 0.2, 0.24), land);
	ALBEDO = mix(surface, vec3(0.22, 0.34, 0.43), clouds * 0.65);
	if (arcade_palette) {
		float relief = pattern.b;
		vec3 sea = vec3(0.025, 0.19, 0.32);
		vec3 land_color = mix(vec3(0.08, 0.38, 0.42), vec3(0.22, 0.55, 0.57), relief);
		float daylight = smoothstep(-0.2, 0.7, dot(normalize(local_normal), normalize(vec3(-0.6, 0.45, 0.65))));
		ALBEDO = mix(sea, land_color, land) * (0.2 + daylight * 0.8);
		ALBEDO = mix(ALBEDO, vec3(0.48, 0.76, 0.83), clouds * daylight * 0.4);
	}
	ROUGHNESS = 0.95;
	EMISSION = ocean * 0.06;
}
