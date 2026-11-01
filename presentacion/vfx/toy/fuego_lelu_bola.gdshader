shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// BOLA DE FUEGO COMO BILLBOARD (ronda 6 de la prueba 3). El mismo método de Le Lu que en las mallas, pero en 2D sobre un quad que mira siempre a la cámara:
// la textura de lenguas sube por el eje de la llama, un segundo ruido, y en vez del gradiente vertical se RESTA un gradiente RADIAL (distancia al centro de la bola,
// estirada hacia arriba), de modo que la silueta es una gota redonda abajo con lenguas arriba. Sin malla 3D: no hay polos, ni facetas, ni tapas.
// En vuelo (`inclin` = 1) el eje de la llama se alinea en pantalla con la velocidad (`vel_dir`, mundo) y la llama se alarga hacia atrás: la estela.
// Los mandos son los mismos nombres de uniform que fuego_lelu.gdshaderinc, para que EfectoToy los maneje igual.

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.22;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float transparencia : hint_range(0.2, 1.0) = 0.97;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
group_uniforms;

group_uniforms texturas;
uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_fino : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform sampler2D rampa_azul : source_color, filter_linear, repeat_disable;
group_uniforms;

group_uniforms forma;
uniform float tam = 2.4;                          // lado del quad en metros
uniform float radio = 0.52;                        // radio de la bola en metros
uniform float alargado = 0.72;                    // cuánto se estira hacia arriba (menor = más alto)
uniform float alargado_vuelo = 0.16;              // y en vuelo (la estela)
uniform vec2 repeticion = vec2(0.8, 0.65);        // repeticiones de la textura de lenguas por metro
uniform vec2 rep_ruido = vec2(0.7, 0.5);
uniform float giro : hint_range(-1.0, 1.0) = 0.05;
uniform float vel_ruido = 0.55;
uniform float peso_ruido : hint_range(0.0, 1.5) = 0.5;
uniform float peso_abajo : hint_range(0.0, 1.0) = 0.25;   // cuánto manda la textura en la mitad de abajo (poco: silueta redonda)
uniform float pot_grad = 3.2;
uniform float fuerza_grad = 1.2;
uniform float desfase = 0.78;
uniform float umbral : hint_range(0.0, 1.0) = 0.25;
uniform float escala_rampa = 1.0;
uniform float contraste = 1.0;
uniform float calor_extra = 0.32;                 // núcleo claro en el centro
uniform float semilla = 0.0;
uniform float inclin : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vel_dir = vec3(0.0, 0.0, -1.0);
uniform float vida : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

varying vec2 eje;

void vertex() {
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * esc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * esc.z, 0.0), MODEL_MATRIX[3]);
	vec3 vd = (VIEW_MATRIX * vec4(vel_dir, 0.0)).xyz;
	vec2 cola = -normalize(vd.xy + vec2(0.00001, 0.0));
	eje = normalize(mix(vec2(0.0, 1.0), cola, inclin) + vec2(0.00001, 0.0));
}

void fragment() {
	float t = TIME * velocidad;
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * tam;
	vec2 perp = vec2(eje.y, -eje.x);
	float ya = dot(p, eje);
	float xa = dot(p, perp);
	float yy = ya;
	if (yy > 0.0) {
		yy *= mix(alargado, alargado_vuelo, inclin) / altura;
	}
	float g = length(vec2(xa / ancho, yy)) / radio;
	float l = texture(lenguas, vec2(xa * repeticion.x + giro * t + semilla, -ya * repeticion.y + t * 0.35)).r;
	float peso_l = mix(peso_abajo, 1.0, smoothstep(-0.1, 0.35, ya / radio));
	float r2 = texture(ruido_a, vec2(xa * rep_ruido.x - giro * t * 1.7 + 0.37 + semilla * 0.5, -ya * rep_ruido.y + t * vel_ruido)).r;
	float f = l * peso_l + (r2 - 0.5) * peso_ruido * (0.5 + ondulacion) - pow(g, pot_grad) * fuerza_grad + desfase;
	float arriba = smoothstep(0.6, 1.8, ya / radio) * chisporroteo;
	float fino = texture(ruido_fino, vec2(xa * 2.5 + semilla * 3.0, -ya * 1.6 + t * 2.4)).r;
	f -= (fino - 0.4) * 1.1 * arriba;
	float a = smoothstep(umbral, umbral + blandura, f);
	float borde = max(abs(p.x), abs(p.y)) * 2.0 / tam;
	a *= 1.0 - smoothstep(0.82, 1.0, borde);
	float idx = clamp((f - umbral) * escala_rampa + calor_extra * (1.0 - smoothstep(0.0, 0.85, g)), 0.0, 1.0);
	idx = pow(idx, contraste);
	vec3 col = mix(texture(rampa, vec2(idx, 0.5)).rgb, texture(rampa_azul, vec2(idx, 0.5)).rgb, tono);
	float titila = 1.0 + 0.14 * chisporroteo * (sin(TIME * 9.3 + semilla * 31.0) * 0.6 + sin(TIME * 14.1 + semilla * 17.0) * 0.4);
	ALBEDO = col * brillo * titila;
	ALPHA = clamp(a * transparencia * vida, 0.0, 1.0);
}
