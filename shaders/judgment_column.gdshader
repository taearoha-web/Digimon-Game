shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 0.0;
uniform float fade = 0.0;
uniform float shell = 0.0;
void fragment() {
	float rim=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.75);
	float flutes=pow(max(0.5+0.5*sin(UV.x*75.3982+sin(UV.y*12.0-age*4.0)*0.25), 0.0),8.0);
	float stream=pow(max(0.5+0.5*sin(UV.y*44.0+UV.x*18.0-age*16.0), 0.0),10.0);
	vec3 gold=mix(vec3(1.0,0.57,0.10),vec3(1.0,0.97,0.78),rim*0.75+flutes*0.25);
	ALBEDO=gold;
	// Feather the lower shaft so the victim and hit number stay readable.
	float ends=smoothstep(0.0,0.06,UV.y)*(1.0-smoothstep(0.72,1.0,UV.y)*0.62);
	ALPHA=fade*ends*mix(0.66*rim+flutes*0.18,0.08+flutes*0.16+stream*0.11,shell);
}
