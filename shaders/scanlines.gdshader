shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float scan = 0.85 + 0.15 * sin(UV.y * 224.0 * 6.28318);
	col.rgb *= mix(1.0, scan, intensity) * brightness;
	COLOR = col;
}
