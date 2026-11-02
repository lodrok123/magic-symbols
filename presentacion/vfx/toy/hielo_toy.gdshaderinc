// HIELO «TOY» (2/11/2026, rama claude/b1-hielo-rayo). Piezas comunes de los shaders del hielo (cristales, esquirlas, escarcha, destello):
//   · blend_mix, SIN emisión y SIN luz (los shaders son unshaded): el hielo no brilla, solo se ve más o menos claro.
//   · PALETA = la del HIELO DEL MUNDO (costra_hielo_3d.gd, vfx_3d.gd, vfx_estado_3d.gd), centralizada en hielo_paleta.gd (los defaults de abajo son IGUALES a esas constantes).
//   · Tres tonos por ESCALONES (facetas): tono_a = hondo, tono_b = claro, tono_c = escarcha (lo más blanco); borde por fresnel con color_borde; grietas con color_grieta.
//   · FUNDIDO DE PROFUNDIDAD contra la geometría de detrás (suave_prof, igual que el agua y el fuego).

uniform vec3 tono_a : source_color = vec3(0.46, 0.66, 0.88);           // hondo (costra_hielo_3d.gd color_hondo)
uniform vec3 tono_b : source_color = vec3(0.72, 0.86, 0.97);           // claro (costra_hielo_3d.gd color_claro)
uniform vec3 tono_c : source_color = vec3(0.86, 0.93, 0.99);           // escarcha (vfx_estado_3d.gd hielo mota)
uniform vec3 color_nucleo : source_color = vec3(0.60, 0.88, 1.0);      // cuerpo del hielo de hechizo (vfx_3d.gd hielo nucleo)
uniform vec3 color_borde : source_color = vec3(0.92, 1.0, 1.0);        // borde claro (vfx_3d.gd hielo borde)
uniform vec3 color_grieta : source_color = vec3(0.30, 0.50, 0.76);     // grietas (costra_hielo_3d.gd color_grieta)
uniform float bandas : hint_range(1.0, 8.0) = 3.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float suave_prof : hint_range(0.0, 3.0) = 0.0;
uniform sampler2D tex_prof : hint_depth_texture, repeat_disable, filter_nearest;

// Tonos por escalones: `v` 0..1 → hondo, claro y escarcha en `bandas` pasos (borde casi duro: el hielo se ve facetado).
vec3 hielo_tonos(float v, float u_escarcha, float suave) {
	float f = clamp(v, 0.0, 1.0) * bandas;
	float i = floor(f);
	float k = (i + smoothstep(0.44, 0.56, f - i)) / bandas;
	vec3 c = mix(tono_a, tono_b, clamp(k * 1.25, 0.0, 1.0));
	return mix(c, tono_c, smoothstep(u_escarcha - suave, u_escarcha + suave, v));
}

// 0 pegado a la geometría de detrás, 1 a `dist` m o más. `vz` = VERTEX.z del fragmento.
float hielo_prof(vec2 suv, float vz, float dist, mat4 inv_proy) {
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
