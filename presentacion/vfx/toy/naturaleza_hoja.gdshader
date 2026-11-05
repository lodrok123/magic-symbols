shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// HOJA Y BRIZNA DE HIERBA «toy» de naturaleza (chamán goblin, 5/11/2026). Un quad subdividido; la forma se recorta aquí (sin textura) y se pinta
// con dos bandas de verde (toon) y un nervio central. El color (verde, naranja si arde, negro de ceniza) lo pone la CPU por instancia (COLOR).
// forma 0 = hoja (lente con punta, nervio y borde oscuro) · forma 1 = brizna (triángulo curvado, base oscura y punta clara).
uniform int forma = 0;
uniform float curva : hint_range(0.0, 1.0) = 0.35;   // hoja: cuánto se comba al lado del nervio · brizna: cuánto se dobla la punta
uniform float contorno : hint_range(0.0, 0.3) = 0.12;
varying vec4 tinte;

void vertex() {
	tinte = COLOR;
	if (forma == 0) {
		float u = UV.x - 0.5;
		VERTEX.z += (u * u) * curva * 2.0;               // la hoja hace cuenco
	} else {
		float v = 1.0 - UV.y;                            // 0 en la base, 1 en la punta
		VERTEX.x += v * v * curva * 3.2;                // el quad es estrecho: la punta se dobla varios anchos
	}
}

void fragment() {
	float u = UV.x * 2.0 - 1.0;                          // -1..1 a lo ancho
	float v = clamp(1.0 - UV.y, 0.0, 1.0);               // 0 base .. 1 punta (UV.y = 0 arriba del quad)
	float ancho;
	if (forma == 0) {
		ancho = pow(sin(3.14159 * clamp(v * 0.96 + 0.02, 0.0, 1.0)), 0.75) * (1.0 - 0.18 * v);
	} else {
		ancho = 1.0 - pow(v, 1.7);                      // ancha casi hasta arriba y punta fina
	}
	float dentro = ancho - abs(u);
	if (dentro < 0.0) {
		discard;
	}
	vec3 base = tinte.rgb;
	float claro = 0.0;
	if (forma == 0) {
		// toon: mitad del lado de la luz más clara y mitad más oscura, nervio y borde con más sombra
		claro = step(0.0, u) * 0.16 - 0.04;
		float nervio = 1.0 - smoothstep(0.0, 0.12, abs(u));
		claro += nervio * 0.13;
	} else {
		claro = smoothstep(0.0, 1.0, v) * 0.30 - 0.22;       // oscura en la base, más clara hacia la punta
		claro += step(0.0, u) * 0.06;
	}
	vec3 col = base * (1.0 + claro);
	float borde = 1.0 - smoothstep(0.0, contorno * max(ancho, 0.25) * 2.0, dentro);
	col = mix(col, base * 0.45, borde * 0.7);
	ALBEDO = col;
}
