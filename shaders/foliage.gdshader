shader_type spatial;
// Foliage wind shader for tree / shrub "Leaves" materials.
// Two-scale motion: a slow trunk-anchored sway plus a fast per-vertex flutter. The sway amount
// grows with height above the instance origin, so trunks stay put and canopies move.
// Works with MultiMeshInstance3D: the per-instance world origin comes from MODEL_MATRIX.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.35;
uniform bool use_vertex_color = true;

// Wind
uniform float wind_strength : hint_range(0.0, 2.0) = 0.6;   // global gust amount (set by gameplay)
uniform float wind_speed : hint_range(0.0, 6.0) = 1.4;
uniform vec2 wind_dir = vec2(1.0, 0.3);
uniform float sway_scale : hint_range(0.0, 1.0) = 0.12;     // metres per metre of height
uniform float flutter_scale : hint_range(0.0, 0.5) = 0.045; // metres, leaf-level jitter
uniform float flutter_freq : hint_range(0.0, 20.0) = 7.0;
uniform float height_ref : hint_range(0.5, 20.0) = 6.0;     // height at which sway reaches 1.0

// Night / autumn tinting hooks shared with the prop materials.
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint : source_color = vec3(0.45, 0.55, 0.75);

varying vec3 v_color;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float origin_y = MODEL_MATRIX[3].y;
	float height = max(world.y - origin_y, 0.0);
	float t = TIME * wind_speed;
	vec2 dir = normalize(wind_dir + vec2(1e-4, 0.0));

	// Phase offset per instance keeps neighbouring trees out of sync.
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.35;
	float gust = sin(t + phase) * 0.6 + sin(t * 0.37 + phase * 1.7) * 0.4;
	float h = clamp(height / height_ref, 0.0, 1.0);
	float sway = gust * wind_strength * sway_scale * h * h;

	// Fast flutter: per-vertex, strongest on the outer canopy (far from the trunk axis).
	vec3 local = VERTEX;
	float radial = clamp(length(vec2(local.x, local.z)) * 0.5, 0.0, 1.0);
	float f = sin(t * flutter_freq + world.x * 3.1 + world.z * 2.7 + world.y * 1.9);
	float flutter = f * wind_strength * flutter_scale * radial * h;

	vec3 offset_world = vec3(dir.x, 0.0, dir.y) * (sway + flutter);
	offset_world.y += -abs(sway) * 0.25 + flutter * 0.4;  // slight droop while bending
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;

	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 base = albedo * v_color * tex.rgb;
	base = mix(base, base * night_tint, night_factor);
	ALBEDO = base;
	ROUGHNESS = roughness;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	// Leaf masses read better with a soft two-sided response.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
