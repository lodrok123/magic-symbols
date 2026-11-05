shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

// DECAL DE FUEGO EN EL SUELO (4/11/2026, explosión del barril). Se pone en una CAJA de lado `2 · radio` (x y z) que se proyecta sobre lo que haya dentro, leyendo la profundidad de la pantalla:
// así el círculo sigue el terreno aunque haya desniveles y no hay z-fighting (no es un plano sobre el suelo). El radio normalizado `rn` vale 1 EXACTAMENTE a `radio` u del centro.
// Dos usos, los dos con la rampa de la bola de FuegoToy (rojo → naranja; el tramo alto casi no se usa, nunca amarillo):
//   · AVISO de la mecha: borde nítido a `radio`, relleno que crece del centro al borde (`llenado`) y late (`latido`).
//   · ONDA al explotar: anillo cuyo frente llega a `radio` cuando `onda` = 1, y un resplandor del suelo que se apaga (`calor`).

uniform sampler2D prof : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float aviso : hint_range(0.0, 1.0) = 0.0;       // opacidad del aviso (0 = apagado)
uniform float llenado : hint_range(0.0, 1.0) = 0.0;     // lo que se ha consumido de la mecha
uniform float latido : hint_range(0.0, 1.0) = 0.0;      // 0..1, lo calcula el script (su ritmo sube con la mecha)
uniform float onda = -1.0;                              // radio normalizado del frente de la onda; < 0 = sin onda
uniform float onda_vida : hint_range(0.0, 1.0) = 0.0;
uniform float calor : hint_range(0.0, 1.0) = 0.0;       // resplandor del suelo tras la explosión
uniform float semilla = 0.0;
// 5/11 (integración): solo se pinta lo que está a <= `alto_max` u sobre el suelo del centro (el origen del aviso, `centro_y` u por debajo del centro de la caja).
// Así no tiñe los hombros ni la cabeza de la jugadora o de los goblins que estén dentro (también miran hacia arriba). Lo más bajo (una terraza de debajo) sí se pinta.
uniform float centro_y = 0.4;
uniform float alto_max = 0.45;

vec3 llama(float k) {
	return texture(rampa, vec2(clamp(k, 0.0, 0.85), 0.5)).rgb;
}

void fragment() {
	float d = texture(prof, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	// solo el suelo: si lo que hay en esa profundidad es una pared (barril, cuerpos, troncos) no se pinta encima
	vec3 nv = normalize(cross(dFdx(v.xyz), dFdy(v.xyz)));
	if (abs((INV_VIEW_MATRIX * vec4(nv, 0.0)).y) < 0.6) {
		discard;
	}
	vec3 mundo = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	if (mundo.y - (MODEL_MATRIX[3].y - centro_y) > alto_max) {
		discard;
	}
	vec3 l = (inverse(MODEL_MATRIX) * vec4(mundo, 1.0)).xyz;
	if (abs(l.x) > 0.5 || abs(l.y) > 0.5 || abs(l.z) > 0.5) {
		discard;
	}
	vec2 q = l.xz * 2.0;
	float rn = length(q);
	if (rn > 1.0) {
		discard;
	}
	float ang = atan(q.y, q.x);
	// lamidos suaves del borde del relleno (fuego blando, no una línea técnica)
	float lam = 1.0 + 0.035 * sin(ang * 5.0 + TIME * 3.0 + semilla * 6.28) + 0.025 * sin(ang * 9.0 - TIME * 4.5 + semilla * 3.0);
	float ru = rn * lam;
	vec3 col = vec3(0.0);
	float a = 0.0;

	if (aviso > 0.0) {
		float frente = llenado * 0.97;
		float relleno = 1.0 - smoothstep(frente - 0.12, frente, ru);
		float cuerpo = relleno * (0.24 + 0.3 * llenado) * (0.72 + 0.28 * latido);
		float base = (1.0 - smoothstep(0.0, 1.0, rn)) * 0.09 + 0.06;           // el área entera se insinúa desde el principio
		float borde = smoothstep(0.9, 0.955, rn) * (1.0 - smoothstep(0.985, 0.998, rn));
		float a_borde = borde * (0.5 + 0.4 * latido) ;
		float a_rel = clamp(cuerpo + base, 0.0, 1.0);
		float k_rel = mix(0.2, 0.5, llenado) + 0.1 * pow(1.0 - rn, 1.5) * llenado;
		vec3 c_rel = llama(k_rel);
		vec3 c_borde = llama(0.3 + 0.2 * latido + 0.1 * llenado);
		float at = 1.0 - (1.0 - a_rel) * (1.0 - a_borde);
		col = (c_rel * a_rel * (1.0 - a_borde) + c_borde * a_borde) / max(at, 0.0001);
		a = at * aviso;
	}

	if (onda >= 0.0 || calor > 0.0) {
		float brillo_suelo = calor * pow(1.0 - rn, 1.3) * 0.55;
		float ring = 0.0;
		if (onda >= 0.0) {
			// frente nítido en `onda`, cola que se apaga hacia dentro
			ring = smoothstep(onda - 0.22, onda - 0.015, rn) * (1.0 - smoothstep(onda - 0.015, onda, rn));
			ring *= onda_vida;
		}
		float a_o = clamp(max(brillo_suelo, ring * 0.85), 0.0, 1.0);
		vec3 c_o = llama(mix(0.1, 0.5, clamp(ring * 0.6 + brillo_suelo, 0.0, 1.0)));
		float at2 = 1.0 - (1.0 - a) * (1.0 - a_o);
		col = (col * a * (1.0 - a_o) + c_o * a_o) / max(at2, 0.0001);
		a = at2;
	}
	ALBEDO = col;
	ALPHA = a;
}
