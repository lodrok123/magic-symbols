shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

// ESFERA DE AGUA (cara delantera). Translúcida: el centro deja ver lo de detrás, el borde se aclara por fresnel y el interior lleva la red de cáusticas en movimiento; un núcleo algo más
// claro hacia el centro. Sin emisión ni luz. La cara trasera (agua_esfera_atras.gdshader) va debajo para dar volumen. Ver agua_toy.gdshaderinc.
#define AGUA_CON_EROSION
#define AGUA_ERO_ESCALA 2.5
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform float radio = 0.4;               // radio de la malla en metros (normaliza la posición del objeto)
uniform float esc_cau = 0.7;              // tamaño de la red de cáusticas (mayor = más fina; baja = menos granulosa a la distancia del juego)
uniform float rim_pot = 2.1;             // dureza del borde claro (fresnel)
uniform float opacidad = 0.56;           // opacidad del centro
uniform float nucleo_k = 0.62;           // cuánto más claro es el núcleo
uniform float semilla = 0.0;
uniform float membrana : hint_range(0.0, 1.0) = 0.0;   // 25/11/2026: BARRERA de agua (VFX_SECUENCIA_MEJORAS 19/11 + ef_barrior de Effekseer): FLUJO que sube por la superficie, ESPUMA en el borde de abajo,
                                                        // borde claro más marcado y el centro más claro para ver lo de dentro. 0 = la esfera de siempre (bola)
uniform float gota : hint_range(0.0, 1.0) = 0.0;     // 25/11/2026: en vuelo (AguaToy._forma_vuelo) la mitad de ATRÁS (+Z del objeto) se afila y se alarga en cola de gota; 0 = esfera
uniform float espuma_frente : hint_range(0.0, 1.0) = 0.0;   // en vuelo: espuma blanca suave en el borde delantero (-Z del objeto)

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX / radio;
	if (gota > 0.0 && VERTEX.z > 0.0) {
		float w = clamp(VERTEX.z / radio, 0.0, 1.0);
		VERTEX.xy *= 1.0 - gota * 0.78 * w * w;
		VERTEX.z *= 1.0 + gota * 0.7;
		NORMAL = normalize(NORMAL + vec3(0.0, 0.0, gota * 0.9 * w * length(NORMAL.xy)));      // la cola mira más hacia atrás: el borde claro sigue a la forma
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, rim_pot);
	float t = TIME * velocidad + semilla * 7.0;
	float cau = agua_cau3(p_obj * esc_cau + vec3(semilla), normalize(p_obj), t);
	cau = mix(cau, 0.45, 0.35);                          // cáusticas más suaves: menos contraste, no se vuelven grano a distancia
	float nucleo = pow(nv, 2.4) * nucleo_k;
	// espuma en el borde delantero (solo en vuelo): casi blanca, rota por las cáusticas
	float frente = (1.0 - smoothstep(-0.85, -0.1, normalize(p_obj).z)) * espuma_frente;
	float espuma = frente * smoothstep(0.15, 0.7, 0.45 * cau + 0.7 * fres + 0.25);
	// membrana (barrera): vetas de agua que suben del suelo a la cima siguiendo la cúpula, y espuma en la franja del suelo (p_obj.y ≈ 0: la cúpula nace en el suelo)
	vec3 pn = normalize(p_obj);
	float lon = atan(pn.z, pn.x);
	float linea = smoothstep(0.86, 0.97, sin(lon * 9.0 + 0.9 * sin(pn.y * 4.0 + t * 0.6) + semilla * 3.0) * 0.5 + 0.5);      // líneas finas por los meridianos
	float vetas = linea * smoothstep(0.35, 0.85, sin(pn.y * 7.0 - t * 2.6 + lon * 1.5) * 0.5 + 0.5) * (1.0 - smoothstep(0.7, 0.93, pn.y));      // a trozos que SUBEN; se deshacen antes de la cima
	float pie = 1.0 - smoothstep(0.0, 0.3, pn.y);
	float esp_pie = pie * smoothstep(0.15, 0.55, cau + 0.35 * sin(lon * 13.0 + t * 1.3) + 0.4 * pie);
	espuma = max(espuma, membrana * esp_pie);
	float v = 0.18 + 0.30 * cau + 0.5 * nucleo * (0.55 + 0.45 * cau) + 0.62 * fres + 0.5 * espuma + membrana * 0.32 * vetas;
	vec3 col = agua_tonos(v, 0.40, 0.88, 0.07);
	col = agua_cau_color(col, cau, 0.35);
	col = agua_borde(col, fres, 0.55);
	// con la erosion encendida la esfera no baja de alfa al morir: se COME por ruido (avance = 1 - vida) y el filo se tiñe con la espuma (tono_c)
	float vv = agua_fade(vida);
	float av = agua_ero_av(1.0 - vida);
	vec3 pe = p_obj + vec3(semilla * 13.0);
	ALBEDO = agua_ero_tinte(col, pe, av) * brillo;
	float a = mix(opacidad * (1.0 - 0.45 * membrana), 0.93, fres) + 0.2 * cau * (1.0 - fres) + 0.1 * nucleo + 0.18 * espuma + membrana * (0.22 * vetas + 0.55 * esp_pie);
	ALPHA = agua_ero_alfa(clamp(a, 0.0, 0.94) * vv * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX), pe, av);
}
