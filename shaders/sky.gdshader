shader_type sky;
// Sunset/night sky with procedural clouds. day_factor: 1 day, 0 night. sunset_factor peaks near dusk.
uniform vec3 zenith_day : source_color = vec3(0.25, 0.45, 0.8);
uniform vec3 horizon_sunset : source_color = vec3(1.0, 0.5, 0.25);
uniform vec3 zenith_night : source_color = vec3(0.02, 0.03, 0.08);
uniform float day_factor : hint_range(0.0, 1.0) = 0.6;
uniform float sunset_factor : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -1.0, 1.0);
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sd = max(dot(d, sun_dir), 0.0);
	vec3 zen = mix(zenith_night, zenith_day, day_factor);
	vec3 hor = mix(mix(zenith_night * 2.0, vec3(0.7, 0.8, 0.95), day_factor), horizon_sunset, sunset_factor * pow(sd * 0.5 + 0.5, 2.0));
	vec3 col = mix(hor, zen, pow(max(h, 0.0), 0.45));
	col += horizon_sunset * pow(sd, 8.0) * sunset_factor * 0.6;
	col += vec3(1.0, 0.85, 0.6) * pow(sd, 600.0) * 20.0 * LIGHT0_ENERGY;
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.15) * 1.5 + vec2(TIME * 0.004, 0.0);
		float c = smoothstep(1.0 - cloud_cover, 1.0, fbm(uv));
		vec3 ccol = mix(vec3(0.15, 0.12, 0.2), mix(vec3(1.0, 0.55, 0.35), vec3(0.95), day_factor * (1.0 - sunset_factor)), max(day_factor, 0.08));
		ccol += horizon_sunset * pow(sd, 3.0) * sunset_factor;
		col = mix(col, ccol, c * smoothstep(0.0, 0.15, h));
		float star = step(0.998, hash(floor(d.xz / (h + 0.01) * 300.0)));
		col += vec3(star) * (1.0 - day_factor) * (1.0 - c);
	} else {
		col = mix(hor * 0.4, vec3(0.03), clamp(-h * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
