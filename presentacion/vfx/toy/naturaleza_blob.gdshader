shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// MANCHA BLANDA «toy» de naturaleza (5/11/2026): halo de la bola, estela (una cadena de manchas que se encogen), destello del impacto y anillo del suelo. Dos bandas (núcleo claro y
// cuerpo) con el canto suave: blando tipo Link's Awakening, no un degradado liso. El color y la opacidad los pone la CPU por instancia (COLOR; a = opacidad).
uniform bool cartel = true;                   // true: mira siempre a la cámara (MultiMesh o quad suelto) · false: tal cual (el anillo plano del suelo)
uniform float anillo : hint_range(0.0, 1.0) = 0.0;   // 0 mancha llena · 1 anillo (hueco en el centro)
uniform float nucleo : hint_range(0.0, 1.0) = 0.45;  // lo que ocupa el núcleo claro (0 sin núcleo)
uniform vec3 color_nucleo : source_color = vec3(0.86, 1.0, 0.68);
uniform float blandura : hint_range(0.05, 0.9) = 0.35;
uniform vec4 modulo : source_color = vec4(1.0);      // multiplica el color de instancia (para los quads sueltos, que no llevan color por instancia)
varying vec4 tinte;

void vertex() {
	tinte = COLOR * modulo;
	if (cartel) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * esc.x, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float forma;
	if (anillo > 0.5) {
		forma = smoothstep(1.0, 1.0 - blandura * 0.5, r) * smoothstep(0.62, 0.62 + blandura * 0.5, r);
	} else {
		forma = smoothstep(1.0, 1.0 - blandura, r);
	}
	if (forma <= 0.01 || tinte.a <= 0.01) {
		discard;
	}
	float en_nucleo = (anillo > 0.5) ? 0.0 : smoothstep(nucleo, nucleo - 0.12, r) * step(0.01, nucleo);
	ALBEDO = mix(tinte.rgb, color_nucleo, en_nucleo);
	ALPHA = clamp(forma * tinte.a, 0.0, 1.0);
}
