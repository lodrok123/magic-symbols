shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// LÁMINA DE AGUA QUE CORRE POR EL SUELO (16/11/2026): lo que queda cuando la figura de agua toca el suelo al morir. Un quad tumbado (QuadMesh FACE_Y de 1 × 1, se escala al alcance máximo) con un FRENTE de espuma
// que avanza, frena y se adelgaza. Antes la ola y el pilar dejaban el mismo charco de anillos redondos (agua_onda.gdshader), que no tenía nada que ver con cómo habían caído: una ola cae hacia una dirección
// y una columna se desparrama por igual.
//   radial = 0  la lámina de la OLA: nace en el pie (borde de atrás del quad, +Z local) y corre hacia delante (-Z); el frente se curva un poco en los lados y los lados se desvanecen.
//   radial = 1  la lámina del PILAR: sale del centro y se abre IGUAL en todas las direcciones (el ruido del borde es pequeño y no depende de la dirección en promedio).
//   frente 0 → 1 cuánto ha llegado (fracción del alcance); cola 0 → 1 por dónde se ha ido el agua de atrás (la lámina se queda en un anillo); espesor 1 → 0 se adelgaza; alfa = fundido global.
// Agua: blend_mix, sin luz ni emisión, paleta del agua del mundo.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D flujo2 : filter_linear_mipmap, repeat_enable;       // T_Noise_Wo14
uniform float radial = 0.0;
uniform float frente : hint_range(0.0, 1.0) = 0.0;
uniform float cola : hint_range(0.0, 1.0) = 0.0;
uniform float espesor : hint_range(0.0, 1.0) = 1.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform float ancho_espuma = 0.05;

varying vec2 v_p;

void vertex() {
	v_p = VERTEX.xz;
}

void fragment() {
	float t = TIME * velocidad;
	vec2 p = v_p * 2.0;
	float q;
	float lado = 1.0;
	float ruido;
	float fr = frente;
	if (radial > 0.5) {
		q = length(p);
		float ang = atan(p.y, p.x);
		ruido = texture(flujo, vec2(cos(ang), sin(ang)) * 0.3 + vec2(0.5 + semilla, 0.5)).r;
	} else {
		q = 0.5 - v_p.y;
		q = clamp(q, 0.0, 1.2);
		lado = 1.0 - smoothstep(0.78, 1.0, abs(p.x));
		fr *= 1.0 - 0.28 * p.x * p.x;
		ruido = texture(flujo, vec2(p.x * 0.35 + semilla, 0.5)).r;
	}
	float d = q - fr * (1.0 + 0.05 * (ruido - 0.5));
	float dentro = 1.0 - smoothstep(-0.012, 0.012, d);
	float w = ancho_espuma * (0.6 + 0.6 * espesor);
	float borde = dentro * (1.0 - smoothstep(0.0, w, -d));
	float rota = smoothstep(0.2, 0.45, texture(flujo2, vec2(p.x * 0.8 + semilla * 3.0, p.y * 0.8 - t * 0.1)).r);
	borde *= 0.55 + 0.45 * rota;
	float cau = agua_cau(p * 1.3 + vec2(semilla * 3.0), t);
	float cuerpo = dentro * smoothstep(cola, cola + 0.12, q);
	float v = 0.2 + 0.3 * cau + 0.6 * borde;
	vec3 col = agua_tonos(v, 0.4, 0.78, 0.07);
	col = agua_cau_color(col, cau, 0.35 * cuerpo);
	ALBEDO = col * brillo;
	float a = cuerpo * 0.62 * espesor * (0.65 + 0.35 * cau) + borde * (0.75 + 0.2 * espesor);       // borde de espuma nítido y con presencia desde que se abre
	ALPHA = clamp(a, 0.0, 0.9) * lado * alfa * vida * smoothstep(0.0, 0.03, fr);
}
