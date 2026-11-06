shader_type spatial;
// Alpha-blended particle cards of the skill layer stack (smoke, dust, debris, leaves, snow).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/skill_layer_card.gdshaderinc"
