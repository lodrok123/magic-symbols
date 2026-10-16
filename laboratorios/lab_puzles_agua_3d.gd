class_name LabPuzlesAgua3D
extends Node

## LABORATORIO DE PUZLES DE AGUA (Fase 13.8, 15/10, Juego). F6 sobre `laboratorios/LabPuzlesAgua3D.tscn`.
## Mapa: mundo/datos_nivel/mapas/PuzlesAgua.txt (25 × 25: nueve salas de 7 × 7; el jugador nace en la del centro y cada sala es un
## puzle). Para DEPURAR la mecánica de fluidos con las piezas de verdad (tinaja, canal, cauce `c`, simulación AguaSim3D, jugador) y con
## los tres disparadores que pidió Pablo: BOTÓN `!` (cualquier magia), PLACA `@` (sensor de presencia: pisarla) y PULSADOR DE AGUA `%`
## (solo agua). Cada puzle se puede resolver por su vía «natural» (lanzar el hechizo que toca) y por los botones, para separar «falla
## el agua» de «falla el disparador».
##
## DESDE EL 16/10 (Fase 12.3) LAS PIEZAS Y LOS PUZLES NO SE MONTAN AQUÍ: salen de las líneas `; pieza` y `; puzle` de PuzlesAgua.txt, que lee
## `Puzle3D` (escenas/puzle.gd; la gramática está en su cabecera). Este nodo conserva lo que es del laboratorio y no del nivel: el HUD, las
## teclas, los carteles de cada sala, `puzle(nombre)` (la sala como diccionario de piezas, para las pruebas) y `pulsador_en(celda)`.
## `SALAS` dice, por sala, qué id del .txt hace cada papel; si Pablo cambia un id en el mapa, el aviso sale al arrancar.
##
## POR QUÉ ES UN NODO HIJO Y NO `reglas = "..."`: igual que TerraFina3D: PruebaTest2 elige las reglas por cadena fija (Pipeline). La
## escena cuelga este nodo como hijo; `_ready` del hijo corre antes que el del padre, así que espera un fotograma y entonces la
## maqueta ya está montada (jugador, Lanzador3D, simulación de agua y la tinaja conectada a `Mundo3D.abrir_cauce`).
##
## LAS SALAS (columna, fila de salas; casillas x 1–7 / 9–15 / 17–23, y igual):
##   Q1 (1,0) LLENA LA CUENCA: tinaja `u` → codo `L` → recto `-` → cuenca `c` 3 × 2. Nivel ≥ 0,45 en (12,5) abre la puerta Z.
##            Vías: agua a la tinaja · botón `!` (activa la tinaja) · placa `@`.
##   Q2 (0,0) TRASVASE: cuenca A llena (2–3, 2–3) · compuerta de HIELO en (4,3) · cuenca B vacía (5–6, 2–3).
##            Fuego a la compuerta (se derrite) o `!`/`@` la abren; B ≥ 0,35 en (6,3) abre Z. (Vasos comunicantes: 0,9 → ~0,45/0,45.)
##   Q3 (2,0) PRESA DE HIELO: arroyo de canal `-` (18, 1–7) con manantial arriba y desagüe abajo. Hielo en (18,2) corta el agua: el
##            vado (18,4) baja de 0,25 y Z se abre MIENTRAS dure el hielo (DURA_HIELO s). `!`/`@` hielan (18,2) por código.
##   Q4 (0,1) DESVÍA EL RÍO: manantial (4,10) → bifurcación (4,12): brazo oeste (3–1, 12) con compuerta ABIERTA en (3,12) y desagüe en (1,12);
##            brazo este (5–7, 12), fondo de saco con la «rueda» (detector ≥ 0,4 en (6,12)). Cerrar la compuerta (hielo, o `!`/`@`) embalsa el
##            caudal en el este y la rueda arranca; reabrirla (fuego) lo vacía por el oeste.
##   Q5 (2,1) VACÍA PARA PASAR: pasillo `c` (20, 10–12) inundado a 0,7 (se nada). Desagüe: compuerta de hielo en (20,13) hacia el
##            sumidero (20,14). Fuego la abre (o `!`/`@`); con (20,11) ≤ 0,25 Z se abre. El fuego también evapora (VOL_EVAPORA por golpe).
##   Q6 (1,2) RIEGA: pulsador de AGUA `%` (12,19): solo el agua lo activa (el botón `!` de al lado NO abre Z: es el control). También `@`.
##            La sala es hierba: para ver el charco de un impacto (y si se seca: bug «charco eterno»).
##   Q7 (2,2) RAYO POR EL AGUA: fuente eléctrica `e` (18,20) → pozo con agua (19,20) → NEXO seco (20,20) → pozo con agua (21,20) → tótem de
##            rayo `i` (22,20). Los pozos tienen nivel fijo (siempre conducen); el nexo (NexoRayo3D, una pila de piedra) corta la corriente hasta
##            que un hechizo de agua lo moja: entonces conduce 30 s, la fuente llega al tótem y Z se abre. Fuego lo seca. `!`/`@` lo mojan por código.
##            (16/10, Pablo: «falta un elemento en medio que haga de nexo»; antes era un canal seco de 3 piezas que pedía 6 hechizos y no se leía.)
##   Q9 (3,0) MOLINO: arroyo de canal (28, 1–7) cerrado por una compuerta en (28,2); el molino (28,5) gira con la corriente (abre Z
##            mientras gira) o 6 s si lo golpea un hechizo de agua (Z se abre y se vuelve a cerrar). `!`/`@` abren la compuerta.
##   Q10 (3,1) ROCA Y BARRIL: cauce (25–30, 12) con manantial en (26,12) y aliviadero en (25,12); una ROCA en (28,12) corta el curso.
##            Fuego al barril (28,11) → explota → la roca se desmorona → el agua llega al este; (30,12) ≥ 0,4 abre Z. Hielo en (27,12)
##            vuelve a cortarlo. `!`/`@` encienden el barril por código.
##   Q8 (0,2) NIVEL JUSTO: tinaja `u` (5,19) → recto `-` (4,19) → cuenca (2–3, 18–19). Z abre solo con (2,18) en 0,5 ± 0,08. El `!` CIERRA
##            EL GRIFO (AguaSim3D.apagar_fuente) y el fuego evapora para bajar. Las tinajas del lab vierten CAUDAL_TINAJA_LAB durante VOL_TINAJA_LAB u³.
## Teclas: 1–9 y 0 (= Q10) llevan al jugador a la entrada de esa sala · R recarga la escena · (las de la maqueta siguen valiendo).
## El HUD muestra, por puzle, la profundidad leída por su detector, el estado de su compuerta y si la puerta está abierta; y el
## volumen total de agua de la escena (si crece sin manantiales, hay una fuga al revés).

const NIVEL_MAPA: String = "PuzlesAgua"
## Reflejo de las líneas de PuzlesAgua.txt (`abrir_cauce(0.5,20)` de las tinajas y `caudal=1.5` del arroyo de Q3): el escenario las usa para
## sus mensajes y sus cuentas. Si Pablo cambia el .txt, `_comprobar_constantes` lo avisa al arrancar.
const CAUDAL_TINAJA_LAB: float = 0.5         ## u³/s de las tinajas del lab (Pablo, 15/10: con 1,5 la banda de Q8 se cruza en 3 s y Q1 inunda la sala)
const VOL_TINAJA_LAB: float = 20.0           ## u³ por tinaja: Q1 necesita 14,3 para 0,45 en 6 casillas; la tinaja vierte unos 40 s
const CAUDAL_ARROYO: float = 0.6             ## u³/s del manantial de Q4 (y de Q3 hasta el 15/10)
const CAUDAL_ARROYO_Q3: float = 1.5          ## u³/s del arroyo de Q3. Medido 15/10: con 0,6 el vado se queda en 0,23 (< 0,25, la puerta ya está abierta sin presa)
const T_HUD: float = 0.2

## Las diez salas, en el orden de las teclas 1–9 y 0. `entrada`: casilla a la que lleva la tecla; `cartel`: dónde se cuelga el texto;
## `ids`: papel → id de la pieza en PuzlesAgua.txt (los papeles que no aparecen valen null en el diccionario de la sala).
const SALAS: Array = [
	{"nombre": "Q1 cuenca", "entrada": Vector2i(12, 8), "cartel": Vector2i(12, 7),
		"texto": "Q1 · LLENA LA CUENCA\nAgua a la tinaja (o botón/placa): vierte 20 u³ y se vacía.\nCon la cuenca a 0,45 se abre la puerta.",
		"ids": {"detector": "q1_nivel", "puerta": "q1_puerta", "tinaja": "q1_tinaja"}},
	{"nombre": "Q2 trasvase", "entrada": Vector2i(4, 8), "cartel": Vector2i(4, 7),
		"texto": "Q2 · TRASVASE\nFuego a la compuerta de hielo (o botón/placa):\nlas dos cuencas se igualan y la puerta se abre a 0,35.",
		"ids": {"detector": "q2_nivel", "compuerta": "q2_compuerta", "puerta": "q2_puerta"}},
	{"nombre": "Q3 presa", "entrada": Vector2i(20, 8), "cartel": Vector2i(20, 7),
		"texto": "Q3 · PRESA DE HIELO\nHielo arriba del arroyo (o botón/placa): el vado se seca\ny la puerta se abre mientras dure el hielo (20 s).",
		"ids": {"detector": "q3_nivel", "puerta": "q3_puerta"}},
	{"nombre": "Q4 desvío", "entrada": Vector2i(8, 12), "cartel": Vector2i(7, 12),
		"texto": "Q4 · DESVÍA EL RÍO\nCierra el brazo oeste (hielo a la compuerta, o botón/placa):\nel agua se embalsa al este y la rueda abre la puerta.",
		"ids": {"detector": "q4_nivel", "compuerta": "q4_compuerta", "puerta": "q4_puerta"}},
	{"nombre": "Q5 vaciar", "entrada": Vector2i(16, 12), "cartel": Vector2i(17, 12),
		"texto": "Q5 · VACÍA PARA PASAR\nFuego al tapón de hielo del desagüe (o botón/placa):\nel pasillo se vacía y la puerta se abre.",
		"ids": {"detector": "q5_nivel", "compuerta": "q5_compuerta", "puerta": "q5_puerta"}},
	{"nombre": "Q6 riego", "entrada": Vector2i(12, 16), "cartel": Vector2i(12, 17),
		"texto": "Q6 · RIEGO\nEl botón azul solo responde al AGUA (el rojo es de control:\nse pulsa con cualquier magia pero no abre nada). La placa amarilla se pisa.",
		"ids": {"puerta": "q6_puerta", "pulsador_agua": "q6_agua", "control": "q6_control"}},
	{"nombre": "Q7 rayo", "entrada": Vector2i(20, 16), "cartel": Vector2i(20, 17),
		"texto": "Q7 · RAYO POR EL AGUA\nMoja la pila del centro (agua) para unir las dos aguas:\nla corriente llega al tótem y abre la puerta.",
		"ids": {"puerta": "q7_puerta", "nexo": "q7_nexo", "emisor": "q7_fuente", "totem": "q7_totem"}},
	{"nombre": "Q8 nivel justo", "entrada": Vector2i(4, 16), "cartel": Vector2i(4, 17),
		"texto": "Q8 · NIVEL JUSTO\nLa puerta solo abre con la cuenca entre 0,42 y 0,58.\nAgua a la tinaja para subir; botón/placa cierran el grifo; fuego evapora.",
		"ids": {"detector": "q8_nivel", "puerta": "q8_puerta", "tinaja": "q8_tinaja"}},
	{"nombre": "Q9 molino", "entrada": Vector2i(28, 8), "cartel": Vector2i(28, 7),
		"texto": "Q9 · MOLINO\nAgua a la rueda: gira 6 s y abre la puerta un rato.\nBotón/placa abren la compuerta: el arroyo corre y la rueda no para.",
		"ids": {"compuerta": "q9_compuerta", "puerta": "q9_puerta", "molino": "q9_molino"}},
	{"nombre": "Q10 roca", "entrada": Vector2i(24, 12), "cartel": Vector2i(25, 12),
		"texto": "Q10 · ROCA Y BARRIL\nFuego al barril: explota y rompe la roca que corta el cauce;\nel agua llega al este y abre la puerta. Hielo lo vuelve a cortar.",
		"ids": {"detector": "q10_nivel", "compuerta": "q10_roca", "puerta": "q10_puerta", "barril": "q10_barril"}},
]
## Papeles que toda sala tiene en su diccionario aunque no los use (null): el HUD y el escenario los leen sin mirar si existen.
const PAPELES_SIEMPRE: Array = ["detector", "compuerta", "puerta"]

var m: Variant = null                        ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _puzle_nodo: Puzle3D = null              ## quien monta las piezas y las reglas desde el .txt
var _puzles: Array = []                      ## [{nombre, entrada, detector, compuerta, puerta, …}] una por sala
var _hud: Label = null
var _t_hud: float = 0.0
var _avisos: Array = []


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada (con la simulación de agua).
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	if Terreno3D.agua_sim == null:
		push_error("LabPuzlesAgua3D: la escena necesita agua_fisica = true (no hay AguaSim3D)")
		return
	_puzle_nodo = Puzle3D.new()
	_puzle_nodo.name = "Puzles"
	add_child(_puzle_nodo)
	_puzle_nodo.iniciar(m, NIVEL_MAPA)
	_avisos.append_array(_puzle_nodo.avisos)
	_comprobar_constantes()
	_montar_salas()
	_montar_hud()
	set_process(true)


## Que las constantes que el escenario usa sigan siendo las del .txt (si Pablo cambia `abrir_cauce(0.5,20)` o el caudal de Q3, que se sepa al arrancar).
func _comprobar_constantes() -> void:
	for r in _puzle_nodo.reglas():
		for a in ((r as Dictionary)["acciones"] as Array):
			var ac: Dictionary = a
			if String(ac["accion"]) == "abrir_cauce" and (ac["args"] as Array).size() == 2:
				if absf(float((ac["args"] as Array)[0]) - CAUDAL_TINAJA_LAB) > 1.0e-6 or absf(float((ac["args"] as Array)[1]) - VOL_TINAJA_LAB) > 1.0e-6:
					_avisos.append("constantes: «%s» vierte %s y el lab dice %.2f u³/s y %.0f u³" % [(r as Dictionary)["nombre"], str(ac["args"]), CAUDAL_TINAJA_LAB, VOL_TINAJA_LAB])
	var arroyo: Puzle3D.Pieza = _puzle_nodo.pieza("q3_arroyo")
	if arroyo != null and absf(float(arroyo.p.get("caudal", 0.0)) - CAUDAL_ARROYO_Q3) > 1.0e-6:
		_avisos.append("constantes: q3_arroyo echa %.2f u³/s y el lab dice %.2f" % [float(arroyo.p.get("caudal", 0.0)), CAUDAL_ARROYO_Q3])


## Cada sala como diccionario de piezas (los ids de SALAS buscados en el .txt) y su cartel. Un id que no está en el mapa deja el papel en null
## y sale como aviso: así se ve al arrancar y no a media prueba.
func _montar_salas() -> void:
	for s in SALAS:
		var sala: Dictionary = s
		var q: Dictionary = {"nombre": sala["nombre"], "entrada": sala["entrada"]}
		for papel in PAPELES_SIEMPRE:
			q[papel] = null
		var ids: Dictionary = sala["ids"]
		for papel in ids:
			var nd: Node = _puzle_nodo.nodo(String(ids[papel]))
			if nd == null:
				_avisos.append("%s: no hay pieza «%s» (papel «%s») en %s.txt" % [sala["nombre"], ids[papel], papel, NIVEL_MAPA])
				push_warning("LabPuzlesAgua3D: " + String(_avisos.back()))
			q[papel] = nd
		_puzles.append(q)
		_cartel(sala["cartel"] as Vector2i, String(sala["texto"]))


## Un cartel flotante en la casilla `c` con las instrucciones de la sala (16/10, Pablo: «no entiendo el puzle»).
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


static func _runa(etiquetas: Array) -> RuneData:
	return Puzle3D.runa(etiquetas)


func pulsador_en(c: Vector2i) -> Pulsador3D:
	if _puzle_nodo == null:
		return null
	var pz: Puzle3D.Pieza = _puzle_nodo.pieza_en(c, "pulsador")
	return pz.nodo as Pulsador3D if pz != null else null


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t_hud += delta
	if _t_hud >= T_HUD:
		_t_hud = 0.0
		_refrescar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	# El orden de _puzles es Q1…Q6, Q7, Q8, Q9, Q10; la tecla 0 es Q10.
	var teclas: Dictionary = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9}
	if teclas.has(k.keycode):
		var n: int = int(teclas[k.keycode])
		if n < _puzles.size():
			colocar_jugador(_puzles[n]["entrada"] as Vector2i)


## Teletransporte del jugador a una casilla (lo mismo que escenario_base.colocar_jugador).
func colocar_jugador(c: Vector2i) -> void:
	if _jug == null:
		return
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if _jug.pj != null:
		_jug.pj.position = p
	_jug.position = p


func puzle(nombre: String) -> Dictionary:
	for q in _puzles:
		if String(q["nombre"]).split(" ")[0] == nombre:        # «Q1», no «Q1 cuenca»; y «Q1» no es «Q10»
			return q
	return {}


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
	if _hud == null or Terreno3D.agua_sim == null:
		return
	var t: String = "LAB PUZLES DE AGUA · 1–9, 0 ir a la sala · R recargar · agua total %.1f u³\n" % Terreno3D.agua_sim.volumen_total()
	for q in _puzles:
		var linea: String = "  %-16s" % String(q["nombre"])
		var det: NivelAgua3D = q["detector"]
		if det != null:
			linea += " nivel %.2f %s %.2f%s" % [det.profundidad, "≤" if det.invertido else ("≈" if det.banda > 0.0 else "≥"), det.objetivo,
				(" ±%.2f" % det.banda) if det.banda > 0.0 else ""]
		var k: Compuerta3D = q["compuerta"]
		if k != null:
			linea += "  compuerta %s" % ("ABIERTA" if k.abierta else "cerrada")
		if q.has("molino"):
			var mo: Molino3D = q["molino"]
			linea += "  corriente %.2f u/s  rueda %s" % [mo.corriente(), "GIRA" if mo.activo else "quieta"]
		if q.has("barril"):
			var ba: Barril3D = q["barril"]
			linea += "  barril %s" % ("EXPLOTADO" if ba.explotado else ("encendido" if ba.encendido else "entero"))
		if q.has("emisor"):
			var em: EmisorRayo3D = q["emisor"]
			linea += "  electrificadas %d" % em.electrificada.size()
		if q.has("nexo"):
			var nx: NexoRayo3D = q["nexo"]
			linea += "  nexo %s" % (("MOJADO %.0f s" % nx.mojado) if nx.conduce else "seco")
		var p: Puzle3D.PuertaPuzle = q["puerta"]
		if p != null:
			linea += "  puerta %s" % ("ABIERTA" if p.abierta else "cerrada")
		t += linea + "\n"
	for a in _avisos:
		t += "  AVISO " + String(a) + "\n"
	_hud.text = t
