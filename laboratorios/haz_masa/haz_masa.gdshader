shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix, fog_disabled;

// BOCANADA DE LA MASA DE FUEGO DEL HAZ (prototipo 9/11/2026). Una instancia de MultiMesh = una bocanada (quad billboard) que mueve haz_masa_sim.gd.
// Mismo lenguaje que el fuego del juego (salpicadura_haz / haz_toy): textura de lenguas + ruido, BORDE RECORTADO por umbral (discard, sin alfa blanda), color de la rampa de la bola cortada en naranja
// (nunca amarillo). Cuando la bocanada se enfria y gana hollin se vuelve HUMO pardo oscuro de dos tonos planos (como humo_toon) y se carcome por los bordes al morir.
// INSTANCE_CUSTOM: r = T (1 caliente → 0), g = hollin, b = semilla, a = edad 0..1.

uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float tope_calor : hint_range(0.3, 1.0) = 0.62;
uniform float umbral = 0.26;
uniform float blandura = 0.12;
uniform float velocidad = 1.0;
uniform vec3 color_claro : source_color = vec3(1.0, 0.62, 0.38);
uniform vec3 humo_claro : source_color = vec3(0.22, 0.11, 0.08);
uniform vec3 humo_sombra : source_color = vec3(0.10, 0.06, 0.05);
uniform float brillo : hint_range(0.3, 2.0) = 1.0;

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	float g = (datos.b - 0.5) * 0.9;          // giro suave en pantalla: que no sean todas iguales (las lenguas siguen subiendo)
	float cg = cos(g);
	float sg = sin(g);
	mat4 giro = mat4(vec4(cg, sg, 0.0, 0.0), vec4(-sg, cg, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb * giro * mat4(vec4(esc.x, 0.0, 0.0, 0.0), vec4(0.0, esc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float T = clamp(datos.r, 0.0, 1.4);
	float hollin = clamp(datos.g, 0.0, 1.5);
	float sem = datos.b;
	float edad = datos.a;
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(q);
	float humo = smoothstep(0.12, 0.6, hollin) * (1.0 - smoothstep(0.25, 0.6, T));
	float t = TIME * velocidad * (0.5 + 0.7 * min(T, 1.0));
	// las lenguas suben (el fuego sube); el humo, mas lento y con otro reparto
	vec2 uv = vec2(q.x * 0.8 + sem * 7.0, -q.y * 0.55 + t * 1.1 * (1.0 - 0.6 * humo) + sem * 3.0);
	float l = texture(lenguas, uv * 0.75).r;
	float r2 = texture(ruido_a, vec2(uv.x * 0.6 + 0.37, uv.y * 0.5 + sem * 2.0)).r;
	// la bocanada es una masa redonda con lenguas por el borde (no una estrella): el cuerpo pesa mas que en la salpicadura
	float cuerpo = r;
	float f = l * 0.8 + (r2 - 0.5) * 0.8 + 1.2 - pow(cuerpo, 2.0) * 1.35;
	// el humo se carcome al morir y se pega a pompas mas gordas
	float um = umbral + 0.42 * smoothstep(0.55, 1.0, edad) + 0.05 * humo;
	float a = smoothstep(um, um + blandura, f);
	a *= 1.0 - smoothstep(0.92, 1.0, cuerpo);
	if (a < 0.5) {
		discard;
	}
	float idx = clamp((f - um) * 0.9 + 0.3 * (1.0 - cuerpo), 0.0, 1.0);
	float calor = clamp(T, 0.0, 1.0);
	float k = clamp(idx * tope_calor * (0.4 + 0.75 * calor), 0.0, tope_calor);
	vec3 fuego = texture(rampa, vec2(k, 0.5)).rgb;
	fuego = mix(fuego, color_claro, 0.55 * smoothstep(0.6, 1.0, idx) * smoothstep(0.55, 1.0, calor));
	// humo: dos tonos planos, la sombra abajo a la derecha de cada pompa
	float sombra = step(0.5, smoothstep(0.0, 1.0, (q.y * -0.5 + q.x * 0.35) + 0.5 + (l - 0.5) * 0.3));
	vec3 hum = mix(humo_claro, humo_sombra, sombra);
	float es_fuego = smoothstep(0.04, 0.38, T) * (1.0 - humo * 0.85);
	vec3 col = mix(hum, fuego, es_fuego);
	ALBEDO = col * brillo;
	ALPHA = mix(0.9, 1.0, es_fuego);
}
