class_name Jugabilidad3D
extends Node

## TEST DE JUGABILIDAD EN 3D (6/10, Pipeline): las REGLAS y los DATOS del nivel de test_jugabilidad.gd sobre la maqueta
## de PruebaTest2 (prueba_test2.gd con `nivel = "jugabilidad"`; se juega con F6 sobre PruebaJugabilidad3D.tscn).
##
## El MAPA, el decorado, el botín, los guardados, el puesto, los empujables y los setos son los de test_jugabilidad.gd,
## copiados tal cual (misma letra en la misma casilla): si el 2D cambia, se vuelve a pegar este bloque y ya.
## Lo que cambia es el arte (piezas 3D en vez de sprites) y que la hierba, el agua y el suelo los pone la maqueta.
##
## Qué hace aquí y qué no:
##   - HACE las cuatro tareas (contacto, matar goblins, hablar, antorchas), la puerta final con sus 4 llamas, el botín
##     del suelo (pociones y oro a Estado), los guardados (mueven el punto de reaparición del Jugador3D) y el HUD.
##   - NO hace lo del Juego: el combate (Combate3D mueve y mata a los goblins y al arquero), el lanzador, la mochila
##     de verdad y las mejoras del alquimista. El arquero sale en las "A" con su modelo, pero hoy lo gobierna el mismo
##     Combate3D de los goblins de espada (cuerpo a cuerpo): su IA a distancia es cosa de Juego (ver DIARIO).
##   - Las losas de desbloqueo (a = agua, w = viento) se ven y se pisan, pero no dan runas: el repertorio es del Juego.
##
## La maqueta lo monta con tres llamadas: `colocar(mundo)` (dentro de _colocar_extras, antes de agrupar los lotes),
## `iniciar(mundo)` (al final de _ready, con el Jugador3D ya montado) y los registros `registrar_*` mientras coloca letras.

const MAPA: PackedStringArray = [
	"#######################",
	"#S....#...~~~~.p.~....#",
	"#.....#......~...~....#",
	"#.vv..#......~...~....#",
	"#.vv..ra.....~i..~....#",
	"#.vv..ra.....~~b~~....#",
	"#.....#......B........#",
	"#.....#......B........#",
	"#.....#......B....#####",
	"#.....#......B....#...#",
	"#.....#......B....#...#",
	"################..X..E#",
	"#gggg~~..m........#...#",
	"#gggg~~..w........#...#",
	"#gggT~~F.w...##########",
	"#gggT~~F.w...#........#",
	"#gggT~~F.w...#.......A#",
	"#gggT~~F.w............#",
	"#gggT~~F.w........W...#",
	"#gggg~~..w............#",
	"#gggg~~..w...........A#",
	"#gggg~~..w............#",
	"#######################",
]

## Decorado del bosque repartido por el mapa: [prop, columna, fila]. Generado con una
## semilla fija y comprobando que no corta ningún camino. Los props con cuerpo (caja,
## barril, peñasco, tocón, tronco, cartel) bloquean el paso; el resto es decorado.
const PROPS: Array = [
	["grass_clump", 8, 1],
	["bush_berry", 9, 1],
	["signpost", 2, 2],
	["lavender", 7, 2],
	["bush_berry", 8, 2],
	["flowers", 10, 2],
	["grass_clump", 18, 2],
	["boulder", 20, 2],
	["mushrooms", 10, 3],
	["bush_berry", 16, 3],
	["flowers", 20, 3],
	["rocks", 21, 3],
	["grass_clump", 9, 4],
	["boulder", 11, 4],
	["barrel", 19, 4],
	["bush", 9, 5],
	["fern", 10, 5],
	["groundcover", 18, 5],
	["flowers", 19, 5],
	["barrel", 21, 5],
	["log", 9, 6],
	["rocks", 21, 6],
	["rocks", 2, 7],
	["stump", 4, 7],
	["flowers", 11, 7],
	["barrel", 15, 7],
	["bush", 18, 7],
	["crate", 20, 7],
	["crate", 1, 8],
	["rocks", 5, 8],
	["mushrooms", 8, 8],
	["boulder", 11, 8],
	["mushrooms", 16, 8],
	["lavender", 17, 8],
	["bush", 2, 9],
	["bush_berry", 3, 9],
	["bush", 4, 9],
	["stump", 7, 9],
	["fern", 10, 9],
	["bush", 11, 9],
	["mushrooms", 15, 9],
	["boulder", 17, 9],
	["fern", 19, 9],
	["bush_berry", 20, 9],
	["stump", 2, 10],
	["mushrooms", 4, 10],
	["lavender", 5, 10],
	["mushrooms", 8, 10],
	["crate", 10, 10],
	["bush_berry", 15, 10],
	["fern", 16, 10],
	["groundcover", 16, 11],
	["flowers", 2, 12],
	["fern", 3, 12],
	["log", 12, 12],
	["groundcover", 15, 12],
	["fern", 13, 13],
	["log", 16, 13],
	["barrel", 20, 13],
	["rocks", 12, 15],
	["fern", 14, 15],
	["mushrooms", 16, 15],
	["rocks", 18, 15],
	["lavender", 11, 16],
	["grass_clump", 14, 16],
	["lavender", 11, 17],
	["flowers", 12, 17],
	["groundcover", 15, 17],
	["lavender", 13, 18],
	["lavender", 14, 18],
	["bush_berry", 15, 18],
	["flowers", 12, 19],
	["flowers", 13, 19],
	["grass_clump", 14, 19],
	["mushrooms", 1, 20],
	["stump", 7, 20],
	["groundcover", 11, 20],
	["barrel", 13, 20],
	["log", 15, 20],
	["mushrooms", 1, 21],
	["groundcover", 7, 21],
	["bush", 13, 21],
	["grass_clump", 14, 21],
	["crate", 17, 21],
]


## Botín del suelo: [objeto, columna, fila]. El oro sale de 5 en 5.
const RECOGIBLES: Array = [
	["pocion", 3, 8], ["pocion", 16, 17], ["pocion", 10, 19],
	["oro", 4, 1], ["oro", 8, 3], ["oro", 19, 3], ["oro", 21, 4],
	["oro", 12, 13], ["oro", 20, 16], ["oro", 11, 18], ["oro", 20, 20],
]


## Las baldosas de punto de guardado.
const GUARDADOS: Array = [Vector2i(3, 10), Vector2i(9, 3), Vector2i(14, 12), Vector2i(16, 19)]


## El puesto de la librera (el del alquimista va 3 casillas al sur).
const PUESTO_CELDA: Vector2i = Vector2i(2, 6)


## Bloques empujables: tierra avanza una casilla; hielo resbala hasta chocar.
const EMPUJABLES: Array = [["tierra", 15, 3], ["tierra", 12, 7], ["hielo", 16, 7]]


## Matorrales secos sueltos en zonas abiertas (arden).
const SETOS: Array = [Vector2i(9, 5), Vector2i(18, 5), Vector2i(13, 21), Vector2i(15, 10),
	Vector2i(19, 9), Vector2i(7, 21), Vector2i(10, 9), Vector2i(14, 16)]


## Id de la pieza 3D de cada prop del 2D: [pieza, bloquea]. Lo que no está aquí (mata de hierba, lavanda, flores, helecho,
## cubresuelos) lo pone Hierba3D, que ya cubre todo el suelo de hierba.
const PIEZA_DE: Dictionary = {
	"bush_berry": ["arbusto_flores", false], "bush": ["arbusto", false], "signpost": ["cartel", true],
	"boulder": ["roca_grande", true], "mushrooms": ["setas", false], "rocks": ["piedras", false],
	"barrel": ["barril", true], "log": ["tronco", true], "stump": ["tocon", true], "crate": ["caja", true],
}

const TAREAS: Array = ["Pisar la baldosa de contacto", "Matar a los goblins", "Hablar con un NPC", "Encender las antorchas"]
const COLOR_LOSA: Dictionary = {"p": Color(1.0, 0.85, 0.35), "a": Color(0.45, 0.72, 1.0), "w": Color(0.65, 1.0, 0.8)}
const NOMBRE_LOSA: Dictionary = {"p": "CONTACTO", "a": "AGUA", "w": "VIENTO"}
const DIALOGOS: Dictionary = {
	"guardabosques": ["El bosque está inquieto desde que se secaron los setos.", "Si el río te frena, el rayo tiende puentes.",
		"Las antorchas del oeste solo arden con fuego que cruce el agua."],
	"librera": ["Mis libros están a buen precio... cuando abra la tienda.", "Los glifos se ganan pisando las losas rúnicas."],
	"alquimista": ["Una poción y un buen mazo de runas lo arreglan casi todo.", "Vuelve con oro y mejoramos esa mochila."],
}
const ALCANCE_HABLAR: float = 2.7       ## unidades (la casilla mide 2,3)
const ALCANCE_BOTIN: float = 0.95
const COLOR_LAMPARA_OFF: Color = Color(0.42, 0.42, 0.48)
const COLOR_LAMPARA_ON: Color = Color(1.0, 0.62, 0.22)

var m: Variant = null                    ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _losas: Dictionary = {}              ## Vector2i -> letra (p, a, w)
var _npcs: Dictionary = {}               ## nombre -> Pj3D
var _botin: Array = []
var _lamparas: Array = []                ## 4 MeshInstance3D sobre la puerta
var _fuegos: Array = [null, null, null, null]
var _puerta: MeshInstance3D = null
var _puerta_c: Vector2i = Vector2i(-1, -1)
var _salida_c: Vector2i = Vector2i(-1, -1)
var _hecha: Array = [false, false, false, false]
var _abierta: bool = false
var _terminado: bool = false
var _n_goblins: int = 0
var _t: float = 0.0
var _t_aviso: float = 0.0
var _ultimo_guardado: Vector2i = Vector2i(-1, -1)
var _jug: Jugador3D = null
var _hud: Label = null
var _aviso: Label = null
var _lineas_dialogo: Dictionary = {}
var _hablando: Pj3D = null
var _t_habla: float = 0.0


## Los empujables en el formato de la maqueta: [tipo, casilla].
static func empujables() -> Array:
	var l: Array = []
	for e in EMPUJABLES:
		l.append([String(e[0]), Vector2i(int(e[1]), int(e[2]))])
	return l


func registrar_losa(letra: String, c: Vector2i) -> void:
	_losas[c] = letra


func registrar_npc(nombre: String, pj: Pj3D) -> void:
	if pj != null:
		_npcs[nombre] = pj


## Todo lo del decorado y los objetos, ANTES de que la maqueta agrupe los lotes.
func colocar(mundo: Variant) -> void:
	m = mundo
	var ocupadas: Dictionary = {}
	for dy in [0, 3]:
		var cp: Vector2i = PUESTO_CELDA + Vector2i(0, dy)
		ocupadas[cp] = true
		ocupadas[cp + Vector2i(1, 0)] = true
	# Los dos puestos con su tendero (la librera y, 3 casillas al sur, la alquimista).
	registrar_npc("librera", m.poner_puesto(PUESTO_CELDA, m.PJ_LIBRERA))
	registrar_npc("alquimista", m.poner_puesto(PUESTO_CELDA + Vector2i(0, 3), m.PJ_ALQUIMISTA))
	# Decorado.
	for p in PROPS:
		var c := Vector2i(int(p[1]), int(p[2]))
		if ocupadas.has(c) or m._bloqueadas.has(c) or not (m._letra(c) == "." or m._letra(c) == "v"):
			continue
		var d: Variant = PIEZA_DE.get(String(p[0]))
		if d == null:
			continue
		var id: String = String((d as Array)[0])
		var giro: float = m.GIRO_CARTEL if id == "cartel" else -1.0
		m._poner(id, c, m.ALTO, bool((d as Array)[1]), id != "cartel", giro)
	# Setos secos sueltos (arden).
	for s in SETOS:
		var cs: Vector2i = s
		if ocupadas.has(cs) or m._bloqueadas.has(cs):
			continue
		if m.objetos_reactivos:
			m._reactivo_pieza("seto", "seto_seco", cs, m.ALTO, true)
		else:
			m._poner("seto_seco", cs, m.ALTO, true)
	# Botín del suelo (nodos sueltos, para poder recogerlos).
	for r in RECOGIBLES:
		var cb := Vector2i(int(r[1]), int(r[2]))
		var tipo: String = String(r[0])
		var nodo: Node3D = null
		if tipo == "pocion":
			nodo = m._pieza(m._id_real("pocion"))
			if nodo != null:
				nodo.position = m._centro_celda(cb, m.ALTO + 0.05)
				m._props.add_child(nodo)
		else:
			nodo = m._oro(m._centro_celda(cb, m.ALTO))
		if nodo != null:
			_botin.append({"nodo": nodo, "c": cb, "tipo": tipo, "n": 5 if tipo == "oro" else 1, "y": nodo.position.y})
	# Losas de suelo.
	for c in _losas:
		var l: String = _losas[c]
		var col: Color = COLOR_LOSA[l]
		m._disco("", m._centro_celda(c, m.Y_DECAL), m.S * 0.85, col)
		var rot := Label3D.new()
		rot.text = NOMBRE_LOSA[l]
		rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rot.font_size = 48
		rot.outline_size = 10
		rot.pixel_size = 0.005
		rot.modulate = col
		rot.position = m._centro_celda(c, m.ALTO + 0.55)
		m._props.add_child(rot)
	# Puerta final y sus cuatro llamas.
	for y in range(MAPA.size()):
		for x in range(MAPA[y].length()):
			if MAPA[y][x] == "X":
				_puerta_c = Vector2i(x, y)
			elif MAPA[y][x] == "E":
				_salida_c = Vector2i(x, y)
	if _puerta_c.x >= 0:
		_montar_puerta()


func _montar_puerta() -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3(0.28, 2.3, m.S * 0.92)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.34, 0.22)
	mat.roughness = 0.9
	caja.material = mat
	_puerta = MeshInstance3D.new()
	_puerta.name = "puerta_final"
	_puerta.mesh = caja
	_puerta.position = m._centro_celda(_puerta_c, m.ALTO + 1.15)
	m._props.add_child(_puerta)
	m._bloqueadas[_puerta_c] = true
	var base: Vector3 = m._centro_celda(_puerta_c, m.ALTO + 3.9)
	for i in range(4):
		var lamp: MeshInstance3D = Formas3D.instancia("llama", COLOR_LAMPARA_OFF, 0.42)
		lamp.position = base + Vector3((float(i) - 1.5) * 0.46, 0.0, 0.0)
		m._props.add_child(lamp)
		_lamparas.append(lamp)


## Al final de _ready de la maqueta: el Jugador3D ya existe y los goblins ya están en `_goblins`.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in m.get_children():
		if n is Jugador3D:
			_jug = n
	_n_goblins = (m._goblins as Array).size()
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)
	# Nombre sobre cada NPC: dice qué modelo se ha cargado (si falta el GLB nuevo se ve el sustituto).
	for k in _npcs:
		var pj: Pj3D = _npcs[k]
		var et := Label3D.new()
		et.text = "%s\n(%s)" % [String(k).to_upper(), pj.id]
		et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		et.font_size = 40
		et.outline_size = 10
		et.pixel_size = 0.005
		et.no_depth_test = true
		et.position = Vector3(0.0, 2.1, 0.0)
		pj.add_child(et)
	for k in DIALOGOS:
		_lineas_dialogo[k] = 0
	_refrescar_hud()


func _process(delta: float) -> void:
	if m == null or m._jugador == null:
		return
	_t += delta
	var pj: Pj3D = m._jugador
	var c: Vector2i = m._celda_de(pj.position)
	# Tarea 1: la baldosa de contacto.
	if not _hecha[0] and _losas.get(c, "") == "p":
		_completar(0)
	# Tarea 2: todos los goblins muertos (Combate3D los saca de _goblins).
	if not _hecha[1] and (m._goblins as Array).is_empty():
		_completar(1)
	# Tarea 4: todas las antorchas encendidas.
	if not _hecha[3]:
		var total: int = 0
		var encendidas: int = 0
		for r in m._reactivos:
			if not is_instance_valid(r):
				continue      # un seto o una telaraña quemados ya se han liberado
			if r.tipo == "brasero":
				total += 1
				if r.is_lit:
					encendidas += 1
		if total > 0 and encendidas == total:
			_completar(3)
	# Losas de desbloqueo.
	if _losas.has(c) and _losas[c] != "p" and _t_aviso <= 0.0:
		_decir("Losa de %s pisada (las runas las da el Juego)" % NOMBRE_LOSA[_losas[c]].to_lower(), 2.5)
	# Guardados.
	if c != _ultimo_guardado and Jugabilidad3D.GUARDADOS.has(c):
		_ultimo_guardado = c
		if _jug != null:
			_jug.puntos_inicio = m._centro_celda(c, m.ALTO)
		_decir("Punto de guardado", 2.0)
	elif not Jugabilidad3D.GUARDADOS.has(c):
		_ultimo_guardado = Vector2i(-1, -1)
	_recoger(pj)
	# Puerta.
	if not _abierta and not _hecha.has(false):
		_abrir()
	if _abierta and not _terminado and c == _salida_c:
		_terminado = true
		_decir("¡Nivel completado en %d s!" % int(_t), 8.0)
	# Texto flotante y NPC hablando.
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	if _hablando != null:
		_t_habla -= delta
		if _t_habla <= 0.0:
			_hablando.animacion_actual = ""
			_hablando.jugar("idle")
			_hablando = null
	_t_hud_actualizar(delta)


var _t_hud: float = 0.0


func _t_hud_actualizar(delta: float) -> void:
	_t_hud += delta
	if _t_hud > 0.25:
		_t_hud = 0.0
		_refrescar_hud()


func _recoger(pj: Pj3D) -> void:
	for i in range(_botin.size() - 1, -1, -1):
		var b: Dictionary = _botin[i]
		var nodo: Node3D = b["nodo"]
		nodo.position.y = float(b["y"]) + (0.06 + 0.06 * sin(_t * 2.4 + float(i))) if String(b["tipo"]) == "pocion" else nodo.position.y
		var d: Vector3 = pj.position - m._centro_celda(b["c"], pj.position.y)
		d.y = 0.0
		if d.length() > ALCANCE_BOTIN:
			continue
		if String(b["tipo"]) == "pocion":
			if Estado.i().agregar("pocion", int(b["n"])) <= 0:
				_decir("Mochila llena", 1.5)
				continue
			_decir("Poción (+1)", 1.6)
		else:
			Estado.i().dar_oro(int(b["n"]))
			_decir("Oro +%d" % int(b["n"]), 1.6)
		nodo.queue_free()
		_botin.remove_at(i)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m._jugador == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var mejor: String = ""
	var dist: float = ALCANCE_HABLAR
	for nombre in _npcs:
		var d: Vector3 = (_npcs[nombre] as Pj3D).position - (m._jugador as Pj3D).position
		d.y = 0.0
		if d.length() < dist:
			dist = d.length()
			mejor = String(nombre)
	if mejor == "":
		return
	var npc: Pj3D = _npcs[mejor]
	var lineas: Array = DIALOGOS[mejor]
	var i: int = int(_lineas_dialogo[mejor])
	_lineas_dialogo[mejor] = i + 1
	_decir("%s: «%s»" % [mejor.capitalize(), String(lineas[i % lineas.size()])], 4.0)
	var hacia: Vector3 = (m._jugador as Pj3D).position - npc.position
	hacia.y = 0.0
	npc.mirar(hacia, 1.0)
	npc.jugar("talk")
	_hablando = npc
	_t_habla = 2.5
	if not _hecha[2]:
		_completar(2)


func _completar(i: int) -> void:
	_hecha[i] = true
	_decir("Tarea %d hecha: %s" % [i + 1, TAREAS[i]], 3.0)
	var lamp: MeshInstance3D = _lamparas[i] if i < _lamparas.size() else null
	if lamp != null:
		lamp.set_surface_override_material(0, Formas3D.material_tinte(COLOR_LAMPARA_ON, false, "llama"))
		_fuegos[i] = m._fx.fuego_fijo(lamp.position - Vector3(0.0, 0.15, 0.0), false, 0.35)
	_refrescar_hud()


func _abrir() -> void:
	_abierta = true
	m._bloqueadas.erase(_puerta_c)
	_decir("¡La puerta se abre!", 4.0)
	if _puerta != null:
		var tw := create_tween()
		tw.tween_property(_puerta, "position:y", _puerta.position.y - 2.4, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_puerta.hide)
	_refrescar_hud()


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var t: String = "TEST DE JUGABILIDAD 3D  ·  E hablar  ·  %d s\n" % int(_t)
	for i in range(4):
		t += "  [%s] %d. %s" % ["x" if _hecha[i] else " ", i + 1, TAREAS[i]]
		if i == 1 and _n_goblins > 0 and not _hecha[1]:
			t += "  (%d/%d)" % [_n_goblins - (m._goblins as Array).size(), _n_goblins]
		t += "\n"
	t += "  Puerta: %s" % ("ABIERTA, sal por el portal" if _abierta else "cerrada")
	_hud.text = t
