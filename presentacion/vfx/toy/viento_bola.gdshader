shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;

// EL AIRE NO LLEVA COLOR PROPIO: el viento se ve por lo que arrastra (hojas, jirones) y por lo que tapa, no por un tinte. Por eso la envoltura de la rafaga
// es blanco roto con un punto FRIO (la misma paleta que viento_toy.gd: CLARO y SOMBRA) y no verde: sobre la hierba del Bosque un aire verde desaparece y en la
// parrilla se leia como un seto. El unico verde del viento es el de las HOJAS sueltas (VientoToy.HOJA).
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform vec4 sombra_aire : source_color = vec4(0.68, 0.87, 0.77, 1.0);   // VientoToy.SOMBRA: el centro, visto de frente
uniform vec4 contorno_aire : source_color = vec4(0.55, 0.74, 0.84, 1.0);   // el filo, un azul de aire en sombra
uniform vec4 claro_aire : source_color = vec4(0.90, 0.99, 0.94, 1.0);    // VientoToy.CLARO: el borde, donde la capa es mas gruesa

void fragment() {
	float frente = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float radio = sqrt(1.0 - frente * frente);
	float degradado = smoothstep(0.13, 0.89, radio);
	float borde = 1.0 - smoothstep(0.955, 0.985, radio);
	// Un filo duro y frio en el borde (toon): sobre un fondo claro (suelo, cielo, nubes) un aire blanco sin filo no tiene silueta.
	float filo = smoothstep(0.86, 0.88, radio) * borde;
	vec3 base = mix(sombra_aire.rgb, claro_aire.rgb, degradado);
	ALBEDO = mix(base, contorno_aire.rgb, filo * 0.85);
	ALPHA = max(mix(0.50, 0.85, degradado) * borde, filo) * vida;
}
