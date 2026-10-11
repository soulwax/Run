shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 0.3) = 0.14;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform vec4 signal_red : source_color = vec4(0.86, 0.12, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float curve = dot(centered, centered);
	uv += centered * curve * 0.0009 * strength;
	float clock = floor(TIME * 12.0);
	float tear = step(0.994, hash(vec2(clock, 17.31)));
	float tear_y = hash(vec2(clock, 31.7));
	float tear_band = tear * (1.0 - smoothstep(0.0, 0.0025, abs(uv.y - tear_y)));
	float roll = 1.0 - smoothstep(0.0, 0.045, abs(fract(uv.y * 0.7 - TIME * 0.035) - 0.5));
	uv.x += tear_band * burst * 0.012 + roll * strength * 0.0008;
	// One screen fetch keeps this global treatment inexpensive at high
	// resolutions. Red accents and the horizontal tear carry the signal-glass
	// character without three channel-offset texture samples per pixel.
	vec3 c = texture(screen, uv).rgb;
	float scanline = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159265);
	float grille = 0.5 + 0.5 * sin(FRAGCOORD.x * 1.0472);
	c *= 1.0 - scanline * strength * 0.15;
	c *= 1.0 - grille * strength * 0.025;
	float phosphor = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 18.0)) - 0.5;
	c += phosphor * strength * 0.018;
	float rim = smoothstep(0.25, 1.65, curve);
	c *= 1.0 - rim * strength * 0.32;
	c += (tear_band * burst * 0.08 + roll * strength * 0.008) * signal_red.rgb;
	c *= 1.0 - burst * 0.075;
	COLOR = vec4(c, 1.0);
}
