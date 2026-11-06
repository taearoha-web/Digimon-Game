shader_type spatial;
// The additive twin of melee_art (same modes and uniforms): cores of light,
// flame and shield glow add onto the scene; the dark rim simply vanishes.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
#include "res://shaders/melee_art.gdshaderinc"
