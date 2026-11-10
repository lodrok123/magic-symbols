shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// ROCA DE TIERRA «TOY» (6/11/2026, 2.ª versión: LA PIEDRA DEL MUNDO). Las mallas son las rocas estilizadas del mapa (arte/meshy/piezas/piedra_est_* y roca_est_*) con SU textura
// (tex_rocas_est/rocas_albedo.png, la misma que llevan en el GLB) y la LUZ DE LA ESCENA (sol + ambiente, como las rocas de ArteEntorno3D / Pieza3D): mate (roughness 1, sin especular),
// opaca (sin ALPHA: pasada opaca), sin emisión ni aditivos. El modo texturizado solo aplica ajustes ligeros sobre el albedo:
//   · `tinte`: un velo de Vfx3D.COLOR["piedra"] (0,72·0,58·0,42) aclarado; a 1,0 es la textura tal cual.
//   · `base_tierra`: la base de la roca (VERTEX.y < 0,2 m del modelo, que tiene la base en y = 0) tira a tierra (`color_base`): los bloques que suben del suelo salen manchados.
//   · con `instancias` = 1 (MultiMesh) INSTANCE_CUSTOM.r = variación de tono 0..1 por roca; `oscurecer` = 1 apaga toda la roca un tercio (fragmentos, piedrecitas).
//   · `plano` = 1 (púas y lajas): tres bandas de tierra, de la raíz parda a la punta ocre.
//     Las facetas conservan el sombreado mate de la escena.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float plano : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color_plano : source_color = vec3(0.56, 0.40, 0.25);
uniform vec3 tinte : source_color = vec3(0.98, 0.96, 0.93);
uniform vec3 color_base : source_color = vec3(0.50, 0.37, 0.24);
uniform float base_tierra : hint_range(0.0, 1.0) = 0.0;
uniform float instancias : hint_range(0.0, 1.0) = 0.0;
uniform float oscurecer : hint_range(0.0, 1.0) = 0.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
// 7/11: en el Bosque las púas del haz salían casi negras contra la hierba clara (caras muy inclinadas: el sol les da de canto y el ambiente no llega). Se sube el ALBEDO del color
// plano, que es lo único que se puede tocar aquí: esta roca va con la luz de la escena y SIN emisión a propósito (regla del 6/11, la vigila `prueba_viento_tierra_toy`).
uniform float aclara_pua : hint_range(1.0, 2.5) = 1.0;

varying float altura;
varying float tono;

void vertex() {
	altura = VERTEX.y;
	tono = instancias > 0.5 ? INSTANCE_CUSTOM.r : 0.5;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tinte;
	// La altura local de las púas está normalizada. Una transición corta
	// mantiene las bandas legibles sin dibujar una línea dura entre ellas.
	vec3 estrato = mix(color_plano * 0.85, color_plano, smoothstep(0.19, 0.27, altura));
	vec3 punta_ocre = mix(color_plano, vec3(0.76, 0.58, 0.40), 0.32);
	float veta = altura + (tono - 0.5) * 0.24;
	estrato = mix(estrato, punta_ocre, smoothstep(0.55, 0.79, veta));
	col = mix(col, estrato, plano);
	col = mix(col, color_base, base_tierra * (1.0 - smoothstep(0.0, 0.2, altura)) * 0.5);
	col *= mix(0.88, 1.08, tono);
	col *= 1.0 - 0.35 * oscurecer;
	ALBEDO = col * mix(1.0, aclara_pua, plano) * brillo;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
