shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// EL AIRE NO LLEVA COLOR PROPIO: la cortina del muro es aire, y el aire se ve por lo que arrastra, no por un tinte. Por eso va en blanco roto con un punto FRIO
// (la paleta de viento_toy.gd: CLARO y SOMBRA) y no en verde: con el verde se leia como un seto y en el Bosque se perdia contra la hierba. El verde del viento
// es solo el de las HOJAS que sube (VientoToy.HOJA).
uniform vec4 sombra_aire : source_color = vec4(0.62, 0.80, 0.88, 1.0);   // las vetas hondas: un poco mas frias que VientoToy.SOMBRA para que la cortina tenga dibujo
uniform vec4 claro_aire : source_color = vec4(0.90, 0.99, 0.97, 1.0);    // VientoToy.CLARO, algo enfriado
uniform float tiempo = 0.0;
uniform float opacidad = 1.0;

void fragment() {
	float altura = UV.y;
	float deriva = sin(altura * 6.2 - tiempo * 2.8 + UV.x * 4.0);
	float lenta = sin(UV.x * 56.0 - altura * 10.0 + tiempo * 3.0 + deriva * 1.65);
	float rapida = sin(UV.x * 115.0 - altura * 21.0 + tiempo * 8.4 + deriva * 2.1);
	float vetas = smoothstep(0.16, 0.96, lenta) * 0.64 + smoothstep(0.58, 1.0, rapida) * 0.36;

	float lateral = smoothstep(0.0, 0.14, min(UV.x, 1.0 - UV.x));
	float cresta = 0.80 + 0.065 * sin(UV.x * 19.0 - tiempo * 4.4) + deriva * 0.035;
	float techo = 1.0 - smoothstep(cresta - 0.19, cresta + 0.15, altura);
	float pie = smoothstep(0.0, 0.055, altura);

	ALBEDO = mix(sombra_aire.rgb, claro_aire.rgb, vetas * 0.61 + 0.25);
	ALPHA = lateral * techo * pie * (0.25 + vetas * 0.25) * opacidad;
}
