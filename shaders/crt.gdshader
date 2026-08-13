shader_type canvas_item;

uniform float curvature : hint_range(0.0, 0.4) = 0.16;
uniform float scanline : hint_range(0.0, 1.0) = 0.28;
uniform float mask : hint_range(0.0, 1.0) = 0.18;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv *= 1.0 + curvature * vec2(uv.y * uv.y, uv.x * uv.x);
	uv = uv * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec4 col = texture(TEXTURE, uv);
	float lines = 0.82 + 0.18 * sin(uv.y * 224.0 * 6.28318);
	col.rgb *= mix(1.0, lines, scanline);

	float stripe = mod(floor(UV.x * 256.0), 3.0);
	vec3 rgb_mask = vec3(1.0);
	if (stripe < 1.0) {
		rgb_mask = vec3(1.0, 0.82, 0.82);
	} else if (stripe < 2.0) {
		rgb_mask = vec3(0.82, 1.0, 0.82);
	} else {
		rgb_mask = vec3(0.82, 0.82, 1.0);
	}
	col.rgb *= mix(vec3(1.0), rgb_mask, mask);

	vec2 centered = UV * 2.0 - 1.0;
	float vig = 1.0 - vignette * dot(centered, centered);
	col.rgb *= vig;
	COLOR = col;
}
