shader_type spatial;
// World-space paving for Godot-built flat surfaces (plazas, paths, slabs):
// tile or concrete-slab grid with dark grout seams, per-tile tone variation and fine grit.
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.56, 0.54, 0.50);
uniform vec3 seam_color : source_color = vec3(0.30, 0.29, 0.27);
uniform float tile_size = 1.0;      // metres per tile
uniform float seam_width = 0.035;   // fraction of a tile
uniform float tile_variation = 0.12;
uniform float grit = 0.08;
uniform float running_bond = 0.0;   // 1 = offset every other row (brick-like)

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	float row = floor(uv.y);
	uv.x += running_bond * 0.5 * mod(row, 2.0);
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(seam_width * 0.6, seam_width, edge);
	float tone = 1.0 + (hash21(cell) - 0.5) * 2.0 * tile_variation;
	float n = vnoise(world_pos.xz * 6.0) * 0.6 + vnoise(world_pos.xz * 23.0) * 0.4;
	vec3 col = base_color * tone * (1.0 - grit + n * grit * 2.0);
	// Weathering blotches across several tiles.
	col *= 0.9 + 0.1 * vnoise(world_pos.xz * 0.35);
	ALBEDO = mix(col, seam_color, seam);
	ROUGHNESS = mix(0.88, 0.97, seam);
	SPECULAR = 0.3;
}
