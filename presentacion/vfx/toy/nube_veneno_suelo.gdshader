shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// MANCHA DEL SUELO de la nube de veneno (5/11/2026): un disco tenue de borde irregular (con un aro un poco más marcado) que dice hasta dónde envenena la nube sin tapar nada.
// Es un quad plano: el borde (r = 1) coincide con el radio de la nube. `crece` (0..1) lo hace brotar desde el centro; `alfa` lo apaga. Sin luz.
uniform vec3 color : source_color = vec3(0.45, 0.80, 0.27);
uniform vec3 color_aro : source_color = vec3(0.20, 0.56, 0.22);
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float tiempo = 0.0;
// GAS PESADO (11/11, NubeVenenoVfx.gas_pesado): las manchas de dentro se arremolinan a ras de suelo (espiral que gira). 0 = la mancha de siempre.
uniform float remolino : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p) / max(crece, 0.02);
	float a = atan(p.y, p.x);
	float borde = 0.94 + 0.03 * sin(a * 5.0 + tiempo * 0.6) + 0.02 * sin(a * 9.0 - tiempo * 0.9);
	float dentro = smoothstep(borde, borde - 0.05, r);
	float aro = smoothstep(borde - 0.09, borde - 0.05, r) * dentro * (0.45 + 0.55 * smoothstep(-0.2, 0.5, sin(a * 13.0 + tiempo * 0.5)));
	float giro = remolino * (tiempo * 0.25 + 1.4 * (1.0 - clamp(length(p), 0.0, 1.0)));   // gira entero y con una torsión fija (no se enrolla con el tiempo)
	vec2 pm = mat2(vec2(cos(giro), sin(giro)), vec2(-sin(giro), cos(giro))) * p;
	float manchas = 0.5 + 0.5 * sin(pm.x * 7.0 + tiempo * 0.4) * sin(pm.y * 6.0 - tiempo * 0.3);
	float al = clamp(dentro * (0.025 + 0.045 * manchas) + aro * 0.20, 0.0, 1.0) * alfa;
	if (al < 0.01) {
		discard;
	}
	ALBEDO = mix(color, color_aro, aro);
	ALPHA = al;
}
