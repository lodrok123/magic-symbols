shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CRISTAL DE HIELO (los prismas de punta del pilar, el muro, la barrera y el haz; el bloque de la bola; las esquirlas que caen). Translúcido: se ve a través, cada CARA es un escalón de tono
// (hondo / claro / escarcha según su orientación respecto a una luz fija arriba a la izquierda), las ARISTAS se aclaran, el borde se aclara por fresnel y la BASE se blanquea con escarcha.
// Una franja de brillo lento recorre el cristal en vertical (lo único que se mueve al «vivir»). `grieta` (0..1, lo anima «morir») dibuja las grietas de T_Cracks336 antes de romperse. Sin emisión ni luz.
// Malla: COLOR.r = altura 0..1 (0 base, 1 punta), UV = (0..1 a lo ancho de cada cara, 0..1 de la base a la punta).
// Con `instancias` = 1 (MultiMesh) INSTANCE_CUSTOM lleva: r = claridad 0..1, g = opacidad, a = fase de la franja.
#include "res://presentacion/vfx/toy/hielo_toy.gdshaderinc"

uniform sampler2D grietas : filter_linear_mipmap, repeat_enable;      // T_Cracks336
uniform float instancias : hint_range(0.0, 1.0) = 0.0;
uniform float opacidad = 0.68;
uniform float rim_pot = 2.0;
uniform float escarcha_base = 0.55;                                   // cuánto se blanquea la base
uniform float grieta : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;

varying vec4 datos;
varying float altura;

void vertex() {
	datos = instancias > 0.5 ? INSTANCE_CUSTOM : vec4(0.5, 1.0, 0.0, semilla);
	altura = COLOR.r;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
	}
	float nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, rim_pot);
	float cara = clamp(dot(n, normalize(vec3(-0.35, 0.8, 0.5))) * 0.5 + 0.5, 0.0, 1.0);
	float arista = 1.0 - smoothstep(0.0, 0.07, min(UV.x, 1.0 - UV.x));
	float franja = fract(TIME * 0.11 * velocidad + datos.a);
	float barrido = (1.0 - smoothstep(0.0, 0.12, abs(altura - franja * 1.4 + 0.2))) * 0.22;
	float base = (1.0 - smoothstep(0.0, 0.32, altura)) * escarcha_base;
	float v = 0.06 + 0.34 * cara + 0.08 * datos.r + 0.16 * fres + 0.12 * arista + 0.8 * barrido + 0.3 * base;
	vec3 col = hielo_tonos(v, 0.9, 0.05);
	col = mix(col, color_nucleo, 0.42 * pow(nv, 2.0) * (1.0 - base));
	col = mix(col, color_borde, clamp(fres * 0.5 + arista * 0.25, 0.0, 1.0));
	float gr = texture(grietas, UV * vec2(1.1, 0.9) + vec2(datos.a * 3.7, datos.r)).r;
	float linea = grieta * smoothstep(0.35, 0.8, gr);
	col = mix(col, color_grieta, clamp(linea, 0.0, 1.0));
	ALBEDO = col * brillo;
	float a = mix(opacidad, 0.92, fres) + 0.12 * arista + 0.25 * base + 0.3 * linea;
	ALPHA = clamp(a, 0.0, 0.95) * vida * datos.g * hielo_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
