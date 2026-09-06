shader_type canvas_item;

// Hard-edged swipe with a short soft gradient, travelling along `dir`.
// progress 0 = fully clear, 1 = fully opaque black.
//
// exit_far_side anchors the covered region to the far edge instead of the near
// one, so the uncover half (progress 1 -> 0) keeps sweeping the same way rather
// than retreating back the way it came. Set it true for uncover.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 dir = vec2(1.0, 0.25);
uniform float softness : hint_range(0.001, 0.5) = 0.12;
uniform bool exit_far_side = false;
uniform vec3 tint : source_color = vec3(0.0);

void fragment() {
	vec2 d = normalize(dir);
	// Projection of UV onto the sweep axis, normalised to roughly 0..1
	// whatever the direction (the axis spans both UV extents).
	float span = abs(d.x) + abs(d.y);
	float t = clamp((dot(UV - 0.5, d) / span) + 0.5, 0.0, 1.0);

	// Pad the travel so the soft edge fully clears both ends of the screen.
	float p = progress * (1.0 + softness * 2.0) - softness;

	float a;
	if (exit_far_side) {
		// Covered where t > 1 - p: edge runs 0 -> 1 as progress goes 1 -> 0.
		a = smoothstep(1.0 - p - softness, 1.0 - p + softness, t);
	} else {
		// Covered where t < p: edge runs 0 -> 1 as progress goes 0 -> 1.
		a = 1.0 - smoothstep(p - softness, p + softness, t);
	}

	COLOR = vec4(tint, clamp(a, 0.0, 1.0));
}
