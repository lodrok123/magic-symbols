shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// LENGUAS DE AGUA COMO LÁMINAS Y-BILLBOARD (fase 3, 3/11/2026: corona del pilar y columnas de la explosión de área). Un MultiMesh (1 draw call) de láminas de FuegoToyMallas.quad_vbb (x -0,5..0,5,
// y 0..1, UV.y = 0 abajo) que GIRAN alrededor de su eje vertical para mirar a la cámara (el mismo método que el muro y el pilar de fuego: de canto no se ven como una raya) y llevan la silueta de
// T_wavesKI96 (un manojo de picos) recortada por un flujo de T_LiquidVertical_Wave que sube. Instancia: la base del transform es (ancho, 0, 0) · (0, alto, 0) · (hacia fuera, unitario);
// INSTANCE_CUSTOM = (semilla, retraso 0..1, -, opacidad).
//   subida 0 → 1     la lengua sube (con un pequeño rebote)
//   curva  0 → 1     la punta se curva HACIA FUERA y se inclina (cuerno)
//   caida  0 → 1     la lengua cae: se acorta y se desvanece
// Cada lámina escalona las tres con su retraso. Es agua: blend_mix, sin emisión ni luz.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D lengua : filter_linear_mipmap, repeat_disable;   // T_wavesKI96
uniform sampler2D liquido : filter_linear_mipmap, repeat_enable;   // T_LiquidVertical_Wave
uniform float subida : hint_range(0.0, 1.0) = 1.0;
uniform float curva : hint_range(0.0, 1.0) = 0.0;
uniform float caida : hint_range(0.0, 1.0) = 0.0;
uniform float curva_fuerza = 0.75;       // cuánto se desplaza la punta hacia fuera (× alto)
uniform float cuelga = 0.45;             // cuánto baja la punta al curvarse (× alto)
uniform float opacidad = 0.8;
uniform float ritmo = 0.6;

varying float v_sem;
varying float v_alfa;
varying float v_caida;
varying float v_sube;

void vertex() {
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 hacia = vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z);
	hacia = length(hacia) > 0.001 ? normalize(hacia) : vec3(0.0, 0.0, 1.0);
	v_sem = INSTANCE_CUSTOM.x;
	float dly = INSTANCE_CUSTOM.y;
	v_alfa = INSTANCE_CUSTOM.w;
	float s = clamp(subida * 1.5 - dly * 0.5, 0.0, 1.0);
	float c = clamp(curva * 1.5 - dly * 0.5, 0.0, 1.0);
	float f = clamp(caida * 1.5 - dly * 0.5, 0.0, 1.0);
	float g = smoothstep(0.0, 1.0, s) * (1.0 + 0.1 * sin(s * 3.14159));
	float hh = h * g * (1.0 - 0.85 * f * f);
	vec3 to = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
	float lh = length(to);
	to = lh > 0.001 ? to / lh : vec3(0.0, 0.0, 1.0);
	vec3 der = vec3(to.z, 0.0, -to.x);
	float vy = UV.y;
	float t = TIME * velocidad;
	float cv = vy * vy;
	// CADA LENGUA TIENE SU CURVA: cuánto se echa hacia fuera y cuánto cuelga la punta salen de su semilla (no son copias rígidas)
	float k1 = fract(v_sem * 1.7);
	float k2 = fract(v_sem * 2.9);
	float tiembla = (sin(t * 3.0 + v_sem * 9.0 + vy * 4.0) * 0.5) * 0.05 * w * vy;
	vec3 pos = MODEL_MATRIX[3].xyz + der * ((UV.x - 0.5) * w + tiembla) + vec3(0.0, vy * hh, 0.0);
	pos += hacia * (cv * h * curva_fuerza * (0.55 + 0.9 * k1) * c);            // la curva general hacia fuera
	pos += hacia * (vy * vy * vy * h * 0.42 * c * (0.5 + k2));                 // y la PUNTA se dobla aún más hacia fuera
	pos.y -= vy * vy * vy * h * cuelga * (0.55 + 0.75 * k2) * c * g;           // ... y cae
	pos += der * (sin(v_sem * 5.0) * 0.12 * w * cv * c);                       // se tuerce un poco de lado
	VERTEX = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to, 0.0)).xyz);
	v_caida = f;
	v_sube = s;
}

// onda triangular de periodo 2: la textura se refleja en vez de repetirse (sin costura horizontal)
float tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

void fragment() {
	float t = TIME * velocidad;
	vec2 uv = vec2(UV.x, UV.y);
	float volteo = step(0.5, fract(v_sem * 3.7));
	uv.x = mix(uv.x, 1.0 - uv.x, volteo);
	vec2 ua = vec2(uv.x * 0.9 + v_sem * 3.0, tri(1.0 - uv.y * 0.8 + t * ritmo + v_sem));
	vec2 ub = vec2(uv.x * 1.6 + 0.4 + v_sem * 5.0, tri(1.0 - uv.y * 1.3 + t * ritmo * 1.5));
	// solo el detalle de la textura (se le resta la media de la zona: sin su degradado de oscuro arriba a claro abajo)
	float n = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
	float n2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
	float sh = texture(lengua, vec2(uv.x, 1.0 - (uv.y * 0.9 + 0.06))).r;
	// silueta de LENGUA DE AGUA: HOMBRO grueso (la anchura máxima está a un tercio, no en la base), punta redondeada que se afila y una línea central que se tuerce a su manera (lean) en vez de un triángulo
	float vy = uv.y;
	float k1 = fract(v_sem * 1.7);
	float k2 = fract(v_sem * 2.9);
	float lean = (k2 - 0.5) * 0.36;
	float cx = 0.5 + lean * vy * vy + 0.05 * sin(vy * 5.0 + v_sem * 6.0) * vy;
	float hw = 0.5 * pow(clamp(1.0 - pow(vy, 1.45 + 0.9 * k1), 0.0, 1.0), 0.5 + 0.3 * k1);
	hw *= 0.4 + 0.6 * (1.0 - smoothstep(0.62, 1.0, vy));
	hw *= 0.9 + 0.2 * sin(vy * 7.0 + v_sem * 4.0);                  // algo de onda en el contorno
	hw = max(hw, 0.075 * sqrt(clamp(1.0 - smoothstep(0.86, 1.0, vy), 0.0, 1.0)));      // la punta es una gota redondeada, no una aguja
	float ex = abs(uv.x - cx) + (n2 - 0.5) * 0.08 * (0.25 + vy) + (sh - 0.5) * 0.04;
	float forma = 1.0 - smoothstep(hw * 0.62, hw + 0.004, ex);
	float borde = smoothstep(hw * 0.5, hw * 0.9 + 0.004, ex);                // franja de espuma pegada al borde de la lengua
	float punta_f = smoothstep(0.72, 0.95, uv.y);
	float v = 0.20 + 0.30 * n + 0.16 * n2 + 0.62 * borde * forma + 0.10 * sh + 0.28 * punta_f * (0.4 + 0.6 * n) + 0.34 * (1.0 - smoothstep(0.0, 0.14, uv.y));
	ALBEDO = agua_tonos(v, 0.44, 0.78, 0.07) * brillo;
	float a = forma * (0.8 + 0.2 * n) * opacidad * v_alfa * (1.0 - smoothstep(0.65, 1.0, v_caida)) * smoothstep(0.0, 0.05, v_sube);
	ALPHA = clamp(a, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
