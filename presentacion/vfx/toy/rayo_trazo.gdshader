shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// TRAZO DE RAYO, capa ADITIVA: el hilo blanco del centro y el HALO AZUL de fuera (rayo_perfil), más un poco de amarillo. Va ENCIMA de rayo_trazo_cuerpo.gdshader (el cuerpo amarillo en mezcla normal: sobre un
// suelo claro, el amarillo aditivo se lava a blanco, y el rayo del juego es amarillo-blanco con halo azul). ADITIVO y sin luz (es luz). Los vértices son los de rayo_trazo.gdshaderinc.
#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"
#include "res://presentacion/vfx/toy/rayo_trazo.gdshaderinc"

void fragment() {
	float d = trazo_d(UV);
	vec3 c = rayo_perfil(d / max(datos.r, 0.2)) * (1.0 - smoothstep(0.85, 1.0, d));
	ALBEDO = c * brillo * trazo_par() * datos.g * vida;
}
