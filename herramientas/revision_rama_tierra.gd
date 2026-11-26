extends SceneTree
## REVISIÓN DE LA RAMA TIERRA (24/11/2026, sesión COMBATE; pedido de Pablo: «revisa los hechizos de la rama tierra y mira si se comportan como deberían, compáralo con otras ramas»).
## Diagnóstico, no prueba: imprime una tabla receta × elemento con lo que decide `Hechizo` (perfil, forma, tamaño, duración, daño, tinta) y, en un mundo vacío,
## lo que sale de verdad al lanzarlo (casillas, bloques de tierra, solidez, marcas de suelo, proyectil). Para comparar la tierra con fuego, agua, hielo, viento y rayo.
##   godot --headless --path . --script res://herramientas/revision_rama_tierra.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

const LADO: int = 20
const ORIGEN_C: Vector2i = Vector2i(5, 10)
const ELEMENTOS: Array = [["tierra", "earth"], ["fuego", "fire"], ["agua", "water"], ["hielo", "ice"], ["viento", "wind"], ["rayo", "lightning"]]
const RECETAS: Array = [
	[], ["flecha"], ["flecha", "flecha"], ["barrera"], ["barrera", "barrera"], ["linea_x"], ["linea_x", "linea_x"], ["linea_z"], ["altura"], ["altura", "altura"],
	["pulso"], ["repeticion"], ["flecha", "repeticion"], ["flecha", "rebote"], ["permanencia"], ["flecha", "permanencia"], ["raido"], ["suelo"],
	["barrera", "flecha"], ["barrera", "linea_x"], ["barrera", "linea_x", "linea_x"], ["barrera", "altura"], ["linea_x", "altura"], ["retardo"], ["flecha", "retardo"],
	["barrera", "pulso"], ["linea_x", "flecha"],
]

var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _senales: Array = []


func _initialize() -> void:
	_correr.call_deferred()


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	for n in root.get_children():
		if n is HechizoVivo or n is Lanzador3D.SolidezV2:
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(ORIGEN_C - Vector2i(2, 0), 1.0)       # fuera de la casilla del hechizo: la tierra no se levanta «encima de la jugadora»
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_senales.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _receta(glifos: Array) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		r.apply(String(gl))
	return r


func _rel(c: Vector2i) -> String:
	var d: Vector2i = c - ORIGEN_C
	return "%+d,%+d" % [d.x, d.y]


func _celdas_txt(cs: Array) -> String:
	var t: PackedStringArray = []
	var ord: Array = cs.duplicate()
	ord.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for c in ord:
		t.append(_rel(c as Vector2i))
	if t.size() > 6:
		return "%s…(%d)" % [" ".join(t.slice(0, 6)), t.size()]
	return " ".join(t)


## Lo que sale al lanzar `glifos` con `rune` desde ORIGEN_C hacia +X, en un mundo vacío.
func _en_el_mundo(glifos: Array, rune: RuneData) -> String:
	_montar()
	await process_frame
	var r := _receta(glifos)
	var antes_marcas: int = _m.marcas.size()
	_l._materializar(r, rune, Lanzador3D.centro_de(ORIGEN_C, 0.0), Vector3.RIGHT)
	var t: float = 0.0
	var max_alt: Dictionary = {}
	var sol: Dictionary = {}
	var vivos_max: int = 0
	while t < 2.0:
		await process_frame
		t += 1.0 / 60.0
		for c in Terreno3D.alturas:
			max_alt[c] = maxi(int(max_alt.get(c, 0)), int(Terreno3D.alturas[c]))
		for s in _l._solideces_v2:
			if is_instance_valid(s):
				for c in (s as Lanzador3D.SolidezV2).celdas:
					sol[c] = true
		var vivos: int = 0
		for n in root.get_children():
			if n is HechizoVivo:
				vivos += 1
		for n in _m.get_children():
			if n is HechizoVivo:
				vivos += 1
		vivos_max = maxi(vivos_max, vivos)
	var marcas: Dictionary = {}
	for i in range(antes_marcas, _m.marcas.size()):
		marcas[(_m.marcas[i] as Array)[1]] = true
	var bloques: Array = []
	for c in max_alt:
		if int(max_alt[c]) > 0:
			bloques.append(c)
	var estado: String = String((_senales[0] as Array)[0]) if not _senales.is_empty() else "-"
	return "estado=%s · bloques[%s] alto=%d · solidez[%s] · marcas[%s] · vivos=%d" % [estado, _celdas_txt(bloques), (max_alt.values().max() if not max_alt.is_empty() else 0),
		_celdas_txt(sol.keys()), _celdas_txt(marcas.keys()), vivos_max]


func _correr() -> void:
	var lineas: PackedStringArray = []
	for receta in RECETAS:
		var cont: Dictionary = {}
		for g in receta:
			cont[g] = int(cont.get(g, 0)) + 1
		lineas.append("")
		lineas.append("######## %s" % ("(sin glifos)" if receta.is_empty() else " + ".join(receta)))
		for par in ELEMENTOS:
			var rune: RuneData = load("res://nucleo/%s_rune.tres" % par[1]) as RuneData
			var h: Hechizo = Hechizo.construir(rune, cont)
			if h == null:
				lineas.append("  %-7s ¡no se construye!" % par[0])
				continue
			var se: Vector3 = h.semiejes
			var datos: String = "%-7s perfil=%-13s forma=%-6s haz=%-5s viaja=%-5s en_punto=%-5s muro=%-5s plataf=%-5s sx/sy/sz=%.2f/%.2f/%.2f niv=%d vida=%.1f+%.1f daño=%.0f tinta=%.1f recarga=%.1f «%s»" % [
				par[0], PrevisionCasteo3D.perfil(h), h.forma, h.haz, h.viaja, h.en_punto, h.es_muro, h.es_plataforma_tierra(), se.x, se.y, se.z, h.niveles,
				h.persiste, h.permanencia, h.dano, h.coste_tinta, h.recarga, NombreHechizo.automatico(h)]
			lineas.append("  " + datos)
			lineas.append("          ↳ " + await _en_el_mundo(receta, rune))
	var f := FileAccess.open("user://revision_rama_tierra.txt", FileAccess.WRITE)
	f.store_string("\n".join(lineas))
	f.close()
	print("\n".join(lineas))
	print("ESCRITO: ", ProjectSettings.globalize_path("user://revision_rama_tierra.txt"))
	quit(0)
