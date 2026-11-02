// AGUA «TOY» (3/11/2026, rama claude/fuego-toy-carga-impacto, docs/PROPUESTA_AGUA_TOY_2026-11-02.md). Piezas comunes de los shaders de cuerpo del agua (esfera, cintas, ondas):
//   · blend_mix, SIN emisión y SIN luz (los shaders son unshaded): el agua no brilla, solo se ve más o menos clara.
//   · PALETA = la del AGUA DEL MUNDO (agua_render_3d.gd), centralizada en agua_paleta.gd (los defaults de abajo son IGUALES a esas constantes): tono_a = hondo, tono_b = somero, tono_c = espuma,
//     color_causticas, color_lecho y tinte_fresnel. Entre hondo y somero hay BANDAS escalones (como el agua del mundo: floor(x * bandas + 0.5) / bandas); la espuma entra por umbral.
//   · CÁUSTICAS: T_Noise_Wf4 (red de líneas claras) muestreada dos veces en direcciones opuestas y mezclada con un flujo de T_Noise_W5i: la red se mueve y se deshace. Se pintan con color_causticas.
//   · ESPUMA / CRESTA por umbral: el tercer tono solo sale donde el valor pasa del umbral alto (cresta, borde, nudos de la red de cáusticas).
//   · FUNDIDO DE PROFUNDIDAD contra la geometría de detrás (suave_prof, igual que el fuego): sin corte recto contra el suelo o la pared.

uniform sampler2D causticas : filter_linear_mipmap, repeat_enable;     // T_Noise_Wf4
uniform sampler2D flujo : filter_linear_mipmap, repeat_enable;         // T_Noise_W5i
uniform vec3 tono_a : source_color = vec3(0.20, 0.52, 0.80);           // hondo (color_hondo_est del agua del mundo)
uniform vec3 tono_b : source_color = vec3(0.44, 0.80, 0.91);           // somero (color_somero_est)
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);            // espuma (color_espuma)
uniform vec3 color_causticas : source_color = vec3(0.72, 0.93, 1.0);
uniform vec3 color_lecho : source_color = vec3(0.16, 0.38, 0.55);
uniform vec3 tinte_fresnel : source_color = vec3(0.88, 0.94, 1.0);
uniform float bandas : hint_range(1.0, 8.0) = 3.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float suave_prof : hint_range(0.0, 3.0) = 0.0;
uniform sampler2D tex_prof : hint_depth_texture, repeat_disable, filter_nearest;


// Redondeo a escalones con borde casi duro (como `floor(x * n + 0.5) / n` del agua del mundo, pero con un filo de 0,06 para que no haya dientes de sierra).
float agua_escalon(float x, float n) {
	float f = clamp(x, 0.0, 1.0) * n;
	float i = floor(f);
	return (i + smoothstep(0.44, 0.56, f - i)) / n;
}

// Tres tonos: v decide entre HONDO y SOMERO en `bandas` escalones (u1 = centro del paso de uno a otro) y, por encima de u2, ESPUMA. `suave` = anchura del filo de la espuma.
vec3 agua_tonos(float v, float u1, float u2, float suave) {
	float k = agua_escalon(smoothstep(u1 - 0.18, u1 + 0.30, v), bandas);
	vec3 c = mix(tono_a, tono_b, k);
	return mix(c, tono_c, smoothstep(u2 - suave, u2 + suave, v));
}

// Las cáusticas son redes de luz: se tiñen con color_causticas donde la red es fuerte (`k` = cuánto).
vec3 agua_cau_color(vec3 c, float cau, float k) {
	return mix(c, color_causticas, clamp(smoothstep(0.35, 0.9, cau) * k, 0.0, 1.0));
}

// Borde claro por fresnel (`f` 0..1).
vec3 agua_borde(vec3 c, float f, float k) {
	return mix(c, tinte_fresnel, clamp(f * k, 0.0, 1.0));
}

// Red de cáusticas en 2D que se mueve: dos capas de Wf4 que van en direcciones opuestas, deformadas por el flujo de W5i. Devuelve 0..1 (1 = nudo brillante).
float agua_cau(vec2 uv, float t) {
	vec2 f = (texture(flujo, uv * 0.35 + vec2(t * 0.03, -t * 0.022)).rg - 0.5) * 0.24;
	float a = texture(causticas, uv + f + vec2(t * 0.05, t * 0.032)).r;
	float b = texture(causticas, uv * 1.37 - f + vec2(-t * 0.038, t * 0.052) + 0.41).r;
	return smoothstep(0.10, 0.5, sqrt(a * b));
}

// La misma red proyectada en tres ejes (esfera y volúmenes): `p` = posición en el objeto (≈ 1 en el radio), `n` = su normal en el objeto.
float agua_cau3(vec3 p, vec3 n, float t) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return w.x * agua_cau(p.yz, t) + w.y * agua_cau(p.xz + 0.17, t) + w.z * agua_cau(p.xy + 0.53, t);
}

// 0 pegado a la geometría de detrás, 1 a `dist` m o más. `vz` = VERTEX.z del fragmento.
float agua_prof(vec2 suv, float vz, float dist, mat4 inv_proy) {
	if (dist <= 0.0) {
		return 1.0;
	}
	float dp = texture(tex_prof, suv).r;
	if (dp > 0.00001) {
		vec4 w = inv_proy * vec4(suv * 2.0 - 1.0, dp, 1.0);
		return clamp((-w.z / w.w + vz) / dist, 0.0, 1.0);
	}
	return 1.0;
}
