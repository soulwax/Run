shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.3) = 0.14;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform vec4 signal_red : source_color = vec4(0.86, 0.12, 0.16, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float curve = dot(centered, centered);
	uv += centered * curve * 0.00065 * strength;
	float tear = step(0.994, fract(sin(floor(TIME * 11.0) * 17.31) * 43758.5453));
	float tear_y = fract(sin(floor(TIME * 11.0) * 31.7) * 24634.6345);
	float tear_band = tear * (1.0 - smoothstep(0.0, 0.003, abs(uv.y - tear_y)));
	uv.x += tear_band * burst * 0.012;
	float split = strength * (0.32 + burst * 2.8);
	vec3 c;
	c.r = texture(screen, uv + vec2(SCREEN_PIXEL_SIZE.x * split, 0.0)).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - vec2(SCREEN_PIXEL_SIZE.x * split, 0.0)).b;
	float scanline = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159265);
	c *= 1.0 - scanline * strength * 0.10;
	float rim = smoothstep(0.25, 1.65, curve);
	c *= 1.0 - rim * strength * 0.25;
	c += tear_band * signal_red.rgb * burst * 0.08;
	c *= 1.0 - burst * 0.07;
	COLOR = vec4(c, 1.0);
}
