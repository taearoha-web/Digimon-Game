shader_type spatial;
// The light a grown pet wears (PetForm): an additive overlay on the pet's own model.
// A rim of its element's colour where the surface turns away from the camera, a soft
// tint over the whole body, and for the god form a thin gold edge; all of it breathes
// slowly. One extra pass of the model's meshes, nothing else.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.85, 0.4, 0.0);
uniform float rim = 0.9;
uniform float base = 0.05;
uniform float sharpness = 2.4;
uniform float pulse = 0.25;
uniform float rate = 1.6;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, sharpness);
	float beat = 1.0 + pulse * sin(TIME * rate);
	vec3 light = color.rgb * (base + edge * rim) * beat;
	light += gold.rgb * smoothstep(0.55, 0.95, edge) * gold.a * (1.0 + pulse * sin(TIME * rate * 1.7 + 1.3));
	ALBEDO = light;
}
