shader_type canvas_item;

// Grainy dissolve: black eats the screen in clumps driven by value noise.
// progress 0 = fully clear, 1 = fully opaque black.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 26.0;
uniform float softness : hint_range(0.001, 0.5) = 0.14;
uniform vec3 tint : source_color = vec3(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smoothed value noise, so the dissolve reads as clumps rather than static.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Two octaves keeps the clumps from looking like a regular grid.
	float n = value_noise(UV * noise_scale) * 0.65
		+ value_noise(UV * noise_scale * 2.7) * 0.35;

	// Pad so progress 0 and 1 are guaranteed fully clear / fully covered.
	float p = progress * (1.0 + softness * 2.0) - softness;
	float a = smoothstep(n - softness, n + softness, p);

	COLOR = vec4(tint, clamp(a, 0.0, 1.0));
}
