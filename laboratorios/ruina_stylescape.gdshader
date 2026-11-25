shader_type spatial;
render_mode cull_disabled;
// PRUEBA del pack «Stylescape: Ruins» (25/11/2026), solo para LabStylescape.
// Una piedra que va de «texturas del pack tal cual» (mezcla_textura = 1) a «color de la paleta del juego» (mezcla_textura = 0),
// con musgo opcional en las caras que miran arriba (lo que en Unreal hacía MF_TopLayer con la rotación de la malla).

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_orm : filter_linear_mipmap_anisotropic, hint_default_white; // de Unreal: R oclusión, G rugosidad, B especular
uniform sampler2D tex_musgo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;

uniform float mezcla_textura : hint_range(0.0, 1.0) = 1.0;  // 1 = color del pack; 0 = color de la paleta (solo conserva el «detalle»)
uniform float detalle : hint_range(0.0, 1.0) = 0.25;         // cuánto claroscuro de la textura sobrevive con el color de la paleta
uniform vec4 color_piedra : source_color = vec4(1.0);         // tinte (con el pack) o color de la paleta
uniform float fuerza_normal : hint_range(0.0, 2.0) = 1.0;
uniform float usa_orm : hint_range(0.0, 1.0) = 1.0;

uniform float musgo : hint_range(0.0, 1.0) = 0.0;             // 0 = sin musgo; 1 = musgo en lo que mira arriba
uniform float musgo_textura : hint_range(0.0, 1.0) = 0.0;     // 1 = la textura de musgo del pack (T_RockyMoss_D); 0 = color plano
uniform vec4 color_musgo : source_color = vec4(0.55, 0.72, 0.25, 1.0);
uniform float musgo_escala = 0.5;                             // repeticiones de la textura de musgo por unidad de mundo
uniform float musgo_umbral : hint_range(0.0, 1.0) = 0.55;     // a partir de qué inclinación (normal.y) hay musgo
uniform float musgo_suave : hint_range(0.01, 0.5) = 0.12;

uniform float recorte : hint_range(0.0, 1.0) = 0.0;           // > 0 para la hiedra (hojas con alfa)

varying vec3 n_mundo;
varying vec3 p_mundo;

void vertex() {
	n_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 t = texture(tex_albedo, UV);
	if (recorte > 0.0 && t.a < recorte) {
		discard;
	}
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	// color de la paleta, aclarado/oscurecido con el claroscuro de la textura (centrado en el gris medio)
	vec3 paleta = color_piedra.rgb * mix(1.0, clamp(1.0 + (lum - 0.4) * 2.0, 0.2, 1.6), detalle);
	vec3 pack = t.rgb * color_piedra.rgb;
	vec3 base = mix(paleta, pack, mezcla_textura);

	float arriba = smoothstep(musgo_umbral - musgo_suave, musgo_umbral + musgo_suave, n_mundo.y) * musgo;
	vec3 musgo_tex = texture(tex_musgo, p_mundo.xz * musgo_escala).rgb;
	vec3 musgo_c = mix(color_musgo.rgb * mix(1.0, 0.85 + lum * 0.4, detalle), musgo_tex, musgo_textura);
	ALBEDO = mix(base, musgo_c, arriba);

	vec3 orm = mix(vec3(1.0, 0.85, 0.5), texture(tex_orm, UV).rgb, usa_orm);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = mix(clamp(orm.g, 0.5, 1.0), 0.95, arriba);
	METALLIC = 0.0;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(tex_normal, UV).rgb;
	NORMAL_MAP_DEPTH = fuerza_normal * (1.0 - arriba * 0.6);
}
