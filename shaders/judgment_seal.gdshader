shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float reveal = 0.0;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float power = 0.0;
uniform float mode = 0.0;
float line(float d, float w) { return 1.0 - smoothstep(w, w + max(fwidth(d),0.0015), abs(d)); }
float seg(vec2 p, vec2 a, vec2 b) { vec2 v=b-a; return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p), a = atan(p.y,p.x);
	float turn = a + age * (mode < 0.5 ? 0.16 : -0.12);
	float borders = line(r-0.94,0.006)+line(r-0.905,0.002)+line(r-0.745,0.006)+line(r-0.71,0.002);
	float ticks = step(0.83,cos(turn*72.0))*line(r-0.88,0.014);
	float cell = mod(turn+0.1308997,0.2617994)-0.1308997;
	vec2 glyph=vec2(cell*0.81,r-0.816);
	float gd=min(seg(glyph,vec2(0,-0.040),vec2(0,0.040)),min(seg(glyph,vec2(-0.03,0.013),vec2(0,0.037)),seg(glyph,vec2(0,0.037),vec2(0.03,0.013))));
	float runes=line(gd,0.004)+line(abs(glyph.x)+abs(glyph.y+0.025)-0.014,0.002);
	vec2 star=vec2(cos(a-age*0.13),sin(a-age*0.13))*r;
	vec2 tilt=vec2(star.x+star.y,star.y-star.x)*0.707107;
	float star_d=min(abs(max(abs(star.x),abs(star.y))-0.45),abs(max(abs(tilt.x),abs(tilt.y))-0.45));
	float lattice=line(star_d,0.004);
	float petals=line(r-(0.40+0.12*cos(turn*8.0)),0.003);
	float iris=line(r-0.24,0.005)+line(r-0.29,0.002)+line(r-0.17,0.002);
	float diamonds=line(abs(mod(a+0.392699,0.785398)-0.392699)*0.61+abs(r-0.60)-0.038,0.004);
	float fill=exp(-r*r*22.0)*power*0.24;
	float pattern=clamp(borders+ticks+runes+lattice+petals+iris+diamonds,0.0,1.0);
	float reveal_mask=1.0-smoothstep(reveal*1.2,reveal*1.2+0.08,r);
	if (mode > 2.5) {
		float crown=pow(max(0.0,cos(turn*12.0)),18.0);
		pattern=clamp(borders+ticks+runes+line(r-(0.56+crown*0.13),0.005),0.0,1.0);
		fill=0.0;
	} else if (mode > 1.5) {
		float wave=0.16+reveal*0.77;
		pattern=line(r-wave,0.010)+line(r-wave*0.79,0.004);
		pattern+=pow(max(0.0,cos(a*16.0+sin(r*16.0)*0.2)),60.0)*smoothstep(0.2,0.3,r)*(1.0-smoothstep(0.55,0.85,r));
		reveal_mask=1.0;
	}
	vec3 gold=mix(vec3(0.67,0.34,0.075),vec3(1.0,0.75,0.24),clamp(runes+lattice+iris,0.0,1.0));
	gold=mix(gold,vec3(1.0,0.96,0.76),clamp(power*0.60+diamonds*0.60,0.0,0.85));
	ALBEDO=gold;
	ALPHA=clamp(pattern*0.97+fill,0.0,1.0)*fade*reveal_mask*(1.0-smoothstep(0.97,1.0,r));
}
