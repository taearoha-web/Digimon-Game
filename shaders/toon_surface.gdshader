shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
// Double-sided variant (JapanKit's batched buildings); see toon_surface.gdshaderinc.
#include "res://shaders/toon_surface.gdshaderinc"
