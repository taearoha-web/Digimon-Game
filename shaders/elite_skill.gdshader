shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(0.4,0.8,1.,1.);
uniform vec4 accent : source_color = vec4(1.,0.9,0.65,1.);
uniform vec4 shade : source_color = vec4(0.05,0.12,0.25,1.);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.88;
varying vec3 point;
void vertex() { point = VERTEX; }
void fragment() {
    float light = dot(normalize(NORMAL),normalize(vec3(-0.35,0.85,0.4)))*0.5+0.5;
    float rim = pow(max(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))), 0.0),2.5);
    float inlay = COLOR.r;
    float line = pow(max(0.5+0.5*sin(point.y*19.0+point.z*7.0-age*3.0), 0.0),24.0)*0.15;
    vec3 ink = mix(shade.rgb, primary.rgb, 0.25+0.65*light);
    ink = mix(ink,accent.rgb,clamp(inlay*0.65+rim*0.25+line,0.,1.));
    float grain = 0.5+0.5*sin(point.x*23.0+point.y*9.0)*sin(point.z*21.0-point.y*13.0);
    float dissolve = smoothstep((1.-fade)*1.12-0.1,(1.-fade)*1.12+0.02,grain);
    ALBEDO = ink; EMISSION = ink * (0.08+inlay*0.16);
    ALPHA = opacity*dissolve*smoothstep(0.,0.12,fade);
}
