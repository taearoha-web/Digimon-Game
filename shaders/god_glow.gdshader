shader_type spatial;
// Additive light of the god-tier hero objects (coronas, shock rings, columns, sparks).
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
#include "god_glow.gdshaderinc"
