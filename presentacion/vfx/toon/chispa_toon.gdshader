// CHISPA TOON (1/11, prueba 2 de VFX §2.4). Rombo amarillo plano y duro, billboard, para GPUParticles3D con QuadMesh. Sin luz. El movimiento a saltos
// de 1/12 s viene de `fixed_fps` de las partículas. `alargado` estiliza el rombo: más estrecho cuanto mayor es (chispa con estela corta).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.89, 0.36, 1.0);
uniform float alargado : hint_range(1.0, 4.0) = 1.8;

void vertex() {
	float s = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz)) * 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	if (abs(p.x) * alargado + abs(p.y) > 0.9) {
		discard;
	}
	ALBEDO = color.rgb;
}
