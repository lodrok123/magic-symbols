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

# --- 22/10 (agua filtro; referencia: un río de Echoes of Wisdom). El agua deja de ser una lámina azul con alfa y pasa a ser un FILTRO turquesa casi transparente sobre un fondo REAL
# (el lecho de cantos, las rocas, las algas): color final = fondo refractado × transmitancia de Beer por profundidad, con un poco de `FILTRO_COLOR_HONDO` solo en lo hondo.
# Superficie casi limpia (sin bandas de dos tonos, sin red de cáusticas, sin franjas), espuma solo en la orilla y donde la corriente rompe fuerte. El hielo no cambia.
# Con `agua_filtro = false` el sombreado hace exactamente lo de antes. El filtro necesita leer la pantalla, así que usa el camino de la refracción aunque `agua_refraccion` esté apagado.
const FILTRO: bool = true
## Absorción por canal (R, G, B) por u de profundidad: el rojo se come enseguida y el azul casi nada, de ahí el turquesa. Con 0,9 u de agua pasa (0,18 · 0,67 · 0,76).
const FILTRO_ABSORCION: Vector3 = Vector3(1.9, 0.45, 0.30)
## Multiplica la absorción (más alto = el agua se oscurece y se tiñe antes).
const FILTRO_DENSIDAD: float = 1.0
## Color al que tiende el agua en lo muy hondo (la luz dispersada). Es un turquesa oscuro: el «albedo propio» del agua es solo este color por `FILTRO_OPACIDAD_HONDO`; nunca blanco lechoso.
const FILTRO_COLOR_HONDO: Color = Color(0.06, 0.33, 0.38)
## Profundidad (u) a la que lo hondo ya se ve casi del todo `FILTRO_COLOR_HONDO` (prof_max_visible): la dispersión crece como 1 − exp(−prof / esto).
const FILTRO_PROF_MAX: float = 1.8
## Cuánto cuenta la dispersión como máximo (0-1): lo justo para que lo muy hondo no se vea vacío; el resto es fondo real.
const FILTRO_OPACIDAD_HONDO: float = 0.45
## Contraste de las facetas con el filtro (era 0,2): casi nada, la superficie queda limpia.
const FILTRO_CONTRASTE_FACETA: float = 0.0
## Altura de la tercera escala de olas con el filtro (era OLA3_ALTURA): más suave.
const FILTRO_OLA3_ALTURA: float = 0.35
## Cuánto de la normal es la SUAVE (gradiente de las olas) en vez de las facetas planas: con facetas, el fondo refractado tendría saltos en cada arista.
const FILTRO_SUAVIDAD: float = 0.9
## Escala de las manchas de espuma del centro (1 = como antes) y de la espuma de crestas/impactos (la salpicadura de un golpe se sigue viendo).
const FILTRO_MANCHAS: float = 0.3
const FILTRO_CRESTAS: float = 0.6
## Fuerza del brillo especular (el de antes era 1) y del reflejo de cielo en los rasantes.
const FILTRO_ESPECULAR: float = 0.55
const FILTRO_FRESNEL: float = 0.10
## Opacidad máxima de las paredes laterales con el filtro (en el borde del agua).
const FILTRO_ALFA_PARED: float = 0.35
## 22/10 (banda oscura del borde): con el filtro el agua se teñia con la profundidad VERTICAL de su casilla (~0,9 u) aunque lo que se ve junto a la orilla sea la pared del bloque a pocos cm bajo la lamina,
## y salia una franja turquesa oscura (la pared de la orilla vista a traves del agua, teñida como si fuera el lecho). Ahora la columna que cuenta es la profundidad REAL de lo que se ve (Y de la lamina
## menos Y del punto visto), con tope en la de la casilla: el lecho no cambia, la pared va de clara (arriba) a teñida (abajo). 1 = asi; 0 = como antes. Las paredes del agua igual (alfa por la altura bajo la lamina).
const FILTRO_TINTE_VISTO: float = 1.0
## Fuerza del «lecho falso» (la red de Voronoi pintada en la superficie, 16/10): la de siempre, y 0 con el filtro (el lecho de verdad está debajo, ver LechoRio3D).
const LECHO_FALSO: float = 0.5
const LECHO_FALSO_FILTRO: float = 0.0

## 22/10 (agua blanca al llenarse) · La espuma de orilla, el menisco y el ruido del borde van pegados al CONTORNO real del agua, no a «poca profundidad»: valen entero a menos
## de ORILLA_DIST_0 (u) de él y nada a más de ORILLA_DIST_1 (el menisco, 1,5 veces). ORILLA_GRAD_MIN = gradiente mínimo de la profundidad (u/u) al estimar esa distancia.
const ORILLA_DIST_0: float = 0.30
const ORILLA_DIST_1: float = 0.70
const ORILLA_GRAD_MIN: float = 0.05
## Pendiente mínima del LECHO entre trocitos (u/u) para que una inclinación de la superficie cuente como caída (cortina, niebla de base, labio).
const CAIDA_LECHO_MIN: float = 0.08

## 22/10 (más movimiento, estilo Zelda Echoes of Wisdom: suave, no ruidoso) · Cuánto avanzan franjas, olas y espuma por ciclo del flow map y por u/s de corriente (a 1/VEL_FRANJA
## ciclos por segundo, 0,55: con 1,8 viajan justo a la velocidad de la corriente; 2,0 un poco por encima, que es lo que se lee como «corre»).
const AVANCE_FLUJO: float = 2.0
## Velocidad (u/s) de las vetas de la cortina de una caída, y fuerza y velocidad relativa de su segunda capa de vetas.
const VEL_CAIDA: float = 2.4
const CAIDA_VETA2: float = 0.7
const CAIDA_VETA2_VEL: float = 1.5
## 24/10 (CASCADA estilo Zelda: Echoes of Wisdom; referencias de Pablo) · Con el agua filtro la cortina de una caída es una cortina azul TRANSLÚCIDA con vetas verticales brillantes en tres capas
## (fuerza y velocidad relativa a VEL_CAIDA de la tercera, ancha y lenta). Las vetas suman luz (CORTINA_LUZ); solo una parte es espuma opaca (CORTINA_OPACIDAD), así se ve lo de detrás.
## CORTINA_VELO = velo azul de la cortina; CORTINA_LABIO = luz del labio superior (el borde de arriba, más claro).
const CAIDA_VETA3: float = 0.55
const CAIDA_VETA3_VEL: float = 0.8
const CORTINA_OPACIDAD: float = 0.38
const CORTINA_LUZ: float = 0.60
const CORTINA_VELO: float = 0.30
const CORTINA_LABIO: float = 0.55
## PIE de la caída: un «pie» es el trocito de la charca que tiene un vecino de agua al menos PIE_SALTO_MIN u más alto (de ahí cae). Se guardan los PIES_MAX de mayor salto (el sombreado declara
## `pies[16]`: si cambia esta constante, cambia allí) a PIE_DESPLAZA lados de trocito del centro hacia fuera de la caída; PIE_SALTO_REF = salto (u) que da fuerza 1; PIE_FASE_MAX = desfase
## máximo (0-1 de ciclo) entre pies para que no pulsen todos a la vez.
const PIES_MAX: int = 16
const PIE_SALTO_MIN: float = 0.35
const PIE_SALTO_REF: float = 1.0
const PIE_DESPLAZA: float = 0.45
const PIE_FASE_MAX: float = 0.18
## Desnivel mínimo del LECHO (u) entre la base y el trocito alto para que haya pie y lámina de cortina (el frente de una lámina que se llena no cuenta).
const PIE_DESNIVEL_MIN: float = 0.30
## Lámina de cortina: cuánto se adelanta (u) hacia la charca desde el plano entre trocitos (para no pelear con la cara de la piedra), prioridad de dibujo (detrás del agua = después de ella,
## AGUA_PRIORIDAD) y opacidades (base, vetas, labio) de la lámina; el resto lo dicen CAIDA_VETA*/VEL_CAIDA.
const CORTINA_SEPARA: float = 0.03
const CORTINA_PRIORIDAD: int = 0
## Lo que se hunde (u) la lámina bajo la superficie de la charca, para que no quede un hueco de piedra entre su pie y la espuma.
const CORTINA_HUNDE: float = 0.25
const CORTINA_ALFA_BASE: float = 0.34
const CORTINA_ALFA_VETA: float = 0.50
const CORTINA_ALFA_LABIO: float = 0.35
## Espuma por celdas del pie (radio y tamaño de celda en u, respiración en rad/s, opacidad máxima) y ondas concéntricas (ciclos/s, radio máximo en u, ancho de cresta en u, luz).
## ONDAS_PIE_N = crestas simultáneas por pie (el sombreado lo repite en su `ONDAS_PIE_N`).
const PIE_ESPUMA_RADIO: float = 0.65
const PIE_ESPUMA_CELDA: float = 0.40
const PIE_ESPUMA_RESP: float = 1.6
const PIE_ESPUMA_FUERZA: float = 0.85
const ONDA_PIE_VEL: float = 0.45
const ONDA_PIE_RMAX: float = 1.8
const ONDA_PIE_ANCHO: float = 0.10
const ONDA_PIE_LUZ: float = 0.9
const ONDAS_PIE_N: int = 3
## GOTAS que saltan en el pie (un único GPUParticles3D con emisión por puntos, los pies): tope de partículas, vida (s), velocidad inicial (u/s) mínima y máxima, apertura (grados) y tamaño (u).
const GOTAS_MAX: int = 40
const GOTAS_VIDA: float = 0.85
const GOTAS_VEL_MIN: float = 1.3
const GOTAS_VEL_MAX: float = 2.7
const GOTAS_ABANICO: float = 38.0
const GOTAS_TAM_MIN: float = 0.09
const GOTAS_TAM_MAX: float = 0.16
const GOTAS_GRAVEDAD: float = 9.0
## BORDES (24/10): la línea clara de la orilla ondula (ORILLA_LINEA_RUIDO en profundidad u, ORILLA_LINEA_ESCALA ciclos/u) y el fondo que se ve lleva manchas oscuras orgánicas y lentas
## (SOMBRA_ORG_FUERZA 0-1 de oscurecimiento, SOMBRA_ORG_ESCALA ciclos/u, SOMBRA_ORG_VEL ciclos/s).
const ORILLA_LINEA_RUIDO: float = 0.06
const ORILLA_LINEA_ESCALA: float = 1.7
const SOMBRA_ORG_FUERZA: float = 0.85
const SOMBRA_ORG_ESCALA: float = 0.75
const SOMBRA_ORG_VEL: float = 0.05
## Opacidad máxima (0-1) de las franjas claras de la corriente con el agua filtro (el río se ve correr). 0 = como antes (sin franjas).
const FILTRO_FRANJAS: float = 0.20
const FILTRO_FRANJAS_UMBRAL: float = 0.62
## 24/10 (agua del río, Pablo: «manchas blancas verticales opacas»): vetas finas y translúcidas, no manchas. El tope baja de 0,40 a 0,20 (luz sumada), el umbral sube de 0,54 a 0,62 (solo las crestas
## del ruido, ~un tercio de la superficie de antes) y la banda de borde (FILTRO_FRANJAS_BANDA, en valor de ruido) pasa de 0,08 a 0,20: el borde de la veta se funde con el agua en vez de cortar seco.
const FILTRO_FRANJAS_BANDA: float = 0.20
## 23/10 (agua del cauce hondo lleno): las vetas son luz que se SUMA a lo que se ve (ya no una mezcla hacia el blanco, que saturaba), y `FILTRO_FRANJAS` es lo más que suman. Solo salen con una
## corriente de verdad: nada por debajo de FILTRO_FLUJO_0 (u/s; lo que deja una lámina que se llena o se agita, 0,1-0,5) y enteras a partir de FILTRO_FLUJO_1 (el río lleva 0,9 propios).
## Fuera del río (el cauce hondo lleno, el estanque, el lab, la Cueva) se aclara el fondo que se ve (× FILTRO_REALCE; 1 = nada) y se le suma un velo turquesa de `filtro_hondo` × FILTRO_VELO que crece con la profundidad.
const FILTRO_REALCE: float = 1.7
const FILTRO_VELO: float = 0.5
const FILTRO_FLUJO_0: float = 0.12
const FILTRO_FLUJO_1: float = 0.70

@export var agua_refraccion: bool = REFRACCION:
	set(v):
		agua_refraccion = v
		_aplicar_eow()
@export var agua_filtro: bool = FILTRO:
	set(v):
		agua_filtro = v
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
uniform float avance_flujo = 2.0;             // cuánto avanzan franjas, olas y espuma por ciclo y por u/s de corriente (0,9 → 1,5 → 2,0 el 22/10: con 1,5 iban al 82 % de la corriente; ver AVANCE_FLUJO)
uniform float adveccion_olas = 1.0;           // 0 = las facetas y la espuma no viajan con la corriente
uniform float caida_fuerza = 1.0;             // 0 = sin efecto de cascada
uniform float caida_pend_min = 0.12;          // inclinación (1 − normal.y) a partir de la cual la superficie es una caída
uniform float caida_veta2 = 0.7;              // 22/10: fuerza (0-1) de la segunda capa de vetas de la cortina (CAIDA_VETA2)
uniform float caida_veta2_vel = 1.5;          // y su velocidad respecto a la primera (CAIDA_VETA2_VEL)
uniform float caida_lecho_min = 0.08;        // 22/10: y pendiente del LECHO (u/u entre trocitos) a partir de la cual hay caída de verdad (si no, es el frente de una lámina que se llena)
uniform float vel_caida = 2.4;                // velocidad (u/s) de las vetas de la cortina (1,6 → 2,4 el 22/10; ver VEL_CAIDA)
// 24/10 (cascada y bordes estilo Echoes of Wisdom). Constantes con su explicación en GDScript (CAIDA_VETA3…, CORTINA_*, PIE_*, ONDA_PIE_*, ORILLA_LINEA_*, SOMBRA_ORG_*).
uniform float caida_veta3 = 0.55;             // fuerza de la tercera capa de vetas (ancha y lenta) de la cortina
uniform float caida_veta3_vel = 0.8;          // y su velocidad respecto a vel_caida
uniform float cortina_opacidad = 0.38;        // espuma blanca OPACA máxima de las vetas de la cortina con el agua filtro (el resto es luz que deja ver lo de detrás)
uniform float cortina_luz = 0.60;             // luz que SUMAN las vetas de la cortina
uniform float cortina_velo = 0.30;            // velo azul translúcido de la cortina
uniform float cortina_labio = 0.55;           // luz del labio superior de la caída
uniform float cortina_geom = 0.0;             // 1 = hay láminas verticales de cortina (CODIGO_CORTINA): la superficie inclinada no dibuja las suyas
uniform int pies_n = 0;                       // pies de caída detectados (ver `_buscar_caidas`)
uniform vec4 pies[16];                        // por pie: x, z (mundo), y de la charca, salto (u)
uniform vec4 pies_dir[16];                    // por pie: dirección (xz) hacia el agua de la charca (alejándose de la caída), fuerza 0-1, fase 0-1
uniform float pie_espuma_radio = 0.65;        // radio (u) del anillo de espuma alrededor de un pie
uniform float pie_espuma_celda = 0.40;        // tamaño (u) de las celdas de esa espuma
uniform float pie_espuma_resp = 1.6;          // rad/s a los que respira la espuma
uniform float pie_espuma_fuerza = 0.85;       // opacidad máxima de la espuma del pie
uniform float onda_pie_vel = 0.45;            // ciclos por segundo de las ondas concéntricas
uniform float onda_pie_rmax = 1.8;            // radio (u) al que se desvanecen
uniform float onda_pie_ancho = 0.10;          // ancho (u) de una cresta al nacer (crece con el radio)
uniform float onda_pie_luz = 0.9;            // luz que suma una cresta
uniform float orilla_linea_ruido = 0.06;      // irregularidad (profundidad, u) de la línea clara de la orilla; 0 = recta
uniform float orilla_linea_escala = 1.7;      // y su escala (ciclos por u)
uniform float sombra_org_fuerza = 0.85;       // cuánto oscurecen las manchas orgánicas el fondo que se ve a través del agua (0 = nada)
uniform float sombra_org_escala = 0.75;       // su escala (ciclos por u)
uniform float sombra_org_vel = 0.05;          // y lo despacio que se mueven (ciclos por segundo)
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
uniform float orilla_dist_0 = 0.30;           // 22/10: a menos de esta distancia (u) del contorno del agua la espuma y el ruido de borde valen entero…
uniform float orilla_dist_1 = 0.70;           // …y a más de esta, nada (ver ORILLA_DIST_* en GDScript); el menisco usa 1,5 veces estas distancias
uniform float orilla_grad_min = 0.05;         // gradiente mínimo de la profundidad (u/u) al calcular esa distancia: tope de la distancia en agua llana
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
// 22/10 (agua filtro) · ver FILTRO_* en GDScript. filtro = 0: nada de esto se usa.
uniform float filtro = 0.0;
uniform vec3 filtro_k = vec3(1.9, 0.45, 0.30);
uniform float filtro_dens = 1.0;
uniform vec3 filtro_hondo : source_color = vec3(0.06, 0.33, 0.38);
uniform float filtro_prof_max = 1.8;
uniform float filtro_opacidad = 0.45;
uniform float filtro_contraste_faceta = 0.0;
uniform float filtro_suavidad = 0.9;
uniform float filtro_manchas = 0.3;
uniform float filtro_crestas = 0.6;
uniform float filtro_espec = 0.55;
uniform float filtro_fresnel = 0.10;
uniform float filtro_tinte_visto = 1.0;
uniform float filtro_franjas_banda = 0.20;    // 24/10: ancho (valor de ruido) del borde de la veta con el agua filtro (FILTRO_FRANJAS_BANDA)
uniform float filtro_franjas_umbral = 0.62;  // 22/10: valor del ruido de franjas a partir del cual hay veta con el agua filtro (FILTRO_FRANJAS_UMBRAL)
uniform float filtro_franjas = 0.20;       // 22/10: opacidad máxima (0-1) de las franjas de la corriente en el agua filtro (FILTRO_FRANJAS); 23/10: ahora es la luz que suma una veta (emisión)
uniform sampler2D cauce : filter_linear, hint_default_black, repeat_disable;   // 23/10: R = 1 en los trocitos de un cauce hondo abierto/lleno (`_montar_cauce`); 0 en el resto
uniform float filtro_realce = 1.0;          // 23/10: cuánto se aclara el fondo que se ve a través del agua fuera del río (FILTRO_REALCE; 1 = nada)
uniform float filtro_velo = 0.0;             // y el velo turquesa que se le suma, por profundidad (FILTRO_VELO)
uniform float filtro_flujo_0 = 0.12;        // 23/10: corriente (u/s) a la que empiezan las vetas con el agua filtro (FILTRO_FLUJO_0)…
uniform float filtro_flujo_1 = 0.70;       // …y a la que llevan toda su fuerza (FILTRO_FLUJO_1)
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
varying float v_pend;                  // 23/10: pendiente de la profundidad (u/u) de este vértice, suave entre vértices (antes salía de las derivadas de pantalla, constantes por triángulo: parches rectangulares)
const float PEND_NORMAL_MAX = 0.30;       // 24/10: pendiente (u/u) a la que la normal suave de la lámina satura (por debajo se queda igual; ver `g_lim` en el fragmento)
varying vec2 v_grad;                 // 24/10: pendiente de la altura de la superficie (dy/dx, dy/dz) de este vértice; continua entre triángulos (la normal por derivadas de pantalla es plana por triángulo)
varying vec2 v_caida;                // x = cuánto sube el vecino más alto (base de una caída), y = cuánto baja el más bajo (labio); en pendiente (u de altura / u de trocito)

// 24/10 (cortes rectos en las vetas) · El hash de antes (fract(p·(123,34; 456,21)), p += dot(p, p+45,32), fract(p.x·p.y)) amplifica cualquier error de redondeo de 1e-4 en un valor
// del todo distinto, y el mismo vértice de la rejilla del ruido salía distinto según el trozo de código que lo evaluaba (la GPU reordena las sumas y multiplicaciones): el ruido
// tenía saltos de hasta 0,5 en líneas rectas de la rejilla (hasta `ruido(pm.xz * 0,5)` pelado los tenía), que eran los «cortes rectos» de las vetas. Ahora el hash es entero: la
// posición se cuantiza a 1/HASH_CUANTO (a prueba de errores de un ulp) y se mezcla con multiplicaciones y xor desplazados. Mismo rango (0-1) y mismo uso.
const float HASH_CUANTO = 256.0;
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p * HASH_CUANTO + 0.5)));
	uint h = q.x * 1597334673u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h >> 8u) * (1.0 / 16777216.0);
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

// 22/10 (esquinas) · Lo que el dibujo sabe de UN trocito de simulación. La malla del agua tiene un vértice por trocito Y UNO EXTRA en el centro de cada cuadrito
// (abanico de 4 triángulos, ver `_construir_malla`): el de centro combina los cuatro trocitos de su alrededor con `combina_centro`.
const float MEDIA_DIAGONAL = 0.7071;      // media diagonal de un cuadrito en lados de trocito: lo que hay de un vértice mojado al centro de un cuadrito mixto (donde la profundidad es 0)

struct Troc {
	float y;           // altura de la superficie en el vértice (con hielo, topes y la bajada de la lámina)
	float prof;        // profundidad con signo: negativa en un trocito seco que adopta la de su vecino mojado (la orilla cae entre ambos)
	vec2 corr;         // corriente (simulación + flow map del río)
	float orilla;      // 1 = toca tierra (franja de orilla)
	vec2 caida;        // (base, labio) de una caída, en pendiente del LECHO
	float hielo;       // 0-1
	float mojado;      // 1 = el trocito tiene agua de verdad (g >= minima), 0 = seco
	float pend;        // 23/10: pendiente de la profundidad con signo (u/u) hacia el vecino más distinto; un vecino seco cuenta como −prof (el contorno cae entre ambos)
};

Troc troc(ivec2 p) {
	ivec2 s = textureSize(datos_a, 0);
	vec4 d = dato(p);
	float y = d.r;
	float prof = d.g;
	vec2 corr = d.ba;
	float orilla = 0.0;                              // 1 = casilla de agua con algún vecino seco/tierra (la franja de orilla de 125)
	float pend = 0.0;                                // 23/10: pendiente de la profundidad en este trocito (ver `Troc.pend`)
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
			pend = mejor / (MEDIA_DIAGONAL * lado_trocito);
			corr = cs;
		} else {
			prof = -1.0;
		}
	}
	if (flujo_activo > 0.5 && prof > 0.0) {
		corr += texelFetch(flujo, clamp(p, ivec2(0), s - 1), 0).rg * vel_rio;     // la corriente propia del río (cae a cero hacia las orillas)
	}
	if (d.g >= minima) {
		// 23/10: pendiente de la profundidad hacia el vecino más distinto. Un vecino seco cuenta como el contorno a una media diagonal (el centro del cuadrito mixto tiene profundidad 0);
		// así sale lo mismo que daba el gradiente del triángulo junto a una orilla recta, pero continuo entre triángulos.
		ivec2 dir3[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int k = 0; k < 4; k++) {
			vec4 n3 = dato(p + dir3[k]);
			pend = max(pend, n3.g >= minima ? abs(n3.g - d.g) / lado_trocito : d.g / (MEDIA_DIAGONAL * lado_trocito));
		}
	}
	float base_c = 0.0;
	float labio_c = 0.0;
	if ((caida_fuerza > 0.0 || orilla_mov > 0.0) && d.g >= minima) {
		ivec2 dir2[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int k = 0; k < 4; k++) {
			vec4 n2 = dato(p + dir2[k]);
			if (n2.g >= minima) {
				// 22/10: desnivel del LECHO (R - G = altura − profundidad), no de la superficie. Una lámina que se llena tiene escalones de superficie
				// entre trocitos llenos y vacíos sobre un lecho llano, y eso no es una cascada (antes salía niebla blanca de base en todo el frente).
				float dy = ((n2.r - n2.g) - (d.r - d.g)) / lado_trocito;
				base_c = max(base_c, dy);
				labio_c = max(labio_c, -dy);
			} else {
				orilla = 1.0;
			}
		}
	}
	float hf = 0.0;
	if (hielo_activo > 0.5) {
		hf = hielo_f(p);
		y += alto_hielo * hf;                          // el hielo sobresale un poco: se ve una losa, no una mancha
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
	return Troc(y, prof, corr, orilla, vec2(base_c, labio_c), hf, d.g >= minima ? 1.0 : 0.0, pend);
}

// Vértice de CENTRO de un cuadrito: combina sus cuatro trocitos. Si el cuadrito mezcla agua y seco, su profundidad es 0 (el contorno del agua pasa por el
// centro: las esquinas, convexas o cóncavas, quedan cuadradas y sin el chaflán que dejaba un triángulo vacío según la diagonal); altura, corriente, orilla,
// caída y hielo salen de los trocitos mojados. Si los cuatro son iguales (todos mojados o todos secos), es la media de los cuatro.
Troc combina_centro(Troc a, Troc b, Troc c, Troc d) {
	float n = a.mojado + b.mojado + c.mojado + d.mojado;
	float w_a = n > 0.5 && n < 3.5 ? a.mojado : 1.0;           // en un cuadrito mixto solo cuentan los mojados; si no, los cuatro
	float w_b = n > 0.5 && n < 3.5 ? b.mojado : 1.0;
	float w_c = n > 0.5 && n < 3.5 ? c.mojado : 1.0;
	float w_d = n > 0.5 && n < 3.5 ? d.mojado : 1.0;
	float k = 1.0 / (w_a + w_b + w_c + w_d);
	Troc r;
	r.y = (a.y * w_a + b.y * w_b + c.y * w_c + d.y * w_d) * k;
	r.corr = (a.corr * w_a + b.corr * w_b + c.corr * w_c + d.corr * w_d) * k;
	r.caida = (a.caida * w_a + b.caida * w_b + c.caida * w_c + d.caida * w_d) * k;
	r.hielo = (a.hielo * w_a + b.hielo * w_b + c.hielo * w_c + d.hielo * w_d) * k;
	r.orilla = (a.orilla + b.orilla + c.orilla + d.orilla) * 0.25;     // la media de los cuatro: el vaivén del centro sigue al de sus esquinas (con el máximo salían facetas brillantes)
	r.prof = (a.prof * w_a + b.prof * w_b + c.prof * w_c + d.prof * w_d) * k;
	r.pend = (a.pend * w_a + b.pend * w_b + c.pend * w_c + d.pend * w_d) * k;
	if (n > 0.5 && n < 3.5) {
		r.prof = 0.0;
		r.orilla = 1.0;
	}
	r.mojado = n > 0.5 ? 1.0 : 0.0;
	return r;
}

// 24/10 (cortes por trocito) · Corriente (simulación + flow map del río) en un punto del mundo, CONTINUA: bilineal entre los cuatro trocitos de alrededor con pesos suavizados
// (3t²−2t³, pendiente cero en cada centro: sin quiebros al cruzar de un trocito a otro). Solo cuentan los trocitos con agua (un seco no arrastra la corriente a cero);
// si ninguno de los cuatro tiene, se usa la de los vértices (`respaldo`). Antes la corriente del fragmento era la interpolada entre vértices, lineal por triángulo: con la
// dirección de un trocito a otro distinta, las vetas y la espuma cambiaban de golpe en el borde del trocito.
vec2 corriente_suave(vec2 xz, vec2 respaldo) {
	vec2 tp = xz / lado_trocito - 0.5;
	ivec2 i0 = ivec2(floor(tp));
	vec2 f = fract(tp);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 s = textureSize(datos_a, 0);
	vec2 suma = vec2(0.0);
	float peso = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k % 2, k / 2);
		ivec2 p = i0 + o;
		float w = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		vec4 d = dato(p);
		if (d.g >= minima) {
			vec2 c = d.ba;
			if (flujo_activo > 0.5) {
				c += texelFetch(flujo, clamp(p, ivec2(0), s - 1), 0).rg * vel_rio;
			}
			suma += c * w;
			peso += w;
		}
	}
	return peso > 0.0001 ? suma / peso : respaldo;
}

void vertex() {
	ivec2 s = textureSize(datos_a, 0);
	Troc t;
	// Los vértices de trocito caen en el centro de su texel (fract = 0,5); los de centro de cuadrito, en la esquina entre cuatro (fract ≈ 0 o ≈ 1).
	bool centro = abs(fract(UV.x * float(s.x)) - 0.5) > 0.25;
	vec2 pend_y;           // 24/10: pendiente de la altura (dy/dx, dy/dz) en este vértice por diferencias centradas: la normal suave del fragmento (`v_grad`)
	if (centro) {
		ivec2 p0 = ivec2(floor(UV * vec2(s) - 0.5));
		Troc c00 = troc(p0);
		Troc c10 = troc(p0 + ivec2(1, 0));
		Troc c01 = troc(p0 + ivec2(0, 1));
		Troc c11 = troc(p0 + ivec2(1, 1));
		t = combina_centro(c00, c10, c01, c11);
		pend_y = vec2((c10.y + c11.y) - (c00.y + c01.y), (c01.y + c11.y) - (c00.y + c10.y)) / (2.0 * lado_trocito);
	} else {
		ivec2 p1 = ivec2(floor(UV * vec2(s)));
		t = troc(p1);
		pend_y = vec2(troc(p1 + ivec2(1, 0)).y - troc(p1 - ivec2(1, 0)).y, troc(p1 + ivec2(0, 1)).y - troc(p1 - ivec2(0, 1)).y) / (2.0 * lado_trocito);
	}
	v_grad = pend_y;
	// 20/10 (b): vaivén tenue de la orilla. Dos senos de periodos distintos (3,7 s y 2,3 s) desfasados por posición, para que la orilla no respire
	// entera a la vez. Amplitud total ≤ `orilla_mov`. Es un movimiento de la superficie, no de la simulación: no cambia profundidad ni corriente.
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float oleaje = 0.55 * sin(TIME * 1.698 + dot(wp, vec2(1.3, 0.9))) + 0.45 * sin(TIME * 2.732 + dot(wp, vec2(-0.7, 1.6)));
	oleaje *= t.orilla * (hielo_activo > 0.5 ? 1.0 - t.hielo : 1.0);        // el hielo no se mece
	VERTEX.y = t.y + orilla_mov * oleaje;
	v_oleaje = oleaje;
	v_caida = t.caida;
	v_prof = t.prof;
	v_pend = t.pend;
	v_corr = t.corr;
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 24/10 · normalize que no revienta: con un vector casi nulo o no finito devuelve «arriba». Una normal NaN en el agua daba UVs de refracción NaN y el fondo salía del
// píxel de una esquina de la pantalla (menta uniforme al llenarse el cauce, parches marrón claro del tamaño de un trocito en el río).
vec3 norm_seguro(vec3 v) {
	float l2 = dot(v, v);
	return l2 > 1.0e-12 ? v * inversesqrt(l2) : vec3(0.0, 1.0, 0.0);
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
	vec3 n = norm_seguro(cross(v2 - v0, v1 - v0));
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

// Normal SUAVE de las olas en `p` (agua filtro): gradiente de `ola_est` por diferencias finitas, a la misma escala que las facetas (altura_ola por u).
vec3 normal_suave(vec2 p, float t) {
	float e = 0.12;
	float h0 = ola_est(p, t);
	float gx = (ola_est(p + vec2(e, 0.0), t) - h0) / e;
	float gz = (ola_est(p + vec2(0.0, e), t) - h0) / e;
	return norm_seguro(vec3(-gx * altura_ola, 1.0, -gz * altura_ola));
}

// Franjas alargadas en el sentido de la corriente: ruido estirado a lo largo de `dir`.
float franja_eje(vec2 uv, vec2 dir) {
	vec2 per = vec2(-dir.y, dir.x);
	float a = dot(uv, dir);
	float b = dot(uv, per);
	return ruido(vec2(a * 0.45, b * 3.2));
}

// 24/10 (cortes por trocito) · El ruido se gira hacia `dir` respecto al ORIGEN del mundo: un cambio de 1° en la dirección mueve el patrón (distancia al origen / tam_franja) × 3,2 × 0,017
// celdas, decenas de metros más allá, y entre un trocito y otro la veta cortaba en seco. Ahora el ruido se calcula en FRANJA_EJES orientaciones fijas y se mezcla entre las dos más
// cercanas a la dirección (con una rampa que deja un ángulo casi puro): el patrón cambia de forma continua con la corriente y no se amplifica con la distancia.
const float FRANJA_EJES = 16.0;
const vec2 FRANJA_MEZCLA = vec2(0.3, 0.7);
float franja(vec2 uv, vec2 dir) {
	float k = atan(dir.y, dir.x) * (FRANJA_EJES / TAU);
	float k0 = floor(k);
	float t = smoothstep(FRANJA_MEZCLA.x, FRANJA_MEZCLA.y, k - k0);
	float a0 = k0 * (TAU / FRANJA_EJES);
	float a1 = a0 + TAU / FRANJA_EJES;
	return mix(franja_eje(uv, vec2(cos(a0), sin(a0))), franja_eje(uv, vec2(cos(a1), sin(a1))), t);
}

// 24/10 (cascada EoW) · Efectos del PIE de las caídas en un punto del mundo: x = espuma por celdas redondeadas que respira (anillo blanco de manchas), y = ondas concéntricas que
// se abren desde el pie y se desvanecen. Solo hacia el agua de la charca (la espuma sube un poco por la parte baja de la cortina; las ondas no). Sin pies no cuesta nada.
const float CAIDA_DESCARTE = 0.45;  // caída (0-1) a partir de la cual no se dibuja la superficie inclinada si hay lámina de cortina
const int ONDAS_PIE_N = 3;         // crestas a la vez por pie, escalonadas en fase (ver ONDAS_PIE_N en GDScript)
vec2 efectos_pie(vec2 xz) {
	float espuma_m = 0.0;
	float ondas_m = 0.0;
	for (int i = 0; i < pies_n; i++) {
		vec4 p = pies[i];
		vec4 pd = pies_dir[i];
		vec2 d = xz - p.xy;
		float r = length(d);
		if (r > onda_pie_rmax + 0.6) {
			continue;
		}
		float lado = dot(d, pd.xy);                                   // > 0: hacia el agua de la charca
		float r_ir = r + (ruido(xz * 3.3 + vec2(TIME * 0.15, 0.0)) - 0.5) * 0.30;     // borde de la espuma irregular
		float m = (1.0 - smoothstep(pie_espuma_radio * 0.45, pie_espuma_radio, r_ir)) * smoothstep(-0.55, -0.1, lado) * pd.z;
		m *= 0.88 + 0.12 * sin(TIME * pie_espuma_resp + pd.w * 6.2832);   // respira, cada pie con su fase
		espuma_m = max(espuma_m, m);
		float hacia = smoothstep(-0.15, 0.25, lado / max(r, 0.001));
		for (int k = 0; k < ONDAS_PIE_N; k++) {
			float f = fract(TIME * onda_pie_vel + float(k) / float(ONDAS_PIE_N) + pd.w);
			float rad = mix(0.25, onda_pie_rmax, f);
			float ancho = onda_pie_ancho * (0.7 + 0.8 * f);
			float q = (r_ir - rad) / ancho;
			ondas_m = max(ondas_m, exp(-q * q) * (1.0 - f) * (1.0 - f) * smoothstep(0.0, 0.08, f) * pd.z * hacia);
		}
	}
	float espuma = 0.0;
	if (espuma_m > 0.01) {
		// Celdas (Voronoi) que se mueven: cerca del pie todo es espuma; hacia fuera solo quedan manchas redondeadas, cada una con su pulso.
		vec3 c = celdas(xz / pie_espuma_celda + vec2(TIME * 0.10, -TIME * 0.06));
		float puntaje = espuma_m * 1.25 + (0.5 - c.x) * 1.1 + sin(TIME * pie_espuma_resp + c.z * 6.2832) * 0.10 - 0.62;
		espuma = smoothstep(0.0, 0.18, puntaje);
	}
	return vec2(espuma, ondas_m);
}

void fragment() {
	vec3 pm = v_pos;
	// 22/10 (agua blanca al llenarse): DISTANCIA (u) de este píxel al contorno del agua, ≈ profundidad / pendiente de la profundidad. La profundidad es lineal
	// en cada triángulo. Una lámina somera y llana (que se llena) tiene gradiente casi 0 → distancia enorme → ni espuma ni menisco ni ruido de borde: eso solo va pegado al contorno real.
	// 23/10: la pendiente sale de los VÉRTICES (`v_pend`, continua entre triángulos). Antes salía de las derivadas de pantalla, que son constantes por triángulo: el frente de una lámina que
	// se llena (escalones de profundidad entre trocitos) daba un menisco y una espuma distintos en cada triángulo, y se veían parches rectangulares pálidos con el borde del trocito.
	float dist_orilla = max(v_prof, 0.0) / max(v_pend, orilla_grad_min);
	float cerca_orilla = 1.0 - smoothstep(orilla_dist_0, orilla_dist_1, dist_orilla);          // 1 junto al contorno, 0 a más de `orilla_dist_1`
	float cerca_menisco = 1.0 - smoothstep(orilla_dist_0 * 1.5, orilla_dist_1 * 1.5, dist_orilla);
	// 16/10 (Pablo: «ruido entre la textura de la orilla y el agua»): la profundidad se interpola entre vértices de 0,77 u y su línea de cero sale
	// recta y en diagonales; se le suma un ruido de dos escalas (quieto, casi sin deriva: no debe parpadear) para que el borde sea irregular.
	// El mismo `prof_e` rige el corte, la línea de espuma y el menisco, así que espuma y arena siguen el mismo contorno. 22/10: solo cerca del contorno.
	float ruido_borde = ruido(pm.xz * 2.7 + vec2(TIME * 0.02, 0.0)) * 0.65 + ruido(pm.xz * 6.3 - 4.1) * 0.35;
	float prof_e = v_prof + (ruido_borde - 0.5) * ruido_orilla * 2.0 * cerca_orilla;
	if (prof_e < 0.0) {
		discard;                       // fuera del agua: el borde sigue la orilla de la simulación (con ruido)
	}
	vec2 corr = corriente_suave(pm.xz, v_corr);
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
	vec3 gn = norm_seguro(cross(dFdx(pm), dFdy(pm)));
	if (gn.y < 0.0) {
		gn = -gn;
	}
	vec3 nm = norm_seguro(mix(normal_faceta(pm.xz - dir * avance * fase1 * adveccion_olas, TIME),
			normal_faceta(pm.xz - dir * avance * fase0 * adveccion_olas, TIME), peso0));     // las olas viajan con la corriente
	if (filtro > 0.5) {
		// Agua filtro: la normal es casi toda la suave (sin aristas de faceta en el fondo refractado ni en el brillo).
		vec3 ns = norm_seguro(mix(normal_suave(pm.xz - dir * avance * fase1 * adveccion_olas, TIME),
				normal_suave(pm.xz - dir * avance * fase0 * adveccion_olas, TIME), peso0));
		nm = norm_seguro(mix(nm, ns, filtro_suavidad));
	}
	// 24/10: lo que inclina la normal de las olas es la pendiente SUAVE de los vértices, no la `gn` de derivadas de pantalla (plana por triángulo): con las alturas de la lámina
	// escalonadas al llenarse, cada triángulo salía con su fresnel, su refracción y su brillo y se veían rectángulos y diagonales pálidos. `gn` se queda para la cascada y el hielo.
	vec2 g_lim = v_grad * inversesqrt(1.0 + dot(v_grad, v_grad) / (PEND_NORMAL_MAX * PEND_NORMAL_MAX));     // sin tope, el frente de una lámina que se llena (escalones de 0,3-1 u entre trocitos) inclina la normal casi a 45° y sale blanco por fresnel y refracción
	vec3 gn_suave = norm_seguro(vec3(-g_lim.x, 1.0, -g_lim.y));
	nm = norm_seguro(nm + (gn_suave - vec3(0.0, 1.0, 0.0)) * 2.0);
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
			nm = norm_seguro(nm + vec3(-pend.x, 0.0, -pend.y) * ondas_fuerza * (1.0 - hielo));   // el hielo no se ondula
			cresta = clamp(abs(h0) * ondas_fuerza * 3.0 - 0.3, 0.0, 1.0) * (1.0 - hielo);
		}
	}

	// Color: somero -> hondo por la profundidad, en bandas.
	float hondo = smoothstep(prof_clara, prof_rio, v_prof);        // 13.9 (b): la opacidad
	float hondo_b = floor(smoothstep(prof_clara, prof_color, v_prof) * bandas + 0.5) / bandas;   // y el color, con su propia rampa
	vec3 ce = mix(color_somero_est, color_hondo_est, hondo_b);
	float lf = clamp(dot(nm, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
	float cfa = filtro > 0.5 ? filtro_contraste_faceta : contraste_faceta;
	ce *= 1.0 - cfa + cfa * 1.3 * smoothstep(0.7, 1.0, lf);
	if (filtro > 0.5) {
		ce = color_espuma;         // agua filtro: el color del agua lo pone el filtro; aquí solo queda la base de la espuma y del hielo
	}

	// Franjas que corren con la corriente (flow map de dos fases desfasadas medio ciclo y mezcladas).
	vec2 uv = pm.xz / tam_franja;
	// 23/10: con el agua filtro las vetas piden una corriente de verdad (FILTRO_FLUJO_*): la que deja una simulación que se llena o se agita (0,1-0,5 u/s, a trompicones de un
	// trocito a otro) ya no las enciende, y salían parches pálidos con el borde del trocito. El río (0,9 u/s propios) las lleva enteras como antes.
	// Solo el agua de un cauce hondo lleno (textura `cauce`, 1 en sus trocitos) usa las vetas nuevas; el río, el estanque, el lab y la Cueva conservan las de siempre.
	float cauce_f = texture(cauce, pm.xz / (lado_trocito * vec2(textureSize(cauce, 0)))).r;
	float efecto_flujo = filtro > 0.5 ? smoothstep(filtro_flujo_0, filtro_flujo_1, vel) : smoothstep(0.04, 0.3, vel);     // 24/10: la misma corriente de verdad en todo el agua filtro (el río incluido)
	float fr = franja(uv - dir * avance * fase0 / tam_franja, dir) * peso0
			+ franja(uv + 0.37 - dir * avance * fase1 / tam_franja, dir) * (1.0 - peso0);
	// 22/10: el cruce de las dos fases promedia dos ruidos y casi nunca pasa de 0,62; con el filtro el umbral baja (FILTRO_FRANJAS_UMBRAL) para que haya vetas.
	float um_franja = filtro > 0.5 ? filtro_franjas_umbral : 0.62;
	float franjas = smoothstep(um_franja, um_franja + (filtro > 0.5 ? filtro_franjas_banda : 0.08), fr) * efecto_flujo;
	ce = mix(ce, color_espuma, franjas * 0.32);

	// LECHO (16/10, Pablo: «es translúcida y está bien, pero no hay sensación de profundidad»). No hay un fondo real bajo el agua (la
	// superficie es lo único que se dibuja), así que se finge: el punto del lecho que se ve a través de este píxel está desplazado
	// en la dirección contraria a la mirada tanto más cuanto más profundo es el agua (paralaje). Sobre ese punto se pinta un fondo oscuro
	// y la red de cáusticas (celdas de Voronoi); al mover la cámara el lecho se desliza respecto a la superficie y se lee como profundidad.
	// Pesa más donde el agua es somera/translúcida (ahí se ve el fondo) y casi nada donde ya es opaca; el hielo no lo lleva.
	if (lecho > 0.0 && hielo < 0.5 && filtro < 0.5) {
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
	float cr_f = filtro > 0.5 ? filtro_crestas : 1.0;     // agua filtro: las crestas de un impacto se ven, pero menos
	float manchas = smoothstep(umbral_m - 0.02, umbral_m + 0.10, suma) * clamp(rompe * 1.6 + cresta * cr_f, 0.0, 1.0);
	manchas *= smoothstep(0.06, 0.2, v_prof);
	if (filtro > 0.5) {
		manchas *= filtro_manchas;     // agua filtro: sin manchas en el centro salvo donde la corriente rompe fuerte, y discretas
	}
	// Orilla: espuma nítida donde la profundidad (interpolada hasta el borde) es casi cero; se funde con el agua hacia dentro.
	// 13.9 (d): el ruido del borde lo arrastra la corriente (el mismo flow map), y por dentro de la orilla va el menisco: una franja ancha y tenue.
	float borde = ruido(pm.xz * 2.2 - dir * TIME * clamp(vel, 0.0, 2.0) * 0.5 + TIME * 0.2);
	// 20/10 (b): la franja de espuma respira con el vaivén (±30 % de su ancho a la amplitud por defecto); proporcional a `orilla_mov`.
	float trans = transicion_orilla * (1.0 + 0.3 * v_oleaje * clamp(orilla_mov / 0.02, 0.0, 2.0));
	// 24/10 (bordes EoW) · la línea clara de la orilla ondula despacio (ruido de baja frecuencia en el valor de la profundidad): sigue el contorno pero no es una recta de regla.
	float ondula_linea = (ruido(pm.xz * orilla_linea_escala + vec2(TIME * 0.03, -TIME * 0.02)) - 0.5) * orilla_linea_ruido;
	float linea = 1.0 - smoothstep(0.0, trans, prof_e + (borde - 0.5) * 0.04 + ondula_linea);
	linea *= linea * cerca_orilla;      // 22/10: la espuma de orilla solo junto al contorno (una lámina somera lejos de él no es espuma)
	float men = (1.0 - smoothstep(trans, trans * 3.5, prof_e)) * menisco * (0.55 + 0.45 * borde) * cerca_menisco;
	float espuma = clamp(max(linea, max(manchas * 0.85, cresta * 0.8 * cr_f)), 0.0, 1.0);
	// CAÍDAS (15/10): donde la superficie se inclina de verdad es una cascada: vetas blancas que bajan por ella; en la BASE (el trocito que
	// tiene un vecino mucho más alto) niebla de espuma que se agita; en el LABIO (el que tiene uno mucho más bajo) un filo de agua rápida.
	float pend_s = 1.0 - clamp(gn.y, 0.0, 1.0);
	// 22/10: y solo si el LECHO baja de verdad ahí (v_caida es pendiente del lecho): el frente de una lámina que se llena inclina la superficie sin ser una cascada.
	float lecho_cae = smoothstep(caida_lecho_min, caida_lecho_min + 0.2, max(v_caida.x, v_caida.y));
	float caida = smoothstep(caida_pend_min, caida_pend_min + 0.3, pend_s) * lecho_cae * caida_fuerza * (1.0 - hielo);
	if (filtro > 0.5 && cortina_geom > 0.5 && caida > CAIDA_DESCARTE) {
		discard;       // 24/10: con lámina vertical de cortina (CODIGO_CORTINA) la superficie muy inclinada de la caída no se dibuja: salía como un cristal pálido delante de la cortina
	}
	vec2 dd = normalize(gn.xz + vec2(0.0001, 0.0));
	float a_traves = dot(pm.xz, vec2(-dd.y, dd.x));       // coordenada a lo ancho de la cortina (las vetas son verticales: corren por pm.y)
	float veta = ruido(vec2(a_traves * 4.0, pm.y * 1.4 + TIME * vel_caida));
	// 22/10 (movimiento): una segunda capa de vetas, más fina y más rápida, que baja desfasada: la cortina se lee como agua que cae y no como un patrón que parpadea.
	float veta2 = ruido(vec2(a_traves * 7.0 + 3.7, pm.y * 2.0 + TIME * vel_caida * caida_veta2_vel));
	float cortina = max(smoothstep(0.50, 0.70, veta), smoothstep(0.56, 0.72, veta2) * caida_veta2) * caida;
	float base_f = smoothstep(0.10, 0.50, v_caida.x) * caida_fuerza * (1.0 - hielo);
	float labio_f = smoothstep(0.10, 0.50, v_caida.y) * caida_fuerza * (1.0 - hielo);
	float niebla = base_f * (0.45 + 0.55 * ruido(pm.xz * 2.4 + vec2(0.0, -TIME * 1.1)));
	vec3 luz_fx = vec3(0.0);        // 24/10: luz que se SUMA a la emisión del agua filtro (cortina, labio, ondas del pie); `(1 - a_x)` la apaga bajo la espuma opaca
	float ondas_pie = 0.0;
	if (filtro > 0.5) {
		// CASCADA EoW (24/10): una cortina translúcida azul con vetas verticales brillantes en TRES capas que bajan a velocidades distintas (la ancha y lenta, la de siempre y la fina y
		// rápida), un labio superior más claro y el agua de detrás visible. Las vetas SUMAN luz (`cortina_luz`); solo una parte es espuma opaca (`cortina_opacidad`).
		float veta3 = ruido(vec2(a_traves * 2.4 + 11.3, pm.y * 0.8 + TIME * vel_caida * caida_veta3_vel));
		float v1 = smoothstep(0.50, 0.70, veta);
		float v2 = smoothstep(0.56, 0.72, veta2) * caida_veta2;
		float v3 = smoothstep(0.50, 0.74, veta3) * caida_veta3;
		// Con lámina de cortina (`cortina_geom`, ver CODIGO_CORTINA) la cortina de la superficie inclinada se apaga: la lámina vertical es la que se ve.
		float caida_s = caida * (1.0 - cortina_geom);
		float vetas = clamp(max(v1, max(v2, v3)) * 0.75 + (v1 + v2 + v3) * 0.15, 0.0, 1.0) * caida_s;
		luz_fx += vec3(0.80, 0.95, 1.0) * vetas * cortina_luz + vec3(0.22, 0.55, 0.85) * caida_s * cortina_velo + vec3(0.88, 0.97, 1.0) * labio_f * cortina_labio;
		// La espuma del PIE (celdas redondeadas que respiran) y las ondas concéntricas; en la cortina misma no hay ondas.
		vec2 fx_pie = efectos_pie(pm.xz);
		ondas_pie = fx_pie.y * (1.0 - caida) * (1.0 - hielo);
		luz_fx += vec3(0.85, 0.97, 1.0) * ondas_pie * onda_pie_luz;
		espuma = clamp(max(max(espuma, vetas * cortina_opacidad), max(max(niebla * 0.35, labio_f * 0.25) * (1.0 - cortina_geom), fx_pie.x * pie_espuma_fuerza * (1.0 - hielo))), 0.0, 1.0);
	} else {
		espuma = clamp(max(espuma, max(cortina * 0.85, max(niebla * 0.9, labio_f * 0.45))), 0.0, 1.0);
	}
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
	if (refraccion > 0.5 || filtro > 0.5) {
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
		if (filtro > 0.5) {
			// AGUA FILTRO: lo que se ve es el fondo refractado × la transmitancia de Beer de la columna de agua (por canal: el rojo se absorbe antes → turquesa),
			// y solo en lo hondo un poco de color propio (dispersión). La espuma, el menisco y el hielo van encima con su propia opacidad.
			float pf = max(v_prof, 0.0);
			pf = mix(pf, min(pf, max(bajo, 0.0)), bueno * filtro_tinte_visto);     // banda oscura: la columna es la de lo que se ve (la pared de la orilla queda poco bajo la lámina)
			vec3 trans = exp(-filtro_k * filtro_dens * pf);
			float scat = (1.0 - exp(-pf / filtro_prof_max)) * filtro_opacidad;
			// 22/10 (movimiento): las franjas del flow map también se ven con el filtro (antes solo teñían `ce`, que aquí no se ve): vetas claras y suaves que corren con la corriente.
			// 23/10: la veta ya no mezcla el ALBEDO hacia el blanco (iluminado por el sol y el ambiente salía blanco opaco con solo un 0,4 y tapaba el fondo en parches con borde de
			// trocito); ahora SUMA luz a la emisión (el fondo se sigue viendo debajo) y no pasa del tope `filtro_franjas`.
			float a_franja = franjas * filtro_franjas * smoothstep(0.0, refr_orilla, prof_e) * (1.0 - hielo);
			float a_x = clamp(max(max(max(espuma, men * 0.45), 0.0), hielo), 0.0, 1.0);      // 24/10: la veta ya no mezcla el albedo en ningún agua filtro (en el río salía en manchas blancas opacas): solo suma luz
			vec3 alb_f = filtro_hondo * scat + vec3(0.88, 0.94, 1.0) * fres * filtro_fresnel;
			ALBEDO = mix(alb_f, ce * brillo, a_x);
			// 23/10 (cauce hondo lleno): un lecho de losas oscuras bajo 0,6-1 u de agua salía pizarra apagada (Beer sobre un fondo casi negro); fuera del río se aclara lo que se ve
			// (`filtro_realce`) y se le suma un velo turquesa que crece con la profundidad (`filtro_velo`). Solo en el cauce hondo (cauce_f = 1): el resto queda como estaba.
			vec3 visto = fondo_r * trans * mix(1.0, filtro_realce, cauce_f) + filtro_hondo * filtro_velo * cauce_f * (1.0 - exp(-pf / filtro_prof_max));
			// 24/10 (bordes EoW) · manchas oscuras ORGÁNICAS y redondeadas que se mueven despacio por el fondo que se ve (como sombras de ondas sobre el lecho): dos ruidos de escala
			// distinta con el dominio deformado por otro, para que no sigan las casillas. Más marcadas con algo de agua; la espuma y la cortina (a_x) las tapan.
			vec2 qo = pm.xz * sombra_org_escala;
			vec2 deforma = vec2(ruido(qo * 1.7 + TIME * vec2(0.05, 0.03)), ruido(qo * 1.7 + 7.7 - TIME * vec2(0.04, 0.06))) - 0.5;
			float of1 = ruido(qo + deforma * 1.6 + TIME * vec2(sombra_org_vel, -sombra_org_vel * 0.7));
			float of2 = ruido(qo * 2.3 + deforma * 2.0 + 3.1 - TIME * vec2(sombra_org_vel * 0.8, sombra_org_vel));
			float mancha_o = smoothstep(0.45, 0.56, of1 * 0.7 + of2 * 0.3) * smoothstep(0.08, 0.45, v_prof) * (1.0 - hielo);
			visto = mix(visto, visto * vec3(0.22, 0.46, 0.58), mancha_o * sombra_org_fuerza);
			EMISSION = visto * (1.0 - scat) * (1.0 - a_x) + vec3(0.80, 0.95, 1.0) * a_franja * (1.0 - a_x) + luz_fx * (1.0 - a_x);
			ALPHA = 1.0;
			v_spec = mix(filtro_espec, 1.0, hielo);
		} else {
		ALBEDO = ce * brillo * alfa_f;
		EMISSION = fondo_r * (1.0 - alfa_f);
		ALPHA = 1.0;
		v_spec = alfa_f;
		}
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
// 22/10 (agua filtro): paredes casi transparentes, del color de lo hondo, con el filo claro del menisco.
uniform float filtro = 0.0;
uniform vec3 filtro_hondo : source_color = vec3(0.06, 0.33, 0.38);
uniform float filtro_prof_max = 1.8;
uniform float filtro_alfa = 0.35;
uniform float filtro_tinte_visto = 1.0;

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
	if (filtro > 0.5) {
		ALBEDO = mix(filtro_hondo, color_espuma, filo * menisco) * brillo;
		float p_aqui = mix(max(v_p, 0.0), max(v_p, 0.0) * (1.0 - v_t), filtro_tinte_visto);     // profundidad bajo la lámina en ESTE punto de la cara (arriba 0, abajo la de la casilla)
		ALPHA = clamp(filtro_alfa * (1.0 - exp(-p_aqui / filtro_prof_max)) * (0.6 + 0.4 * v_t) + filo * 0.3, 0.0, 1.0);
	}
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

## 24/10 (cascada EoW) · La CORTINA de una caída: una lámina vertical translúcida (una por cada cara de caída, ver `_actualizar_pies`) delante de la piedra, con el agua de detrás visible.
## UV.x = coordenada a lo ancho (u de mundo, continua entre láminas contiguas), UV.y = altura relativa en la lámina (0 pie, 1 labio). Tres capas de vetas verticales que bajan a distinta
## velocidad (las de VEL_CAIDA, CAIDA_VETA2_VEL y CAIDA_VETA3_VEL), el labio de arriba más claro y la base que se funde con la espuma del pie.
const CODIGO_CORTINA: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 color_hondo : source_color = vec3(0.12, 0.50, 0.85);
uniform vec3 color_claro : source_color = vec3(0.78, 0.95, 1.0);
uniform float alfa_base = 0.34;             // opacidad de la lámina sin vetas (deja ver lo de detrás)
uniform float alfa_veta = 0.50;             // y lo que suben las vetas
uniform float alfa_labio = 0.35;            // y el labio superior
uniform float vel_caida = 2.4;
uniform float veta2_fuerza = 0.7;
uniform float veta2_vel = 1.5;
uniform float veta3_fuerza = 0.55;
uniform float veta3_vel = 0.8;

varying vec3 v_pos;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

const float HASH_CUANTO = 256.0;
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p * HASH_CUANTO + 0.5)));
	uint h = q.x * 1597334673u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h >> 8u) * (1.0 / 16777216.0);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float a = UV.x;
	float t = UV.y;
	float y = v_pos.y;
	float v1 = smoothstep(0.58, 0.78, ruido(vec2(a * 7.0, y * 0.40 + TIME * vel_caida)));
	float v2 = smoothstep(0.62, 0.80, ruido(vec2(a * 12.0 + 3.7, y * 0.65 + TIME * vel_caida * veta2_vel))) * veta2_fuerza;
	float v3 = smoothstep(0.56, 0.80, ruido(vec2(a * 3.5 + 11.3, y * 0.28 + TIME * vel_caida * veta3_vel))) * veta3_fuerza;
	float vetas = clamp(max(v1, max(v2, v3)) * 0.75 + (v1 + v2 + v3) * 0.15, 0.0, 1.0);
	float labio = smoothstep(0.78, 1.0, t);
	float pie = smoothstep(0.0, 0.10, t);
	vec3 col = mix(color_hondo, color_claro, clamp(vetas * 0.9 + labio * 0.6 + t * 0.10, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(alfa_base + vetas * alfa_veta + labio * alfa_labio, 0.0, 1.0) * pie;
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


## Enlaza con la simulación y construye la malla (un vértice por centro de trocito y otro en el centro de cada cuadrito). Se puede llamar otra vez al cambiar de nivel.
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
	_mat.set_shader_parameter("ola3_altura", (FILTRO_OLA3_ALTURA if agua_filtro else OLA3_ALTURA) if olas_tercera_escala else 0.0)
	_mat.set_shader_parameter("ola3_k", TAU / OLA3_LONGITUD)
	_mat.set_shader_parameter("ola3_vel", OLA3_VEL)
	_mat.set_shader_parameter("ola3_dir", Vector2.from_angle(deg_to_rad(OLA3_RUMBO)))
	_mat.set_shader_parameter("ola3_dir2", Vector2.from_angle(deg_to_rad(OLA3_RUMBO + OLA3_CRUCE)))
	# Agua filtro: el filtro, el lecho falso apagado y las constantes FILTRO_* (el sombreado lee la pantalla con filtro aunque la refracción esté apagada).
	_mat.set_shader_parameter("filtro", 1.0 if agua_filtro else 0.0)
	_mat.set_shader_parameter("filtro_k", FILTRO_ABSORCION)
	_mat.set_shader_parameter("filtro_dens", FILTRO_DENSIDAD)
	_mat.set_shader_parameter("filtro_hondo", FILTRO_COLOR_HONDO)
	_mat.set_shader_parameter("filtro_prof_max", FILTRO_PROF_MAX)
	_mat.set_shader_parameter("filtro_opacidad", FILTRO_OPACIDAD_HONDO)
	_mat.set_shader_parameter("filtro_contraste_faceta", FILTRO_CONTRASTE_FACETA)
	_mat.set_shader_parameter("filtro_suavidad", FILTRO_SUAVIDAD)
	_mat.set_shader_parameter("filtro_manchas", FILTRO_MANCHAS)
	_mat.set_shader_parameter("filtro_crestas", FILTRO_CRESTAS)
	_mat.set_shader_parameter("filtro_espec", FILTRO_ESPECULAR)
	_mat.set_shader_parameter("filtro_fresnel", FILTRO_FRESNEL)
	_mat.set_shader_parameter("filtro_tinte_visto", FILTRO_TINTE_VISTO)
	_mat.set_shader_parameter("lecho", LECHO_FALSO_FILTRO if agua_filtro else LECHO_FALSO)
	_mat.set_shader_parameter("orilla_dist_0", ORILLA_DIST_0)
	_mat.set_shader_parameter("orilla_dist_1", ORILLA_DIST_1)
	_mat.set_shader_parameter("orilla_grad_min", ORILLA_GRAD_MIN)
	_mat.set_shader_parameter("caida_lecho_min", CAIDA_LECHO_MIN)
	_mat.set_shader_parameter("avance_flujo", AVANCE_FLUJO)
	_mat.set_shader_parameter("vel_caida", VEL_CAIDA)
	_mat.set_shader_parameter("caida_veta2", CAIDA_VETA2)
	_mat.set_shader_parameter("caida_veta2_vel", CAIDA_VETA2_VEL)
	_mat.set_shader_parameter("caida_veta3", CAIDA_VETA3)
	_mat.set_shader_parameter("caida_veta3_vel", CAIDA_VETA3_VEL)
	_mat.set_shader_parameter("cortina_opacidad", CORTINA_OPACIDAD)
	_mat.set_shader_parameter("cortina_luz", CORTINA_LUZ)
	_mat.set_shader_parameter("cortina_velo", CORTINA_VELO)
	_mat.set_shader_parameter("cortina_labio", CORTINA_LABIO)
	_mat.set_shader_parameter("pie_espuma_radio", PIE_ESPUMA_RADIO)
	_mat.set_shader_parameter("pie_espuma_celda", PIE_ESPUMA_CELDA)
	_mat.set_shader_parameter("pie_espuma_resp", PIE_ESPUMA_RESP)
	_mat.set_shader_parameter("pie_espuma_fuerza", PIE_ESPUMA_FUERZA)
	_mat.set_shader_parameter("onda_pie_vel", ONDA_PIE_VEL)
	_mat.set_shader_parameter("onda_pie_rmax", ONDA_PIE_RMAX)
	_mat.set_shader_parameter("onda_pie_ancho", ONDA_PIE_ANCHO)
	_mat.set_shader_parameter("onda_pie_luz", ONDA_PIE_LUZ)
	_mat.set_shader_parameter("orilla_linea_ruido", ORILLA_LINEA_RUIDO)
	_mat.set_shader_parameter("orilla_linea_escala", ORILLA_LINEA_ESCALA)
	_mat.set_shader_parameter("sombra_org_fuerza", SOMBRA_ORG_FUERZA)
	_mat.set_shader_parameter("sombra_org_escala", SOMBRA_ORG_ESCALA)
	_mat.set_shader_parameter("sombra_org_vel", SOMBRA_ORG_VEL)
	_mat.set_shader_parameter("filtro_franjas", FILTRO_FRANJAS)
	_mat.set_shader_parameter("filtro_franjas_umbral", FILTRO_FRANJAS_UMBRAL)
	_mat.set_shader_parameter("filtro_franjas_banda", FILTRO_FRANJAS_BANDA)
	_mat.set_shader_parameter("filtro_realce", FILTRO_REALCE)
	_mat.set_shader_parameter("filtro_velo", FILTRO_VELO)
	_mat.set_shader_parameter("filtro_flujo_0", FILTRO_FLUJO_0)
	_mat.set_shader_parameter("filtro_flujo_1", FILTRO_FLUJO_1)
	# Con refracción (o con filtro) el agua tapa lo que se dibuje antes: va la primera de lo transparente. Sin ella, la prioridad de siempre (0).
	var lee_pantalla: bool = agua_refraccion or agua_filtro
	_mat.render_priority = AGUA_PRIORIDAD if lee_pantalla else 0
	if _mat_pared != null:
		_mat_pared.render_priority = PARED_PRIORIDAD if lee_pantalla else 0
		_mat_pared.set_shader_parameter("filtro", 1.0 if agua_filtro else 0.0)
		_mat_pared.set_shader_parameter("filtro_hondo", FILTRO_COLOR_HONDO)
		_mat_pared.set_shader_parameter("filtro_prof_max", FILTRO_PROF_MAX)
		_mat_pared.set_shader_parameter("filtro_alfa", FILTRO_ALFA_PARED)
		_mat_pared.set_shader_parameter("filtro_tinte_visto", FILTRO_TINTE_VISTO)
	_aplicar_lecho()


## Agua filtro: el material del LECHO de cantos (LechoRio3D) recibe aquí la textura de datos de la simulación (profundidad por trocito: las cáusticas son más fuertes con poco
## fondo) y el tamaño del trocito. Se vuelve a dar cada vez que la textura se rehace (primera lectura).
var _mat_lecho: ShaderMaterial = null


func enlazar_lecho(m: ShaderMaterial) -> void:
	_mat_lecho = m
	_aplicar_lecho()


## Adornos del lecho (algas): reciben el flow map de la corriente para balancearse hacia donde corre el agua (LechoRio3D.enlazar_flujo). Se vuelve a dar al rehacerse el flow map.
var _adornos_lecho: Node3D = null


func enlazar_adornos(raiz: Node3D) -> void:
	_adornos_lecho = raiz
	_aplicar_adornos()


func _aplicar_adornos() -> void:
	if _adornos_lecho == null or not is_instance_valid(_adornos_lecho) or _mat == null or sim == null:
		return
	var tex: Texture2D = _mat.get_shader_parameter("flujo") as Texture2D
	if tex != null:
		LechoRio3D.enlazar_flujo(_adornos_lecho, tex, sim.l)


func _aplicar_lecho() -> void:
	if _mat_lecho == null or _tex_b == null or sim == null:
		return
	_mat_lecho.set_shader_parameter("datos", _tex_b)
	_mat_lecho.set_shader_parameter("lado_trocito", sim.l)
	_mat_lecho.set_shader_parameter("usa_datos", 1.0)


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
		_aplicar_lecho()
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
	_actualizar_cauce()
	_lecturas += 1
	if _lecturas % 4 == 0:
		_buscar_caidas()
	if paredes and (primera or _lecturas % maxi(paredes_cada, 1) == 0):
		var t2: int = Time.get_ticks_usec()
		_reconstruir_paredes()
		_ms_paredes = lerpf(_ms_paredes, float(Time.get_ticks_usec() - t2) / 1000.0, 0.2)
	_ms_lectura = lerpf(_ms_lectura, float(Time.get_ticks_usec() - t0) / 1000.0, 0.2)


## 23/10 (agua del cauce hondo lleno) · Textura R8 por trocito con 1 en los trocitos de las casillas de cauce abiertas a la simulación (`Terreno3D.cauces_abiertos`, y se quedan ahí
## cuando pasan a «~»): el sombreado (`cauce`) aclara el fondo que se ve a través de esa agua y usa las vetas de corriente nuevas. Se rehace solo si cambia el número de casillas abiertas.
var _n_cauces: int = 0
func _actualizar_cauce() -> void:
	var n: int = Terreno3D.cauces_abiertos.size()
	if n == _n_cauces or sim == null or _mat == null:
		return
	_n_cauces = n
	var img := Image.create(sim.w, sim.h, false, Image.FORMAT_R8)
	var por_casilla: float = sim.lado_casilla / sim.l          # trocitos por lado de casilla
	for c in Terreno3D.cauces_abiertos.keys():
		var v: Vector2i = c
		for y in range(roundi(float(v.y) * por_casilla), roundi(float(v.y + 1) * por_casilla)):
			for x in range(roundi(float(v.x) * por_casilla), roundi(float(v.x + 1) * por_casilla)):
				if x >= 0 and y >= 0 and x < sim.w and y < sim.h:
					img.set_pixel(x, y, Color(1.0, 0.0, 0.0))
	_mat.set_shader_parameter("cauce", ImageTexture.create_from_image(img))


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
	_aplicar_adornos()


## Busca en la simulación los trocitos de BASE de una caída (agua con un vecino de agua bastante más alto) y avisa de los mayores (`caida_detectada`).
func _buscar_caidas() -> void:
	if sim == null:
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
			var k_mejor: int = 0
			var desnivel: float = 0.0
			var sup_alta: float = sup
			for k in range(4):
				var j: int = vec[i * 4 + k]
				if j < 0 or cerrado[j] == 1 or prof[j] < minima:
					continue
				var salto: float = suelo[j] + prof[j] - sup
				if salto > mejor:
					mejor = salto
					k_mejor = k
					desnivel = suelo[j] - suelo[i]
					sup_alta = suelo[j] + prof[j]
			if mejor >= SALTO_CAIDA:
				cand.append([mejor, Vector3((float(x) + 0.5) * sim.l, sup, (float(y) + 0.5) * sim.l), k_mejor, desnivel, sup_alta])
	# Mayor salto primero; a igual salto, por posición (el orden no cambia entre lecturas: los pies no parpadean cuando hay más de PIES_MAX).
	cand.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		var pa: Vector3 = a[1]
		var pb: Vector3 = b[1]
		return pa.x < pb.x if not is_equal_approx(pa.x, pb.x) else pa.z < pb.z)
	if caida_detectada.has_connections():
		for k in range(mini(cand.size(), MAX_CAIDAS)):
			caida_detectada.emit(global_transform * (cand[k][1] as Vector3) if is_inside_tree() else (cand[k][1] as Vector3), float(cand[k][0]))
	_actualizar_pies(cand)


## Los vecinos de una casilla en el orden de `sim.vecinos`: izquierda (-x), derecha (+x), arriba (-z), abajo (+z).
const DIRS_VECINOS: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]
var _pies_cpu := PackedVector4Array()       ## los pies que lleva el sombreado: x, z (mundo), y, salto
var _gotas: GPUParticles3D = null
var _gotas_pm: ParticleProcessMaterial = null
var _gotas_firma: int = 0
var _cortinas: MeshInstance3D = null          ## las láminas verticales de las cortinas (una malla)
var _mat_cortina: ShaderMaterial = null
## Las gotas que saltan en el pie de las caídas se pueden apagar (si otro sistema ya las pone).
@export var gotas_caida: bool = true


## Pies de caída (ver PIES_MAX): del candidato de cada base saca su posición (hacia fuera de la caída), la dirección hacia la charca, la fuerza por el salto y una fase por posición; lo
## sube al sombreado (`pies`, `pies_dir`) solo si cambió, y mueve el emisor de gotas a esos puntos.
func _actualizar_pies(cand: Array) -> void:
	if _mat == null:
		return
	var pies := PackedVector4Array()
	var dirs := PackedVector4Array()
	var locales := PackedVector3Array()
	var caras: Array = []           # por pie: [centro de la base, dirección hacia el trocito alto, y de la charca, y del labio] en coordenadas de este nodo
	for c in cand:
		if pies.size() >= PIES_MAX or float(c[0]) < PIE_SALTO_MIN:
			break
		if float(c[3]) < PIE_DESNIVEL_MIN:
			continue                # el frente de una lámina que se llena (el lecho no baja ahí) no es una cascada
		var salto: float = c[0]
		var lejos: Vector2 = -DIRS_VECINOS[int(c[2])]            # de la base, hacia fuera de la caída (el vecino alto queda al otro lado)
		var local: Vector3 = (c[1] as Vector3) + Vector3(lejos.x, 0.0, lejos.y) * (PIE_DESPLAZA * sim.l)
		var mundo: Vector3 = global_transform * local if is_inside_tree() else local
		var dir_m: Vector3 = global_transform.basis * Vector3(lejos.x, 0.0, lejos.y) if is_inside_tree() else Vector3(lejos.x, 0.0, lejos.y)
		var dir_xz := Vector2(dir_m.x, dir_m.z).normalized()
		var fase: float = fposmod(sin(local.x * 12.9898 + local.z * 78.233) * 43758.5453, 1.0) * PIE_FASE_MAX
		pies.append(Vector4(mundo.x, mundo.z, mundo.y, salto))
		dirs.append(Vector4(dir_xz.x, dir_xz.y, clampf(salto / PIE_SALTO_REF, 0.35, 1.0), fase))
		locales.append(local)
		caras.append([c[1], -lejos, float((c[1] as Vector3).y), float(c[4])])
	var firma: int = hash(pies)
	if firma == _gotas_firma and (_gotas != null or pies.is_empty()):
		return
	_gotas_firma = firma
	_pies_cpu = pies
	var n: int = pies.size()
	while pies.size() < PIES_MAX:
		pies.append(Vector4.ZERO)
		dirs.append(Vector4.ZERO)
	_mat.set_shader_parameter("pies_n", n)
	_mat.set_shader_parameter("pies", pies)
	_mat.set_shader_parameter("pies_dir", dirs)
	_mat.set_shader_parameter("cortina_geom", 1.0 if n > 0 and agua_filtro else 0.0)
	_poner_cortinas(caras)
	_poner_gotas(locales)


## Láminas verticales de cortina (una por pie, CODIGO_CORTINA): el plano entre el trocito de la charca y el alto, de la altura de la charca a la del labio, un poco hacia la charca para
## no pelearse con la cara de la piedra. Una sola malla (una llamada de dibujo); se rehace solo cuando cambian los pies.
func _poner_cortinas(caras: Array) -> void:
	if caras.is_empty() or not agua_filtro:
		if _cortinas != null:
			_cortinas.visible = false
		return
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for cara in caras:
		var base: Vector3 = cara[0]
		var hacia: Vector2 = cara[1]                       # del trocito de la charca hacia el alto
		var paralelo := Vector2(-hacia.y, hacia.x)
		var centro := Vector2(base.x, base.z) + hacia * (0.5 * sim.l) - hacia * CORTINA_SEPARA
		var a: Vector2 = centro - paralelo * (0.5 * sim.l)
		var b: Vector2 = centro + paralelo * (0.5 * sim.l)
		var y0: float = float(cara[2]) - bajada_lamina - CORTINA_HUNDE          # la lámina de agua se dibuja `bajada_lamina` por debajo de la superficie de la simulación
		var y1: float = float(cara[3]) - bajada_lamina
		var u0: float = a.dot(paralelo)
		var u1: float = b.dot(paralelo)
		var n0: int = vs.size()
		vs.append(Vector3(a.x, y0, a.y))
		vs.append(Vector3(b.x, y0, b.y))
		vs.append(Vector3(b.x, y1, b.y))
		vs.append(Vector3(a.x, y1, a.y))
		uvs.append(Vector2(u0, 0.0))
		uvs.append(Vector2(u1, 0.0))
		uvs.append(Vector2(u1, 1.0))
		uvs.append(Vector2(u0, 1.0))
		idx.append_array(PackedInt32Array([n0, n0 + 1, n0 + 2, n0, n0 + 2, n0 + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _cortinas == null:
		_cortinas = MeshInstance3D.new()
		_cortinas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sh := Shader.new()
		sh.code = CODIGO_CORTINA
		_mat_cortina = ShaderMaterial.new()
		_mat_cortina.shader = sh
		_mat_cortina.render_priority = CORTINA_PRIORIDAD
		_mat_cortina.set_shader_parameter("vel_caida", VEL_CAIDA)
		_mat_cortina.set_shader_parameter("veta2_fuerza", CAIDA_VETA2)
		_mat_cortina.set_shader_parameter("veta2_vel", CAIDA_VETA2_VEL)
		_mat_cortina.set_shader_parameter("veta3_fuerza", CAIDA_VETA3)
		_mat_cortina.set_shader_parameter("veta3_vel", CAIDA_VETA3_VEL)
		_mat_cortina.set_shader_parameter("alfa_base", CORTINA_ALFA_BASE)
		_mat_cortina.set_shader_parameter("alfa_veta", CORTINA_ALFA_VETA)
		_mat_cortina.set_shader_parameter("alfa_labio", CORTINA_ALFA_LABIO)
		_cortinas.material_override = _mat_cortina
		add_child(_cortinas)
	_cortinas.mesh = malla
	_cortinas.visible = true


## Mueve las gotas a los pies (puntos en coordenadas de este nodo). Sin pies o con `gotas_caida` apagado, no emiten.
func _poner_gotas(locales: PackedVector3Array) -> void:
	if locales.is_empty() or not gotas_caida:
		if _gotas != null:
			_gotas.emitting = false
		return
	if _gotas == null:
		_gotas = _crear_gotas()
		add_child(_gotas)
	var img := Image.create(PIES_MAX, 1, false, Image.FORMAT_RGBF)
	for i in range(locales.size()):
		img.set_pixel(i, 0, Color(locales[i].x, locales[i].y, locales[i].z))
	var tex := ImageTexture.create_from_image(img)
	_gotas_pm.emission_point_texture = tex
	_gotas_pm.emission_point_count = locales.size()
	_gotas.visibility_aabb = AABB(Vector3(-1.0, -4.0, -1.0), Vector3(float(sim.w) * sim.l + 2.0, 12.0, float(sim.h) * sim.l + 2.0))
	_gotas.emitting = true


## Un único emisor de gotas para todas las caídas: GOTAS_MAX partículas como mucho, discos con borde claro (burbujas) que saltan hacia arriba y caen.
func _crear_gotas() -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = GOTAS_MAX
	gp.lifetime = GOTAS_VIDA
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.direction = Vector3.UP
	pm.spread = GOTAS_ABANICO
	pm.initial_velocity_min = GOTAS_VEL_MIN
	pm.initial_velocity_max = GOTAS_VEL_MAX
	pm.gravity = Vector3(0.0, -GOTAS_GRAVEDAD, 0.0)
	pm.scale_min = GOTAS_TAM_MIN
	pm.scale_max = GOTAS_TAM_MAX
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(0.92, 0.98, 1.0, 0.9), Color(0.85, 0.96, 1.0, 0.75), Color(0.85, 0.96, 1.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	_gotas_pm = pm
	var tg := Gradient.new()               # disco con borde claro y centro casi transparente: una burbuja
	tg.offsets = PackedFloat32Array([0.0, 0.55, 0.82, 0.95, 1.0])
	tg.colors = PackedColorArray([Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.3), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = tg
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = tex
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = sm
	gp.draw_pass_1 = q
	return gp


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
	# Un vértice por trocito (w·h) y UNO EXTRA en el centro de cada cuadrito ((w-1)·(h-1)), a continuación de los otros. Sus UV caen en la esquina
	# entre cuatro texels (el sombreado los reconoce por eso y combina los cuatro trocitos). Cuatro triángulos por cuadrito, en abanico: sin diagonal,
	# así que el contorno del agua no depende de hacia dónde caiga (antes: chaflán y un triángulo vacío en las esquinas).
	var n_trocitos: int = w * h
	verts.resize(n_trocitos + (w - 1) * (h - 1))
	uvs.resize(verts.size())
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			verts[i] = Vector3((x + 0.5) * l, 0.0, (y + 0.5) * l)
			uvs[i] = Vector2((x + 0.5) / float(w), (y + 0.5) / float(h))
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (h - 1) * 12)
	var k: int = 0
	for y in range(h - 1):
		for x in range(w - 1):
			var a: int = y * w + x
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			var m: int = n_trocitos + y * (w - 1) + x
			verts[m] = Vector3((x + 1.0) * l, 0.0, (y + 1.0) * l)
			uvs[m] = Vector2((x + 1.0) / float(w), (y + 1.0) / float(h))
			idx[k] = a; idx[k + 1] = c; idx[k + 2] = m
			idx[k + 3] = c; idx[k + 4] = d; idx[k + 5] = m
			idx[k + 6] = d; idx[k + 7] = b; idx[k + 8] = m
			idx[k + 9] = b; idx[k + 10] = a; idx[k + 11] = m
			k += 12
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
