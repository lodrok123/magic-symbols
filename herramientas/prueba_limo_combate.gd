extends "res://herramientas/escenario_base.gd"
## E1 · LIMO ELEMENTAL (28/10; reglas de Pablo; enemigos/limo_3d.gd). Sobre la escena real del Bosque, con hechizos lanzados por el camino de verdad (`Lanzador3D.lanzar_ahora`):
##   · sin teñir, el primer elemento lo TIÑE (sin daño); su elemento otra vez lo hace GRANDE (salta un 30 % más, pega el doble); grande, su elemento solo lo CURA; otro elemento le hace daño;
##   · la previsión del indicador (A2/A3) lo dice antes: «tine», «crece», «cura»;
##   · también se tiñe de lo que pisa (casilla mojada), y crece al ENTRAR en su elemento, no por quedarse; en la llama de su elemento no se quema;
##   · persigue a brincos, avisa (C3) y su acometida hace 15 (30 de grande) con un retroceso leve; se hunde en el agua honda; el golpe F le hace daño.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_limo_combate.gd

const FILA: int = 33
var _comprobaciones: int = 0
var _creados: Array = []
var _vida_min: float = 0.0      ## la vida más baja del limo mientras volaba y llegaba la última flecha


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _limo(c: Vector2i, elemento: String = "", grande: bool = false, quieto: bool = true) -> Limo3D:
	var l: Limo3D = Limo3D.crear(maqueta, _pos(c), elemento, grande)
	l.quieto = quieto
	_creados.append(l)
	return l


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()


func _jugadora(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1000.0
	j._t_inv = 0.0
	j._empuje = Vector3.ZERO


func _preparar(c: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	_jugadora(c)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _lanzar(datos: Dictionary, dir: Vector3, origen: Vector3 = Vector3.INF) -> bool:
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(datos, jugador.position if origen == Vector3.INF else origen, dir)


## La reacción que la previsión pinta para `l` con lo preparado (o «» si no hay entrada).
func _prevista(datos: Dictionary, l: Limo3D, dir: Vector3) -> String:
	for e in PrevisionHechizo.prever(lanzador, datos, jugador.position, dir):
		if e["nodo"] == l:
			return String(e["reaccion"])
	return ""


## Prepara `elemento + flecha` desde (11, FILA), comprueba la previsión, lo lanza al oeste y espera a que llegue.
func _flecha(l: Limo3D, elemento: String, esperado: String, nombre: String) -> void:
	var oeste := Vector3(-1, 0, 0)
	var d: Dictionary = _preparar(Vector2i(11, FILA), elemento, ["flecha"])
	var prev: String = _prevista(d, l, oeste)
	if esperado != "":
		_ok("%s: la previsión dice «%s»" % [nombre, esperado], prev == esperado, "dice «%s»" % prev)
	_lanzar(d, oeste)
	_vida_min = l.health
	var t: float = 0.0
	while t < 1.0:
		t += await avanzar_s(1.0 / 30.0)
		_vida_min = minf(_vida_min, l.health)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(20)
	await _caso_elementos()
	await _caso_suelo()
	await _caso_llama_propia()
	await _caso_persigue_y_acomete()
	await _caso_grande_pega_doble()
	await _caso_agua_honda()
	await _caso_golpe_f()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso_elementos() -> void:
	var l: Limo3D = _limo(Vector2i(10, FILA))
	await avanzar(3)
	_ok("1 nace sin teñir, normal y con 60 de vida", l.elemento == "" and not l.grande and is_equal_approx(l.health, Limo3D.VIDA) and l.cuerpo != null)
	_ok("1 es un Combate3D del grupo de enemigos (vigía, previsión, tinta)", l is Combate3D and l.is_in_group("combate3d"))
	await _flecha(l, "fuego", "tine", "2 fuego sin teñir")
	_ok("2 el fuego lo tiñe de fuego", l.elemento == "fuego" and l.cuerpo.elemento == "fuego", l.elemento)
	_ok("2 teñirse no le hace daño ni lo prende", is_equal_approx(l.health, Limo3D.VIDA) and l.quemando <= 0.0, "vida %.1f · quemando %.1f" % [l.health, l.quemando])
	var alcance0: float = l.alcance_acometida()
	await _flecha(l, "fuego", "crece", "3 fuego otra vez")
	_ok("3 su elemento otra vez lo hace GRANDE", l.grande and l.cuerpo.tamano >= LimoVisual3D.TAMANO_GRANDE - 0.01)
	_ok("3 crecer no le hace daño", is_equal_approx(l.health, Limo3D.VIDA), "vida %.1f" % l.health)
	_ok("3 grande pega el doble (30)", is_equal_approx(l.dano_golpe(), 30.0), str(l.dano_golpe()))
	_ok("3 grande salta un 30 % más lejos", is_equal_approx(l.alcance_acometida(), alcance0 * 1.3), "%.2f → %.2f" % [alcance0, l.alcance_acometida()])
	_ok("3 y es más alto (la barra sube con él)", l.altura > LimoVisual3D.ALTO * 1.5)
	await _flecha(l, "rayo", "", "4 rayo")
	_ok("4 otro elemento (rayo) le hace daño", _vida_min < Limo3D.VIDA - 1.0, "vida mínima %.1f" % _vida_min)
	_ok("4 y no cambia su tinte", l.elemento == "fuego")
	await avanzar_s(3.0)                               # que se apaguen las llamas de su flecha (sobre ellas, grande, se cura solo)
	l.health = 30.0
	var herido: float = l.health
	await _flecha(l, "fuego", "cura", "5 fuego al grande")
	_ok("5 grande, su elemento solo lo CURA (al menos CURA_MIN)", l.health >= herido + Limo3D.CURA_MIN - 0.01 and _vida_min >= herido - 0.01 and l.grande, "%.1f → %.1f" % [herido, l.health])
	var abs: Array = l.absorciones.map(func(a: Dictionary) -> String: return String(a["accion"]))
	_ok("5 el registro de absorciones es tiñe, crece, cura", abs == ["tine", "crece", "cura"], str(abs))
	_limpiar()
	await avanzar(3)


func _caso_suelo() -> void:
	var limpia := Vector2i(12, FILA - 2)
	var mojada := Vector2i(12, FILA)
	var mojada2 := Vector2i(10, FILA)
	for c in [limpia, mojada, mojada2]:
		for est in EstadosSuelo3D.TODOS:
			Terreno3D.estados.poner(c, est, false)
	var l: Limo3D = _limo(mojada)
	Terreno3D.estados.poner(mojada, EstadosSuelo3D.MOJADA, true)
	await avanzar_s(0.5)
	_ok("6 sobre una casilla mojada se tiñe de agua", l.elemento == "agua", "«%s»" % l.elemento)
	await avanzar_s(1.0)
	_ok("6 quedarse en su elemento NO lo hace crecer", not l.grande)
	l.position = _pos(limpia)
	await avanzar_s(0.5)
	Terreno3D.estados.poner(mojada2, EstadosSuelo3D.MOJADA, true)
	l.position = _pos(mojada2)
	await avanzar_s(0.5)
	_ok("6 salir y volver a ENTRAR en su elemento lo hace crecer", l.grande)
	var h0: float = 40.0
	l.health = h0
	await avanzar_s(2.0)
	_ok("6 grande y sobre su elemento, se cura poco a poco (%.1f → %.1f)" % [h0, l.health], l.health > h0 + 5.0)
	for c in [mojada, mojada2]:
		Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, false)
	_limpiar()
	await avanzar(3)


func _caso_llama_propia() -> void:
	var c := Vector2i(10, FILA)
	var l: Limo3D = _limo(c, "fuego")
	var d: Dictionary = _preparar(Vector2i(12, FILA), "fuego", ["barrera"])
	var lanzo: bool = _lanzar(d, Vector3(-1, 0, 0), l.position)
	_ok("7 se levanta una barrera de fuego sobre el limo de fuego", lanzo)
	var min_vida: float = l.health
	var t: float = 0.0
	while t < 3.0:
		t += await avanzar_s(0.1)
		min_vida = minf(min_vida, l.health)
	_ok("7 dentro de la llama de su elemento no pierde vida (mínimo %.1f)" % min_vida, min_vida >= Limo3D.VIDA - 0.01)
	_ok("7 ni arde", l.quemando <= 0.0)
	_ok("7 la llama, que le llega como golpe, lo hace crecer una vez", l.grande and l.absorciones.filter(func(a: Dictionary) -> bool: return a["accion"] == "crece").size() == 1,
		str(l.absorciones))
	_limpiar()
	await avanzar(3)
	# Sin teñir, la llama lo tiñe (y no lo quema).
	var l2: Limo3D = _limo(c)
	d = _preparar(Vector2i(12, FILA), "fuego", ["barrera"])
	_lanzar(d, Vector3(-1, 0, 0), l2.position)
	await avanzar_s(2.0)
	_ok("7 sin teñir, la llama lo tiñe de fuego sin quemarlo", l2.elemento == "fuego" and l2.health >= Limo3D.VIDA - 0.01 and not l2.grande,
		"«%s» · vida %.1f · grande %s" % [l2.elemento, l2.health, l2.grande])
	_limpiar()
	await avanzar(3)


func _caso_persigue_y_acomete() -> void:
	_jugadora(Vector2i(9, FILA))
	var l: Limo3D = _limo(Vector2i(12, FILA), "", false, false)
	var d0: float = Vector2(l.position.x - jugador.position.x, l.position.z - jugador.position.z).length()
	var a: AvisoAtaque3D = null
	var t: float = 0.0
	while t < 8.0 and a == null:
		t += await avanzar_s(1.0 / 30.0)
		for n in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (n as AvisoAtaque3D).dueno == l:
				a = n
	var d1: float = Vector2(l.position.x - jugador.position.x, l.position.z - jugador.position.z).length()
	_ok("8 la ve y se acerca a brincos (%.1f u → %.1f u)" % [d0, d1], d1 < d0 - 0.5)
	_ok("8 antes de la acometida marca dónde caerá (C3)", a != null and a.forma == "circulo" and is_equal_approx(a.radio, l.radio_golpe()))
	if a == null:
		_limpiar()
		return
	_ok("8 el aviso sale ≥ 0,4 s antes (%.2f s)" % a.t_impacto, a.t_impacto >= AvisoAtaque3D.T_MIN)
	var j: Jugador3D = jugador as Jugador3D
	var v0: float = j.vida
	var p0: Vector3 = j.position
	var t_aviso: float = a.t_impacto
	var ta: float = a.t
	t = 0.0
	while t < 3.0 and j.vida >= v0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("8 la acometida le hace 15", is_equal_approx(v0 - j.vida, Limo3D.DANO), "%.1f" % (v0 - j.vida))
	_ok("8 el golpe cae al aterrizar, cuando acaba el aviso (%.2f vs %.2f)" % [ta + t, t_aviso], absf(ta + t - t_aviso) <= 0.1)
	await avanzar_s(0.6)
	var movida: float = Vector2(j.position.x - p0.x, j.position.z - p0.z).length()
	_ok("8 y un retroceso leve (%.2f u)" % movida, movida > 0.1 and movida < 1.5)
	_ok("8 cuenta la acometida y el golpe", l.acometidas >= 1 and l.golpes_dados >= 1)
	_limpiar()
	await avanzar(3)


func _caso_grande_pega_doble() -> void:
	_jugadora(Vector2i(9, FILA))
	var l: Limo3D = _limo(Vector2i(11, FILA), "agua", true, false)
	_ok("9 nace grande y teñido (pieza `limo elemento=agua grande=si`)", l.grande and l.elemento == "agua")
	var j: Jugador3D = jugador as Jugador3D
	var v0: float = j.vida
	var t: float = 0.0
	while t < 8.0 and j.vida >= v0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("9 la acometida del grande hace 30", is_equal_approx(v0 - j.vida, 30.0), "%.1f" % (v0 - j.vida))
	_limpiar()
	await avanzar(3)


func _caso_agua_honda() -> void:
	var l: Limo3D = _limo(Vector2i(8, 31))
	_ok("10 junto al agua honda (7,31)", Terreno3D.es_agua(Vector2i(7, 31)))
	var hundidos: Array = []
	l.hundido.connect(func(e: Combate3D) -> void: hundidos.append(e))
	l.push(Vector3(-1, 0, 0), 1500.0)
	await avanzar_s(1.0)
	_ok("10 empujado al agua honda, se hunde", not is_instance_valid(l) or l.se_hundio, "hundidos %d" % hundidos.size())
	_ok("10 y avisa «hundido» (tinta por reacción)", hundidos.size() == 1)
	_limpiar()
	await avanzar(3)


func _caso_golpe_f() -> void:
	var l: Limo3D = _limo(Vector2i(10, FILA), "fuego")
	var r: Dictionary = l.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 600.0)
	_ok("11 el golpe F le hace su daño plano aunque esté teñido", is_equal_approx(float(r["dano"]), 5.0) and is_equal_approx(l.health, Limo3D.VIDA - 5.0), str(r))
	_limpiar()
	await avanzar(3)
