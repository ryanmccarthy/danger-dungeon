shader_type canvas_item;

// Plain dip to black. progress 0 = fully clear, 1 = fully opaque black.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.0);

void fragment() {
	COLOR = vec4(tint, progress);
}
