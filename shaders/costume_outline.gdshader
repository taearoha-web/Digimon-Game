shader_type spatial;
// The cartoon outline of the closed costume pieces, swaying with them.
render_mode unshaded, cull_front, shadows_disabled;

#define COSTUME_OUTLINE
#include "res://shaders/costume.gdshaderinc"
