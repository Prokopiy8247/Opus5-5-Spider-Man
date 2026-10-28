shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
// Used on a thin quad strip; UV.x along the web (0 hand .. 1 anchor), UV.y across.
uniform vec4 color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform float tremble = 0.03;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float along = UV.x;
	float env = sin(along * 3.14159);
	VERTEX += NORMAL * sin(along * 40.0 + TIME * 35.0) * tremble * env;
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.2, 1.0, across);
	float gloss = pow(1.0 - across, 6.0) * 0.6;
	ALBEDO = color.rgb + vec3(gloss);
	ALPHA = core * color.a * alpha_mul;
}
