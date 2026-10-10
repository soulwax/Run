shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 beam_color : source_color = vec4(0.54, 0.71, 0.79, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = pow(max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float taper = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.66, 1.0, UV.y));
	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * 0.15;
	ALPHA = strength * taper * edge * 0.026;
}
