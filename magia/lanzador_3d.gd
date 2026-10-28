class_name Lanzador3D
extends Grimorio

## LANZADOR DE HECHIZOS EN 3D (Test 3). Dueño: Juego.
##
## Sustituyó a spellcaster.gd en la maqueta 3D. Desde M4 (13/10) HEREDA de Grimorio (magia/grimorio.gd, un Node3D; spellcaster.gd era Node2D). El grimorio, el reconocedor $P, las tres páginas,
## la recarga y el aviso de fallos son los mismos, y cambia solo dos cosas:
##   1. Las REGLAS DEL LIBRO: un glifo por sector (el segundo se rechaza con aviso) y una receta por página
##      (con ratón, todos los glifos de la página se funden en un hechizo). `pilar` y `retardo` no están activos.
##   2. QUÉ SALE al lanzar: ya no hay Area2D ni Spell; la receta (SpellRecipe, sin tocarla) se lee en CASILLAS y se
##      materializa en 3D con el modo lanzar (4.1b), la tierra y el hielo que caducan (4.1c) y la altura (4.4).
##
## CONTRATO on_spell_hit (publicado en docs/DIARIO.md, 2026-10-06):
##
##   func on_spell_hit(rune_data: RuneData, direccion: Vector3) -> void
##
## Lo implementa cualquier nodo que quiera reaccionar a un hechizo: un Area3D en la capa CAPA_REACTIVO. Se decide por
## las etiquetas de `rune_data.tags`, nunca por `rune_type`. `direccion` es horizontal y unitaria (y = 0), o ZERO si el
## hechizo está quieto. Opcionales (si faltan se asume lo de siempre):
##   spell_reacts(rune_data, direccion) -> bool     ¿cambia algo de verdad? (falta = sí)
##   spell_passes_through() -> bool                 superficie: reacciona pero no detiene
##   spell_flies_over(rune_data, cargado) -> bool   deja pasar a algunos (el agua al viento)
##   carried_element() -> RuneData                  lo que el viento puede llevarse (una llama)
##   bloquea_proyectiles(proyectil) -> bool         (zona en CAPA_BLOQUEO) ¿para a este proyectil?
##   refleja_a(proyectil) -> bool                   (zona en CAPA_BLOQUEO) ¿lo devuelve?
##   push(direccion: Vector3, fuerza: float)        viento y atracción empujan a quien lo tenga
##   nivel_altura() -> int                          niveles que ocupa. Falta = 1 (un objeto de pie). 0 = a ras (fogata, charco,
##                                                  placa, puente): reacciona a lo que pasa POR ENCIMA o lo toca, pero no lo detiene;
##                                                  lo que vuela a un nivel más alto que el objeto (levitación) lo salta.
##
## DÓNDE ESTÁ EL SUELO: no es un Area3D. Cada hechizo marca el suelo llamando a Vfx3D.lanzar(elemento, origen, destino)
## UNA vez por casilla; el impacto del Vfx3D llega a PruebaTest2._al_impactar (ESTADOS_SUELO.md). Por eso aquí NO se
## llama nunca a _al_impactar a mano: un agua dos veces sobre la misma casilla la helaría.

## --- Capas de física del Test 3 ---
const CAPA_HECHIZO: int = 1 << 7     ## capa 8
const CAPA_REACTIVO: int = 1 << 8    ## capa 9: lo que implementa on_spell_hit
const CAPA_BLOQUEO: int = 1 << 9     ## capa 10: zonas que paran proyectiles
const CAPA_SOLIDO: int = Terreno3D.CAPA_SOLIDO     ## capa 11: colisión REAL de las piezas del nivel .tscn (6.10); el valor vive en Terreno3D (M1)


## --- Modo lanzar (§0b) ---
const TIEMPO_LANZAR: float = 0.3           ## Engine.time_scale mientras se apunta (5.2; Pablo lo confirmó el 6/10)
const TIEMPO_LIBRO: float = 0.3             ## Engine.time_scale con el libro abierto: ya no pausa, los goblins siguen (5.2)
const RALENTIZADO: float = TIEMPO_LANZAR
const ALCANCE_ORIGEN: float = 3.0           ## casillas: radio del anillo que se dibuja al apuntar (el hechizo NO nace ahí: 5.1)
const TOLERANCIA_ALCANCE_U: float = 0.05    ## u: holgura al comparar el origen con el borde del anillo (el origen vivo se recorta justo en el borde)
const ARRASTRE_MINIMO: float = 0.45        ## casillas: menos que esto es un clic, no un arrastre
const TIEMPO_MAX_MODO: float = 12.0         ## segundos de reloj: pasado esto se cancela solo
const PREVER_REACCIONES: bool = true         ## 28/10 · A3: pintar en el indicador lo que el hechizo haría al soltar (PrevisionReaccion3D, con PrevisionHechizo.prever_rapido)
const TIEMPO_PAGINA: float = 0.7            ## 27/10 · A1: Engine.time_scale en el lanzamiento RÁPIDO (mantener 1/2/3). Más suave que el 0,3 del libro porque aquí te mueves; Pablo lo afina en el playtest

## --- Lo que sale ---
const ALCANCE_FLECHA: float = 3.0           ## casillas (6.5: bola pequeña, alcance corto)
const RADIO_BOLA: float = 0.25               ## metros (≈ media casilla de diámetro)
const ALTO_BOLA: float = 0.6                 ## Vfx3D.lanzar eleva la bola 0,6·escala sobre los pies que recibe (valor suyo; ver diario P2)
const ALCANCE_HAZ: float = 8.0              ## casillas (rayo)
const VEL_MURO: float = 1.72                ## casillas/s (Sigils.WALL_SPEED 110 px / 64)
const VEL_ONDA: float = 1.48                ## casillas/s (Sigils.PULSE_SPEED 95 px / 64)
const RADIO_GOLPE: float = 0.42             ## casillas: radio de cada manifestación quieta
const FUERZA_EMPUJE: float = 2600.0         ## la del 2D; Combate3D la reduce a su escala

## --- Tierra e hielo con duración (§0b) ---
## --- Barrera-burbuja (Fase 12, 16/10; referencia: la burbuja de agua de Sidon en TotK, vídeo de Pablo 15/10) ---
## Una esfera que envuelve al jugador, le sigue, para el PRIMER impacto que la toque y revienta. Sustituye a la cúpula con escudo de vida
## (VIDA_ESCUDO y la resistencia ×1,5 por barrera repetida se retiran: repetir la barrera es una burbuja nueva, no una más dura).
const RADIO_BURBUJA: float = 1.3             ## u de mundo: radio de la esfera que para golpes, flechas y elementos
const ALTO_BURBUJA: float = 0.9              ## u: el centro de la esfera sobre los pies del jugador
## Qué le pasa al mundo cuando la burbuja `barrera` revienta con el elemento `recibido`: [nombre de la reacción, elemento de la
## AccionElemental que se aplica en el punto]. Lo que no está aquí no reacciona (la salpicadura del elemento de la burbuja sí sale
## siempre) y la TIERRA absorbe cualquier cosa sin más.
const REACCIONES_BURBUJA: Dictionary = {
	"agua": {"fuego": ["vapor", "fuego"]},       # el fuego evapora la burbuja: vapor (y se quita el agua que hubiera en el punto)
	"fuego": {"agua": ["vapor", "fuego"]},       # y al revés: el agua apaga la burbuja de fuego
	"hielo": {"fuego": ["charco", "agua"]},      # el hielo se funde: un charco donde estalla
}
## --- Barrera que protege (6.3) ---
const MULT_VIDA_BARRERA: float = 2.0        ## la barrera quieta dura el doble que antes...
const VIDA_MIN_BARRERA: float = 6.0         ## ...y como poco esto (s)
const T_CRECE: float = 0.9                  ## s que tarda el anillo de barrera + pulso en llegar a su radio (6.4)
const MAX_TIERRA_APILADA: int = 1           ## bloques de tierra uno encima de otro
const MAX_NIVELES_TIERRA: int = 8           ## tope de bloques vivos a la vez (FIFO)
const DURACION_TIERRA: float = 25.0         ## segundos
const DURACION_HIELO: float = 20.0          ## segundos, salvo casillas en `hielo_permanente`
const AVISO_CADUCA: float = 3.0             ## segundos finales en que parpadea


## --- El repertorio del Test 3: los seis elementos, nueve sellos (sin `pilar` ni `retardo`) ---
## LIBRO (16/10, Pablo): el libro antiguo («nivel1» y la lámina de doce casillas) era un placeholder. TODAS las progresiones usan ya `LIBROS["bosque"]`
## (grimorio_bosque.png): tres huecos de glifo que se abren por orden (abajo → abajo-izq → abajo-der) según `glifos_por_pagina`. Con 2, como hasta ahora,
## están abiertos los dos primeros y el juego es el mismo; con 6 (los bancos de pruebas) se abren los tres y el resto del presupuesto se apila en ellos.
## Cuando existan las mejoras que abren huecos, `glifos_por_pagina` de nivel1/bosque pasa a ser lo que haya ganado el jugador (hoy no hay mecanismo).
## --- Progresión en 3D: qué tienes en cada nivel (vocabulario del diseño: SELLO = elemento, GLIFO = forma) ---
## `Repertoire` ya hace que el libro solo enseñe lo activo; aquí se decide QUÉ está activo, y cuántas páginas (libros) hay y
## cuántos glifos caben en una. «todo» es el banco de pruebas de siempre (Test 3). La clave se elige con el nombre del nivel
## (`mundo.nivel`); si no hay una con ese nombre vale «todo». Para probar un nivel concreto sin tocar el mundo: PROGRESION_FORZADA.
## `capacidad` = [elementos, glifos] que caben en la página derecha del libro (Repertoire.max_elementos / max_glifos); sin ella, sin límite.
## El primer libro de la historia (27/10, Pablo): 4 elementos y 6 glifos, que se van ganando jugando. Un libro posterior traerá más.
const CAPACIDAD_PRIMER_LIBRO: Array = [4, 6]
const PROGRESIONES: Dictionary = {
	"todo": {"sellos": ["fuego", "agua", "viento", "tierra", "rayo", "hielo"],
		"glifos": ["flecha", "barrera", "linea", "altura", "levitacion", "repeticion", "rebote", "pulso"],
		"paginas": 3, "glifos_por_pagina": 6, "libro": "bosque"},
	# Primer nivel (Pablo, 8/10): UN sello y DOS glifos, una sola página, y como mucho dos glifos en ella.
	"nivel1": {"sellos": ["fuego"], "glifos": ["flecha", "barrera"], "paginas": 1, "glifos_por_pagina": 2, "libro": "bosque", "capacidad": CAPACIDAD_PRIMER_LIBRO},
	# Bosque 1 (Fase 9, 9.9, Pablo 10/10): se empieza con FUEGO + FLECHA y una página (un hueco de sello, dos de glifo). El
	# sello de AGUA se recoge detrás de la telaraña (Bosque3D, zona `a`) y la BARRERA se compra al guardabosques por 20 de oro.
	"bosque": {"sellos": ["fuego"], "glifos": ["flecha"], "paginas": 1, "glifos_por_pagina": 2, "libro": "bosque", "capacidad": CAPACIDAD_PRIMER_LIBRO},
	# Kit de pruebas (11.15, Pablo 12/10): el Bosque como laboratorio, con TODO el repertorio desde el principio, hielo incluido.
	# Se elige con `mundo.kit = "pruebas"`; el Bosque3D no quita ni bloquea nada de esto (solo desbloquea, y es idempotente).
	"pruebas": {"sellos": ["fuego", "agua", "viento", "tierra", "rayo", "hielo"],
		"glifos": ["flecha", "barrera", "linea", "altura", "levitacion", "repeticion", "rebote", "pulso"],
		"paginas": 3, "glifos_por_pagina": 6, "libro": "bosque"},
	# 27/10: la Gruta Batida (docs/GRUTA_BATIDA.md), el nivel de la BARRERA: tres elementos (fuego, tierra, hielo) y solo flecha, barrera y línea, para que cada puzle se lea como «¿dónde y de qué levanto la barrera?».
	# El cofre del final da ᛉ permanencia (la barrera que dura).
	"barrera": {"sellos": ["fuego", "tierra", "hielo"], "glifos": ["flecha", "barrera", "linea"],
		"paginas": 3, "glifos_por_pagina": 4, "libro": "bosque", "capacidad": CAPACIDAD_PRIMER_LIBRO},
}
const PROGRESION_FORZADA: String = ""          ## «nivel1», «todo»…: manda sobre el nombre del nivel (para probar)
const PALETA_RUNAS: bool = true               ## paleta F1 de pruebas (rune_palette.gd), como en Blockout y TestJugabilidad
const HUECOS_POR_PAGINA: int = 6
const ELEMENTOS_TEST3: PackedStringArray = ["fuego", "agua", "viento", "tierra", "rayo", "hielo"]
const SELLOS_TEST3: PackedStringArray = ["flecha", "barrera", "linea", "altura", "levitacion", "repeticion", "rebote", "pulso"]
## 8/10 (8.1c): amplificar, retardo, atracción y espejo quedan fuera del 3D (siguen en el 2D). R3 (17/10): `tamano` y `pilar` se retiran
## (cada eje tiene su glifo) y `levitacion` (ᛏ) vale SOLO como `altura`.

## DÓNDE golpeó el último hechizo (mundo) y a qué nivel; on_spell_hit no lleva posición. Vector3.INF = ninguna.
static var ultimo_impacto: Vector3 = Vector3.INF
static var ultimo_nivel: int = 0

## Radio (m) de la bola que se dibuja ahora; Tamaño lo agranda (8.5). Vuelve a RADIO_BOLA con cada lanzamiento.
var _radio_bola_actual: float = RADIO_BOLA


## Casillas cuyo hielo no caduca (el nivel lo marca): Vector2i -> true.
static var hielo_permanente: Dictionary = {}

## --- Lo que Lanzador3D necesita saber del resto (lo pone Jugador3D.montar) ---
var mundo: Node3D = null
var fx: Vfx3D = null
var jugador: Node3D = null              ## Jugador3D
var tinta: Tinta = null                  ## la tinta del jugador (15/10). null = los hechizos no cuestan nada (pruebas y laboratorios)
var desplaza_mano: Vector3 = Vector3.ZERO   ## 24/10: mientras se dispara, de la casilla de origen a la mano (x, z); el proyectil nace ahí (`_salida_de_mano`)
var camara: Camera3D = null
var altura: int = 0                     ## nivel del hechizo que pregunta a una barrera (bloquea_proyectiles lo lee)

var capa_ui: CanvasLayer = null
var menu: MenuPestanas = null           ## el menú con pestañas (I Inventario, J Misiones): en 3D lo monta el lanzador, como el libro
var mochila: BolsaUI = null             ## (heredado) la bolsa antigua: ya no se monta, queda null (la sustituye `menu`)
var diario: DiarioMisiones = null       ## (heredado) el diario suelto: ya no se monta, queda null (vive dentro de `menu`)
var libro: Control = null
var _libro_lento: bool = false
var _barrera_activa: Campo = null
var _ts_libro: float = 1.0
var _aviso: Label = null
var _tw_aviso: Tween = null
const AVISO_BORDE: Color = Color(0, 0, 0, 0.9)    ## contorno de siempre del aviso
const AVISO_DURA: float = 1.4                     ## s que se queda el aviso antes de apagarse
var _guia: Label = null

## --- Modo lanzar ---
var modo_lanzar: bool = false
var _preparado: Dictionary = {}
var _ms_modo: int = 0
var _fijado: bool = false
var _origen_fijo: Vector3 = Vector3.ZERO
var _origen_vivo: Vector3 = Vector3.ZERO
var _punto_vivo: Vector3 = Vector3.ZERO
var _marca_origen: MeshInstance3D = null
var _marca_flecha: MeshInstance3D = null
var _marca_alcance: MeshInstance3D = null
var _prev_casillas: Array = []                 ## 8.8: una caja por casilla que ocupará el hechizo (previsualización al apuntar)
var _prev_color: Color = Color.WHITE
var _apuntado: Apuntado3D = null              ## 28/10: el recorrido real, las retículas y el motivo de «no se puede» del indicador (vive lo que el modo de lanzar)
var cursor_puesto: String = ""                 ## 28/10: el cursor de apuntar que está puesto («color|cruz»; vacío = el del sistema). Se cambia solo cuando cambia
var _vista_reaccion: PrevisionReaccion3D = null   ## A3: los rótulos, anillos y cuadros de la reacción prevista (vive lo que el modo de lanzar)
var _ts_antes: float = 1.0
var _rapido: bool = false                      ## A1: el modo de apuntar actual es el de mantener 1/2/3 (no bloquea a la jugadora, se lanza al soltar la tecla)
var _pagina_rapida: int = -1                   ## A1: índice de la página (0–2) cuya tecla se mantiene
## A1: «lanzamiento inteligente» (ajuste del jugador): pulsar 1/2/3 lanza al instante hacia el ratón, sin indicador. Vive con las demás opciones del jugador en `Estado`
## (`asistencia`, `trazo_recto`); aún no hay pantalla de ajustes ni guardado, así que se cambia desde la paleta F1 o por código. El día que haya menú de opciones, engancharlo ahí.
var lanzamiento_inteligente: bool:
	get:
		return Estado.i().lanzamiento_inteligente
	set(v):
		Estado.i().lanzamiento_inteligente = v

## --- Lo vivo ---
var _campos: Array = []                 ## Campo: muros, corros, ondas, tierra...
var _bloques: Array = []                ## tierra construida: {celda, niveles, nodos, resta, v2}
var _zonas_v2: Array = []               ## zonas V2 vivas (plasma, gas, campo): ZonaV2
var _solideces_v2: Array = []           ## SolidezV2 vivas: lo que bloquea proyectiles y aguanta golpes (propiedad `solidez`)
var _columnas: Array = []               ## alturas temporales de columnas: {celda, niveles, resta, nodo}
var _hielo: Dictionary = {}             ## Vector2i -> {resta, agua}
var _t_hielo: float = 0.0
var _huecos_usados: Array = [{}, {}, {}]    ## por página: clave del sector -> nombre del glifo
var manifestaciones_vivas: int = 0

signal lanzado(elemento: String, forma: String, manifestaciones: int)
signal modo_cambiado(activo: bool)
## Una casilla pasó a ser agua (o dejó de serlo) según la simulación. Para quien dependa de «es agua» y no pregunte cada vez.
signal agua_cambio(c: Vector2i, es_agua: bool)

## --- CONJURO (Fase 14.5 · A3, 16/10, Juego): del libro a la mano, y dispara ---
## Al SOLTAR el botón ya no sale el hechizo al instante: primero se «conjura» en tres tiempos (total ~0,45 s de anticipación):
##   1. RUNA   (~0,10 s)  la runa brilla en la página (el HUD de páginas la destella).
##   2. VOLUTA (~0,25 s)  una voluta del elemento (HiloLuz3D) viaja del libro a la mano del jugador.
##   3. FORMA  (~0,10 s)  en la mano se forma la bola del elemento, que crece hasta el disparo.
##   4. DISPARO           `_disparar`: sale el hechizo, con lo mismo que salía antes (receta, tinta y recarga ya cobradas al soltar).
## Por qué el coste y la recarga se cobran AL SOLTAR y no al disparar: si no, se podría lanzar dos veces en la ventana de 0,45 s.
## PARA QUE PABLO LO AFINE: todo está aquí, en `RETARDO_CONJURO` (segundos [runa, voluta, forma] por elemento), `conjuro_escala` (un
## multiplicador de todos: 0 = sin anticipación, 1 = lo previsto, 2 = el doble) y `conjuro_activo` (apagarlo vuelve al disparo
## instantáneo de antes). PlayLog anota cada conjuro (`conjuro`) con el retardo medido, para ver si molesta.
## Qué espera el Pipeline (VFX/pose): la señal `conjuro_fase(fase, elemento, posicion)` sale al empezar cada tiempo ("runa", "voluta",
## "forma", "disparo"); `posicion` es la de la mano (la del libro en "voluta" para el arranque). Lo que se ve hoy es un sustituto
## (hilo de luz y una esfera brillante) que ellos cambiarán por el VFX de verdad sin tocar los tiempos.
const RETARDO_CONJURO: Dictionary = {
	"defecto": [0.10, 0.25, 0.10],
	"fuego": [0.10, 0.25, 0.10],
	"agua": [0.10, 0.28, 0.12],
	"viento": [0.08, 0.20, 0.08],
	"rayo": [0.06, 0.14, 0.06],      ## el rayo es instantáneo por naturaleza: la anticipación más corta
	"hielo": [0.10, 0.26, 0.12],
	"tierra": [0.12, 0.30, 0.14],    ## la tierra es lenta y pesada
}
var conjuro_activo: bool = true
var conjuro_escala: float = 1.0
## T-CP1: el cast point del lanzamiento en curso ({} = ninguno): id, origen (CastPoints), dir, origen_mundo, elemento. Lo borra cada `lanzar_ahora`.
var _cast_point: Dictionary = {}
var sonidos_fase: Array = []             ## [{fase, pedido, suena, elemento}] de cada sonido pedido a Sfx por fase (para las pruebas; ver `_sonar_fase_v2`)
var ultimo_castpoint: Dictionary = {}    ## la última medida al disparar con cast point (ver `_medir_cast_point`)
var ultimo_disparo: Dictionary = {}       ## el último hechizo que salió: {pagina, origen, dir} (donde nace y hacia dónde; lo leen las pruebas del lanzamiento rápido, A1)
var conjurando: bool = false             ## hay un conjuro en marcha (entre soltar y disparar)
## 22/10 (Pablo: «la bola de la carga es toda roja»): true cuando `ConjuroVfx3D` dibuja la forma en la mano; entonces no se pone la esfera lisa de
## prueba (`_forma_en_mano`), que desde que el proyectil mide la mitad (21/10) envolvía la bola de fuego y la del agua y las tapaba de un solo color.
var forma_externa: bool = false
var _t_conjuro: float = 0.0              ## segundos DE JUEGO (con time_scale y pausa) desde que se soltó: es lo que se anota como retardo
var _page_hud: Control = null
## HC4: un hechizo pide un efecto visual por su NOMBRE (acción `vfx`, `estela` y `efecto_impacto`). Lo resuelve el Pipeline (VfxEstado3D / Vfx3D): mientras nadie escuche, no se ve nada.
signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
## Receta V2: sale UNA vez por hechizo, antes de materializarlo. Para el VFX del Pipeline: un dibujo por ESTADO escalado a (x, y, z).
## `g` = {x, y, z (semiejes en casillas), celdas: Array[Vector2i], niveles: int}; `props` = lo de Sigils.aplicar_v2 (viaja, solidez…).
signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)


## =====================================================================================================
##  Configuración y utilidades de casilla (estáticas: las usan también Jugador3D y Combate3D)
## =====================================================================================================

static func configurar(p_mundo: Node3D) -> void:
	Terreno3D.configurar(p_mundo)
	Terreno3D.al_solidificar = soltar_presos
	ReaccionesAgua3D.efecto = _efecto_mundo
	ReaccionesSuelo3D.clasificar = _clase_de_casilla
	ReaccionesSuelo3D.prever_hierba = _prever_hierba
	ReaccionesSuelo3D.reiniciar()
	mundo_s = p_mundo                    # espejo M1
	agua_sim = null                      # espejo M1


## De qué clase es una casilla para el ESTADO del suelo (ReaccionesSuelo3D): las mismas tres ramas que `PruebaTest2._al_impactar` (agua, hierba,
## suelo no bloqueado), preguntándoselas a la maqueta para que las dos cosas decidan igual. «» = no recibe nada (bloqueada, o la maqueta está
## precalentando shaders: entonces `_al_impactar` tampoco marca el suelo). Sin esos métodos (una maqueta de mentira en una prueba) tampoco recibe nada.
static func _clase_de_casilla(c: Vector2i) -> String:
	var m: Node3D = mundo_s
	if m == null or not is_instance_valid(m) or not m.has_method("_es_agua") or not m.has_method("_es_hierba"):
		return ""
	if bool(m.get("_precalentando")):
		return ""
	if bool(m.call("_es_agua", m.call("_letra", c))):
		return "agua"
	if bool(m.call("_es_hierba", c)):
		return "hierba"
	var bl: Variant = m.get("_bloqueadas")
	if bl is Dictionary and (bl as Dictionary).has(c):
		return ""
	return "suelo"


## 28/10 · A2: lo que ese elemento le haría a la hierba de `c`, preguntándoselo a la maqueta (que es quien tiene el autómata). «» si no hay maqueta o no sabe.
static func _prever_hierba(elemento: String, c: Vector2i) -> String:
	var m: Node3D = mundo_s
	if m == null or not is_instance_valid(m) or not m.has_method("prever_hierba"):
		return ""
	return String(m.call("prever_hierba", elemento, c))


## --- Hechizos sobre el agua (Fase 11.4, 12/10) ---
## M3 (13/10): la lógica vive en ReaccionesAgua3D (mundo/), que recibe una AccionElemental. Aquí queda el reenvío y UN solo sitio
## con lo que no es del mundo (`_efecto_mundo`: vapor, avisar al render del hielo, atrapar, poner al día lo helado).
static func hechizo_sobre_agua(elemento: String, punto: Vector3) -> void:
	ReaccionesAgua3D.aplicar(AccionElemental.nueva(elemento, punto))    ## REENVÍO M3


## Lo que el mundo pide a la magia y a la presentación cuando el agua cambia. Lo recibe ReaccionesAgua3D.efecto (ver su cabecera).
static func _efecto_mundo(nombre: String, punto: Vector3, radio: float, segundos: float) -> void:
	match nombre:
		"vapor", "hielo_desde":
			# El dibujo no es del Juego: se avisa por la fachada y la maqueta (Pipeline) decide qué pintar (entrada 43 del diario).
			if Mundo3D.actual != null:
				Mundo3D.actual.avisar_impacto(punto, nombre, radio)
		"hielo_formado":
			atrapar(punto, radio, segundos)
		"hielo_cambios":
			procesar_cambios_hielo()


## Pone al día lo que depende del hielo de la simulación: `_helada` de la maqueta (la usan es_agua, y_pies, pisable, el rayo, el
## dibujo antiguo…) y lo que estaba preso. Se llama tras cada hechizo y cada fotograma (el hielo también se suelta solo al acabar
## su tiempo).
static func procesar_cambios_hielo() -> void:
	if Terreno3D.agua_sim == null or Terreno3D.mundo_s == null:
		return
	for cb in Terreno3D.agua_sim.cambios_hielo():
		_hielo_cambio(cb["c"] as Vector2i, bool(cb["helada"]))


static func _hielo_cambio(c: Vector2i, helada: bool) -> void:
	Terreno3D.poner_helada(c, helada)
	if helada:
		if Terreno3D.mundo_s.has_method("_liberar"):
			Terreno3D.mundo_s.call("_liberar", c)              # como hace la maqueta al helar: a pie se puede pisar
	else:
		if letra_de(c) == "~":
			bloquear_celda(c)                        # vuelve a ser agua: a pie no se pisa (se nada desde la orilla)
		# ajustes VFX: la placa de hielo se rompe. Se avisa por la fachada y VfxElemento3D (lo comparten la maqueta y el lab) dibuja VfxHielo.placa_rota.
		if Mundo3D.actual != null and is_instance_valid(Mundo3D.actual):
			Mundo3D.actual.avisar_impacto(Terreno3D.centro_de(c, Terreno3D.superficie_agua(c)), "hielo_roto", Terreno3D.casilla)
		# (El canal «helado» del suelo lo apaga la maqueta al oír casilla_cambio «hielo»: ya no se le llama por reflexión.)
		soltar_presos(c)


## Atrapa lo que esté dentro del hielo recién hecho: los troncos (Flotador3D se congela hasta que el hielo se suelta) y los goblins
## (su estado «congelado» durante `segundos`). «Dentro» = su posición cae sobre un trocito helado. El jugador NO queda preso:
## Jugador3D sale del nado solo y se sube a la cara del hielo.
const AVISO_HIELO: float = 0.15        ## fracción de tiempo que le queda al hielo para que la costra abra grietas
static var _presos: Array = []         ## goblins presos en hielo ahora mismo (para avisarles y soltarles la costra)


static func atrapar(punto: Vector3, radio: float, segundos: float) -> void:
	if Terreno3D.agua_sim == null:
		return
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	for f in arbol.get_nodes_in_group("flotador"):
		if is_instance_valid(f) and _dentro_del_hielo((f as Node3D).global_position, punto, radio):
			f.call("congelar")
	for g in arbol.get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and _dentro_del_hielo((g as Node3D).global_position, punto, radio):
			g.set("congelado", maxf(float(g.get("congelado")), segundos))
			g.set_meta("preso_hielo", true)
			if not _presos.has(g):
				_presos.append(g)
			if not g.has_meta("costra_hielo"):
				# La costra (Pipeline) se pone sobre el modelo del goblin; si no tiene `pj`, sobre el propio nodo.
				var modelo: Variant = g.get("pj")
				var raiz_m: Node = modelo as Node if modelo != null else g
				var costra := CostraHielo3D.new()
				raiz_m.add_child(costra)
				g.set_meta("costra_hielo", costra)


static func _dentro_del_hielo(p: Vector3, centro: Vector3, radio: float) -> bool:
	var d := Vector2(p.x - centro.x, p.z - centro.z)
	return d.length() <= radio + 0.5 * Terreno3D.casilla and Terreno3D.agua_sim.hielo_en(p) > -INF


## El hielo de la casilla se ha soltado: los goblins que estaban presos en ella quedan libres.
static func soltar_presos(c: Vector2i) -> void:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	for g in arbol.get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and g.has_meta("preso_hielo") and celda_de((g as Node3D).global_position) == c:
			_soltar_preso(g)


## Libera a un goblin preso: acaba su «congelado», quita la marca y la costra se deshace (derretir) en vez de desaparecer de golpe.
static func _soltar_preso(g: Node) -> void:
	g.set("congelado", 0.0)
	if g.has_meta("preso_hielo"):
		g.remove_meta("preso_hielo")
	if g.has_meta("costra_hielo"):
		var costra: Variant = g.get_meta("costra_hielo")
		if is_instance_valid(costra):
			(costra as CostraHielo3D).derretir()
		g.remove_meta("costra_hielo")
	_presos.erase(g)


## Cada fotograma: a los presos a los que les queda menos del 15 % de hielo se les abren las grietas (aviso); a los que ya no
## están sobre hielo, o cuyo «congelado» ha acabado por su cuenta, se les quita la costra.
static func vigilar_presos() -> void:
	if _presos.is_empty():
		return
	for g in _presos.duplicate():
		if not is_instance_valid(g):
			_presos.erase(g)
			continue
		var f: float = -1.0
		if Terreno3D.agua_sim != null:
			f = Terreno3D.agua_sim.fraccion_hielo_en((g as Node3D).global_position)
		if f < 0.0 or float(g.get("congelado")) <= 0.0:
			_soltar_preso(g)
			continue
		var costra: Variant = g.get_meta("costra_hielo") if g.has_meta("costra_hielo") else null
		if costra != null and is_instance_valid(costra):
			(costra as CostraHielo3D).aviso(f < AVISO_HIELO)


## Un chorro de agua es un MANANTIAL mientras dura (ver ReaccionesAgua3D.abrir_caudal).
static func abrir_caudal(c: Vector2i, caudal: float, dura: float) -> void:
	ReaccionesAgua3D.abrir_caudal(c, caudal, dura)    ## REENVÍO M3


## =====================================================================================================
##  REENVÍOS M1 (13/10): el terreno ya vive en Terreno3D (mundo/terreno_3d.gd). Estas funciones solo reenvían, para que
##  nada se rompa mientras los demás archivos pasan a llamar a Terreno3D directamente. Cuando nadie las use, se borran.
## =====================================================================================================
## Espejos: SOLO los leen (por Script.get o directamente) archivos que no son del Juego (prueba_test2.gd). El dueño real es
## Terreno3D; configurar() y montar_agua_sim() los mantienen al día. No escribir aquí desde fuera.
static var mundo_s: Node3D = null                 ## ESPEJO M1 de Terreno3D.mundo_s
static var agua_sim: AguaSim3D = null             ## ESPEJO M1 de Terreno3D.agua_sim
const LECHO_AGUA: float = Terreno3D.LECHO_AGUA    ## REENVÍO M1
const FONDO_CANAL: float = Terreno3D.FONDO_CANAL  ## REENVÍO M1

static func bloqueada(c: Vector2i) -> bool:
	return Terreno3D.bloqueada(c)    ## REENVÍO M1

static func bloquear_celda(c: Vector2i) -> void:
	Terreno3D.bloquear_celda(c)    ## REENVÍO M1

static func bloquear_celda_completa(c: Vector2i) -> void:
	Terreno3D.bloquear_celda_completa(c)    ## REENVÍO M1

static func liberar_celda(c: Vector2i) -> void:
	Terreno3D.liberar_celda(c)    ## REENVÍO M1

static func activar_fuente_nodos(p_mundo: Node3D) -> int:
	return Terreno3D.activar_fuente_nodos(p_mundo)    ## REENVÍO M1

static func activar_fuente_casillas() -> void:
	Terreno3D.activar_fuente_casillas()    ## REENVÍO M1

static func sobre_hielo(p: Vector3) -> bool:
	return Terreno3D.sobre_hielo(p)    ## REENVÍO M1

static func cubre_hielo(c: Vector2i) -> bool:
	return Terreno3D.cubre_hielo(c)    ## REENVÍO M1

static func celda_de(p: Vector3) -> Vector2i:
	return Terreno3D.celda_de(p)    ## REENVÍO M1

static func centro_de(c: Vector2i, y: float = 0.0) -> Vector3:
	return Terreno3D.centro_de(c, y)    ## REENVÍO M1

static func en_mapa(c: Vector2i) -> bool:
	return Terreno3D.en_mapa(c)    ## REENVÍO M1

static func letra_de(c: Vector2i) -> String:
	return Terreno3D.letra_de(c)    ## REENVÍO M1

static func es_agua(c: Vector2i) -> bool:
	return Terreno3D.es_agua(c)    ## REENVÍO M1

static func es_cauce_seco(c: Vector2i) -> bool:
	return Terreno3D.es_cauce_seco(c)    ## REENVÍO M1

static func es_canal_ruinas(c: Vector2i) -> bool:
	return Terreno3D.es_canal_ruinas(c)    ## REENVÍO M1

static func lados_de_canal(c: Vector2i) -> Array:
	return Terreno3D.lados_de_canal(c)    ## REENVÍO M1

static func altura_en(c: Vector2i) -> int:
	return Terreno3D.altura_en(c)    ## REENVÍO M1

static func fijar_altura(c: Vector2i, niveles: int) -> void:
	Terreno3D.fijar_altura(c, niveles)    ## REENVÍO M1

static func y_pies(c: Vector2i) -> float:
	return Terreno3D.y_pies(c)    ## REENVÍO M1

static func celda_solida(c: Vector2i, nivel: int) -> bool:
	return Terreno3D.celda_solida(c, nivel)    ## REENVÍO M1

static func calcular_huellas(p_mundo: Node3D) -> int:
	return Terreno3D.calcular_huellas(p_mundo)    ## REENVÍO M1

static func es_parcial(c: Vector2i) -> bool:
	return Terreno3D.es_parcial(c)    ## REENVÍO M1

static func choca_huella(c: Vector2i, p: Vector3) -> bool:
	return Terreno3D.choca_huella(c, p)    ## REENVÍO M1

static func pisable(c: Vector2i, nivel: int, sube: bool, max_nivel: int, nada: bool, ignora_bloqueo: bool = false) -> bool:
	return Terreno3D.pisable(c, nivel, sube, max_nivel, nada, ignora_bloqueo)    ## REENVÍO M1

static func linea_libre(a: Vector3, b: Vector3) -> bool:
	return Terreno3D.linea_libre(a, b)    ## REENVÍO M1


static func montar_agua_sim(sub: int = 3) -> AguaSim3D:    ## REENVÍO M1 (y refresca el espejo agua_sim)
	agua_sim = Terreno3D.montar_agua_sim(sub)
	return agua_sim

## --- Agua con física (Fase 11.3, 12/10) ---
## Si es false, todo sigue como antes (el agua es la letra «~»). Se puede apagar sin tocar nada más.
static var agua_con_fisica: bool = true
## Agua echada por un hechizo (11.4), en u³. Un impacto de agua es un charco; cada casilla marcada por un muro o un corro, otro.
## 12/10 (Pablo): un 80 % menos (1,2 → 0,24): el agua convocada debe ser sutil; ya se escalará en hechizos grandes.
const VOL_AGUA_IMPACTO: float = ReaccionesAgua3D.VOL_AGUA_IMPACTO    ## REENVÍO M3
## Lo que se evapora por un impacto de fuego (u³): un charco desaparece, un río apenas nota un bocado.
## (Un 80 % menos, como el agua que se echa: 1,5 → 0,3.)
const VOL_EVAPORA: float = ReaccionesAgua3D.VOL_EVAPORA    ## REENVÍO M3
## Caudal (u³/s) que aporta CADA casilla de un chorro de agua mientras el chorro dura.
## (12/10, Pablo: un 80 % menos, 0,8 → 0,16.)
const CAUDAL_CHORRO_CELDA: float = 0.16
## --- Hielo de verdad (11.13) ---
## Radio (en casillas) del círculo que hiela o funde un impacto. 0,6 casillas = una casilla casi entera, pero sigue la forma del agua.
const RADIO_HIELO: float = ReaccionesAgua3D.RADIO_HIELO    ## REENVÍO M3


## Nombre de elemento (el de Vfx3D) de una runa.
static func elemento_de(rune: RuneData) -> String:
	return Objetos.elemento_de(rune)


## =====================================================================================================
##  Arranque
## =====================================================================================================

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS      # para deshacer la pausa del libro (5.2)
	add_to_group("player")      # el libro busca ahí un nodo 2D desde el que sonar (Sfx)
	Repertoire.aim_with_mouse = true
	aplicar_progresion(progresion_de(mundo))
	if agua_con_fisica and mundo != null:
		montar_agua_sim()


## Qué progresión toca (11.15): PROGRESION_FORZADA si no está vacía; si no, el `kit` del mundo (si lo tiene y no está vacío); si no,
## el nombre del nivel como hasta ahora; y «todo» si no hay mundo. El kit existe para que un mismo nivel (el Bosque) pueda
## montarse con otro repertorio sin cambiar su nombre ni su progresión de juego.
static func progresion_de(p_mundo: Node) -> String:
	if PROGRESION_FORZADA != "":
		return PROGRESION_FORZADA
	if p_mundo != null:
		var kit: Variant = p_mundo.get("kit")
		if kit != null and String(kit) != "":
			return String(kit)
		var nivel: Variant = p_mundo.get("nivel")
		if nivel != null:
			return String(nivel)
	return "todo"


## Fija el repertorio (qué sellos y glifos se enseñan y se pueden usar), cuántas páginas hay y cuántos glifos caben en una.
## Devuelve el nombre de la progresión que se aplicó. Un nombre desconocido aplica «todo».
static func aplicar_progresion(nombre: String) -> String:
	# El nombre del nivel llega como lo escribe la escena («Bosque»); las progresiones van en minúsculas.
	var clave: String = nombre if PROGRESIONES.has(nombre) else (nombre.to_lower() if PROGRESIONES.has(nombre.to_lower()) else "todo")
	var p: Dictionary = PROGRESIONES[clave]
	Repertoire.max_sigils_per_page = int(p["glifos_por_pagina"])
	Repertoire.max_pages = int(p["paginas"])
	Repertoire.libro = String(p.get("libro", ""))
	var cap: Array = p.get("capacidad", [0, 0])
	Repertoire.fijar_capacidad(int(cap[0]), int(cap[1]))
	Repertoire.set_active(PackedStringArray(p["sellos"]), PackedStringArray(p["glifos"]))
	return clave


## No se puede elegir una página que aún no tienes.
func select_page(indice: int) -> void:
	if indice >= Repertoire.pages_available(PAGES):
		return
	super.select_page(indice)


## El libro y las pestañas de página, en una capa propia. Lo llama Jugador3D.montar() tras poner `mundo`.
func construir_interfaz() -> void:
	capa_ui = CanvasLayer.new()
	capa_ui.layer = 10
	capa_ui.name = "InterfazLanzador"
	add_child(capa_ui)

	var paginas := Control.new()
	paginas.set_script(load("res://presentacion/ui/page_hud.gd"))
	_page_hud = paginas
	capa_ui.add_child(paginas)
	paginas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# La paleta de pruebas (F1 la esconde): glifos y elementos con un clic, sin dibujar. En 3D no estaba montada; la usan
	# las pruebas de la Fase 8 mientras Pablo no tenga todos los gestos grabados (8.3).
	if PALETA_RUNAS:
		var paleta := PanelContainer.new()
		paleta.set_script(load("res://presentacion/ui/rune_palette.gd"))
		capa_ui.add_child(paleta)

	# 24/10: el MENÚ CON PESTAÑAS (I = Inventario, J = Misiones) sustituye a la mochila-bolsa (`BolsaUI`, ya no se monta) y al diario suelto (`DiarioMisiones`,
	# del que el menú reutiliza la lista y la ficha). Pausa el árbol; el lanzador es ALWAYS. La línea de la misión seguida sigue en el HUD.
	menu = MenuPestanas.new()
	capa_ui.add_child(menu)
	capa_ui.add_child(MisionHud.new())

	libro = Control.new()
	libro.process_mode = Node.PROCESS_MODE_ALWAYS
	libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	libro.set_script(load("res://presentacion/ui/spellbook.gd"))
	capa_ui.add_child(libro)
	libro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 24)
	_aviso.add_theme_color_override("font_outline_color", AVISO_BORDE)
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.modulate.a = 0.0
	capa_ui.add_child(_aviso)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_aviso.offset_top = 90.0
	_aviso.offset_bottom = 130.0

	_guia = Label.new()
	_guia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guia.add_theme_font_size_override("font_size", 18)
	_guia.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_guia.add_theme_constant_override("outline_size", 5)
	_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guia.visible = false
	capa_ui.add_child(_guia)
	_guia.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_guia.offset_top = -120.0
	_guia.offset_bottom = -90.0
	_guia.offset_left = -420.0
	_guia.offset_right = 420.0


## Aviso en pantalla (se apaga solo). Lo usan también Jugador3D y Combate3D.
## `borde`: color del contorno del texto (el de la calidad al coger un material: AvisoObjeto). `duracion`: segundos que se queda antes de apagarse.
func avisar(texto: String, color: Color = Color(1, 0.9, 0.6), borde: Color = AVISO_BORDE, duracion: float = AVISO_DURA) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	AvisoObjeto.estilo_comun(_aviso)          # respaldo oscuro suave; el de calidad lo pone AvisoObjeto.mostrar_texto después de este aviso
	_aviso.add_theme_color_override("font_color", color)
	_aviso.add_theme_color_override("font_outline_color", borde)
	_aviso.modulate.a = 1.0
	if _tw_aviso != null and _tw_aviso.is_valid():
		_tw_aviso.kill()                      # un aviso nuevo no hereda el apagado del anterior
	_tw_aviso = _aviso.create_tween()
	_tw_aviso.tween_interval(duracion)
	_tw_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)


## =====================================================================================================
##  Las reglas del libro (4.1)
## =====================================================================================================

## Un glifo por sector. Va aquí y no en el libro porque por esta función entran los dos caminos ($P y atajo de raya).
func add_sigil(sector: Vector2, sigil_name: String, calidad: float = 1.0) -> void:
	if Repertoire.sigil_active(Sigils.repertorio_de(sigil_name)):
		for c in current_components:
			if (c["direction"] as Vector2).is_equal_approx(sector) and not (c["sigils"] as Array).is_empty():
				Sfx.play(self, "sello_no")
				_feedback("Hueco ocupado: ya hay '%s'" % String((c["sigils"] as Array)[0]))
				PlayLog.event("fallo", {"tipo": "hueco_ocupado", "nuevo": sigil_name,
					"ocupado": String((c["sigils"] as Array)[0])})
				PlayLog3D.gesto("rechazado", sigil_name)
				return
	super.add_sigil(sector, sigil_name, calidad)


## La paleta de pruebas (F1) pone todos los glifos en el sector de la derecha, y la regla «un glifo por sector» rechazaría
## el segundo. Aquí cada glifo de la paleta va al PRIMER sector libre de los 8 del libro (el mismo reparto que haría
## alguien dibujando), para poder probar recetas de varios glifos (Línea + Altura…) sin grabar los gestos.
func place_sigil(sigil_name: String) -> void:
	var paso: float = TAU / 8.0
	# Láminas con huecos que se desbloquean (libro «bosque»): solo se pone en un hueco ABIERTO, igual que un trazo dibujado.
	var candidatos: Array = []
	if libro != null and libro.has_method("restringe_huecos") and bool(libro.call("restringe_huecos")):
		candidatos = libro.call("sectores_abiertos")
		if candidatos.is_empty():
			_feedback("No hay ningún hueco de glifo abierto")
			return
	else:
		for i in range(8):
			candidatos.append(Vector2(cos(paso * float(i)), sin(paso * float(i))) if i > 0 else Vector2.RIGHT)
	for sector in candidatos:
		var libre: bool = true
		for c in current_components:
			if (c["direction"] as Vector2).is_equal_approx(sector) and not (c["sigils"] as Array).is_empty():
				libre = false
				break
		if libre:
			add_sigil(sector, sigil_name, 1.0)
			return
	_feedback("Los 8 huecos de la página están ocupados")


## Cuenta cada gesto como reconocido, rechazado o confundido para la tabla de PlayLog3D (4.5).
func add_gesture(strokes: Array, sector: Vector2) -> void:
	var antes_sellos: int = sigils_used()
	var antes_elemento: Runes.Type = current_element
	var antes_aviso: int = feedback_until
	super.add_gesture(strokes, sector)
	var cambio: bool = sigils_used() != antes_sellos or current_element != antes_elemento
	if cambio:
		PlayLog3D.gesto("reconocido", "elemento" if sector == Vector2.ZERO else "glifo")
	elif feedback_until != antes_aviso:
		if feedback_text.contains("se parece a"):
			PlayLog3D.gesto("confundido", feedback_text)
		elif not feedback_text.begins_with("Hueco ocupado"):
			PlayLog3D.gesto("rechazado", feedback_text)


## =====================================================================================================
##  Lanzar una página: modo lanzar (4.1b)
## =====================================================================================================

## Al cerrar el libro se lanza la página en la que estabas. El libro fijó el sitio al abrir; aquí no hace falta:
## el hechizo se apunta DESPUÉS, en el modo lanzar.
func cast_current() -> void:
	_fin_libro_lento()
	cast_page(page)


## Lo llama el libro justo ANTES de abrirse (y de pausar el árbol). 5.2: el libro ya no pausa; el tiempo va al
## TIEMPO_LIBRO y `_process` deshace la pausa que pone spellbook.gd mientras el libro esté abierto.
func remember_aim() -> void:
	if not _libro_lento:
		_libro_lento = true
		_ts_libro = Engine.time_scale
		Engine.time_scale = TIEMPO_LIBRO


func _fin_libro_lento() -> void:
	if _libro_lento:
		_libro_lento = false
		Engine.time_scale = 1.0 if _ts_libro <= 0.0 else _ts_libro


func libro_abierto() -> bool:
	return libro != null and bool(libro.get("is_open"))


## 8.8: ¿se puede lanzar una receta con estos glifos? Devuelve "" si sí, o el aviso. Pensado para que el libro avise ANTES de
## cerrarlo (spellbook.gd es de Pablo: la llamada la pone él; mientras, `cast_page` ya se niega con este mismo aviso).
static func aviso_receta(glifos: Array, rune: RuneData = null) -> String:
	var receta := Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		receta.apply(String(gl))
	if rune != null:
		return GeometriaV2.aviso_materia(receta.geo(), rune)       # R2: depende del estado del elemento
	return ""


## El modo de siempre (libro / pruebas / mando): valida la página y entra en el modo de apuntar BLOQUEANDO a la jugadora a `RALENTIZADO`. Es lo que llaman los
## escenarios y `lanzar_pagina_ya`. Las teclas 1/2/3 con el libro cerrado NO pasan por aquí: usan `pulsar_pagina` / `soltar_pagina` (A1, lanzamiento rápido).
func cast_page(indice: int) -> void:
	if _preparar_pagina(indice):
		_entrar_modo_lanzar()


## Todas las comprobaciones de `cast_page` (recarga, tinta, altura, glifos sin uso…) y, si pasan, deja la página lista en `_preparado`. Devuelve false si se negó
## (con su aviso). No toca el tiempo ni la jugadora: de ahí cuelgan los dos modos, el de siempre (`cast_page`) y el rápido (`pulsar_pagina`).
func _preparar_pagina(indice: int) -> bool:
	if indice < 0 or indice >= Repertoire.pages_available(PAGES):
		return false
	if modo_lanzar:
		_cancelar_modo()
	if jugador != null and not bool(jugador.call("puede_lanzar")):
		_feedback("Ahora no puedes lanzar")
		Sfx.play(self, "sello_no")
		return false

	var ficha: Dictionary = pages[indice]
	var element_data: RuneData = rune_database.get(ficha["element"])
	var componentes: Array = ficha["components"]
	if element_data == null:
		_feedback("La página %d no tiene elemento" % (indice + 1))
		return false
	if not Repertoire.element_active(_gesture_name_of(ficha["element"])):
		_feedback("Ese elemento ya no está activo")
		return false
	if componentes.is_empty():
		_feedback("A la página %d le falta algún glifo" % (indice + 1))
		return false
	if cooldown_left[indice] > 0.0:
		Sfx.play(self, "sello_no")
		_feedback("Recargando (%.1f s)" % cooldown_left[indice])
		PlayLog.event("cast_bloqueado", {"pagina": indice + 1, "queda": snappedf(cooldown_left[indice], 0.1)})
		return false

	# UNA RECETA POR PÁGINA: los glifos de todos los sectores se funden en un solo hechizo.
	var fusion: Dictionary = {"sigils": [], "quality": []}
	for c in componentes:
		(fusion["sigils"] as Array).append_array(c["sigils"])
		(fusion["quality"] as Array).append_array(c.get("quality", []))
	for s in fusion["sigils"]:
		if not Repertoire.sigil_active(Sigils.repertorio_de(s)):
			_feedback("Un glifo de la página ya no está activo")
			return false

	var calidad: float = float(ficha.get("element_q", 1.0))
	for q in fusion["quality"]:
		calidad = minf(calidad, float(q))

	var receta := Receta3D.new(Vector2.RIGHT)
	for s in fusion["sigils"]:
		receta.apply(s)
	# Flecha y barrera solo orientan el eje: el glifo de "lejos" (origin) no las desplaza. Que la barrera nazca donde apuntas lo decide `Hechizo.en_punto` (más abajo).
	if receta.travels or receta.spread:
		receta.origin = 0.0
	receta.calidad = calidad
	# 8.6: el tope de altura combinado. Si lo supera, se avisa y NO se lanza (no se recorta en silencio).
	# R2: el tope de pisar depende del ESTADO del elemento (un sólido más alto de lo que se sube no se lanza).
	var aviso_v2: String = GeometriaV2.aviso_materia(receta.geo(), element_data)
	if aviso_v2 != "":
		Sfx.play(self, "sello_no")
		_feedback(aviso_v2)
		PlayLog.event("cast_rechazado_altura", {"pagina": indice + 1, "y_tope": int(receta.geo()["y_tope"]), "glifos": (fusion["sigils"] as Array).duplicate()})
		return false
	# R3: los glifos aparcados (retardo, atracción, espejo, amplificar) no rompen nada: se dibujan, se avisa y no hacen nada.
	if not receta.ignorados.is_empty():
		_feedback("Aún sin uso: %s" % ", ".join(receta.ignorados))
		PlayLog.event("glifo_sin_uso", {"pagina": indice + 1, "glifos": Array(receta.ignorados)})

	# TINTA (15/10): se comprueba aquí, antes de apuntar, para no ralentizar el tiempo y luego negarte el lanzamiento. Se COBRA al soltar
	# (`lanzar_ahora`): si cancelas el apuntado no pierdes nada.
	var coste_tinta: float = Tinta.coste_receta(receta.coste_v2())
	if tinta != null:
		coste_tinta = tinta.coste_efectivo(coste_tinta, Objetos.elemento_de(element_data))     # E1: la rebaja del pigmento (la aplica Tinta, aquí solo se le dice el elemento)
	if tinta != null and not tinta.puede_pagar(receta.forma(), coste_tinta):
		Sfx.play(self, "sello_no")
		_feedback("Tinta insuficiente (%d / %d)" % [int(ceil(tinta.actual)), int(ceil(coste_tinta))])
		PlayLog.event("cast_sin_tinta", {"pagina": indice + 1, "forma": receta.forma(), "coste": snappedf(coste_tinta, 0.1), "hay": snappedf(tinta.actual, 0.1)})
		return false

	_preparado = {"indice": indice, "receta": receta, "rune": element_data, "calidad": calidad,
		"glifos": (fusion["sigils"] as Array).duplicate(),
		"elemento_nombre": _gesture_name_of(ficha["element"]),
		"en_punto": receta.hechizo(element_data).en_punto}      # 18/10: «nace donde apuntas» (cast on point); lo pide un glifo (la barrera)
	return true


## 27/10 · A1 LANZAMIENTO RÁPIDO (docs/PROPUESTA_COMBATE.md §1.1). Las teclas 1/2/3 con el libro cerrado: al PULSAR la página entra en un modo de apuntar corto (`TIEMPO_PAGINA`,
## sin bloquear a la jugadora: anda mientras apunta) con los mismos marcadores y la misma previsualización de siempre, pegados al ratón; al SOLTAR esa misma tecla (`soltar_pagina`)
## lanza hacia donde está el ratón; clic derecho o Esc cancelan sin cobrar y soltar después ya no hace nada. Un toque corto lanza igual. Mientras dura, otra página se ignora.
## Con `lanzamiento_inteligente` pulsar lanza al instante hacia el ratón, sin indicador. Si la página no se puede lanzar (recarga, tinta…) avisa y no entra en nada.
func pulsar_pagina(indice: int) -> void:
	if modo_lanzar and _rapido:
		return                                   # ya hay una página en la mano: la otra tecla se ignora hasta soltar o cancelar
	if not _preparar_pagina(indice):
		return
	if lanzamiento_inteligente:
		_lanzar_al_instante()
		return
	_entrar_modo_lanzar(true, indice)


## Suelta la tecla de página: si es la que está apuntando en modo rápido, lanza. Si el modo ya se canceló (clic derecho, Esc, tinta…) o es otra página, no hace nada.
func soltar_pagina(indice: int) -> void:
	if not (modo_lanzar and _rapido and indice == _pagina_rapida):
		return
	_actualizar_raton_rapido()
	_soltar()


## El lanzamiento inteligente: sin modo ni indicador, de la jugadora hacia el ratón (o del punto del ratón recortado, si el hechizo nace donde apuntas), con el conjuro de siempre.
func _lanzar_al_instante() -> void:
	_fijado = false
	_actualizar_raton_rapido()
	var origen: Vector3 = _origen_vivo
	var dir: Vector3 = _direccion_actual()
	var datos: Dictionary = _preparado
	_preparado = {}
	if lanzar_ahora(datos, origen, dir, true):
		PlayLog.event("lanzamiento_inteligente", {"pagina": int(datos["indice"]) + 1})


## Lee el ratón AHORA y recalcula origen y puntero. En el modo rápido se hace cada fotograma: la jugadora se mueve aunque el ratón esté quieto.
func _actualizar_raton_rapido() -> void:
	var vp: Viewport = get_viewport()
	if vp != null and jugador != null:
		_actualizar_puntero(vp.get_mouse_position())


## 15/10 (Fase 13.10, escenarios) · Lanza la página SIN el modo de apuntar: lo que hacen `cast_page` y luego soltar el botón, pero con
## el origen y la dirección dados. Existe para los escenarios de `herramientas/` (que no tienen ratón ni cámara que apunte) y para
## cualquier mando futuro que no apunte con el puntero. Devuelve false si `cast_page` se negó (recarga, sin glifos, altura de más…).
## Por qué aquí y no en la prueba: salir del modo toca estado privado (`_preparado`, el tiempo ralentizado) que no debe manejar de fuera.
## `con_conjuro` (false por defecto: los escenarios existentes esperan el hechizo al instante) pasa por la secuencia del conjuro.
func lanzar_pagina_ya(indice: int, origen: Vector3, dir: Vector3, con_conjuro: bool = false) -> bool:
	cast_page(indice)
	if not modo_lanzar:
		return false
	var datos: Dictionary = _preparado
	_salir_modo(true)
	_preparado = {}
	return lanzar_ahora(datos, origen, dir, con_conjuro)


## `rapido` (A1): el modo de las teclas 1/2/3 — tiempo a `TIEMPO_PAGINA`, la jugadora NO se bloquea (anda a paso normal) y se lanza al soltar la tecla de `pagina`.
func _entrar_modo_lanzar(rapido: bool = false, pagina: int = -1) -> void:
	modo_lanzar = true
	_rapido = rapido
	_pagina_rapida = pagina
	_fijado = false
	_ms_modo = Time.get_ticks_msec()
	_ts_antes = Engine.time_scale
	var tiempo: float = TIEMPO_PAGINA if rapido else RALENTIZADO
	Engine.time_scale = tiempo
	var rune: RuneData = _preparado["rune"]
	var forma: String = (_preparado["receta"] as Receta3D).forma()
	if jugador != null:
		if rapido:
			jugador.call("apuntar_en_marcha", true)
		else:
			jugador.call("bloquear", true)
		jugador.call("apuntar_lanzar", Objetos.elemento_de(rune), (_preparado["receta"] as Receta3D).forma_vfx(), tiempo)
	_crear_marcadores(rune.color)
	if rapido:
		_actualizar_raton_rapido()                # ya desde el primer fotograma: un toque corto lanza hacia el ratón de ahora
	if _guia != null:
		_guia.text = ("Suelta [%d] para lanzar · clic derecho o Esc cancela" % (pagina + 1)) if rapido \
			else "Apunta con el ratón · arrastra para dirigir · suelta para lanzar · clic derecho o Esc cancela"
		_guia.visible = true
	modo_cambiado.emit(true)
	PlayLog.event("modo_lanzar", {"pagina": int(_preparado["indice"]) + 1, "forma": forma, "rapido": rapido})


## `lanzando` true = se sale para LANZAR (el libro se queda en la mano hasta que acabe el lanzamiento, T-CP1); false = se cancela (el libro vuelve al cinto).
func _salir_modo(lanzando: bool = false) -> void:
	var era_rapido: bool = _rapido
	modo_lanzar = false
	_rapido = false
	_pagina_rapida = -1
	_fijado = false
	Engine.time_scale = 1.0 if _ts_antes <= 0.0 else _ts_antes
	if _guia != null:
		_guia.visible = false
	for m in [_marca_origen, _marca_flecha, _marca_alcance]:
		if m != null and is_instance_valid(m):
			(m as Node).queue_free()
	_marca_origen = null
	_marca_flecha = null
	_marca_alcance = null
	if _vista_reaccion != null and is_instance_valid(_vista_reaccion):
		_vista_reaccion.queue_free()
	_vista_reaccion = null
	if _apuntado != null and is_instance_valid(_apuntado):
		_apuntado.queue_free()
	_apuntado = null
	_poner_cursor(Color.WHITE, false, false)
	for m in _prev_casillas:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_prev_casillas.clear()
	if jugador != null:
		if era_rapido:
			jugador.call("apuntar_en_marcha", false)      # A1: no se la bloqueó al entrar, así que no se «desbloquea» (otra cosa pudo bloquearla entretanto)
		else:
			jugador.call("bloquear", false)
		jugador.call("terminar_apuntar", lanzando)
	modo_cambiado.emit(false)


func _cancelar_modo() -> void:
	if not modo_lanzar:
		return
	_salir_modo()
	_preparado = {}
	PlayLog.event("modo_lanzar_cancelado")


func _unhandled_input(ev: InputEvent) -> void:
	if not modo_lanzar:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		_cancelar_modo()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancelar_modo()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not _rapido:       # A1: en el modo rápido el clic izquierdo no fija origen ni arrastra: apunta el ratón y suelta la tecla
			if mb.pressed:
				_actualizar_puntero(mb.position)
				_fijado = true
				_origen_fijo = _origen_vivo
			elif _fijado:
				_actualizar_puntero(mb.position)
				_soltar()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and not _rapido:       # en el modo rápido el ratón se lee cada fotograma (`_actualizar_raton_rapido`)
		_actualizar_puntero((ev as InputEventMouseMotion).position)


## Rayo cámara → plano del suelo (a la altura de los pies del jugador).
func punto_en_suelo(pos_pantalla: Vector2) -> Vector3:
	if camara == null or jugador == null:
		return Vector3.ZERO
	var o: Vector3 = camara.project_ray_origin(pos_pantalla)
	var d: Vector3 = camara.project_ray_normal(pos_pantalla)
	var y: float = float(jugador.call("y_pies_actual"))
	if absf(d.y) < 0.0001:
		return Vector3(o.x, y, o.z)
	var t: float = (y - o.y) / d.y
	return o + d * t


func _actualizar_puntero(pos_pantalla: Vector2) -> void:
	_punto_vivo = punto_en_suelo(pos_pantalla)
	_calcular_origen_vivo()


## De dónde nace lo que se lanza, según el punto apuntado (`_punto_vivo`). Aparte de `_actualizar_puntero` para poder probarlo sin cámara.
func _calcular_origen_vivo() -> void:
	var yo: Vector3 = (jugador as Node3D).position
	var hacia: Vector3 = _punto_vivo - yo
	hacia.y = 0.0
	# 5.1: el ratón da SOLO la dirección; todo nace en el jugador (lanzar lejos trivializaba el puzle).
	# 18/10: salvo un hechizo con `en_punto` (la barrera): nace en el punto apuntado, pero sin salir del anillo de ALCANCE_ORIGEN (no se lanza a cualquier parte).
	_origen_vivo = yo
	if bool(_preparado.get("en_punto", false)):
		var tope: float = ALCANCE_ORIGEN * Terreno3D.casilla
		if hacia.length() > tope:
			hacia = hacia.normalized() * tope
		_origen_vivo = Vector3(yo.x + hacia.x, yo.y, yo.z + hacia.z)


## Dirección con la que sale ahora: el arrastre desde el origen fijado; sin arrastre, de ti hacia el origen.
func _direccion_actual() -> Vector3:
	var yo: Vector3 = (jugador as Node3D).position
	if _fijado:
		var arr: Vector3 = _punto_vivo - _origen_fijo
		arr.y = 0.0
		if arr.length() >= ARRASTRE_MINIMO * Terreno3D.casilla:
			return arr.normalized()
	var de_ti: Vector3 = (_origen_fijo if _fijado else _origen_vivo) - yo
	de_ti.y = 0.0
	if de_ti.length() > 0.2:
		return de_ti.normalized()
	var al_puntero: Vector3 = _punto_vivo - yo         # nace en ti: sale hacia donde señala el ratón
	al_puntero.y = 0.0
	if al_puntero.length() > 0.2:
		return al_puntero.normalized()
	var m: Vector3 = jugador.call("mirada")
	return m if m.length() > 0.01 else Vector3(0, 0, 1)


## La mochila llama aquí al pulsar una poción (el nodo "player" es el lanzador; el que bebe es el jugador).
func usar_pocion() -> void:
	if jugador != null:
		jugador.call("usar_pocion")


func _process(delta: float) -> void:
	if libro_abierto():
		if get_tree().paused:
			get_tree().paused = false        # 5.2: el libro de spellbook.gd pausa; aquí solo se ralentiza
	elif _libro_lento:
		_fin_libro_lento()                   # cerrado por otro camino (sin lanzar)
	if get_tree().paused:
		return                               # pausa real (muerte, victoria): nada se mueve
	if Terreno3D.agua_sim != null:
		Terreno3D.agua_sim.paso(delta)                 # avanza en pasos fijos por dentro; con el libro abierto va más lento, como todo
		for cb in Terreno3D.agua_sim.cambios():
			agua_cambio.emit(cb["c"], cb["agua"])
			Terreno3D._avisar(cb["c"], "agua")       # M2: lo mismo, para quien escuche a Mundo3D
		procesar_cambios_hielo()             # 11.13: el hielo que se suelta solo al acabar su tiempo
		vigilar_presos()                     # 11.15: grietas en la costra cuando al hielo le queda poco
	ReaccionesSuelo3D.sincronizar_hierba(mundo)      # 21/10: «quemada» de la hierba que arde (y se quita si el agua la apaga)
	super._process(delta)
	if conjurando:
		_t_conjuro += delta
	_avanzar_caducidades(delta)
	if modo_lanzar:
		if Time.get_ticks_msec() - _ms_modo > int(TIEMPO_MAX_MODO * 1000.0):
			avisar("Lanzamiento cancelado")
			_cancelar_modo()
			return
		if _rapido:
			_actualizar_raton_rapido()      # A1: ella se mueve aunque el ratón esté quieto: origen y previsualización se recalculan cada fotograma
		_pintar_marcadores()
		if jugador != null:
			jugador.call("mirar_hacia", _direccion_actual())


func _soltar() -> void:
	var origen: Vector3 = _origen_fijo if _fijado else _origen_vivo
	var dir: Vector3 = _direccion_actual()
	var datos: Dictionary = _preparado
	# Un sólido quieto que no cabe donde apuntas se avisa y se SIGUE apuntando (sin salir del modo, sin cobrar): el jugador reapunta o cancela.
	if not datos.is_empty():
		var motivo: String = rechazo_de_construccion(datos, origen)
		if motivo != "":
			_avisar_sin_construir(motivo)
			if _rapido:
				_cancelar_modo()          # A1: la tecla sigue pulsada, pero no se sigue apuntando: se cancela (no cobra) y soltarla luego no hace nada
			else:
				_fijado = false
			return
	_salir_modo(not datos.is_empty())
	_preparado = {}
	if datos.is_empty():
		return
	lanzar_ahora(datos, origen, dir, true)


## El aviso de «ahí no se puede construir» (también en `feedback_text`, que es lo que leen las pruebas y los escenarios).
func _avisar_sin_construir(motivo: String) -> void:
	var texto: String = "Ahí no se puede construir: %s" % motivo
	feedback_text = texto
	avisar(texto)
	Sfx.play(self, "sello_no")
	PlayLog.event("cast_rechazado_construccion", {"motivo": motivo})


## Lo que pasa al soltar: animación, cobro, recarga y (tras el conjuro, si lo hay) el disparo. Público para las pruebas.
## `con_conjuro` false = el disparo sale en el mismo fotograma, como antes de la Fase 14.5.
## Devuelve false si un sólido quieto no cabe donde nace (aviso y NADA se cobra: ni tinta ni recarga); true si se lanzó.
func lanzar_ahora(datos: Dictionary, origen: Vector3, dir: Vector3, con_conjuro: bool = false) -> bool:
	var motivo_no: String = rechazo_de_construccion(datos, origen)
	if motivo_no != "":
		_avisar_sin_construir(motivo_no)
		return false
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var indice: int = int(datos["indice"])
	var elemento: String = Objetos.elemento_de(rune)
	var forma: String = receta.forma()
	_cast_point = {}
	if jugador != null:
		jugador.call("mirar_hacia", dir)
		# T-CP1: el cast point sale del nombre DERIVADO de la receta (x_mano · alto · abajo → variación de CastPoints). Sin variación o sin clip: como siempre.
		var punto: String = CastPoints.variacion_de(String(receta.geo().get("nombre", "")))
		jugador.call("lanzar_clip", elemento, receta.forma_vfx(), punto)
		var activo: String = String(jugador.call("punto_cast")) if jugador.has_method("punto_cast") else ""
		if activo != "":
			_cast_point = {"id": activo, "origen": String(CastPoints.datos(activo)["origen"]), "dir": dir, "origen_mundo": origen, "elemento": elemento}

	if tinta != null:
		tinta.gastar(forma, Tinta.coste_receta(receta.coste_v2()), elemento)       # E1: con el elemento, para la rebaja del pigmento

	# Recarga y coste al SOLTAR: durante el conjuro la página ya no se puede volver a lanzar.
	cooldown_total[indice] = receta.cooldown
	cooldown_left[indice] = receta.cooldown

	var tiempos: Array = tiempos_conjuro(elemento)
	if con_conjuro and conjuro_activo and is_inside_tree() and not _cast_point.is_empty() and conjuro_escala > 0.0:
		_conjurar_punto(datos, origen, dir)       # el clip manda: el hechizo nace en el `instante` del cast point
	elif con_conjuro and conjuro_activo and is_inside_tree() and (float(tiempos[0]) + float(tiempos[1]) + float(tiempos[2])) > 0.0:
		_conjurar(datos, origen, dir, tiempos)    # sin clip de cast point: el reloj de RETARDO_CONJURO, como antes
	else:
		_disparar(datos, origen, dir, 0.0)
	return true


## Los tres tiempos [runa, voluta, forma] de un elemento, ya con `conjuro_escala`.
func tiempos_conjuro(elemento: String) -> Array:
	var base: Array = RETARDO_CONJURO.get(elemento, RETARDO_CONJURO["defecto"])
	var k: float = maxf(conjuro_escala, 0.0)
	return [float(base[0]) * k, float(base[1]) * k, float(base[2]) * k]


## Segundos que pasan entre soltar y que salga el hechizo (la suma de los tres tiempos).
func retardo_total(elemento: String) -> float:
	var t: Array = tiempos_conjuro(elemento)
	return float(t[0]) + float(t[1]) + float(t[2])


## La secuencia. Usa temporizadores que respetan la pausa y el `time_scale` (como todo lo del mundo).
func _conjurar(datos: Dictionary, origen: Vector3, dir: Vector3, tiempos: Array) -> void:
	var rune: RuneData = datos["rune"]
	var elemento: String = Objetos.elemento_de(rune)
	var indice: int = int(datos["indice"])
	var color: Color = rune.color
	_t_conjuro = 0.0
	conjurando = true
	# 1. La runa brilla en la página.
	conjuro_fase.emit("runa", elemento, _pos_mano())
	_sonar_fase_v2("carga", elemento)
	if _page_hud != null and _page_hud.has_method("destello"):
		_page_hud.call("destello", indice, float(tiempos[0]) + 0.15)
	await get_tree().create_timer(float(tiempos[0]), false).timeout
	# 2. La voluta del libro a la mano.
	var libro_p: Vector3 = _pos_libro()
	conjuro_fase.emit("voluta", elemento, libro_p)
	_voluta(libro_p, color, float(tiempos[1]))
	await get_tree().create_timer(float(tiempos[1]), false).timeout
	# 3. La forma se crece en la mano.
	var mano: Vector3 = _pos_mano()
	conjuro_fase.emit("forma", elemento, mano)
	var esfera: MeshInstance3D = null if forma_externa else _forma_en_mano(mano, color, float(tiempos[2]))
	await get_tree().create_timer(float(tiempos[2]), false).timeout
	if is_instance_valid(esfera):
		esfera.queue_free()
	conjurando = false
	# Si el jugador murió mientras conjuraba, no sale nada (la tinta ya se gastó: se anota).
	if jugador != null and bool(jugador.get("muerto")):
		PlayLog.event("conjuro", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "interrumpido": true})
		return
	_disparar(datos, origen, dir, _t_conjuro)


## T-CP1: el conjuro cuando hay cast point. Las tres anticipaciones (runa, voluta, forma) se reparten el tiempo que tarda el CLIP en llegar a su `instante`
## (CastPoints: `anticipacion`) y el disparo NO sale por reloj sino cuando el clip llega a ese instante, mirado fotograma a fotograma (el reloj solo es el
## respaldo: si el clip no avanza —pausa, sin esqueleto— sale al acabar el tiempo previsto + 0,6 s). `conjuro_fase` lleva la posición del cast point
## en «forma» (la mano libre, sobre la cabeza o a los pies), que es donde crece la forma.
func _conjurar_punto(datos: Dictionary, origen: Vector3, dir: Vector3) -> void:
	var rune: RuneData = datos["rune"]
	var elemento: String = Objetos.elemento_de(rune)
	var indice: int = int(datos["indice"])
	var color: Color = rune.color
	var id: String = String(_cast_point["id"])
	var d: Dictionary = CastPoints.datos(id)
	var anticipacion: Array = d["anticipacion"]
	var total: float = maxf(float(jugador.call("tiempo_instante_cast")), 0.05)
	var instante: float = clampf(float(d["instante"]), 0.0, 1.0)
	_t_conjuro = 0.0
	conjurando = true
	conjuro_fase.emit("runa", elemento, _pos_mano())
	_sonar_fase_v2("carga", elemento)
	var t_runa: float = total * float(anticipacion[0])
	var t_voluta: float = total * float(anticipacion[1])
	var t_forma: float = total * float(anticipacion[2])
	if _page_hud != null and _page_hud.has_method("destello"):
		_page_hud.call("destello", indice, t_runa + 0.15)
	await get_tree().create_timer(maxf(t_runa, 0.001), false).timeout
	var libro_p: Vector3 = _pos_libro()
	conjuro_fase.emit("voluta", elemento, libro_p)
	_voluta(libro_p, color, t_voluta)
	await get_tree().create_timer(maxf(t_voluta, 0.001), false).timeout
	var punto: Vector3 = _pos_cast_point()
	conjuro_fase.emit("forma", elemento, punto)
	var esfera: MeshInstance3D = null if forma_externa else _forma_en_mano(punto, color, t_forma)
	# Espera al instante del clip (por fotograma). El respaldo por reloj evita quedarse esperando si el clip no avanza.
	var espera: float = 0.0
	var limite: float = t_forma + 0.6
	while espera < limite:
		var f: float = float(jugador.call("fraccion_cast"))
		if f < 0.0 or f >= instante - 0.0001:
			break
		await get_tree().process_frame
		espera += get_process_delta_time()
	if is_instance_valid(esfera):
		esfera.queue_free()
	conjurando = false
	if jugador != null and bool(jugador.get("muerto")):
		PlayLog.event("conjuro", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "interrumpido": true})
		return
	_medir_cast_point(instante, total)
	_disparar(datos, origen, dir, _t_conjuro)


## Lo que se mide al disparar con cast point: cuánto se desvió el fotograma del clip del `instante` pedido (objetivo ≤ 1 fotograma) y a qué distancia de la
## mano libre sale (con el origen en la mano, ≤ 0,15 u). Queda en `ultimo_castpoint` (para el lab y las pruebas) y en PlayLog `castpoint`.
func _medir_cast_point(instante: float, total: float) -> void:
	var f: float = float(jugador.call("fraccion_cast"))
	var dt: float = maxf(get_process_delta_time(), 0.0001)
	var desfase_s: float = (f - instante) * (total / maxf(instante, 0.0001)) if f >= 0.0 else 0.0
	var mano: Vector3 = _pos_mano()
	var punto: Vector3 = _pos_cast_point()
	ultimo_castpoint = {"id": String(_cast_point["id"]), "origen": String(_cast_point["origen"]), "instante": snappedf(instante, 0.001), "fraccion": snappedf(f, 0.001),
		"desfase_s": snappedf(desfase_s, 0.0001), "desfase_fotogramas": snappedf(desfase_s / dt, 0.01), "dist_mano": snappedf(mano.distance_to(punto), 0.001)}
	PlayLog.event("castpoint", ultimo_castpoint)


## Dónde nace el hechizo: el punto de CastPoints de la variación en curso, más su `desplazamiento` (que afina el laboratorio). Sin jugador: la mano.
func _pos_cast_point() -> Vector3:
	var p: Vector3 = _pos_mano()
	if jugador != null and jugador.has_method("posicion_punto_cast") and not _cast_point.is_empty():
		p = jugador.call("posicion_punto_cast", String(_cast_point["origen"]), _cast_point["dir"] as Vector3) as Vector3
	if not _cast_point.is_empty():
		p += CastPoints.desplazamiento_mundo(String(_cast_point["id"]), _cast_point["dir"] as Vector3)
	return p


## Para ConjuroVfx3D (148): de dónde sale el hechizo en curso y a qué punto del suelo va. `origen` es mano_libre · manos_alto · suelo_delante (sin cast point,
## mano_libre); `destino` es el punto del suelo (una casilla delante en el alto y el suelo; a tres casillas en el eje X). Se puede llamar en cualquier fase.
func origen_conjuro(_elemento: String = "") -> Dictionary:
	var o: String = String(_cast_point.get("origen", "mano_libre"))
	if not ["mano_libre", "manos_alto", "suelo_delante"].has(o):
		o = "mano_libre"
	var base: Vector3 = _cast_point.get("origen_mundo", jugador.global_position if jugador != null else Vector3.ZERO) as Vector3
	var dir: Vector3 = _cast_point.get("dir", Vector3.RIGHT) as Vector3
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	var casillas: float = 3.0 if o == "mano_libre" else 1.0
	var destino: Vector3 = base + dir * Terreno3D.casilla * casillas
	destino.y = Terreno3D.y_pies(celda_de(destino))
	return {"origen": o, "destino": destino}


## El disparo: lo que antes hacía `lanzar_ahora` tras cobrar. `retardo` = lo que tardó el conjuro (0 si no lo hubo).
func _disparar(datos: Dictionary, origen: Vector3, dir: Vector3, retardo: float) -> void:
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var indice: int = int(datos["indice"])
	var elemento: String = Objetos.elemento_de(rune)
	var forma: String = receta.forma()
	ultimo_disparo = {"pagina": indice + 1, "origen": origen, "dir": dir}
	conjuro_fase.emit("disparo", elemento, _pos_mano())
	_sonar_fase_v2("disparo", elemento)
	var hechizo: Hechizo = hechizo_de(datos)
	desplaza_mano = _salida_de_mano(hechizo, origen)
	var n: int = lanzar_hechizo(hechizo, origen, dir)
	desplaza_mano = Vector3.ZERO
	var ev: Dictionary = {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "glifos": datos["glifos"],
		"calidad": snappedf(float(datos["calidad"]), 0.01), "recarga": receta.cooldown, "forma": forma, "tinta": snappedf(tinta.actual if tinta != null else -1.0, 0.1),
		"origen": [snappedf(origen.x, 0.1), snappedf(origen.z, 0.1)], "manifestaciones": n}
	if retardo > 0.0:
		ev["retardo"] = snappedf(retardo, 0.01)
	PlayLog.event("cast", ev)
	_registrar_receta_v2(hechizo, datos, n)
	if retardo > 0.0:
		var t: Array = tiempos_conjuro(elemento)
		PlayLog.event("conjuro", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "runa": t[0], "voluta": t[1], "forma": t[2],
			"previsto": snappedf(float(t[0]) + float(t[1]) + float(t[2]), 0.01), "retardo": snappedf(retardo, 0.01), "interrumpido": false})
	PlayLog3D.manifestaciones(n, forma, elemento)
	lanzado.emit(elemento, forma, n)


## 28/10 · A2: el `Hechizo` que sale de una página preparada (`datos` de `_preparar_pagina`), tal cual lo lanza `_disparar` — con el pigmento de daño (E1) —, y con los `cambios_hechizo` del
## laboratorio encima (lo que añade `lanzar_hechizo`). Lo usan `_disparar` y la previsión (`PrevisionHechizo`), para que prevean EXACTAMENTE lo que sale. Devuelve null si la runa no se lanza.
func hechizo_de(datos: Dictionary) -> Hechizo:
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var hechizo: Hechizo = receta.hechizo(rune)
	if tinta != null and hechizo != null:
		hechizo.dano *= tinta.mult_dano(Objetos.elemento_de(rune))         # E1: pigmento de daño del elemento (único sitio; 1 si no toca). Se queda en el hechizo: golpe, área y escudo lo leen de ahí
	return hechizo


## 24/10 (Pablo: «que los proyectiles salgan de la mano real de la jugadora»): con un personaje con esqueleto, el proyectil nace EN LA MANO (el cast point de la
## variación en curso, o la mano que lanza si no hay) y no a `Hechizo.ALTURA_MANO_U` (0,9 u) sobre los pies, que no era la altura de ninguna mano (la de la
## jugadora está a ~0,40 u en el instante del cast). Cambia `altura_salida` (la altura de la mano sobre el suelo de su casilla: HechizoVivo suma ahí `elevacion`)
## y devuelve cuánto se aparta la mano de `origen` en el plano: `desplaza_mano`, que solo aplica el PROYECTIL al nacer (HechizoVivo._iniciar_proyectil); el
## volumen y sus casillas siguen saliendo de `origen`, para que la mano no cambie de casilla un hechizo. Sin esqueleto (laboratorios, pruebas) no cambia nada;
## y si el laboratorio sobrescribe `altura_salida` (`cambios`), manda él.
func _salida_de_mano(hechizo: Hechizo, origen: Vector3) -> Vector3:
	if hechizo == null or hechizo.velocidad <= 0.0 or jugador == null or not (jugador.get("pj") is Node3D):
		return Vector3.ZERO
	if hechizo.en_punto:
		return Vector3.ZERO                               # 24/10 (D-5): lo que se apunta (barrera + flecha) nace EN EL PUNTO apuntado, no en la mano ni a su altura (ESPEC §1.2)
	if String(_cast_point.get("origen", "mano_libre")) == "suelo_delante":
		return Vector3.ZERO                               # ese cast point está en el suelo: un proyectil que naciera ahí chocaría al salir; sale como siempre
	var mano: Vector3 = _pos_cast_point()
	var c: Vector2i = celda_de(mano)
	if not Terreno3D.en_mapa(c):
		return Vector3.ZERO
	# Con gravedad (la flecha de tierra, el agua en arco) sale como siempre: su alcance está pensado desde 0,9 u sobre los pies, y saliendo de la mano la
	# flecha de tierra chocaba con el borde de la casilla a 0,5 casillas en vez de caer a 0,7 (prueba_cast_points E2b, 24/10): ni con la altura de diseño
	# valía apartarla en el plano. La Cueva (enlace y muro de C2) depende de ese arco.
	if hechizo.gravedad > 0.0:
		return Vector3.ZERO
	hechizo.altura_salida = maxf(mano.y - Terreno3D.y_pies(c), 0.0) / Terreno3D.casilla
	if c != celda_de(origen):
		return Vector3.ZERO                               # la mano asoma a otra casilla (junto a un muro): solo la altura, el punto se queda en la suya
	return Vector3(mano.x - origen.x, 0.0, mano.z - origen.z)


## La mano que lanza (la derecha: la de las motas del lanzamiento). Sin esqueleto (laboratorios) se aproxima.
func _pos_mano() -> Vector3:
	var pj: Node3D = jugador.get("pj") if jugador != null else null
	if pj != null:
		var chispas: Variant = pj.get("_chispas")
		if chispas is Node3D and is_instance_valid(chispas) and (chispas as Node3D).is_inside_tree():
			return (chispas as Node3D).global_position
		return pj.global_transform * Vector3(0.28, 0.85, 0.30)
	if jugador != null:
		return jugador.global_position + Vector3(0.0, 0.9, 0.0)
	return Vector3.ZERO


## El libro del jugador: el del cinto si se ve, o un punto en la cadera.
func _pos_libro() -> Vector3:
	var pj: Node3D = jugador.get("pj") if jugador != null else null
	if pj != null:
		# T-CP1: con el libro YA en la mano (no vuelve al cinto al lanzar) la voluta sale de él.
		var en_mano: Variant = pj.get("_libro")
		if en_mano is Node3D and is_instance_valid(en_mano) and (en_mano as Node3D).is_inside_tree():
			return (en_mano as Node3D).global_position
		if pj.has_method("_libro_cinto"):
			var cinto: Variant = pj.call("_libro_cinto")
			if cinto is Node3D and is_instance_valid(cinto) and (cinto as Node3D).is_inside_tree():
				return (cinto as Node3D).global_position
		return pj.global_transform * Vector3(-0.30, 0.55, -0.05)
	if jugador != null:
		return jugador.global_position + Vector3(-0.3, 0.55, 0.0)
	return Vector3.ZERO


## La voluta: un hilo de luz con un arco suave (sube a mitad de camino) del libro a la mano. Se borra sola al llegar.
func _voluta(desde: Vector3, color: Color, dura: float) -> void:
	var hasta: Vector3 = _pos_mano()
	var medio: Vector3 = (desde + hasta) * 0.5 + Vector3(0.0, 0.25, 0.0)
	var hilo := HiloLuz3D.new()
	var padre: Node = mundo if mundo != null else self
	padre.add_child(hilo)
	hilo.preparar([desde, desde.lerp(medio, 0.6), medio, medio.lerp(hasta, 0.6), hasta], color)
	hilo.viajar(maxf(dura, 0.05))
	get_tree().create_timer(dura + 0.8, false).timeout.connect(Lanzador3D._borrar_si_vive.bind(weakref(hilo)))   # referencia DÉBIL: una lambda que capture el hilo da error en el motor si muere antes (ver HechizoVivo._olvidar)


## La forma en la mano: una esfera emisiva que crece de 0 a su tamaño en `dura` s (sustituto del VFX del Pipeline).
func _forma_en_mano(pos: Vector3, color: Color, dura: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = RADIO_BOLA * 0.8
	esfera.height = RADIO_BOLA * 1.6
	m.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var padre: Node = mundo if mundo != null else self
	padre.add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * 0.05
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE, maxf(dura, 0.05)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return m


## --- Marcadores del modo lanzar ---

func _crear_marcadores(color: Color) -> void:
	# 28/10 (aspecto del apuntado): los colores y materiales salen de `Apuntado3D` (más vivos que la runa y con contorno oscuro: la tierra parda no se veía sobre la tierra).
	_prev_color = Apuntado3D.color_de(Objetos.elemento_de(_preparado.get("rune") as RuneData) if _preparado.has("rune") else "", color)
	_marca_origen = Apuntado3D.disco(0.5 * Terreno3D.casilla, _prev_color, 0.09)
	mundo.add_child(_marca_origen)
	_marca_alcance = Apuntado3D.disco(2.0 * ALCANCE_ORIGEN * Terreno3D.casilla, Color(_prev_color, 0.6), 0.06, 64.0, false, false, 0.02)
	mundo.add_child(_marca_alcance)
	_marca_flecha = MeshInstance3D.new()          # se queda (lo miran las pruebas de A1), pero la flecha la dibuja ya `Apuntado3D` siguiendo el vuelo real
	_marca_flecha.visible = false
	mundo.add_child(_marca_flecha)
	if _apuntado == null:
		_apuntado = Apuntado3D.new()
		mundo.add_child(_apuntado)
	_poner_cursor(_prev_color, false)
	if PREVER_REACCIONES and _vista_reaccion == null:
		_vista_reaccion = PrevisionReaccion3D.new()
		mundo.add_child(_vista_reaccion)


## 28/10: el cursor del ratón mientras se apunta es una retícula del color del elemento (roja con X si no se lanzaría), la misma que la del suelo (`Apuntado3D.imagen_cursor`).
## `puesto` false = vuelve el del sistema. Solo se toca el cursor cuando cambia (crear la imagen cuesta); sin ventana (headless) se apunta el estado y no se toca nada.
func _poner_cursor(color: Color, cruz: bool, puesto: bool = true) -> void:
	var clave: String = ("%s|%s" % [color.to_html(), cruz]) if puesto else ""
	if clave == cursor_puesto:
		return
	cursor_puesto = clave
	if DisplayServer.get_name() == "headless":
		return
	if puesto:
		var c: int = Apuntado3D.TAM_CURSOR / 2
		Input.set_custom_mouse_cursor(Apuntado3D.imagen_cursor(color, cruz), Input.CURSOR_ARROW, Vector2(c, c))
	else:
		Input.set_custom_mouse_cursor(null)


func _pintar_marcadores() -> void:
	if _marca_origen == null:
		return
	var yo: Vector3 = (jugador as Node3D).position
	var o: Vector3 = _origen_fijo if _fijado else _origen_vivo
	_marca_origen.position = Vector3(o.x, y_pies(celda_de(o)) + 0.1, o.z)
	_marca_alcance.position = Vector3(yo.x, y_pies(celda_de(yo)) + 0.07, yo.z)
	var d: Vector3 = _direccion_actual()
	var largo: float = 1.1 * Terreno3D.casilla
	_marca_flecha.position = o + d * largo * 0.5 + Vector3(0, 0.1, 0)
	_pintar_previsualizacion(o, d)


## 8.8 / R3: las casillas que ocupará el hechizo y su altura, calculadas con la MISMA geometría con la que se lanza (así lo que se ve es lo
## que sale). Rojo = no se lanzaría con este elemento.
## 28/10 (aspecto del apuntado): un proyectil ya no enseña la caja de su cuerpo bajo la jugadora (no es donde cae), sino su RECORRIDO real y una retícula donde se para
## (`Apuntado3D`, con el vuelo en seco de `PrevisionHechizo`); lo que no vuela (barrera, haz) enseña sus casillas como un fantasma de su alto real y una cinta recta.
## El anillo de alcance solo sale si el hechizo nace donde apuntas (es lo único a lo que limita). Un sólido que no cabe sale en rojo con su motivo, antes de soltar.
func _pintar_previsualizacion(origen: Vector3, dir: Vector3) -> void:
	var receta: Receta3D = _preparado.get("receta") as Receta3D
	if receta == null:
		return
	var g: Dictionary = receta.geo()
	var viaja: float = float((g["props"] as Dictionary).get("viaja", 0.0))
	var largo_flecha: float = viaja * Terreno3D.casilla          # lo que se desplaza lo que no vuela como proyectil (0 = nace y se queda)
	var valido: bool = GeometriaV2.aviso_materia(g, _preparado.get("rune") as RuneData) == ""
	var alto: float = Terreno3D.ALTO_NIVEL * float(GeometriaV2.niveles(g) - 1)
	var motivo: String = ""
	if valido and (alto > 0.0 or bool(_preparado.get("en_punto", false))):
		motivo = rechazo_de_construccion(_preparado, origen)
	var prevision: Array = PrevisionHechizo.prever_rapido(self, _preparado, origen, dir) if valido and motivo == "" else []
	var recorrido: Dictionary = PrevisionHechizo.ultimo_recorrido if valido and motivo == "" else {}
	var vuela: bool = not (recorrido.get("caminos", []) as Array).is_empty()
	_marca_alcance.visible = bool(_preparado.get("en_punto", false))
	var cs: Array = [] if vuela else GeometriaV2.celdas(g, Vector2(origen.x, origen.z), Vector2(dir.x, dir.z), Terreno3D.casilla)
	var no_vale: bool = not valido or motivo != ""
	while _prev_casillas.size() < cs.size():
		var mi := MeshInstance3D.new()
		var caja := BoxMesh.new()
		mi.mesh = caja
		mi.material_override = Apuntado3D.material_casilla(_prev_color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mundo.add_child(mi)
		_prev_casillas.append(mi)
	for i in range(_prev_casillas.size()):
		var mi: MeshInstance3D = _prev_casillas[i]
		mi.visible = i < cs.size()
		if not mi.visible:
			continue
		var c: Vector2i = cs[i]
		var h: float = 0.06 + alto
		var tam := Vector3(Terreno3D.casilla * 0.9, h, Terreno3D.casilla * 0.9)
		(mi.mesh as BoxMesh).size = tam
		mi.set_instance_shader_parameter("tam", tam)
		var mat: ShaderMaterial = mi.material_override as ShaderMaterial
		mat.set_shader_parameter("color", Apuntado3D.COLOR_NO if no_vale else _prev_color)
		mat.set_shader_parameter("invalido", no_vale)
		mi.position = Vector3((float(c.x) + 0.5) * Terreno3D.casilla, y_pies(c) + h * 0.5 + 0.02, (float(c.y) + 0.5) * Terreno3D.casilla)
	Apuntado3D.pintar_disco(_marca_origen, Apuntado3D.COLOR_NO if no_vale else _prev_color)
	_poner_cursor(Apuntado3D.COLOR_NO if no_vale else _prev_color, no_vale)
	if _apuntado != null and is_instance_valid(_apuntado):
		_apuntado.mostrar(recorrido, origen, dir, largo_flecha, _prev_color, motivo if motivo != "" else ("" if valido else "Demasiado alto: no se podría pisar"),
			(jugador as Node3D).position if bool(_preparado.get("en_punto", false)) else Vector3.INF)
	# A3: lo que pasaría al soltar AQUÍ (el mismo origen y la misma dirección que `_soltar` pasa a `lanzar_ahora`). Un hechizo que no se lanzaría no prevé nada.
	if _vista_reaccion != null and is_instance_valid(_vista_reaccion):
		_vista_reaccion.mostrar(prevision)



## =====================================================================================================
##  Materializar la receta en 3D
## =====================================================================================================

## Devuelve cuántas manifestaciones salen en total. Desde HC2 (18/10) el Lanzador solo conjura: construye el `Hechizo` de la receta y crea el `HechizoVivo` que lo ejecuta.
func _materializar(receta: Receta3D, rune: RuneData, origen: Vector3, dir: Vector3, permitir_cinematico: bool = false) -> int:
	return lanzar_hechizo(receta.hechizo(rune, permitir_cinematico), origen, dir)


## HC2: lanza un `Hechizo` ya construido (el de `Hechizo.construir`, el del libro o el que un laboratorio haya tocado a mano). Devuelve cuántas casillas ocupa (0 = rechazado).
func lanzar_hechizo(hechizo: Hechizo, origen: Vector3, dir: Vector3) -> int:
	if hechizo == null:
		return 0                                            # p. ej. una runa cinemática sin permiso (Hechizo.construir devolvió null)
	return HechizoVivo.crear(_con_cambios(hechizo), origen, dir, self).casillas


## HC5: sobrescrituras en vivo del laboratorio ({campo: valor}, ver Hechizo.EDITABLES). Vacío en el juego: el siguiente hechizo sale tal cual lo construyó `Hechizo.construir`.
## Si no está vacío, se aplican al hechizo ANTES de crearlo (también por el camino completo del conjuro: `_disparar` pasa por aquí).
var cambios_hechizo: Dictionary = {}

func _con_cambios(hechizo: Hechizo) -> Hechizo:
	return hechizo.con(cambios_hechizo) if not cambios_hechizo.is_empty() else hechizo


## R4 (17/10): entrada PÚBLICA para lanzar una receta ya montada sin pasar por el libro, la tinta ni la recarga. La usan los laboratorios
## (LabRecetas3D, y el de cast points cuando exista) para no llamar a un método con «_». Devuelve cuántas casillas/manifestaciones salieron
## (0 = no se lanzó: p. ej. un sólido más alto de lo que se puede pisar).
func lanzar_receta(receta: Receta3D, rune: RuneData, origen: Vector3, dir: Vector3) -> int:
	return _materializar(receta, rune, origen, dir)


## Ola suelta de la receta antigua. Solo la usan las pruebas de burbujas (`prueba_barrera`) para montar un Campo a mano; el juego ya no llega aquí.
func _una_ola(receta: Receta3D, data: RuneData, elemento: String, origen: Vector3, dir: Vector3) -> int:
	var giro: float = Vector2(dir.x, dir.z).angle() - Vector2.RIGHT.angle()
	var manifest: Array = receta.manifestaciones_en(Vector2(origen.x, origen.z), Vector2(dir.x, dir.z))
	return _crear_campo(receta, data, elemento, origen, giro, manifest, receta.height)


func _barrido(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, dir: Vector3, alcance: float,
		nivel: int) -> void:
	var y_vuelo: float = y_pies(celda_de(origen)) + Terreno3D.ALTO_NIVEL * 0.5 * float(1 + nivel)
	var inicio := Vector3(origen.x, y_vuelo, origen.z)
	var res: Dictionary = trazar(inicio, dir, alcance, nivel, rune, receta.lifetime > 0.0, receta.bounces, receta.pull)
	var t: float = 0.0
	for tramo in res["tramos"]:
		var a: Vector3 = tramo["desde"]
		var b: Vector3 = tramo["hasta"]
		var pie_a: Vector3 = Vector3(a.x, y_pies(celda_de(a)), a.z)
		var pie_b: Vector3 = Vector3(b.x, y_pies(celda_de(b)), b.z)
		# P2 (13/10): si lo que frena la bola es un objeto con punto de activación (el cuenco de la antorcha, la boca de la tinaja),
		# la bola acaba ahí y no donde roza la caja de acierto. Vfx3D.lanzar eleva los dos extremos ALTO_BOLA·escala sobre los
		# «pies» que se le pasan, por eso se resta.
		var p_act: Vector3 = _activacion_al_final(tramo)
		if p_act != Vector3.INF and fx != null:
			pie_b = Vector3(p_act.x, p_act.y - ALTO_BOLA * fx.escala, p_act.z)
		var el: String = String(tramo.get("elemento", elemento))
		if Vfx3D.ELEMENTOS.has(el):
			_visual_en(t, el, pie_a, pie_b)
		var viaje: float = _tiempo_de_viaje(el, a.distance_to(b))
		for g in tramo["golpes"]:
			var obj: Node = g["obj"]
			var dist_g: float = float(g["dist"])
			var dir_g: Vector3 = tramo["dir"]
			var rune_g: RuneData = tramo.get("rune", rune)
			_despues(t + _tiempo_de_viaje(el, dist_g), _golpear.bind(obj, rune_g, dir_g, g["punto"], nivel, receta.pull,
				(tramo["desde"] as Vector3)))
		t += viaje


## P2: el punto de activación del objeto que PARA este tramo (el último golpe, a la distancia a la que acaba el tramo, que
## reacciona al hechizo). Vector3.INF si el tramo acaba en una pared, en el alcance, o en un objeto sin punto propio.
func _activacion_al_final(tramo: Dictionary) -> Vector3:
	var largo: float = (tramo["desde"] as Vector3).distance_to(tramo["hasta"] as Vector3)
	var golpes: Array = tramo["golpes"]
	for i in range(golpes.size() - 1, -1, -1):
		var g: Dictionary = golpes[i]
		if absf(float(g["dist"]) - largo) > 0.01:
			continue
		var obj: Node = g["obj"]
		if not is_instance_valid(obj) or not obj.has_method("punto_activacion"):
			return Vector3.INF
		if obj.has_method("spell_reacts") and not bool(obj.call("spell_reacts", tramo["rune"], tramo["dir"])):
			return Vector3.INF
		return obj.call("punto_activacion")
	return Vector3.INF


## P2: lo primero activable que cruza el haz de un chorro, de la mano hacia delante. Devuelve su punto de activación (o INF).
func _activacion_en_haz(mano: Vector3, dir: Vector3, largo: float, rune: RuneData) -> Vector3:
	var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	for h in _rayo_areas(espacio, mano, dir, largo):
		var obj: Node = h["obj"]
		if not obj.has_method("punto_activacion") or not obj.has_method("on_spell_hit"):
			continue
		if obj.has_method("spell_reacts") and not bool(obj.call("spell_reacts", rune, dir)):
			continue
		return obj.call("punto_activacion")
	return Vector3.INF


func _tiempo_de_viaje(elemento: String, distancia: float) -> float:
	# 6.5: todos son una bola que viaja; el rayo, más rápido; la tierra, más lenta.
	var v: float = fx.velocidad if fx != null else 7.0
	match elemento:
		"rayo":
			v *= 2.0
		"tierra":
			v *= 0.8
	return maxf(0.1, distancia / maxf(v, 0.1))


func _visual_en(retraso: float, elemento: String, pie_a: Vector3, pie_b: Vector3) -> void:
	if fx == null:
		return
	if retraso <= 0.001:
		_visual(elemento, pie_a, pie_b)
	else:
		_despues(retraso, _visual.bind(elemento, pie_a, pie_b))


func _visual(elemento: String, pie_a: Vector3, pie_b: Vector3) -> void:
	if fx != null and is_instance_valid(fx):
		fx.lanzar_forma("bola", elemento, pie_a, pie_b, {"radio": _radio_bola_actual})


## Borra un nodo si sigue vivo. Se conecta con `.bind(weakref(nodo))`: una lambda que capture el nodo da error en el motor («Lambda capture at index 0 was freed») cuando
## muere antes que el temporizador (pruebas, cambio de escena), aunque la lambda compruebe `is_instance_valid`.
static func _borrar_si_vive(ref: WeakRef) -> void:
	var n: Variant = ref.get_ref()
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


## Un campo salió del árbol: cuenta una manifestación menos y se saca de `_campos`. Por referencias débiles (ver `_borrar_si_vive`): el lanzador puede haber muerto ya.
static func _campo_terminado(lanzador_ref: WeakRef, campo_ref: WeakRef, cuenta: int) -> void:
	var l: Variant = lanzador_ref.get_ref()
	if l == null:
		return
	(l as Lanzador3D).manifestaciones_vivas = maxi(0, (l as Lanzador3D).manifestaciones_vivas - cuenta)
	var c: Variant = campo_ref.get_ref()
	if c != null:
		(l as Lanzador3D)._campos.erase(c)


## Levanta un bloque de tierra por casilla (el anillo Vfx3D "corro" ya dibuja la tierra).
func _levantar_tierra(celdas: Dictionary) -> void:
	for c in celdas:
		construir_tierra(c as Vector2i, false)


func _despues(t: float, f: Callable) -> void:
	if t <= 0.001:
		f.call()
		return
	get_tree().create_timer(t, false).timeout.connect(f)


## BARRIDO: del origen en línea recta hasta `alcance`. Corta en una casilla sólida (que sea alta para este nivel),
## en una barrera o en lo primero que reacciona y detiene. Lo que atraviesa se anota como golpe. Con rebotes la
## trayectoria se parte en tramos. Devuelve {tramos: [{desde, hasta, dir, golpes, rune?, elemento?}], fin}.
func trazar(origen: Vector3, dir: Vector3, alcance: float, nivel: int, rune: RuneData, atraviesa: bool,
		rebotes: int, atrae: bool) -> Dictionary:
	var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var tramos: Array = []
	var pos: Vector3 = origen
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var restante: float = alcance
	var ya: Dictionary = {}
	var cargado: bool = false
	var rune_act: RuneData = rune
	var reflejado: bool = false
	altura = nivel

	while restante > 0.05:
		# 1) La primera casilla sólida del camino.
		var dist_celda: float = restante
		var normal := Vector3.ZERO
		var paso: float = Terreno3D.casilla * 0.1
		var previa: Vector2i = celda_de(pos)
		var rec: float = paso
		var choca_celda: bool = false
		var celda_sola: bool = false                     # lo que corta es una casilla sólida (no una barrera)
		var refleja_vol: bool = false                    # lo que corta es un volumen con solidez y rebote, sin desplazamiento (R3)
		while rec <= restante:
			var q: Vector3 = pos + d * rec
			var cq: Vector2i = celda_de(q)
			if cq != previa:
				if celda_solida(cq, nivel):
					dist_celda = maxf(rec - paso * 0.5, 0.0)
					var dx: int = cq.x - previa.x
					var dz: int = cq.y - previa.y
					normal = Vector3(-float(dx), 0.0, 0.0) if absi(dx) >= absi(dz) else Vector3(0.0, 0.0, -float(dz))
					choca_celda = true
					celda_sola = true
					break
				previa = cq
			if _barrera_en(q, nivel):
				dist_celda = rec
				normal = -d
				choca_celda = true
				refleja_vol = _solidez_refleja_en(q)
				break
			rec += paso

		# 2) Las zonas y objetos que el rayo atraviesa hasta ahí (y la casilla sólida que los contiene).
		var limite: float = minf(restante, dist_celda + Terreno3D.casilla * 1.42) if choca_celda else restante
		var golpes: Array = []
		var parada: float = dist_celda
		var alcance_golpes: float = dist_celda + (Terreno3D.casilla * 1.05 if celda_sola else 0.0)   # un objeto DENTRO de la casilla sólida
		var rebota_zona: bool = false
		var hits: Array = _rayo_areas(espacio, pos, d, limite)
		var cortado: bool = choca_celda
		for h in hits:
			var obj: Node = h["obj"]
			if ya.has(obj):
				continue
			if float(h["dist"]) > alcance_golpes:
				break
			ya[obj] = true
			if obj.has_method("bloquea_proyectiles") and bool(obj.call("bloquea_proyectiles", self)):
				parada = float(h["dist"])
				normal = -d
				rebota_zona = (obj.has_method("refleja_a") and bool(obj.call("refleja_a", self))) or rebotes > 0
				cortado = true
				choca_celda = false
				break
			var nv: int = int(obj.call("nivel_altura")) if obj.has_method("nivel_altura") else 1
			if nv < nivel:
				continue                                # vuela por encima (levitación más alta que el objeto)
			var a_ras: bool = nv < 1 + nivel            # objeto a ras: reacciona pero no frena
			if rune_act.tags.has("viento") and not cargado and obj.has_method("carried_element"):
				var llevado: RuneData = obj.call("carried_element")
				if llevado != null:
					rune_act = llevado
					cargado = true
			golpes.append({"obj": obj, "dist": float(h["dist"]), "punto": pos + d * float(h["dist"])})
			var reacciona: bool = true
			if obj.has_method("spell_reacts"):
				reacciona = bool(obj.call("spell_reacts", rune_act, d))
			var cruza: bool = a_ras or (obj.has_method("spell_passes_through") and bool(obj.call("spell_passes_through"))) \
				or (obj.has_method("spell_flies_over") and bool(obj.call("spell_flies_over", rune_act, cargado)))
			if reacciona and not cruza and not atraviesa:
				parada = float(h["dist"])
				cortado = true
				choca_celda = false
				break

		var fin: Vector3 = pos + d * parada
		var tramo: Dictionary = {"desde": pos, "hasta": fin, "dir": d, "golpes": golpes, "rune": rune_act,
			"elemento": Objetos.elemento_de(rune_act)}
		tramos.append(tramo)
		restante -= parada
		if cortado and (choca_celda or rebota_zona) and (rebotes > 0 or (refleja_vol and not reflejado)) and normal != Vector3.ZERO and restante > 0.3:
			d = d.bounce(normal.normalized())
			d.y = 0.0
			d = d.normalized()
			pos = fin + d * 0.05
			if rebotes > 0:
				rebotes -= 1
			else:
				reflejado = true                      # un volumen que refleja devuelve cada trazo UNA vez
			continue
		pos = fin
		break

	return {"tramos": tramos, "fin": pos}


## ¿Hay una barrera VIVA (de las nuestras: corro, muro) en este punto, a un nivel que la salta o no?
## `excepto` (24/10): el linaje de un HechizoVivo que pregunta desde dentro (el proyectil, D-6): se salta las solideces de SU propio lanzamiento para no chocar con el muro que él mismo levanta.
## `trazar` no pasa nada: ve todas, como siempre.
func _barrera_en(p: Vector3, nivel: int, excepto: Object = null) -> bool:
	for c in _campos:
		if is_instance_valid(c) and (c as Campo).bloquea_a(p, nivel):
			return true
	var propia: Vector2i = celda_de((jugador as Node3D).position) if jugador != null else Vector2i(-99999, -99999)
	for s in _solideces_v2:
		if is_instance_valid(s) and not (excepto != null and (s as SolidezV2).linaje == excepto) and (s as SolidezV2).bloquea_a(p, nivel, propia):
			return true
	return false


## ¿El volumen con solidez que hay en este punto devuelve los proyectiles? (rebote sin desplazamiento, R3) `excepto`: ver `_barrera_en`.
func _solidez_refleja_en(p: Vector3, excepto: Object = null) -> bool:
	for s in _solideces_v2:
		if is_instance_valid(s) and not (excepto != null and (s as SolidezV2).linaje == excepto) and (s as SolidezV2).refleja and (s as SolidezV2).contiene(p):
			return true
	return false


## Algo AJENO (la flecha de un goblin) está en `p`: si un volumen con solidez lo contiene, lo para y aguanta `dano`. Devuelve true si lo ha parado.
func solidez_para(p: Vector3, dano: float) -> bool:
	for s in _solideces_v2:
		if is_instance_valid(s) and (s as SolidezV2).contiene(p):
			(s as SolidezV2).golpe(dano)
			return true
	return false


## Todo lo que el rayo cruza en las capas reactiva y de bloqueo, ordenado por distancia.
func _rayo_areas(espacio: PhysicsDirectSpaceState3D, pos: Vector3, d: Vector3, largo: float) -> Array:
	var res: Array = []
	var excluir: Array[RID] = []
	var fin: Vector3 = pos + d * largo
	for i in range(24):
		var q := PhysicsRayQueryParameters3D.create(pos, fin, CAPA_REACTIVO | CAPA_BLOQUEO)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		q.hit_from_inside = true
		q.exclude = excluir
		var r: Dictionary = espacio.intersect_ray(q)
		if r.is_empty():
			break
		excluir.append(r["rid"])
		var obj: Object = r["collider"]
		if obj is Node:
			res.append({"obj": obj, "dist": pos.distance_to(r["position"] as Vector3)})
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	return res


## Aplica un hechizo a un objeto, por el contrato: empuje, viento que se lleva, spell_reacts, on_spell_hit.
## `hechizo` (HC4): el Hechizo que golpea. Si viene y el objeto es un enemigo (`Combate3D`), el golpe usa SUS campos (veneno, daño tocado en el lab…) y no los del RuneData; el contrato
## `on_spell_hit(rune, dir)` del resto de objetos no cambia.
func _golpear(obj: Node, rune: RuneData, dir: Vector3, punto: Vector3, nivel: int, atrae: bool, desde: Vector3, hechizo: Hechizo = null) -> bool:
	if obj == null or not is_instance_valid(obj) or rune == null:
		return false
	# 12/10 (Pablo): lo activable se activa en SU punto (el cuenco de la antorcha, la boca de la tinaja…), no donde roza la caja.
	var activable: bool = obj.has_method("punto_activacion")
	if activable:
		punto = obj.call("punto_activacion")
	var empuje: Dictionary = empuje_de_golpe(obj, rune, dir, punto, atrae, desde)
	if not empuje.is_empty():
		obj.call("push", empuje["dir"], empuje["fuerza"])
	if not obj.has_method("on_spell_hit"):
		return false
	var reacciona: bool = true
	if obj.has_method("spell_reacts"):
		reacciona = bool(obj.call("spell_reacts", rune, dir))
	if activable and reacciona and fx != null and is_instance_valid(fx):
		fx.chispazo(punto, Objetos.elemento_de(rune))        # la chispa nace en el punto de activación
	ultimo_impacto = punto
	ultimo_nivel = nivel
	# 14/10: qué objeto recibe el golpe (el registro de partida solo decía los lanzamientos, no a quién llegaban).
	PlayLog.event("golpe_objeto", {"objeto": _nombre_de_objeto(obj), "elemento": Objetos.elemento_de(rune), "reacciona": reacciona,
		"punto": [snappedf(punto.x, 0.1), snappedf(punto.y, 0.1), snappedf(punto.z, 0.1)]})
	if hechizo != null and obj is Combate3D:
		(obj as Combate3D).on_spell_hit(rune, dir, hechizo)
	else:
		obj.call("on_spell_hit", rune, dir)
	ultimo_impacto = Vector3.INF
	ultimo_nivel = 0
	return reacciona


## 28/10 · A2 (previsión): el empuje que `_golpear` da a `obj` ANTES de su `on_spell_hit` (el viento empuja, la atracción tira), sin darlo: {dir, fuerza} o {} si no empuja. Es la decisión
## que `_golpear` ejecuta con `push`, extraída para que la previsión del indicador (`PrevisionHechizo`) y el golpe real no puedan divergir.
static func empuje_de_golpe(obj: Node, rune: RuneData, dir: Vector3, punto: Vector3, atrae: bool, desde: Vector3) -> Dictionary:
	var es_viento: bool = rune.tags.has("viento")
	if not ((es_viento or atrae) and obj.has_method("push")):
		return {}
	if atrae:
		var hacia: Vector3 = desde - (obj as Node3D).global_position
		hacia.y = 0.0
		if hacia.length() > 0.01:
			return {"dir": hacia.normalized(), "fuerza": FUERZA_EMPUJE * (1.0 if es_viento else 0.7)}
		return {}
	var emp: Vector3 = dir
	if emp.length() < 0.01:
		emp = (obj as Node3D).global_position - punto
		emp.y = 0.0
		emp = emp.normalized()
	return {"dir": emp, "fuerza": FUERZA_EMPUJE}


## Nombre legible de un objeto golpeado para el registro: su `tipo` si lo tiene (Reactivo3D), si no su clase o su nombre.
func _nombre_de_objeto(obj: Node) -> String:
	var t: Variant = obj.get("tipo")
	if t != null and String(t) != "":
		return String(t)
	var sc: Variant = obj.get_script()
	if sc is Script and String((sc as Script).get_global_name()) != "":
		return String((sc as Script).get_global_name())
	return String(obj.name) if String(obj.name) != "" else obj.get_class()


## =====================================================================================================
##  Campos: lo que se queda (muros, corros, ondas, tierra, columnas) (4.1, 4.4)
## =====================================================================================================

## ¿Es la barrera quieta que te envuelve (cúpula)? Barrera sola o con elemento: ni flecha, ni pulso, ni línea, ni altura.
func es_barrera_cupula(receta: Receta3D) -> bool:
	return receta.spread and not receta.travels and not receta.line and not receta.pulse and receta.height <= 0


## Cuánto vive el campo de esta receta (la barrera cúpula dura más: 6.3).
func vida_campo(receta: Receta3D) -> float:
	var v: float = receta.vida()
	if es_barrera_cupula(receta):
		v = maxf(v * MULT_VIDA_BARRERA, VIDA_MIN_BARRERA)
	return v


func _crear_campo(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, giro: float, manifest: Array,
		nivel: int) -> int:
	var factor: float = Sigils.quality_factor(receta.calidad)
	var muro: bool = receta.es_barrera_movil()
	var cupula: bool = es_barrera_cupula(receta)
	var sigue: bool = receta.sigue() or cupula
	var onda: bool = receta.expande()
	var campo := Campo.new()
	campo.lanz = self
	campo.rune = rune
	campo.elemento = elemento
	campo.nivel = nivel
	# 8.1 (decisión 3): la Barrera bloquea siempre; una Línea sin Barrera bloquea solo si el MATERIAL es sólido (tierra, hielo).
	campo.bloquea = receta.blocks or (receta.usa_geo() and receta.line and (elemento == "tierra" or elemento == "hielo"))
	campo.refleja = receta.blocks and receta.bounces > 0
	campo.atrae = receta.pull
	campo.atraviesa = receta.lifetime > 0.0
	campo.viaja = muro
	campo.vida = vida_campo(receta)
	# 11.4: un chorro de AGUA es un manantial en cada casilla que toca, mientras dura el campo.
	campo.caudal = CAUDAL_CHORRO_CELDA if elemento == "agua" and receta.usa_geo() and String(receta.geo()["nombre"]) == "chorro" else 0.0
	campo.altura_barrera = receta.height
	if cupula:
		campo.burbuja = true
		campo.bloquea = false            # los hechizos del propio jugador salen de dentro de la burbuja sin chocar con ella

	# Centroide de cada dirección (una onda se abre desde el centro de lo suyo).
	var suma := Vector2.ZERO
	for m in manifest:
		suma += (m["p"] as Vector2)
	var centro2: Vector2 = suma / float(maxi(manifest.size(), 1))

	var origen2 := Vector2(origen.x, origen.z)
	var y_base: float = y_pies(celda_de(origen))
	var cuenta: int = 0
	if cupula:
		# UNA esfera de RADIO_BURBUJA centrada en el jugador (+ ALTO_BURBUJA) que le sigue: sustituye al anillo de casillas del manifiesto
		# (que además marcaba el suelo de alrededor con el elemento: la burbuja no toca el suelo hasta que revienta).
		var centro_b: Vector3 = (jugador as Node3D).position + Vector3(0.0, ALTO_BURBUJA, 0.0)
		campo.puntos.append(centro_b)
		campo.vel.append(Vector3.ZERO)
		campo.dirs.append(Vector3.ZERO)
		campo.niveles.append(nivel)
		campo.vivos.append(true)
		campo.rel.append(Vector3(0.0, ALTO_BURBUJA, 0.0))
		cuenta = 1
	for m in (manifest if not cupula else []):
		var rel: Vector2 = (m["p"] as Vector2).rotated(giro) * Terreno3D.casilla
		var p2: Vector2 = origen2 + rel
		var dir2: Vector2 = (m["dir"] as Vector2).rotated(giro)
		var nivel_m: int = int(m.get("nivel", 0))
		var elev: float = float(m.get("elev", 0.0))
		var punto := Vector3(p2.x, y_base + Terreno3D.ALTO_NIVEL * (0.5 + float(nivel_m) + elev), p2.y)
		var v := Vector3.ZERO
		if muro:
			v = Vector3(dir2.x, 0.0, dir2.y).normalized() * VEL_MURO * Terreno3D.casilla
		elif onda:
			var rad: Vector2 = ((m["p"] as Vector2) - centro2).rotated(giro)
			if rad.length() < 0.001:
				rad = dir2
			v = Vector3(rad.x, 0.0, rad.y).normalized() * VEL_ONDA * Terreno3D.casilla
		campo.puntos.append(punto)
		campo.vel.append(v)
		campo.dirs.append(Vector3(dir2.x, 0.0, dir2.y).normalized() if (muro or not receta.es_quieto()) else Vector3.ZERO)
		campo.niveles.append(nivel_m)
		campo.vivos.append(true)
		campo.rel.append(punto - (jugador as Node3D).position)
		cuenta += 1
	if sigue:
		campo.sigue = jugador as Node3D
	mundo.add_child(campo)
	_campos.append(campo)
	_visual_campo(receta, elemento, origen, campo, muro, receta.blocks and receta.height > 0 and receta.spread and not onda)
	campo.iniciar()
	if cupula:
		_proteger_con(campo)
	manifestaciones_vivas += cuenta
	campo.tree_exited.connect(Lanzador3D._campo_terminado.bind(weakref(self), weakref(campo), cuenta))

	# Lo que construye: tierra quieta (un bloque por casilla) y columna (barrera + levitación).
	var columna: bool = receta.blocks and receta.height > 0 and receta.spread and not onda
	if columna:
		_levantar_columna(campo, receta.vida(), 1, rune.color)
	elif rune.tags.has("tierra") and receta.es_quieto() and not muro and not cupula:
		var celdas: Dictionary = {}
		for pt in campo.puntos:
			celdas[celda_de(pt as Vector3)] = true
		var levantar: Callable = _levantar_tierra.bind(celdas)       # método del lanzador, no lambda: si el lanzador muere antes, el motor suelta la conexión sin error
		if onda:
			_despues(T_CRECE, levantar)          # barrera + pulso: el anillo crece y los bloques aparecen al llegar
		else:
			levantar.call()
	return cuenta


## =====================================================================================================
##  MATERIA V2 (R2): el estado del elemento decide qué ES el volumen
## =====================================================================================================
##
## Aquí no hay ni un `if elemento == …`: el camino es  geometría (celdas × niveles)  →  `RuneData.estado`  →  un método por estado
## (MATERIA_V2)  →  las cifras (persiste, empuje, pisable, deja) salen del RuneData. Lo que NO se resuelve por dato queda anotado en el diario.
## Las propiedades (`viaja`, `solidez`, `copias`, `rebotes`, `crece`) las aplica el CICLO DE VIDA de abajo (R3): este bloque solo sabe qué
## hace cada estado con UNA tanda de casillas.

# =============================== CICLO DE VIDA V2 (R3) ===============================

## 27/10: el sonido arcano que acompaña a TODO conjuro al empezar (Sfx.CATALOGO; grabado, CC0).
const SFX_CONJURO: String = "conjuro_arcano"

## SONIDO POR FASE (MEJORAS_POTENCIA §1): «<elemento>_carga» al empezar el conjuro, «<elemento>_disparo» al salir y «<nombre derivado>_impacto» al
## materializarse. Si el nombre no está en `Sfx.CATALOGO`, cae en el sonido del elemento de siempre (elem_*): así suena hoy y mejora solo cuando el Pipeline dé de alta
## los nuevos. Cada fase pide su sonido UNA vez (queda anotado en `sonidos_fase` para las pruebas). `Sfx` es del Pipeline: aquí solo se llama.
func _sonar_fase_v2(fase: String, elemento: String, derivado: String = "", en: Vector3 = Vector3.ZERO) -> void:
	var nombre: String = "%s_%s" % [derivado if fase == "impacto" and derivado != "" else elemento, fase]
	var real: String = nombre if Sfx.CATALOGO.has(nombre) else elemento
	sonidos_fase.append({"fase": fase, "pedido": nombre, "suena": real, "elemento": elemento})
	if Sfx.CATALOGO.has(real):
		Sfx.play(self, real, 0.85 if fase == "carga" and real == elemento else 0.0)
	if fase == "carga" and Sfx.CATALOGO.has(SFX_CONJURO):
		Sfx.play(self, SFX_CONJURO)          # 27/10: la capa arcana común a todo conjuro, debajo del sonido del elemento


## PlayLog `receta_v2`: lo que se ha lanzado, en números (dimensiones, propiedades, estado, coste), para equilibrar sin adivinar.
func _registrar_receta_v2(hechizo: Hechizo, datos: Dictionary, manifestaciones: int) -> void:
	var sx: Vector3 = hechizo.semiejes
	PlayLog.event("receta_v2", {"pagina": int(datos["indice"]) + 1, "elemento": hechizo.elemento, "estado": hechizo.estado_materia,
		"x": snappedf(sx.x, 0.01), "y": snappedf(sx.y, 0.01), "z": snappedf(sx.z, 0.01),
		"niveles": hechizo.niveles, "propiedades": hechizo.propiedades_usadas(), "nombre": hechizo.forma,
		"coste_relativo": snappedf(hechizo.coste, 0.01), "coste_tinta": snappedf(hechizo.coste_tinta, 0.1),
		"casillas": manifestaciones, "calidad": snappedf(hechizo.calidad, 0.01), "ignorados": Array(hechizo.ignorados)})


## Marca el suelo de una casilla: es EL impacto del hechizo en ella (PruebaTest2._al_impactar, ESTADOS_SUELO.md). Las
## formas de Vfx3D.lanzar_forma son solo visuales y no emiten `impacto`, así que una casilla se marca aquí, una vez.
func marcar_celda(elemento: String, c: Vector2i) -> void:
	if mundo != null and en_mapa(c) and mundo.has_method("_al_impactar"):
		if _agua_o_hielo_en_altura(elemento, c):
			return
		var punto: Vector3 = centro_de(c, y_pies(c))
		mundo.call("_al_impactar", elemento, punto)
		al_impactar(elemento, punto)     # el hielo de un muro o corro tambien caduca a los 20 s (L3)


## H4 (DISENO_FUTURO §0b): agua, hielo y charcos SOLO existen a nivel 0. Una casilla con tierra o con una columna
## encima (altura >= 1) no recibe ese estado del suelo: el hechizo golpea el bloque, no el suelo de debajo.
func _agua_o_hielo_en_altura(elemento: String, c: Vector2i) -> bool:
	if (elemento == "agua" or elemento == "hielo") and altura_en(c) >= 1:
		PlayLog.event("estado_en_altura_rechazado", {"elemento": elemento, "celda": [c.x, c.y], "nivel": altura_en(c)})
		return true
	return false


## Todo impacto de Vfx3D pasa por aqui ANTES de llegar al suelo de PruebaTest2 (Jugador3D.montar la conecta en lugar
## de PruebaTest2._al_impactar): filtra H4 y despues deja que el mundo y `al_impactar` hagan lo de siempre.
func impacto_filtrado(elemento: String, punto: Vector3) -> void:
	if not _agua_o_hielo_en_altura(elemento, celda_de(punto)):
		if mundo != null and mundo.has_method("_al_impactar"):
			mundo.call("_al_impactar", elemento, punto)
	al_impactar(elemento, punto)


## El dibujo de lo que se queda: UNA llamada a Vfx3D.lanzar_forma por hechizo (columna: una por casilla).
func _visual_campo(receta: Receta3D, elemento: String, origen: Vector3, campo: Node3D, muro: bool, columna: bool) -> void:
	var c3: Campo = campo as Campo
	if fx == null or not Vfx3D.ELEMENTOS.has(elemento) or c3.puntos.is_empty():
		return
	var centro := Vector3.ZERO
	for p in c3.puntos:
		centro += p as Vector3
	centro /= float(c3.puntos.size())
	var radio: float = 0.0
	for p in c3.puntos:
		radio = maxf(radio, Vector2((p as Vector3).x - centro.x, (p as Vector3).z - centro.z).length())
	var pie_o := Vector3(origen.x, y_pies(celda_de(origen)), origen.z)
	var pie_c := Vector3(centro.x, y_pies(celda_de(centro)), centro.z)
	var dura: float = vida_campo(receta)
	if bool(receta.geo().get("envuelve", false)) and not receta.line:
		radio = float(receta.geo()["radio_envuelve"]) * Terreno3D.casilla    # la banda de casillas es más ancha que la forma dibujada
	if columna:
		return                                 # lo dibuja _levantar_columna casilla a casilla
	if receta.usa_geo() and String(receta.geo()["nombre"]) == "chorro":
		# Línea sola: HAZ desde la mano hacia delante, del largo de la geometría y con la vida del campo.
		var dh: Vector3 = pie_c - pie_o
		dh.y = 0.0
		if dh.length() < 0.01:
			dh = Vector3(0, 0, 1)
		var largo_m: float = float(receta.geo()["largo"]) * Terreno3D.casilla
		# Vfx3D multiplica `largo` por su `escala`: se divide aquí para que el haz dibujado mida lo que sus casillas.
		var esc: float = maxf(float(fx.get("escala")), 0.01)
		var dir_h: Vector3 = dh.normalized()
		var fin_h: Vector3 = pie_o + dir_h * largo_m
		# P2: si el haz da en algo activable, acaba en su punto de activación (largo recortado y altura de la punta en `y` del destino).
		var y_vuelo: float = y_pies(celda_de(origen)) + Terreno3D.ALTO_NIVEL * 0.5 * float(1 + c3.nivel)
		var p_act: Vector3 = _activacion_en_haz(Vector3(origen.x, y_vuelo, origen.z), dir_h, largo_m, c3.rune)
		if p_act != Vector3.INF:
			largo_m = clampf((p_act - pie_o).dot(dir_h), Terreno3D.casilla * 0.5, largo_m)
			fin_h = Vector3(pie_o.x + dir_h.x * largo_m, p_act.y, pie_o.z + dir_h.z * largo_m)
		fx.lanzar_forma("chorro", elemento, pie_o, fin_h, {"largo": largo_m / esc, "dura": dura})
	elif muro or receta.line:
		# Barrera que avanza (barrera + flecha) o muro de `linea`: MURO, con la duración real del campo.
		var d: Vector3 = (c3.dirs[0] as Vector3) if not c3.dirs.is_empty() else Vector3.ZERO
		if d.length() < 0.01:
			d = pie_c - pie_o
			d.y = 0.0
		if d.length() < 0.01:
			d = Vector3(0, 0, 1)
		fx.lanzar_forma("muro", elemento, pie_c - d.normalized() * 1.0, pie_c, {"radio": clampf(radio, 0.6, 3.0), "dura": dura})
	else:
		if receta.expande():
			# barrera + pulso (6.4): el ANILLO (de piedra, si es tierra) NACE en ti y CRECE hasta su radio. `crece` y `rompe`
			# son opciones nuevas pedidas al Pipeline (6.17); mientras no las lea, el anillo sale ya en su radio.
			var dura_corro: float = DURACION_TIERRA if elemento == "tierra" else minf(dura, 3.0)
			fx.lanzar_forma("corro", elemento, pie_o, pie_c, {"radio": clampf(radio, 0.6, 3.5), "dura": dura_corro,
				"crece": true, "t_crece": T_CRECE, "rompe": elemento == "tierra" or elemento == "hielo"})
		else:
			# Barrera quieta (6.3, 6.4): CÚPULA que envuelve al personaje y LE SIGUE; la de tierra es de bloques. Vive lo que el campo.
			var antes: Array = fx.get_children()
			# Burbuja: el radio REAL (RADIO_BURBUJA, el de la colisión). Vfx3D multiplica `radio` por su `escala`, de ahí la división.
			# Mientras el Pipeline no tenga la forma "burbuja" se pide la "cupula" de siempre; cuando exista se usa sola (FORMAS).
			var esc_b: float = maxf(float(fx.get("escala")), 0.01)
			var forma_b: String = "burbuja" if Vfx3D.FORMAS.has("burbuja") else "cupula"
			fx.lanzar_forma(forma_b, elemento, pie_o, pie_c, {"radio": RADIO_BURBUJA / esc_b, "dura": dura,
				"rompe": elemento == "tierra" or elemento == "hielo"})
			for h in fx.get_children():
				if antes.has(h) or not (h is Node3D) or h is Light3D:
					continue
				# La raíz de la cúpula nace en el centro pedido y lleva mallas (esfera de shader o, en tierra, piedras).
				var d_xz := Vector2((h as Node3D).position.x - pie_c.x, (h as Node3D).position.z - pie_c.z)
				if d_xz.length() < 0.05 and not (h as Node).find_children("*", "MeshInstance3D", true, false).is_empty():
					c3.visual = h as Node3D
					c3.visual_rel = (h as Node3D).position - (jugador as Node3D).position
					break


## La burbuja protege: una a la vez (la nueva sustituye a la vieja, que se va sin reventar) y el jugador se la apunta para parar golpes.
## 16/10: ya no hay escudo de vida ni «×1,5 por barrera repetida» (8.5): la burbuja para UN impacto y revienta; repetirla es una nueva.
func _proteger_con(campo: Node3D) -> void:
	if _barrera_activa != null and is_instance_valid(_barrera_activa) and _barrera_activa != campo:
		_barrera_activa.queue_free()
	_barrera_activa = campo as Campo


## ¿Hay una barrera viva que pueda parar este golpe? La llama Jugador3D.recibir_dano.
## 8/10 · LA BARRERA DEVUELVE SU ELEMENTO: cuando para el golpe de un enemigo, le aplica a ESE enemigo el elemento de la barrera
## de forma estándar (el mismo efecto que un hechizo de ese elemento: fuego quema, agua moja o cura al elemental, tierra
## ralentiza, hielo congela...) pero SIN daño directo: el daño del golpe ya lo ha absorbido ella. `desde` es la posición del
## atacante (la que pasa Combate3D a recibir_dano), con la que se localiza al enemigo.
func atacante_en(desde: Vector3) -> Combate3D:
	var mejor: Combate3D = null
	var dmin: float = 1.2
	for g in get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(g) or (g as Combate3D).muerto:
			continue
		var d: float = Vector2((g as Node3D).position.x - desde.x, (g as Node3D).position.z - desde.z).length()
		if d < dmin:
			dmin = d
			mejor = g as Combate3D
	return mejor


func aplicar_elemento(enemigo: Combate3D, elemento: String) -> void:
	if enemigo == null or not is_instance_valid(enemigo) or enemigo.muerto or elemento == "":
		return
	for k in rune_database.keys():
		var r: RuneData = rune_database[k]
		if Objetos.elemento_de(r) == elemento:
			var sin_dano: Hechizo = Hechizo.construir(r, {})        # el elemento solo, sin daño: aplica su estado y su empuje
			sin_dano.dano = 0.0
			var dir: Vector3 = enemigo.position - jugador.position
			dir.y = 0.0
			enemigo.golpe(sin_dano, dir.normalized() if dir.length() > 0.01 else Vector3.ZERO)
			PlayLog.event("barrera_aplica_elemento", {"elemento": elemento, "a": enemigo.nombre})
			return


func absorber_golpe(cantidad: float, desde: Vector3) -> bool:
	if _barrera_activa == null or not is_instance_valid(_barrera_activa):
		_barrera_activa = null
		return false
	return _barrera_activa.absorber(cantidad, desde)


## ¿Hay una burbuja VIVA que contenga este punto? Para lo ajeno que vuela (la flecha de un goblin) y quiere saber si ya la tocó.
func burbuja_contiene(p: Vector3) -> bool:
	return _barrera_activa != null and is_instance_valid(_barrera_activa) and _barrera_activa.contiene(p)


## Algo AJENO con `elemento` ("" = golpe o flecha normal) toca la burbuja en `punto`: la burbuja revienta con él. Devuelve true si
## había una burbuja que lo ha parado. `atacante` (opcional) recibe el elemento de la burbuja, como en el golpe cuerpo a cuerpo (8/10).
func burbuja_recibe(elemento: String, punto: Vector3, atacante: Combate3D = null) -> bool:
	if _barrera_activa == null or not is_instance_valid(_barrera_activa):
		_barrera_activa = null
		return false
	return _barrera_activa.reventar(elemento, punto, atacante)


## Lo que le pasa al mundo cuando una burbuja de `barrera` revienta con `recibido` en `punto` (tabla REACCIONES_BURBUJA). Estática: se
## mide sin lanzador. Devuelve el nombre de la reacción: «vapor», «charco», «absorbe» (la tierra) o «» (ninguna).
static func reaccion_burbuja(barrera: String, recibido: String, punto: Vector3) -> String:
	var r: Array = (REACCIONES_BURBUJA.get(barrera, {}) as Dictionary).get(recibido, [])
	if r.is_empty():
		return "absorbe" if barrera == "tierra" else ""
	var nombre: String = String(r[0])
	if nombre == "vapor" and Mundo3D.actual != null:
		Mundo3D.actual.avisar_impacto(punto, "vapor", RADIO_BURBUJA)       # la maqueta pinta la bocanada (ver _al_impacto_mundo)
	var accion := AccionElemental.nueva(String(r[1]), punto)
	accion.toca_suelo = false      # solo agua de la simulación: la maqueta no pinta nada en el suelo ahí, y el estado no debe saber más que la imagen
	Mundo3D.aplicar_accion(accion)     # evapora el agua del punto / echa el charco
	return nombre


## ¿Se puede construir un bloque (tierra, hielo) de `niveles` de alto en la casilla `c`? "" = sí; si no, el MOTIVO en una frase corta para el aviso. Es la regla que usa `construir_tierra`
## (fuera del mapa, agua o puente, bloqueada, cornisa permanente, encima de la jugadora o de un enemigo) más el tope de altura que se sube (`Jugador3D.MAX_NIVELES_SUBIBLES`), sacada aquí
## para poder preguntarla EN SECO antes de cobrar (`rechazo_de_construccion`): sin esto, un sólido que no cabía se rechazaba en silencio con la tinta y la recarga ya gastadas.
## `sobre_agua`: el hielo hiela el agua que cubre (marcar_celda) y por eso sí cabe sobre ella; la tierra no.
func puede_construir_en(c: Vector2i, niveles: int = 1, sobre_agua: bool = false) -> String:
	if not en_mapa(c):
		return "fuera del mapa"
	# El agua de un río está «bloqueada» por sí misma: el hielo que la hiela no se rechaza por eso (hielo quieto sobre agua = helarla, como antes), la tierra sí.
	var hiela_agua: bool = sobre_agua and es_agua(c)
	if not sobre_agua:
		if es_agua(c):
			return "es agua"
		var l: String = letra_de(c)
		if l == "~" or l == "b":
			return "es agua o puente"
	if bloqueada(c) and not hiela_agua:
		return "la casilla está ocupada"
	if Terreno3D.permanentes.has(c):
		return "hay una cornisa"
	if jugador != null and bool(jugador.call("ocupa", c)):
		return "estás encima"
	for g in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and celda_de((g as Node3D).position) == c:
			return "hay un enemigo"
	if niveles > Jugador3D.MAX_NIVELES_SUBIBLES:
		return "demasiada altura"
	return ""


## ¿El sólido quieto que se va a lanzar (`datos` de `cast_page`) puede construirse donde nace (`origen`)? "" = sí (o no es un sólido quieto: no hay nada que mirar); si no, el motivo.
## Se pregunta ANTES de cobrar tinta y recarga. Mira la casilla apuntada (la que el rasterizado incluye siempre) y que no esté más lejos del anillo de alcance (`ALCANCE_ORIGEN`).
func rechazo_de_construccion(datos: Dictionary, origen: Vector3) -> String:
	var receta: Receta3D = datos.get("receta")
	var rune: RuneData = datos.get("rune")
	if receta == null or rune == null or jugador == null:
		return ""
	var h: Hechizo = receta.hechizo(rune)
	if h == null or not h.solido_quieto:
		return ""
	# Una barrera (solidez > 0) protege con su SolidezV2 aunque el bloque de tierra de debajo no quepa (el muro que nace en tu propia casilla y te cubre: escenario_bosque_01_v01 4.6): se lanza como siempre.
	if h.solidez > 0.0:
		return ""
	if h.en_punto:
		var lejos: Vector3 = origen - (jugador as Node3D).position
		lejos.y = 0.0
		if lejos.length() > ALCANCE_ORIGEN * Terreno3D.casilla + TOLERANCIA_ALCANCE_U:
			return "queda fuera de tu alcance"
	return puede_construir_en(celda_de(origen), h.niveles, rune.deja == "helado")


## Un bloque de tierra en la casilla. Se apila hasta MAX_TIERRA_APILADA, caduca a los 25 s y hay un tope de
## MAX_NIVELES_TIERRA vivos a la vez (el más viejo se deshace antes). No se construye sobre agua, sobre algo
## sólido ni encima de alguien.
## `opc` (R2, solo lo pasa la materia V2; vacío = como siempre): resta (s que dura), color, apilar (bloques máx. en la casilla), v2 (no cuenta para
## el tope FIFO de MAX_NIVELES_TIERRA: un volumen entero no debe borrar la tierra que ya había).
func construir_tierra(c: Vector2i, dibujar: bool = true, opc: Dictionary = {}) -> bool:
	if puede_construir_en(c) != "":
		return false
	var entrada: Dictionary = {}
	for b in _bloques:
		if (b["celda"] as Vector2i) == c:
			entrada = b
	if entrada.is_empty():
		entrada = {"celda": c, "niveles": 0, "nodos": [], "resta": float(opc.get("resta", DURACION_TIERRA)), "v2": bool(opc.get("v2", false))}
		_bloques.append(entrada)
	elif int(entrada["niveles"]) >= int(opc.get("apilar", MAX_TIERRA_APILADA)):
		entrada["resta"] = float(opc.get("resta", DURACION_TIERRA))
		return false
	entrada["niveles"] = int(entrada["niveles"]) + 1
	entrada["resta"] = float(opc.get("resta", DURACION_TIERRA))
	var n: int = int(entrada["niveles"])
	var bloque := Area3D.new()              # Area3D: así la placa de peso (grupo "peso") lo nota
	bloque.name = "BloqueTierra"
	bloque.collision_layer = 1
	bloque.collision_mask = 0
	bloque.monitoring = false
	bloque.add_to_group("peso")
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(Terreno3D.casilla * 0.8, Terreno3D.ALTO_NIVEL * 0.9, Terreno3D.casilla * 0.8)
	cs.shape = forma
	bloque.add_child(cs)
	var caja := BoxMesh.new()
	caja.size = Vector3(Terreno3D.casilla * 0.94, Terreno3D.ALTO_NIVEL, Terreno3D.casilla * 0.94)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = opc.get("color", Color(0.5, 0.37, 0.24))
	mat.roughness = 1.0
	caja.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	var facetado: bool = dibujar and VfxTierra.vestir_bloques       # 21/10: GANCHO de dibujo (VFX de tierra): 4 trozos facetados que emergen en vez de la caja
	mi.visible = dibujar and not facetado   # con el anillo de tierra dibujado encima, el bloque es solo colisión
	bloque.add_child(mi)
	var centro: Vector3 = centro_de(c, Terreno3D.alto_suelo + Terreno3D.ALTO_NIVEL * (float(n) - 0.5))
	bloque.position = centro - Vector3(0, Terreno3D.ALTO_NIVEL * 0.6, 0)
	mundo.add_child(bloque)
	if facetado:
		VfxTierra.vestir_bloque(bloque, caja.size, Vector3(centro.x, centro.y - Terreno3D.ALTO_NIVEL * 0.5, centro.z))      # solo dibujo: la colisión de arriba no cambia
	(entrada["nodos"] as Array).append(bloque)
	var tw: Tween = bloque.create_tween()
	tw.tween_property(bloque, "position", centro, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recalcular(c)
	_aplicar_tope_tierra()
	return true


func _niveles_de_tierra() -> int:
	var n: int = 0
	for b in _bloques:
		if not bool(b.get("v2", false)):
			n += int(b["niveles"])
	return n


## El tope: si hay más de MAX_NIVELES_TIERRA bloques vivos, se deshace la entrada más antigua entera.
func _aplicar_tope_tierra() -> void:
	while _niveles_de_tierra() > MAX_NIVELES_TIERRA and _bloques.size() > 1:
		var peor: Dictionary = {}
		for b in _bloques:
			if bool(b.get("v2", false)):
				continue                            # los volúmenes V2 no entran en el FIFO (ver construir_tierra)
			if peor.is_empty() or float(b["resta"]) < float(peor["resta"]):
				peor = b
		if peor.is_empty():
			break
		_deshacer_bloque(peor)


func _deshacer_bloque(b: Dictionary) -> void:
	for n in (b["nodos"] as Array):
		if is_instance_valid(n):
			var mi: Node3D = n as Node3D
			var tw: Tween = mi.create_tween()
			tw.tween_property(mi, "scale", Vector3(1.0, 0.02, 1.0), 0.2)
			tw.tween_callback(mi.queue_free)
	_bloques.erase(b)
	_recalcular(b["celda"] as Vector2i)


## Columna de barrera + levitación: sólida, subible (hasta 2 niveles) y bloquea proyectiles. Dura lo que el campo.
func _levantar_columna(campo: Node3D, duracion: float, niveles: int, color: Color) -> void:
	var celdas: Dictionary = {}
	for pt in (campo as Campo).puntos:
		var c: Vector2i = celda_de(pt as Vector3)
		if not en_mapa(c) or es_agua(c) or bloqueada(c) \
				or jugador != null and bool(jugador.call("ocupa", c)):
			continue
		celdas[c] = true
	for c in celdas:
		var caja := BoxMesh.new()
		caja.size = Vector3(Terreno3D.casilla * 0.9, Terreno3D.ALTO_NIVEL * float(niveles), Terreno3D.casilla * 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.lightened(0.3), 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.4
		caja.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = caja
		mi.name = "ColumnaBarrera"
		mi.position = centro_de(c as Vector2i, Terreno3D.alto_suelo + Terreno3D.ALTO_NIVEL * float(niveles) * 0.5)
		mundo.add_child(mi)
		_columnas.append({"celda": c, "niveles": niveles, "resta": duracion, "nodo": mi})
		if fx != null and Vfx3D.ELEMENTOS.has(Objetos.elemento_de(campo_rune(campo))):
			var pie_c := Vector3(centro_de(c as Vector2i).x, y_pies(c as Vector2i), centro_de(c as Vector2i).z)
			fx.lanzar_forma("columna", Objetos.elemento_de(campo_rune(campo)), pie_c, pie_c, {"dura": minf(duracion, 3.0)})
		_recalcular(c as Vector2i)


func campo_rune(campo: Node3D) -> RuneData:
	return (campo as Campo).rune


## alturas[c] = lo más alto entre lo permanente, la tierra y las columnas de esa casilla.
func _recalcular(c: Vector2i) -> void:
	var n: int = int(Terreno3D.permanentes.get(c, 0))
	for b in _bloques:
		if (b["celda"] as Vector2i) == c:
			n = maxi(n, int(b["niveles"]))
	for k in _columnas:
		if (k["celda"] as Vector2i) == c:
			n = maxi(n, int(k["niveles"]))
	if n <= 0:
		Terreno3D.alturas.erase(c)
	else:
		Terreno3D.alturas[c] = n
	if Terreno3D.agua_sim != null:
		Terreno3D.agua_sim.refrescar_casilla(c)        # 11.4: la tierra levantada hace de presa; al caducar, el agua pasa


## =====================================================================================================
##  Lo que caduca: tierra (25 s), columnas e hielo (20 s) (4.1c)
## =====================================================================================================

func _avanzar_caducidades(delta: float) -> void:
	for b in _bloques.duplicate():
		b["resta"] = float(b["resta"]) - delta
		var aviso: bool = float(b["resta"]) < AVISO_CADUCA
		for n in (b["nodos"] as Array):
			if is_instance_valid(n):
				(n as Node3D).visible = not aviso or int(float(b["resta"]) * 6.0) % 2 == 0
		if float(b["resta"]) <= 0.0:
			_deshacer_bloque(b)
	for k in _columnas.duplicate():
		k["resta"] = float(k["resta"]) - delta
		if float(k["resta"]) <= 0.0:
			if is_instance_valid(k["nodo"]):
				(k["nodo"] as Node).queue_free()
			_columnas.erase(k)
			_recalcular(k["celda"] as Vector2i)
	_t_hielo += delta
	if _t_hielo >= 0.25:
		var dt: float = _t_hielo
		_t_hielo = 0.0
		for c in _hielo.keys():
			var e: Dictionary = _hielo[c]
			if not _casilla_helada(c as Vector2i):
				_hielo.erase(c)               # otro lo deshizo (fuego): ya no hay nada que caducar
				continue
			if hielo_permanente.has(c):
				continue
			e["resta"] = float(e["resta"]) - dt
			if float(e["resta"]) <= 0.0:
				_derretir(c as Vector2i, bool(e["agua"]))
				_hielo.erase(c)


func _casilla_helada(c: Vector2i) -> bool:
	return en_mapa(c) and Terreno3D.helada(c)      # B2: el estado oficial; la maqueta ya no tiene imagen propia


## Cada impacto de hielo o de agua puede haber helado una casilla: si es así, se apunta cuándo se deshace.
## Va DESPUÉS del manejador de PruebaTest2 (se conecta más tarde), así que el estado ya está escrito.
func al_impactar(elemento: String, punto: Vector3) -> void:
	# 11.4: el agua de la simulación Y (21/10) el estado del suelo (mojada, helada, quemada), con la misma regla que la maqueta acaba de pintar.
	# `aplicar_accion` es el único punto: ningún hechizo escribe estados por su cuenta.
	Mundo3D.aplicar_accion(AccionElemental.nueva(elemento, punto))
	if elemento != "hielo" and elemento != "agua":
		return
	var c: Vector2i = celda_de(punto)
	if not en_mapa(c) or not _casilla_helada(c):
		return
	if _hielo.has(c):
		return                              # el hielo se aplica una vez: otro hielo encima NO renueva los 20 s (Pablo, 12/10)
	_hielo[c] = {"resta": DURACION_HIELO, "agua": letra_de(c) == "~"}
	PlayLog.event("hielo", {"celda": [c.x, c.y], "agua": letra_de(c) == "~"})


## El hielo se deshace: el agua vuelve a ser agua (y se vuelve a bloquear para quien camina) y el suelo
## neutro se queda mojado. Quien estuviera encima cae al agua (Jugador3D lo ve solo).
func _derretir(c: Vector2i, era_agua: bool) -> void:
	if Terreno3D.agua_sim != null:
		Terreno3D.agua_sim.helar_casilla(c, false)     # 11.4: el agua vuelve a correr
	if era_agua:
		Terreno3D.poner_helada(c, false)
		bloquear_celda(c)
	else:
		ReaccionesSuelo3D.derretir(c)      # el estado del suelo: sin escarcha y mojada (el suelo lo dibuja leyendo ese estado)
	if mundo != null and mundo.has_method("quitar_placa_hielo"):
		mundo.call("quitar_placa_hielo", c)      # 11.16: sin hielo no hay placa (antes lo hacía el canal B de la imagen de la maqueta)
	if fx != null:
		fx.vapor(centro_de(c, Terreno3D.alto_agua if era_agua else Terreno3D.alto_suelo))
	PlayLog.event("hielo_deshecho", {"celda": [c.x, c.y]})


func marcas_de_hielo() -> int:
	return _hielo.size()


func bloques_de_tierra() -> int:
	return _niveles_de_tierra()


## =====================================================================================================
##  Deshacer y vaciar: los huecos se liberan con el libro
## =====================================================================================================

func clear_sequence() -> void:
	super.clear_sequence()


## =====================================================================================================
##  RECETA V2: el volumen es un ELIPSOIDE (docs/GLIFOS_RECETA.md §2.1)
## =====================================================================================================
##
## Sin nombres de forma: lo que antes eran siete ramas escritas a mano (chorro, muro, arco, corro, columna…) aquí es SOLO el tamaño de
## tres semiejes. «Muro» es X grande, «pilar» es Y grande, «haz» es Z grande. El nombre se DERIVA al final, y solo para elegir la animación
## de lanzar, el cast point y el VFX (`nombre_derivado`).
##
## `g` es lo que devuelve `Sigils.aplicar_v2` ({x, y, z: semiejes en casillas, props}). Marco local, orientado a la mirada:
## Z = hacia delante, X = de lado, Y = arriba. NACE EN LA MANO y QUIETO: el elipsoide se estira hacia delante manteniendo su
## extremo de atrás a RADIO_BASE_V2 de la mano, es decir, su centro se adelanta (z − radio base) casillas. Con los tres ejes en el radio
## base (sin glifos) es una esfera de una casilla de diámetro centrada en la mano.
class GeometriaV2 extends RefCounted:
	## Margen para comparar semiejes en coma flotante. Un eje «domina» si es el mayor; en un empate gana Z, luego Y, luego X (el orden del doc).
	const EPS: float = 0.0001

	## Cuánto se adelanta el centro del volumen sobre la mano, en casillas: (z − radio base) para que el extremo de atrás se quede en la mano. **Con barrera
	## (props.solidez) es 0**: el volumen es la circunferencia que rodea al jugador y está centrado en él (18/10, Pablo). Lo usan `celdas`, el alambre del
	## laboratorio y debería usarlo el VFX por estado (mismo criterio: `props` tiene `solidez` ⇒ centro en el jugador).
	static func adelanto(g: Dictionary) -> float:
		if (g.get("props", {}) as Dictionary).has("solidez"):
			return 0.0
		return float(g["z"]) - Sigils.RADIO_BASE_V2

	## La geometría de una receta: lo de Sigils.aplicar_v2 más lo que el resto del Lanzador pregunta a `Receta3D.geo()`.
	static func evaluar(contadores: Dictionary) -> Dictionary:
		var g: Dictionary = Sigils.aplicar_v2(contadores)
		var viaja: bool = float((g["props"] as Dictionary).get("viaja", 0.0)) > 0.0
		g["nombre"] = nombre_derivado(g, viaja)
		g["viaja"] = viaja
		g["y_tope"] = niveles(g) - 1                    # niveles que sube por encima del suelo (como en GeometriaHechizo)
		g["valida"] = true                              # R1: el tope de pisar (MAX_NIVELES_SUBIBLES) se decide con la materia (F2)
		g["aviso"] = ""
		return g

	## Volumen del elipsoide, en casillas cúbicas.
	static func volumen(g: Dictionary) -> float:
		return Sigils.volumen_v2(g)

	## Niveles de altura que ocupa (mínimo 1: la esfera base ocupa el del suelo). Cada glifo de altura suma un nivel.
	static func niveles(g: Dictionary) -> int:
		return maxi(1, roundi(2.0 * float(g["y"])))

	## Eje en el que más se estira: "x" | "y" | "z", o "esfera" si no se ha estirado ninguno.
	static func eje_dominante(g: Dictionary) -> String:
		var mayor: String = "z"
		for e in ["y", "x"]:                            # Z primero: gana los empates
			if float(g[e]) > float(g[mayor]) + EPS:
				mayor = e
		return mayor if float(g[mayor]) > Sigils.RADIO_BASE_V2 + EPS else "esfera"

	## Nombre para la animación de lanzar, el cast point y el VFX (LAB_CASTPOINT): lo que VIAJA o se estira hacia delante (Z) sale con la
	## mano al frente ("x_mano"); lo que domina en altura se eleva ("alto"); lo plano y quieto se pone en el suelo ("abajo"). Una esfera, o una mezcla que no
	## encaja en ninguna (p. ej. ancho y alto a la vez sin Z), sale con la mano al frente: es el lanzar de siempre.
	static func nombre_derivado(g: Dictionary, viaja: bool) -> String:
		if bool(g.get("haz", false)):
			return "x_mano"                             # RAYO (21/10): ᛁ + elemento es un haz; sale con la mano al frente aunque ᛁ vaya en X (ancho) o en Z (fondo)
		var dom: String = eje_dominante(g)
		if viaja or (dom == "z" and float(g["z"]) > float(g["x"]) + EPS and float(g["z"]) > float(g["y"]) + EPS):
			return "x_mano"
		if dom == "y":
			return "alto"
		if dom != "esfera" and float(g["y"]) <= Sigils.RADIO_BASE_V2 + EPS:
			return "abajo"
		return "x_mano"

	## Aviso si este volumen no se puede lanzar con este elemento ("" = se puede). Hoy: un SÓLIDO más alto de lo que el jugador sube
	## (`Jugador3D.MAX_NIVELES_SUBIBLES`) no se lanza, sea pisable o no (lo no pisable sería un muro inalcanzable). Mismo texto y mismo
	## `y_tope` que el aviso de siempre. Los demás estados no tienen tope de altura: el agua no se apila, un gas o un campo no se pisan.
	static func aviso_materia(g: Dictionary, rune: RuneData) -> String:
		if rune == null or rune.estado != "solido":
			return ""
		var n: int = niveles(g)
		if n <= Jugador3D.MAX_NIVELES_SUBIBLES:
			return ""
		return "Demasiada altura: sube %d niveles y solo se pueden pisar %d. No se lanza." % [n, Jugador3D.MAX_NIVELES_SUBIBLES]

	## Rasteriza el elipsoide sobre las casillas: una casilla cuenta si su CENTRO cae dentro (en planta, a la altura de la mano), y
	## SIEMPRE la del origen, para que la esfera base no desaparezca si su centro cae justo entre dos casillas. `origen` y `dir` en
	## el plano del suelo (x, z del mundo, en metros), `casilla` = lado de una casilla en metros. Devuelve Array[Vector2i].
	static func celdas(g: Dictionary, origen: Vector2, dir: Vector2, casilla: float) -> Array:
		var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		var perp: Vector2 = d.orthogonal()
		var sx: float = float(g["x"])
		var sz: float = float(g["z"])
		var avance: float = adelanto(g)          # el centro se adelanta: el extremo de atrás se queda en la mano (con barrera, 0: centrado en el jugador)
		var c0 := Vector2i(int(floorf(origen.x / casilla)), int(floorf(origen.y / casilla)))
		var n: int = int(ceilf(maxf(sx, sz * 2.0))) + 1
		var salida: Array = []
		for dx in range(-n, n + 1):
			for dz in range(-n, n + 1):
				var c := Vector2i(c0.x + dx, c0.y + dz)
				var centro := Vector2((float(c.x) + 0.5) * casilla, (float(c.y) + 0.5) * casilla)
				var rel: Vector2 = (centro - origen) / casilla
				var lz: float = rel.dot(d) - avance
				var lx: float = rel.dot(perp)
				if (lz * lz) / (sz * sz) + (lx * lx) / (sx * sx) <= 1.0 or c == c0:
					salida.append(c)
		return salida


## =====================================================================================================
##  Receta en 3D: lee SpellRecipe sin tocarla
## =====================================================================================================

class Receta3D extends SpellRecipe:
	## R3 (17/10): la receta V2 es la ÚNICA. Desaparecen `antigua`, el interruptor `V2`, `GLIFOS_GEO` y las siete ramas con nombre de
	## GeometriaHechizo: los contadores van directos a `Sigils.aplicar_v2` y `geo()` es `GeometriaV2`.

	## Glifos aparcados (17/10): se pueden dibujar sin romper nada, pero aún no hacen nada. La receta los apunta en `ignorados` y el
	## Lanzador avisa «Aún sin uso».
	const APARCADOS: PackedStringArray = ["retardo", "atraccion", "espejo", "amplificar"]

	## Glifos que la v2 no conoce (los aparcados y cualquier otro): no rompen la receta, se anotan aquí.
	var ignorados: PackedStringArray = PackedStringArray()

	## Cuántas veces se dibujó cada glifo V2 (un multiconjunto: el orden de dibujo no cuenta).
	var contadores: Dictionary = {}
	var _geo: Dictionary = {}

	## Se conserva porque el resto del Lanzador (campos antiguos, `_spread_points`) lo lee; en la V2 nunca vale true.
	var line: bool = false

	## Un glifo suma a su contador y la recarga sale de la tabla. No pasa por SpellRecipe.apply: la V2 no usa FORM/OPERATOR.
	## `levitacion` (ᛏ) vale como `altura` (Sigils.ALIAS_V2): ya no tiene significado propio.
	func apply(sigil_name: String) -> void:
		_geo = {}
		var nombre: String = Sigils.glifo_v2(sigil_name)
		if Sigils.GLIFOS_V2.has(nombre):
			contadores[nombre] = int(contadores.get(nombre, 0)) + 1
			cooldown = Sigils.cooldown_v2(contadores)
		else:
			ignorados.append(sigil_name)
		_sincronizar()

	## HC2: el `Hechizo` que sale de esta receta con un elemento (los glifos dibujados, la calidad del trazo y lo que la receta no conoce, anotado en `ignorados`).
	func hechizo(rune: RuneData, permitir_cinematico: bool = false) -> Hechizo:
		var h: Hechizo = Hechizo.construir(rune, contadores, calidad, permitir_cinematico)
		if h == null:
			return null                                    # runa cinemática sin permiso (ver Hechizo.construir)
		h.ignorados.append_array(ignorados)
		return h

	## Coste en tinta de la receta (número relativo; ver Sigils.coste_v2): la esfera base vale 1.
	func coste_v2() -> float:
		var g: Dictionary = geo()
		return Sigils.coste_v2(g, g["props"])

	## Siempre true: no hay otro camino. Se deja por los que aún preguntan.
	func usa_geo() -> bool:
		return true

	## La geometría de esta receta (se recalcula al añadir glifos).
	func geo() -> Dictionary:
		if _geo.is_empty():
			_geo = GeometriaV2.evaluar(contadores)
		return _geo

	## Los indicadores antiguos (los lee el resto del Lanzador) se derivan de los números de la receta; cada uno sale de UNA propiedad o eje.
	func _sincronizar() -> void:
		var g: Dictionary = geo()
		var props: Dictionary = g["props"]
		travels = bool(g["viaja"])
		reach = 1 if travels else 0
		spread = float(g["x"]) > Sigils.RADIO_BASE_V2 or float(g["z"]) > Sigils.RADIO_BASE_V2
		line = false
		blocks = props.has("solidez")
		height = int(g["y_tope"])
		barriers = 0
		copies = int(props.get("copias", 1.0))
		bounces = int(props.get("rebotes", 0.0))
		pulse = props.has("crece")
		lifetime = 0.0

	## Muro quieto delante del lanzador (solo para los campos antiguos de las pruebas de burbuja).
	func _spread_points(centros: Array, dir: Vector2) -> Array:
		if not line or travels:
			return super._spread_points(centros, dir)
		var salida: Array = []
		var perp := dir.orthogonal()
		var mitad: int = Sigils.wall_half(barriers)
		for centro in centros:
			for k in range(-mitad, mitad + 1):
				salida.append(centro + dir * TILE * 1.5 + perp * TILE * float(k))
		return salida

	## ¿Es un muro (de línea o de barrera + flecha)?
	func es_muro() -> bool:
		return line or _es_barrera_movil()

	## Nombre DERIVADO de las medidas (x_mano · alto · abajo): lo único que se usa para elegir cast point y animación (LAB_CASTPOINT.md).
	## Ya no es una forma con nombre en la lógica: sale de qué eje domina y de si viaja.
	func forma() -> String:
		return String(geo()["nombre"])

	func es_volador() -> bool:
		return _es_volador()

	func es_barrera_movil() -> bool:
		return _es_barrera_movil()

	func es_quieto() -> bool:
		return _es_quieto()

	func sigue() -> bool:
		return false

	## PUENTE TEMPORAL: Vfx3D y el clip de lanzar de Pj3D (Pipeline) solo conocen las formas de siempre. Cada nombre derivado se traduce al
	## clip más parecido que ya existe hasta que el Pipeline adopte x_mano/alto/abajo (ver diario, entrada de R3):
	##   x_mano -> proyectil (mano al frente) · alto -> columna (manos arriba) · abajo -> corro (golpe al suelo).
	func forma_vfx() -> String:
		match forma():
			"alto":
				return "columna"
			"abajo":
				return "corro"
		return "proyectil"

	func expande() -> bool:
		return _expande()

	## Cuánto vive lo que se queda (segundos de juego). Las mismas cuentas que SpellRecipe._construir.
	func vida() -> float:
		var factor: float = Sigils.quality_factor(calidad)
		var v: float = (Sigils.BASE_LIFETIME + lifetime) * factor
		if _es_barrera_movil():
			v = Sigils.WALL_LIFETIME * factor
		elif _es_chorro():
			v = (Sigils.BASE_LIFETIME + lifetime + Sigils.jet_hold(reach)) * factor
		return v

	## El elemento con el daño potenciado (sin tocar el .tres compartido).
	func potenciada(element: RuneData) -> RuneData:
		return _powered(element)

	## Las manifestaciones en CASILLAS relativas al origen y con la dirección del eje +X como «delante»: [{p, dir, nivel, elev}].
	func manifestaciones() -> Array:
		var c := Vector2(0.5, 0.5) * Terreno3D.casilla      # origen en el centro de una casilla: sin sesgo de rejilla
		return manifestaciones_en(c, Vector2.RIGHT)

	## Las casillas del volumen para un lanzamiento real. `origen` es el mundo (x, z) en metros y `dir` la mirada. Rasteriza el elipsoide y lo
	## apila `niveles` veces. Devuelve casillas relativas al origen en el marco donde +X es «delante».
	func manifestaciones_en(origen: Vector2, dir: Vector2) -> Array:
		var res: Array = []
		var g: Dictionary = geo()
		var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		var giro: float = d.angle()
		var cas: float = Terreno3D.casilla
		var niveles_g: int = GeometriaV2.niveles(g)
		for c in GeometriaV2.celdas(g, origen, d, cas):
			var centro := Vector2((float((c as Vector2i).x) + 0.5) * cas, (float((c as Vector2i).y) + 0.5) * cas)
			var local: Vector2 = ((centro - origen) / cas).rotated(-giro)
			for nivel in range(niveles_g):
				res.append({"p": local, "dir": Vector2.RIGHT, "nivel": nivel, "elev": 0.0})
		if res.size() > Sigils.MAX_MANIFESTATIONS:
			res.resize(Sigils.MAX_MANIFESTATIONS)
		return res


## =====================================================================================================
##  Campo: un conjunto de puntos del mismo hechizo que viven un rato
## =====================================================================================================

class Campo extends Node3D:
	var lanz: Lanzador3D = null
	var rune: RuneData = null
	var elemento: String = ""
	var nivel: int = 0
	var bloquea: bool = false
	var refleja: bool = false
	var atrae: bool = false
	var atraviesa: bool = false
	var viaja: bool = false
	var altura_barrera: int = 0
	var vida: float = 1.0
	var caudal: float = 0.0          ## u³/s que aporta cada casilla tocada al agua de la simulación (chorro de agua, 11.4)
	var sigue: Node3D = null
	var visual: Node3D = null        ## la cúpula de Vfx3D, que se mueve con el jugador (6.3)
	var visual_rel: Vector3 = Vector3.ZERO
	var burbuja: bool = false        ## es la barrera-burbuja (Fase 12): una esfera que sigue al jugador y revienta al primer impacto
	var reventada: bool = false      ## ya ha reventado (ya no para nada, y solo se va a liberar al final del fotograma)
	var reaccion: String = ""        ## qué reacción hubo al reventar («vapor», «charco», «absorbe» o «»): para las pruebas y el diario
	var _t_vigia: float = 0.0        ## s hasta volver a mirar el mundo (fuego y electricidad) alrededor de la burbuja

	var puntos: Array = []          ## Vector3
	var vel: Array = []             ## Vector3
	var dirs: Array = []            ## Vector3 (ZERO si quieto)
	var niveles: Array = []         ## int: piso de la columna
	var vivos: Array = []           ## bool
	var rel: Array = []             ## Vector3 respecto al jugador (para lo que te sigue)

	var _t: float = 0.0
	var _golpeados: Dictionary = {}
	var _celdas: Dictionary = {}
	var _forma: SphereShape3D = null

	## Se emite al reventar la burbuja: con qué elemento ("" = golpe/flecha normal), dónde y qué reacción hubo.
	signal revento(recibido: String, punto: Vector3, reaccion: String)

	func iniciar() -> void:
		_forma = SphereShape3D.new()
		_forma.radius = Lanzador3D.RADIO_GOLPE * Terreno3D.casilla
		name = "Campo_" + elemento
		if burbuja:
			return                          # la burbuja no marca el suelo de alrededor: solo lo toca al reventar
		for i in range(puntos.size()):
			_marcar_suelo(puntos[i] as Vector3)

	## El centro de la esfera: el jugador + ALTO_BURBUJA (o el punto fijo si no hay jugador al que seguir).
	func centro() -> Vector3:
		if sigue != null and is_instance_valid(sigue):
			return sigue.position + Vector3(0.0, Lanzador3D.ALTO_BURBUJA, 0.0)
		return puntos[0] as Vector3 if not puntos.is_empty() else global_position

	## ¿Está `p` dentro de la esfera? (solo una burbuja viva, que no haya reventado, contiene algo).
	func contiene(p: Vector3) -> bool:
		return burbuja and not reventada and p.distance_to(centro()) <= Lanzador3D.RADIO_BURBUJA

	## El punto de la esfera que mira hacia `desde` (a la altura del centro): donde se dibuja y se calcula lo que impactó.
	func punto_hacia(desde: Vector3) -> Vector3:
		var c: Vector3 = centro()
		var d := Vector3(desde.x - c.x, 0.0, desde.z - c.z)
		if d.length() < 0.01:
			d = Vector3(0.0, 0.0, 1.0)
		return c + d.normalized() * Lanzador3D.RADIO_BURBUJA

	## REVIENTA al primer impacto. `recibido` es el elemento de lo que la tocó ("" = golpe o flecha normal) y `punto` dónde.
	##   · salpicadura de SU elemento por la fachada (`Mundo3D.avisar_impacto`: la maqueta decide qué pinta y suena);
	##   · la REACCIÓN entre los dos elementos (Lanzador3D.REACCIONES_BURBUJA) como una AccionElemental en el punto;
	##   · regla del 8/10 intacta: si hubo atacante, la burbuja le devuelve SU elemento (sin daño: el golpe ya lo ha parado ella).
	## Devuelve true si ha reventado ahora; false si no es una burbuja o ya había reventado (el segundo impacto no la encuentra).
	func reventar(recibido: String, punto: Vector3, atacante: Combate3D = null) -> bool:
		if not burbuja or reventada:
			return false
		reventada = true
		if Mundo3D.actual != null:
			Mundo3D.actual.avisar_impacto(punto, elemento, Lanzador3D.RADIO_BURBUJA)
		reaccion = Lanzador3D.reaccion_burbuja(elemento, recibido, punto)
		if atacante != null:
			lanz.aplicar_elemento(atacante, elemento)
		Combate3D.flotante(lanz.mundo, centro() + Vector3(0.0, 1.5, 0.0), "¡Revienta!", Color(0.6, 0.9, 1.0))
		PlayLog.event("barrera_revienta", {"elemento": elemento, "recibido": recibido, "reaccion": reaccion,
			"punto": [snappedf(punto.x, 0.1), snappedf(punto.z, 0.1)]})
		revento.emit(recibido, punto, reaccion)
		queue_free()
		return true

	## Lo que ya arde o lleva corriente DENTRO de la esfera (o pegado a ella) la revienta sin que nadie la golpee: fuego (los objetos
	## `flammable3d` encendidos y las barreras de fuego «B») y agua electrificada (`EmisorRayo3D.electrificada`, casillas que toca la esfera).
	## Se mira cada 0,1 s: son decenas de objetos, no hace falta en cada fotograma de física.
	func _vigilar_mundo() -> void:
		var c0: Vector3 = centro()
		var r: float = Lanzador3D.RADIO_BURBUJA
		for n in get_tree().get_nodes_in_group("emisor_rayo"):
			if not is_instance_valid(n):
				continue
			for ce in (n.get("electrificada") as Array):
				var centro_c: Vector3 = Terreno3D.centro_de(ce as Vector2i)
				var m: float = Terreno3D.casilla * 0.5
				# distancia del centro de la esfera al cuadrado de la casilla (en planta): la esfera la toca si es ≤ radio
				var dx: float = maxf(absf(c0.x - centro_c.x) - m, 0.0)
				var dz: float = maxf(absf(c0.z - centro_c.z) - m, 0.0)
				if dx * dx + dz * dz <= r * r:
					reventar("rayo", Vector3(clampf(c0.x, centro_c.x - m, centro_c.x + m), c0.y, clampf(c0.z, centro_c.z - m, centro_c.z + m)))
					return
		for n in get_tree().get_nodes_in_group("flammable3d"):
			if is_instance_valid(n) and bool(n.get("is_lit")):
				var pn: Vector3 = (n as Node3D).global_position
				if Vector2(pn.x - c0.x, pn.z - c0.z).length() <= r + 0.4:
					reventar("fuego", Vector3(pn.x, c0.y, pn.z))
					return
		for h in lanz.mundo.get_children():
			if h is Lanzador3D.BarreraFuego and not (h as Lanzador3D.BarreraFuego).apagada:
				var ph: Vector3 = (h as Node3D).global_position
				if Vector2(ph.x - c0.x, ph.z - c0.z).length() <= r + Terreno3D.casilla * 0.5:
					reventar("fuego", Vector3(ph.x, c0.y, ph.z))
					return

	## ¿Esta barrera frena a algo que vuela por `p` a nivel `n`? Lo que levita más alto que ella pasa por encima.
	func bloquea_a(p: Vector3, n: int) -> bool:
		if not bloquea or n > altura_barrera:
			return false
		var r2: float = pow(Lanzador3D.RADIO_GOLPE * Terreno3D.casilla * 1.15, 2.0)
		for i in range(puntos.size()):
			if bool(vivos[i]):
				var q: Vector3 = puntos[i]
				if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) <= r2:
					return true
		return false

	func _marcar_suelo(p: Vector3) -> void:
		var c: Vector2i = Lanzador3D.celda_de(p)
		if _celdas.has(c) or not Lanzador3D.en_mapa(c):
			return
		_celdas[c] = true
		lanz.marcar_celda(elemento, c)
		if caudal > 0.0:
			Mundo3D.aplicar_accion(AccionElemental.nueva("agua", Terreno3D.centro_de(c), 0.0, caudal, maxf(vida - _t, 0.1)))   # M3: un manantial mientras dura

	## Un golpe o una flecha de un enemigo contra la burbuja (lo llama Jugador3D.recibir_dano): la burbuja revienta con él y el daño no
	## llega. Devuelve true si lo ha parado. Los demás campos (muros, corros…) no paran golpes. `_cantidad`: ya no cuenta, la burbuja
	## para UN impacto sea del tamaño que sea (antes había un escudo de 60 puntos).
	func absorber(_cantidad: float, desde: Vector3) -> bool:
		if not burbuja or reventada:
			return false
		return reventar("", punto_hacia(desde), lanz.atacante_en(desde))

	func _exit_tree() -> void:
		if visual != null and is_instance_valid(visual):
			visual.queue_free()               # la cúpula desaparece cuando se rompe o caduca el campo

	func _physics_process(delta: float) -> void:
		_t += delta
		if visual != null and is_instance_valid(visual) and sigue != null and is_instance_valid(sigue):
			visual.position = sigue.position + visual_rel
		if _t >= vida:
			queue_free()                    # sin tocarla, la burbuja se desvanece: NO revienta (ni salpica ni reacciona)
			return
		if burbuja:
			if reventada:
				return
			puntos[0] = centro()
			_t_vigia -= delta
			if _t_vigia <= 0.0:
				_t_vigia = 0.1
				_vigilar_mundo()
			return
		var espacio: PhysicsDirectSpaceState3D = lanz.mundo.get_world_3d().direct_space_state
		var algun_vivo: bool = false
		for i in range(puntos.size()):
			if not bool(vivos[i]):
				continue
			var p: Vector3 = puntos[i]
			if sigue != null and is_instance_valid(sigue):
				p = sigue.position + (rel[i] as Vector3) + Vector3(0, sin(_t * 4.0 + float(i)) * 0.08, 0)
			else:
				p += (vel[i] as Vector3) * delta
			var c: Vector2i = Lanzador3D.celda_de(p)
			if viaja or (vel[i] as Vector3) != Vector3.ZERO:
				if Lanzador3D.celda_solida(c, nivel):
					# Se detiene contra lo sólido, pero ANTES lo golpea: una barrera de fuego, una telaraña o un goblin
					# tras una casilla bloqueada tienen que notar el muro o la onda que se les echa encima.
					_golpear(espacio, p, dirs[i] as Vector3)
					vivos[i] = false
					continue
			puntos[i] = p
			algun_vivo = true
			_marcar_suelo(p)
			_golpear(espacio, p, dirs[i] as Vector3)
		if not algun_vivo:
			queue_free()

	func _golpear(espacio: PhysicsDirectSpaceState3D, p: Vector3, dir: Vector3) -> void:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _forma
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.collision_mask = Lanzador3D.CAPA_REACTIVO
		q.collide_with_areas = true
		q.collide_with_bodies = false
		for r in espacio.intersect_shape(q, 16):
			var obj: Object = r["collider"]
			if not (obj is Node) or _golpeados.has(obj):
				continue
			var nv: int = int((obj as Node).call("nivel_altura")) if (obj as Node).has_method("nivel_altura") else 1
			if nv < nivel and not atrae:
				continue
			_golpeados[obj] = true
			lanz._golpear(obj as Node, rune, dir, p, nivel, atrae, p)


## =====================================================================================================
##  Barrera de fuego (letra B del plano): se apaga con agua o frío, como en el 2D
## =====================================================================================================

## Pone una BarreraFuego en cada casilla "B" del plano. Busca la llama (Vfx3D.fuego_fijo) y la luz que la maqueta
## puso ahí para poder apagarlas. Las llama Jugador3D.montar() una vez montado el mundo.
static func colocar_barreras(p_mundo: Node3D) -> int:
	var n: int = 0
	var fx: Node = p_mundo.get("_fx")
	var lado: int = int(p_mundo.get("_lado"))
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if String(p_mundo.call("_letra", c)) != "B":
				continue
			var centro: Vector3 = centro_de(c, Terreno3D.alto_suelo)
			var b := BarreraFuego.new()
			b.mundo = p_mundo
			b.celda = c
			b.position = centro + Vector3(0.0, Terreno3D.ALTO_NIVEL, 0.0)
			var cs := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = Vector3(Terreno3D.casilla * 0.95, Terreno3D.ALTO_NIVEL * 2.0, Terreno3D.casilla * 0.95)
			cs.shape = caja
			b.add_child(cs)
			b.collision_layer = CAPA_REACTIVO
			b.collision_mask = 0
			if fx != null:
				for h in fx.get_children():
					if h is Node3D and not (h is Light3D) \
							and Vector2((h as Node3D).position.x - centro.x, (h as Node3D).position.z - centro.z).length() < 0.1 \
							and absf((h as Node3D).position.y - centro.y) < 0.05:
						b.llama = h
						break
			for l in p_mundo.find_children("*", "OmniLight3D", true, false):
				var lp: Vector3 = (l as Node3D).global_position
				if Vector2(lp.x - centro.x, lp.z - centro.z).length() < 0.1 and lp.y > centro.y + 0.3 and lp.y < centro.y + 1.3:
					b.luz = l
					break
			p_mundo.add_child(b)
			n += 1
	return n


## Zona de una receta V2 con pulsos (plasma, gas, campo): vive `vida` s y cada `intervalo` llama al pulso de su estado (HechizoVivo.pulsar).
class ZonaV2 extends Node3D:
	var lanz: Lanzador3D = null
	var rune: RuneData = null
	var elemento: String = ""
	var dir: Vector3 = Vector3.FORWARD
	var origen: Vector3 = Vector3.ZERO
	var celdas: Dictionary = {}          ## Vector2i -> true
	var vida: float = 1.0
	var metodo_pulso: String = ""
	var intervalo: float = 0.25          ## s entre pulsos (el `intervalo` del Hechizo)
	var dano_periodico: float = 0.0      ## puntos/s del pulso de plasma (el `dano_periodico` del Hechizo)
	var tocados: Dictionary = {}         ## instance_id -> true: a quién ya le llegó el golpe entero
	var _acum: float = 0.0

	func pulso() -> void:
		if metodo_pulso != "" and lanz != null and is_instance_valid(lanz):
			HechizoVivo.pulsar(metodo_pulso, lanz, self)

	## Avanza `delta` s (público: las pruebas lo llaman a mano).
	func avanzar(delta: float) -> void:
		vida -= delta
		_acum += delta
		while _acum >= intervalo and vida > 0.0:
			_acum -= intervalo
			pulso()
		if vida <= 0.0:
			queue_free()

	func _physics_process(delta: float) -> void:
		avanzar(delta)


## SOLIDEZ V2 (R3): lo que la propiedad `solidez` pone ENCIMA de cualquier estado. Un grupo de casillas que bloquea proyectiles (los del
## jugador por `Lanzador3D._barrera_en`, los ajenos por `solidez_para`) y aguanta `aguante` de daño antes de romperse. Dura `vida` s.
## `refleja`: el volumen tiene rebote y no se desplaza, así que DEVUELVE los proyectiles en vez de pararlos.
class SolidezV2 extends Node3D:
	var celdas: Dictionary = {}          ## Vector2i -> true
	var niveles: int = 1
	var vida: float = 1.0
	var aguante: float = 30.0
	var refleja: bool = false
	var elemento: String = ""
	var linaje: Object = null            ## el lanzamiento (HechizoVivo.Linaje) que la levantó: sus propios proyectiles no chocan con ella (null = de nadie: la ven todos)

	## ¿Está este punto dentro de alguna casilla del volumen?
	func contiene(p: Vector3) -> bool:
		return celdas.has(Lanzador3D.celda_de(p))

	## ¿Para un proyectil que vuela a `n` niveles sobre el suelo? Nunca en la casilla `propia` (la de quien lanza: no se bloquea a sí mismo).
	func bloquea_a(p: Vector3, n: int, propia: Vector2i) -> bool:
		var c: Vector2i = Lanzador3D.celda_de(p)
		return c != propia and celdas.has(c) and n < niveles

	## Recibe un golpe de `dano`. Devuelve true si lo ha aguantado; al agotarse el aguante, el volumen se deshace.
	func golpe(dano: float) -> bool:
		aguante -= dano
		if aguante <= 0.0:
			queue_free()
		return true

	## Avanza `delta` s (público: las pruebas lo llaman a mano).
	func avanzar(delta: float) -> void:
		vida -= delta
		if vida <= 0.0:
			queue_free()

	func _physics_process(delta: float) -> void:
		avanzar(delta)


class BarreraFuego extends Area3D:
	var mundo: Node3D = null
	var celda: Vector2i = Vector2i.ZERO
	var llama: Node3D = null
	var luz: Node3D = null
	var apagada: bool = false

	func nivel_altura() -> int:
		return 1

	func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
		if apagada or rune_data == null:
			return
		if not (rune_data.tags.has("agua") or rune_data.tags.has("frio")):
			return
		apagar_ahora()
		# El agua salpica: también apaga las casillas de fuego pegadas (así el hueco cabe, y no hay que acertar fila a fila).
		for h in mundo.get_children():
			if h is BarreraFuego and not (h as BarreraFuego).apagada:
				var d: Vector2i = (h as BarreraFuego).celda - celda
				if absi(d.x) + absi(d.y) == 1:
					(h as BarreraFuego).apagar_ahora()

	func apagar_ahora() -> void:
		if apagada:
			return
		apagada = true
		var fx: Variant = mundo.get("_fx")
		if fx != null:
			if llama != null:
				fx.apagar(llama)
			fx.vapor(Lanzador3D.centro_de(celda, Terreno3D.alto_suelo + 0.3))
		if luz != null and is_instance_valid(luz):
			luz.queue_free()
		Lanzador3D.liberar_celda(celda)
		collision_layer = 0
		PlayLog.event("barrera_fuego_apagada", {"celda": [celda.x, celda.y]})
		Combate3D.flotante(mundo, Lanzador3D.centro_de(celda, Terreno3D.alto_suelo + 1.2), "¡Apagada!", Color(0.5, 0.8, 1.0))
