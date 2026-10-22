extends MeshInstance3D
class_name AguaRender3D
## DIBUJO DEL AGUA DESDE LA SIMULACIÓN (Fase 11.7, 12/10). Lo escribe el Pipeline; la simulación (AguaSim3D) es del Juego.
##
## Qué hace: lee `AguaSim3D.imagen()` (un texel por trocito de suelo: R = Y de la superficie, G = profundidad, B/A = corriente
## en u/s) y dibuja el agua como una malla de rejilla con UN VÉRTICE POR CENTRO DE TROCITO. Así se VE llenarse (los vértices
## suben con la superficie), rebosar y nivelarse, y el borde del agua sigue la orilla real de la simulación, no una letra.
##
## Por qué una rejilla y no el plano de antes: el plano de CODIGO_AGUA era un bloque por casilla «~» con la superficie fija;
## aquí la superficie la manda la simulación, trocito a trocito (0,77 u), y la profundidad y la corriente llegan al sombreado.
##
## Aspecto: el estilizado que aprobó Pablo (13/10 (8)): facetas planas que se inclinan, dos tonos en bandas por la
## profundidad, espuma nítida en la orilla y manchas de espuma de dos ruidos. Añade lo que la simulación sabe y la letra no:
## franjas que corren hacia donde va el agua de verdad (flow map de dos fases) y espuma donde la corriente es fuerte.
##
## Uso:
##   var r := AguaRender3D.new(); add_child(r); r.enlazar(sim)      # sim: AguaSim3D
## Se actualiza solo (`hz_actualizacion` veces por segundo, no cada fotograma: el agua no cambia tan deprisa, y el
## sombreado interpola entre dos actualizaciones para que no se vea a saltos).
## `fuente_ondas(textura, origen_xz, lado)` enchufa las ondas de AguaOndas3D (11.8; mejor `ondas.conectar(render)`); sin ellas, el agua queda lisa.
##
## 13.9 (15/10, a petición de Pablo; lo escribe el Juego en `presentacion/`): EL AGUA OCUPA ESPACIO.
##   (a) PAREDES LATERALES: donde el agua toca tierra, pared o un trocito seco se dibuja la cara vertical del agua (`_paredes`, una malla
##       aparte que se rehace al leer la simulación, solo en la caja de trabajo): se ve el grosor, no solo la superficie. Solo lo que
##       sobresale del suelo de al lado (si la orilla es más alta que el agua, la tierra la tapa y no hay nada que dibujar).
##       Para que la pared y la superficie se junten, el vértice seco de la orilla toma la altura del agua vecina (antes `min(suelo, agua)`).
##   (b) OPACIDAD Y COLOR POR PROFUNDIDAD: `prof_clara` (0,1 u: casi transparente, color somero) → `prof_rio` (1,4 u: azul del río, casi opaco; era 0,9 hasta el 16/10).
##   (c) TOPES DE SUPERFICIE: `poner_topes({casilla: y})` / `proveedor_topes` limitan la Y a la que se DIBUJA el agua de una casilla.
##       Es para el canal de piedra: el cauce admite unos 0,37 u de agua (borde a 0,475 u del suelo, fondo a 0,107 u, medido en la pieza)
##       y la simulación llega a 0,48 u en la primera casilla; sin tope el agua sobresalía 0,11 u por encima de la piedra y se veía un tubo.
##   (d) MENISCO: franja clara y tenue por dentro de la orilla (el agua sube un poco contra el borde) y espuma de orilla arrastrada por
##       el flow map (la corriente mueve el ruido del borde). En las paredes, un filo claro arriba.
##   (e) ONDAS: ver `AguaOndas3D` (la maqueta la monta y la conecta; las gotas que caen llaman a `impulso`).
##
## HIELO (11.14, 12/10): si la simulación tiene `textura_hielo()` (RG8: R = 1 helado, G = lo que le queda, 0-1; mismo origen y texel
## que `imagen()`), los trocitos helados se pintan como hielo: blanco azulado y opaco, en facetas con grietas, un poco más alto que el
## agua y sin franjas, espuma ni ondas. Al helarse CRECE desde el punto del impacto en ~0,3 s; al derretirse se deshace en ~0,3 s;
## con G < 0,15 se abren grietas y se oscurece (avisa de que se va a romper). El tiempo de cada trocito (cuándo se heló, cuándo se
## soltó) se guarda aquí, en una textura propia, porque la simulación solo dice «helado sí/no». El punto del impacto se deduce del
## centro de lo que se heló de golpe; si el Juego quiere dar el exacto, llama a `hielo_desde(pos)` justo antes de helar.

## Veces por segundo que se lee la simulación (el contrato del Juego pide 10–15).
@export var hz_actualizacion: float = 12.0
## Debajo de esta profundidad (u) un trocito es lámina de suelo mojado, no agua que se vea como tal (contrato: ~0,05).
@export var profundidad_minima: float = 0.05

# --- 22/10 (agua EoW, PLAN_EOW_VISUAL §1.6 y §2 fila «Agua»): REFRACCIÓN y TERCERA ESCALA DE OLAS. Todo en constantes con nombre; el shader recibe estos números al enlazar. ---
## Interruptor de la refracción (también `agua_refraccion` en la maqueta). Apagado = el agua de antes: mezcla por alfa sobre lo que ya hay dibujado, sin leer la pantalla.
const REFRACCION: bool = true
## Cuánto desplaza la inclinación de las olas al fondo, en u de mundo por unidad de inclinación y por u de profundidad (hasta `REFR_PROF_TOPE`). 0,9 u de agua con facetas de 0,3 de pendiente = ~0,16 u.
const REFR_FUERZA: float = 0.8
## Profundidad (u) a partir de la cual la refracción ya no crece (el río hondo no deforma el doble que el estanque).
const REFR_PROF_TOPE: float = 0.6
## Profundidad de agua (u) con la que la refracción llega entera: más cerca de la orilla se atenúa (no hay agua que doble nada y se verían fantasmas de tierra).
const REFR_ORILLA: float = 0.30
## Margen (u) con el que se descarta lo que está DELANTE del agua o por ENCIMA de su lámina (árboles, la chibi, el bloque de la orilla): pasan de 0 a 1 en este rango.
const REFR_MARGEN: float = 0.05
## Franja (fracción de pantalla) pegada al borde en la que la refracción se apaga: la textura de pantalla no tiene nada más allá y estiraría el último píxel.
const REFR_BORDE: float = 0.04
## Prioridad de dibujo del agua entre lo transparente: la primera, para que el fuego, los VFX y la hierba que se dibujan después queden ENCIMA (con refracción el agua deja de ser
## una mezcla y tapa lo que se dibuje antes). Las paredes laterales, justo después.
const AGUA_PRIORIDAD: int = -3
const PARED_PRIORIDAD: int = -2
## Tercera escala de olas: un oleaje AMPLIO y lento (las facetas de 0,75 u y el ruido fino de las ondas ya estaban) que inclina grupos enteros de facetas, con su propia dirección,
## velocidad y amplitud. Se suma a la altura de las olas que las facetas leen en sus vértices, así que sigue siendo plano por facetas y viaja con la corriente como las demás.
const OLA3_ACTIVA: bool = true
const OLA3_ALTURA: float = 0.85        ## amplitud en las unidades de `ola_est` (la suma de las tres olas de siempre llega a ±1,1)
const OLA3_LONGITUD: float = 5.5       ## u de cresta a cresta (las olas de siempre miden ~2,7-3,3 u)
const OLA3_VEL: float = 0.55           ## rad/s
const OLA3_RUMBO: float = 200.0        ## grados (en XZ) hacia donde avanza
const OLA3_CRUCE: float = 68.0         ## grados que gira la segunda onda que se cruza con la primera (rompe las rayas)

@export var agua_refraccion: bool = REFRACCION:
	set(v):
		agua_refraccion = v
		_aplicar_eow()
@export var olas_tercera_escala: bool = OLA3_ACTIVA:
	set(v):
		olas_tercera_escala = v
		_aplicar_eow()

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D datos_a : filter_nearest, repeat_disable;     // lectura anterior de la simulación (R altura, G prof, BA corriente)
uniform sampler2D datos_b : filter_nearest, repeat_disable;     // lectura última
uniform float mezcla = 1.0;                                     // 0 = a, 1 = b (interpola entre dos lecturas)
uniform float minima = 0.05;

uniform vec3 color_somero_est : source_color = vec3(0.44, 0.80, 0.91);
uniform vec3 color_hondo_est : source_color = vec3(0.20, 0.52, 0.80);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform float hondura = 1.5;                  // (sin uso desde 13.9: el color y la opacidad salen de prof_clara / prof_rio)
uniform float prof_clara = 0.1;               // 13.9: a esta profundidad (u) el agua es somera: color claro y casi transparente
uniform float prof_rio = 1.4;                 // y a esta, la OPACIDAD llega al río. 16/10 (14.2 d): 0,9 → 1,4 para que el lecho (0,9 u en el río) se vea: con 0,9 la parte honda era opaca (alfa 0,95) y tapaba el fondo
uniform float prof_color = 0.9;               // el COLOR somero→hondo sigue su rampa de siempre (0,9): separado de la opacidad para que ver el fondo no lave el azul
uniform float alfa_clara = 0.2;
uniform float alfa_rio = 0.95;
uniform float menisco = 0.55;                 // fuerza de la franja clara de la orilla
// 15/10 (DIARIO 95) · CORRIENTE DEL RÍO Y CAÍDAS.
uniform sampler2D flujo : filter_nearest, hint_default_black, repeat_disable;   // RG = dirección × tamaño (0-1) de la corriente propia del río, por trocito (`proveedor_flujo`)
uniform float flujo_activo = 0.0;
uniform float vel_rio = 0.9;                  // u/s que se suman a la corriente de la simulación en la dirección del flujo (0 = el río no corre solo)
uniform float avance_flujo = 1.5;             // cuánto avanzan franjas, olas y espuma por ciclo y por u/s de corriente (antes 0,9: iban a la mitad)
uniform float adveccion_olas = 1.0;           // 0 = las facetas y la espuma no viajan con la corriente
uniform float caida_fuerza = 1.0;             // 0 = sin efecto de cascada
uniform float caida_pend_min = 0.12;          // inclinación (1 − normal.y) a partir de la cual la superficie es una caída
uniform float vel_caida = 1.6;                // velocidad (u/s) de las vetas de la cortina
uniform sampler2D topes : filter_nearest, hint_default_black, repeat_disable;   // 13.9 (c): Y máxima a la que se dibuja cada trocito (0 = sin tope)
uniform float topes_activos = 0.0;
uniform float bandas = 3.0;                   // escalones entre somero y hondo
uniform float faceta = 0.75;                  // lado de los triángulos de las olas (u)
uniform float altura_ola = 0.32;
uniform float contraste_faceta = 0.2;
uniform float espuma_manchas = 0.5;
uniform float ruido_orilla = 0.11;            // 16/10: cuánto desordena el ruido el contorno del agua (u de profundidad; ~0,3 u de orilla). 0 = recto, como antes
uniform float lecho = 0.5;                    // 16/10: fuerza del LECHO falso (la profundidad que se ve a través del agua); 0 = sin lecho
uniform float prof_lecho = 0.9;               // cuánto se desplaza el lecho por unidad de profundidad (paralaje)
uniform vec3 color_lecho : source_color = vec3(0.16, 0.38, 0.55);     // el fondo visto a través: más oscuro y frío que la arena
uniform vec3 color_causticas : source_color = vec3(0.72, 0.93, 1.0);  // las redes de luz que dibuja el agua sobre el lecho
uniform float transicion_orilla = 0.08;       // profundidad (u) en la que la espuma de la orilla se funde con el agua
uniform float vel_espuma = 1.1;               // desde esta corriente (u/s) rompe en espuma
uniform float tam_franja = 0.8;               // tamaño de las franjas de la corriente (u)
uniform float vel_franja = 0.55;              // ciclos por segundo del flow map
uniform float brillo = 1.0;
uniform float contraste = 1.2;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);

// 22/10 (agua EoW) · REFRACCIÓN. Con `refraccion` = 1 el fondo que se ve a través del agua es la pantalla ya dibujada (lo opaco: el lecho de verdad y los
// bloques bajo la lámina), desplazada por la inclinación de las olas. Para eso el agua pasa a ser «opaca» (ALPHA = 1) y su mezcla por alfa la hace ella misma:
// ALBEDO = color × alfa y EMISSION = fondo × (1 − alfa). Con 0 es el agua de antes, sin leer la pantalla.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D prof_escena : hint_depth_texture, repeat_disable, filter_nearest;
uniform float refraccion = 0.0;
uniform float refr_fuerza = 0.8;
uniform float refr_prof_tope = 0.6;
uniform float refr_orilla = 0.3;
uniform float refr_margen = 0.05;
uniform float refr_borde = 0.04;
// 22/10 (agua EoW) · TERCERA ESCALA DE OLAS (ver OLA3_* en GDScript). ola3_altura = 0 la apaga.
uniform float ola3_altura = 0.0;
uniform float ola3_k = 1.14;                  // 2π / longitud
uniform float ola3_vel = 0.55;
uniform vec2 ola3_dir = vec2(-0.94, -0.34);
uniform vec2 ola3_dir2 = vec2(0.1, -0.99);
varying float v_spec;                         // cuánto del brillo especular se ve: el alfa del agua con refracción (sin ella el alfa ya lo atenúa al mezclar), 1 sin ella

// Ondas que reaccionan (11.8): textura de AguaOndas3D, R = altura (u). La pendiente y las crestas salen de ella. Sin ella, quedan a cero.
uniform sampler2D ondas : filter_linear, hint_default_black, repeat_disable;
uniform vec3 ondas_rect = vec3(0.0, 0.0, 1.0);   // x0, z0 y lado (u) de la zona que cubre la textura
uniform float ondas_fuerza = 0.0;                // 0 = sin ondas

// Hielo (11.14): hielo_t por trocito, RGF: R = segundo en que empezó a helarse, G = segundo en que empezó a soltarse (solo cambia al helar o soltar).
// hielo_g es la textura_hielo() tal cual (RG8): su G = lo que le queda al hielo (0-1), que baja sola con el tiempo.
uniform sampler2D hielo_t : filter_nearest, hint_default_black, repeat_disable;
uniform sampler2D hielo_g : filter_nearest, hint_default_white, repeat_disable;
uniform float hielo_activo = 0.0;
uniform float reloj = 0.0;                    // segundos propios del dibujo (los de hielo_t van con este reloj)
uniform float lado_trocito = 0.7667;
uniform float alto_hielo = 0.07;              // cuánto sobresale el hielo del agua (u)
// 20/10 (DIARIO 211) · DOS RETOQUES. Los valores reales los manda GDScript (`BAJADA_LAMINA`, `ORILLA_MOV`); estos son solo por defecto.
uniform float bajada_lamina = 0.08;           // cuánto se baja toda la lámina (u) respecto a lo que dice la simulación, para que los bloques de al lado la sobresalgan
uniform float orilla_mov = 0.02;              // amplitud (u) del vaivén vertical de las casillas de agua que tocan tierra; 0 = quieta
uniform float crece_s = 0.1;                  // lo que tarda un trocito en pasar de agua a hielo una vez le toca
uniform float funde_s = 0.2;                  // y en deshacerse una vez le toca (cada trocito con un retraso al azar de hasta 0,12 s)
uniform float aviso_umbral = 0.15;            // por debajo de este G aparecen las grietas grandes
uniform vec3 color_hielo_claro : source_color = vec3(0.70, 0.84, 0.96);
uniform vec3 color_hielo_hondo : source_color = vec3(0.46, 0.66, 0.88);
uniform vec3 color_grieta : source_color = vec3(0.30, 0.50, 0.76);
uniform float tam_faceta_hielo = 1.3;         // tamaño de las facetas del hielo (u)

varying float v_prof;
varying vec2 v_corr;
varying vec3 v_pos;
varying float v_oleaje;                // -1..1: el vaivén de orilla de este vértice (0 lejos de tierra); el fragmento lo usa para ensanchar la espuma
varying vec2 v_caida;                 // x = cuánto sube el vecino más alto (base de una caída), y = cuánto baja el más bajo (labio); en pendiente (u de altura / u de trocito)

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Cuánto hielo hay en un trocito ahora (0-1): crece desde su segundo de inicio y se deshace desde el de fin, cada uno con un retraso propio.
float hielo_f(ivec2 p) {
	ivec2 s = textureSize(hielo_t, 0);
	p = clamp(p, ivec2(0), s - 1);
	vec4 h = texelFetch(hielo_t, p, 0);
	float crece = clamp((reloj - h.r) / crece_s, 0.0, 1.0);
	float funde = clamp((reloj - h.g - hash(vec2(p) * 0.37) * 0.12) / funde_s, 0.0, 1.0);
	return crece * (1.0 - funde);
}

// (hielo, aviso) en un punto del mundo: bilineal entre los cuatro trocitos de alrededor.
vec2 hielo_ab(vec2 xz) {
	vec2 tp = xz / lado_trocito - 0.5;
	ivec2 i0 = ivec2(floor(tp));
	vec2 f = fract(tp);
	ivec2 s = textureSize(hielo_t, 0);
	float h00 = hielo_f(i0);
	float h10 = hielo_f(i0 + ivec2(1, 0));
	float h01 = hielo_f(i0 + ivec2(0, 1));
	float h11 = hielo_f(i0 + ivec2(1, 1));
	float a00 = texelFetch(hielo_g, clamp(i0, ivec2(0), s - 1), 0).g;
	float a10 = texelFetch(hielo_g, clamp(i0 + ivec2(1, 0), ivec2(0), s - 1), 0).g;
	float a01 = texelFetch(hielo_g, clamp(i0 + ivec2(0, 1), ivec2(0), s - 1), 0).g;
	float a11 = texelFetch(hielo_g, clamp(i0 + ivec2(1, 1), ivec2(0), s - 1), 0).g;
	// El aviso se pondera por cuánto hielo hay en cada trocito (un trocito sin hielo no debe contagiar su G).
	float w00 = (1.0 - f.x) * (1.0 - f.y) * h00;
	float w10 = f.x * (1.0 - f.y) * h10;
	float w01 = (1.0 - f.x) * f.y * h01;
	float w11 = f.x * f.y * h11;
	float sw = w00 + w10 + w01 + w11;
	float hielo = sw;
	float g = sw > 0.0001 ? (w00 * a00 + w10 * a10 + w01 * a01 + w11 * a11) / sw : 1.0;
	return vec2(hielo, 1.0 - smoothstep(0.0, aviso_umbral, g));
}

vec4 dato(ivec2 p) {
	ivec2 s = textureSize(datos_a, 0);
	p = clamp(p, ivec2(0), s - 1);
	return mix(texelFetch(datos_a, p, 0), texelFetch(datos_b, p, 0), mezcla);
}

void vertex() {
	ivec2 s = textureSize(datos_a, 0);
	ivec2 p = ivec2(floor(UV * vec2(s)));
	vec4 d = dato(p);
	float y = d.r;
	float prof = d.g;
	vec2 corr = d.ba;
	float orilla = 0.0;                              // 1 = casilla de agua con algún vecino seco/tierra (la franja de orilla de 125)
	if (d.g < minima) {
		// Trocito seco: baja el vértice a la altura del agua vecina (si no, la orilla de tierra más alta lo levantaría y
		// el borde saldría torcido) y su profundidad pasa a NEGATIVA: así el borde del agua cae en medio, entre el último
		// trocito mojado y el primero seco, en vez de pegarse al centro del seco.
		float mejor = -1.0;
		float hs = 0.0;
		vec2 cs = vec2(0.0);
		ivec2 dirs[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int k = 0; k < 4; k++) {
			vec4 n = dato(p + dirs[k]);
			if (n.g >= minima && n.g > mejor) {
				mejor = n.g;
				hs = n.r;
				cs = n.ba;
			}
		}
		if (mejor > 0.0) {
			orilla = 1.0;              // 20/10: este vértice seco que adopta el agua vecina ES la orilla
			y = hs;                    // 13.9: a ras del agua vecina (la pared vertical baja desde aquí; ver `_reconstruir_paredes`)
			prof = -mejor;
			corr = cs;
		} else {
			prof = -1.0;
		}
	}
	if (flujo_activo > 0.5 && prof > 0.0) {
		corr += texelFetch(flujo, clamp(p, ivec2(0), s - 1), 0).rg * vel_rio;     // la corriente propia del río (cae a cero hacia las orillas)
	}
	float base_c = 0.0;
	float labio_c = 0.0;
	if ((caida_fuerza > 0.0 || orilla_mov > 0.0) && d.g >= minima) {
		ivec2 dir2[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int k = 0; k < 4; k++) {
			vec4 n2 = dato(p + dir2[k]);
			if (n2.g >= minima) {
				float dy = (n2.r - d.r) / lado_trocito;
				base_c = max(base_c, dy);
				labio_c = max(labio_c, -dy);
			} else {
				orilla = 1.0;
			}
		}
	}
	v_caida = vec2(base_c, labio_c);
	if (hielo_activo > 0.5) {
		y += alto_hielo * hielo_f(p);                  // el hielo sobresale un poco: se ve una losa, no una mancha
	}
	if (topes_activos > 0.5) {
		float tp = texelFetch(topes, clamp(p, ivec2(0), s - 1), 0).r;
		if (tp > 0.0) {
			y = min(y, tp);
		}
	}
	// 20/10 (a): la lámina baja un margen fijo. Se limita a la mitad de la profundidad para que una lámina fina no atraviese su lecho;
	// con el agua llena (prof > 2·bajada) la bajada es siempre `bajada_lamina`, igual en pozo, canal y estanque. Va al final, después
	// de los topes y del hielo, para que todo lo que se dibuja baje a la vez. `_reconstruir_paredes` aplica la misma cuenta a la cima de la pared.
	y -= min(bajada_lamina, 0.5 * abs(prof));
	// 20/10 (b): vaivén tenue de la orilla. Dos senos de periodos distintos (3,7 s y 2,3 s) desfasados por posición, para que la orilla no respire
	// entera a la vez. Amplitud total ≤ `orilla_mov`. Es un movimiento de la superficie, no de la simulación: no cambia profundidad ni corriente.
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float oleaje = 0.55 * sin(TIME * 1.698 + dot(wp, vec2(1.3, 0.9))) + 0.45 * sin(TIME * 2.732 + dot(wp, vec2(-0.7, 1.6)));
	oleaje *= orilla * (hielo_activo > 0.5 ? 1.0 - hielo_f(p) : 1.0);        // el hielo no se mece
	y += orilla_mov * oleaje;
	v_oleaje = oleaje;
	VERTEX.y = y;
	v_prof = prof;
	v_corr = corr;
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ola_est(vec2 p, float t) {
	float h = sin(p.x * 1.9 + t * 1.1) * 0.5 + sin(p.y * 2.3 - t * 0.9) * 0.35 + sin((p.x + p.y) * 1.3 + t * 0.7) * 0.25;
	// Tercera escala (agua EoW): dos ondas largas que se cruzan, con su rumbo, velocidad y amplitud. Con ola3_altura = 0 no suma nada.
	h += ola3_altura * (0.6 * sin(dot(p, ola3_dir) * ola3_k - t * ola3_vel) + 0.4 * sin(dot(p, ola3_dir2) * ola3_k * 0.8 - t * ola3_vel * 0.7 + 1.7));
	return h;
}

// Normal plana del triángulo de la rejilla de olas en el que cae `p` (la misma rejilla girada y sesgada del agua estilizada
// de antes: triángulos casi equiláteros, sin cuadros alineados con las casillas).
const mat2 GIRO_FACETA = mat2(vec2(0.90, 0.43), vec2(-0.43, 0.90));
const mat2 SESGO_FACETA = mat2(vec2(1.0, 0.0), vec2(-0.577, 1.155));
vec3 normal_faceta(vec2 p, float t) {
	vec2 g = SESGO_FACETA * (GIRO_FACETA * p) / faceta;
	vec2 b = floor(g);
	vec2 f = fract(g);
	vec2 a1 = f.x > f.y ? b + vec2(1.0, 0.0) : b + vec2(1.0, 1.0);
	vec2 a2 = f.x > f.y ? b + vec2(1.0, 1.0) : b + vec2(0.0, 1.0);
	vec3 v0 = vec3(b.x, ola_est(b * faceta, t) * altura_ola / faceta, b.y);
	vec3 v1 = vec3(a1.x, ola_est(a1 * faceta, t) * altura_ola / faceta, a1.y);
	vec3 v2 = vec3(a2.x, ola_est(a2 * faceta, t) * altura_ola / faceta, a2.y);
	vec3 n = normalize(cross(v2 - v0, v1 - v0));
	return n.y < 0.0 ? -n : n;
}

// Celdas de Voronoi: x = distancia al centro de la celda más cercana, y = distancia a la arista (F2 - F1), z = número al azar de la celda.
vec3 celdas(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o * 0.85 + 0.075 - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + 5.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

// Franjas alargadas en el sentido de la corriente: ruido estirado a lo largo de `dir`.
float franja(vec2 uv, vec2 dir) {
	vec2 per = vec2(-dir.y, dir.x);
	float a = dot(uv, dir);
	float b = dot(uv, per);
	return ruido(vec2(a * 0.45, b * 3.2));
}

void fragment() {
	vec3 pm = v_pos;
	// 16/10 (Pablo: «ruido entre la textura de la orilla y el agua»): la profundidad se interpola entre vértices de 0,77 u y su línea de cero sale
	// recta y en diagonales; se le suma un ruido de dos escalas (quieto, casi sin deriva: no debe parpadear) para que el borde sea irregular.
	// El mismo `prof_e` rige el corte, la línea de espuma y el menisco, así que espuma y arena siguen el mismo contorno.
	float ruido_borde = ruido(pm.xz * 2.7 + vec2(TIME * 0.02, 0.0)) * 0.65 + ruido(pm.xz * 6.3 - 4.1) * 0.35;
	float prof_e = v_prof + (ruido_borde - 0.5) * ruido_orilla * 2.0;
	if (prof_e < 0.0) {
		discard;                       // fuera del agua: el borde sigue la orilla de la simulación (con ruido)
	}
	vec2 corr = v_corr;
	float vel = length(corr);
	// Flow map de dos fases (franjas, facetas y espuma): desfasadas medio ciclo y mezcladas, así nada «salta» al reiniciarse.
	vec2 dir = vel > 0.001 ? corr / vel : vec2(1.0, 0.0);
	float fase0 = fract(TIME * vel_franja);
	float fase1 = fract(TIME * vel_franja + 0.5);
	float peso0 = 1.0 - abs(2.0 * fase0 - 1.0);
	float avance = clamp(vel, 0.0, 2.5) * avance_flujo;

	// Hielo (11.14): cuánto hay aquí y cuánto avisa de que se rompe. El borde es irregular (ruido) y suave (smoothstep).
	float hielo = 0.0;
	float aviso = 0.0;
	if (hielo_activo > 0.5) {
		vec2 ha = hielo_ab(pm.xz);
		hielo = smoothstep(0.36, 0.64, ha.x + (ruido(pm.xz * 2.6) - 0.5) * 0.32);
		aviso = ha.y;
	}

	// Inclinación real de la superficie (una caída o una pendiente) + olas en facetas planas.
	vec3 gn = normalize(cross(dFdx(pm), dFdy(pm)));
	if (gn.y < 0.0) {
		gn = -gn;
	}
	vec3 nm = normalize(mix(normal_faceta(pm.xz - dir * avance * fase1 * adveccion_olas, TIME),
			normal_faceta(pm.xz - dir * avance * fase0 * adveccion_olas, TIME), peso0));     // las olas viajan con la corriente
	nm = normalize(nm + (gn - vec3(0.0, 1.0, 0.0)) * 2.0);
	// Ondas que reaccionan: su pendiente se suma a la normal.
	float cresta = 0.0;
	if (ondas_fuerza > 0.0) {
		vec2 uvo = (pm.xz - ondas_rect.xy) / ondas_rect.z;
		if (uvo.x > 0.0 && uvo.y > 0.0 && uvo.x < 1.0 && uvo.y < 1.0) {
			// La textura guarda solo la altura (R); la pendiente sale de las diferencias con los vecinos (texel = lado / tamaño).
			vec2 px = 1.0 / vec2(textureSize(ondas, 0));
			float h0 = texture(ondas, uvo).r;
			float dx = texture(ondas, uvo + vec2(px.x, 0.0)).r - texture(ondas, uvo - vec2(px.x, 0.0)).r;
			float dz = texture(ondas, uvo + vec2(0.0, px.y)).r - texture(ondas, uvo - vec2(0.0, px.y)).r;
			vec2 pend = vec2(dx, dz) / (2.0 * ondas_rect.z * px.x);
			nm = normalize(nm + vec3(-pend.x, 0.0, -pend.y) * ondas_fuerza * (1.0 - hielo));   // el hielo no se ondula
			cresta = clamp(abs(h0) * ondas_fuerza * 3.0 - 0.3, 0.0, 1.0) * (1.0 - hielo);
		}
	}

	// Color: somero -> hondo por la profundidad, en bandas.
	float hondo = smoothstep(prof_clara, prof_rio, v_prof);        // 13.9 (b): la opacidad
	float hondo_b = floor(smoothstep(prof_clara, prof_color, v_prof) * bandas + 0.5) / bandas;   // y el color, con su propia rampa
	vec3 ce = mix(color_somero_est, color_hondo_est, hondo_b);
	float lf = clamp(dot(nm, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
	ce *= 1.0 - contraste_faceta + contraste_faceta * 1.3 * smoothstep(0.7, 1.0, lf);

	// Franjas que corren con la corriente (flow map de dos fases desfasadas medio ciclo y mezcladas).
	vec2 uv = pm.xz / tam_franja;
	float efecto_flujo = smoothstep(0.04, 0.3, vel);
	float fr = franja(uv - dir * avance * fase0 / tam_franja, dir) * peso0
			+ franja(uv + 0.37 - dir * avance * fase1 / tam_franja, dir) * (1.0 - peso0);
	float franjas = smoothstep(0.62, 0.70, fr) * efecto_flujo;
	ce = mix(ce, color_espuma, franjas * 0.32);

	// LECHO (16/10, Pablo: «es translúcida y está bien, pero no hay sensación de profundidad»). No hay un fondo real bajo el agua (la
	// superficie es lo único que se dibuja), así que se finge: el punto del lecho que se ve a través de este píxel está desplazado
	// en la dirección contraria a la mirada tanto más cuanto más profundo es el agua (paralaje). Sobre ese punto se pinta un fondo oscuro
	// y la red de cáusticas (celdas de Voronoi); al mover la cámara el lecho se desliza respecto a la superficie y se lee como profundidad.
	// Pesa más donde el agua es somera/translúcida (ahí se ve el fondo) y casi nada donde ya es opaca; el hielo no lo lleva.
	if (lecho > 0.0 && hielo < 0.5) {
		vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec2 pl = pm.xz - vw.xz / max(vw.y, 0.35) * v_prof * prof_lecho;
		vec3 cl = celdas(pl / 0.9 + vec2(TIME * 0.03, -TIME * 0.02));
		float red = 1.0 - smoothstep(0.0, 0.16, cl.y);
		vec3 fondo = mix(color_lecho, color_causticas, red * 0.45);
		float prof_k = smoothstep(0.1, 0.7, v_prof);                 // sin profundidad no hay lecho que ver (la orilla)
		ce = mix(ce, fondo, lecho * prof_k * (0.45 - 0.25 * hondo));
	}

	// Espuma: manchas de dos ruidos que corren en sentidos opuestos, más abundantes donde la corriente es fuerte.
	vec2 pf0 = pm.xz - dir * avance * fase0 * adveccion_olas;      // la espuma también va con la corriente (dos fases)
	vec2 pf1 = pm.xz - dir * avance * fase1 * adveccion_olas;
	float s1 = mix(ruido(pf1 * 0.95 + TIME * vec2(0.09, 0.05)), ruido(pf0 * 0.95 + TIME * vec2(0.09, 0.05)), peso0);
	float s2 = mix(ruido(pf1 * 1.35 - TIME * vec2(0.06, 0.08) + 7.3), ruido(pf0 * 1.35 - TIME * vec2(0.06, 0.08) + 7.3), peso0);
	float suma = s1 + s2 - 1.0;
	float rompe = smoothstep(vel_espuma, vel_espuma + 0.9, vel);
	// 16/10 (Pablo): las manchas salían con picos y también en agua quieta. Ahora el borde es un smoothstep (blando, redondeado) y las manchas
	// solo existen donde el agua «lleva algo»: corriente (`rompe`) u ondas (`cresta`). Sin eso el agua queda limpia. Se quita el anillo fino de
	// antes (era un segundo escalón de 0,08 de ancho que dibujaba contornos duros).
	float umbral_m = espuma_manchas - rompe * 0.3;
	float manchas = smoothstep(umbral_m - 0.02, umbral_m + 0.10, suma) * clamp(rompe * 1.6 + cresta, 0.0, 1.0);
	manchas *= smoothstep(0.06, 0.2, v_prof);
	// Orilla: espuma nítida donde la profundidad (interpolada hasta el borde) es casi cero; se funde con el agua hacia dentro.
	// 13.9 (d): el ruido del borde lo arrastra la corriente (el mismo flow map), y por dentro de la orilla va el menisco: una franja ancha y tenue.
	float borde = ruido(pm.xz * 2.2 - dir * TIME * clamp(vel, 0.0, 2.0) * 0.5 + TIME * 0.2);
	// 20/10 (b): la franja de espuma respira con el vaivén (±30 % de su ancho a la amplitud por defecto); proporcional a `orilla_mov`.
	float trans = transicion_orilla * (1.0 + 0.3 * v_oleaje * clamp(orilla_mov / 0.02, 0.0, 2.0));
	float linea = 1.0 - smoothstep(0.0, trans, prof_e + (borde - 0.5) * 0.04);
	linea *= linea;
	float men = (1.0 - smoothstep(trans, trans * 3.5, prof_e)) * menisco * (0.55 + 0.45 * borde);
	float espuma = clamp(max(linea, max(manchas * 0.85, cresta * 0.8)), 0.0, 1.0);
	// CAÍDAS (15/10): donde la superficie se inclina de verdad es una cascada: vetas blancas que bajan por ella; en la BASE (el trocito que
	// tiene un vecino mucho más alto) niebla de espuma que se agita; en el LABIO (el que tiene uno mucho más bajo) un filo de agua rápida.
	float pend_s = 1.0 - clamp(gn.y, 0.0, 1.0);
	float caida = smoothstep(caida_pend_min, caida_pend_min + 0.3, pend_s) * caida_fuerza * (1.0 - hielo);
	vec2 dd = normalize(gn.xz + vec2(0.0001, 0.0));
	float veta = ruido(vec2(dot(pm.xz, vec2(-dd.y, dd.x)) * 4.0, pm.y * 1.4 + TIME * vel_caida));
	float cortina = smoothstep(0.50, 0.70, veta) * caida;
	float base_f = smoothstep(0.10, 0.50, v_caida.x) * caida_fuerza * (1.0 - hielo);
	float labio_f = smoothstep(0.10, 0.50, v_caida.y) * caida_fuerza * (1.0 - hielo);
	float niebla = base_f * (0.45 + 0.55 * ruido(pm.xz * 2.4 + vec2(0.0, -TIME * 1.1)));
	espuma = clamp(max(espuma, max(cortina * 0.85, max(niebla * 0.9, labio_f * 0.45))), 0.0, 1.0);
	ce = mix(ce, color_espuma, espuma);
	ce = mix(ce, color_espuma, men * 0.45);

	float alfa_agua = mix(alfa_clara, alfa_rio, sqrt(hondo)) + espuma + men * 0.25;   // raíz: una lámina de 0,3 u ya se lee como agua
	float rugosidad = 0.18;
	if (hielo > 0.0) {
		// Facetas: celdas grandes, cada una con su tono y su inclinación (se ve tallado, no liso).
		vec3 fa = celdas(pm.xz / tam_faceta_hielo);
		vec2 incl = vec2(hash(vec2(fa.z * 17.1, 3.3)), hash(vec2(fa.z * 9.7, 5.1))) - 0.5;
		vec3 ni = normalize(vec3(incl.x * 0.9, 1.0, incl.y * 0.9));
		ni = normalize(ni + (gn - vec3(0.0, 1.0, 0.0)) * 2.0);
		float li = clamp(dot(ni, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
		vec3 ci = mix(color_hielo_hondo, color_hielo_claro, 0.35 + 0.65 * fa.z);
		ci *= 0.70 + 0.26 * smoothstep(0.5, 1.0, li);
		// Grietas: las finas de siempre (otra malla de celdas, girada, y cortadas por ruido para que no sean una cuadrícula);
		// con el aviso se abren más, se juntan con las aristas de las facetas y todo el hielo se oscurece.
		float pulso = 0.85 + 0.15 * sin(TIME * 13.0);
		vec3 gr = celdas((GIRO_FACETA * pm.xz) / (tam_faceta_hielo * 0.62) + 3.1);
		float corta = smoothstep(0.30 - aviso * 0.25, 0.55 - aviso * 0.25, ruido(pm.xz * 1.4 + 9.0));
		float ancho = 0.035 + aviso * 0.07 * pulso;
		float grieta = (1.0 - smoothstep(ancho, ancho + 0.03, gr.y)) * corta;
		float arista = (1.0 - smoothstep(0.02, 0.05 + aviso * 0.05, fa.y)) * aviso * 0.8;
		ci = mix(ci, color_grieta * (1.0 - 0.2 * aviso), clamp(grieta * 0.75 + arista, 0.0, 1.0));
		ci *= 1.0 - 0.28 * aviso;
		ce = mix(ce, ci, hielo);
		nm = normalize(mix(nm, ni, hielo));
		alfa_agua = mix(alfa_agua, 1.0, hielo);
		rugosidad = mix(rugosidad, 0.12, hielo);
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 4.0);
	ce = mix(ce, vec3(0.88, 0.94, 1.0), fres * 0.25);
	float alfa_f = clamp(alfa_agua, 0.0, 1.0);
	v_spec = 1.0;
	if (refraccion > 0.5) {
		// REFRACCIÓN (agua EoW). Cuánto se deforma el fondo: la INCLINACIÓN de la superficie respecto a la plana (en el espacio de la cámara), por la profundidad (con tope),
		// y nada en la orilla (sin agua que doble) ni en el hielo (es sólido). El desplazamiento está en u de mundo y se pasa a pantalla con la proyección (ortogonal o no).
		float amp = min(max(v_prof, 0.0), refr_prof_tope) * smoothstep(0.0, refr_orilla, prof_e) * (1.0 - hielo);
		vec2 inc = (VIEW_MATRIX * vec4(nm, 0.0)).xy - (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xy;
		vec2 esc = vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]) * 0.5;
		if (PROJECTION_MATRIX[3][3] < 0.5) {
			esc /= max(-VERTEX.z, 0.1);                      // en perspectiva el tamaño en pantalla baja con la distancia
		}
		vec2 uv_r = SCREEN_UV + vec2(inc.x, -inc.y) * refr_fuerza * amp * esc;
		// Fantasmas: lo que hay en el punto desplazado solo se refracta si está DETRÁS del agua (más lejos que ella en la vista) y BAJO su lámina (Y de mundo menor). Si no
		// (un árbol, la chibi, el bloque de la orilla, que quedan por encima o delante) se usa el píxel de siempre. Todo con rampa suave, sin saltos.
		float borde_p = min(min(uv_r.x, 1.0 - uv_r.x), min(uv_r.y, 1.0 - uv_r.y));
		float d_esc = texture(prof_escena, clamp(uv_r, vec2(0.0), vec2(1.0))).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(uv_r * 2.0 - 1.0, d_esc, 1.0);
		vp.xyz /= vp.w;
		float detras = (-vp.z) - (-VERTEX.z);                 // > 0: lo del punto desplazado está más lejos que esta superficie de agua
		float bajo = pm.y - (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).y;     // > 0: y bajo la lámina
		float bueno = smoothstep(0.0, refr_margen, detras) * smoothstep(0.0, refr_margen, bajo) * smoothstep(0.0, refr_borde, borde_p);
		vec2 uv_f = mix(SCREEN_UV, uv_r, bueno);
		vec3 fondo_r = texture(pantalla, uv_f).rgb;
		ALBEDO = ce * brillo * alfa_f;
		EMISSION = fondo_r * (1.0 - alfa_f);
		ALPHA = 1.0;
		v_spec = alfa_f;
	} else {
		ALBEDO = ce * brillo;
		ALPHA = alfa_f;
	}
	ROUGHNESS = rugosidad;
	SPECULAR = 0.5 * v_spec;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 60.0) * 0.5 * LIGHT_COLOR * ATTENUATION * v_spec;
}
"""

## 13.9 (a): sombreado de las PAREDES laterales. COLOR.r = altura relativa en la cara (0 abajo, 1 arriba), COLOR.g = profundidad del trocito.
## Mismos colores y mismo criterio de profundidad que la superficie; más oscura hacia el fondo y con un filo claro arriba (el menisco).
const CODIGO_PARED: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 color_somero_est : source_color = vec3(0.44, 0.80, 0.91);
uniform vec3 color_hondo_est : source_color = vec3(0.20, 0.52, 0.80);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform float prof_clara = 0.1;
uniform float prof_rio = 1.4;
uniform float prof_color = 0.9;
uniform float alfa_clara = 0.2;
uniform float alfa_rio = 0.95;
uniform float bandas = 3.0;
uniform float menisco = 0.55;
uniform float brillo = 1.0;
uniform float contraste = 1.2;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);

varying float v_t;
varying float v_p;

void vertex() {
	v_t = COLOR.r;
	v_p = COLOR.g;
}

void fragment() {
	float hondo = smoothstep(prof_clara, prof_rio, v_p);
	float hondo_b = floor(smoothstep(prof_clara, prof_color, v_p) * bandas + 0.5) / bandas;
	vec3 ce = mix(color_somero_est, color_hondo_est, hondo_b) * (0.74 + 0.26 * v_t);
	float filo = smoothstep(0.78, 1.0, v_t);
	ce = mix(ce, color_espuma, filo * menisco);
	ALBEDO = ce * brillo;
	ALPHA = clamp(mix(alfa_clara, alfa_rio, sqrt(hondo)) * (0.6 + 0.4 * v_t) + filo * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.2;
	SPECULAR = 0.4;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
"""

## Si no se llama a `enlazar` a mano, se pregunta a este Callable cada fotograma hasta que devuelva la simulación (el Lanzador la
## crea al cargar el nivel, después de que existan los nodos).
var proveedor: Callable = Callable()
var sim: AguaSim3D = null
var _mat: ShaderMaterial = null
var _tex_a: ImageTexture = null
var _tex_b: ImageTexture = null
var _img_b: Image = null
var _desde: float = 0.0               ## segundos desde la última lectura
var _intervalo: float = 1.0 / 12.0
var _ms_lectura: float = 0.0          ## media de lo que cuesta leer la simulación (ms), para medirlo

# 13.9
## Dibuja las paredes laterales del agua (a). Con `false` solo hay superficie, como antes.
@export var paredes: bool = true
## Cada cuántas lecturas se rehacen las paredes (1 = todas; 2 = a la mitad de frecuencia: ~6 veces por segundo con 12 Hz).
@export var paredes_cada: int = 1
## (c) Si no se llama a `poner_topes`, se pregunta a este Callable al enlazar: devuelve {Vector2i casilla: Y máxima del agua}.
var proveedor_topes: Callable = Callable()
## 15/10 (DIARIO 95): {casilla (Vector2i): dirección (Vector2 unitario)} de la corriente PROPIA del río. La simulación casi no mueve el agua del
## río (el nivel está fijo), así que sin esto se lee como un lago quieto. `flujo_hacia_salidas` lo calcula desde el mapa. Vacío = sin corriente propia.
var proveedor_flujo: Callable = Callable()
## Una caída detectada en la simulación: `pos` = el trocito de la base (mundo) y `salto` = lo que sube el vecino más alto (u). La maqueta la
## conecta a las ondas (anillos que salen de donde cae el agua). Se emite hasta MAX_CAIDAS veces cada ~0,33 s.
signal caida_detectada(pos: Vector3, salto: float)
const SALTO_CAIDA: float = 0.2
## 20/10 (DIARIO 211) · CONSTANTE 1. Cuánto se baja la lámina de agua (u) respecto a la superficie de la simulación. Hasta ahora quedaba
## 0,04 u por debajo de la cara superior del bloque vecino (ALTO_AGUA = ALTO − 0,04): cualquier onda de más de 0,04 u la cortaba el bloque.
## Con 0,08 el margen total es de 0,12 u. Es solo dibujo: nado, física y simulación no cambian. Misma para pozo, canal y estanque.
const BAJADA_LAMINA: float = 0.08
## CONSTANTE 2. Amplitud (u) del vaivén vertical de la orilla (casillas de agua que tocan tierra). Dos senos de 3,7 s y 2,3 s, desfasados por
## posición. Tiene que quedar ≤ 0,02 u y ≤ BAJADA_LAMINA para que la cresta más alta siga por debajo del borde del bloque. 0 = orilla quieta.
const ORILLA_MOV: float = 0.02
## Valores en uso (empiezan en las constantes; el laboratorio los cambia en vivo). Las paredes los releen en la siguiente lectura (12 Hz).
var bajada_lamina: float = BAJADA_LAMINA:
	set(v):
		bajada_lamina = v
		if _mat != null:
			_mat.set_shader_parameter("bajada_lamina", v)
var orilla_mov: float = ORILLA_MOV:
	set(v):
		orilla_mov = v
		if _mat != null:
			_mat.set_shader_parameter("orilla_mov", v)
## Lo que se baja la lámina en una casilla de profundidad `p`: igual que en el shader (nunca más de la mitad de la profundidad).
func bajada_para(p: float) -> float:
	return minf(bajada_lamina, 0.5 * absf(p))
const MAX_CAIDAS: int = 6
var _topes_casillas: Dictionary = {}
var _topes_cpu := PackedFloat32Array()   ## por trocito, la Y máxima a la que se dibuja (0 = sin tope); la misma que lleva la textura `topes`
var _paredes: MeshInstance3D = null
var _mat_pared: ShaderMaterial = null
var _lecturas: int = 0
var _ms_paredes: float = 0.0
var _quads_paredes: int = 0

# Hielo (11.14)
const SEG_CRECE: float = 0.3          ## lo que tarda el hielo en cubrir la zona del impacto
const SEG_NUNCA: float = 1.0e8
var _reloj: float = 0.0
var _hielo_r_prev := PackedByteArray() ## el canal R (helado sí/no) de la lectura anterior: si no cambia, no hay nada que calcular
var _hielo_ceros := PackedByteArray()
var _hielo_g_tex: ImageTexture = null
var _hielo_est := PackedByteArray()   ## 1 = estaba helado en la lectura anterior
var _hielo_ini := PackedFloat32Array()
var _hielo_fin := PackedFloat32Array()
var _hielo_datos := PackedFloat32Array()   ## RG por trocito (inicio, fin), persistente: solo se tocan los que cambian
var _hielo_tex: ImageTexture = null
var _hielo_w: int = 0
var _hielo_h: int = 0
var _hielo_vivo_hasta: float = -1.0   ## mientras haya hielo o se esté deshaciendo, el sombreado lo dibuja
var _hielo_origen: Vector2 = Vector2.ZERO
var _hielo_origen_ok: bool = false
var _ms_hielo: float = 0.0


## Enlaza con la simulación y construye la malla (un vértice por centro de trocito). Se puede llamar otra vez al cambiar de nivel.
func enlazar(p_sim: AguaSim3D) -> void:
	sim = p_sim
	if sim == null or sim.w <= 0:
		mesh = null
		return
	_construir_malla()
	if _mat == null:
		var sh := Shader.new()
		sh.code = CODIGO
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	material_override = _mat
	_mat.set_shader_parameter("minima", profundidad_minima)
	_mat.set_shader_parameter("bajada_lamina", bajada_lamina)
	_mat.set_shader_parameter("orilla_mov", orilla_mov)
	_aplicar_eow()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if proveedor_topes.is_valid() and _topes_casillas.is_empty():
		var t: Variant = proveedor_topes.call()
		if t is Dictionary:
			_topes_casillas = t
	_aplicar_topes()
	_montar_paredes()
	_montar_flujo()
	_leer(true)


## Agua EoW: vuelca al sombreado los interruptores y las constantes de la refracción y de la tercera escala de olas (y la prioridad de dibujo). Se llama al enlazar y
## cada vez que cambia un interruptor; sin material todavía no hace nada.
func _aplicar_eow() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("refraccion", 1.0 if agua_refraccion else 0.0)
	_mat.set_shader_parameter("refr_fuerza", REFR_FUERZA)
	_mat.set_shader_parameter("refr_prof_tope", REFR_PROF_TOPE)
	_mat.set_shader_parameter("refr_orilla", REFR_ORILLA)
	_mat.set_shader_parameter("refr_margen", REFR_MARGEN)
	_mat.set_shader_parameter("refr_borde", REFR_BORDE)
	_mat.set_shader_parameter("ola3_altura", OLA3_ALTURA if olas_tercera_escala else 0.0)
	_mat.set_shader_parameter("ola3_k", TAU / OLA3_LONGITUD)
	_mat.set_shader_parameter("ola3_vel", OLA3_VEL)
	_mat.set_shader_parameter("ola3_dir", Vector2.from_angle(deg_to_rad(OLA3_RUMBO)))
	_mat.set_shader_parameter("ola3_dir2", Vector2.from_angle(deg_to_rad(OLA3_RUMBO + OLA3_CRUCE)))
	# Con refracción el agua tapa lo que se dibuje antes: va la primera de lo transparente. Sin ella, la prioridad de siempre (0).
	_mat.render_priority = AGUA_PRIORIDAD if agua_refraccion else 0
	if _mat_pared != null:
		_mat_pared.render_priority = PARED_PRIORIDAD if agua_refraccion else 0


## El material del agua (para las pruebas y los ajustes finos desde fuera).
func material_agua() -> ShaderMaterial:
	return _mat


## 13.9 (c): limita la Y a la que se DIBUJA el agua de cada casilla: `topes` = {Vector2i casilla: Y}. Se puede llamar antes o después de
## `enlazar`. Vacío lo quita. No cambia la simulación: solo lo que se ve (el canal de piedra no deja ver el agua por encima de su borde).
func poner_topes(topes: Dictionary) -> void:
	_topes_casillas = topes
	if sim != null:
		_aplicar_topes()


func _aplicar_topes() -> void:
	if _mat == null or sim == null or sim.w <= 0:
		return
	_topes_cpu = PackedFloat32Array()
	if _topes_casillas.is_empty():
		_mat.set_shader_parameter("topes_activos", 0.0)
		return
	var n: int = sim.w * sim.h
	_topes_cpu.resize(n)
	_topes_cpu.fill(0.0)
	for c in _topes_casillas.keys():
		var cc: Vector2i = c
		if cc.x < 0 or cc.y < 0 or cc.x >= sim.ancho or cc.y >= sim.alto:
			continue
		var y: float = float(_topes_casillas[c])
		for sy in range(sim.sub):
			for sx in range(sim.sub):
				_topes_cpu[(cc.y * sim.sub + sy) * sim.w + cc.x * sim.sub + sx] = y
	var im := Image.create_from_data(sim.w, sim.h, false, Image.FORMAT_RF, _topes_cpu.to_byte_array())
	_mat.set_shader_parameter("topes", ImageTexture.create_from_image(im))
	_mat.set_shader_parameter("topes_activos", 1.0)


## Enchufa las ondas de AguaOndas3D (11.8): `textura` R = altura (u); cubre el cuadrado de lado `lado` desde `origen_xz`.
func fuente_ondas(textura: Texture2D, origen_xz: Vector2, lado: float, fuerza: float = 1.0) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("ondas", textura)
	_mat.set_shader_parameter("ondas_rect", Vector3(origen_xz.x, origen_xz.y, lado))
	_mat.set_shader_parameter("ondas_fuerza", fuerza)


## Cambia un parámetro del sombreado (colores, bandas, espuma…).
func ajustar(nombre: String, valor: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(nombre, valor)
	if _mat_pared != null and nombre in ["color_somero_est", "color_hondo_est", "color_espuma", "prof_clara", "prof_rio", "prof_color", "alfa_clara", "alfa_rio", "bandas", "menisco", "brillo", "contraste", "sombra_tinte"]:
		_mat_pared.set_shader_parameter(nombre, valor)


## La última lectura de la simulación como textura (R altura, G profundidad, BA corriente): AguaOndas3D la usa de máscara de agua.
func textura_datos() -> Texture2D:
	return _tex_b


func milisegundos_lectura() -> float:
	return _ms_lectura


## Lo que cuesta rehacer las paredes (ms), aparte de la lectura del agua, y cuántas caras llevan ahora.
func milisegundos_paredes() -> float:
	return _ms_paredes


func caras_paredes() -> int:
	return _quads_paredes


## Lo que cuesta leer el hielo en cada lectura (ms), aparte de la lectura del agua.
func milisegundos_hielo() -> float:
	return _ms_hielo


## El Juego, si sabe dónde cayó el hechizo, lo dice justo antes de helar: el hielo crecerá desde ahí. Si no, crece desde el centro de lo helado.
func hielo_desde(pos: Vector3) -> void:
	_hielo_origen = Vector2(pos.x, pos.z)
	_hielo_origen_ok = true


func _process(delta: float) -> void:
	if sim == null and proveedor.is_valid():
		var s: Variant = proveedor.call()
		if s is AguaSim3D:
			enlazar(s)
	if sim == null or _mat == null:
		return
	_reloj += delta
	_mat.set_shader_parameter("reloj", _reloj)
	_mat.set_shader_parameter("hielo_activo", 1.0 if _reloj < _hielo_vivo_hasta else 0.0)
	_intervalo = 1.0 / maxf(hz_actualizacion, 1.0)
	_desde += delta
	if _desde >= _intervalo:
		_leer(false)
		_desde = 0.0
	_mat.set_shader_parameter("mezcla", clampf(_desde / _intervalo, 0.0, 1.0))


## Lee la simulación: la lectura anterior pasa a `datos_a` y la nueva a `datos_b`; el sombreado interpola entre las dos.
func _leer(primera: bool) -> void:
	var t0: int = Time.get_ticks_usec()
	var img: Image = sim.imagen()
	if _tex_b == null or primera or _tex_b.get_width() != img.get_width() or _tex_b.get_height() != img.get_height():
		_tex_a = ImageTexture.create_from_image(img)
		_tex_b = ImageTexture.create_from_image(img)
	else:
		_tex_a.update(_img_b)
		_tex_b.update(img)
	_img_b = img
	_mat.set_shader_parameter("datos_a", _tex_a)
	_mat.set_shader_parameter("datos_b", _tex_b)
	_mat.set_shader_parameter("mezcla", 1.0 if primera else 0.0)
	_mat.set_shader_parameter("lado_trocito", sim.l)
	var t1: int = Time.get_ticks_usec()
	_leer_hielo(primera)
	_ms_hielo = lerpf(_ms_hielo, float(Time.get_ticks_usec() - t1) / 1000.0, 0.2)
	_lecturas += 1
	if _lecturas % 4 == 0:
		_buscar_caidas()
	if paredes and (primera or _lecturas % maxi(paredes_cada, 1) == 0):
		var t2: int = Time.get_ticks_usec()
		_reconstruir_paredes()
		_ms_paredes = lerpf(_ms_paredes, float(Time.get_ticks_usec() - t2) / 1000.0, 0.2)
	_ms_lectura = lerpf(_ms_lectura, float(Time.get_ticks_usec() - t0) / 1000.0, 0.2)


## Dirección de la corriente propia del río por casilla, desde el mapa: cada casilla de agua (`es_agua(c) -> bool`) fluye hacia la salida más cercana, que es el
## casilla de agua que `es_salida(c) -> bool` marque (por defecto el agua del borde del mapa; un río tiene entrada y salida y solo la salida tira del agua). Se calcula la distancia a esas salidas (anchura) y la
## dirección es el descenso de esa distancia; en la salida misma, hacia fuera del mapa. Un lago sin salida (sin agua en el borde) no fluye.
static func flujo_hacia_salidas(lado: int, es_agua: Callable, es_salida: Callable = Callable()) -> Dictionary:
	var dist: Dictionary = {}
	var cola: Array[Vector2i] = []
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if not bool(es_agua.call(c)):
				continue
			var vale: bool = bool(es_salida.call(c)) if es_salida.is_valid() else (x == 0 or y == 0 or x == lado - 1 or y == lado - 1)
			if vale:
				dist[c] = 0
				cola.append(c)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for d in dirs:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= lado or n.y >= lado or dist.has(n) or not bool(es_agua.call(n)):
				continue
			dist[n] = int(dist[c]) + 1
			cola.append(n)
	var res: Dictionary = {}
	for c in dist.keys():
		var v := Vector2.ZERO
		for d in dirs:
			var n: Vector2i = (c as Vector2i) + d
			if n.x < 0 or n.y < 0 or n.x >= lado or n.y >= lado:
				if int(dist[c]) == 0:
					v += Vector2(d)                       # salida en el borde: hacia fuera del mapa (en una salida interior, el término de abajo apunta de la casilla que llega hacia ella)
			elif dist.has(n):
				v += Vector2(d) * float(int(dist[c]) - int(dist[n]))
		if v.length() > 0.01:
			res[c] = v.normalized()
	return res


## Textura de la corriente propia por TROCITO (RGF; el mismo tamaño que la de la simulación). Se interpola entre los centros de casilla con 0 donde no
## hay río: la corriente se apaga sola hacia las orillas (el centro corre más que la orilla) y los giros del cauce son curvas, no esquinas.
func _montar_flujo() -> void:
	if not proveedor_flujo.is_valid() or _mat == null:
		return
	var d: Variant = proveedor_flujo.call()
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return
	var flu: Dictionary = d
	var img := Image.create(sim.w, sim.h, false, Image.FORMAT_RGF)
	for y in range(sim.h):
		for x in range(sim.w):
			var pos := Vector2((float(x) + 0.5) * sim.l, (float(y) + 0.5) * sim.l) / sim.lado_casilla - Vector2(0.5, 0.5)
			var cx: int = floori(pos.x)
			var cy: int = floori(pos.y)
			var fx: float = pos.x - float(cx)
			var fy: float = pos.y - float(cy)
			var v := Vector2.ZERO
			for oy in range(2):
				for ox in range(2):
					var peso: float = (fx if ox == 1 else 1.0 - fx) * (fy if oy == 1 else 1.0 - fy)
					v += (flu.get(Vector2i(cx + ox, cy + oy), Vector2.ZERO) as Vector2) * peso
			img.set_pixel(x, y, Color(v.x, v.y, 0.0))
	_mat.set_shader_parameter("flujo", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("flujo_activo", 1.0)


## Busca en la simulación los trocitos de BASE de una caída (agua con un vecino de agua bastante más alto) y avisa de los mayores (`caida_detectada`).
func _buscar_caidas() -> void:
	if sim == null or not caida_detectada.has_connections():
		return
	var w: int = sim.w
	var h: int = sim.h
	var caja: Rect2i = sim.caja_trabajo() if sim.has_method("caja_trabajo") else Rect2i(0, 0, w, h)
	if caja.size.x <= 0 or caja.size.y <= 0:
		return
	var prof: PackedFloat32Array = sim.prof
	var suelo: PackedFloat32Array = sim.suelo
	var cerrado: PackedByteArray = sim.cerrado
	var helado: PackedByteArray = sim.helado
	var vec: PackedInt32Array = sim.vecinos
	var minima: float = profundidad_minima
	var cand: Array = []
	for y in range(maxi(0, caja.position.y - 1), mini(h, caja.position.y + caja.size.y + 1)):
		for x in range(maxi(0, caja.position.x - 1), mini(w, caja.position.x + caja.size.x + 1)):
			var i: int = y * w + x
			if prof[i] < minima or cerrado[i] == 1 or helado[i] == 1:
				continue
			var sup: float = suelo[i] + prof[i]
			var mejor: float = 0.0
			for k in range(4):
				var j: int = vec[i * 4 + k]
				if j < 0 or cerrado[j] == 1 or prof[j] < minima:
					continue
				mejor = maxf(mejor, suelo[j] + prof[j] - sup)
			if mejor >= SALTO_CAIDA:
				cand.append([mejor, Vector3((float(x) + 0.5) * sim.l, sup, (float(y) + 0.5) * sim.l)])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for k in range(mini(cand.size(), MAX_CAIDAS)):
		caida_detectada.emit(global_transform * (cand[k][1] as Vector3) if is_inside_tree() else (cand[k][1] as Vector3), float(cand[k][0]))


## Hielo (11.14): lee `imagen_hielo()` y guarda por trocito CUÁNDO empezó a helarse y CUÁNDO a soltarse (en el reloj propio), para que el
## sombreado pueda hacer crecer el hielo desde el impacto y deshacerlo en ~0,3 s. Si la simulación no tiene hielo, no hace nada.
## Coste: por lectura solo se copia el canal R y se compara con el anterior (nativo, sin bucle); el bucle por trocitos solo corre cuando
## algo se hiela o se suelta. El G («lo que le queda») va a la tarjeta tal cual, sin procesar.
func _leer_hielo(primera: bool) -> void:
	if sim == null or not (sim.has_method("imagen_hielo") or sim.has_method("textura_hielo")):
		return
	var fuente: Variant = sim.call("imagen_hielo") if sim.has_method("imagen_hielo") else sim.call("textura_hielo")
	var img: Image = null
	if fuente is Image:
		img = fuente
	elif fuente is Texture2D:
		img = (fuente as Texture2D).get_image()
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RG8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RG8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = w * h
	var reinicio: bool = primera or w != _hielo_w or h != _hielo_h or _hielo_ini.size() != n
	if reinicio:
		_hielo_w = w
		_hielo_h = h
		_hielo_r_prev.resize(n)
		_hielo_r_prev.fill(0)
		_hielo_ceros.resize(n)
		_hielo_ceros.fill(0)
		_hielo_ini.resize(n)
		_hielo_ini.fill(SEG_NUNCA)
		_hielo_fin.resize(n)
		_hielo_fin.fill(SEG_NUNCA)
		_hielo_datos.resize(n * 2)
		for i in range(n):
			_hielo_datos[i * 2] = SEG_NUNCA
			_hielo_datos[i * 2 + 1] = SEG_NUNCA
		_hielo_tex = null
		_hielo_g_tex = null
	# El canal R solo (conversión nativa): ¿helado o no?
	var solo_r: Image = img.duplicate()
	solo_r.convert(Image.FORMAT_R8)
	var r: PackedByteArray = solo_r.get_data()
	var hay: bool = r != _hielo_ceros
	var cambio: bool = r != _hielo_r_prev
	if not hay and not cambio and not reinicio and _reloj >= _hielo_vivo_hasta:
		return                                   # sin hielo y sin cambios: nada que leer ni subir
	if hay:
		_hielo_vivo_hasta = _reloj + 1.0         # tras soltarse el último, sigue dibujándose 1 s: lo que tarda en deshacerse
	# G (lo que le queda) a la tarjeta, tal cual.
	if _hielo_g_tex == null:
		_hielo_g_tex = ImageTexture.create_from_image(img)
	else:
		_hielo_g_tex.update(img)
	_mat.set_shader_parameter("hielo_g", _hielo_g_tex)
	if not cambio and not reinicio:
		return
	# Algo se heló o se soltó: el bucle por trocitos (solo ahora).
	var nuevos := PackedInt32Array()
	for i in range(n):
		var ahora: int = r[i]
		if ahora == _hielo_r_prev[i]:
			continue
		if ahora >= 128:
			if reinicio:
				_hielo_ini[i] = -SEG_NUNCA          # ya estaba helado al cargar: sin animación
				_hielo_datos[i * 2] = -SEG_NUNCA
			else:
				nuevos.append(i)
			_hielo_fin[i] = SEG_NUNCA
			_hielo_datos[i * 2 + 1] = SEG_NUNCA
		else:
			_hielo_fin[i] = _reloj
			_hielo_datos[i * 2 + 1] = _reloj
	_hielo_r_prev = r
	# Los recién helados crecen desde el impacto: cada uno empieza en proporción a su distancia, para cubrirlo todo en SEG_CRECE.
	if nuevos.size() > 0:
		var c := Vector2.ZERO
		if _hielo_origen_ok:
			c = _hielo_origen / sim.l - Vector2(0.5, 0.5)
		else:
			for i in nuevos:
				c += Vector2(float(i % w), float(i / w))
			c /= float(nuevos.size())
		var dmax: float = 1.0
		for i in nuevos:
			dmax = maxf(dmax, c.distance_to(Vector2(float(i % w), float(i / w))))
		for i in nuevos:
			var dist: float = c.distance_to(Vector2(float(i % w), float(i / w)))
			_hielo_ini[i] = _reloj + SEG_CRECE * dist / dmax
			_hielo_datos[i * 2] = _hielo_ini[i]
		_hielo_origen_ok = false
	var im := Image.create_from_data(w, h, false, Image.FORMAT_RGF, _hielo_datos.to_byte_array())
	if _hielo_tex == null:
		_hielo_tex = ImageTexture.create_from_image(im)
	else:
		_hielo_tex.update(im)
	_mat.set_shader_parameter("hielo_t", _hielo_tex)


## 13.9 (a): el material y el nodo de las paredes (se crean una vez).
func _montar_paredes() -> void:
	if _paredes == null:
		_paredes = MeshInstance3D.new()
		_paredes.name = "ParedesAgua"
		_paredes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_paredes.extra_cull_margin = 4096.0           # la malla se rehace y sus cajas no se miden: que nunca se recorte
		add_child(_paredes)
	if _mat_pared == null:
		var sh := Shader.new()
		sh.code = CODIGO_PARED
		_mat_pared = ShaderMaterial.new()
		_mat_pared.shader = sh
	_paredes.material_override = _mat_pared
	_paredes.mesh = null
	_aplicar_eow()                  # agua EoW: la prioridad de dibujo de las paredes


## 13.9 (a): rehace las caras verticales del agua. Por cada trocito CON agua y cada uno de sus 4 lados que da a un trocito seco, cerrado
## (tierra, pared, borde del mapa), una cara en la arista compartida, desde la superficie hasta el suelo del lado más alto de los dos
## (lo que queda por debajo del suelo de al lado lo tapa la tierra). Solo recorre la caja de trabajo de la simulación. Las casillas con tope (canal) no llevan paredes: las pone la piedra.
func _reconstruir_paredes() -> void:
	if sim == null or _paredes == null:
		return
	var w: int = sim.w
	var h: int = sim.h
	var l: float = sim.l
	var caja: Rect2i = sim.caja_trabajo() if sim.has_method("caja_trabajo") else Rect2i(0, 0, w, h)
	if caja.size.x <= 0 or caja.size.y <= 0:
		_paredes.mesh = null
		_quads_paredes = 0
		return
	var x0: int = maxi(0, caja.position.x - 1)
	var y0: int = maxi(0, caja.position.y - 1)
	var x1: int = mini(w - 1, caja.position.x + caja.size.x)
	var y1: int = mini(h - 1, caja.position.y + caja.size.y)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var prof: PackedFloat32Array = sim.prof
	var suelo: PackedFloat32Array = sim.suelo
	var cerrado: PackedByteArray = sim.cerrado
	var helado: PackedByteArray = sim.helado
	var vec: PackedInt32Array = sim.vecinos
	var hay_topes: bool = _topes_cpu.size() == w * h
	var mitad: float = l * 0.5
	var minima: float = profundidad_minima
	var q: int = 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			var p: float = prof[i]
			if p < minima or cerrado[i] == 1 or helado[i] == 1:
				continue
			var sup: float = suelo[i] + p - bajada_para(p)             # 20/10: la cima de la pared baja igual que la lámina (si no, asomaría sobre ella)
			if hay_topes and _topes_cpu[i] > 0.0:
				continue                                          # casilla con tope = canal de piedra: la piedra ya es su pared (y el agua no sobresale)
			for k in range(4):
				var j: int = vec[i * 4 + k]
				var suelo_j: float = suelo[i]
				if j >= 0:
					if cerrado[j] == 0 and prof[j] >= minima:
						continue                                  # agua con agua: no hay pared
					suelo_j = suelo[j]
				var base: float = maxf(suelo[i], suelo_j)
				if sup - base < 0.012:
					continue
				var cx: float = (float(x) + 0.5) * l
				var cz: float = (float(y) + 0.5) * l
				var a: Vector3
				var b: Vector3
				var n: Vector3
				match k:
					0:
						a = Vector3(cx - mitad, 0.0, cz + mitad); b = Vector3(cx - mitad, 0.0, cz - mitad); n = Vector3(-1.0, 0.0, 0.0)
					1:
						a = Vector3(cx + mitad, 0.0, cz - mitad); b = Vector3(cx + mitad, 0.0, cz + mitad); n = Vector3(1.0, 0.0, 0.0)
					2:
						a = Vector3(cx - mitad, 0.0, cz - mitad); b = Vector3(cx + mitad, 0.0, cz - mitad); n = Vector3(0.0, 0.0, -1.0)
					_:
						a = Vector3(cx + mitad, 0.0, cz + mitad); b = Vector3(cx - mitad, 0.0, cz + mitad); n = Vector3(0.0, 0.0, 1.0)
				var v0: int = verts.size()
				verts.append(Vector3(a.x, base, a.z))
				verts.append(Vector3(b.x, base, b.z))
				verts.append(Vector3(b.x, sup, b.z))
				verts.append(Vector3(a.x, sup, a.z))
				for m in range(4):
					norms.append(n)
				cols.append(Color(0.0, p, 0.0))
				cols.append(Color(0.0, p, 0.0))
				cols.append(Color(1.0, p, 0.0))
				cols.append(Color(1.0, p, 0.0))
				idx.append(v0); idx.append(v0 + 1); idx.append(v0 + 2)
				idx.append(v0); idx.append(v0 + 2); idx.append(v0 + 3)
				q += 1
	_quads_paredes = q
	if q == 0:
		_paredes.mesh = null
		return
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_paredes.mesh = m


func _construir_malla() -> void:
	var w: int = sim.w
	var h: int = sim.h
	var l: float = sim.l
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(w * h)
	uvs.resize(w * h)
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			verts[i] = Vector3((x + 0.5) * l, 0.0, (y + 0.5) * l)
			uvs[i] = Vector2((x + 0.5) / float(w), (y + 0.5) / float(h))
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (h - 1) * 6)
	var k: int = 0
	for y in range(h - 1):
		for x in range(w - 1):
			var a: int = y * w + x
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			# Diagonal que alterna (como un tablero) para que las facetas del borde no se alineen siempre igual.
			if (x + y) % 2 == 0:
				idx[k] = a; idx[k + 1] = c; idx[k + 2] = b
				idx[k + 3] = b; idx[k + 4] = c; idx[k + 5] = d
			else:
				idx[k] = a; idx[k + 1] = c; idx[k + 2] = d
				idx[k + 3] = a; idx[k + 4] = d; idx[k + 5] = b
			k += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Los vértices suben y bajan en el sombreado: la caja de recorte debe cubrir cualquier altura del nivel.
	m.custom_aabb = AABB(Vector3(0.0, -20.0, 0.0), Vector3(w * l, 60.0, h * l))
	mesh = m
