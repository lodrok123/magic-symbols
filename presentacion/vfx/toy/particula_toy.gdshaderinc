// CUERPO COMÚN de las partículas de la bola en vuelo (ronda 7): los jirones (modo 0, un trozo de la textura de lenguas) y las chispas con estela (modo 1, quad fino
// con la cabeza en el origen de la partícula y la cola hacia atrás). El quad se orienta en pantalla con la velocidad (`vel_dir`, mundo) si `inclin` = 1.
uniform vec3 vel_dir = vec3(0.0, 0.0, -1.0);
uniform float inclin : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.0, 3.0) = 1.2;
uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
varying float semilla_p;

#include "res://presentacion/vfx/toy/nucleo_toy.gdshaderinc"

void vertex() {
	semilla_p = fract(float(INSTANCE_ID) * 0.6180339);
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 vd = (VIEW_MATRIX * vec4(vel_dir, 0.0)).xyz;
	vec2 cola = -normalize(vd.xy + vec2(0.00001, 0.0));
	vec2 e = normalize(mix(vec2(0.0, 1.0), cola, inclin) + vec2(0.00001, 0.0));
	vec2 v = VERTEX.xy;
	if (MODO == 1) {
		v.y += 0.5;
	}
	VERTEX = vec3(v.x * e.y + v.y * e.x, -v.x * e.x + v.y * e.y, 0.0);
	MODELVIEW_MATRIX = nucleo_billboard(vec3(esc.x), VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	float a;
	vec3 col = COLOR.rgb;
	if (MODO == 0) {
		float tex = texture(lenguas, UV * vec2(0.3, 0.45) + vec2(semilla_p, semilla_p * 1.7)).r;
		float forma = 1.0 - length((UV - 0.5) * 2.0);
		a = smoothstep(0.12, 0.45, tex * 1.4 * clamp(forma * 1.6, 0.0, 1.0));
	} else {
		float cabeza = pow(clamp(UV.y, 0.0, 1.0), 2.2);               // 1 en la cabeza (abajo del quad), 0 en la cola
		float fino = pow(clamp(1.0 - abs(UV.x - 0.5) * 2.0, 0.0, 1.0), 1.5);
		a = cabeza * fino;
		col = mix(col, vec3(1.0, 0.9, 0.6), cabeza * 0.6);
	}
	ALBEDO = col * brillo;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
