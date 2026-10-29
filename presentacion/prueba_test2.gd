extends Node3D

## MAQUETA 3D DE TEST 2 (estética pastel).
## Lee el mismo plano de letras de test_2.gd (40 x 40) y lo monta en 3D: bloques con el suelo pintado y
## TRANSICIONES suaves entre hierba / camino / tierra / piedra (shader), agua animada, el decorado de Meshy
## (bosque.glb, objetos.glb, magia.glb), partículas (fuego, humo, brasas, esporas, destellos, pétalos) y los
## personajes chibi del pipeline. Es solo visual: se pasea con la chibi; no hay hechizos ni pruebas.
##
## Teclas: WASD mover · Shift correr · + / - zoom (la inclinación está fija a 60°, ver INCLINACION) · H sombras · P partículas
##         K decorado on/off · G hierba 3D on/off · L luz plana/suave de personajes · [ / ] tamaño de la chibi
##
## Rendimiento (docs/PLAN_ACCION_TEST2.md §1.3): el decorado va por LOTES (un MultiMesh por pieza y malla, no un
## nodo por casilla), la hierba en bloques que Godot descarta fuera de cámara y sin sombra, y la sombra del sol
## llega a 30 m. El HUD enseña llamadas de dibujo, primitivas y memoria de vídeo para la tabla de §1.2.

const TEST2 = preload("res://mundo/datos_nivel/datos_test2.gd")

const S: float = 2.3                ## lado de una casilla en unidades (la chibi mide ~1)
const ALTO: float = S * 0.45        ## alto de un bloque de tierra
## 23/10: la pared de la Cueva (`pared_foso_cueva.png`, 1024 × 512) cubre 2 S de ancho; en vertical se estira ×2 (= su proporción 2:1) para que las piedras no salgan alargadas.
const PARED_FOSO_ESCALA_V: float = 2.0
## La textura sale muy oscura (valor medio ~0,25) y con la luz de la cueva la pared de la charca se perdía en negro: se multiplica el albedo del costado (HDR: Color admite > 1).
const PARED_FOSO_BRILLO: float = 2.6
## 27/10: el mojado en la Cueva (ver `_construir_suelo`, estilo «cueva»): oscurece casi sin color, más brillo especular y menos rugoso.
const MOJADO_CUEVA_TINTE: Vector3 = Vector3(0.38, 0.4, 0.44)
const MOJADO_CUEVA_ESPEC: float = 1.0
const MOJADO_CUEVA_RUG: float = 0.12
## 6.16: el agua llega CASI a ras del bloque de hierba (4 cm por debajo; antes 0,6 × ALTO y se veía un escalón de 40 cm). El Lanzador y el
## Jugador leen esta constante, así que el nivel lógico del agua sube con la imagen.
const ALTO_AGUA: float = ALTO - 0.04
const VEL_ANDAR: float = 1.6
const VEL_CORRER: float = 3.0
const ZOOM_INICIAL: float = 6.0
const ZOOM_MINIMO: float = 2.0
const SEGUIMIENTO: float = 14.0
## Inclinación de la cámara, BLOQUEADA (Pablo, 6/10: «de momento lockeamos en 60 grados, siguiendo al personaje»). Solo el zoom +/- sigue libre.
## Para volver a probar otros ángulos, cambiar esta constante (las teclas R/F y 1/2/3 se quitaron).
const INCLINACION: float = 60.0

const RAIZ: String = "res://arte/modelos/"
const SUELO: String = "res://arte/suelo_meshy/"
const VFX: String = "res://presentacion/vfx/"
const PRECALENTAR: float = 1.6
const RUNAS: String = VFX + "runas/"
## Cartel de Meshy: giro para que el tablero mire a la cámara y dónde queda el centro del tablero (MEDIDA 1.3).
const GIRO_CARTEL: float = 319.0
## Orientación a mano de una pieza concreta del mapa Test 2 (el de jugabilidad tiene la suya: Jugabilidad3D.GIROS): casilla (x, y) del mapa → grados sobre el eje vertical. Gana a todo lo demás
## (el giro aleatorio de cada casilla y los giros fijos del código). Ej.: Vector2i(12, 7): 90.0 gira 90° lo que haya en esa casilla.
const GIROS_CELDA: Dictionary = {
}
const RUNA_EN_TABLERO: Vector3 = Vector3(0.0, 1.0, 0.14)
## Si una pieza está en varias bibliotecas, se usa la de la primera. Antes que todas, las REGENERADAS sueltas de
## meshy/piezas/<id>.glb (una pieza por GLB; ver meshy/INTEGRAR_PIEZAS.cmd): sustituyen a la de la lámina.
const CARPETA_PIEZAS: String = Pieza3D.CARPETA_PIEZAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
const BIBLIOTECAS: Array = Pieza3D.BIBLIOTECAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Las piezas buenas de las bibliotecas nuevas sustituyen a las de la lámina (REGENERAR.md §1): árbol y pino
## (arboles_2), seto (arbusto_otono en vez de seto_seco), puesto (puesto_mercado) y arco (arco_ruina).
## Si la nueva falta, se usa la vieja.
const SUSTITUTAS: Dictionary = Pieza3D.SUSTITUTAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Empujables (todavía sin mecánica en la maqueta): cubos con la textura de tierra o de hielo.
const EMPUJABLES: Array = [["tierra", Vector2i(6, 33)], ["hielo", Vector2i(28, 26)]]
## Las texturas de suelo_meshy son claras para la paleta (V 0,8-0,99; ARTE.md pide 0,2-0,76): se oscurecen
## aquí y la luz vuelve a valores normales (antes se bajaba la luz y se apagaban también los personajes).
const OSCURECER_SUELO: float = 0.78
const LUZ_AMBIENTE: float = 0.6
const LUZ_SOL: float = 1.0

## Personajes: id del pipeline (res://arte/modelos/<id>.glb) y su alto en pantalla. Si falta, el sustituto.
const PJ_JUGADOR: Array = ["jugadora_base", "woodland_wanderer", "chibi_elf_v2", "chibi_elf", "chibi_test"]   # 24/10: la jugadora nueva (jugadora_base, Mixamo + ropa por piezas) sustituye a la elfa de 100k (woodland_wanderer, 12/10), que queda de respaldo si falla la carga
const PJ_LIBRERA: Array = ["bookseller_chibi", "elfo_base", "chibi_test"]   # 22/10: elfo_base = el elfo básico de la familia (Tripo, clips de chibi_elf vía ClipsFamilia)
const PJ_GOBLIN: Array = ["goblin_warrior_chibi", "goblin_warrior"]
## Espadachín: el mismo modelo del guerrero con espada (Pj3D.MODELO_DE + Equipo3D.EQUIPO). Ocupa las "A" del
## mapa hasta que haya arquero en 3D.
const PJ_ESPADACHIN: Array = ["goblin_espadachin", "goblin_warrior_chibi"]
## Elemental de bosque (el enemigo élite lento; ver combate_3d.gd, ID_ELEMENTAL). Sin sustituto: si falta el modelo, no sale.
const PJ_ELEMENTAL: Array = ["elemental_bosque"]
## Personajes nuevos (6/10): la alquimista de los mercados, el arquero y el guardabosques. Sus GLB aún no están en el repo
## (COPIAR_MODELOS.cmd los copia desde el pipeline): mientras falten, `_personaje` usa el siguiente de la lista.
const PJ_ALQUIMISTA: Array = ["alchemist_elf", "elfo_base", "bookseller_chibi", "chibi_test"]   # 22/10: elfo_base, el elfo básico, antes que la librera
const PJ_ARQUERO: Array = ["goblin_archer_chibi", "goblin_espadachin", "goblin_warrior_chibi"]
## Goblin asesino (22/10): dos dagas, ataque doble y movimiento agazapado; mismo comportamiento cuerpo a cuerpo que el guerrero. Sin letra de mapa todavía: se crea con `_personaje(PJ_ASESINO, pos)`.
const PJ_ASESINO: Array = ["goblin_asesino", "goblin_espadachin", "goblin_warrior_chibi"]
const PJ_GUARDABOSQUES: Array = ["ranger_human", "bookseller_chibi", "chibi_test"]
const ALTO_PJ: Dictionary = {"woodland_wanderer": 1.0, "chibi_elf_v2": 1.0, "chibi_elf": 1.0, "chibi_test": 1.0, "bookseller_chibi": 0.95,
	"goblin_warrior_chibi": 0.85, "goblin_warrior": 0.85, "goblin_espadachin": 0.85, "jugadora_base": 1.0,      # 24/10: la jugadora (base + ropa por piezas), primera de PJ_JUGADOR
	"alchemist_elf": 0.95, "elfo_base": 1.0, "goblin_archer_chibi": 0.85, "goblin_base": 0.85, "marimanta": 0.8,"goblin_asesino": 0.85, "ranger_human": 1.1,      # 10/10: el guardabosques (Meshy «Wolfwood Ranger») es un adulto: algo más alto que la elfa
	"elemental_bosque": 2.5,      # elite lento: el doble de alto que un goblin (0,85)
	"goblin_chaman": 0.85,       # 28/10: el chamán goblin (esqueleto de Marimanta + bastón), como los otros goblins
	"golem_piedra": 1.7,         # 28/10: el gólem de piedra (cuerpo riggeado), el doble de alto que un goblin
	"loberno": 0.75,      # 13/10: lobo (Meshy). Mide 0,60 u de alto y 1,02 de largo; a 0,75 sus zancadas casan con VEL_PATRULLA (walk) y VEL_PERSEGUIR (Gallop)
	"gato_guardabosques": 0.55,   # 11/10: la mascota del guardabosques; su alto incluye la cola levantada (el lomo queda a ~0,35)
	"lince": 0.65}      # 14/10: la mascota que sustituye al gato; su alto incluye cola y cuerno (el lomo queda a ~0,33)

## Tamaño de cada pieza de decorado (alto en unidades; las marcadas "ancho" se miden por su ancho).
const MEDIDA: Dictionary = Pieza3D.MEDIDA     ## la tabla vive en pieza_3d.gd (la usa también el editor)
const MEDIDA_ANCHO: Dictionary = Pieza3D.MEDIDA_ANCHO     ## la tabla vive en pieza_3d.gd (la usa también el editor)

## --- Alturas del suelo (6/10, Pipeline; criterio de Link's Awakening: cada casilla tiene UN nivel y lo plano va a ras) ---
## Antes cada pieza plana (placa, baldosa) se escalaba por su ancho y sobresalía lo que diera su malla (grosores distintos),
## los discos de runa iban a +0,03 y +0,05 puestos a ojo, y las bases irregulares de Meshy dejaban huecos o flotaban.
## Ahora: lo plano sobresale un grosor FIJO (PLANAS), todo decal va a una de dos alturas y toda pieza se hunde HUNDIR.
## `ALTO` y `ALTO_AGUA` no cambian de valor: el Lanzador y el Jugador los leen de aquí (ver diario).
const Y_DECAL: float = ALTO + 0.02        ## discos, runas y marcas sobre el suelo desnudo (igual que Vfx3D._marca)
const Y_SOBRE_PLANA: float = ALTO + 0.07  ## decal encima de una pieza plana (baldosa de guardado): grosor de la baldosa + 0,03
const HUNDIR: float = 0.03                ## cuánto se entierra cada pieza: la base irregular de Meshy no deja hueco ni flota
## Piezas planas: lo que sobresale del suelo, en unidades, da igual lo gruesa que venga la malla (el resto queda enterrado).
const PLANAS: Dictionary = Pieza3D.PLANAS     ## la tabla vive en pieza_3d.gd (la usa también el editor)
## Sombra de contacto (elipse plana, borde duro) bajo cada pieza en pie: ancla la pieza al suelo como en Link's Awakening.
## Radio en unidades antes de la variación de tamaño de cada copia. Lo que no está aquí no lleva sombra (plano o diminuto).
const SOMBRA_CONTACTO: Dictionary = {
	"arbol_redondo": 0.95, "arbol_redondo_2": 0.95, "pino": 0.8, "pino_2": 0.8, "arbusto": 0.6, "arbusto_flores": 0.6,
	"arbusto_otono": 0.7, "seto_seco": 0.7, "roca_grande": 0.75, "roca_cristal": 0.6, "tronco": 0.6, "tocon": 0.4,
	"totem_runico": 0.5, "brasero": 0.45, "fogata": 0.5, "puesto": 1.0, "puesto_mercado": 1.0, "dummy": 0.45,
	"cartel": 0.4, "barril": 0.4, "cofre": 0.45, "caja": 0.45, "caja_pequena": 0.35, "valla": 0.4, "arco_ruina": 0.9,
	"arco_puerta": 0.9, "portal_salida": 0.9, "seta_reactiva": 0.4, "flor_reactiva": 0.4, "raiz_reactiva": 0.4,
	# 16/10 (14.2, e): las piezas de las bibliotecas nuevas de Meshy no llevaban sombra. Radio ≈ 0,55 × la huella media medida de cada una
	# (herramientas/medir_pies.gd); las de suelo (helechos, hierba alta, hojas, cañas, paja, flores) no llevan, como las matas.
	"campamento_cazo": 0.8, "campamento_cofre": 0.75, "campamento_rocas": 0.9, "campamento_tienda": 1.5, "cristal_elemental": 0.3,
	"cristal_sanctuario": 0.6, "estandarte_goblin": 0.3, "pilar": 0.5, "raiz_mundo": 0.4, "roca_musgosa": 0.45, "rocas_pequenas": 0.36,
	"tienda_goblin": 0.9, "torre_goblin": 0.9, "tinaja_ruina": 0.65, "tronco_musgoso": 0.46, "tronco_resina": 0.35,
	"tronco_sin_resina": 0.32, "troncos_apilados": 0.38,
}

## Estado de la hierba por casilla (ESTADOS_SUELO.md §1.2). Una casilla sin entrada es hierba FINA.
enum Fase { CRECIDA = 1, PRENDIENDO = 2, ARDIENDO = 3, CENIZAS = 4 }
const MAX_ARDIENDO: int = 60         ## casillas de hierba encendidas a la vez; más allá no se propaga
const MAX_FX_HIERBA: int = 24        ## de ellas, las que llevan partículas (el resto solo oscurece el suelo)
const T_PRENDIENDO: float = 1.0      ## s en PRENDIENDO antes de ARDIENDO (IGNITE_TIME)
const T_ARDIENDO: float = 5.0        ## s ardiendo antes de CENIZAS (BURN_TIME); R sube lineal en ese tiempo
const FRENTE_VEL: float = 0.5        ## casillas/s a las que crece el frente de contagio (32 px/s ÷ 64)
const FRENTE_MIN: float = 0.4        ## a partir de aquí el frente puede prender (26 px)
const T_SALTO: float = 0.6           ## s que espera una casilla encendida antes de contagiar a una vecina (6.9a)
const FRENTE_MAX: float = 1.7        ## y se acaba aquí (SPREAD_RADIUS 110 px)
const CONO_VIENTO: float = 3.6       ## alcance del viento sobre hierba ardiendo (230 px)
const T_PISADO: float = 2.0          ## s que tarda en levantarse la hierba pisada (solo aspecto)
const T_CRECER: float = 0.6          ## s que tarda la hierba en brotar al regarla
## Ids pequeños del decorado en lotes que NO proyectan sombra (Paso 4): solo árboles, bloques, puestos y personajes.
const SIN_SOMBRA: Array = ["arbusto", "arbusto_flores", "arbusto_otono", "seto_seco", "piedras", "piedra", "setas",
	"seta", "tocon", "cartel", "pasadero", "juncos", "matas", "flores", "caja_pequena", "baldosa_guardado", "pocion"]
## Bloque 4 EoW: piezas del decorado cuya sombra la proyecta una copia reducida (≈ 1/8 de triángulos, MallaReducida3D) y no la malla entera.
const SOMBRA_REDUCIDA: Array = ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2", "cueva_pared", "cueva_esquina_ext", "cueva_esquina_int"]
const FRACCION_SOMBRA: float = 0.125
## Bloque 1 EoW: piezas del decorado que se mecen con el viento y con cuánta fuerza (1 = árbol de copa redonda). El pino, más rígido.
## Solo en las piezas de los lotes (el decorado que no reacciona): un seto que arde lleva los materiales de Reactivo3D.
const VIENTO_DECORADO: Dictionary = {"arbol_redondo": 1.0, "arbol_redondo_2": 1.0, "pino": 0.6, "pino_2": 0.6,
	"arbusto": 1.0, "arbusto_flores": 1.0, "arbusto_otono": 1.0}
## Rejillas de prueba del tamaño de textura (Paso 4): px que ocupa en pantalla un metro a 1080p con el zoom inicial.
const PX_POR_UNIDAD_1080: float = 1080.0 / ZOOM_INICIAL

const COLOR_ELEMENTO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "rayo": Color(1.0, 0.92, 0.4),
}

## Mezcla del suelo: un mapa de tipos por casilla (R hierba, G camino, B tierra, A piedra) que el shader
## lee DEFORMADO por un campo de ruido para que los bordes salgan ondulados y no cuadrados. El ruido es una
## textura hecha en CPU (`_campo_ruido`), así la hierba 3D (Hierba3D) sabe exactamente dónde está el borde.
## Además: dos muestras de cada textura a escalas y giros distintos mezcladas por ruido (no se ve la
## repetición en cuadros) y una variación suave de tono a gran escala.
## 14.2 (e): la sombra de contacto es ahora SombraContacto3D (degradado suave; antes un disco de borde duro con alfa 0,30). `SOMBRA_DUREZA` 1 vuelve al disco.
const SOMBRA_ALFA: float = 0.34
const SOMBRA_DUREZA: float = 0.0

const CODIGO_SUELO: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D mapa : filter_linear, repeat_disable;
uniform sampler2D campo : filter_linear, repeat_enable;
uniform sampler2D t_hierba : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_camino : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_tierra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_piedra : source_color, filter_linear_mipmap, repeat_enable;
// 15/10 (Juego, DIARIO 84): BORDE DE HIERBA. Una franja de hojas (hierba_borde.png, 885x172, alfa) tendida sobre la frontera entre la hierba y
// cualquier otro suelo, con su lado deshilachado hacia el otro suelo, y la hierba junto a la frontera algo más oscura. Sin textura: borde_fuerza = 0.
uniform sampler2D t_borde : source_color, filter_linear, repeat_enable;
uniform float borde_fuerza = 0.0;                                       // 0 = sin borde (no hay textura) · 1 = el borde completo
uniform float borde_ancho = 0.9;                                        // alto de la franja en unidades de mundo (0,4 casillas)
uniform float borde_oscuro = 0.78;                                      // lo que se oscurece la hierba pegada a la frontera (1 = nada)
uniform vec3 borde_tinte : source_color = vec3(0.80, 0.90, 0.72);       // las hojas de Meshy son más claras que la hierba del suelo
// 16/10 (Juego, 14.2 · P4): BORDES ENTRE TODOS LOS MATERIALES. El borde de hierba de arriba cubre «hierba contra lo que sea»; esto cubre las parejas
// que quedaban en una mezcla blanda y difusa: camino↔tierra, camino↔piedra y tierra↔piedra. En cada pareja un material «lame» al otro: su color
// se funde sobre el vecino en un degradado de `par_lame` u, con el filo deshilachado por un ruido fino de `par_ruido` u y un poco de sombra en el
// propio filo. Los tres valores van en el orden (camino↔tierra, camino↔piedra, tierra↔piedra); el que lame es siempre el primero de la pareja
// (la arena del camino lame la tierra y la piedra; la tierra lame la piedra). Además la hierba «invade» la tierra con matas sueltas.
// `par_fuerza` = 0 vuelve a la mezcla de antes; `invade_hierba` = 0 quita las matas.
uniform float par_fuerza = 1.0;
uniform vec3 par_lame = vec3(0.5, 0.4, 0.25);                           // u de degradado de cada pareja (camino↔tierra, camino↔piedra, tierra↔piedra)
uniform vec3 par_ruido = vec3(0.30, 0.25, 0.40);                        // u de desflecado del filo de cada pareja
uniform float par_sombra = 0.18;                                        // lo que se oscurece el filo del que lame (0 = nada)
uniform float invade_hierba = 1.0;                                      // matas de hierba sueltas sobre la tierra junto a la hierba (0 = ninguna)
// joints: TIRAS DE TRANSICIÓN (PLAN_EOW_VISUAL §1.3). `joints_fuerza` = 0 las quita (queda el suelo de antes). La TABLA de pares (ancho, amplitud del
// ruido, densidad, escala, tinte) vive en prueba_test2.gd (`JOINTS_PARES`) y llega por estos uniforms. Cada tira es una banda de MIGAS del suelo que
// «lame» (su color, tinte incluido) tendida sobre el otro, con el filo cortado por ruido (no por casilla) y un borde algo más oscuro; las matas de
// hierba (hierba→camino, hierba→piedra) reutilizan la máscara de `invade_hierba`. Va ANTES del estado: lo mojado, quemado o helado también pinta la tira.
// `mapa_fuera` (R = 1 en agua, cauce seco y huecos) apaga las tiras junto a ellos: el agua y las orillas no llevan tira de suelo.
uniform float joints_fuerza = 0.0;
uniform sampler2D mapa_fuera : hint_default_black, filter_linear, repeat_disable;
uniform vec4 joint_ct = vec4(0.55, 0.22, 0.9, 2.3);                     // camino→tierra: (ancho u, amplitud del ruido u, densidad 0-1, escala del grano)
uniform vec4 joint_cp = vec4(0.50, 0.20, 0.85, 2.3);                    // camino→piedra
uniform vec4 joint_tp = vec4(0.60, 0.25, 0.9, 2.3);                     // tierra→piedra
uniform vec3 joint_tinte_ct : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 joint_tinte_cp : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 joint_tinte_tp : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 joint_matas = vec3(0.7, 0.0, 0.8);                         // fuerza de las matas de hierba sobre camino, (tierra: ya lo hace invade_hierba), piedra
uniform vec3 joint_matas_ancho = vec3(1.4, 0.0, 1.2);                   // y hasta dónde se adentran (u) sobre camino, tierra, piedra
// joints lámina: ATLAS pintado (arte/suelo_meshy/joints_atlas.png, 1024 x 640 = 5 filas de 128 px; orden y orientación en herramientas/joints_atlas.py:
// 0 camino→tierra · 1 camino→piedra · 2 tierra→piedra · 3 hierba→camino · 4 hierba→piedra; arriba = lado denso = suelo de origen, abajo = migas sobre el vecino).
// `joints_lamina` 1 = usa el atlas en esas cinco parejas (0 = la tira procedural de antes; se pone a 0 sola si falta el archivo). Hierba→tierra no
// tiene fila: sigue con las matas de `invade_hierba`.
uniform sampler2D t_joints : source_color, filter_linear_mipmap, repeat_enable;
uniform float joints_lamina = 0.0;
uniform float joints_contraste = 0.85;     // CONSERVACIÓN del contraste pintado: 1 = como está pintada (máximo contraste); 0 = todo a la media local (liso). Más alto = más contraste y más presencia
uniform float joints_escala = 5.5;         // u de mundo que mide el atlas a lo ancho (1024 px); la altura de la fila (128 px) es la octava parte de eso, multiplicada por `joints_ancho` de la pareja
uniform vec4 joints_ancho = vec4(1.6, 1.8, 1.8, 1.6);   // estiramiento a lo ancho de la tira (a lo largo de su eje perpendicular a la frontera) de las filas 0-3: 1 = proporción pintada; 2 = el doble de ancha
uniform float joints_ancho4 = 1.8;         // lo mismo de la fila 4 (hierba→piedra)
uniform float joints_afina = 0.6;          // 0-1: cuánto se acerca el color de las losas (todo) y el de la arena/tierra (parcial) del atlas al de su suelo de origen
uniform float joints_piedra_ref = 0.30;    // luminancia lineal media de las losas del atlas (para conservar su luminancia relativa al teñirlas)
uniform float joints_sigue = 0.4;         // 0 = la tira sigue la frontera lisa de la rejilla; 1 = la frontera ruidosa real del suelo (la misma que corta el degradado)
uniform float joints_linea = 0.44;         // v (0-1 dentro de la fila) donde cae la frontera de los dos suelos
uniform vec3 color_ceniza : source_color = vec3(0.22, 0.20, 0.18);
uniform float fuerza_ceniza = 0.0;     // 6.14: el suelo NO se ennegrece al quemarse (0 = nada; 1 = el antiguo suelo de ceniza)
uniform vec3 color_escarcha : source_color = vec3(0.84, 0.94, 0.98);
// 21/10 (Juego/Pipeline, V4 de PLAN_EOW_VISUAL + B2): ESTADO DEL SUELO, una casilla por píxel, de UNA sola fuente:
//   estado_juego  = Mundo3D.textura_estados() = Terreno3D.estados (OFICIAL): R quemada · G mojada · B helada · A segada (cada canal con su intensidad)
// (Lo pisado de la hierba no es del suelo: lo lee solo el shader de la hierba, de `_tex_pisado`.) `estado_eow` = 0 devuelve el aspecto de antes de V4
// (bordes de casilla, quemado sin pintar, mojado y hielo sin reflejo) con la misma textura.
// Sin casillas: el canal filtrado (bilineal) sube de 0 a 1 en una casilla; en vez de cortarlo en 0,5 (el borde de la casilla) se le suma un ruido de
// `estado_ruido` y se corta ahí con un filo de `estado_filo` de ancho: el contorno sale irregular y pintado, no un cuadrado.
uniform sampler2D estado_juego : hint_default_black, filter_linear, repeat_disable;
uniform float estado_eow = 1.0;
uniform float estado_ruido = 0.6;        // cuánto desplaza el ruido el contorno (en unidades del canal: 0,5 ≈ media casilla)
uniform float estado_filo = 0.06;        // ancho del filo del contorno (en unidades del canal)
// Quemado: albedo × carbón, un borde chamuscado hacia fuera y manchas de ceniza gris encima. Fuera de la hierba se pinta un poco menos.
uniform float fuerza_quemado = 1.0;
uniform vec3 carbon_mult = vec3(0.10, 0.09, 0.085);        // el albedo se multiplica por esto en lo quemado
uniform vec3 chamusco_mult = vec3(0.50, 0.38, 0.27);      // y por esto en el filo, antes del carbón
uniform vec3 color_ceniza_gris : source_color = vec3(0.50, 0.49, 0.47);
uniform float ceniza_gris = 0.3;                          // cuánto cubren las manchas de ceniza gris (0 = nada)
uniform float quemado_sin_hierba = 0.75;                  // fuerza del quemado sobre tierra, camino o piedra (1 = igual que en la hierba)
// Mojado: oscuro y azulado, con el filo un poco más oscuro, y brillante: baja la rugosidad y sube SPECULAR para que refleje la sonda de la sala.
uniform vec3 tinte_mojado = vec3(0.62, 0.66, 0.78);       // el mismo tinte del 2D
uniform float filo_mojado = 0.14;                         // lo que se oscurece el borde del charco
uniform float rug_mojado = 0.18;
uniform float espec_mojado = 0.6;
// Helado: escarcha clara con un borde azulado de fresnel (más azul y más brillo donde el suelo se ve de refilón) y rugosidad baja.
uniform vec3 color_fresnel_hielo : source_color = vec3(0.45, 0.72, 1.0);
uniform float fresnel_hielo = 1.1;
uniform float fresnel_exp = 2.0;
uniform float rug_hielo = 0.12;
uniform float espec_hielo = 0.7;
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float tam_tex = 4.6;
uniform float ruido = 0.45;
uniform float dureza = 0.16;
uniform float variacion = 0.07;
uniform float brillo = 1.0;
// albedos (22/10, `Albedos3D`, PLAN_EOW_VISUAL §1.2): por familia (x = K, y = VALOR): c' = (media + (c - media) * K) * VALOR, con la media de la propia textura
// (mip alto). (1, 1) = como antes. Los pone `Albedos3D.aplicar_suelo` según el export `albedos_eow` de la maqueta.
uniform vec2 alb_hierba = vec2(1.0);
uniform vec2 alb_camino = vec2(1.0);
uniform vec2 alb_tierra = vec2(1.0);
uniform vec2 alb_piedra = vec2(1.0);
uniform float alb_mip = 12.0;
uniform float contraste = 2.5;                                          // rampa de luz: 1 = como el PBR · 4 = cel
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);      // lo que llega a la sombra: frío y pastel
// Rugosidad: relieve fino por mapa de normales (ruido generado si no hay textura). Con la rampa de luz, los bultos
// salen como moteado claro/oscuro, que es lo que hace que la arena y la tierra no parezcan una lámina lisa.
uniform sampler2D normal_suelo : hint_normal, filter_linear_mipmap, repeat_enable;
// 12/10 (11.10): suelo mojado por la simulación del agua (AguaSim3D.textura_mojado(): R8, 0-1, un texel por trocito). Filtrada, el borde del
// mojado se difumina. Oscurece y baja la rugosidad igual que el mojado de la casilla; sin simulación no hay textura y no hace nada.
uniform sampler2D mojado_fisico : hint_default_black, filter_linear, repeat_disable;
uniform vec4 mojado_rect = vec4(0.0, 0.0, 1.0, 1.0);   // x0, z0, ancho y alto (u) de la zona que cubre la textura
uniform float mojado_activo = 0.0;
uniform float rugosidad = 0.5;            // 0 liso · 1 muy rugoso (tecla B)
uniform float tam_rugosidad = 1.4;        // unidades de mundo por repetición del relieve
// Relieve PROPIO de la tierra: mapa de normales sacado de su textura (piedras en relieve, musgo y gravilla). Si no hay
// (usa_normal_tierra = 0) la tierra usa el relieve genérico de arriba, como siempre.
uniform sampler2D normal_tierra : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float usa_normal_tierra = 0.0;
vec3 muestra(sampler2D t, vec2 p, float mezcla) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 0.73 + vec2(0.37, 0.11);
	return mix(texture(t, p).rgb, texture(t, q).rgb, mezcla);
}
// albedos: la muestra de cada familia, con su compresión de contraste hacia la media de su textura y su ajuste de valor.
vec3 alb_corr(sampler2D t, vec3 c, vec2 kv) {
	vec3 med = textureLod(t, vec2(0.5), alb_mip).rgb;
	return (med + (c - med) * kv.x) * kv.y;
}
vec3 mh(vec2 p, float mezcla) { return alb_corr(t_hierba, muestra(t_hierba, p, mezcla), alb_hierba); }
vec3 mc(vec2 p, float mezcla) { return alb_corr(t_camino, muestra(t_camino, p, mezcla), alb_camino); }
vec3 mt(vec2 p, float mezcla) { return alb_corr(t_tierra, muestra(t_tierra, p, mezcla), alb_tierra); }
vec3 mp(vec2 p, float mezcla) { return alb_corr(t_piedra, muestra(t_piedra, p, mezcla), alb_piedra); }
// Una pareja de materiales. `k` selecciona los canales de `mapa` (+ el que lame, - el lamido): `d` = +1 dentro del que lame, -1 dentro del otro,
// 0 en la frontera. De d y de su gradiente sale la distancia con signo `sd` (u; + = dentro del que lame) a la frontera, igual que el borde de hierba.
// Devuelve el color de la pareja y, en `peso`, cuánto manda esa pareja en este punto (0 lejos de ella).
vec3 pareja(vec3 c_lame, vec3 c_otro, vec4 k, float lame, float rug, vec2 uvm, vec2 fino, out float peso, out float sd_o, out vec3 nrm_o) {
	float eb = 0.5 / lado;
	vec4 m0 = texture(mapa, uvm);
	float d = dot(m0, k);
	vec2 g = vec2(dot(texture(mapa, uvm + vec2(eb, 0.0)), k) - dot(texture(mapa, uvm - vec2(eb, 0.0)), k),
		dot(texture(mapa, uvm + vec2(0.0, eb)), k) - dot(texture(mapa, uvm - vec2(0.0, eb)), k));
	float gl = max(length(g), 0.3);
	float sd = d / gl * celda + (fino.x - 0.5) * 2.0 * rug;
	float wl = smoothstep(-max(lame, 0.08), 0.0, sd);                      // 1 en el que lame; decae hacia el otro en `lame` u
	vec3 col = mix(c_otro, c_lame, wl);
	col *= 1.0 - par_sombra * (1.0 - smoothstep(0.0, 0.5, sd)) * step(0.0, sd);   // el filo del que lame, algo más oscuro
	peso = smoothstep(0.5, 0.85, dot(m0, abs(k)));
	sd_o = sd;
	nrm_o = vec3(g / max(length(g), 0.0001), smoothstep(0.2, 0.5, length(g)));   // joints lámina: hacia el que lame (xy) y cuánto fiarse de ello (z)
	return col;
}
// joints lámina: una muestra del atlas. `dir` = dirección de la frontera (el eje de la tira sale perpendicular a ella), `sabajo` = u de mundo desde la
// frontera hacia el lado de las migas (+), `fila` = 0-4. Devuelve el alfa y en `rgb` el color con el contraste ya bajado (mezcla hacia la media local,
// nivel 3 de mipmap; el PNG no se toca).
// A lo largo de la tira, u = pm.x o pm.z según hacia dónde mire la frontera (y una mezcla suave en las diagonales): proyectar la posición sobre una
// dirección que gira con el suelo (u = pm · tangente) da un u que corre decenas de veces más deprisa de lo debido y estira el atlas en rayas.
// joints lámina: tono de una muestra del atlas hacia el de sus suelos. Las losas (poco saturadas, filas 1, 2 y 4) toman el color MEDIO de la textura
// de piedra del suelo × su luminancia relativa; la arena (filas 0, 1, 3) y la tierra (fila 2) se acercan parcialmente a la del camino / la tierra.
vec3 lamina_tono(float fila, vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float sat = (mx - min(c.r, min(c.g, c.b))) / max(mx, 0.01);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float losa = (fila == 1.0 || fila == 2.0 || fila == 4.0) ? 1.0 - smoothstep(0.34, 0.5, sat) : 0.0;
	vec3 pie = textureLod(t_piedra, vec2(0.5), 11.0).rgb * alb_piedra.y * clamp(lum / joints_piedra_ref, 0.3, 1.8);   // albedos: × el VALOR de la piedra
	float calido = (1.0 - losa) * smoothstep(0.03, 0.1, c.r - c.g);          // arena / tierra (la hierba tiene g > r)
	vec3 ref = fila == 2.0 ? vec3(0.35, 0.18, 0.10) : vec3(0.62, 0.38, 0.18);   // color medio lineal de la arena / tierra pintada
	vec3 des = fila == 2.0 ? textureLod(t_tierra, vec2(0.5), 11.0).rgb * alb_tierra.y : textureLod(t_camino, vec2(0.5), 11.0).rgb * alb_camino.y;   // albedos: × su VALOR
	vec3 mult = pow(des / ref, vec3(joints_afina));
	return mix(mix(c, c * mult, calido), pie, losa * joints_afina);
}
float lamina_tira(float fila, vec2 dir, float sabajo, vec2 pmxz, out vec3 rgb) {
	float pxu = 1024.0 / joints_escala;                                  // píxeles del atlas por u de mundo (a lo largo de la tira)
	float anch = fila < 0.5 ? joints_ancho.x : (fila < 1.5 ? joints_ancho.y : (fila < 2.5 ? joints_ancho.z : (fila < 3.5 ? joints_ancho.w : joints_ancho4)));
	float pyu = pxu / anch;                                              // y a lo ancho: estirado, la tira es `anch` veces más ancha
	float ypx = joints_linea * 128.0 + sabajo * pyu;
	float vv = (fila * 128.0 + clamp(ypx, 1.0, 127.0)) / 640.0;
	vec2 uva = vec2(pmxz.x / joints_escala, vv);
	vec2 uvb = vec2(pmxz.y / joints_escala + 0.37, vv);
	vec2 dsx = vec2(0.0, dFdx(sabajo) * pyu / 640.0);                    // derivadas explícitas (fuera de ramas): sin costuras de mipmap
	vec2 dsy = vec2(0.0, dFdy(sabajo) * pyu / 640.0);
	vec4 ta = textureGrad(t_joints, uva, vec2(dFdx(pmxz.x) / joints_escala, dsx.y), vec2(dFdy(pmxz.x) / joints_escala, dsy.y));
	vec4 tb = textureGrad(t_joints, uvb, vec2(dFdx(pmxz.y) / joints_escala, dsx.y), vec2(dFdy(pmxz.y) / joints_escala, dsy.y));
	float wa = smoothstep(0.35, 0.65, abs(dir.y));                       // tangente = (-dir.y, dir.x): si es sobre todo horizontal, u = x
	vec4 tx = mix(tb, ta, wa);
	vec3 media = mix(textureLod(t_joints, uvb, 3.0).rgb, textureLod(t_joints, uva, 3.0).rgb, wa);
	float ct = (fila == 1.0 || fila == 2.0 || fila == 4.0) ? joints_contraste : mix(1.0, joints_contraste, 0.35);   // las losas (filas 1, 2, 4) pierden todo el contraste pedido; la arena/tierra y la hierba pintada solo un poco: la media local de esas filas mezcla verde con arena y ensucia
	rgb = lamina_tono(fila, mix(media, tx.rgb, ct));
	return tx.a * step(1.0, ypx) * step(ypx, 127.0);
}// joints: la tira de migas de una pareja. `sd` = distancia con signo de `pareja` (+ dentro del que lame): las migas caen en el lado del otro suelo
// (sd < 0), densas en la frontera y cada vez más raras hasta `ancho` u; el ruido de `amp` u desplaza la frontera antes de cortar, y el grano son dos
// octavas del campo de ruido. `rim` (0-1) = el borde de cada miga, para oscurecerlo un poco.
float migas(float sd, vec4 p, vec2 c, out float rim) {
	float n = texture(campo, c / lado * 3.1 + vec2(0.17, 0.43)).g;
	float s2 = sd + (n - 0.5) * 2.0 * p.y;
	float dens = (1.0 - smoothstep(0.0, p.x, -s2)) * step(s2, 0.0);
	float g = smoothstep(0.2, 0.8, texture(campo, c / lado * p.w).r * 0.6 + texture(campo, c / lado * p.w * 2.6 + vec2(0.3, 0.7)).g * 0.4);
	float m = dens * p.z - g;
	rim = 1.0 - smoothstep(0.0, 0.12, m);
	return smoothstep(0.0, 0.035, m);
}
// joints lámina: distancia con signo (u; + = en el que lame) y dirección de la frontera de una pareja leídas del mapa SIN el ruido de borde: xy = hacia el que lame,
// z = fiabilidad (0 en esquinas y huecos sueltos), w = distancia.
vec4 sd_limpia(vec4 k, vec2 c) {
	float eb = 0.5 / lado;
	vec2 u0 = c / lado;
	float d = dot(texture(mapa, u0), k);
	vec2 g = vec2(dot(texture(mapa, u0 + vec2(eb, 0.0)), k) - dot(texture(mapa, u0 - vec2(eb, 0.0)), k),
		dot(texture(mapa, u0 + vec2(0.0, eb)), k) - dot(texture(mapa, u0 - vec2(0.0, eb)), k));
	float gl = length(g);
	return vec4(g / max(gl, 0.0001), smoothstep(0.2, 0.5, gl), d / max(gl, 0.3) * celda);
}
// joints lámina: cobertura de la tira de migas de una pareja (`fila` del atlas) y su color. Mezcla la procedural (`migas`) con el atlas según `joints_lamina`
// (`sd_limpia`: la distancia y la dirección de la frontera SIN el ruido de borde de `uvm` ni el desflecado fino de `pareja`, que varían tan deprisa que estiran el atlas en rayas) y la fiabilidad de la dirección (`nrm.z`: en esquinas y huecos sueltos cae a la procedural sola).
float joint_migas(float fila, vec4 p, float sdp, vec4 k, vec3 nrm, vec2 c, vec2 pmxz, vec3 base, vec3 tinte, out vec3 colo) {
	float rim;
	float mp = migas(sdp, p, c, rim);
	colo = base * tinte * (1.0 - 0.14 * rim);
	float L = joints_lamina * nrm.z;
	if (L > 0.0) {
		vec3 rgb;
		vec4 sl = sd_limpia(k, c);
		float a = lamina_tira(fila, sl.xy, -(mix(sl.w, sdp, joints_sigue) + (texture(campo, c / lado).a - 0.5) * 0.9 * (1.0 - joints_sigue)), pmxz, rgb);
		L = joints_lamina * sl.z;
		colo = mix(colo, rgb * tinte, L);
		mp = mix(mp, a, L);
	}
	return mp;
}
void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pm.xz += UV2;     // V3: el labio de BordePiedras3D «dobla» la textura de la tapa por la pared (sin rayas); la malla del bloque no trae UV2 y vale 0
	vec2 c = pm.xz / celda;
	vec4 r = texture(campo, c / lado);
	vec2 uvm = (c + (r.rg - 0.5) * 2.0 * ruido) / lado;
	vec4 w0 = texture(mapa, uvm);
	vec4 w = smoothstep(vec4(0.5 - dureza), vec4(0.5 + dureza), w0);
	float s = w.r + w.g + w.b + w.a;
	if (s < 0.05) {
		w = w0;
		s = w.r + w.g + w.b + w.a;
	}
	w /= max(s, 0.0001);
	vec2 t = pm.xz / tam_tex;
	float m = smoothstep(0.3, 0.7, r.b);
	vec3 col = mh(t, m) * w.r + mc(t, m) * w.g
		+ mt(t, m) * w.b + mp(t, m) * w.a;
	float apaga = 1.0 - smoothstep(0.05, 0.4, texture(mapa_fuera, uvm).r);   // joints: junto a agua, cauce o huecos no hay tira
	if (par_fuerza > 0.0) {
		vec3 cg = mc(t, m);
		vec3 cb = mt(t, m);
		vec3 ca = mp(t, m);
		vec2 fino = texture(campo, c / lado * 3.7).rg;                           // ruido fino del filo (campo se repite)
		float pw;
		float sdp;
		vec3 nrmj;
		vec3 cmj;
		col = mix(col, pareja(cg, cb, vec4(0.0, 1.0, -1.0, 0.0), par_lame.x, par_ruido.x, uvm, fino, pw, sdp, nrmj), pw * par_fuerza);
		if (joints_fuerza > 0.0 && pw > 0.0) {      // joints camino→tierra: sobre la mezcla de la pareja, las migas del camino
			float mk = joint_migas(0.0, joint_ct, sdp, vec4(0.0, 1.0, -1.0, 0.0), nrmj, c, pm.xz, cg, joint_tinte_ct, cmj) * pw * apaga * joints_fuerza;
			col = mix(col, cmj, mk);
		}
		col = mix(col, pareja(cg, ca, vec4(0.0, 1.0, 0.0, -1.0), par_lame.y, par_ruido.y, uvm, fino, pw, sdp, nrmj), pw * par_fuerza);
		if (joints_fuerza > 0.0 && pw > 0.0) {      // camino→piedra
			float mk = joint_migas(1.0, joint_cp, sdp, vec4(0.0, 1.0, 0.0, -1.0), nrmj, c, pm.xz, cg, joint_tinte_cp, cmj) * pw * apaga * joints_fuerza;
			col = mix(col, cmj, mk);
		}
		col = mix(col, pareja(cb, ca, vec4(0.0, 0.0, 1.0, -1.0), par_lame.z, par_ruido.z, uvm, fino, pw, sdp, nrmj), pw * par_fuerza);
		if (joints_fuerza > 0.0 && pw > 0.0) {      // tierra→piedra
			float mk = joint_migas(2.0, joint_tp, sdp, vec4(0.0, 0.0, 1.0, -1.0), nrmj, c, pm.xz, cb, joint_tinte_tp, cmj) * pw * apaga * joints_fuerza;
			col = mix(col, cmj, mk);
		}
	}
	// BORDE DE HIERBA. `mapa` guarda un tipo por casilla y, filtrado, su canal R (hierba) sube de 0 a 1 en una casilla: ahí está la frontera.
	// De él salen la dirección (el gradiente) y la distancia con signo `sb` (u de mundo; + = hacia el otro suelo) a la línea R = 0,5. uvm ya
	// lleva el ruido de borde, así la franja sigue la frontera orgánica del suelo y no la recta de la rejilla.
	if (borde_fuerza > 0.0) {
		float eb = 0.5 / lado;
		vec2 gb = vec2(texture(mapa, uvm + vec2(eb, 0.0)).r - texture(mapa, uvm - vec2(eb, 0.0)).r,
			texture(mapa, uvm + vec2(0.0, eb)).r - texture(mapa, uvm - vec2(0.0, eb)).r);
		float gl = length(gb);                                                // ~1 por casilla en una frontera recta; 0 lejos de ella
		if (gl > 0.2) {
			float sb = (0.5 - texture(mapa, uvm).r) / gl * celda;
			vec2 nb = -gb / gl;                                               // hacia el otro suelo
			float fb = smoothstep(0.2, 0.5, gl);                              // en esquinas y huecos sueltos el gradiente es poco fiable: se apaga
			// La hierba pegada a la frontera, más oscura (solo en su lado).
			float oscuro = (1.0 - smoothstep(0.0, 1.2 * borde_ancho, -sb)) * step(sb, 0.0);
			col *= mix(1.0, borde_oscuro, oscuro * w.r * fb * borde_fuerza);
			// La hierba invade la tierra: matas sueltas (manchas de ruido) en la tierra junto a la frontera, cada vez más raras.
			if (invade_hierba > 0.0 || joints_fuerza > 0.0) {
				float mata = smoothstep(0.58, 0.66, texture(campo, c / lado * 5.3).b + (texture(campo, c / lado * 9.1).g - 0.5) * 0.35);
				float cerca = (1.0 - smoothstep(0.1, 1.5 * borde_ancho + 0.6, sb)) * step(0.0, sb);
				col = mix(col, mh(t, m) * borde_tinte, mata * cerca * w.b * fb * invade_hierba * borde_fuerza);
				// joints (hierba→camino, hierba→piedra): matas sueltas sobre el camino y entre las losas, con su propio alcance.
				if (joints_fuerza > 0.0) {
					float cj = (1.0 - smoothstep(0.1, max(dot(w.gba, joint_matas_ancho), 0.11), sb)) * step(0.0, sb);
					float fj = (w.g * joint_matas.x + w.a * joint_matas.z) * apaga;
					col = mix(col, mh(t, m) * borde_tinte * 0.96, mata * cj * fj * fb * joints_fuerza * borde_fuerza * (1.0 - joints_lamina));
				}
			}
			float cubre = 0.0;     // cuánto de este píxel lo cubre la lámina: las hojas de hierba_borde no la tapan donde hay lámina
			if (joints_lamina > 0.0 && joints_fuerza > 0.0) {      // joints lámina: hierba→camino (fila 3) y hierba→piedra (fila 4) del atlas: la hierba densa en el lado de arriba, las matas sueltas sobre el vecino
				vec4 ot = texture(mapa, uvm + nb * (0.75 / lado));          // qué hay al otro lado de la frontera: camino (G) o piedra (A); tierra no tiene fila
				vec3 rgbl;
				float al = lamina_tira(ot.a > ot.g ? 4.0 : 3.0, nb, sb + (texture(campo, c / lado).a - 0.5) * 0.5, pm.xz, rgbl);
				cubre = al * clamp(ot.g + ot.a, 0.0, 1.0) * apaga * fb * joints_fuerza * joints_lamina;
				col = mix(col, rgbl * mix(vec3(1.0), borde_tinte, 0.5), cubre);       // el tinte de las hojas, a medias: la hierba del atlas ya es del tono bueno
			}
			// La franja: v = 0 en su lado de hierba (65 % del alto) y v = 1 en el lado deshilachado (35 %), que cae sobre el otro suelo.
			float vb = (sb + 0.65 * borde_ancho) / borde_ancho;
			if (vb > 0.0 && vb < 1.0) {
				float ub = dot(pm.xz, vec2(-nb.y, nb.x)) / (borde_ancho * 5.15);   // 5,15 = 885 / 172, para no estirar las hojas
				vec4 hb = texture(t_borde, vec2(ub, vb));
				col = mix(col, hb.rgb * borde_tinte, hb.a * fb * borde_fuerza * (1.0 - 0.85 * cubre));
			}

		}
	}
	// Estado por celda (ESTADOS_SUELO.md §4). uvm ya lleva el ruido de borde: la ceniza y el charco quedan orgánicos.
	vec4 e = texture(estado_juego, uvm);
	float q;
	float mo;
	float he;
	float espec = 0.0;
	float rug = 1.0;
	if (estado_eow > 0.5) {
		// V4. El estado oficial por canal (R quemada · G mojada · B helada) y el contorno cortado por ruido, no por casilla.
		vec3 est = e.rgb;
		float nq = texture(campo, c / lado * 2.3).r * 0.55 + texture(campo, c / lado * 5.7 + vec2(0.37, 0.11)).g * 0.45;
		float nm = texture(campo, c / lado * 2.9 + vec2(0.52, 0.23)).g * 0.55 + texture(campo, c / lado * 6.3 + vec2(0.11, 0.71)).r * 0.45;
		float nh = texture(campo, c / lado * 3.3 + vec2(0.81, 0.47)).r * 0.55 + texture(campo, c / lado * 7.1 + vec2(0.29, 0.93)).g * 0.45;
		// QUEMADO: carbón con manchas de ceniza gris y un filo chamuscado hacia fuera.
		float fq = est.r + (nq - 0.5) * estado_ruido;
		q = smoothstep(0.5 - estado_filo, 0.5 + estado_filo, fq) * mix(quemado_sin_hierba, 1.0, w.r) * fuerza_quemado;
		float dentro = smoothstep(0.5 + estado_filo, 0.5 + estado_filo + 0.22, fq);   // 0 en el filo, 1 dentro
		float mancha = smoothstep(0.46, 0.64, texture(campo, c / lado * 9.0).b * 0.5 + texture(campo, c / lado * 15.0 + vec2(0.2, 0.6)).g * 0.5);
		vec3 negro = col * carbon_mult;
		vec3 gris = color_ceniza_gris * (0.8 + 0.4 * r.a);
		vec3 quemado = mix(col * chamusco_mult, mix(negro, gris, mancha * ceniza_gris), dentro);
		col = mix(col, quemado, q);
		// MOJADO: oscuro y azulado; el filo del charco algo más oscuro.
		float fm = est.g + (nm - 0.5) * estado_ruido;
		mo = smoothstep(0.5 - estado_filo, 0.5 + estado_filo, fm);
		float filo_m = mo * (1.0 - smoothstep(0.5 + estado_filo, 0.5 + estado_filo + 0.2, fm));
		if (mojado_activo > 0.5) {
			vec2 uvf = (pm.xz - mojado_rect.xy) / mojado_rect.zw;
			if (uvf.x > 0.0 && uvf.y > 0.0 && uvf.x < 1.0 && uvf.y < 1.0) {
				mo = max(mo, smoothstep(0.05, 0.6, texture(mojado_fisico, uvf).r));   // 11.10: el suelo que moja el agua física
			}
		}
		col = mix(col, col * tinte_mojado, mo);
		col *= 1.0 - filo_mojado * filo_m;
		// HELADO: escarcha por encima de todo, con el azul de fresnel en lo que se ve de refilón.
		float fh = est.b + (nh - 0.5) * estado_ruido;
		he = smoothstep(0.5 - estado_filo, 0.5 + estado_filo, fh);
		col = mix(col, mix(col * vec3(0.8, 0.95, 1.05), color_escarcha * (0.9 + 0.2 * r.a), 0.7), he);
		float refilon = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_exp);
		col += color_fresnel_hielo * refilon * fresnel_hielo * he;
		rug = mix(mix(1.0, rug_mojado, mo), rug_hielo, he);
		espec = max(mo * espec_mojado, he * espec_hielo);
	} else {
		q = smoothstep(0.5 - dureza, 0.5 + dureza, e.r) * w.r;               // quemado: solo donde hay hierba
		col = mix(col, color_ceniza * (0.8 + 0.4 * r.a), q * fuerza_ceniza);
		mo = smoothstep(0.35, 0.65, e.g);                                    // mojado: el tinte del 2D (0,62 0,66 0,78)
		if (mojado_activo > 0.5) {
			vec2 uvf = (pm.xz - mojado_rect.xy) / mojado_rect.zw;
			if (uvf.x > 0.0 && uvf.y > 0.0 && uvf.x < 1.0 && uvf.y < 1.0) {
				mo = max(mo, smoothstep(0.05, 0.6, texture(mojado_fisico, uvf).r));   // 11.10: el suelo que moja el agua física
			}
		}
		col = mix(col, col * vec3(0.62, 0.66, 0.78), mo);
		he = smoothstep(0.4, 0.6, e.b);                                      // helado: escarcha por encima de todo
		col = mix(col, mix(col * vec3(0.8, 0.95, 1.05), color_escarcha * (0.9 + 0.2 * r.a), 0.7), he);
		rug = mix(1.0, 0.35, mo);
	}
	ALBEDO = col * brillo * (1.0 + (r.a - 0.5) * 2.0 * variacion);
	ROUGHNESS = rug;
	SPECULAR = espec;
	// Relieve: dos escalas del mismo mapa (gruesa y fina) para que no se vea la repetición; la escarcha lo alisa,
	// la hierba lo suaviza (sus briznas ya dan textura) y la piedra lo marca más.
	vec2 tr = pm.xz / tam_rugosidad;
	vec3 n1 = texture(normal_suelo, tr).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_suelo, tr * 3.1 + vec2(0.5, 0.25)).rgb * 2.0 - 1.0;
	vec3 nr = normalize(vec3(n1.xy * 0.65 + n2.xy * 0.35, 1.0));
	if (usa_normal_tierra > 0.5) {
		// Mismas dos muestras que el color (la segunda girada y a otra escala): la normal gira con ella.
		mat2 giro = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		vec2 g1 = texture(normal_tierra, t).xy * 2.0 - 1.0;
		vec2 g2 = transpose(giro) * (texture(normal_tierra, giro * t * 0.73 + vec2(0.37, 0.11)).xy * 2.0 - 1.0);
		vec2 gt = mix(g1, g2, m);
		nr = normalize(vec3(mix(nr.xy, gt + nr.xy * 0.3, w.b), 1.0));
	}
	float fuerza = rugosidad * (0.5 + 0.5 * (w.g + w.b) + 0.8 * w.a) * (1.0 - he);
	NORMAL_MAP = nr * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = fuerza * 2.2;
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Rampa suave en vez de coseno: tapa clara, sombra fría. ATTENUATION lleva la sombra proyectada.
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	// El suelo mojado brilla un poco (el seco no tiene especular).
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 40.0) * (1.0 - ROUGHNESS) * LIGHT_COLOR * ATTENUATION;
}
"""

## Agua estilizada (docs/IMPLEMENTAR_TECNICAS.md Paso 2): claro en la orilla y hondo en el centro por la
## DISTANCIA A LA ORILLA de cada celda (no hay lecho bajo el agua: el depth buffer daría una profundidad
## constante), espuma rota junto a tierra, ondas con dos normales que se cruzan y hielo cuando B (helado) sube.
const CODIGO_AGUA: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D orilla : filter_linear, repeat_disable;                       // distancia a tierra / 4 (en casillas)
uniform sampler2D campo : filter_linear, repeat_enable;                         // el mismo ruido del suelo
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;   // B = helado
uniform sampler2D normal_agua : filter_linear_mipmap, repeat_enable;
uniform sampler2D t_agua : source_color, filter_linear_mipmap, repeat_enable;   // water_arriba.png
uniform vec3 color_somero : source_color = vec3(0.52, 0.84, 0.86);
uniform vec3 color_hondo : source_color = vec3(0.16, 0.44, 0.66);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 color_hielo : source_color = vec3(0.82, 0.93, 0.97);
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform float tam_tex = 4.6;
uniform float ruido = 0.45;
uniform float fuerza_normal = 0.5;      // 6.16: más ondas (antes 0,35)
uniform float ancho_espuma = 0.16;
uniform float brillo = 1.0;
uniform float contraste = 1.5;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);
// 13/10 · AGUA ESTILIZADA (el aspecto de paddy-exe/Godot-3D-Stylized-Water, MIT, rehecho sin profundidad de escena):
// facetas planas que se inclinan con las olas (low-poly), dos tonos en bandas por la distancia a la orilla, línea de espuma
// nítida junto a tierra y manchas de espuma de dos ruidos que corren en sentidos opuestos. 0 = el agua pintada de antes.
uniform float estilizada : hint_range(0.0, 1.0) = 1.0;
uniform float faceta = 0.75;                // lado de los triángulos de agua (u)
uniform float altura_ola = 0.32;            // cuánto se inclinan
uniform vec3 color_somero_est : source_color = vec3(0.44, 0.80, 0.91);
uniform vec3 color_hondo_est : source_color = vec3(0.20, 0.52, 0.80);
uniform float bandas = 3.0;                 // escalones entre somero y hondo
uniform float espuma_manchas = 0.5;         // umbral de las manchas (más alto = menos manchas)
uniform float contraste_faceta = 0.2;       // cuánto se oscurecen las facetas que no miran a la luz (low-poly)
uniform float transicion_orilla = 0.4;      // 10/10: casillas que tarda la espuma de la orilla en fundirse con el agua (antes un corte seco)

float ola_est(vec2 p, float t) {
	return sin(p.x * 1.9 + t * 1.1) * 0.5 + sin(p.y * 2.3 - t * 0.9) * 0.35 + sin((p.x + p.y) * 1.3 + t * 0.7) * 0.25;
}

// Normal plana del triángulo de la rejilla en el que cae `p`: la altura de la ola en sus tres esquinas. La rejilla va girada
// y sesgada (triángulos casi equiláteros) para que no se lean cuadros alineados con las casillas.
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

void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 c = pm.xz / celda;
	vec4 r = texture(campo, c / lado);
	vec2 uvm = (c + (r.rg - 0.5) * 2.0 * ruido) / lado;      // misma deformación que el suelo
	float dist = max(texture(orilla, uvm).r * 4.0 - 0.5, 0.0);   // casillas desde el borde de la tierra
	vec2 uv = pm.xz / tam_tex;
	// Dos muestras de la normal con rumbos y velocidades distintas: rompe la repetición.
	vec2 na = texture(normal_agua, uv + TIME * vec2(0.034, 0.019)).rg * 2.0 - 1.0;
	vec2 nb = texture(normal_agua, uv * 1.7 - TIME * vec2(0.022, 0.028)).rg * 2.0 - 1.0;
	vec2 n = (na + nb) * fuerza_normal;
	float hielo = smoothstep(0.4, 0.6, texture(estado, uvm).b);
	n *= 1.0 - hielo;                                         // el hielo está quieto
	// Claro en la orilla, hondo en el centro.
	vec3 col = mix(color_somero, color_hondo, 1.0 - exp(-dist * 0.9));
	// La pintura actual como detalle, desplazada por la onda para que "ondee".
	col *= mix(vec3(1.0), texture(t_agua, uv + n * 0.08).rgb, 0.45);
	// Espuma: banda junto a la orilla, rota por el ruido y por la onda, que avanza y retrocede.
	float borde = dist + (r.b - 0.5) * 0.15 + n.x * 0.1 + sin(TIME * 0.8 + r.g * 6.28) * 0.03;
	float espuma = 1.0 - smoothstep(0.0, ancho_espuma, borde);
	espuma *= 0.55 + 0.45 * step(0.4, fract((uv.x + uv.y) * 2.5 + TIME * 0.3 + r.r));   // a trozos
	col = mix(col, color_espuma, espuma * 0.9 * (1.0 - hielo));
	// Hielo: pálido, con la textura del agua casi apagada.
	col = mix(col, color_hielo * (0.9 + 0.2 * r.a), hielo);
	vec3 nm = vec3(n.x, 1.0, n.y);
	if (estilizada > 0.5) {
		nm = normalize(mix(normal_faceta(pm.xz, TIME), vec3(0.0, 1.0, 0.0), hielo));
		float hondo = 1.0 - exp(-dist * 0.9);
		hondo = floor(hondo * bandas + 0.5) / bandas;                     // dos tonos (y un intermedio) en bandas
		vec3 ce = mix(color_somero_est, color_hondo_est, hondo);
		// Sombreado propio de cada faceta (como el low-poly del GIF): la que mira a la luz, clara; la que no, oscura.
		float lf = clamp(dot(nm, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
		ce *= 1.0 - contraste_faceta + contraste_faceta * 1.3 * smoothstep(0.7, 1.0, lf);
		float s1 = texture(campo, uv * 0.35 + TIME * vec2(0.012, 0.007)).r;
		float s2 = texture(campo, uv * 0.5 - TIME * vec2(0.008, 0.011) + 0.37).g;
		float suma = s1 + s2 - 1.0;
		float manchas = step(espuma_manchas, suma) + step(0.22, suma) * (1.0 - step(0.3, suma)) * 0.12;
		float borde_e = dist + (r.b - 0.5) * 0.15 + sin(TIME * 0.8 + r.g * 6.28) * 0.03;
		float linea = 1.0 - smoothstep(0.0, transicion_orilla, borde_e);    // espuma que se funde con el agua (antes step: corte seco)
		linea *= linea;                                                     // cae rápido al principio y se alarga al final
		ce = mix(ce, color_espuma, clamp(max(linea, manchas * 0.85), 0.0, 1.0) * (1.0 - hielo));
		col = mix(ce, color_hielo * (0.9 + 0.2 * r.a), hielo);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.88, 0.94, 1.0), fres * 0.25 * (1.0 - hielo));
	ALBEDO = col * brillo;
	ROUGHNESS = mix(0.18, 0.6, hielo);
	SPECULAR = 0.5;
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	// Brillo del sol sobre las ondas (Blinn-Phong: al definir light() se pierde el especular del PBR).
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), mix(24.0, 90.0, 1.0 - ROUGHNESS)) * 0.5 * LIGHT_COLOR * ATTENUATION;
}
"""

## Bloque empujable (Paso 5): tapa y lado distintos por la normal en el mundo y grietas que aparecen con `danio`.
const CODIGO_BLOQUE: String = """
shader_type spatial;
uniform sampler2D t_arriba : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_lado : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grietas : filter_linear_mipmap, repeat_enable;   // R leves · G medias · B rotura
uniform float danio = 0.0;                                           // 0 intacto ... 1 a punto de romperse
uniform vec3 color_grieta : source_color = vec3(0.25, 0.18, 0.12);
uniform float tam_tex = 2.3;
uniform float brillo = 1.0;
void fragment() {
	vec3 pm = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool arriba = abs(nm.y) > 0.5;
	vec2 uv = arriba ? pm.xz / tam_tex : (abs(nm.x) > 0.5 ? pm.zy : pm.xy) / tam_tex;
	vec3 col = arriba ? texture(t_arriba, uv).rgb : texture(t_lado, uv).rgb;
	vec3 g = texture(t_grietas, uv).rgb;
	float grieta = max(max(g.r * step(0.2, danio), g.g * step(0.5, danio)), g.b * step(0.8, danio));
	ALBEDO = mix(col, color_grieta, grieta) * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


## Decorado en lotes (MultiMesh por pieza). El prerender del Test 2D lo apaga: necesita cada pieza como nodo.
@export var decorado_por_lotes: bool = true
## Círculo de transparencia alrededor del jugador: lo que queda entre la cámara y él (árboles, setos, el puesto) se
## vuelve translúcido en ese círculo. Solo afecta al decorado en lotes y a los objetos reactivos (Ocluso3D).
@export var transparencia_jugador: bool = true
@export var radio_transparencia: float = 1.9
## Bloque 1 EoW: cuánto se mecen árboles y arbustos (`VIENTO_DECORADO`; 0 = quietos). Necesita `transparencia_jugador` (es el mismo material).
@export var viento_decorado: float = 1.0
## La Cueva (23/10): «bosque» (de serie: árboles en las paredes, hierba) o «cueva» (paredes de roca del kit de cueva según sus vecinas, suelo de
## roca y basalto, estalagmitas). Ver `_pared_cueva`.
@export var estilo: String = "bosque"
## Bloque 4 EoW: escala del render 3D (1 = nativa). Medido en una Intel UHD 620 (Bosque): 0,75 da ≈ +20 % de FPS; el HUD sigue nítido.
@export_range(0.5, 1.0, 0.05) var escala_render: float = 1.0
## Bloque 4 EoW: la sombra de árboles y pinos la proyecta una copia reducida (`SOMBRA_REDUCIDA`). Desmarcar = la malla entera, como antes.
@export var sombra_reducida: bool = true
## Bloque 3 EoW: bruma baja en el fondo de los cauces secos hondos (NieblaFoso3D). Desmarcar = sin niebla.
@export var niebla_fosos: bool = true
## Quita la parte delantera del toldo del puesto de mercado (desde la cámara tapaba al tendero).
@export var recortar_toldo: bool = true
## Hierba de todo el mapa a la vez (el prerender 2D la necesita entera). Si no, solo alrededor de la chibi.
@export var hierba_completa: bool = false
## Niveles editables: la hierba (las briznas 3D y lo que prende con el fuego) solo crece en las casillas ZONA_V (la verde
## fuerte de la paleta). Así un fuego no incendia todo el nivel: el suelo normal (SUELO) no arde. Sin marcar, vuelve lo de
## antes: hierba en todo el suelo que pinta hierba. No afecta al Test 2 (su aldea conserva sus letras).
@export var hierba_solo_en_zona_v: bool = true
## Al empezar, tapa la pantalla un instante y lanza los seis elementos para compilar sus shaders (el prerender 2D lo apaga).
@export var precalentar_al_inicio: bool = true
## 9/10: fuego luminoso aditivo (VfxKit3D) en vez del facetado. Mientras Pablo no lo apruebe sale el viejo.
@export var fuego_nuevo: bool = false
## Tamaño de los efectos con el kit nuevo (`Vfx3D.escala`; en el Lab es la tecla X). Pablo lo fijó en 0,6 el 10/10.
const ESCALA_VFX_NUEVO: float = 0.6
## Objetos que reaccionan a los hechizos (Reactivo3D, tarea 4.7: seto, tronco, telaraña, tótems, fogatas, antorchas, puente
## y placa). El prerender del Test 2D los apaga: allí son decorado.
@export var objetos_reactivos: bool = true
## Qué nivel monta esta escena: "test2" (el laboratorio de elementos, 40×40) o "jugabilidad" (el Test de jugabilidad
## de siempre, 23×23, con sus cuatro tareas: ver jugabilidad_3d.gd). Lo elige PruebaJugabilidad3D.tscn.
@export var nivel: String = "test2"
## 7.14: qué REGLAS lleva el nivel, aparte de cuál es. "" = automático (las del Test de jugabilidad solo si
## `nivel == "jugabilidad"`), "ninguna" o "jugabilidad" (tareas, puerta final, botín, NPC que hablan y guardados, leídos de
## los marcadores del nivel). Así un nivel nuevo (Nivel_Bosque.tscn) tiene tareas sin tocar código.
@export var reglas: String = ""
## 6.10 camino A: si existe `poc_25d/niveles/<nivel>.tscn` (se crea con F9, «hornear»), el decorado y lo que bloquea salen de
## sus nodos Pieza3D y no de las letras del mapa (las letras siguen dando el suelo, los personajes y los objetos reactivos).
## Se puede editar ese .tscn en Godot: mover, girar, escalar, borrar y añadir piezas. Poner a false para volver a las letras.
@export var usar_escena: bool = true
## 9.7 · VITRINA de los VFX del Bosque: sin reglas (Bosque3D) que los gobiernen, deja puestos a la vista las runas de la puerta
## encendidas, el cauce lleno, el agua conectada electrificada y el surtidor echando chorro cada pocos segundos. Con reglas
## no hace nada: mandan ellas (encender_runa, llenar_cauce…). Solo vale en un nivel con esas piezas.
@export var vitrina_vfx: bool = false
## 13/10: agua del río con el aspecto low-poly estilizado (facetas, dos tonos, espuma nítida). Desmarcar = el agua pintada de antes.
@export var agua_estilizada: bool = true
## 12/10 (Fase 11.7): el agua se dibuja desde la SIMULACIÓN (AguaRender3D lee Lanzador3D.agua) en vez de plano + tiras del canal. Por
## defecto apagado hasta que Pablo lo apruebe. Encendido: las casillas de agua llevan solo su lecho (Lanzador3D.LECHO_AGUA bajo la superficie
## de antes, como en la simulación) y el canal de Canal3D no se monta. Sin simulación (Lanzador3D.agua_sim) no se dibuja agua.
@export var agua_fisica: bool = false
## 23/10 (Cueva): el agua del mapa corre hacia el sur como un río (`_flujo_rio`). Desmarcar donde el agua es una charca quieta: si no,
## las franjas de la corriente se dibujan sobre agua parada (en la charca de la Cueva se veían como goteras blancas).
@export var agua_corre: bool = true
## 24/10 (Bosque 01 v01): las `A` del mapa son goblins ARQUEROS de verdad (flechas) aunque el nivel no lleve las reglas por nombre `bosque`. Sin esto, un nivel con sus reglas como nodo hijo
## (Bosque 01) ponía en cada `A` un espadachín cuerpo a cuerpo.
@export var arqueros: bool = false
## 12/10 (11.16): el kit de hechizos de esta escena. El Lanzador lo lee (`mundo.get("kit")`, 11.15) y, si no está vacío, lo usa en lugar del
## nombre del nivel: «pruebas» = todos los hechizos y glifos (con hielo) para iterar sin tocar el kit del nivel de verdad.
@export var kit: String = ""
## 16/10 (Fase 14.2, a): DIORAMA. Profundidad de campo «tilt-shift» como en Echoes of Wisdom: nítido donde está la protagonista y cada vez más borroso
## hacia el fondo, lo que da escala de maqueta y esconde el horizonte y el borde del mapa. Es `CameraAttributesPractical` (desenfoque lejano), así
## que SOLO existe en Forward+ y Mobile: en Compatibilidad no hace nada (se apaga solo). Se apaga a mano con F7 o desmarcando `diorama`.
@export var diorama: bool = true
## albedos (22/10, `Albedos3D`, PLAN_EOW_VISUAL §1.2 + pendiente OSCURECER_SUELO de ARTE.md §10): iguala el contraste y el valor de los albedos de la hierba, el suelo y las piezas
## del decorado en los SHADERS (compresión hacia la media de cada textura + ajuste de valor por familia; constantes en `Albedos3D`). false = el aspecto de antes.
@export var albedos_eow: bool = true
## Cuánto desenfoca: 0 = nada, 1 = el máximo razonable (`dof_blur_amount` 0,12); 0,5 es sutil.
@export_range(0.0, 1.0) var diorama_fuerza: float = 0.5
## Qué parte de media pantalla (hacia el fondo) queda nítida antes de empezar a desenfocar. 0,6 = el 60 %.
@export_range(0.2, 1.0) var diorama_nitidez: float = 0.6
## 16/10 (Fase 14.2, b): falda biselada al pie de cada escalón y borde de agua + anillo de cantos rodados en el labio (BordePiedras3D).
@export var bordes_blandos: bool = true
## 21/10 (V3 de PLAN_EOW_VISUAL): el LABIO redondeado de la arista de arriba de los bordes (orillas del agua, escalones de `Terreno3D.alturas`, borde del
## mapa y huecos del mapa): una tira de `BORDE_LABIO_ANCHO` u por encima del bloque (ver BordePiedras3D). Desmarcar = las aristas vivas de antes.
@export var bisel_suelo: bool = true
## labio cauce (22/10): el mismo labio + falda + cantos en el borde del CAUCE SECO (casillas `c`): el suelo ya no termina plano y de arista viva contra el bloque hundido.
## Visual puro (sin colisión). Desmarcar (o `bisel_suelo = false`) = el escalón recto de antes. Cambiarlo en vivo: `reconstruir_bordes_cauce()`.
@export var bisel_cauce: bool = true
## cauce profundo (22/10, Pablo: «piedrecitas blancas que vienen del fondo» y «no veo sensación de profundidad»): el lecho seco sigue 0,1 u bajo el suelo (se PISA a ras: `Terreno3D.y_pies` de una `c`
## cerrada es `alto_suelo`, así que un lecho más hondo dejaría al jugador flotando), pero se lee más hondo: oclusión falsa hacia las paredes, pared y falda más oscuras, labio con sombra y grava
## pequeña de tonos del lecho (los guijarros de antes salían casi blancos y como pastillas). Desmarcar = el cauce de antes, tal cual. En vivo: se aplica solo (`aplicar_cauce_profundo`).
@export var cauce_profundo: bool = true:
	set(v):
		cauce_profundo = v
		if is_node_ready():
			aplicar_cauce_profundo()
## cauce hondo (22/10, Pablo: «que el jugador se caiga, y que tenga un desnivel; si no, no habrá sensación de profundidad»): el cauce seco es un FOSO de `Terreno3D.PROF_CAUCE` (0,94 u)
## con el fondo donde ya lo ponía la simulación de agua. Se anda por el fondo, se entra cayendo y se sale trepando; el agua lo llena desde el fondo real. Desmarcar = el cauce de antes
## (lecho a 0,1 u bajo el suelo, se pisa a ras). En vivo: se aplica solo. Ver `Terreno3D.cauce_hondo`.
@export var cauce_hondo: bool = true:
	set(v):
		cauce_hondo = v
		Terreno3D.fijar_cauce_hondo(v)
		if is_node_ready():
			aplicar_cauce_profundo()
## 21/10 (V4 de PLAN_EOW_VISUAL): el ESTADO del suelo (mojado, quemado, helado) leído del estado del juego (`Mundo3D.textura_estados()`), con el borde
## irregular por ruido (sin casillas), carbón y ceniza al quemarse, charco que refleja y escarcha con fresnel. Desmarcar = el shader de antes
## (bordes de casilla, quemado sin pintar, mojado y hielo sin reflejo; B2: lee el mismo estado oficial, solo cambia cómo se pinta).
@export var estado_suelo_eow: bool = true
## joints (PLAN_EOW_VISUAL §1.3, 22/10): TIRAS DE TRANSICIÓN entre suelos distintos, con el filo cortado por ruido (ver `JOINTS_PARES` y el bloque «joints» del shader
## del suelo). Desmarcar = el suelo de antes (sin migas ni matas nuevas). Se pone antes de añadir la maqueta al árbol.
@export var joints_suelo: bool = true
## joints lámina (22/10): las cinco tiras (camino→tierra, camino→piedra, tierra→piedra, hierba→camino, hierba→piedra) salen del ATLAS pintado
## `joints_atlas.png`. Desmarcar = la tira procedural de antes. Si falta el archivo del atlas también cae a la procedural. Antes de añadir la maqueta al árbol.
@export var joints_lamina: bool = true
const JOINTS_ATLAS: String = "res://arte/suelo_meshy/joints_atlas.png"
const JOINTS_CONTRASTE: float = 0.85    ## CONSERVACIÓN del contraste: 1 = atlas como está pintado (máximo contraste); 0 = todo a la media local (liso). Antes 0,55; más alto = losas y migas con más presencia
const JOINTS_ESCALA: float = 5.5        ## u de mundo que mide el atlas a lo ancho (1024 px); la fila (128 px) mide 1/8 de eso (0,69 u) × el ancho de la pareja, y una losa del atlas ~0,55 u
const JOINTS_LINEA: float = 0.40        ## fracción de la fila donde cae la frontera de los dos suelos
const JOINTS_AFINA: float = 0.6         ## 0-1: cuánto se tiñen las losas del atlas al color medio del suelo de piedra (y la arena/tierra hacia su suelo)
const JOINTS_PIEDRA_REF: float = 0.30   ## luminancia lineal media de las losas pintadas (para teñir conservando su luminancia relativa)
const BORDE_LABIO_ANCHO: float = 0.2         ## u: lo que se adentra el labio en la cara de arriba y baja por la pared (0,15–0,25)
const BORDE_LABIO_SOBRESALE: float = 0.05    ## u: lo que asoma sobre la arista viva (la tira va por fuera del bloque y la tapa)
var _camara_dof: CameraAttributesPractical = null
## 21/10 (F1–F3 de PLAN_EOW, entrada 233): luz por zona, banda tilt-shift y sonda de reflejos. Los tres se prueban con teclas (AvPág / RePág / Inicio).
## `zona_luz` es una fila de `LuzZona3D.ZONAS` (sol y ambiente de dos colores). «bosque» es EXACTAMENTE la luz de antes: no cambia el aspecto de nada.
@export var zona_luz: String = "bosque"
## Banda de tilt-shift (nítido en el centro, borroso arriba y abajo). V1 (21/10): ENCENDIDA de serie (`Posproceso3D.TILT_SHIFT_DEFECTO`); RePág la apaga para comparar.
@export var tilt_shift: bool = Posproceso3D.TILT_SHIFT_DEFECTO
## Sonda de reflejos de la sala (el agua y el hielo reflejan lo que hay alrededor). V1 (21/10): ENCENDIDA de serie (`Posproceso3D.SONDA_DEFECTO`); Inicio la quita / la vuelve a hornear.
@export var sonda_reflejos: bool = Posproceso3D.SONDA_DEFECTO
## agua EoW (22/10): UNA sonda por sala con agua o hielo (en vez de una para todo el mapa). Sala = el rectángulo que ofrece el laboratorio (`salas_rects()`), o un bloque de
## `LuzZona3D.SONDA_BLOQUE` × `LuzZona3D.SONDA_BLOQUE` casillas si el nivel no tiene salas; solo donde hay agua, con la caja ajustada al agua más `SONDA_MARGEN`. Desmarcar = la sonda única de antes.
@export var sondas_por_sala: bool = true
## agua EoW (22/10): la refracción del agua física (AguaRender3D; ver sus constantes REFR_*). Desmarcar = el agua de antes, que mezcla por alfa sin leer la pantalla.
@export var agua_refraccion: bool = AguaRender3D.REFRACCION
## agua EoW (22/10): la tercera escala de olas (AguaRender3D, constantes OLA3_*). Desmarcar = las olas de antes.
@export var agua_olas_tercera: bool = AguaRender3D.OLA3_ACTIVA
## agua filtro (22/10): el agua como FILTRO turquesa casi transparente sobre un fondo real (lecho de cantos con cáusticas, guijarros pequeños y desaturados, algas/rocas si hay modelos),
## superficie casi limpia y espuma solo en la orilla (AguaRender3D, constantes FILTRO_*; LechoRio3D). Desmarcar = el agua estilizada de antes, exacta. Cambiarlo en vivo: `aplicar_agua_filtro()`.
@export var agua_filtro: bool = AguaRender3D.FILTRO:
	set(v):
		agua_filtro = v
		if is_node_ready():
			aplicar_agua_filtro()
## adornos agua (22/10): algas y rocas de río sobre el lecho (LechoRio3D.construir_adornos; MultiMesh, sin colisión, las algas se balancean con la corriente). Solo con `agua_filtro`: con el agua
## estilizada (casi opaca en lo hondo) no se verían y solo costarían triángulos, y el agua de antes tiene que quedar exacta. Cambiarlo en vivo reconstruye el lecho (`aplicar_agua_filtro`).
@export var agua_adornos: bool = true:
	set(v):
		agua_adornos = v
		if is_node_ready():
			aplicar_agua_filtro()
var _env: Environment = null
var _tilt: TiltShift3D = null
var _sonda: ReflectionProbe = null
var _sondas: Array = []                         ## agua EoW: las sondas por sala (la primera es también `_sonda`)
var _bordes: BordePiedras3D = null              ## orilla del agua
var _rastrojo: Rastrojo3D = null                ## lo que queda de la hierba segada o quemada (14.2 · P3)
var _bordes_terraza: BordePiedras3D = null      ## escalones de altura (Terreno3D.alturas, las pone el nivel después de montarse la maqueta)
var _bordes_mapa: BordePiedras3D = null         ## V3: labio del borde del mapa (solo labio)
var _bordes_cauce: BordePiedras3D = null        ## labio cauce: suelo ↔ lecho seco (`c` cerrada); falda con el material del lecho
var _bordes_cauce_abierto: BordePiedras3D = null   ## labio cauce: suelo ↔ `c` abierta a cuenca (pozo); se trata como orilla de agua (falda con el material del costado)
var _mat_labio_terraza: StandardMaterial3D = null   ## V3: el labio de las terrazas, de color de vértice como ellas
var _mat_lado_suelo: Material = null
var _hash_alturas: int = 0
var _t_alturas: float = 0.0
var _agua_render: AguaRender3D = null
## La correa fija de la mochila (los 8 huecos y el oro, abajo) la monta `bolsa_ui.gd` (Juego) y siempre está a la vista. Pablo (10/10)
## la quiere fuera: la mochila solo sale con I. Con `false` se esconde desde aquí, sin tocar el archivo del Juego.
@export var mostrar_correa_mochila: bool = false
const NIVELES: String = "res://mundo/datos_nivel/"
var _modo_escena: bool = false
var _registro: Array = []       ## cada _poner: [id pedido, casilla, Transform3D, bloquea, origen "decor" | "marcador"] (lo que F9 hornea)
## 7.2: nivel editable `Nivel_<Nombre>.tscn` (suelo en GridMap, piezas instanciadas, marcadores). Si existe, MANDA sobre las letras.
var _modo_nivel: bool = false
var _nivel_raiz: Node = null           ## el .tscn instanciado (fuera del árbol: solo se lee)
var _marcas: Array = []                ## marcadores de datos: {grupo, tipo, c, giro} (botín, empujables…)
var _en_marcador: bool = false         ## true mientras se coloca algo que sale de un marcador/letra, no del decorado
var _cel_barrera: Array = []           ## casillas `B` (barrera de fuego) del mapa activo, para agruparlas en paredes (7.11)
var _muros_def: Array = []             ## paredes de fuego del nivel editable: {celdas, vertical} (de los marcadores `B` con `largo`)
var _celdas_canal: Dictionary = {}      ## casillas con una pieza canal_recto/canal_codo de un nivel horneado ANTIGUO (los nuevos usan marcadores `-` `L`)
var _canal_llenos: Dictionary = {}      ## casillas de canal cuyo marcador pide `lleno` (empiezan con agua)
var _canal_tf: Dictionary = {}          ## casilla de canal (`-` `L`) -> Transform3D REAL de su marcador (posición, giro y escala, como en el editor)
var _marca_tf: Dictionary = {}          ## 13/10: casilla -> Transform3D REAL de cualquier marcador (posición, giro y escala), como lo dibuja el editor
var _desvios: Dictionary = {}           ## casilla -> Vector2 (x, z): lo que el marcador de la tinaja está desplazado del centro de su casilla
var _puentes_def: Array = []           ## puentes reactivos del nivel editable (marcadores `P`): {celdas, activador (casilla o (-1,-1))}
var _celdas_pieza: Dictionary = {}     ## casillas bloqueadas por una pieza del .tscn (Vector2i -> true)
## 12/10 (Pablo): lo que cuenta como MURO. Su casilla bloquea ENTERA, siempre: no se roza ni se cuela por un hueco de su forma.
const MUROS_COLISION: Array = ["empalizada_goblin", "puerta_goblin", "arco_ruina", "arco_puerta"]
var _celdas_muro: Dictionary = {}      ## casillas de muro (Vector2i -> true)
## 12/10 (Pablo): NPCs y objetos (reactivos) colisionan por su CONTORNO: un círculo en los pies, no la casilla entera.
const RADIO_CONTORNO_NPC: float = 0.3
const RADIO_CONTORNO_OBJETO: float = 0.4
var _npcs_contorno: Array = []         ## Pj3D de NPC quietos (los registra `_npc`)
var _solidos: Node3D = null            ## cuerpos de colisión de esas piezas

var _mapa: PackedStringArray = PackedStringArray()
var _giros: Dictionary = {}                ## giros a mano del mapa activo (Jugabilidad3D.GIROS o GIROS_CELDA)
## Escala de cada marcador del nivel (.tscn), por casilla: Vector3. Solo la usan los objetos que la admiten (de momento la
## telaraña); sin entrada, escala 1. En el modo letras está vacío.
var _escalas: Dictionary = {}
## Nivel editable: la casilla del GridMap que pasa a ser la (0, 0) de la maqueta (la esquina mín. de las casillas pintadas) y
## el tamaño real (ancho × alto) del rectángulo pintado. La maqueta trabaja en un cuadrado de `_lado` = el mayor de los dos,
## con la parte sobrante vacía (letra " ": sin suelo, bloqueada). Todo el .tscn se desplaza -_origen casillas al cargarlo.
var _origen: Vector2i = Vector2i.ZERO
var _ancho: int = 0
var _alto: int = 0
var _desplaza: Vector3 = Vector3.ZERO
var _lado: int = 40
var _bloqueadas: Dictionary = {}
var _bibliotecas: Array[Node3D] = []
var _props: Node3D = null
var _efectos: Node3D = null
var _girar: Array[Node3D] = []
var _goblins: Array[Pj3D] = []
var _jugador: Pj3D = null
var _mat_agua: ShaderMaterial = null
var _mat_suelo: ShaderMaterial = null
var _tex_estado_juego: ImageTexture = null    ## `Mundo3D.textura_estados()` (R quemada · G mojada · B helada · A segada): la ÚNICA imagen de estado; la leen suelo, agua y hierba
## B2: lo PISADO (hierba aplastada por la chibi o el viento) no es un hecho del juego y no cabe en el estado oficial (avisaría a todo el juego a cada
## paso): textura propia de un canal (R8, una casilla por píxel, 0..1) que solo lee el shader de la hierba. Se levanta sola en `T_PISADO` s.
var _img_pisado: Image = null
var _tex_pisado: ImageTexture = null
var _pisado_sucio: bool = false
var _mojada: Dictionary = {}             ## Vector2i -> ms hasta los que la hierba no prende (la acaba de mojar el agua)
const T_MOJADA_MS: int = 8000
const RADIO_APAGAR: int = 2               ## el agua apaga en un cuadrado de (2r+1) casillas, no solo en la del impacto
var _hf: Dictionary = {}                  ## Vector2i -> {fase, t, v, frente, contagia, fx}: hierba que no es FINA
var _pisadas: Dictionary = {}             ## casillas con pisado > 0 (se levantan solas)
var _mundo: Mundo3D = null                ## 13/10 (M2): el mundo vivo. «¿Está helada?» ya no se guarda aquí: `Terreno3D.helada(c)`
var _fx: Vfx3D = null
var _dir_hechizo: Vector3 = Vector3(0.0, 0.0, 1.0)
var _t_cast: float = 0.0
var _precalentando: bool = false
var externo: bool = false                 ## true: Jugador3D (Juego) mueve al jugador y Combate3D a los goblins
var _velo: Control = null
var _t_velo: float = 0.0
var _f_velo: int = 0
var _ms_velo: int = 0
var _ms_estado: float = 0.0
var _empujables: Array[MeshInstance3D] = []
var _tex_grietas: Texture2D = null
var _contraste: float = 2.5
var _rugosidad: float = 0.5     ## relieve del suelo (tecla B): 0 · 0,5 · 1
var _hierba: Hierba3D = null
var _sin_hierba: Dictionary = {}          ## casillas con runa en el suelo: la hierba no la tapa
var _img_mapa: Image = null
var _img_zona_v: Image = null              ## solo las casillas ZONA_V (R = 1): el mapa de la hierba cuando `hierba_solo_en_zona_v`
var _img_campo: Image = null
var _camara: Camera3D = null
var _sol: DirectionalLight3D = null
var _foco: Vector3 = Vector3.ZERO
var _tam_camara: float = ZOOM_INICIAL
var _incl: float = INCLINACION
var _giro_cam: float = 0.0              ## giro de la cámara en pasos de 90° (Z/C): para ver qué tapa algo desde el otro lado
var _hud: Label = null
var _t_hud: float = 0.0
var _avisos: PackedStringArray = PackedStringArray()
var _lotes: Dictionary = {}          ## id -> Array[Transform3D] de las copias puestas
var _plantillas: Dictionary = {}     ## id -> [[Mesh, Transform3D local, Material], ...] (vacío si no hay pieza)
var _n_lotes: int = 0
var _sombras: Array[Transform3D] = []   ## elipses de contacto de las piezas puestas en lotes (se dibujan en un solo MultiMesh)
var _canal: Canal3D = null               ## el canal por el que corre el agua de la tinaja (10/10)
var _reactivos: Array[Reactivo3D] = []   ## los objetos de 4.7 (para enlazar el tótem de rayo con el puente)
## Los datos del nivel (de test_2.gd o de jugabilidad_3d.gd, según `nivel`).
## Las reglas del nivel: Jugabilidad3D (reglas "jugabilidad") o Bosque3D (reglas "bosque", 9.8, del Juego). Sin tipo a propósito:
## Bosque3D lo hace el Juego y se carga solo si existe `bosque_3d.gd`; las dos tienen iniciar, colocar, registrar_npc y registrar_losa.
var _reglas = null
## 9.5: el mapa salió de `niveles/mapas/<nivel>.txt` (no del .tscn ni de las constantes de siempre).
var _de_archivo: bool = false
## 9.7 · Bosque 1: cauce seco (`c`), runas de la puerta (`X`) y agua electrificada. Lo maneja el Juego con llenar_cauce,
## encender_runa y electrificar_agua (abajo, «API del Bosque»).
const ALTO_CAUCE: float = ALTO - 0.1          ## el lecho va 0,1 por debajo del suelo: se lee como zanja, y el agua lo tapa
const ALTO_RUNAS: float = 3.1                 ## sobre el suelo: encima del dintel del arco
## cauce profundo · constantes (cauce seco cerrado). Todo es visual: no toca colisión, `Terreno3D` ni la simulación de agua.
const GUIJARROS_ANTES: int = 9                 ## sin `cauce_profundo`: los 9 de siempre
const GUIJARROS_CAUCE: int = 5                 ## por casilla (antes 9): grava dispersa, no un tapiz de pastillas
const GUIJARRO_RADIO_MIN: float = 0.045        ## u (antes 0,10–0,24): de grava, no de piedra
const GUIJARRO_RADIO_VAR: float = 0.05         ## u que se suman al mínimo según el hash
const GUIJARRO_ALARGADO: float = 1.3           ## largo/ancho (antes 1,4)
const GUIJARRO_ALTO: float = 0.6               ## alto/ancho (antes 0,45: óvalos planos)
const GUIJARRO_GRIS_MIN: float = 0.27          ## luminancia sRGB de los tonos tierra-gris (el lecho ronda 0,40: los guijarros más oscuros que él, nunca blancos)
const GUIJARRO_GRIS_VAR: float = 0.12
const GUIJARRO_TINTE: Color = Color(1.08, 0.96, 0.84)   ## multiplicador del gris: tierra parda, como el lecho
const LECHO_CAUCE_OSCURO: float = 0.88         ## el lecho en conjunto, algo más oscuro que el suelo que lo rodea
const OCLUSION_ANCHO: float = 0.9              ## u desde la pared hacia dentro en las que el lecho se oscurece (casilla de 2,3 u)
const OCLUSION_FUERZA: float = 0.62            ## cuánto se oscurece pegado a la pared (0 = nada, 1 = negro)
const OCLUSION_REJILLA: int = 8                ## divisiones por lado de la tapa del lecho (los colores de vértice interpolan en ellas)
const PARED_CAUCE_OSCURA: float = 0.6          ## multiplicador de la falda del cauce (la pared interior): más oscura que el lecho
const PARED_FOSO_OSCURA: float = 0.72          ## cauce hondo: multiplicador de la piedra de la pared del foso (más oscura que la del pozo de una cuenca)
const PIE_LABIO_CAUCE: float = 0.0          ## normal del pie del labio (ver `BordePiedras3D.labio_pie_arriba`): 0 = pared vertical, más oscura que el suelo
var _guijarros: MultiMeshInstance3D = null
var _celdas_cauce: Array[Vector2i] = []        ## cauce profundo: las casillas `c` (para rehacer tapas y guijarros en vivo)
var _mat_falda_cauce: StandardMaterial3D = null  ## cauce profundo: la falda (pared interior) del lecho seco, más oscura que el lecho
var _albedo_lecho_base: Color = Color.WHITE
var _malla_lecho_plano: ArrayMesh = null       ## la tapa lisa de antes (sin oclusión)## agua filtro: el material del lecho del río (LechoRio3D), el del suelo que sustituye, la malla del bloque (para cambiarle el material en vivo) y las casillas de agua (para rehacer guijarros y adornos).
var _mat_lecho_agua: ShaderMaterial = null
var _mat_suelo_lecho: Material = null
var _malla_lecho_agua: ArrayMesh = null
var _celdas_agua: Array[Transform3D] = []
var _adornos_lecho: Node3D = null
var _lecho_rio_medida: Dictionary = {}     ## {n, diam_max (de los guijarros pequeños), sat (media)}: para las pruebas (el MultiMesh no se puede leer sin GPU)
var _agua_cauce: Dictionary = {}             ## casilla `c` -> MeshInstance3D de su agua (oculta hasta llenar_cauce)
## 13.9 (15/10, DIARIO 92): la casilla `c` ABIERTA a la simulación (`Terreno3D.es_cuenca`) es un POZO con fondo (PozoCauce3D), no el bloque macizo de
## ALTO_CAUCE. Cerrada se ve como siempre (el lecho seco del Bosque). `_actualizar_pozos` mira cada 0,1 s si alguna se abrió o se cerró.
var _tapas_cauce: Dictionary = {}            ## casilla `c` -> MeshInstance3D del bloque del lecho seco (visible mientras NO es cuenca)
var _pozos_cauce: Dictionary = {}            ## casilla `c` -> PozoCauce3D (se crea la primera vez que se abre: así lee el alto del agua ya configurado)
var _estado_pozo: Dictionary = {}            ## casilla `c` -> bool: último estado visto (abierta = pozo). Con `cauce_hondo` es siempre true: el foso se dibuja también seco
var _estado_abierta: Dictionary = {}         ## cauce hondo: casilla `c` -> bool, último estado «con agua»: cuenca abierta a la simulación o ya pasada a «~» (borde de orilla; si no, borde de lecho seco)
var _mat_piedra_pozo_hondo: StandardMaterial3D = null   ## cauce hondo: la piedra de la pared del foso, más oscura que la del pozo de una cuenca
var _guijarros_cauce: Dictionary = {}        ## casilla `c` -> [índice del primer guijarro, Array de sus 9 transformadas con la tapa puesta]
var _mat_lecho_cauce: StandardMaterial3D = null
var _mat_piedra_pozo: StandardMaterial3D = null
var _t_pozos: float = 0.0
var _nivel_pozo: Dictionary = {}              ## casilla `c` -> último nivel visto (0..1 de la altura del pozo): para saber si SUBE
var _t_sonido_pozo: Dictionary = {}           ## casilla `c` -> s hasta el siguiente «glu glu» del llenado
var _t_caida_fx: Dictionary = {}              ## posición redondeada de una caída -> segundos (reloj) de su último efecto (para no apilarlos)
var _runas_puerta: Dictionary = {}           ## elemento -> [StandardMaterial3D del símbolo, posición]
var _canal_orden: Array = []                 ## 13/10: casillas del canal en orden de llenado (índice = el de Canal3D)
var _chispas_agua: Dictionary = {}           ## casilla -> Node3D con las chispas del agua electrificada
var _t_rayo_agua: Timer = null             ## chispazos sueltos por el agua electrificada
const REGLAS_BOSQUE: String = "res://escenas/bosque_3d.gd"
var _guardados: Array = []
var _suelo_obj: Array = []
var _rotulos: Dictionary = {}
var _color_prueba: Dictionary = {}
var _empuj_def: Array = EMPUJABLES


func _ready() -> void:
	# 13/10 (M2): el Mundo3D se crea AQUÍ, el primero, para que exista antes de que el Jugador llame a Lanzador3D.configurar.
	# Es el dueño del estado del suelo (helada, electrificada…); esta maqueta solo lo dibuja y le escucha `casilla_cambio`.
	_mundo = Mundo3D.new()
	_mundo.name = "Mundo"
	add_child(_mundo)
	_mundo.casilla_cambio.connect(_al_cambiar_casilla)
	_mundo.impacto.connect(_al_impacto_mundo)
	# 14.2 · P3: el estado «segada» de una casilla lo marca el Juego en EstadosSuelo3D; aquí solo se DIBUJA su rastrojo.
	_rastrojo = Rastrojo3D.new()
	_rastrojo.name = "Rastrojo"
	_rastrojo.lado = S
	add_child(_rastrojo)
	Terreno3D.estados.cambio.connect(_al_cambiar_estado_suelo)
	_modo_nivel = usar_escena and HorneadorNivel.existe_nivel(nivel)      # nombre exacto: ver existe_nivel (Windows no distingue mayúsculas)
	if reglas == "jugabilidad" or (reglas == "" and nivel == "jugabilidad"):
		_reglas = Jugabilidad3D.new()
		_reglas.name = "Reglas"
	elif reglas == "bosque":
		# 9.6: las reglas del Bosque 1 (Bosque3D, 9.8) son del Juego; mientras no exista su archivo, el nivel va sin reglas.
		if ResourceLoader.exists(REGLAS_BOSQUE):
			_reglas = (load(REGLAS_BOSQUE) as GDScript).new()
			_reglas.name = "Reglas"
		else:
			_avisos.append("reglas «bosque»: aún no existe bosque_3d.gd (Juego, 9.8); el nivel va sin reglas")
	if nivel == "jugabilidad":
		_mapa = Jugabilidad3D.MAPA
		_giros = Jugabilidad3D.giros()
		_guardados = Jugabilidad3D.GUARDADOS
		_empuj_def = Jugabilidad3D.empujables()
	elif nivel == "pruebas":
		_mapa = NivelPruebas.MAPA              # 7.12: el banco de pruebas (16×16); lo demás vacío
		_giros = {}
		_guardados = []
		_empuj_def = []
	elif not _modo_nivel and HorneadorNivel.ruta_mapa(nivel) != "":
		# 9.5: las letras salen de `niveles/mapas/<nivel>.txt` (el mapa del plan tal cual). F9 lo hornea en Nivel_<Nivel>.tscn.
		var tam: Array = []
		var giros: Dictionary = {}
		_mapa = HorneadorNivel.leer_mapa(nivel, tam, giros)
		_ancho = int(tam[0])
		_alto = int(tam[1])
		_de_archivo = true
		_giros = giros           # `; giro x y grados` del archivo (arcos que se cruzan de oeste a este…)
		_guardados = []
		_empuj_def = []
	elif _modo_nivel and nivel != "test2":
		# Un nivel nuevo de Pablo (Nivel_Bosque.tscn…): todo sale del .tscn. Sin esto heredaba el botín, los rótulos y los
		# colores de prueba del Test 2, puestos en las casillas del Test 2.
		_mapa = PackedStringArray()
		_giros = {}
		_guardados = []
		_empuj_def = []
	else:
		_mapa = TEST2.MAPA_TEST2
		_giros = GIROS_CELDA
		_guardados = TEST2.GUARDADOS_T2
		_suelo_obj = TEST2.SUELO_T2
		_rotulos = TEST2.ROTULOS
		_color_prueba = TEST2.COLOR_PRUEBA
	if _modo_nivel:
		_leer_nivel()
	_lado = _mapa.size()
	# 13/10 (M5, paso 1): el terreno recibe el mapa UNA vez y contesta solo (letra, canal, lados abiertos…). `_bloqueadas`, `_celdas_canal`
	# y `_giros` se comparten por referencia (aquí no se reasignan después); el mapa se COPIA: cambiar una letra ya es `Terreno3D.poner_letra`.
	Terreno3D.cargar_datos(_mapa, _bloqueadas, _celdas_canal, _giros)
	Terreno3D.fijar_cauce_hondo(cauce_hondo)      # cauce hondo: antes de construir el cauce (el setter no corre con el valor de serie)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	# Bloque 4 EoW: escala del render 3D (EoW dibuja a 1408 × 792 y reescala). Por debajo de 1, FSR reescala con nitidez; el HUD no se toca.
	if escala_render < 0.999:
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		get_viewport().scaling_3d_scale = clampf(escala_render, 0.5, 1.0)

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	if estilo == "cueva":
		# Casi negro: lo que queda fuera del mapa o entre dos paredes es roca a oscuras, no cielo. Con el celeste de serie el agua lo
		# reflejaba (manchas blancas en la charca) y se veía por los huecos entre las paredes.
		env.background_color = Color(0.035, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = LUZ_AMBIENTE
	entorno.environment = env
	Paleta3D.aplicar_ajuste(env)        # 14.2 (c): ajuste de color ÚNICO (brillo/contraste/saturación): ver Paleta3D y ARTE.md §10
	VfxKit3D.activar_glow(env)          # bloom: solo brilla lo que pasa de 1,4 en HDR (el corazón del fuego nuevo); agua y cristales no llegan
	Posproceso3D.aplicar_entorno(env, get_viewport())   # V1 (21/10): SSAO, tonemap y FXAA (todo apagable: ver posproceso_3d.gd)
	add_child(entorno)

	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	_sol.light_color = Color(1.0, 0.96, 0.88)
	_sol.light_energy = LUZ_SOL
	_sol.shadow_enabled = true
	_sol.directional_shadow_max_distance = 30.0
	add_child(_sol)
	_env = env
	LuzZona3D.aplicar(env, _sol, zona_luz)    # F1: sol y ambiente de la zona (con «bosque» queda igual que lo de arriba)

	_props = Node3D.new()
	_props.name = "Decorado"
	add_child(_props)
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_fx = Vfx3D.new()
	_fx.estilo_fuego_nuevo = fuego_nuevo
	if fuego_nuevo:
		_fx.escala = ESCALA_VFX_NUEVO      # 10/10 (Pablo): la flecha de fuego y el resto del kit nuevo, al 0,6 que fijó en el Lab
	_efectos.add_child(_fx)
	_fx.impacto.connect(_al_impactar)
	# enganche logros (diario 245): la presentacion de las reacciones (A4) y de los logros (PLAN_EOW_VISUAL §4) se engancha AQUI, una vez por nivel montado,
	# no en cada laboratorio. `conectar` es idempotente por mundo (is_connected sobre un Callable estatico), asi que el lab que la repita no duplica.
	ReaccionesVfx3D.conectar(_mundo, _efectos)
	Logros3D.conectar(_mundo, _efectos)

	Albedos3D.activo = albedos_eow          # albedos: antes de crear ningún material
	if transparencia_jugador and decorado_por_lotes:
		Ocluso3D.preparar()
		Albedos3D.parchear_ocluso()         # albedos: la corrección de las piezas entra en el shader común (idempotente); el interruptor es el uniforme global
		Albedos3D.poner_piezas(albedos_eow)
	_cargar_bibliotecas()
	_construir_suelo()
	_modo_escena = usar_escena and not _modo_nivel and ResourceLoader.exists(_ruta_escena())
	_colocar_letras()
	_montar_canal()
	_montar_agua_fisica()
	_colocar_extras()
	if _modo_nivel:
		_instanciar_nivel()
	elif _modo_escena:
		_instanciar_escena()
	_colocar_empujables()
	_construir_lotes()
	_sembrar_hierba()
	_ambiente()
	for b in _bibliotecas:
		b.free()
	_bibliotecas.clear()
	# El .tscn del nivel se instancia fuera del árbol solo para leerlo: hay que liberarlo a mano. Si no, todas sus piezas,
	# mallas y marcadores se quedaban vivos hasta cerrar el juego (Godot lo avisa al parar: «mesh is null», «leaked»).
	if _nivel_raiz != null and is_instance_valid(_nivel_raiz):
		_nivel_raiz.free()
	_nivel_raiz = null

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = _tam_camara
	_camara.near = 0.1
	_camara.far = 300.0
	add_child(_camara)
	if _jugador != null:
		_foco = _centro(_jugador)
	_colocar_camara()
	_montar_diorama()
	_montar_tilt_shift()
	_montar_sonda()

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_actualizar_hud()
	_precalentar(capa)
	Jugador3D.montar(self)
	# 16/10 (T6b): el VFX del conjuro (voluta del libro a la mano y forma en la mano, por elemento). Escucha `conjuro_fase` del Lanzador3D del Juego.
	ConjuroVfx3D.conectar(get_node_or_null("Lanzador3D"), self)
	# 18/10 (H5): el VFX por ESTADO de la receta V2 (VfxEstado3D, diario 155/162). Escucha `hechizo_v2` y dibuja el volumen X·Y·Z según el estado del
	# elemento, con lo que manda la señal (persiste, suelo, t_caida, eventos, celdas). Se cuelga de esta maqueta como «VfxEstado3D». El dibujo de forma
	# antiguo (Vfx3D.lanzar_forma) ya no lo pide ningún hechizo: `_materializar` es solo la V2. Medidas del terreno: las mismas que usa el Lanzador3D.
	var vfx_estado: VfxEstado3D = VfxEstado3D.conectar(get_node_or_null("Lanzador3D"), self)
	vfx_estado.casilla = Terreno3D.casilla
	vfx_estado.alto_nivel = Terreno3D.ALTO_NIVEL
	vfx_estado.y_pies = func(c: Vector2i) -> float: return Terreno3D.y_pies(c)
	if _velo != null:
		vfx_estado.precalentar(_jugador.position)       # detrás del velo de «Preparando efectos…»: compila los siete efectos antes de jugar
	# 20/10 (entrada 203): el efecto por ELEMENTO vuelve a mandar. VfxElemento3D escucha lo mismo que VfxEstado3D (el `HechizoVivo` que entra en el
	# lanzador y `hechizo_v2`) y cuelga del HechizoVivo las piezas de VfxKit3D del elemento. VfxEstado3D (por estado de la materia) se queda APAGADO hasta
	# validarlo elemento por elemento (F8 lo enciende y apaga), para que no se dibuje encima del de elemento.
	var vfx_elemento: VfxElemento3D = VfxElemento3D.conectar(get_node_or_null("Lanzador3D"), self)
	vfx_elemento.casilla = Terreno3D.casilla
	vfx_estado.encendido = false
	# Bloque 2 EoW (23/10): con el libro abierto o apuntando, lo que reaccionaría al hechizo se marca con un borde de luz (Realce3D).
	var lz: Lanzador3D = get_node_or_null("Lanzador3D") as Lanzador3D
	if lz != null:
		Realce3D.montar(lz, self)
	# Bloque 3 EoW (23/10): luz y cámara por área, de las líneas «; zona» del mapa del nivel (Zonas3D). Sin esas líneas no cambia nada.
	Zonas3D.montar(self)
	# Bloque 3 EoW: bruma baja en el fondo de los cauces secos hondos (NieblaFoso3D); se va cuando se llenan.
	if niebla_fosos:
		NieblaFoso3D.montar(self)
	_ocultar_correa_mochila()
	if _modo_escena or _modo_nivel:
		_activar_solidez_por_nodos()
	if _reglas != null:
		add_child(_reglas)
		_reglas.iniciar(self)
	elif vitrina_vfx:
		_vitrina_vfx()


## 13/10 (M5): los datos del mapa en Terreno3D son estáticos y sobreviven a esta escena: al salir se sueltan, o el nivel siguiente
## empezaría viendo el mapa y los bloqueos de este.
func _exit_tree() -> void:
	Terreno3D.olvidar_datos()
	Terreno3D.fijar_cauce_hondo(false)      # cauce hondo: el interruptor es de esta maqueta; el siguiente nivel pone el suyo
	Logros3D.restaurar_tiempo()      # enganche logros: salir en pleno hitstop no deja el juego a cámara lenta


## --- Utilidades de rejilla ---

func _letra(c: Vector2i) -> String:
	# 13/10 (M5, paso 3): con datos propios la letra la contesta el terreno (que es quien la cambia). Antes de `cargar_datos` (durante
	# `_leer_nivel` y hasta fijar `_lado`) aún no hay, y se lee la copia de carga. OJO: no quitar el respaldo, o Terreno3D volvería
	# a preguntarle a esta función y se quedaría en bucle.
	if Terreno3D.datos_propios:
		return Terreno3D.letra_de(c)
	if c.y < 0 or c.y >= _lado or c.x < 0 or c.x >= _mapa[c.y].length():
		return "#"
	return _mapa[c.y][c.x]


func _centro_celda(c: Vector2i, y: float) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)


func _hash(x: int, y: int, sal: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (sal * 83492791))


func _es_agua(l: String) -> bool:
	return l == "~" or l == "b"


## Tipo de suelo de una casilla para la mezcla: 0 hierba, 1 camino, 2 tierra, 3 piedra.
func _tipo_suelo(c: Vector2i) -> int:
	var l: String = _letra(c)
	if _reglas != null or _de_archivo or (_modo_nivel and nivel != "test2"):
		# Test de jugabilidad y niveles editables (salvo el Test 2, que conserva su aldea): el suelo sale de las letras (hierba de bosque; camino bajo la puerta, la salida y las losas).
		if l == "c" or l == "e" or l == "u" or l == "-" or l == "L" or l == "R":
			return 3        # 9.6: lecho de piedras del cauce seco; piedra bajo la fuente eléctrica, la tinaja y los canales
		if l == "g" or l == "F" or l == "T" or l == "B" or l == "t" or l == "y" or l == "o" or l == "x" or l == "V":
			return 2        # tierra pisada bajo el campamento goblin
		if l == "X" or l == "E" or l == "S" or l == "p" or l == "a" or l == "w" or _es_agua(l):
			return 1
		return 0
	if l == "g" or l == "F" or l == "T" or l == "B":
		return 2
	if l == "X" or l == "E" or l == "S" or l == "n" or l == "Q" or l == "M":
		return 1
	if l == "K" or l == "R":
		return 3
	if _es_agua(l):
		return 1    # orilla de arena alrededor del agua
	if l == "#":
		return 0
	# El camino principal (aldea -> plaza -> puerta) y el pasillo este-oeste de la fila 16.
	if (c.x >= 18 and c.x <= 20 and c.y >= 6) or c.y == 16:
		return 1
	# La aldea y la plaza: camino con manchas de hierba.
	if c.x >= 14 and c.x <= 25 and c.y >= 7 and c.y <= 38:
		return 1 if _hash(c.x, c.y, 11) % 3 != 0 else 0
	if _hash(c.x, c.y, 12) % 11 == 0:
		return 2
	return 0


## --- Suelo ---

## 16/10 (Pablo): arena (el suelo de «camino», marrón claro) en las casillas de tierra pegadas al agua por sus 4 lados, en los niveles
## editables y los de archivo. Es solo el color del suelo del shader: `_tipo_suelo` no cambia, así que `_es_hierba` (dónde crece y arde
## la hierba) sigue igual. En el Test 2 no: conserva su aldea y su suelo de siempre. `false` lo quita.
const ORILLA_SIEMPRE: bool = true


func _junto_a_agua(c: Vector2i) -> bool:
	if not (_reglas != null or _de_archivo or (_modo_nivel and nivel != "test2")):
		return false
	for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _es_agua(_letra(c + v)):
			return true
	return false


## joints · TABLA DE PARES. Clave «a_b» con a < b en el orden hierba, camino, tierra, piedra. Medidas en u de mundo (1 casilla = 2,3 u).
##   - parejas de MIGAS (camino→tierra, camino→piedra, tierra→piedra): «sobre» = el suelo cuyas migas caen sobre el otro (el que «lame» en `pareja`),
##     «ancho» = hasta dónde llegan, «amp» = cuánto desplaza el ruido la frontera antes de cortar, «dens» = densidad en la frontera (0-1),
##     «escala» = frecuencia del grano sobre el campo de ruido, «tinte» = lo que se multiplica el color de las migas.
##   - parejas de MATAS de hierba (hierba→camino, hierba→piedra): «ancho» = hasta dónde se adentran, «fuerza» = su opacidad. Hierba→tierra ya tenía matas
##     (`invade_hierba`, alcance 1,5 × `borde_ancho` + 0,6 u); se anota aquí para completar la tabla pero no cambia.
##   - todas llevan además lo de antes: la franja de hojas de la hierba y el degradado «lame» de `pareja`.
## Textura de borde: PROCEDURAL (migas = máscara de ruido del campo × la textura del suelo que lame; matas = la máscara de `invade_hierba` con la textura de
## hierba). No hay asset: arte/meshy/PROMPTS_JOINTS.md propone uno para pedirlo si se quiere sustituir.
const JOINTS_PARES: Dictionary = {
	"camino_tierra": {"sobre": "camino", "textura": "migas de arena", "ancho": 0.9, "amp": 0.35, "dens": 1.0, "escala": 2.3, "tinte": Color(1.0, 1.0, 1.0), "lamina_ancho": 1.7},
	"camino_piedra": {"sobre": "camino", "textura": "migas de arena", "ancho": 0.8, "amp": 0.3, "dens": 1.0, "escala": 2.3, "tinte": Color(1.0, 1.0, 1.0), "lamina_ancho": 1.9},
	"tierra_piedra": {"sobre": "tierra", "textura": "migas de tierra / grava", "ancho": 0.9, "amp": 0.35, "dens": 1.0, "escala": 2.3, "tinte": Color(1.0, 1.0, 1.0), "lamina_ancho": 1.9},
	"hierba_camino": {"sobre": "hierba", "textura": "matas de hierba", "ancho": 1.4, "fuerza": 0.7, "lamina_ancho": 1.3},
	"hierba_piedra": {"sobre": "hierba", "textura": "matas de hierba entre las losas", "ancho": 1.2, "fuerza": 0.8, "lamina_ancho": 1.3},
	"hierba_tierra": {"sobre": "hierba", "textura": "matas de hierba (invade_hierba)", "ancho": 1.0, "fuerza": 1.0},
}
const TIPOS_SUELO: Array = ["hierba", "camino", "tierra", "piedra"]


## joints · ¿esta casilla es suelo llano que pinta el shader (y por tanto puede llevar tira)? No: sin pintar (« »), agua, cauce seco («c»; es un
## hueco con su propio lecho) ni las casillas del borde sin letra.
func _suelo_llano(c: Vector2i) -> bool:
	if not _en_mapa(c):
		return false
	var l: String = _letra(c)
	return l != " " and l != "c" and not _es_agua(l)


## joints · tipo de suelo de la casilla tal como lo pinta el mapa (con la orilla de arena junto al agua), o -1 si no es suelo llano.
func _tipo_joint(c: Vector2i) -> int:
	if not _suelo_llano(c):
		return -1
	var t: int = _tipo_suelo(c)
	if t == 0 and ORILLA_SIEMPRE and _junto_a_agua(c):
		t = 1
	return t


## joints · las aristas entre casillas de suelo llano de tipos distintos (la lista que el shader pinta como tira; la usan las pruebas). Cada una:
## {c, v (vecino a la derecha o abajo), par ("a_b" de JOINTS_PARES), a, b}. Con `joints_suelo = false` no hay ninguna.
func joints_aristas() -> Array:
	var res: Array = []
	if not joints_suelo:
		return res
	for y in range(_lado):
		for x in range(_lado):
			var c := Vector2i(x, y)
			var a: int = _tipo_joint(c)
			if a < 0:
				continue
			for v in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: int = _tipo_joint(c + (v as Vector2i))
				if b < 0 or b == a:
					continue
				res.append({"c": c, "v": c + (v as Vector2i), "par": "%s_%s" % [TIPOS_SUELO[mini(a, b)], TIPOS_SUELO[maxi(a, b)]], "a": a, "b": b})
	return res


## joints lámina · el atlas de tiras (5 filas de 128 px) o null si no está el archivo (entonces el suelo usa la tira procedural). Ruta sustituible para las pruebas.
var joints_atlas_ruta: String = JOINTS_ATLAS


func joints_atlas_textura() -> Texture2D:
	if not ResourceLoader.exists(joints_atlas_ruta):
		return null
	return load(joints_atlas_ruta) as Texture2D


## joints · el mapa de «no es suelo llano» (R = 1 en agua, cauce seco y huecos) que apaga las tiras junto a ellos, y los uniforms de la tabla.
func _aplicar_joints(mat: ShaderMaterial) -> void:
	var fuera := Image.create_empty(_lado, _lado, false, Image.FORMAT_R8)
	for y in range(_lado):
		for x in range(_lado):
			var l: String = _letra(Vector2i(x, y))
			fuera.set_pixel(x, y, Color(1.0 if (l == " " or l == "c" or _es_agua(l)) else 0.0, 0.0, 0.0))
	mat.set_shader_parameter("mapa_fuera", ImageTexture.create_from_image(fuera))
	for par in ["camino_tierra", "camino_piedra", "tierra_piedra"]:
		var d: Dictionary = JOINTS_PARES[par]
		var suf: String = {"camino_tierra": "ct", "camino_piedra": "cp", "tierra_piedra": "tp"}[par]
		mat.set_shader_parameter("joint_" + suf, Vector4(float(d["ancho"]), float(d["amp"]), float(d["dens"]), float(d["escala"])))
		var tn: Color = d["tinte"]
		mat.set_shader_parameter("joint_tinte_" + suf, Vector3(tn.r, tn.g, tn.b))
	var mc: Dictionary = JOINTS_PARES["hierba_camino"]
	var mp: Dictionary = JOINTS_PARES["hierba_piedra"]
	mat.set_shader_parameter("joint_matas", Vector3(float(mc["fuerza"]), 0.0, float(mp["fuerza"])))
	mat.set_shader_parameter("joint_matas_ancho", Vector3(float(mc["ancho"]), 0.0, float(mp["ancho"])))
	mat.set_shader_parameter("joints_fuerza", 1.0 if joints_suelo else 0.0)
	var atlas: Texture2D = joints_atlas_textura()
	if atlas != null:
		mat.set_shader_parameter("t_joints", atlas)
	mat.set_shader_parameter("joints_lamina", 1.0 if (joints_lamina and joints_suelo and atlas != null) else 0.0)
	mat.set_shader_parameter("joints_contraste", JOINTS_CONTRASTE)
	mat.set_shader_parameter("joints_escala", JOINTS_ESCALA)
	mat.set_shader_parameter("joints_linea", JOINTS_LINEA)
	mat.set_shader_parameter("joints_afina", JOINTS_AFINA)
	mat.set_shader_parameter("joints_piedra_ref", JOINTS_PIEDRA_REF)
	# Ancho de la tira del atlas por pareja («lamina_ancho» de JOINTS_PARES): 1 = proporción pintada.
	var anchos: Array = []
	for par in ["camino_tierra", "camino_piedra", "tierra_piedra", "hierba_camino", "hierba_piedra"]:
		anchos.append(float(JOINTS_PARES[par].get("lamina_ancho", 1.0)))
	mat.set_shader_parameter("joints_ancho", Vector4(anchos[0], anchos[1], anchos[2], anchos[3]))
	mat.set_shader_parameter("joints_ancho4", anchos[4])


func _construir_suelo() -> void:
	# Mapa de tipos para el shader.
	var img := Image.create_empty(_lado, _lado, false, Image.FORMAT_RGBA8)
	for y in range(_lado):
		for x in range(_lado):
			var t: int = _tipo_suelo(Vector2i(x, y))
			if t == 0 and ORILLA_SIEMPRE and _junto_a_agua(Vector2i(x, y)):
				t = 1       # 16/10 (Pablo): la orilla de arena va SIEMPRE alrededor del agua (solo el color del suelo: la hierba y su fuego no cambian)
			img.set_pixel(x, y, Color(1.0 if t == 0 else 0.0, 1.0 if t == 1 else 0.0, 1.0 if t == 2 else 0.0, 1.0 if t == 3 else 0.0))
	_img_mapa = img
	_img_zona_v = null
	if _solo_zona_v():
		_img_zona_v = Image.create_empty(_lado, _lado, false, Image.FORMAT_RGBA8)
		for y in range(_lado):
			for x in range(_lado):
				var lz: String = _letra(Vector2i(x, y))
				_img_zona_v.set_pixel(x, y, Color(1.0 if lz == "v" or lz == "," else 0.0, 0.0, 0.0, 0.0))     # `,` = hierba corta (9.6)
	_img_campo = _campo_ruido(_lado * 8)
	var sh := Shader.new()
	sh.code = CODIGO_SUELO
	var mat_suelo := ShaderMaterial.new()
	mat_suelo.shader = sh
	mat_suelo.set_shader_parameter("mapa", ImageTexture.create_from_image(img))
	mat_suelo.set_shader_parameter("campo", ImageTexture.create_from_image(_img_campo))
	mat_suelo.set_shader_parameter("t_hierba", _tex(SUELO + "hierba_arriba.png"))
	mat_suelo.set_shader_parameter("t_camino", _tex(SUELO + "path_arriba.png"))
	# Tierra: la nueva (tierra_arriba.png + su normal) si está; si no, la de siempre.
	var hay_tierra_nueva: bool = ResourceLoader.exists(SUELO + "tierra_arriba.png") and ResourceLoader.exists(SUELO + "tierra_arriba_normal.png")
	mat_suelo.set_shader_parameter("t_tierra", _tex(SUELO + ("tierra_arriba.png" if hay_tierra_nueva else "dirt_arriba.png")))
	if hay_tierra_nueva:
		mat_suelo.set_shader_parameter("normal_tierra", load(SUELO + "tierra_arriba_normal.png") as Texture2D)
		mat_suelo.set_shader_parameter("usa_normal_tierra", 1.0)
	# 11/10 (Pablo): piedra = las losas que pasó Pablo (losas_piedra.png, 3×3 losas, se repite sin costura) si están; si no, la de siempre.
	# Es el suelo de tipo 3: bajo el cristal, la tinaja, los canales y el cauce seco.
	var piedra: String = "losas_piedra.png" if ResourceLoader.exists(SUELO + "losas_piedra.png") else "stone_arriba.png"
	mat_suelo.set_shader_parameter("t_piedra", _tex(SUELO + piedra))
	# Borde de hierba (15/10, DIARIO 84): si no está la textura el shader no pinta nada (borde_fuerza = 0).
	if ResourceLoader.exists(SUELO + "hierba_borde.png"):
		mat_suelo.set_shader_parameter("t_borde", load(SUELO + "hierba_borde.png") as Texture2D)
		mat_suelo.set_shader_parameter("borde_fuerza", 1.0)
	# La Cueva: todo el suelo es roca de cueva y el de tipo «piedra» (bajo la fuente, la tinaja, la lava…), basalto. Sin borde de hierba.
	if estilo == "cueva" and ResourceLoader.exists(SUELO + "roca_cueva_arriba.png"):
		var roca: Texture2D = _tex(SUELO + "roca_cueva_arriba.png")
		for p in ["t_hierba", "t_camino", "t_tierra"]:
			mat_suelo.set_shader_parameter(p, roca)
		mat_suelo.set_shader_parameter("usa_normal_tierra", 0.0)
		mat_suelo.set_shader_parameter("borde_fuerza", 0.0)
		if ResourceLoader.exists(SUELO + "basalto_arriba.png"):
			mat_suelo.set_shader_parameter("t_piedra", _tex(SUELO + "basalto_arriba.png"))
		# 27/10: el tinte del mojado de siempre es azulado y con la luz azul de la Cueva no se leía. Aquí el mojado OSCURECE (casi neutro) y
		# brilla más: la roca mojada se distingue por oscura y lustrosa, no por el color.
		mat_suelo.set_shader_parameter("tinte_mojado", MOJADO_CUEVA_TINTE)
		mat_suelo.set_shader_parameter("espec_mojado", MOJADO_CUEVA_ESPEC)
		mat_suelo.set_shader_parameter("rug_mojado", MOJADO_CUEVA_RUG)
	mat_suelo.set_shader_parameter("celda", S)
	mat_suelo.set_shader_parameter("lado", float(_lado))
	mat_suelo.set_shader_parameter("tam_tex", S * 2.0)
	mat_suelo.set_shader_parameter("brillo", OSCURECER_SUELO)
	Albedos3D.aplicar_suelo(mat_suelo, albedos_eow)       # albedos: compresión de contraste y valor por familia del suelo
	mat_suelo.set_shader_parameter("contraste", _contraste)
	mat_suelo.set_shader_parameter("normal_suelo", _normal_suelo())
	mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
	_img_pisado = Image.create_empty(_lado, _lado, false, Image.FORMAT_R8)
	_tex_pisado = ImageTexture.create_from_image(_img_pisado)
	# El estado oficial del juego (R quemada · G mojada · B helada · A segada) y el interruptor. La textura se vuelve a pedir cada fotograma
	# (`_subir_estado_juego`): es siempre el mismo objeto salvo que el mapa cambie de tamaño; entonces la reparte al suelo, al agua y a la hierba.
	mat_suelo.set_shader_parameter("estado_eow", 1.0 if estado_suelo_eow else 0.0)
	_aplicar_joints(mat_suelo)       # joints: tiras de transición (mapa de «fuera» + tabla de pares)
	_mat_suelo = mat_suelo

	var mat_lado: StandardMaterial3D
	if estilo == "cueva" and ResourceLoader.exists(SUELO + "pared_foso_cueva.png"):
		# 23/10 (hoja D4): los costados (pared de la charca, borde del mapa, terrazas) son la pared de piedra mojada de la cueva, no la franja de tierra del Bosque.
		# La textura es 2:1 y se repite en horizontal: se estira el eje Y del triplanar para que las piedras no salgan alargadas.
		mat_lado = _mat_triplanar(SUELO + "pared_foso_cueva.png", Color(0.3, 0.33, 0.4))
		mat_lado.uv1_scale = Vector3(1.0, PARED_FOSO_ESCALA_V, 1.0) / (S * 2.0)
		mat_lado.albedo_color = mat_lado.albedo_color * PARED_FOSO_BRILLO
	else:
		mat_lado = _mat_triplanar(SUELO + "cuerpo.png", Color(0.85, 0.66, 0.5))
	var sha := Shader.new()
	sha.code = CODIGO_AGUA
	_mat_agua = ShaderMaterial.new()
	_mat_agua.shader = sha
	_mat_agua.set_shader_parameter("orilla", ImageTexture.create_from_image(_mapa_orilla()))
	_mat_agua.set_shader_parameter("campo", mat_suelo.get_shader_parameter("campo"))
	_mat_agua.set_shader_parameter("t_agua", _tex(SUELO + "water_arriba.png"))
	_mat_agua.set_shader_parameter("normal_agua", _normal_agua())
	_mat_agua.set_shader_parameter("celda", S)
	_mat_agua.set_shader_parameter("lado", float(_lado))
	_mat_agua.set_shader_parameter("tam_tex", S * 2.0)
	_mat_agua.set_shader_parameter("brillo", OSCURECER_SUELO)
	_mat_agua.set_shader_parameter("contraste", maxf(_contraste * 0.6, 1.0))
	_mat_agua.set_shader_parameter("estilizada", 1.0 if agua_estilizada else 0.0)
	_subir_estado_juego()      # el suelo y el agua reciben el estado oficial (la hierba, cuando se siembra)

	var tierra: Array[Transform3D] = []
	var agua: Array[Transform3D] = []
	var cauce: Array[Vector2i] = []
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var t := Transform3D(Basis.IDENTITY, _centro_celda(c, 0.0))
			if _letra(c) == " ":
				continue          # casilla sin pintar del nivel editable: sin suelo
			if _letra(c) == "c":
				cauce.append(c)   # 9.7: el cauce seco va aparte (hundido y con su agua lista para llenarse)
				continue
			if _es_agua(_letra(c)):
				agua.append(t)
			else:
				tierra.append(t)
	_multimalla(_malla_bloque(ALTO, mat_suelo, mat_lado), tierra)
	if agua_fisica:
		# agua filtro: el bloque del lecho lleva su propio material (cantos + cáusticas) en vez del del suelo; `aplicar_agua_filtro` lo cambia en vivo con `surface_set_material`.
		_mat_lecho_agua = LechoRio3D.crear_material(OSCURECER_SUELO)
		_mat_suelo_lecho = mat_suelo
		_malla_lecho_agua = _malla_bloque(ALTO_AGUA - Lanzador3D.LECHO_AGUA, _mat_lecho_agua if (agua_filtro and not Engine.is_editor_hint()) else mat_suelo, mat_lado)
		_multimalla(_malla_lecho_agua, agua)   # solo el lecho (el mismo de la simulación): el agua la dibuja AguaRender3D
	else:
		_multimalla(_malla_bloque(ALTO_AGUA, _mat_agua, mat_lado), agua)
	_construir_cauce(cauce, mat_lado)
	_construir_orillas()
	_mat_lado_suelo = mat_lado
	_construir_lecho_rio(agua)
	_construir_bordes_agua(mat_lado)
	_construir_bisel_mapa()
	reconstruir_bordes_cauce()      # labio cauce


## 9.7 · LECHO DEL CAUCE SECO: bloque hundido ALTO_CAUCE con la piedra del suelo oscurecida y parda (material propio) y
## guijarros aplastados de tonos tierra-gris encima. Cada casilla trae ya su bloque de agua, oculto: llenar_cauce lo sube.
## Por qué un bloque de agua por casilla y no un MultiMesh: el Juego puede llenar solo una parte (el agua avanza).
func _construir_cauce(celdas: Array[Vector2i], mat_lado: Material) -> void:
	_tapas_cauce.clear()
	for pz in _pozos_cauce.values():
		if is_instance_valid(pz):
			(pz as Node).queue_free()
	_pozos_cauce.clear()
	_estado_pozo.clear()
	_estado_abierta.clear()
	_guijarros_cauce.clear()
	_celdas_cauce = celdas.duplicate()
	_guijarros = null
	_malla_lecho_plano = null
	if celdas.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bola := SphereMesh.new()
	bola.radius = 1.0
	bola.height = 2.0
	bola.radial_segments = 8
	bola.rings = 4
	var mg := StandardMaterial3D.new()
	mg.vertex_color_use_as_albedo = true
	mg.roughness = 0.9
	bola.material = mg
	mm.mesh = bola
	var malla_agua: ArrayMesh = _malla_bloque(ALTO_AGUA, _mat_agua, mat_lado)
	for c in celdas:
		var agua := MeshInstance3D.new()
		agua.mesh = malla_agua
		agua.position = _centro_celda(c, 0.0)
		agua.visible = false
		add_child(agua)
		_agua_cauce[c] = agua
	# Tapa propia (no el shader del suelo): piedra apagada y algo parda, que se lea «seco» al lado de la hierba y del río.
	var mat_lecho: StandardMaterial3D = _mat_triplanar(SUELO + "stone_arriba.png", Color(0.5, 0.47, 0.42))
	mat_lecho.albedo_color = mat_lecho.albedo_color * Color(0.72, 0.66, 0.58)
	# Un bloque por casilla (no un MultiMesh): cada uno se oculta cuando su casilla se abre y pasa a ser pozo.
	_albedo_lecho_base = mat_lecho.albedo_color
	mat_lecho.vertex_color_use_as_albedo = true      # cauce profundo: la oclusión va en el color de vértice (las mallas sin color lo dan blanco: no cambia nada)
	_mat_lecho_cauce = mat_lecho
	_mat_falda_cauce = mat_lecho.duplicate() as StandardMaterial3D
	_mat_piedra_pozo = _mat_triplanar(SUELO + "stone_arriba.png", Color(0.5, 0.47, 0.42))
	_mat_piedra_pozo_hondo = _mat_piedra_pozo.duplicate() as StandardMaterial3D
	_mat_piedra_pozo_hondo.albedo_color = _mat_piedra_pozo.albedo_color * Color(PARED_FOSO_OSCURA, PARED_FOSO_OSCURA, PARED_FOSO_OSCURA)
	_malla_lecho_plano = _malla_bloque(ALTO_CAUCE, mat_lecho, mat_lado)
	for c in celdas:
		var tapa := MeshInstance3D.new()
		tapa.mesh = _malla_lecho_plano
		tapa.position = _centro_celda(c, 0.0)
		add_child(tapa)
		_tapas_cauce[c] = tapa
		_estado_pozo[c] = false
	_guijarros = MultiMeshInstance3D.new()
	_guijarros.multimesh = mm
	add_child(_guijarros)
	aplicar_cauce_profundo()


## cauce profundo · ¿esa casilla vecina de una `c` hace de pared (suelo, muro, terraza)? No lo son otra `c`, el agua ni el vacío.
func _pared_de_cauce(n: Vector2i) -> bool:
	var l: String = _letra(n)
	return _en_mapa(n) and l != "c" and l != " " and not _es_agua(l)


## cauce profundo · oclusión falsa: multiplicador de luz (1 = nada, menos = más oscuro) en el punto (x, z) local de la casilla `c`, según la distancia a sus lados con pared.
func _oclusion_cauce(c: Vector2i, x: float, z: float) -> float:
	var r: float = S * 0.5
	var f: float = 1.0
	for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _pared_de_cauce(c + (v as Vector2i)):
			continue
		var d: float = r - (x * float((v as Vector2i).x) + z * float((v as Vector2i).y))
		var t: float = clampf(1.0 - d / OCLUSION_ANCHO, 0.0, 1.0)
		f = minf(f, 1.0 - OCLUSION_FUERZA * t * t)
	return f


## cauce profundo · la tapa del lecho de una casilla con la oclusión en el color de vértice (rejilla de OCLUSION_REJILLA²). Los costados son los de la malla lisa.
func _malla_lecho_oscurecida(c: Vector2i) -> ArrayMesh:
	var malla: ArrayMesh = _malla_tapa_oscurecida(c, ALTO_CAUCE)
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _malla_lecho_plano.surface_get_arrays(1))
	malla.surface_set_material(1, _malla_lecho_plano.surface_get_material(1))
	return malla


## cauce profundo · solo la TAPA con la oclusión en el color de vértice, a la altura `y` (el lecho de 10 cm, o el fondo del foso con `cauce_hondo`). Una superficie.
func _malla_tapa_oscurecida(c: Vector2i, y: float) -> ArrayMesh:
	var n: int = OCLUSION_REJILLA
	var r: float = S * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_mat_lecho_cauce)
	for iz in range(n):
		for ix in range(n):
			var x0: float = -r + S * float(ix) / float(n)
			var x1: float = -r + S * float(ix + 1) / float(n)
			var z0: float = -r + S * float(iz) / float(n)
			var z1: float = -r + S * float(iz + 1) / float(n)
			for p in [[x0, z0], [x1, z0], [x1, z1], [x0, z0], [x1, z1], [x0, z1]]:
				var f: float = _oclusion_cauce(c, float(p[0]), float(p[1]))
				st.set_color(Color(f, f, f))
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(float(p[0]), float(p[1])))
				st.add_vertex(Vector3(float(p[0]), y, float(p[1])))
	return st.commit()


## cauce profundo · aplica (o quita) la lectura de profundidad del cauce seco: color del lecho y de la pared, tapas con oclusión, grava nueva y bordes. Se llama sola al cambiar el interruptor.
func aplicar_cauce_profundo() -> void:
	if _tapas_cauce.is_empty() or _malla_lecho_plano == null or _mat_lecho_cauce == null:
		return
	var p: bool = cauce_profundo
	_mat_lecho_cauce.albedo_color = _albedo_lecho_base * (Color(LECHO_CAUCE_OSCURO, LECHO_CAUCE_OSCURO, LECHO_CAUCE_OSCURO) if p else Color.WHITE)
	_mat_falda_cauce.albedo_color = _albedo_lecho_base * (Color(PARED_CAUCE_OSCURA, PARED_CAUCE_OSCURA, PARED_CAUCE_OSCURA) if p else Color.WHITE)
	for c in _tapas_cauce.keys():
		(_tapas_cauce[c] as MeshInstance3D).mesh = _malla_lecho_oscurecida(c) if p else _malla_lecho_plano
	# cauce hondo: los fosos se rehacen (fondo con oclusión o liso, pared más oscura, hondo o no) y `_sincronizar_pozos` los vuelve a poner donde toque.
	for pz in _pozos_cauce.values():
		if is_instance_valid(pz):
			(pz as Node).queue_free()
	_pozos_cauce.clear()
	for c in _tapas_cauce.keys():
		_estado_pozo[c] = false
		_estado_abierta[c] = false
		(_tapas_cauce[c] as MeshInstance3D).visible = true
	_rellenar_guijarros()
	if not _sincronizar_pozos():
		reconstruir_bordes_cauce()


## cauce profundo · los guijarros del lecho seco. Con `cauce_profundo`: pocos, pequeños, de tonos tierra-gris (srgb: el color se lee como lo escrito, no como lineal, que salía casi
## blanco) y oscurecidos por la misma oclusión que el lecho. Sin él: los 9 de antes, sin tocar. Una casilla ya abierta a cuenca los lleva al fondo del pozo (`_mover_guijarros_cauce`).
func _rellenar_guijarros() -> void:
	if _guijarros == null:
		return
	var p: bool = cauce_profundo
	var por: int = GUIJARROS_CAUCE if p else GUIJARROS_ANTES
	var mm: MultiMesh = _guijarros.multimesh
	((mm.mesh as SphereMesh).material as StandardMaterial3D).vertex_color_is_srgb = p
	mm.instance_count = _celdas_cauce.size() * por
	_guijarros_cauce.clear()
	var i: int = 0
	for c in _celdas_cauce:
		var base_guij: Array = []
		for k in range(por):
			var h: int = _hash(c.x, c.y, 40 + k)
			var off := Vector3(float(h % 97) / 96.0 - 0.5, 0.0, float((h >> 7) % 97) / 96.0 - 0.5) * S * 0.85
			var r: float = (GUIJARRO_RADIO_MIN + GUIJARRO_RADIO_VAR * float((h >> 3) % 10) / 9.0) if p else (0.1 + float((h >> 3) % 10) / 70.0)
			var largo: float = GUIJARRO_ALARGADO if p else 1.4
			var alto: float = GUIJARRO_ALTO if p else 0.45
			var giro := Basis(Vector3.UP, float(h % 360))
			var forma: Basis = (giro * Basis.from_scale(Vector3(r * largo, r * alto, r))) if p else giro.scaled(Vector3(r * largo, r * alto, r))      # cauce profundo: el óvalo gira con su ángulo (antes todos miraban a lo mismo)
			var tf_g := Transform3D(forma, _centro_celda(c, ALTO_CAUCE) + off)
			mm.set_instance_transform(i, tf_g)
			base_guij.append(tf_g)
			if p:
				var gris: float = GUIJARRO_GRIS_MIN + GUIJARRO_GRIS_VAR * float((h >> 11) % 10) / 9.0
				var f: float = _oclusion_cauce(c, off.x, off.z)
				mm.set_instance_color(i, Color(gris * GUIJARRO_TINTE.r * f, gris * GUIJARRO_TINTE.g * f, gris * GUIJARRO_TINTE.b * f))
			else:
				var gris2: float = 0.32 + 0.16 * float((h >> 11) % 10) / 9.0
				mm.set_instance_color(i, Color(gris2 * 1.05, gris2, gris2 * 0.9))
			i += 1
		_guijarros_cauce[c] = [i - por, base_guij]
	for c in _celdas_cauce:
		if bool(_estado_pozo.get(c, false)):
			_mover_guijarros_cauce(c, true)


## 13.9 · POZOS: cada 0,1 s mira qué casillas `c` están abiertas a la simulación (`Terreno3D.es_cuenca`). Abierta = pozo (PozoCauce3D, sin
## tapa, fondo en `alto_agua − LECHO_AGUA` como el lecho del río y el suelo de la simulación) y los guijarros bajan al fondo; cerrada = el lecho
## seco de siempre. Se mira por sondeo y no por señal porque quien abre (`Surtidor3D`, `Mundo3D.abrir_cauce`, las compuertas) escribe directamente
## en `Terreno3D.cauces_abiertos`. Entre dos pozos vecinos, y contra el agua de río, no se dibuja pared.
func _actualizar_pozos(delta: float) -> void:
	if _tapas_cauce.is_empty():
		return
	_t_pozos += delta
	if _t_pozos < 0.1:
		return
	_t_pozos = 0.0
	_sincronizar_pozos()
	# 16/10 (diario 97): lo que se ve y se oye mientras el pozo se llena. La marca de humedad sube con el nivel y se queda al bajar; el
	# sonido de llenado sube de tono con el nivel (de 0,7 a 1,6) y suena cada ~0,8 s mientras el agua sube.
	for c in _pozos_cauce.keys():
		if not bool(_estado_pozo.get(c, false)):
			continue
		var pz: PozoCauce3D = _pozos_cauce[c]
		var sup: float = Terreno3D.superficie_agua(c)
		var nivel: float = clampf((sup - pz.y_fondo) / maxf(pz.y_borde - pz.y_fondo, 0.01), 0.0, 1.0)
		pz.poner_nivel(sup)
		var subiendo: bool = nivel > float(_nivel_pozo.get(c, 0.0)) + 0.004 and nivel < 0.97
		_nivel_pozo[c] = nivel
		var t_s: float = float(_t_sonido_pozo.get(c, 0.0)) - 0.1
		if subiendo and t_s <= 0.0:
			Sfx.llenado(pz, nivel)
			t_s = 0.8
		_t_sonido_pozo[c] = maxf(t_s, 0.0)


## cauce hondo · ¿se dibuja la casilla `c` como foso (PozoCauce3D, sin tapa)? Una cuenca abierta a la simulación, o cualquier `c` del cauce con `cauce_hondo` (también cuando ya pasó a «~»:
## el foso sigue siendo foso, ahora con agua). Y ¿con agua? Cuenca abierta, o letra de agua (`~`) / puente (`b`) en una casilla que fue `c`.
func _hueco_de(c: Vector2i) -> bool:
	return (Terreno3D.cauce_hondo and not Terreno3D.cauces_a_ras.has(c)) or Terreno3D.es_cuenca(c)


func _con_agua_de(c: Vector2i) -> bool:
	return Terreno3D.es_cuenca(c) or (Terreno3D.cauce_hondo and not Terreno3D.cauces_a_ras.has(c) and _es_agua(_letra(c)))


## Pone al día lo que se dibuja de cada casilla `c` (tapa o foso, guijarros, bordes y paredes entre fosos vecinos) si su estado cambió desde la última vez. true = hubo cambios.
func _sincronizar_pozos() -> bool:
	var cambio: bool = false
	for c in _tapas_cauce.keys():
		var hueco: bool = _hueco_de(c)
		var agua: bool = _con_agua_de(c)
		if hueco == bool(_estado_pozo.get(c, false)) and agua == bool(_estado_abierta.get(c, false)):
			continue
		var cambio_hueco: bool = hueco != bool(_estado_pozo.get(c, false))
		_estado_pozo[c] = hueco
		_estado_abierta[c] = agua
		cambio = true
		(_tapas_cauce[c] as MeshInstance3D).visible = not hueco
		if hueco and not _pozos_cauce.has(c):
			var p := PozoCauce3D.new()
			p.position = _centro_celda(c, 0.0)
			add_child(p)
			if Terreno3D.cauce_hondo:
				p.construir(S, ALTO_AGUA - Terreno3D.LECHO_AGUA, ALTO, _mat_piedra_pozo_hondo, _mat_lecho_cauce, _malla_tapa_oscurecida(c, ALTO_AGUA - Terreno3D.LECHO_AGUA) if cauce_profundo else null)
			else:
				p.construir(S, ALTO_AGUA - Terreno3D.LECHO_AGUA, ALTO, _mat_piedra_pozo, _mat_lecho_cauce)
			_pozos_cauce[c] = p
		if _pozos_cauce.has(c):
			(_pozos_cauce[c] as Node3D).visible = hueco
		if cambio_hueco:
			_mover_guijarros_cauce(c, hueco)
	if cambio:
		reconstruir_bordes_cauce()      # labio cauce: la casilla que se abre/cierra cambia de seco a orilla (o al revés)
		for c in _pozos_cauce.keys():
			var p: PozoCauce3D = _pozos_cauce[c]
			for i in range(PozoCauce3D.LADOS.size()):
				var n: Vector2i = (c as Vector2i) + PozoCauce3D.LADOS[i]
				var sin_pared: bool = bool(_estado_pozo.get(n, false)) or _letra(n) == "~"
				p.mostrar_lado(i, not sin_pared)
	return cambio


## labio cauce · BORDE DEL CAUCE SECO. Una arista por cada lado de casilla entre suelo normal y `c` (nada entre `c` y `c`, ni hacia agua, muros o vacío).
## Se reutiliza BordePiedras3D: labio V3 con el shader del suelo (`_mat_suelo`, así el estado y las tiras de joints siguen por encima de la arista), falda y cantos.
##   · `c` CERRADA (lecho seco, 0,1 u por debajo del suelo): la pared mide 0,1, así que el labio (0,2) la cubre ENTERA y la falda (0,3) es en la práctica
##     una rampa de 0,1 sobre el lecho; por eso la falda lleva el material del LECHO (`_mat_lecho_cauce`, que es el suelo que continúa), no el costado del suelo.
##     Cantos más pequeños y escasos (2 por lado, 0,25–0,45 u): contra una zanja de 10 cm los de 0,6 u parecerían rocas.
##   · `c` ABIERTA (pozo, `_estado_pozo`): pasa a ser ORILLA de agua, igual que una casilla de tierra junto a `~`: fondo en el del pozo, falda con el material del
##     costado y cantos de serie. El labio no se tapa con el agua (está 0,04 por encima de ella) y sigue siendo la arista de arriba de la pared del pozo. Un nodo
##     por estado y se rehacen los dos cuando una casilla cambia: nunca queda un borde seco flotando sobre un pozo ni uno de pozo sobre un lecho cerrado.
##   · Sin duplicar las orillas de agua: `_construir_bordes_agua` solo mira suelo ↔ `~` y aquí solo suelo ↔ `c`; un pozo pegado a `~` no tiene arista (misma agua).
## Una malla de labio y una de falda por estado, y un MultiMesh de cantos: no hay nodos por casilla. Sin colisión.
func reconstruir_bordes_cauce() -> void:
	var secos: Array = []
	var abiertos: Array = []
	if bisel_cauce and bisel_suelo and _mat_suelo != null and _mat_lado_suelo != null and not _tapas_cauce.is_empty():
		var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var y_fondo_pozo: float = ALTO_AGUA - Terreno3D.LECHO_AGUA
		for cc in _tapas_cauce.keys():
			var c: Vector2i = cc
			var hueco: bool = bool(_estado_pozo.get(c, false))      # cauce hondo: el foso seco también baja hasta el fondo (borde de lecho, no de orilla)
			var abierta: bool = bool(_estado_abierta.get(c, false))
			for v in dirs:
				var n: Vector2i = c + (v as Vector2i)
				var l: String = _letra(n)
				if _es_agua(l) or l == "#" or l == " " or l == "c" or not _en_mapa(n) or Terreno3D.altura_en(n) > 0:
					continue
				# La casilla ALTA es la de suelo (n) y el lado bajo queda hacia la `c`: dirección -v.
				var b: Dictionary = {"c": n, "v": -(v as Vector2i), "y_alto": ALTO, "y_bajo": y_fondo_pozo if hueco else ALTO_CAUCE}
				if not bordes_blandos:
					b["solo_labio"] = true
				(abiertos if abierta else secos).append(b)
	if _bordes_cauce == null:
		_bordes_cauce = BordePiedras3D.new()
		_bordes_cauce.name = "BordesCauce"
		_bordes_cauce.ancho_labio = BORDE_LABIO_ANCHO
		_bordes_cauce.sobresale_labio = BORDE_LABIO_SOBRESALE
		_bordes_cauce.falda_arriba = 0.8         # pared de 10 cm: la falda es una rampa, no una pared (si no, banda oscura)
		_bordes_cauce.piedras_por_borde = 2
		_bordes_cauce.piedra_min = 0.25
		_bordes_cauce.piedra_max = 0.45
		add_child(_bordes_cauce)
		_bordes_cauce_abierto = BordePiedras3D.new()
		_bordes_cauce_abierto.name = "BordesCauceAbierto"
		_bordes_cauce_abierto.ancho_labio = BORDE_LABIO_ANCHO
		_bordes_cauce_abierto.sobresale_labio = BORDE_LABIO_SOBRESALE
		add_child(_bordes_cauce_abierto)
	# cauce profundo: la pared interior (falda) más oscura que el lecho, el pie del labio como pared vertical y el labio con sombra sobre el lecho. Apagado = lo de antes.
	_bordes_cauce.labio_pie_arriba = PIE_LABIO_CAUCE if cauce_profundo else BordePiedras3D.LABIO_PIE_ARRIBA
	_bordes_cauce.labio_proyecta_sombra = cauce_profundo
	# cauce hondo: la pared mide 0,94 u (no 10 cm): falda de pared (normal horizontal) y cantos de serie; el foso con agua conserva el labio con sombra.
	_bordes_cauce.falda_arriba = 0.0 if Terreno3D.cauce_hondo else 0.8
	_bordes_cauce.piedras_por_borde = 3 if Terreno3D.cauce_hondo else 2
	_bordes_cauce.piedra_min = 0.3 if Terreno3D.cauce_hondo else 0.25
	_bordes_cauce.piedra_max = 0.6 if Terreno3D.cauce_hondo else 0.45
	_bordes_cauce_abierto.labio_pie_arriba = PIE_LABIO_CAUCE if (cauce_profundo and Terreno3D.cauce_hondo) else BordePiedras3D.LABIO_PIE_ARRIBA
	_bordes_cauce_abierto.labio_proyecta_sombra = cauce_profundo and Terreno3D.cauce_hondo
	_bordes_cauce.construir(secos, S, _mat_falda_cauce if (cauce_profundo and _mat_falda_cauce != null) else _mat_lecho_cauce, _mat_suelo)
	_bordes_cauce_abierto.construir(abiertos, S, _mat_lado_suelo, _mat_suelo)


## Los 9 guijarros de una casilla: sobre el lecho (cerrada) o en el fondo del pozo (abierta).
func _mover_guijarros_cauce(c: Vector2i, abierta: bool) -> void:
	if _guijarros == null or not _guijarros_cauce.has(c):
		return
	var datos: Array = _guijarros_cauce[c]
	var mm: MultiMesh = _guijarros.multimesh
	var dy: float = (ALTO_AGUA - Terreno3D.LECHO_AGUA + 0.02 - ALTO_CAUCE) if abierta else 0.0
	for k in range((datos[1] as Array).size()):
		var tf: Transform3D = (datos[1] as Array)[k]
		tf.origin.y += dy
		mm.set_instance_transform(int(datos[0]) + k, tf)


## --- 6.16 ORILLA: transición agua → hierba ---
## En cada casilla de tierra pegada a una de agua (por sus 4 lados) se pone una franja de arena de ~0,22 casillas con el borde
## ondulado y, de vez en cuando, un par de piedrecitas: la hierba ya no pasa de golpe al bloque de agua. Todo en dos MultiMesh.
const COLOR_ARENA: Color = Color(0.86, 0.76, 0.56)
const ANCHO_ORILLA: float = 0.24         ## fracción de casilla
## 11/10 (Pablo): las franjas planas sueltas se leían como «trampolines» que sobresalen del borde del agua, por muy redondeadas que fueran.
## Apagadas: la transición la dan el suelo de arena del shader y la espuma del agua, que sí siguen la orilla. Con `true` vuelven.
const FRANJAS_ARENA: bool = false


## Franja de arena de la orilla: una «píldora» plana de 1 x 1 (el largo va en X, el grosor en Z; la escala la ensancha) con los dos
## extremos en semicírculo. El radio de los extremos (en unidades de la malla) es medio grosor medio: ANCHO_ORILLA / 2 del largo,
## así que al escalar el semicírculo sale circular. Arriba en y = 0,01 (la parte de arriba de la caja de 0,02 de antes).
func _malla_franja_redonda(segmentos: int = 12) -> ArrayMesh:
	var rx: float = clampf(ANCHO_ORILLA * 0.5, 0.05, 0.5)
	var contorno: PackedVector2Array = PackedVector2Array()
	for i in range(segmentos + 1):          # extremo +X: de -90° a +90°
		var a: float = -PI * 0.5 + PI * float(i) / float(segmentos)
		contorno.append(Vector2(0.5 - rx + rx * cos(a), 0.5 * sin(a)))
	for i in range(segmentos + 1):          # extremo -X: de 90° a 270°
		var a2: float = PI * 0.5 + PI * float(i) / float(segmentos)
		contorno.append(Vector2(-0.5 + rx + rx * cos(a2), 0.5 * sin(a2)))
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var idx := PackedInt32Array()
	vs.append(Vector3(0.0, 0.01, 0.0))
	ns.append(Vector3.UP)
	for p in contorno:
		vs.append(Vector3(p.x, 0.01, p.y))
		ns.append(Vector3.UP)
	var n: int = contorno.size()
	for i in range(n):
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % n)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return malla


func _construir_orillas() -> void:
	var franjas: Array[Transform3D] = []
	var piedras: Array[Transform3D] = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			if _es_agua(_letra(c)) or _letra(c) == "#" or _letra(c) == " " or _letra(c) == "c":
				continue          # el cauce va hundido: una franja de arena a la altura del suelo quedaría flotando
			for d in dirs:
				var v: Vector2i = d
				if not _es_agua(_letra(c + v)):
					continue
				var h: int = _hash(c.x, c.y, v.x * 3 + v.y * 5 + 11)
				var grosor: float = S * ANCHO_ORILLA * (0.8 + 0.4 * float(h % 100) / 99.0)
				var largo: float = S * (0.96 + 0.04 * float((h >> 3) % 10) / 9.0)
				# La franja está pegada al borde de la casilla que da al agua: su eje largo va a lo largo del borde.
				var centro: Vector3 = _centro_celda(c, ALTO + 0.012) + Vector3(float(v.x), 0.0, float(v.y)) * (S * 0.5 - grosor * 0.5)
				var giro: float = 0.0 if v.y != 0 else PI * 0.5
				var b := Basis(Vector3.UP, giro).scaled(Vector3(largo, 1.0, grosor))
				if FRANJAS_ARENA:
					franjas.append(Transform3D(b, centro))
				if h % 3 == 0:
					var q: Vector3 = _centro_celda(c, ALTO) + Vector3(float(v.x), 0.0, float(v.y)) * (S * 0.5 - grosor * 0.6)
					var a: Vector3 = Vector3(float(v.y), 0.0, float(v.x)) * (float((h >> 5) % 100) / 99.0 - 0.5) * S * 0.7
					var tam: float = 0.07 + 0.05 * float((h >> 9) % 10) / 9.0
					piedras.append(Transform3D(Basis(Vector3.UP, float(h % 628) / 100.0).scaled(Vector3.ONE * tam), q + a))
	if not franjas.is_empty():
		# 11/10 (Pablo): las franjas de arena eran cajas planas con las cuatro esquinas afiladas. Ahora son una «píldora» plana: lados
		# rectos y los dos extremos semicirculares (sin esquinas).
		var caja: ArrayMesh = _malla_franja_redonda()
		var m := StandardMaterial3D.new()
		m.albedo_color = COLOR_ARENA * OSCURECER_SUELO
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		caja.surface_set_material(0, m)
		_multimalla(caja, franjas)
	if not piedras.is_empty():
		var roca: Mesh = (Formas3D.instancia("piedra", Color(0.7, 0.66, 0.6), 1.0) as MeshInstance3D).mesh
		_multimalla(roca, piedras)


## --- 14.2 · Presentación del escenario (diorama, bordes blandos, lecho del río) ---

## (a) DIORAMA. Cámara ortogonal a 60°: la profundidad de un punto del suelo crece 1,73 u por cada unidad que sube en pantalla (el suelo
## se ve de lado: sen 30° arriba por cada cos 30° de profundidad), así que media pantalla cubre ≈ 0,87 × `_tam_camara` de profundidad. La
## zona nítida y la transición se miden en esa unidad, y la distancia de referencia es la del JUGADOR a la cámara (no un valor fijo):
## si la cámara se acerca o se aleja con el zoom o el seguimiento, la nitidez sigue pegada a él.
func _montar_diorama() -> void:
	_camara_dof = CameraAttributesPractical.new()
	_camara_dof.dof_blur_far_enabled = false
	_camara_dof.dof_blur_near_enabled = false      # solo el fondo: lo de delante (el borde de abajo de la pantalla) se queda nítido
	_camara.attributes = _camara_dof
	_actualizar_diorama()


## F2: la banda de tilt-shift (TiltShift3D, capa 0: por debajo del HUD). Apagada salvo que `tilt_shift` esté marcado.
func _montar_tilt_shift() -> void:
	_tilt = TiltShift3D.new()
	_tilt.encendido = tilt_shift
	add_child(_tilt)
	Posproceso3D.montar_vineta(self)    # V1: viñeta suave (capa 0, después del tilt-shift para quedar encima; el HUD sigue por encima de todo)


## F3: una sonda de reflejos que cubre el mapa entero (la sala), horneada una vez. Si ya hay una, se quita y se crea otra (así se vuelve a hornear).
func _montar_sonda() -> void:
	for s in _sondas:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_sondas.clear()
	if _sonda != null:
		_sonda.queue_free()
		_sonda = null
	if not sonda_reflejos or _lado <= 0:
		return
	if sondas_por_sala:       # agua EoW: una por sala (o bloque) con agua o hielo
		_sondas = LuzZona3D.sondas_por_cajas(self, cajas_sondas(), S)
		if not _sondas.is_empty():
			_sonda = _sondas[0]
		return
	var centro: Vector3 = _centro_celda(Vector2i(_lado / 2, _lado / 2), 3.0)
	_sonda = LuzZona3D.sonda_reflejos(self, centro, Vector3(_lado * S, 10.0, _lado * S))
	_sondas = [_sonda]


## agua EoW: las cajas (en casillas) de las sondas por sala. Las salas las ofrece el primer hijo con `salas_rects()` (los laboratorios); sin ellas, bloques de `SONDA_BLOQUE`.
## Una casilla «tiene agua» si es `~`, `b` (puente sobre agua) o `c` (cauce seco que se llena); el hielo solo existe sobre agua, así que ya está contado.
func cajas_sondas() -> Array:
	var salas: Array = []
	for h in get_children():
		if h.has_method("salas_rects"):
			salas = h.call("salas_rects")
			break
	var ancho: int = _lado
	for fila in _mapa:
		ancho = maxi(ancho, fila.length())
	return LuzZona3D.cajas_sondas(_hay_agua_sonda, ancho, _lado, salas)


func _hay_agua_sonda(c: Vector2i) -> bool:
	var l: String = _letra(c)
	return _es_agua(l) or l == "c"


## agua EoW: las sondas que hay montadas ahora (para las pruebas).
func sondas_montadas() -> Array:
	return _sondas.filter(func(s) -> bool: return is_instance_valid(s))


func _actualizar_diorama() -> void:
	if _camara_dof == null or _camara == null:
		return
	# En Compatibilidad la profundidad de campo no existe (la documentación de CameraAttributesPractical la limita a Forward+ y Mobile).
	var activo: bool = diorama and diorama_fuerza > 0.0 and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	_camara_dof.dof_blur_far_enabled = activo
	if not activo:
		return
	var ref: Vector3 = _centro(_jugador) if _jugador != null else _foco
	var adelante: Vector3 = -_camara.global_transform.basis.z
	var d: float = maxf((ref - _camara.global_position).dot(adelante), 1.0)
	var media: float = 0.87 * _tam_camara
	_camara_dof.dof_blur_far_distance = d + diorama_nitidez * media
	_camara_dof.dof_blur_far_transition = 0.6 * media
	_camara_dof.dof_blur_amount = 0.12 * diorama_fuerza


## (b) BORDES BLANDOS DEL AGUA. Falda al pie del talud (hasta el lecho, que se ve a través del agua) y anillo de cantos en el labio. Solo
## junto a `~`: el puente (`b`) no lleva ni falda ni piedras (taparían el paso), el cauce seco (`c`) ya lleva sus guijarros.
func _construir_bordes_agua(mat_lado: Material) -> void:
	if not bordes_blandos:
		return
	var y_bajo: float = (ALTO_AGUA - Lanzador3D.LECHO_AGUA) if agua_fisica else ALTO_AGUA
	var bordes: Array = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var l: String = _letra(c)
			if _es_agua(l) or l == "#" or l == " " or l == "c":
				continue
			for v in dirs:
				if _letra(c + (v as Vector2i)) == "~":
					bordes.append({"c": c, "v": v, "y_alto": ALTO, "y_bajo": y_bajo})
	_bordes = BordePiedras3D.new()
	_bordes.name = "BordesAgua"
	_bordes.ancho_labio = BORDE_LABIO_ANCHO
	_bordes.sobresale_labio = BORDE_LABIO_SOBRESALE
	add_child(_bordes)
	_bordes.construir(bordes, S, mat_lado, _mat_suelo if bisel_suelo else null)     # V3: el labio lleva el shader del suelo (la tapa continúa por encima de la arista)


## V3 · LABIO DEL BORDE DEL MAPA. Los bloques de tierra que dan al vacío (el borde del cuadrado, o una casilla « » sin suelo) enseñan una pared con
## la arista de arriba viva. Solo labio: no hay suelo bajo el que fundir una falda ni se ponen piedras. No se tocan el agua, los puentes ni el
## cauce seco (su banco ya lleva lo suyo). Las terrazas (`Terreno3D.alturas`, las pone el nivel después) llevan su propio labio en `_vigilar_alturas`;
## el de una casilla elevada en el borde del mapa (hoy ninguna) quedaría enterrado en su columna.
func _construir_bisel_mapa() -> void:
	if not bisel_suelo or _mat_suelo == null:
		return
	var bordes: Array = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var l: String = _letra(c)
			if _es_agua(l) or l == " " or l == "c":
				continue
			for v in dirs:
				var vec: Vector2i = c + (v as Vector2i)
				var fuera: bool = vec.x < 0 or vec.y < 0 or vec.y >= _lado or vec.x >= _mapa[vec.y].length() or _letra(vec) == " "
				if fuera:
					bordes.append({"c": c, "v": v, "y_alto": ALTO, "y_bajo": 0.0, "solo_labio": true})
	if bordes.is_empty():
		return
	_bordes_mapa = BordePiedras3D.new()
	_bordes_mapa.name = "BordesMapa"
	_bordes_mapa.ancho_labio = BORDE_LABIO_ANCHO
	_bordes_mapa.sobresale_labio = BORDE_LABIO_SOBRESALE
	add_child(_bordes_mapa)
	_bordes_mapa.construir(bordes, S, _mat_lado_suelo, _mat_suelo)


## V4/B2: pide la imagen del estado del juego (`Mundo3D.textura_estados()`: se rehace sola si algo cambió y es el mismo objeto de siempre) y se la da
## al suelo (`estado_juego`), al agua (`estado`, B = helado) y a la hierba. Solo vuelve a asignar los uniforms si el objeto cambió (el mapa cambió de
## tamaño, o es la primera vez). Barato: sin cambios no sube nada. La hierba, al sembrarse, la pide ella misma (`set_estado`).
func _subir_estado_juego() -> void:
	if _mat_suelo == null:
		return
	var tex: ImageTexture = Mundo3D.textura_estados()
	if tex != _tex_estado_juego:
		_tex_estado_juego = tex
		_mat_suelo.set_shader_parameter("estado_juego", tex)
		if _mat_agua != null:
			_mat_agua.set_shader_parameter("estado", tex)
		if _hierba != null:
			_hierba.set_estado_textura(tex)


## Cada 0,5 s mira si cambió `Terreno3D.alturas` (lo escribe el nivel —TerraFina3D— DESPUÉS de que la maqueta se monte, y la maqueta no pinta
## las terrazas: las pinta él) y, si cambió, rehace el borde blando de los escalones. Sondeo y no señal: es dato estático sin aviso.
func _vigilar_alturas(delta: float) -> void:
	if not bordes_blandos or _mat_lado_suelo == null:
		return
	_t_alturas += delta
	if _t_alturas < 0.5:
		return
	_t_alturas = 0.0
	var h: int = Terreno3D.alturas.hash()
	if h == _hash_alturas:
		return
	_hash_alturas = h
	var bordes: Array = []
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in Terreno3D.alturas.keys():
		var n: int = Terreno3D.altura_en(c)
		if n <= 0:
			continue
		for v in dirs:
			var vec: Vector2i = (c as Vector2i) + (v as Vector2i)
			if not _en_mapa(vec) or _letra(vec) == "#":
				continue          # el borde del mapa y los muros ya se ven por sí solos (igual que las terrazas de TerraFina3D)
			var nv: int = Terreno3D.altura_en(vec)
			if nv >= n:
				continue
			# V3: el color del labio es el de la tapa de la terraza (TerraFina3D.COLOR_TOPE, por la letra de la casilla alta, sin su variación por casilla).
			bordes.append({"c": c, "v": v, "y_alto": Terreno3D.alto_suelo + float(n) * Terreno3D.ALTO_NIVEL,
				"y_bajo": Terreno3D.alto_suelo + float(nv) * Terreno3D.ALTO_NIVEL,
				"color": TerraFina3D.COLOR_TOPE.get(_letra(c as Vector2i), TerraFina3D.COLOR_TOPE["."])})
	if _bordes_terraza == null:
		_bordes_terraza = BordePiedras3D.new()
		_bordes_terraza.name = "BordesTerraza"
		_bordes_terraza.ancho_labio = BORDE_LABIO_ANCHO
		_bordes_terraza.sobresale_labio = BORDE_LABIO_SOBRESALE
		add_child(_bordes_terraza)
	if _mat_labio_terraza == null:
		_mat_labio_terraza = StandardMaterial3D.new()          # como el de las terrazas (TerraFina3D._mat_vertices): color por vértice
		_mat_labio_terraza.vertex_color_use_as_albedo = true
		_mat_labio_terraza.roughness = 1.0
	# V7: con TerraFina3D.terrazas_shader_suelo el labio lleva el shader del suelo (igual que la tapa de la terraza); si no, el de vértices de antes.
	var mat_labio: Material = _mat_suelo if (TerraFina3D.terrazas_shader_suelo and _mat_suelo != null) else _mat_labio_terraza
	_bordes_terraza.construir(bordes, S, _mat_lado_suelo, mat_labio if bisel_suelo else null)


## (d) LECHO DEL RÍO. Con la simulación de agua el fondo era un bloque liso a ALTO_AGUA − LECHO_AGUA; con el agua más transparente
## (prof_rio 1,4) se ve entero, así que lleva guijarros de la paleta (piedras claras y oscuras con un toque de tierra mojada) y, cada
## tres casillas, un canto grande. Mismo mecanismo que los guijarros del cauce seco (9.7): un MultiMesh.
func _construir_lecho_rio(celdas: Array[Transform3D]) -> void:
	if not agua_fisica or celdas.is_empty():
		return
	_celdas_agua = celdas
	var filtro: bool = agua_filtro and not Engine.is_editor_hint()      # agua filtro: guijarros más pequeños, menos y desaturados; adornos si hay modelos
	var y_lecho: float = ALTO_AGUA - Lanzador3D.LECHO_AGUA
	var tfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	var casillas_adorno: Array = []
	var dmax: float = 0.0
	for t in celdas:
		var c := Vector2i(int(floorf(t.origin.x / S)), int(floorf(t.origin.z / S)))
		if _letra(c) != "~":
			continue          # bajo el puente (`b`) no se ve el agua ni el lecho: ahí no se esparcen guijarros
		if filtro:
			var junto_a_tierra: bool = false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _letra(c + (d as Vector2i)) != "~":
					junto_a_tierra = true
			casillas_adorno.append({"c": c, "centro": Vector3(t.origin.x, y_lecho, t.origin.z), "profunda": not junto_a_tierra})
		var n: int = 7 + (1 if _hash(c.x, c.y, 71) % 3 == 0 else 0)
		for k in range(n):
			var h: int = _hash(c.x, c.y, 80 + k)
			var f1: float = float(h % 1000) / 999.0
			var f2: float = float((h >> 10) % 1000) / 999.0
			var f3: float = float((h >> 20) % 1000) / 999.0
			var grande: bool = k == 7                # el canto grande de cada tercera casilla
			if filtro and not grande and float(k) / 6.0 >= LechoRio3D.GUIJARRO_DENSIDAD:
				continue                              # el filtro deja menos guijarros (se cuentan por k para que sea reproducible por casilla)
			var diam: float = lerpf(0.5, 0.75, f1) if grande else lerpf(0.14, 0.34, f1)
			if filtro:
				diam *= LechoRio3D.GUIJARRO_ESCALA
			if not grande:
				dmax = maxf(dmax, diam)
			var alto: float = diam * (0.55 if grande else 0.4)
			var pos := Vector3(t.origin.x + (f2 - 0.5) * S * 0.78, y_lecho + alto * 0.3, t.origin.z + (f3 - 0.5) * S * 0.78)
			tfs.append(Transform3D(Basis(Vector3.UP, float(h % 628) / 100.0).scaled(Vector3(diam, alto, diam * lerpf(0.75, 1.0, f2))), pos))
			var col: Color = Paleta3D.PIEDRA_OSCURA.lerp(Paleta3D.PIEDRA, f3)
			col = col.lerp(Paleta3D.TIERRA, 0.3 if f1 > 0.5 else 0.12)
			cols.append(LechoRio3D.color_guijarro(col) if filtro else col)
	var sat: float = 0.0
	for i in range(tfs.size()):
		sat += cols[i].s
	_lecho_rio_medida = {"n": tfs.size(), "diam_max": dmax, "sat": sat / maxf(float(tfs.size()), 1.0)}
	var previo: Node = get_node_or_null("lecho_rio")
	if previo != null:
		remove_child(previo)
		previo.queue_free()
	if _adornos_lecho != null and is_instance_valid(_adornos_lecho):
		remove_child(_adornos_lecho)
		_adornos_lecho.queue_free()
	_adornos_lecho = null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BordePiedras3D._malla_canto()
	mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		mm.set_instance_transform(i, tfs[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "lecho_rio"
	mi.multimesh = mm
	if filtro:
		mi.material_override = LechoRio3D.material_guijarro_filtro(mm.mesh.surface_get_material(0))      # los guijarros no quedan negros bajo el filtro turquesa
		mi.material_overlay = LechoRio3D.capa_causticas(Terreno3D.alto_agua)      # 27/10: la red de luz del fondo sigue sobre los guijarros
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if filtro and agua_adornos:
		# adornos agua: algas y rocas de río (ids en LechoRio3D.IDS_ALGAS / IDS_ROCAS): solo si hay modelos en arte/meshy/piezas/ o arte/suelo_meshy/; si no, null y no se pone nada.
		_adornos_lecho = LechoRio3D.construir_adornos(casillas_adorno, S, func(x: int, y: int, sal: int) -> int: return _hash(x, y, sal), Lanzador3D.LECHO_AGUA, OSCURECER_SUELO)
		if _adornos_lecho != null:
			add_child(_adornos_lecho)
			if _agua_render != null:
				_agua_render.enlazar_adornos(_adornos_lecho)       # adornos agua: las algas siguen la corriente del flow map


## agua filtro (22/10): aplica el interruptor `agua_filtro` EN VIVO (también al montar): el sombreado del agua, el material del bloque del lecho, los guijarros y los adornos.
func aplicar_agua_filtro() -> void:
	if _agua_render != null:
		_agua_render.agua_filtro = agua_filtro
	if _malla_lecho_agua != null:
		_malla_lecho_agua.surface_set_material(0, _mat_lecho_agua if (agua_filtro and not Engine.is_editor_hint()) else _mat_suelo_lecho)
	if not _celdas_agua.is_empty():
		_construir_lecho_rio(_celdas_agua)

## --- 6.16 HIELO: capa de pulido sobre el agua helada ---
## Placa translúcida y brillante, con grietas claras, y dos cristales en una esquina (como `cristal_hielo`). Se borra con la casilla.
var _placas_hielo: Dictionary = {}


## Quita la placa de una casilla (el hielo se soltó: ya es agua otra vez). La llama `_al_cambiar_casilla` cuando la casilla deja de estar helada y el
## Lanzador al soltarse el hielo de la simulación (20 s o fuego); también se puede llamar a mano.
func quitar_placa_hielo(c: Vector2i) -> void:
	if not _placas_hielo.has(c):
		return
	var raiz: Node = _placas_hielo[c]
	_placas_hielo.erase(c)
	if is_instance_valid(raiz):
		raiz.queue_free()


func _poner_placa_hielo(c: Vector2i) -> void:
	if _placas_hielo.has(c) or not _es_agua(_letra(c)):
		return
	var raiz := Node3D.new()
	raiz.position = _centro_celda(c, ALTO_AGUA + 0.02)
	add_child(raiz)
	var placa := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(S * 0.97, 0.05, S * 0.97)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.95, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.0
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	caja.material = m
	placa.mesh = caja
	placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(placa)
	var h: int = _hash(c.x, c.y, 77)
	for i in range(3):
		var g := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(S * (0.35 + 0.25 * float((h >> (i * 3)) % 10) / 9.0), 0.01, 0.025)
		var mg := StandardMaterial3D.new()
		mg.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.material = mg
		g.mesh = gm
		g.position = Vector3((float((h >> (i * 5)) % 100) / 99.0 - 0.5) * S * 0.4, 0.03, (float((h >> (i * 7 + 1)) % 100) / 99.0 - 0.5) * S * 0.4)
		g.rotation.y = float((h >> (i * 4)) % 314) / 100.0
		raiz.add_child(g)
	for i in range(2):
		var cr: MeshInstance3D = Formas3D.instancia("cristal", Color.WHITE, 0.3 + 0.12 * float(i))
		cr.position = Vector3(S * (0.28 - 0.1 * float(i)), 0.02, S * (0.3 - 0.06 * float(i)))
		raiz.add_child(cr)
	_placas_hielo[c] = raiz


## Distancia de cada casilla de agua a la tierra más cercana (0 = tierra), /4 para caber en un byte.
func _mapa_orilla() -> Image:
	var orilla := Image.create_empty(_lado, _lado, false, Image.FORMAT_R8)
	var dist: Dictionary = {}
	var cola: Array[Vector2i] = []
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			if not _es_agua(_letra(Vector2i(x, y))):
				dist[Vector2i(x, y)] = 0
				cola.append(Vector2i(x, y))
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if n.x < 0 or n.y < 0 or n.y >= _lado or n.x >= _mapa[n.y].length() or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			cola.append(n)
	for y in range(_lado):
		for x in range(_lado):
			orilla.set_pixel(x, y, Color(clampf(float(dist.get(Vector2i(x, y), 0)) / 4.0, 0.0, 1.0), 0.0, 0.0))
	# 10/10: la distancia sale por casillas (de 4 en 4 vecinos) y su contorno es un rombo: la orilla salía en picos. Se
	# amplía con interpolación cúbica para que el contorno sea curvo; el shader lee igual (solo cambia la resolución).
	orilla.resize(_lado * 4, _lado * 4, Image.INTERPOLATE_CUBIC)
	return orilla


## Normal del agua: la pintada por Pablo (suelo_meshy/agua_normal.png) si existe; si no, ruido suave.
## Relieve del suelo: suelo_meshy/suelo_normal.png si existe; si no, ruido fino convertido a normal.
func _normal_suelo() -> Texture2D:
	if ResourceLoader.exists(SUELO + "suelo_normal.png"):
		return load(SUELO + "suelo_normal.png") as Texture2D
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_octaves = 4
	n.fractal_lacunarity = 2.4
	n.fractal_gain = 0.55
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 10.0
	nt.noise = n
	return nt


func _normal_agua() -> Texture2D:
	if ResourceLoader.exists(SUELO + "agua_normal.png"):
		return load(SUELO + "agua_normal.png") as Texture2D
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 2
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n
	return nt


## Hierba con volumen encima de las casillas de hierba (y su borde ondulado). Va después del decorado
## para no crecer dentro de troncos, puestos o tótems.
func _sembrar_hierba() -> void:
	_hierba = Hierba3D.new()
	_hierba.name = "Hierba"
	_hierba.brillo = OSCURECER_SUELO
	_hierba.albedos_eow = albedos_eow       # albedos
	add_child(_hierba)
	_hierba.sembrar(Rect2(0.0, 0.0, float(_lado) * S, float(_lado) * S), ALTO, _peso_hierba, not hierba_completa, _alto_hierba)
	_hierba.set_estado(Mundo3D.textura_estados(), _tex_pisado, S, float(_lado))     # después de sembrar: es ahí donde se crean los materiales
	if not hierba_completa and _jugador != null:
		_hierba.actualizar(_jugador.position, true)     # lo que se ve al empezar, de golpe; el resto al andar


## Campo de ruido para deformar los bordes (RG), mezclar dos muestras de textura (B) y variar el tono (A).
## Ruido de valor hecho aquí (no en el shader) para que CPU y GPU vean exactamente lo mismo.
func _campo_ruido(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var celdas: float = float(_lado)
	for y in range(n):
		for x in range(n):
			var c := Vector2(float(x) + 0.5, float(y) + 0.5) / float(n) * celdas
			var r: float = _vruido(c * 1.7, 0) * 0.67 + _vruido(c * 4.3, 1) * 0.33
			var g: float = _vruido(c * 1.7, 2) * 0.67 + _vruido(c * 4.3, 3) * 0.33
			var b: float = _vruido(c * 0.6, 4)
			var a: float = _vruido(c * 0.35, 5) * 0.7 + _vruido(c * 1.1, 6) * 0.3
			img.set_pixel(x, y, Color(r, g, b, a))
	return img


## Ruido de valor: interpola números al azar puestos en una rejilla.
func _vruido(p: Vector2, sal: int) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f: Vector2 = p - Vector2(i)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a: float = _azar(i, sal)
	var b: float = _azar(i + Vector2i(1, 0), sal)
	var c: float = _azar(i + Vector2i(0, 1), sal)
	var d: float = _azar(i + Vector2i(1, 1), sal)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


func _azar(i: Vector2i, sal: int) -> float:
	return float(_hash(i.x, i.y, sal + 40) % 10007) / 10006.0


## Lectura bilineal de una imagen como la hace la GPU (centros de texel), con o sin repetición.
func _bilineal(img: Image, uv: Vector2, repetir: bool) -> Color:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var p := Vector2(uv.x * float(w) - 0.5, uv.y * float(h) - 0.5)
	var i := Vector2i(floori(p.x), floori(p.y))
	var f: Vector2 = p - Vector2(i)
	var res := Color(0, 0, 0, 0)
	for k in range(4):
		var o := Vector2i(k % 2, floori(float(k) / 2.0))
		var q: Vector2i = i + o
		if repetir:
			q = Vector2i(posmod(q.x, w), posmod(q.y, h))
		else:
			q = Vector2i(clampi(q.x, 0, w - 1), clampi(q.y, 0, h - 1))
		var peso: float = (f.x if o.x == 1 else 1.0 - f.x) * (f.y if o.y == 1 else 1.0 - f.y)
		res += img.get_pixelv(q) * peso
	return res


## Cuánta hierba hay en un punto del mundo (0..1): lo mismo que pinta el shader del suelo.
## Nada en el agua ni dentro de casillas ocupadas por decorado (salvo los muros de árboles).
func _peso_hierba(x: float, z: float) -> float:
	var celda := Vector2i(floori(x / S), floori(z / S))
	var l: String = _letra(celda)
	if _es_agua(l) or (_bloqueadas.has(celda) and l != "#") or _sin_hierba.has(celda):
		return 0.0
	var c := Vector2(x, z) / S
	var r: Color = _bilineal(_img_campo, c / float(_lado), true)
	var uvm: Vector2 = (c + Vector2(r.r - 0.5, r.g - 0.5) * 2.0 * 0.45) / float(_lado)
	var e: float = 0.16
	if _img_zona_v != null:
		# Solo ZONA_V: el mismo borde ondulado de siempre, pero el mapa solo tiene esas casillas.
		return smoothstep(0.5 - e, 0.5 + e, _bilineal(_img_zona_v, uvm, false).r)
	var w0: Color = _bilineal(_img_mapa, uvm, false)
	var wr: float = smoothstep(0.5 - e, 0.5 + e, w0.r)
	var tot: float = wr + smoothstep(0.5 - e, 0.5 + e, w0.g) + smoothstep(0.5 - e, 0.5 + e, w0.b) \
		+ smoothstep(0.5 - e, 0.5 + e, w0.a)
	if tot < 0.05:
		return w0.r
	return wr / tot


func _tex(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	_avisos.append("falta " + ruta.get_file())
	return null


func _mat_triplanar(ruta: String, color_si_falta: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t: Texture2D = _tex(ruta)
	if t != null:
		m.albedo_texture = t
		var brillo_bloque: float = OSCURECER_SUELO * Albedos3D.valor_bloque(ruta, albedos_eow)      # albedos: el VALOR de su familia (el contraste no se puede tocar en un StandardMaterial3D)
		m.albedo_color = Color(brillo_bloque, brillo_bloque, brillo_bloque)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / (S * 2.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.albedo_color = color_si_falta
	return m


## Un bloque de una casilla: tapa (material propio) y cuatro costados (material de tierra).
func _malla_bloque(h: float, mat_tapa: Material, mat_lado: Material) -> ArrayMesh:
	var r: float = S * 0.5
	var malla := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_tapa)
	_quad(st, Vector3(-r, h, -r), Vector3(r, h, -r), Vector3(r, h, r), Vector3(-r, h, r), Vector3.UP)
	st.commit(malla)
	var sl := SurfaceTool.new()
	sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	sl.set_material(mat_lado)
	_quad(sl, Vector3(r, 0, r), Vector3(-r, 0, r), Vector3(-r, h, r), Vector3(r, h, r), Vector3(0, 0, 1))
	_quad(sl, Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(r, h, r), Vector3(r, h, -r), Vector3(1, 0, 0))
	_quad(sl, Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, h, -r), Vector3(-r, h, -r), Vector3(0, 0, -1))
	_quad(sl, Vector3(-r, 0, r), Vector3(-r, 0, -r), Vector3(-r, h, -r), Vector3(-r, h, r), Vector3(-1, 0, 0))
	sl.commit(malla)
	return malla


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z))
		st.add_vertex(v as Vector3)


func _multimalla(malla: Mesh, transformaciones: Array[Transform3D]) -> void:
	if transformaciones.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla
	mm.instance_count = transformaciones.size()
	for i in range(transformaciones.size()):
		mm.set_instance_transform(i, transformaciones[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)


## --- Decorado: bibliotecas de Meshy ---

func _cargar_bibliotecas() -> void:
	for ruta in rutas_piezas_sueltas() + BIBLIOTECAS:
		var r: String = String(ruta)
		if not ResourceLoader.exists(r):
			_avisos.append("falta " + r.get_file())
			continue
		var escena: PackedScene = load(r) as PackedScene
		if escena != null:
			_bibliotecas.append(escena.instantiate() as Node3D)


## Los GLB de meshy/piezas/ (piezas regeneradas, una por archivo, con el nodo llamado como su id).
static func rutas_piezas_sueltas() -> Array:
	var res: Array = []
	if not DirAccess.dir_exists_absolute(CARPETA_PIEZAS):
		return res
	for f in DirAccess.get_files_at(CARPETA_PIEZAS):
		var nombre: String = String(f).trim_suffix(".import").trim_suffix(".remap")
		if nombre.get_extension().to_lower() == "glb" and not res.has(CARPETA_PIEZAS + nombre):
			res.append(CARPETA_PIEZAS + nombre)
	res.sort()
	return res


## El id que se usa de verdad: la sustituta si existe en alguna biblioteca.
func _id_real(id: String) -> String:
	var nuevo: String = String(SUSTITUTAS.get(id, ""))
	if nuevo != "" and _hay_pieza(nuevo):
		# Una regenerada suelta con el id viejo (meshy/piezas/<id>.glb) gana a la sustituta.
		if _hay_pieza(id) and _en_piezas_sueltas(id):
			return id
		return nuevo
	return id


func _hay_pieza(id: String) -> bool:
	for b in _bibliotecas:
		if b.find_child(id, true, false) is Node3D:
			return true
	return false


func _en_piezas_sueltas(id: String) -> bool:
	for b in _bibliotecas:
		if String(b.scene_file_path).begins_with(CARPETA_PIEZAS) and b.find_child(id, true, false) is Node3D:
			return true
	return false


## Copia de una pieza escalada a su medida, con la base en y = 0. null si no está en ninguna biblioteca.
func _pieza(id: String) -> Node3D:
	# 12/10: modelo suelto `meshy/piezas/<id>.glb` (p. ej. el cristal de la fuente eléctrica): se usa tal cual, sin depender del nombre del nodo.
	var suelto: String = "res://arte/meshy/piezas/" + id + ".glb"
	if ResourceLoader.exists(suelto):
		var escena_suelta: PackedScene = load(suelto) as PackedScene
		if escena_suelta != null:
			var suelto_n: Node3D = escena_suelta.instantiate() as Node3D
			suelto_n.rotation.y = deg_to_rad(float(Pieza3D.GIRO_MODELO.get(id, 0.0)))      # giro por modelo (ver Pieza3D.GIRO_MODELO; el cristal, a 0)
			return _a_paleta(_normalizar(suelto_n, id), id)
	for b in _bibliotecas:
		var n: Node = b.find_child(id, true, false)
		if n != null and n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			return _a_paleta(_normalizar(copia, id), id)
	if not _avisos.has("sin pieza " + id):
		_avisos.append("sin pieza " + id)
	return null


## 14.2 (c): las piezas de Meshy que se salen de la paleta se tiñen hacia ella (Paleta3D.PIEZAS: lo medido y a qué color se acercan).
func _a_paleta(n: Node3D, id: String) -> Node3D:
	if n != null:
		var t: Color = Paleta3D.tinte_de_pieza(id)
		if t != Color.WHITE:
			Paleta3D.tintar(n, t)
	return n


func _normalizar(modelo: Node3D, id: String) -> Node3D:
	var caja: AABB = _caja(modelo, Transform3D.IDENTITY)
	var raiz := Node3D.new()
	raiz.add_child(modelo)
	if caja.size.y <= 0.0001:
		return raiz
	var f: float = 1.0
	if MEDIDA_ANCHO.has(id):
		f = float(MEDIDA_ANCHO[id]) / maxf(caja.size.x, caja.size.z)
	else:
		f = float(MEDIDA.get(id, 1.0)) / caja.size.y
	modelo.scale *= f
	var cx: float = caja.position.x + caja.size.x * 0.5
	var cz: float = caja.position.z + caja.size.z * 0.5
	modelo.position = -Vector3(cx, caja.position.y, cz) * f
	if PLANAS.has(id):
		# Pieza plana: se entierra salvo un grosor fijo, sea cual sea el que traiga la malla (placa 0,05, baldosa 0,04).
		var grosor: float = float(PLANAS[id])
		var alto_final: float = caja.size.y * f
		if alto_final > grosor:
			modelo.position.y -= alto_final - grosor
	return raiz


func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Pone una pieza en una casilla, algo desplazada, girada y con un tamaño variado para que no marque la rejilla.
func _poner(id_pedido: String, c: Vector2i, y: float, bloquea: bool, variar: bool = true, giro_fijo: float = -1.0) -> Node3D:
	var id: String = _id_real(id_pedido)
	var p: Vector3 = _centro_celda(c, y if PLANAS.has(id) else y - HUNDIR)
	var h: int = _hash(c.x, c.y, id_pedido.length())
	var escala: float = 1.0
	if variar:
		p += Vector3(float(h % 61 - 30) / 100.0, 0.0, float((h >> 6) % 61 - 30) / 100.0) * S * 0.5
		escala = 0.88 + float(h % 25) / 100.0
	var giro: float = float(_giros[c]) if _giros.has(c) else (giro_fijo if giro_fijo >= 0.0 else float(h % 360))
	_registro.append([id_pedido, c, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)).scaled(Vector3.ONE * escala), p), bloquea,
		"marcador" if _en_marcador else "decor"])
	if _modo_escena or (_modo_nivel and not _en_marcador):
		return null         # el nivel viene del .tscn: lo coloca _instanciar_escena (y de ahí sale qué bloquea)
	if bloquea:
		_bloqueadas[c] = true
	var t_pieza := Transform3D(Basis(Vector3.UP, deg_to_rad(giro)).scaled(Vector3.ONE * escala), p)
	if _en_marcador and _marca_tf.has(c):
		# 13/10: el marcador tal cual (posición, giro y escala), como lo dibuja el editor. También en los lotes: el decorado
		# va por lotes (decorado_por_lotes) y antes el lote se llenaba con el centro de la casilla, sin la escala del marcador.
		t_pieza = _marca_tf[c]
	if decorado_por_lotes:
		if _plantilla(id).is_empty():
			return null
		if not _lotes.has(id):
			_lotes[id] = []
		(_lotes[id] as Array).append(t_pieza)
		if SOMBRA_CONTACTO.has(id):
			var r: float = float(SOMBRA_CONTACTO[id]) * escala
			_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(t_pieza.origin.x, Y_DECAL - 0.005, t_pieza.origin.z)))
		return null
	var n: Node3D = _pieza(id)
	if n == null:
		return null
	n.transform = t_pieza
	_props.add_child(n)
	return n


## 13/10: la piedra del canal va donde el marcador está en el editor (posición, giro y escala). Material original (gris).
## Antes se ponía en el centro de la casilla y sin escala, así que no coincidía con lo que se veía en Nivel_Bosque.
func _piedra_canal(n: Node3D, c: Vector2i) -> void:
	if _canal_tf.has(c):
		var t: Transform3D = _canal_tf[c]
		n.transform = Transform3D(t.basis, Vector3(t.origin.x, n.position.y, t.origin.z))


## 13/10: dónde está el marcador de la casilla `c` en el editor (su posición real), o el centro de la casilla a la altura `y`
## si no hay marcador (mapa de letras). Para que personajes y telarañas salgan donde se ven en Nivel_Bosque.
func _pos_marca(c: Vector2i, y: float) -> Vector3:
	if _marca_tf.has(c):
		var o: Vector3 = (_marca_tf[c] as Transform3D).origin
		return Vector3(o.x, y, o.z)
	return _centro_celda(c, y)


## 13/10: centro de una casilla de canal para el agua: el del marcador (dentro de su casilla) o el centro de la casilla.
func _canal_centro(c: Vector2i) -> Vector3:
	var centro: Vector3 = _centro_celda(c, ALTO)
	if _canal_tf.has(c):
		var t: Transform3D = _canal_tf[c]
		centro.x = t.origin.x
		centro.z = t.origin.z
	return centro


## --- Objetos que reaccionan a los hechizos (Reactivo3D, tarea 4.7) ---

## Pone un Reactivo3D con la pieza de Meshy de visual (ya no va a lotes: hace falta como nodo para tintarla).
func _reactivo_pieza(tipo: String, id_pedido: String, c: Vector2i, y: float, bloquea: bool, variar: bool = true,
		giro_fijo: float = -1.0, elemento: String = "", encendida: bool = false) -> Reactivo3D:
	var raiz: Node3D = _pieza(_id_real(id_pedido))
	if raiz == null:
		return null
	var modelo: Node3D = raiz.get_child(0) as Node3D
	raiz.remove_child(modelo)
	raiz.free()
	var p: Vector3 = _centro_celda(c, y if PLANAS.has(_id_real(id_pedido)) else y - HUNDIR)
	var h: int = _hash(c.x, c.y, id_pedido.length())
	var escala: float = 1.0
	if variar:
		p += Vector3(float(h % 61 - 30) / 100.0, 0.0, float((h >> 6) % 61 - 30) / 100.0) * S * 0.5
		escala = 0.88 + float(h % 25) / 100.0
	if tipo == "surtidor" and _desvios.has(c):
		var dv: Vector2 = _desvios[c]          # la tinaja se queda donde la pusiste dentro de la casilla (marcador del nivel)
		p += Vector3(dv.x, 0.0, dv.y)
	var giro: float = float(_giros[c]) if _giros.has(c) else (giro_fijo if giro_fijo >= 0.0 else float(h % 360))
	_registro.append([id_pedido, c, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), p), bloquea, "marcador"])    # solo el giro, para hornear
	if bloquea:
		_bloqueadas[c] = true
	# Sombra de contacto solo de los que se quedan (tótem, fogata, brasero); seto, tronco y telaraña se consumen.
	if (tipo == "totem" or tipo == "fogata" or tipo == "brasero") and SOMBRA_CONTACTO.has(_id_real(id_pedido)):
		var rs: float = float(SOMBRA_CONTACTO[_id_real(id_pedido)]) * escala
		_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rs * 2.0, 1.0, rs * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
	var r: Reactivo3D = _nuevo_reactivo(tipo, c, p, modelo, elemento)
	if _marca_tf.has(c):
		r.transform = _marca_tf[c]     # 13/10: el marcador tal cual, como en el editor (sin variación aleatoria ni desvíos extra)
	else:
		r.scale = Vector3.ONE * escala
		r.rotation_degrees = Vector3(0.0, giro, 0.0)
	r.start_lit = encendida
	_props.add_child(r)
	return r


func _nuevo_reactivo(tipo: String, c: Vector2i, p: Vector3, visual: Node3D, elemento: String) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.name = "reactivo_" + tipo
	if visual != null:
		r.add_child(visual)         # primero: el prerender saca el id de la primera hija
	r.preparar(tipo, c, elemento, _fx, visual)
	r.position = p
	r.hierba_cerca = _hierba_cerca
	r.consumido.connect(_al_consumir)
	r.activado.connect(_al_activar)
	_reactivos.append(r)
	return r


## Modelos de la telaraña (Pablo, 7/10, Tripo). Cada GLB trae DOS piezas lado a lado, que se separan al cargar por el signo de x:
##   telarana_red.glb:  x < 0 la red sana (blanca) · x > 0 la red ardiendo (brasas naranjas). 1 x 0,45 de ancho y alto.
##   telarana_base.glb: x < 0 el tronco seco sobre la roca con musgo (1 de alto) · x > 0 un tronco fino suelto (0,66).
## La BASE es decorado que se queda (la red se quema, los troncos no); la RED es el visual del Reactivo3D, con dos hijas
## "sana" y "ardiendo" que el reactivo alterna al prender y apagar.
const TELARANA_RED: String = "res://arte/meshy/telarana/telarana_red.glb"
const TELARANA_BASE: String = "res://arte/meshy/telarana/telarana_base.glb"
const TELARANA_ESCALA_RED: float = 3.9       ## la red sana mide 0,5 → 1,95 u: cubre la casilla entre los dos troncos
const TELARANA_ESCALA_BASE: float = 2.1      ## el tronco grande mide 1,0 → 2,1 u (el alto del cuerpo de la telaraña es 2)
static var _tel_mallas: Dictionary = {}      ## "sana" | "ardiendo" | "tronco" | "palo" -> [Mesh, AABB de la parte]
static var _tel_probado: bool = false


func _cargar_telarana() -> bool:
	return Pieza3D.telarana_cargar()      # 13/10: el código vive en Pieza3D (lo usa también el marcador `r` del editor)


static func _malla_de_glb(ruta: String) -> Mesh:
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return null
	var raiz: Node = ps.instantiate()
	var mi: MeshInstance3D = raiz as MeshInstance3D
	if mi == null:
		var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
		mi = l[0] as MeshInstance3D if not l.is_empty() else null
	var m: Mesh = mi.mesh if mi != null else null
	raiz.free()
	return m


## [Mesh, AABB de la parte]: los triángulos de `malla` cuyo centro tiene x < 0 (`izquierda`) o x >= 0. Conserva UV y material.
static func _mitad_malla(malla: Mesh, izquierda: bool) -> Array:
	var res := ArrayMesh.new()
	var caja := AABB()
	var hay: bool = false
	for si in range(malla.get_surface_count()):
		var arr: Array = malla.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nuevo := PackedInt32Array()
		var t: int = 0
		while t + 2 < idx.size():
			var mx: float = (v[idx[t]].x + v[idx[t + 1]].x + v[idx[t + 2]].x) / 3.0
			if (mx < 0.0) == izquierda:
				for k in range(3):
					nuevo.append(idx[t + k])
					# La AABB de la parte se mide a mano: la del ArrayMesh cuenta TODOS los vértices, también los de la otra mitad.
					caja = AABB(v[idx[t + k]], Vector3.ZERO) if not hay else caja.expand(v[idx[t + k]])
					hay = true
			t += 3
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(si))
	return [res, caja]


## Una parte de la telaraña centrada en x/z, apoyada en y = 0 (si `al_suelo`) y escalada.
func _parte_telarana(clave: String, escala_parte: float, al_suelo: bool) -> MeshInstance3D:
	return Pieza3D.telarana_parte(clave, escala_parte, al_suelo)


## La telaraña: la red (reactivo, arde y se va) entre dos troncos (decorado, se quedan). Sin los modelos, la de antes:
## hilos 3D (Formas3D "telarana") en un plano de pie, radio 1.
func _poner_telarana(c: Vector2i) -> void:
	if _cargar_telarana():
		var red := Node3D.new()
		red.name = "telarana"
		var sana: MeshInstance3D = _parte_telarana("sana", TELARANA_ESCALA_RED, false)
		var ardiendo: MeshInstance3D = _parte_telarana("ardiendo", TELARANA_ESCALA_RED, false)
		ardiendo.visible = false
		for h in [sana, ardiendo]:
			var mh: MeshInstance3D = h
			mh.position.y += 1.15
			mh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			red.add_child(mh)
		# Giro y escala del marcador (nivel .tscn): se aplican a la red y a los troncos, no al Reactivo3D, para que su caja
		# de colisión siga siendo la de una casilla (la telaraña bloquea su casilla, la estires o no).
		var giro_t: float = deg_to_rad(float(_giros.get(c, 0.0)))
		var esc_t: Vector3 = _escalas.get(c, Vector3.ONE)
		red.rotation.y = giro_t
		red.scale = esc_t
		var rt: Reactivo3D = _nuevo_reactivo("telarana", c, _pos_marca(c, ALTO), red, "")
		_props.add_child(rt)
		# Los troncos, a los lados de la red (en x, el plano de la red es XY) y un poco hacia atrás.
		var base := Node3D.new()
		base.name = "telarana_base"
		base.position = _pos_marca(c, ALTO)
		base.rotation.y = giro_t
		base.scale = esc_t
		for tr in Pieza3D.telarana_troncos():       # los mismos troncos que dibuja el marcador `r` en el editor
			base.add_child(tr as Node3D)
		_props.add_child(base)
		return
	var s3: MeshInstance3D = Formas3D.instancia("telarana", Color(0.93, 0.93, 0.97))
	s3.name = "telarana"
	s3.position = Vector3(0.0, 1.0, 0.0)
	var r: Reactivo3D = _nuevo_reactivo("telarana", c, _centro_celda(c, ALTO), s3, "")
	_props.add_child(r)


## 11/10 (Pablo: «siempre debe ser cruzable»): el puente de una casilla `b` es la pieza `puente_runico` (Meshy «Ancient Runestone
## Bridge», el tramo largo con arco de la lámina de 4 piezas). No bloquea: la casilla `b` se pisa siempre (Lanzador3D.y_pies la pone a
## ALTO_AGUA + 0,12, y ahí se deja la cubierta del puente). El paso del puente va por el eje Z del modelo: se gira 90° cuando el
## agua sigue hacia el norte o el sur (el río corre de norte a sur y el puente lo cruza de este a oeste).
## CUBIERTA_PUENTE: alto de la cubierta, en fracción del largo del modelo (medido sobre la malla: 0,060 de 0,295).
const PUENTE_FIJO: String = "puente_runico"
const CUBIERTA_PUENTE: float = 0.203


func _poner_puente_fijo(c: Vector2i) -> void:
	var n: Node3D = _pieza(PUENTE_FIJO)
	if n == null:
		_poner("puente", c, ALTO_AGUA + 0.05, false, false, 90.0)      # sin el modelo nuevo: el puente de antes, también fijo
		return
	var largo: float = float(MEDIDA_ANCHO.get(PUENTE_FIJO, S))
	var rio_ns: bool = _es_agua(_letra(c + Vector2i(0, 1))) or _es_agua(_letra(c + Vector2i(0, -1)))
	n.name = "puente_%d_%d" % [c.x, c.y]
	n.position = _centro_celda(c, ALTO_AGUA + 0.12 - largo * CUBIERTA_PUENTE)
	n.rotation.y = deg_to_rad(90.0 if rio_ns else 0.0)
	_props.add_child(n)


## El puente plegable de la cámara de rayo: levantado contra la orilla oeste (bloquea la casilla) hasta que lo tiende el
## tótem de rayo. La bisagra es el borde oeste de la casilla.
func _poner_puente(c: Vector2i) -> void:
	var raiz: Node3D = _pieza(_id_real("puente"))
	if raiz == null:
		return
	var modelo: Node3D = raiz.get_child(0) as Node3D
	raiz.remove_child(modelo)
	raiz.free()
	var cuerpo := Node3D.new()
	cuerpo.name = "puente"
	cuerpo.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	cuerpo.position = Vector3(S * 0.5, 0.0, 0.0)
	cuerpo.add_child(modelo)
	var bisagra: Vector3 = _centro_celda(c, ALTO_AGUA + 0.05) - Vector3(S * 0.5, 0.0, 0.0)
	_bloqueadas[c] = true
	var r: Reactivo3D = _nuevo_reactivo("puente", c, bisagra, cuerpo, "")
	_props.add_child(r)


## El tótem de rayo tiende el puente (nivel_base._on_interruptor).
func _enlazar_reactivos() -> void:
	var puente: Reactivo3D = null
	for r in _reactivos:
		if r.tipo == "puente":
			puente = r
	for r in _reactivos:
		if r.tipo == "totem" and r.elemento == "rayo" and puente != null:
			r.activado.connect(func(_t: String, _e: String) -> void: puente.tender())
	# 13/10 (Pablo): el tótem de rayo es el final del puzzle: al activarse la tinaja deja de echar agua (el totem ya queda activo
	# para siempre: `activo` es true y `spell_reacts` devuelve false, así que no vuelve a reaccionar).
	for r in _reactivos:
		if r.tipo == "totem" and r.elemento == "rayo":
			r.activado.connect(func(_t: String, _e: String) -> void: _parar_tinajas())


func _parar_tinajas() -> void:
	for r in _reactivos:
		if r.tipo == "surtidor":
			r.dejar_de_verter()


## Bloqueo / desbloqueo EN JUEGO de una casilla (tierra que se solidifica, hielo, puente, puerta…): siempre por aquí y no
## tocando `_bloqueadas` a mano. Por qué: con el nivel en .tscn la solidez la contesta la fuente de colisión del Lanzador
## (6.10) y esta se enteraría de los cambios solo a través de `bloquear_celda` / `liberar_celda`. El diccionario se sigue
## manteniendo porque la hierba, los NPC y el reparto de objetos lo leen.
func _bloquear(c: Vector2i) -> void:
	_bloqueadas[c] = true
	if Terreno3D.mundo_s == self:
		Lanzador3D.bloquear_celda(c)


func _liberar(c: Vector2i) -> void:
	_bloqueadas.erase(c)
	if Terreno3D.mundo_s == self:
		Lanzador3D.liberar_celda(c)


func _al_consumir(c: Vector2i) -> void:
	_liberar(c)


func _al_activar(tipo: String, _elemento: String) -> void:
	if tipo == "puente":
		for r in _reactivos:
			if is_instance_valid(r) and r.tipo == "puente":
				_liberar(r.celda)


## Lo que el fuego de un objeto hace a la hierba (combustible.gd contagia a TODO lo que arde a ≤ 110 px cada 0,8 s):
## prende la hierba fina o crecida de alrededor, y con viento solo la de su cono.
func _hierba_cerca(pos: Vector3, radio: float, viento: Vector3) -> void:
	var c0: Vector2i = _celda_de(pos)
	var r: int = ceili(radio / S)
	for y in range(c0.y - r, c0.y + r + 1):
		for x in range(c0.x - r, c0.x + r + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q) or not _es_hierba(q):
				continue
			var d: Vector3 = _centro_celda(q, pos.y) - pos
			d.y = 0.0
			if d.length() > radio:
				continue
			if viento != Vector3.ZERO and d.length() > 0.01 and d.normalized().dot(viento.normalized()) < 0.3:
				continue
			var f: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
			if f == 0 or f == Fase.CRECIDA:
				_poner_fase(q, Fase.PRENDIENDO)


## El objeto que arde más cercano al centro de una casilla de hierba, si el frente de contagio (en casillas) lo toca.
func _objeto_al_alcance(c: Vector2i, frente: float) -> Reactivo3D:
	var mejor: Reactivo3D = null
	var dm: float = frente
	var centro: Vector3 = _centro_celda(c, ALTO)
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or not o.can_burn():
			continue
		var d: Vector3 = o.global_position - centro
		d.y = 0.0
		var dc: float = d.length() / S
		if dc <= dm:
			dm = dc
			mejor = o
	return mejor


## Los tags de cada elemento (contrato on_spell_hit, diario 2026-10-06 00:50). El Lanzador3D usará los .tres del 2D.
const TAGS_ELEMENTO: Dictionary = {
	"fuego": ["fuego", "calor"], "agua": ["agua"], "tierra": ["tierra"], "viento": ["viento"],
	"rayo": ["rayo", "electrico"], "hielo": ["hielo", "frio"],
}


## Lo que hará el Lanzador3D (4.1) con CAPA_REACTIVO: avisa a los objetos reactivos de la casilla del impacto. Mientras
## el Lanzador no exista, F1–F6 pasan por aquí para poder probar los objetos.
func _golpear_objetos(elemento: String, punto: Vector3) -> void:
	if externo or not objetos_reactivos:    # con Lanzador3D (externo) los golpes llegan por on_spell_hit
		return
	var runa := RuneData.new()
	runa.display_name = elemento
	var tags: Array[String] = []
	for t in TAGS_ELEMENTO.get(elemento, []):
		tags.append(String(t))
	runa.tags = tags
	Lanzador3D.ultimo_impacto = punto
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or not is_instance_valid(o) or o.collision_layer == 0:
			continue
		var d: Vector3 = o.global_position - punto
		d.y = 0.0
		if d.length() > S * 0.6:
			continue
		if o.spell_reacts(runa, _dir_hechizo):
			o.on_spell_hit(runa, _dir_hechizo)
	Lanzador3D.ultimo_impacto = Vector3.INF


## Las mallas de una pieza ya medida (como la deja _pieza), con su transformación respecto a la base.
func _plantilla(id: String) -> Array:
	if _plantillas.has(id):
		return _plantillas[id]
	var res: Array = []
	var n: Node3D = _pieza(id)
	if n != null:
		_mallas_de(n, Transform3D.IDENTITY, res)
		n.free()
	for parte in res:
		var malla: Mesh = parte[0] as Mesh
		if recortar_toldo and id == "puesto_mercado":
			malla = Ocluso3D.recortar_toldo(malla)
		if transparencia_jugador:
			malla = Ocluso3D.malla_con_hueco(malla)
			if parte[2] != null:
				parte[2] = Ocluso3D.convertir(parte[2] as Material)
			if viento_decorado > 0.0 and VIENTO_DECORADO.has(id):
				var fuerza: float = float(VIENTO_DECORADO[id]) * viento_decorado
				for i in range(malla.get_surface_count()):
					Ocluso3D.poner_viento(malla.surface_get_material(i), fuerza, malla)
				if parte[2] != null:
					Ocluso3D.poner_viento(parte[2] as Material, fuerza, malla)
		parte[0] = malla
	_plantillas[id] = res
	return res


func _mallas_de(n: Node, acum: Transform3D, res: Array) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n as MeshInstance3D
		var malla: Mesh = mi.mesh
		# Materiales puestos en el nodo (no en la malla): se copian a una malla propia para el MultiMesh.
		var con_nodo: bool = false
		for i in range(malla.get_surface_count()):
			if mi.get_surface_override_material(i) != null:
				con_nodo = true
		if con_nodo:
			malla = malla.duplicate() as Mesh
			for i in range(malla.get_surface_count()):
				var m: Material = mi.get_surface_override_material(i)
				if m != null:
					malla.surface_set_material(i, m)
		res.append([malla, t, mi.material_override])
	for h in n.get_children():
		_mallas_de(h, t, res)


## Un MultiMesh por pieza, malla y TROZO del mapa (BLOQUE_LOTE x BLOQUE_LOTE): centenares de nodos -> unas
## decenas de llamadas, y cada trozo con su caja para que Godot no dibuje (ni sombree) lo que queda fuera de cámara.
const BLOQUE_LOTE: float = S * 7.0

func _construir_lotes() -> void:
	for id in _lotes:
		var trozos: Dictionary = {}
		for t in (_lotes[id] as Array):
			var o: Vector3 = (t as Transform3D).origin
			var k := Vector2i(floori(o.x / BLOQUE_LOTE), floori(o.z / BLOQUE_LOTE))
			if not trozos.has(k):
				trozos[k] = []
			(trozos[k] as Array).append(t)
		for k in trozos:
			var copias: Array = trozos[k]
			for parte in _plantilla(String(id)):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = parte[0] as Mesh
				mm.instance_count = copias.size()
				var local: Transform3D = parte[1]
				for i in range(copias.size()):
					mm.set_instance_transform(i, (copias[i] as Transform3D) * local)
				var mi := MultiMeshInstance3D.new()
				mi.name = "lote_%s_%d_%d" % [String(id), k.x, k.y]
				mi.multimesh = mm
				if SIN_SOMBRA.has(String(id)):
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if parte[2] != null:
					mi.material_override = parte[2] as Material
				_props.add_child(mi)
				_n_lotes += 1
				# Bloque 4 EoW: la sombra de árboles y pinos la proyecta una copia REDUCIDA (MallaReducida3D) que no se ve; el árbol de verdad ya no la
				# proyecta. Medido en el Bosque: la pasada de sombra dibujaba ≈ 3,8 M de triángulos de 4,35 M por fotograma.
				if sombra_reducida and SOMBRA_REDUCIDA.has(String(id)) and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					var reducida: Mesh = MallaReducida3D.reducir(mm.mesh, FRACCION_SOMBRA)
					if reducida != mm.mesh:
						var mms := MultiMesh.new()
						mms.transform_format = MultiMesh.TRANSFORM_3D
						mms.mesh = reducida
						mms.instance_count = mm.instance_count
						for i in range(mm.instance_count):
							mms.set_instance_transform(i, mm.get_instance_transform(i))
						var mis := MultiMeshInstance3D.new()
						mis.name = mi.name + "_sombra"
						mis.multimesh = mms
						mis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
						mis.material_override = mi.material_override
						_props.add_child(mis)
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_construir_sombras()


## Un solo MultiMesh con la elipse de contacto de todas las piezas en pie (una llamada de dibujo).
func _construir_sombras() -> void:
	if _sombras.is_empty():
		return
	var mat: ShaderMaterial = SombraContacto3D.material(SOMBRA_ALFA, SOMBRA_DUREZA)     # 14.2 (e): el mismo material que usan las piezas de puzle
	var q: QuadMesh = SombraContacto3D.malla(mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = _sombras.size()
	for i in range(_sombras.size()):
		mm.set_instance_transform(i, _sombras[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "sombras_contacto"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_efectos.add_child(mi)


## Hielo = la textura del agua desaturada y aclarada (no hay textura de hielo propia).
func _textura_hielo(agua: Texture2D) -> Texture2D:
	if agua == null:
		return null
	var img: Image = agua.get_image()
	if img == null:
		return agua
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(256, 256)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var g: float = c.get_luminance()
			img.set_pixel(x, y, Color(lerpf(c.r, g, 0.75), lerpf(c.g, g, 0.7), lerpf(c.b, g, 0.55)).lightened(0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Bloques empujables de tierra y hielo: cubos con tapa y lado distintos y grietas (CODIGO_BLOQUE). Las texturas
## definitivas (tierra_lado, hielo_arriba, hielo_lado, grietas en suelo_meshy/) son opcionales: sin ellas se usa
## la del suelo, el agua desaturada y unas grietas hechas con ruido.
func _colocar_empujables() -> void:
	for e in _empuj_def:
		var tipo: String = String(e[0])
		var c: Vector2i = e[1]
		var lado: float = S * 0.62
		var caja := BoxMesh.new()
		caja.size = Vector3(lado, lado, lado)
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = CODIGO_BLOQUE
		m.shader = sh
		if tipo == "hielo":
			var agua: Texture2D = _tex(SUELO + "water_arriba.png")
			var base: Texture2D = _tex_o(SUELO + "hielo_arriba.png", _textura_hielo(agua))
			m.set_shader_parameter("t_arriba", base)
			m.set_shader_parameter("t_lado", _tex_o(SUELO + "hielo_lado.png", base))
			m.set_shader_parameter("color_grieta", Color(0.9, 0.97, 1.0))
		else:
			m.set_shader_parameter("t_arriba", _tex(SUELO + "dirt_arriba.png"))
			m.set_shader_parameter("t_lado", _tex_o(SUELO + "tierra_lado.png", _tex(SUELO + "cuerpo.png")))
		m.set_shader_parameter("t_grietas", _grietas())
		m.set_shader_parameter("danio", 0.0)
		m.set_shader_parameter("brillo", OSCURECER_SUELO)
		caja.material = m
		var mi := MeshInstance3D.new()
		mi.name = "empujable_" + tipo
		mi.mesh = caja
		mi.position = Vector3(0.0, lado * 0.5, 0.0)
		var raiz := Node3D.new()           # misma forma que las piezas (raíz + modelo): el prerender 2D la recorta
		raiz.position = _centro_celda(c, ALTO)
		raiz.add_child(mi)
		_props.add_child(raiz)
		_bloqueadas[c] = true
		_empujables.append(mi)


## La textura si existe; si no, el sustituto (sin avisar: son texturas que aún no se han entregado).
func _tex_o(ruta: String, sustituta: Texture2D) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	return sustituta


## Grietas: R leves, G medias, B rotura. La de Pablo (suelo_meshy/grietas.png) o tres redes de celdas con ruido.
func _grietas() -> Texture2D:
	if _tex_grietas != null:
		return _tex_grietas
	if ResourceLoader.exists(SUELO + "grietas.png"):
		_tex_grietas = load(SUELO + "grietas.png") as Texture2D
		return _tex_grietas
	var canales: Array[Image] = []
	for i in range(3):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB      # 0 en los bordes entre celdas = grieta
		n.frequency = 0.018 + 0.012 * float(i)
		n.seed = 11 + i * 7
		canales.append(n.get_image(256, 256, false, false, true))
	var img := Image.create_empty(256, 256, true, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var col := Color(0.0, 0.0, 0.0)
			for i in range(3):
				col[i] = 1.0 - smoothstep(0.06, 0.17 + 0.01 * float(i), canales[i].get_pixel(x, y).r)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	_tex_grietas = ImageTexture.create_from_image(img)
	return _tex_grietas


## Tecla V: sube el daño del empujable más cercano a la chibi (0 → 0,34 → 0,68 → 1 → de nuevo 0).
func _danar_empujable_cercano() -> void:
	if _jugador == null or _empujables.is_empty():
		return
	var mejor: MeshInstance3D = null
	var dmin: float = 1.0e9
	for e in _empujables:
		var d: float = e.global_position.distance_to(_jugador.position)
		if d < dmin:
			dmin = d
			mejor = e
	var m: ShaderMaterial = (mejor.mesh as BoxMesh).material as ShaderMaterial
	var v0: Variant = m.get_shader_parameter("danio")
	var d0: float = float(v0) if v0 != null else 0.0
	m.set_shader_parameter("danio", 0.0 if d0 > 0.9 else minf(d0 + 0.34, 1.0))


## --- Lo que pide cada letra del plano ---

## --- Estilo «cueva» (23/10, docs/PLAN_BOSQUE_EOW.md §6) ---
## Cada casilla `#` mira cuáles de sus cuatro vecinas son suelo y elige pieza y giro (el frente del modelo, +Z local, hacia el suelo):
##   una vecina                → pared de frente a ella
##   dos vecinas en ángulo     → esquina EXTERIOR (la roca que asoma)
##   dos vecinas opuestas      → pared (un tabique entre dos salas), de frente a una de ellas
##   tres o cuatro             → esquina exterior (un pilar)
##   ninguna, pero sí en diagonal → esquina INTERIOR, hacia esa diagonal
##   ninguna                   → roca maciza: una pared con giro al azar, para que no quede un hueco que parezca paso
## `GIRO_CUEVA` corrige hacia dónde mira cada modelo de Tripo (medido en las capturas de herramientas/captura_cueva.gd).
const GIRO_CUEVA: Dictionary = {"cueva_pared": 0.0, "cueva_esquina_ext": 0.0, "cueva_esquina_int": 0.0}
const DECOR_CUEVA: Array = ["estalagmitas_a", "estalagmitas_b", "rocas_pequenas", "estalagmitas_a", "piedras"]


func _pared_cueva(c: Vector2i) -> void:
	var dirs: Array = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]     # sur (+Z), este (+X), norte, oeste
	var giros: Array = [0.0, 90.0, 180.0, 270.0]                                              # el giro sobre Y que lleva +Z local a cada una
	var libres: Array = []
	for i in range(4):
		if _suelo_de_cueva(c + (dirs[i] as Vector2i)):
			libres.append(i)
	var h: int = _hash(c.x, c.y, 41)
	var id: String = "cueva_pared"
	var giro: float = float(h % 4) * 90.0
	match libres.size():
		1:
			giro = giros[libres[0]]
		2:
			var a: int = libres[0]
			var b: int = libres[1]
			if (a + 2) % 4 == b:
				giro = giros[a if h % 2 == 0 else b]           # tabique: de frente a una de las dos salas
			else:
				id = "cueva_esquina_ext"
				# Entre las dos vecinas: con (0, 1) = sur y este, la esquina mira a 45°; (3, 0) = oeste y sur da 315°.
				giro = 45.0 + 90.0 * float(a if (a + 1) % 4 == b else b)
		3, 4:
			id = "cueva_esquina_ext"
		0:
			var diag: Array = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1)]
			for i in range(4):
				if _suelo_de_cueva(c + (diag[i] as Vector2i)):
					id = "cueva_esquina_int"
					giro = 45.0 + 90.0 * float(i)
					break
	_poner(id, c, ALTO, true, false, fposmod(giro + float(GIRO_CUEVA.get(id, 0.0)), 360.0))


func _suelo_de_cueva(q: Vector2i) -> bool:
	return _en_mapa(q) and _letra(q) != "#" and _letra(q) != " "


func _junto_a_pared(c: Vector2i) -> bool:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if _en_mapa(c + d) and _letra(c + d) == "#":
			return true
	return false


func _colocar_letras() -> void:
	# "matas" y "flores" de Meshy salieron mal (rocas de cristal y bolas): retiradas, las pone Hierba3D.
	# "caja_cristal" también: los empujables son cubos (_colocar_empujables).
	var decor: Array = ["arbusto", "arbusto_flores", "piedras", "setas", "tocon", "arbusto", "piedras"]
	for y in range(_lado):
		for x in range(_mapa[y].length()):
			var c := Vector2i(x, y)
			var l: String = _letra(c)
			var h: int = _hash(x, y, 3)
			_en_marcador = not "#~.,cUtxV".contains(l)      # pared, agua, suelos, arcos `U`, tienda, empalizada y estandarte son decorado; el resto (también los canales `-` `L`) sale de un marcador
			match l:
				" ":
					_bloqueadas[c] = true          # fuera de lo pintado: no se pisa
				"#":
					if not (_modo_escena or _modo_nivel) or x == 0 or y == 0 or x == _mapa[y].length() - 1 or y == _lado - 1:
						_bloqueadas[c] = true      # en modo escena el borde sigue cerrado; el resto lo deciden las piezas del .tscn
					if estilo == "cueva":
						_pared_cueva(c)
					elif h % 6 == 0:
						_poner("arbusto" if h % 2 == 0 else "roca_grande", c, ALTO, true)
					else:
						# Toda casilla de pared lleva un árbol: antes 1 de cada 4 quedaba sin modelo y era un hueco que parecía
						# paso pero bloqueaba (pared invisible). Juego, 2026-10-06.
						_poner("arbol_redondo" if h % 3 != 0 else "pino", c, ALTO, true)
				"~":
					_bloqueadas[c] = true
					if h % 9 == 0:
						_poner("juncos", c, ALTO_AGUA, false)
				"b":
					# 11/10 (Pablo): el puente de piedra rúnica, FIJO: siempre se cruza (antes, con objetos_reactivos, era el plegable
					# que levantado bloqueaba la casilla hasta que lo tendía el tótem de rayo; `_poner_puente` se queda por si se vuelve a él).
					_poner_puente_fijo(c)
				"z":
					if objetos_reactivos:
						_reactivo_pieza("seto", "seto_seco", c, ALTO, true)
					else:
						_poner("seto_seco", c, ALTO, true)
				"l":
					if objetos_reactivos:
						_reactivo_pieza("tronco", "tronco", c, ALTO, true)
					else:
						_poner("tronco", c, ALTO, true)
				"h":
					_poner("setas", c, ALTO, false)
				"r":
					_bloqueadas[c] = true
					if objetos_reactivos:
						_poner_telarana(c)
					else:
						_cartel_plano(VFX + "telarana.png", _centro_celda(c, ALTO + 1.0), 2.0, false, Color.WHITE)
				"j", "k", "i":
					var el: String = {"j": "fuego", "k": "agua", "i": "rayo"}[l]
					if objetos_reactivos:
						_reactivo_pieza("totem", "totem_runico", c, ALTO, true, false, 0.0, el)
					else:
						_poner("totem_runico", c, ALTO, true, false, 0.0)
						var col: Color = COLOR_ELEMENTO[el]
						_disco(VFX + "circulo_runico.png", _centro_celda(c, Y_DECAL), S * 1.1, col)
						_luz(_centro_celda(c, ALTO + 1.4), col, 1.0, 3.5)
				"B":
					# Barrera de fuego: la casilla bloquea (el Lanzador pone una BarreraFuego por casilla) y su fuego se dibuja luego
					# como UNA pared por tramo recto (_colocar_barreras_fuego), no una llama por casilla (7.11).
					_bloqueadas[c] = true
					_cel_barrera.append(c)
				"F":
					if objetos_reactivos:
						_reactivo_pieza("fogata", "fogata", c, ALTO, true, false, -1.0, "", true)
					else:
						_poner("fogata", c, ALTO, true, false)
						_fuego(_centro_celda(c, ALTO + 0.1), false)
				"T":
					if objetos_reactivos:
						_reactivo_pieza("brasero", "brasero", c, ALTO, true, false)
					else:
						_poner("brasero", c, ALTO, true, false)
						_fuego(_centro_celda(c, ALTO + 1.25), false, 0.6)
				"n", "Q":
					var tendero: Pj3D = poner_puesto(c, PJ_LIBRERA if l == "n" else PJ_ALQUIMISTA)
					if _reglas != null:
						_reglas.registrar_npc("librera" if l == "n" else "alquimista", tendero)
				"M":
					var librera: Pj3D = _npc(PJ_LIBRERA, _pos_marca(c, ALTO))
					_bloqueadas[c] = true
					if _reglas != null and _reglas.has_method("registrar_npc"):
						_reglas.registrar_npc("librera", librera)      # 9.8: sin esto la librera del Bosque no habla
				"m":
					# Guardabosques (el que habla en el Test de jugabilidad): la regla le pone nombre y diálogo.
					var gb: Pj3D = _npc(PJ_GUARDABOSQUES, _pos_marca(c, ALTO))
					_bloqueadas[c] = true
					if _reglas != null:
						_reglas.registrar_npc("guardabosques", gb)
					_mascota_guardabosques.call_deferred(gb)      # cuando el nivel ya está montado (para saber qué casillas se pisan)
				"p", "a", "w":
					# Losas del suelo (contacto, desbloqueo de agua y de viento): las pinta y vigila la regla.
					_sin_hierba[c] = true
					if _reglas != null:
						_reglas.registrar_losa(l, c)
				"D":
					_poner("dummy", c, ALTO, true, false, 0.0)
				"s", "f", "q":
					var planta: String = {"s": "seta_reactiva", "f": "flor_reactiva", "q": "raiz_reactiva"}[l]
					_poner(planta, c, ALTO, true)
					_esporas(_centro_celda(c, ALTO + 0.5))
				"A", "W":
					var quien: Array = PJ_GOBLIN
					if l == "A":
						quien = PJ_ARQUERO if (_reglas != null or arqueros) else PJ_ESPADACHIN
					var g: Pj3D = _personaje(quien, _pos_marca(c, ALTO))
					if g != null:
						_goblins.append(g)
				"G":
					# Elemental de bosque (marcador G, tipo "elemental"): entra en `_goblins` como los demás; el Jugador3D le cuelga
					# su Combate3D al arrancar (equipar reconoce el id y le da el comportamiento propio). La altura sale de ALTO_PJ.
					var el: Pj3D = _personaje(PJ_ELEMENTAL, _pos_marca(c, ALTO))
					if el != null:
						_goblins.append(el)
				"X":
					# El arco nuevo (arco_ruina, mercado.glb) ya tiene la abertura hacia la cámara; el viejo
					# (arco_puerta, objetos.glb) la tiene a +-X y hay que girarlo. Se cruza de norte a sur.
					var arco: String = _id_real("arco_puerta")
					var giro_arco: float = 0.0 if arco == "arco_ruina" else 90.0
					if _reglas is Jugabilidad3D:
						giro_arco += 90.0       # la puerta del test de jugabilidad se cruza de oeste a este
					if _giros.has(c):
						giro_arco = float(_giros[c])     # el mapa en archivo lo dice (`; giro x y grados`)
					_poner(arco, c, ALTO, false, false, giro_arco)
					if _de_archivo or nivel == "Bosque":
						_poner_runas_puerta(c, giro_arco)    # 9.7: la puerta de las tres runas
				"E":
					_poner("portal_salida", c, ALTO, false, false, 0.0)
					_destellos(_centro_celda(c, ALTO + 1.5), Color(0.75, 0.9, 1.0))
				"K":
					if objetos_reactivos:
						_reactivo_pieza("placa", "placa_peso", c, ALTO, false, false)
					else:
						_poner("placa_peso", c, ALTO, false, false)
				"S":
					_jugador = _personaje(PJ_JUGADOR, _pos_marca(c, ALTO))
				",", "c":
					pass        # 9.6: hierba corta (la siembra Hierba3D, baja) y cauce seco (_construir_cauce): sin decorado
				"U":
					# 9.6: arco de piedra por el que se pasa (decorado, no marcador): no bloquea. Giro: `; giro` del mapa o 0.
					_poner("arco_ruina", c, ALTO, false, false, 0.0)
				"t":
					# 10/10: tienda goblin (decorado, bloquea). Letra libre: el nivel solo la pinta donde quiere campamento.
					_sin_hierba[c] = true
					_poner("tienda_goblin", c, ALTO, true, false)
				"x":
					_sin_hierba[c] = true
					_poner("empalizada_goblin", c, ALTO, true, false, 0.0)       # corre a lo largo de X; `; giro` para ponerla de lado
				"V":
					_sin_hierba[c] = true
					_poner("estandarte_goblin", c, ALTO, true, false)
				"y":
					# 10/10: puerta del campamento. ARDE (Reactivo3D `puerta_goblin`): al consumirse libera la casilla.
					_sin_hierba[c] = true
					if objetos_reactivos:
						_reactivo_pieza("puerta_goblin", "puerta_goblin", c, ALTO, true, false, 0.0)
					else:
						_poner("puerta_goblin", c, ALTO, true, false, 0.0)
				"o":
					# 10/10: torre del campamento. ARDE (Reactivo3D `torre_goblin`).
					_sin_hierba[c] = true
					if objetos_reactivos:
						_reactivo_pieza("torre_goblin", "torre_goblin", c, ALTO, true, false)
					else:
						_poner("torre_goblin", c, ALTO, true, false)
				"-", "L":
					# 10/10: canal de ruinas, recto (`-`) o codo (`L`): decorado que no bloquea (se camina por encima). El giro de
					# la pieza (`; giro x y grados`) es solo visual: por dónde corre el agua lo decide la vecindad de casillas.
					_sin_hierba[c] = true
					var pieza_canal: Node3D = _poner("canal_recto" if l == "-" else "canal_codo", c, ALTO, false, false, 0.0)
					if pieza_canal != null:
						_piedra_canal(pieza_canal, c)
				"e":
					# 9.7: fuente eléctrica: el cristal con chispas permanentes (Reactivo3D tipo emisor_rayo, objetos_3d.gd).
					_sin_hierba[c] = true
					if objetos_reactivos:
						_reactivo_pieza("emisor_rayo", "cristal_sanctuario", c, ALTO, true, false, 0.0, "rayo")
					else:
						_poner("cristal_sanctuario", c, ALTO, true, false, 0.0)
				"u":
					# 9.7: surtidor: tinaja de ruinas (antes: pilar en su pila); con agua echa el chorro y avisa (activado "surtidor").
					_sin_hierba[c] = true
					if objetos_reactivos:
						_reactivo_pieza("surtidor", "tinaja_ruina", c, ALTO, true, false, 0.0, "agua")
					else:
						_poner("tinaja_ruina", c, ALTO, true, false, 0.0)
				".":
					if estilo == "cueva":
						if h % 11 == 0 and _junto_a_pared(c):        # cueva: estalagmitas y rocas pegadas a la pared, no en medio del paso
							_poner(String(DECOR_CUEVA[_hash(x, y, 5) % DECOR_CUEVA.size()]), c, ALTO, false)
					elif h % 9 == 0 and _tipo_suelo(c) == 0 and nivel != "pruebas":      # el banco de pruebas va limpio
						_poner(String(decor[_hash(x, y, 5) % decor.size()]), c, ALTO, false)

	_en_marcador = false
	_colocar_barreras_fuego()
	_enlazar_reactivos()
	_colocar_puentes_reactivos()


## Puentes reactivos (marcador `P`): una fila de losas bajo el agua que sube cuando se activa el marcador enlazado. El color de
## las runas es el del elemento del activador (cian si no tiene). Por qué la casilla pasa a letra `b`: el resto del juego (altura
## del jugador y goblins, hielo, agua) decide por la letra; así la casilla ya es puente y no agua.
func _colocar_puentes_reactivos() -> void:
	for d in _puentes_def:
		var celdas: Array = (d as Dictionary)["celdas"]
		var centros: Array = []
		for c in celdas:
			centros.append(_centro_celda(c, ALTO_AGUA))
		var act: Reactivo3D = null
		for r in _reactivos:
			if is_instance_valid(r) and r.celda == ((d as Dictionary)["activador"] as Vector2i):
				act = r
		var color: Color = Color(0.2, 0.9, 1.0)
		if act != null and Vfx3D.COLOR.has(act.elemento):
			color = Vfx3D.COLOR[act.elemento]
		var pr := PuenteReactivo3D.new()
		pr.name = "puente_reactivo"
		_props.add_child(pr)
		pr.preparar(celdas, centros, ALTO_AGUA + 0.12, ALTO_AGUA, _fx, color)
		pr.losa_lista.connect(_al_tender_losa)
		if act != null:
			# Hilo de luz del activador a la primera losa (por casillas andables, con pocos giros). La hierba no lo tapa.
			var ruta: Array = _ruta_hilo(act.celda, celdas)
			if ruta.size() >= 2:
				var puntos: Array = []
				for q in ruta:
					puntos.append((q as Dictionary)["p"])
					_sin_hierba[(q as Dictionary)["c"]] = true
				var hilo := HiloLuz3D.new()
				hilo.name = "hilo_luz"
				_props.add_child(hilo)
				hilo.preparar(puntos, color)
				pr.poner_hilo(hilo, 0.6)
		if act != null:
			act.activado.connect(func(_t: String, _e: String) -> void: pr.tender(act.global_position))
		elif (d as Dictionary)["activador"] != Vector2i(-1, -1):
			_avisos.append("puente reactivo: no hay objeto reactivo en la casilla %s" % str((d as Dictionary)["activador"]))


## Ruta del hilo de luz: de la casilla del activador a la orilla junto a la losa más cercana, por casillas sin agua ni objetos,
## con un pequeño castigo por cada giro (rutas rectas y limpias). Devuelve [{c: casilla, p: punto del mundo}]; el último punto
## entra un poco en la losa. Vacío si no hay camino.
func _ruta_hilo(origen: Vector2i, celdas_puente: Array) -> Array:
	var primera: Vector2i = celdas_puente[0]
	var dmin: int = 1 << 30
	for c in celdas_puente:
		var d: int = absi((c as Vector2i).x - origen.x) + absi((c as Vector2i).y - origen.y)
		if d < dmin:
			dmin = d
			primera = c
	var dirs: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var dist: Dictionary = {}
	var previo: Dictionary = {}
	var cubos: Dictionary = {0: [Vector3i(origen.x, origen.y, 4)]}
	dist[Vector3i(origen.x, origen.y, 4)] = 0
	var final: Vector3i = Vector3i(-1, -1, -1)
	var coste: int = 0
	while coste <= 3000 and final.x < 0:
		if cubos.has(coste):
			var i: int = 0
			while i < (cubos[coste] as Array).size() and final.x < 0:
				var s: Vector3i = (cubos[coste] as Array)[i]
				i += 1
				if int(dist.get(s, 1 << 30)) != coste:
					continue
				var cs := Vector2i(s.x, s.y)
				if absi(cs.x - primera.x) + absi(cs.y - primera.y) == 1:
					final = s
					break
				for k in range(4):
					var n: Vector2i = cs + (dirs[k] as Vector2i)
					if not _en_mapa(n) or _es_agua(_letra(n)) or _letra(n) == "#" or _bloqueadas.has(n):
						continue
					var nuevo: int = coste + 10 + (0 if (s.z == 4 or s.z == k) else 6)
					var ns := Vector3i(n.x, n.y, k)
					if nuevo < int(dist.get(ns, 1 << 30)):
						dist[ns] = nuevo
						previo[ns] = s
						if not cubos.has(nuevo):
							cubos[nuevo] = []
						(cubos[nuevo] as Array).append(ns)
		coste += 1
	if final.x < 0:
		return []
	var celdas: Array = []
	var cur: Vector3i = final
	while true:
		celdas.push_front(Vector2i(cur.x, cur.y))
		if not previo.has(cur):
			break
		cur = previo[cur]
	var res: Array = []
	for c in celdas:
		res.append({"c": c, "p": _centro_celda(c, ALTO + 0.14)})
	# el último tramo entra en la losa hasta un cuarto de casilla de su borde
	var ult: Vector2i = celdas[celdas.size() - 1]
	var haz: Vector2 = Vector2(primera - ult)
	var centro: Vector3 = _centro_celda(primera, ALTO_AGUA + 0.26)
	res.append({"c": primera, "p": centro - Vector3(haz.x, 0.0, haz.y) * (S * 0.25)})
	return res


func _al_tender_losa(c: Vector2i) -> void:
	Terreno3D.poner_letra(c, "b")      # 13/10 (M5): la letra es del terreno; `_mapa` es solo la copia de carga (dibujo)
	_liberar(c)


## 7.11: una pared de fuego continua por cada tramo recto de barrera (letras `B` contiguas, o un marcador `B` con `largo`).
## La luz y las brasas van dentro de la pared (Vfx3D.fuego_pared); `apagar_tramo` la parte cuando el agua apaga una casilla.
func _colocar_barreras_fuego() -> void:
	var tramos: Array = _muros_def if _modo_nivel else HorneadorNivel.tramos_barrera(_cel_barrera)
	for t in tramos:
		var td: Dictionary = t
		var celdas: Array = td["celdas"]
		var centros: Array = []
		for ce in celdas:
			centros.append(_centro_celda(ce as Vector2i, ALTO))
		_fx.fuego_pared(celdas, centros, Vector3.BACK if bool(td["vertical"]) else Vector3.RIGHT, S)


## --- 6.10 camino A: nivel editable (.tscn con nodos Pieza3D) ---

func _ruta_escena() -> String:
	return NIVELES + nivel + ".tscn"


## Transform de `n` respecto a `raiz` (el .tscn instanciado no está en el árbol: no hay global_transform).
func _transform_en(n: Node3D, raiz: Node) -> Transform3D:
	var t: Transform3D = n.transform
	var padre: Node = n.get_parent()
	while padre != null and padre != raiz and padre is Node3D:
		t = (padre as Node3D).transform * t
		padre = padre.get_parent()
	return t


## Lee las Pieza3D del .tscn del nivel y hace con ellas lo mismo que _poner: lotes de decorado, sombra de contacto y casilla
## bloqueada (la que contiene su posición). Lo que el Lanzador llama «huellas» sale de aquí sin cambios (calcular_huellas lee _lotes).
func _instanciar_escena() -> void:
	var ps: PackedScene = load(_ruta_escena()) as PackedScene
	if ps == null:
		_avisos.append("no se pudo cargar " + _ruta_escena())
		_modo_escena = false
		return
	var raiz: Node = ps.instantiate()
	var colocadas: int = 0
	for n in raiz.find_children("*", "Pieza3D", true, false):
		var pz: Pieza3D = n as Pieza3D
		var id_pedido: String = pz.id
		var id: String = _id_real(id_pedido)
		var t: Transform3D = _transform_en(pz, raiz)
		var p: Vector3 = t.origin
		var escala: float = t.basis.get_scale().x
		if pz.bloquea:
			var cp: Vector2i = _celda_de(p)
			_bloqueadas[cp] = true
			_celdas_pieza[cp] = true
			_poner_colision(id_pedido, t)
			if MUROS_COLISION.has(id):
				_celdas_muro[cp] = true
		if decorado_por_lotes:
			if _plantilla(id).is_empty():
				continue
			if not _lotes.has(id):
				_lotes[id] = []
			(_lotes[id] as Array).append(t)
			if SOMBRA_CONTACTO.has(id):
				var r: float = float(SOMBRA_CONTACTO[id]) * escala
				_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
		else:
			var nodo: Node3D = _pieza(id)
			if nodo == null:
				continue
			nodo.transform = t
			_props.add_child(nodo)
		colocadas += 1
	raiz.free()
	print("Nivel desde ", _ruta_escena(), ": ", colocadas, " piezas")


## El cuerpo sólido de una pieza que bloquea, en la capa CAPA_SOLIDO del Lanzador. Es lo que lee la fuente de solidez por
## nodos: «lo que se ve es lo que choca». La escala del nodo se aplica a mano a la forma (un StaticBody con escala no uniforme
## deforma la colisión), y solo se respeta el giro en Y.
func _poner_colision(id_pedido: String, t: Transform3D) -> void:
	if _solidos == null:
		_solidos = Node3D.new()
		_solidos.name = "Solidos"
		add_child(_solidos)
	var f: Dictionary = Pieza3D.forma_colision(id_pedido)
	var k: float = t.basis.get_scale().x
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = Lanzador3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("bloquea")
	cuerpo.position = t.origin
	cuerpo.rotation.y = t.basis.orthonormalized().get_euler().y
	# 21/10 (diario 227): los cascos medidos sobre el contorno del modelo, uno por trozo (un arco = dos pilares y el paso libre). Una caja que envolvía los dos pilares tapaba el paso.
	for cs in Pieza3D.formas_colision(id_pedido, k):
		cuerpo.add_child(cs)
	if cuerpo.get_child_count() == 0:
		# Sin cascos (pieza más baja que `ColisionPieza.ALTO_MIN_SOLIDO` pero marcada como que bloquea): la caja/cilindro de siempre.
		var forma := CollisionShape3D.new()
		if bool(f["cilindro"]):
			var cil := CylinderShape3D.new()
			cil.radius = float(f["radio"]) * k
			cil.height = float(f["alto"]) * k
			forma.shape = cil
		else:
			var caja := BoxShape3D.new()
			caja.size = (f["tam"] as Vector3) * k
			forma.shape = caja
		forma.position = (f["centro"] as Vector3) * k
		cuerpo.add_child(forma)
	_solidos.add_child(cuerpo)


## Cuerpo de contorno: un cilindro de `radio` en los pies de algo (NPC, objeto), en la capa de lo sólido.
func _poner_contorno(pies: Vector3, radio: float) -> void:
	if _solidos == null:
		_solidos = Node3D.new()
		_solidos.name = "Solidos"
		add_child(_solidos)
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = Lanzador3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("bloquea")
	cuerpo.position = Vector3(pies.x, ALTO, pies.z)
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = radio
	cil.height = 1.6
	forma.shape = cil
	forma.position = Vector3(0.0, 0.8, 0.0)
	cuerpo.add_child(forma)
	_solidos.add_child(cuerpo)


## Con el nivel en .tscn la solidez pasa a ser la de la colisión real (Lanzador3D.activar_fuente_nodos). El motor de física
## no ve los cuerpos recién creados hasta un par de fotogramas de física, por eso se espera. Hasta entonces manda el diccionario.
## Lo que NO es una pieza del .tscn (agua, borde, NPC, objetos reactivos, la puerta…) sigue en `_bloqueadas` y se traspasa
## a la fuente como bloqueo «extra», para que la fuente por nodos lo vea igual que antes.
func _activar_solidez_por_nodos() -> void:
	# 12/10 (Pablo): contorno (círculo en los pies) de los NPC quietos y de los objetos reactivos: cuerpos en CAPA_SOLIDO ANTES de
	# esperar a la física, para que la fuente por nodos los vea como el resto de piezas (casilla «parcial»: se rodean, no se atraviesan).
	var contorno: Dictionary = {}
	for n in _npcs_contorno:
		if is_instance_valid(n):
			var cn: Vector2i = _celda_de((n as Node3D).global_position)
			_poner_contorno((n as Node3D).global_position, RADIO_CONTORNO_NPC)
			contorno[cn] = true
	for r in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		var ro: Reactivo3D = r as Reactivo3D
		if ro == null or ro.tipo == "puente" or ro.tipo == "placa" or ro.tipo == "telarana":
			continue
		var cr: Vector2i = _celda_de(ro.global_position)
		if not _bloqueadas.has(cr) or _celdas_pieza.has(cr):
			continue
		_poner_contorno(ro.global_position, RADIO_CONTORNO_OBJETO)
		contorno[cr] = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or Terreno3D.mundo_s != self:
		return
	var n: int = Lanzador3D.activar_fuente_nodos(self)
	if n == 0 and not _celdas_pieza.is_empty():
		push_warning("PruebaTest2: la física no ve las piezas del nivel; vuelvo a la solidez por casillas.")
		Lanzador3D.activar_fuente_casillas()
		return
	for c in _bloqueadas.keys():
		if not _celdas_pieza.has(c) and not contorno.has(c):
			Lanzador3D.bloquear_celda(c)
	for c in _celdas_muro.keys():
		Lanzador3D.bloquear_celda_completa(c)      # un muro nunca es «parcial»
	print("Solidez por colisión: ", n, " casillas de piezas, ", _bloqueadas.size() - _celdas_pieza.size(), " extra")


## 13/10 (P4): F9 SÍ hornea (medido: tres F9 seguidos dejaron tres horneados idénticos y sus copias), pero es síncrono: empaquetar ~370
## piezas deja el juego quieto varios segundos y la única señal era un `print` en la consola, así que parecía una pausa y se volvía
## a pulsar (cada pulsación aparta el anterior como `_copia_<hora>`). Ahora: aviso visible en el HUD ANTES de bloquear (se esperan dos
## fotogramas para que se dibuje), resultado visible después, y las F9 que llegaron durante el bloqueo se ignoran (3 s de margen).
var _horneando: bool = false
var _ms_hornear: int = -100000


func _hornear_con_aviso() -> void:
	if _horneando or Time.get_ticks_msec() - _ms_hornear < 3000:
		return
	_horneando = true
	var espera: String = "HORNEANDO… el juego se queda quieto unos segundos"
	_avisos.append(espera)
	_actualizar_hud()
	await get_tree().process_frame
	await get_tree().process_frame
	var ruta: String = hornear()
	_avisos.erase(espera)
	var res: String = ("Horneado: " + ruta.get_file()) if ruta != "" else "F9: no se ha horneado nada (mira la consola)"
	_avisos.append(res)
	_actualizar_hud()
	_ms_hornear = Time.get_ticks_msec()
	_horneando = false
	await get_tree().create_timer(8.0).timeout
	_avisos.erase(res)


## F9: hornea lo que las letras han colocado como `niveles/Nivel_<Nombre>.tscn` (ver HorneadorNivel). Con el nivel ya cargado
## desde su .tscn no hace nada: ese archivo manda y tiene tus ediciones. Para volver a generarlo desde las letras (PISA las
## ediciones; la versión anterior se aparta como `..._copia_<hora>.tscn`): poner `usar_escena = false` y pulsar F9.
func hornear() -> String:
	if _modo_nivel or _modo_escena:
		print("Hornear: este nivel ya se ha cargado de su .tscn, que manda sobre las letras. Para regenerarlo desde las letras (pisa las ",
			"ediciones) desmarca `usar_escena` en PruebaTest2 y vuelve a pulsar F9.")
		return ""
	var extras: Array = []
	if _reglas is Jugabilidad3D:
		for r in Jugabilidad3D.RECOGIBLES:
			extras.append({"grupo": "recogible", "tipo": String(r[0]), "c": Vector2i(int(r[1]), int(r[2]))})
		extras.append({"letra": "n", "c": Jugabilidad3D.PUESTO_CELDA})
		extras.append({"letra": "Q", "c": Jugabilidad3D.PUESTO_CELDA + Vector2i(0, 3)})
		# Los setos sueltos de las reglas (no son letras del mapa): los que de verdad se pusieron, que ya constan en el registro.
		for r in _registro:
			var rd: Array = r
			var c_seto: Vector2i = rd[1]
			if String(rd[0]) == "seto_seco" and String(rd[4]) == "marcador" and _letra(c_seto) == ".":
				extras.append({"letra": "z", "c": c_seto})
	for e in _empuj_def:
		extras.append({"grupo": "empujable", "tipo": String(e[0]), "c": e[1] as Vector2i})
	if nivel == "pruebas":
		for e in NivelPruebas.piezas():
			extras.append({"rotulo": String(e[0]), "c": e[1] as Vector2i})
	var datos: Dictionary = {"nivel": nivel, "mapa": Terreno3D.mapa if Terreno3D.datos_propios else _mapa, "registro": _registro, "extras": extras}
	return HorneadorNivel.hornear(datos)


## --- 7.2: el nivel editable (Nivel_<Nombre>.tscn) ---

## Contrato con el Juego (7.5): el rectángulo del nivel en casillas DEL MUNDO de la maqueta. En un nivel editable es el
## rectángulo pintado del GridMap (puede no ser cuadrado), ya desplazado para que empiece en (0, 0): la maqueta mueve el .tscn
## entero -`origen_nivel()` casillas al cargarlo, así `_lado`, `_celda_de` y `centro_de` del Lanzador siguen valiendo.
## Con las letras, el cuadrado de siempre.
func limites() -> Rect2i:
	if (_modo_nivel or _de_archivo) and _ancho > 0 and _alto > 0:
		return Rect2i(0, 0, _ancho, _alto)
	return Rect2i(0, 0, _lado, _lado)


## La casilla del GridMap del .tscn que es la (0, 0) del mundo (para pasar de casillas del editor a casillas del juego:
## juego = editor - origen_nivel()). Con las letras, (0, 0).
func origen_nivel() -> Vector2i:
	return _origen if _modo_nivel else Vector2i.ZERO


## Transform de un nodo del .tscn en el mundo de la maqueta: respecto a la raíz del nivel y desplazado -_origen casillas.
func _t_nivel(n: Node3D) -> Transform3D:
	var t: Transform3D = _transform_en(n, _nivel_raiz)
	t.origin += _desplaza
	return t


## ¿Esta pieza (id y cuerpo) está bajo un nodo con ese nombre? (Piezas / Borde)
func _bajo(n: Node, nombre: String, raiz: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != raiz:
		if String(p.name) == nombre:
			return true
		p = p.get_parent()
	return false


## La letra de `c` en unas filas de texto (las del nivel que se está leyendo); fuera, " ".
static func _letra_en(filas: Array, c: Vector2i) -> String:
	if c.y < 0 or c.y >= filas.size() or c.x < 0 or c.x >= (filas[c.y] as String).length():
		return " "
	return (filas[c.y] as String)[c.x]


## Recorre el .tscn y da todas las piezas (nodos con metadato `id`; no se baja dentro de ellas).
func _piezas_de(n: Node, fuera: Array) -> void:
	for h in n.get_children():
		if h.has_meta("id"):
			fuera.append(h)
		else:
			_piezas_de(h, fuera)


## Lee el nivel y deja listo lo que `_ready` esperaba de las letras: el mapa (`_mapa`), los giros de los marcadores, los
## guardados y los empujables. El resto de la maqueta (agua, hierba, personajes, objetos reactivos…) no se entera.
func _leer_nivel() -> void:
	var ps: PackedScene = load(HorneadorNivel.ruta(nivel)) as PackedScene
	if ps == null:
		_avisos.append("no se pudo cargar " + HorneadorNivel.ruta(nivel))
		_modo_nivel = false
		return
	_leer_nivel_de(ps.instantiate())


## 13/10: lee un nivel ya instanciado. El juego le pasa el .tscn recién cargado (fuera del árbol); la vista del suelo del
## editor (vista_suelo_editor.gd) le pasa la escena ABIERTA, para construir el suelo con este mismo código. Solo lee.
func _leer_nivel_de(raiz: Node) -> void:
	_nivel_raiz = raiz
	var suelo: GridMap = null
	for g in _nivel_raiz.find_children("*", "GridMap", true, false):
		suelo = g as GridMap
		break
	if suelo == null or suelo.mesh_library == null:
		_avisos.append("el nivel no tiene GridMap de suelo")
		_modo_nivel = false
		return
	# El rectángulo del nivel = la caja de las casillas pintadas (cualquier origen, también negativo). Antes salía del
	# metadato `lado` de la raíz, que se copia al duplicar un nivel (Nivel_Bosque heredó 16 de Nivel_Pruebas).
	var usadas: Array[Vector3i] = suelo.get_used_cells()
	if usadas.is_empty():
		_avisos.append("el GridMap del nivel está vacío")
		_modo_nivel = false
		return
	var mn := Vector2i(usadas[0].x, usadas[0].z)
	var mx := mn
	var por_celda: Dictionary = {}      ## Vector2i -> [planta, item]: si hay varias plantas, manda la más alta
	var otras_plantas: int = 0
	for u in usadas:
		var c2 := Vector2i(u.x, u.z)
		mn = Vector2i(mini(mn.x, c2.x), mini(mn.y, c2.y))
		mx = Vector2i(maxi(mx.x, c2.x), maxi(mx.y, c2.y))
		if u.y != 0:
			otras_plantas += 1
		if not por_celda.has(c2) or int((por_celda[c2] as Array)[0]) < u.y:
			por_celda[c2] = [u.y, suelo.get_cell_item(u)]
	if otras_plantas > 0:
		_avisos.append("%d casillas del suelo en otra planta (no la 0): cuentan como suelo de la 0 (Q/E del GridMap cambian de planta)" % otras_plantas)
	if not suelo.position.is_zero_approx():
		_avisos.append("el nodo Suelo está desplazado %s: el cargador lo ignora (déjalo en 0, 0, 0)" % str(suelo.position))
	_origen = mn
	_ancho = mx.x - mn.x + 1
	_alto = mx.y - mn.y + 1
	_desplaza = Vector3(-float(mn.x) * S, 0.0, -float(mn.y) * S)
	var lado: int = maxi(_ancho, _alto)
	var filas: Array = []
	for y in range(lado):
		filas.append(" ".repeat(lado))       # " " = sin pintar: sin suelo y bloqueada
	for c2 in por_celda:
		var cc: Vector2i = (c2 as Vector2i) - mn
		var l: String = HorneadorNivel.letra_de_item(suelo.mesh_library, int((por_celda[c2] as Array)[1]))
		filas[cc.y] = (filas[cc.y] as String).substr(0, cc.x) + l + (filas[cc.y] as String).substr(cc.x + 1)
	var giros: Dictionary = {}
	_escalas = {}
	_marcas.clear()
	_muros_def.clear()
	_puentes_def.clear()
	_desvios.clear()
	_canal_llenos.clear()
	_canal_tf.clear()
	_marca_tf.clear()
	for n in _nivel_raiz.find_children("*", "Marcador3D", true, false):
		var mk: Marcador3D = n as Marcador3D
		var t: Transform3D = _t_nivel(mk)
		var c: Vector2i = _celda_de(t.origin)
		if c.x < 0 or c.y < 0 or c.x >= lado or c.y >= lado or _letra_en(filas, c) == " ":
			_avisos.append("marcador fuera del suelo pintado: %s en la casilla %s del editor" % [mk.name, str(c + mn)])
			continue
		var giro: float = fposmod(rad_to_deg(t.basis.orthonormalized().get_euler().y), 360.0)
		giros[c] = snappedf(giro, 0.01)
		if mk.letra == "u":
			# La tinaja respeta dónde la pusiste DENTRO de su casilla (el resto de marcadores se centran).
			var centro: Vector3 = _centro_celda(c, 0.0)
			_desvios[c] = Vector2(t.origin.x - centro.x, t.origin.z - centro.z)
		_marca_tf[c] = t
		if mk.letra == "-" or mk.letra == "L":
			_canal_tf[c] = t          # 13/10: la piedra y el agua van donde el marcador está en el editor, no al centro de la casilla
		if (mk.letra == "-" or mk.letra == "L") and mk.lleno:
			_canal_llenos[c] = true
		var esc: Vector3 = t.basis.get_scale()
		if not esc.is_equal_approx(Vector3.ONE):
			_escalas[c] = esc
		if mk.letra == "B":
			# Barrera de fuego (7.11): un marcador cubre `largo` casillas a lo largo de su eje X (el más cercano: horizontal o vertical).
			var vertical: bool = absf(t.basis.x.z) > absf(t.basis.x.x)
			var dir := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
			var cubiertas: Array = []
			for k in range(maxi(mk.largo, 1)):
				var off: float = (float(k) - float(maxi(mk.largo, 1) - 1) * 0.5) * S
				var pos := Vector2(t.origin.x, t.origin.z) + dir * off
				var cb := Vector2i(int(floor(pos.x / S)), int(floor(pos.y / S)))
				if cb.x < 0 or cb.y < 0 or cb.x >= lado or cb.y >= lado or cubiertas.has(cb):
					continue
				cubiertas.append(cb)
				filas[cb.y] = (filas[cb.y] as String).substr(0, cb.x) + "B" + (filas[cb.y] as String).substr(cb.x + 1)
			if not cubiertas.is_empty():
				_muros_def.append({"celdas": cubiertas, "vertical": vertical})
			continue
		if mk.letra == "P":
			# Puente reactivo: las casillas que cubre (a lo largo de su eje X) deben ser AGUA; se quedan como agua y bloqueadas
			# hasta que lo activa el marcador enlazado (PuenteReactivo3D las convierte en puente una a una).
			var vert: bool = absf(t.basis.x.z) > absf(t.basis.x.x)
			var d2 := Vector2(0.0, 1.0) if vert else Vector2(1.0, 0.0)
			var cubre: Array = []
			for k in range(maxi(mk.largo, 1)):
				var of2: float = (float(k) - float(maxi(mk.largo, 1) - 1) * 0.5) * S
				var p2 := Vector2(t.origin.x, t.origin.z) + d2 * of2
				var cp2 := Vector2i(int(floor(p2.x / S)), int(floor(p2.y / S)))
				if cp2.x < 0 or cp2.y < 0 or cp2.x >= lado or cp2.y >= lado or cubre.has(cp2):
					continue
				if _letra_en(filas, cp2) != "~":
					_avisos.append("puente reactivo %s: la casilla %s del editor no es agua" % [mk.name, str(cp2 + mn)])
					continue
				cubre.append(cp2)
			var ca: Vector2i = Vector2i(-1, -1)
			var an: Marcador3D = mk.get_node_or_null(mk.activador) as Marcador3D if not mk.activador.is_empty() else null
			if an != null:
				ca = _celda_de(_t_nivel(an).origin)
			else:
				_avisos.append("puente reactivo %s sin activador: no se tenderá nunca" % mk.name)
			if not cubre.is_empty():
				_puentes_def.append({"celdas": cubre, "activador": ca})
			continue
		if mk.letra != "":
			filas[c.y] = (filas[c.y] as String).substr(0, c.x) + mk.letra + (filas[c.y] as String).substr(c.x + 1)
		else:
			_marcas.append({"grupo": mk.grupo, "tipo": mk.tipo, "c": c, "giro": giro})
	# Paredes (#): las casillas donde hay una pieza del Borde. Las del Borde y nada más: un árbol suelto de Piezas no es pared.
	var piezas: Array = []
	_piezas_de(_nivel_raiz, piezas)
	var guardados: Array = []
	_celdas_canal.clear()
	for pn in piezas:
		var pz: Node3D = pn as Node3D
		var cp: Vector2i = _celda_de(_t_nivel(pz).origin)
		if cp.x < 0 or cp.y < 0 or cp.x >= lado or cp.y >= lado:
			continue
		# Los canales del nivel horneado son piezas (no letras): sus casillas son las que llena el agua (_montar_canal).
		var id_canal: String = String(pz.get_meta("id"))
		if id_canal == "canal_recto" or id_canal == "canal_codo":
			_celdas_canal[cp] = true
		if _bajo(pz, "Borde", _nivel_raiz) and _letra_en(filas, cp) != " ":      # sin suelo debajo sigue vacía
			filas[cp.y] = (filas[cp.y] as String).substr(0, cp.x) + "#" + (filas[cp.y] as String).substr(cp.x + 1)
		if String(pz.get_meta("id")) == "baldosa_guardado":
			guardados.append(cp)
	var m := PackedStringArray()
	for f in filas:
		m.append(String(f))
	_mapa = m
	_giros = giros
	_guardados = guardados
	var emp: Array = []
	for mc in _marcas:
		if String((mc as Dictionary)["grupo"]) == "empujable":
			emp.append([String((mc as Dictionary)["tipo"]), (mc as Dictionary)["c"]])
	_empuj_def = emp
	print("Nivel leído de ", HorneadorNivel.ruta(nivel), ": ", _ancho, "×", _alto, " casillas desde ", _origen, " del editor, ",
		_marcas.size(), " marcadores de datos, ", guardados.size(), " guardados")


## Lo que el .tscn aporta: el decorado (a los lotes de siempre, para que se dibuje igual y barato) y la colisión REAL de cada
## pieza (su StaticBody3D, capa MUNDO). Una pieza con `bloquea` falso no lleva cuerpo. Las celdas que ocupan esos cuerpos
## son las que la fuente de solidez por nodos (Lanzador3D) ve como bloqueadas.
func _instanciar_nivel() -> void:
	var piezas: Array = []
	_piezas_de(_nivel_raiz, piezas)
	var colocadas: int = 0
	var hundidas: int = 0
	for pn in piezas:
		var pz: Node3D = pn as Node3D
		var id_pedido: String = String(pz.get_meta("id"))
		var id: String = _id_real(id_pedido)
		var t: Transform3D = _t_nivel(pz)
		# Una pieza por debajo del suelo se sube a él: al soltarla arrastrando en el editor, Godot la deja en y = 0 (las casillas
		# del GridMap no tenían colisión) y en el juego quedaba enterrada bajo la tapa del bloque (a ALTO). Lo que está por
		# encima del suelo no se toca.
		var y_suelo: float = ALTO_AGUA if _es_agua(_letra(_celda_de(t.origin))) else ALTO
		if t.origin.y < y_suelo - 0.15:
			t.origin.y = y_suelo
			hundidas += 1
		var p: Vector3 = t.origin
		var escala: float = t.basis.get_scale().x
		var es_muro: bool = MUROS_COLISION.has(id)      # 12/10 (Pablo): un muro bloquea siempre, aunque la pieza no lo marque
		if bool(pz.get_meta("bloquea", false)) or es_muro:
			var cuerpo: StaticBody3D = pz.get_node_or_null("cuerpo") as StaticBody3D
			if cuerpo != null:
				_poner_cuerpo(cuerpo, t, p)
				if es_muro:
					_marcar_muro(cuerpo, t, p)
			elif es_muro:
				# Sin cuerpo propio: el de la biblioteca de piezas (su caja), para que el muro exista de verdad.
				var cp_m: Vector2i = _celda_de(p)
				_bloqueadas[cp_m] = true
				_celdas_pieza[cp_m] = true
				_poner_colision(id_pedido, t)
				var f_m: Dictionary = Pieza3D.forma_colision(id_pedido)
				var k_m: float = t.basis.get_scale().x
				var mitad_m: Vector3 = (t.basis.orthonormalized() * (((f_m["tam"] as Vector3) if not bool(f_m["cilindro"]) else Vector3(float(f_m["radio"]) * 2.0, 1.0, float(f_m["radio"]) * 2.0)) * 0.5 * k_m)).abs()
				_marcar_muro_caja(t * ((f_m["centro"] as Vector3) * k_m), mitad_m)
			else:
				_avisos.append("pieza %s bloquea pero no tiene `cuerpo`" % pz.name)
		if decorado_por_lotes:
			if _plantilla(id).is_empty():
				continue
			if not _lotes.has(id):
				_lotes[id] = []
			(_lotes[id] as Array).append(t)
			if SOMBRA_CONTACTO.has(id):
				var r: float = float(SOMBRA_CONTACTO[id]) * escala
				_sombras.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 1.7)), Vector3(p.x, Y_DECAL - 0.005, p.z)))
		else:
			var nodo: Node3D = _pieza(id)
			if nodo == null:
				continue
			nodo.transform = t
			_props.add_child(nodo)
		colocadas += 1
	# Los rótulos del nivel (Label3D bajo `Rotulos`, p. ej. los del banco de pruebas) se copian tal cual al decorado.
	for l in _nivel_raiz.find_children("*", "Label3D", true, false):
		var et: Label3D = (l as Label3D).duplicate() as Label3D
		et.position = _t_nivel(l as Node3D).origin
		_props.add_child(et)
	if hundidas > 0:
		_avisos.append("%d piezas estaban bajo el suelo (y < %.2f): subidas a él" % [hundidas, ALTO])
	print("Nivel desde ", HorneadorNivel.ruta(nivel), ": ", colocadas, " piezas")


## Copia el StaticBody3D de la pieza del .tscn a la maqueta, en su sitio. Las casillas que toca se apuntan en `_bloqueadas`
## (lo siguen leyendo la hierba y el reparto de objetos), y como «de pieza» para no traspasarlas luego a `extras`.
func _poner_cuerpo(modelo: StaticBody3D, t: Transform3D, p: Vector3) -> void:
	if _solidos == null:
		_solidos = Node3D.new()
		_solidos.name = "Solidos"
		add_child(_solidos)
	var cuerpo: StaticBody3D = modelo.duplicate() as StaticBody3D
	cuerpo.transform = t
	cuerpo.add_to_group("bloquea")
	_solidos.add_child(cuerpo)
	var cp: Vector2i = _celda_de(p)
	_bloqueadas[cp] = true
	_celdas_pieza[cp] = true


## Un muro del .tscn: bloquea las casillas que cubre su cuerpo (la de su posición y las que caen dentro de la caja), enteras.
func _marcar_muro(cuerpo: StaticBody3D, t: Transform3D, p: Vector3) -> void:
	_celdas_muro[_celda_de(p)] = true
	for forma in cuerpo.find_children("*", "CollisionShape3D", true, false):
		var caja := (forma as CollisionShape3D).shape as BoxShape3D
		if caja == null:
			continue
		_marcar_muro_caja(t * (forma as CollisionShape3D).position, (t.basis * (caja.size * 0.5)).abs())


## Marca como muro las casillas cuyo centro cae dentro de la caja (centro, semiancho) del mundo.
func _marcar_muro_caja(centro: Vector3, mitad: Vector3) -> void:
	var c0: Vector2i = _celda_de(centro - mitad)
	var c1: Vector2i = _celda_de(centro + mitad)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var q := Vector2i(x, y)
			var cc: Vector3 = _centro_celda(q, ALTO)
			if absf(cc.x - centro.x) <= mitad.x + 0.01 and absf(cc.z - centro.z) <= mitad.z + 0.01:
				_celdas_muro[q] = true


## Lo que test_2.gd coloca fuera del plano: guardados, objetos del suelo y carteles de cada cámara.
func _colocar_extras() -> void:
	if _reglas != null:
		_reglas.colocar(self)
	if nivel == "pruebas":
		for e in NivelPruebas.piezas():     # una pieza de cada (se hornean como decorado; los rótulos van aparte, ver hornear)
			_poner(String(e[0]), e[1] as Vector2i, ALTO, bool(e[2]), false, 0.0)
	for g in _guardados:
		var c: Vector2i = g
		_poner("baldosa_guardado", c, ALTO, false, false, 0.0)
		_disco(VFX + "circulo_runico.png", _centro_celda(c, Y_SOBRE_PLANA), S * 0.8, Color(0.6, 0.85, 1.0))
	for o in _suelo_obj:
		var datos: Array = o
		var c2 := Vector2i(int(datos[1]), int(datos[2]))
		if String(datos[0]) == "pocion":
			_poner("pocion", c2, ALTO, false)
		else:
			_oro(_centro_celda(c2, ALTO))
	for k in _rotulos:
		var c3: Vector2i = _rotulos[k]
		# El tablero del cartel de Meshy mira a 41° del eje: girado así queda de cara a la cámara (+Z).
		_poner("cartel", c3, ALTO, true, false, GIRO_CARTEL)
		_runa_cartel(String(k), _centro_celda(c3, ALTO))
		_runa_suelo(String(k), _centro_celda(c3 + Vector2i(0, 1), Y_DECAL))
		_sin_hierba[c3 + Vector2i(0, 1)] = true
		var l3 := Label3D.new()
		l3.text = String(k).to_upper()
		l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l3.font_size = 64
		l3.outline_size = 12
		l3.modulate = _color_prueba[k]
		l3.position = _centro_celda(c3, ALTO + 1.9)
		l3.pixel_size = 0.006
		_props.add_child(l3)


## Símbolo del elemento pintado en el tablero del cartel (brilla un poco: sin sombreado).
func _runa_cartel(elem: String, base: Vector3) -> void:
	var t: Texture2D = _tex(RUNAS + "runa_%s.png" % elem)
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	m.albedo_color = Color(1.15, 1.15, 1.15)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = base + RUNA_EN_TABLERO
	_props.add_child(mi)


## Baldosa rúnica del elemento delante de cada cartel: luz en el suelo que late despacio.
func _runa_suelo(elem: String, p: Vector3) -> void:
	var t: Texture2D = _tex(RUNAS + "runa_suelo_%s.png" % elem)
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(S * 0.95, S * 0.95)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_efectos.add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(m, "albedo_color", Color(1.0, 1.0, 1.0, 0.6), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "albedo_color", Color(1.3, 1.3, 1.3, 1.0), 1.4).set_trans(Tween.TRANS_SINE)


## Montoncito de monedas (no hay modelo de oro todavía).
func _oro(p: Vector3) -> Node3D:
	var moneda := CylinderMesh.new()
	moneda.top_radius = 0.09
	moneda.bottom_radius = 0.09
	moneda.height = 0.03
	moneda.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.35)
	m.roughness = 0.4
	moneda.material = m
	var monton := Node3D.new()
	monton.position = p
	_props.add_child(monton)
	for i in range(6):
		var mi := MeshInstance3D.new()
		mi.mesh = moneda
		mi.position = Vector3(float(i % 3 - 1) * 0.07, 0.015 + floorf(float(i) / 3.0) * 0.032, float((i * 7) % 3 - 1) * 0.05)
		monton.add_child(mi)
	return monton


## --- Personajes ---

func _personaje(opciones: Array, p: Vector3) -> Pj3D:
	for o in opciones:
		var id: String = String(o)
		if ResourceLoader.exists(RAIZ + Pj3D.glb_de(id) + ".glb"):
			var pj := Pj3D.new()
			pj.position = p
			add_child(pj)
			pj.cargar(id)
			pj.set_alto(float(ALTO_PJ.get(id, 1.0)))
			return pj
	_avisos.append("sin personaje " + String(opciones[0]))
	return null


func _npc(opciones: Array, p: Vector3) -> Pj3D:
	var n: Pj3D = _personaje(opciones, p)
	if n != null:
		n.rotation.y = 0.0
		_npcs_contorno.append(n)
	return n


## 11/10 (Pablo: «ponlo de mascota del guardabosques patrullando»): el gato (Meshy «gatipedro», clips idle y walk) da vueltas
## alrededor de su dueño. Sin navegación: 8 puntos en corro a RADIO_GATO del guardabosques; se quitan los que caen en una casilla que
## no se pisa (agua, árbol, pared…) y, si el corro queda cortado, patrulla de ida y vuelta por el tramo seguido más largo (así nunca
## cruza lo que no se pisa ni atraviesa al guardabosques). En cada punto impar se para un rato. Si falta el GLB, no sale y punto.
const PJ_GATO: Array = ["lince"]   # 14/10: el lince cornudo sustituye al gato (gato_guardabosques.glb y sus ajustes quedan sin uso)
const RADIO_GATO: float = 1.4          ## distancia (u) del corro al guardabosques
const VEL_GATO: float = 0.23         ## 14/10: ESTIMADO para el lince (clip walk a 0,5; pie apoyado ~0,46 u/s a velocidad normal): ajustar mirando que no patine. Lo de abajo es del gato anterior: 11/10: +50 % (antes 0,05) junto con VEL_CLIP_PJ 0,27 -> 0,405. u/s andando. 11/10: medido en LabGato3D con lo que Pablo dejó «lockeado» (PASO_CORTO 0,23 / 0,53 / 0,50, vaivenes, animación a 0,27): las patas apoyadas retroceden a ~0,04-0,06 u/s a escala del juego; más rápido, patina. Para un paseo más ágil: sube a la vez VEL_CLIP_PJ (pj_3d.gd) y esto en la misma proporción
const PAUSA_GATO: Vector2 = Vector2(0.8, 2.5)   ## s parado en un punto (al azar entre los dos)


func _mascota_guardabosques(dueno: Pj3D) -> void:
	if dueno == null or not is_instance_valid(dueno):
		return
	var centro: Vector3 = dueno.position
	var c0: Vector2i = Lanzador3D.celda_de(centro)
	var libres: Array = []            # por cada una de las 8 direcciones: el punto, o null si no se pisa
	for k in range(8):
		var ang: float = TAU * float(k) / 8.0
		var p: Vector3 = centro + Vector3(cos(ang), 0.0, sin(ang)) * RADIO_GATO
		var c: Vector2i = Lanzador3D.celda_de(p)
		var vale: bool = c == c0 or (_en_mapa(c) and not _es_agua(_letra(c)) and not _bloqueadas.has(c) and not Lanzador3D.bloqueada(c))
		libres.append(p if vale else null)
	# Tramo seguido más largo del corro (dando la vuelta).
	var mejor: Array = []
	if not libres.has(null):
		mejor = libres.duplicate()
		mejor.append(libres[0])          # corro completo: vuelve al primero
	else:
		for ini in range(8):
			if libres[ini] == null or libres[(ini + 7) % 8] != null:
				continue                 # solo empiezan tramos justo después de un hueco
			var tramo: Array = []
			var k2: int = ini
			while libres[k2 % 8] != null and tramo.size() < 8:
				tramo.append(libres[k2 % 8])
				k2 += 1
			if tramo.size() > mejor.size():
				mejor = tramo
		if mejor.size() >= 2:
			var vuelta: Array = mejor.duplicate()
			vuelta.reverse()
			mejor.append_array(vuelta.slice(1))      # ida y vuelta
	if mejor.size() < 2:
		_avisos.append("gato del guardabosques: no hay sitio libre a su alrededor")
		return
	var gato: Pj3D = _personaje(PJ_GATO, mejor[0])
	if gato == null:
		return
	var tw: Tween = gato.create_tween().set_loops()
	for i in range(mejor.size() - 1):
		var a: Vector3 = mejor[i]
		var b: Vector3 = mejor[i + 1]
		tw.tween_callback(_gato_anda.bind(gato, b - a))
		tw.tween_property(gato, "position", b, maxf(a.distance_to(b) / VEL_GATO, 0.1))
		if i % 2 == 1:
			tw.tween_callback(gato.jugar.bind("idle"))
			tw.tween_callback(_gato_maulla.bind(gato))
			tw.tween_interval(randf_range(PAUSA_GATO.x, PAUSA_GATO.y))


## 14/10: el lince maúlla a veces al pararse (una de cada tres pausas, aprox.). Suena en su sitio: solo se oye si estás cerca.
func _gato_maulla(gato: Pj3D) -> void:
	if is_instance_valid(gato) and randf() < 0.35:
		Sfx3D.play(gato, "gato_maullido")


func _gato_anda(gato: Pj3D, d: Vector3) -> void:
	if d.length() > 0.001:
		gato.rotation.y = atan2(d.x, d.z)      # el modelo mira a +Z, como los demás personajes
	gato.jugar("walk")


## El puesto de venta en `c` (ocupa c y c+x) con su tendero dentro, de cara a la cámara. Lo usan las letras n/Q y el
## Test de jugabilidad (PUESTO_CELDA).
func poner_puesto(c: Vector2i, tendero: Array) -> Pj3D:
	var antes: bool = _en_marcador
	_en_marcador = true            # el puesto sale de su marcador (n / Q), no del decorado del nivel
	_poner("puesto", c, ALTO, true, false, 0.0)
	_bloqueadas[c + Vector2i(1, 0)] = true
	_en_marcador = antes
	return _npc(tendero, _centro_celda(c, ALTO) + Vector3(0.0, 0.0, -S * 0.35))


## --- Efectos ---

func _mat_sprite(ruta: String, aditivo: bool, frames: int = 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(ruta)
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if frames > 1:
		m.particles_anim_h_frames = frames
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = true
	return m


func _particulas(ruta: String, p: Vector3, cantidad: int, vida: float, caja: Vector3, vel: float,
		apertura: float, tam: float, aditivo: bool, frames: int = 1, gravedad: Vector3 = Vector3.ZERO,
		tam_final: float = 0.4, color: Color = Color.WHITE) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3.UP
	pm.spread = apertura
	pm.initial_velocity_min = vel * 0.7
	pm.initial_velocity_max = vel * 1.3
	pm.gravity = gravedad
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.angle_min = -20.0
	pm.angle_max = 20.0
	var curva := Curve.new()
	curva.max_value = 2.0
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, tam_final))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	if frames > 1:
		pm.anim_speed_min = 1.0
		pm.anim_speed_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(tam, tam)
	quad.material = _mat_sprite(ruta, aditivo, frames)
	var gp := GPUParticles3D.new()
	gp.amount = cantidad
	gp.lifetime = vida
	gp.process_material = pm
	gp.draw_pass_1 = quad
	gp.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12))
	gp.position = p
	_efectos.add_child(gp)
	return gp


## Fuego: llamas 3D, brasas y humo (Vfx3D.fuego_fijo), con luz cálida. `barrera` = muro de llamas que ocupa la casilla.
func _fuego(p: Vector3, barrera: bool, escala: float = 1.0, eje: Vector3 = Vector3.RIGHT) -> void:
	_fx.fuego_fijo(p, barrera, escala, eje, S)
	LuzTitila3D.aplicar(_luz(p + Vector3(0, 0.8 * escala, 0), Color(1.0, 0.6, 0.3), 1.6 if barrera else 1.1, 4.0 if barrera else 3.0))


func _esporas(p: Vector3) -> void:
	_fx.esporas(p)


func _destellos(p: Vector3, color: Color) -> void:
	_fx.destellos(p, color)
	_luz(p, color, 1.0, 4.0)


## Pétalos y hojas que caen despacio alrededor de la cámara.
func _ambiente() -> void:
	if estilo == "cueva":
		# La cueva: motas de polvo que flotan despacio (no pétalos ni hojas, que caen de los árboles).
		var p := _particulas(VFX + "polvo.png", Vector3.ZERO, 18, 9.0, Vector3(9, 1.2, 9), 0.08, 60.0, 0.06, false,
			1, Vector3(0.04, 0.02, 0.03), 0.5)
		p.name = "AmbienteCueva"
		return
	var a := _particulas(VFX + "petalo.png", Vector3.ZERO, 26, 7.0, Vector3(9, 0.5, 9), 0.25, 60.0, 0.22, false,
		1, Vector3(0.15, -0.25, 0.05), 1.0)
	a.name = "Ambiente1"
	var b := _particulas(VFX + "hoja.png", Vector3.ZERO, 14, 8.0, Vector3(9, 0.5, 9), 0.2, 60.0, 0.25, false,
		1, Vector3(0.2, -0.22, 0.0), 1.0)
	b.name = "Ambiente2"
	var pm1: ParticleProcessMaterial = a.process_material as ParticleProcessMaterial
	pm1.angular_velocity_min = -60.0
	pm1.angular_velocity_max = 60.0
	var pm2: ParticleProcessMaterial = b.process_material as ParticleProcessMaterial
	pm2.angular_velocity_min = -45.0
	pm2.angular_velocity_max = 45.0


func _luz(p: Vector3, color: Color, energia: float, rango: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	_efectos.add_child(l)
	return l


## Un círculo rúnico plano (pieza 3D de Formas3D) tumbado en el suelo, que gira despacio. `_ruta` ya no se usa (era el sprite).
func _disco(_ruta: String, p: Vector3, tam: float, color: Color) -> void:
	var mi: MeshInstance3D = Formas3D.instancia("runa", color)
	mi.scale = Vector3(tam, 1.0, tam)
	var pivote := Node3D.new()
	pivote.add_child(mi)
	_efectos.add_child(pivote)
	pivote.position = p
	_girar.append(pivote)


## Un sprite de pie que mira a la cámara (telaraña).
func _cartel_plano(ruta: String, p: Vector3, tam: float, aditivo: bool, color: Color) -> void:
	var s3 := Sprite3D.new()
	s3.texture = _tex(ruta)
	s3.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s3.pixel_size = tam / float(maxi(s3.texture.get_width(), 1)) if s3.texture != null else 0.01
	s3.modulate = color
	s3.shaded = false
	s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if aditivo:
		s3.modulate = color
	s3.position = p
	_props.add_child(s3)


## --- Estado del suelo -------------------------------------------------------------------------------------
## Las reglas son las de docs/ESTADOS_SUELO.md (sacadas del 2D); si difieren de IMPLEMENTAR_TECNICAS.md Paso 1,
## manda aquel. B2: el estado (R quemado · G mojado · B helado) es `Terreno3D.estados`, el oficial; aquí solo se escribe el AVANCE visual del quemado
## (`_poner_quemado`) y lo PISADO (solo aspecto, `_img_pisado`).

func _celda_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))


func _en_mapa(c: Vector2i) -> bool:
	if Terreno3D.datos_propios:
		return Terreno3D.en_mapa(c)
	return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado


## Hierba en el sentido del 2D (letras v/G): casilla de tipo hierba, sin objeto encima y que no sea agua.
func _es_hierba(c: Vector2i) -> bool:
	var l: String = _letra(c)
	if _solo_zona_v() and l != "v":
		return false
	return l != "#" and not _es_agua(l) and not _bloqueadas.has(c) and _tipo_suelo(c) == 0


## ¿La hierba solo en ZONA_V? Solo en niveles editables (menos el Test 2) y en los mapas de archivo (9.5), si el export está marcado.
func _solo_zona_v() -> bool:
	return hierba_solo_en_zona_v and (_de_archivo or (_modo_nivel and nivel != "test2"))


## 9.6: la hierba corta decorativa (`,`) sale a algo más de la mitad de alto que la de las zonas V. No arde: `_es_hierba` solo
## cuenta las `v`, así que el fuego no prende ni se propaga en ella.
const ALTO_HIERBA_CORTA: float = 0.55


func _alto_hierba(x: float, z: float) -> float:
	return ALTO_HIERBA_CORTA if _letra(Vector2i(floori(x / S), floori(z / S))) == "," else 1.0


## Lo que se VE de «quemado» en una casilla (0..1): el círculo que crece mientras la hierba arde, y 1 en la ceniza y en la hierba segada (el suelo
## queda oscurecido). Es el AVANCE visual del estado oficial (`EstadosSuelo3D.poner_avance`): no es un hecho, la casilla solo pasa a `quemada` para
## los puzles pasada la mitad (`ReaccionesSuelo3D.sincronizar_hierba`). Mojado y helado no pasan por aquí: son hechos y los escribe el estado.
func _poner_quemado(c: Vector2i, valor: float) -> void:
	if not _en_mapa(c):
		return
	Terreno3D.estados.poner_avance(c, EstadosSuelo3D.QUEMADA, valor)


## Suma `cantidad` a lo pisado de la casilla y las de alrededor (radio en casillas), saturando a 1.
## Las esquinas del cuadrado reciben la mitad: la marca queda redondeada.
func marcar_pisado(c: Vector2i, cantidad: float, radio: int = 0) -> void:
	for y in range(c.y - radio, c.y + radio + 1):
		for x in range(c.x - radio, c.x + radio + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q) or x < 0 or y < 0 or x >= _img_pisado.get_width() or y >= _img_pisado.get_height():
				continue
			var k: float = cantidad * (0.5 if absi(x - c.x) + absi(y - c.y) > radio else 1.0)
			var v: float = clampf(_img_pisado.get_pixel(x, y).r + k, 0.0, 1.0)
			_img_pisado.set_pixel(x, y, Color(v, 0.0, 0.0, 1.0))
			if v > 0.0:
				_pisadas[q] = true
	_pisado_sucio = true


## Qué deja cada hechizo en el suelo, según el tipo de casilla. Un impacto toca UNA casilla (radio 0 como en el 2D).
func _al_impactar(elemento: String, punto: Vector3) -> void:
	if _precalentando:
		return
	_golpear_objetos(elemento, punto)
	var c: Vector2i = _celda_de(punto)
	if not _en_mapa(c):
		return
	if elemento == "agua" or elemento == "hielo":
		_apagar_area(c, punto, elemento == "hielo")
	if _es_agua(_letra(c)):
		_impacto_en_agua(elemento, c)
	elif _es_hierba(c):
		_impacto_en_hierba(elemento, c)
	elif not _bloqueadas.has(c):
		_impacto_en_suelo(elemento, c)
	if elemento == "viento":
		marcar_pisado(c, 1.0, 2)      # tumba la hierba en un radio grande: solo aspecto (§5)


## Suelo neutro (§1.1, §4.1): SECO → MOJADO → HELADO. El fuego deshace un escalón y no quema.
## B2: la regla es `EstadosSuelo3D.TRANSICIONES` y quien la aplica es `Mundo3D.aplicar_accion` desde `Lanzador3D.al_impactar` (el juego). La maqueta
## suelta (sin Lanzador: Test 2, capturas) la aplica ella misma aquí, UNA vez, para que el suelo se moje igualmente. En los dos casos el suelo solo
## se DIBUJA leyendo el estado; aquí lo único propio es el vapor del charco que se seca (se decide con el estado de ANTES del impacto).
func _impacto_en_suelo(elemento: String, c: Vector2i) -> void:
	var accion: String = String(ReaccionesSuelo3D.ACCION_DE.get(elemento, ""))
	if accion == "":
		return                    # rayo (descarga: lo hace el VFX), tierra y viento: no cambian canales del suelo.
	var e: EstadosSuelo3D = Terreno3D.estados
	if elemento == "fuego" and e.tiene(c, EstadosSuelo3D.MOJADA) and not e.tiene(c, EstadosSuelo3D.HELADA):
		_fx.vapor(_centro_celda(c, ALTO))      # el charco se seca con vapor (el hielo, en cambio, pasa a charco sin vapor)
	if not _juego_aplica_estado():
		e.aplicar(c, accion)


## ¿Hay un Lanzador que aplica los estados del suelo (`Mundo3D.aplicar_accion`) en cada impacto? Si no, la maqueta lo hace ella (ver `_impacto_en_suelo`).
func _juego_aplica_estado() -> bool:
	return Lanzador3D.mundo_s == self or get_node_or_null("Lanzador3D") != null


## Agua (§1.5): el agua helada se puede pisar. El hielo dura (20 s con la simulación) y el fuego lo funde; la placa se quita al soltarse.
func _impacto_en_agua(elemento: String, c: Vector2i) -> void:
	match elemento:
		"hielo":
			if not Terreno3D.helada(c):
				Terreno3D.poner_helada(c, true)      # el hecho vive en Mundo3D.estados; el agua y el suelo lo dibujan leyéndolo
				_liberar(c)
				if not agua_fisica:
					_poner_placa_hielo(c)      # con agua física el hielo lo dibuja AguaRender3D desde la simulación (11.14)
		"fuego":
			_fx.vapor(_centro_celda(c, ALTO_AGUA))      # hierve; el hielo no se derrite


## El Mundo3D avisa de que algo cambió en una casilla. Aquí solo se redibuja: el dato ya lo tiene el mundo.
## «hielo»: el suelo y el agua ya dibujan el hielo leyendo el estado; aquí solo se quita la placa cuando la casilla deja de estar helada (11.16: sin
## hielo no hay placa; antes se quedaba para siempre aunque el agua volviera), lo deshiele quien sea (esta maqueta o el Juego). Idempotente.
## 14.2 · P3 (rastrojo). El Juego emite `EstadosSuelo3D.cambio(c, "segada", si)`; la maqueta dibuja el rastrojo y deja la hierba de la casilla
## encogida (avance de «quemado» a 1, el mismo canal R). `quemada` = que antes de segarse ardió (mata carbonizada en vez de cortada); si no se dice, se
## mira el quemado de la casilla. Pública para que el Juego la pueda llamar directamente si prefiere no pasar por el estado.
func marcar_segada(c: Vector2i, si: bool, quemada: bool = false) -> void:
	if _rastrojo == null or not _en_mapa(c):
		return
	if si:
		var e: EstadosSuelo3D = Terreno3D.estados
		var ardio: bool = quemada or e.avance(c, EstadosSuelo3D.QUEMADA) >= 0.5 or e.tiene(c, EstadosSuelo3D.QUEMADA)
		var y: float = ALTO
		if Terreno3D.datos_propios:
			y = Terreno3D.alto_suelo + float(Terreno3D.altura_en(c)) * Terreno3D.ALTO_NIVEL
		_rastrojo.poner(c, y, Rastrojo3D.TIPO_QUEMADO if ardio else Rastrojo3D.TIPO_CORTADO)
		_poner_quemado(c, 1.0)
		if _hierba != null:
			_hierba.set_crecida(c, 0.0)
	else:
		_rastrojo.quitar(c)
		if not _hf.has(c):
			_poner_quemado(c, 0.0)


func _al_cambiar_estado_suelo(c: Vector2i, estado: String, si: bool) -> void:
	if estado == "segada":
		marcar_segada(c, si)


func _al_cambiar_casilla(c: Vector2i, que: String) -> void:
	if que == "hielo" and _en_mapa(c) and not Terreno3D.helada(c):
		quitar_placa_hielo(c)


## M3 (13/10): el mundo avisa de DÓNDE y de QUÉ pasó con `impacto`; aquí se decide cómo se pinta. Hoy el Lanzador pinta el vapor y
## el hielo que crece llamando a `get("_fx")` / `get("_agua_render")` sobre esta maqueta (campos privados, ARQUITECTURA_MODULAR §5).
## Para que pueda dejar de hacerlo, escucho dos avisos: «vapor» (se evaporó agua o se fundió hielo) y «hielo_desde» (va a helarse
## desde ese punto: el render hace crecer el hielo). Los demás elementos los sigue pintando el hechizo; no se duplica nada.
func _al_impacto_mundo(punto: Vector3, elemento: String, _radio: float) -> void:
	match elemento:
		"vapor":
			if _fx != null:
				_fx.vapor(punto)
		"hielo_desde":
			if _agua_render != null and _agua_render.has_method("hielo_desde"):
				_agua_render.hielo_desde(punto)


## Hierba (§1.2, §4.2). Sin entrada en _hf = FINA.
func _impacto_en_hierba(elemento: String, c: Vector2i) -> void:
	match prever_hierba(elemento, c):
		"prende":
			_poner_fase(c, Fase.PRENDIENDO)
		"arde":
			_poner_fase(c, Fase.ARDIENDO)
		"brota":
			_hf[c] = {"fase": Fase.CRECIDA, "t": 0.0, "v": 0.0, "fx": null}     # brota (y pasa a bloquear)
		"apaga":
			_apagar(c)                                                          # FINA, R = 0 (rebrota)
		"abanica":
			_abanicar(c)


## 28/10 · A2 (previsión): qué le haría este elemento a la hierba de la casilla `c`, sin tocarla: «prende» (fuego sobre hierba que no está mojada ni ardiendo, con hueco para otra
## llama), «arde» (rayo), «brota» (agua o hielo sobre hierba corta), «apaga» (agua o hielo sobre la que arde), «abanica» (el viento aviva la que arde) o «» (nada). Es la regla de
## `_impacto_en_hierba`, que la ejecuta; la previsión del indicador (`ReaccionesSuelo3D.prever`) la consulta por aquí.
func prever_hierba(elemento: String, c: Vector2i) -> String:
	var f: int = int((_hf[c] as Dictionary)["fase"]) if _hf.has(c) else 0
	match elemento:
		"fuego":
			if (f == 0 or f == Fase.CRECIDA) and _puede_prender(c):
				return "prende"
		"rayo":
			if f == 0 or f == Fase.CRECIDA or f == Fase.PRENDIENDO:
				return "arde"
		"agua", "hielo":
			if f == 0:
				return "brota"
			if f == Fase.PRENDIENDO or f == Fase.ARDIENDO or f == Fase.CENIZAS:
				return "apaga"
		"viento":
			if f == Fase.ARDIENDO:
				return "abanica"
	return ""


## ¿Puede empezar a prender la hierba de `c`? No si ya hay MAX_ARDIENDO casillas encendidas (una GPU integrada no lo aguanta) ni si está mojada (si no, el fuego vecino la reenciende al instante).
func _puede_prender(c: Vector2i) -> bool:
	var ardiendo: int = 0
	for k in _hf:
		var fk: int = int((_hf[k] as Dictionary)["fase"])
		if fk == Fase.PRENDIENDO or fk == Fase.ARDIENDO:
			ardiendo += 1
	if ardiendo >= MAX_ARDIENDO:
		return false
	return int(_mojada.get(c, 0)) <= Time.get_ticks_msec()


func _quitar_fx(c: Vector2i) -> void:
	if _hf.has(c):
		var fx: Variant = (_hf[c] as Dictionary).get("fx")
		if fx != null and is_instance_valid(fx):
			_fx.apagar(fx as Node3D)
		(_hf[c] as Dictionary)["fx"] = null


func _poner_fase(c: Vector2i, fase: int) -> void:
	var viejo: Dictionary = _hf.get(c, {})
	# Tope: una GPU integrada no aguanta medio mapa en llamas (el 6/10 se congeló). Más allá de MAX_ARDIENDO casillas encendidas a la
	# vez no se propaga más; más allá de MAX_FX_HIERBA siguen ardiendo (quemado en el suelo) pero sin partículas.
	var con_fx: int = 0
	for k in _hf:
		var dk: Dictionary = _hf[k]
		var fk: int = int(dk["fase"])
		if fk == Fase.PRENDIENDO or fk == Fase.ARDIENDO:
			if dk.get("fx") != null:
				con_fx += 1
	if fase == Fase.PRENDIENDO and not _puede_prender(c):
		return                                  # ya hay MAX_ARDIENDO encendidas, o está mojada (si no, el fuego vecino la reenciende al instante)
	_quitar_fx(c)
	var d: Dictionary = {"fase": fase, "t": 0.0, "v": 0.0, "frente": float(viejo.get("frente", 0.0)),
		"contagia": bool(viejo.get("contagia", true)), "fx": null}
	if con_fx < MAX_FX_HIERBA:
		d["fx"] = _fx.llamas(_centro_celda(c, ALTO), 0.5 if fase == Fase.PRENDIENDO else 1.0, S * 0.32)
	_hf[c] = d
	if _hierba != null:
		_hierba.set_crecida(c, 0.0)       # deja de ser alta: se achicharra


## Apagada o regada tras arder: FINA otra vez, sin rastro.
## El agua (y el hielo) apagan todo lo que arde alrededor del impacto y dejan la hierba mojada unos segundos.
## Bloque 1 EoW: además se VE: el agua la moja y el hielo le pone escarcha (`Hierba3D`, solo aspecto), con menos fuerza hacia el borde.
func _apagar_area(c: Vector2i, punto: Vector3, con_hielo: bool = false) -> void:
	var ahora: int = Time.get_ticks_msec() + T_MOJADA_MS
	for y in range(c.y - RADIO_APAGAR, c.y + RADIO_APAGAR + 1):
		for x in range(c.x - RADIO_APAGAR, c.x + RADIO_APAGAR + 1):
			var q := Vector2i(x, y)
			if not _en_mapa(q) or not _es_hierba(q):
				continue
			_mojada[q] = ahora
			if _hierba != null:
				var k: float = 1.0 - 0.6 * float(maxi(absi(x - c.x), absi(y - c.y))) / float(maxi(RADIO_APAGAR, 1))
				if con_hielo:
					_hierba.escarchar(q, k)
				else:
					_hierba.mojar(q, k)
			if _hf.has(q):
				var f: int = int((_hf[q] as Dictionary)["fase"])
				if f == Fase.PRENDIENDO or f == Fase.ARDIENDO or f == Fase.CENIZAS:
					_apagar(q)
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE):
		var o: Reactivo3D = n as Reactivo3D
		if o == null or o.estado != Reactivo3D.EstadoObj.ARDIENDO:
			continue
		var d: Vector3 = o.global_position - punto
		d.y = 0.0
		if d.length() <= (RADIO_APAGAR + 0.5) * S:
			o._apagar()


func _apagar(c: Vector2i) -> void:
	_quitar_fx(c)
	_hf.erase(c)
	_poner_quemado(c, 1.0 if _rastrojo != null and _rastrojo.hay(c) else 0.0)       # una casilla segada no vuelve a crecer
	if _hierba != null:
		_hierba.set_crecida(c, 0.0)


## Viento con dirección sobre hierba ARDIENDO: prende la hierba del cono de delante (≤ 230 px, producto escalar ≥ 0,3).
func _abanicar(c: Vector2i) -> void:
	var r: int = ceili(CONO_VIENTO)
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var q := Vector2i(x, y)
			if q == c or not _en_mapa(q) or not _es_hierba(q):
				continue
			var d := Vector2(float(x - c.x), float(y - c.y))
			if d.length() > CONO_VIENTO or d.normalized().dot(Vector2(_dir_hechizo.x, _dir_hechizo.z)) < 0.3:
				continue
			var f: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
			if f == 0 or f == Fase.CRECIDA:
				_poner_fase(q, Fase.PRENDIENDO)


## Cada fotograma mientras haya algo vivo: fases de la hierba, contagio por frente y pisadas.
func _avanzar_estado(dt: float) -> void:
	var prender: Array[Vector2i] = []
	var promover: Array[Vector2i] = []
	var ceniza: Array[Vector2i] = []
	var objetos_a_prender: Array[Reactivo3D] = []
	for c in _hf:
		var d: Dictionary = _hf[c]
		var f: int = int(d["fase"])
		if f == Fase.CRECIDA:
			if float(d["v"]) < 1.0:
				d["v"] = minf(float(d["v"]) + dt / T_CRECER, 1.0)
				if _hierba != null:
					_hierba.set_crecida(c, float(d["v"]))
			continue
		if f != Fase.PRENDIENDO and f != Fase.ARDIENDO:
			continue
		d["t"] = float(d["t"]) + dt
		if f == Fase.PRENDIENDO and float(d["t"]) >= T_PRENDIENDO:
			promover.append(c)
		elif f == Fase.ARDIENDO:
			_poner_quemado(c, float(d["t"]) / T_ARDIENDO)        # el círculo quemado crece mientras arde
			if float(d["t"]) >= T_ARDIENDO:
				ceniza.append(c)
		# Contagio por frente: un círculo que crece desde la casilla; prende la primera hierba que toque y se acaba.
		# 6.9a: el fuego salta solo a las 4 vecinas (sin diagonales) y espera T_SALTO s tras prender antes de contagiar.
		if bool(d["contagia"]) and float(d["t"]) >= T_SALTO:
			d["frente"] = maxf(float(d["frente"]) + dt * FRENTE_VEL, 1.0)   # las vecinas están a 1: alcanzable ya
			var fr: float = float(d["frente"])
			if fr > FRENTE_MAX:
				d["contagia"] = false
			elif fr >= FRENTE_MIN:
				var objeto: Reactivo3D = _objeto_al_alcance(c, fr) if objetos_reactivos else null
				if objeto != null:
					# El frente toca primero un objeto que arde (seto, tronco, telaraña): prende y el frente se acaba.
					objetos_a_prender.append(objeto)
					d["contagia"] = false
					continue
				var mejor := Vector2i(-1, -1)
				var dm: float = 1.0e9
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = c + v
					var dist: float = Vector2(v).length()
					if dist > fr or not _en_mapa(q) or not _es_hierba(q):
						continue
					var fq: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
					if fq != 0 and fq != Fase.CRECIDA:
						continue
					var desempate: float = dist + float(_hash(q.x, q.y, 21) % 100) * 0.0001
					if desempate < dm:
						dm = desempate
						mejor = q
				if mejor.x >= 0:
					prender.append(mejor)
					d["contagia"] = false
	for c in promover:
		_poner_fase(c, Fase.ARDIENDO)
		(_hf[c] as Dictionary)["t"] = 0.0
	for c in ceniza:
		_quitar_fx(c)
		_poner_quemado(c, 1.0)
		var d2: Dictionary = _hf[c]
		d2["fase"] = Fase.CENIZAS
	for o in objetos_a_prender:
		if is_instance_valid(o):
			o.ignite()
	for q in prender:
		var fq2: int = int((_hf[q] as Dictionary)["fase"]) if _hf.has(q) else 0
		if fq2 == 0 or fq2 == Fase.CRECIDA:
			_poner_fase(q, Fase.PRENDIENDO)
	# Lo pisado se levanta solo (baja en T_PISADO s). Mojado y helado no caducan (§4.4.5).
	var libres: Array[Vector2i] = []
	for c in _pisadas:
		var v: float = maxf(_img_pisado.get_pixel(c.x, c.y).r - dt / T_PISADO, 0.0)
		_img_pisado.set_pixel(c.x, c.y, Color(v, 0.0, 0.0, 1.0))
		_pisado_sucio = true
		if v <= 0.0:
			libres.append(c)
	for c in libres:
		_pisadas.erase(c)


## Tapa la pantalla un momento y lanza los seis elementos: compila shaders y carga texturas antes de jugar.
## Mientras dura, los impactos no marcan el suelo.
func _precalentar(capa: CanvasLayer) -> void:
	if _jugador == null or not precalentar_al_inicio:
		return
	var velo := ColorRect.new()
	velo.color = Color(0.81, 0.91, 0.94)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aviso := Label.new()
	aviso.text = "Preparando efectos..."
	aviso.position = Vector2(24.0, 24.0)
	aviso.add_theme_color_override("font_color", Color(0.25, 0.35, 0.4))
	velo.add_child(aviso)
	capa.add_child(velo)
	_precalentando = true
	_velo = velo
	_t_velo = 0.0
	_f_velo = 0
	_ms_velo = Time.get_ticks_msec()
	_fx.precalentar(_jugador.position, _jugador.position + Vector3(1.5, 0.0, 1.5))


## --- Bucle ---

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_F9:
			_hornear_con_aviso()
		KEY_F10:
			_alternar_capa_agua()
		KEY_Z, KEY_C:
			# Giro de 90° de la cámara (Z/C: Q y E son beber y hablar en Jugador3D). El movimiento sigue a la cámara.
			_giro_cam = fposmod(_giro_cam + (90.0 if k.keycode == KEY_Z else -90.0), 360.0)
			_colocar_camara()
		KEY_H:
			_sol.shadow_enabled = not _sol.shadow_enabled
		KEY_P:
			_efectos.visible = not _efectos.visible
		KEY_K:
			_props.visible = not _props.visible
		KEY_G:
			if _hierba != null:
				_hierba.visible = not _hierba.visible
		KEY_J:
			if _hierba != null:
				_hierba.set_modo(_hierba.modo + 1)
		KEY_L:
			if _jugador != null:
				_jugador.set_modo_luz(1 - _jugador.modo_luz)
		KEY_F7:
			# 14.2 (a): enciende/apaga el diorama (el desenfoque del fondo) para comparar capturas.
			diorama = not diorama
			print("Diorama (desenfoque del fondo): %s" % ("sí" if diorama else "no"))
		# F1–F6 ya no lanzan el VFX de cada elemento (23/10): los hechizos solo salen escribiendo en el libro. F1 es de la paleta de runas.
		KEY_PAGEUP:
			# RePág: siguiente zona de luz (bosque → cenital → atardecer → ruinas → hielo). Solo cambia sol y ambiente.
			zona_luz = LuzZona3D.siguiente(zona_luz)
			LuzZona3D.aplicar(_env, _sol, zona_luz)
			print("Zona de luz: %s" % zona_luz)
		KEY_PAGEDOWN:
			# AvPág: enciende/apaga la banda de tilt-shift.
			tilt_shift = not tilt_shift
			if _tilt != null:
				_tilt.encendido = tilt_shift
			print("Tilt-shift: %s" % ("sí" if tilt_shift else "no"))
		KEY_HOME:
			# Inicio: crea / quita la sonda de reflejos (al crearla se hornea de nuevo con lo que haya ahora).
			sonda_reflejos = not sonda_reflejos
			_montar_sonda()
			print("Sonda de reflejos: %s" % ("sí" if sonda_reflejos else "no"))
		KEY_T:
			# Rampa de luz del suelo y del agua: 1 (como el PBR) · 2,5 · 4 (cel suave). Para comparar capturas.
			_contraste = 1.0 if _contraste >= 4.0 else (2.5 if _contraste < 2.5 else 4.0)
			_mat_suelo.set_shader_parameter("contraste", _contraste)
			_mat_agua.set_shader_parameter("contraste", maxf(_contraste * 0.6, 1.0))
		KEY_F8:
			# 20/10 (203): enciende/apaga el VFX por ESTADO de la materia (VfxEstado3D), apagado de serie. Para compararlo con el de elemento.
			var ve: VfxEstado3D = get_node_or_null("VfxEstado3D") as VfxEstado3D
			if ve != null:
				ve.encendido = not ve.encendido
				print("VFX por estado (VfxEstado3D): %s" % ("ENCENDIDO" if ve.encendido else "apagado"))
		KEY_V:
			_danar_empujable_cercano()
		KEY_B:
			# Relieve del suelo: 0 (liso) · 0,5 · 1. Para comparar capturas.
			_rugosidad = 0.0 if _rugosidad >= 1.0 else (0.5 if _rugosidad < 0.5 else 1.0)
			_mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
			print("Rugosidad del suelo: %.1f" % _rugosidad)
		KEY_N:
			if _jugador != null:
				_jugador.set_nivel_grimorio(Equipo3D.nivel_grimorio % 3 + 1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_tam_camara = maxf(ZOOM_MINIMO, _tam_camara * 0.9)
			_camara.size = _tam_camara
		KEY_MINUS, KEY_KP_SUBTRACT:
			_tam_camara = minf(60.0, _tam_camara * 1.1)
			_camara.size = _tam_camara
		KEY_BRACKETLEFT:
			if _jugador != null:
				_jugador.set_escala(_jugador.scale.x * 0.9)
		KEY_BRACKETRIGHT:
			if _jugador != null:
				_jugador.set_escala(_jugador.scale.x * 1.1)
		KEY_COMMA, KEY_PERIOD:
			# Postura: , baja la cabeza 2°, . la echa atrás 2° (con Shift, los hombros: < cierra, > abre).
			if _jugador != null:
				var q: Array = _jugador.postura()
				var paso: float = 2.0 if k.keycode == KEY_PERIOD else -2.0
				if k.shift_pressed:
					q[3] = float(q[3]) + paso
				else:
					q[0] = float(q[0]) + paso
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()
		KEY_U, KEY_I:
			# Piernas: U dobla las rodillas 2°, I las estira (con Shift, los pies: cierra / abre).
			# Letras y no ; ' porque en teclado español ; es Shift+, y Godot nunca lo manda como tecla propia.
			if _jugador != null:
				var q: Array = _jugador.postura()
				var paso: float = 2.0 if k.keycode == KEY_I else -2.0
				if k.shift_pressed:
					q[5] = float(q[5]) + paso
				else:
					q[4] = float(q[4]) + paso
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()
		KEY_Y, KEY_O:
			# Pelvis: Y la echa adelante 2°, O la endereza (quita el culo en pompa sin mover las piernas).
			if _jugador != null:
				var q: Array = _jugador.postura()
				q[6] = float(q[6]) + (2.0 if k.keycode == KEY_O else -2.0)
				_jugador.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
				_imprimir_postura()


## Tipo de hierba: 0 briznas · 1 tarjetas pintadas · 2 las dos (tecla J).
func set_modo_hierba(m: int) -> void:
	if _hierba != null:
		_hierba.set_modo(m)


## Impactos de prueba (capturas y QA): [["fuego", Vector2i(12, 8)], ["agua", Vector2i(13, 8)], ...].
func impactar_en(lista: Array) -> void:
	_precalentando = false
	for e in lista:
		var punto: Vector3 = _centro_celda(e[1] as Vector2i, ALTO)
		_al_impactar(String(e[0]), punto)
		if _juego_aplica_estado():      # con Lanzador, el estado lo escribe `Lanzador3D.al_impactar`, que aquí no pasa: se hace como él
			Mundo3D.aplicar_accion(AccionElemental.nueva(String(e[0]), punto))


## Escribe en la consola el estado de cada casilla viva (QA): fase de la hierba y canales del suelo.
func imprimir_estado() -> void:
	for c in _hf:
		var d: Dictionary = _hf[c]
		print("CAPTURA estado ", c, " fase=", Fase.find_key(int(d["fase"])), " t=", snappedf(float(d["t"]), 0.1))
	var img: Image = Terreno3D.estados.imagen()
	for y in range(mini(_lado, img.get_height())):
		for x in range(mini(_lado, img.get_width())):
			var p: Color = img.get_pixel(x, y)
			if p.r > 0.0 or p.g > 0.0 or p.b > 0.0:
				print("CAPTURA canales ", Vector2i(x, y), " R=", snappedf(p.r, 0.01), " G=", p.g, " B=", p.b)


## Lleva a la chibi a una casilla (para pruebas y capturas).
func ir_a(c: Vector2i) -> void:
	if _jugador == null:
		return
	_jugador.position = _centro_celda(c, ALTO)
	_foco = _centro(_jugador)
	if _hierba != null and not hierba_completa:
		_hierba.set_radio(clampi(ceili(_tam_camara * 0.95 / _hierba.lado_bloque) + 1, 2, 7))
		_hierba.actualizar(_jugador.position, true)


func _centro(p: Pj3D) -> Vector3:
	return p.position + Vector3(0.0, 0.85 * p.scale.y, 0.0)


func _colocar_camara() -> void:
	var e: float = deg_to_rad(90.0 - _incl)
	var dir: Vector3 = (-Vector3(0.0, sin(e), cos(e))).rotated(Vector3.UP, deg_to_rad(_giro_cam))
	_camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * 40.0)


func _process(delta: float) -> void:
	_actualizar_pozos(delta)
	_vigilar_alturas(delta)
	if _jugador != null:
		if not externo:
			_mover(delta)
		if _hierba != null and not hierba_completa:
			# El radio crece con el zoom para que no se vea el borde de lo sembrado al alejar la cámara.
			_hierba.set_radio(clampi(ceili(_tam_camara * 0.95 / _hierba.lado_bloque) + 1, 2, 7))
			_hierba.actualizar(_jugador.position)
		_foco = _foco.lerp(_centro(_jugador) + Sensacion3D.adelanto_actual * (_tam_camara / ZOOM_INICIAL), 1.0 - exp(-SEGUIMIENTO * delta))     # gamefeel lote 4: el foco se adelanta hacia donde va y apunta (la misma fracción de pantalla a cualquier zoom)
		if transparencia_jugador and decorado_por_lotes:
			Ocluso3D.actualizar(_jugador.position + Vector3(0.0, 0.8, 0.0), radio_transparencia)
		var amb: Node = _efectos.get_node_or_null("Ambiente1")
		if amb != null:
			(amb as Node3D).position = _jugador.position + Vector3(0.0, 5.0, 0.0)
		var amb2: Node = _efectos.get_node_or_null("Ambiente2")
		if amb2 != null:
			(amb2 as Node3D).position = _jugador.position + Vector3(0.0, 5.0, 0.0)
		# Los goblins miran al jugador cuando está cerca.
		for g in _goblins:
			var d: Vector3 = _jugador.position - g.position
			d.y = 0.0
			if not externo and d.length() < 7.0:
				g.mirar(d, delta)
	_colocar_camara()
	_actualizar_diorama()
	for p in _girar:
		p.rotate_y(delta * 0.4)
	# Estado del suelo: avanza las fases de la hierba, levanta lo pisado y sube la textura una vez por frame.
	_t_cast = maxf(_t_cast - delta, 0.0)
	if not _hf.is_empty() or not _pisadas.is_empty():
		var t0: int = Time.get_ticks_usec()
		_avanzar_estado(delta)
		_ms_estado = lerpf(_ms_estado, float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	if _pisado_sucio:
		_tex_pisado.update(_img_pisado)      # update() reutiliza la textura en GPU; create_from_image la recrearía
		_pisado_sucio = false
	_subir_estado_juego()
	if _hierba != null:
		_hierba.subir_crecida()
		_hierba.avanzar_humedad(delta)
		if _jugador != null:
			_hierba.set_posicion_jugador(_jugador.position)
	if _velo != null:
		# Tiempo REAL (no suma de deltas): si el equipo va lento o compila shaders a tirones, el velo no se eterniza.
		_f_velo += 1
		_t_velo = float(Time.get_ticks_msec() - _ms_velo) / 1000.0
		if _f_velo > 10 and _t_velo >= PRECALENTAR:
			_velo.queue_free()
			_velo = null
			_precalentando = false
	_t_hud += delta
	if _t_hud > 0.3:
		_t_hud = 0.0
		_actualizar_hud()


func _pisable(p: Vector3) -> bool:
	var c := Vector2i(int(floorf(p.x / S)), int(floorf(p.z / S)))
	if c.x < 0 or c.y < 0 or c.y >= _lado or c.x >= _mapa[c.y].length():
		return false
	if _hf.has(c) and int((_hf[c] as Dictionary)["fase"]) == Fase.CRECIDA and float((_hf[c] as Dictionary)["v"]) > 0.5:
		return false      # la hierba crecida es sólida (grass_block.gd GROWN)
	return not _bloqueadas.has(c)


func _mover(delta: float) -> void:
	var entrada := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		entrada.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		entrada.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		entrada.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		entrada.y += 1.0
	if entrada == Vector2.ZERO:
		if _t_cast <= 0.0:
			_jugador.jugar("idle")
		return
	var mov: Vector3 = Vector3(entrada.x, 0.0, entrada.y).normalized().rotated(Vector3.UP, deg_to_rad(_giro_cam))
	var correr: bool = Input.is_key_pressed(KEY_SHIFT)
	var paso: Vector3 = mov * (VEL_CORRER if correr else VEL_ANDAR) * delta
	var destino: Vector3 = _jugador.position + paso
	if not _pisable(destino):
		destino = _jugador.position + Vector3(paso.x, 0.0, 0.0)
		if not _pisable(destino):
			destino = _jugador.position + Vector3(0.0, 0.0, paso.z)
			if not _pisable(destino):
				destino = _jugador.position
	# Sobre el puente se va a la altura del agua + tablas; en tierra, a la del bloque.
	var c := Vector2i(int(floorf(destino.x / S)), int(floorf(destino.z / S)))
	destino.y = ALTO_AGUA + 0.12 if (_letra(c) == "b" or Terreno3D.helada(c)) else ALTO
	_jugador.position = destino
	marcar_pisado(c, 0.35)      # pisa la hierba de su casilla (solo aspecto)
	_jugador.mirar(mov, delta)
	_jugador.jugar("run" if correr else "walk")


func _imprimir_postura() -> void:
	var q: Array = _jugador.postura()
	print("Postura %s: cabeza %.0f° cuello %.0f° columna %.0f° brazos %.0f° rodillas %.0f° pies %.0f° pelvis %.0f° (apúntalo en Pj3D.POSTURAS)" % [
		_jugador.id, q[0], q[1], q[2], q[3], q[4], q[5], q[6]])


func _actualizar_hud() -> void:
	var aviso: String = ""
	if not _avisos.is_empty():
		aviso = "\n(!) " + ", ".join(_avisos.slice(0, 6))
		if _avisos.size() > 6:
			aviso += " ..."
	var tipo_hierba: String = String(Hierba3D.NOMBRES_MODO[_hierba.modo]) if _hierba != null else "-"
	var dibujo: String = "dibujo: %d llamadas · %d k prim. · %d MB vídeo · %d lotes" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), _n_lotes]
	if _hierba != null:
		dibujo += " · hierba %d bloques / %d matojos" % [_hierba.numero_de_bloques(), _hierba.numero_de_matojos()]
	_hud.text = "TEST 2 en 3D | %d FPS | inclinación %d° (fija) | sombras %s | partículas %s | hierba: %s | %s%s\nWASD mover · Shift correr · +/- zoom · H sombras · P partículas · K decorado · G hierba · J tipo de hierba · [ ] tamaño · N grimorio · , . cabeza · U I rodillas · Y O pelvis (Shift: brazos / pies)\nRePág luz · AvPág tilt-shift · Inicio sonda · T rampa de luz %.1f · B relieve · V grietas del empujable más cercano · estado: %d casillas, %.2f ms" % [
		int(Engine.get_frames_per_second()), int(_incl), "sí" if _sol.shadow_enabled else "no",
		"sí" if _efectos.visible else "no", tipo_hierba, dibujo, aviso, _contraste, _hf.size() + _pisadas.size(), _ms_estado]
	if _reglas != null:
		_hud.text = _hud.text.replace("TEST 2 en 3D", "Test de jugabilidad en 3D")
	# En un laboratorio de hechizos (LabRecetas3D / LabHechizos3D) la línea de la maqueta sobra: sombras, hierba, postura, decorado… son de otros tests y
	# se pisan con los paneles del lab. Solo queda lo imprescindible para mover al jugador (18/10, Pablo: «solo lo imprescindible para pruebas»).
	if _reglas != null and _reglas.get_script() != null and String((_reglas.get_script() as Script).get_global_name()) in ["LabRecetas3D", "LabHechizos3D"]:
		_hud.text = "%d FPS · WASD mover · Shift correr · +/- zoom" % int(Engine.get_frames_per_second())


## --- 9.7 · API del Bosque (la usa el Juego: Bosque3D, 9.8–9.11) ---

## Las tres runas de la puerta final, encima del arco de `c` y repartidas a lo ancho de su abertura (`giro` = el del arco).
## Son sprites que miran a la cámara (los iconos de vfx/runas): apagadas = piedra oscura; encender_runa las prende.
func _poner_runas_puerta(c: Vector2i, giro: float) -> void:
	var eje: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(giro))     # a lo ancho del arco
	var elems: Array = ["fuego", "agua", "rayo"]
	for i in range(elems.size()):
		var el: String = elems[i]
		var t: Texture2D = _tex(RUNAS + "runa_%s.png" % el)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = t
		m.albedo_color = Color(0.22, 0.21, 0.24, 0.9)      # apagada: grabada en piedra
		var q := QuadMesh.new()
		q.size = Vector2(0.62, 0.62)
		q.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = _centro_celda(c, ALTO + ALTO_RUNAS) + eje * (float(i) - 1.0) * 0.72
		_efectos.add_child(mi)
		_runas_puerta[el] = [m, mi.position]


## Enciende (o apaga) la runa `elemento` ("fuego" | "agua" | "rayo") de la puerta: color pleno por encima de 1 (en Forward+
## el bloom la hace brillar), destello del elemento y una luz pequeña que se queda. Con las tres, la puerta es del Juego.
func encender_runa(elemento: String, si: bool = true) -> void:
	if not _runas_puerta.has(elemento):
		return
	var m: StandardMaterial3D = (_runas_puerta[elemento] as Array)[0]
	var p: Vector3 = (_runas_puerta[elemento] as Array)[1]
	var destino: Color = Color(1.6, 1.6, 1.6, 1.0) if si else Color(0.22, 0.21, 0.24, 0.9)
	create_tween().tween_property(m, "albedo_color", destino, 0.6).set_trans(Tween.TRANS_SINE)
	if si:
		_fx.chispazo(p, elemento)
		_luz(p + Vector3(0.0, 0.0, 0.3), COLOR_ELEMENTO.get(elemento, Color.WHITE), 0.8, 2.5)


## El surtidor ha echado agua: las casillas del cauce (todas si `celdas` va vacío, en orden de arriba abajo) se llenan una
## tras otra: el agua sube desde el lecho, salpica y la casilla pasa a ser agua (`~`: bloquea y conduce como el río).
## Los guijarros se hunden bajo el agua.
## 22/10 (cauce hondo): el agua SUBE desde el fondo real del foso (`Terreno3D.fondo_cauce`), no desde 0,1 u bajo el suelo.
##   · Con agua física (`agua_fisica` y simulación) el agua la dibuja AguaRender3D desde la simulación; el bloque opaco `_agua_cauce` NO se enseña (con él puesto a la vez salían los «bloques
##     blancos»: el surtidor de Bosque3D llama aquí por cada casilla que pasa a «~» y el bloque de `_mat_agua` tapaba el agua de verdad dentro del pozo). Si la casilla aún no está abierta a la
##     simulación (llamada directa: la vitrina, una prueba), se abre y se llena subiendo el nivel desde el fondo hasta `ALTO_AGUA`; la letra pasa a «~» cuando ya es agua (como hace el surtidor),
##     no antes: así quien esté dentro sigue pisando el fondo hasta que el agua le llega.
##   · Sin agua física: el bloque de agua sube desde el fondo.
func llenar_cauce(celdas: Array = []) -> void:
	var lista: Array = celdas if not celdas.is_empty() else _agua_cauce.keys()
	var k: int = 0
	var fisica: bool = agua_fisica and Terreno3D.agua_sim != null and not Engine.is_editor_hint()
	var hondo: bool = Terreno3D.cauce_hondo
	for v in lista:
		var c: Vector2i = v
		if not _agua_cauce.has(c) or (_agua_cauce[c] as MeshInstance3D).visible:
			continue
		var mi: MeshInstance3D = _agua_cauce[c]
		if fisica:
			if mi.has_meta("llenando"):
				continue
			mi.set_meta("llenando", true)
			var sim: AguaSim3D = Terreno3D.agua_sim
			var ya_abierta: bool = Terreno3D.cauces_abiertos.has(c)
			if not ya_abierta:
				Terreno3D.cauces_abiertos[c] = true
				sim.solidificar_casilla(c, false)
			var tw_f := create_tween()
			tw_f.tween_interval(0.35 * float(k))
			if not ya_abierta:
				tw_f.tween_method(_subir_agua_cauce.bind(c), ALTO_AGUA - Terreno3D.LECHO_AGUA, ALTO_AGUA, 0.9).set_trans(Tween.TRANS_SINE)
			tw_f.tween_callback(_cauce_a_agua.bind(c))
			k += 1
			continue
		mi.visible = true
		mi.position.y = (Terreno3D.fondo_cauce() + 0.02 if hondo else ALTO_CAUCE) - ALTO_AGUA - (0.0 if hondo else 0.02)          # empieza justo bajo el lecho (cauce hondo: sobre el fondo del foso)
		var tw := mi.create_tween()
		tw.tween_interval(0.35 * float(k))                       # el agua baja hacia el río, no aparece de golpe
		tw.tween_property(mi, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_fx.salpicadura.bind(_centro_celda(c, ALTO_AGUA), 0.7))
		Terreno3D.poner_letra(c, "~")      # 13/10 (M5): ídem
		_bloqueadas[c] = true
		k += 1
	if k > 0 and _guijarros != null and not hondo:
		_guijarros.create_tween().tween_property(_guijarros, "position:y", -0.16, 0.9 + 0.35 * float(k))


## llenar_cauce con agua física: sube el nivel de la casilla en la simulación (y = superficie).
func _subir_agua_cauce(y: float, c: Vector2i) -> void:
	if Terreno3D.agua_sim != null:
		Terreno3D.agua_sim.llenar_casilla(c, y)


## llenar_cauce con agua física: el agua ya llegó. La casilla pasa a «~» (bloquea y conduce como el río) y salpica.
func _cauce_a_agua(c: Vector2i) -> void:
	Terreno3D.poner_letra(c, "~")      # 13/10 (M5): ídem
	_bloqueadas[c] = true
	_fx.salpicadura(_centro_celda(c, ALTO_AGUA), 0.7)


## Nombre que pidió el Juego (diario 10/10 03:00, punto 4): dibuja el agua de las casillas `c` que acaban de pasar a `~`.
## Si el Juego ya cambió la letra y el bloqueo (Surtidor3D), esto solo pone el agua y las salpicaduras.
func poner_agua(celdas: Array) -> void:
	llenar_cauce(celdas)


## Agua electrificada (9.10): en cada casilla, chispas eléctricas que corren a ras del agua, una luz amarilla que parpadea
## cada tres casillas y, cada 0,3 s, un chispazo en una casilla al azar. `activo = false` lo quita de esas casillas.
func electrificar_agua(celdas: Array, activo: bool = true) -> void:
	var n: int = 0
	for v in celdas:
		var c: Vector2i = v
		# 13/10 (M2): el HECHO «electrificada» es del mundo; las chispas (abajo) son solo dibujo y se quedan aquí.
		if Terreno3D.estados != null:
			Terreno3D.estados.poner(c, EstadosSuelo3D.ELECTRIFICADA, activo)
		if not activo:
			if _chispas_agua.has(c):
				(_chispas_agua[c] as Node3D).queue_free()
				_chispas_agua.erase(c)
			continue
		if _chispas_agua.has(c):
			continue
		# 13/10 (Pablo): chispas SUTILES y azules (las del hechizo de rayo, Vfx3D.chispas_agua), sobre el agua de verdad:
		# en el canal, sobre la tira de agua de cada mitad (su altura y el sitio del marcador); en el río, sobre la casilla.
		var raiz := Node3D.new()
		_efectos.add_child(raiz)
		var punto: Vector3 = _centro_celda(c, ALTO_AGUA + 0.06)
		var k: int = _canal_orden.find(c) if _canal != null else -1
		if k >= 0:
			# 11/10 (Pablo): centellas por TODA el agua, no 3 sueltas en el centro de la tira. Cada tira (y el relleno de la cámara)
			# lleva chispas según su superficie (CHISPAS_AGUA_M2) y salen por todo su ancho.
			var tiras: Array = []
			for m in _canal.mitades(k):
				tiras.append([m[0], m[1], _canal.ancho_agua])
			tiras.append_array(_canal.rellenos(k))
			for m in tiras:
				var pv: Node3D = m[0]
				var largo: float = float(m[1])
				var ancho: float = float(m[2])
				var gp: GPUParticles3D = _fx.chispas_agua(maxi(3, ceili(largo * ancho * CHISPAS_AGUA_M2)))
				var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				pm.emission_box_extents = Vector3(ancho * 0.48, 0.01, largo * 0.5)
				Vfx3D.atenuar(gp, BRILLO_CHISPAS_CANAL)          # más vivas que las de un hechizo sobre el agua (se tienen que ver)
				pm.scale_min *= TAM_CHISPAS_CANAL
				pm.scale_max *= TAM_CHISPAS_CANAL
				raiz.add_child(gp)
				var t: Transform3D = pv.global_transform.orthonormalized()
				gp.global_transform = Transform3D(t.basis, t * Vector3(0.0, 0.02, largo * 0.5))
			punto = _canal_centro(c) + Vector3(0.0, _canal.alto_agua + 0.03, 0.0)
		else:
			raiz.position = punto
			var gp2: GPUParticles3D = _fx.chispas_agua(5)
			var pm2: ParticleProcessMaterial = gp2.process_material as ParticleProcessMaterial
			pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm2.emission_box_extents = Vector3(S * 0.45, 0.02, S * 0.45)
			raiz.add_child(gp2)
			gp2.global_position = punto
		raiz.set_meta("punto", punto)
		if n % 3 == 0:
			var l := OmniLight3D.new()
			l.light_color = Vfx3D.COLOR_CHISPA_AGUA
			l.omni_range = 2.5
			l.shadow_enabled = false
			raiz.add_child(l)
			l.global_position = punto + Vector3(0.0, 0.4, 0.0)
			var tw := l.create_tween().set_loops()
			for e in [1.2, 0.3, 0.9, 0.15, 1.4, 0.5]:
				tw.tween_property(l, "light_energy", float(e) * LUZ_AGUA_ELECTRICA, 0.06)
				tw.tween_interval(0.04 + 0.08 * float(e))
		_chispas_agua[c] = raiz
		n += 1
	if _t_rayo_agua == null:
		_t_rayo_agua = Timer.new()
		_t_rayo_agua.wait_time = 0.45         # 11/10: más seguidos para que se vea la corriente (13/10 era 0,9; antes 0,3)
		add_child(_t_rayo_agua)
		_t_rayo_agua.timeout.connect(_chispazo_agua)
	if _chispas_agua.is_empty():
		_t_rayo_agua.stop()
	elif _t_rayo_agua.is_stopped():
		_t_rayo_agua.start()


func _chispazo_agua() -> void:
	if _chispas_agua.is_empty():
		return
	var cs: Array = _chispas_agua.keys()
	var c: Vector2i = cs[randi() % cs.size()]
	var p: Vector3 = (_chispas_agua[c] as Node3D).get_meta("punto", _centro_celda(c, ALTO_AGUA + 0.1))
	var r: float = 0.25 if _canal_orden.has(c) else 0.8          # en el canal, sobre la tira de agua
	_fx.chispazo_suave(p + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r)))


## 13/10: energía de la luz azul del agua electrificada (1 = la de antes, amarilla y fuerte).
const LUZ_AGUA_ELECTRICA: float = 0.35
## 11/10: chispas por metro cuadrado de agua electrificada en el canal (una tira de 1 × 0,6 lleva ~10). Más = más centellas.
const CHISPAS_AGUA_M2: float = 16.0
## 11/10: brillo (multiplica el de Vfx3D.chispas_agua, que ya viene a 0,55) y tamaño de las chispas del canal electrificado.
const BRILLO_CHISPAS_CANAL: float = 3.0
const TAM_CHISPAS_CANAL: float = 3.0


## 12/10 (Fase 11.7) · Agua física: AguaRender3D dibuja la simulación del Lanzador. Si la simulación aún no existe (el Lanzador la crea
## al cargar el nivel, 11.3), el dibujo se enlaza solo en cuanto aparece. En el editor (VistaSuelo) no se monta: sigue el agua pintada.
func _montar_agua_fisica() -> void:
	if not agua_fisica or Engine.is_editor_hint():
		return
	_agua_render = AguaRender3D.new()
	_agua_render.name = "AguaFisica"
	# 13/10: la simulación de agua se lee de Terreno3D (capa mundo/), ya no por reflexión sobre el Lanzador (ARQUITECTURA_MODULAR §5.2).
	_agua_render.proveedor = func() -> Variant: return Terreno3D.agua_sim
	_agua_render.proveedor_topes = _topes_agua_canal        # 13.9 (c): el agua del canal no sobresale de la piedra
	if agua_corre:
		_agua_render.proveedor_flujo = _flujo_rio           # 15/10 (diario 95): el río corre hacia su salida (si no, se lee como un lago)
	_agua_render.caida_detectada.connect(_onda_de_caida)    # y donde el agua CAE se levantan anillos en la base
	_agua_render.agua_refraccion = agua_refraccion          # agua EoW: refracción y tercera escala de olas (interruptores de la maqueta)
	_agua_render.olas_tercera_escala = agua_olas_tercera
	_agua_render.agua_filtro = agua_filtro                 # agua filtro (22/10): el agua como filtro turquesa sobre el lecho real
	if _mat_lecho_agua != null:
		_agua_render.enlazar_lecho(_mat_lecho_agua)         # el lecho lee la profundidad del agua para sus cáusticas
	if _adornos_lecho != null:
		_agua_render.enlazar_adornos(_adornos_lecho)        # adornos agua: las algas siguen la corriente
	add_child(_agua_render)
	# 11.10: el suelo lee la textura de mojado de la simulación unas 8 veces por segundo (si la simulación la ofrece: 11.4).
	var reloj := Timer.new()
	reloj.wait_time = 0.125
	reloj.autostart = true
	reloj.timeout.connect(_actualizar_suelo_mojado)
	add_child(reloj)


## 20/10 (entrada 204, W1 del PLAN_TRES_FRENTES): F10 alterna el dibujo del agua entre AguaRender3D (el de siempre) y la capa nueva AguaCapa3D (superficie ×4
## que sigue a la simulación, ver `agua_capa_3d.gd`) SOBRE EL MAPA REAL, para compararlas con la misma simulación. Es una prueba: la capa ya tiene hielo, ondas,
## cascada y orilla con ruido (W2, entrada 208), pero NO paredes ni topes del canal: en un canal de piedra el agua puede sobresalir. El sitio donde verla entera es
## `laboratorios/LabAguaCapa3D.tscn` (entrada 209). Al encenderla se imprime lo
## que cuesta (GPU y lectura); al apagarla se para la capa y vuelve el dibujo de siempre.
var _capa_agua: AguaCapa3D = null


func _alternar_capa_agua() -> void:
	if _agua_render == null or Terreno3D.agua_sim == null:
		print("Capa de agua (F10): este mapa no tiene agua física (agua_fisica = false o aún sin simulación)")
		return
	if _capa_agua == null:
		_capa_agua = AguaCapa3D.new()
		_capa_agua.name = "AguaCapa"
		add_child(_capa_agua)
		_capa_agua.process_mode = Node.PROCESS_MODE_DISABLED
		_capa_agua.visible = false
	var encender: bool = not _capa_agua.visible
	if encender:
		if _capa_agua.sim != Terreno3D.agua_sim:
			_capa_agua.enlazar(Terreno3D.agua_sim)             # la primera vez, o si el nivel se ha recargado con otra simulación
	_capa_agua.visible = encender
	_capa_agua.process_mode = Node.PROCESS_MODE_INHERIT if encender else Node.PROCESS_MODE_DISABLED
	_agua_render.visible = not encender
	if encender:
		var d: Vector2i = _capa_agua.dimension_fina()
		print("Capa de agua (F10): ENCENDIDA · %d × %d texels · F10 vuelve al dibujo de siempre" % [d.x, d.y])
		get_tree().create_timer(3.0).timeout.connect(_informar_capa_agua)
	else:
		print("Capa de agua (F10): apagada (dibujo de siempre)")


func _informar_capa_agua() -> void:
	if _capa_agua != null and _capa_agua.visible:
		print("Capa de agua: GPU %.3f ms por pasada · lectura de la simulación %.3f ms (a %.0f Hz)" % [_capa_agua.milisegundos_gpu(), _capa_agua.milisegundos_lectura(), _capa_agua.hz_lectura])


## 12/10 (Fase 11.18, Pipeline) · Chorros y salpicaduras de gotas (AguaMetaballs3D) para el Juego y la tinaja. Solo con agua física; sin ella
## devuelven null y quien llama sigue con su dibujo de siempre. El nodo se crea la primera vez que se pide (necesita la cámara, que se monta
## después que el agua) y se queda como `_gotas_agua`.
var _gotas_agua: AguaMetaballs3D = null


func _asegurar_gotas_agua() -> AguaMetaballs3D:
	if not agua_fisica or Engine.is_editor_hint() or _camara == null:
		return null
	if _gotas_agua == null:
		_gotas_agua = AguaMetaballs3D.new()
		_gotas_agua.name = "GotasAgua"
		_gotas_agua.camara = _camara
		add_child(_gotas_agua)
		# 13.9 (e): cada salpicadura (la del chorro al caer, la de un impacto) levanta una onda en el agua de ese punto.
		_gotas_agua.salpico.connect(func(pos: Vector3) -> void:
			var o: AguaOndas3D = _asegurar_ondas()
			if o != null:
				o.impulso(pos, FUERZA_ONDA_SALPICA, RADIO_ONDA)
		)
	return _gotas_agua


## 13.9 (e) · Ondas del agua (AguaOndas3D): hasta ahora NO estaban montadas en el juego (solo existían como clase). Una zona de 40 u que sigue a la
## cámara; el agua dibujada (AguaRender3D) suma su pendiente a la normal y espuma en las crestas. Se crea la primera vez que algo las pide.
## Medido en el canal (15/10, ventana virtual): con 0,12 u cada 0,35 s las ondas, encerradas en un cauce de 0,8 u, se acumulaban y la espuma de crestas
## lo cubría todo de blanco; con ≈ 0,04 u se ven los anillos sin tapar el agua.
const ONDAS_AGUA: bool = true                    ## false = sin ondas (por si el Bosque baja de fps: son 2 SubViewport de 256² a 60 pasos/s)
const FUERZA_ONDA_SALPICA: float = 0.05          ## altura (u) de la onda de una salpicadura
const FUERZA_ONDA_CHORRO: float = 0.035          ## y la del chorro continuo al caer (cada SEG_ONDA_CHORRO s)
const RADIO_ONDA: float = 0.6
const SEG_ONDA_CHORRO: float = 0.3
## 13.9 (c) · Y (sobre el suelo) hasta la que se DIBUJA el agua en una casilla de canal de ruinas. Medido en la pieza `canal_recto` escalada
## al mundo: borde a 0,475 u, fondo del cauce a 0,107 u (cabe ≈ 0,37 u de agua); el codo llega a 0,507. 0,44 deja siempre el borde por encima.
const BORDE_CANAL: float = 0.44
var _ondas_agua: AguaOndas3D = null


func _asegurar_ondas() -> AguaOndas3D:
	if not ONDAS_AGUA or not agua_fisica or Engine.is_editor_hint() or _camara == null or _agua_render == null:
		return null
	if _ondas_agua == null:
		_ondas_agua = AguaOndas3D.new()
		_ondas_agua.name = "OndasAgua"
		_ondas_agua.objetivo = _camara
		_ondas_agua.nivel_y = Terreno3D.alto_suelo
		add_child(_ondas_agua)
		_ondas_agua.conectar(_agua_render)
	return _ondas_agua


## 15/10 (diario 95) · Corriente propia del río (`AguaRender3D.proveedor_flujo`): {casilla: dirección}. El río del Bosque está cerrado por `#`
## (no toca el borde), así que la salida es su extremo SUR: las casillas de río con la Y mayor. El mapa aún no dice por dónde sale el agua;
## si un nivel lo necesita distinto, que Juego añada una instrucción de mapa y esto la lea (aquí solo se decide la salida).
func _flujo_rio() -> Dictionary:
	var lado: int = Terreno3D.lado_del_mapa()
	var es_rio := func(c: Vector2i) -> bool: return Terreno3D.letra_de(c) == "~" or Terreno3D.letra_de(c) == "b"
	var y_sur: int = -1
	for y in range(lado):
		for x in range(lado):
			if es_rio.call(Vector2i(x, y)):
				y_sur = y
	if y_sur < 0:
		return {}
	var es_salida := func(c: Vector2i) -> bool: return c.y == y_sur
	return AguaRender3D.flujo_hacia_salidas(lado, es_rio, es_salida)


## 15/10 (diario 95) · Una caída detectada en la simulación (cuenca que se llena, agua que baja de un escalón): anillos en su base.
const FUERZA_ONDA_CAIDA: float = 0.03
func _onda_de_caida(pos: Vector3, salto: float) -> void:
	var o: AguaOndas3D = _asegurar_ondas()
	if o != null:
		o.impulso(pos, FUERZA_ONDA_CAIDA * clampf(salto / 0.5, 0.5, 2.0), RADIO_ONDA)
	# 16/10 (diario 97): donde el chorro cae al agua, un anillo que se abre, niebla que rebota y burbujas que suben (VfxPuzle3D). Cada
	# sitio se repite como mucho cada 0,45 s: la simulación avisa cada 0,33 s por cada trocito de la base y se apilarían.
	if salto < 0.3 or not is_inside_tree():
		return
	var clave := Vector2i(roundi(pos.x * 2.0), roundi(pos.z * 2.0))
	var ahora: float = float(Time.get_ticks_msec()) / 1000.0
	if ahora - float(_t_caida_fx.get(clave, -9.0)) < 0.45:
		return
	_t_caida_fx[clave] = ahora
	VfxPuzle3D.anillo_caida(self, pos, 0.9)
	VfxPuzle3D.caida_chorro(self, pos, 1.0, false)
	VfxPuzle3D.burbujas(self, pos - Vector3(0.0, 0.1, 0.0), 0.3, false)


## 13.9 (c) · {casilla: Y máxima del agua dibujada} de todas las casillas de canal de ruinas del mapa (`AguaRender3D.proveedor_topes`).
func _topes_agua_canal() -> Dictionary:
	var d: Dictionary = {}
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if Terreno3D.es_canal_ruinas(c):
				d[c] = Terreno3D.alto_suelo + BORDE_CANAL
	return d


## 13.9 (e) · mientras el chorro cae (emitiendo), una onda en su punto de caída cada SEG_ONDA_CHORRO s.
func _ondear_chorro(chorro: Variant) -> void:
	if chorro == null or not is_instance_valid(chorro) or not is_inside_tree():
		return
	var e: GPUParticles3D = chorro as GPUParticles3D
	if e == null or not e.emitting:
		return
	var o: AguaOndas3D = _asegurar_ondas()
	if o != null and e.has_meta("caida"):
		o.impulso(e.get_meta("caida") as Vector3, FUERZA_ONDA_CHORRO, RADIO_ONDA)
	get_tree().create_timer(SEG_ONDA_CHORRO).timeout.connect(_ondear_chorro.bind(e))


## Un chorro de agua que sale HORIZONTAL de `origen` hacia `dir`, cae `y` u y llega `x` u más allá (ver AguaMetaballs3D.chorro_fisico). `dura` ≤ 0:
## hasta pararlo con `parar_chorro_agua`. `caudal` > 0 fija las gotas por segundo (la tinaja). Devuelve el emisor, o null sin agua física.
func chorro_agua(origen: Vector3, dir: Vector3, x: float, y: float, r: float = 0.25, dura: float = -1.0, caudal: float = -1.0,
		salpica: bool = true) -> Variant:
	var g: AguaMetaballs3D = _asegurar_gotas_agua()
	if g == null:
		return null
	var e: GPUParticles3D = g.chorro_fisico(origen, dir, x, y, r, dura, caudal, salpica)
	if e != null and not salpica:
		_ondear_chorro(e)               # 13.9 (e): con salpicadura ya llega una onda por cada una (señal `salpico`); sin ella, las ondas van por su cuenta
	return e


func parar_chorro_agua(chorro: Variant) -> void:
	if _gotas_agua != null and chorro != null:
		_gotas_agua.detener(chorro as GPUParticles3D)


## Una salpicadura de gotas donde cae agua (un impacto, una caída al canal).
func salpicadura_agua(pos: Vector3) -> void:
	var g: AguaMetaballs3D = _asegurar_gotas_agua()
	if g != null:
		g.salpicadura(pos)


func _actualizar_suelo_mojado() -> void:
	if _mat_suelo == null or _agua_render == null or _agua_render.sim == null:
		return
	var sim: AguaSim3D = _agua_render.sim
	if not sim.has_method("textura_mojado"):
		return
	_mat_suelo.set_shader_parameter("mojado_fisico", sim.call("textura_mojado"))
	_mat_suelo.set_shader_parameter("mojado_rect", Vector4(0.0, 0.0, float(sim.w) * sim.l, float(sim.h) * sim.l))
	_mat_suelo.set_shader_parameter("mojado_activo", 1.0)


## 10/10 · Canal de ruinas: las casillas `-` (recto) y `L` (codo) conectadas a la casilla de DELANTE de la tinaja (hacia donde
## vierte: Reactivo3D.INCLINA_HACIA con su giro) forman el canal (letras del mapa o marcadores `-`/`L` del nivel); se ordenan por distancia (anchura) y se llenan una a una con
## `Canal3D.retraso` / `t_casilla` (ajustables: `_canal.retraso = 0.5`). Si no hay tinaja o no hay canal pegado, no hace nada.
func _montar_canal() -> void:
	var tinaja: Reactivo3D = null
	for r in _reactivos:
		if r.tipo == "surtidor" and bool(r.get("_es_tinaja")):
			tinaja = r
	if tinaja == null:
		return
	# Hacia donde vierte (Reactivo3D.INCLINA_HACIA, local de la tinaja) con el giro de la pieza.
	var avance: Vector3 = tinaja.transform.basis * Reactivo3D.dir_vertido()
	var dir := Vector2i(roundi(avance.x), roundi(avance.z))
	var inicio: Vector2i = tinaja.celda + dir
	if not _es_canal(inicio):
		_avisos.append("tinaja en %s: no hay canal (`-` o `L`) en la casilla de delante %s" % [tinaja.celda, inicio])
		return
	var orden: Array = [inicio]
	var visto: Dictionary = {inicio: true}
	var i: int = 0
	while i < orden.size():
		var c: Vector2i = orden[i]
		i += 1
		for v in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var n: Vector2i = c + v
			# 12/10: el agua solo pasa de una casilla a otra si las dos tienen abierto el lado que las une (según el GIRO del marcador).
			if not visto.has(n) and _es_canal(n) and _abre_hacia(c, v) and _abre_hacia(n, -v):
				visto[n] = true
				orden.append(n)
	if agua_fisica:
		# 15/10 (Juego, Fase 13.8 · pedido de Pablo). Con agua física el agua del canal la DIBUJA AguaRender3D desde la simulación; no hay
		# Canal3D (la tira de agua pintada) ni el arroyo de la tinaja: serían la misma agua dos veces, la una pintada y la otra física.
		# La simulación empieza a recibir agua cuando el chorro de la tinaja LLEGA al canal (agua_llega), por el mismo orden de casillas
		# (de la caída hacia abajo). `abrir_cauce` es idempotente: si además el hechizo golpea el Surtidor3D de Bosque3D, no suma dos veces.
		tinaja.sin_arroyo()        # el chorro cae ya en el canal: agua_llega sale en cuanto cae, sin la tira del arroyo
		tinaja.agua_llega.connect(func() -> void: Mundo3D.abrir_cauce(orden, Surtidor3D.CAUDAL_TINAJA))
		return
	var centros: Array = []
	for c in orden:
		centros.append(_canal_centro(c))
	_canal = Canal3D.new()
	_canal.name = "Canal"
	add_child(_canal)
	_canal_orden = orden
	# 13/10 (Pablo): el río empieza JUSTO donde cae el chorro de la tinaja (antes: un arroyo hasta el borde de la casilla y una
	# salpicadura en la caída).
	var caida: Vector3 = tinaja.punto_caida_global()
	caida.y = (centros[0] as Vector3).y
	_canal.configurar(centros, Vector3(dir.x, 0.0, dir.y), caida)
	# Casillas cuyo marcador pide `lleno`: empiezan con agua.
	var llenas: Array = []
	for k in range(orden.size()):
		if _canal_llenos.has(orden[k]):
			llenas.append(k)
	if not llenas.is_empty():
		_canal.marcar_llenas(llenas)
	tinaja.sin_arroyo()        # el canal ya empieza en la caída: el agua llega en cuanto cae el chorro
	# El canal se llena cuando el agua LLEGA a él (el arroyo termina de avanzar), no al golpear la tinaja ni al empezar a verter.
	# Electricidad (11/10): el agua se electrifica casilla a casilla al pasar por la fuente `e`, con el mismo ritmo que el fluido.
	# El cristal (fuente `e`) solo electrifica por su canal azul (12/10): la casilla a la que apunta es la que puede electrificarse.
	# Si el canal no pasa por esa casilla, el canal no se electrifica nunca. El agua de la casilla a la que apunta el cristal se electrifica al llegar el
	# agua de la tinaja (ver `_al_llenarse_canal`), nunca antes.
	var celda_rayo: Vector2i = _celda_frente_fuente()
	var primera: int = orden.size()
	for k in range(orden.size()):
		if orden[k] == celda_rayo:
			primera = k
			break
	_canal.casilla_llena.connect(_electrificar_canal.bind(orden, primera))
	_canal.lleno.connect(_al_llenarse_canal.bind(celda_rayo))
	tinaja.agua_llega.connect(_canal.llenar.bind(false))


## 11/10: la casilla `i` del canal acaba de llenarse. Desde la primera casilla que toca la fuente eléctrica en adelante, el agua
## que pasa se electrifica (chispas amarillas). Va con el llenado, así que el frente eléctrico sigue al agua y no aparece de golpe.
func _electrificar_canal(i: int, orden: Array, primera: int) -> void:
	if i == primera:
		# 11/10 (Pablo: «centellas en todo el agua»): al llegar el agua a la casilla del cristal se electrifica TODA la que ya
		# hay en el canal, también la de antes del cristal (la cámara junto a la tinaja); la de después, según va llegando.
		electrificar_agua(orden.slice(0, i + 1))
	elif i > primera and i < orden.size():
		electrificar_agua([orden[i]])


## 12/10: la casilla a la que apunta el cristal (fuente `e`). El cristal tiene un canal azul por su lado +Z local (hacia donde mira
## con giro 0, basis.z): ESA es la dirección por la que toca el agua. Con el giro del marcador se gira el canal azul hacia el agua.
## Devuelve Vector2i(-99, -99) si no hay cristal en el nivel.
func _celda_frente_fuente() -> Vector2i:
	for r in _reactivos:
		if is_instance_valid(r) and r.tipo == "emisor_rayo":
			var f: Vector3 = r.transform.basis.z
			return r.celda + Vector2i(roundi(f.x), roundi(f.z))
	return Vector2i(-99, -99)


## 12/10: el canal acaba de llenarse (llega el agua de la tinaja). Solo entonces se electrifica la casilla a la que apunta el
## cristal si tiene agua o canal: el agua que se conecta con la tinaja es la que se electrifica.
func _al_llenarse_canal(celda_rayo: Vector2i) -> void:
	if _en_mapa(celda_rayo) and (_letra(celda_rayo) == "~" or _es_canal(celda_rayo)):
		electrificar_agua([celda_rayo])


## ¿Alguna casilla vecina de `c` (en las 4 direcciones) tiene la letra `l`?
func _adyacente_letra(c: Vector2i, l: String) -> bool:
	for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + v
		if _en_mapa(n) and _letra(n) == l:
			return true
	return false


## 12/10: ¿la casilla de canal `c` tiene abierto su lado hacia `v` (Vector2i en 4 direcciones)? Los lados salen del marcador:
## recto (`-`): corre a lo largo de su eje X local (giro 0 = este-oeste, 90 = norte-sur); codo (`L`): abre al oeste y al sur con
## giro 0, y gira con el marcador. Así el agua sigue el giro que le pongas al marcador, también en un codo.
func _abre_hacia(c: Vector2i, v: Vector2i) -> bool:
	if Terreno3D.datos_propios:
		return Terreno3D.abre_hacia(c, v)
	var giro: float = deg_to_rad(float(_giros.get(c, 0.0)))
	var base: Array = [Vector2(-1, 0), Vector2(1, 0)] if _letra(c) != "L" else [Vector2(-1, 0), Vector2(0, 1)]
	for b in base:
		var lx: float = b.x
		var lz: float = b.y
		# Mismo giro que Basis(UP, giro): eje X local = (cos, 0, -sin); eje Z local = (sin, 0, cos).
		var mx: int = roundi(lx * cos(giro) + lz * sin(giro))
		var mz: int = roundi(-lx * sin(giro) + lz * cos(giro))
		if Vector2i(mx, mz) == v:
			return true
	return false


func _es_canal(c: Vector2i) -> bool:
	if Terreno3D.datos_propios:
		return Terreno3D.es_canal(c)
	# Con las letras: `-` y `L` del mapa. Con el nivel horneado (Nivel_Bosque.tscn) esas letras ya no existen: son las piezas
	# canal_recto / canal_codo que `_leer_nivel` apuntó en `_celdas_canal`.
	return _celdas_canal.has(c) or (_en_mapa(c) and (_letra(c) == "-" or _letra(c) == "L"))


## Vitrina (`vitrina_vfx`): todo lo de 9.7 a la vista a la vez, sin jugar. Runas, cauce y agua electrificada se quedan; el
## surtidor echa un chorro cada 5 s. El agua electrificada es la conectada por 4 vecinas a las casillas del cauce.
func _vitrina_vfx() -> void:
	for el in ["fuego", "agua", "rayo"]:
		encender_runa(el)
	llenar_cauce()
	var hecho: Dictionary = {}
	var cola: Array = _agua_cauce.keys()
	for c in cola:
		hecho[c] = true
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if not hecho.has(n) and _en_mapa(n) and _letra(n) == "~":
				hecho[n] = true
				cola.append(n)
	# 12/10: sin electrificar al empezar. El agua se electrifica solo cuando la tinaja la conecta (`_al_llenarse_canal`).
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		for r in _reactivos:
			if is_instance_valid(r) and r.tipo == "surtidor":
				r.brotar())


## Esconde la correa de la mochila (`BolsaUI._pie`) mientras `mostrar_correa_mochila` sea false. La mochila grande (I) no cambia.
## Si el Juego cambia el nombre del nodo, no pasa nada: simplemente no se esconde nada. El arreglo de fondo es suyo (diario 10/10).
func _ocultar_correa_mochila() -> void:
	if mostrar_correa_mochila:
		return
	for n in get_tree().root.find_children("*", "BolsaUI", true, false):
		var pie = n.get("_pie")
		if pie is Control:
			(pie as Control).visible = false
