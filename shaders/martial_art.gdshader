shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(1.,0.45,0.15,1.);
uniform vec4 accent : source_color = vec4(1.,0.95,0.75,1.);
uniform vec4 shade : source_color = vec4(0.25,0.05,0.09,1.);
uniform float fade = 1.;
uniform float age = 0.;
uniform float opacity = 0.95;
uniform float morph = -1.;
varying vec3 local;
void vertex() { if (morph >= 0.) { VERTEX = mix(VERTEX,CUSTOM0.xyz,morph); } local = VERTEX; }
void fragment() {
    float light = clamp(dot(normalize(NORMAL),normalize(vec3(-0.4,0.8,0.6)))*0.5+0.5,0.,1.);
    float edge = pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
    float gold = COLOR.r;
    vec3 ink = mix(shade.rgb,primary.rgb,0.32+light*0.68);
    ink = mix(ink,accent.rgb,clamp(gold*0.87+edge*0.20,0.,1.));
    float band = pow(0.5+0.5*sin(local.y*12.-local.z*4.-age*8.),12.);
    ink += accent.rgb * band * gold * 0.12;
    float grain = 0.5+0.5*sin(local.x*29.+local.y*17.)*sin(local.z*21.-local.y*11.);
    float cut = smoothstep((1.-fade)*1.1-0.08,(1.-fade)*1.1+0.12,grain);
    ALBEDO = ink;
    EMISSION = ink*(0.14+gold*0.28);
    ALPHA = opacity*cut*smoothstep(0.,0.16,fade);
}
