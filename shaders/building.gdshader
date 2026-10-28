shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Iteration 3 building shader (contract in docs/CONTRACTS.md).
// UV = metres. CUSTOM0 = (style, variant, seed, surface). CUSTOM1 = (bay_w, floor_h, ground_h, ground_type).
// Arrays: facade layer = style, ground = 16 + type, roof = 24 + roof_type.

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_array : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_array : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray emission_mask_array : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float far_start = 160.0;
uniform float far_end = 260.0;
uniform float grime_strength : hint_range(0.0, 0.5) = 0.18;
uniform float night_energy : hint_range(0.0, 4.0) = 2.6;

global uniform float city_night;

varying flat vec4 v_c0;
varying flat vec4 v_c1;
varying vec3 v_wpos;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

// Variant palettes: 3 per style (tint multiplies the near-neutral baked albedo; w = wear 0..1).
vec4 palette(int s, int v) {
	vec4 p[42] = vec4[42](
		vec4(1.00, 1.00, 1.00, 0.35), vec4(0.86, 0.80, 0.78, 0.60), vec4(1.08, 0.94, 0.86, 0.20), // 0 red brick
		vec4(1.00, 1.00, 1.00, 0.25), vec4(1.05, 1.02, 0.90, 0.15), vec4(0.88, 0.84, 0.78, 0.55), // 1 tan
		vec4(1.00, 1.00, 1.00, 0.30), vec4(0.88, 0.82, 0.80, 0.45), vec4(1.10, 0.98, 0.90, 0.20), // 2 brownstone
		vec4(1.00, 1.00, 1.00, 0.25), vec4(1.04, 1.00, 0.92, 0.15), vec4(0.86, 0.86, 0.84, 0.55), // 3 deco
		vec4(1.00, 1.00, 1.00, 0.05), vec4(0.85, 1.05, 1.10, 0.05), vec4(1.05, 1.00, 0.85, 0.10), // 4 glass bg
		vec4(1.00, 1.00, 1.00, 0.05), vec4(1.10, 1.05, 0.95, 0.05), vec4(0.85, 0.95, 1.15, 0.10), // 5 dark
		vec4(1.00, 1.00, 1.00, 0.45), vec4(1.06, 1.02, 0.94, 0.30), vec4(0.84, 0.86, 0.88, 0.70), // 6 brutal
		vec4(1.00, 1.00, 1.00, 0.20), vec4(1.02, 0.96, 0.88, 0.30), vec4(0.96, 0.98, 1.02, 0.45), // 7 terracotta
		vec4(1.00, 1.00, 1.00, 0.20), vec4(0.95, 1.05, 1.00, 0.25), vec4(1.08, 1.00, 0.88, 0.40), // 8 midcentury
		vec4(1.00, 1.00, 1.00, 0.05), vec4(0.90, 1.00, 1.05, 0.10), vec4(1.10, 0.98, 0.90, 0.10), // 9 spandrel
		vec4(1.00, 1.00, 1.00, 0.55), vec4(0.85, 0.80, 0.80, 0.75), vec4(1.06, 0.96, 0.88, 0.40), // 10 warehouse
		vec4(1.00, 1.00, 1.00, 0.10), vec4(0.92, 1.02, 1.06, 0.15), vec4(1.06, 1.00, 0.92, 0.20), // 11 podium
		vec4(1.00, 1.00, 1.00, 0.10), vec4(1.03, 1.00, 0.95, 0.10), vec4(0.98, 0.98, 1.00, 0.15), // 12 landmark
		vec4(1.00, 1.00, 1.00, 0.45), vec4(0.92, 0.92, 0.94, 0.60), vec4(1.04, 0.98, 0.92, 0.35)  // 13 bridge
	);
	return p[clamp(s, 0, 13) * 3 + clamp(v, 0, 2)];
}

// Flat average colour per layer for the far path (approximate means of the baked albedo).
vec3 far_color(int layer) {
	vec3 c[14] = vec3[14](vec3(0.30, 0.13, 0.09), vec3(0.50, 0.38, 0.24), vec3(0.24, 0.16, 0.12),
		vec3(0.55, 0.50, 0.42), vec3(0.12, 0.25, 0.28), vec3(0.06, 0.07, 0.08), vec3(0.38, 0.37, 0.34),
		vec3(0.68, 0.64, 0.57), vec3(0.32, 0.36, 0.37), vec3(0.17, 0.21, 0.26), vec3(0.27, 0.13, 0.09),
		vec3(0.24, 0.32, 0.36), vec3(0.62, 0.57, 0.48), vec3(0.36, 0.34, 0.31));
	return c[clamp(layer, 0, 13)];
}

void vertex() {
	v_c0 = CUSTOM0;
	v_c1 = CUSTOM1;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	int style = int(v_c0.r + 0.5);
	int variant = int(v_c0.g + 0.5);
	float seed = v_c0.b;
	int surface = int(v_c0.a + 0.5);
	float bay = max(v_c1.r, 0.5);
	float flh = max(v_c1.g, 0.5);
	float gh = max(v_c1.b, 0.5);
	int gtype = int(v_c1.a + 0.5);
	vec2 m = UV;
	float dist = length(v_wpos - CAMERA_POSITION_WORLD);
	float far_t = smoothstep(far_start, far_end, dist);

	float layer;
	vec2 tuv;
	bool facade = surface != 1;
	bool is_ground = false;
	vec2 cell = vec2(0.0);
	if (!facade) {
		int roof = (style == 12) ? 4 : int(floor(seed * 5.0));
		layer = float(24 + clamp(roof, 0, 4));
		tuv = m / 8.0;
	} else {
		// Ground floor band, with a small per-building seed jitter of which bays get shop type.
		is_ground = m.y < gh && surface == 0;
		if (is_ground) {
			layer = float(16 + clamp(gtype, 0, 5));
			tuv = vec2(m.x / (2.0 * bay), m.y / gh);
		} else {
			layer = float(style);
			vec2 g = vec2(m.x / bay, (m.y - gh) / flh);   // bays and floors (exact integers per wall)
			cell = floor(g);
			tuv = g * 0.5;                                   // tile = 2 bays x 2 floors
		}
	}
	tuv.y = 1.0 - tuv.y;   // image row 0 is the top of the tile

	vec4 pal = palette(style, variant);
	vec3 tint = facade && !is_ground ? pal.rgb : vec3(1.0);
	float wear = pal.a;

	vec3 alb = texture(albedo_array, vec3(tuv, layer)).rgb;
	vec3 orm = texture(orm_array, vec3(tuv, layer)).rgb;
	vec3 em = texture(emission_mask_array, vec3(tuv, layer)).rgb;
	vec3 nrm = texture(normal_array, vec3(tuv, layer)).rgb;

	// Macro grime: subtle, large-scale only (never replaces textures).
	float macro = vnoise(v_wpos.xz * 0.04 + v_wpos.y * 0.03 + seed * 37.0);
	float streak = vnoise(vec2(v_wpos.x * 0.6 + v_wpos.z * 0.6, v_wpos.y * 0.05));
	float grime = grime_strength * wear * (0.5 * macro + 0.5 * streak) * (1.0 - em.r);
	alb *= tint * (1.0 - grime);
	alb *= 0.94 + 0.12 * h21(vec2(seed * 91.0, float(variant)));

	// Glass: low roughness, metallic-ish, fresnel boost so the sky reflects (sunset on towers).
	float glass = em.r;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 5.0);
	float rough = mix(orm.g, 0.04, glass);
	float metal = mix(orm.b, 0.15 + 0.5 * fres, glass);
	alb = mix(alb, alb * 0.6 + vec3(0.04) * fres, glass * 0.5);
	SPECULAR = mix(0.5, 0.9, glass);

	// Far path: flat averaged colour, no normal map, no window grid (stops moiré / shimmer).
	vec3 farc = (!facade) ? vec3(0.22, 0.22, 0.23) : (is_ground ? vec3(0.22, 0.2, 0.19) : far_color(style) * tint);
	ALBEDO = mix(alb, farc * (1.0 - 0.5 * grime), far_t);
	ROUGHNESS = mix(rough, mix(0.75, 0.3, float(style == 4 || style == 5 || style == 9 || style == 11)), far_t);
	METALLIC = mix(metal, 0.2 * float(style == 4 || style == 5 || style == 9), far_t);
	AO = mix(orm.r, 1.0, far_t);
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), far_t);
	NORMAL_MAP_DEPTH = 1.0;

	// Night: per-window lit state from hash(seed, bay, floor). Frames and curtains stay unlit.
	if (city_night > 0.001 && facade) {
		vec2 wid = is_ground ? vec2(floor(m.x / bay), -1.0) : cell;
		float h = h21(wid + seed * 113.0);
		float ratio = 0.2 + 0.5 * fract(seed * 7.31);
		float lit = step(h, ratio);
		float k = fract(h * 13.7);
		vec3 warm = vec3(1.0, 0.62, 0.30);      // ~2700K
		vec3 cool = vec3(0.85, 0.92, 1.0);      // ~5000K
		vec3 col = k < 0.62 ? warm : (k < 0.95 ? cool : vec3(0.35, 0.5, 1.0) * (0.6 + 0.4 * sin(TIME * 9.0 + h * 40.0)));
		float curtain = em.g;
		col = mix(col, warm * vec3(1.0, 0.8, 0.6) * 0.45, curtain);   // curtained = dim, warmer
		float lum = 0.35 + 0.65 * fract(h * 31.1);                     // interior depth variety
		float mask = em.r * (1.0 - em.b);
		if (is_ground) { lit = 1.0; lum = 0.8; }
		float e = mask * lit * lum * city_night * night_energy * (1.0 - 0.6 * far_t);
		EMISSION = col * min(e, 4.0) * 0.5;
		ALBEDO *= 1.0 - 0.6 * mask * lit * city_night;   // lit window shows its light, not reflections
	}
}
