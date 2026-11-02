// RAYO «TOY» (2/11/2026, rama claude/b1-hielo-rayo). Piezas comunes de los shaders del rayo (trazos, destellos, suelo):
//   · ADITIVO (blend_add) y unshaded: el rayo es luz, es el único de los elementos nuevos que brilla. Sin escribir profundidad. Única excepción: el CUERPO amarillo del trazo (rayo_trazo_cuerpo.gdshader) va en mezcla normal, porque
//     sumar amarillo a un suelo claro da blanco; el hilo blanco y el halo azul van encima, aditivos.
//   · PALETA = la del RAYO DEL JUEGO (vfx_3d.gd, vfx_estado_3d.gd, emisor_rayo_3d.gd), centralizada en rayo_paleta.gd (los defaults de abajo son IGUALES a esas constantes): hilo blanco, cuerpo amarillo y halo azul.
//   · `vida` apaga el efecto entero; `brillo` lo sube o lo baja.

uniform vec3 color_nucleo : source_color = vec3(1.0, 1.0, 0.90);      // centro blanco (vfx_estado_3d.gd rayo mota)
uniform vec3 color_cuerpo : source_color = vec3(1.0, 0.93, 0.40);      // amarillo (vfx_3d.gd COLOR rayo)
uniform vec3 color_halo : source_color = vec3(0.35, 0.62, 1.0);        // halo azul (vfx_estado_3d.gd rayo c)
uniform vec3 color_borde : source_color = vec3(0.5, 0.82, 1.0);        // borde claro del halo (vfx_3d.gd rayo borde)
uniform vec3 color_hondo : source_color = vec3(0.2, 0.45, 0.95);       // azul profundo del halo (vfx_3d.gd rayo nucleo)
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;

// Color de un punto a distancia `d` (0 = eje, 1 = borde del halo) de un trazo: hilo blanco, cuerpo amarillo y halo azul que se apaga hacia fuera. Devuelve el color aditivo (ya multiplicado por su intensidad).
vec3 rayo_perfil(float d) {
	d = clamp(d, 0.0, 1.0);
	float hilo = 1.0 - smoothstep(0.0, 0.06, d);
	float cuerpo = 1.0 - smoothstep(0.03, 0.4, d);
	float halo = pow(1.0 - d, 1.8) * smoothstep(0.06, 0.4, d);               // el halo azul empieza fuera del cuerpo amarillo: dentro no lo lava a blanco
	vec3 c = color_nucleo * hilo * 0.55 + color_cuerpo * cuerpo * 0.1;
	c += mix(color_hondo, color_halo, smoothstep(0.9, 0.2, d)) * halo * 0.8 + color_borde * halo * 0.12;
	return c;
}
