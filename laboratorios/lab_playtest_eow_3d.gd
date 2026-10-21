class_name LabPlaytestEoW3D
extends Node

## LABORATORIO DE PLAYTEST DE EoW (21/10, Juego). Sobre `laboratorios/LabPlaytestEoW.tscn` (la maqueta PruebaTest2 con `nivel = "PlaytestEoW"`). Es el
## sitio donde Pablo JUEGA las mecánicas nuevas del plan (PLAN_EOW rondas 1–4, diario 238) una sala por mecánica y las ve en pantalla: el mismo
## armazón que el lab de puzles de fuego (LabPuzlesFuego3D): salas de 7 × 7, un cartel por sala, HUD y teclas para ir a cada sala.
## Mapa: mundo/datos_nivel/mapas/PlaytestEoW.txt (la cabecera explica cada sala). Las piezas salen de las líneas `; pieza` / `; puzle` del .txt, que lee
## `Puzle3D`; este nodo pone lo que un mapa no sabe decir: el enganche de los efectos, el HUD, las teclas, los carteles y lo que cada sala necesita
## al arrancar (encender el brasero del arquero, crear al arquero…).
##
## LAS SALAS (columna, fila; casillas x 1–7 / 9–15 / 17–23 / 25–31, y 1–7 / 9–15). Hechas la 1, la 2 y la 3; las demás tienen su hook `_preparar_sala_N()`
## vacío y documentado para que cada tarea siguiente lo rellene SIN tocar el resto:
##   1 (0,0) FUEGO POR CONTACTO (A2) · 2 (1,0) AL AGUA (A3) · 3 (2,0) ESCUDO (A5) · 4 (3,0) CAMINOS (D2) · 5 (0,1) SUELO Y CONDICIONES (B1+C2) ·
##   6 (1,1) SALA CERRADA (C3+C1) · 7 (2,1) FINAL INTEGRADO · (3,1) reserva.
##
## TECLAS (constantes de abajo; libres: no las usan la maqueta ni Jugador3D — F7 es diorama, F9 hornear, F10 capa de agua):
##   Shift + 1–7 ir a la sala (también el teclado numérico KP 1–7, sin Shift) · X dibuja/oculta la RUTA de cada goblin (Caminos3D) · M guardar las flags ·
##   F cargarlas · R reiniciar el laboratorio.
##   POR QUÉ SHIFT: el libro de hechizos (presentacion/ui/spellbook.gd) usa 1, 2 y 3 para LANZAR la página 1–3 y lee la entrada antes que nadie (`_input`) sin mirar
##   Shift. Este nodo es el último hijo de la maqueta, así que ve la tecla ANTES que el libro, y CONSUME Shift + 1–7 (`set_input_as_handled`): saltar de sala no lanza
##   página. Las cifras sueltas siguen siendo del libro. El teclado numérico (KP 1–7) tampoco lo usa el libro y vale sin Shift.
## HUD: sala actual, estado del enganche de efectos, las últimas 8 reacciones (`Mundo3D.reaccion`), las flags puestas y los estados de la casilla del jugador.

const NIVEL_MAPA: String = "PlaytestEoW"

# --- Teclas ---
const TECLAS_SALA: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]   ## en el orden de las salas
const TECLAS_SALA_KP: Array = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7]   ## lo mismo en el teclado numérico (sin Shift; no lanza páginas)
const TECLA_RUTAS: Key = KEY_X
const TECLA_GUARDAR: Key = KEY_M
const TECLA_CARGAR: Key = KEY_F
const TECLA_REINICIAR: Key = KEY_R

const T_HUD: float = 0.2                       ## s entre dos refrescos del HUD
const T_RUTAS: float = 0.5                     ## s entre dos recálculos de las rutas dibujadas (el mismo periodo que usa la IA: Combate3D.PERIODO_CAMINO)
const MAX_REACCIONES: int = 8                  ## cuántas reacciones recientes enseña el HUD
const T_MENSAJE: float = 4.0                   ## s que se queda en el HUD el resultado de guardar/cargar
## Dónde se guardan las flags de ESTE laboratorio. No es el `user://flags.json` del juego a propósito: guardar aquí no debe pisar la partida de Pablo.
const RUTA_GUARDADO: String = "user://flags_playtest_eow.json"

# --- Sala 1 · fuego por contacto (A2) ---
## El arquero y su brasero van en la MISMA columna (x=6), uno sobre otro en y: el arquero patrulla en X (Combate3D._patrullar), así que su ronda nunca lo
## acerca al brasero. En la misma fila se prendería él mismo cada pocos segundos (medido: moría ardiendo de su propio brasero, regla A2). El jugador se
## acerca por el norte (6,5)/(6,4): el brasero (6,6) queda entre los dos y la flecha lo cruza.
const SALA1_ARQUERO: Vector2i = Vector2i(6, 7)                  ## casilla del arquero (el mapa no tiene letra de arquero sin reglas: `A` sale espadachín)
const SALA1_BRASERO_ARQUERO: Vector2i = Vector2i(6, 6)          ## el brasero que arde delante del arquero (letra T del mapa + pieza `s1_brasero_arq`)
## Los braseros (como toda pieza que bloquea) cortan la línea de visión: `Terreno3D.linea_libre` mira casillas, y el arquero ni ve al jugador ni, si ve, vuela
## la flecha por tramos (la que comprueba las llamas); medido en el escenario. Para que la flecha CRUCE de verdad una llama, esta casilla se libera al arrancar:
## el brasero se ve y arde igual, pero ni el arquero ni su flecha lo tratan como pared (y el jugador lo atraviesa). false = el comportamiento real del juego.
const SALA1_LIBERAR_BRASERO_ARQUERO: bool = true
## LA FILA GOBLIN–BRASERO–SETOS (medido en el escenario; sin esto la cadena «brasero → goblin → seto» de la sala no ocurre nunca). El goblin patrulla en X, entre el
## brasero (casilla 2,3) y el primer seto (4,3). Tres cosas del juego tal cual lo impiden:
##   1. A un goblin lo frena la casilla ENTERA de un brasero (2,3 u; un Reactivo3D no tiene huella): se queda a 1,17 u de su centro y el contacto (caja de 1,46 u +
##      radio del goblin 0,32) solo llega a 1,05 u. Por mucho que patrulle pegado, NO lo toca. Se corrige moviendo el brasero DENTRO de su casilla 0,6 u hacia el
##      goblin (la maqueta ya desplaza las piezas hasta ±0,35 u al azar): ahora lo alcanza a 0,55 u. `SALA1_CORRIMIENTO_BRASERO` = 0 es el juego tal cual.
##   2. La caja del seto mide 2,07 × 0,92 u y gira al azar: de canto frente al goblin no lo alcanza. El mapa le pone `; giro x 3 0` a los cuatro setos.
##   3. Ardiendo, cada daño (0,5 s) lo para 0,3 s (`INTERRUPCION_DANO`): anda al 40 %. La quemadura dura 3 s (`QUEMA_CONTACTO`) y el contacto con un brasero NO la
##      renueva si ya arde; el pasillo hasta el seto son ~1,9 u (ida al tope, vuelta y pasillo), 4–5 s a ese paso: el fuego se le apaga ANTES de llegar. Se corrige
##      alargando su quemadura hasta `SALA1_QUEMA_GOBLIN_S` cuando se prende (`quema_goblin_s1`, que la prueba puede poner a 0 para ver el juego tal cual).
const SALA1_CORRIMIENTO_BRASERO: float = 0.6          ## u en X hacia el goblin (el brasero de la izquierda)
const SALA1_QUEMA_GOBLIN_S: float = 8.0               ## s de quemadura del goblin guerrero al prenderse (0 = la del juego, 3 s)

# --- Sala 2 · al agua (A3) ---
## La charca son las letras `~` del mapa (x 10–14, y 2–4): agua honda en la que se nada. El mapa NO sabe decir «esta agua empieza helada» (no hay letra de hielo), así
## que la franja del este (x 13–14) se hiela al arrancar con `Terreno3D.poner_helada`: es donde un goblin empujado NO se hunde. `SALA2_HELAR_FRANJA` = false es el
## mapa tal cual (toda la charca honda; el hielo solo existe si el jugador lo lanza).
const SALA2_HELAR_FRANJA: bool = true
const SALA2_FRANJA_X: Array = [13, 14]                ## columnas de la charca que empiezan heladas
const SALA2_FRANJA_Y: Array = [2, 3, 4]               ## filas de la charca
## (Retirado 21/10: el clip de ahogarse se pisaba con `idle` porque `Combate3D._physics_process` seguía con `_animar()` tras hundirse el goblin. Ya está arreglado en
## origen —`if muerto: return` entre `_ajustar_al_suelo` y `_animar`— y el lab no retoca nada.)

# --- Sala 3 · escudo (A5) ---
## El goblin del escudo es la letra `W` de (20,3). Con su IA de verdad MIRA SIEMPRE al jugador en cuanto lo ve (`mirada` = hacia el objetivo al perseguir; patrullando mira
## a ±X), así que «por la espalda» solo se puede si no lo ha visto, y a un jugador que ya está en su radio de detección (5,75 u) el escudo se le gira con él (medido en el
## escenario, aviso 3.14: de cara, `persigue`, en unas ejecuciones; en otras no lo ve a 4,6 u de espaldas y sigue patrullando). Para poder rodearlo y comprobar el cono, el lab lo deja QUIETO mirando a la entrada (+Z): sin IA, pero recibe disparos, empujes y efectos.
## `SALA3_QUIETO` = false es el juego tal cual (el goblin ve al jugador, le planta cara y el escudo siempre está de frente).
const SALA3_GOBLIN: Vector2i = Vector2i(20, 3)
const SALA3_QUIETO: bool = true

## Las salas, en el orden de las teclas. `rect`: casillas (x, y, ancho, alto) · `entrada`: a dónde lleva la tecla · `cartel`: dónde se cuelga el texto.
## `ids`: papel → id de la pieza en el .txt (los que no existen en el mapa salen como aviso en el HUD, no tumban el lab).
const SALAS: Array = [
	{"nombre": "1 Fuego por contacto (A2)", "rect": Rect2i(1, 1, 7, 7), "entrada": Vector2i(2, 6), "cartel": Vector2i(3, 7),
		"texto": "1 · FUEGO POR CONTACTO (A2)\nFuego al brasero de arriba a la izquierda (a 2 casillas, no más): el goblin que patrulla pegado a él se prende\ny, ardiendo, prende los setos secos (el fuego corre por la fila; tarda 8–12 s en llegar al tercero).\nCORTAFUEGOS: agua al TERCER seto (se seca a los 12 s: repite el agua si hace falta): no prende y el cuarto se salva.\nAbajo a la derecha, el arquero: acércate a su brasero por el norte y su flecha lo cruza y llega ardiendo.\n(Ajustes del lab, medidos: ver las constantes SALA1_* en lab_playtest_eow_3d.gd.)",
		"ids": {"brasero": "s1_brasero", "seto1": "s1_seto1", "seto2": "s1_seto2", "seto3": "s1_seto3", "seto4": "s1_seto4", "brasero_arquero": "s1_brasero_arq"}},
	{"nombre": "2 Al agua (A3)", "rect": Rect2i(9, 1, 7, 7), "entrada": Vector2i(12, 7), "cartel": Vector2i(12, 6),
		"texto": "2 · AL AGUA (A3)\nTres goblins en la orilla sur de la charca. VIENTO (flecha) desde el sur contra los de la IZQUIERDA y el del centro: empujados\na la parte honda se HUNDEN (sin botín, aviso «hundido»). El de la DERECHA cae en la franja de HIELO: no se hunde.\nLanza HIELO a la charca honda y vuelve a empujar: el hielo lo sostiene. FUEGO al hielo y se derrite.\nAl norte, otro goblin no te ve desde allí (la charca es más ancha que su vista): dispárale (agua, flecha) desde la orilla y te rodea\npor la orilla o cruza por el hielo, pero nunca se mete solo en el agua honda.",
		"ids": {}},
	{"nombre": "3 Escudo (A5)", "rect": Rect2i(17, 1, 7, 7), "entrada": Vector2i(20, 6), "cartel": Vector2i(20, 7),
		"texto": "3 · ESCUDO (A5)\nGoblin con escudo, quieto y mirando a la entrada. Dispara desde aquí (de frente): el escudo lo para («bloqueado»).\nRodéalo y dispara por la ESPALDA o de lado: pasa. FUEGO de frente: el escudo ARDE («prendido») y a los 3 s se consume\n(«consumido»); después el disparo de frente ya llega. AGUA apaga el escudo que arde; TIERRA lo desgasta hasta romperlo.",
		"ids": {}},
	{"nombre": "4 Caminos (D2)", "rect": Rect2i(25, 1, 7, 7), "entrada": Vector2i(28, 6), "cartel": Vector2i(28, 7),
		"texto": "4 · CAMINOS (D2)\n(sala vacía: la rellena otra tarea)\nRutas de goblin con obstáculos, escalones y agua. Tecla X: dibuja la ruta.",
		"ids": {}},
	{"nombre": "5 Suelo y condiciones (B1+C2)", "rect": Rect2i(1, 9, 7, 7), "entrada": Vector2i(4, 14), "cartel": Vector2i(4, 15),
		"texto": "5 · SUELO Y CONDICIONES (B1+C2)\n(sala vacía: la rellena otra tarea)\nCasillas mojadas, heladas o quemadas y reglas `si=casilla(x,y).estado`.",
		"ids": {}},
	{"nombre": "6 Sala cerrada (C3+C1)", "rect": Rect2i(9, 9, 7, 7), "entrada": Vector2i(12, 14), "cartel": Vector2i(12, 15),
		"texto": "6 · SALA CERRADA (C3+C1)\n(sala vacía: la rellena otra tarea)\nCerrojo + vigía + cofre + flags. M guarda las flags, F las carga.",
		"ids": {}},
	{"nombre": "7 Final integrado", "rect": Rect2i(17, 9, 7, 7), "entrada": Vector2i(20, 14), "cartel": Vector2i(20, 15),
		"texto": "7 · FINAL INTEGRADO\n(sala vacía: la rellena otra tarea)\nTodas las mecánicas juntas.",
		"ids": {}},
]

var m: Variant = null                          ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _mundo: Mundo3D = null
var _puzle_nodo: Puzle3D = null
var _salas: Array = []                         ## [{nombre, rect, entrada, <papel>: nodo, …}] una por sala (los papeles que faltan valen null)
var _avisos: Array = []
var _hud: Label = null
var _t_hud: float = 0.0
var _reloj: float = 0.0                        ## s desde que arrancó el lab (con el tiempo de juego, no de pared)
var _enganche_ok: bool = false                 ## lo que devolvió `ReaccionesVfx3D.conectar`
var _reacciones: Array = []                    ## [{nombre, tipo, t}] las últimas MAX_REACCIONES, la más reciente al final
var _n_reacciones: int = 0                     ## cuántas han llegado en total (el HUD no las pierde aunque la lista rote)
var _mensaje: String = ""
var _t_mensaje: float = 0.0
var _rutas_visibles: bool = false
var _t_rutas: float = 0.0
var _marcas_ruta: Node3D = null
var _malla_marca: CylinderMesh = null
var _guerrero_s1: Combate3D = null
var _arquero_s1: Combate3D = null
var _sala_anterior: int = -1                   ## la sala del jugador en el fotograma anterior (para avisar a `_al_entrar_sala`)
var quema_goblin_s1: float = SALA1_QUEMA_GOBLIN_S   ## s de quemadura del guerrero de la sala 1 al prenderse; las pruebas pueden cambiarlo (0 = la del juego)


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada (con el jugador y, si la escena lo pide, el agua física).
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	_mundo = m.get("_mundo") as Mundo3D
	(m as Node).move_child(self, (m as Node).get_child_count() - 1)       # el último hijo recibe `_input` el primero: antes que el libro de hechizos (ver la cabecera)
	_enganchar_efectos()
	_puzle_nodo = Puzle3D.new()
	_puzle_nodo.name = "Puzles"
	add_child(_puzle_nodo)
	_puzle_nodo.iniciar(m, NIVEL_MAPA)
	_avisos.append_array(_puzle_nodo.avisos)
	_montar_salas()
	_preparar_salas()
	_montar_hud()
	set_process(true)


## Engancha la tabla reacción → efecto + sonido del Pipeline (`ReaccionesVfx3D`) a `Mundo3D.reaccion` (sin esto A4 no se ve ni suena; el Pipeline pidió que el
## nivel lo haga al montarse) y escucha la misma señal para el HUD. Si `conectar` devuelve false no hay efectos: se ve en el HUD, no se esconde.
func _enganchar_efectos() -> void:
	var padre_fx: Node3D = m.get("_efectos") as Node3D
	_enganche_ok = _mundo != null and padre_fx != null and ReaccionesVfx3D.conectar(_mundo, padre_fx)
	if not _enganche_ok:
		_avisos.append("ReaccionesVfx3D.conectar devolvió false (mundo %s, padre de efectos %s): las reacciones no se verán ni sonarán" % [str(_mundo), str(padre_fx)])
	if _mundo != null and not _mundo.reaccion.is_connected(_al_reaccionar):
		_mundo.reaccion.connect(_al_reaccionar)


## Anota la reacción para el HUD. El tipo se calcula AHORA (con la misma regla que usa la tabla de efectos): el nodo puede liberarse un segundo después.
func _al_reaccionar(nombre: String, _punto: Vector3, nodo: Node) -> void:
	# Sala 1: la quemadura del goblin guerrero se alarga (ver SALA1_QUEMA_GOBLIN_S). `prender_por_contacto` pone `quemando` ANTES de avisar «prendido».
	if nombre == "prendido" and nodo != null and nodo == _guerrero_s1 and quema_goblin_s1 > 0.0:
		_guerrero_s1.quemando = maxf(_guerrero_s1.quemando, quema_goblin_s1)
	var tipo: String = ReaccionesVfx3D.tipo_de(nodo)
	if tipo == "" and nodo != null:
		tipo = String(nodo.get_class())
	_reacciones.append({"nombre": nombre, "tipo": tipo if tipo != "" else "-", "t": _reloj})
	_n_reacciones += 1
	while _reacciones.size() > MAX_REACCIONES:
		_reacciones.pop_front()


## Cada sala como diccionario de piezas (los ids de SALAS buscados en el .txt) y su cartel. Un id que no está en el mapa deja el papel en null y sale como
## aviso: así se ve al arrancar y no a media prueba.
func _montar_salas() -> void:
	for s in SALAS:
		var sala: Dictionary = s
		var q: Dictionary = {"nombre": sala["nombre"], "rect": sala["rect"], "entrada": sala["entrada"]}
		var ids: Dictionary = sala["ids"]
		for papel in ids:
			var nd: Node = _puzle_nodo.nodo(String(ids[papel]))
			if nd == null:
				_avisos.append("%s: no hay pieza «%s» (papel «%s») en %s.txt" % [sala["nombre"], ids[papel], papel, NIVEL_MAPA])
				push_warning("LabPlaytestEoW3D: " + String(_avisos.back()))
			q[papel] = nd
		_salas.append(q)
		_cartel(sala["cartel"] as Vector2i, String(sala["texto"]))


## Un cartel flotante en la casilla `c` con las instrucciones de la sala.
func _cartel(c: Vector2i, texto: String) -> void:
	var rot := Label3D.new()
	rot.text = texto
	rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rot.font_size = 26
	rot.outline_size = 8
	rot.pixel_size = 0.006
	rot.modulate = Color(1.0, 0.97, 0.85)
	rot.position = Terreno3D.centro_de(c, Terreno3D.alto_suelo + 2.6)
	(m.get("_props") as Node).add_child(rot)


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que cada sala necesita al arrancar. Las salas 2–7 SOLO rellenan su hook (y, si quieren, `_al_entrar_sala`).
# ---------------------------------------------------------------------------------------------------------------------

func _preparar_salas() -> void:
	_preparar_sala_1()
	_preparar_sala_2()
	_preparar_sala_3()
	_preparar_sala_4()
	_preparar_sala_5()
	_preparar_sala_6()
	_preparar_sala_7()


## SALA 1 · FUEGO POR CONTACTO (A2). Lo que el mapa no dice: el brasero del arquero arde desde el principio, el arquero existe (sin reglas la letra `A` es un
## espadachín) y el goblin guerrero de la fila de setos es el de la casilla (3,3). El brasero de la izquierda y los setos se quedan como el mapa los pone.
func _preparar_sala_1() -> void:
	var q: Dictionary = sala(1)
	var br: Variant = q.get("brasero_arquero")
	if br != null and is_instance_valid(br):
		(br as Reactivo3D).encender_llama()
	if SALA1_LIBERAR_BRASERO_ARQUERO:
		Terreno3D.liberar_celda(SALA1_BRASERO_ARQUERO)          # ver el comentario de la constante
	var izq: Variant = q.get("brasero")
	if izq != null and is_instance_valid(izq):
		(izq as Node3D).global_position.x += SALA1_CORRIMIENTO_BRASERO            # ver el comentario de la constante
	_guerrero_s1 = _combate_en(Vector2i(3, 3))
	_arquero_s1 = _crear_arquero(SALA1_ARQUERO)
	q["guerrero"] = _guerrero_s1
	q["arquero"] = _arquero_s1
	if _guerrero_s1 == null:
		_avisos.append("sala 1: no hay goblin guerrero en (3,3) (letra W del mapa; ¿falta arte/modelos/goblin_warrior_chibi.glb?)")
	if _arquero_s1 == null:
		_avisos.append("sala 1: no se pudo crear el arquero (¿falta arte/modelos/goblin_archer_chibi.glb?)")


## SALA 2 · AL AGUA (A3). El mapa pone la charca (`~`), los tres goblins de la orilla sur (W en (10,5), (12,5), (14,5)) y el que persigue desde la orilla norte (W en
## (12,1)). Lo que el mapa no dice: la franja de hielo inicial (ver SALA2_HELAR_FRANJA). El HUD enseña `hundido` y `empujado` en las reacciones.
func _preparar_sala_2() -> void:
	var q: Dictionary = sala(2)
	if SALA2_HELAR_FRANJA:
		for x in SALA2_FRANJA_X:
			for y in SALA2_FRANJA_Y:
				Terreno3D.poner_helada(Vector2i(int(x), int(y)), true)
	q["orilla_izq"] = _combate_en(Vector2i(10, 5))
	q["orilla_centro"] = _combate_en(Vector2i(12, 5))
	q["orilla_hielo"] = _combate_en(Vector2i(14, 5))
	q["perseguidor"] = _combate_en(Vector2i(12, 1))
	for papel in ["orilla_izq", "orilla_centro", "orilla_hielo", "perseguidor"]:
		if q[papel] == null:
			_avisos.append("sala 2: no hay goblin «%s» (letra W del mapa)" % papel)


## SALA 3 · ESCUDO (A5). El mapa pone al goblin (W en (20,3)); aquí se le cuelga el escudo y se le deja mirando a la entrada (ver SALA3_QUIETO).
func _preparar_sala_3() -> void:
	var q: Dictionary = sala(3)
	var g: Combate3D = _combate_en(SALA3_GOBLIN)
	q["goblin"] = g
	q["escudo"] = null
	if g == null:
		_avisos.append("sala 3: no hay goblin en %s (letra W del mapa)" % str(SALA3_GOBLIN))
		return
	q["escudo"] = Escudo3D.equipar(g)
	g.mirada = Vector3(0.0, 0.0, 1.0)                  # hacia el sur, a la entrada (20,6)
	if SALA3_QUIETO:
		g.quieto = true
	if g.pj != null:
		g.pj.mirar(g.mirada, 1.0)


## SALA 4 · CAMINOS (D2). HOOK VACÍO. Idea: muros/agua/escalones de por medio y un goblin que persigue; la tecla X (rutas) dibuja lo que calcula Caminos3D
## desde cada goblin hasta el jugador. Piezas del .txt con prefijo `s4_`.
func _preparar_sala_4() -> void:
	pass


## SALA 5 · SUELO Y CONDICIONES (B1+C2). HOOK VACÍO. Idea: reglas `si=casilla(x,y).mojada|helada|quemada…` en el .txt (prefijo `s5_`) y, aquí, estados de
## suelo de salida con `Terreno3D.estados.poner(c, "mojada", true)`. El HUD ya enseña los estados de la casilla del jugador.
func _preparar_sala_5() -> void:
	pass


## SALA 6 · SALA CERRADA (C3+C1). HOOK VACÍO. Idea: `vigia` + `cerrojo` + `cofre` en el .txt (prefijo `s6_`; ejemplo completo en la cabecera de escenas/puzle.gd)
## y goblins creados aquí con `_crear_goblin`. M guarda las flags (`RUTA_GUARDADO`) y F las carga: el HUD las lista.
func _preparar_sala_6() -> void:
	pass


## SALA 7 · FINAL INTEGRADO. HOOK VACÍO. Idea: una sala que junte las anteriores. Piezas del .txt con prefijo `s7_`.
func _preparar_sala_7() -> void:
	pass


## Se llama cuando el jugador pasa de una sala a otra (`n` = 1–7, 0 = pasillo o hueco de reserva). HOOK VACÍO para lo que haya que hacer al entrar
## (cerrar una puerta, arrancar un temporizador…).
func _al_entrar_sala(_n: int) -> void:
	pass


# ---------------------------------------------------------------------------------------------------------------------
#  Ayudas para crear enemigos (las salas 2–7 las usan)
# ---------------------------------------------------------------------------------------------------------------------

## El Combate3D vivo cuya casilla de PARTIDA (`casa`) es `c`: así se reconoce a los goblins que pone el mapa (letra W).
func _combate_en(c: Vector2i) -> Combate3D:
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb != null and Terreno3D.celda_de(cb.casa) == c:
			return cb
	return null


## Un goblin con su IA en la casilla `c`. `arquero` = el modelo del arquero (el mapa solo sabe poner guerrero o espadachín sin reglas). Lo mismo que hace
## Jugador3D.montar con los de `_goblins`, pero después de montado el mundo. null si falta el modelo.
func _crear_goblin(c: Vector2i, arquero: bool = false) -> Combate3D:
	if _jug == null:
		return null
	var pj: Pj3D = m.call("_personaje", m.PJ_ARQUERO if arquero else m.PJ_GOBLIN, m.call("_pos_marca", c, m.ALTO))
	if pj == null:
		return null
	(m.get("_goblins") as Array).append(pj)
	return Combate3D.equipar(pj, m, _jug, _jug.lanz)


func _crear_arquero(c: Vector2i) -> Combate3D:
	return _crear_goblin(c, true)


# ---------------------------------------------------------------------------------------------------------------------
#  Acceso para las pruebas y para las salas
# ---------------------------------------------------------------------------------------------------------------------

## La sala `n` (1–7) como diccionario de piezas; {} si no existe.
func sala(n: int) -> Dictionary:
	return _salas[n - 1] if n >= 1 and n <= _salas.size() else {}


func puzle_nodo() -> Puzle3D:
	return _puzle_nodo


func enganche_ok() -> bool:
	return _enganche_ok


func avisos() -> Array:
	return _avisos


## Las últimas reacciones ([{nombre, tipo, t}], la más reciente al final) y cuántas han llegado en total.
func reacciones() -> Array:
	return _reacciones.duplicate()


func total_reacciones() -> int:
	return _n_reacciones


func hud() -> Label:
	return _hud


func rutas_visibles() -> bool:
	return _rutas_visibles


## Cuántas marcas de ruta hay dibujadas ahora mismo.
func marcas_de_ruta() -> int:
	return _marcas_ruta.get_child_count() if _marcas_ruta != null else 0


## La sala (1–7) en la que está la casilla `c`; 0 si es un hueco de paso, un pasillo o la reserva.
func sala_de(c: Vector2i) -> int:
	for i in range(SALAS.size()):
		if (SALAS[i]["rect"] as Rect2i).has_point(c):
			return i + 1
	return 0


func sala_actual() -> int:
	return sala_de(Terreno3D.celda_de(_jug.global_position)) if _jug != null else 0


## Teletransporte del jugador a la entrada de la sala `n` (1–7). Devuelve false si no existe.
func ir_a_sala(n: int) -> bool:
	if n < 1 or n > SALAS.size():
		return false
	colocar_jugador(SALAS[n - 1]["entrada"] as Vector2i)
	return true


## Teletransporte del jugador a una casilla (lo mismo que escenario_base.colocar_jugador).
func colocar_jugador(c: Vector2i) -> void:
	if _jug == null:
		return
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if _jug.pj != null:
		_jug.pj.position = p
	_jug.position = p


## Guarda las flags en `RUTA_GUARDADO`. Devuelve si se pudo.
func guardar_flags() -> bool:
	var ok: bool = Flags.i().guardar(RUTA_GUARDADO)
	_decir("flags guardadas (%d) en %s" % [Flags.i().nombres().size(), RUTA_GUARDADO] if ok else "NO se pudieron guardar las flags")
	return ok


## Carga las flags de `RUTA_GUARDADO`. Devuelve si había algo que cargar.
func cargar_flags() -> bool:
	var ok: bool = Flags.i().cargar(RUTA_GUARDADO)
	_decir("flags cargadas (%d)" % Flags.i().nombres().size() if ok else "no hay guardado en %s" % RUTA_GUARDADO)
	return ok


func _decir(texto: String) -> void:
	_mensaje = texto
	_t_mensaje = T_MENSAJE
	print("LabPlaytestEoW: " + texto)


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_reloj += delta
	if _t_mensaje > 0.0:
		_t_mensaje -= delta
	var n: int = sala_actual()
	if n != _sala_anterior:
		_sala_anterior = n
		_al_entrar_sala(n)
	if _rutas_visibles:
		_t_rutas -= delta
		if _t_rutas <= 0.0:
			_t_rutas = T_RUTAS
			_dibujar_rutas()
	_t_hud += delta
	if _t_hud >= T_HUD:
		_t_hud = 0.0
		_refrescar_hud()


## `_input` y no `_unhandled_input`: el libro de hechizos se queda con 1–3 antes de que lleguen a un `_unhandled_input` (ver la cabecera). No consume nada.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == TECLA_REINICIAR:
		get_tree().reload_current_scene()
	elif k.keycode == TECLA_RUTAS:
		alternar_rutas()
	elif k.keycode == TECLA_GUARDAR:
		guardar_flags()
	elif k.keycode == TECLA_CARGAR:
		cargar_flags()
	else:
		var i: int = TECLAS_SALA.find(k.keycode) if k.shift_pressed else -1       # solo con Shift: sin él, 1–3 son del libro de hechizos
		if i < 0:
			i = TECLAS_SALA_KP.find(k.keycode)
		if i >= 0:
			ir_a_sala(i + 1)
			get_viewport().set_input_as_handled()             # el libro no debe ver esta tecla (si no, lanzaría la página 1–3)


# ---------------------------------------------------------------------------------------------------------------------
#  Rutas de los goblins (Caminos3D)
# ---------------------------------------------------------------------------------------------------------------------

func alternar_rutas() -> void:
	_rutas_visibles = not _rutas_visibles
	if _rutas_visibles:
		_t_rutas = 0.0
		_dibujar_rutas()
	else:
		_borrar_rutas()


func _borrar_rutas() -> void:
	if _marcas_ruta == null:
		return
	for h in _marcas_ruta.get_children():
		h.queue_free()
		_marcas_ruta.remove_child(h)


## Redibuja la ruta que `Caminos3D.camino` da de cada goblin vivo a la casilla del jugador: un disco plano en cada casilla, de un color por goblin. La ruta
## PROPIA del goblin (`Combate3D._ruta`) es privada y solo existe mientras persigue; esta es la que calcularía ahora mismo, que es lo que se quiere ver.
func _dibujar_rutas() -> void:
	if _jug == null:
		return
	if _marcas_ruta == null:
		_marcas_ruta = Node3D.new()
		_marcas_ruta.name = "RutasGoblins"
		(m as Node).add_child(_marcas_ruta)
		_malla_marca = CylinderMesh.new()
		_malla_marca.top_radius = 0.28
		_malla_marca.bottom_radius = 0.28
		_malla_marca.height = 0.05
	_borrar_rutas()
	var meta: Vector2i = Terreno3D.celda_de(_jug.global_position)
	var i: int = 0
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb == null or cb.muerto:
			continue
		var color: Color = Color.from_hsv(fmod(float(i) * 0.19, 1.0), 0.85, 1.0)
		i += 1
		var camino: Array[Vector2i] = Caminos3D.camino(Terreno3D.celda_de(cb.global_position), meta)
		for c in camino:
			var mi := MeshInstance3D.new()
			mi.mesh = _malla_marca
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat
			mi.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c) + 0.06)
			_marcas_ruta.add_child(mi)


# ---------------------------------------------------------------------------------------------------------------------
#  HUD
# ---------------------------------------------------------------------------------------------------------------------

func _montar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_refrescar_hud()


func _refrescar_hud() -> void:
	if _hud == null:
		return
	_hud.text = texto_hud()


## El texto del HUD (separado para que la prueba lo lea sin esperar al refresco).
func texto_hud() -> String:
	var n: int = sala_actual()
	var t: String = "LAB PLAYTEST EoW · sala %s\n" % (String(SALAS[n - 1]["nombre"]) if n > 0 else "(pasillo)")
	t += "  efectos de reacciones: %s\n" % ("enganchados (ReaccionesVfx3D)" if _enganche_ok else "NO ENGANCHADOS: no se ven ni suenan")
	t += "REACCIONES (últimas %d de %d)\n" % [_reacciones.size(), _n_reacciones]
	if _reacciones.is_empty():
		t += "  (ninguna todavía)\n"
	for i in range(_reacciones.size() - 1, -1, -1):
		var r: Dictionary = _reacciones[i]
		t += "  %-14s %-10s hace %4.1f s\n" % [r["nombre"], r["tipo"], _reloj - float(r["t"])]
	var flags: Array = Flags.i().nombres()
	t += "FLAGS (%d): %s\n" % [flags.size(), ", ".join(PackedStringArray(flags)) if not flags.is_empty() else "ninguna"]
	if _jug != null:
		t += _texto_casilla(Terreno3D.celda_de(_jug.global_position))
	if _t_mensaje > 0.0:
		t += "  >> %s\n" % _mensaje
	for a in _avisos:
		t += "  AVISO %s\n" % String(a)
	t += "Shift+1–7 sala (o KP 1–7) · X rutas goblins (%s) · M guardar flags · F cargar flags · R reiniciar" % ("SÍ" if _rutas_visibles else "no")
	return t


## Los estados de la casilla `c`: del suelo (B1), agua (y su profundidad), helada y altura.
func _texto_casilla(c: Vector2i) -> String:
	var estados: Array = []
	for e in EstadosSuelo3D.TODOS:
		if Terreno3D.estados.tiene(c, e):
			estados.append("%s %.1f" % [e, Terreno3D.estados.intensidad(c, e)])
	var agua: String = "no"
	if Terreno3D.es_agua(c):
		agua = "sí"
		if Terreno3D.agua_sim != null:
			agua += " (%.2f u)" % Terreno3D.agua_sim.profundidad_casilla(c)
	return "CASILLA %s · estados: %s · agua: %s · helada: %s · altura: %d\n" % [str(c), ", ".join(PackedStringArray(estados)) if not estados.is_empty() else "ninguno",
		agua, "sí" if Terreno3D.helada(c) else "no", Terreno3D.altura_en(c)]
