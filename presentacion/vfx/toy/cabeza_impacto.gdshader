shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled;

// COPIA de cabeza_toy.gdshader SIN prueba de profundidad, para el destello del impacto (si no, la pared o el suelo cortan el disco en un semicírculo). El original no se toca.
// CABEZA DE LA BOLA (ronda 7): masa redonda, compacta y muy brillante en el frente (blanco en el centro, amarillo alrededor, naranja fino en el borde), opaca en el centro,
// con poco ruido en el borde. Un quad con billboard completo y gradiente radial; la cola (fuego_lelu_bola) nace detrás de ella.

uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float transparencia : hint_range(0.2, 1.0) = 1.0;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float tam = 1.0;
uniform float radio = 0.22;
uniform float semilla = 0.0;
uniform sampler2D ruido : hint_default_white, filter_linear, repeat_enable;

void vertex() {
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * esc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * esc.z, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float t = TIME * velocidad;
	vec2 p = (UV - 0.5) * tam;
	float th = atan(p.y, p.x);
	float n = texture(ruido, vec2(cos(th + t * 0.4), sin(th + t * 0.4)) * 0.25 + vec2(0.5 + semilla, 0.5 + t * 0.05)).r;
	float g = length(p) / radio * (1.0 + (n - 0.5) * 0.28 * (0.4 + chisporroteo));
	float a = 1.0 - smoothstep(0.78, 1.0, g);                                 // opaca en el centro, borde fino
	vec3 blanco = vec3(1.0, 0.97, 0.82);
	vec3 amarillo = vec3(1.0, 0.55, 0.12);
	vec3 naranja = vec3(1.0, 0.36, 0.05);
	vec3 col = mix(blanco, amarillo, smoothstep(0.06, 0.2, g));      // ronda 8: anillo amarillo estrecho
	col = mix(col, naranja, smoothstep(0.24, 0.5, g));
	col = mix(col, mix(vec3(0.8, 0.95, 1.0), vec3(0.15, 0.4, 1.0), smoothstep(0.3, 0.95, g)), tono);
	float titila = 1.0 + 0.1 * chisporroteo * (sin(TIME * 11.0 + semilla * 20.0) * 0.6 + sin(TIME * 15.0) * 0.4);
	ALBEDO = col * brillo * titila;
	ALPHA = clamp(a * transparencia * vida, 0.0, 1.0);
}