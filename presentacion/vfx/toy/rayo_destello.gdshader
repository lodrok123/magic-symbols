shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// DESTELLO DEL RAYO (el halo breve de un impacto, el núcleo de la bola, el brillo de los postes y las chispas). Estrella de T_flare8_vfx en billboard, teñida con el perfil del rayo (blanco al centro, amarillo,
// azul fuera). ADITIVO y sin luz. Sirve como MultiMesh (INSTANCE_CUSTOM: r = fuerza de la estrella 0..1 (0 = solo el halo redondo), g = opacidad, b = giro en rad, a = fase) o como MeshInstance3D suelto
// (`instancias` = 0: el tamaño lo da la escala del nodo y el uniform `giro`). El tamaño es el del quad (1 m × escala).
#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform float instancias : hint_range(0.0, 1.0) = 0.0;
uniform float estrella : hint_range(0.0, 1.0) = 0.8;
uniform float giro = 0.0;
uniform float opacidad = 1.0;

varying vec4 datos;

void vertex() {
	datos = instancias > 0.5 ? INSTANCE_CUSTOM : vec4(estrella, 1.0, giro, 0.0);
	vec3 centro = MODELVIEW_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float c = cos(datos.b);
	float sn = sin(datos.b);
	vec2 q = vec2(VERTEX.x * c - VERTEX.y * sn, VERTEX.x * sn + VERTEX.y * c) * s;
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(q, 0.0), 1.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float t = texture(tex, UV).r;
	float redondo = pow(clamp(1.0 - length(p), 0.0, 1.0), 2.2);
	float f = mix(redondo, max(t, redondo * 0.6), datos.r);
	float d = 1.0 - clamp(f, 0.0, 1.0);                                        // 0 en el centro del destello, 1 fuera
	vec3 c = rayo_perfil(d * 0.9) * smoothstep(0.0, 0.18, f);
	ALBEDO = c * brillo * datos.g * opacidad * vida;
}
