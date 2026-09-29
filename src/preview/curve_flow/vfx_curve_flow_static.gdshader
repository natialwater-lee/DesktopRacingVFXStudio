shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D strand_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool native_strand = false;
uniform float heads[64];
uniform int active_count = 0;
uniform float segment_length = 1.0;
uniform float path_length = 1.0;
uniform float brightness = 1.0;
uniform float texture_phase = 0.0;
varying flat int slot_id;
varying float rear_release;

void vertex() {
	slot_id = int(round(COLOR.r * 64.0));
	rear_release = COLOR.g;
}

void fragment() {
	float d = UV.x;
	float head = heads[slot_id];
	float u = (d - (head - segment_length)) / segment_length;
	// No fract/modulo: a stopped segment leaves the path once, tail included.
	if (slot_id >= active_count || u < 0.0 || u > 1.0) {
		discard;
	}
	float taper = smoothstep(0.0, 0.30, u) * (1.0 - smoothstep(0.74, 1.0, u));
	float width_ratio = mix(0.04, 1.0, taper) * mix(0.18, 1.0, rear_release);
	float signed_cross = (UV.y * 2.0 - 1.0) / width_ratio;
	float cross = abs(signed_cross);
	float v = (signed_cross + 1.0) * 0.5;
	float path_fade = smoothstep(0.0, 16.0, d) * smoothstep(0.0, 28.0, path_length - d);
	float alpha = brightness * path_fade * rear_release;
	// Texture derivatives are evaluated before edge discard for stable mip selection.
	if (native_strand) {
		vec4 strand = texture(strand_texture, vec2(u, mix(38.0 / 171.0, 148.0 / 171.0, v)));
		COLOR = vec4(strand.rgb, strand.a * alpha);
	} else {
		vec2 filaments = texture(flow_texture, vec2((d - head) / 1024.0 + texture_phase, v)).rg;
		float core = filaments.r * 1.65;
		float halo = filaments.g;
		float edge = 1.0 - smoothstep(0.72, 1.0, cross);
		float envelope = smoothstep(0.0, 0.38, u) * (1.0 - smoothstep(0.68, 1.0, u));
		vec3 tint = mix(vec3(1.0, 0.59, 0.20), vec3(1.0, 0.94, 0.78), core / max(core + halo, 0.001));
		COLOR = vec4(tint, alpha * (core + halo) * edge * envelope);
	}
	if (cross > 1.0) { discard; }
}
