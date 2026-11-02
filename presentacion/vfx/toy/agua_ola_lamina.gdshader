shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// LÁMINAS Y-BILLBOARD DE LA OLA (fase 4, 3/11/2026; AguaToy.Figura.MURO). Como el muro de fuego: un MultiMesh de láminas (FuegoToyMallas.quad_vbb: x -0,5..0,5, y 0..1) que GIRAN alrededor del eje vertical
// para mirar a la cámara y están repartidas en varias FILAS DE PROFUNDIDAD, para que de canto (mirando a lo largo de la ola) la ola no sea una raya y para que de frente tenga masa.
//   modo 0  CUERPO: masa de agua translúcida con bandas hondo / somero y el borde de arriba irregular, que sube con `crece`, se inclina y cae con `corte`.
//   modo 1  CRESTA: espuma con la silueta de T_Wave66 (lenguas que apuntan hacia delante, como una cresta que se riza) en lo alto de la ola, curvada y caída hacia delante.
// Instancia: base = (ancho, 0, 0) · (0, alto de la lámina, 0) · (hacia delante, unitario); INSTANCE_CUSTOM = (semilla, retraso 0..1, x local (m), opacidad).
// Sin luz ni emisión, paleta del agua del mundo (agua_paleta.gd).
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

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

float envol(float x, float t, float sem) {
	float borde = 1.0 - 0.6 * pow(clamp(abs(x) / max(a, 0.01), 0.0, 1.0), 4.0);
	float n = textureLod(flujo, vec2(x * 0.32 + sem, t * 0.05 + sem * 0.5), 0.0).r;
	return borde * (0.86 + 0.34 * (n - 0.5) * (0.4 + ondulacion));
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
	float t = TIME * velocidad;
	float rise = smoothstep(0.0, 1.0, clamp(crece * 1.25 - dly * 0.25, 0.0, 1.0));
	float f2 = pow(clamp(corte * 1.2 - dly * 0.2, 0.0, 1.0), 1.4);
	float H = alto * rise * envol(xl, t, 0.0);               // altura de la cresta aquí
	float cu = smoothstep(0.45, 1.0, crece);
	vec3 to = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
	float lh = length(to);
	to = lh > 0.001 ? to / lh : vec3(0.0, 0.0, 1.0);
	vec3 der = vec3(to.z, 0.0, -to.x);
	float vy = UV.y;
	float tiembla = sin(t * 2.2 + v_sem * 9.0 + vy * 4.0) * 0.04 * w * vy;
	vec3 base = MODEL_MATRIX[3].xyz + hacia * avance;
	float y;
	float fwd_k;
	if (modo == 0) {
		// cuerpo: llega hasta la altura de la ola y se inclina hacia delante al caer
		y = vy * h * (H / max(alto, 0.01)) * (1.0 - 0.88 * f2);
		fwd_k = f2 * 1.25 * vy * h * (H / max(alto, 0.01));
	} else {
		// cresta: una franja en lo alto (de 0,55 a 1,05 de H) que se riza hacia delante
		float y0 = H * 0.58;
		float hc = h * (H / max(alto, 0.01));
		y = (y0 + vy * hc) * (1.0 - 0.88 * f2);
		fwd_k = f2 * 1.25 * (y0 + vy * hc) + vy * vy * hc * 0.85 * cu;
		y -= vy * vy * vy * hc * 0.5 * cu;
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
	float t = TIME * velocidad;
	vec2 uv = UV;
	float ex = abs(uv.x - 0.5) * 2.0;
	float ruido = texture(flujo, vec2(uv.x * 1.3 + v_sem * 3.0, uv.y * 0.9 - t * 0.05)).r;
	float a_fin = clamp(smoothstep(0.015, 0.08, v_h) * (1.0 - smoothstep(0.7, 1.0, v_f)), 0.0, 1.0);
	if (modo == 0) {
		vec2 ua = vec2(uv.x * 0.8 + v_sem * 3.0, tri(1.0 - uv.y * 0.9 + t * ritmo + v_sem));
		vec2 ub = vec2(uv.x * 1.5 + 0.4 + v_sem * 5.0, tri(1.0 - uv.y * 1.4 + t * ritmo * 1.5));
		float d1 = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
		float d2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
		float lado = 1.0 - smoothstep(0.55, 1.0, ex + (ruido - 0.5) * 0.35);
		float arriba = 1.0 - smoothstep(0.78, 1.0, uv.y + (ruido - 0.5) * 0.2);
		float pie = smoothstep(0.0, 0.08, uv.y);
		float tira = smoothstep(0.45, 0.8, 0.6 * d1 + 0.4 * d2);
		float espuma = smoothstep(0.8, 0.96, uv.y + (ruido - 0.5) * 0.12) * (0.4 + 0.6 * tira);
		float v = 0.04 + 0.30 * d1 + 0.14 * d2 + 0.26 * uv.y + 0.7 * espuma;
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
		ALPHA = clamp(rota * opacidad * v_alfa, 0.0, 0.9) * (1.0 - smoothstep(0.85, 1.0, ex)) * a_fin * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
	}
}
