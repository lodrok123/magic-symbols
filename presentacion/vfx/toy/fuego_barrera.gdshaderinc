// BARRERA DE FUEGO (ronda de Pablo, 2/11/2026; referencias ref_barrera_video_a / b): una cúpula de fuego «toy» con
//   · BORDE brillante muy marcado (fresnel fuerte en la silueta, amarillo-blanco por dentro y naranja hacia fuera),
//   · interior TRANSLÚCIDO con jirones de llama que corren por la superficie (ruido triplanar en coordenadas de la esfera unitaria: sin polos ni costuras),
//   · LAMIDOS: una segunda cáscara, solo visible en la silueta, cuyos vértices se desplazan hacia fuera con el ruido (más arriba que abajo): llamas que lamen hacia fuera,
//   · un fundido con el suelo (el aro brillante de la base es otro nodo: aro_barrera.gdshader).
// Se incluye desde fuego_barrera_atras (caras traseras), fuego_barrera_delante (caras delanteras) y fuego_barrera_lamidos (#define LAMIDOS). Paleta de la bola (rampa).
// Los nombres de los diez mandos de EfectoToy (altura, ancho, blandura, velocidad, brillo, tono, chisporroteo, vida) son los mismos para que se muevan igual.

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.22;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
uniform float transparencia : hint_range(0.2, 1.0) = 0.92;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms texturas;
uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_v : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_fino : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform sampler2D rampa_azul : source_color, filter_linear, repeat_disable;
group_uniforms;

group_uniforms forma;
uniform vec3 semiejes = vec3(1.5, 1.5, 1.5);       // semiejes de la malla (m): pasa de coordenadas de modelo a esfera unitaria
uniform float suelo_y = -0.6;                      // altura del suelo en coordenadas de modelo (m)
uniform vec2 repeticion = vec2(3.0, 1.4);          // repeticiones de las lenguas por vuelta y por meridiano (como las demás figuras: según el tamaño)
uniform vec2 rep_ruido = vec2(5.0, 2.0);
uniform float semilla = 0.0;
uniform float v_base : hint_range(0.0, 0.9) = 0.3;       // (compatibilidad con las escenas de la prueba 3; sin uso)
uniform float borde_pot : hint_range(0.5, 8.0) = 2.0;    // potencia del fresnel del borde (más alto = borde más fino)
uniform float borde_fuerza : hint_range(0.0, 2.0) = 1.4;
uniform float velo : hint_range(0.0, 0.5) = 0.07;       // opacidad del interior sin jirones
uniform float jirones : hint_range(0.0, 1.0) = 0.85;    // opacidad de los jirones de llama del interior
uniform float cobertura : hint_range(0.0, 1.0) = 0.5;    // cuánta superficie cubren los jirones
uniform float lamido_alto : hint_range(0.0, 0.6) = 0.2; // cuánto salen los lamidos (fracción del radio)
uniform float escala_jir : hint_range(0.2, 2.0) = 1.0;    // × la frecuencia de los jirones (menos = corrientes más anchas)
uniform float borde_blanco : hint_range(0.0, 1.0) = 0.0;  // borde más luminoso (amarillo-blanco)
uniform float lam_amplio : hint_range(0.0, 1.0) = 0.0;    // los lamidos salen en más superficie y con más cuerpo
uniform float interior_calor : hint_range(0.0, 1.0) = 0.0; // jirones interiores más calientes (más naranja intenso)
group_uniforms;

varying vec3 dir_o;
varying float h_s;
varying float arriba_o;

void vertex() {
	dir_o = VERTEX / semiejes;
	h_s = VERTEX.y - suelo_y;
	arriba_o = clamp(dir_o.y, -1.0, 1.0);
#ifdef LAMIDOS
	float t = TIME * velocidad;
	float ang = atan(dir_o.z, dir_o.x) / 6.28318;
	float up = smoothstep(-0.25, 0.85, arriba_o);
	vec2 uv1 = vec2(ang * repeticion.x * 2.0 + semilla, dir_o.y * 1.4 - t * 0.55);
	vec2 uv2 = vec2(ang * repeticion.x * 3.0 + 0.37 - semilla, dir_o.y * 2.2 - t * 0.85 + 0.5);
	float n1 = textureLod(ruido_v, uv1, 0.0).r;
	float n2 = textureLod(ruido_v, uv2, 0.0).r;
	float lam = pow(clamp(n1 * 0.6 + n2 * 0.5 - 0.15, 0.0, 1.0), 1.3);
	float fuera = lamido_alto * max(semiejes.x, semiejes.z) * (0.3 + 0.9 * up) * lam * (0.5 + ondulacion);
	VERTEX += NORMAL * fuera;
#endif
	VERTEX.y *= altura;
	VERTEX.xz *= ancho;
}

// muestra triplanar de una textura sobre la esfera unitaria `n` (pesos w): `k` = repeticiones por unidad de arco
float triplanar(sampler2D tex, vec3 n, vec3 w, vec2 k, vec2 mov) {
	float a = texture(tex, vec2(n.z * k.x, n.y * k.y) + mov).r;
	float b = texture(tex, vec2(n.x * k.x + 0.31, n.y * k.y) + mov).r;
	float c = texture(tex, vec2(n.x * k.x + 0.57, n.z * k.x) + mov.yx * 0.5).r;
	return a * w.x + b * w.z + c * w.y;
}

void fragment() {
	float t = TIME * velocidad;
	vec3 n = normalize(dir_o);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 k = vec2(repeticion.x, repeticion.y * 1.6) / 6.28318 * 1.6 * escala_jir;
	// un ruido lento deforma el campo de los jirones (corrientes que se curvan sobre la cúpula)
	float warp = triplanar(ruido_a, n, w, vec2(rep_ruido.x, rep_ruido.y * 1.5) / 6.28318 * 2.0, vec2(semilla * 0.7 + t * 0.05, -t * 0.12)) - 0.5;
	float l = triplanar(ruido_v, n, w, k * 1.1, vec2(t * 0.05 + semilla + warp * 0.9, -t * 0.16 + warp * 1.1));
	float l2 = triplanar(lenguas, n, w, k * 0.9, vec2(-t * 0.07 + 0.43, -t * 0.4 + warp * 0.6 + 0.2));
	float campo = l * 0.8 + l2 * 0.35 + warp * 0.45;
	campo = 0.56 + (campo - 0.56) * 2.8;       // el ruido de nubes tiene poco contraste: se abre alrededor de su media
	float jir = smoothstep(0.78 - cobertura * 0.44, 0.78 - cobertura * 0.44 + blandura * 0.9, campo);
	// fresnel
	vec3 nrm = normalize(NORMAL);
	float cosv = abs(dot(nrm, normalize(VIEW)));
	float fr = pow(1.0 - clamp(cosv, 0.0, 1.0), borde_pot);
	float borde = clamp(fr * borde_fuerza * (0.8 + 0.4 * l), 0.0, 1.0);
	float suelo = smoothstep(0.0, 0.18 * semiejes.y, h_s);
#ifdef LAMIDOS
	// lamidos: lenguas que suben por la silueta, solo donde el borde es fuerte
	float ang2 = atan(dir_o.z, dir_o.x) / 6.28318;
	float up2 = smoothstep(-0.3, 0.8, arriba_o);
	float lt = texture(lenguas, vec2(ang2 * repeticion.x * 2.2 + semilla, dir_o.y * 1.6 - t * 0.7)).r;
	float lt2 = texture(ruido_a, vec2(ang2 * repeticion.x * 3.5 + 0.2, dir_o.y * 2.0 - t * 1.05)).r;
	float tong = smoothstep(0.4, 0.4 + blandura, lt * 0.8 + lt2 * 0.45 - 0.2 + up2 * 0.2);
	float en_silueta = smoothstep(0.35 - 0.3 * lam_amplio, 0.8 - 0.35 * lam_amplio, fr * 1.6);
	float alfa = tong * en_silueta * suelo * (0.35 + 0.65 * up2) * (1.0 + 0.5 * lam_amplio);
	float idx = clamp(0.35 + 0.4 * lt + 0.25 * fr, 0.0, 1.0);
#else
	float idx_j = clamp(0.38 + 0.5 * (campo - 0.5) + 0.25 * fr + 0.18 * interior_calor, 0.0, 1.0);
	float idx_b = clamp(0.62 + 0.38 * smoothstep(0.35, 1.0, borde), 0.0, 1.0);
	float idx = mix(idx_j, idx_b, smoothstep(0.1, 0.7, borde));
	float alfa_int = velo + jirones * jir;
	float alfa = max(alfa_int * (1.0 - 0.4 * borde), borde * 0.95);
	alfa *= suelo;
#endif
	vec3 col = mix(texture(rampa, vec2(idx, 0.5)).rgb, texture(rampa_azul, vec2(idx, 0.5)).rgb, tono);
	float titila = 1.0 + 0.1 * chisporroteo * (sin(TIME * 9.3 + semilla * 31.0) * 0.6 + sin(TIME * 14.1 + semilla * 17.0) * 0.4);
	ALBEDO = col * brillo * titila * (1.0 + (0.4 + 0.5 * borde_blanco) * borde);
#ifndef LAMIDOS
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.86, 0.5) * brillo * titila, borde_blanco * smoothstep(0.5, 1.0, borde) * 0.6);
#endif
	ALPHA = clamp(alfa * transparencia * vida, 0.0, 1.0);
}
