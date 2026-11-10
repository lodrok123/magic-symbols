shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// ESPUMA / BOCANADAS DE AGUA (fase 3, 3/11/2026: base y cresta del pilar, estallido y bases de las columnas de la explosión de área). Un MultiMesh de quads billboard con whitePuff03 (Kenney, CC0):
// 1 draw call para toda la espuma de un efecto. Instancia: origen = centro, ancho de la base = tamaño (m); INSTANCE_CUSTOM = (opacidad, claridad 0..1, giro en rad, -).
// El gris del borde de la textura se tiñe de celeste (nada de nube gris): el tono sale de la rampa de agua entre celeste y casi blanco. Blend_mix, sin emisión ni luz.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D puff : filter_linear_mipmap, repeat_disable;

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	vec3 centro = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float sz = length(MODEL_MATRIX[0].xyz);
	float cg = cos(datos.z);
	float sg = sin(datos.z);
	vec2 q = vec2(VERTEX.x * cg - VERTEX.y * sg, VERTEX.x * sg + VERTEX.y * cg) * sz;
	VERTEX = centro + vec3(q, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec4 tx = texture(puff, UV);
	float lum = tx.r;
	float k = clamp(0.35 + 0.65 * datos.y * (0.5 + 0.5 * lum), 0.0, 1.0);
	vec3 c = mix(tono_b, tono_c, k);
	ALBEDO = c * brillo;
	ALPHA = clamp(smoothstep(0.12, 0.85, tx.a) * datos.x, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
