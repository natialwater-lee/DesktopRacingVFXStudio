shader_type canvas_item;
render_mode unshaded, blend_add;
uniform bool refined = false;
uniform bool textured = false;
uniform bool flow_texture_enabled = true;
uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D strand_texture : source_color, filter_linear_mipmap, repeat_disable;

// UV.x is position WITHIN the moving segment, not phase along the whole lane.
// Analytic screen-footprint broadening preserves subpixel core energy without bloom.
void fragment() {
	bool png_strand = COLOR.b < 0.5;
	float lane_alpha = COLOR.a;
	float cross = abs(UV.y * 2.0 - 1.0);
	float footprint = max(fwidth(UV.y) * 2.0, 0.001);
	float core_width = refined ? 0.28 : 0.12;
	float core_sigma = sqrt(core_width * core_width + footprint * footprint * 0.18);
	float core = exp(-cross * cross / (core_sigma * core_sigma)) * core_width / core_sigma * (refined ? 1.05 : 1.0);
	float halo = exp(-cross * cross / (refined ? 0.30 : 0.23)) * (refined ? 0.32 : 0.28);
	float edge = 1.0 - smoothstep(0.72, 1.0, cross);
	float segment_u = textured ? COLOR.r : UV.x;
	if (textured && flow_texture_enabled) {
		vec2 filaments = texture(flow_texture, UV).rg;
		// Split lobes have ~60% of B's integrated core energy; normalize that loss.
		core = filaments.r * 1.65;
		halo = filaments.g;
	}
	float envelope = smoothstep(0.0, refined ? 0.38 : 0.22, segment_u) * (1.0 - smoothstep(refined ? 0.68 : 0.82, 1.0, segment_u));
	vec3 tint = mix(vec3(1.0, 0.59, 0.20), refined ? vec3(1.0, 0.94, 0.78) : vec3(1.0, 0.92, 0.72), core / max(core + halo, 0.001));
	COLOR = vec4(tint, COLOR.a * (core + halo) * edge * envelope);
	if (png_strand) {
		// Native color/alpha only: no tint multiplication, analytic core or extra halo.
		vec4 strand = texture(strand_texture, UV);
		COLOR = vec4(strand.rgb, strand.a * lane_alpha);
	}
}
