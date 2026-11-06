shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled, ambient_light_disabled, fog_disabled;

// ROCA DE MAGMA (6/11/2026, MagmaToy; concepto de Pablo en docs/capturas/referencias/magma_concepto/). Roca OSCURA SÓLIDA (albedo de rocas_magma_albedo.png,
// oscurecido) cuyas GRIETAS (la máscara rocas_magma_emisivo.png, canal R) y su CONTORNO (fresnel) brillan según `calor`:
//   0 gris apagado (una piedra fría)  ·  0,5 rojo  ·  1 amarillo en las grietas y el borde (aquí el amarillo SÍ vale: es calor de grieta, no llama).
// `por_instancia` = true: el calor sale de INSTANCE_CUSTOM.r (las esquirlas y los pétalos del cráter, cada una con el suyo, en un MultiMesh).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D emisivo_tex : source_color, filter_linear_mipmap;
uniform float calor : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.0, 4.0) = 1.0;
uniform float oscuro : hint_range(0.0, 1.5) = 0.45;     // × el albedo (la roca del concepto es casi negra)
uniform bool por_instancia = false;

varying float v_calor;

vec3 color_calor(float c) {
	vec3 gris = vec3(0.20, 0.17, 0.18);
	vec3 rojo = vec3(1.0, 0.10, 0.02);
	vec3 naranja = vec3(1.0, 0.42, 0.05);
	vec3 amarillo = vec3(1.0, 0.86, 0.32);
	vec3 a = mix(gris, rojo, smoothstep(0.0, 0.45, c));
	vec3 b = mix(naranja, amarillo, smoothstep(0.78, 1.0, c));
	return mix(a, b, smoothstep(0.45, 0.78, c));
}

void vertex() {
	v_calor = por_instancia ? INSTANCE_CUSTOM.r : calor;
}

void fragment() {
	float c = clamp(v_calor, 0.0, 1.0);
	// roca MATE gris-marrón casi negra: la luminancia del albedo teñida (el albedo original tira a gris violeta y con luz parecía pulido)
	float luma = dot(texture(albedo_tex, UV).rgb, vec3(0.3, 0.59, 0.11));
	vec3 alb = vec3(0.34, 0.28, 0.25) * (0.35 + 0.9 * luma) * oscuro * mix(1.0, 0.6, c);
	// la grieta tiene tres capas (ronda 2, f03/f04 del concepto): NÚCLEO fino (amarillo), BASE ancha (rojo-naranja, la máscara desenfocada) y HALO suave hacia la roca
	float nucleo = smoothstep(0.45, 0.85, texture(emisivo_tex, UV).r);
	float base = smoothstep(0.10, 0.45, textureLod(emisivo_tex, UV, 1.5).r);
	float halo = smoothstep(0.03, 0.3, textureLod(emisivo_tex, UV, 3.0).r);
	float fuerza = smoothstep(0.02, 0.25, c);
	vec3 col_nucleo = color_calor(c);
	vec3 col_base = color_calor(c * 0.62);                   // la base siempre más fría que el núcleo: naranja-rojo cuando el núcleo es amarillo
	vec3 col_halo = color_calor(c * 0.45);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col_rim = mix(vec3(0.3, 0.26, 0.25), vec3(1.0, 0.22, 0.03), smoothstep(0.0, 0.5, c));
	ALBEDO = alb;
	EMISSION = (col_nucleo * nucleo * (0.9 + 1.4 * c) + col_base * base * (0.5 + 0.9 * c) + col_halo * halo * 0.3 * c + col_rim * rim * 0.45 * c) * fuerza * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
