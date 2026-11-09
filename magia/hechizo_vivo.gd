class_name HechizoVivo
extends Node3D

## UN HECHIZO EN MARCHA (HC2, 18/10; docs/HECHIZO_CLASE.md §2.1). Dueño: Juego.
##
## Ejecuta un `Hechizo` (la definición, datos puros): lo materializa en el mundo en el orden de siempre y lo deja vivir. El `Lanzador3D` solo conjura
## y lo crea con `HechizoVivo.crear(hechizo, origen, dir, lanzador)`; todo lo que antes hacían `_materializar_v2`, `_eventos_v2` y `_materia_*` vive aquí.
## **Su estado en marcha vive aquí, no en la definición** (el camino que recorre, a qué golpeó ya, qué le queda por hacer).
##
## HC2 es una MUDANZA: mismo resultado que antes (pruebas de materia, receta y lab a 0). Los servicios que siguen siendo del lanzador (trazar, golpear,
## marcar suelo, construir tierra, el registro de zonas y solideces, la señal `hechizo_v2`) se piden con `lanz.`
##
## Nace en el origen del cast point, se desplaza, rebota y persiste (`eventos`), y cada tanda de casillas se llena según el estado de la materia
## (`MATERIA_V2`). Cuando se han cumplido todos sus eventos retardados, se borra solo: lo que deja en el mundo (ZonaV2, SolidezV2, tierra, agua) tiene su propia vida.
##
## CUATRO REGLAS NUEVAS (24/10, decisión de Pablo tras la auditoría docs/ANALISIS_DIRECCION_24-10/05_auditoria_hechizo.md, D-1, D-6 y D-7):
##   · ᚠ en el PROYECTIL: con `copias` > 1 salen `copias` proyectiles (un HechizoVivo hermano cada uno), abiertos en abanico de `dispersion` grados EN TOTAL y separados `separacion` m
##     de lado. Antes salía UNO solo y el glifo cobraba tinta y recarga sin hacer nada. La tinta y la recarga se cobran una vez (en `lanzar_ahora`); cada copia cobra el mismo golpe.
##     Con las copias de un VOLUMEN quieto en número PAR, los centros caían justo en el borde entre dos casillas y se rasterizaban en la misma (ᚠ×1 daba 1 casilla en vez de 2): ahora el
##     reparto se desplaza medio paso (ver `eventos_de`).
##   · El PROYECTIL se para en una `SolidezV2` de otro hechizo igual que `Lanzador3D.trazar`: gasta un rebote si le quedan, y si la solidez refleja (barrera + rebote) se refleja una vez.
##     Nunca choca con la solidez de su propio lanzamiento (`linaje`): sin eso la flecha de «barrera + flecha» se autodestruiría contra el muro que ella misma levanta.
##   · ᚷ `crece` va en m/s DE RADIO (ESPEC §1.3), no en escala por segundo: el volumen nace a `escala_nace` × sus semiejes y crece hasta el 100 % en
##     (semieje − semieje × escala_nace) / crece segundos (`tiempo_crecimiento`). Mientras crece rasteriza casillas nuevas cada vez que su radio cruza una (antes solo había 8 fases fijas).
##     El proyectil con `crece` crece en vuelo (su radio de acierto `_radio_u` sube a `crece` m/s hasta el de `semiejes_vuelo`).
##
## CINCO REGLAS GENERALES DE COMBINAR GLIFOS (3/11/2026, decisión de Pablo «R1…R5»: no se hardcodean recetas; salen de condiciones por PROPIEDADES del Hechizo —solidez, velocidad, copias, retorna, crece, semiejes— para cualquier elemento):
##   · R1 · ᛇ sobre algo con FORMA = la forma viaja. Con solidez (`Hechizo.volumen_viaja`, ᛜ + ᛇ) NO sale una bola: el volumen entero recorre su ruta (`eventos_de`, a la velocidad de la flecha) y su SolidezV2 lo ACOMPAÑA
##     (`_solidez_sigue`: ocupa las casillas donde está y suelta las que deja); lo que encuentra se golpea (`_contacto` por tanda) y se empuja (`EMPUJE_MURO_K`). ᚲ + ᛇ sin solidez sigue siendo la bola de siempre.
##   · R2 · ᛃ sobre lo que viaja = el camino incluye la VUELTA. El proyectil ya volvía (`_fin_de_ida`); ahora el volumen que viaja también vuelve al lanzador (tramo de vuelta en `eventos_de`: vuelve a golpear, sin repetir su materia).
##   · R3 · ᛃ SIN flecha y con ᚠ (≥ 2 copias) = las copias ORBITAN el lanzador (`Hechizo.orbita`, `_materializar_orbita`): un orbe por copia, el radio lo abren los semiejes X/Z, la duración la dan persiste + permanencia; golpean lo
##     que tocan en su vuelta y, con ᚨ, un orbe sale disparado contra un enemigo vivo cercano. Sin copias, ᛃ sigue siendo el eco del impacto.
##   · R4 · ᚷ sobre un volumen que domina en altura (`Hechizo.columna`, ᛏ + ᚷ) = crece de ABAJO ARRIBA (antes la altura nacía entera): su altura sube con `crece` y ELEVA lo que haya dentro (`_avanzar_columna`: `elevar` del
##     jugador y los enemigos, el mismo contrato que `push`).
##   · R5 · ᚷ golpea AL CRECER: cada fase de crecimiento ya golpeaba las casillas NUEVAS que alcanza (`eventos_de` + `_vivir` + `tocados`: onda expansiva por casillas); y un volumen líquido que crece (`Hechizo.estalla`, ᛚ ᚷ…) ESTALLA al expirar
##     con daño en área de su tamaño final (`_estallar`, `Hechizo.radio_estallido`): lo que ya dibuja `AguaToy.area_al_impactar`.

## --- MATERIA V2 (R2, 17/10; docs/GLIFOS_RECETA.md §2.3-2.4): lo que llena el volumen lo decide el estado de la materia, UNA vez por estado ---
const T_LLENADO_V2: float = 1.0             ## líquido: s que tarda en echar el agua de su volumen
const T_CAIDA_BASE_V2: float = 0.4          ## líquido: cuándo entra el agua en AguaSim = T_CAIDA_BASE_V2 + T_CAIDA_POR_Y_V2 × semieje_y (máx. T_CAIDA_MAX_V2): casa con la caída de la masa del VFX (155)
const T_CAIDA_POR_Y_V2: float = 0.07
const T_CAIDA_MAX_V2: float = 0.8
const ESTADO_RESERVA_V2: String = "campo"   ## estado que se usa si un Hechizo trae uno que no conocemos (el más inofensivo)
## estado -> método que lo materializa (recibe el contexto y devuelve cuántas manifestaciones ocupa). Añadir un estado es añadir una línea.
const MATERIA_V2: Dictionary = {
	"solido": "_materia_solido", "liquido": "_materia_liquido", "plasma": "_materia_plasma",
	"energia": "_materia_energia", "gas": "_materia_gas", "campo": "_materia_campo",
}
## estado -> método que corre en cada pulso de su zona (los estados instantáneos no tienen)
const PULSO_V2: Dictionary = {"plasma": "pulso_plasma", "gas": "pulso_gas", "campo": "pulso_campo"}

## 6/11/2026 · B5 HECHIZO × HECHIZO (PROPUESTAS_COMBATE bloque B; Spellbreak). Un proyectil vivo que ENTRA en una casilla ocupada por una ZONA viva de otro elemento se transforma. La tabla es la UNICA regla:
## CRUCES[elemento del proyectil][elemento de la zona] = {accion, aviso (reacción de Mundo3D.REACCIONES que se avisa, sin catálogo nuevo), previsto (rótulo de PrevisionReaccion3D.ESTILO), …}.
##   apagar     el proyectil se apaga y deja `vapor` (EstadosSuelo3D) en la casilla       encender  el proyectil pasa a `a` (se reconstruye con su runa `runa` y sus mismos glifos: hereda su quema)
##   descargar  daño del hechizo a todo enemigo/pieza de la zona de agua (y del agua conectada) y la zona queda electrificada; el proyectil se gasta
## Una "zona viva" es la de un HECHIZO (las ZonaV2 de `Lanzador3D._zonas_v2`: la llama del fuego, el campo del viento; y `Lanzador3D.zonas_cruce`: el charco que deja el agua), NO el agua del mapa: si lo
## fuera, la flecha de fuego que cruza un río en un puzle se apagaría. Fallo que evita: ningún hechizo reaccionaba con otro, así que dos zonas se pisaban sin más.
## Añadir un cruce es una fila aquí (y, si es un tipo de acción nuevo, un caso en `_cruce`); la previsión (`prevision["cruces"]`) lo anuncia con el mismo rótulo.
const CRUCES: Dictionary = {
	"fuego": {"agua": {"accion": "apagar", "aviso": Mundo3D.R_APAGADO_AGUA, "previsto": "vapor"}},
	"viento": {"fuego": {"accion": "encender", "a": "fuego", "runa": "res://nucleo/fire_rune.tres", "aviso": Mundo3D.R_LLAMARADA, "previsto": "llamarada"}},
	"rayo": {"agua": {"accion": "descargar", "aviso": Mundo3D.R_ELECTROCUTADO, "previsto": "descarga"}},
	# R3 (6/11): la lava en el agua hierve: vapor y, al enfriarse, costra (escombro 6 s). Se gasta el proyectil. «previsto» sigue siendo «vapor» (la costra no tiene rótulo propio).
	"magma": {"agua": {"accion": "costra", "aviso": Mundo3D.R_APAGADO_AGUA, "previsto": "vapor"}},
}
## R3 (§10 de docs/REACCIONES_ENTORNO: presupuesto de 16 nodos conductores): lo máximo que SE SUMA a la zona del rayo por agua/conductor conectado (casillas fuera del volumen, por anillos desde la zona).
## Fallo que evita: la búsqueda de `agua_conectada` llega a LIMITE_BUSQUEDA, así que un rayo en la orilla de un lago lo electrificaba entero (y golpeaba a todo lo que hubiera dentro).
const MAX_NODOS_DESCARGA: int = 16
const ZONA_AGUA_S: float = 6.0             ## B5: lo que dura el charco de un hechizo de agua como zona de cruce (el agua real sigue en AguaSim3D; esto es solo para que otro hechizo la reconozca)

## --- CICLO DE VIDA V2 (R3, 17/10; GLIFOS_RECETA §2.2 y §2.4; vida nueva: ESPEC_HECHIZO §0.3, 19/10) ---
## Orden fijo, y cada paso lee SOLO números del Hechizo (ningún `if` por pareja de glifos):
##   1. copias   repartidas a lo largo de X con `separacion` m entre una y otra y abiertas `dispersion` grados
##   2. nace tras `retardo`, quieto, y crece si `crece` desde `escala_nace` (solo en planta: la altura nace entera; ver diario)
##   3. se desplaza `distancia_max` m a `velocidad` (8 m/s si es 0), parando donde para `trazar` (casilla sólida, barrera, objeto)
##   4. rebota `rebotes` veces (es el rebote de `trazar`); sin desplazamiento, el volumen refleja los proyectiles que le llegan
##   5. VIDA: si viaja desaparece al llegar o chocar y se queda `permanencia` s; si nace quieto dura `persiste` + `permanencia` (la `persiste` del elemento NO cuenta al viajar)
##   6. `solidez` por encima de cualquier estado: SolidezV2 bloquea proyectiles y aguanta golpes
const MUESTRAS_CRECE_V2: int = 24          ## 24/10: en cuántos pasos iguales se muestrea el crecimiento de un volumen para ver cuándo su radio cruza una casilla (antes: 8 fases de al menos un `intervalo`)
const PASO_CRECE_MIN_S: float = 0.05       ## s: paso mínimo entre dos muestras del crecimiento (un crecimiento muy corto no se parte en trozos más pequeños que unos fotogramas)
const SEPARACION_COPIAS_MIN_CASILLAS: float = 1.0   ## casillas de centro a centro entre dos copias como mínimo (una copia por casilla: la casilla es lo que se rasteriza)
const MAX_EVENTOS_V2: int = 128           ## tope de apariciones (copias × fases × posiciones) por hechizo (3/11: 64 → 128, que el volumen que viaja y vuelve con copias no se corte en la vuelta)
## 3/11 (R1/R2): el muro que viaja y empuja. Fracción de `Lanzador3D.FUERZA_EMPUJE` con que arrastra a quien alcanza; cuánto se queda su SolidezV2 tras su último paso si no hay `permanencia`.
const EMPUJE_MURO_K: float = 0.5
const COLA_SOLIDEZ_S: float = 0.3
## 6/11 (bloque B7, fuego amigo suave; Magicka): las zonas vivas de TU hechizo (la llama que deja el fuego, la descarga de tu rayo sobre el agua que pisas) también te dañan. Fallo que evita: poner
## una barrera de fuego o un rayo sobre el agua no tenía riesgo ninguno, así que dónde la ponías daba igual. `static var` y no `const` para que las pruebas que no lo quieran lo apaguen.
static var FUEGO_AMIGO: bool = true
const INTERVALO_LATIDO: float = 0.6      ## 6/11 (C2): s por mitad del latido de una barrera `late` cuando el hechizo no fija `intervalo` (0,25 s por defecto latiria demasiado rapido para verse)
const DANO_PROPIO_POR_TIC: float = 2.0    ## lo que te quita cada pulso de la zona (el mismo `intervalo` que a los enemigos); pasa por tu defensa y tu invulnerabilidad (`Jugador3D.dano_ambiental`)
const GRACIA_PROPIA_S: float = 0.6         ## s tras lanzar sin daño propio: el hechizo sale de TU casilla y sin esto te quemarías al nacer
var _t_creado_ms: int = Time.get_ticks_msec()   ## cuándo nació este lanzamiento (la gracia de la descarga, que no tiene zona con reloj propio)
## 3/11 (R3): los orbes de ᛃ + ᚠ. Radio de la órbita = ORBITA_RADIO_BASE_CAS + ORBITA_RADIO_POR_SEMIEJE × el mayor de X y Z (casillas); una vuelta cada ORBITA_VUELTA_S s; dura persiste + permanencia (mínimo ORBITA_VIDA_MIN_S).
const ORBITA_RADIO_BASE_CAS: float = 1.0
const ORBITA_RADIO_POR_SEMIEJE: float = 2.0
const ORBITA_VUELTA_S: float = 2.0
const ORBITA_VIDA_MIN_S: float = 3.0
const ORBE_RADIO_MIN_U: float = 0.2         ## u: el orbe acierta con su tamaño en vuelo (semiejes × ESCALA_PROYECTIL), pero nunca menos de esto
## 3/11 (R4): lo que vive como mínimo (s) el pilar que sube, alzando lo que tiene dentro.
const COLUMNA_VIDA_MIN_S: float = 1.0
const PASO_SECO_S: float = 1.0 / 20.0          ## 28/10 · A2: paso de la simulación en seco. Más grueso que el de la física (1/60) para que sea barata (se llama cada fotograma al apuntar): el rayo de `_golpes_areas` cubre todo el tramo, así que no se salta nada; el arco cambia unos milímetros
const PASOS_MAX_SECO: int = 100             ## A2: tope de pasos de un proyectil en seco (5 s de vuelo): lo que no ha parado a tiempo se da por llegado
## Estados cuya materia NO golpea por sí sola lo que toca (plasma, gas y energía sí: ver sus pulsos). Al llegar su tanda de casillas, golpean UNA vez a los
## reactivos y enemigos que haya dentro, igual que lo hacía la flecha de siempre (`_golpear`: on_spell_hit, hielo que apresa, agua que moja…).
const CONTACTO_V2: PackedStringArray = ["solido", "liquido", "campo"]
const VIDA_MIN_SOLIDEZ_V2: float = 2.0     ## s que dura la solidez de lo que no persiste (agua, rayo)

## --- HC4 (18/10; HECHIZO_CLASE §2.2 y §2.3): el hechizo que SE MUEVE y los eventos ---
## Un hechizo con `velocidad` > 0 es un PROYECTIL: un punto con volumen que se mueve en el mundo paso a paso (`paso(dt)`) en vez de materializar sus casillas de golpe.
## Un hechizo con `velocidad` = 0 (todos los de hoy) sigue por el camino de siempre, sin cambios. Ambos disparan los eventos de `Hechizo.eventos`.
const GRAVEDAD_U: float = 9.8               ## u/s² de una caída con `gravedad` = 1
const VEL_MIN_PROYECTIL: float = 0.5        ## u/s: por debajo, un proyectil que frena se da por parado
const VIDA_RETORNO_S: float = 4.0           ## s máximos de la vuelta de un `retorna`
const RADIO_ENEMIGO_U: float = 0.6          ## radio con que un enemigo (o un reactivo) recibe un golpe de proyectil
const CENTRO_ENEMIGO_U: float = 0.8         ## altura del pecho sobre sus pies: a donde apunta `busca` y de donde cuenta la ventana vertical del golpe
const VENTANA_Y_U: float = 1.0              ## holgura vertical del golpe (más el radio del proyectil)
const GIRO_BASE: float = 1.5 * TAU         ## rad/s de giro hacia el objetivo con `busca` = 1 (30/10, playtest de Pablo: «un solo ᚨ ya debe notarse como imán»; antes TAU)
const BUSCA_ALCANCE_CAS: float = 6.0        ## casillas a las que `busca` ve un objetivo
const BUSCA_COS: float = 0.5                ## cono de `busca` = 1: coseno de 60° a cada lado
const BUSCA_COS_POR_NIVEL: float = 0.5      ## 30/10: el cono se abre con `busca`: cada glifo más baja el coseno esto (busca 1 → 0,5 · 2 → 0 (±90°) · 3 → −0,5 (±120°)): más glifos ven objetivos más laterales
const LLEGADA_U: float = 0.7                ## a esta distancia del lanzador, lo que vuelve (`retorna`) se da por recogido
const SEGURIDAD_S: float = 0.25             ## s tras nacer en los que NO hiere al lanzador aunque `golpea_lanzador`
const DESPLAZA_HIJO_U: float = 0.15         ## un hijo nace un poco por delante, para no chocar en el mismo punto que su padre
const PASO_ESTELA_U: float = 0.5            ## cada cuántas unidades recorridas pide su `estela`
const HAZ_BOCA_U: float = 0.4               ## RAYO: u que el haz nace por delante de la mano (el lanzallamas de siempre)
const HAZ_PUNTA_Y_U: float = 0.1            ## RAYO: altura sobre el suelo (u) de la punta del dibujo

## Cuántos hechizos vivos lleva un mismo lanzamiento (el padre y sus hijos comparten uno): el tope es Hechizo.MAX_VIVOS.
class Linaje extends RefCounted:
	var vivos: int = 0

var linaje: Linaje = null
var proyectil: bool = false                ## ¿se mueve? (velocidad > 0)
var activo: bool = false                   ## proyectil en vuelo
var motivo_fin: String = ""                ## «golpe» | «muro» | «suelo» | «alcance» | «tiempo» | «frenado» | «retorno»
var p: Vector3 = Vector3.ZERO              ## posición en el mundo
var v: Vector3 = Vector3.ZERO              ## velocidad (u/s): su dirección es hacia dónde va y su módulo, cuánto
var recorrido: float = 0.0                 ## u recorridas en este tramo (la ida o la vuelta)
var _p_previa: Vector3 = Vector3.ZERO     ## dónde estaba al empezar el paso (el rayo de los objetos va de aquí a `p`)
var edad: float = 0.0                      ## s de este tramo
var volviendo: bool = false
var golpes_dados: int = 0                  ## objetos que ha golpeado en este tramo (perfora)
var espera: float = 0.0                    ## H5: s de `retardo` que le quedan a un proyectil antes de ponerse en marcha (nace quieto en la mano; `paso` los descuenta; 0 = ya en marcha). El VFX y las pruebas lo leen
var rebotes_usados: int = 0
var golpeados: Dictionary = {}             ## instance_id -> true: a quién ya golpeó en este tramo (un hijo hereda los del padre)
var eventos_vistos: Array = []             ## nombres de los eventos disparados, en orden (las pruebas y el lab los leen)
var manual: bool = false                   ## true = no avanza solo (las pruebas llaman a `paso`)
var _max_recorrido: float = 0.0
var quedandose: bool = false              ## true mientras dura su `permanencia` (ya se paró o llegó, y todavía no desaparece)
var _t_viaje: float = 0.0                  ## s hasta que el volumen que viaja llega o choca (0 = no viaja)
## Gamefeel lote 2 (29/10): el ARRANQUE (Sensacion3D.factor_arranque). Solo en la ida del primer tramo de un proyectil que se mueve, y solo en el vuelo de verdad
## (`_physics_process`): `paso` con su dt (las pruebas y la previsión) no lo nota. El dibujo lee `factor_arranque` para estirarse.
var t_arranque: float = 0.0                ## s de juego desde que salió (deja de contar al acabar el arranque)
var factor_arranque: float = 1.0           ## el factor de velocidad de este fotograma (1 = su velocidad)
var _radio_u: float = 0.0                  ## radio con que el proyectil acierta AHORA (u); con `crece` sube en vuelo hasta `_radio_pleno_u`
var _radio_pleno_u: float = 0.0            ## el radio de acierto entero del proyectil (u): el de `semiejes_vuelo`
var _crece_u: float = 0.0                  ## u/s a los que crece el radio de acierto del proyectil (`crece` m/s × casilla; 0 = no crece)
var tiempo_crecimiento: float = 0.0        ## s que tarda en llegar a su tamaño entero lo que `crece` (volumen o proyectil); 0 = no crece (las pruebas y el lab lo leen)
var _reflejado: bool = false               ## el proyectil ya fue devuelto una vez por una SolidezV2 con rebote (como `trazar`: un trazo se refleja una vez)
var _viaja_sig: Array = []                 ## para cada acción de al_viajar, el recorrido en que le toca
var _estela_sig: float = 0.0
var _golpeo_lanzador: bool = false
var _sitio_golpe: Vector3 = Vector3.INF         ## dónde estaba lo que lo paró de un golpe (el sitio de su impacto); INF = no lo paró un golpe
var _contacto_celdas: Array = []                 ## 29/10: las casillas que tocó al pararse (pared, barrera, objeto, enemigo o suelo): de ahí sale su momento «final» (el pulso ᚱ); vacío = no tocó nada
var _contado: bool = false

var lanz: Lanzador3D = null                ## quien lo conjuró: presta trazar, golpear, marcar suelo, construir tierra y los registros
var h: Hechizo = null                      ## la definición (no se toca)
var g: Dictionary = {}                     ## su geometría en el formato de siempre (Hechizo.geo())
var data: RuneData = null                  ## lo que ven los estados y los reactivos (Combate3D y Reactivo3D aún leen un RuneData: HC3)
var elemento: String = ""
var estado: String = "campo"
var casillas: int = 0                      ## cuántas manifestaciones ocupó al nacer (lo que devolvía `_materializar_v2`)
var golpes_camino: Array = []              ## lo que tocó el último `camino`: [{obj, punto, dir, desde}] (los golpes se dan cuando llega el volumen)
var _pendientes: int = 0                   ## eventos retardados por cumplir
var _nacido: bool = false
var _celdas_volumen: Array = []            ## las casillas que ocupa el volumen que NACE quieto (de ahí salen los efectos de momento «inicio», «continuo» y «final»)
var momentos_vistos: Array = []            ## MOMENTO DE EJECUCIÓN: [{momento, glifo, accion, t}] en el orden en que se dispararon (las pruebas y el lab lo leen)
var pulsos_soltados: Array = []            ## los Pulso3D que ha soltado este hechizo (glifo ᚱ)
var _momento_hecho: Dictionary = {}        ## momento -> true para «inicio» y «final» (una vez cada uno: sin reentradas)
var finales_vistos: Array = []             ## H2: los eventos de final (`Hechizo.EVENTOS_FINAL`) que SALTARON, tengan o no acciones: un tramo termina en exactamente uno (las pruebas lo leen)
var ecos_de_retorno: int = 0               ## 31/10: veces que ᛃ sin flecha repitió el impacto (las pruebas lo leen)
## --- 3/11 (R1-R5): el estado en marcha de las reglas de combinar glifos (las pruebas y el VFX lo leen) ---
var _solideces_sigue: Dictionary = {}      ## R1: copia -> {nodo: SolidezV2, hasta: ms}: la solidez que acompaña a cada copia del volumen que viaja
var orbes: Array = []                      ## R3: [{p: Vector3, ang: float, vuelta: float (rad de esta vuelta), golpeados: Dictionary, activo: bool, lanzado: bool}]; vacío si no orbita
var radio_orbita_u: float = 0.0            ## R3: radio de la órbita (u)
var orbes_lanzados: int = 0                ## R3 + ᚨ: orbes que salieron disparados contra un enemigo
var _vida_orbita: float = 0.0
var _t_orbita: float = 0.0
var _objetivos_orbe: Dictionary = {}       ## R3 + ᚨ: instance_id -> true de los enemigos a los que ya se disparó un orbe
var _t_nacido: float = 0.0                 ## s de juego desde que nació el volumen (lo que cuenta `avanzar_volumen`)
var columna: Dictionary = {}               ## R4: {celdas: Dictionary, y1: m de la altura final (casillas), nace: fracción con que nace, t0: s hasta que nace, t: s que tarda en crecer, vida: s hasta que suelta lo que alza}; vacío si no crece en altura
var elevados: int = 0                      ## R4: veces que `elevar` alzó a algo (las pruebas lo leen)
var estallidos: int = 0                    ## R5: veces que el volumen líquido estalló en área (las pruebas lo leen)
var _centro_volumen: Vector3 = Vector3.ZERO ## el centro del volumen que nace quieto, en el suelo: de ahí sale el estallido
## ⧖ / ᛃ (31/10, REV 01 del checklist, Pablo: «haz que haya un impacto con un pequeño delay»): sin flecha, ᛃ repite el impacto EN EL PUNTO DE IMPACTO (la punta del haz o el sitio del volumen)
## este tiempo después de acabar: otra vez la materia y el daño. Sustituye a «vuelve a la mano» (30/10).
const RETORNO_ECO_S: float = 0.4
var _final_hecho: bool = false             ## H2: ya saltó uno de los tres finales: ningún hechizo dispara dos (la ida de un `retorna` no cuenta: solo acaba el tramo de vuelta)
var reloj_vida: float = 0.0                ## s de juego desde que nació (`edad` solo cuenta los tramos de un proyectil): fecha los momentos de ejecución
var _en_momento: bool = false             ## true mientras corren las acciones de un momento: un efecto que nace en él no dispara otro momento de este hechizo
var _rechazado: bool = false              ## el hechizo se rechazó entero (altura que la materia no admite): no suelta ni su pulso
var _juice_impacto: bool = false          ## E1 (6/11): ya pidió el temblor/hitstop de su primer impacto (un área que golpea a cinco, o un haz que perfora, lo hace UNA vez, no cinco: congelaría el mundo en tartamudeo)
var seco: bool = false                     ## 28/10 · A2: modo «en seco» (`HechizoVivo.prever`): corre las MISMAS reglas pero no aplica nada: los golpes y las marcas de suelo se anotan en `prevision` en vez de darse
var prevision: Dictionary = {}             ## A2: lo que haría el hechizo en seco: {golpes: [{obj, dir, punto, desde}], suelo: [{elemento, celda}], fin: Vector3 (INF = no se detuvo), causa: String, rebotes: int, cruces: [{reaccion, celda, accion}] (B5)}
var cruces_vistos: Array = []              ## B5: los cruces que hizo este proyectil, en orden: [{accion, aviso, celda, zona}] (las pruebas lo leen)
var _celda_cruce: Vector2i = Vector2i(-9999, -9999)   ## B5: la última casilla en la que se miraron las zonas (solo se mira al ENTRAR en una casilla nueva)
## A1 (2/11, VFX en el juego; solo DATOS para el dibujo, la lógica no los lee): el proyectil avisa de su fin y de sus rebotes con lo que el VFX necesita y antes no llegaba (la normal de la superficie y su material).
signal terminado(causa: String, pos: Vector3, normal: Vector3, material: String)   ## causa = `motivo_fin`; normal = hacia fuera de lo que paró al proyectil; material = letra del mapa de la casilla (muro, suelo) o ""
signal rebotado(pos: Vector3, normal: Vector3)


## Crea el hechizo vivo de una definición, lo materializa y devuelve el nodo (`casillas` = cuántas casillas ocupó; 0 = no se lanzó).
## `linaje` y `ya_golpeados` los pasa `crear_hijo` (los límites son del lanzamiento entero y un hijo no repite el golpe de su padre); `a_mano` = no avanza solo (pruebas).
## `copia` (24/10): qué proyectil de los `copias` del hechizo es éste. El que llama pasa 0 y `crear` lanza los demás (hermanos con el mismo linaje); solo el hechizo lanzado (profundidad 0)
## se multiplica, un hijo de `crear_hijo` no (ya lleva su propio abanico). `casillas` del devuelto suma las de todos los hermanos.
static func crear(hechizo: Hechizo, origen: Vector3, dir: Vector3, lanzador: Lanzador3D, linaje_: Linaje = null, ya_golpeados: Dictionary = {}, a_mano: bool = false, copia: int = 0) -> HechizoVivo:
	var nuevo: HechizoVivo = preparar(hechizo, lanzador)
	nuevo.linaje = linaje_ if linaje_ != null else Linaje.new()
	nuevo.linaje.vivos += 1
	nuevo._contado = true
	nuevo.golpeados = ya_golpeados.duplicate()
	nuevo.manual = a_mano
	lanzador.add_child(nuevo)
	nuevo.set_physics_process(not a_mano)
	var n_proyectiles: int = copias_de_proyectil(hechizo)
	if hechizo.proyectil:                      # 3/11 (R1): el volumen sólido que viaja (ᛜ + ᛇ) no es un proyectil: lo recorre `_materializar`
		var salida: Dictionary = salida_de_copia(hechizo, copia, n_proyectiles, dir)
		nuevo.casillas = nuevo._iniciar_proyectil(origen, salida["dir"], salida["desvio"])
	else:
		nuevo.casillas = nuevo._materializar(origen, dir)
	nuevo._nacido = true
	if nuevo.casillas == 0 and not nuevo.proyectil and hechizo.resuena > 0.0 and not nuevo._rechazado:
		nuevo._pulso_sin_volumen(origen)
	if nuevo.casillas > 0:
		if copia == 0 and hechizo.profundidad == 0:
			Sensacion3D.juice_hechizo(hechizo.nivel_potencia, false, lanzador, dir, hechizo.haz)      # E1 (6/11): temblor e hitstop de la salida según su potencia; solo el hechizo lanzado, no sus hijos ni copias
		nuevo.disparar_evento("al_nacer", origen, dir)
		nuevo._arrancar_momentos(origen, dir)
		nuevo._programar_extincion(origen, dir)
	nuevo._revisar_fin()
	if copia == 0:
		for i in range(1, n_proyectiles):
			if nuevo.linaje.vivos >= Hechizo.MAX_VIVOS:
				break                                                    # el tope de hechizos vivos es del lanzamiento entero (las copias también cuentan)
			var hermano: HechizoVivo = crear(hechizo, origen, dir, lanzador, nuevo.linaje, ya_golpeados, a_mano, i)
			nuevo.casillas += hermano.casillas
	return nuevo


## Cuántos proyectiles salen de un hechizo: sus `copias` si es un PROYECTIL lanzado (velocidad > 0, profundidad 0), y 1 en cualquier otro caso (un volumen se reparte en `eventos_de`; un hijo no se multiplica).
static func copias_de_proyectil(hechizo: Hechizo) -> int:
	if not hechizo.proyectil or hechizo.profundidad > 0:
		return 1
	return maxi(hechizo.copias, 1)


## Dirección y desvío de la copia `i` de `n` de un proyectil: el abanico abre `dispersion` grados EN TOTAL (de −d/2 a +d/2 repartidos a partes iguales; una sola copia va recta) y las copias se
## separan `separacion` m de lado, centradas en la mano. Devuelve {dir: Vector3 horizontal-con-su-inclinación, desvio: Vector3 en u que se suma a la salida}.
static func salida_de_copia(hechizo: Hechizo, i: int, n: int, dir: Vector3) -> Dictionary:
	var d0: Vector3 = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	if n <= 1:
		return {"dir": d0, "desvio": Vector3.ZERO}
	var grados: float = lerpf(-hechizo.dispersion * 0.5, hechizo.dispersion * 0.5, float(i) / float(n - 1))
	var lado: Vector3 = d0.cross(Vector3.UP).normalized()
	var desvio: Vector3 = lado * ((float(i) - float(n - 1) * 0.5) * hechizo.separacion * Terreno3D.casilla)
	return {"dir": d0.rotated(Vector3.UP, deg_to_rad(grados)), "desvio": desvio}


func _exit_tree() -> void:
	if _contado and linaje != null:
		linaje.vivos -= 1
		_contado = false


## 28/10 · A2 (previsión del indicador, docs/PROPUESTA_COMBATE.md §7). Corre el hechizo EN SECO: las mismas reglas que al lanzarlo de verdad (el vuelo del proyectil con su gravedad, sus choques y su
## alcance; el camino de lo que viaja; las casillas de un volumen; el haz) pero sin aplicar nada — no suena, no emite señales, no levanta tierra ni echa agua, no crea zonas ni solideces, no golpea. En
## vez de golpear, ANOTA a quién habría golpeado (`_golpear`) y qué casillas de suelo habría marcado (`_marcar`). Devuelve:
##   golpes  [{obj, dir, punto, desde}] en el orden en que llegarían    suelo  [{elemento, celda}]    fines  [Vector3] dónde se detiene cada proyectil (vacío si no hay proyectil)
##   causas  [String] por qué se detuvo (golpe · muro · suelo · alcance · tiempo · frenado)    rebotes  cuántos rebotes dio en total
## NO cubre (se anota en la previsión): los eventos del hechizo (hijos, explosión en área `radio_explosion`, `al_golpear`…), los pulsos periódicos de las zonas, el empuje del gas a los enemigos ni los momentos
## de los glifos (el pulso de ᚱ). Un proyectil con `retorna` se prevé solo en la ida.
static func prever(hechizo: Hechizo, lanzador: Lanzador3D, origen: Vector3, dir: Vector3) -> Dictionary:
	var res: Dictionary = {"golpes": [], "suelo": [], "fines": [], "causas": [], "rebotes": 0, "caminos": [], "volumenes": [], "cruces": []}     # B5: cruces = lo que haría el proyectil al pasar por zonas de otro hechizo · caminos (28/10, apuntado): los puntos del vuelo de cada copia, para dibujarlo
	if hechizo == null or lanzador == null or lanzador.mundo == null or not lanzador.is_inside_tree():
		return res
	var copias: int = copias_de_proyectil(hechizo)
	for i in range(copias if hechizo.proyectil else 1):
		var v := HechizoVivo.new()
		v.lanz = lanzador
		v.h = hechizo
		v.g = hechizo.geo()
		v.elemento = hechizo.elemento
		v.estado = hechizo.estado_materia if MATERIA_V2.has(hechizo.estado_materia) else ESTADO_RESERVA_V2
		v.data = hechizo.fuente
		v.seco = true
		v.prevision = {"golpes": [], "suelo": [], "fin": Vector3.INF, "causa": "", "rebotes": 0, "cruces": []}
		v.linaje = Linaje.new()
		if hechizo.proyectil:
			var salida: Dictionary = salida_de_copia(hechizo, i, copias, dir)
			v._iniciar_proyectil(origen, salida["dir"], salida["desvio"])
			var camino: PackedVector3Array = [v.p]
			var pasos: int = 0
			while v.activo and not v.volviendo and pasos < PASOS_MAX_SECO:
				v.paso(PASO_SECO_S)
				pasos += 1
				camino.append(v.p)
			if v.activo and v.prevision["fin"] == Vector3.INF:
				v.prevision["fin"] = v.p                                # volvía (`retorna`) o no acabó: se queda donde llegó la ida
				v.prevision["causa"] = "retorna" if v.volviendo else "tiempo"
			if v.prevision["fin"] != Vector3.INF and camino[camino.size() - 1] != v.prevision["fin"]:
				camino.append(v.prevision["fin"])
			(res["caminos"] as Array).append(camino)
		elif hechizo.haz:
			v._materializar_haz(origen, dir)
			if v.prevision.has("haz"):
				(res["caminos"] as Array).append(v.prevision["haz"])
		else:
			v._materializar(origen, dir)
		(res["golpes"] as Array).append_array(v.prevision["golpes"] as Array)
		(res["volumenes"] as Array).append_array(v.prevision.get("volumenes", []) as Array)
		(res["suelo"] as Array).append_array(v.prevision["suelo"] as Array)
		(res["cruces"] as Array).append_array(v.prevision["cruces"] as Array)
		if v.prevision["fin"] != Vector3.INF:
			(res["fines"] as Array).append(v.prevision["fin"])
			(res["causas"] as Array).append(String(v.prevision["causa"]))
		res["rebotes"] = int(res["rebotes"]) + int(v.prevision["rebotes"])
		v.free()
	return res


## Un HechizoVivo montado pero sin nacer ni colgar del árbol: lo que `crear` usa y lo que las pruebas piden para mirar `eventos` o `camino` sin lanzar.
static func preparar(hechizo: Hechizo, lanzador: Lanzador3D) -> HechizoVivo:
	var v := HechizoVivo.new()
	v.lanz = lanzador
	v.h = hechizo
	v.g = hechizo.geo()
	v.elemento = hechizo.elemento
	v.estado = hechizo.estado_materia if MATERIA_V2.has(hechizo.estado_materia) else ESTADO_RESERVA_V2
	# 5. dura `persiste` × calidad: lo vean los estados en una COPIA (el .tres es compartido).
	v.data = hechizo.fuente
	if v.data != null and v.data.persiste > 0.0:
		v.data = hechizo.fuente.duplicate()
		v.data.persiste = hechizo.persiste
	return v


## Cuándo entra el agua de un hechizo líquido: 0,4 s + 0,07 s por cada unidad de semieje Y, hasta 0,8 s (la caída de la masa del VFX por estado).
static func tiempo_caida(geo: Dictionary) -> float:
	return minf(T_CAIDA_BASE_V2 + T_CAIDA_POR_Y_V2 * float(geo.get("y", 0.0)), T_CAIDA_MAX_V2)


## Hace que ocurra lo que dice el Hechizo: avisa al VFX, y cada tanda de casillas cobra vida a su hora. Devuelve cuántas casillas ocupa (0 = rechazado).
func _materializar(origen: Vector3, dir: Vector3) -> int:
	if h.orbita:
		return _materializar_orbita(origen, dir)          # 3/11 (R3): ᛃ sin flecha y con ᚠ: las copias orbitan al lanzador
	if h.haz:
		return _materializar_haz(origen, dir)             # RAYO (21/10): ᛁ + elemento. No es un volumen que se rasteriza: es un recorrido
	var aviso: String = Lanzador3D.GeometriaV2.aviso_materia(g, h.fuente)
	if aviso != "":
		if not seco:
			PlayLog.event("cast_rechazado_altura", {"elemento": elemento, "y_tope": int(g["y_tope"])})
		_rechazado = true
		return 0
	var props: Dictionary = g["props"]
	var d2 := Vector2(dir.x, dir.z)
	if d2.length() < 0.001:
		d2 = Vector2.RIGHT
	d2 = d2.normalized()
	# 1-4. cuándo y dónde aparece cada tanda de casillas (solo números).
	var eventos: Array = eventos_de(g, Vector2(origen.x, origen.z), d2)
	var todas: Array = []
	for ev in eventos:
		todas.append_array(ev["celdas"] as Array)
	_celdas_volumen = todas
	var niveles: int = Lanzador3D.GeometriaV2.niveles(g)
	# Lo que el VFX por estado (155) necesita y no podía adivinar: `persiste` ya multiplicado por la calidad, la altura del SUELO bajo el origen (el origen
	# es la mano) y los eventos de tiempo del hechizo (copias, viaje, rebotes: {t, pos: Vector2 del mundo, dir: Vector2}), sin las casillas.
	var t_caida: float = tiempo_caida(g) if estado == "liquido" else 0.0
	var c_origen: Vector2i = Terreno3D.celda_de(origen)
	var suelo: float = Terreno3D.y_pies(c_origen) if Terreno3D.en_mapa(c_origen) else origen.y
	var eventos_vfx: Array = []
	for ev in eventos:
		eventos_vfx.append({"t": float(ev["t"]), "pos": ev["pos"], "dir": ev["dir"], "vuelta": bool(ev.get("vuelta", false)), "copia": int(ev.get("copia", 0))})
	# §0.3 — la vida: si viaja, desaparece al llegar o chocar (+ `permanencia`) y la `persiste` del elemento NO cuenta; si nace quieto, `persiste` + `permanencia`.
	var viaja: bool = h.viaja
	_t_viaje = float(eventos.back()["t"]) if (viaja and not eventos.is_empty()) else 0.0
	var vida_total: float = (_t_viaje if viaja else h.persiste) + h.permanencia
	var volumen: Dictionary = {"x": g["x"], "y": g["y"], "z": g["z"], "celdas": todas, "niveles": niveles,
		"persiste": data.persiste, "suelo": suelo, "eventos": eventos_vfx, "t_caida": t_caida,
		"viaja": viaja, "velocidad": _velocidad_viaje(), "permanencia": h.permanencia, "vida_total": vida_total,
		"elevacion": h.elevacion, "separacion": h.separacion, "dispersion": h.dispersion, "gravedad": h.gravedad}
	if h.retorna and viaja:
		volumen["retorna"] = true                                              # 3/11 (R2): la ruta de `eventos` incluye la VUELTA (cada evento dice si es de vuelta); la clave solo sale si pasa
	# 3/11 (R4/R5): lo que el dibujo necesita del volumen que crece en altura o estalla (solo datos: la lógica ya lo decide aquí).
	var p0: Vector2 = (eventos[0]["pos"] as Vector2) if not eventos.is_empty() else Vector2(origen.x, origen.z)
	_centro_volumen = Vector3(p0.x, suelo + 0.3, p0.y)
	if h.columna and not viaja:
		var celdas_col: Dictionary = {}
		for c in todas:
			celdas_col[c] = true
		columna = {"celdas": celdas_col, "y1": float(g["y"]), "nace": h.escala_nace, "t0": h.retardo, "t": tiempo_crecimiento,
			"vida": h.retardo + maxf(maxf(tiempo_crecimiento, h.persiste + h.permanencia), COLUMNA_VIDA_MIN_S), "suelo": suelo}
		volumen["columna"] = {"y1": float(g["y"]), "nace": h.escala_nace, "t0": h.retardo, "t": tiempo_crecimiento}
		if not seco:
			_despues(float(columna["vida"]), func() -> void: pass)         # el hechizo vive mientras el pilar alza lo que tiene dentro (si no, se borraba al acabar de echar el agua)
	if h.estalla and h.profundidad == 0:
		volumen["estalla"] = {"t": h.retardo + _t_estallido(), "radio": h.radio_estallido}
	if not seco:
		lanz._sonar_fase_v2("impacto", elemento, String(g.get("nombre", "")), origen)
		lanz.hechizo_v2.emit(estado, elemento, volumen, origen, dir, props)
	else:
		# 28/10 (apuntado): lo que se anunciaría al dibujo, para el FANTASMA del indicador (`Apuntado3D`); no cambia lo que hace
		if not prevision.has("volumenes"):
			prevision["volumenes"] = []
		(prevision["volumenes"] as Array).append({"estado": estado, "elemento": elemento, "volumen": volumen, "origen": origen, "dir": dir, "props": props})
	var copias: float = float(props.get("copias", 1.0))
	var solidez: float = float(props.get("solidez", 0.0))
	var refleja: bool = float(props.get("rebotes", 0.0)) > 0.0 and float(props.get("viaja", 0.0)) <= 0.0
	var cuenta: int = 0
	var tocados: Dictionary = {}                       # a quién le llegó ya el golpe entero en ESTE hechizo (instance_id -> true)
	var tocados_vuelta: Dictionary = {}                # R2: el tramo de VUELTA es un tramo nuevo: puede volver a golpear a todos (como el proyectil que vuelve, `_fin_de_ida`)
	var ocupacion_s: float = (2.0 * float(g["z"]) + 1.0) / maxf(_velocidad_viaje(), 0.001)    # R1: lo que tarda el volumen en pasar por encima de una casilla (su fondo + una casilla)
	for ev in eventos:
		var celdas_ev: Array = ev["celdas"]
		var dir_ev: Vector2 = ev["dir"]
		var dir3: Vector3 = dir if dir_ev.is_equal_approx(d2) else Vector3(dir_ev.x, 0.0, dir_ev.y)
		var pos: Vector2 = ev["pos"]
		var vuelta: bool = bool(ev.get("vuelta", false))
		var vida: float = -1.0                             # -1 = sin vida declarada: cada materia usa la suya de siempre
		if viaja:
			vida = maxf(_t_viaje - float(ev["t"]) + h.permanencia, h.intervalo)
			if ev.has("ocupa"):
				# R1: la materia de un volumen que VIAJA y es sólido (muro) vive lo que el volumen tarda en pasar por la casilla (más la `permanencia` si es el último paso): el muro lleva su fuego o su agua, no los siembra
				vida = maxf(ocupacion_s + (h.permanencia if float(ev["t"]) >= float(ev["fin"]) - 0.001 else 0.0), h.intervalo)
		elif vida_total > 0.0:
			vida = vida_total
		var ctx: Dictionary = {"data": data, "elemento": elemento, "g": g, "celdas": celdas_ev, "niveles": niveles, "vida": vida,
			"origen": origen if pos.is_equal_approx(Vector2(origen.x, origen.z)) else Vector3(pos.x, origen.y, pos.y),
			"dir": dir3, "estado": estado, "fraccion": copias * float(celdas_ev.size()) / float(maxi(todas.size(), 1)),
			"tocados": tocados_vuelta if vuelta else tocados, "golpes": ev.get("golpes", [])}
		if ev.has("ocupa"):                                 # R1: el volumen que viaja lleva su solidez consigo (`_solidez_sigue`)
			ctx["sigue"] = true
			ctx["ocupa"] = ev["ocupa"]
			ctx["copia"] = int(ev.get("copia", 0))
			ctx["t_ev"] = float(ev["t"])
			ctx["fin"] = float(ev["fin"])
			var mv: Vector2 = ev.get("mueve", dir_ev)
			ctx["mueve"] = Vector3(mv.x, 0.0, mv.y)
		if vuelta:
			ctx["vuelta"] = true                            # R2: en la vuelta solo golpea y mueve la solidez; la materia ya se echó en la ida
		var t: float = float(ev["t"])
		if t <= 0.001 or seco:           # en seco no se espera: todas las tandas, de golpe (lo que ocupará el hechizo en total)
			cuenta += _vivir(ctx, solidez, refleja)
		else:
			if not vuelta:
				cuenta += celdas_ev.size()
			_despues(t, func() -> void: _vivir(ctx, solidez, refleja))
	return cuenta


## RAYO («haz», 21/10, decisión de Pablo): ᛁ `linea` + elemento. Un haz recto de la mano hacia `dir`, de `Hechizo.alcance_haz` m, que se PARA en casillas sólidas y barreras (el mismo `trazar` que el
## desplazamiento) y aplica el golpe del elemento a TODO el recorrido a la vez: cada casilla recibe su estado de suelo (mojado, quemado, helado…) y cada enemigo o reactivo que cruza, el golpe UNA vez
## (un haz perfora: no se detiene en el primero). No deja bloques, agua en la simulación ni zonas: el muro es de `barrera`. El dibujo (VfxElemento3D) llega por `hechizo_v2` con `volumen["haz"]`
## ({desde: la mano, hasta: la punta a ras de suelo, ancho en u, alcance, largo}). Devuelve las casillas que recorre (mínimo 1: un haz contra una pared pegada también se dispara).
func _materializar_haz(origen: Vector3, dir: Vector3) -> int:
	var d2 := Vector2(dir.x, dir.z)
	if d2.length() < 0.001:
		d2 = Vector2.RIGHT
	d2 = d2.normalized()
	var o2 := Vector2(origen.x, origen.z)
	var cas: float = Terreno3D.casilla
	# 30/10 (playtest de Pablo: ᚦ «tiene que tener efecto en el punto de impacto»): sin flecha, `perfora` deja ATRAVESAR hasta `perfora` casillas sólidas o barreras: el haz sigue detrás de ellas
	# con el alcance que le queda en vez de pararse en la primera. Cada tramo libre es un segmento; las casillas atravesadas no entran en el recorrido (siguen sin quemarse).
	var segmentos: Array = []
	var golpes_total: Array = []
	var inicio_s: Vector2 = o2
	var restante_cas: float = h.alcance_haz
	var atravesadas: int = 0
	var fin2: Vector2 = o2
	while true:
		var tramo: Array = camino(inicio_s, d2, restante_cas, 0, true)
		fin2 = (tramo.back()["p"] as Vector2) if not tramo.is_empty() else inicio_s
		segmentos.append([inicio_s, fin2])
		golpes_total.append_array(golpes_camino)
		restante_cas -= inicio_s.distance_to(fin2) / cas
		if atravesadas >= h.perfora or restante_cas < 0.05:
			break
		var salto: Dictionary = _haz_salto_obstaculo(fin2, d2, restante_cas * cas)
		if salto.is_empty() or atravesadas + int(salto["n"]) > h.perfora:
			break                                       # no hay obstáculo delante (acabó el alcance) o es más grueso de lo que perfora: se para como siempre
		atravesadas += int(salto["n"])
		restante_cas -= fin2.distance_to(salto["salida"] as Vector2) / cas
		inicio_s = salto["salida"]
		fin2 = inicio_s
	golpes_camino = golpes_total
	# Las casillas del recorrido: la recta de la mano al final muestreada a un cuarto de casilla (una diagonal no se salta ninguna), sin la del lanzador ni las sólidas.
	var c0: Vector2i = Terreno3D.celda_de(origen)
	var celdas: Array = []
	var vistas: Dictionary = {}
	var largo: float = o2.distance_to(fin2)
	for seg in segmentos:
		var a_s: Vector2 = seg[0]
		var b_s: Vector2 = seg[1]
		var pasos: int = maxi(int(ceilf(a_s.distance_to(b_s) / (cas * 0.25))), 1)
		for i in range(pasos + 1):
			var q: Vector2 = a_s.lerp(b_s, float(i) / float(pasos))
			var c: Vector2i = Terreno3D.celda_de(Vector3(q.x, 0.0, q.y))
			if c == c0 or vistas.has(c) or not Lanzador3D.en_mapa(c) or Lanzador3D.celda_solida(c, 0):
				continue
			vistas[c] = true
			celdas.append(c)
	_celdas_volumen = celdas
	var suelo: float = Terreno3D.y_pies(c0) if Terreno3D.en_mapa(c0) else origen.y
	var d3 := Vector3(d2.x, 0.0, d2.y)
	var mano := Vector3(o2.x, suelo + (h.altura_salida + h.elevacion) * cas, o2.y) + d3 * HAZ_BOCA_U                # de donde sale: la altura de la mano de una flecha, un poco por delante
	var punta := Vector3(fin2.x, suelo + HAZ_PUNTA_Y_U, fin2.y)                                                          # y acaba a ras del suelo, como el lanzallamas de siempre
	var vida_vfx: float = Hechizo.HAZ_DURA_S + h.permanencia
	if seco:
		prevision["haz"] = PackedVector3Array([mano, punta])       # 28/10 (apuntado): por dónde va el haz, para dibujarlo; no cambia lo que hace
	var volumen: Dictionary = {"x": g["x"], "y": g["y"], "z": g["z"], "celdas": celdas, "niveles": 1, "persiste": 0.0, "suelo": suelo,
		"eventos": [{"t": 0.0, "pos": o2, "dir": d2}], "t_caida": 0.0, "viaja": false, "velocidad": 0.0, "permanencia": h.permanencia, "vida_total": vida_vfx,
		"elevacion": h.elevacion, "separacion": h.separacion, "dispersion": h.dispersion, "gravedad": h.gravedad,
		"haz": {"desde": mano, "hasta": punta, "ancho": Hechizo.HAZ_ANCHO * cas, "alcance": h.alcance_haz, "largo": largo}}
	if not seco:
		lanz._sonar_fase_v2("impacto", elemento, String(g.get("nombre", "")), origen)
		lanz.hechizo_v2.emit(estado, elemento, volumen, origen, dir, g["props"])
	var ctx: Dictionary = {"data": data, "elemento": elemento, "g": g, "celdas": celdas, "niveles": 1, "vida": vida_vfx, "origen": origen, "dir": d3, "estado": estado,
		"fraccion": 1.0, "tocados": {}, "golpes": golpes_camino.duplicate()}
	_golpes_del_camino(ctx)
	_materia_haz(ctx)
	if is_inside_tree() and not seco:
		_despues(vida_vfx, func() -> void: pass)         # el HechizoVivo vive lo que se ve el haz: el dibujo cuelga de él y, si se va antes, se apaga a los 0,5 s (VfxElemento3D._soltar)
	return maxi(celdas.size(), 1)


## =====================================================================================================
##  3/11/2026 · R3, R4 y R5 (decisión de Pablo): lo que hace un volumen que NO es un proyectil mientras vive
## =====================================================================================================
## Un solo ticker, `avanzar_volumen(dt)`: lo llama `_physics_process` (y las pruebas, a mano, con `a_mano`). Hace avanzar los orbes (R3) y alza lo que haya dentro del pilar que crece (R4).

const ORBE_LANZADO_VEL: float = 5.0         ## m/s del orbe que sale disparado con ᚨ (más rápido que la flecha: ya va con su tamaño y rumbo)

func avanzar_volumen(dt: float) -> void:
	if proyectil or seco or not _nacido or dt <= 0.0:
		return
	_t_nacido += dt
	if not columna.is_empty():
		_avanzar_columna(dt)
	if not orbes.is_empty():
		_avanzar_orbes(dt)


## R3 · ᛃ sin flecha y con ᚠ (`Hechizo.orbita`): cada copia es un ORBE que da vueltas al lanzador. Radio = `ORBITA_RADIO_BASE_CAS` + `ORBITA_RADIO_POR_SEMIEJE` × el mayor de X y Z (así las ᛁ abren la órbita), una vuelta cada
## `ORBITA_VUELTA_S` s, repartidos a partes iguales; viven persiste + permanencia (mínimo `ORBITA_VIDA_MIN_S`). Cada orbe golpea una vez por vuelta a lo que toca (como el proyectil: `_golpear` → `al_golpear`). Con ᚨ (`busca`),
## un orbe por glifo sale disparado como proyectil contra un enemigo vivo cercano (`_orbe_busca`: el mismo imán que el proyectil). Devuelve cuántos orbes salen (las copias).
func _materializar_orbita(origen: Vector3, dir: Vector3) -> int:
	var cas: float = Terreno3D.casilla
	var n: int = maxi(h.copias, 1)
	var d2 := Vector2(dir.x, dir.z)
	d2 = d2.normalized() if d2.length() > 0.001 else Vector2.RIGHT
	radio_orbita_u = (ORBITA_RADIO_BASE_CAS + ORBITA_RADIO_POR_SEMIEJE * maxf(float(g["x"]), float(g["z"]))) * cas
	_vida_orbita = clampf(h.persiste + h.permanencia, ORBITA_VIDA_MIN_S, Hechizo.LIM_VIDA_S)
	_t_orbita = 0.0
	_centro_volumen = Vector3(origen.x, 0.0, origen.z)
	orbes = []
	for i in range(n):
		orbes.append({"ang": d2.angle() + TAU * float(i) / float(n), "vuelta": 0.0, "golpeados": {}, "activo": true, "lanzado": false, "p": Vector3.ZERO})
	_poner_orbes()
	if seco:
		return n
	var c0: Vector2i = Terreno3D.celda_de(origen)
	var suelo: float = Terreno3D.y_pies(c0) if Terreno3D.en_mapa(c0) else origen.y
	var volumen: Dictionary = {"x": g["x"], "y": g["y"], "z": g["z"], "celdas": [c0], "niveles": 1, "persiste": 0.0, "suelo": suelo,
		"eventos": [{"t": 0.0, "pos": Vector2(origen.x, origen.z), "dir": d2, "vuelta": false}], "t_caida": 0.0, "viaja": false, "velocidad": 0.0, "permanencia": h.permanencia, "vida_total": _vida_orbita,
		"elevacion": h.elevacion, "separacion": h.separacion, "dispersion": h.dispersion, "gravedad": h.gravedad,
		"orbita": {"n": n, "radio": radio_orbita_u, "vuelta_s": ORBITA_VUELTA_S, "vida": _vida_orbita, "radio_orbe": maxf(maxf(float(g["x"]), float(g["z"])) * Hechizo.ESCALA_PROYECTIL * cas, ORBE_RADIO_MIN_U)}}
	lanz._sonar_fase_v2("impacto", elemento, String(g.get("nombre", "")), origen)
	lanz.hechizo_v2.emit(estado, elemento, volumen, origen, dir, g["props"])
	_despues(_vida_orbita, _fin_orbita)
	return n


## El centro de la órbita: el lanzador a la altura de su mano (si no hay lanzador en juego, donde se lanzó).
func _centro_orbita() -> Vector3:
	var base: Vector3 = _centro_volumen
	if lanz != null and lanz.jugador != null and is_instance_valid(lanz.jugador):
		base = (lanz.jugador as Node3D).global_position
	var c: Vector2i = Terreno3D.celda_de(base)
	var suelo: float = Terreno3D.y_pies(c) if Terreno3D.en_mapa(c) else base.y
	return Vector3(base.x, suelo + (h.altura_salida + h.elevacion) * Terreno3D.casilla, base.z)


## Pone cada orbe en su sitio de la órbita (sin avanzar el ángulo).
func _poner_orbes() -> void:
	var centro: Vector3 = _centro_orbita()
	for o in orbes:
		var a: float = float((o as Dictionary)["ang"])
		(o as Dictionary)["p"] = centro + Vector3(cos(a), 0.0, sin(a)) * radio_orbita_u


func _avanzar_orbes(dt: float) -> void:
	_t_orbita += dt
	if _t_orbita >= _vida_orbita:
		_fin_orbita()
		return
	var w: float = TAU / ORBITA_VUELTA_S
	var centro: Vector3 = _centro_orbita()
	var r_acierto: float = maxf(maxf(float(g["x"]), float(g["z"])) * Hechizo.ESCALA_PROYECTIL * Terreno3D.casilla, ORBE_RADIO_MIN_U)
	for o in orbes:
		var od: Dictionary = o
		if not bool(od["activo"]):
			continue
		od["ang"] = float(od["ang"]) + w * dt
		od["vuelta"] = float(od["vuelta"]) + w * dt
		if float(od["vuelta"]) >= TAU:
			od["vuelta"] = float(od["vuelta"]) - TAU
			(od["golpeados"] as Dictionary).clear()                 # una vuelta nueva: puede volver a golpear a lo que ya tocó
		var a: float = float(od["ang"])
		od["p"] = centro + Vector3(cos(a), 0.0, sin(a)) * radio_orbita_u
		_golpes_del_orbe(od, r_acierto, Vector3(-sin(a), 0.0, cos(a)))
	_orbe_busca()


## Lo que toca un orbe en su posición (enemigos y reactivos a menos de radio + RADIO_ENEMIGO_U en planta y dentro de la ventana vertical): un golpe por objeto y vuelta.
func _golpes_del_orbe(o: Dictionary, r: float, tangente: Vector3) -> void:
	if lanz == null or not lanz.is_inside_tree():
		return
	var p_orbe: Vector3 = o["p"]
	var golpeados_orbe: Dictionary = o["golpeados"]
	for grupo in ["combate3d", "reactivo3d"]:
		for obj in lanz.get_tree().get_nodes_in_group(grupo):
			if fuera_de_juego(obj) or golpeados_orbe.has((obj as Object).get_instance_id()):
				continue
			var c: Vector3 = (obj as Node3D).global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0)
			var plano: Vector3 = c - p_orbe
			plano.y = 0.0
			if plano.length() > r + RADIO_ENEMIGO_U or absf(c.y - p_orbe.y) > r + VENTANA_Y_U:
				continue
			golpeados_orbe[(obj as Object).get_instance_id()] = true
			golpes_dados += 1
			_golpear(obj, tangente, (obj as Node3D).global_position, p_orbe)


## R3 + ᚨ: «un orbe sale disparado hacia un enemigo vivo cercano (como el imán actual)». Por cada ᚨ (`busca`) un orbe — el más cercano al enemigo — deja la órbita como PROYECTIL (copia del hechizo con velocidad, alcance
## `BUSCA_ALCANCE_CAS` y su `busca`, que lo gira hacia el objetivo con `_buscar`), contra el enemigo vivo más cercano al lanzador dentro de ese alcance que aún no tenga un orbe encima.
func _orbe_busca() -> void:
	if h.busca <= 0.0 or orbes_lanzados >= int(ceilf(h.busca)) or lanz == null or not lanz.is_inside_tree() or linaje == null or linaje.vivos >= Hechizo.MAX_VIVOS:
		return
	var centro: Vector3 = _centro_orbita()
	var objetivo: Node3D = null
	var mejor: float = INF
	for e in lanz.get_tree().get_nodes_in_group("combate3d"):
		if fuera_de_juego(e) or _objetivos_orbe.has((e as Object).get_instance_id()) or (e.has_method("apuntable") and not e.apuntable()):
			continue                                    # (6/11: el canouro con niebla no se deja fijar)
		var dist: float = ((e as Node3D).global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0) - centro).length()
		if dist <= BUSCA_ALCANCE_CAS * Terreno3D.casilla and dist < mejor:
			mejor = dist
			objetivo = e as Node3D
	if objetivo == null:
		return
	var elegido: int = -1
	var cerca: float = INF
	for i in range(orbes.size()):
		if bool((orbes[i] as Dictionary)["activo"]):
			var dd: float = ((orbes[i] as Dictionary)["p"] as Vector3).distance_to(objetivo.global_position)
			if dd < cerca:
				cerca = dd
				elegido = i
	if elegido < 0:
		return
	var od: Dictionary = orbes[elegido]
	od["activo"] = false
	od["lanzado"] = true
	orbes_lanzados += 1
	_objetivos_orbe[(objetivo as Object).get_instance_id()] = true
	var hijo: Hechizo = h.copiar()
	hijo.eventos = {}
	hijo.profundidad = h.profundidad + 1
	hijo.con({"velocidad": ORBE_LANZADO_VEL, "distancia_max": BUSCA_ALCANCE_CAS, "copias": 1, "retorna": false, "crece": 0.0, "solidez": 0.0, "gravedad": 0.0, "retardo": 0.0})
	var al: Vector3 = objetivo.global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0) - (od["p"] as Vector3)
	al.y = 0.0
	var d: Vector3 = al.normalized() if al.length() > 0.01 else Vector3.RIGHT
	HechizoVivo.crear(hijo, od["p"] as Vector3, d, lanz, linaje, golpeados.duplicate(), manual)


## Se acaba la órbita: los orbes se apagan (lo que ya salió disparado sigue su vuelo).
func _fin_orbita() -> void:
	for o in orbes:
		(o as Dictionary)["activo"] = false


## R4 · la altura (u sobre el suelo) a la que ha subido el pilar que crece: de `nace` × su altura final a la entera, a `crece` m/s de radio (el mismo tiempo que ya manda `tiempo_de_crecer`). 0 si no es un pilar o aún no ha nacido.
func altura_columna_u() -> float:
	if columna.is_empty():
		return 0.0
	var t: float = _t_nacido - float(columna["t0"])
	if t < 0.0:
		return 0.0
	var total: float = float(columna["t"])
	var nace: float = float(columna["nace"])
	var s: float = 1.0 if total <= 0.0 else clampf(nace + (1.0 - nace) * t / total, nace, 1.0)
	return float(columna["y1"]) * s * Terreno3D.casilla


## R4 · «ELEVA lo que haya dentro»: mientras vive el pilar (`columna["vida"]`), todo lo que está en sus casillas y tiene `elevar` (el contrato nuevo, hermano de `push`: `Jugador3D.elevar` usa su `vy`, el salto de siempre;
## `Combate3D.elevar` alza su dibujo como el saltito del golpe) sube con la cima: se queda a la altura que lleva el pilar. Al acabar, se suelta (el jugador cae por su gravedad; el enemigo baja).
func _avanzar_columna(dt: float) -> void:
	if lanz == null or not lanz.is_inside_tree() or _t_nacido < float(columna["t0"]) or _t_nacido > float(columna["vida"]):
		return
	var alto: float = altura_columna_u()
	var celdas: Dictionary = columna["celdas"]
	var dentro: Array = []
	if lanz.jugador != null and is_instance_valid(lanz.jugador) and celdas.has(Terreno3D.celda_de((lanz.jugador as Node3D).global_position)):
		dentro.append(lanz.jugador)
	for grupo in ["combate3d", "reactivo3d"]:
		dentro.append_array(nodos_en(lanz, grupo, celdas))
	for obj in dentro:
		if obj.has_method("elevar"):
			obj.call("elevar", alto, dt)
			if elemento == "viento" and not (obj is Jugador3D and obj.nadando):
				VfxToyJuego.aura_viento(obj, 0.55, true)
			elevados += 1
		elif elemento == "viento" and obj is RigidBody3D:
			var cuerpo := obj as RigidBody3D
			if cuerpo.freeze:
				continue
			var suelo: float = Terreno3D.y_pies(Terreno3D.celda_de(cuerpo.global_position))
			var diferencia: float = suelo + alto - cuerpo.global_position.y
			cuerpo.sleeping = false
			cuerpo.linear_velocity.y = clampf(diferencia * 7.0, -2.0, 5.0)
			VfxToyJuego.aura_viento(cuerpo, 0.55, true)
			elevados += 1


## R5 · cuánto vive (s, desde que nace) el volumen líquido que crece antes de estallar: su vida (persiste + permanencia) con un mínimo de `Hechizo.ESTALLIDO_MIN_S` y nunca menos de lo que tarda en crecer.
func _t_estallido() -> float:
	return maxf(maxf(h.persiste + h.permanencia, Hechizo.ESTALLIDO_MIN_S), tiempo_crecimiento)


## R5 · el estallido del volumen líquido que ha crecido (`Hechizo.estalla`): el agua revienta y daña en área (`_danar_area`, el mismo de `radio_explosion`) de `Hechizo.radio_estallido` casillas desde su centro, con el daño del hechizo.
func _estallar(dir: Vector3) -> void:
	if lanz == null or not lanz.is_inside_tree():
		return
	estallidos += 1
	eventos_vistos.append("estallido")
	_danar_area(h.radio_estallido, h.dano, _centro_volumen, dir)


## `perfora` del haz: si justo delante de `desde` (a menos de media casilla) hay una casilla sólida o una barrera, sigue en línea recta hasta salir de ella (como mucho `max_m` metros) y devuelve
## {salida: Vector2 (un poco más allá), n: casillas sólidas distintas y barreras atravesadas}. Vacío si no hay obstáculo delante o no se sale de él dentro del alcance.
func _haz_salto_obstaculo(desde: Vector2, d: Vector2, max_m: float) -> Dictionary:
	if lanz == null or lanz.mundo == null:
		return {}
	var cas: float = Terreno3D.casilla
	var paso: float = cas * 0.1
	var y: float = Terreno3D.y_pies(Terreno3D.celda_de(Vector3(desde.x, 0.0, desde.y))) + Terreno3D.ALTO_NIVEL * 0.5
	var dentro: bool = false
	var cuenta: Dictionary = {}
	var libres_seguidos: int = 0
	var rec: float = paso
	while rec <= max_m:
		var q: Vector2 = desde + d * rec
		var cq: Vector2i = Terreno3D.celda_de(Vector3(q.x, 0.0, q.y))
		var sol: bool = Lanzador3D.celda_solida(cq, 0)
		var bar: bool = lanz._barrera_en(Vector3(q.x, y, q.y), 0)
		if sol or bar:
			dentro = true
			cuenta[cq if sol else Vector2i(-1000, int(floorf(rec / cas)))] = true         # una barrera cuenta una vez por casilla de recorrido que ocupa
			libres_seguidos = 0
		elif dentro:
			return {"salida": q + d * paso, "n": cuenta.size()}
		elif rec > cas * 0.5:
			return {}                                       # no hay obstáculo pegado al final del tramo
		rec += paso
	return {}


## Lo que el haz hace en sus casillas (RAYO): la ENERGÍA es la descarga de siempre (recorre el agua y los conductores y golpea a todo lo que haya); el resto marca el estado de suelo que deja el
## elemento (`deja`) y golpea UNA vez a cada enemigo y reactivo de las casillas, como un impacto de ese elemento (`_contacto` → `Lanzador3D._golpear`: daño, estados, empuje del viento…).
func _materia_haz(ctx: Dictionary) -> int:
	var celdas: Array = ctx["celdas"]
	if celdas.is_empty():
		return 0
	if String(ctx["estado"]) == "energia":
		return _descarga(ctx, {})
	var rune: RuneData = ctx["data"]
	if rune != null and rune.deja != "":
		for c in celdas:
			_marcar(String(ctx["elemento"]), c as Vector2i)
	_contacto(ctx)
	return celdas.size()


## Ejecuta `f` dentro de `t` s (de juego: respeta la pausa y el time_scale). El nodo no se borra hasta que se hayan cumplido todos sus retrasos.
func _despues(t: float, f: Callable) -> void:
	if t <= 0.001:
		f.call()
		return
	_pendientes += 1
	get_tree().create_timer(t, false).timeout.connect(HechizoVivo._tras_espera.bind(weakref(self), f))      # referencia DÉBIL (como `_olvidar`): una lambda que capture `self` da error en el motor si el nodo muere antes


## Cumple un retraso de `_despues`. Si el HechizoVivo ya no existe (pruebas, cambio de escena) no hace nada y `f` ni se llama (sus propias capturas apuntan a él).
static func _tras_espera(yo_ref: WeakRef, f: Callable) -> void:
	var yo: Variant = yo_ref.get_ref()
	if yo == null or not is_instance_valid(yo) or not (yo as HechizoVivo).is_inside_tree():
		return
	f.call()
	(yo as HechizoVivo)._pendientes -= 1
	(yo as HechizoVivo)._revisar_fin()


## Cuando ya nació y no le queda nada por cumplir, se borra (lo que dejó en el mundo sigue con su vida propia).
func _revisar_fin() -> void:
	if _nacido and _pendientes <= 0 and not activo and is_inside_tree() and not is_queued_for_deletion():
		queue_free()


## Una tanda de casillas cobra vida: el estado del elemento la llena (MATERIA_V2) y, si hay `solidez`, un SolidezV2 la protege por encima.
func _vivir(ctx: Dictionary, solidez: float, refleja: bool) -> int:
	var vuelta: bool = bool(ctx.get("vuelta", false))
	if vuelta and seco:
		return 0                                           # R2: la previsión no cuenta la vuelta
	_golpes_del_camino(ctx)
	var sigue: bool = bool(ctx.get("sigue", false)) and solidez > 0.0
	if sigue and not seco:
		_solidez_sigue(ctx, solidez, refleja)              # R1: la solidez del volumen que viaja se mueve con él (también en un paso sin casillas nuevas)
	if (ctx["celdas"] as Array).is_empty():
		return 0
	if CONTACTO_V2.has(String(ctx["estado"])) or vuelta:
		_contacto(ctx)                                     # R2: en la vuelta TODOS los estados golpean lo que cruzan (en la ida los de zona lo hacen por su pulso)
	if vuelta:
		return 0                                           # …pero sin repetir la materia
	if seco:
		return _materia_seca(ctx)
	var n: int = int(call(String(MATERIA_V2[String(ctx["estado"])]), ctx))
	if solidez > 0.0 and not sigue:
		_solidez(ctx, solidez, refleja)
	return n


## Lo que el desplazamiento tocó por el camino (`trazar`: objetos que reaccionan y paran el trazo): un golpe a cada uno, una vez.
func _golpes_del_camino(ctx: Dictionary) -> void:
	var tocados: Dictionary = ctx["tocados"]
	for gp in ctx["golpes"]:
		var obj: Node = gp["obj"]
		if not is_instance_valid(obj) or tocados.has(obj.get_instance_id()):
			continue
		tocados[obj.get_instance_id()] = true
		_golpear(obj, gp["dir"], gp["punto"], gp["desde"])


## Golpe de contacto de los estados que no lo dan en su materia: a cada reactivo y enemigo de las casillas, una vez por hechizo.
func _contacto(ctx: Dictionary, grupos: Array = ["reactivo3d", "combate3d"]) -> void:
	var tocados: Dictionary = ctx["tocados"]
	var celdas: Dictionary = {}
	for c in ctx["celdas"]:
		celdas[c] = true
	for grupo in grupos:
		for obj in nodos_en(lanz, grupo, celdas):
			if tocados.has(obj.get_instance_id()) or fuera_de_juego(obj):
				continue
			tocados[obj.get_instance_id()] = true
			_golpear(obj, ctx["dir"], (obj as Node3D).global_position, ctx["origen"])


## Las tandas de casillas de TODO el hechizo, en orden de tiempo: [{t, celdas, pos: Vector2, dir: Vector2}]. Las casillas de cada tanda son las
## NUEVAS (las que no estaban ya en una anterior): un volumen que crece o viaja deja su rastro sin repetir casillas.
##   1. copias   n volúmenes repartidos a lo largo de X (perpendicular a la mirada), separados lo que mide cada uno de ancho
##   2. nace     en la mano, quieto; si `crece`, empieza a `escala_nace` en planta y su radio crece `crece` m/s hasta el 100 % (`tiempo_de_crecer`)
##   3. viaja    `distancia_max` m desde ahí (a `velocidad`, 8 m/s si es 0), parando donde para `trazar`; 4. rebota `rebotes` veces (el rebote de `trazar`)
func eventos_de(geo: Dictionary, origen: Vector2, d: Vector2) -> Array:
	var props: Dictionary = geo["props"]
	var cas: float = Terreno3D.casilla
	var copias: int = maxi(1, int(props.get("copias", 1.0)))
	var crece: float = float(props.get("crece", 0.0))
	var viaja: float = float(props.get("viaja", 0.0))
	var rebotes: int = int(props.get("rebotes", 0.0))
	var perp: Vector2 = d.orthogonal()
	# de centro a centro: lo que mide cada copia + el hueco entre ellas, pero nunca menos de una casilla (24/10: con la base 0,10 la esfera base mide 0,2 y dos copias caían en la misma casilla)
	var separacion: float = maxf(2.0 * float(geo["x"]) + h.separacion, SEPARACION_COPIAS_MIN_CASILLAS) * cas
	var vel: float = _velocidad_viaje()                                      # m/s = casillas/s
	var semieje_crece: float = maxf(float(geo["x"]), float(geo["z"]))        # el radio que manda el tiempo de crecimiento: el mayor de la planta (la altura nace entera)
	if h.columna:
		semieje_crece = maxf(semieje_crece, float(geo["y"]))                   # 3/11 (R4): un pilar crece también de abajo arriba y manda su altura: la altura NO nace entera
	var fases: Array = fases_crece(crece, h.escala_nace, h.intervalo, semieje_crece)
	tiempo_crecimiento = tiempo_de_crecer(crece, h.escala_nace, semieje_crece)
	var ya: Dictionary = {}
	var eventos: Array = []
	var sigue: bool = h.volumen_viaja                                          # 3/11 (R1): cada paso del volumen sólido que viaja es un evento aunque no gane casillas, con TODAS las que ocupa (su solidez las lleva)
	# Con un número PAR de copias el reparto simétrico (−0,5, +0,5 pasos…) pone sus centros justo en el borde entre dos casillas, y el redondeo de coma flotante los mete a veces en la misma:
	# ᚠ×1 daba 1 casilla en vez de 2 y ᚠ×3 daba 3 en vez de 4 (auditoría D-1). El centro del reparto se corre medio paso (la primera copia, o la mitad de ellas, queda en la mano y el resto
	# a un paso entero): cada centro cae a un número entero de pasos de la mano, nunca en un borde. Con un número impar el reparto es el simétrico de siempre.
	var mitad_copias: int = floori(float(copias - 1) * 0.5)
	for i in range(copias):
		var o: Vector2 = origen + perp * (float(i - mitad_copias) * separacion)
		var di: Vector2 = d.rotated(deg_to_rad((float(i) - float(copias - 1) * 0.5) * h.dispersion))   # abanico: cada copia mira `dispersion` grados más allá que la anterior
		var primero_copia: int = eventos.size()
		for f in fases:
			_evento(eventos, ya, geo, float(f["s"]), o, di, h.retardo + float(f["t"]), sigue, i)
		if viaja > 0.0:
			var t0: float = h.retardo + float((fases.back() as Dictionary)["t"])
			var recorrido: Array = camino(o, di, viaja, rebotes)
			for j in range(recorrido.size()):
				var paso: Dictionary = recorrido[j]
				_evento(eventos, ya, geo, 1.0, paso["p"], paso["d"], t0 + float(j + 1) / vel, sigue, i)
			if not golpes_camino.is_empty():
				var fin: Dictionary = recorrido.back() if not recorrido.is_empty() else {"p": o, "d": di}
				eventos.append({"t": t0 + float(recorrido.size()) / vel, "celdas": [], "pos": fin["p"], "dir": fin["d"], "golpes": golpes_camino.duplicate()})
			# 3/11 · R2 (decisión de Pablo: «ᛃ sobre cualquier cosa que viaja = el camino incluye la VUELTA»): el volumen que viaja y `retorna` deshace su ruta hasta la mano. El tramo de vuelta es un tramo nuevo
			# (vuelve a golpear a todos lo que cruza, y su solidez lo sigue) pero NO repite la materia: el fuego o el agua ya quedaron en la ida. La dirección del dibujo (`dir`) es la de siempre; `mueve` es hacia dónde va.
			if h.retorna and not recorrido.is_empty():
				var t_ida: float = t0 + float(recorrido.size()) / vel
				var puntos: Array = [{"p": o, "d": di}] + recorrido
				for k in range(1, puntos.size()):
					var destino: Dictionary = puntos[puntos.size() - 1 - k]
					var desde: Dictionary = puntos[puntos.size() - k]
					var sentido: Vector2 = ((destino["p"] as Vector2) - (desde["p"] as Vector2))
					sentido = sentido.normalized() if sentido.length() > 0.001 else -(desde["d"] as Vector2)
					var cs_vuelta: Array = _celdas_del_volumen(geo, destino["p"] as Vector2, di)
					var ev_vuelta: Dictionary = {"t": t_ida + float(k) / vel, "celdas": cs_vuelta, "pos": destino["p"], "dir": di, "mueve": sentido, "vuelta": true}
					if sigue:
						ev_vuelta["ocupa"] = cs_vuelta
						ev_vuelta["copia"] = i
					eventos.append(ev_vuelta)
		if sigue:
			var t_fin: float = 0.0
			for k in range(primero_copia, eventos.size()):
				t_fin = maxf(t_fin, float((eventos[k] as Dictionary)["t"]))
			for k in range(primero_copia, eventos.size()):
				if (eventos[k] as Dictionary).has("ocupa"):
					(eventos[k] as Dictionary)["fin"] = t_fin
	eventos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	if eventos.size() > MAX_EVENTOS_V2:
		eventos.resize(MAX_EVENTOS_V2)
	return eventos


## A qué velocidad (m/s = casillas/s) se desplaza lo que viaja: `velocidad`, o la de siempre (8) si el hechizo no la fija.
func _velocidad_viaje() -> float:
	return h.velocidad if h.velocidad > 0.0 else Hechizo.VELOCIDAD_VIAJE_DEFECTO


## Cuánto tarda (s) en llegar a su tamaño entero lo que crece `crece` m/s de RADIO (ESPEC §1.3) desde `escala_nace` × `semieje` hasta `semieje` m: (semieje − semieje × escala_nace) / crece.
## Antes (hasta el 24/10) `crece` era una fracción de escala por segundo: (1 − escala_nace) / crece, igual para un volumen de 0,2 m que para uno de 3 m. Sin `crece`: 0.
static func tiempo_de_crecer(crece: float, escala_nace: float, semieje: float) -> float:
	if crece <= 0.0:
		return 0.0
	return maxf(semieje - semieje * escala_nace, 0.0) / crece


## Fases de crecimiento en planta: [{t, s}] con s de `escala_nace` a 1, repartidas en MUESTRAS_CRECE_V2 pasos iguales del tiempo de crecimiento (el radio crece LINEAL a `crece` m/s). Sin `crece`: una sola
## fase al 100 % en t = 0. `semieje` es el radio entero en m (el mayor de la planta): con 1 m es el tiempo «de referencia». `eventos_de` solo guarda las fases en que el volumen gana una casilla
## nueva (las que no cambian nada no dejan tanda), así que muestrear fino no llena de eventos: es lo que hace que el volumen vuelva a rasterizar justo cuando su radio cruza una casilla.
## (`_intervalo` ya no limita las fases: se conserva solo para no romper a quien llama con tres argumentos.)
static func fases_crece(crece: float, escala_nace: float, _intervalo: float, semieje: float = 1.0) -> Array:
	if crece <= 0.0:
		return [{"t": 0.0, "s": 1.0}]
	var fases: Array = []
	var total: float = tiempo_de_crecer(crece, escala_nace, semieje)
	var paso: float = maxf(total / float(MUESTRAS_CRECE_V2), PASO_CRECE_MIN_S)
	var t: float = 0.0
	while t < total - 0.001:
		fases.append({"t": t, "s": minf(1.0, escala_nace + (1.0 - escala_nace) * t / maxf(total, 0.0001))})
		t += paso
	fases.append({"t": total, "s": 1.0})
	return fases


## Añade la tanda de casillas del volumen a escala `s` (en planta) centrado en `pos`, sin las que ya tenía un evento anterior.
func _evento(eventos: Array, ya: Dictionary, geo: Dictionary, s: float, pos: Vector2, d: Vector2, t: float, con_ocupa: bool = false, copia: int = 0) -> void:
	var gs: Dictionary = geo.duplicate()
	gs["x"] = float(geo["x"]) * s
	gs["z"] = float(geo["z"]) * s
	var nuevas: Array = []
	var todas_en_mapa: Array = []
	var lista_celdas: Array = _celdas_de_paso(gs, pos, d) if con_ocupa else Lanzador3D.GeometriaV2.celdas(gs, pos, d, Terreno3D.casilla)
	for c in lista_celdas:
		var cc: Vector2i = c
		if not Lanzador3D.en_mapa(cc):
			continue
		todas_en_mapa.append(cc)
		if not ya.has(cc):
			ya[cc] = true
			nuevas.append(cc)
	if con_ocupa:
		# R1: el volumen sólido que viaja deja un evento en CADA paso (aunque no gane casillas) con todas las que ocupa en él: su SolidezV2 se mueve con ellas
		eventos.append({"t": t, "celdas": nuevas, "pos": pos, "dir": d, "ocupa": todas_en_mapa, "copia": copia})
	elif not nuevas.is_empty():
		eventos.append({"t": t, "celdas": nuevas, "pos": pos, "dir": d})


## Las casillas del volumen (a su escala entera) centrado en `pos` mirando a `d`, sin las que quedan fuera del mapa: lo que ocupa en ese paso de su ruta.
func _celdas_del_volumen(geo: Dictionary, pos: Vector2, d: Vector2) -> Array:
	var r: Array = []
	for c in _celdas_de_paso(geo, pos, d):
		if Lanzador3D.en_mapa(c as Vector2i):
			r.append(c)
	return r


## 3/11 (R1): las casillas del volumen centrado en `pos` SIN la propia casilla de `pos` cuando el centro del volumen va más de media casilla por delante (ᛜ + ᛁ: el muro nace una casilla delante de quien lanza). `GeometriaV2.celdas`
## mete siempre la casilla de `pos` (para la esfera base es su centro); en un muro es la de quien lanza, y un volumen que se desplaza no debe arrastrarla consigo. Un volumen quieto no pasa por aquí: no cambia.
func _celdas_de_paso(gs: Dictionary, pos: Vector2, d: Vector2) -> Array:
	var cas: float = Terreno3D.casilla
	var r: Array = Lanzador3D.GeometriaV2.celdas(gs, pos, d, cas)
	var avance: float = Lanzador3D.GeometriaV2.adelanto(gs)
	if avance < 0.5:
		return r
	var c0 := Vector2i(int(floorf(pos.x / cas)), int(floorf(pos.y / cas)))
	var dn: Vector2 = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var rel: Vector2 = (Vector2((float(c0.x) + 0.5) * cas, (float(c0.y) + 0.5) * cas) - pos) / cas
	var lz: float = rel.dot(dn) - avance
	var lx: float = rel.dot(dn.orthogonal())
	var sx: float = maxf(float(gs["x"]), 0.0001)
	var sz: float = maxf(float(gs["z"]), 0.0001)
	if (lz * lz) / (sz * sz) + (lx * lx) / (sx * sx) <= 1.0:
		return r
	r.erase(c0)
	return r


## El camino del desplazamiento: una posición por casilla recorrida, [{p: Vector2, d: Vector2}], SIN la de partida. Lo traza `trazar` (para
## en casillas sólidas, barreras y objetos que reaccionan; rebota `rebotes` veces), así que viajar y rebotar es lo MISMO que una flecha.
func camino(origen: Vector2, d: Vector2, viaja: float, rebotes: int, atraviesa: bool = false) -> Array:
	var cas: float = Terreno3D.casilla
	var res: Array = []
	golpes_camino = []
	if lanz.mundo == null:
		for k in range(1, int(floorf(viaja)) + 1):
			res.append({"p": origen + d * cas * float(k), "d": d})
		return res
	var inicio := Vector3(origen.x, Lanzador3D.y_pies(Lanzador3D.celda_de(Vector3(origen.x, 0.0, origen.y))) + Terreno3D.ALTO_NIVEL * 0.5, origen.y)
	var altura_antes: int = lanz.altura
	var tr: Dictionary = lanz.trazar(inicio, Vector3(d.x, 0.0, d.y), viaja * cas, 0, data, atraviesa, rebotes, false, h)
	lanz.altura = altura_antes
	var recorrido: float = 0.0
	var siguiente: float = cas
	for tramo in tr["tramos"]:
		var a: Vector3 = tramo["desde"]
		var b: Vector3 = tramo["hasta"]
		var largo: float = a.distance_to(b)
		var dd := Vector2((tramo["dir"] as Vector3).x, (tramo["dir"] as Vector3).z)
		while siguiente <= recorrido + largo + 0.001:
			var q: Vector3 = a.lerp(b, (siguiente - recorrido) / maxf(largo, 0.0001))
			res.append({"p": Vector2(q.x, q.z), "d": dd})
			siguiente += cas
		recorrido += largo
		for gp in tramo["golpes"]:
			golpes_camino.append({"obj": gp["obj"], "punto": gp["punto"], "dir": tramo["dir"], "desde": tramo["desde"]})
	# Si el trazo se cortó entre dos casillas (un objeto, una pared), el volumen llega hasta ese punto: ahí es donde «impacta».
	var fin3: Vector3 = tr["fin"]
	var fin2 := Vector2(fin3.x, fin3.z)
	var hacia_atras := Vector2(((tr["tramos"] as Array).back() as Dictionary)["dir"].x, ((tr["tramos"] as Array).back() as Dictionary)["dir"].z)
	for _k in range(8):                                   # `trazar` acaba unos centímetros DENTRO de la casilla sólida que lo para: el volumen se queda delante
		if not Lanzador3D.celda_solida(Lanzador3D.celda_de(Vector3(fin2.x, 0.0, fin2.y)), 0):
			break
		fin2 -= hacia_atras * cas * 0.1
	var ultima: Vector2 = (res.back()["p"] as Vector2) if not res.is_empty() else origen
	if fin2.distance_to(ultima) > cas * 0.05:
		var tramos: Array = tr["tramos"]
		var dir_fin := Vector2(((tramos.back() as Dictionary)["dir"] as Vector3).x, ((tramos.back() as Dictionary)["dir"] as Vector3).z)
		res.append({"p": fin2, "d": dir_fin})
	return res


## Cuánto vive lo que nace en esta tanda (§0.3): la vida que calculó `_materializar`, o `defecto` si el hechizo no declara ninguna (persiste = permanencia = 0).
static func _vida(ctx: Dictionary, defecto: float) -> float:
	var v: float = float(ctx.get("vida", -1.0))
	return defecto if v < 0.0 else v


## SÓLIDO: un cuerpo con colisión por casilla × niveles. Pisable (`pisable`): el bloque de tierra de siempre, que sube `Terreno3D.alturas`
## y hace de presa del agua; si no, una casilla bloqueada. Dura `persiste` s (el hielo, por tanto, se «derrite» al acabar: el bloque se hunde). Si el
## elemento deja estado de suelo (`deja`: el hielo hiela el agua que cubre), se marca ANTES de construir (H4: con un bloque encima no se marca).
func _materia_solido(ctx: Dictionary) -> int:
	var rune: RuneData = ctx["data"]
	var persiste: float = _vida(ctx, Lanzador3D.DURACION_TIERRA)
	var puestos: int = 0
	for c in ctx["celdas"]:
		var cc: Vector2i = c
		if rune.deja != "":
			_marcar(String(ctx["elemento"]), cc)
		if rune.pisable:
			var opc: Dictionary = {"resta": persiste, "color": rune.color.darkened(0.15), "v2": true, "apilar": int(ctx["niveles"]), "elemento": String(ctx["elemento"])}
			opc.merge(perfil_solido(cc, ctx))
			for _k in range(int(ctx["niveles"])):
				if lanz.construir_tierra(cc, true, opc):
					puestos += 1
		elif Lanzador3D.en_mapa(cc) and not Lanzador3D.es_agua(cc) and not Lanzador3D.bloqueada(cc):
			Lanzador3D.bloquear_celda(cc)
			lanz._despues(persiste, Lanzador3D.liberar_celda.bind(cc))      # la casilla se libera aunque este nodo ya no exista
			puestos += int(ctx["niveles"])
	return puestos


## 29/10 (Pablo, laboratorio de geometrías: «con el sólido crea formas que se parezcan a la geometría»): el DIBUJO de cada bloque sigue el perfil del elipsoide.
## Las casillas del centro, enteras; las del borde, más estrechas (hasta PERFIL_BORDE_XZ) y desplazadas hacia dentro, y un poco más bajas (PERFIL_BORDE_Y), así un
## muro ancho sale curvo y una losa larga, redondeada. La colisión y la altura que se pisa no cambian (la casilla sigue entera). Un volumen de una casilla no cambia.
const PERFIL_BORDE_XZ: float = 0.7
const PERFIL_BORDE_Y: float = 0.85

## {"escala": Vector3, "desplaza": Vector3} del bloque de la casilla `c` dentro del volumen de `ctx` (centro `origen`, dirección `dir`, semiejes `g` en casillas).
static func perfil_solido(c: Vector2i, ctx: Dictionary) -> Dictionary:
	var cas: float = Terreno3D.casilla
	var o: Vector3 = ctx["origen"]
	var d3: Vector3 = ctx["dir"]
	var d := Vector2(d3.x, d3.z)
	d = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var g: Dictionary = ctx["g"]
	var sx: float = maxf(float(g["x"]), 0.5)
	var sz: float = maxf(float(g["z"]), 0.5)
	var rel: Vector2 = (Vector2((float(c.x) + 0.5) * cas, (float(c.y) + 0.5) * cas) - Vector2(o.x, o.z)) / cas
	# 31/10 (REV 01, Pablo: «la tierra, geometrías coherentes con los ejes X y Z»): el centro del elipsoide está `GeometriaV2.adelanto(g)` casillas por delante de `origen` (como en `celdas`);
	# antes se medía desde `origen` y una losa larga en Z salía con el fondo recortado como si fuera borde y la parte de atrás entera.
	# (Lo que aplica un proyectil al pararse ya va CENTRADO en el punto, `_celdas_en`: ahí no hay adelanto.)
	var lz: float = rel.dot(d) - (0.0 if bool(ctx.get("impacto", false)) else Lanzador3D.GeometriaV2.adelanto(g))
	var lx: float = rel.dot(d.orthogonal())
	var r2: float = (lx * lx) / (sx * sx) + (lz * lz) / (sz * sz)
	if r2 <= 0.0001 or (sx <= 0.5 and sz <= 0.5):
		return {}
	var k: float = sqrt(clampf(1.0 - r2, 0.0, 1.0))            # 1 en el centro, 0 en el borde del elipsoide
	var exz: float = lerpf(PERFIL_BORDE_XZ, 1.0, k)
	var ey: float = lerpf(PERFIL_BORDE_Y, 1.0, k)
	var hacia_centro: Vector2 = -rel.normalized() * cas * (1.0 - exz) * 0.5 * 0.94
	return {"escala": Vector3(exz, ey, exz), "desplaza": Vector3(hacia_centro.x, -Terreno3D.ALTO_NIVEL * (1.0 - ey) * 0.5, hacia_centro.y)}


## LÍQUIDO: agua en la simulación proporcional al volumen del elipsoide (`Sigils.volumen_agua_v2`, casillas³ × casilla³ = u³), repartido a partes iguales entre las casillas libres. Cada
## casilla echa su parte en T_LLENADO_V2 s y se apaga sola (fuente_en + limitar_fuente). Si la casilla ya tenía un manantial (un río, un surtidor) NO se
## pisa: ahí el agua se añade de golpe (anadir). El agua no se apila: los niveles no cuentan (el volumen ya los lleva), y H4 sigue: nada sobre tierra.
func _materia_liquido(ctx: Dictionary) -> int:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return 0
	var libres: Array = []
	for c in ctx["celdas"]:
		if not Lanzador3D.bloqueada(c as Vector2i) and Lanzador3D.altura_en(c as Vector2i) < 1:
			libres.append(c)
	if libres.is_empty():
		return 0
	var total: float = Sigils.volumen_agua_v2(ctx["g"]) * pow(Terreno3D.casilla, 3.0) * float(ctx.get("fraccion", 1.0))   # R3: copias y tandas reparten el volumen
	var parte: float = total / float(libres.size())
	# El agua entra en la simulación cuando la masa del VFX por estado ha caído (t_caida); la solidez, si hay, protege desde el principio.
	var echar: Callable = func() -> void:
		for c in libres:
			var cc: Vector2i = c
			if sim.caudal_en(cc) > 0.0 or sim.volumen_restante(cc) != INF:
				sim.anadir(Lanzador3D.centro_de(cc, Terreno3D.alto_agua), parte, Terreno3D.casilla * 0.5)
			else:
				sim.fuente_en(cc, parte / T_LLENADO_V2)
				sim.limitar_fuente(cc, parte)
	_despues(tiempo_caida(ctx["g"]), echar)
	_registrar_charco(libres, tiempo_caida(ctx["g"]))
	return libres.size()


## B5: el charco que deja un hechizo de agua, como zona de cruce (fuego por agua = vapor, rayo por agua = descarga). Una ZonaV2 sin pulso (no es zona de `_zonas_v2`: las pruebas y el limo cuentan esas)
## guardada en `Lanzador3D.zonas_cruce`; dura lo que tarda el agua en caer más `ZONA_AGUA_S`. El agua real sigue siendo la simulación; esto es solo para que otro hechizo sepa que hay agua DE HECHIZO aquí.
func _registrar_charco(celdas: Array, t_caida: float) -> void:
	var z := Lanzador3D.ZonaV2.new()
	z.lanz = lanz
	z.elemento = "agua"
	z.vida = t_caida + ZONA_AGUA_S
	for c in celdas:
		z.celdas[c] = true
	var l: Lanzador3D = lanz
	l.mundo.add_child(z)
	l.zonas_cruce.append(z)
	z.tree_exited.connect(HechizoVivo._olvidar.bind(weakref(l), z))


## PLASMA: una zona que hiere mientras dura (`persiste` s) y deja su estado de suelo (`deja`). Prende lo que arda: los reactivos (Reactivo3D) de
## sus casillas reciben el golpe del elemento UNA vez. Quien entra recibe el golpe entero; luego, un pulso de `dano_periodico` × `intervalo` cada `intervalo`.
func _materia_plasma(ctx: Dictionary) -> int:
	return _abrir_zona(ctx)


## ENERGÍA: una descarga instantánea sobre el volumen que además RECORRE el agua y los conductores conectados a él (la búsqueda de EmisorRayo3D).
## Golpea una vez a todo lo que esté en esas casillas (enemigos y reactivos: un tótem de rayo se activa).
func _materia_energia(ctx: Dictionary) -> int:
	var area: Dictionary = {}
	return _descarga(ctx, area)


## GAS: un campo de empuje durante `persiste` s; cada pulso empuja a quien esté dentro con `FUERZA_EMPUJE × empuje` por segundo.
func _materia_gas(ctx: Dictionary) -> int:
	return _abrir_zona(ctx)


## CAMPO: ralentiza durante `persiste` s lo que esté dentro (el `lento` de Combate3D).
func _materia_campo(ctx: Dictionary) -> int:
	return _abrir_zona(ctx)


## Abre la zona de un estado con pulsos (plasma, gas, campo): la vida es `persiste` y cada pulso llama al de PULSO_V2. Devuelve las casillas.
func _abrir_zona(ctx: Dictionary) -> int:
	var rune: RuneData = ctx["data"]
	var z := Lanzador3D.ZonaV2.new()
	z.lanz = lanz
	z.rune = rune
	z.elemento = String(ctx["elemento"])
	z.dir = ctx["dir"]
	z.origen = ctx["origen"]
	z.vida = maxf(_vida(ctx, 0.0), h.intervalo)
	z.intervalo = h.intervalo
	z.dano_periodico = h.dano_periodico
	z.metodo_pulso = String(PULSO_V2.get(String(ctx["estado"]), ""))
	z.tocados = ctx["tocados"]                              # compartido con el resto de tandas del hechizo: el golpe entero llega una vez
	for c in ctx["celdas"]:
		z.celdas[c] = true
		if rune.deja != "":
			_marcar(z.elemento, c as Vector2i)    # el estado de suelo (quemado…) se marca al nacer, una vez por casilla
	var l: Lanzador3D = lanz                               # el callback no puede capturar `self` (este nodo se borra al acabar sus eventos) ni el lanzador (puede morir antes que la zona)
	l.mundo.add_child(z)
	l._zonas_v2.append(z)
	z.tree_exited.connect(HechizoVivo._olvidar.bind(weakref(l), z))
	if bool(ctx.get("impacto", false)):
		# la zona nace al PARARSE el proyectil: quien ya recibió su golpe no cobra además el pulso periódico en el mismo instante (sí los siguientes, si sigue dentro)
		var dp: float = z.dano_periodico
		z.dano_periodico = 0.0
		z.pulso()
		z.dano_periodico = dp
	else:
		z.pulso()                                          # el primer pulso es al nacer
	return (ctx["celdas"] as Array).size()


## Saca una zona o una solidez de las listas del lanzador cuando sale del árbol. Por una referencia DÉBIL: una lambda que captura el lanzador da error en el motor si el lanzador muere antes
## (cambio de escena, pruebas) aunque la lambda compruebe `is_instance_valid`, porque el error salta al llamarla.
static func _olvidar(lanzador_ref: WeakRef, nodo: Node) -> void:
	var l: Variant = lanzador_ref.get_ref()
	if l != null:
		(l as Lanzador3D)._zonas_v2.erase(nodo)
		(l as Lanzador3D).zonas_cruce.erase(nodo)
		(l as Lanzador3D)._solideces_v2.erase(nodo)


## 3/11 (diario 347): lo que ya no está en juego para un hechizo: un enemigo muerto o un reactivo CONSUMIDO. El consumido sigue ~1 s en escena disolviéndose, ya sin capa de
## colisión (el rayo de `_golpes_areas` no lo ve), pero los golpes POR GRUPO lo contaban: una flecha que salía de la casilla de una telaraña recién quemada moría ahí sin hacer nada.
static func fuera_de_juego(obj: Object) -> bool:
	if not is_instance_valid(obj):
		return true
	if obj.get("muerto") == true:
		return true
	return obj is Reactivo3D and (obj as Reactivo3D).estado == Reactivo3D.EstadoObj.CONSUMIDO


## Los nodos de un grupo cuya casilla está en `celdas` (Dictionary Vector2i -> true). Lo muerto y lo consumido no cuentan (`fuera_de_juego`).
static func nodos_en(lanzador: Lanzador3D, grupo: String, celdas: Dictionary) -> Array:
	var r: Array = []
	for n in lanzador.get_tree().get_nodes_in_group(grupo):
		if is_instance_valid(n) and not fuera_de_juego(n) and celdas.has(Lanzador3D.celda_de((n as Node3D).global_position)):
			r.append(n)
	return r


## Lo que hace una zona en cada pulso: la ZonaV2 pide aquí el método de su estado (PULSO_V2).
static func pulsar(metodo: String, lanzador: Lanzador3D, z: Lanzador3D.ZonaV2) -> void:
	match metodo:
		"pulso_plasma":
			pulso_plasma(lanzador, z)
		"pulso_gas":
			pulso_gas(lanzador, z)
		"pulso_campo":
			pulso_campo(lanzador, z)


## PULSO DE PLASMA: el golpe entero a quien entra (los reactivos arden una vez); a los que siguen dentro, un trozo del daño.
static func pulso_plasma(lanzador: Lanzador3D, z: Lanzador3D.ZonaV2) -> void:
	var d: Vector3 = z.dir
	# 28/10 (Gruta Batida): también lo inflamable que no es Reactivo3D (la cuerda que sostiene un puente, un barril): la llama que nace encima lo prende.
	var objetos: Array = nodos_en(lanzador, "reactivo3d", z.celdas)
	for obj in nodos_en(lanzador, Reactivo3D.GRUPO_ARDE, z.celdas):
		if not objetos.has(obj) and obj.has_method("on_spell_hit"):
			objetos.append(obj)
	for obj in objetos:
		if z.tocados.has(obj.get_instance_id()):
			continue
		z.tocados[obj.get_instance_id()] = true
		lanzador._golpear(obj, z.rune, d, (obj as Node3D).global_position, 0, false, z.origen)
	for e in nodos_en(lanzador, "combate3d", z.celdas):
		if not is_instance_valid(e) or bool(e.get("muerto")):
			continue
		if z.tocados.has(e.get_instance_id()):
			# El impacto que el escudo paró deja su zona, y sus pulsos entran por aquí directos a `receive_damage` (no por `on_spell_hit`): sin esta
			# consulta el escudo ardiendo no protegía de su propio campo de llamas (el goblin perdía 10 cada 0,25 s). Si el escudo cubre de frente, no hay daño.
			if e.has_method("escudo_cubre") and bool(e.call("escudo_cubre", d)):
				continue
			# E1 (28/10): el limo teñido de ESTE elemento no se quema en su propia llama (si ya es grande, le cura).
			if e.has_method("absorbe_pulso") and bool(e.call("absorbe_pulso", z.elemento, z.dano_periodico * z.intervalo)):
				continue
			var r_pulso: float = float(e.call("multiplicador", z.elemento)) if e.has_method("multiplicador") else 1.0       # 29/10 (DANO_Y_TINTA): el daño continuo pasa por R, no por la defensa
			e.call("receive_damage", Dano.continuo(z.dano_periodico * z.intervalo, r_pulso))
		else:
			z.tocados[e.get_instance_id()] = true
			lanzador._golpear(e, z.rune, d, (e as Node3D).global_position, 0, false, z.origen)
	if z.dano_periodico > 0.0:
		var quitado: float = golpe_propio(lanzador, z.celdas, z.elemento, z.edad, not z.avisada_jugadora)
		if quitado > 0.0:
			z.avisada_jugadora = true


## B7: el daño de una zona o descarga de TU hechizo sobre ti, si estás dentro de sus `celdas` y ya pasó la gracia (`edad_s` desde que lanzaste). Va por `Jugador3D.dano_ambiental` (invulnerabilidad,
## defensa, viñeta, HUD; sin empujón ni hitstop). `con_rotulo`: el «¡Te quemas!» solo sale la primera vez por zona. Devuelve lo que te quitó (0 si nada).
static func golpe_propio(lanzador: Lanzador3D, celdas: Dictionary, elemento: String, edad_s: float, con_rotulo: bool = true) -> float:
	if not FUEGO_AMIGO or edad_s < GRACIA_PROPIA_S or lanzador == null or not is_instance_valid(lanzador):
		return 0.0
	var j: Node3D = lanzador.jugador
	if j == null or not is_instance_valid(j) or not j.has_method("dano_ambiental") or not celdas.has(Lanzador3D.celda_de(j.global_position)):
		return 0.0
	var quitado: float = float(j.call("dano_ambiental", DANO_PROPIO_POR_TIC, elemento))
	if quitado > 0.0 and con_rotulo:
		Combate3D.flotante(lanzador.mundo, j.global_position + Vector3(0.0, 2.1, 0.0), "¡Te quemas!" if elemento == "fuego" else "¡Te hiere tu hechizo!", Combate3D.COLORES.get(elemento, Color(1.0, 0.5, 0.2)), 0.9)
	return quitado


## PULSO DE GAS: empuja con `empuje` (0-1) × FUERZA_EMPUJE por segundo, en la dirección de la mirada. Los reactivos (no los enemigos: ya se empujan
## aquí) reciben el golpe del elemento una vez.
static func pulso_gas(lanzador: Lanzador3D, z: Lanzador3D.ZonaV2) -> void:
	var sopla: bool = Materia.sopla(Materia.de(z.rune))
	for e in nodos_en(lanzador, "combate3d", z.celdas):
		if e.has_method("push"):
			e.call("push", z.dir, Lanzador3D.FUERZA_EMPUJE * z.rune.empuje * z.intervalo)
			if sopla:
				VfxToyJuego.aura_viento(e, maxf(0.65, z.intervalo + 0.22))
	for obj in nodos_en(lanzador, "reactivo3d", z.celdas):
		if z.tocados.has(obj.get_instance_id()):
			continue
		z.tocados[obj.get_instance_id()] = true
		lanzador._golpear(obj, z.rune, z.dir, (obj as Node3D).global_position, 0, false, z.origen)


## PULSO DE CAMPO: ralentiza (el `lento` de Combate3D dura un poco más que el pulso, así no parpadea entre uno y otro).
static func pulso_campo(lanzador: Lanzador3D, z: Lanzador3D.ZonaV2) -> void:
	for e in nodos_en(lanzador, "combate3d", z.celdas):
		e.set("lento", maxf(float(e.get("lento")), z.intervalo * 2.0))


## DESCARGA: las casillas del volumen + el agua y los conductores conectados a ellas (la búsqueda de EmisorRayo3D, por las 4 vecinas). Un
## golpe a cada enemigo y reactivo que esté dentro. Instantánea: lo único que queda es el aviso al VFX (`hechizo_v2`) y el estado de suelo si lo hay.
func _descarga(ctx: Dictionary, area: Dictionary) -> int:
	var rune: RuneData = ctx["data"]
	var conduce := func(c: Vector2i) -> bool: return Lanzador3D.en_mapa(c) and Terreno3D.conduce(c)
	for c in ctx["celdas"]:
		area[c] = true
	var vistas: Dictionary = {}
	# C2 (3/11): la descarga de un rayo deja `electrificada` (2 s, `EstadosSuelo3D.DURA`) en el agua y los conductores que recorre. En seco solo se anota (no escribe estados). No cambia el daño ni la búsqueda.
	var electrifica: bool = not seco and String(ctx["elemento"]) == "rayo"
	var nodos: int = 0                                    # R3: casillas añadidas por conexión, fuera del volumen (ver MAX_NODOS_DESCARGA)
	for c in ctx["celdas"]:
		if vistas.has(c):
			continue
		for w in EmisorRayo3D.agua_conectada(c as Vector2i, conduce):
			if not area.has(w):
				if nodos >= MAX_NODOS_DESCARGA:
					break
				nodos += 1
			area[w] = true
			vistas[w] = true
			if electrifica:
				Terreno3D.estados.mantener(w as Vector2i, EstadosSuelo3D.ELECTRIFICADA)
	var d: Vector3 = ctx["dir"]
	var tocados: Dictionary = ctx["tocados"]
	for grupo in ["reactivo3d", "combate3d"]:
		for obj in nodos_en(lanz, grupo, area):
			if tocados.has(obj.get_instance_id()):
				continue
			tocados[obj.get_instance_id()] = true
			_golpear(obj, d, (obj as Node3D).global_position, ctx["origen"])
	if not seco and String(ctx["elemento"]) == "rayo":
		# B7: si pisas el agua o el conductor que recorre tu propia descarga, te llega (una vez: la descarga es instantánea)
		golpe_propio(lanz, area, "rayo", float(Time.get_ticks_msec() - _t_creado_ms) / 1000.0)
	if rune.deja != "":
		for c in ctx["celdas"]:
			_marcar(String(ctx["elemento"]), c as Vector2i)
	return (ctx["celdas"] as Array).size()


## 6. SOLIDEZ por encima de cualquier estado: las casillas de la tanda bloquean proyectiles y aguantan golpes (también el agua o el gas).
func _solidez(ctx: Dictionary, solidez: float, refleja: bool) -> Lanzador3D.SolidezV2:
	var s := Lanzador3D.SolidezV2.new()
	s.celdas = {}
	for c in ctx["celdas"]:
		s.celdas[c] = true
	s.niveles = int(ctx["niveles"])
	s.vida = maxf(_vida(ctx, 0.0), VIDA_MIN_SOLIDEZ_V2)
	s.aguante = h.resistencia
	s.refleja = refleja
	s.elemento = String(ctx["elemento"])
	if s.elemento == "viento" and maxf(h.semieje_x, h.semieje_z) >= 2.0 * minf(h.semieje_x, h.semieje_z) - 0.0001:
		var direccion: Vector3 = ctx.get("dir", Vector3.ZERO)
		if h.semieje_z > h.semieje_x:
			direccion = Vector3(-direccion.z, 0.0, direccion.x)
		s.normal_flecha = Vector3(direccion.x, 0.0, direccion.z).normalized()
	s.linaje = linaje                                       # de quién es: los proyectiles de este mismo lanzamiento no chocan con ella (ver `_avanzar`)
	var l: Lanzador3D = lanz                               # (ver _abrir_zona: el callback sobrevive a este nodo)
	# C2: «barrera + pulso» (`Hechizo.late`): la barrera nace entera y late (se retrae y vuelve) al ritmo del pulso de la zona; sin `intervalo` propio, `INTERVALO_LATIDO`.
	s.late = h.late
	s.periodo_late = h.intervalo if h.intervalo > 0.0 else INTERVALO_LATIDO
	l.mundo.add_child(s)
	l._solideces_v2.append(s)
	s.tree_exited.connect(HechizoVivo._olvidar.bind(weakref(l), s))
	return s


## 3/11/2026 · R1 (decisión de Pablo: «la solidez debe acompañar al volumen mientras se mueve»): el volumen sólido que viaja lleva UNA SolidezV2 por copia que ocupa, en cada paso de su ruta, justo las casillas donde está
## (`ctx["ocupa"]`): las casillas que deja se liberan y las nuevas bloquean. Vive hasta su último paso (`ctx["fin"]`) más la `permanencia` (o `COLA_SOLIDEZ_S`). Si la rompen a golpes (`aguante`) no se rehace.
## «Si es razonable se empuja»: lo que ya había en una casilla que el muro ocupa por primera vez (enemigos, que tienen `push`) sale arrastrado en la dirección del paso, con `EMPUJE_MURO_K` de la fuerza del viento.
func _solidez_sigue(ctx: Dictionary, solidez: float, refleja: bool) -> void:
	var copia: int = int(ctx.get("copia", 0))
	var ocupa: Array = ctx["ocupa"]
	# Tras su último paso: si vuelve (ᛃ) se deshace en cuanto llega (COLA_SOLIDEZ_S); si no, SE PLANTA donde llega como la barrera de ᛜ + ᛇ de siempre (§0.3): persiste + permanencia, mínimo VIDA_MIN_SOLIDEZ_V2
	var cola: float = COLA_SOLIDEZ_S if h.retorna else maxf(h.persiste + h.permanencia, VIDA_MIN_SOLIDEZ_V2)
	var vida: float = maxf(float(ctx["fin"]) - float(ctx["t_ev"]), 0.0) + cola
	var reg: Dictionary = _solideces_sigue.get(copia, {})
	var s: Lanzador3D.SolidezV2 = reg.get("nodo") as Lanzador3D.SolidezV2 if reg.has("nodo") and is_instance_valid(reg.get("nodo")) else null
	var antes: Dictionary = {}
	if s == null:
		if reg.has("nodo"):
			return                                          # la rompieron a golpes a mitad de camino: no se rehace
		s = _solidez({"data": ctx["data"], "elemento": ctx["elemento"], "niveles": ctx["niveles"],
			"celdas": ocupa, "vida": vida, "dir": ctx["dir"]}, solidez, refleja)
		_solideces_sigue[copia] = {"nodo": s}
	else:
		antes = s.celdas
	var nuevas: Dictionary = {}
	s.celdas = {}
	for c in ocupa:
		s.celdas[c] = true
		if not antes.has(c):
			nuevas[c] = true
	s.vida = vida
	var mueve: Vector3 = ctx.get("mueve", Vector3.ZERO)
	if mueve.length() > 0.01 and not nuevas.is_empty():
		for obj in nodos_en(lanz, "combate3d", nuevas):
			if obj.has_method("push"):
				obj.call("push", mueve.normalized(), Lanzador3D.FUERZA_EMPUJE * EMPUJE_MURO_K)


## =====================================================================================================
##  HC4: golpe con eventos, proyectil y catálogo de acciones
## =====================================================================================================

## El golpe del hechizo a un objeto: lo da el lanzador (con ESTE Hechizo, así un enemigo recibe sus campos) y después saltan `al_golpear` y, si lo mata, `al_matar`.
func _golpear(obj: Node, dir: Vector3, punto: Vector3, desde: Vector3) -> void:
	if seco:
		(prevision["golpes"] as Array).append({"obj": obj, "dir": dir, "punto": punto, "desde": desde})
		return
	lanz._golpear(obj, data, dir, punto, 0, false, desde, h)
	if not _juice_impacto and obj is Combate3D:
		_juice_impacto = true
		Sensacion3D.juice_hechizo(h.nivel_potencia, true, lanz)        # E1 (6/11): temblor e hitstop del impacto según su potencia, solo al dar a un enemigo
	_tras_golpe(obj, punto, dir)


## 28/10 · A2: marcar el suelo de una casilla con el estado de un elemento (`Lanzador3D.marcar_celda`); en seco solo se anota.
func _marcar(elemento_: String, c: Vector2i) -> void:
	if seco:
		(prevision["suelo"] as Array).append({"elemento": elemento_, "celda": c})
		return
	lanz.marcar_celda(elemento_, c)


## 28/10 · A2: lo que haría la MATERIA del hechizo en una tanda de casillas, en seco: la energía descarga (agua y conductores incluidos); la zona de plasma golpea a quien esté dentro en su primer pulso;
## la de gas, solo a los reactivos (el empuje a los enemigos no es un golpe); y todo lo que deja un estado de suelo (`deja`) lo marca, salvo el líquido (que no marca casillas: echa agua a la simulación).
## No levanta tierra, no echa agua a la simulación, no crea zonas ni solideces.
func _materia_seca(ctx: Dictionary) -> int:
	var rune: RuneData = ctx["data"]
	match String(ctx["estado"]):
		"energia":
			return _descarga(ctx, {})                       # ya marca `deja` y golpea
		"plasma":
			_contacto(ctx)
		"gas":
			_contacto(ctx, ["reactivo3d"])
		"liquido":
			return (ctx["celdas"] as Array).size()         # el agua no marca casillas: va a la simulación del agua (`_materia_liquido`), que aquí no se corre
	if rune != null and rune.deja != "":
		for c in ctx["celdas"]:
			_marcar(String(ctx["elemento"]), c as Vector2i)
	return (ctx["celdas"] as Array).size()


func _tras_golpe(obj: Node, punto: Vector3, dir: Vector3) -> void:
	if h.efecto_impacto != "":
		lanz.vfx_hechizo.emit(h.efecto_impacto, punto, elemento)
	disparar_evento("al_golpear", punto, dir, {"obj": obj})
	if is_instance_valid(obj) and obj.get("muerto") == true:
		disparar_evento("al_matar", punto, dir, {"obj": obj})


## Dispara un evento del Hechizo: sus acciones, en el orden fijo de `Hechizo.ordenar_acciones` (paso y orden de tabla del glifo que las puso; las que no vienen de un glifo,
## paso 1 y orden 0, van primero y entre sí en el orden de la lista). `radio_explosion` > 0 añade DESPUÉS de todas a `al_golpear` una explosión de ese radio con el daño del hechizo.
func disparar_evento(nombre: String, pos: Vector3, dir: Vector3, extra: Dictionary = {}) -> void:
	var acciones: Array = _ordenadas(h.eventos.get(nombre, []) as Array)
	if nombre == "al_golpear" and h.radio_explosion > 0.0:
		acciones.append({"accion": "danar_area", "radio": h.radio_explosion, "dano": h.dano})
	if acciones.is_empty():
		return
	eventos_vistos.append(nombre)
	for a in acciones:
		_accion(a as Dictionary, pos, dir, extra)


## Copia de una lista de acciones de un evento en el orden fijo. Una acción sin `paso` ni `orden` (la que se escribió a mano o la puso el laboratorio) vale `Sigils.PASO_DEFECTO` y orden 0.
func _ordenadas(lista: Array) -> Array:
	var r: Array = []
	for i in range(lista.size()):
		var a: Dictionary = (lista[i] as Dictionary).duplicate()
		a["paso"] = int(a.get("paso", Sigils.PASO_DEFECTO))
		a["orden"] = int(a.get("orden", 0))
		a["i"] = i
		r.append(a)
	return Hechizo.ordenar_acciones(r)


## El FINAL de un tramo: salta UNO de los tres eventos (`Hechizo.EVENTOS_FINAL`) y, antes que él, el momento «final» de los glifos con las casillas dadas (vacías = sin momento).
## `causa` = `motivo_fin` del proyectil, o «extincion» si acaba la vida de lo que nace quieto. Un segundo final del mismo hechizo se ignora (`_final_hecho`).
func _disparar_final(evento: String, causa: String, pos: Vector3, dir: Vector3, celdas: Array) -> void:
	if _final_hecho:
		return
	_final_hecho = true
	finales_vistos.append(evento)
	if h.profundidad == 0 and not celdas.is_empty() and not h.acciones_en_fin(causa).is_empty():
		_momento(Sigils.MOMENTO_FINAL, celdas, causa)
	disparar_evento(evento, pos, dir, {"causa": causa})      # C3: la causa viaja con el final (el hijo de «al impactar» no nace al recoger un proyectil que vuelve)


## ᛃ sin flecha (31/10): el ECO. El mismo `Hechizo` vuelve a golpear donde impactó: su materia (`_aplicar_materia_en_el_sitio`) y su daño en el área que ocupa (`_danar_area`).
## Al lanzador solo le hiere `golpea_lanzador`, como siempre.
func _eco_de_retorno(origen: Vector3, dir: Vector3) -> void:
	if lanz == null or not lanz.is_inside_tree():
		return
	ecos_de_retorno += 1
	if h.haz:
		_materializar_haz(origen, dir)          # el haz golpea en TODO su recorrido: el eco es otro haz igual (dibujo, sonido, estados y un golpe a cada uno)
		return
	_aplicar_materia_en_el_sitio(origen, dir)
	_danar_area(maxf(maxf(float(g.get("x", 0.0)), float(g.get("z", 0.0))), 0.5), h.dano, origen, dir)


## Lo que NACE QUIETO se extingue al acabar su vida (`persiste` + `permanencia`, o lo que dura el haz o el viaje del volumen): ahí saltan `al_expirar` y el momento «final» de los glifos
## (los de momento «final» o «extincion»), con las casillas del volumen. Un proyectil no pasa por aquí: su final lo dispara `_terminar`.
func _programar_extincion(origen: Vector3, dir: Vector3) -> void:
	if proyectil:
		return
	if h.estalla and h.profundidad == 0 and not seco:
		# 3/11 · R5 (decisión de Pablo: «ᚷ + agua = explosión»): el volumen líquido que ha crecido ESTALLA al acabar su vida (lo que dibuja `AguaToy.area_al_impactar`): daño en área de su tamaño final
		_despues(h.retardo + _t_estallido(), func() -> void: _estallar(dir))
	if h.retorna and not h.viaja and not h.orbita and h.profundidad == 0 and not seco:
		# 31/10 (REV 01, ᛃ sin flecha): al acabar (el haz es instantáneo: al nacer; el volumen quieto, al expirar) y RETORNO_ECO_S después, el impacto se repite en su sitio (`_eco_de_retorno`)
		# 3/11 (R2/R3): lo que viaja ya VUELVE (`eventos_de`) y lo que orbita ya da vueltas (`_materializar_orbita`): el eco es solo para el ᛃ sin camino ni copias
		var hasta_r: float = 0.0 if h.haz else maxf(h.persiste, 0.0) + h.permanencia
		_despues(maxf(hasta_r, 0.0) + RETORNO_ECO_S, func() -> void: _eco_de_retorno(origen, dir))
	var momento: bool = h.profundidad == 0 and not h.glifos.is_empty() and not h.acciones_en_fin("extincion").is_empty()
	if not momento and not h.eventos.has("al_expirar"):
		return
	# §0.3: lo que viaja expira al llegar + `permanencia`; lo que nace quieto, a `persiste` + `permanencia`
	var hasta: float = (Hechizo.HAZ_DURA_S if h.haz else (_t_viaje if h.viaja else maxf(h.persiste, 0.0))) + h.permanencia
	if h.orbita:
		hasta = _vida_orbita                              # 3/11 (R3): los orbes viven lo que dura la órbita
	_despues(maxf(hasta, 0.0), func() -> void: _disparar_final("al_expirar", "extincion", origen, dir, _celdas_del_momento(origen) if momento else []))


## =====================================================================================================
##  MOMENTO DE EJECUCIÓN (23/10, Pulso resonante fase 2; PLAN_PULSO_RESONANTE §10 bis, GLIFOS_RECETA §2.4 bis)
## =====================================================================================================
## Los glifos con `accion` (hoy ᚱ) hacen algo en el punto de la vida del hechizo que dice su dato `momento` (resuelto con `Hechizo.momento_de`):
##   inicio    al nacer el volumen (`crear`), una vez
##   continuo  mientras vive, cada `Sigils.PERIODO_MIN_CONTINUO_S` (o su `intervalo`, si es mayor), con tope `Sigils.MAX_DISPAROS_CONTINUOS`; el primero, al nacer
##   final     al acabarse: un proyectil, al pararse (alcance, choque, suelo, golpe); lo que nace quieto, al acabar su vida (persiste + permanencia, o el tiempo del haz).
##             H2 (29/10): el final son TRES eventos (`al_impactar`: lo paró un golpe · `al_detenerse`: se paró sin golpear · `al_expirar`: se extingue lo que nace quieto) y un hechizo dispara UNO por
##             tramo (`_disparar_final`). Un glifo con `momento` «final» actúa en los tres; con «impacto», «detencion» o «extincion», solo en el suyo (`Hechizo.acciones_en_fin`).
##             En la ida y vuelta de `retorna` solo cuenta el final de la VUELTA: al acabar la ida el proyectil da la vuelta (`_fin_de_ida`) y no dispara nada; el de la vuelta (motivo «retorno» al recogerse,
##             o el que sea si choca) es el único, sin momento «final» si es «retorno» (el pulso no sale al volver a la mano).
## UN SOLO DESPACHADOR Y UN SOLO CATÁLOGO: `_momento` no tiene catálogo propio, llama a `_accion` con {accion, celdas} y `Hechizo.ACCIONES` (que incluye `emitir_pulso`) es el único. Un solo orden:
## las acciones de un momento salen en el de `Hechizo.acciones_en` / `acciones_en_fin` (el `paso` de cada glifo y la tabla), y las de un evento en el de `Hechizo.ordenar_acciones` (`_ordenadas`), no en el de dibujo.
## SIN REENTRADAS: «inicio» y «final» disparan una vez por hechizo, y mientras corren las acciones de un momento (`_en_momento`) ningún otro momento de este hechizo puede dispararse. Un hijo (`crear_hijo`)
## no repite los efectos de su padre. Los demás glifos (flecha, barrera, repetición, rebote, crecer, permanencia) no tienen `accion`: su `momento` describe lo que ya hacen dentro del ciclo de vida.


## Programa los momentos «inicio», «continuo» y «final» de un hechizo que acaba de nacer (el «final» no: lo dispara `_terminar` en un proyectil y `_programar_extincion` en lo que nace quieto).
func _arrancar_momentos(origen: Vector3, dir: Vector3) -> void:
	if h.profundidad > 0 or h.glifos.is_empty():
		return
	var celdas: Array = _celdas_del_momento(origen)
	if not h.acciones_en(Sigils.MOMENTO_INICIO).is_empty():
		_momento(Sigils.MOMENTO_INICIO, celdas)
	var continuas: Array = h.acciones_en(Sigils.MOMENTO_CONTINUO)
	if not continuas.is_empty():
		var vida: float = _vida_continua()
		var periodo: float = maxf(h.intervalo, Sigils.PERIODO_MIN_CONTINUO_S)
		var n: int = mini(1 + int(floorf(vida / periodo)), Sigils.MAX_DISPAROS_CONTINUOS)
		for k in range(n):
			if k == 0:
				_momento(Sigils.MOMENTO_CONTINUO, celdas)
			else:
				_despues(float(k) * periodo, func() -> void: _momento(Sigils.MOMENTO_CONTINUO, _celdas_del_momento(origen)))


## ᚱ con una materia SÓLIDA (hielo, tierra) y el volumen bajo los pies de quien lanza (24/10, fase 3): el bloque no se puede levantar donde está la jugadora (`casillas` = 0), pero el glifo no
## tiene por qué quedarse mudo: el pulso sale UNA vez desde esas casillas, sea cual sea su momento (el periodo del continuo no tiene sentido sin un volumen que dure). Sin esto, ᚱ + hielo
## no hacía nada si no se le añadía una flecha, y las estatuas de C1 (que piden hielo) no se podían hacer con el glifo solo.
func _pulso_sin_volumen(origen: Vector3) -> void:
	var celdas: Array = _celdas_del_momento(origen)
	for momento in [Sigils.MOMENTO_INICIO, Sigils.MOMENTO_CONTINUO, Sigils.MOMENTO_FINAL]:
		if not _acciones_del(momento, "extincion").is_empty():
			_momento(momento, celdas)
			return


## Cuánto vive lo que nace quieto (s) para los disparos continuos: su `persiste` + `permanencia` (con el suelo de la solidez), sin pasar del límite global. Un proyectil vive lo que viaje.
func _vida_continua() -> float:
	var v: float = h.persiste + h.permanencia
	if h.solidez > 0.0:
		v = maxf(v, VIDA_MIN_SOLIDEZ_V2)
	if proyectil:
		v = maxf(_max_recorrido / maxf(h.velocidad * Terreno3D.casilla, 0.001), 0.0)
	return clampf(v, 0.0, Hechizo.LIM_VIDA_S)


## Las casillas de las que sale un efecto de momento: las del volumen que nació; un proyectil, las que ocupa donde está; sin ninguna, la del origen.
func _celdas_del_momento(origen: Vector3) -> Array:
	if proyectil:
		return _celdas_en(p, v.normalized() if v.length() > 0.001 else Vector3.RIGHT)
	if not _celdas_volumen.is_empty():
		return _celdas_volumen
	return [Terreno3D.celda_de(origen)]


## Las acciones de glifo de un momento: «final» incluye las del momento fino de `causa` (`Hechizo.acciones_en_fin`).
func _acciones_del(momento: String, causa: String) -> Array:
	return h.acciones_en_fin(causa) if momento == Sigils.MOMENTO_FINAL else h.acciones_en(momento)


## Dispara las acciones de un momento (ver arriba) por el despachador único `_accion`. Devuelve cuántas hizo. `causa` solo importa en «final» (por defecto, la extinción).
func _momento(momento: String, celdas: Array, causa: String = "extincion") -> int:
	if _en_momento or h.profundidad > 0:
		return 0
	if momento != Sigils.MOMENTO_CONTINUO:
		if _momento_hecho.has(momento):
			return 0
		_momento_hecho[momento] = true
	var hechas: int = 0
	_en_momento = true
	for a in _acciones_del(momento, causa):
		if not Hechizo.ACCIONES.has(String(a["accion"])):
			continue                                          # los datos nunca rompen el juego
		if _accion({"accion": String(a["accion"])}, p, Vector3.RIGHT, {"celdas": celdas}):
			hechas += 1
		momentos_vistos.append({"momento": momento, "glifo": String(a["glifo"]), "accion": String(a["accion"]), "t": reloj_vida})
	_en_momento = false
	return hechas


## ᚱ: suelta un Pulso3D desde las casillas dadas, con el elemento de la receta (sin elemento, el azul claro del base) y `resuena` casillas de alcance. Es del jugador.
func _soltar_pulso(celdas: Array) -> bool:
	var alcance: int = int(roundf(h.resuena))
	if alcance <= 0 or celdas.is_empty() or lanz == null or not lanz.is_inside_tree():
		return false
	var cont: Node = lanz.mundo if lanz.mundo != null else lanz
	pulsos_soltados.append(Pulso3D.emitir(cont, celdas, elemento, alcance, null, Callable(), true))
	return true


## El despachador único y el catálogo cerrado de acciones (`Hechizo.ACCIONES`), para los eventos y para los momentos de los glifos. Una acción que no está en él se ignora: los datos nunca rompen el juego.
## Devuelve si hizo algo (solo `emitir_pulso` puede no hacerlo: sin alcance, sin casillas o sin mundo).
func _accion(a: Dictionary, pos: Vector3, dir: Vector3, extra: Dictionary) -> bool:
	match String(a.get("accion", "")):
		"danar_area":
			_danar_area(float(a.get("radio", 1.0)), float(a.get("dano", h.dano)), pos, dir)
		"crear_hijo":
			_crear_hijo(a, pos, dir, extra)
		"estado_suelo":
			_estado_suelo(String(a.get("estado", elemento)), float(a.get("radio", 0.0)), pos)
		"sonido":
			lanz._sonar_fase_v2(String(a.get("nombre", "impacto")), elemento, "", pos)
		"vfx":
			lanz.vfx_hechizo.emit(String(a.get("nombre", "")), pos, elemento)
		"emitir_pulso":
			return _soltar_pulso(extra["celdas"] as Array if extra.has("celdas") else _celdas_del_momento(pos))
		_:
			return false
	return true


## Daño en área: a cada enemigo y reactivo a menos de `radio` casillas de `pos` le llega el golpe del elemento con ese `dano` (estados y empuje radial incluidos);
## al lanzador, solo si `golpea_lanzador`.
func _danar_area(radio: float, dano: float, pos: Vector3, dir: Vector3) -> void:
	var alcance: float = radio * Terreno3D.casilla
	var hd: Hechizo = h.copiar()
	hd.dano = dano
	hd.eventos = {}
	for grupo in ["combate3d", "reactivo3d"]:
		for obj in lanz.get_tree().get_nodes_in_group(grupo):
			if fuera_de_juego(obj):
				continue
			var c: Vector3 = (obj as Node3D).global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0)
			var plano: Vector3 = c - pos
			plano.y = 0.0
			if plano.length() > alcance + RADIO_ENEMIGO_U or absf(c.y - pos.y) > alcance + VENTANA_Y_U + RADIO_ENEMIGO_U:
				continue
			var radial: Vector3 = plano.normalized() if plano.length() > 0.01 else dir
			lanz._golpear(obj, data, radial, (obj as Node3D).global_position, 0, false, pos, hd)
	if h.golpea_lanzador and lanz.jugador != null and is_instance_valid(lanz.jugador) and lanz.jugador.has_method("recibir_dano"):
		var al_j: Vector3 = lanz.jugador.global_position - pos
		al_j.y = 0.0
		if al_j.length() <= alcance + RADIO_ENEMIGO_U:
			lanz.jugador.call("recibir_dano", dano, pos)
			if elemento == "viento":
				VfxToyJuego.aura_viento(lanz.jugador, 0.85)


## Hijos: `cuantos` copias del hechizo (con `cambios` encima y SIN eventos, salvo que los traigan en «eventos»), repartidas en un abanico de `abanico` grados
## alrededor de la dirección. Profundidad ≤ Hechizo.MAX_PROFUNDIDAD y ≤ Hechizo.MAX_VIVOS vivos por lanzamiento. No repiten el golpe del padre.
func _crear_hijo(a: Dictionary, pos: Vector3, dir: Vector3, extra: Dictionary) -> void:
	if h.profundidad >= Hechizo.MAX_PROFUNDIDAD:
		return
	if (a.get("salvo", []) as Array).has(String(extra.get("causa", ""))):
		return                                         # C3: «salvo» = causas de fin con las que este hijo NO nace (retorno: el proyectil vuelve a la mano)
	var cuantos: int = maxi(int(a.get("cuantos", 1)), 1)
	var abanico: float = float(a.get("abanico", 0.0))
	var ya: Dictionary = golpeados.duplicate()
	if extra.has("obj") and is_instance_valid(extra["obj"]):
		ya[(extra["obj"] as Object).get_instance_id()] = true
	var d0: Vector3 = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	for i in range(cuantos):
		if linaje.vivos >= Hechizo.MAX_VIVOS:
			break
		var hijo: Hechizo = _hijo_de_pagina(a) if a.has("glifos_hijo") else h.copiar()
		if hijo == null:
			continue
		if not a.has("glifos_hijo"):
			hijo.eventos = {}
		hijo.profundidad = h.profundidad + 1
		if not a.has("glifos_hijo"):
			hijo.con(a.get("cambios", {}) as Dictionary)
		var grados: float = 0.0 if cuantos == 1 else lerpf(-abanico * 0.5, abanico * 0.5, float(i) / float(cuantos - 1))
		var d: Vector3 = d0.rotated(Vector3.UP, deg_to_rad(grados))
		HechizoVivo.crear(hijo, pos + d * DESPLAZA_HIJO_U, d, lanz, linaje, ya, manual)


## C3 (6/11/2026) · el hijo del glifo «al impactar» (⧖ `retardo` entre dos formas; ver `Hechizo.DISPARADOR`): NO es una copia del padre con cambios, es la SIGUIENTE forma de la página, construida desde sus glifos (`glifos_hijo`, con su
## orden de dibujo) y con el elemento del padre: la flecha + ⧖ + barrera deja una BARRERA, no una flecha gruesa. Hereda del padre la potencia (sobrecarga) y la proporción del pigmento de daño (el
## `dano *= mult_dano` del lanzador se aplica después de construir; sin esto el hijo saldría sin pigmento). Su coste de tinta no se cobra aparte: lo paga el padre con `Dano.K_HIJO`.
func _hijo_de_pagina(a: Dictionary) -> Hechizo:
	var hijo: Hechizo = Hechizo.construir(h.fuente, a["glifos_hijo"] as Dictionary, h.calidad, false, a.get("orden_hijo", []) as Array)
	if hijo == null:
		return null
	hijo.potencia = h.potencia
	if Dano.tiene_tabla(h.elemento):
		var base: float = Dano.base_elemental(h._contar_glifos_dano(), h.elemento)
		if base > 0.0:
			hijo.dano *= h.dano / base
	return hijo


## Marca el suelo con el estado de un elemento en un círculo de `radio` casillas (0 = solo la casilla de `pos`).
func _estado_suelo(estado_: String, radio: float, pos: Vector3) -> void:
	var c0: Vector2i = Terreno3D.celda_de(pos)
	var r: int = int(ceilf(radio))
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if Vector2(dx, dy).length() <= radio + 0.001:
				_marcar(estado_, c0 + Vector2i(dx, dy))


## ---------------------------------------------------------------------------------------------------
##  El proyectil
## ---------------------------------------------------------------------------------------------------

## `desvio` (u): cuánto se aparta de la mano esta copia del abanico (ver `salida_de_copia`); cero para un proyectil solo.
func _iniciar_proyectil(origen: Vector3, dir: Vector3, desvio: Vector3 = Vector3.ZERO) -> int:
	proyectil = true
	activo = true
	# Sale a `altura_salida` sobre el suelo de su casilla (el origen que llega es el de los pies del jugador: sin esto, un proyectil con gravedad nace ya en el suelo).
	var c0: Vector2i = Terreno3D.celda_de(origen)
	p = Vector3(origen.x, (Terreno3D.y_pies(c0) if Terreno3D.en_mapa(c0) else origen.y) + (h.altura_salida + h.elevacion) * Terreno3D.casilla, origen.z)
	# 24/10: sale de la mano de la jugadora (Lanzador3D._salida_de_mano), no del centro de sus pies. Un hechizo `en_punto` NO: nace donde apunta (ESPEC §1.2) y sumarle el desplazamiento de
	# la mano lo sacaba de la mano en vez del punto (auditoría D-5, «barrera + flecha»).
	if lanz != null and not h.en_punto and lanz.get("desplaza_mano") is Vector3:
		p += lanz.get("desplaza_mano") as Vector3
	p += desvio
	var d: Vector3 = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	v = d * h.velocidad * Terreno3D.casilla                    # el Hechizo habla en m/s; aquí se pasa a u/s (ESPEC §0.1)
	if h.gravedad > 0.0 and h.impulso_salida > 0.0:
		v.y += h.impulso_salida * Terreno3D.casilla               # sale en arco (el agua): sin gravedad no se aplica, o subiría para siempre
	_max_recorrido = (h.distancia_max if h.distancia_max > 0.0 else Hechizo.LIM_DISTANCIA) * Terreno3D.casilla     # sin alcance, el tope de seguridad: nada vuela para siempre
	_radio_pleno_u = maxf(h.semiejes_vuelo.x, h.semiejes_vuelo.z) * Terreno3D.casilla       # con qué radio acierta EN VUELO (Hechizo.ESCALA_PROYECTIL); la explosión y las zonas no lo usan
	_radio_u = _radio_pleno_u
	if h.crece > 0.0:
		# 24/10 (D-7): `crece` es m/s de radio. El proyectil nace a `escala_nace` de su radio y crece en vuelo; el VFX y el golpe leen `_radio_u`, que sube cada paso (ver `paso`).
		_radio_u = _radio_pleno_u * h.escala_nace
		_crece_u = h.crece * Terreno3D.casilla
		tiempo_crecimiento = tiempo_de_crecer(h.crece, h.escala_nace, _radio_pleno_u / Terreno3D.casilla)
	_viaja_sig = []
	for a in (h.eventos.get("al_viajar", []) as Array):
		_viaja_sig.append(maxf(float((a as Dictionary).get("cada", 1.0)), 0.1) * Terreno3D.casilla)
	if is_inside_tree():
		global_position = p
	if seco:
		return 1                                       # la previsión no espera: simula desde que arranca
	if h.retardo > 0.0 and h.profundidad == 0:
		espera = h.retardo                             # H5: nace quieto en el origen y arranca a los `retardo` s (un hijo no repite la espera de su padre)
	lanz._sonar_fase_v2("impacto", elemento, String(g.get("nombre", "")), origen)
	if h.estela != "":
		lanz.vfx_hechizo.emit(h.estela, p, elemento)
	return 1


func _physics_process(delta: float) -> void:
	paso(delta * _arranque(delta))
	avanzar_volumen(delta)                                 # 3/11 (R3/R4): orbes y pilar que alza; un proyectil no pasa por aquí


## El factor de este fotograma (en el punto medio del paso, para que lo recorrido cuadre) y avanza el reloj del arranque.
func _arranque(delta: float) -> float:
	if espera > 0.0:
		return 1.0                                     # H5: esperando su `retardo`: el arranque suave empieza cuando se pone en marcha
	if volviendo or not activo or t_arranque >= Sensacion3D.T_ARRANQUE or v.length() < 0.01:
		t_arranque = maxf(t_arranque, Sensacion3D.T_ARRANQUE) if v.length() >= 0.01 else t_arranque
		factor_arranque = 1.0
		return 1.0
	factor_arranque = Sensacion3D.factor_arranque(t_arranque + delta * 0.5)
	t_arranque += delta
	return factor_arranque


func _process(delta: float) -> void:
	reloj_vida += delta


## Un paso de `dt` segundos: orienta (busca o vuelta), acelera, cae, avanza chocando con el mundo, golpea y comprueba si ha acabado. En este orden y sin más estado que el de arriba.
func paso(dt: float) -> void:
	if not activo or dt <= 0.0:
		return
	if espera > 0.0:                                   # H5: `retardo` del proyectil: quieto en el origen, sin edad ni golpes; lo que sobra del paso ya cuenta como vuelo
		if dt <= espera:
			espera -= dt
			return
		dt -= espera
		espera = 0.0
	edad += dt
	if _radio_u < _radio_pleno_u:                                          # `crece` en vuelo: el radio de acierto sube a `crece` m/s hasta el entero
		_radio_u = minf(_radio_pleno_u, _radio_u + _crece_u * dt)
	# 1. hacia dónde: la vuelta apunta al lanzador; `busca` gira hacia el objetivo más cercano del cono
	if volviendo:
		var j: Vector3 = _pos_lanzador()
		if (j - p).length() > 0.01:
			v = (j - p).normalized() * v.length()
	elif h.busca > 0.0:
		_buscar(dt)
	# 2. cuánto: aceleración (negativa = frena) y caída
	if h.aceleracion != 0.0:
		var nuevo_modulo: float = v.length() + h.aceleracion * Terreno3D.casilla * dt
		if nuevo_modulo <= VEL_MIN_PROYECTIL:
			_terminar("frenado")
			return
		v = v.normalized() * nuevo_modulo
	if h.gravedad != 0.0:
		v.y -= GRAVEDAD_U * h.gravedad * dt
	# 3. avanza, chocando con el mundo si le toca
	var sigue: bool = _avanzar(dt)
	if not sigue or not activo:
		return
	if is_inside_tree():
		global_position = p
	# 3 bis (B5): al ENTRAR en una casilla con una zona viva de otro hechizo, el proyectil puede transformarse (CRUCES). Antes de los golpes: un proyectil apagado no golpea.
	_cruzar_zonas()
	if not activo:
		return
	# 4. golpes, rastro y estela
	_golpes_del_paso()
	if not activo:
		return
	_rastro()
	# 5. ¿ha llegado al final de su tramo?
	if volviendo:
		if (_pos_lanzador() - p).length() <= LLEGADA_U or edad >= VIDA_RETORNO_S:
			_terminar("retorno")
	elif recorrido >= _max_recorrido:
		_fin_de_ida("alcance")
	elif edad >= Hechizo.LIM_VIDA_S:                                 # tope de seguridad (§1.9): la `persiste` del elemento ya NO acaba un viaje (§0.3)
		_fin_de_ida("tiempo")


func _pos_lanzador() -> Vector3:
	if lanz.jugador != null and is_instance_valid(lanz.jugador):
		return lanz.jugador.global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0)
	return p


func _choca_mundo() -> bool:
	return h.choca_con == 0 or (h.choca_con & Hechizo.CHOCA_MUNDO) != 0


func _choca_enemigos() -> bool:
	return h.choca_con == 0 or (h.choca_con & Hechizo.CHOCA_ENEMIGOS) != 0


## Mueve el punto `v·dt`. Si entra en una casilla sólida (o toca el suelo), rebota si le quedan rebotes y si no, acaba. Devuelve false si ha acabado.
func _avanzar(dt: float) -> bool:
	_p_previa = p
	var nuevo: Vector3 = p + v * dt
	if _choca_mundo():
		# 24/10 (D-6): el volumen con SOLIDEZ de otro hechizo (muro, barrera) para al proyectil igual que a `trazar` (`_barrera_en`, la misma consulta, no una copia): gasta un rebote si le quedan y, si
		# la solidez refleja (barrera + rebote), se devuelve UNA vez. Nunca la de su propio lanzamiento (`linaje`): la flecha de «barrera + flecha» levanta su muro al pararse y sus hermanas vuelan junto a él.
		if lanz != null and lanz._barrera_en(nuevo, 0, linaje):
			var devuelve: bool = lanz._solidez_refleja_en(nuevo, linaje) and not _reflejado
			if rebotes_usados < h.rebotes or devuelve:
				v.x = -v.x
				v.z = -v.z
				if rebotes_usados < h.rebotes:
					_rebotar()
				else:
					_reflejado = true
				return true
			_contacto_celdas = [Lanzador3D.celda_de(nuevo)]
			_terminar_o_volver("muro")
			return false
		# 6/11 (B3): el escombro del suelo (`EstadosSuelo3D.bloquea_proyectil`) para al proyectil al ENTRAR en su casilla. Solo al entrar (celda distinta de la actual): si no, el que nace encima
		# de un escombro moriria en su primer paso.
		var c_ant: Vector2i = Lanzador3D.celda_de(p)
		var c_esc: Vector2i = Lanzador3D.celda_de(nuevo)
		if c_esc != c_ant and Lanzador3D.en_mapa(c_esc) and Terreno3D.estados != null and Terreno3D.estados.bloquea_proyectil(c_esc):
			_contacto_celdas = [c_esc]
			_terminar_o_volver("muro")
			return false
		var sol_x: bool = Lanzador3D.celda_solida(Lanzador3D.celda_de(Vector3(nuevo.x, p.y, p.z)), 0)
		var sol_z: bool = Lanzador3D.celda_solida(Lanzador3D.celda_de(Vector3(p.x, p.y, nuevo.z)), 0)
		var sol_n: bool = Lanzador3D.celda_solida(Lanzador3D.celda_de(nuevo), 0)
		if sol_x or sol_z or sol_n:
			if rebotes_usados < h.rebotes:
				if sol_x or not sol_z:
					v.x = -v.x
				if sol_z or not sol_x:
					v.z = -v.z
				_rebotar()
				return true
			# Un reactivo (pulsador, brasero, tótem…) o un enemigo en la casilla SÓLIDA contra la que choca también recibe el golpe: su casilla bloquea, así que el
			# proyectil nunca llegaría a su radio. Es lo que hacía la flecha de siempre (tocaba lo que había en la casilla donde paraba).
			_golpear_celdas([Lanzador3D.celda_de(Vector3(nuevo.x, p.y, p.z)) if sol_x else Vector2i(-9999, -9999),
				Lanzador3D.celda_de(Vector3(p.x, p.y, nuevo.z)) if sol_z else Vector2i(-9999, -9999),
				Lanzador3D.celda_de(nuevo) if sol_n else Vector2i(-9999, -9999)])
			_golpes_areas(p, p + v.normalized() * Terreno3D.casilla * 1.05)         # lo que hay DENTRO de la casilla sólida (un pulsador, una antorcha…)
			_contacto_celdas = []
			for cs in [[sol_x, Vector3(nuevo.x, p.y, p.z)], [sol_z, Vector3(p.x, p.y, nuevo.z)], [sol_n, nuevo]]:
				if bool(cs[0]) and not _contacto_celdas.has(Lanzador3D.celda_de(cs[1] as Vector3)):
					_contacto_celdas.append(Lanzador3D.celda_de(cs[1] as Vector3))
			_terminar_o_volver("muro")
			return false
		var c: Vector2i = Lanzador3D.celda_de(nuevo)
		if v.y < 0.0 and Lanzador3D.en_mapa(c) and nuevo.y < Lanzador3D.y_pies(c) + 0.05:
			if rebotes_usados < h.rebotes:
				nuevo.y = Lanzador3D.y_pies(c) + 0.05
				v.y = absf(v.y)
				p = nuevo
				_rebotar()
				return true
			_contacto_celdas = [c]
			_terminar_o_volver("suelo")
			return false
	# El alcance se mide en el SUELO (lo que marca el anillo de casillas): un arco (`impulso_salida`) recorre más en 3D y, contado así, se acababa en el aire.
	recorrido += Vector2(nuevo.x - p.x, nuevo.z - p.z).length()
	p = nuevo
	return true


## Los objetos que no están en los grupos (pulsadores, antorchas, barriles, compuertas, tótems…) son Area3D en la capa reactiva: se encuentran con un rayo del tramo
## recorrido, como hacía `trazar`. Un objeto activable detiene el proyectil (más allá de `perfora`); una barrera que bloquea proyectiles también.
func _golpes_areas(desde: Vector3, hasta: Vector3) -> void:
	if not activo or not _choca_enemigos() or lanz == null or lanz.mundo == null:          # sin lanzador o sin mundo (pruebas del VFX) no hay a quién golpear: se salta
		return
	var plano: Vector3 = Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	var largo: float = plano.length()
	if largo < 0.0001:
		return
	var c: Vector2i = Lanzador3D.celda_de(desde)
	var y: float = desde.y if (h.gravedad != 0.0 or absf(v.y) > 0.01) else ((Lanzador3D.y_pies(c) + Terreno3D.ALTO_NIVEL * 0.5) if Terreno3D.en_mapa(c) else desde.y)
	var espacio: PhysicsDirectSpaceState3D = lanz.mundo.get_world_3d().direct_space_state
	for hit in lanz._rayo_areas(espacio, Vector3(desde.x, y, desde.z), plano / largo, largo):
		var obj: Node = hit["obj"]
		if not is_instance_valid(obj) or golpeados.has(obj.get_instance_id()):
			continue
		if obj.has_method("bloquea_proyectiles") and bool(obj.call("bloquea_proyectiles", lanz)):
			if obj is Node3D:
				_contacto_celdas = [Lanzador3D.celda_de((obj as Node3D).global_position)]
			_terminar_o_volver("muro")
			return
		if not obj.has_method("on_spell_hit") or fuera_de_juego(obj):
			continue
		golpeados[obj.get_instance_id()] = true
		golpes_dados += 1
		_golpear(obj, v.normalized(), (obj as Node3D).global_position, p)
		if not volviendo and golpes_dados > h.perfora:
			_sitio_golpe = (obj as Node3D).global_position
			_contacto_celdas = [Lanzador3D.celda_de(_sitio_golpe)]
			_terminar_o_volver("golpe")
			return


## Golpea (una vez por objeto y tramo) a los reactivos y enemigos cuya casilla está en `celdas`. Solo se usa al chocar con una casilla sólida.
func _golpear_celdas(celdas: Array) -> void:
	if not _choca_enemigos() or lanz == null or not lanz.is_inside_tree():             # sin lanzador en el árbol (pruebas del VFX) se salta el golpe de casillas
		return
	for grupo in ["combate3d", "reactivo3d"]:
		for obj in lanz.get_tree().get_nodes_in_group(grupo):
			if fuera_de_juego(obj) or golpeados.has((obj as Object).get_instance_id()):
				continue
			if not celdas.has(Lanzador3D.celda_de((obj as Node3D).global_position)):
				continue
			golpeados[(obj as Object).get_instance_id()] = true
			golpes_dados += 1
			_golpear(obj, v.normalized(), (obj as Node3D).global_position, p)


func _rebotar() -> void:
	rebotes_usados += 1
	if seco:
		prevision["rebotes"] = int(prevision.get("rebotes", 0)) + 1
		return                                         # `al_rebotar` son acciones (hijos, sonidos): en seco no
	rebotado.emit(p, v.normalized())                   # A1: para el dibujo (la velocidad ya está reflejada: apunta hacia fuera de lo que rebotó)
	disparar_evento("al_rebotar", p, v.normalized())


## `busca`: gira la velocidad hacia el enemigo vivo más cercano del cono delante (`BUSCA_COS`, más abierto con más `busca`) y dentro de BUSCA_ALCANCE_CAS, hasta `busca × GIRO_BASE` rad/s.
## Ignora a los ya golpeados en este tramo (así un hijo que encadena no vuelve al que acaba de herir).
func _buscar(dt: float) -> void:
	if lanz == null or not lanz.is_inside_tree():
		return
	var dir: Vector3 = v.normalized()
	var mejor: Vector3 = Vector3.ZERO
	var mejor_d: float = INF
	var cos_cono: float = lerpf(BUSCA_COS, BUSCA_COS - 2.0 * BUSCA_COS_POR_NIVEL, clampf((h.busca - 1.0) / 2.0, 0.0, 1.0))
	for e in lanz.get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(e) or e.get("muerto") == true or golpeados.has((e as Object).get_instance_id()):
			continue
		if e.has_method("apuntable") and not e.apuntable():
			continue                                    # 6/11: el canouro con niebla no se deja fijar
		var a: Vector3 = (e as Node3D).global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0) - p
		var dist: float = a.length()
		if dist < 0.01 or dist > BUSCA_ALCANCE_CAS * Terreno3D.casilla or dir.dot(a / dist) < cos_cono:
			continue
		if dist < mejor_d:
			mejor_d = dist
			mejor = a / dist
	if mejor_d == INF:
		return
	var ang: float = dir.angle_to(mejor)
	if ang < 0.0001:
		return
	var giro: float = minf(ang, h.busca * GIRO_BASE * dt)
	v = dir.slerp(mejor, giro / ang) * v.length()


## B5: las zonas vivas de hechizo que ocupan la casilla `c`: elemento -> [zonas]. Son las ZonaV2 con pulso del lanzador (llama, campo) y los charcos de `Lanzador3D.zonas_cruce`. Una zona que ya se
## está borrando no cuenta (el fuego que acaba de apagarse no enciende el viento).
static func zonas_en(lanzador: Lanzador3D, c: Vector2i) -> Dictionary:
	var r: Dictionary = {}
	for lista in [lanzador._zonas_v2, lanzador.zonas_cruce]:
		for z in lista:
			if not is_instance_valid(z) or (z as Node).is_queued_for_deletion() or not (z as Lanzador3D.ZonaV2).celdas.has(c):
				continue
			var e: String = (z as Lanzador3D.ZonaV2).elemento
			if not r.has(e):
				r[e] = []
			(r[e] as Array).append(z)
	return r


## B5: al ENTRAR en una casilla nueva, mira si la ocupa una zona de otro hechizo con la que haya cruce (`CRUCES`). Solo al entrar: un proyectil lento que tarda tres fotogramas en salir de una
## casilla no se transforma tres veces. Un cruce por casilla (el primero de la fila de su elemento).
func _cruzar_zonas() -> void:
	if lanz == null or not lanz.is_inside_tree() or not CRUCES.has(elemento):
		return
	var c: Vector2i = Lanzador3D.celda_de(p)
	if c == _celda_cruce:
		return
	_celda_cruce = c
	if not Lanzador3D.en_mapa(c):
		return
	var zonas: Dictionary = zonas_en(lanz, c)
	var fila: Dictionary = CRUCES[elemento]
	for otro in fila:
		if zonas.has(otro):
			_cruce(fila[otro] as Dictionary, c, zonas[otro] as Array)
			return


## B5: ejecuta una fila de `CRUCES`. En seco (previsión) solo anota el cruce y deja que el proyectil siga el mismo camino (se acaba o se transforma), sin tocar el suelo ni avisar.
func _cruce(f: Dictionary, c: Vector2i, zonas: Array) -> void:
	cruces_vistos.append({"accion": String(f["accion"]), "aviso": String(f["aviso"]), "celda": c})
	if seco:
		(prevision["cruces"] as Array).append({"reaccion": String(f["previsto"]), "celda": c, "accion": String(f["accion"])})
	match String(f["accion"]):
		"apagar", "costra":
			if not seco:
				Terreno3D.estados.mantener(c, EstadosSuelo3D.VAPOR)
				if String(f["accion"]) == "costra":
					Terreno3D.estados.mantener(c, EstadosSuelo3D.ESCOMBRO)      # R3: la lava que se enfría deja costra (escombro 6 s: frena y para proyectiles)
			_terminar("cruce")
		"encender":
			_transformar(f)
		"descargar":
			_descargar_en_zona(zonas)
			_terminar("cruce")
	if not seco:
		Mundo3D.avisar_reaccion(String(f["aviso"]), Terreno3D.centro_de(c, Terreno3D.y_pies(c)), null)


## B5 · «encender»: el proyectil pasa a ser de otro elemento SIN dejar de volar (misma velocidad, mismo camino). Se reconstruye el hechizo con la runa de la fila y los mismos glifos, así hereda
## todo lo del nuevo elemento (la quema, el daño por tics, lo que deja). La potencia (sobrecarga) y la profundidad se conservan, y también el hijo de «al impactar» (C3), que no sale del elemento.
func _transformar(f: Dictionary) -> void:
	var rune: RuneData = load(String(f["runa"])) as RuneData
	if rune == null:
		return
	var nuevo: Hechizo = Hechizo.construir(rune, h.glifos, h.calidad, false, h.orden_glifos)
	if nuevo == null:
		return
	nuevo.potencia = h.potencia
	nuevo.profundidad = h.profundidad
	for ev in h.eventos:
		for a in (h.eventos[ev] as Array):
			if (a as Dictionary).has("glifos_hijo"):
				var lista: Array = nuevo.eventos.get(ev, []) as Array
				lista.append((a as Dictionary).duplicate(true))
				nuevo.eventos[ev] = lista
	h = nuevo
	data = rune
	elemento = nuevo.elemento
	estado = nuevo.estado_materia if MATERIA_V2.has(nuevo.estado_materia) else ESTADO_RESERVA_V2


## B5 · «descargar»: el rayo que cruza un charco descarga sobre TODA la zona de agua (y el agua que la toca): daño del hechizo a quien esté dentro, y la zona pasa a `electrificada`. Es la
## descarga de siempre (`_descarga`) con las casillas de la zona; `golpeados` es la lista de «ya tocados», así el proyectil no vuelve a herir al mismo enemigo en su siguiente paso.
func _descargar_en_zona(zonas: Array) -> void:
	if data == null:
		return
	var celdas: Array = []
	for z in zonas:
		for k in (z as Lanzador3D.ZonaV2).celdas:
			if not celdas.has(k):
				celdas.append(k)
	_descarga({"data": data, "elemento": elemento, "celdas": celdas, "tocados": golpeados, "dir": v.normalized() if v.length() > 0.001 else Vector3.RIGHT, "origen": p}, {})
	if not seco:
		for k in celdas:
			Terreno3D.estados.mantener(k as Vector2i, EstadosSuelo3D.ELECTRIFICADA)


## Los objetos que toca el proyectil en su posición: enemigos y reactivos a menos de radio + RADIO_ENEMIGO_U (en planta) y dentro de la ventana vertical. Uno por objeto y tramo.
func _golpes_del_paso() -> void:
	_golpes_areas(_p_previa, p)
	if not activo:
		return
	if _choca_enemigos() and lanz != null and lanz.is_inside_tree():
		for grupo in ["combate3d", "reactivo3d"]:
			for obj in lanz.get_tree().get_nodes_in_group(grupo):
				if not activo:
					return
				if fuera_de_juego(obj) or golpeados.has((obj as Object).get_instance_id()):
					continue
				var c: Vector3 = (obj as Node3D).global_position + Vector3(0.0, CENTRO_ENEMIGO_U, 0.0)
				var plano: Vector3 = c - p
				plano.y = 0.0
				if plano.length() > _radio_u + RADIO_ENEMIGO_U or absf(c.y - p.y) > _radio_u + VENTANA_Y_U:
					continue
				golpeados[(obj as Object).get_instance_id()] = true
				golpes_dados += 1
				_golpear(obj, v.normalized(), (obj as Node3D).global_position, p)
				if not volviendo and golpes_dados > h.perfora:
					_sitio_golpe = (obj as Node3D).global_position
					_contacto_celdas = [Lanzador3D.celda_de(_sitio_golpe)]
					_terminar_o_volver("golpe")
					return
	if lanz != null and not seco and h.golpea_lanzador and not volviendo and not _golpeo_lanzador and edad > SEGURIDAD_S and lanz.jugador != null and is_instance_valid(lanz.jugador):
		var al_j: Vector3 = _pos_lanzador() - p
		al_j.y = 0.0
		if al_j.length() <= _radio_u + RADIO_ENEMIGO_U and lanz.jugador.has_method("recibir_dano"):
			_golpeo_lanzador = true
			lanz.jugador.call("recibir_dano", h.dano, p)
			if elemento == "viento":
				VfxToyJuego.aura_viento(lanz.jugador, 0.85)
			disparar_evento("al_golpear", p, v.normalized(), {"obj": lanz.jugador})


## Estela y `al_viajar`: lo que toca según lo recorrido.
func _rastro() -> void:
	if seco:
		return                                         # estela y `al_viajar` son efectos: en seco no
	if h.estela != "" and recorrido + (PASO_ESTELA_U if recorrido == 0.0 else 0.0) >= _estela_sig:
		_estela_sig = recorrido + PASO_ESTELA_U
		lanz.vfx_hechizo.emit(h.estela, p, elemento)
	var acciones: Array = h.eventos.get("al_viajar", []) as Array
	for i in range(mini(acciones.size(), _viaja_sig.size())):
		if recorrido >= float(_viaja_sig[i]):
			_viaja_sig[i] = float(_viaja_sig[i]) + maxf(float((acciones[i] as Dictionary).get("cada", 1.0)), 0.1) * Terreno3D.casilla
			eventos_vistos.append("al_viajar")
			_accion(acciones[i] as Dictionary, p, v.normalized(), {})


## Acaba la ida: si `retorna`, da la vuelta (nuevo tramo: puede volver a golpear a todos); si no, acaba.
func _terminar_o_volver(causa: String) -> void:
	_fin_de_ida(causa)


func _fin_de_ida(causa: String) -> void:
	if h.retorna and not volviendo:
		volviendo = true
		golpeados.clear()
		golpes_dados = 0
		recorrido = 0.0
		_sitio_golpe = Vector3.INF
		_contacto_celdas = []
		edad = 0.0
		if v.length() < VEL_MIN_PROYECTIL:
			v = Vector3.RIGHT * maxf(h.velocidad * Terreno3D.casilla, VEL_MIN_PROYECTIL)
		return
	_terminar(causa)


## Las casillas de donde sale el momento «final» de un proyectil que se ha parado en `sitio`: la superficie que tocó (`_contacto_celdas`) y la casilla en la que
## está; si no tocó nada (llegó a su alcance), las de su volumen (`_celdas_en`).
func celdas_de_contacto(sitio: Vector3, dir_fin: Vector3) -> Array:
	if _contacto_celdas.is_empty():
		return _celdas_en(sitio, dir_fin)
	var r: Array = _contacto_celdas.duplicate()
	var aqui: Vector2i = Terreno3D.celda_de(sitio)
	if not r.has(aqui) and Terreno3D.en_mapa(aqui):
		r.append(aqui)
	return r


## Acaba el proyectil (H2): salta UNO de los tres finales según la causa: `al_impactar` si lo paró un golpe (después del `al_golpear` de lo que golpeó) y `al_detenerse` en cualquier otra
## (muro, suelo, alcance, tiempo, frenado, retorno). `al_expirar` es la extinción de lo que nace quieto: un proyectil ya no lo dispara. Con cualquiera de los dos, el momento «final» de los
## glifos sale UNA vez (el de «retorno» no: el pulso no sale al recoger el proyectil).
func _terminar(causa: String) -> void:
	if not activo:
		return
	activo = false
	motivo_fin = causa
	var dir_fin: Vector3 = v.normalized() if v.length() > 0.001 else Vector3.RIGHT
	if causa == "cruce":
		# B5: el proyectil se gastó en el cruce con la zona de otro hechizo (vapor, descarga): no aplica su materia donde está ni salta ningún final (ni el hijo de «al impactar»: no impactó).
		# El VFX lo recibe como un fin sin choque («alcance»: se encoge y se va), que es el que ya sabe dibujar.
		if seco:
			prevision["fin"] = p
			prevision["causa"] = causa
		else:
			terminado.emit("alcance", p, -dir_fin, "")
		quedandose = false
		_revisar_fin()
		return
	if not seco:
		terminado.emit(causa, p, _normal_de_fin(causa, dir_fin), _material_de_fin(causa))      # A1: el VFX recibe el fin con su normal y su material
	if (causa == "muro" or causa == "suelo") and not seco and lanz != null:
		Sensacion3D.impacto_mundo(lanz, p, dir_fin, h.elemento, _radio_u, causa)      # gamefeel lote 4: parar contra el mundo se nota
	var celdas_final: Array = []
	if causa != "retorno":
		# el sitio del impacto es donde se para; si lo paró un golpe, donde está lo golpeado (un goblin en el agua se hiela con su casilla, no la de antes)
		var sitio: Vector3 = _sitio_golpe if (causa == "golpe" and _sitio_golpe != Vector3.INF) else p
		_aplicar_materia_en_el_sitio(sitio, dir_fin)
		if seco:
			prevision["fin"] = sitio
			prevision["causa"] = causa
			return                                      # momentos y finales son efectos: en seco no
		# MOMENTO «final» (ᚱ + flecha = el pulso sale donde choca, sin caso especial). 29/10 (Pablo): si se paró CONTRA algo (pared, barrera, objeto, enemigo, suelo), sale
		# de la SUPERFICIE DE CONTACTO (la casilla tocada más la de delante, donde está), no de todo el volumen; así entra en la veta o el agua que ha tocado. Si llegó a su alcance sin tocar nada, del volumen.
		celdas_final = celdas_de_contacto(sitio, dir_fin)
	_disparar_final("al_impactar" if causa == "golpe" else "al_detenerse", causa, p, dir_fin, celdas_final)
	var expirar: Callable = func() -> void:
		quedandose = false
	# §0.3: donde se para (llega, choca o golpea) se queda `permanencia` s y luego desaparece; sin permanencia, desaparece ya. La vuelta de un `retorna` no se queda.
	if h.permanencia > 0.0 and causa != "retorno":
		quedandose = true
		_despues(h.permanencia, expirar)
	else:
		expirar.call()
	_revisar_fin()


## A1: la normal (hacia fuera) de lo que paró al proyectil, solo para el dibujo: suelo = arriba; muro = la contraria al eje horizontal dominante de la velocidad (las paredes son de casilla); golpe y demás = contra la marcha.
func _normal_de_fin(causa: String, dir_fin: Vector3) -> Vector3:
	if causa == "suelo":
		return Vector3.UP
	if causa == "muro":
		return Vector3(-signf(dir_fin.x), 0.0, 0.0) if absf(dir_fin.x) >= absf(dir_fin.z) else Vector3(0.0, 0.0, -signf(dir_fin.z))
	return -dir_fin


## A1: el material de lo que paró al proyectil, solo para el dibujo: la letra del mapa de la casilla de contacto (muro, suelo); "" si no hay (un golpe, el alcance). Aún no hay tabla letra → material.
func _material_de_fin(causa: String) -> String:
	if (causa == "muro" or causa == "suelo") and not _contacto_celdas.is_empty() and Lanzador3D.en_mapa(_contacto_celdas[0] as Vector2i):
		return Lanzador3D.letra_de(_contacto_celdas[0] as Vector2i)
	return ""


## ESPEC §0.3 (regla de impacto, 19/10): al PARARSE (alcance, choque, suelo, golpe más allá de `perfora`, frenado) el proyectil aplica su MATERIA una vez en el sitio: el agua va a
## AguaSim y forma el charco, el fuego prende lo que arda y deja el suelo quemado, el hielo hiela, la tierra levanta su bloque, el rayo descarga… Es el EFECTO DEL IMPACTO, no
## permanencia: lo que dura lo decide la materia. Dura `persiste` + `permanencia` (como lo que nace quieto: el bloque de tierra vive su `persiste`; el fuego, su zona). La
## `permanencia` además deja el cuerpo del proyectil colgado ese tiempo (`quedandose`, en `_terminar`). Antes de parar ya fue golpeando reactivos y enemigos (`_golpes_del_paso`):
## a quien ya recibió el golpe NO se le repite (`tocados` parte de `golpeados`). Sin lanzador o sin mundo (pruebas del VFX) se salta, en vez de fallar.
## 28/10 (Pablo): la flecha de TIERRA solo golpea (pedrada + retroceso, en vuelo): sin ᛉ ni ᛜ no levanta bloque al pararse (ESPEC §0.3). Con `permanencia` o `solidez` > 0 sí.
func _aplicar_materia_en_el_sitio(pos: Vector3, dir: Vector3) -> void:
	if lanz == null or lanz.mundo == null or not lanz.is_inside_tree() or not MATERIA_V2.has(estado):
		return
	var props: Dictionary = g["props"]
	if elemento == "tierra" and h.permanencia <= 0.0 and float(props.get("solidez", 0.0)) <= 0.0:
		return
	var celdas: Array = _celdas_en(pos, dir)
	if celdas.is_empty():
		return
	var niveles: int = Lanzador3D.GeometriaV2.niveles(g)
	var vida: float = h.persiste + h.permanencia if (h.persiste + h.permanencia) > 0.0 else -1.0       # -1 = cada materia usa la suya de siempre
	var ctx: Dictionary = {"data": data, "elemento": elemento, "g": g, "celdas": celdas, "niveles": niveles, "vida": vida,
		"origen": pos, "dir": dir, "estado": estado, "fraccion": 1.0, "tocados": golpeados.duplicate(), "golpes": [], "impacto": true}
	_vivir(ctx, float(props.get("solidez", 0.0)), false)


## Las casillas que ocupa el volumen del hechizo CENTRADO en `pos` (el mismo elipsoide que `GeometriaV2.celdas`, sin adelantarlo: el proyectil ya está donde tiene que estar).
func _celdas_en(pos: Vector3, dir: Vector3) -> Array:
	var cas: float = Terreno3D.casilla
	var d := Vector2(dir.x, dir.z)
	d = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var perp: Vector2 = d.orthogonal()
	var sx: float = float(g["x"])
	var sz: float = float(g["z"])
	var o := Vector2(pos.x, pos.z)
	var c0: Vector2i = Terreno3D.celda_de(pos)
	var n: int = int(ceilf(maxf(sx, sz * 2.0))) + 1
	var salida: Array = []
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var c := Vector2i(c0.x + dx, c0.y + dz)
			if not Terreno3D.en_mapa(c):
				continue
			var rel: Vector2 = (Vector2((float(c.x) + 0.5) * cas, (float(c.y) + 0.5) * cas) - o) / cas
			var lz: float = rel.dot(d)
			var lx: float = rel.dot(perp)
			if (lz * lz) / (sz * sz) + (lx * lx) / (sx * sx) <= 1.0 or c == c0:
				salida.append(c)
	return salida
