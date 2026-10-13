extends SceneTree
## AccionElemental + Mundo3D.aplicar + ReaccionesAgua3D (M3, 13/10), con maqueta falsa y sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_accion.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0
var _efectos: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var m := MundoFalso.new()
	m._mapa = ["######", "#....#", "#.~~.#", "#....#", "#....#", "######"]
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	_datos()
	await _reparto(m)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Caudal total (u³/s) que hay en los trocitos de la casilla.
func _caudal(sim: AguaSim3D, c: Vector2i) -> float:
	var t: float = 0.0
	for i in sim._trozos(c):
		t += sim.fuente[i]
	return t


func _datos() -> void:
	var a := AccionElemental.nueva("agua", Vector3(1, 2, 3))
	_ok("1 nueva: elemento y punto; el resto a «el habitual»", a.elemento == "agua" and a.punto == Vector3(1, 2, 3) and a.radio == 0.0 and a.cantidad == 0.0 and a.duracion == 0.0 and a.origen == null)
	var b := AccionElemental.nueva("fuego", Vector3.ZERO, 1.5, 0.7, 2.0)
	_ok("1 nueva con todo", b.radio == 1.5 and b.cantidad == 0.7 and b.duracion == 2.0)


func _reparto(m: MundoFalso) -> void:
	# Sin simulación: no hace nada y no rompe.
	ReaccionesAgua3D.aplicar(AccionElemental.nueva("agua", Terreno3D.centro_de(Vector2i(2, 3))))
	_ok("2 sin simulación no hace nada", Terreno3D.agua_sim == null)
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	_ok("2 Lanzador3D.configurar engancha el efecto del mundo", ReaccionesAgua3D.efecto.is_valid())
	# Registro de efectos: se sustituye el gancho para ver qué pide el mundo.
	ReaccionesAgua3D.efecto = func(nombre: String, _p: Vector3, radio: float, seg: float) -> void: _efectos.append([nombre, radio > 0.0, seg])
	var w := Mundo3D.new()
	root.add_child(w)
	var impactos: Array = []
	w.impacto.connect(func(p: Vector3, el: String, r: float) -> void: impactos.append([p, el, r]))
	var p: Vector3 = Terreno3D.centro_de(Vector2i(3, 3))
	var v0: float = sim.volumen_total()
	w.aplicar(AccionElemental.nueva("agua", p))
	_ok("3 agua por defecto echa VOL_AGUA_IMPACTO", absf(sim.volumen_total() - v0 - ReaccionesAgua3D.VOL_AGUA_IMPACTO) < 0.01, "%.3f" % (sim.volumen_total() - v0))
	_ok("3 y emite impacto con el elemento y el radio por defecto", impactos.size() == 1 and impactos[0][1] == "agua" and absf(impactos[0][2] - Terreno3D.casilla * ReaccionesAgua3D.RADIO_HIELO) < 1.0e-4, "%s" % [impactos])
	v0 = sim.volumen_total()
	w.aplicar(AccionElemental.nueva("agua", p, 0.0, 0.5))
	_ok("3 la cantidad de la acción manda sobre la de siempre", absf(sim.volumen_total() - v0 - 0.5) < 0.01, "%.3f" % (sim.volumen_total() - v0))
	# Manantial: duración > 0 → caudal mientras dura, y no cuenta como impacto.
	impactos.clear()
	var c := Vector2i(3, 3)
	var q0: float = _caudal(sim, c)
	Mundo3D.aplicar_accion(AccionElemental.nueva("agua", p, 0.0, 1.0, 0.3))
	var durante: float = _caudal(sim, c)
	_ok("4 con duración es un manantial (caudal sumado)", absf(durante - q0 - 1.0) < 1.0e-4, "%.3f → %.3f" % [q0, durante])
	_ok("4 un chorro no emite un impacto por casilla", impactos.is_empty())
	await create_timer(0.5).timeout
	var despues: float = _caudal(sim, c)
	_ok("4 al acabar la duración lo retira", absf(despues - q0) < 1.0e-4, "%.3f" % despues)
	# Fuego: evapora `cantidad`.
	for _i in range(60 * 2):
		sim.paso(1.0 / 60.0)
	var pa: Vector3 = Terreno3D.centro_de(Vector2i(2, 2))
	var antes: float = sim.volumen_total()
	_efectos.clear()
	ReaccionesAgua3D.aplicar(AccionElemental.nueva("fuego", pa, 0.0, 0.05))
	var quitado: float = antes - sim.volumen_total()
	_ok("5 fuego con cantidad 0,05 quita como mucho 0,05", quitado > 0.0 and quitado <= 0.05 + 1.0e-4, "%.4f" % quitado)
	_ok("5 pide siempre «hielo_cambios» al terminar", _efectos.back()[0] == "hielo_cambios")
	# Hielo: avisa desde dónde, y si heló, atrapar.
	_efectos.clear()
	ReaccionesAgua3D.aplicar(AccionElemental.nueva("hielo", pa))
	var nombres: Array = _efectos.map(func(e: Array) -> String: return e[0])
	_ok("6 hielo: hielo_desde → hielo_formado → hielo_cambios (en ese orden)", nombres == ["hielo_desde", "hielo_formado", "hielo_cambios"], "%s" % [nombres])
	_ok("6 hielo_formado lleva radio y duración", _efectos[1][1] == true and absf(_efectos[1][2] - AguaSim3D.DURA_HIELO) < 1.0e-4)
	_ok("6 la simulación heló la casilla", sim.casilla_helada(Vector2i(2, 2)))
	# Fuera de mapa y casilla con tierra: nada.
	_efectos.clear()
	ReaccionesAgua3D.aplicar(AccionElemental.nueva("agua", Vector3(-50, 0, -50)))
	Terreno3D.fijar_altura(Vector2i(4, 4), 1)
	ReaccionesAgua3D.aplicar(AccionElemental.nueva("fuego", Terreno3D.centro_de(Vector2i(4, 4))))
	_ok("7 fuera del mapa o bajo tierra no pasa nada (ni siquiera efectos)", _efectos.is_empty())
	# Los reenvíos de Lanzador3D siguen valiendo.
	ReaccionesAgua3D.efecto = Callable()
	_ok("8 constantes reenviadas", Lanzador3D.VOL_AGUA_IMPACTO == ReaccionesAgua3D.VOL_AGUA_IMPACTO and Lanzador3D.VOL_EVAPORA == ReaccionesAgua3D.VOL_EVAPORA and Lanzador3D.RADIO_HIELO == ReaccionesAgua3D.RADIO_HIELO)
	v0 = sim.volumen_total()
	Lanzador3D.hechizo_sobre_agua("agua", Terreno3D.centro_de(Vector2i(1, 3)))
	_ok("8 Lanzador3D.hechizo_sobre_agua sigue funcionando (reenvío)", sim.volumen_total() > v0 + 0.1)
	w.queue_free()
	m.queue_free()
