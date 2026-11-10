#[compute]
#version 450
// MODO TOON DEL AGUA (10/11/2026, item 5 de docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md). La SIMULACION es la del port de lejrimostfa/force-field-vfx-threejs (MIT) en modo
// agua (gas.x = cantidad de agua; ver AGUA en gas_comun.glslinc); el DIBUJO es la variante de raymarch_toon.glsl con el lenguaje del AguaToy (presentacion/vfx/toy/agua_toy.gdshaderinc):
//   · la misma SUPERFICIE: primer punto del rayo con f = agua·k_T > umbral, 5 bisecciones, borde smoothstep(umbral ± blandura/2) deformado en la franja del borde con las texturas
//     del AguaToy (T_Noise_W5i y T_Noise_Wo14 como flujo, en tres planos, arrastradas por la velocidad del gas con un mapa de flujo de dos fases: el agua corre por donde va el gas);
//   · TRES TONOS por umbral (agua_tonos): HONDO / SOMERO en `bandas` escalones casi duros (agua_escalon) y ESPUMA por encima del umbral alto (hilos que corren y borde roto);
//   · CAUSTICAS (T_Noise_Wf4, dos capas opuestas deformadas por el flujo, en tres planos) teñidas con CAUSTICAS; BORDE claro por FRESNEL con la normal del campo (gradiente);
//   · agua: blend_mix, sin emision ni luz; translucida (mas opaca donde es mas gruesa), como el tubo del HAZ del AguaToy.
// Los COLORES no estan escritos aqui: llegan en la textura «paleta» (8 x 1, sRGB) que HazGas hace con AguaPaleta (HONDO, SOMERO, ESPUMA, CAUSTICAS, LECHO, FRESNEL).
// Salida igual que los otros raymarch (rgb premultiplicado, a = lo que queda del fondo): compone.glsl no cambia. Sin humo.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#include "gas_comun.glslinc"
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D vel;
layout(set = 0, binding = 2) uniform sampler2D profundidad;
layout(set = 0, binding = 3) uniform sampler2D flujo;        // T_Noise_W5i
layout(set = 0, binding = 4) uniform sampler2D flujo2;       // T_Noise_Wo14
layout(set = 0, binding = 5) uniform sampler2D causticas;    // T_Noise_Wf4
layout(set = 0, binding = 6) uniform sampler2D paleta;       // AguaPaleta: 0 HONDO, 1 SOMERO, 2 ESPUMA, 3 CAUSTICAS, 4 LECHO, 5 FRESNEL (sRGB)
layout(set = 0, binding = 7, rgba16f) uniform restrict writeonly image2D crudo;

#define UMBRAL V.toon0.x
#define BLANDURA V.toon0.y
#define CONTRASTE V.toon0.z
#define OPAC_MAX V.toon0.w
#define K_T V.toon1.x
#define OPAC_MIN V.toon1.y
#define AMP V.toon1.z
#define ESC V.toon1.w
#define K_CAUSTICAS V.toon2.x
#define K_FRESNEL V.toon2.y
#define ESC_RAMPA V.toon2.z
#define T_TOON V.toon2.w
#define VEL_FLUJO V.toon3.x
#define BANDAS V.toon3.y
#define PROF_COLOR V.toon3.z

vec3 srgb_a_lineal(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 color_paleta(int i) { return srgb_a_lineal(textureLod(paleta, vec2((float(i) + 0.5) / 8.0, 0.5), 0.0).rgb); }

vec3 g_rd = vec3(0.0, 0.0, -1.0);

// agua_toy.gdshaderinc: agua_escalon y agua_tonos (tres tonos por umbral)
float agua_escalon(float x, float n) {
	float f = clamp(x, 0.0, 1.0) * n;
	float i = floor(f);
	return (i + smoothstep(0.44, 0.56, f - i)) / n;
}
vec3 agua_tonos(float v, float u1, float u2, float suave) {
	float k = agua_escalon(smoothstep(u1 - 0.18, u1 + 0.30, v), BANDAS);
	vec3 c = mix(color_paleta(0), color_paleta(1), k);
	return mix(c, color_paleta(2), smoothstep(u2 - suave, u2 + suave, v));
}
// agua_toy.gdshaderinc: agua_cau (red de cáusticas en 2D que se mueve)
float agua_cau(vec2 uv, float t) {
	vec2 f = (textureLod(flujo, uv * 0.35 + vec2(t * 0.03, -t * 0.022), 0.0).rg - 0.5) * 0.24;
	float a = textureLod(causticas, uv + f + vec2(t * 0.05, t * 0.032), 0.0).r;
	float b = textureLod(causticas, uv * 1.37 - f + vec2(-t * 0.038, t * 0.052) + 0.41, 0.0).r;
	return smoothstep(0.10, 0.5, sqrt(a * b));
}

// Pesos de las tres proyecciones por la dirección del rayo (la que se ve de frente manda), como raymarch_toon.
vec3 pesos_rayo() {
	vec3 w = max(abs(g_rd) - 0.15, 0.0);
	return w / max(w.x + w.y + w.z, 1e-4);
}

// Ruido del borde del agua: flujo rápido (como agua_haz.gdshader: dos capas a velocidades distintas) arrastrado por el gas con un mapa de flujo de dos fases.
// Devuelve (ruido del borde, hilos que corren).
vec2 ruido_agua(vec3 p, vec3 u) {
	vec3 uv = clamp(u, vec3(-8.0), vec3(8.0));
	vec3 w = pesos_rayo();
	vec2 n = vec2(0.0);
	for (int k = 0; k < 2; k++) {
		float fase = fract(T_TOON * VEL_FLUJO + float(k) * 0.5);
		float peso = 1.0 - abs(fase * 2.0 - 1.0);
		vec3 q = (p - uv * fase * 0.35) * ESC + float(k) * 0.31;
		vec2 m = vec2(0.0);
		if (w.z > 0.0) m += w.z * vec2(textureLod(flujo, q.xy * 0.6, 0.0).r, textureLod(flujo2, q.xy * 1.1 + 0.37, 0.0).r);
		if (w.x > 0.0) m += w.x * vec2(textureLod(flujo, q.zy * 0.6 + 0.19, 0.0).r, textureLod(flujo2, q.zy * 1.1 + 0.61, 0.0).r);
		if (w.y > 0.0) m += w.y * vec2(textureLod(flujo, q.xz * 0.6 + 0.43, 0.0).r, textureLod(flujo2, q.xz * 1.1 + 0.83, 0.0).r);
		n += peso * m;
	}
	return n;
}

float agua_cru(vec3 pos) { return textureLod(gas, (pos - WLO) / WTAM, 0.0).x * K_T; }

float campo(vec3 pos) {
	vec3 uvw = (pos - WLO) / WTAM;
	float f = textureLod(gas, uvw, 0.0).x * K_T;
	if (abs(f - UMBRAL) < AMP) {
		vec2 n = ruido_agua(pos, textureLod(vel, uvw, 0.0).xyz);
		f += (n.x * 0.9 + (n.y - 0.5) * 0.6 - 0.45) * AMP;
	}
	return f;
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
		int pasos = int(V.marcha.x);
		if (V.toon3.w > 0.0) pasos = clamp(int(ceil((tFar - tNear) / (1.2 * V.toon3.w))), pasos, 320);
		float dl = (tFar - tNear) / float(pasos);
		float f_max = -1.0;
		float t_agua = 1e9;
		float t_prev = tNear;
		float f_dentro = -1.0;
		float t = tNear + dl * 0.5;
		for (int k = 0; k < pasos; k++) {
			vec3 pos = ro + rd * t;
			float f = campo(pos);
			f_max = max(f_max, f);
			if (t_agua > 1e8 && f > UMBRAL) {
				float a = t_prev, b = t;
				for (int j = 0; j < 5; j++) {
					float m = 0.5 * (a + b);
					if (campo(ro + rd * m) > UMBRAL) b = m; else a = m;
				}
				t_agua = b;
			}
			if (t_agua < 1e8 && t <= t_agua + PROF_COLOR) f_dentro = max(f_dentro, f);
			if (t_agua < 1e8 && t > t_agua + PROF_COLOR) break;
			t_prev = t;
			t += dl;
		}
		float a_borde = smoothstep(UMBRAL - BLANDURA * 0.5, UMBRAL + BLANDURA * 0.5, f_max);
		if (a_borde > 0.0) {
			float fi = max(f_dentro, f_max * step(1e8, t_agua));
			float grueso = pow(clamp((fi - UMBRAL) * ESC_RAMPA, 0.0, 1.0), CONTRASTE);
			vec3 ps = ro + rd * min(t_agua, tFar);
			// normal del agua: el gradiente del campo sin ruido (6 lecturas, solo en la superficie)
			float e = max(V.toon3.w, 0.02) * 1.5;
			vec3 gr = vec3(agua_cru(ps + vec3(e, 0, 0)) - agua_cru(ps - vec3(e, 0, 0)), agua_cru(ps + vec3(0, e, 0)) - agua_cru(ps - vec3(0, e, 0)),
				agua_cru(ps + vec3(0, 0, e)) - agua_cru(ps - vec3(0, 0, e)));
			vec3 nrm = length(gr) > 1e-5 ? -normalize(gr) : -rd;
			vec3 u_s = textureLod(vel, (ps - WLO) / WTAM, 0.0).xyz;
			vec2 rn = ruido_agua(ps, u_s);
			// tres tonos: hondo donde el agua es gruesa y quieta, somero en el cuerpo, espuma en los hilos que corren y en el borde roto (como agua_haz: v 0,25..1)
			float hilos = smoothstep(0.55, 0.9, rn.y) * 0.28 + smoothstep(0.6, 0.95, rn.x) * 0.12;
			float v = 0.22 + 0.28 * (1.0 - grueso) + hilos + 0.18 * (1.0 - smoothstep(UMBRAL, UMBRAL + BLANDURA, f_max));
			vec3 c = agua_tonos(v, 0.44, 0.86, 0.06);
			// cáusticas en tres planos (agua_cau3) y borde claro por fresnel (agua_borde)
			vec3 wc = pow(abs(nrm), vec3(4.0));
			wc /= (wc.x + wc.y + wc.z + 0.0001);
			vec3 pc = ps * ESC * 0.9;
			float cau = wc.x * agua_cau(pc.yz, T_TOON) + wc.y * agua_cau(pc.xz + 0.17, T_TOON) + wc.z * agua_cau(pc.xy + 0.53, T_TOON);
			c = mix(c, color_paleta(3), clamp(smoothstep(0.35, 0.9, cau) * K_CAUSTICAS, 0.0, 1.0));
			float fr = pow(1.0 - clamp(abs(dot(nrm, -rd)), 0.0, 1.0), 3.0);
			c = mix(c, color_paleta(5), clamp(fr * K_FRESNEL, 0.0, 1.0));
			float a_f = a_borde * mix(OPAC_MIN, OPAC_MAX, grueso);
			color = c * a_f;
			trans = 1.0 - a_f;
		}
	}
	imageStore(crudo, gid, vec4(color, trans));
}
