shader_type canvas_item;

// Screen-warp effect: spins the frame behind around the centre, pulling inward,
// then lands on pure black. Draws an opaque copy of the screen, so the overlay
// must be hidden entirely when progress is 0.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float max_turns = 1.6;
uniform float pull : hint_range(0.0, 1.0) = 0.35;
uniform vec3 tint : source_color = vec3(0.0);

void fragment() {
	// Work in aspect-corrected space so the swirl stays circular on a
	// non-square viewport.
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);

	float r = length(p);
	float ang = atan(p.y, p.x);

	// Twist harder near the centre, and ease the whole thing in.
	float e = progress * progress;
	ang += e * max_turns * TAU * (1.0 - smoothstep(0.0, 0.75, r));
	r *= 1.0 - pull * e;

	vec2 warped = vec2(cos(ang), sin(ang)) * r;
	vec2 uv = clamp(warped / vec2(aspect, 1.0) + 0.5, vec2(0.0), vec2(1.0));

	vec3 c = texture(screen_tex, uv).rgb;
	COLOR = vec4(mix(c, tint, smoothstep(0.55, 1.0, progress)), 1.0);
}
