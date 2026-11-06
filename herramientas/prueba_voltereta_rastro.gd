extends SceneTree
## C6 · Voltereta con rastro (6/11, docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloque C). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_voltereta_rastro.gd
## Con una página de fuego, hielo o agua seleccionada, rodar deja en la casilla de salida el estado de ese elemento (4 de tinta, `VolteretaRastro.TINTA_RASTRO`).
## El fuego solo prende donde `EstadosSuelo3D.puede_prender` lo permite (hierba sí; roca no). Sin tinta no hay rastro ni cobro; sin elemento o con rayo, tampoco.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _precalentando: bool = false
	var prendidas: Dictionary = {}           ## la hierba que la «maqueta» ha puesto a arder
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_agua(l: String) -> bool:
		return l == "~"
	func _es_hierba(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado and String(_mapa[c.y][c.x]) == "v"
	## Misma regla que PruebaTest2.prever_hierba para el fuego: prende solo si el material lo deja.
	func prever_hierba(elemento: String, c: Vector2i) -> String:
		if elemento == "fuego" and not prendidas.has(c) and Terreno3D.estados.puede_prender(c):
			return "prende"
		return ""
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		var c: Vector2i = Terreno3D.celda_de(punto)
		if _es_hierba(c) and prever_hierba(elemento, c) == "prende":
			prendidas[c] = true
	func quitar_placa_hielo(_c: Vector2i) -> void:
		pass

const SECA := Vector2i(8, 8)
const ROCA := Vector2i(9, 8)        ## suelo desnudo con material roca
const HIERBA := Vector2i(4, 4)
const HIERBA2 := Vector2i(5, 4)

var _fallos: int = 0
var _m: MundoFalso = null
var _e: EstadosSuelo3D = null
var _l: Lanzador3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_fuego()
	_agua_y_hielo()
	_sin_tinta()
	_sin_elemento()
	_tabla()
	Terreno3D.estados.limpiar()
	Terreno3D.estados.olvidar_materiales()
	_l.free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	for c in [HIERBA, HIERBA2]:
		filas[c.y] = filas[c.y].substr(0, c.x) + "v" + filas[c.y].substr(c.x + 1)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	Terreno3D.alturas.clear()
	_e = Terreno3D.estados
	_e.limpiar()
	_e.olvidar_materiales()
	_e.hierba_en = Callable(_m, "_es_hierba")
	_e.poner_material(ROCA, "roca")
	_l = Lanzador3D.new()                    # sin añadir al árbol: sin interfaz, solo páginas y `marcar_celda`
	_l.mundo = _m
	# Las páginas las crea el `_ready` del Grimorio (que arma interfaz y señales de libro); aquí solo hacen falta tres fichas vacías con las mismas claves.
	for i in range(Grimorio.PAGES):
		_l.pages.append({"element": Runes.Type.NONE, "element_q": 1.0, "element2": Runes.Type.NONE, "element2_q": 1.0, "element_viejo": 1, "components": [], "undo": []})


func _pagina(tipo: Runes.Type) -> void:
	_l.pages[_l.page]["element"] = tipo


func _tinta(cantidad: float = 100.0) -> Tinta:
	var t: Tinta = Tinta.new()
	t.actual = cantidad
	t.frascos = 0
	return t


func _fuego() -> void:
	_e.limpiar()
	_pagina(Runes.Type.SHAPE_TRIANGLE)
	_ok("0 la página de fuego se lee como «fuego»", VolteretaRastro.elemento_seleccionado(_l) == "fuego")
	var t: Tinta = _tinta()
	var r: String = VolteretaRastro.dejar(_l, t, HIERBA)
	_ok("1 fuego en HIERBA: deja rastro, la hierba arde y cuesta %d" % int(VolteretaRastro.TINTA_RASTRO), r == "fuego" and _m.prendidas.has(HIERBA) and is_equal_approx(t.actual, 100.0 - VolteretaRastro.TINTA_RASTRO), "tinta=%.1f" % t.actual)
	var t2: Tinta = _tinta()
	var r2: String = VolteretaRastro.dejar(_l, t2, ROCA)
	_ok("2 fuego en ROCA: no prende, no hay rastro y no se cobra", r2 == "" and not _m.prendidas.has(ROCA) and is_equal_approx(t2.actual, 100.0) and _estados_de(ROCA).is_empty())
	var t3: Tinta = _tinta()
	_ok("2 fuego en suelo de tierra seca: tampoco", VolteretaRastro.dejar(_l, t3, SECA) == "" and is_equal_approx(t3.actual, 100.0))


func _agua_y_hielo() -> void:
	_e.limpiar()
	_pagina(Runes.Type.SHAPE_CIRCLE)
	var t: Tinta = _tinta()
	var r: String = VolteretaRastro.dejar(_l, t, SECA)
	_ok("3 agua deja MOJADA y cuesta 4", r == "agua" and _e.tiene(SECA, EstadosSuelo3D.MOJADA) and is_equal_approx(t.actual, 96.0), "tinta=%.1f" % t.actual)
	_e.limpiar()
	_pagina(Runes.Type.ELEMENT_ICE)
	var t2: Tinta = _tinta()
	var r2: String = VolteretaRastro.dejar(_l, t2, SECA)
	_ok("4 hielo deja HELADA y cuesta 4", r2 == "hielo" and _e.tiene(SECA, EstadosSuelo3D.HELADA) and is_equal_approx(t2.actual, 96.0), "tinta=%.1f" % t2.actual)
	# El fuego sí actúa sobre lo helado aunque el suelo no «prenda»: es la tabla (hielo -> charco), y por eso se cobra.
	_pagina(Runes.Type.SHAPE_TRIANGLE)
	_ok("4 fuego sobre casilla helada la funde (la tabla, no una regla propia)", VolteretaRastro.dejar(_l, _tinta(), SECA) == "fuego" and not _e.tiene(SECA, EstadosSuelo3D.HELADA))


func _sin_tinta() -> void:
	_e.limpiar()
	_pagina(Runes.Type.SHAPE_CIRCLE)
	var t: Tinta = _tinta(VolteretaRastro.TINTA_RASTRO - 0.5)
	_ok("5 sin tinta suficiente no hay rastro", VolteretaRastro.dejar(_l, t, SECA) == "" and not _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	_ok("5 y no se cobra nada", is_equal_approx(t.actual, VolteretaRastro.TINTA_RASTRO - 0.5), "tinta=%.2f" % t.actual)
	var tf: Tinta = _tinta(0.0)
	tf.frascos = 3
	_ok("5 con la barra vacía pero con frascos TAMPOCO: la voltereta no gasta un frasco", VolteretaRastro.dejar(_l, tf, SECA) == "" and tf.frascos == 3)
	var justo: Tinta = _tinta(VolteretaRastro.TINTA_RASTRO)
	_ok("5 con justo 4 sí", VolteretaRastro.dejar(_l, justo, SECA) == "agua" and justo.actual < 0.01)


func _sin_elemento() -> void:
	_e.limpiar()
	_pagina(Runes.Type.NONE)
	var t: Tinta = _tinta()
	_ok("6 página sin elemento: no hay rastro ni cobro", VolteretaRastro.dejar(_l, t, SECA) == "" and is_equal_approx(t.actual, 100.0))
	_pagina(Runes.Type.ELEMENT_LIGHTNING)
	_ok("6 página de rayo: no hay rastro ni cobro", VolteretaRastro.dejar(_l, t, SECA) == "" and is_equal_approx(t.actual, 100.0) and _e.tiene(SECA, EstadosSuelo3D.ELECTRIFICADA) == false)
	_ok("6 sin lanzador: nada", VolteretaRastro.dejar(null, t, SECA) == "")


func _tabla() -> void:
	var k: Array = VolteretaRastro.RASTRO_DE.keys()
	k.sort()
	_ok("7 RASTRO_DE = fuego, hielo, agua (los derivados aún no)", k == ["agua", "fuego", "hielo"], str(k))


func _estados_de(c: Vector2i) -> Array:
	var r: Array = []
	for s in EstadosSuelo3D.TODOS:
		if _e.tiene(c, s):
			r.append(s)
	return r
