shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CORTINA DE AGUA DEL PILAR / GÉISER (fase 3, 3/11/2026). Un tubo abierto (AguaMallas.tubo: UV.x = vuelta, UV.y = 0 en el suelo y 1 en la cresta) cuyo VÉRTICE SHADER hace la columna:
//   · `crece` (0 → ~1,15 → 1) la sube desde el suelo con un pico de altura; `corte` (0 → 1) la DESPLOMA: la altura cae con la gravedad (~corte²) SIN ensancharse y el agua se va tarde y por igual en toda
//     la altura (16/11: antes reventaba hacia fuera ×2,3 como un chapoteo radial y se leía como una flor que se abre; deshacerse es perder presión, no explotar).
//   · base apenas abocinada (sale a presión de un punto, no de una flor), labio abierto arriba y un balanceo que sube; el borde de arriba es irregular (ruido por vuelta): lenguas, no un corte recto.
//   · `latido` (lo pone AguaToy, ~1 ± 0,03) respira la altura mientras vive; AguaToy.pilar_cresta() usa el MISMO valor, por eso no sale de TIME aquí.
//   · `falda` = 1: la capa que REBOSA de la cresta y CAE por fuera (radio 1,28 abajo → 1,58 arriba, pegada a la columna), con la textura fluyendo hacia ABAJO, rota por el ruido (huecos) y más visible
//     arriba. Sube por dentro, cae por fuera: eso es lo que convierte un tubo en un géiser.
// FRAGMENT: T_LiquidVertical_Wave con flujo hacia ARRIBA (dos capas a distinta escala y velocidad), tres tonos por umbral, borde claro por fresnel y espuma en la base y en la cresta. Translúcido
// (blend_mix, sin emisión ni luz). La capa «Nucleo» es la misma malla más fina, más clara y más rápida.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D liquido : filter_linear_mipmap, repeat_enable;    // T_LiquidVertical_Wave
uniform float rx = 0.5;
uniform float rz = 0.5;
uniform float alto = 4.0;
uniform float rep_x = 2.0;               // repeticiones de la textura alrededor
uniform float crece : hint_range(0.0, 1.3) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float grosor = 1.0;
uniform float nucleo = 0.0;
uniform float opacidad = 0.6;
uniform float ritmo = 0.5;               // flujo hacia arriba
uniform float semilla = 0.0;
uniform float falda : hint_range(0.0, 1.0) = 0.0;    // 1 = la capa que cae por fuera
uniform float latido = 1.0;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;

varying float v_a;
varying float v_y;
varying float v_m;
varying float v_top;
varying float v_rest;

void vertex() {
	float a = UV.x;
	float s = UV.y;
	float t = TIME * velocidad;
	float caida = clamp(corte / 0.5, 0.0, 1.0);       // la columna llega al suelo a corte 0,5 (antes 0,7): la lámina radial necesita la otra mitad para abrirse despacio
	caida *= caida;
	float hh = max(crece, 0.0) * (1.0 - caida) * latido;
	float n = textureLod(flujo, vec2(a * 2.0 + semilla, t * 0.12 + semilla), 0.0).r;
	float tope = hh * (1.0 + 0.2 * (n - 0.5)) * alto;
	float y = s * tope * mix(1.0, 0.9, falda);      // el borde de arriba de la falda queda POR DEBAJO de la cresta de la cortina
	float svert = hh * alto;
	// el abocinado de la base y el labio de arriba se miden respecto al radio de referencia (0,5 m): en un pilar ancho el mismo porcentaje daba un «tambor con campana» (cintura estrecha entre base y labio)
	float kr = clamp(0.5 / max((rx + rz) * 0.5, 0.05), 0.35, 1.0);
	float flare = 1.0 + 0.35 * kr * exp(-y * 2.4) * (1.0 - 0.6 * corte);
	float sc = mix(s, s * 0.9, falda);              // la falda sigue el radio que tiene la cortina a su misma altura
	float labio = 1.0 + 0.22 * kr * smoothstep(0.82, 1.0, sc) + 0.1 * kr * smoothstep(0.55, 0.8, sc) * (0.5 + 0.5 * sin(t * 2.0 + a * 6.2832 * 2.0));
	float bal = 1.0 + 0.07 * ondulacion * sin(y * 4.5 - t * 5.0 + a * 12.566 + semilla * 3.0);
	float ensancha = 1.0 + 0.08 * caida;
	// PILAR BAJO Y ANCHO (16/11, «se lee regular»: un tambor de paredes rectas con un cilindro blanco dentro): cuando el alto no llega a ~3 radios la columna deja de ser un tubo y se
	// ESTRECHA hacia arriba, como un borbotón que empuja desde abajo; el núcleo se estrecha más (chorro dentro del borbotón). Con alto / radio ≥ 3 (el pilar de referencia, 8) no cambia nada.
	float chato = 1.0 - smoothstep(1.2, 3.0, alto / max((rx + rz) * 0.5, 0.05));
	float estrecha = 1.0 - chato * mix(0.42, 0.62, nucleo) * pow(sc, mix(1.6, 1.0, nucleo));
	float rm = flare * labio * bal * ensancha * grosor * estrecha;
	// FALDA: nace del labio (arriba sale pegada a la cortina), se abre en seta justo debajo (máximo hacia s = 0,85) y desde ahí cae recta cerrándose un poco. La separación se mide en METROS
	// (0,12-0,30 m, suave con el radio): con un factor multiplicativo un pilar de 1,3 m sacaba una campana de 2 m (medusa) y de dos fundas de cristal concéntricas.
	float sep = clamp(0.12 + 0.1 * (rx + rz) * 0.5, 0.12, 0.30);
	float seta = smoothstep(1.0, 0.85, s) * (1.0 - 0.3 * clamp((0.85 - s) / 0.55, 0.0, 1.0));
	float off = falda * sep * seta;
	float ang = a * 6.2831853;
	VERTEX = vec3(cos(ang) * (rx * rm + off), y, sin(ang) * (rz * rm + off));
	NORMAL = normalize(vec3(cos(ang) / max(rx, 0.01), 0.0, sin(ang) / max(rz, 0.01)));
	v_a = a;
	v_y = s;
	v_m = y;
	v_rest = 1.0 - caida;
	v_top = clamp(svert / max(alto, 0.01), 0.0, 1.2);
}

// onda triangular de periodo 2: la textura se refleja en vez de repetirse (sin costura horizontal cada pocos metros)
float tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

void fragment() {
	float t = TIME * velocidad;
	float sen = 1.0 - 2.0 * falda;                  // +1 la columna sube, -1 la falda baja
	vec2 ua = vec2(v_a * rep_x + semilla, tri(1.0 - v_m * 0.40 + sen * t * ritmo));
	vec2 ub = vec2(v_a * round(rep_x * 1.7) + 0.31 + semilla * 1.3, tri(1.0 - v_m * 0.72 + sen * t * ritmo * 1.6));
	// solo el DETALLE de la textura (sin su degradado de oscuro arriba a claro abajo): la media de la zona se resta
	float d1 = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
	float d2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
	float cau = agua_cau(vec2(v_a * rep_x * 1.3, v_m * 0.5 - t * 0.2) + semilla, t);
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	fres = pow(clamp(fres, 0.0, 1.0), 1.6);
	float base = exp(-v_m * 1.8);
	float cresta = smoothstep(0.80, 0.97, v_y);
	float v = 0.22 + 0.40 * d1 + 0.22 * d2 + 0.08 * cau + 0.30 * fres + 0.20 * base + 0.30 * cresta + nucleo * (0.2 + 0.12 * d1);
	vec3 col = agua_tonos(v, 0.46, 0.82, 0.07);
	col = agua_cau_color(col, cau, 0.3);
	col = agua_borde(col, fres, 0.5);
	ALBEDO = col * brillo;
	float a = opacidad * (0.55 + 0.30 * d1 + 0.30 * fres + 0.25 * base + 0.2 * cresta);
	a *= 1.0 - smoothstep(0.90, 1.0, v_y) * (0.55 + 0.45 * d2) * (1.0 - falda);
	a *= smoothstep(0.0, 0.03, v_y);
	// pilar bajo y ancho: el núcleo, que ahí es grande, va más transparente (macizo se leía como un cubo blanco boca abajo dentro del agua)
	a *= 1.0 - 0.45 * nucleo * (1.0 - smoothstep(1.2, 3.0, alto / max((rx + rz) * 0.5, 0.05)));
	// la falda: rota por el ruido (huecos), más visible en el tercio de arriba y perdiéndose hacia el suelo; no tapa la columna
	// HILOS verticales: bandas de alta frecuencia alrededor (nº entero por vuelta: sin costura) con huecos claros entre ellas, que bajan con la textura. Se pierde entre el 25 y el 60 % de la altura
	// (más abajo solo quedan gotas y espuma) y casi desaparece en pilares bajos, donde manda la columna.
	float nh = 4.0 * rep_x;
	float hilo = 0.5 + 0.5 * sin(v_a * 6.2831853 * nh + 2.0 * sin(v_a * 6.2831853 * 3.0 + semilla * 5.0) + v_m * 0.5 + t * 0.8);
	float hueco = smoothstep(0.42, 0.68, 0.65 * hilo + 0.35 * d1);
	float vis = smoothstep(0.25, 0.6, v_y) * (1.0 - smoothstep(0.84, 0.98, v_y)) * smoothstep(0.7, 1.0, crece) * smoothstep(1.4, 2.6, alto);
	a = mix(a, a * hueco * vis, falda);
	// al morir el agua se va TARDE (que se vea caer) y por igual en toda la altura
	a *= 1.0 - smoothstep(0.55, 0.9, corte);
	a *= smoothstep(0.04, 0.3, v_rest);            // y baja con la altura que queda: el muñón corto del final casi no se ve
	ALPHA = clamp(a, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
