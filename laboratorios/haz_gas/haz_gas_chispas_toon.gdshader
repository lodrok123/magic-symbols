// MODO TOON (9/11): las mismas chispas del port, con el color de las chispas del FuegoToy (fuego_toy.gd, haz: (1, 0,5, 0,15) -> (0,95, 0,32, 0,08)), mezcla normal (no aditivas, que sobre el suelo claro del lab se irían a amarillo)
// y un poco más gruesas (se leen como trazos de juguete). Basado en el material de src/render/sparks.js (lejrimostfa/force-field-vfx-threejs, MIT). Quads estirados a lo largo de su movimiento EN PANTALLA (cabeza = posicion,
// cola = posicion - v * 0,028 s), aditivos, color (1, 0.42, 0.1) * (calor^2 * 16 + 0.6). La posicion y la velocidad salen de la imagen de estado del compute (chispas.glsl):
// fila 0 posicion (w vida), fila 1 velocidad (w grosor). Un MultiMesh de N quads; INSTANCE_ID elige la chispa.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D estado : filter_nearest, repeat_disable;
uniform mat4 dominio_a_mundo;

varying float calor;

void vertex() {
	vec4 P = texelFetch(estado, ivec2(INSTANCE_ID, 0), 0);
	vec4 V = texelFetch(estado, ivec2(INSTANCE_ID, 1), 0);
	vec3 cabeza = (dominio_a_mundo * vec4(P.xyz, 1.0)).xyz;
	vec3 cola = (dominio_a_mundo * vec4(P.xyz - V.xyz * 0.028, 1.0)).xyz;
	vec4 a = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cabeza, 1.0));
	vec4 b = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cola, 1.0));
	float along = VERTEX.x + 0.5;
	vec4 clip = mix(a, b, along);
	vec2 na = a.xy / a.w, nb = b.xy / b.w;
	vec2 d = nb - na;
	vec2 dir = d / max(length(d), 0.0001);
	vec2 lado = vec2(-dir.y, dir.x) * VERTEX.y * 0.0034 * (V.w * 0.6 + 0.6);
	clip.xy += lado * clip.w;
	POSITION = clip;
	calor = clamp(P.w / 1.2, 0.0, 1.0);
}

void fragment() {
	// el calor (vida que queda) va del naranja claro de las chispas del FuegoToy al rojo-naranja con que se apagan
	ALBEDO = mix(vec3(0.89, 0.084, 0.007), vec3(1.0, 0.214, 0.019), calor);      // los Color() de la rampa de FuegoToy son sRGB: aquí en lineal
	ALPHA = 0.95;
}
