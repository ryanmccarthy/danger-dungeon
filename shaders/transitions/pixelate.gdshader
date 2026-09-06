shader_type canvas_item;

// Screen-warp effect: quantises the frame behind into blocks that grow with
// progress, then lands on pure black. Draws an opaque copy of the screen, so
// the overlay must be hidden entirely when progress is 0.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float min_blocks = 6.0;
uniform float max_blocks = 480.0;
uniform vec3 tint : source_color = vec3(0.0);

void fragment() {
	// Exponential falloff so the blocks visibly chunk up early rather than
	// spending most of the transition at near-native resolution.
	float blocks = mix(log(max_blocks), log(min_blocks), progress);
	blocks = exp(blocks);

	vec2 uv = (floor(SCREEN_UV * blocks) + 0.5) / blocks;
	vec3 c = texture(screen_tex, uv).rgb;

	COLOR = vec4(mix(c, tint, smoothstep(0.65, 1.0, progress)), 1.0);
}
