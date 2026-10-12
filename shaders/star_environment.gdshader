shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// All surfaces are opaque. No screen texture, depth texture, refraction,
// particles, additional lights or transparent cloud layers are required.
uniform int surface_role = 0; // 0 sculpted prop, 1 terrain, 2 water, 3 foliage
uniform int region = 0;
uniform float glow = 0.0;
varying vec3 world_position;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (surface_role == 3) {
		// A few centimetres of crown movement; trunks and silhouettes stay put.
		float weight = clamp(VERTEX.y + 0.2, 0.0, 1.0);
		VERTEX.x += sin(TIME * 0.72 + p.x * 0.31 + p.z * 0.19) * 0.018 * weight;
	}
	world_position = p;
}

float grain(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (surface_role == 1) {
		vec2 p = world_position.xz;
		float broad = sin(p.x * 0.22 + sin(p.y * 0.13) * 1.9) * sin(p.y * 0.27);
		float small = grain(p * 3.0) - 0.5;
		col *= 0.98 + broad * 0.026 + small * 0.026;
		if (region == 2 || region == 3) {
			vec2 cell = abs(fract(p * (region == 2 ? 0.25 : 0.33)) - 0.5);
			float grout = smoothstep(0.468, 0.493, max(cell.x, cell.y));
			float pavement = 1.0;
			if (region == 3) {
				pavement = 1.0 - smoothstep(15.0, 21.0, distance(p, vec2(25.0, -24.0)));
			} else {
				float garden = smoothstep(8.0, 12.0, abs(p.x)) * (1.0 - smoothstep(36.0, 41.0, length(p)));
				pavement -= garden * 0.82;
			}
			col *= 1.0 - grout * 0.105 * pavement;
		}
	} else if (surface_role == 2) {
		float wave = sin(world_position.x * 1.7 + world_position.z * 1.3 - TIME * 0.65);
		float crossing = sin(world_position.x * 0.73 - world_position.z * 2.0 + TIME * 0.37);
		float thread = smoothstep(0.93, 0.996, wave * 0.72 + crossing * 0.28);
		col = mix(col, vec3(0.76, 0.94, 0.90), thread * 0.30);
	}
	ALBEDO = col;
	ROUGHNESS = surface_role == 2 ? 0.7 : 1.0;
	EMISSION = col * glow;
}
