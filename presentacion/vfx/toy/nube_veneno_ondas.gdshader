shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// ONDAS DEL VENENO (18/11/2026, seta venenosa): anillos concéntricos a ras de suelo que NACEN en el centro de la nube (la seta que la exhala) y viajan hacia fuera hasta el BORDE ACTUAL de la nube,
// uno cada `periodo` s, para que en un fotograma suelto se vea de dónde sale el gas. Es un quad plano que ocupa el radio final (el borde del quad es r = 1); `radio_k` (0..1) es el radio actual
// de la nube sobre el final (ella crece al nacer). Centro más denso, frentes de onda nítidos, y todo se desvanece hacia el borde. Sin luz, translúcido; solo lo monta NubeVenenoVfx con `ondas`.
// Cada frente lleva un HALO verde oscuro y un filo verde claro (se lee igual sobre hierba clara que sobre suelo oscuro); el centro, un relleno verde más denso. Los verdes son los de NubeVenenoVfx.
uniform vec3 color_oscuro : source_color = vec3(0.14, 0.46, 0.20);
uniform vec3 color : source_color = vec3(0.45, 0.80, 0.27);
uniform vec3 color_claro : source_color = vec3(0.62, 0.92, 0.34);
uniform vec3 color_nucleo : source_color = vec3(0.86, 1.0, 0.68);
uniform float edad = 0.0;                          // s desde que nació la nube (la primera onda sale con ella)
uniform float periodo = 0.7;                       // s entre dos ondas
uniform int n_ondas = 3;                           // cuántas caben a la vez (cada una tarda n_ondas · periodo en llegar al borde)
uniform float radio_k : hint_range(0.0, 1.0) = 1.0;
uniform float ancho = 0.06;                        // grosor de un frente, en radios finales
uniform float fuerza = 1.0;                        // > 1 mientras la nube crece: más marcadas
uniform float alfa : hint_range(0.0, 1.0) = 1.0;   // se apaga al disiparse / arder

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float R = max(radio_k, 0.03);
	float fase = edad / periodo;
	float halo = 0.0;
	float filo = 0.0;
	for (int i = 0; i < n_ondas; i++) {
		float x = fase - float(i);
		if (x < 0.0) {
			continue;                                // esta onda aún no ha nacido
		}
		float ciclo = float(n_ondas);
		float u = (x - ciclo * floor(x / ciclo)) / ciclo;     // 0 = recién salida del centro · 1 = en el borde
		float r = u * R;
		float w = ancho * (0.7 + 0.8 * u);           // el frente se ensancha un poco al alejarse
		float dist = abs(d - r);
		float vida = smoothstep(0.0, 0.06, u) * pow(1.0 - u, 0.6);
		halo = max(halo, (1.0 - smoothstep(0.0, w * 1.25, dist)) * vida);
		filo = max(filo, (1.0 - smoothstep(0.0, w * 0.4, dist)) * vida);
	}
	float borde = 1.0 - smoothstep(R * 0.88, R, d);  // todo se desvanece hacia el borde actual
	float nucleo = exp(-pow(d / (0.28 * R + 0.02), 2.0));
	float denso = 1.0 - smoothstep(0.0, R, d);      // relleno: más denso en el centro
	// 18/11 (Pablo: «más contraste»): el relleno entre ondas baja (deja ver el suelo), el halo de cada frente es el verde oscuro de la paleta MÁS oscuro (×0,4) y casi opaco, el filo sube al verde del núcleo,
	// y el borde actual de la nube lleva un aro oscuro fijo: sobre hierba clara se leen anillos oscuros con un filo de luz; sobre suelo oscuro, el filo.
	float aro = (1.0 - smoothstep(0.0, 0.07, abs(d - R * 0.93))) * step(d, R);
	float relleno = (0.14 + 0.30 * denso * denso) * borde;
	float f = min(fuerza, 1.6);
	float al = relleno + halo * 0.95 * f * borde + filo * 0.5 * f * borde + nucleo * 0.25 + aro * 0.55;
	al = clamp(al, 0.0, 0.97) * alfa;
	if (al < 0.01) {
		discard;
	}
	vec3 sombra = color_oscuro * 0.4;
	vec3 col = mix(color_oscuro, color, clamp(denso * denso * 0.6 + nucleo * 0.7, 0.0, 1.0));
	col = mix(col, sombra, clamp(max(halo, aro) * 1.1, 0.0, 1.0));
	col = mix(col, color_nucleo, clamp(filo * 1.3, 0.0, 1.0));
	col = mix(col, color_nucleo, clamp(nucleo * 0.8, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = al;
}
