// SPRITE DE LE LU RECOLOREADO CON LA RAMPA DE LA BOLA (rama fuego-toy-carga-impacto, 1/11/2026).
// Las texturas de assets/vfx/lelu_noise/ son en escala de grises (o, el flipbook, con color de explosión y humo): aquí solo se usa su FORMA (luminancia o alfa) y su luminancia como
// «temperatura»; el color sale SIEMPRE de la rampa de la bola (FuegoToy._rampa_bola, blanco-amarillo → naranja). El tramo [lo, hi] de la rampa deja fuera su extremo rojo oscuro:
// no puede salir rojo oscuro, ni gris, ni negro. `calor` desplaza la temperatura (se enfría con el tiempo).
// Lo incluyen lelu_sprite_mix.gdshader (mezcla, con prueba de profundidad), lelu_sprite_mix_nd.gdshader (mezcla sin prueba de profundidad) y lelu_sprite_add.gdshader (aditivo, solo destellos).

uniform sampler2D tex : filter_linear, repeat_disable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float usar_alfa : hint_range(0.0, 1.0) = 0.0;     // 1 = la forma es el alfa de la textura (flipbook, briznas); 0 = su luminancia
uniform vec2 recorte = vec2(0.0, 1.0);                    // forma: por debajo de x no hay nada, por encima de y es opaca
uniform vec2 luminancia = vec2(0.0, 1.0);                 // luminancia que se lleva al principio / fin del tramo de la rampa
uniform vec2 tramo = vec2(0.34, 1.0);                     // tramo de la rampa que se usa (0.34 ≈ naranja; sin rojo oscuro)
uniform float calor : hint_range(-1.0, 1.0) = 0.0;
uniform float brillo : hint_range(0.0, 4.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float potencia = 1.0;                             // curva de la forma (>1 afina)
uniform float centro : hint_range(0.0, 1.0) = 0.0;        // 1 = la forma se apaga hacia el borde del quad (mancha de calor)
uniform float giro = 0.0;                                 // radianes: gira la textura alrededor del centro
uniform int billboard : hint_range(0, 1) = 1;             // 1 = mira a la cámara; 0 = fijo en el plano del quad
uniform int fb_cols : hint_range(1, 8) = 1;               // flipbook: columnas, filas y fotograma (con decimales: mezcla dos fotogramas) y último fotograma que se usa
uniform int fb_filas : hint_range(1, 8) = 1;
uniform float fotograma = 0.0;
uniform float fotograma_max = 0.0;

#include "res://presentacion/vfx/toy/nucleo_toy.gdshaderinc"

void vertex() {
	if (billboard == 1) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = nucleo_billboard(esc, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	}
}

vec4 muestra(vec2 uv, float f) {
	int i = int(floor(f));
	vec2 celda = vec2(float(i % fb_cols), float(i / fb_cols));
	vec2 n = vec2(float(fb_cols), float(fb_filas));
	return texture(tex, (celda + clamp(uv, vec2(0.025), vec2(0.975))) / n);
}

vec4 sprite_color(vec2 uv0) {
	vec2 q = uv0 - 0.5;
	float cs = cos(giro);
	float sn = sin(giro);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
	vec2 uv = q + 0.5;
	float dentro = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec4 t = muestra(uv, floor(fotograma));
	if (fb_cols * fb_filas > 1) {
		vec4 t2 = muestra(uv, min(floor(fotograma) + 1.0, fotograma_max));
		t = mix(t, t2, fract(fotograma));
	}
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float forma = mix(lum, t.a, usar_alfa);
	forma = clamp((forma - recorte.x) / max(recorte.y - recorte.x, 0.0001), 0.0, 1.0);
	forma = pow(forma, potencia);
	if (centro > 0.0) {
		forma *= mix(1.0, 1.0 - smoothstep(0.0, 1.0, length(uv0 - 0.5) * 2.0), centro);
	}
	float ln = clamp((lum - luminancia.x) / max(luminancia.y - luminancia.x, 0.0001), 0.0, 1.0);
	float k = clamp(mix(tramo.x, tramo.y, ln) + calor, 0.0, 1.0);
	vec3 c = texture(rampa, vec2(k, 0.5)).rgb * brillo;
	return vec4(c, clamp(forma * vida * dentro, 0.0, 1.0));
}
