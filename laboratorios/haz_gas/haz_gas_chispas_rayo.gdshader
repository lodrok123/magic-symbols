// MODO RAYO (11/11, choque con identidad; Pablo: «en vez de los puntitos del fuego, chispas para el rayo»): las chispas GPU del port (chispas.glsl, basado en
// src/render/sparks.js de lejrimostfa/force-field-vfx-threejs, MIT) dibujadas como CHISPAS ELECTRICAS. El compute las hace rapidas, cortas y con codos (quiebran la
// direccion cada 1/24 s); aqui cada una es un trazo largo (cola = posicion - v · 0,06 s) que ademas se dibuja en ZIGZAG dentro de su quad, con una RAMA corta en
// una de cada tres, PARPADEO (a saltos de 1/30 s) y los colores del rayo de gas: nucleo blanco azulado, cuerpo azul y borde HALO_BORDE (RayoPaleta). Nunca naranja.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D estado : filter_nearest, repeat_disable;
uniform mat4 dominio_a_mundo;
uniform vec3 nucleo : source_color = vec3(0.93, 0.98, 1.0);
uniform vec3 cuerpo : source_color = vec3(0.5, 0.82, 1.0);
uniform vec3 borde : source_color = vec3(0.3, 0.55, 1.0);
uniform int cada = 3;
uniform float ancho = 0.024;        // ancho del quad (NDC): cabe el zigzag

varying float v_along;
varying float v_lado;
varying float v_vida;
varying float v_id;

float h1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	vec4 P = texelFetch(estado, ivec2(INSTANCE_ID, 0), 0);
	vec4 V = texelFetch(estado, ivec2(INSTANCE_ID, 1), 0);
	vec3 cabeza = (dominio_a_mundo * vec4(P.xyz, 1.0)).xyz;
	vec3 cola = (dominio_a_mundo * vec4(P.xyz - V.xyz * 0.06, 1.0)).xyz;
	vec4 a = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cabeza, 1.0));
	vec4 b = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cola, 1.0));
	float along = VERTEX.x + 0.5;
	vec4 clip = mix(a, b, along);
	vec2 na = a.xy / a.w, nb = b.xy / b.w;
	vec2 d = nb - na;
	vec2 dir = d / max(length(d), 0.0001);
	vec2 lado = vec2(-dir.y, dir.x) * VERTEX.y * ancho * (V.w * 0.5 + 0.75);
	clip.xy += lado * clip.w;
	// parpadeo: a saltos de 1/30 s, una de cada cuatro veces la chispa no se ve
	float parpa = h1(float(INSTANCE_ID) * 1.37 + floor(TIME * 30.0) * 0.731);
	if (INSTANCE_ID % max(cada, 1) != 0 || P.w <= 0.0 || P.y < -5.0 || parpa < 0.25) clip = vec4(0.0, 0.0, -2.0, 1.0);
	POSITION = clip;
	v_along = along;
	v_lado = VERTEX.y * 2.0;
	v_vida = clamp(P.w / 0.2, 0.0, 1.0);
	v_id = float(INSTANCE_ID);
}

// zigzag de -1 a 1 (onda triangular) con los vertices al azar por chispa
float zz(float x, float s) {
	float k = floor(x);
	float f = fract(x);
	float y0 = h1(k + s) * 2.0 - 1.0;
	float y1 = h1(k + 1.0 + s) * 2.0 - 1.0;
	return mix(y0, y1, f);
}

void fragment() {
	float s = v_id * 0.173 + floor(TIME * 30.0) * 0.37;       // el dibujo del zigzag tambien salta con el parpadeo
	float punta = smoothstep(0.0, 0.12, v_along) * (1.0 - smoothstep(0.75, 1.0, v_along));   // la cabeza arranca fina y la cola se apaga
	float y = zz(v_along * 3.0, s) * 0.55 * smoothstep(0.0, 0.25, v_along);
	float dist = abs(v_lado - y);
	// rama: una de cada tres chispas suelta, desde su primer codo, un trazo corto hacia un lado
	if (h1(v_id * 0.91) < 0.34 && v_along > 0.33 && v_along < 0.75) {
		float y_r = zz(0.99, s) * 0.55 + (v_along - 0.33) * (h1(v_id * 1.7) < 0.5 ? -2.6 : 2.6);
		dist = min(dist, abs(v_lado - y_r) * 1.25);
	}
	float g = mix(0.75, 1.0, v_vida);
	float c_nucleo = 1.0 - smoothstep(0.07 * g, 0.12 * g, dist);
	float c_cuerpo = 1.0 - smoothstep(0.17 * g, 0.24 * g, dist);
	float c_borde = 1.0 - smoothstep(0.26 * g, 0.36 * g, dist);
	if (c_borde * punta < 0.02) discard;
	ALBEDO = c_nucleo > 0.5 ? nucleo : (c_cuerpo > 0.5 ? cuerpo : borde);
	ALPHA = max(max(c_nucleo, c_cuerpo * 0.95), c_borde * 0.6) * punta;
}
