shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(0.95,0.62,0.16,1.);
uniform vec4 accent : source_color = vec4(1.,0.96,0.76,1.);
uniform vec4 shade : source_color = vec4(0.20,0.12,0.32,1.);
uniform float fade = 1.;
uniform float age = 0.;
uniform float opacity = 0.94;
uniform float spectral = 0.;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
    float relief = clamp(dot(normalize(NORMAL),normalize(vec3(-0.4,0.8,0.6)))*0.5+0.5,0.,1.);
    float edge = pow(max(1.-abs(dot(normalize(NORMAL),normalize(VIEW))), 0.0),2.);
    float inlay = clamp(COLOR.r,0.,1.);
    vec3 tint = primary.rgb;
    vec3 elements = mix(vec3(0.22,0.67,1.),vec3(1.,0.47,0.18),smoothstep(0.25,0.70,inlay));
    tint = mix(tint,elements,spectral*0.58);
    vec3 ink = mix(shade.rgb,tint,0.28+relief*0.72);
    ink = mix(ink,accent.rgb,clamp(inlay*0.76+edge*0.24,0.,1.));
    float stream = pow(max(0.5+0.5*sin(local.y*12.-local.z*9.-age*7.), 0.0),10.);
    ink += accent.rgb*stream*inlay*0.12;
    float grain = 0.5+0.5*sin(local.x*23.+local.y*17.)*sin(local.z*19.-local.y*13.);
    float dissolve = smoothstep((1.-fade)*1.15-0.12,(1.-fade)*1.15+0.09,grain);
    ALBEDO = ink;
    EMISSION = ink*(0.20+inlay*0.28);
    ALPHA = opacity*dissolve*smoothstep(0.,0.14,fade);
}
