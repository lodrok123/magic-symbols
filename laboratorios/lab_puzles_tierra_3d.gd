class_name LabPuzlesTierra3D
extends Node

## LABORATORIO DE PUZLES DE TIERRA (21/11/2026, Juego). Sobre `laboratorios/LabPuzlesTierra3D.tscn`; mismo armazón que los de agua y fuego (LabPuzlesAgua3D, LabPuzlesFuego3D): salas de 7 × 7, un cartel por sala,
## BOTÓN `!` y PLACA `@` como vías alternativas a la «natural» (el hechizo), HUD con el estado de cada puzle y las teclas 1–7 para ir a cada sala. Kit de hechizos: `demo` (fuego, agua y tierra; flecha, línea, barrera,
## altura, ᚱ pulso y ᛒ suelo), el que tendrá la jugadora en la demo.
## Mapa: mundo/datos_nivel/mapas/PuzlesTierra.txt (33 × 19: siete salas de 7 × 7 en dos filas y un PASILLO en medio, y = 9, por el que se va de una a otra). Las piezas y los puzles NO se montan aquí: salen de las
## líneas `; pieza` y `; puzle` del .txt, que lee `Puzle3D` (escenas/puzle.gd; gramática en su cabecera). Este nodo conserva lo que es del laboratorio y no del nivel: el HUD, las teclas, los carteles,
## `puzle(nombre)` (la sala como diccionario de piezas, para las pruebas), `pulsador_en(celda)` y las losas de la vía `!`/`@` de T4.
## El aspecto es el del bosque (la escena lleva un solo `estilo` para todo el mapa): el bioma de cada sala (bosque, pantano, cueva) es el del cartel, no el de las paredes.
##
## LAS SALAS (columna, fila de salas; casillas x 1–7 / 9–15 / 17–23 / 25–31, y 1–7 / 11–17):
##   T1 (0,0) PLACA A DISTANCIA (bosque): una placa de peso 1 en una isla de roca rodeada de vacío, fuera de alcance andando. Un bloque de tierra puesto encima la pisa y abre la puerta (4,3); se cierra si el bloque caduca (7 s).
##   T2 (1,0) DOS PLACAS, UNA ROCA Y LA TIERRA (bosque): dos placas de peso 1; la roca pequeña se empuja sobre una y un bloque de tierra pisa la otra. La puerta abre solo con las dos a la vez.
##   T3 (2,0) DESVÍA EL ARROYO (pantano): un arroyo corre hacia un sumidero; un bloque de tierra hace de PRESA y el agua remonta por un brazo hasta el vaso, cuyo nivel abre la puerta.
##   T4 (3,0) PUENTE DE SUELO (cueva): un foso de vacío de dos casillas entre la entrada y el cofre; ᛒ suelo + tierra planta una losa por casilla (8 s). Vías `!` y `@`: plantan las dos losas (12 s).
##   T5 (0,1) ESCUDO CONTRA FLECHAS (cueva): un pasillo barrido por un mascarón; un bloque de tierra delante de la boca tapa las flechas y deja llegar a la placa del fondo (aparece el cofre).
##   T6 (1,1) BLOQUE DE ENLACE (cueva): cristal → veta con un HUECO → receptor de tierra. Un bloque de tierra sobre el hueco cierra el circuito; el pulso de un hechizo de tierra al cristal abre la puerta.
##   T7 (2,1) SELLA LA MÁMOA (pantano): una mámoa de la que vuelve un mouro al morir; tapada con tierra, el mouro muere de verdad y aparece el cofre.
## Teclas: 1–7 llevan al jugador a la entrada de esa sala · R recarga la escena · (las de la maqueta siguen valiendo).

const NIVEL_MAPA: String = "PuzlesTierra"
const T_HUD: float = 0.2
const DURA_LOSA_VIA: float = 12.0              ## s que dura cada losa que planta la vía `!`/`@` de T4 (la del hechizo dura lo que dura ᛒ: 8 s)

## Las siete salas, en el orden de las teclas 1–7. `entrada`: casilla a la que lleva la tecla; `cartel`: dónde se cuelga el texto; `ids`: papel → id de la pieza en PuzlesTierra.txt.
const SALAS: Array = [
	{"nombre": "T1 placa a distancia", "entrada": Vector2i(4, 7), "cartel": Vector2i(4, 6),
		"texto": "T1 · PLACA A DISTANCIA (bosque)\nLa placa de peso de la isla (derecha) no se alcanza andando: pon un BLOQUE DE TIERRA encima desde aquí.\nLa puerta abre mientras el bloque aguanta (7 s): pasa antes de que caduque.\nBotón/placa de este lado: abren la puerta.",
		"ids": {"peso": "t1_peso", "puerta": "t1_puerta", "cofre": "t1_cofre", "boton": "t1_boton", "placa": "t1_placa"}},
	{"nombre": "T2 dos placas", "entrada": Vector2i(12, 7), "cartel": Vector2i(12, 6),
		"texto": "T2 · DOS PLACAS, UNA ROCA Y LA TIERRA (bosque)\nEmpuja la roca sobre una placa y pisa la otra con un bloque de tierra.\nLa puerta solo abre con las dos a la vez; el bloque caduca a los 7 s: ponlo el último.\nBotón/placa de abajo: abren la puerta.",
		"ids": {"pa": "t2_pa", "pb": "t2_pb", "roca": "t2_roca", "puerta": "t2_puerta", "cofre": "t2_cofre", "boton": "t2_boton", "placa": "t2_placa"}},
	{"nombre": "T3 arroyo", "entrada": Vector2i(20, 7), "cartel": Vector2i(20, 6),
		"texto": "T3 · DESVÍA EL ARROYO (pantano)\nEl arroyo corre al sumidero. Un bloque de tierra en su cauce hace de PRESA: el agua remonta por el brazo hasta el vaso.\nCon el vaso lleno se abre la puerta (una vez: la puerta se queda).\nBotón/placa: abren la puerta.",
		"ids": {}},
	{"nombre": "T4 puente", "entrada": Vector2i(28, 7), "cartel": Vector2i(28, 6),
		"texto": "T4 · PUENTE DE SUELO (cueva)\nEl foso no se pisa. ᛒ suelo + tierra planta una losa en la casilla que apuntas (8 s): dos losas y cruzas hasta el cofre.\nBotón/placa: plantan las dos losas (12 s).",
		"ids": {"cofre": "t4_cofre", "boton": "t4_boton", "placa": "t4_placa"}},
	{"nombre": "T5 escudo", "entrada": Vector2i(4, 11), "cartel": Vector2i(4, 12),
		"texto": "T5 · ESCUDO CONTRA FLECHAS (cueva)\nEl mascarón del fondo dispara por el pasillo. Tierra + barrera delante de su boca (casilla (4,17), desde (4,14)) tapa las flechas.\nLlega a la placa del fondo (a la derecha) y aparece el cofre.\nBotón: apaga el mascarón 8 s · placa: hace aparecer el cofre.",
		"ids": {}},
	{"nombre": "T6 enlace", "entrada": Vector2i(12, 11), "cartel": Vector2i(12, 13),
		"texto": "T6 · BLOQUE DE ENLACE (cueva)\nLa veta tiene un hueco: sin nada encima no conduce. Un bloque de tierra sobre el hueco cierra el circuito.\nLuego un hechizo de tierra al cristal (izquierda) manda el pulso al receptor y la puerta se abre.\nBotón: activa el receptor · placa: abre la puerta.",
		"ids": {}},
	{"nombre": "T7 mámoa", "entrada": Vector2i(20, 11), "cartel": Vector2i(20, 12),
		"texto": "T7 · SELLA LA MÁMOA (pantano)\nEl mouro vuelve de la mámoa cada vez que lo vences. Tapa la mámoa con tierra (o una roca) y véncelo: muere de verdad y aparece el cofre.\nBotón: tapa la mámoa · placa: hace aparecer el cofre.",
		"ids": {}},
]
## Papeles de cada sala que se buscan en el .txt (se completan abajo: las salas de arriba solo traen los que ya estaban decididos al escribir los carteles).
const IDS_POR_SALA: Dictionary = {
	"T3": {"nivel": "t3_nivel", "puerta": "t3_puerta", "cofre": "t3_cofre", "boton": "t3_boton", "placa": "t3_placa"},
	"T5": {"trampa": "t5_trampa", "fondo": "t5_fondo", "cofre": "t5_cofre", "boton": "t5_boton", "placa": "t5_placa"},
	"T6": {"cristal": "t6_cristal", "veta": "t6_veta", "receptor": "t6_receptor", "puerta": "t6_puerta", "cofre": "t6_cofre", "boton": "t6_boton", "placa": "t6_placa"},
	"T7": {"mamoa": "t7_mamoa", "roca": "t7_roca", "mouro": "t7_mouro", "vigia": "t7_vigia", "cofre": "t7_cofre", "boton": "t7_boton", "placa": "t7_placa"},
}
## Las dos casillas del foso de T4 (de la entrada al cofre): las que planta la vía `!`/`@`.
const LOSAS_T4: Array = [Vector2i(28, 5), Vector2i(28, 4)]

var m: Variant = null                        ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _jug: Jugador3D = null
var _puzle_nodo: Puzle3D = null              ## quien monta las piezas y las reglas desde el .txt
var _salas: Array = []                       ## [{nombre, entrada, <papel>: nodo…}] una por sala
var _hud: Label = null
var _t_hud: float = 0.0
var _avisos: Array = []
var _losas_via_puestas: int = 0              ## cuántas veces ha plantado T4 sus losas por la vía `!`/`@` (las pruebas)


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
		push_error("LabPuzlesTierra3D: la escena necesita agua_fisica = true (T3 usa agua)")
		return
	_puzle_nodo = Puzle3D.new()
	_puzle_nodo.name = "Puzles"
	add_child(_puzle_nodo)
	_puzle_nodo.iniciar(m, NIVEL_MAPA)
	_avisos.append_array(_puzle_nodo.avisos)
	_montar_salas()
	_conectar_via_t4()
	_montar_hud()
	set_process(true)


## Cada sala como diccionario de piezas (los ids buscados en el .txt) y su cartel. Un id que no está en el mapa deja el papel en null y sale como aviso: así se ve al arrancar y no a media prueba.
func _montar_salas() -> void:
	for s in SALAS:
		var sala: Dictionary = s
		var q: Dictionary = {"nombre": sala["nombre"], "entrada": sala["entrada"]}
		var corto: String = String(sala["nombre"]).split(" ")[0]
		var ids: Dictionary = (sala["ids"] as Dictionary).duplicate()
		ids.merge(IDS_POR_SALA.get(corto, {}) as Dictionary)
		for papel in ids:
			var nd: Node = _puzle_nodo.nodo(String(ids[papel]))
			if nd == null:
				_avisos.append("%s: no hay pieza «%s» (papel «%s») en %s.txt" % [sala["nombre"], ids[papel], papel, NIVEL_MAPA])
				push_warning("LabPuzlesTierra3D: " + String(_avisos.back()))
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


func pulsador_en(c: Vector2i) -> Pulsador3D:
	if _puzle_nodo == null:
		return null
	var pz: Puzle3D.Pieza = _puzle_nodo.pieza_en(c, "pulsador")
	return pz.nodo as Pulsador3D if pz != null else null


## La sala por su nombre corto («T1»…«T7»); {} si no existe.
func sala(nombre: String) -> Dictionary:
	for q in _salas:
		if String(q["nombre"]).split(" ")[0] == nombre:
			return q
	return {}


# ---------------------------------------------------------------------------------------------------------------------
#  La vía `!`/`@` de T4: el .txt no tiene una acción «plantar losa», así que la hace el lab (como la mecha de F4 en el lab de fuego)
# ---------------------------------------------------------------------------------------------------------------------

func _conectar_via_t4() -> void:
	var q: Dictionary = sala("T4")
	for papel in ["boton", "placa"]:
		var p: Variant = q.get(papel)
		if p != null and is_instance_valid(p):
			(p as Pulsador3D).pulsado.connect(_al_pulsar_t4)


func _al_pulsar_t4(_quien: Variant = null) -> void:
	plantar_losas_t4()


## Planta las dos losas de T4 (la misma losa de tierra que ᛒ suelo, `Lanzador3D.levantar_plataforma_tierra`) durante DURA_LOSA_VIA s. Si ya están puestas (las del hechizo o las de una pulsación anterior) no repite.
func plantar_losas_t4() -> void:
	var lanz: Lanzador3D = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	if lanz == null:
		return
	var nuevas: Array[Vector2i] = []
	for c in LOSAS_T4:
		if not Terreno3D.plataformas_tierra.has(c as Vector2i):
			nuevas.append(c as Vector2i)
	for c in nuevas:
		var una: Array[Vector2i] = [c]
		lanz.levantar_plataforma_tierra(una, DURA_LOSA_VIA, Terreno3D.alto_suelo)
	if not nuevas.is_empty():
		_losas_via_puestas += 1


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
	var teclas: Dictionary = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6}
	if teclas.has(k.keycode):
		var n: int = int(teclas[k.keycode])
		if n < _salas.size():
			colocar_jugador(_salas[n]["entrada"] as Vector2i)


## Teletransporte del jugador a una casilla (lo mismo que escenario_base.colocar_jugador).
func colocar_jugador(c: Vector2i) -> void:
	if _jug == null:
		return
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if _jug.pj != null:
		_jug.pj.position = p
	_jug.position = p


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


func _vivo(nd: Variant) -> bool:
	return nd != null and is_instance_valid(nd)


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var t: String = "LAB PUZLES DE TIERRA · 1–7 ir a la sala · R recargar · bloques de tierra vivos %d\n" % _bloques_vivos()
	for q in _salas:
		t += "  %-22s%s\n" % [String(q["nombre"]), _estado(q)]
	for a in _avisos:
		t += "  AVISO " + String(a) + "\n"
	_hud.text = t


func _bloques_vivos() -> int:
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	return (lanz.get("_bloques") as Array).size() if lanz != null and lanz.get("_bloques") is Array else 0


## La línea de HUD de una sala: lo que lee cada papel que tenga.
func _estado(q: Dictionary) -> String:
	var s: String = ""
	for papel in ["peso", "pa", "pb", "fondo"]:
		var p: Variant = q.get(papel)
		if _vivo(p):
			s += "  %s %s" % [papel, "PISADA" if bool((p as Object).get("activo")) else "libre"]
	var roca: Variant = q.get("roca")
	if _vivo(roca):
		s += "  roca en %s" % str((roca as BloqueEmpujable3D).celda)
	var nv: Variant = q.get("nivel")
	if _vivo(nv):
		s += "  vaso %.2f/%.2f" % [(nv as NivelAgua3D).profundidad, (nv as NivelAgua3D).objetivo]
	var tr: Variant = q.get("trampa")
	if _vivo(tr):
		s += "  mascarón %s" % ("APAGADO" if not bool((tr as Object).get("activa")) else ("AVISO" if bool((tr as Object).get("en_aviso")) else "espera"))
	var rc: Variant = q.get("receptor")
	if _vivo(rc):
		s += "  receptor %s" % ("ACTIVO" if bool((rc as Object).get("activo")) else "libre")
	var ma: Variant = q.get("mamoa")
	if _vivo(ma):
		var mm: Mamoa3D = ma
		s += "  mámoa %s" % ("AGRIETADA" if mm.esta_agrietada else ("tapada" if not mm.abierta else "abierta"))
	var mo: Variant = q.get("mouro")
	if _vivo(mo):
		var me: MouroEspectro3D = mo
		s += "  mouro %s" % ("latente" if me.latente else ("vida %.0f" % me.health))
	var pu: Variant = q.get("puerta")
	if _vivo(pu):
		s += "  puerta %s" % ("ABIERTA" if bool((pu as Object).get("abierta")) else "cerrada")
	var cf: Variant = q.get("cofre")
	if _vivo(cf):
		s += "  cofre %s" % ("oculto" if bool((cf as Object).get("es_oculto")) else ("abierto" if bool((cf as Object).get("es_abierto")) else ("sellado" if not bool((cf as Object).call("sellado_cumplido")) else "listo (E)")))
	return s
