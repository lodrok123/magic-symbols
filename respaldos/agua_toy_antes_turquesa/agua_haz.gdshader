shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// HAZ DE AGUA (fase 2, 3/11/2026; referencias ref_agua_haz_a / ref_agua_haz_b). Un chorro que NACE DE UN PUNTO (como el haz de fuego: la malla es FuegoToyMallas.haz_cono, sin modificar), se abre en
// bocanadas hasta una punta redondeada y deshecha. Es una tira a lo largo del eje del haz que el vertex shader GIRA alrededor de ese eje para mirar a la cámara (billboard de eje): volumen desde
// cualquier ángulo, sin borde recto ni en el origen (ancho ~0) ni en la punta.
// Es agua: blend_mix, sin emisión ni luz. TUBO translúcido celeste (tres tonos por umbral) con flujo RÁPIDO hacia fuera (T_Noise_W5i + T_Noise_Wo14), borde más claro y un núcleo más claro (la capa
// «Nucleo» es la misma malla más fina con `nucleo` alto).
//   crece 0 → 1   el chorro sale del origen hasta su largo («nacer»)
//   corte 0 → 1   el chorro se suelta del origen, avanza y se rompe en islas de agua («morir»)
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D flujo2 : filter_linear_mipmap, repeat_enable;     // T_Noise_Wo14
// mandos de EfectoToy (los que no tienen efecto en el haz existen para que _param_mats no falle)
uniform float altura : hint_range(0.3, 3.0) = 1.0;
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.2;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;

uniform float largo = 3.0;
uniform float r_origen = 0.012;
uniform float r_fin = 0.2;
uniform float grosor = 1.0;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float umbral : hint_range(0.0, 1.0) = 0.3;
uniform float desfase = 0.95;
uniform float opacidad = 0.62;
uniform float nucleo = 0.0;              // 0 tubo, 1 núcleo más claro y más fino
uniform float v_chorro = 1.0;

varying float v_p;
varying float v_sc;
varying float v_lat;
varying float v_w;

void vertex() {
	float lat = UV.x * 2.0 - 1.0;
	float s = UV.y * 1.8;
	float desp = corte * 0.6;
	float sc = s - desp;
	float g = max(crece, 0.03);
	float p = sc / g;
	float t = TIME * velocidad * v_chorro;
	float along = sc * largo;
	float boc = textureLod(flujo, vec2(along * 0.28 - t * 0.9 + semilla, semilla * 0.7), 0.0).r;
	float boc2 = textureLod(flujo2, vec2(along * 0.7 - t * 1.6, 0.4 + semilla), 0.0).r;
	float bm = 0.74 + (0.5 * boc + 0.25 * boc2) * (0.5 + ondulacion * 0.55);
	float base = r_origen + (r_fin - r_origen) * pow(clamp(p, 0.0, 1.0), 0.8);
	float w = base * bm * grosor * ancho;
	w *= sqrt(clamp(1.0 - smoothstep(0.8, 1.05, p), 0.0, 1.0));
	w *= mix(1.0, smoothstep(corte * 0.7 - 0.02, corte * 0.7 + 0.22, sc), step(0.001, corte));
	w = mix(w, r_origen * 0.3, step(p, 0.0));
	vec3 c_w = (MODEL_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 eje = normalize((MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	bool orto = PROJECTION_MATRIX[3][3] == 1.0;
	vec3 a_cam = orto ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz - c_w);
	vec3 der = INV_VIEW_MATRIX[0].xyz;
	der = normalize(der - eje * dot(der, eje));
	vec3 lado = cross(eje, a_cam);
	float ll = length(lado);
	lado = ll > 0.0001 ? lado / ll : der;
	lado = normalize(mix(der * sign(dot(der, lado) + 0.00001), lado, smoothstep(0.03, 0.3, ll)));
	vec3 pos = c_w + lado * lat * w;
	VERTEX = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(a_cam, 0.0)).xyz);
	v_p = p;
	v_sc = sc;
	v_lat = lat;
	v_w = max(w, 0.0001);
}

void fragment() {
	float t = TIME * velocidad * v_chorro;
	float d = abs(v_lat);
	float along = v_sc * largo;
	float lat_m = v_lat * v_w;
	float p = v_p;
	// flujo rápido hacia fuera: dos capas a velocidades distintas; los metros laterales son reales (la textura no se estira al ensanchar)
	float a1 = texture(flujo, vec2(lat_m * 1.5 + semilla, -along * 0.42 + t * 1.0)).r;
	float a2 = texture(flujo2, vec2(lat_m * 2.2 + 0.37 + semilla * 0.5, -along * 0.8 + t * 1.9)).r;
	float f = a1 * 0.9 + (a2 - 0.5) * 0.9 * (0.5 + ondulacion) - pow(d, 2.4) * 1.1 + desfase;
	f -= smoothstep(0.5, 1.0, p) * (0.5 + (a2 - 0.4) * 1.0 * chisporroteo) * 1.1;
	f += (1.0 - smoothstep(0.0, 0.3, p)) * 0.7;
	// al cortarse se rompe en islas de agua
	float bola = texture(flujo, vec2(along * 0.8 + semilla, lat_m * 1.6 + t * 0.06 + 0.2)).r;
	f -= corte * 2.4 * (1.0 - smoothstep(0.4, 0.62, bola));
	float a = smoothstep(umbral, umbral + blandura, f);
	a *= smoothstep(0.0, 0.04, p) * (1.0 - smoothstep(0.94, 1.04, p));
	a *= 1.0 - smoothstep(0.78, 1.0, d);
	a *= 1.0 - smoothstep(0.7, 1.0, corte);
	// tonos: azul en el cuerpo, celeste en los hilos que corren, cresta casi blanca en el borde y en el núcleo
	float centro = 1.0 - d;
	float hilos = smoothstep(0.55, 0.9, a2) * 0.28 + smoothstep(0.6, 0.95, a1) * 0.12;
	float v = 0.25 + 0.20 * a1 + hilos + 0.22 * smoothstep(0.62, 1.0, d) * (1.0 - 0.6 * nucleo) + nucleo * (0.16 + 0.26 * centro) + 0.10 * (1.0 - smoothstep(0.0, 0.5, p));
	ALBEDO = agua_tonos(v, 0.44, 0.82, 0.08) * brillo;
	ALPHA = clamp(a * opacidad, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
