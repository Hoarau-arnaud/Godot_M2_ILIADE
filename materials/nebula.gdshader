shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(2.7, 1.7);
	float envelope = exp(-dot(point, point) * 3.5);
	float cloud = envelope * (0.65 + 0.35 * sin(point.x * 6.0 + point.y * 4.0));
	ALBEDO = mix(vec3(0.06, 0.16, 0.3), vec3(0.26, 0.08, 0.3), UV.x);
	ALPHA = cloud * 0.22;
}
