extends SceneTree
## C2 «tinta por reacción» (28/10): +20 de tinta por cada COMBO provocado contra un enemigo. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_tinta_reaccion.gd
## Enemigos reales (Combate3D) en un mundo con agua honda; cada reacción se provoca por el camino real (golpe de hechizo, empujón al agua, escudo que se quema).
##   1. Cada reacción de la lista da +20: hundido, electrocutado mojado, congelado, mano quemada, apagado.
##   2. La misma reacción en el mismo enemigo no vuelve a dar; en OTRO enemigo sí.
##   3. No dan: el golpe simple, el quemado normal, el rayo sin mojar, el mojado, el empujón que no hunde.
##   4. El muñeco (grupo «muneco» o `premia_tinta` false) no da.
##   5. Nunca pasa de la tinta máxima, y con la barra llena el premio no se gasta.
##   6. Mano quemada con el escudo real; el escudo roto a golpes no da.
##   7. Evento `tinta_reaccion` en el PlayLog.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const COL_AGUA: Array = [6, 7]
const Y_FILAS: Array = [3, 4, 5, 6, 7, 8]

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _tinta: Tinta = null
var _fallos: int = 0
var _senales: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_combos()
	_topes()
	_no_cuentan()
	_muneco()
	_maximo()
	await _mano()
	_diario()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			elif COL_AGUA.has(x) and Y_FILAS.has(y):
				f += "~"
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 12.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	_tinta = Tinta.new()
	_tinta.reaccion_premiada.connect(func(t: String, c: float) -> void: _senales.append([t, c]))
	var det: TintaReaccion = TintaReaccion.conectar(_mundo, _tinta)
	var escuchas: int = 0
	for c in _mundo.reaccion.get_connections():
		if (c["callable"] as Callable).get_object() == det:
			escuchas += 1
	_ok("0 el detector cuelga del mundo y volver a conectar no lo duplica", TintaReaccion.conectar(_mundo, _tinta) == det and escuchas == 1, "escuchas %d" % escuchas)


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


func _nuevo(p: Vector3) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	return g


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		if is_instance_valid(g):
			g._physics_process(DT)


func _vaciar() -> void:
	_tinta.actual = 0.0
	_senales.clear()


## Tinta que sube al hacer `f.call()`.
func _delta(f: Callable) -> float:
	var antes: float = _tinta.actual
	f.call()
	return _tinta.actual - antes


func _hundir(g: Combate3D) -> void:
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g, 120)


func _combos() -> void:
	_vaciar()
	var g := _nuevo(_suelo(3, 2))
	g.golpe(_h("water"), Vector3.ZERO)
	_ok("1.1 electrocutado: rayo sobre un enemigo MOJADO da +20", is_equal_approx(_delta(func() -> void: g.golpe(_h("lightning"), Vector3.ZERO)), 20.0))
	var g2 := _nuevo(_suelo(3, 4))
	_ok("1.2 congelado: el hielo que lo deja preso da +20", is_equal_approx(_delta(func() -> void: g2.golpe(_h("ice"), Vector3.ZERO)), 20.0) and g2.congelado > 0.0)
	var g3 := _nuevo(_suelo(3, 6))
	g3.golpe(_h("fire"), Vector3.ZERO)
	_ok("1.3 (control) el fuego que lo quema no ha dado nada nuevo", is_equal_approx(_tinta.actual, 40.0) and g3.quemando > 0.0, "%.1f" % _tinta.actual)
	_ok("1.4 apagado: agua a un enemigo que arde da +20", is_equal_approx(_delta(func() -> void: g3.golpe(_h("water"), Vector3.ZERO)), 20.0) and g3.quemando <= 0.0)
	var g4 := _nuevo(Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S))
	_ok("1.5 hundido: empujado al agua honda da +20", is_equal_approx(_delta(func() -> void: _hundir(g4)), 20.0) and g4.se_hundio)
	var tipos: Array = []
	var todas20: bool = true
	for s in _senales:
		tipos.append(s[0])
		todas20 = todas20 and is_equal_approx(s[1], 20.0)
	_ok("1.6 cada una avisó con su tipo y 20", tipos == ["electrocutado", "congelado", "apagado", "hundido"] and todas20, str(_senales))


func _topes() -> void:
	_vaciar()
	var a := _nuevo(_suelo(2, 10))
	var b := _nuevo(_suelo(4, 10))
	a.golpe(_h("ice"), Vector3.ZERO)
	_ok("2.1 primer congelado de A: +20", is_equal_approx(_tinta.actual, 20.0))
	a.congelado = 0.0
	a.golpe(_h("ice"), Vector3.ZERO)
	_ok("2.2 el mismo congelado en el mismo enemigo NO vuelve a dar", is_equal_approx(_tinta.actual, 20.0), "%.1f" % _tinta.actual)
	b.golpe(_h("ice"), Vector3.ZERO)
	_ok("2.3 el mismo tipo en OTRO enemigo sí da", is_equal_approx(_tinta.actual, 40.0), "%.1f" % _tinta.actual)
	a.golpe(_h("water"), Vector3.ZERO)
	a.golpe(_h("lightning"), Vector3.ZERO)
	_ok("2.4 otro tipo (electrocutado) en A sí da", is_equal_approx(_tinta.actual, 60.0), "%.1f" % _tinta.actual)
	a.golpe(_h("lightning"), Vector3.ZERO)
	_ok("2.5 y no se repite", is_equal_approx(_tinta.actual, 60.0))
	var t2 := Tinta.new()
	t2.actual = 0.0
	t2.premiar_reaccion(a, "congelado")
	_ok("2.6 la marca vive en el enemigo: otra Tinta tampoco repite", is_equal_approx(t2.actual, 0.0))


func _no_cuentan() -> void:
	_vaciar()
	var g := _nuevo(_suelo(2, 12))
	g.golpe(_h("earth"), Vector3.ZERO)
	g.golpe(_h("fire"), Vector3.ZERO)
	_ok("3.1 un golpe simple y un quemado normal NO dan", is_equal_approx(_tinta.actual, 0.0) and g.quemando > 0.0, "%.1f" % _tinta.actual)
	var h := _nuevo(_suelo(4, 12))
	h.golpe(_h("lightning"), Vector3.ZERO)
	_ok("3.2 el rayo sobre un enemigo SECO no da", is_equal_approx(_tinta.actual, 0.0))
	h.golpe(_h("water"), Vector3.ZERO)
	_ok("3.3 mojarlo no da", is_equal_approx(_tinta.actual, 0.0))
	h.golpe(_h("wind"), Vector3(1, 0, 0))
	_ok("3.4 un empujón suelto de viento no da", is_equal_approx(_tinta.actual, 0.0))
	var corto := _nuevo(Vector3(3.0 * S, Terreno3D.alto_suelo, 5.5 * S))
	corto.push(Vector3(1, 0, 0), 60.0, true)
	_pasos(corto, 60)
	_ok("3.5 un empujón que no llega al agua no da", is_equal_approx(_tinta.actual, 0.0) and not corto.muerto)
	_ok("3.6 un tipo no premiado o un nulo no dan", is_equal_approx(_tinta.premiar_reaccion(h, "empujado"), 0.0) and is_equal_approx(_tinta.premiar_reaccion(null, "hundido"), 0.0))
	_ok("3.7 sin señales de premio", _senales.is_empty(), str(_senales))


func _muneco() -> void:
	_vaciar()
	var m := _nuevo(_suelo(9, 4))
	m.add_to_group("muneco")
	m.golpe(_h("ice"), Vector3.ZERO)
	_ok("4.1 el muñeco (grupo «muneco») no da", is_equal_approx(_tinta.actual, 0.0))
	var d := _nuevo(_suelo(9, 6))
	d.premia_tinta = false
	d.golpe(_h("ice"), Vector3.ZERO)
	_ok("4.2 la diana con `premia_tinta` false no da", is_equal_approx(_tinta.actual, 0.0))
	var g := _nuevo(_suelo(9, 8))
	g.golpe(_h("ice"), Vector3.ZERO)
	_ok("4.3 (control) un enemigo normal sí", is_equal_approx(_tinta.actual, 20.0))


func _maximo() -> void:
	_vaciar()
	_tinta.actual = _tinta.maxima - 5.0
	var g := _nuevo(_suelo(11, 10))
	g.golpe(_h("ice"), Vector3.ZERO)
	_ok("5.1 no pasa del máximo (quedaban 5: sube 5)", is_equal_approx(_tinta.actual, _tinta.maxima) and not _senales.is_empty() and is_equal_approx(_senales[0][1], 5.0), str(_senales))
	var h := _nuevo(_suelo(11, 12))
	var frascos: int = _tinta.frascos
	h.golpe(_h("ice"), Vector3.ZERO)
	_ok("5.2 con la barra llena no hay premio ni se gasta: ni frascos ni pasa del máximo", is_equal_approx(_tinta.actual, _tinta.maxima) and _tinta.frascos == frascos
		and not h.has_meta("tinta_reaccion_congelado"))
	_tinta.actual = 0.0
	h.congelado = 0.0
	h.golpe(_h("ice"), Vector3.ZERO)
	_ok("5.3 y queda disponible para cuando haya hueco", is_equal_approx(_tinta.actual, 20.0))


func _mano() -> void:
	_vaciar()
	var g := _nuevo(_suelo(9, 10))
	var e: Escudo3D = Escudo3D.equipar(g, false)
	e.prender()
	e.arde_t = 0.01
	for _i in 4:
		await process_frame
	_ok("6.1 mano quemada: el escudo se consume ardiendo y da +20", is_equal_approx(_tinta.actual, 20.0) and e.estado == "quemado" and g.stun_timer > 0.5,
		"%.1f estado=%s stun=%.2f" % [_tinta.actual, e.estado, g.stun_timer])
	_ok("6.2 avisó con tipo «mano_quemada»", _senales.size() == 1 and _senales[0][0] == "mano_quemada", str(_senales))
	var h := _nuevo(_suelo(9, 12))
	var e2: Escudo3D = Escudo3D.equipar(h, false)
	e2._consumir("roto")
	_ok("6.3 un escudo roto a golpes (sin quemar) no da", is_equal_approx(_tinta.actual, 20.0))


func _diario() -> void:
	PlayLog.event("sonda_c2", {})
	var f: FileAccess = PlayLog._file
	var ruta: String = f.get_path() if f != null else ""
	var texto: String = FileAccess.get_file_as_string(ruta) if ruta != "" else ""
	_ok("7.1 el PlayLog apunta «tinta_reaccion» con tipo y enemigo", texto.contains("\"evento\":\"tinta_reaccion\"") and texto.contains("\"tipo\":\"hundido\"") and texto.contains("\"enemigo\":"),
		ruta)
	_ok("7.2 la constante vale 20 y hay 5 tipos premiados", is_equal_approx(Tinta.TINTA_POR_REACCION, 20.0) and Tinta.REACCIONES_PREMIADAS.size() == 5)
