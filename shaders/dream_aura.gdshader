shader_type canvas_item;

uniform vec4 aura_tint : source_color = vec4(0.12, 0.055, 0.24, 1.0);
uniform float intensity : hint_range(0.0, 0.3) = 0.12;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float radius = length(vec2(centered.x * 0.82, centered.y));
	float edge = smoothstep(0.38, 1.16, radius);
	float horizon = exp(-pow((SCREEN_UV.y - 0.64) / 0.23, 2.0));
	float breath = 0.94 + 0.06 * sin(TIME * 0.31);
	float alpha = intensity * clamp(edge * 0.72 + horizon * 0.14, 0.0, 0.82) * breath;
	COLOR = vec4(aura_tint.rgb, alpha);
}
