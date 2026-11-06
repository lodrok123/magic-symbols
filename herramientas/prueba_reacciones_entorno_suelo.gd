extends SceneTree
## R1 del suelo (6/11, docs/REACCIONES_ENTORNO_2026-11-06.md §2): magma y naturaleza sobre el suelo, filas de REACCION_MATERIAL, escombro/vapor en el puzle, rótulos de la
## previsión y los TOPES (legibilidad y rendimiento: casillas por impacto, casillas vivas por estado). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reacciones_entorno_suelo.gd

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _precalentando: bool = false
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_agua(l: String) -> bool:
		return l == "~"
	func _es_hierba(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado and String(_mapa[c.y][c.x]) == "v"
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass
	func quitar_placa_hielo(_c: Vector2i) -> void:
		pass

const SECA := Vector2i(8, 8)
const SECA2 := Vector2i(9, 8)
const HIERBA := Vector2i(4, 4)
const AGUA := Vector2i(12, 12)
const ARENA := Vector2i(6, 6)
const ROCA := Vector2i(7, 9)
const MADERA := Vector2i(7, 7)

var _fallos: int = 0
var _m: MundoFalso = null
var _e: EstadosSuelo3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_magma()
	_naturaleza()
	_rayo_roca()
	_propagacion()
	_puzle()
	_prevision()
	_tope_por_impacto()
	_tope_vivas()
	Terreno3D.estados.limpiar()
	Terreno3D.estados.olvidar_materiales()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	for c in [HIERBA, Vector2i(5, 4), Vector2i(4, 5)]:
		filas[c.y] = filas[c.y].substr(0, c.x) + "v" + filas[c.y].substr(c.x + 1)
	for c in [AGUA, Vector2i(13, 12)]:
		filas[c.y] = filas[c.y].substr(0, c.x) + "~" + filas[c.y].substr(c.x + 1)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#" or filas[y][x] == "~":
				_m._bloqueadas[Vector2i(x, y)] = true
	Terreno3D.alturas.clear()
	_e = Terreno3D.estados
	_e.limpiar()
	_e.olvidar_materiales()
	_e.hierba_en = Callable(_m, "_es_hierba")
	_e.poner_material(ARENA, "arena")
	_e.poner_material(ROCA, "roca")
	_e.poner_material(MADERA, "madera")
	# La maqueta de verdad, sin añadirla al árbol: solo para preguntarle `prever_hierba` (su regla; no usa nodos). Se le quita el `hierba_en` que se puso al construirla.
	_ok("0 montaje: clases", ReaccionesSuelo3D.clase_de(SECA) == "suelo" and ReaccionesSuelo3D.clase_de(HIERBA) == "hierba" and ReaccionesSuelo3D.clase_de(AGUA) == "agua")


func _accion(elemento: String, c: Vector2i, radio: float = 0.0) -> Dictionary:
	return ReaccionesSuelo3D.aplicar(AccionElemental.nueva(elemento, Terreno3D.centro_de(c, 0.0), radio))


func _prever(elemento: String, c: Vector2i) -> String:
	return String(ReaccionesSuelo3D.prever(elemento, c).get("reaccion", ""))


func _magma() -> void:
	_e.limpiar()
	_ok("1 ACCION_DE: magma = «magma» y naturaleza = «brota»", ReaccionesSuelo3D.ACCION_DE.get("magma", "") == "magma" and ReaccionesSuelo3D.ACCION_DE.get("naturaleza", "") == "brota")
	# Magma sobre AGUA: costra (escombro 6 s) y vapor.
	_ok("1 prever magma sobre agua = «costra»", _prever("magma", AGUA) == "costra", _prever("magma", AGUA))
	var r: Dictionary = _accion("magma", AGUA)
	_ok("1 magma sobre AGUA deja escombro y vapor", _e.tiene(AGUA, EstadosSuelo3D.ESCOMBRO) and _e.tiene(AGUA, EstadosSuelo3D.VAPOR) and bool(r.get("cambio", false)))
	_ok("1 …el escombro dura 6 s y bloquea proyectiles", is_equal_approx(_e.queda(AGUA, EstadosSuelo3D.ESCOMBRO), 6.0) and _e.bloquea_proyectil(AGUA))
	_e.avanzar(6.1)
	_ok("1 …y a los 6,1 s la costra se va", not _e.tiene(AGUA, EstadosSuelo3D.ESCOMBRO) and not _e.bloquea_proyectil(AGUA))
	# Magma sobre suelo MOJADO: costra y vapor; la mojada se evapora.
	_e.limpiar()
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_ok("1 prever magma sobre mojada = «costra»", _prever("magma", SECA) == "costra")
	_accion("magma", SECA)
	_ok("1 magma sobre suelo MOJADO: escombro + vapor y ya no está mojado", _e.tiene(SECA, EstadosSuelo3D.ESCOMBRO) and _e.tiene(SECA, EstadosSuelo3D.VAPOR) and not _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	# Magma sobre suelo seco: nada (calor sin más), y sobre hielo funde.
	_e.limpiar()
	_ok("1 magma sobre suelo seco: nada y la previsión no promete nada", not bool(_accion("magma", SECA2).get("cambio", false)) and _prever("magma", SECA2) == "" and _e.cuantas(EstadosSuelo3D.ESCOMBRO) == 0)
	_e.aplicar(SECA, "frio")
	_accion("magma", SECA)
	_ok("1 magma sobre hielo del suelo lo funde (como el fuego)", not _e.tiene(SECA, EstadosSuelo3D.HELADA) and _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	_e.limpiar()
	# Prender: la tabla y la regla de la maqueta.
	_ok("1 magma × hierba y madera prende; roca, tierra, arena y agua no", _e.puede_prender(HIERBA, "magma") and _e.puede_prender(MADERA, "magma") and not _e.puede_prender(ROCA, "magma") and not _e.puede_prender(SECA, "magma") and not _e.puede_prender(ARENA, "magma") and not _e.puede_prender(AGUA, "magma"))
	var t2: Object = _maqueta()
	if t2 == null:
		_ok("1 la maqueta (PruebaTest2) se pudo instanciar para preguntarle prever_hierba", false)
	else:
		_ok("1 magma sobre hierba = «prende» (la misma regla que el fuego)", String(t2.call("prever_hierba", "magma", HIERBA)) == "prende" and String(t2.call("prever_hierba", "fuego", HIERBA)) == "prende")
		t2.free()


## La maqueta suelta (sin árbol): `prever_hierba` solo lee `_hf`, `_mojada` y `Terreno3D.estados`. Al construirla pisa `hierba_en` y `estado_zona_en`: se restauran.
func _maqueta() -> Object:
	var s: Script = load("res://presentacion/prueba_test2.gd")
	if s == null:
		return null
	var antes_h: Callable = _e.hierba_en
	var o: Object = s.new()
	_e.hierba_en = antes_h
	return o


func _naturaleza() -> void:
	_e.limpiar()
	# Tierra MOJADA germina.
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_ok("2 prever naturaleza sobre tierra mojada = «germina»", _prever("naturaleza", SECA) == "germina", _prever("naturaleza", SECA))
	var r: Dictionary = _accion("naturaleza", SECA)
	_ok("2 naturaleza sobre tierra MOJADA: el material pasa a hierba", _e.material_de(SECA) == "hierba" and bool(r.get("cambio", false)), _e.material_de(SECA))
	_ok("2 …y la casilla sigue mojada", _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	_ok("2 …ya germinada, otra naturaleza no hace nada más", _prever("naturaleza", SECA) == "" and not bool(_accion("naturaleza", SECA).get("cambio", false)))
	_e.olvidar_materiales()
	_e.poner_material(ARENA, "arena")
	_e.poner_material(ROCA, "roca")
	_e.poner_material(MADERA, "madera")
	# Arena mojada también.
	_e.poner(ARENA, EstadosSuelo3D.MOJADA, true)
	_accion("naturaleza", ARENA)
	_ok("2 naturaleza sobre ARENA mojada también germina", _e.material_de(ARENA) == "hierba")
	_e.poner_material(ARENA, "arena")
	# Tierra SECA: nada.
	_e.limpiar()
	_ok("2 naturaleza sobre tierra SECA: nada (ni cambio ni previsión)", not bool(_accion("naturaleza", SECA2).get("cambio", false)) and _e.material_de(SECA2) == "tierra" and _prever("naturaleza", SECA2) == "")
	# Roca (aunque esté mojada) y agua: nada.
	_e.poner(ROCA, EstadosSuelo3D.MOJADA, true)
	_accion("naturaleza", ROCA)
	_ok("2 naturaleza sobre ROCA (incluso mojada): nada", _e.material_de(ROCA) == "roca" and _prever("naturaleza", ROCA) == "")
	_e.limpiar()
	_accion("naturaleza", AGUA)
	_ok("2 naturaleza sobre AGUA: nada", _e.cuantas(EstadosSuelo3D.MOJADA) == 0 and _prever("naturaleza", AGUA) == "" and _e.material_de(AGUA) == "agua")
	# Hierba: brota (la regla de la maqueta, como el agua sobre hierba corta).
	var t2: Object = _maqueta()
	if t2 != null:
		_ok("2 naturaleza sobre hierba corta = «brota»", String(t2.call("prever_hierba", "naturaleza", HIERBA)) == "brota" and String(t2.call("prever_hierba", "agua", HIERBA)) == "brota")
		t2.free()
	_ok("2 la hierba no la gestiona el estado del suelo (aplicar no hace nada ahí)", _accion("naturaleza", HIERBA).is_empty())
	_e.limpiar()


func _rayo_roca() -> void:
	_e.limpiar()
	_ok("3 rayo sobre roca SECA: nada", not bool(_accion("rayo", ROCA).get("cambio", false)) and not _e.tiene(ROCA, EstadosSuelo3D.ELECTRIFICADA) and _prever("rayo", ROCA) == "")
	_e.poner(ROCA, EstadosSuelo3D.MOJADA, true)
	_accion("rayo", ROCA)
	_ok("3 rayo sobre roca MOJADA: tampoco (la roca no conduce, §1.5)", not _e.tiene(ROCA, EstadosSuelo3D.ELECTRIFICADA))
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_accion("rayo", SECA)
	_ok("3 y en tierra mojada sigue electrificando (lo de siempre)", _e.tiene(SECA, EstadosSuelo3D.ELECTRIFICADA))
	_ok("3 hielo × agua hiela (ya existía) y rayo × agua conduce", bool(EstadosSuelo3D.reaccion("hielo", "agua", "hiela", false)) and bool(EstadosSuelo3D.reaccion("rayo", "agua", "conduce", false)))
	_e.limpiar()


func _propagacion() -> void:
	_e.limpiar()
	_ok("4 la madera prende pero NO propaga; la hierba prende y propaga", _e.puede_prender(MADERA) and not _e.propaga_fuego(MADERA) and _e.puede_prender(HIERBA) and _e.propaga_fuego(HIERBA))
	# El autómata de la maqueta pregunta `propaga_fuego` antes de contagiar: se comprueba en su código (la maqueta entera no se monta aquí).
	var fuente: String = FileAccess.get_file_as_string("res://presentacion/prueba_test2.gd")
	_ok("4 `_avanzar_estado` contagia solo si `propaga_fuego(c)` y respeta PROPAGA_POR_TICK", fuente.contains("and Terreno3D.estados.propaga_fuego(c):") and fuente.contains("prender.size() >= EstadosSuelo3D.PROPAGA_POR_TICK"))
	_ok("4 PROPAGA_POR_TICK = 2 y DESALOJO_POR_TICK = 1", EstadosSuelo3D.PROPAGA_POR_TICK == 2 and EstadosSuelo3D.DESALOJO_POR_TICK == 1)


func _puzle() -> void:
	var base: String = "; pieza b pulsador 1 1\n; pieza k compuerta 3 1\n; pieza p puerta 4 1\n"
	for est in ["escombro", "vapor"]:
		var r: Dictionary = Puzle3D.parsear(base + "; puzle r cuando=b.pulsado si=casilla(8,8).%s hace=p.abrir" % est)
		var reglas: Array = r["reglas"]
		_ok("5 `si=casilla(x,y).%s` se lee sin avisos" % est, (r["avisos"] as Array).is_empty() and reglas.size() == 1 and reglas[0]["si_expr"][0][0]["estado"] == est, str(r["avisos"]))
	_e.limpiar()
	_e.aplicar(SECA, "escombro")
	_ok("5 y la casilla con escombro lo cumple (el dato que lee el puzle: `estados.tiene`)", _e.tiene(SECA, "escombro") and "escombro" in Puzle3D.ESTADOS_CASILLA and "vapor" in Puzle3D.ESTADOS_CASILLA)
	_e.limpiar()


func _prevision() -> void:
	_ok("6 ESTILO tiene «Germina» y «Costra»", String((PrevisionReaccion3D.ESTILO["germina"] as Array)[0]) == "Germina" and String((PrevisionReaccion3D.ESTILO["costra"] as Array)[0]) == "Costra")
	_e.limpiar()
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	var g: Dictionary = ReaccionesSuelo3D.prever("naturaleza", SECA)
	var k: Dictionary = ReaccionesSuelo3D.prever("magma", SECA)
	_ok("6 `ReaccionesSuelo3D.prever` devuelve germina y costra", String(g.get("reaccion", "")) == "germina" and String(k.get("reaccion", "")) == "costra", str(g) + str(k))
	_ok("6 …y rotula a la previsión con los textos nuevos", PrevisionReaccion3D._texto(String(g["reaccion"])) == "Germina" and PrevisionReaccion3D._texto(String(k["reaccion"])) == "Costra")
	_e.limpiar()


## LEGIBLE: un impacto grande marca como mucho `MAX_CASILLAS_POR_IMPACTO`, las más cercanas al punto, y la previsión pide la misma lista.
func _tope_por_impacto() -> void:
	_e.limpiar()
	var centro := Vector2i(10, 5)
	var a: AccionElemental = AccionElemental.nueva("agua", Terreno3D.centro_de(centro, 0.0), 8.0)
	var lista: Array = ReaccionesSuelo3D.casillas_de_impacto("agua", a.punto, a.radio)
	_ok("7 un impacto de agua enorme (radio 8 m) pide como mucho %d casillas (pide %d)" % [int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["agua"]), lista.size()], lista.size() <= int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["agua"]) and lista.size() >= 2)
	_ok("7 la primera es la del punto y están ordenadas de cerca a lejos", lista[0] == centro and _ordenada(lista, a.punto))
	var r: Dictionary = ReaccionesSuelo3D.aplicar(a)
	var n: int = _e.cuantas(EstadosSuelo3D.MOJADA)
	_ok("7 …y el estado marca exactamente esas: %d mojadas ≤ %d" % [n, int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["agua"])], n <= int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["agua"]) and n == lista.size() and int(r.get("casillas", -1)) == n)
	_e.limpiar()
	_accion("fuego", centro, 8.0)
	var f: Array = ReaccionesSuelo3D.casillas_de_impacto("fuego", a.punto, 8.0)
	_ok("7 el fuego, aún más recortado: %d casillas ≤ %d" % [f.size(), int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["fuego"])], f.size() <= int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["fuego"]))
	_ok("7 un impacto sin radio marca UNA casilla", ReaccionesSuelo3D.casillas_de_impacto("agua", a.punto, 0.0).size() == 1)
	# Naturaleza: tope MAX_BROTES_HECHIZO sobre una zona mojada más grande.
	_e.limpiar()
	for y in range(3, 6):
		for x in range(14, 18):
			_e.poner(Vector2i(x, y), EstadosSuelo3D.MOJADA, true)       # 12 casillas de tierra mojada
	_accion("naturaleza", Vector2i(15, 4), 8.0)
	var germinadas: int = 0
	for y in range(3, 6):
		for x in range(14, 18):
			if _e.material_de(Vector2i(x, y)) == "hierba":
				germinadas += 1
	_ok("7 naturaleza sobre 12 casillas mojadas: germinan exactamente MAX_BROTES_HECHIZO = %d (germinan %d)" % [ReaccionesSuelo3D.MAX_BROTES_HECHIZO, germinadas], germinadas == ReaccionesSuelo3D.MAX_BROTES_HECHIZO and ReaccionesSuelo3D.MAX_BROTES_HECHIZO == int(ReaccionesSuelo3D.MAX_CASILLAS_POR_IMPACTO["naturaleza"]))
	_e.limpiar()
	_e.olvidar_materiales()
	_e.poner_material(ARENA, "arena")
	_e.poner_material(ROCA, "roca")
	_e.poner_material(MADERA, "madera")


func _ordenada(lista: Array, p: Vector3) -> bool:
	var ant: float = -1.0
	for c in lista:
		var q: Vector3 = Terreno3D.centro_de(c as Vector2i)
		var d: float = Vector2(q.x - p.x, q.z - p.z).length()
		if d + 0.0001 < ant:
			return false
		ant = d
	return true


## RENDIMIENTO: tope global de casillas con cada estado; se retira la más vieja.
func _tope_vivas() -> void:
	_e.limpiar()
	var tope: int = int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["mojada"])
	var celdas: Array = []
	for y in range(1, 19):
		for x in range(1, 19):
			var c := Vector2i(x, y)
			if ReaccionesSuelo3D.clase_de(c) == "suelo" and _e.material_de(c) == "tierra" and c != SECA:
				celdas.append(c)
	_ok("8 hay casillas de sobra para 100 impactos (%d)" % celdas.size(), celdas.size() >= 100)
	var nunca_mas: bool = true
	var maximo: int = 0
	for i in range(100):
		_accion("agua", celdas[i] as Vector2i)
		_e.avanzar(0.05)                        # cada impacto, un poco más joven que el anterior
		maximo = maxi(maximo, _e.cuantas(EstadosSuelo3D.MOJADA))
		if _e.cuantas(EstadosSuelo3D.MOJADA) > tope:
			nunca_mas = false
	_ok("8 100 impactos de agua seguidos: nunca más de MAX_CASILLAS_VIVAS = %d mojadas (máximo visto %d)" % [tope, maximo], nunca_mas and maximo == tope)
	_ok("8 la primera mojada es la que se retiró; la última sigue", not _e.tiene(celdas[0] as Vector2i, EstadosSuelo3D.MOJADA) and _e.tiene(celdas[99] as Vector2i, EstadosSuelo3D.MOJADA))
	_ok("8 se retiran por orden: las 40 primeras fuera y las 60 últimas dentro", not _e.tiene(celdas[39] as Vector2i, EstadosSuelo3D.MOJADA) and _e.tiene(celdas[40] as Vector2i, EstadosSuelo3D.MOJADA))
	# Escombro: tope 20.
	_e.limpiar()
	var tope_e: int = int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["escombro"])
	for i in range(30):
		_e.aplicar(celdas[i] as Vector2i, "escombro")
		_e.avanzar(0.05)
	_ok("8 30 escombros: como mucho MAX_CASILLAS_VIVAS = %d (hay %d)" % [tope_e, _e.cuantas(EstadosSuelo3D.ESCOMBRO)], _e.cuantas(EstadosSuelo3D.ESCOMBRO) == tope_e and not _e.tiene(celdas[0] as Vector2i, EstadosSuelo3D.ESCOMBRO))
	# Lo permanente (sin reloj) no se desaloja.
	_e.limpiar()
	_e.poner(celdas[0] as Vector2i, EstadosSuelo3D.MOJADA, true, 1.0, 0.0)
	for i in range(1, 80):
		_accion("agua", celdas[i] as Vector2i)
		_e.avanzar(0.05)
	_ok("8 una mojada sin reloj (permanente) no se desaloja", _e.tiene(celdas[0] as Vector2i, EstadosSuelo3D.MOJADA) and _e.cuantas(EstadosSuelo3D.MOJADA) <= tope)
	_e.limpiar()
