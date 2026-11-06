shader_type spatial;
// Warrior / Lancer / Defender class layers (MeleeArt). One material per pooled
// layer; `mode` picks the look, every mode shares the colour hierarchy
// white-hot core (accent) -> palette (primary) -> dark rim (shade), a soft
// fade-in (appear) and a noise dissolve (gone) instead of a hard cut.
//   0 ribbon  blade arcs, thrust streaks, spirals: UV.x along (tail 0 -> head 1),
//             UV.y across (1 = cutting edge). The head sweeps (sweep, tail) so
//             the leading edge burns white and the trailing smear cools and lags.
//   1 ground  cracks, burning cross, scorch: UV.x across the seam, UV.y distance
//             from the origin; a hot front runs out (sweep) and cools to embers.
//   2 panel   hexagonal shield light / mirror plates: UV.y 0 centre -> 1 rim,
//             COLOR.r stagger (panels light in turn), ripple from the centre.
//   3 aura    flame / blood aura on an open cylinder: UV.x around, UV.y height;
//             turbulent tongues, heartbeat (pulse) and veins of light.
//   4 solid   glow silhouettes (dragon, spear, banner, chain): COLOR.r core,
//             UV.x along; optional scale pattern and cloth wave.
//   5 ring    shock / wind / ripple rings: UV.y across the band.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/melee_art.gdshaderinc"
