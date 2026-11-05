class_name LabPuzlesFuego3D
extends Node

## LABORATORIO DE PUZLES DE FUEGO (Fase 14.6, 16/10, Juego). Sobre `laboratorios/LabPuzlesFuego3D.tscn`; mismo armazón que el de agua
## (LabPuzlesAgua3D): salas de 7 × 7, un cartel por sala, BOTÓN `!` y PLACA `@` como vías alternativas a la «natural» (el hechizo),
## HUD con el estado de cada puzle y las teclas 1–5 para ir a cada sala.
## Mapa: mundo/datos_nivel/mapas/PuzlesFuego.txt. Las piezas y los puzles NO se montan aquí: salen de las líneas `; pieza` y `; puzle` del
## .txt, que lee `Puzle3D` (escenas/puzle.gd; gramática en su cabecera). Este nodo conserva lo que es del laboratorio y no del nivel: el HUD, las
## teclas, los carteles, `puzle(nombre)` (la sala como diccionario de piezas, para las pruebas), `pulsador_en(celda)` y la MECHA de F4.
##
## LAS SALAS (columna, fila de salas; casillas x 1–7 / 9–15 / 17–23 / 25–31, y 1–7 / 9–15):
##   F1 (1,0) CUATRO ANTORCHAS: 4 braseros en las esquinas y un contador (ContadorReactivos3D). Con 4/4 encendidos se abre la puerta Z (12,1); si uno
##            se apaga, se cierra. Vías: fuego a cada brasero · `!` y `@` los encienden por código.
##   F2 (0,1) RELÉ DE BRASEROS: fila de 4 (1,3,5,7 en y=11). Cada uno enciende al siguiente a los 1,5 s y se apaga a los 6 s. Encendido el primero:
##            A 0–6, B 1,5–7,5, C 3–9, D 4,5–10,5. La puerta (7,9) solo está abierta cuando A y D arden A LA VEZ: de 4,5 a 6 s tras encender A.
##            Vías: fuego a A (y correr a la puerta) · `!` y `@` encienden A.
##   F3 (2,0) QUEMA LA CUERDA: arroyo de canal (18,1–7) con una compuerta LEVANTADA en (18,2) que lo deja correr; la cuerda (19,2) la sostiene. Quemarla
##            (fuego) hace caer la compuerta: corta el agua, el vado (18,4) baja de 0,25 y se abre la puerta (22,4). `!` y `@` queman la cuerda.
##   F4 (3,0) CONTRAFUEGO: mecha T (25,4) + 4 setos secos (26–29,4) + barril (30,4). A los T_MECHA_F4 s de entrar en la sala la MECHA (esto lo hace el
##            lab: el .txt no tiene temporizadores) enciende el brasero y prende el primer seto; el fuego corre por los setos, enciende el barril, explota
##            y abre la puerta (31,1). CORTAFUEGOS: agua al seto del medio (28,4) antes de que llegue: queda mojado (no prende), el fuego se queda en
##            (26,4)-(27,4) y el barril sigue entero; luego se enciende a mano (fuego, `!` o `@`).
##   F5 (0,0) DERRITE EL BLOQUE: cuenca A llena (2–3,2–3), compuerta de HIELO (4,3), cuenca B (5–6,2–3) y una antorcha (6,5). El fuego derrite el hielo,
##            el agua llega a B y a 0,2 el charco APAGA la antorcha. La puerta (1,6) se abre con la antorcha encendida Y el hielo derretido: el orden
##            importa. `!` derrite el hielo, `@` enciende la antorcha.
## Teclas: 1–5 llevan al jugador a la entrada de esa sala (F1, F2, F3, F4, F5) · R recarga la escena · (las de la maqueta siguen valiendo).
## F6–F10 (caldera, fogata con combustible, luz en cueva, viento y escudo) son de la segunda tanda: las salas (2,1) (3,1) (0,2)–(3,2) están libres.

const NIVEL_MAPA: String = "PuzlesFuego"
const T_MECHA_F4: float = 5.0                 ## s desde que el jugador pisa la sala de F4 hasta que se enciende la mecha (FASE14_PRESENTACION.md §6)
const SALA_F4: Rect2i = Rect2i(25, 1, 7, 7)   ## casillas de la sala de F4 (x, y, ancho, alto)
const CAUDAL_ARROYO_F3: float = 1.5           ## u³/s del arroyo de F3 (mismo valor que el de Q3 de PuzlesAgua: con menos el vado no pasa de 0,25)
const T_HUD: float = 0.2

## Las cinco salas, en el orden de las teclas 1–5. `entrada`: casilla a la que lleva la tecla; `cartel`: dónde se cuelga el texto; `ids`: papel →
## id de la pieza en PuzlesFuego.txt (los papeles que no aparecen valen null en el diccionario de la sala).
const SALAS: Array = [
	{"nombre": "F1 antorchas", "entrada": Vector2i(12, 8), "cartel": Vector2i(12, 7),
		"texto": "F1 · ENCIENDE LAS CUATRO ANTORCHAS\nFuego a cada brasero (o botón/placa: las encienden).\nCon las cuatro encendidas se abre la puerta; si una se apaga, se cierra.",
		"ids": {"b1": "f1_b1", "b2": "f1_b2", "b3": "f1_b3", "b4": "f1_b4", "contador": "f1_cont", "puerta": "f1_puerta"}},
	{"nombre": "F2 relé", "entrada": Vector2i(8, 12), "cartel": Vector2i(7, 12),
		"texto": "F2 · RELÉ DE BRASEROS\nEnciende el primero (o botón/placa) y corre a la puerta:\nla llama pasa de uno a otro (1,5 s) y se apaga a los 6 s.\nLa puerta solo abre si el primero y el último arden A LA VEZ.",
		"ids": {"a": "f2_a", "b": "f2_b", "c": "f2_c", "d": "f2_d", "contador": "f2_cont", "puerta": "f2_puerta"}},
	{"nombre": "F3 cuerda", "entrada": Vector2i(20, 8), "cartel": Vector2i(20, 7),
		"texto": "F3 · QUEMA LA CUERDA\nFuego a la cuerda (o botón/placa): la compuerta levantada cae,\ncorta el arroyo y el vado se seca: se abre la puerta.",
		"ids": {"detector": "f3_nivel", "compuerta": "f3_compuerta", "cuerda": "f3_cuerda", "puerta": "f3_puerta"}},
	{"nombre": "F4 contrafuego", "entrada": Vector2i(28, 8), "cartel": Vector2i(28, 7),
		"texto": "F4 · CONTRAFUEGO\nA los 5 s de entrar se enciende la mecha y el fuego corre por los setos hasta el barril.\nDeja que explote (abre la puerta) o moja el seto del medio\ny enciende el barril cuando tú quieras (fuego, botón o placa).",
		"ids": {"mecha": "f4_mecha", "s1": "f4_s1", "s2": "f4_s2", "s3": "f4_s3", "s4": "f4_s4", "barril": "f4_barril", "puerta": "f4_puerta"}},
	{"nombre": "F5 hielo", "entrada": Vector2i(4, 8), "cartel": Vector2i(4, 7),
		"texto": "F5 · DERRITE EL BLOQUE\nEl fuego derrite el hielo y el agua APAGA la antorcha de abajo.\nLa puerta abre con la antorcha encendida y el hielo derretido: el orden importa.\nBotón: derrite · placa: enciende la antorcha.",
		"ids": {"detector": "f5_charco", "compuerta": "f5_hielo", "antorcha": "f5_antorcha", "contador": "f5_cont", "puerta": "f5_puerta"}},
]
## TRAMPAS DE PARED (5/11/2026, docs/TRAMPAS_PARED_2026-11-05.md): tres salas más, aparte de las cinco de arriba para no tocar `_puzles` (que cuentan las pruebas). Teclas 6–8.
##   F7 (3,1) DRAGONES CRONOMETRADOS: dos cabezas en el muro norte (26,8) y (30,8) que escupen por las columnas x=26 y x=30 por turnos (1,5 s de fuego + 2,0 s de descanso, la segunda desfasada 1,75 s); placa (31,12) al fondo.
##   F8 (0,2) FLECHAS QUE SE ESQUIVAN O SE BLOQUEAN: un mascarón (8,20) dispara una flecha normal cada 1,5 s por la fila y=20; un bloque de piedra empujable (5,21) la tapa.
##   F9 (1,2) LA FLECHA DE FUEGO QUE ENCIENDE: un mascarón en el muro norte (14,16), de frente a la cámara, lanza una flecha de fuego cada 3 s por la columna x=14: prende dos setos y enciende el barril del fondo.
const TRAMPAS: Array = [
	{"nombre": "F7 dragones", "entrada": Vector2i(25, 12), "cartel": Vector2i(28, 10),
		"texto": "F7 · DRAGONES CRONOMETRADOS\nUn chorro por columna (x=26 y x=30): 1,5 s de fuego, 2 s de descanso,\navisan con brasas y humo 0,5 s antes. Nunca arden los dos a la vez.\nLlega a la placa del fondo. Botón: los apaga 8 s · agua a la cabeza: la apaga 8 s.",
		"ids": {"a": "t_drg_a", "b": "t_drg_b", "placa": "t_drg_placa", "boton": "t_drg_boton"}},
	{"nombre": "F8 flechas", "entrada": Vector2i(4, 17), "cartel": Vector2i(4, 18),
		"texto": "F8 · FLECHAS\nEl mascarón dispara una flecha cada 1,5 s por la fila de la placa.\nEsquívala o empuja el bloque al norte (5,20) para taparte.",
		"ids": {"a": "t_fl_a", "bloque": "t_fl_bloque", "placa": "t_fl_placa"}},
	{"nombre": "F9 flecha de fuego", "entrada": Vector2i(12, 17), "cartel": Vector2i(12, 19),
		"texto": "F9 · LA FLECHA DE FUEGO ENCIENDE\nCada 3 s el mascarón abre la boca y lanza una flecha de fuego hacia el sur:\nprende los setos y enciende el barril. Agua a un seto = cortafuegos · botón: lo apaga.",
		"ids": {"a": "t_fl_fuego", "s1": "t_fl_s1", "s2": "t_fl_s2", "barril": "t_fl_barril", "boton": "t_fl_boton"}},
]
## Papeles que toda sala tiene en su diccionario aunque no los use (null): el HUD y el escenario los leen sin mirar si existen.
const PAPELES_SIEMPRE: Array = ["detector", "compuerta", "puerta", "contador"]

var m: Variant = null                        ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _puzle_nodo: Puzle3D = null              ## quien monta las piezas y las reglas desde el .txt
var _puzles: Array = []                      ## [{nombre, entrada, detector, compuerta, puerta, …}] una por sala
var _trampas: Array = []                     ## [{nombre, entrada, a, b, placa, …}] las tres salas de trampas de pared (TRAMPAS)
var _hud: Label = null
var _t_hud: float = 0.0
var _avisos: Array = []
var _mecha_t: float = -1.0                   ## s desde que el jugador entró en la sala de F4 (-1 = aún no ha entrado)
var _mecha_encendida: bool = false


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
		push_error("LabPuzlesFuego3D: la escena necesita agua_fisica = true (F3 y F5 usan agua)")
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


## Que las constantes que el escenario usa sigan siendo las del .txt.
func _comprobar_constantes() -> void:
	var arroyo: Puzle3D.Pieza = _puzle_nodo.pieza("f3_arroyo")
	if arroyo != null and absf(float(arroyo.p.get("caudal", 0.0)) - CAUDAL_ARROYO_F3) > 1.0e-6:
		_avisos.append("constantes: f3_arroyo echa %.2f u³/s y el lab dice %.2f" % [float(arroyo.p.get("caudal", 0.0)), CAUDAL_ARROYO_F3])


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
				push_warning("LabPuzlesFuego3D: " + String(_avisos.back()))
			q[papel] = nd
		_puzles.append(q)
		_cartel(sala["cartel"] as Vector2i, String(sala["texto"]))
	for s in TRAMPAS:
		var sala_t: Dictionary = s
		var qt: Dictionary = {"nombre": sala_t["nombre"], "entrada": sala_t["entrada"]}
		var ids_t: Dictionary = sala_t["ids"]
		for papel in ids_t:
			var nd_t: Node = _puzle_nodo.nodo(String(ids_t[papel]))
			if nd_t == null:
				_avisos.append("%s: no hay pieza «%s» (papel «%s») en %s.txt" % [sala_t["nombre"], ids_t[papel], papel, NIVEL_MAPA])
				push_warning("LabPuzlesFuego3D: " + String(_avisos.back()))
			qt[papel] = nd_t
		_trampas.append(qt)
		_cartel(sala_t["cartel"] as Vector2i, String(sala_t["texto"]))


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
	_mecha(delta)
	_t_hud += delta
	if _t_hud >= T_HUD:
		_t_hud = 0.0
		_refrescar_hud()


## La mecha de F4: cuando el jugador pisa la sala empieza la cuenta; a los T_MECHA_F4 s se enciende el brasero y prende el primer seto. Una sola vez
## por carga (R recarga la escena y la vuelve a armar). Si el jugador sale de la sala la cuenta sigue: la mecha es del nivel, no de él.
func _mecha(delta: float) -> void:
	if _mecha_encendida or _jug == null or _puzles.size() < 4:
		return
	if _mecha_t < 0.0:
		if SALA_F4.has_point(Terreno3D.celda_de(_jug.global_position)):
			_mecha_t = 0.0
		return
	_mecha_t += delta
	if _mecha_t < T_MECHA_F4:
		return
	_mecha_encendida = true
	encender_mecha()


## Enciende la mecha de F4 (también la llama el escenario para no esperar). Brasero encendido + primer seto prendido.
func encender_mecha() -> void:
	var q: Dictionary = puzle("F4")
	if q.is_empty():
		return
	_mecha_encendida = true
	var br: Variant = q.get("mecha")
	if br != null and is_instance_valid(br):
		(br as Reactivo3D).encender_llama()
	var s1: Variant = q.get("s1")
	if s1 != null and is_instance_valid(s1):
		(s1 as Reactivo3D).ignite()


func mecha_encendida() -> bool:
	return _mecha_encendida


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	var teclas: Dictionary = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4}
	if teclas.has(k.keycode):
		var n: int = int(teclas[k.keycode])
		if n < _puzles.size():
			colocar_jugador(_puzles[n]["entrada"] as Vector2i)
	var teclas_t: Dictionary = {KEY_6: 0, KEY_7: 1, KEY_8: 2}          # trampas de pared: F7, F8, F9
	if teclas_t.has(k.keycode):
		var nt: int = int(teclas_t[k.keycode])
		if nt < _trampas.size():
			colocar_jugador(_trampas[nt]["entrada"] as Vector2i)


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
		if String(q["nombre"]).split(" ")[0] == nombre:        # «F1», no «F1 antorchas»
			return q
	return {}


## Una sala de trampas de pared por su nombre corto («F7», «F8», «F9»); {} si no existe.
func trampas(nombre: String) -> Dictionary:
	for q in _trampas:
		if String(q["nombre"]).split(" ")[0] == nombre:
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


## El estado de una trampa de pared para el HUD: «APAGADA», y por fase para el dragón («reposo», «AVISO», «ESCUPE») o «espera»/«AVISO» para las flechas.
func _estado_trampa(tr: Variant) -> String:
	if not bool((tr as Object).get("activa")):
		return "APAGADA"
	if tr is TrampaDragon3D:
		return ["reposo", "AVISO", "ESCUPE", "apagada"][int((tr as TrampaDragon3D).fase)]
	return "AVISO" if bool((tr as Object).get("en_aviso")) else "espera"


func _llama(r: Variant) -> String:
	return "ARDE" if (r != null and is_instance_valid(r) and bool((r as Object).get("is_lit"))) else "apagado"


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var t: String = "LAB PUZLES DE FUEGO · 1–5 ir a la sala · R recargar\n"
	for q in _puzles:
		var linea: String = "  %-16s" % String(q["nombre"])
		var ct: ContadorReactivos3D = q["contador"]
		if ct != null:
			linea += " encendidas %d/%d" % [ct.encendidos, ct.minimo]
		var det: NivelAgua3D = q["detector"]
		if det != null:
			linea += " nivel %.2f %s %.2f" % [det.profundidad, "≤" if det.invertido else "≥", det.objetivo]
		var k: Compuerta3D = q["compuerta"]
		if k != null:
			linea += "  compuerta %s" % ("ABIERTA" if k.abierta else "cerrada")
		if q.has("cuerda"):
			var cu: Cuerda3D = q["cuerda"]
			linea += "  cuerda %s" % ["entera", "ARDIENDO", "ROTA"][int(cu.estado)]
		if q.has("a"):
			linea += "  A %s B %s C %s D %s" % [_llama(q["a"]), _llama(q["b"]), _llama(q["c"]), _llama(q["d"])]
		if q.has("antorcha"):
			linea += "  antorcha %s" % _llama(q["antorcha"])
		if q.has("barril"):
			var ba: Barril3D = q["barril"]
			var mecha: String = "mecha ENCENDIDA" if _mecha_encendida else (("mecha en %.1f s" % maxf(0.0, T_MECHA_F4 - _mecha_t)) if _mecha_t >= 0.0 else "mecha: entra en la sala")
			linea += "  %s · barril %s" % [mecha, "EXPLOTADO" if ba.explotado else ("encendido" if ba.encendido else "entero")]
			var setos: String = ""
			for id in ["s1", "s2", "s3", "s4"]:
				var s: Variant = q[id]
				setos += "%s " % ("·" if s == null or not is_instance_valid(s) else ("ARDE" if bool(s.get("is_lit")) else ("mojado" if bool(s.call("esta_mojado")) else "seco")))
			linea += " · setos " + setos
		var p: Puzle3D.PuertaPuzle = q["puerta"]
		if p != null:
			linea += "  puerta %s" % ("ABIERTA" if p.abierta else "cerrada")
		t += linea + "\n"
	t += "TRAMPAS DE PARED · 6–8 ir a la sala\n"
	for q in _trampas:
		var lt: String = "  %-18s" % String(q["nombre"])
		for papel in ["a", "b"]:
			var tr: Variant = q.get(papel)
			if tr != null and is_instance_valid(tr):
				lt += "  %s %s" % [papel.to_upper(), _estado_trampa(tr)]
		var pl: Variant = q.get("placa")
		if pl != null and is_instance_valid(pl):
			lt += "  placa %s" % ("PISADA" if bool((pl as Object).get("activo")) else "libre")
		if q.has("barril") and q["barril"] != null and is_instance_valid(q["barril"]):
			var bt: Barril3D = q["barril"]
			lt += "  barril %s" % ("EXPLOTADO" if bt.explotado else ("encendido" if bt.encendido else "entero"))
		t += lt + "\n"
	for a in _avisos:
		t += "  AVISO " + String(a) + "\n"
	_hud.text = t
