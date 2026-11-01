// HUMO TOON (1/11, prueba 2 de VFX §2.3). Para GPUParticles3D con un QuadMesh: una bola redonda de DOS tonos grises azulados (cuerpo y media luna
// de luz arriba a la izquierda), borde duro, billboard. Sin luz. El movimiento se cuantiza con `fixed_fps` de las partículas (12 fps, sin
// interpolar); no hay degradado de alfa: la bola nace, crece y desaparece de golpe cuando muere la partícula.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 tono_cuerpo : source_color = vec4(0.30, 0.34, 0.44, 1.0);   // gris azulado oscuro
uniform vec4 tono_luz : source_color = vec4(0.52, 0.58, 0.68, 1.0);      // gris azulado claro
uniform float luz_radio : hint_range(0.3, 1.2) = 0.78;                    // radio de la media luna respecto a la bola
uniform vec2 luz_desfase = vec2(-0.2, 0.22);                              // hacia dónde se corre el círculo claro (UV de la bola)
uniform float redondez : hint_range(0.5, 1.0) = 0.94;                     // radio de la bola dentro del quad

void vertex() {
	// Billboard conservando la escala de la partícula.
	float s = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz)) * 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	if (length(p) > redondez) {
		discard;
	}
	vec3 col = tono_cuerpo.rgb;
	if (length(p - luz_desfase) < luz_radio * redondez) {
		col = tono_luz.rgb;
	}
	ALBEDO = col;
}
