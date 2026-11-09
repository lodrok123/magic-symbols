shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

// LUZ DEL HAZ EN EL SUELO (9/11/2026, idea «el fuego ilumina lo que toca» de la demo de gas de three.js). Decal como explosion_suelo.gdshader: una CAJA a lo largo del haz que se proyecta sobre lo
// que haya dentro leyendo la profundidad de la pantalla (sigue los desniveles, sin z-fighting). Una mancha naranja-roja blanda a lo largo del chorro (más estrecha cerca de la mano, más ancha
// y fuerte hacia la punta) y más fuerte en el punto de choque; late con el chorro (crece) y se apaga al soltarse (corte). Colores: rampa de la bola de FuegoToy (nunca amarillo).
// Solo superficies HORIZONTALES (normal reconstruida de la profundidad) y a <= `alto_max` u sobre el suelo del origen del toy: no tiñe los hombros ni la cabeza de la jugadora o los goblins.
// Coordenadas: el toy mira a -Z y su origen es la mano; `u` = metros a lo largo del haz desde la mano, `x` = metros a lo ancho.

uniform sampler2D prof : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform vec3 dim = vec3(3.6, 2.4, 6.0);       // escala de la caja (m)
uniform float centro_u = 3.0;                 // metros a lo largo del haz a los que está el centro de la caja
uniform float largo = 4.0;                    // m del haz
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float fuerza : hint_range(0.0, 1.0) = 0.5;           // opacidad máxima de la mancha a lo largo del chorro
uniform vec4 choque_a = vec4(-1.0, 0.0, 1.2, 0.0);            // (u, x, radio, fuerza); fuerza 0 = sin choque
uniform vec4 choque_b = vec4(-1.0, 0.0, 1.2, 0.0);
uniform float centro_y = 0.4;                                 // m sobre el suelo del centro de la caja
uniform float alto_max = 0.45;
// agua y rayo (9/11): con 	inte.a > 0 la mancha es de ese color fijo (agua: suelo húmedo oscuro, SIN brillo; rayo: destello blanco-azulado) en vez de la rampa del fuego; late 0 = sin latido;
// parpadeo 1 = el punto de choque parpadea a saltos (rayo); destello lo baja el toy para que el destello dure muy poco.
uniform vec4 tinte : source_color = vec4(0.0);
uniform float late : hint_range(0.0, 1.0) = 1.0;
uniform float parpadeo : hint_range(0.0, 1.0) = 0.0;
uniform float destello : hint_range(0.0, 1.0) = 1.0;

vec3 llama(float k) {
	return texture(rampa, vec2(clamp(k, 0.0, 0.7), 0.5)).rgb;
}

float mancha(vec4 c, float u, float x, float pulso) {
	if (c.w <= 0.0) {
		return 0.0;
	}
	vec2 d = vec2(u - c.x, x - c.y) / max(c.z, 0.05);
	return c.w * exp(-dot(d, d) * 1.6) * pulso;
}

void fragment() {
	float d = texture(prof, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	// solo el suelo: si lo que hay en esa profundidad es una pared o un cuerpo no se pinta encima
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
	float x = l.x * dim.x;
	float u = centro_u - l.z * dim.z;                  // la caja está en -Z del toy: +z local = hacia la mano
	float pulso = mix(1.0, 0.82 + 0.12 * sin(TIME * 9.0 + semilla * 6.28 + u * 1.3) + 0.06 * sin(TIME * 15.3 + semilla * 3.0), late);
	float ancho = mix(0.4, 1.0, clamp(u / max(largo, 0.1), 0.0, 1.0));
	float lat = exp(-pow(abs(x) / ancho, 2.0) * 1.3);
	float alcance = crece * largo;
	float lon = smoothstep(-0.3, 0.5, u) * (1.0 - smoothstep(alcance - 0.5, alcance + 0.2, u));
	float a = lat * lon * fuerza * pulso * (0.55 + 0.45 * clamp(u / max(largo, 0.1), 0.0, 1.0));
	float hot = max(mancha(choque_a, u, x, pulso), mancha(choque_b, u, x, pulso)) * smoothstep(0.7, 1.0, crece) * destello;
	hot *= mix(1.0, step(0.45, fract(sin(floor(TIME * 24.0) * 91.7 + semilla * 13.0) * 437.58)), parpadeo);
	a = 1.0 - (1.0 - a) * (1.0 - hot);
	a *= 1.0 - smoothstep(0.05, 0.75, corte);
	// el borde de la caja se desvanece (la mancha nunca acaba en un corte recto)
	a *= (1.0 - smoothstep(0.38, 0.5, abs(l.x))) * (1.0 - smoothstep(0.38, 0.5, abs(l.z)));
	if (tinte.a > 0.0) {
		ALBEDO = tinte.rgb;
		ALPHA = clamp(a * tinte.a, 0.0, 0.9);
	} else {
		ALBEDO = llama(mix(0.0, 0.12, clamp(a * 1.3, 0.0, 1.0)));
		ALPHA = clamp(a, 0.0, 0.9);
	}
}
