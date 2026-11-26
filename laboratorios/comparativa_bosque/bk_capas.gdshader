// ROCAS Y TRONCOS DE PURE NATURE (BK) en Godot (26/11/2026, comparativa Unreal/Godot). Aproxima:
//   · MM_BK_StandardLayered (rocas, acantilado): textura base × detalle repetido, y una CAPA (hierba) encima de las caras que miran
//     hacia arriba («Blend Normal», «Blend Sharpness», «Blend Bias»).
//   · MM_BK_VegetationTrunk (troncos): textura × «Main Color», y la capa (musgo/hierba) que sube desde el suelo hasta «Offset» cm con
//     una transición de «Falloff» cm.
// La máscara del pack (_mask): G = oclusión. Lo demás de la máscara no se usa.
shader_type spatial;

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mascara : filter_linear_mipmap, repeat_enable;
uniform bool hay_mascara = false;
uniform vec3 tinte = vec3(1.0);
uniform float fuerza_normal = 1.0;
uniform float oclusion = 0.7;
uniform float rugosidad = 0.9;
// detalle (rocas)
uniform sampler2D detalle : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool hay_detalle = false;
uniform float repeticion_detalle = 3.0;
// capa
uniform sampler2D capa_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool hay_capa = false;
uniform vec3 capa_tinte = vec3(1.0);
uniform float repeticion_capa = 5.0;
uniform bool capa_por_altura = false;    // troncos: desde el suelo; rocas: caras hacia arriba
uniform float capa_umbral = 0.55;        // rocas: a partir de qué «cuánto mira arriba» (0..1) aparece la capa
uniform float capa_dureza = 6.0;
uniform float capa_alto = 0.4;           // troncos: m desde el suelo
uniform float capa_transicion = 1.0;     // troncos: m de transición

varying vec3 v_mundo;
varying vec3 v_normal_mundo;

void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(albedo, UV).rgb * tinte;
	if (hay_detalle) {
		c *= texture(detalle, UV * repeticion_detalle).rgb;
	}
	float w = 0.0;
	if (hay_capa) {
		if (capa_por_altura) {
			w = clamp(1.0 - (v_mundo.y - capa_alto) / max(capa_transicion, 0.01), 0.0, 1.0);
		} else {
			w = clamp((v_normal_mundo.y - capa_umbral) * capa_dureza, 0.0, 1.0);
		}
		c = mix(c, texture(capa_albedo, UV * repeticion_capa).rgb * capa_tinte, w);
	}
	ALBEDO = c;
	ROUGHNESS = rugosidad;
	SPECULAR = 0.3;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = fuerza_normal * (1.0 - w * 0.6);
	if (hay_mascara) {
		AO = mix(1.0, texture(mascara, UV).g, oclusion);
		AO_LIGHT_AFFECT = 0.3;
	}
}
