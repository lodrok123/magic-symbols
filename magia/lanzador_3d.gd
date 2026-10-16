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
const ARRASTRE_MINIMO: float = 0.45         ## casillas: menos que esto es un clic, no un arrastre
const TIEMPO_MAX_MODO: float = 12.0         ## segundos de reloj: pasado esto se cancela solo

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
## --- Progresión en 3D: qué tienes en cada nivel (vocabulario del diseño: SELLO = elemento, GLIFO = forma) ---
## `Repertoire` ya hace que el libro solo enseñe lo activo; aquí se decide QUÉ está activo, y cuántas páginas (libros) hay y
## cuántos glifos caben en una. «todo» es el banco de pruebas de siempre (Test 3). La clave se elige con el nombre del nivel
## (`mundo.nivel`); si no hay una con ese nombre vale «todo». Para probar un nivel concreto sin tocar el mundo: PROGRESION_FORZADA.
const PROGRESIONES: Dictionary = {
	"todo": {"sellos": ["fuego", "agua", "viento", "tierra", "rayo", "hielo"],
		"glifos": ["flecha", "barrera", "linea", "altura", "tamano", "levitacion", "repeticion", "rebote", "pulso"],
		"paginas": 3, "glifos_por_pagina": 6},
	# Primer nivel (Pablo, 8/10): UN sello y DOS glifos, una sola página, y como mucho dos glifos en ella.
	"nivel1": {"sellos": ["fuego"], "glifos": ["flecha", "barrera"], "paginas": 1, "glifos_por_pagina": 2, "libro": "nivel1"},
	# Bosque 1 (Fase 9, 9.9, Pablo 10/10): se empieza con FUEGO + FLECHA y una página (un hueco de sello, dos de glifo). El
	# sello de AGUA se recoge detrás de la telaraña (Bosque3D, zona `a`) y la BARRERA se compra al guardabosques por 20 de oro.
	"bosque": {"sellos": ["fuego"], "glifos": ["flecha"], "paginas": 1, "glifos_por_pagina": 2, "libro": "nivel1"},
	# Kit de pruebas (11.15, Pablo 12/10): el Bosque como laboratorio, con TODO el repertorio desde el principio, hielo incluido.
	# Se elige con `mundo.kit = "pruebas"`; el Bosque3D no quita ni bloquea nada de esto (solo desbloquea, y es idempotente).
	"pruebas": {"sellos": ["fuego", "agua", "viento", "tierra", "rayo", "hielo"],
		"glifos": ["flecha", "barrera", "linea", "altura", "tamano", "levitacion", "repeticion", "rebote", "pulso"],
		"paginas": 3, "glifos_por_pagina": 6},
}
const PROGRESION_FORZADA: String = ""          ## «nivel1», «todo»…: manda sobre el nombre del nivel (para probar)
const PALETA_RUNAS: bool = true               ## paleta F1 de pruebas (rune_palette.gd), como en Blockout y TestJugabilidad
const HUECOS_POR_PAGINA: int = 6
const ELEMENTOS_TEST3: PackedStringArray = ["fuego", "agua", "viento", "tierra", "rayo", "hielo"]
const SELLOS_TEST3: PackedStringArray = ["flecha", "barrera", "linea", "altura", "tamano", "levitacion", "repeticion", "rebote", "pulso"]
## 8/10 (8.1c): amplificar, retardo, atracción y espejo quedan fuera del 3D (siguen en el 2D). `altura` y `tamano` se
## ya están (8.2 de Pablo, 8/10 22:20).

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
var camara: Camera3D = null
var altura: int = 0                     ## nivel del hechizo que pregunta a una barrera (bloquea_proyectiles lo lee)

var capa_ui: CanvasLayer = null
var mochila: BolsaUI = null            ## la mochila (I): en 3D la monta el lanzador, como el libro
var diario: DiarioMisiones = null        ## el diario de misiones (J)
var libro: Control = null
var _libro_lento: bool = false
var _barrera_activa: Campo = null
var _ts_libro: float = 1.0
var _aviso: Label = null
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
var _ts_antes: float = 1.0

## --- Lo vivo ---
var _campos: Array = []                 ## Campo: muros, corros, ondas, tierra...
var _bloques: Array = []                ## tierra construida: {celda, niveles, nodos, resta}
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
	"tiempo": [0.12, 0.30, 0.12],
}
var conjuro_activo: bool = true
var conjuro_escala: float = 1.0
var conjurando: bool = false             ## hay un conjuro en marcha (entre soltar y disparar)
var _t_conjuro: float = 0.0              ## segundos DE JUEGO (con time_scale y pausa) desde que se soltó: es lo que se anota como retardo
var _page_hud: Control = null
signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)


## =====================================================================================================
##  Configuración y utilidades de casilla (estáticas: las usan también Jugador3D y Combate3D)
## =====================================================================================================

static func configurar(p_mundo: Node3D) -> void:
	Terreno3D.configurar(p_mundo)
	Terreno3D.al_solidificar = soltar_presos
	ReaccionesAgua3D.efecto = _efecto_mundo
	mundo_s = p_mundo                    # espejo M1
	agua_sim = null                      # espejo M1


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

	# La mochila (I) también en 3D: antes solo la montaba nivel_base (2D). Pausa el árbol; el lanzador es ALWAYS.
	mochila = BolsaUI.new()
	capa_ui.add_child(mochila)

	# El diario de misiones (J) y su línea en el HUD (Fase 14.3). Pausa como la mochila; solo lee de `Misiones`.
	diario = DiarioMisiones.new()
	capa_ui.add_child(diario)
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
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
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
func avisar(texto: String, color: Color = Color(1, 0.9, 0.6)) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.add_theme_color_override("font_color", color)
	_aviso.modulate.a = 1.0
	var tw: Tween = _aviso.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.5)


## =====================================================================================================
##  Las reglas del libro (4.1)
## =====================================================================================================

## Un glifo por sector. Va aquí y no en el libro porque por esta función entran los dos caminos ($P y atajo de raya).
func add_sigil(sector: Vector2, sigil_name: String, calidad: float = 1.0) -> void:
	if Repertoire.sigil_active(sigil_name):
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
	for i in range(8):
		var sector := Vector2(cos(paso * float(i)), sin(paso * float(i))) if i > 0 else Vector2.RIGHT
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
static func aviso_receta(glifos: Array) -> String:
	var receta := Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		receta.apply(String(gl))
	if receta.usa_geo() and not bool(receta.geo()["valida"]):
		return String(receta.geo()["aviso"])
	return ""


func cast_page(indice: int) -> void:
	if indice < 0 or indice >= Repertoire.pages_available(PAGES):
		return
	if modo_lanzar:
		_cancelar_modo()
	if jugador != null and not bool(jugador.call("puede_lanzar")):
		_feedback("Ahora no puedes lanzar")
		Sfx.play(self, "sello_no")
		return

	var ficha: Dictionary = pages[indice]
	var element_data: RuneData = rune_database.get(ficha["element"])
	var componentes: Array = ficha["components"]
	if element_data == null:
		_feedback("La página %d no tiene elemento" % (indice + 1))
		return
	if not Repertoire.element_active(_gesture_name_of(ficha["element"])):
		_feedback("Ese elemento ya no está activo")
		return
	if componentes.is_empty():
		_feedback("A la página %d le falta algún glifo" % (indice + 1))
		return
	if cooldown_left[indice] > 0.0:
		Sfx.play(self, "sello_no")
		_feedback("Recargando (%.1f s)" % cooldown_left[indice])
		PlayLog.event("cast_bloqueado", {"pagina": indice + 1, "queda": snappedf(cooldown_left[indice], 0.1)})
		return

	# UNA RECETA POR PÁGINA: los glifos de todos los sectores se funden en un solo hechizo.
	var fusion: Dictionary = {"sigils": [], "quality": []}
	for c in componentes:
		(fusion["sigils"] as Array).append_array(c["sigils"])
		(fusion["quality"] as Array).append_array(c.get("quality", []))
	for s in fusion["sigils"]:
		if not Repertoire.sigil_active(s):
			_feedback("Un glifo de la página ya no está activo")
			return

	var calidad: float = float(ficha.get("element_q", 1.0))
	for q in fusion["quality"]:
		calidad = minf(calidad, float(q))

	var receta := Receta3D.new(Vector2.RIGHT)
	for s in fusion["sigils"]:
		receta.apply(s)
	# Flecha y barrera solo orientan el eje: SIEMPRE nacen en el jugador. El glifo de "lejos" (origin) no las desplaza.
	if receta.travels or receta.spread:
		receta.origin = 0.0
	receta.calidad = calidad
	# 8.6: el tope de altura combinado. Si lo supera, se avisa y NO se lanza (no se recorta en silencio).
	if receta.usa_geo() and not bool(receta.geo()["valida"]):
		Sfx.play(self, "sello_no")
		_feedback(String(receta.geo()["aviso"]))
		PlayLog.event("cast_rechazado_altura", {"pagina": indice + 1, "y_tope": int(receta.geo()["y_tope"]), "glifos": (fusion["sigils"] as Array).duplicate()})
		return

	# TINTA (15/10): se comprueba aquí, antes de apuntar, para no ralentizar el tiempo y luego negarte el lanzamiento. Se COBRA al soltar
	# (`lanzar_ahora`): si cancelas el apuntado no pierdes nada.
	if tinta != null and not tinta.puede_pagar(receta.forma()):
		Sfx.play(self, "sello_no")
		_feedback("Tinta insuficiente (%d / %d)" % [int(ceil(tinta.actual)), int(Tinta.coste_de(receta.forma()))])
		PlayLog.event("cast_sin_tinta", {"pagina": indice + 1, "forma": receta.forma(), "coste": Tinta.coste_de(receta.forma()), "hay": snappedf(tinta.actual, 0.1)})
		return

	_preparado = {"indice": indice, "receta": receta, "rune": element_data, "calidad": calidad,
		"glifos": (fusion["sigils"] as Array).duplicate(),
		"elemento_nombre": _gesture_name_of(ficha["element"])}
	_entrar_modo_lanzar()


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
	_salir_modo()
	_preparado = {}
	lanzar_ahora(datos, origen, dir, con_conjuro)
	return true


func _entrar_modo_lanzar() -> void:
	modo_lanzar = true
	_fijado = false
	_ms_modo = Time.get_ticks_msec()
	_ts_antes = Engine.time_scale
	Engine.time_scale = RALENTIZADO
	var rune: RuneData = _preparado["rune"]
	var forma: String = (_preparado["receta"] as Receta3D).forma()
	if jugador != null:
		jugador.call("bloquear", true)
		jugador.call("apuntar_lanzar", Objetos.elemento_de(rune), (_preparado["receta"] as Receta3D).forma_vfx(), RALENTIZADO)
	_crear_marcadores(rune.color)
	if _guia != null:
		_guia.text = "Apunta con el ratón · arrastra para dirigir · suelta para lanzar · clic derecho o Esc cancela"
		_guia.visible = true
	modo_cambiado.emit(true)
	PlayLog.event("modo_lanzar", {"pagina": int(_preparado["indice"]) + 1, "forma": forma})


func _salir_modo() -> void:
	modo_lanzar = false
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
	for m in _prev_casillas:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_prev_casillas.clear()
	if jugador != null:
		jugador.call("bloquear", false)
		jugador.call("terminar_apuntar")
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
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_actualizar_puntero(mb.position)
				_fijado = true
				_origen_fijo = _origen_vivo
			elif _fijado:
				_actualizar_puntero(mb.position)
				_soltar()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
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
	var yo: Vector3 = (jugador as Node3D).position
	var hacia: Vector3 = _punto_vivo - yo
	hacia.y = 0.0
	# 5.1: el ratón da SOLO la dirección; todo nace en el jugador (lanzar lejos trivializaba el puzle).
	_origen_vivo = yo


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
	super._process(delta)
	if conjurando:
		_t_conjuro += delta
	_avanzar_caducidades(delta)
	if modo_lanzar:
		if Time.get_ticks_msec() - _ms_modo > int(TIEMPO_MAX_MODO * 1000.0):
			avisar("Lanzamiento cancelado")
			_cancelar_modo()
			return
		_pintar_marcadores()
		if jugador != null:
			jugador.call("mirar_hacia", _direccion_actual())


func _soltar() -> void:
	var origen: Vector3 = _origen_fijo if _fijado else _origen_vivo
	var dir: Vector3 = _direccion_actual()
	var datos: Dictionary = _preparado
	_salir_modo()
	_preparado = {}
	if datos.is_empty():
		return
	lanzar_ahora(datos, origen, dir, true)


## Lo que pasa al soltar: animación, cobro, recarga y (tras el conjuro, si lo hay) el disparo. Público para las pruebas.
## `con_conjuro` false = el disparo sale en el mismo fotograma, como antes de la Fase 14.5.
func lanzar_ahora(datos: Dictionary, origen: Vector3, dir: Vector3, con_conjuro: bool = false) -> void:
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var indice: int = int(datos["indice"])
	var elemento: String = Objetos.elemento_de(rune)
	var forma: String = receta.forma()
	if jugador != null:
		jugador.call("mirar_hacia", dir)
		jugador.call("lanzar_clip", elemento, receta.forma_vfx())

	if tinta != null:
		tinta.gastar(forma)

	# Recarga y coste al SOLTAR: durante el conjuro la página ya no se puede volver a lanzar.
	cooldown_total[indice] = receta.cooldown
	cooldown_left[indice] = receta.cooldown

	var tiempos: Array = tiempos_conjuro(elemento)
	if con_conjuro and conjuro_activo and is_inside_tree() and (float(tiempos[0]) + float(tiempos[1]) + float(tiempos[2])) > 0.0:
		_conjurar(datos, origen, dir, tiempos)
	else:
		_disparar(datos, origen, dir, 0.0)


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
	var esfera: MeshInstance3D = _forma_en_mano(mano, color, float(tiempos[2]))
	await get_tree().create_timer(float(tiempos[2]), false).timeout
	if is_instance_valid(esfera):
		esfera.queue_free()
	conjurando = false
	# Si el jugador murió mientras conjuraba, no sale nada (la tinta ya se gastó: se anota).
	if jugador != null and bool(jugador.get("muerto")):
		PlayLog.event("conjuro", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "interrumpido": true})
		return
	_disparar(datos, origen, dir, _t_conjuro)


## El disparo: lo que antes hacía `lanzar_ahora` tras cobrar. `retardo` = lo que tardó el conjuro (0 si no lo hubo).
func _disparar(datos: Dictionary, origen: Vector3, dir: Vector3, retardo: float) -> void:
	var receta: Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var indice: int = int(datos["indice"])
	var elemento: String = Objetos.elemento_de(rune)
	var forma: String = receta.forma()
	conjuro_fase.emit("disparo", elemento, _pos_mano())
	var n: int = _materializar(receta, rune, origen, dir)
	var ev: Dictionary = {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "glifos": datos["glifos"],
		"calidad": snappedf(float(datos["calidad"]), 0.01), "recarga": receta.cooldown, "forma": forma, "tinta": snappedf(tinta.actual if tinta != null else -1.0, 0.1),
		"origen": [snappedf(origen.x, 0.1), snappedf(origen.z, 0.1)], "manifestaciones": n}
	if retardo > 0.0:
		ev["retardo"] = snappedf(retardo, 0.01)
	PlayLog.event("cast", ev)
	if retardo > 0.0:
		var t: Array = tiempos_conjuro(elemento)
		PlayLog.event("conjuro", {"pagina": indice + 1, "elemento": datos["elemento_nombre"], "runa": t[0], "voluta": t[1], "forma": t[2],
			"previsto": snappedf(float(t[0]) + float(t[1]) + float(t[2]), 0.01), "retardo": snappedf(retardo, 0.01), "interrumpido": false})
	PlayLog3D.manifestaciones(n, forma, elemento)
	lanzado.emit(elemento, forma, n)


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
	get_tree().create_timer(dura + 0.8, false).timeout.connect(func() -> void:
		if is_instance_valid(hilo):
			hilo.queue_free())


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
	_prev_color = color
	_marca_origen = _anillo(0.22 * Terreno3D.casilla, 0.34 * Terreno3D.casilla, color)
	_marca_alcance = _anillo(ALCANCE_ORIGEN * Terreno3D.casilla - 0.09, ALCANCE_ORIGEN * Terreno3D.casilla, Color(color, 0.55))
	var flecha := BoxMesh.new()
	flecha.size = Vector3(0.12, 0.05, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flecha.material = m
	_marca_flecha = MeshInstance3D.new()
	_marca_flecha.mesh = flecha
	_marca_flecha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(_marca_flecha)


func _anillo(r_int: float, r_ext: float, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_int
	t.outer_radius = r_ext
	t.rings = 32
	t.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.scale = Vector3(1.0, 0.05, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(mi)
	return mi


func _pintar_marcadores() -> void:
	if _marca_origen == null:
		return
	var yo: Vector3 = (jugador as Node3D).position
	var o: Vector3 = _origen_fijo if _fijado else _origen_vivo
	_marca_origen.position = o + Vector3(0, 0.08, 0)
	_marca_alcance.position = yo + Vector3(0, 0.06, 0)
	var d: Vector3 = _direccion_actual()
	var largo: float = 1.1 * Terreno3D.casilla
	_marca_flecha.position = o + d * largo * 0.5 + Vector3(0, 0.1, 0)
	_marca_flecha.scale = Vector3(1, 1, largo)
	_marca_flecha.rotation = Vector3(0, atan2(d.x, d.z), 0)
	_pintar_previsualizacion(o, d)


## 8.8: las casillas que ocupará el hechizo y su altura, calculadas con la MISMA geometría con la que se lanza (así lo
## que se ve es lo que sale). Un proyectil no ocupa casillas: alarga la flecha hasta su alcance. Solo recetas de la Fase 8.
func _pintar_previsualizacion(origen: Vector3, dir: Vector3) -> void:
	var receta: Receta3D = _preparado.get("receta") as Receta3D
	if receta == null or not receta.usa_geo():
		return
	var g: Dictionary = receta.geo()
	var largo_flecha: float = 1.1 * Terreno3D.casilla
	if bool(g.get("chorro", false)):
		largo_flecha = float(g["largo"]) * Terreno3D.casilla
		_marca_flecha.position = origen + dir * largo_flecha * 0.5 + Vector3(0, 0.1, 0)
		_marca_flecha.scale = Vector3(1, 1, largo_flecha)
	elif float(g["alcance"]) > 0.0:
		largo_flecha = float(g["alcance"]) * Terreno3D.casilla
		_marca_flecha.position = origen + dir * largo_flecha * 0.5 + Vector3(0, 0.1, 0)
		_marca_flecha.scale = Vector3(1, 1, largo_flecha)
	var cs: Array = GeometriaHechizo.celdas(g, Vector2(origen.x, origen.z), Vector2(dir.x, dir.z), Terreno3D.casilla)
	while _prev_casillas.size() < cs.size():
		var mi := MeshInstance3D.new()
		var caja := BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		caja.material = m
		mi.mesh = caja
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mundo.add_child(mi)
		_prev_casillas.append(mi)
	var alto: float = Terreno3D.ALTO_NIVEL * float(g["alto"])
	for i in range(_prev_casillas.size()):
		var mi: MeshInstance3D = _prev_casillas[i]
		mi.visible = i < cs.size()
		if not mi.visible:
			continue
		var c: Vector2i = cs[i]
		var h: float = 0.06 + alto
		(mi.mesh as BoxMesh).size = Vector3(Terreno3D.casilla * 0.9, h, Terreno3D.casilla * 0.9)
		((mi.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(_prev_color, 0.30) if bool(g["valida"]) else Color(1, 0.2, 0.2, 0.35)
		mi.position = Vector3((float(c.x) + 0.5) * Terreno3D.casilla, y_pies(c) + h * 0.5 + 0.02, (float(c.y) + 0.5) * Terreno3D.casilla)



## =====================================================================================================
##  Materializar la receta en 3D
## =====================================================================================================

## Devuelve cuántas manifestaciones salen en total. La primera ola sale ya; las siguientes (repetición en onda)
## salen cada Sigils.WAVE_GAP segundos sin bloquear al lanzador.
func _materializar(receta: Receta3D, rune: RuneData, origen: Vector3, dir: Vector3) -> int:
	var elemento: String = Objetos.elemento_de(rune)
	var data: RuneData = receta.potenciada(rune)
	var olas: int = mini(receta.copies, 3) if receta.expande() else 1
	var primera: int = _una_ola(receta, data, elemento, origen, dir)
	for o in range(1, olas):
		_ola_diferida(float(o) * Sigils.WAVE_GAP, receta, data, elemento, origen, dir)
	return mini(primera * olas, Sigils.MAX_MANIFESTATIONS * olas)


func _ola_diferida(espera: float, receta: Receta3D, data: RuneData, elemento: String, origen: Vector3,
		dir: Vector3) -> void:
	await get_tree().create_timer(espera, false).timeout
	if is_inside_tree():
		_una_ola(receta, data, elemento, origen, dir)


func _una_ola(receta: Receta3D, data: RuneData, elemento: String, origen: Vector3, dir: Vector3) -> int:
	var giro: float = Vector2(dir.x, dir.z).angle() - Vector2.RIGHT.angle()
	var nivel: int = receta.height
	if receta.es_volador():
		return _lanzar_volador(receta, data, elemento, origen, dir, nivel)
	var manifest: Array = receta.manifestaciones_en(Vector2(origen.x, origen.z), Vector2(dir.x, dir.z)) if receta.usa_geo() \
		else receta.manifestaciones()
	return _crear_campo(receta, data, elemento, origen, giro, manifest, nivel)


## Una flecha (o un haz): se resuelve al lanzar con un barrido, y los efectos llegan cuando llega el dibujo.
func _lanzar_volador(receta: Receta3D, rune: RuneData, elemento: String, origen: Vector3, dir: Vector3,
		nivel: int) -> int:
	var dirs: Array = []
	var bases: Array = [dir]
	if receta.mirror:
		bases.append(-dir)
	if receta.copies <= 1:
		dirs = bases
	else:
		var abanico: float = deg_to_rad(22.0)
		for b in bases:
			for i in range(receta.copies):
				dirs.append((b as Vector3).rotated(Vector3.UP, (float(i) - float(receta.copies - 1) * 0.5) * abanico))
	var factor: float = Sigils.quality_factor(receta.calidad)
	var alcance: float = ALCANCE_FLECHA * Terreno3D.casilla * factor
	_radio_bola_actual = RADIO_BOLA
	if receta.usa_geo():
		# 8.1a: varias flechas = más alcance (3 casillas, +1 por flecha, tope 5). Lo dice la geometría.
		alcance = float(receta.geo()["alcance"]) * Terreno3D.casilla * factor
		# Tamaño agranda la bola (solo lo que se dibuja: el barrido sigue siendo un rayo; ver diario).
		_radio_bola_actual = RADIO_BOLA * float(receta.geo()["radio"]) / GeometriaHechizo.RADIO_0
	elif receta.reach > 1:
		alcance *= 1.0 + 0.25 * float(receta.reach - 1)
	var n: int = 0
	for d in dirs:
		if n >= Sigils.MAX_MANIFESTATIONS:
			break
		_barrido(receta, rune, elemento, origen, d as Vector3, alcance, nivel)
		n += 1
	return n


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
		if cortado and (choca_celda or rebota_zona) and rebotes > 0 and normal != Vector3.ZERO and restante > 0.3:
			d = d.bounce(normal.normalized())
			d.y = 0.0
			d = d.normalized()
			pos = fin + d * 0.05
			rebotes -= 1
			continue
		pos = fin
		break

	return {"tramos": tramos, "fin": pos}


## ¿Hay una barrera VIVA (de las nuestras: corro, muro) en este punto, a un nivel que la salta o no?
func _barrera_en(p: Vector3, nivel: int) -> bool:
	for c in _campos:
		if is_instance_valid(c) and (c as Campo).bloquea_a(p, nivel):
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
func _golpear(obj: Node, rune: RuneData, dir: Vector3, punto: Vector3, nivel: int, atrae: bool, desde: Vector3) -> bool:
	if obj == null or not is_instance_valid(obj) or rune == null:
		return false
	# 12/10 (Pablo): lo activable se activa en SU punto (el cuenco de la antorcha, la boca de la tinaja…), no donde roza la caja.
	var activable: bool = obj.has_method("punto_activacion")
	if activable:
		punto = obj.call("punto_activacion")
	var es_viento: bool = rune.tags.has("viento")
	if (es_viento or atrae) and obj.has_method("push"):
		if atrae:
			var hacia: Vector3 = desde - (obj as Node3D).global_position
			hacia.y = 0.0
			if hacia.length() > 0.01:
				obj.call("push", hacia.normalized(), FUERZA_EMPUJE * (1.0 if es_viento else 0.7))
		else:
			var emp: Vector3 = dir
			if emp.length() < 0.01:
				emp = (obj as Node3D).global_position - punto
				emp.y = 0.0
				emp = emp.normalized()
			obj.call("push", emp, FUERZA_EMPUJE)
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
	obj.call("on_spell_hit", rune, dir)
	ultimo_impacto = Vector3.INF
	ultimo_nivel = 0
	return reacciona


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
	campo.tree_exited.connect(func() -> void:
		manifestaciones_vivas = maxi(0, manifestaciones_vivas - cuenta)
		_campos.erase(campo))

	# Lo que construye: tierra quieta (un bloque por casilla) y columna (barrera + levitación).
	var columna: bool = receta.blocks and receta.height > 0 and receta.spread and not onda
	if columna:
		_levantar_columna(campo, receta.vida(), 1, rune.color)
	elif rune.tags.has("tierra") and receta.es_quieto() and not muro and not cupula:
		var celdas: Dictionary = {}
		for pt in campo.puntos:
			celdas[celda_de(pt as Vector3)] = true
		var levantar := func() -> void:
			for c in celdas:
				construir_tierra(c as Vector2i, false)   # el anillo (Vfx3D "corro") ya dibuja la tierra
		if onda:
			_despues(T_CRECE, levantar)          # barrera + pulso: el anillo crece y los bloques aparecen al llegar
		else:
			levantar.call()
	return cuenta


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
	if receta.usa_geo() and bool(receta.geo()["envuelve"]) and not receta.line:
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
			var sin_dano: RuneData = r.duplicate()
			sin_dano.damage = 0.0
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
	Mundo3D.aplicar_accion(AccionElemental.nueva(String(r[1]), punto))     # evapora el agua del punto / echa el charco
	return nombre


## Un bloque de tierra en la casilla. Se apila hasta MAX_TIERRA_APILADA, caduca a los 25 s y hay un tope de
## MAX_NIVELES_TIERRA vivos a la vez (el más viejo se deshace antes). No se construye sobre agua, sobre algo
## sólido ni encima de alguien.
func construir_tierra(c: Vector2i, dibujar: bool = true) -> bool:
	if not en_mapa(c) or es_agua(c):
		return false
	var l: String = letra_de(c)
	if l == "~" or l == "b":
		return false
	if bloqueada(c) or Terreno3D.permanentes.has(c):
		return false
	if jugador != null and bool(jugador.call("ocupa", c)):
		return false
	for g in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and celda_de((g as Node3D).position) == c:
			return false
	var entrada: Dictionary = {}
	for b in _bloques:
		if (b["celda"] as Vector2i) == c:
			entrada = b
	if entrada.is_empty():
		entrada = {"celda": c, "niveles": 0, "nodos": [], "resta": DURACION_TIERRA}
		_bloques.append(entrada)
	elif int(entrada["niveles"]) >= MAX_TIERRA_APILADA:
		entrada["resta"] = DURACION_TIERRA
		return false
	entrada["niveles"] = int(entrada["niveles"]) + 1
	entrada["resta"] = DURACION_TIERRA
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
	mat.albedo_color = Color(0.5, 0.37, 0.24)
	mat.roughness = 1.0
	caja.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	mi.visible = dibujar                    # con el anillo de tierra dibujado encima, el bloque es solo colisión
	bloque.add_child(mi)
	var centro: Vector3 = centro_de(c, Terreno3D.alto_suelo + Terreno3D.ALTO_NIVEL * (float(n) - 0.5))
	bloque.position = centro - Vector3(0, Terreno3D.ALTO_NIVEL * 0.6, 0)
	mundo.add_child(bloque)
	(entrada["nodos"] as Array).append(bloque)
	var tw: Tween = bloque.create_tween()
	tw.tween_property(bloque, "position", centro, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recalcular(c)
	_aplicar_tope_tierra()
	return true


func _niveles_de_tierra() -> int:
	var n: int = 0
	for b in _bloques:
		n += int(b["niveles"])
	return n


## El tope: si hay más de MAX_NIVELES_TIERRA bloques vivos, se deshace la entrada más antigua entera.
func _aplicar_tope_tierra() -> void:
	while _niveles_de_tierra() > MAX_NIVELES_TIERRA and _bloques.size() > 1:
		var peor: Dictionary = _bloques[0]
		for b in _bloques:
			if float(b["resta"]) < float(peor["resta"]):
				peor = b
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
	var img: Image = mundo.get("_img_estado")
	return img != null and en_mapa(c) and img.get_pixel(c.x, c.y).b >= 0.5


## Cada impacto de hielo o de agua puede haber helado una casilla: si es así, se apunta cuándo se deshace.
## Va DESPUÉS del manejador de PruebaTest2 (se conecta más tarde), así que el estado ya está escrito.
func al_impactar(elemento: String, punto: Vector3) -> void:
	hechizo_sobre_agua(elemento, punto)      # 11.4: el agua de la simulación (la maqueta ya hizo lo del suelo)
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
	mundo.call("_poner_canal", c, 2, 0.0)
	if Terreno3D.agua_sim != null:
		Terreno3D.agua_sim.helar_casilla(c, false)     # 11.4: el agua vuelve a correr
	if era_agua:
		Terreno3D.poner_helada(c, false)
		bloquear_celda(c)
	else:
		mundo.call("_poner_canal", c, 1, 1.0)
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
##  GeometriaHechizo (Fase 8, 8.4): la receta como datos puros
## =====================================================================================================

## Recibe CUÁNTAS VECES se ha dibujado cada glifo (un multiconjunto: el orden de dibujo no existe aquí) y devuelve
## la forma en CASILLAS. No toca nodos ni escenas, así se prueba en headless con una tabla.
## Orden fijo de evaluación: forma base -> Altura -> Tamaño -> Barrera -> Flecha -> tope Y.
## Por qué un orden fijo: si cada glifo "reaccionara" al anterior, volverían las reglas por pareja que la Fase 8 quiere
## evitar; así cada glifo hace UNA operación y el resultado no depende de cómo se dibujó.
class GeometriaHechizo extends RefCounted:
	const RADIO_0: float = 0.5          ## esfera por defecto: radio en casillas (1 casilla de diámetro)
	const LARGO_0: float = 3.0          ## Línea: largo en casillas
	const GROSOR_LINEA: float = 0.5     ## semi-grosor de la línea (1 casilla de pared); Tamaño no lo toca
	const LINEA_EXTRA: float = 0.2      ## cada Línea repetida alarga la forma un 20 % de su largo base (2 → ×1,2; 3 → ×1,4)
	const TAMANO_RADIO: float = 0.5     ## cada Tamaño: +0,5 casilla de radio...
	const TAMANO_LARGO: float = 2.0     ## ...o +2 casillas de largo
	const TAMANO_TOPE: float = 3.0      ## la forma no pasa de ×3 su medida base
	const FLECHA_0: float = 3.0         ## Flecha: traslada 3 casillas; cada repetición +1
	const FLECHA_TOPE: float = 5.0
	const ESCUDO_FACTOR: float = 1.5    ## Barrera repetida: la vida del escudo ×1,5 por vez
	const ESCUDO_TOPE: float = 3.0
	const ENVUELVE_EXTRA: float = 1.0   ## Barrera: la forma se coloca a (radio + 1 casilla) del jugador, para que no le pise los pies
	const LINEA_DELANTE: float = 1.5    ## Línea suelta: el muro nace a 1,5 casillas delante del jugador (como el muro de siempre)
	const GROSOR_TOL: float = 0.0       ## holgura al rasterizar la línea (0 = exacto: medido, sale una fila de casillas conexa en todos los ángulos)
	const ANILLO_MITAD: float = 0.5     ## la forma hueca ocupa una banda de 1 casilla de ancho (radio ± 0,5)
	const HAZ_DESDE: float = 0.5        ## chorro: la primera casilla del haz empieza a media casilla de la mano
	const VIDA_CHORRO: float = 1.6      ## s: lo que dura el dibujo de Vfx3D «chorro»; el haz hace daño y marca suelo lo mismo

	## `c`: {linea, altura, tamano, flecha, barrera} -> int (los que falten valen 0).
	## `max_y`: niveles que se pueden pisar por encima del suelo (Jugador3D.MAX_NIVELES_SUBIBLES).
	## Devuelve {base, nombre, radio, largo, alto, alcance, envuelve, bloquea, resistencia, proyectil, y_tope,
	##           valida, aviso}.
	static func evaluar(c: Dictionary, max_y: int = 1) -> Dictionary:
		var n_linea: int = maxi(int(c.get("linea", 0)), 0)
		var n_altura: int = maxi(int(c.get("altura", 0)), 0)
		var n_tamano: int = maxi(int(c.get("tamano", 0)), 0)
		var n_flecha: int = maxi(int(c.get("flecha", 0)), 0)
		var n_barrera: int = maxi(int(c.get("barrera", 0)), 0)

		# 1. Forma base. LARGO_0 (3 casillas) es el alcance de una Flecha; cada Línea repetida suma LINEA_EXTRA (20 %).
		var es_linea: bool = n_linea > 0
		var radio: float = GROSOR_LINEA if es_linea else RADIO_0
		var largo: float = LARGO_0 if es_linea else 0.0
		# 2. Altura: estira hacia arriba, +1 nivel por repetición. No mueve la forma.
		var alto: int = n_altura
		# 3. Tamaño: escala radio (esfera) o largo (línea); nunca la altura. Tope ×3 de la medida base.
		if es_linea:
			largo = minf(LARGO_0 * (1.0 + LINEA_EXTRA * float(n_linea - 1)) + TAMANO_LARGO * float(n_tamano), LARGO_0 * TAMANO_TOPE)
		else:
			radio = minf(RADIO_0 + TAMANO_RADIO * float(n_tamano), RADIO_0 * TAMANO_TOPE)
		# 4. Barrera: alrededor del jugador, hueca, bloquea proyectiles. Repetirla = más resistencia, no más tamaño.
		var envuelve: bool = n_barrera > 0
		var resistencia: float = 0.0
		if envuelve:
			resistencia = minf(pow(ESCUDO_FACTOR, float(n_barrera - 1)), ESCUDO_TOPE)
		# 5. Flecha: traslada la forma. Alrededor del jugador no tiene sentido trasladar: se ignora si envuelve.
		var alcance: float = 0.0
		if n_flecha > 0 and not envuelve:
			alcance = minf(FLECHA_0 + float(n_flecha - 1), FLECHA_TOPE)
		# 5b. Línea SOLA (sin Altura ni Barrera) = CHORRO: un haz desde la mano en la dirección de la mirada, no un muro de lado.
		# Flecha no lo traslada: lo ALARGA (+1 casilla por Flecha, mismo tope ×3 que Tamaño).
		var chorro: bool = es_linea and alto == 0 and not envuelve
		if chorro and n_flecha > 0:
			largo = minf(largo + float(n_flecha), LARGO_0 * TAMANO_TOPE)
		# Lo que viaja sin envolver al jugador es un proyectil: no se queda en pie, no cuenta para el tope Y.
		var proyectil: bool = alcance > 0.0
		# 6. Tope Y combinado: solo lo que queda en pie y se puede pisar.
		var y_tope: int = 0 if proyectil else alto
		var valida: bool = y_tope <= max_y
		var aviso: String = ""
		if not valida:
			aviso = "Demasiada altura: sube %d niveles y solo se pueden pisar %d. No se lanza." % [y_tope, max_y]

		return {
			"base": "linea" if es_linea else "esfera",
			"nombre": _nombre(es_linea, alto, envuelve, alcance > 0.0), "chorro": chorro,
			"radio": radio, "largo": largo, "alto": alto, "alcance": alcance,
			"radio_envuelve": (radio + ENVUELVE_EXTRA) if (envuelve and not es_linea) else (ENVUELVE_EXTRA + RADIO_0 if envuelve else 0.0),
			"envuelve": envuelve, "bloquea": envuelve, "resistencia": resistencia,
			"proyectil": proyectil, "y_tope": y_tope, "valida": valida, "aviso": aviso,
		}

	## RASTERIZAR (8.6): las casillas del mundo que ocupa la forma. Una casilla cuenta si su CENTRO cae dentro de la
	## forma. `origen` y las casillas van en coordenadas de mundo (x, z) en metros; `dir` es la mirada (unitaria).
	## Marco local: +x = delante, +y = al lado. Una bola (proyectil de esfera) no ocupa casillas (viaja por barrido): devuelve [].
	## Siempre incluye la casilla que contiene al origen si la forma no es hueca, para que una esfera de radio 0,5
	## nunca desaparezca por caer su centro justo entre dos casillas.
	static func celdas(g: Dictionary, origen: Vector2, dir: Vector2, casilla: float) -> Array:
		var salida: Array = []
		if bool(g["proyectil"]) and String(g["base"]) == "esfera":
			return salida                                  # la bola viaja por barrido; el muro que avanza sí ocupa casillas al nacer
		var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		var perp: Vector2 = d.orthogonal()
		var es_linea: bool = String(g["base"]) == "linea"
		var envuelve: bool = bool(g["envuelve"])
		var radio: float = float(g["radio"])
		var largo: float = float(g["largo"])
		var r_env: float = float(g["radio_envuelve"])
		# Hasta dónde mirar: caja que contiene la forma, en casillas.
		var chorro: bool = bool(g.get("chorro", false))
		var alcance_caja: float = r_env + 1.0 if envuelve else (largo + 1.0 if chorro else (LINEA_DELANTE + largo * 0.5 + 1.0 if es_linea else radio + 1.0))
		var c0 := Vector2i(int(floorf(origen.x / casilla)), int(floorf(origen.y / casilla)))
		if chorro:
			# Haz: se recorre el rayo de la mano hacia delante y se anotan las casillas que ATRAVIESA (en una diagonal, la
			# regla «el centro cae dentro» dejaba el haz en 2 casillas de 3; así salen 3-4 siempre y todas contiguas).
			var vistas: Dictionary = {}
			var paso: float = 0.1
			var t: float = HAZ_DESDE
			while t <= largo:                  # el haz acaba donde acaba el dibujo (antes HAZ_DESDE + largo: +0,5 casilla de más)
				var q: Vector2 = origen + d * t * casilla
				var cq := Vector2i(int(floorf(q.x / casilla)), int(floorf(q.y / casilla)))
				if cq != c0 and not vistas.has(cq):
					vistas[cq] = true
					salida.append(cq)
				t += paso
			return salida
		var n: int = int(ceilf(alcance_caja)) + 1
		var apertura: float = minf(largo / maxf(r_env, 0.001), TAU) if (es_linea and envuelve) else TAU
		for dx in range(-n, n + 1):
			for dz in range(-n, n + 1):
				var c := Vector2i(c0.x + dx, c0.y + dz)
				var centro := Vector2((float(c.x) + 0.5) * casilla, (float(c.y) + 0.5) * casilla)
				var rel: Vector2 = (centro - origen) / casilla
				var lx: float = rel.dot(d)
				var ly: float = rel.dot(perp)
				var dentro: bool = false
				if envuelve:
					var dist: float = rel.length()
					dentro = absf(dist - r_env) <= ANILLO_MITAD
					if dentro and es_linea and apertura < TAU - 0.001:
						dentro = absf(atan2(ly, lx)) <= apertura * 0.5
				elif chorro:
					# Haz: una fila de casillas a lo largo de la mirada, de la mano hacia delante.
					dentro = lx >= HAZ_DESDE and lx < largo and absf(ly) <= GROSOR_LINEA + GROSOR_TOL
				elif es_linea:
					dentro = absf(lx - LINEA_DELANTE) <= GROSOR_LINEA + GROSOR_TOL and absf(ly) <= largo * 0.5
				else:
					dentro = rel.length() <= radio
				if dentro or (not envuelve and not es_linea and dx == 0 and dz == 0):
					salida.append(c)
		return salida

	## Nombre de la forma con el vocabulario de hoy (el Pipeline anima y pone VFX por este nombre) más `arco`.
	static func _nombre(es_linea: bool, alto: int, envuelve: bool, viaja: bool) -> String:
		if es_linea:
			if envuelve:
				return "arco"
			return "muro" if alto > 0 else "chorro"     # Línea sola = haz desde la mano; con altura, muro alto
		if viaja:
			return "proyectil"
		if envuelve:
			return "columna" if alto > 0 else "corro"
		return "columna" if alto > 0 else "punto"


## =====================================================================================================
##  Receta en 3D: lee SpellRecipe sin tocarla
## =====================================================================================================

class Receta3D extends SpellRecipe:
	## Fase 8: los cinco glifos de la etapa 1. Su recarga viene de `Sigils.FORM`; el significado en 3D lo pone la geometría.
	const GLIFOS_GEO: PackedStringArray = ["linea", "altura", "tamano", "flecha", "barrera"]

	## Cuántas veces se dibujó cada glifo de la etapa 1 (un multiconjunto: el orden de dibujo no cuenta).
	var contadores: Dictionary = {}
	## ¿Lleva algún glifo que NO es de la etapa 1 (levitación, repetición, rebote, pulso, amplificar…)? Entonces la receta
	## se interpreta como hoy hasta la etapa 2 (decidido 8/10).
	var antigua: bool = false
	var _geo: Dictionary = {}

	## 5.4: glifo `linea` (un muro delante). Va aquí porque `Sigils.FORM` es de Pablo: cuando exista la entrada
	## `"linea"` en `Sigils.FORM` (ver diario) se usa la suya; mientras tanto basta con este parche.
	var line: bool = false

	func apply(sigil_name: String) -> void:
		if GLIFOS_GEO.has(sigil_name):
			contadores[sigil_name] = int(contadores.get(sigil_name, 0)) + 1
		else:
			antigua = true
		_geo = {}
		if sigil_name == "linea":
			var repetido: bool = _aplicados.has(sigil_name)
			_aplicados[sigil_name] = int(_aplicados.get(sigil_name, 0)) + 1
			line = true
			spread = true
			blocks = true
			barriers += 1                              # varias líneas: el muro se ensancha, como varias barreras
			cooldown = maxf(cooldown, 2.0)
			if repetido:
				cooldown += Sigils.STACK_COOLDOWN
		else:
			super.apply(sigil_name)
		_sincronizar()

	## ¿Se interpreta con la geometría (Fase 8) o como hoy?
	func usa_geo() -> bool:
		return not antigua

	## La geometría de esta receta (se recalcula al añadir glifos).
	func geo() -> Dictionary:
		if _geo.is_empty():
			_geo = GeometriaHechizo.evaluar(contadores, Jugador3D.MAX_NIVELES_SUBIBLES)
		return _geo

	## Con la geometría mandando, los indicadores antiguos (los lee el resto del Lanzador: campos, barridos, cúpula) se
	## derivan de ella para que ambos caminos digan lo mismo. Cada uno sale de UN dato de la geometría.
	func _sincronizar() -> void:
		if antigua:
			return
		var g: Dictionary = geo()
		travels = float(g["alcance"]) > 0.0 and not bool(g["chorro"])   # el chorro no viaja: la Flecha lo alarga
		reach = 1 if travels else 0                 # varias flechas = más alcance (8.1a), no «chorro»
		spread = String(g["base"]) == "linea" or bool(g["envuelve"])
		line = String(g["base"]) == "linea"
		blocks = bool(g["bloquea"])                  # solo la Barrera; la Línea sólida se decide por material al lanzar
		height = int(g["alto"])
		barriers = 0
		copies = 1
		lifetime = 0.0

	## Muro quieto delante del lanzador: una fila perpendicular a la mirada, a 1,5 casillas. Con flecha, el muro que
	## avanza de siempre (SpellRecipe); con pulso, el mismo muro (empujarlo y estirarlo llega con la física de 5.4b).
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

	## Nombre de la forma, para la animación de lanzar y la matriz de VFX del Pipeline (4.6, 4.6b).
	func forma() -> String:
		if usa_geo():
			return String(geo()["nombre"])
		if es_volador():
			return "proyectil"
		if es_barrera_movil() or (line and not travels):
			return "muro"
		if expande():
			return "onda"
		if spread and height > 0:
			return "columna"
		if spread:
			return "corro"         # barrera sola / área sin barrera: ANILLO cerrado alrededor del lanzador
		if sigue():
			return "flotante"
		return "punto"

	func es_volador() -> bool:
		return _es_volador()

	func es_barrera_movil() -> bool:
		return _es_barrera_movil()

	func es_quieto() -> bool:
		return _es_quieto()

	func sigue() -> bool:
		return not usa_geo() and _sigue()

	## Forma que entienden hoy Vfx3D, Formas3D y la animación de lanzar: `arco` aún no existe allí (8.10), se dibuja como muro.
	func forma_vfx() -> String:
		var f: String = forma()
		if f == "arco":
			return "muro"
		# Clip de lanzar por forma (Pj3D.ANIM_CAST es del Pipeline; aquí se elige entre los que ya existen):
		# el haz lanza en horizontal como un proyectil; el muro ALTO (línea + altura/levitación) alza los brazos.
		if f == "chorro":
			return "proyectil"
		if f == "muro" and line and height > 0:
			return "columna"
		return f

	func expande() -> bool:
		return _expande()

	## Cuánto vive lo que se queda (segundos de juego). Las mismas cuentas que SpellRecipe._construir.
	func vida() -> float:
		var factor: float = Sigils.quality_factor(calidad)
		var v: float = (Sigils.BASE_LIFETIME + lifetime) * factor
		if usa_geo() and String(geo()["nombre"]) == "chorro":
			return GeometriaHechizo.VIDA_CHORRO * factor
		if _es_barrera_movil():
			v = Sigils.WALL_LIFETIME * factor
		elif not usa_geo() and _sigue():
			v = Sigils.FOLLOW_LIFETIME * factor
		elif _es_chorro():
			v = (Sigils.BASE_LIFETIME + lifetime + Sigils.jet_hold(reach)) * factor
		return v

	## El elemento con el daño potenciado (sin tocar el .tres compartido).
	func potenciada(element: RuneData) -> RuneData:
		return _powered(element)

	## Las manifestaciones en CASILLAS relativas al origen y con la dirección del eje +X como "delante":
	## [{p: Vector2, dir: Vector2, nivel: int, elev: float}]. SpellRecipe apila la altura restando a Y en 2D; aquí se
	## deshace para que `nivel` y `elev` sean niveles de verdad.
	func manifestaciones() -> Array:
		if usa_geo():
			var c := Vector2(0.5, 0.5) * Terreno3D.casilla      # origen en el centro de una casilla: sin sesgo de rejilla
			return manifestaciones_en(c, Vector2.RIGHT)
		var res: Array = []
		var volador: bool = _es_volador()
		var apilado: bool = height > 0 and spread and not _expande()
		var sube: float = float(height) * (0.5 if volador else 1.0)
		for d in _fan():
			var puntos: Array = _points(d)
			for i in range(puntos.size()):
				var p: Vector2 = puntos[i]
				var nivel: int = 0
				var elev: float = 0.0
				if apilado:
					nivel = i % (height + 1)
					p.y += LEVEL * float(nivel)
				elif height > 0:
					p.y += LEVEL * sube
					elev = sube
				res.append({"p": p / TILE, "dir": d, "nivel": nivel, "elev": elev})
		if res.size() > Sigils.MAX_MANIFESTATIONS:
			res.resize(Sigils.MAX_MANIFESTATIONS)
		return res

	## 8.5/8.6: las manifestaciones de la geometría para un lanzamiento real. `origen` es el mundo (x, z) en metros y `dir`
	## la mirada. Rasteriza a casillas (las que tienen el centro dentro de la forma) y las apila `alto` niveles. Devuelve
	## lo mismo que `manifestaciones()`: casillas relativas al origen en el marco donde +X es «delante», para que
	## `_crear_campo` las gire con la mirada. Un proyectil no ocupa casillas: devuelve [].
	func manifestaciones_en(origen: Vector2, dir: Vector2) -> Array:
		var res: Array = []
		var g: Dictionary = geo()
		var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		var giro: float = d.angle()
		var cas: float = Terreno3D.casilla
		for c in GeometriaHechizo.celdas(g, origen, d, cas):
			var centro := Vector2((float((c as Vector2i).x) + 0.5) * cas, (float((c as Vector2i).y) + 0.5) * cas)
			var local: Vector2 = ((centro - origen) / cas).rotated(-giro)
			for nivel in range(int(g["alto"]) + 1):
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
