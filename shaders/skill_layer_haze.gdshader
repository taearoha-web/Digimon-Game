shader_type spatial;
// Heat haze of the skill layer stack (high quality only, SkillLayers): a camera-
// facing card of faint rising shimmer lines over a fire or a heavy landing. It
// reads no screen copy (a WebGL2 back-buffer read costs a full-screen copy on a
// phone), only its own waves, so it stays cheap and Compatibility safe.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float fade = 1.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	mat4 world = mat4(vec4(normalize(INV_VIEW_MATRIX[0].xyz) * s, 0.0), vec4(normalize(INV_VIEW_MATRIX[1].xyz) * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz) * s, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask = (1.0 - smoothstep(0.3, 1.0, length(p * vec2(1.0, 0.8)))) * fade;
	float bend = sin(UV.x * 7.0 + TIME * 2.3) * 1.7 + sin(UV.x * 17.0 - TIME * 3.1) * 0.5;
	float lines = pow(abs(sin(UV.y * 26.0 + TIME * 9.0 + bend)), 18.0);
	float veil = 0.5 + 0.5 * sin(UV.y * 5.0 + TIME * 4.0 + UV.x * 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(mask * (lines * 0.07 + veil * 0.02), 0.0, 1.0);
}
