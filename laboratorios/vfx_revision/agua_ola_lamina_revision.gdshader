shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// LÁMINAS Y-BILLBOARD DE LA OLA (fase 4, 3/11/2026; AguaToy.Figura.MURO). Como el muro de fuego: un MultiMesh de láminas (FuegoToyMallas.quad_vbb: x -0,5..0,5, y 0..1) que GIRAN alrededor del eje vertical
// para mirar a la cámara y están repartidas en varias FILAS DE PROFUNDIDAD, para que de canto (mirando a lo largo de la ola) la ola no sea una raya y para que de frente tenga masa.
//   modo 0  CUERPO: masa de agua translúcida con bandas hondo / somero y el borde de arriba irregular, que sube con `crece`, se inclina y cae con `corte`.
//   modo 1  CRESTA: espuma con la silueta de T_Wave66 (lenguas que apuntan hacia delante, como una cresta que se riza) en lo alto de la ola, curvada y caída hacia delante.
// Instancia: base = (ancho, 0, 0) · (0, alto de la lámina, 0) · (hacia delante, unitario); INSTANCE_CUSTOM = (semilla, retraso 0..1, x local (m), opacidad).
// Sin luz ni emisión, paleta del agua del mundo (agua_paleta.gd).
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"
#include "res://laboratorios/vfx_revision/ola_movimiento.gdshaderinc"

uniform sampler2D liquido : filter_linear_mipmap, repeat_enable;    // T_LiquidVertical_Wave
uniform sampler2D onda66 : filter_linear_mipmap, repeat_disable;    // T_Wave66
uniform int modo = 0;
uniform float a = 3.45;
uniform float alto = 1.5;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float avance = 0.0;
uniform float opacidad = 0.5;
uniform float ritmo = 0.4;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;

varying float v_sem;
varying float v_alfa;
varying float v_fwd;
varying float v_f;
varying float v_h;
varying float v_onda;

float envol(float x, float t, float sem) {
	// 17/11 (Pablo: «no me da sensación de altura»): los extremos caen tarde y poco (antes al 40 % con potencia 4: un lomo) y la cresta ondula ALREDEDOR del alto (antes media 0,86)
	float borde = 1.0 - 0.4 * pow(clamp(abs(x) / max(a, 0.01), 0.0, 1.0), 9.0);
	float n = textureLod(flujo, vec2(x * 0.32 + sem, t * 0.05 + sem * 0.5), 0.0).r;
	return borde * (1.0 + 0.22 * (n - 0.5) * (0.4 + ondulacion) + ola_pulso(x, t) * (1.0 - smoothstep(0.0, 0.5, corte)));
}

void vertex() {
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 hacia = vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z);
	hacia = length(hacia) > 0.001 ? normalize(hacia) : vec3(0.0, 0.0, -1.0);
	v_sem = INSTANCE_CUSTOM.x;
	float dly = INSTANCE_CUSTOM.y;
	float xl = INSTANCE_CUSTOM.z;
	v_alfa = INSTANCE_CUSTOM.w;
	float t = tiempo_ola;
	float rise = ola_subida(xl, a, crece);
	// La misma caída frontal que la cortina; pequeño desfase entre láminas.
	float f2 = clamp(corte * 1.08 - dly * 0.08, 0.0, 1.0);
	float H = alto * rise * envol(xl, t, 0.0);               // altura de la cresta aquí
	float cu = smoothstep(0.45, 1.0, crece);
	vec3 to = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
	float lh = length(to);
	to = lh > 0.001 ? to / lh : vec3(0.0, 0.0, 1.0);
	vec3 der = vec3(to.z, 0.0, -to.x);
	float vy = UV.y;
	float tiembla = sin(t * 2.2 + v_sem * 9.0 + vy * 4.0) * 0.04 * w * vy;
	vec3 base = MODEL_MATRIX[3].xyz + hacia * (avance - ola_desplazamiento(xl, t, corte) * rise);
	float y;
	float fwd_k;
	if (modo == 0) {
		// cuerpo: llega hasta la altura de la ola y se inclina hacia delante al caer
		float y0 = vy * h * (H / max(alto, 0.01));
		vec2 p = ola_colapso(vec2(0.0, y0), H, 0.0, 1.0 - 0.58 * vy, f2);
		y = p.y;
		fwd_k = -p.x;
	} else {
		// cresta: una franja en lo alto (de 0,55 a 1,05 de H) que se riza hacia delante
		float y0 = H * 0.8;                                  // la cresta es una franja ESTRECHA arriba (antes desde 0,58·H: una cúpula blanca que ocupaba media figura)
		// 17/11: la franja va SOBRE la cresta (arranca a 0,84·H y acaba a ras de ella, entre 0,95 y 1,03·H; más arriba eran copos sueltos flotando encima) y la mueve la misma onda viajera de las cabrillas de agua_ola.gdshader: crece y se ve más donde pasa
		float onda = 0.5 + 0.5 * sin(xl * 1.8 - t * 3.6 + 1.5 * sin(xl * 0.6 + t * 0.7));
		v_onda = onda;
		y0 += H * 0.04;
		float hc = h * 0.6 * (H / max(alto, 0.01)) * (0.5 + 0.4 * onda);
		float yy = y0 + vy * hc;
		float rizo = vy * vy * hc * 0.85 * cu;
		vec2 p = ola_colapso(vec2(-rizo, yy - vy * vy * vy * hc * 0.5 * cu), H, 0.0, 0.55 + 0.2 * vy, f2);
		y = p.y;
		fwd_k = -p.x;
	}
	vec3 pos = base + der * ((UV.x - 0.5) * w + tiembla) + vec3(0.0, y, 0.0) + hacia * fwd_k;
	VERTEX = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to, 0.0)).xyz);
	v_fwd = dot(hacia, der);
	v_f = f2;
	v_h = H;
}

float tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

void fragment() {
	float t = tiempo_ola;
	vec2 uv = UV;
	float ex = abs(uv.x - 0.5) * 2.0;
	float ruido = texture(flujo, vec2(uv.x * 1.3 + v_sem * 3.0, uv.y * 0.9 - t * 0.05)).r;
	float a_fin = clamp(smoothstep(0.015, 0.08, v_h) * (1.0 - smoothstep(0.86, 1.0, v_f)), 0.0, 1.0);
	if (modo == 0) {
		vec2 ua = vec2(uv.x * 1.9 + v_sem * 3.0, tri(1.0 - uv.y * 0.45 + t * ritmo + v_sem));       // vetas verticales (17/11), como la cortina
		vec2 ub = vec2(uv.x * 3.3 + 0.4 + v_sem * 5.0, tri(1.0 - uv.y * 0.7 + t * ritmo * 1.5));
		float d1 = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
		float d2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
		float lado = 1.0 - smoothstep(0.55, 1.0, ex + (ruido - 0.5) * 0.35);
		float arriba = 1.0 - smoothstep(0.78, 1.0, uv.y + (ruido - 0.5) * 0.2);
		float pie = smoothstep(0.0, 0.08, uv.y);
		float tira = smoothstep(0.45, 0.8, 0.6 * d1 + 0.4 * d2);
		float espuma = smoothstep(0.93, 0.99, uv.y + (ruido - 0.5) * 0.12) * (0.4 + 0.6 * tira);
		float v = 0.02 + 0.30 * d1 + 0.14 * d2 + 0.32 * uv.y * uv.y + 0.7 * espuma;
		ALBEDO = agua_tonos(v, 0.44, 0.84, 0.07) * brillo;
		ALPHA = clamp(opacidad * (0.7 + 0.3 * d1) * lado * arriba * pie * v_alfa + 0.12 * espuma * lado, 0.0, 0.8) * a_fin * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
	} else {
		// la textura tiene las lenguas hacia la derecha: se vuelve para que apunten hacia delante en pantalla
		vec2 q = uv;
		q.x = v_fwd >= 0.0 ? uv.x : 1.0 - uv.x;
		float m = texture(onda66, vec2(q.x, 1.0 - q.y)).r;
		float rota = smoothstep(0.3, 0.7, m + (ruido - 0.5) * 0.35);
		float nucleo = smoothstep(0.5, 0.9, m + (ruido - 0.5) * 0.2);
		vec3 c = mix(tono_b, tono_c, clamp(0.45 + 0.55 * nucleo, 0.0, 1.0));
		ALBEDO = c * brillo;
		ALPHA = clamp(rota * opacidad * v_alfa * (0.35 + 0.65 * v_onda), 0.0, 0.9) * (1.0 - smoothstep(0.85, 1.0, ex)) * a_fin * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
	}
}

