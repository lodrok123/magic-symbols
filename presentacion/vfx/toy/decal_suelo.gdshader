shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, cull_back, unshaded, fog_disabled;
// `cull_back` y no `cull_front`: con la cámara FUERA de la caja hay que pintar sus caras de delante, que quedan por encima del suelo y pasan la prueba de profundidad; con las de
// detrás el suelo las tapa y no se ve nada (probado el 7/11: no se dibujaba). `depth_draw_never` para que la caja no tape a nadie.

// DECAL DE SUELO (7/11/2026). Una CAJA que pinta su textura sobre lo que haya dentro, sea cual sea el relieve: reconstruye la posición del mundo desde el DEPTH_TEXTURE y descarta
// lo que cae fuera de la caja. Sirve para lo que un quad tumbado no sabe hacer: pegarse al terreno irregular (cuestas, escalones, la orilla), que es justo lo que nos fallaba con las
// grietas del haz de tierra. Pablo pasó la referencia: https://godotshaders.com/shader/decal-shader-similar-to-forward-decal-but-for-compatibility-mobile/ (LeLu, CC0; a su vez
// port de «Decal Shader 4.0» de OlisUnfinishedProjects). Va en Forward+, Mobile y Compatibility, al contrario que el nodo `Decal` de Godot.
//
// Lo que cambia respecto al original: aquí la textura es una MÁSCARA DE GRIETA (negro opaco donde hay grieta, fondo transparente: `T_Groundmark19`, `T_Cracks336`), no un albedo PBR;
// el color lo pone `color` y el brillo `color_emision` + `emision` (para el magma, que las grietas tienen que arder). Sin normal ni roughness: esto es toon y va `unshaded`.
// Y se añade `avance`: tapa la parte de la caja que va por delante de ese punto (0..1 a lo largo de su eje Z local), que es como las grietas CORREN de la mano a la punta del haz.

uniform sampler2D mascara : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 escala = vec2(1.0, 1.0);
uniform vec3 color : source_color = vec3(0.06, 0.04, 0.03);
uniform vec3 color_emision : source_color = vec3(0.0, 0.0, 0.0);
uniform float emision : hint_range(0.0, 8.0) = 0.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float fuerza : hint_range(0.0, 2.0) = 1.0;          // cuánto pinta la máscara
uniform float avance : hint_range(0.0, 1.0) = 1.0;          // 0 = nada; 1 = toda la caja (a lo largo de su Z local, de −0,5 a +0,5)
uniform float borde_avance : hint_range(0.0, 0.5) = 0.06;   // el frente de la grieta no corta a cuchillo

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;
uniform float media_caja = 0.5;

// Fundido por el eje Y de la caja (el del `Decal` de Forward+ y el del vídeo de tierra): lo que está más alto dentro de la caja se desvanece.
uniform bool fundido_y = false;
uniform float fundido_desde : hint_range(0.0, 1.0) = 0.3;
uniform float fundido_hasta : hint_range(0.0, 1.0) = 0.8;
uniform float fundido_curva : hint_range(0.1, 8.0) = 2.0;

varying mat4 INV_MODELO;

void vertex() {
	INV_MODELO = inverse(MODEL_MATRIX);
}

vec3 mundo_desde_prof(float prof, vec2 uv_pantalla, mat4 inv_proy, mat4 inv_vista) {
	vec4 pos_clip = vec4(uv_pantalla * 2.0 - 1.0, prof, 1.0);
	vec4 pos_vista = inv_proy * pos_clip;
	pos_vista /= pos_vista.w;
	return (inv_vista * pos_vista).xyz;
}

void fragment() {
	float prof = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 p_mundo = mundo_desde_prof(prof, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec4 p = INV_MODELO * vec4(p_mundo, 1.0);
	if (abs(p.x) > media_caja || abs(p.y) > media_caja || abs(p.z) > media_caja || vida < 0.01) {
		discard;
	}
	// el frente de la grieta: de la cara −Z (la mano) hacia +Z
	float a_lo_largo = (p.z + media_caja) / (2.0 * media_caja);
	float frente = 1.0 - smoothstep(avance - borde_avance, avance, a_lo_largo);
	if (frente <= 0.001) {
		discard;
	}
	float y_fade = 1.0;
	if (fundido_y) {
		float ny = clamp((p.y + media_caja) / (2.0 * media_caja), 0.0, 1.0);
		y_fade = 1.0 - pow(smoothstep(fundido_desde, fundido_hasta, ny), fundido_curva);
		if (y_fade <= 0.001) {
			discard;
		}
	}
	vec2 uv = (p.xz / (2.0 * media_caja) + 0.5) * escala;
	vec4 t = texture(mascara, uv);
	float m = t.a * (1.0 - t.r) * fuerza;             // grieta = píxel OPACO y oscuro de la máscara
	if (m <= 0.002) {
		discard;
	}
	ALBEDO = color;
	EMISSION = color_emision * emision;
	ALPHA = clamp(m, 0.0, 1.0) * vida * frente * y_fade;
}
