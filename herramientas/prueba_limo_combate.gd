extends "res://herramientas/escenario_base.gd"
## E1 · LIMO ELEMENTAL (28/10; reglas de Pablo; enemigos/limo_3d.gd). Sobre la escena real del Bosque, con hechizos lanzados por el camino de verdad (`Lanzador3D.lanzar_ahora`):
##   · sin teñir, el primer elemento lo TIÑE (sin daño); su elemento otra vez lo hace GRANDE (salta un 30 % más, pega el doble); grande, su elemento solo lo CURA; otro elemento le hace daño;
##   · la previsión del indicador (A2/A3) lo dice antes: «tine», «crece», «cura»;
##   · también se tiñe de lo que pisa (casilla mojada), y crece al ENTRAR en su elemento, no por quedarse; en la llama de su elemento no se quema;
##   · persigue a brincos, avisa (C3) y su acometida hace 15 (30 de grande) con un retroceso leve; se hunde en el agua honda; el golpe F le hace daño.
##   · D3 (6/11/2026): el FUEGO lo divide (normal → 2 pequeños, grande → 2 normales, mitad de vida, mismo elemento; un pequeño muere; sin 2 casillas libres no se divide), el HIELO lo
##     vuelve un bloque empujable T_BLOQUE s (se empuja con viento, vuelve con su vida, cae al agua y muere hundido), su acometida lleva su elemento y la previsión dice «divide», «bloque», «muere».
##     El hielo y el agua vuelan en arco: a 1 casilla le pasan por encima a un limo bajo, así que se disparan desde 2.
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
func _flecha(l: Limo3D, elemento: String, esperado: String, nombre: String, desde: Vector2i = Vector2i(11, FILA)) -> void:
	var oeste := Vector3(-1, 0, 0)
	var d: Dictionary = _preparar(desde, elemento, ["flecha"])
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
	await _caso_divide()
	await _caso_pequeno()
	await _caso_sin_sitio()
	await _caso_bloque()
	await _caso_bloque_expira()
	await _caso_bloque_agua()
	await _caso_ataque_con_elemento()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso_elementos() -> void:
	var l: Limo3D = _limo(Vector2i(10, FILA))
	await avanzar(3)
	_ok("1 nace sin teñir, normal y con su vida máxima (30)", l.elemento == "" and not l.grande and is_equal_approx(l.health, Limo3D.VIDA) and l.cuerpo != null)
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
	# 29/10 (DANO_Y_TINTA): el rayo (55) mata de un golpe a un limo de 30; para medir que «le hace daño» se le da más vida un momento.
	l.vida_max = 200.0
	l.health = 200.0
	await _flecha(l, "rayo", "", "4 rayo")
	_ok("4 otro elemento (rayo) le hace daño", _vida_min < 199.0, "vida mínima %.1f" % _vida_min)
	l.vida_max = Limo3D.VIDA
	_ok("4 y no cambia su tinte", l.elemento == "fuego")
	await avanzar_s(3.0)                               # que se apaguen las llamas de su flecha (sobre ellas, grande, se cura solo)
	l.health = 10.0
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
	var h0: float = 15.0                                # 29/10 (DANO_Y_TINTA): su vida máxima es 30 (antes 60 y el test partía de 40)
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


## Limpia y espera a que se apaguen las llamas del hechizo anterior: un fuego que sigue en el suelo vuelve a golpear al limo de la prueba siguiente (y lo divide o lo mata antes de tiempo).
func _calmar() -> void:
	_limpiar()
	await avanzar_s(4.0)


## Cuenta cuántos limos vivos (no muertos, no divididos) hay en el grupo de enemigos.
func _vivos() -> Array:
	var r: Array = []
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Limo3D and not (n as Limo3D).muerto:
			r.append(n)
	return r


func _caso_divide() -> void:
	# D3 · el FUEGO divide al limo teñido de otro elemento: normal → 2 pequeños; grande → 2 normales; mitad de vida cada uno, mismo elemento.
	var l: Limo3D = _limo(Vector2i(10, FILA), "agua")
	l.health = 24.0
	await avanzar(3)
	var d: Dictionary = _preparar(Vector2i(11, FILA), "fuego", ["flecha"])
	_ok("12 normal de agua + fuego: la previsión dice «divide»", _prevista(d, l, Vector3(-1, 0, 0)) == "divide", "dice «%s»" % _prevista(d, l, Vector3(-1, 0, 0)))
	_lanzar(d, Vector3(-1, 0, 0))
	var t: float = 0.0
	while t < 1.5 and not l.se_dividio:
		t += await avanzar_s(1.0 / 30.0)
	_ok("12 el limo normal se divide (no muere: sin botín)", l.se_dividio and l.divisiones == 1 and l.botin_soltado.is_empty(), "se_dividio %s" % l.se_dividio)
	var hs: Array = l.hijos.filter(func(h: Variant) -> bool: return is_instance_valid(h))
	_creados.append_array(hs)
	_ok("12 deja %d pequeños" % Limo3D.N_HIJOS, hs.size() == Limo3D.N_HIJOS and hs.all(func(h: Limo3D) -> bool: return h.pequeno and not h.grande), "hijos %d" % hs.size())
	_ok("12 del mismo elemento (agua)", hs.all(func(h: Limo3D) -> bool: return h.elemento == "agua" and h.cuerpo.elemento == "agua"))
	_ok("12 con la mitad de la vida (máx %.1f · actual %.1f de 24)" % [Limo3D.VIDA * Limo3D.FRACCION_VIDA_HIJO, 24.0 * Limo3D.FRACCION_VIDA_HIJO],
		hs.all(func(h: Limo3D) -> bool: return is_equal_approx(h.vida_max, Limo3D.VIDA * 0.5) and is_equal_approx(h.health, 12.0)), str(hs.map(func(h: Limo3D) -> float: return h.health)))
	_ok("12 a escala 0,6 (cuerpo y cápsula más bajos)", hs.all(func(h: Limo3D) -> bool: return is_equal_approx(h.cuerpo.tamano, 0.6) and h.altura < LimoVisual3D.ALTO))
	var celdas: Array = hs.map(func(h: Limo3D) -> Vector2i: return Terreno3D.celda_de(h.position))
	_ok("12 en casillas distintas, adyacentes y libres", celdas.size() == 2 and celdas[0] != celdas[1] and celdas.all(func(c: Vector2i) -> bool: return absi(c.x - 10) <= 1 and absi(c.y - FILA) <= 1 and c != Vector2i(10, FILA)), str(celdas))
	_ok("12 están en el grupo de enemigos y el padre ya no", hs.all(func(h: Limo3D) -> bool: return h.is_in_group("combate3d")) and not l.is_in_group("combate3d"))
	await _calmar()
	# Grande de agua → dos normales.
	var g: Limo3D = _limo(Vector2i(10, FILA), "agua", true)
	await avanzar(3)
	d = _preparar(Vector2i(11, FILA), "fuego", ["flecha"])
	_ok("13 grande de agua + fuego: la previsión dice «divide»", _prevista(d, g, Vector3(-1, 0, 0)) == "divide")
	_lanzar(d, Vector3(-1, 0, 0))
	t = 0.0
	while t < 1.5 and not g.se_dividio:
		t += await avanzar_s(1.0 / 30.0)
	var ns: Array = g.hijos.filter(func(h: Variant) -> bool: return is_instance_valid(h))
	_creados.append_array(ns)
	_ok("13 el grande da dos NORMALES (ni grandes ni pequeños)", ns.size() == 2 and ns.all(func(h: Limo3D) -> bool: return not h.grande and not h.pequeno and is_equal_approx(h.cuerpo.tamano, 1.0)))
	_ok("13 con la mitad de la vida (15)", ns.all(func(h: Limo3D) -> bool: return is_equal_approx(h.vida_max, 15.0) and is_equal_approx(h.health, 15.0)), str(ns.map(func(h: Limo3D) -> float: return h.health)))
	await _calmar()


func _caso_pequeno() -> void:
	# Un pequeño (que no es de fuego) con fuego MUERE; con su elemento crece un escalón; pega la mitad.
	var p: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(10, FILA)), "fuego", false, true)
	p.quieto = true
	_creados.append(p)
	await avanzar(3)
	_ok("14 el pequeño pega la mitad (%.1f) y pesa menos" % p.dano_golpe(), is_equal_approx(p.dano_golpe(), Limo3D.DANO * Limo3D.MULT_DANO_PEQUENO) and p.masa < 0.6)
	var d: Dictionary = _preparar(Vector2i(11, FILA), "fuego", ["flecha"])
	_ok("14 el pequeño con su elemento: la previsión dice «crece»", _prevista(d, p, Vector3(-1, 0, 0)) == "crece")
	_lanzar(d, Vector3(-1, 0, 0))
	await avanzar_s(1.0)
	_ok("14 con su elemento sube un escalón (pequeño → normal, no grande)", not p.pequeno and not p.grande and is_equal_approx(p.cuerpo.tamano, 1.0), "pequeno %s grande %s tam %.2f" % [p.pequeno, p.grande, p.cuerpo.tamano])
	await _calmar()
	var q: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(10, FILA)), "agua", false, true)
	q.quieto = true
	_creados.append(q)
	await avanzar(3)
	d = _preparar(Vector2i(11, FILA), "fuego", ["flecha"])
	var prev: String = _prevista(d, q, Vector3(-1, 0, 0))
	_ok("15 pequeño de agua + fuego: la previsión dice «muere»", prev == "muere", "dice «%s»" % prev)
	var capt: Dictionary = {}
	q.tree_exiting.connect(func() -> void:       # el limo muerto se libera en el mismo fotograma: se lee justo antes
		capt["muerto"] = q.muerto
		capt["se_dividio"] = q.se_dividio
		capt["divisiones"] = q.divisiones
		capt["hijos"] = q.hijos.size()
		capt["muerte_el"] = q.muerte_el)
	_lanzar(d, Vector3(-1, 0, 0))
	var t: float = 0.0
	while t < 1.5 and capt.is_empty():
		t += await avanzar_s(1.0 / 30.0)
	_ok("15 el pequeño con fuego MUERE (no se divide más)", not capt.is_empty() and bool(capt["muerto"]) and not bool(capt["se_dividio"]) and int(capt["divisiones"]) == 0 and int(capt["hijos"]) == 0, str(capt))
	_ok("15 y muere de fuego (carbón/sonido de la variante)", String(capt.get("muerte_el", "")) == "fuego", str(capt))
	await _calmar()


func _caso_sin_sitio() -> void:
	# Rodeado (solo queda libre la casilla por donde llega la flecha: 1 < 2) no se divide y recibe el fuego de siempre.
	var c0 := Vector2i(10, FILA)
	var l: Limo3D = _limo(c0, "agua")
	var cercos: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var c := Vector2i(c0.x + dx, c0.y + dy)
			if c == c0 or c == Vector2i(c0.x + 1, c0.y):
				continue
			if Terreno3D.bloqueada(c):
				continue
			if c == Vector2i(c0.x - 1, c0.y):
				var b := BloqueEmpujable3D.new()                # al oeste, un bloque de verdad (`BloqueEmpujable3D.en`); la flecha no pasa por ahí
				b.name = "cerco_%d_%d" % [c.x, c.y]
				b.preparar(c, "piedra", maqueta)
				maqueta.add_child(b)
				cercos.append(b)
			else:
				Terreno3D.bloquear_celda(c)                     # el resto, casillas bloqueadas (sin cuerpo que desvíe la flecha, que es ancha)
				cercos.append(c)
	await avanzar(3)
	var libres: Array = l._celdas_para_hijos()
	_ok("16 con %d casillas tapadas solo queda %d libre (menos de 2)" % [cercos.size(), libres.size()], libres.size() < Limo3D.N_HIJOS, str(libres))
	# La flecha de fuego es ancha y los cercos de los lados la pararían: el golpe se da directo, con el mismo Hechizo que construye la flecha (`Hechizo.construir`).
	_jugadora(Vector2i(14, FILA))
	libres = l._celdas_para_hijos()
	_ok("16 con la jugadora lejos queda 1 casilla libre (la de levante): sigue siendo menos de 2", libres.size() == 1, str(libres))
	var h: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {})
	var prop: Array = l.prever_golpe(h, Vector3(-1, 0, 0))["reacciones_propias"]
	_ok("16 la previsión NO dice «divide»", not prop.has("divide") and l.accion_elemento("fuego") == "", str(prop))
	var v0: float = l.health
	l.golpe(h, Vector3(-1, 0, 0))
	await avanzar_s(0.3)
	_ok("16 sin sitio no se divide: sigue ahí, sin hijos", not l.se_dividio and l.divisiones == 0 and l.hijos.is_empty() and is_instance_valid(l))
	_ok("16 y recibe el daño normal del fuego (vida %.1f → %.1f)" % [v0, l.health], l.health < v0 - 0.5 or l.muerto)
	for b in cercos:
		if b is BloqueEmpujable3D:
			Terreno3D.liberar_celda((b as BloqueEmpujable3D).celda)
			(b as Node).queue_free()
		else:
			Terreno3D.liberar_celda(b as Vector2i)
	await _calmar()


func _caso_bloque() -> void:
	# D3 · el HIELO vuelve al limo teñido de otro elemento un bloque empujable: se empuja con viento, resbala, y a los T_BLOQUE s vuelve a ser limo con su vida.
	var c0 := Vector2i(10, FILA)
	var l: Limo3D = _limo(c0, "fuego")
	l.health = 22.0
	await avanzar(3)
	var d: Dictionary = _preparar(Vector2i(12, FILA), "hielo", ["flecha"])        # el hielo vuela en arco como el agua: a 1 casilla le pasa por encima a un limo bajo
	var prev: String = _prevista(d, l, Vector3(-1, 0, 0))
	_ok("17 limo de fuego + hielo: la previsión dice «bloque»", prev == "bloque", "dice «%s»" % prev)
	_lanzar(d, Vector3(-1, 0, 0))
	var t: float = 0.0
	while t < 1.5 and not l.en_bloque:
		t += await avanzar_s(1.0 / 30.0)
	_ok("17 el limo se congela en bloque", l.en_bloque and l.bloque != null and is_instance_valid(l.bloque))
	if not l.en_bloque or l.bloque == null:
		_limpiar()
		return
	var b: BloqueEmpujable3D = l.bloque
	_ok("17 es un BloqueEmpujable3D de hielo en su casilla, bloqueándola", b.material == "hielo" and b.celda == c0 and BloqueEmpujable3D.en(c0) == b and Terreno3D.bloqueada(c0) and b.is_in_group("empujable") and b.is_in_group("peso"))
	_ok("17 el limo ya no es un enemigo (fuera del grupo) y su cuerpo está helado", not l.is_in_group("combate3d") and l.cuerpo.esta_congelado() and l.collision_layer == 0)
	_ok("17 conserva su vida (22) y su elemento", is_equal_approx(l.health, 22.0) and l.elemento == "fuego", "vida %.1f" % l.health)
	# Viento desde el este: el bloque de hielo resbala hacia el oeste y el limo con él.
	await avanzar_s(0.5)
	d = _preparar(Vector2i(11, FILA), "viento", ["flecha"])
	_lanzar(d, Vector3(-1, 0, 0))
	await avanzar_s(2.0)
	_ok("18 el viento empuja el bloque (resbala al oeste desde la casilla %d hasta la %d)" % [c0.x, b.celda.x], b.celda.x < c0.x and b.empujones >= 1, "celda %s" % str(b.celda))
	var dist: float = Vector2(l.position.x - b.position.x, l.position.z - b.position.z).length()
	_ok("18 el limo y su cuerpo van con el bloque (%.2f u)" % dist, dist < 0.05 and Vector2(l.cuerpo.position.x - b.position.x, l.cuerpo.position.z - b.position.z).length() < 0.05)
	_ok("18 aún es bloque (vive T_BLOQUE = %.0f s)" % Limo3D.T_BLOQUE, l.en_bloque)
	_limpiar()
	await avanzar(3)


func _caso_bloque_expira() -> void:
	var c0 := Vector2i(10, FILA)
	var l: Limo3D = _limo(c0, "fuego")
	l.health = 22.0
	l.mojado = 0.0
	await avanzar(3)
	_ok("19 congelar_en_bloque", l.congelar_en_bloque())
	var t: float = 0.0
	while t < Limo3D.T_BLOQUE - 1.0:
		t += await avanzar_s(0.25)
	_ok("19 a %.0f s sigue siendo bloque" % t, l.en_bloque and is_instance_valid(l.bloque))
	while t < Limo3D.T_BLOQUE + 1.0 and l.en_bloque:
		t += await avanzar_s(0.25)
	_ok("19 a los T_BLOQUE s vuelve a ser limo (%.2f s)" % t, not l.en_bloque and t >= Limo3D.T_BLOQUE - 0.3 and t <= Limo3D.T_BLOQUE + 0.8)
	await avanzar(3)
	_ok("19 con la vida que tenía (22), su elemento y de nuevo enemigo", is_equal_approx(l.health, 22.0) and l.elemento == "fuego" and l.is_in_group("combate3d") and l.collision_layer == Lanzador3D.CAPA_REACTIVO and not l.cuerpo.esta_congelado(),
		"vida %.1f" % l.health)
	_ok("19 el bloque desaparece y deja libre la casilla", BloqueEmpujable3D.en(c0) == null and not Terreno3D.bloqueada(c0))
	_ok("19 y el limo reaparece en el centro de esa casilla", Terreno3D.celda_de(l.position) == c0)
	_limpiar()
	await avanzar(3)


func _caso_bloque_agua() -> void:
	# El bloque que resbala al agua honda se hunde y el limo muere hundido (tinta por «hundido»).
	var l: Limo3D = _limo(Vector2i(8, 31), "fuego")
	await avanzar(3)
	var hundidos: Array = []
	l.hundido.connect(func(e: Combate3D) -> void: hundidos.append(e))
	_ok("20 junto al agua honda (7,31)", Terreno3D.es_agua(Vector2i(7, 31)) and l.congelar_en_bloque())
	var b: BloqueEmpujable3D = l.bloque
	await avanzar_s(0.3)
	var d: Dictionary = _preparar(Vector2i(10, 31), "viento", ["flecha"])
	_lanzar(d, Vector3(-1, 0, 0))
	var capt: Dictionary = {}
	l.tree_exiting.connect(func() -> void:
		capt["muerto"] = l.muerto
		capt["se_hundio"] = l.se_hundio)
	var t: float = 0.0
	while t < 3.0 and capt.is_empty():
		t += await avanzar_s(1.0 / 30.0)
	await avanzar_s(0.5)
	_ok("20 el bloque cae al agua y el limo muere hundido", not capt.is_empty() and bool(capt["muerto"]) and bool(capt["se_hundio"]), str(capt))
	_ok("20 avisa «hundido» una vez (tinta por reacción)", hundidos.size() == 1, "hundidos %d" % hundidos.size())
	_ok("20 el bloque se va y no deja casillas bloqueadas", not is_instance_valid(b) or b.is_queued_for_deletion())
	await avanzar_s(1.5)
	_ok("20 (7,31) y (8,31) quedan libres", not Terreno3D.bloqueada(Vector2i(7, 31)) and not Terreno3D.bloqueada(Vector2i(8, 31)))
	_limpiar()
	await avanzar(3)


func _caso_ataque_con_elemento() -> void:
	# D3 · su acometida lleva su elemento. Jugadora sin `aplicar_estado`: el estado se pone en SU casilla (agua → mojada; la nota por el aguante y el calor).
	var cs: Array = []
	for x in range(6, 13):
		cs.append(Vector2i(x, FILA))
		for est in EstadosSuelo3D.TODOS:
			Terreno3D.estados.poner(Vector2i(x, FILA), est, false)
	_jugadora(Vector2i(9, FILA))
	var l: Limo3D = _limo(Vector2i(11, FILA), "agua", false, false)
	var j: Jugador3D = jugador as Jugador3D
	var v0: float = j.vida
	var t: float = 0.0
	while t < 8.0 and j.vida >= v0:
		t += await avanzar_s(1.0 / 30.0)
	var c: Vector2i = Terreno3D.celda_de(j.position)
	_ok("21 la acometida del limo de agua le hace daño", j.vida < v0)
	_ok("21 canal: la jugadora %s `aplicar_estado`" % ("tiene" if j.has_method("aplicar_estado") else "NO tiene (queda el gancho y el suelo)"), true)
	var ok_el: bool = (l.efecto_ataque == "estado") or (l.efecto_ataque == "suelo" and Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA))
	_ok("21 y le deja su elemento (efecto «%s», casilla %s mojada: %s)" % [l.efecto_ataque, str(c), Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA)], ok_el)
	_limpiar()
	await avanzar(3)
	# Sin teñir no deja nada.
	for x in range(6, 13):
		for est in EstadosSuelo3D.TODOS:
			Terreno3D.estados.poner(Vector2i(x, FILA), est, false)
	_jugadora(Vector2i(9, FILA))
	var n: Limo3D = _limo(Vector2i(11, FILA), "", false, false)
	v0 = j.vida
	t = 0.0
	while t < 8.0 and j.vida >= v0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("22 sin teñir, su acometida no deja ningún elemento", j.vida < v0 and n.efecto_ataque == "" and Terreno3D.estados.cuantas(EstadosSuelo3D.MOJADA) == 0)
	_limpiar()
	await avanzar(3)


func _caso_golpe_f() -> void:
	var l: Limo3D = _limo(Vector2i(10, FILA), "fuego")
	var r: Dictionary = l.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 600.0)
	_ok("11 el golpe F le hace su daño plano aunque esté teñido", is_equal_approx(float(r["dano"]), 5.0) and is_equal_approx(l.health, Limo3D.VIDA - 5.0), str(r))
	_limpiar()
	await avanzar(3)
