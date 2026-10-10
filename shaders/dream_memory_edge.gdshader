shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;

uniform vec4 albedo_tint : source_color = vec4(0.5, 0.55, 0.6, 1.0);
uniform vec4 glow_tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 surface = texture(surface_texture, UV * 1.6).rgb;
    float frost = clamp((world_point.y - 0.3) * 0.12, 0.0, 0.16);
    ALBEDO = mix(albedo_tint.rgb, albedo_tint.rgb * surface, texture_strength) + frost;
	ROUGHNESS = 0.86;
	SPECULAR = 0.18;
    EMISSION = glow_tint.rgb * reveal;
    ALPHA = smoothstep(0.0, 0.85, reveal);
}
