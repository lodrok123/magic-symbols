shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// FRANJAS DE ESPUMA (fase 4, 3/11/2026: base del géiser). Sustituyen a las bocanadas redondas (whitePuff, «bolas de algodón»): como la espuma del agua del mundo (franjas y bordes por umbral),
// cada franja es un quad TUMBADO en el suelo, largo y estrecho, tangente al borde del charco, cuyo contorno rompe un flujo de T_Noise_W5i: una tira de espuma rasgada, con un filo claro (color_espuma)
// y un cuerpo somero. MultiMesh de quads FACE_Y; instancia: base = (largo, 0, 0) · (0, 1, 0) · (0, 0, ancho); INSTANCE_CUSTOM = (opacidad, claridad 0..1, semilla, -). Sin luz ni emisión.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;                       // x a lo largo de la franja, y a lo ancho
	float t = TIME * velocidad;
	float n = texture(flujo, vec2(UV.x * 1.6 + datos.z, UV.y * 0.9 + t * 0.03)).r;
	float n2 = texture(flujo, vec2(UV.x * 3.4 - t * 0.04, UV.y * 1.7 + datos.z * 0.7 + 0.3)).r;
	float largo_f = 1.0 - pow(abs(p.x), 2.4);         // se afila en los extremos
	float cruz_f = 1.0 - abs(p.y);
	float f = largo_f * cruz_f * 1.7 + (n - 0.5) * 0.8 + (n2 - 0.5) * 0.4 - 0.5;
	float a = smoothstep(0.0, 0.16, f);
	float cuerpo = smoothstep(0.30, 0.9, f);
	vec3 c = mix(tono_b, tono_c, clamp(0.45 + 0.55 * datos.y * (0.35 + 0.65 * (1.0 - cuerpo)), 0.0, 1.0));
	ALBEDO = c * brillo;
	ALPHA = clamp(a * datos.x, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
