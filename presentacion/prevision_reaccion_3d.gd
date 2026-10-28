class_name PrevisionReaccion3D
extends Node3D

## A3 · PREVISUALIZAR LA REACCIÓN EN EL INDICADOR (docs/PROPUESTA_COMBATE.md §1.2 y §7; 28/10). Dueño: Juego.
##
## Pinta, mientras se apunta (libro o lanzamiento rápido), lo que `PrevisionHechizo.prever_rapido` dice que pasaría al soltar. NO decide nada: solo dibuja la lista que le pasa
## `Lanzador3D._pintar_previsualizacion` cada fotograma (`mostrar`). Tres familias, cada una con su forma para que no se confundan con las cajas del hechizo (A1, color del elemento):
##   · ENEMIGO  un rótulo sobre la cabeza con la reacción principal y su multiplicador («Congela ×2», «Prende ½»), una segunda línea si hay otra reacción que importa, y un anillo
##              en el suelo del color de la reacción. Si lo empuja: un disco en su destino unido por una línea; si acaba en el agua, el disco es azul y dice «¡Hunde!».
##   · SUELO    un cuadro plano del color de la reacción en cada casilla que cambia, y un rótulo pequeño por reacción (en la primera casilla de ese grupo).
##   · PIEZA    un anillo alrededor de la pieza y un rótulo encima («Enciende», «Rompe»…). Un bloque que se mueve lleva disco en su destino; la lava, un cuadro en cada casilla que enfría.
## Un hechizo que no reacciona con nada no pinta nada. Los nodos se reutilizan entre fotogramas (pozas por tipo): no se crea nada mientras la lista no crezca.

## reacción -> [texto, color]. Las tres familias comparten nombres («moja», «prende»…) con el mismo color, para que se lea igual en un enemigo y en el suelo.
const ESTILO: Dictionary = {
	"bloquea": ["Bloquea", Color(0.72, 0.72, 0.76)],
	"hunde": ["¡Hunde!", Color(0.35, 0.6, 1.0)],
	"electrocuta": ["Electrocuta", Color(1.0, 0.92, 0.3)],
	"congela": ["Congela", Color(0.55, 0.95, 1.0)],
	"prende": ["Prende", Color(1.0, 0.55, 0.2)],
	"moja": ["Moja", Color(0.35, 0.65, 1.0)],
	"seca": ["Seca", Color(0.95, 0.82, 0.55)],
	"apaga": ["Apaga", Color(0.8, 0.85, 0.9)],
	"aturde": ["Aturde", Color(1.0, 0.95, 0.6)],
	"empuja": ["Empuja", Color(0.95, 0.95, 0.95)],
	"ralentiza": ["Ralentiza", Color(0.75, 0.6, 1.0)],
	"golpe": ["Golpe", Color(0.95, 0.95, 0.95)],
	"hiela": ["Hiela", Color(0.55, 0.95, 1.0)],
	"derrite": ["Derrite", Color(0.6, 0.85, 1.0)],
	"evapora": ["Evapora", Color(0.92, 0.92, 0.95)],
	"arde": ["Arde", Color(1.0, 0.4, 0.15)],
	"brota": ["Brota", Color(0.5, 0.95, 0.4)],
	"abanica": ["Aviva", Color(1.0, 0.7, 0.35)],
	"enciende": ["Enciende", Color(1.0, 0.6, 0.2)],
	"aviva": ["Aviva", Color(1.0, 0.7, 0.35)],
	"activa": ["Activa", Color(1.0, 0.85, 0.35)],
	"mueve": ["Mueve", Color(0.95, 0.95, 0.95)],
	"agrieta": ["Agrieta", Color(0.85, 0.7, 0.5)],
	"rompe": ["Rompe", Color(0.9, 0.6, 0.4)],
	"enfria": ["Enfría", Color(0.62, 0.68, 0.78)],
}
const COLOR_DEBIL: Color = Color(1.0, 0.35, 0.25)       ## «×2»
const ALTO_ROTULO: float = 0.5                           ## por encima de los pies + altura: justo sobre la barra de vida (Combate3D: altura + 0,28); más alto, en la vista isométrica cae sobre el enemigo de detrás
const ALTO_ROTULO_PIEZA: float = 1.3
const LADO_SUELO: float = 0.62                           ## lado del cuadro de suelo, en casillas (las cajas del hechizo son de 0,9: este queda dentro y se distingue)
const ALFA_SUELO: float = 0.55

## Lo pintado en el último `mostrar`, para las pruebas: [{que, reaccion, texto, celda, nodo}].
var pintado: Array[Dictionary] = []

var _rotulos: Array[Label3D] = []
var _anillos: Array[MeshInstance3D] = []
var _cuadros: Array[MeshInstance3D] = []
var _lineas: Array[MeshInstance3D] = []
var _usados: Dictionary = {"rotulo": 0, "anillo": 0, "cuadro": 0, "linea": 0}


## Pinta la lista de `PrevisionHechizo.prever` (o `prever_rapido`). Vacía = no se ve nada.
func mostrar(prevision: Array) -> void:
	for k in _usados:
		_usados[k] = 0
	pintado.clear()
	var suelo_por_reaccion: Dictionary = {}                # reacción -> [celdas] (un rótulo por grupo)
	for e in prevision:
		var que: String = String(e.get("que", ""))
		var nodo: Variant = e.get("nodo")
		if nodo != null and not is_instance_valid(nodo):
			continue
		match que:
			"enemigo":
				_enemigo(e)
			"pieza":
				_pieza(e)
			"suelo":
				var r: String = String(e["reaccion"])
				if not suelo_por_reaccion.has(r):
					suelo_por_reaccion[r] = []
				(suelo_por_reaccion[r] as Array).append(e["celda"])
	# Casillas que ya llevan rótulo de enemigo o pieza con esa reacción (el fuego que prende al goblin prende también la hierba bajo él): el cuadro sí, el rótulo repetido no.
	var rotuladas: Dictionary = {}
	for p in pintado:
		rotuladas["%s|%s" % [p["reaccion"], p["celda"]]] = true
	for r in suelo_por_reaccion:
		var celdas: Array = suelo_por_reaccion[r]
		for c in celdas:
			_cuadro(c, _color(r))
		var txt: String = _texto(r)
		var c0: Vector2i = celdas[0]
		var con_rotulo: bool = false
		for c in celdas:
			if not rotuladas.has("%s|%s" % [r, c]):
				c0 = c
				con_rotulo = true
				break
		if con_rotulo:
			_rotulo(_centro(c0) + Vector3(0, 0.45, 0), txt, _color(r), 0.8)
		pintado.append({"que": "suelo", "reaccion": r, "texto": txt, "celda": c0, "celdas": celdas.duplicate(), "nodo": null})
	_esconder_sobrantes()


## Lo esconde todo (al salir del modo de lanzar se libera el nodo entero; esto es para cuando la previsión se queda vacía).
func limpiar() -> void:
	mostrar([])


func _enemigo(e: Dictionary) -> void:
	var g: Node3D = e["nodo"] as Node3D
	if g == null:
		return
	var extra: Dictionary = e.get("extra", {})
	var lista: Array = extra.get("reacciones", [String(e["reaccion"])])
	var principal: String = String(e["reaccion"])
	var linea1: String = _texto(principal) + _sufijo(float(e.get("mult", 1.0)))
	var segunda: String = ""
	for r in lista:
		if String(r) != principal and String(r) != "golpe":
			segunda = _texto(String(r))
			break
	var alto: float = float(g.get("altura")) if g.get("altura") != null else 1.0
	var cabeza: Vector3 = g.global_position + Vector3(0, alto + ALTO_ROTULO, 0)
	var col: Color = _color(principal)
	var mult: float = float(e.get("mult", 1.0))
	_rotulo(cabeza, linea1 if segunda == "" else "%s\n%s" % [linea1, segunda], COLOR_DEBIL if mult > 1.01 and principal != "bloquea" else col, 1.0)
	_anillo(g.global_position, 0.42 * Terreno3D.casilla, col)
	var destino: Vector3 = extra.get("destino", g.global_position)
	if (lista.has("empuja") or lista.has("hunde")) and destino.distance_to(g.global_position) > 0.25 * Terreno3D.casilla:
		var col_d: Color = _color("hunde") if bool(extra.get("hundira", false)) else _color("empuja")
		_linea(g.global_position, destino, col_d)
		_anillo(destino, 0.22 * Terreno3D.casilla, col_d)
	pintado.append({"que": "enemigo", "reaccion": principal, "texto": linea1, "segunda": segunda, "celda": e["celda"], "nodo": g, "destino": destino})


func _pieza(e: Dictionary) -> void:
	var r: String = String(e["reaccion"])
	var col: Color = _color(r)
	var nodo: Node3D = e.get("nodo") as Node3D
	var extra: Dictionary = e.get("extra", {})
	var txt: String = _texto(r)
	if r == "enfria":                                   # la lava: un cuadro por casilla que se enfría, y un rótulo
		var celdas: Array = extra.get("celdas", [e["celda"]])
		for c in celdas:
			_cuadro(c, col)
		_rotulo(_centro(celdas[0]) + Vector3(0, 0.5, 0), txt, col, 0.9)
		pintado.append({"que": "pieza", "reaccion": r, "texto": txt, "celda": celdas[0], "celdas": celdas.duplicate(), "nodo": nodo})
		return
	var pos: Vector3 = nodo.global_position if nodo != null else _centro(e["celda"])
	_anillo(pos, 0.45 * Terreno3D.casilla, col)
	_rotulo(pos + Vector3(0, ALTO_ROTULO_PIEZA, 0), txt, col, 0.9)
	if r == "mueve" and extra.has("destino"):
		var cd: Vector2i = extra["destino"]
		var pd: Vector3 = _centro(cd)
		_linea(pos, pd, col)
		_anillo(pd, 0.3 * Terreno3D.casilla, col)
	pintado.append({"que": "pieza", "reaccion": r, "texto": txt, "celda": e["celda"], "nodo": nodo})


# --- dibujo (pozas) ----------------------------------------------------------------------------------------------------------

func _rotulo(pos: Vector3, txt: String, col: Color, escala: float) -> void:
	var l: Label3D = _de_poza("rotulo") as Label3D
	l.text = txt
	l.modulate = col
	l.pixel_size = 0.0056 * escala
	l.global_position = pos


func _anillo(pos: Vector3, radio: float, col: Color) -> void:
	var mi: MeshInstance3D = _de_poza("anillo") as MeshInstance3D
	var t: TorusMesh = mi.mesh as TorusMesh
	t.inner_radius = radio - 0.07
	t.outer_radius = radio
	(t.material as StandardMaterial3D).albedo_color = Color(col, 0.9)
	mi.global_position = Vector3(pos.x, _y_suelo(pos) + 0.07, pos.z)


func _cuadro(c: Vector2i, col: Color) -> void:
	var mi: MeshInstance3D = _de_poza("cuadro") as MeshInstance3D
	var lado: float = LADO_SUELO * Terreno3D.casilla
	(mi.mesh as PlaneMesh).size = Vector2(lado, lado)
	((mi.mesh as PlaneMesh).material as StandardMaterial3D).albedo_color = Color(col, ALFA_SUELO)
	mi.global_position = _centro(c) + Vector3(0, 0.09, 0)


func _linea(a: Vector3, b: Vector3, col: Color) -> void:
	var mi: MeshInstance3D = _de_poza("linea") as MeshInstance3D
	var pa: Vector3 = Vector3(a.x, _y_suelo(a) + 0.08, a.z)
	var pb: Vector3 = Vector3(b.x, _y_suelo(b) + 0.08, b.z)
	var largo: float = maxf(pa.distance_to(pb), 0.01)
	(mi.mesh as BoxMesh).size = Vector3(0.08, 0.03, largo)
	((mi.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(col, 0.85)
	mi.global_position = (pa + pb) * 0.5
	var d: Vector3 = pb - pa
	mi.rotation = Vector3(0, atan2(d.x, d.z), 0)


func _de_poza(tipo: String) -> Node3D:
	var poza: Array = _poza(tipo)
	var i: int = int(_usados[tipo])
	_usados[tipo] = i + 1
	if i < poza.size():
		var n: Node3D = poza[i]
		n.visible = true
		return n
	var nuevo: Node3D = _crear(tipo)
	add_child(nuevo)
	poza.append(nuevo)
	return nuevo


func _poza(tipo: String) -> Array:
	match tipo:
		"rotulo":
			return _rotulos
		"anillo":
			return _anillos
		"cuadro":
			return _cuadros
	return _lineas


func _crear(tipo: String) -> Node3D:
	if tipo == "rotulo":
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.render_priority = 2
		l.outline_render_priority = 1
		return l
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = tipo != "cuadro"                    # anillos y líneas se ven aunque los tape un poco el modelo; el cuadro de suelo, no (se vería a través de las paredes)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match tipo:
		"anillo":
			var t := TorusMesh.new()
			t.rings = 32
			t.ring_segments = 4
			t.material = m
			mi.mesh = t
			mi.scale = Vector3(1.0, 0.05, 1.0)
		"cuadro":
			var p := PlaneMesh.new()
			p.material = m
			mi.mesh = p
		_:
			var b := BoxMesh.new()
			b.material = m
			mi.mesh = b
	return mi


func _esconder_sobrantes() -> void:
	for tipo in _usados:
		var poza: Array = _poza(tipo)
		for i in range(int(_usados[tipo]), poza.size()):
			(poza[i] as Node3D).visible = false


# --- utilidades ----------------------------------------------------------------------------------------------------------------

static func _texto(reaccion: String) -> String:
	return String((ESTILO.get(reaccion, [reaccion.capitalize(), Color.WHITE]) as Array)[0])


static func _color(reaccion: String) -> Color:
	return (ESTILO.get(reaccion, ["", Color.WHITE]) as Array)[1]


static func _sufijo(mult: float) -> String:
	if mult > 1.01:
		return " ×2"
	if mult < 0.99:
		return " ½"
	return ""


static func _centro(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


static func _y_suelo(p: Vector3) -> float:
	return Terreno3D.y_pies(Terreno3D.celda_de(p))
