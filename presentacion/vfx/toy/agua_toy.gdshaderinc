// AGUA «TOY» (3/11/2026, rama claude/fuego-toy-carga-impacto, docs/PROPUESTA_AGUA_TOY_2026-11-02.md). Piezas comunes de los shaders de cuerpo del agua (esfera, cintas, ondas):
//   · blend_mix, SIN emisión y SIN luz (los shaders son unshaded): el agua no brilla, solo se ve más o menos clara.
//   · PALETA = la del AGUA DEL MUNDO (agua_render_3d.gd), centralizada en agua_paleta.gd (los defaults de abajo son IGUALES a esas constantes): tono_a = hondo, tono_b = somero, tono_c = espuma,
//     color_causticas, color_lecho y tinte_fresnel. Entre hondo y somero hay BANDAS escalones (como el agua del mundo: floor(x * bandas + 0.5) / bandas); la espuma entra por umbral.
//   · CÁUSTICAS: T_Noise_Wf4 (red de líneas claras) muestreada dos veces en direcciones opuestas y mezclada con un flujo de T_Noise_W5i: la red se mueve y se deshace. Se pintan con color_causticas.
//   · ESPUMA / CRESTA por umbral: el tercer tono solo sale donde el valor pasa del umbral alto (cresta, borde, nudos de la red de cáusticas).
//   · FUNDIDO DE PROFUNDIDAD contra la geometría de detrás (suave_prof, igual que el fuego): sin corte recto contra el suelo o la pared.

uniform sampler2D causticas : filter_linear_mipmap, repeat_enable;     // T_Noise_Wf4
uniform sampler2D flujo : filter_linear_mipmap, repeat_enable;         // T_Noise_W5i
uniform vec3 tono_a : source_color = vec3(0.12, 0.46, 0.50);           // hondo (turquesa del agua del juego con filtro, ver agua_paleta.gd)
uniform vec3 tono_b : source_color = vec3(0.34, 0.74, 0.72);           // somero (turquesa del agua del juego con filtro)
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);            // espuma (color_espuma)
uniform vec3 color_causticas : source_color = vec3(0.66, 0.95, 0.92);
uniform vec3 color_lecho : source_color = vec3(0.07, 0.34, 0.38);
uniform vec3 tinte_fresnel : source_color = vec3(0.88, 0.94, 1.0);
uniform float bandas : hint_range(1.0, 8.0) = 3.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float suave_prof : hint_range(0.0, 3.0) = 0.0;
#define NUCLEO_CON_PROF
#ifdef AGUA_CON_EROSION
#define NUCLEO_CON_EROSION
#ifndef AGUA_ERO_ESCALA
#define AGUA_ERO_ESCALA 3.0
#endif
#endif
#include "res://presentacion/vfx/toy/nucleo_toy.gdshaderinc"      // declara tex_prof y nucleo_prof (y, con AGUA_CON_EROSION, usar_erosion y erosion_alfa3 / erosion_borde3)

// EROSION DEL AGUA (8/11/2026, docs/estudios/VFX_DIAGNOSTICO_2026-11-07.md §8). Un shader la lleva SI define AGUA_CON_EROSION antes de incluir este fichero (y, si quiere otro tiling, AGUA_ERO_ESCALA).
// Los uniforms ero_* se declaran aqui, una vez; cada material puede sobrescribirlos. El shader solo añade: (1) `muerte` = su variable de muerte 0..1 (1 - vida en las bolas; un smoothstep de `corte` /
// `caida` en las figuras que mueren por geometria), (2) `float av = agua_ero_av(muerte)`, (3) agua_fade(...) en el desvanecido por alfa que la erosion sustituye, (4) agua_ero_alfa / agua_ero_tinte
// al final. Garantias: av = 0 -> el alfa sale igual que entra; av = 1 -> sale 0; con VfxKit3D.usar_erosion apagado av = 0 y agua_fade(f) = f, o sea, el shader da EXACTAMENTE lo de antes.
#ifdef AGUA_CON_EROSION
uniform float ero_escala = AGUA_ERO_ESCALA;   // tiling del ruido (por metro, o por el espacio que use el shader)
uniform float ero_dureza = 1.4;               // pow del ruido: mayor = islas y huecos mas marcados
uniform float ero_inicio : hint_range(0.0, 0.9) = 0.15;   // la silueta aguanta hasta que `muerte` pasa de aqui; avance = smoothstep(ero_inicio, 1, muerte)
uniform float ero_brillo = 0.4;               // el filo que se come SUMA ero_brillo * tono_c: conserva el tono
uniform float ero_ancho = 0.35;               // ancho del borde teñido de espuma

float agua_ero_av(float muerte) {
	return usar_erosion ? smoothstep(ero_inicio, 1.0, clamp(muerte, 0.0, 1.0)) : 0.0;
}

// El desvanecido por alfa que la erosion sustituye: con la erosion encendida vale 1 (el efecto no baja de alfa, se come por ruido).
float agua_fade(float f) {
	return usar_erosion ? 1.0 : f;
}

float agua_ero_alfa(float alfa, vec3 pe, float av) {
	return erosion_alfa3(alfa, pe, av, ero_escala, ero_dureza);
}

vec3 agua_ero_tinte(vec3 col, vec3 pe, float av) {
	if (av <= 0.0) {
		return col;
	}
	float bo = erosion_borde3(pe, av, ero_escala, ero_dureza, ero_ancho);
	return mix(col, tono_c, bo) + tono_c * ero_brillo * bo;
}
#endif


// Redondeo a escalones con borde casi duro (como `floor(x * n + 0.5) / n` del agua del mundo, pero con un filo de 0,06 para que no haya dientes de sierra).
float agua_escalon(float x, float n) {
	float f = clamp(x, 0.0, 1.0) * n;
	float i = floor(f);
	return (i + smoothstep(0.44, 0.56, f - i)) / n;
}

// Tres tonos: v decide entre HONDO y SOMERO en `bandas` escalones (u1 = centro del paso de uno a otro) y, por encima de u2, ESPUMA. `suave` = anchura del filo de la espuma.
vec3 agua_tonos(float v, float u1, float u2, float suave) {
	float k = agua_escalon(smoothstep(u1 - 0.18, u1 + 0.30, v), bandas);
	vec3 c = mix(tono_a, tono_b, k);
	return mix(c, tono_c, smoothstep(u2 - suave, u2 + suave, v));
}

// Las cáusticas son redes de luz: se tiñen con color_causticas donde la red es fuerte (`k` = cuánto).
vec3 agua_cau_color(vec3 c, float cau, float k) {
	return mix(c, color_causticas, clamp(smoothstep(0.35, 0.9, cau) * k, 0.0, 1.0));
}

// Borde claro por fresnel (`f` 0..1).
vec3 agua_borde(vec3 c, float f, float k) {
	return mix(c, tinte_fresnel, clamp(f * k, 0.0, 1.0));
}

// Red de cáusticas en 2D que se mueve: dos capas de Wf4 que van en direcciones opuestas, deformadas por el flujo de W5i. Devuelve 0..1 (1 = nudo brillante).
float agua_cau(vec2 uv, float t) {
	vec2 f = (texture(flujo, uv * 0.35 + vec2(t * 0.03, -t * 0.022)).rg - 0.5) * 0.24;
	float a = texture(causticas, uv + f + vec2(t * 0.05, t * 0.032)).r;
	float b = texture(causticas, uv * 1.37 - f + vec2(-t * 0.038, t * 0.052) + 0.41).r;
	return smoothstep(0.10, 0.5, sqrt(a * b));
}

// La misma red proyectada en tres ejes (esfera y volúmenes): `p` = posición en el objeto (≈ 1 en el radio), `n` = su normal en el objeto.
float agua_cau3(vec3 p, vec3 n, float t) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return w.x * agua_cau(p.yz, t) + w.y * agua_cau(p.xz + 0.17, t) + w.z * agua_cau(p.xy + 0.53, t);
}

// 0 pegado a la geometría de detrás, 1 a `dist` m o más. `vz` = VERTEX.z del fragmento.
float agua_prof(vec2 suv, float vz, float dist, mat4 inv_proy) {
	return nucleo_prof(suv, vz, dist, inv_proy);
}
