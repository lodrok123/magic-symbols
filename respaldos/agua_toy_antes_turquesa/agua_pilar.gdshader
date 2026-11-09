shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CORTINA DE AGUA DEL PILAR / GÉISER (fase 3, 3/11/2026). Un tubo abierto (AguaMallas.tubo: UV.x = vuelta, UV.y = 0 en el suelo y 1 en la cresta) cuyo VÉRTICE SHADER hace la columna:
//   · `crece` (0 → ~1,15 → 1) la sube desde el suelo con un pico de altura; `corte` (0 → 1) la DESPLOMA (la altura cae con la gravedad, ~corte²) mientras se ensancha como un chapoteo.
//   · base ensanchada (como si brotara), labio abierto arriba y un balanceo que sube; el borde de arriba es irregular (ruido por vuelta): lenguas, no un corte recto.
// FRAGMENT: T_LiquidVertical_Wave con flujo hacia ARRIBA (dos capas a distinta escala y velocidad), tres tonos por umbral, borde claro por fresnel y espuma en la base y en la cresta. Translúcido
// (blend_mix, sin emisión ni luz). La capa «Nucleo» es la misma malla más fina, más clara y más rápida.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D liquido : filter_linear_mipmap, repeat_enable;    // T_LiquidVertical_Wave
uniform float rx = 0.5;
uniform float rz = 0.5;
uniform float alto = 4.0;
uniform float rep_x = 2.0;               // repeticiones de la textura alrededor
uniform float crece : hint_range(0.0, 1.3) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float grosor = 1.0;
uniform float nucleo = 0.0;
uniform float opacidad = 0.6;
uniform float ritmo = 0.5;               // flujo hacia arriba
uniform float semilla = 0.0;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;

varying float v_a;
varying float v_y;
varying float v_m;
varying float v_top;

void vertex() {
	float a = UV.x;
	float s = UV.y;
	float t = TIME * velocidad;
	float caida = clamp(corte / 0.7, 0.0, 1.0);
	caida *= caida;
	float hh = max(crece, 0.0) * (1.0 - caida);
	float n = textureLod(flujo, vec2(a * 2.0 + semilla, t * 0.12 + semilla), 0.0).r;
	float tope = hh * (1.0 + 0.2 * (n - 0.5)) * alto;
	float y = s * tope;
	float svert = hh * alto;
	float flare = 1.0 + 1.1 * exp(-y * 2.4) * (1.0 - 0.6 * corte);
	float labio = 1.0 + 0.22 * smoothstep(0.82, 1.0, s) + 0.1 * smoothstep(0.55, 0.8, s) * (0.5 + 0.5 * sin(t * 2.0 + a * 6.2832 * 2.0));
	float bal = 1.0 + 0.07 * ondulacion * sin(y * 4.5 - t * 5.0 + a * 12.566 + semilla * 3.0);
	float ensancha = 1.0 + 1.3 * caida;
	float rm = flare * labio * bal * ensancha * grosor;
	float ang = a * 6.2831853;
	VERTEX = vec3(cos(ang) * rx * rm, y, sin(ang) * rz * rm);
	NORMAL = normalize(vec3(cos(ang) / max(rx, 0.01), 0.0, sin(ang) / max(rz, 0.01)));
	v_a = a;
	v_y = s;
	v_m = y;
	v_top = clamp(svert / max(alto, 0.01), 0.0, 1.2);
}

// onda triangular de periodo 2: la textura se refleja en vez de repetirse (sin costura horizontal cada pocos metros)
float tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

void fragment() {
	float t = TIME * velocidad;
	vec2 ua = vec2(v_a * rep_x + semilla, tri(1.0 - v_m * 0.40 + t * ritmo));
	vec2 ub = vec2(v_a * round(rep_x * 1.7) + 0.31 + semilla * 1.3, tri(1.0 - v_m * 0.72 + t * ritmo * 1.6));
	// solo el DETALLE de la textura (sin su degradado de oscuro arriba a claro abajo): la media de la zona se resta
	float d1 = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
	float d2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
	float cau = agua_cau(vec2(v_a * rep_x * 1.3, v_m * 0.5 - t * 0.2) + semilla, t);
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	fres = pow(clamp(fres, 0.0, 1.0), 1.6);
	float base = exp(-v_m * 1.8);
	float cresta = smoothstep(0.80, 0.97, v_y);
	float v = 0.22 + 0.40 * d1 + 0.22 * d2 + 0.08 * cau + 0.30 * fres + 0.20 * base + 0.30 * cresta + nucleo * (0.2 + 0.12 * d1);
	vec3 col = agua_tonos(v, 0.46, 0.82, 0.07);
	col = agua_cau_color(col, cau, 0.3);
	col = agua_borde(col, fres, 0.5);
	ALBEDO = col * brillo;
	float a = opacidad * (0.55 + 0.30 * d1 + 0.30 * fres + 0.25 * base + 0.2 * cresta);
	a *= 1.0 - smoothstep(0.90, 1.0, v_y) * (0.55 + 0.45 * d2);
	a *= smoothstep(0.0, 0.03, v_y);
	a *= 1.0 - smoothstep(0.5, 0.75, corte);
	ALPHA = clamp(a, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
