// DISTORSIÓN DE CALOR (1/11, comparativa de VFX §1.2). Un plano billboard o un cilindro envolvente que desplaza lo que hay detrás
// con un normal map de ruido que sube. Solo Forward+ y Mobile (hint_screen_texture). La máscara radial (UV) lo apaga hacia los bordes.
// Lo que se ve detrás es la pasada OPACA: las llamas (transparentes) se dibujan después, encima; por eso el material lleva render_priority bajo.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D normales : hint_normal, filter_linear, repeat_enable;
uniform float fuerza : hint_range(0.0, 0.2) = 0.012;
uniform float velocidad = 0.6;
uniform float escala = 1.2;
uniform float borde : hint_range(0.0, 0.5) = 0.35;      // anchura del desvanecido radial
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;   // la anima la escena (0 = sin calor)
uniform bool billboard = true;
uniform int mascara = 0;                                 // 0 radial (quad), 1 vertical (cilindro: se apaga arriba y abajo)

void vertex() {
	if (billboard) {
		mat4 mundo = mat4(normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * mundo;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float m;
	if (mascara == 1) {
		float v = UV.y < 0.5 ? UV.y * 2.0 : 1.0;   // CylinderMesh: los lados usan v en [0, 0,5]
		m = smoothstep(0.0, borde, v) * smoothstep(0.0, borde, 1.0 - v);
		m *= pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);   // se apaga hacia la silueta: sin «tubo de cristal»
	} else {
		m = 1.0 - smoothstep(1.0 - borde, 1.0, r);
	}
	m *= intensidad;
	vec2 n = texture(normales, UV * escala + vec2(0.0, -TIME * velocidad)).rg * 2.0 - 1.0;
	vec2 d = n * fuerza * m;
	ALBEDO = texture(pantalla, SCREEN_UV + d).rgb;
	ALPHA = m;   // se funde con el fondo real hacia los bordes: sin escalón visible en el cielo
}
