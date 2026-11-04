shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_add, fog_disabled;

// SELLO DEL RAYO EN EL SUELO (5/11/2026; referencia en vídeo de Pablo: el «Ultimate» y el «Area of effect» del paquete de rayo ponen un círculo mágico con estrella bajo la descarga). Es un DECAL (como
// explosion_suelo.gdshader): una caja de lado `2 · radio` que se proyecta sobre el terreno leyendo la profundidad, así que sigue los desniveles y no hay z-fighting. Lo que dibuja, todo con líneas finas y
// el perfil del rayo del juego (hilo blanco, cuerpo amarillo y halo azul: rayo_toy.gdshaderinc; no hay paleta nueva): un aro exterior doble, una corona de marcas (dashes irregulares, las «runas»), un aro interior
// y una ESTRELLA de seis puntas (dos triángulos). `aparece` (0 → 1) abre el sello desde el centro, `vida` lo apaga, `giro` lo hace girar y `chispa` (0..1) lo hace parpadear a saltos como el rayo.
#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

uniform sampler2D prof : hint_depth_texture, repeat_disable, filter_nearest;
uniform float aparece : hint_range(0.0, 1.0) = 1.0;
uniform float giro = 0.0;
uniform float chispa : hint_range(0.0, 1.0) = 0.5;
uniform float semilla = 0.0;
uniform float grosor = 0.018;        // grosor de las líneas, en fracción del radio

float hash(float n) {
	return fract(sin(n * 127.1 + semilla * 311.7) * 43758.5453);
}

// distancia de q al segmento a-b
float seg(vec2 q, vec2 a, vec2 b) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	float d = texture(prof, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	vec3 nv = normalize(cross(dFdx(v.xyz), dFdy(v.xyz)));
	if (abs((INV_VIEW_MATRIX * vec4(nv, 0.0)).y) < 0.6) {
		discard;                                  // solo el suelo
	}
	vec3 mundo = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec3 l = (inverse(MODEL_MATRIX) * vec4(mundo, 1.0)).xyz;
	if (abs(l.x) > 0.5 || abs(l.y) > 0.5 || abs(l.z) > 0.5) {
		discard;
	}
	vec2 q = l.xz * 2.0;                          // radio normalizado: 1 a `radio` u del centro
	float rn = length(q);
	if (rn > 1.0) {
		discard;
	}
	float c = cos(giro);
	float s = sin(giro);
	vec2 p = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
	float ang = atan(p.y, p.x);
	float ab = aparece;
	float g = grosor;

	// aros: exterior doble, el de las marcas y el interior
	float dm = 1e3;
	dm = min(dm, abs(rn - 0.97));
	dm = min(dm, abs(rn - 0.90) * 1.6);
	dm = min(dm, abs(rn - 0.66) * 1.4);
	dm = min(dm, abs(rn - 0.18) * 1.2);

	// corona de marcas entre 0,72 y 0,86: 28 casillas, cada una un dash de largo irregular (las runas)
	float celdas = 28.0;
	float k = floor((ang / 6.2831853 + 0.5) * celdas);
	float f = fract((ang / 6.2831853 + 0.5) * celdas);
	float alto = 0.72 + 0.14 * hash(k + 1.0);
	float ancho_m = 0.25 + 0.5 * hash(k + 7.0);
	float en_marca = step(0.35, hash(k + 3.0));
	float dmar = max(abs(f - 0.5) - ancho_m * 0.5, 0.0) * 0.14 + max(max(0.72 - rn, rn - alto), 0.0);
	dm = min(dm, mix(1e3, dmar, en_marca));

	// estrella de seis puntas (dos triángulos de circunradio 0,66)
	float R = 0.66;
	float de = 1e3;
	for (int i = 0; i < 3; i++) {
		float a0 = 1.5707963 + 2.0943951 * float(i);
		float a1 = a0 + 2.0943951;
		vec2 A = vec2(cos(a0), sin(a0)) * R;
		vec2 B = vec2(cos(a1), sin(a1)) * R;
		de = min(de, seg(p, A, B));
		vec2 A2 = -A;
		vec2 B2 = -B;
		de = min(de, seg(p, A2, B2));
	}
	dm = min(dm, de);

	float u = dm / g;
	// el sello se abre del centro al borde con `aparece`
	float abre = 1.0 - smoothstep(ab - 0.15, ab, rn);
	// parpadeo a saltos (rayo): 12 cambios por segundo
	float salto = floor(TIME * 12.0);
	float par = mix(1.0, 0.45 + 0.55 * hash(salto), chispa);
	vec3 col = rayo_perfil(clamp(u / 9.0, 0.0, 1.0));
	float vis = (1.0 - smoothstep(0.0, 1.0, u / 9.0)) * abre;
	ALBEDO = col * brillo * 1.8 * par * vida * vis;
	ALPHA = 1.0;
}
