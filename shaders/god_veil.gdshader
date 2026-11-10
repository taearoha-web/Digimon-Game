shader_type spatial;
// Alpha-blended faces of the god-tier hero objects: deep space, scorch marks, dense fire
// (overlapping flames keep their hue instead of burning out to white).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
#include "god_glow.gdshaderinc"
