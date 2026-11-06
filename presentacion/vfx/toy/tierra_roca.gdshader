shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// ROCA DE TIERRA «TOY» (6/11/2026, 2.ª versión: LA PIEDRA DEL MUNDO). Las mallas son las rocas estilizadas del mapa (arte/meshy/piezas/piedra_est_* y roca_est_*) con SU textura
// (tex_rocas_est/rocas_albedo.png, la misma que llevan en el GLB) y la LUZ DE LA ESCENA (sol + ambiente, como las rocas de ArteEntorno3D / Pieza3D): mate (roughness 1, sin especular),
// opaca (sin ALPHA: pasada opaca), sin emisión ni aditivos. Encima, solo ajustes ligeros sobre la textura, nunca color plano:
//   · `tinte`: un velo de Vfx3D.COLOR["piedra"] (0,72·0,58·0,42) aclarado; a 1,0 es la textura tal cual.
//   · `base_tierra`: la base de la roca (VERTEX.y < 0,2 m del modelo, que tiene la base en y = 0) tira a tierra (`color_base`): los bloques que suben del suelo salen manchados.
//   · con `instancias` = 1 (MultiMesh) INSTANCE_CUSTOM.r = variación de tono 0..1 por roca; `oscurecer` = 1 apaga toda la roca un tercio (fragmentos, piedrecitas).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tinte : source_color = vec3(0.98, 0.96, 0.93);
uniform vec3 color_base : source_color = vec3(0.50, 0.37, 0.24);
uniform float base_tierra : hint_range(0.0, 1.0) = 0.0;
uniform float instancias : hint_range(0.0, 1.0) = 0.0;
uniform float oscurecer : hint_range(0.0, 1.0) = 0.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;

varying float altura;
varying float tono;

void vertex() {
	altura = VERTEX.y;
	tono = instancias > 0.5 ? INSTANCE_CUSTOM.r : 0.5;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tinte;
	col = mix(col, color_base, base_tierra * (1.0 - smoothstep(0.0, 0.2, altura)) * 0.5);
	col *= mix(0.88, 1.08, tono);
	col *= 1.0 - 0.35 * oscurecer;
	ALBEDO = col * brillo;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
