#[compute]
#version 450
// MODO TOON del haz de gas (9/11/2026, prototipo A de Pablo): la SIMULACION es la del port de lejrimostfa/force-field-vfx-threejs (MIT), pero el DIBUJO es el lenguaje
// aprobado del fuego del juego (presentacion/vfx/toy/fuego_lelu.gdshaderinc + la rampa de la bola de FuegoToy):
//   · no se acumula densidad: se busca la SUPERFICIE del campo de fuego f = T·k_T + combustible·k_c, deformado en el borde con las MISMAS texturas de Le Lu
//     (lenguas, ruido_a, ruido_fino) proyectadas en los planos verticales del dominio, subiendo con el tiempo y arrastradas por la velocidad del gas
//     (mapa de flujo de dos fases, como el agua de los juegos);
//   · opacidad = smoothstep(umbral - blandura/2, umbral + blandura/2, f máximo a lo largo del rayo) (el borde de las lenguas: ni duro ni borroso) · transparencia 0,95;
//   · color = rampa de la bola indexada por (f - umbral) dentro de la superficie (unos centímetros hacia dentro: el centro del chorro sale en el tono claro), con pow(contraste)
//     y cortada en el tope (0,62 = HAZ_TOPE_CALOR de FuegoToy: naranja con contraste, nunca el tramo amarillo);
//   · humo: donde manda el hollin, una franja PARDA PLANA de dos tonos (los del humo del haz y del FuegoToy), con el mismo borde recortado.
// Sin luz por volumenes, sin ACES propio, sin viñeta: sale tal cual al color de la escena del lab (el entorno normal del lab hace su tonemap como con FuegoToy).
// Salida igual que el raymarch realista (rgb premultiplicado, a = lo que queda del fondo) para que compone.glsl no cambie.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#include "gas_comun.glslinc"
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D vel;
layout(set = 0, binding = 2) uniform sampler2D profundidad;
layout(set = 0, binding = 3) uniform sampler2D lenguas;
layout(set = 0, binding = 4) uniform sampler2D ruido_a;
layout(set = 0, binding = 5) uniform sampler2D ruido_fino;
layout(set = 0, binding = 6) uniform sampler2D rampa;
layout(set = 0, binding = 7, rgba16f) uniform restrict writeonly image2D crudo;

#define UMBRAL V.toon0.x
#define BLANDURA V.toon0.y
#define CONTRASTE V.toon0.z
#define TOPE V.toon0.w
#define K_T V.toon1.x
#define K_C V.toon1.y
#define AMP V.toon1.z
#define ESC V.toon1.w
#define UMBRAL_HUMO V.toon2.x
#define OPAC_HUMO V.toon2.y
#define ESC_RAMPA V.toon2.z
#define T_TOON V.toon2.w
#define SUBE V.toon3.x
#define CHISPORROTEO V.toon3.y
#define PROF_COLOR V.toon3.z

// La rampa es una GradientTexture1D de Godot: en el material se lee con source_color (sRGB -> lineal). Aqui llega cruda: se convierte.
vec3 srgb_a_lineal(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }

// Ruido de lenguas en un punto del dominio, desplazado por el gas: dos fases de un mapa de flujo (cada una arrastra las texturas con la velocidad local
// durante medio ciclo y se funde con la otra), mas la subida constante de las lenguas (como en fuego_lelu: suben con el tiempo).
vec3 g_rd = vec3(0.0, 0.0, -1.0);      // el rayo de este pixel: pesa las tres proyecciones (la que se ve de frente manda; nada de vetas estiradas)

// Ruido de un plano: lenguas (verticales en los planos verticales), ruido_a y ruido_fino, como fuego_lelu (l + (r2 - 0,5) * peso - fino * chisporroteo).
float ruido_plano(vec2 a, float sube, float vertical, float semilla) {
	vec2 b = a + vec2(semilla, 0.0);
	float l = vertical > 0.5 ? textureLod(lenguas, vec2(b.x * 0.5, b.y + sube), 0.0).r : textureLod(ruido_a, b * 0.45 + vec2(0.0, sube * 0.2), 0.0).r;
	float r = textureLod(ruido_a, b * 0.8 + vec2(0.13, sube * 0.3), 0.0).r;
	float fi = textureLod(ruido_fino, b * 2.6 + vec2(0.0, sube * 1.8), 0.0).r;
	return 0.6 * l + 0.4 * r - (fi - 0.4) * 0.5 * CHISPORROTEO;
}

float lenguas_en(vec3 p, vec3 u) {
	vec3 uv = clamp(u, vec3(-6.0), vec3(6.0));
	vec3 w = abs(g_rd);
	w = max(w - 0.15, 0.0);
	w /= max(w.x + w.y + w.z, 1e-4);
	float n = 0.0;
	for (int k = 0; k < 2; k++) {
		float fase = fract(T_TOON * 0.6 + float(k) * 0.5);
		float peso = 1.0 - abs(fase * 2.0 - 1.0);
		vec3 q = (p - uv * fase * 0.55) * ESC;
		float sube = T_TOON * SUBE;
		float m = 0.0;
		// planos verticales x-y (se ve mirando por z) y z-y (mirando por x): lenguas que suben; plano x-z (mirando desde arriba): ruido sin dirección
		if (w.z > 0.0) m += w.z * ruido_plano(vec2(q.x, -q.y * 0.55), sube, 1.0, 0.0);
		if (w.x > 0.0) m += w.x * ruido_plano(vec2(q.z, -q.y * 0.55), sube * 1.07, 1.0, 0.37);
		if (w.y > 0.0) m += w.y * ruido_plano(q.xz * 0.8, sube * 0.4, 0.0, 0.71);
		n += peso * m;
	}
	return n;
}

struct Campo { float fuego; float humo; float T; };

Campo campo(vec3 pos) {
	vec3 uvw = (pos - WLO) / WTAM;
	vec4 s = textureLod(gas, uvw, 0.0);
	Campo c;
	c.T = s.x;
	float f = s.x * K_T + s.w * K_C;
	// solo hollin: el polvo de la demo es una capa de 1-3 celdas a ras de suelo y en toon deja ver la rejilla en bloques (queda en el dibujo realista)
	float h = s.y * 1.9;
	c.fuego = f;
	c.humo = h;
	// solo en la franja del borde se gasta en ruido: el interior ya es solido y lo vacio, vacio
	if (abs(f - UMBRAL) < AMP || abs(h - UMBRAL_HUMO) < AMP) {
		float n = lenguas_en(pos, textureLod(vel, uvw, 0.0).xyz) - 0.5;
		c.fuego = f + n * AMP;
		c.humo = h + n * AMP * 0.45;         // el humo, menos roto que la llama (bocanadas planas, como humo_toon)
	}
	return c;
}

void main() {
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	if (gid.x >= int(V.tam.x) || gid.y >= int(V.tam.y)) return;
	vec2 uv = (vec2(gid) + 0.5) / V.tam.xy;
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec4 a4 = V.inv_vp * vec4(ndc, -1.0, 1.0);
	vec4 b4 = V.inv_vp * vec4(ndc, 1.0, 1.0);
	vec3 ro = a4.xyz / a4.w;
	vec3 rd = normalize(b4.xyz / b4.w - ro);
	g_rd = rd;
	vec3 lo = WLO, hi = WLO + WTAM;
	vec3 inv = vec3(1.0) / (rd + vec3(0.00001));
	vec3 t0 = (lo - ro) * inv, t1 = (hi - ro) * inv;
	vec3 mn = min(t0, t1), mx = max(t0, t1);
	float tNear = max(max(max(mn.x, mn.y), mn.z), 0.0);
	float tFar = min(min(mx.x, mx.y), mx.z);
	if (V.marcha.z > 0.5) {
		ivec2 pz = clamp(ivec2(uv * V.tam.zw), ivec2(0), ivec2(V.tam.zw) - 1);
		float d = texelFetch(profundidad, pz, 0).r;
		if (d > 0.0) {
			vec4 h4 = V.inv_vp * vec4(ndc, 1.0 - 2.0 * d, 1.0);
			tFar = min(tFar, dot(h4.xyz / h4.w - ro, rd));
		}
	}
	vec3 color = vec3(0.0);
	float trans = 1.0;
	if (tFar > tNear) {
		// el paso no puede ser más grueso que el chorro: como mucho 1,2 celdas de gas (toon3.w = celda), con tope; si no, los chorros finos salen a trozos
		int pasos = int(V.marcha.x);
		if (V.toon3.w > 0.0) pasos = clamp(int(ceil((tFar - tNear) / (1.2 * V.toon3.w))), pasos, 320);
		float dl = (tFar - tNear) / float(pasos);
		float f_max = -1.0, h_max = -1.0;
		float t_fuego = 1e9, t_humo = 1e9;
		float f_prev = -1.0, t_prev = tNear;
		float f_dentro = -1.0;            // f máximo en los PROF_COLOR m que siguen a la superficie (el color)
		float h_tono = 0.0;
		float t = tNear + dl * 0.5;
		for (int k = 0; k < pasos; k++) {
			vec3 pos = ro + rd * t;
			Campo c = campo(pos);
			if (c.humo > h_max) {
				h_max = c.humo;
			}
			if (t_humo > 1e8 && c.humo > UMBRAL_HUMO && t < t_fuego) {
				t_humo = t;
				// dos tonos planos: el claro arriba (si encima hay menos humo), el oscuro abajo
				h_tono = step(campo(pos + vec3(0.0, 0.35, 0.0)).humo, c.humo - 0.05);
			}
			f_max = max(f_max, c.fuego);
			if (t_fuego > 1e8 && c.fuego > UMBRAL) {
				// biseccion entre el paso anterior y este: la superficie f = umbral
				float a = t_prev, b = t;
				for (int j = 0; j < 5; j++) {
					float m = 0.5 * (a + b);
					if (campo(ro + rd * m).fuego > UMBRAL) b = m; else a = m;
				}
				t_fuego = b;
			}
			if (t_fuego < 1e8 && t <= t_fuego + PROF_COLOR) {
				f_dentro = max(f_dentro, c.fuego);
			}
			if (t_fuego < 1e8 && t > t_fuego + PROF_COLOR) break;     // ya se tiene el color: lo de detrás no se ve (las llamas son opacas)
			f_prev = c.fuego;
			t_prev = t;
			t += dl;
		}
		// FUEGO: el borde de las lenguas de fuego_lelu
		float a_f = smoothstep(UMBRAL - BLANDURA * 0.5, UMBRAL + BLANDURA * 0.5, f_max) * 0.95;
		float fi = max(f_dentro, f_max * step(1e8, t_fuego));
		float idx = clamp((fi - UMBRAL) * ESC_RAMPA, 0.0, 1.0);
		idx = pow(idx, CONTRASTE) * TOPE;
		vec3 c_f = srgb_a_lineal(textureLod(rampa, vec2(idx, 0.5), 0.0).rgb);
		// HUMO: franja parda plana de dos tonos (humo del FuegoToy 0,20 0,10 0,06 y el del haz 0,30 0,15 0,09, en sRGB), borde recortado igual
		float a_h = smoothstep(UMBRAL_HUMO - BLANDURA * 0.5, UMBRAL_HUMO + BLANDURA * 0.5, h_max) * OPAC_HUMO;
		// tonos en sRGB (como los Color() del humo de FuegoToy y del haz) pasados a lineal
		vec3 c_h = srgb_a_lineal(mix(vec3(0.20, 0.10, 0.06), vec3(0.30, 0.15, 0.09), h_tono));
		if (t_humo < t_fuego) {
			// humo delante del fuego: solo tapa la llama donde el hollín MANDA claramente (si no salen manchas de suciedad sobre la llama, que el fuego
			// del juego no tiene); donde la llama es fuerte el humo de delante se queda en un velo
			if (a_f > 0.01) a_h *= mix(0.25, 1.0, smoothstep(0.0, 0.5, (h_max - UMBRAL_HUMO) - (fi - UMBRAL) * 2.0));
			color = c_h * a_h + c_f * a_f * (1.0 - a_h);
		} else {
			color = c_f * a_f + c_h * a_h * (1.0 - a_f);
		}
		trans = (1.0 - a_f) * (1.0 - a_h);
	}
	imageStore(crudo, gid, vec4(color, trans));
}
