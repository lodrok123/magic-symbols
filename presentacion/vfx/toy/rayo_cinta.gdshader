shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

uniform bool descarga = false;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
uniform float fase_descarga = 0.0;

void fragment() {
	float borde = abs(UV.x * 2.0 - 1.0);
	// Las cintas suaves llevan el canal rojo del vértice a cero.
	if (COLOR.r < 0.5) {
		ALBEDO = mix(color_nucleo, color_halo, smoothstep(0.0, 0.62, borde)) * brillo;
		ALPHA = pow(1.0 - smoothstep(0.0, 1.0, borde), 2.0) * COLOR.a * vida;
	} else if (descarga) {
		float centro = 1.0 - smoothstep(0.24, 0.51, borde);
		vec3 borde_calido = mix(color_cuerpo, color_borde, smoothstep(0.56, 0.96, borde) * 0.36);
		vec2 celda = vec2(floor(UV.y * 16.0), floor(TIME * 34.0 * velocidad));
		float pulso = fract(sin(dot(celda, vec2(12.9898, 78.233))) * 43758.5453);
		float reloj = TIME * 9.0 * velocidad + fase_descarga;
		float ritmo = fract(sin(floor(reloj) * 91.73) * 43758.5453);
		float pausa = smoothstep(0.46, 0.72, ritmo) * (1.0 - smoothstep(0.08, 0.31, fract(reloj)));
		float fogonazo = smoothstep(0.18, 0.27, fract(reloj)) * (1.0 - smoothstep(0.27, 0.48, fract(reloj)));
		ALBEDO = mix(borde_calido, color_nucleo, centro) * brillo * mix(1.0, 0.72 + 0.40 * pulso + 0.34 * fogonazo, chisporroteo);
		float visible = 1.0 - pausa * smoothstep(0.0, 0.6, chisporroteo) * 0.76;
		ALPHA = (1.0 - smoothstep(0.23, 0.95, borde)) * COLOR.a * vida * visible;
	} else {
		vec3 tono = mix(color_nucleo, color_cuerpo, smoothstep(0.10, 0.34, borde));
		tono = mix(tono, color_hondo, smoothstep(0.50, 0.67, borde));
		tono = mix(tono, color_halo, smoothstep(0.68, 0.92, borde));
		float pulso = 0.88 + 0.12 * sin(UV.y * 11.0 - TIME * 31.0 * velocidad);
		ALBEDO = tono * brillo * pulso;
		ALPHA = (1.0 - smoothstep(0.72, 1.0, borde)) * COLOR.a * vida;
	}
}
