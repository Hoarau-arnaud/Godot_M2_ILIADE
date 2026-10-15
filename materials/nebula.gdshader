shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 cloud_color_a : source_color = vec3(0.06, 0.16, 0.3);
uniform vec3 cloud_color_b : source_color = vec3(0.26, 0.08, 0.3);
uniform bool presentation_cached = false;
uniform sampler2D presentation_map : filter_linear, repeat_disable;
uniform float opacity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(2.7, 1.7);
	float cloud;
	if (presentation_cached) {
		cloud = texture(presentation_map, UV).r;
	} else {
		float envelope = exp(-dot(point, point) * 3.5);
		cloud = envelope * (0.65 + 0.35 * sin(point.x * 6.0 + point.y * 4.0));
	}
	ALBEDO = mix(cloud_color_a, cloud_color_b, UV.x);
	ALPHA = cloud * opacity;
}
