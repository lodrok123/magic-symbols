shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// Mismo lenguaje del agua del proyecto: paleta central, bandas y causticas LeLu.
// El reloj externo mantiene pausa y retroceso en las texturas y la geometria.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float aparicion : hint_range(0.0, 1.0) = 1.0;
uniform bool corona = false;
uniform float edad = 0.0;
uniform float radio = 0.4;
uniform float deformacion = 0.13;
uniform float cola = 0.0;
uniform float oblicuo = 0.0;
uniform float pared : hint_range(0.0, 1.0) = 0.0;      // 1 = impacto contra pared lateral: lamina pegada y que cae por gravedad
uniform float cabeza : hint_range(0.0, 1.0) = 0.0;     // nucleo claro en el frente durante el vuelo
uniform float destello : hint_range(0.0, 1.0) = 0.0;   // aclarado breve al primer contacto
varying vec3 mundo;
varying vec3 local;
varying vec3 normal_local;

// Puntas verticales del borde de la lamina: dos frecuencias, una ancha y otra fina.
float punta(float a) {
	float p1 = pow(0.5 + 0.5 * sin(a * 9.0 + 1.7 + 1.5 * sin(a * 3.0)), 2.2);
	float p2 = pow(0.5 + 0.5 * sin(a * 13.0 - 0.9 + sin(a * 5.0)), 3.0);
	return p1 * 0.75 + p2 * 0.25;
}

vec3 copa(vec2 uv) {
	float a = uv.x * 6.2831853;
	float v = uv.y;
	float u = clamp(edad / 0.55, 0.0, 1.0);
	float frente = 1.0 + oblicuo * cos(a) * 0.42;
	float lobulo = 0.62 + 0.29 * sin(a * 5.0 + 0.8) + 0.15 * sin(a * 9.0 - 0.3);
	float h = sin(pow(u, 0.65) * 3.1415926) * radio * 1.9;
	float irregular = 1.0 + 0.18 * sin(a * 3.0 + 1.2) + 0.12 * sin(a * 7.0);
	float r = radio * (0.20 + v * (0.55 + 3.5 * u) * irregular * frente);
	float y = h * (sin(v * 3.1415926) * 0.30 + v * v * lobulo) * frente;
	// Picos que se elevan en el borde durante la apertura y se recogen al caer.
	float alza = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 1.0, u));
	y += h * punta(a) * smoothstep(0.45, 1.0, v) * alza * 0.42 * frente * (1.0 - 0.5 * pared);
	r *= 1.0 - 0.04 * punta(a) * smoothstep(0.6, 1.0, v) * alza;
	// Pared lateral: poca separacion, mas extension sobre la pared y el borde se descuelga
	// (la x local es "arriba" en el mundo: la copa va rotada 90 grados).
	y *= mix(1.0, 0.10, pared);
	r *= mix(1.0, 1.0, pared);
	float cae = pared * edad * edad * 1.2 * (0.25 + v);
	return vec3(cos(a) * r - cae, 0.02 + y, sin(a) * r);
}

vec3 masa(vec3 p) {
	p = normalize(p);
	float n = sin(dot(p, vec3(2.8, 1.9, 1.5)) + reloj * 3.0)
		+ 0.55 * sin(dot(p, vec3(-1.7, 3.6, 2.3)) - reloj * 3.8);
	vec3 q = p * (1.0 + n * deformacion);
	// El mismo volumen cerrado forma cabeza y cola; +Z queda detras del vuelo.
	float atras = smoothstep(-0.15, 1.0, p.z);
	q.xy *= 1.0 - min(cola, 1.0) * atras * 0.70;
	q.xy *= 1.0 + sin(p.z * 8.0 - reloj * 9.0) * atras * min(cola, 1.0) * 0.27;
	q.z += cola * pow(max(p.z, 0.0), 1.4);
	q.x += sin(p.z * 4.0 - reloj * 7.0) * atras * cola * 0.10;
	q.y += sin(p.z * 5.0 + reloj * 6.0) * atras * cola * 0.05;
	return q;
}

void vertex() {
	if (corona) {
		VERTEX = copa(UV);
		vec3 da = copa(UV + vec2(0.001, 0.0)) - copa(UV - vec2(0.001, 0.0));
		vec3 dv = copa(UV + vec2(0.0, 0.001)) - copa(UV - vec2(0.0, 0.001));
		NORMAL = normalize(cross(dv, da));
	} else {
		vec3 n = normalize(VERTEX);
		vec3 t = normalize(cross(abs(n.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), n));
		vec3 b = cross(n, t);
		vec3 dt = masa(VERTEX + t * 0.005) - masa(VERTEX - t * 0.005);
		vec3 db = masa(VERTEX + b * 0.005) - masa(VERTEX - b * 0.005);
		NORMAL = normalize(cross(dt, db));
		VERTEX = masa(VERTEX);
	}
	local = VERTEX;
	normal_local = NORMAL;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Las masas usan la cara delantera como agua_esfera; las laminas son dobles.
	if (!corona && !FRONT_FACING) { discard; }
	float onda1 = dot(mundo, vec3(4.0, 3.0, 2.0)) + reloj * 2.4;
	float onda2 = dot(mundo, vec3(-3.0, 2.0, 5.0)) - reloj * 3.1;
	vec3 perturbacion = vec3(cos(onda1) * 0.17, sin(onda2) * 0.09, cos(onda2) * 0.14);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(perturbacion, 0.0)).xyz);
	vec2 uv = clamp(SCREEN_UV + NORMAL.xy * 0.012, vec2(0.001), vec2(0.999));
	float d = texture(tex_prof, uv).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
	// No refractar un objeto opaco situado delante de la superficie.
	if (p.z / p.w > VERTEX.z - 0.015) { uv = SCREEN_UV; }
	vec3 fondo = textureLod(pantalla, uv, 0.0).rgb;
	float nv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - nv, 2.1);
	float nace = smoothstep(0.01, 0.18, aparicion);
	float cau = mix(agua_cau3(local * 0.7, normalize(normal_local), reloj * velocidad), 0.45, 0.30);
	float nucleo = pow(nv, 2.4) * 0.32;
	// Cabeza del vuelo: la cola (+Z local) queda mas oscura, el frente se aclara.
	float frente = smoothstep(0.1, 0.95, -normalize(normal_local).z) * cabeza;
	float claridad = 0.18 + 0.30 * cau + 0.50 * nucleo + 0.30 * fresnel
		+ 0.38 * frente + 0.20 * frente * fresnel + 0.35 * destello;
	vec3 col = agua_tonos(claridad, 0.40, 0.90, 0.07);
	col = agua_cau_color(col, cau, 0.40);
	col = agua_borde(col, fresnel, 0.18);
	// Refraccion discreta: prevalecen los tonos del agua del mundo.
	ALBEDO = mix(col, fondo * mix(color_lecho, tono_b, 0.7), 0.10 * (1.0 - fresnel)) * brillo;
	ALPHA = nace * (0.40 + 0.15 * cau + 0.14 * fresnel + 0.05 * nucleo + 0.18 * frente) * vida;
	ALPHA *= agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
	if (corona) {
		float a = UV.x * 6.2831853;
		float fragmentos = 0.52 + 0.25 * sin(a * 5.0 + UV.y * 9.0) + 0.22 * sin(a * 11.0 - UV.y * 13.0);
		float rotura = smoothstep(0.12, 0.48, edad) * smoothstep(0.25, 1.0, UV.y) * 0.95;
		// Las puntas resisten mas la rotura: se deshacen en gotas al final.
		fragmentos += 0.40 * punta(a) * UV.y;
		ALPHA *= smoothstep(rotura - 0.09, rotura + 0.09, fragmentos);
		ALPHA += 0.10 * destello;
		// Contra pared solo queda un chapoteo breve: el resto es la nube de fragmentos.
		ALPHA *= 1.0 - smoothstep(mix(0.40, 0.14, pared), mix(0.55, 0.26, pared), edad);
	}
}
