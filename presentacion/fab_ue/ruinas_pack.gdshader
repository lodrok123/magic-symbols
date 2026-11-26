// RUINAS DE STYLESCAPE en Godot SIN TEÑIR (26/11/2026, comparativa Unreal/Godot). Aproxima M_RuinsMaster tal cual viene en el pack
// (el juego usa otra cosa: el «modo 3» con el beige de nuestros muros). Hace:
//   · textura × «Tint»; AORM del pack (R = oclusión con «AO Power», G = rugosidad elevada a «Roughness Power»).
//   · «Top Layer»: musgo en las caras que miran hacia arriba («Blend Normal»; con «Top Layer Min/Max Blend» como umbral).
//   · «Rim Lighting»: un borde de luz azulado en el contorno (fresnel), muy suave.
//   · «Normal Flatness»: aplana el relieve (0 = tal cual, 1 = plano).
shader_type spatial;

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aorm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tinte = vec3(1.0);
uniform float ao_potencia = 1.5;
uniform float rugosidad_potencia = 1.0;
uniform float aplanar = 0.25;
uniform sampler2D capa_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D capa_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float capa_repeticion = 10.0;    // repeticiones por metro de mundo
uniform float capa_umbral = 0.45;
uniform float capa_dureza = 6.0;
uniform float capa_opacidad = 1.0;
uniform float capa_relieve = 50.0;       // «Blend Normal» de Unreal
uniform float musgo_caras_planas_menos = 0.85;   // cuánto musgo se quita en las caras que miran arriba (0 = nada, 1 = todo)
uniform vec3 borde_color = vec3(0.68, 0.94, 1.0);
uniform float borde_fuerza = 0.15;

varying vec3 v_mundo;
varying vec3 v_normal_mundo;

void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 m = texture(aorm, UV).rgb;
	vec3 c = texture(albedo, UV).rgb * tinte;
	// 26/11: el musgo se decide con la normal DE LA TEXTURA (por píxel), como en Unreal: así sale en el canto de arriba de cada ladrillo
	// y no tapa entera la cara superior. Normal del mapa (tangente) -> vista -> mundo.
	// 2.º (26/11): «Blend Normal» exagera el relieve de la textura antes de mirar qué apunta arriba (50 en los muros, 100 en las losas,
	// 8 en la madera): así cada ladrillo con la cara algo inclinada hacia arriba coge musgo, a manchas, también en las paredes verticales.
	vec3 nt = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	nt.xy *= capa_relieve * 0.1;
	vec3 n_vista = normalize(TANGENT * nt.x + BINORMAL * nt.y + NORMAL * nt.z);
	vec3 n_mundo = normalize((INV_VIEW_MATRIX * vec4(n_vista, 0.0)).xyz);
	float w = clamp((n_mundo.y - capa_umbral) * capa_dureza, 0.0, 1.0) * capa_opacidad;
	// 3.º (26/11): en Unreal las caras planas de arriba (tapas de pilares, losas) son piedra clara con vetas, no una alfombra de musgo.
	w *= 1.0 - smoothstep(0.7, 0.95, v_normal_mundo.y) * musgo_caras_planas_menos;
	vec3 musgo = texture(capa_albedo, v_mundo.xz * capa_repeticion * 0.1).rgb;
	ALBEDO = mix(c, musgo, w);
	AO = pow(m.r, ao_potencia);
	AO_LIGHT_AFFECT = 0.4;
	// 4.º (26/11): con la rugosidad del AORM tal cual (media 0,11 en los muros) la piedra reflejaba el cielo azul como mojada: manchas
	// azules en las caras en sombra. En Unreal se ve mate: la textura solo modula un poco una rugosidad alta.
	ROUGHNESS = mix(0.75 + 0.25 * m.g, 0.85, w);
	SPECULAR = 0.25;
	vec3 nm = texture(normal_tex, UV).rgb;
	NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), clamp(aplanar, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = borde_color * fres * borde_fuerza;
}
