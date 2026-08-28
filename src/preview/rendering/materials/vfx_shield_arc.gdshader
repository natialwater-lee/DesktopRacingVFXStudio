shader_type canvas_item;
render_mode unshaded;

uniform float scroll_offset = 0.0;

void fragment() {
	COLOR *= texture(TEXTURE, vec2(fract(UV.x + scroll_offset), UV.y));
}
