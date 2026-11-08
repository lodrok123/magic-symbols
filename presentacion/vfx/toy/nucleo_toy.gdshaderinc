// NUCLEO COMUN DE LOS SHADERS «TOY» (7/11/2026, docs/estudios/VFX_DIAGNOSTICO_2026-11-07.md). Piezas que estaban copiadas en varios shaders:
//   · nucleo_billboard: el cartel que mira a la camara (antes copiado en 9 shaders).
//   · nucleo_prof: fundido por profundidad contra la geometria de detras (antes agua_prof y hielo_prof, identicas). Declara aqui `tex_prof`.
//   · erosion_alfa / erosion_borde: el efecto se CONSUME por ruido en vez de bajar el alfa (la firma de Genshin: _ErodeNoise). Solo lo usan, de momento, las cuatro «bolas»
//     (agua_esfera, fuego_lelu_bola, hielo_cristal, rayo_bola). Con `usar_erosion` apagado (global, ver VfxKit3D.usar_erosion) los shaders dan EXACTAMENTE lo de antes.
//
// Reglas de la erosion: `avance` 0 = intacto (el alfa sale igual que entro) y 1 = consumido del todo (sale 0); monotona entre medias. No tiene reloj propio: el avance es el
// que el shader ya usaba para morir (1 - vida), asi que no cambia CUANDO desaparece, solo COMO.
//
// Opcional (se pide con #define ANTES del #include): NUCLEO_CON_PROF declara `tex_prof` (lo declara el nucleo, no el shader que lo incluye) y trae nucleo_prof;
// NUCLEO_CON_EROSION trae las funciones de erosion y el global `usar_erosion`. Los parametros llevan prefijo n_ para no chocar con los uniforms del shader (ancho, escala...).

// Cartel que mira a la camara. `esc` = escala del objeto por eje (para escala uniforme, vec3(esc.x)). Uso en vertex():
//   vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
//   MODELVIEW_MATRIX = nucleo_billboard(esc, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
mat4 nucleo_billboard(vec3 esc, mat4 vista, mat4 vista_inv, mat4 modelo) {
	return vista * mat4(vec4(vista_inv[0].xyz * esc.x, 0.0), vec4(vista_inv[1].xyz * esc.y, 0.0), vec4(vista_inv[2].xyz * esc.z, 0.0), modelo[3]);
}

#ifdef NUCLEO_CON_PROF
uniform sampler2D tex_prof : hint_depth_texture, repeat_disable, filter_nearest;

// 0 pegado a la geometria de detras, 1 a `dist` m o mas. `vz` = VERTEX.z del fragmento.
float nucleo_prof(vec2 suv, float vz, float dist, mat4 inv_proy) {
	if (dist <= 0.0) {
		return 1.0;
	}
	float dp = texture(tex_prof, suv).r;
	if (dp > 0.00001) {
		vec4 w = inv_proy * vec4(suv * 2.0 - 1.0, dp, 1.0);
		return clamp((-w.z / w.w + vz) / dist, 0.0, 1.0);
	}
	return 1.0;
}
#endif

#ifdef NUCLEO_CON_EROSION
global uniform bool usar_erosion;

float nucleo_hash(vec3 n_p) {
	n_p = fract(n_p * 0.1031);
	n_p += dot(n_p, n_p.zyx + 31.32);
	return fract((n_p.x + n_p.y) * n_p.z);
}

float nucleo_vnoise(vec3 n_p) {
	vec3 n_i = floor(n_p);
	vec3 n_f = fract(n_p);
	n_f = n_f * n_f * (3.0 - 2.0 * n_f);
	float n_a = mix(nucleo_hash(n_i), nucleo_hash(n_i + vec3(1.0, 0.0, 0.0)), n_f.x);
	float n_b = mix(nucleo_hash(n_i + vec3(0.0, 1.0, 0.0)), nucleo_hash(n_i + vec3(1.0, 1.0, 0.0)), n_f.x);
	float n_c = mix(nucleo_hash(n_i + vec3(0.0, 0.0, 1.0)), nucleo_hash(n_i + vec3(1.0, 0.0, 1.0)), n_f.x);
	float n_d = mix(nucleo_hash(n_i + vec3(0.0, 1.0, 1.0)), nucleo_hash(n_i + vec3(1.0, 1.0, 1.0)), n_f.x);
	return mix(mix(n_a, n_b, n_f.y), mix(n_c, n_d, n_f.y), n_f.z);
}

// Ruido 0..1 de dos octavas, ensanchado para que use todo el rango (si no, la erosion no avanzaria de forma pareja) y apretado con `n_dureza` (pow: > 1 = islas y huecos mas marcados).
float nucleo_ruido_ero(vec3 n_p, float n_escala, float n_dureza) {
	n_p *= n_escala;
	float n_r = 0.65 * nucleo_vnoise(n_p) + 0.35 * nucleo_vnoise(n_p * 2.13 + vec3(7.1, 3.7, 1.3));
	return pow(smoothstep(0.22, 0.78, n_r), n_dureza);
}

// Ancho (en unidades de ruido) del filo de la erosion.
const float NUCLEO_ERO_FILO = 0.12;

// Visibilidad 0..1 de un punto con ruido `n_r`. avance 0 -> 1 para todo n_r >= 0; avance 1 -> 0 para todo n_r <= 1.
float nucleo_ero_vis(float n_r, float n_avance) {
	return clamp((n_r - n_avance * (1.0 + NUCLEO_ERO_FILO)) / NUCLEO_ERO_FILO + 1.0, 0.0, 1.0);
}

// Version 3D (esferas: la posicion en el objeto no tiene costura). `n_p` = posicion (o uv) ya con su semilla.
float erosion_alfa3(float n_alfa, vec3 n_p, float n_avance, float n_escala, float n_dureza) {
	if (n_avance <= 0.0) {
		return n_alfa;
	}
	return n_alfa * nucleo_ero_vis(nucleo_ruido_ero(n_p, n_escala, n_dureza), n_avance);
}

float erosion_borde3(vec3 n_p, float n_avance, float n_escala, float n_dureza, float n_ancho) {
	if (n_avance <= 0.0) {
		return 0.0;
	}
	float n_r = nucleo_ruido_ero(n_p, n_escala, n_dureza);
	float n_d = n_r - (n_avance * (1.0 + NUCLEO_ERO_FILO) - NUCLEO_ERO_FILO);     // > 0 = aun hay material; cerca de 0 = el filo que se esta comiendo
	float n_k = (1.0 - smoothstep(0.0, max(n_ancho, 0.001), n_d)) * step(0.0, n_d);
	return n_k * smoothstep(0.0, 0.1, n_avance);                                  // sin avance no hay borde (con avance = 0 todo queda como estaba)
}

// `avance` 0 = intacto, 1 = consumido del todo. Devuelve el alfa ya comido por ruido.
float erosion_alfa(float n_alfa, vec2 n_uv, float n_avance, float n_escala, float n_dureza) {
	return erosion_alfa3(n_alfa, vec3(n_uv, 0.37), n_avance, n_escala, n_dureza);
}

// Lo mismo pero devuelve 0..1 de «cuanto borde de erosion hay aqui», para teñirlo con el extremo caliente de la rampa del elemento.
float erosion_borde(vec2 n_uv, float n_avance, float n_escala, float n_dureza, float n_ancho) {
	return erosion_borde3(vec3(n_uv, 0.37), n_avance, n_escala, n_dureza, n_ancho);
}
#endif
