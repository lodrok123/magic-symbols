shader_type spatial;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_mapa : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool usar_normal = false;
uniform bool tenir_gorro = false;
uniform vec2 caja = vec2(0.0, 1.0);
uniform vec4 gorro : source_color = vec4(1.0);
uniform vec4 tono_ropa : source_color = vec4(1.0);
varying float altura;

void vertex() {
	altura = (VERTEX.y - caja.x) / caja.y;
}

void fragment() {
	vec3 original = texture(textura, UV).rgb;
	float tela = smoothstep(0.006, 0.063, original.r - original.g * 1.09);
	float vestimenta = tela * (1.0 - smoothstep(0.57, 0.67, altura));
	vec3 color = mix(original, original * tono_ropa.rgb, vestimenta);
	if (tenir_gorro) {
		float zona_gorro = smoothstep(0.77, 0.86, altura) * tela;
		float claro = dot(original, vec3(0.30, 0.59, 0.11));
		color = mix(color, gorro.rgb * (0.50 + 2.7 * claro), zona_gorro);
	}
	ALBEDO = color;
	ROUGHNESS = 0.8;
	if (usar_normal) {
		NORMAL_MAP = texture(normal_mapa, UV).rgb;
	}
}
