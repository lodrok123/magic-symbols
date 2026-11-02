shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// TRAZO DE RAYO, capa del CUERPO: el amarillo del rayo del juego (color_cuerpo) en MEZCLA NORMAL, con un centro casi blanco. Es lo único del rayo que no es aditivo: sumar amarillo a un suelo claro da
// blanco, y el rayo del juego es amarillo-blanco con halo azul. Va DEBAJO de rayo_trazo.gdshader (aditivo: hilo blanco y halo azul). Sin emisión y sin luz. Los vértices son los de rayo_trazo.gdshaderinc.
#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"
#include "res://presentacion/vfx/toy/rayo_trazo.gdshaderinc"

void fragment() {
	float d = trazo_d(UV) / max(datos.r, 0.2);
	float cuerpo = 1.0 - smoothstep(0.16, 0.56, d);
	vec3 c = mix(color_cuerpo, color_nucleo, 1.0 - smoothstep(0.0, 0.1, d));
	ALBEDO = c * brillo;
	ALPHA = clamp(cuerpo * 1.1, 0.0, 1.0) * trazo_par() * datos.g * vida;
}
