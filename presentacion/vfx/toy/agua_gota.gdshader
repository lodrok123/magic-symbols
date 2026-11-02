shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// GOTAS Y BURBUJAS DE AGUA (MultiMesh movido por la CPU: AguaGotas, ImpactoAguaToy, CargaAguaToy). Un quad por gota que mira a la cámara y se ALARGA en pantalla a lo largo de su velocidad
// (si viene hacia la cámara se queda redonda). Es agua, no luz: blend_mix, sin emisión. Gota = cuerpo azul translúcido con borde claro y un brillo pequeño arriba-izquierda.
// Burbuja = aro claro con el interior casi transparente y un puntito de brillo.
// INSTANCE_CUSTOM: r = claridad 0..1 (0 azul medio, 1 celeste), g = opacidad, b = 1 burbuja, a = reservado.
// En la transformación de la instancia: eje Y = dirección de la velocidad (mundo) × largo, eje X/Z = ancho.

uniform vec3 tono_a : source_color = vec3(0.12, 0.46, 0.50);
uniform vec3 tono_b : source_color = vec3(0.34, 0.74, 0.72);
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);
uniform float brillo : hint_range(0.3, 3.0) = 1.0;

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	vec3 centro = MODELVIEW_MATRIX[3].xyz;
	vec3 yv = (VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz;
	float largo = length(MODEL_MATRIX[1].xyz);
	float ancho = length(MODEL_MATRIX[0].xyz);
	float l3 = max(length(yv), 0.00001);
	vec2 d2 = yv.xy;
	float l2 = length(d2);
	vec2 dir = l2 > 0.00001 ? d2 / l2 : vec2(0.0, 1.0);
	float largo_vis = max(ancho, largo * (l2 / l3));
	vec2 lado = vec2(-dir.y, dir.x);
	vec2 q = vec2(VERTEX.x * ancho, VERTEX.y * largo_vis);          // el quad mide 1 m (de -0,5 a 0,5): ancho y largo completos
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(lado * q.x + dir * q.y, 0.0), 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;      // y = +1 delante (hacia donde va), -1 detrás
	if (datos.b > 0.5) {
		float d = length(p);
		float aro = smoothstep(0.62, 0.92, d) * (1.0 - smoothstep(0.94, 1.0, d));
		float punto = 1.0 - smoothstep(0.0, 0.3, length(p - vec2(-0.36, 0.38)));
		vec3 c = mix(tono_b, tono_c, clamp(aro * 0.8 + punto, 0.0, 1.0)) * brillo;
		float a = clamp(0.16 * (1.0 - step(1.0, d)) + aro * 0.78 + punto * 0.6, 0.0, 0.9);
		ALBEDO = c;
		ALPHA = a * datos.g;
	} else {
		// gota: cabeza redonda delante, cola más fina detrás
		float afila = mix(0.62, 1.0, smoothstep(-1.0, 0.35, p.y));
		vec2 q = vec2(p.x / afila, p.y);
		float d = length(q);
		float cuerpo = 1.0 - smoothstep(0.82, 1.0, d);
		float borde = smoothstep(0.5, 0.9, d);
		float brillito = 1.0 - smoothstep(0.0, 0.34, length(q - vec2(-0.30, 0.34)));
		float v = 0.22 + 0.24 * datos.r + 0.42 * borde + 0.7 * brillito;
		vec3 c = mix(tono_a, tono_b, smoothstep(0.30, 0.55, v));
		c = mix(c, tono_c, smoothstep(0.72, 0.92, v)) * brillo;
		ALBEDO = c;
		ALPHA = clamp(cuerpo * (0.6 + 0.3 * borde + 0.3 * brillito), 0.0, 0.92) * datos.g;
	}
}
