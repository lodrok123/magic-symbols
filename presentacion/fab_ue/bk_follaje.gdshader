// FOLLAJE DE PURE NATURE (BK) en Godot (26/11/2026, comparativa Unreal/Godot). Traduce dos materiales maestros del pack:
//   · MM_BK_VegetationLeaves (hojas de árbol y arbusto). Copiado del grafo de Unreal (docs/fab_ue/grafos/MM_BK_VegetationLeaves.txt):
//       degradado = WorldAlignedBlend(Gradient Contrast, Gradient Offset) = saturar(normal_arriba × contraste + desplazamiento)
//       tinte     = mezcla(Main Color, Gradient Color, degradado)        (las hojas que miran arriba toman el Gradient)
//       color     = mezcla(textura, mezcla(textura, tinte, vc) × textura, vc)    vc = color de vértice R (casi siempre 1)
//   · MM_BK_Grass (hierba, flores, helechos): textura × la mezcla de «Color 01» y «Color 02» según un ruido en el mundo, con fuerza «Color Power».
// Lo que NO se copia: el viento, el «Hiding Power»/«AngleFade» (las hojas que se ponen de canto se desvanecen) y el color del terreno (RVT).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool hay_normal = true;
uniform float fuerza_normal = 0.2;
uniform float rugosidad = 0.8;
uniform float corte_alfa = 0.5;
// Hojas: degradado por altura
uniform bool es_hoja = true;
uniform bool una_cara = true;
// Multiplicador de reserva (1 = como el pack). Hubo un 6 mientras los tintes entraban oscurecidos (ver MaterialesUE.HOJAS_BRILLO).
uniform float brillo_hojas = 1.0;
uniform bool sin_luz = false;           // depuración: solo el color (sin luz)
uniform vec3 color_abajo = vec3(1.0);
uniform vec3 color_arriba = vec3(1.0);
uniform float altura_malla = 10.0;      // (ya no se usa: el degradado era por altura antes de leer el grafo)
uniform bool usa_color_vertice = true;  // si la malla no trae color de vértice, Godot da blanco (= 1): mismo resultado que R = 1
uniform float degradado_desplaz = 0.5;
uniform float degradado_contraste = 1.5;
// Hierba: dos colores según ruido del mundo
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float escala_ruido = 100.0;     // m por repetición del ruido
uniform float fuerza_color = 1.0;
// Translucidez de las hojas (luz que pasa a través): en Unreal es el modelo «Two Sided Foliage»
uniform float translucidez = 0.3;

varying vec3 v_mundo;
varying float v_arriba;                 // cuánto mira hacia arriba la normal (mundo), -1..1
varying float v_vc;

void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_arriba = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	v_vc = usa_color_vertice ? COLOR.r : 1.0;
}

void fragment() {
	// 26/11: en Unreal las hojas de árbol son de UNA cara (MM_BK_VegetationLeaves no es «Two Sided»); pintadas por detrás les llega la
	// normal al revés y la copa sale negra. La hierba sí es de dos caras.
	if (es_hoja && una_cara && !FRONT_FACING) {
		discard;
	}
	vec4 t = texture(albedo, UV);
	vec3 c;
	if (es_hoja) {
		float g = clamp(v_arriba * degradado_contraste + degradado_desplaz, 0.0, 1.0);
		vec3 tinte = mix(color_abajo, color_arriba, g);
		c = mix(t.rgb, mix(t.rgb, tinte, v_vc) * t.rgb, v_vc) * brillo_hojas;
	} else {
		float n = texture(ruido, v_mundo.xz / max(escala_ruido, 0.01)).r;
		c = t.rgb * mix(vec3(1.0), mix(color_abajo, color_arriba, n), fuerza_color);
	}
	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = corte_alfa;
	ROUGHNESS = rugosidad;
	SPECULAR = 0.2;
	if (hay_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = fuerza_normal;
	}
	BACKLIGHT = ALBEDO * translucidez;
	if (sin_luz) {
		EMISSION = ALBEDO;
		ALBEDO = vec3(0.0);
	}
}
