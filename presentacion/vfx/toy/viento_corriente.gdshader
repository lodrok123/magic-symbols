shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// EL AIRE NO LLEVA COLOR PROPIO: las cintas son aire y el aire se ve por lo que arrastra, no por un tinte. Todas van en blanco roto con un punto FRIO
// (la paleta de viento_toy.gd: CLARO y SOMBRA, que viento_corrientes.gd pasa por uniforme); ninguna es verde. El verde del viento es solo el de las HOJAS.
uniform vec4 claro : source_color = vec4(0.90, 0.99, 0.94, 1.0);
uniform vec4 sombra : source_color = vec4(0.68, 0.87, 0.77, 1.0);
uniform vec4 sombra_honda : source_color = vec4(0.55, 0.74, 0.83, 1.0);   // las cintas del muro (tinte 0,5): el aire a contraluz, mas frio, para que se lean contra la cortina

void fragment() {
	float centro = 1.0 - abs(UV.x * 2.0 - 1.0);
	float punta = smoothstep(0.0, 0.19, UV.y) * (1.0 - smoothstep(0.66, 1.0, UV.y));
	float nervio = smoothstep(0.26, 0.92, centro);
	vec3 base = mix(sombra.rgb, claro.rgb, nervio);
	float cobertura = smoothstep(0.0, 0.75, centro);
	if (COLOR.g < 0.25) {
		base = mix(sombra_honda.rgb, vec3(0.93, 0.98, 1.0), nervio);
	} else if (COLOR.g < 0.75) {
		base = mix(sombra_honda.rgb, claro.rgb, nervio);
	} else if (COLOR.g < 0.9) {
		// Las cintas del tornado se ensanchan por tramos y se afinan en los extremos.
		float perfil = 0.29 + 0.62 * sin(UV.y * 3.14159)
			+ 0.11 * sin(UV.y * 17.0 + TIME * 2.4);
		float sesgo = sin(UV.y * 9.0 + TIME * 1.6) * 0.11;
		float cinta = 1.0 - abs(UV.x * 2.0 - 1.0 + sesgo) / perfil;
		float cuerpo = smoothstep(0.06, 0.78, cinta);
		float borde = smoothstep(-0.16, 0.19, cinta);
		base = mix(sombra.rgb, claro.rgb, smoothstep(0.17, 0.8, cinta));
		cobertura = borde * (0.21 + cuerpo * 0.79);
	}
	ALBEDO = base;
	ALPHA = cobertura * punta * COLOR.a;
}
