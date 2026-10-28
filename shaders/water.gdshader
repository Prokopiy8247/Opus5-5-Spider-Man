shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.02, 0.08, 0.12);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.22, 0.28);
uniform float wave_height = 0.25;
uniform float wave_speed = 0.6;

varying vec3 wpos;

float wave(vec2 p, float t) {
	return sin(p.x * 0.08 + t) * 0.5 + sin(p.y * 0.11 - t * 1.3) * 0.35 + sin((p.x + p.y) * 0.21 + t * 1.7) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(wpos.xz, TIME * wave_speed) * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	float e = 0.5;
	float hx = wave(wpos.xz + vec2(e, 0.0), t) - wave(wpos.xz - vec2(e, 0.0), t);
	float hz = wave(wpos.xz + vec2(0.0, e), t) - wave(wpos.xz - vec2(0.0, e), t);
	vec3 nw = normalize(vec3(-hx * 2.0, 1.0, -hz * 2.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color, shallow_color, fres);
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
	SPECULAR = 0.8;
}
