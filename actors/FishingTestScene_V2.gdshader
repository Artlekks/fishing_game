shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Preserve the original brightness/detail,
	// but replace its hue/color.
	float brightness = max(tex.r, max(tex.g, tex.b));

	COLOR = vec4(
		tint_color.rgb * brightness,
		tex.a * tint_color.a
	);
}