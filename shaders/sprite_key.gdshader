shader_type canvas_item;

uniform vec4 key_color : source_color;
uniform float key_tolerance = 0.08;

void fragment() {
	vec4 pixel_sample = texture(TEXTURE, UV);
	float distance_to_key = distance(pixel_sample.rgb, key_color.rgb);
	if (distance_to_key <= key_tolerance) {
		discard;
	}
	COLOR = pixel_sample * COLOR;
}
