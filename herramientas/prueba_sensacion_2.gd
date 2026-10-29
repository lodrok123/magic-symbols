extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, LOTE 2 (29/10; presentacion/sensacion_3d.gd). Sobre la escena real del Bosque:
##   1 ARRANQUE del proyectil: la curva sale a 1,8×, no baja de 0,75× y suma lo mismo que sin arranque; en vuelo de verdad el proyectil va más rápido al salir, se
##     estira, deja estela y, pasado el arranque, ha recorrido lo mismo que con la sensación apagada;
##   2 POLVO: un goblin empujado levanta polvo al salir y otra vez al caer del vuelo; la jugadora empujada también;
##   3 ESQUIVA PERFECTA: rodar en la ventana de un aviso pone el filtro violeta, deja copias y suena el tic; al acabar el tiempo bruja se va todo y el tiempo vuelve a 1;
##   4 MUERTE: temblor al caer uno; si era el último de la sala, cámara lenta que vuelve sola a 1 (y no si el tiempo ya era de otro); el oro SALTA y se IMANTA hacia ella;
##   5 REACCIONES grandes: el rayo sobre mojado («¡Descarga!») y el fuego sobre mojado («¡Vapor!»): rótulo grande, hitstop de todos y su sonido;
##   6 con la sensación apagada, nada de esto: sin cámara lenta, el oro aparece en su sitio y no hay reacción grande.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sensacion_2.gd

var _comprobaciones: int = 0
var _creados: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i, quieto: bool = true, vida: float = 100000.0) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.quieto = quieto
	g.position = p
	g.casa = p
	g.health = vida
	g.vida_max = vida
	g.debil = ""
	g.resiste = ""
	g.oro = 0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if lista is Array and n is Pj3D:
				(lista as Array).erase(n)
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()
	Engine.time_scale = 1.0


## Quita de en medio a los enemigos del nivel (están lejos, pero así «el último de la sala» depende solo de los de la prueba).
func _vaciar_nivel() -> void:
	for n in get_nodes_in_group("combate3d"):
		if not _creados.has(n):
			(n as Node).remove_from_group("combate3d")
			(n as Node).queue_free()


func _pagina(elemento: String, glifos: Array) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()


func _jugadora(c: Vector2i) -> Jugador3D:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._t_hitstop = 0.0
	j._empuje = Vector3.ZERO
	return j


func _hechizos(n: Node, lista: Array = []) -> Array:
	for c in n.get_children():
		if c is HechizoVivo and (c as HechizoVivo).activo:
			lista.append(c)
		_hechizos(c, lista)
	return lista


func _etiquetas() -> Array:
	return maqueta.get_children().filter(func(n): return n is Label3D)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	_caso_curva()
	await _caso_arranque()
	await _caso_polvo()
	await _caso_esquiva()
	await _caso_muerte()
	await _caso_reacciones()
	await _caso_apagada()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- 1 · arranque ------------------------------------------------------------------------------------------------------

func _caso_curva() -> void:
	var t_a: float = Sensacion3D.T_ARRANQUE
	_ok("1 la curva sale a 1 + ARRANQUE", is_equal_approx(Sensacion3D.factor_arranque(0.0), 1.0 + Sensacion3D.ARRANQUE))
	_ok("1 y acaba en 1 (a T_ARRANQUE y después)", is_equal_approx(Sensacion3D.factor_arranque(t_a), 1.0) and is_equal_approx(Sensacion3D.factor_arranque(5.0), 1.0))
	var suma: float = 0.0
	var minimo: float = 9.0
	var n: int = 3000
	for i in n:
		var f: float = Sensacion3D.factor_arranque((float(i) + 0.5) / float(n) * t_a)
		suma += f * t_a / float(n)
		minimo = minf(minimo, f)
	_ok("1 suma lo mismo que sin arranque (%.4f s de %.4f)" % [suma, t_a], absf(suma - t_a) < 0.001)
	_ok("1 frena sin pararse (mínimo %.2f)" % minimo, minimo > 0.55 and minimo < 0.8)
	var b: Basis = Sensacion3D.base_estirada(Vector3(1, 0, 0), 1.5, 1.0)
	_ok("1 el estirón alarga en la dirección del vuelo y conserva el volumen", is_equal_approx(b.x.length(), 1.5) and absf(b.determinant() - 1.0) < 0.001, str(b))


## Lanza una flecha de fuego al este y devuelve [velocidad en el primer fotograma (u/s), recorrido a 0,6 s, estirón máximo, nº de bolas de estela].
func _vuelo() -> Array:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	_pagina("fuego", ["flecha"])
	var ya: Array = _hechizos(maqueta)
	lanzador.lanzar_pagina_ya(0, j.position, Vector3(1, 0, 0))
	var hv: HechizoVivo = null
	var t: float = 0.0
	while hv == null and t < 1.0:
		t += await avanzar_s(1.0 / 30.0)
		for h in _hechizos(maqueta):
			if not ya.has(h):
				hv = h
	if hv == null:
		return [0.0, 0.0, 1.0, 0]
	var r0: float = hv.recorrido
	await avanzar(1)
	var v1: float = (hv.recorrido - r0) * 30.0 if is_instance_valid(hv) else 0.0
	var est_max: float = 1.0
	var estela0: int = int(Sensacion3D.cuenta["estela"])
	var rec: float = 0.0
	for i in 21:                     # 0,7 s de fotogramas reales (la `edad` del hechizo ya va con el arranque: no sirve de reloj aquí)
		if not is_instance_valid(hv) or not hv.activo:
			break
		for c in hv.get_children():
			if c is VfxElemento3D.Proyectil:
				est_max = maxf(est_max, (c as VfxElemento3D.Proyectil).estiron_ahora)
		rec = hv.recorrido
		await avanzar(1)
	await avanzar_s(1.5)
	return [v1, rec, est_max, int(Sensacion3D.cuenta["estela"]) - estela0]


func _caso_arranque() -> void:
	var con: Array = await _vuelo()
	Sensacion3D.ACTIVA = false
	var sin: Array = await _vuelo()
	Sensacion3D.ACTIVA = true
	_ok("1 en vuelo sale más rápido que a su velocidad (%.1f u/s vs %.1f)" % [con[0], sin[0]], float(con[0]) > float(sin[0]) * 1.3, str([con, sin]))
	_ok("1 y se estira (máx %.2f)" % float(con[2]), float(con[2]) > 1.25)
	_ok("1 deja estela al salir (%d bolas)" % int(con[3]), int(con[3]) >= 2)
	_ok("1 apagada: ni estirón ni estela", is_equal_approx(float(sin[2]), 1.0) and int(sin[3]) == 0)
	_ok("1 pasado el arranque ha recorrido lo mismo (%.2f u vs %.2f)" % [con[1], sin[1]], absf(float(con[1]) - float(sin[1])) < 0.25)


# --- 2 · polvo ---------------------------------------------------------------------------------------------------------

func _caso_polvo() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(8, 33))
	await avanzar(3)
	var p0: int = int(Sensacion3D.cuenta["polvo"])
	g.push(Vector3(-1, 0, 0), 900.0, true)
	_ok("2 el goblin empujado levanta polvo al salir", int(Sensacion3D.cuenta["polvo"]) == p0 + 1)
	var vuela: bool = g._fase_empuje == Combate3D.FASE_VOLANDO
	await avanzar_s(maxf(g.pj.duracion("empujado") * 0.5, 0.1) + 0.2)
	_ok("2 y otra vez al caer del vuelo", not vuela or int(Sensacion3D.cuenta["polvo"]) >= p0 + 2, "vuela %s · %d" % [vuela, int(Sensacion3D.cuenta["polvo"]) - p0])
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(2)
	p0 = int(Sensacion3D.cuenta["polvo"])
	j.push(Vector3(1, 0, 0), 4.0)
	_ok("2 la jugadora empujada también", int(Sensacion3D.cuenta["polvo"]) == p0 + 1)
	j.push(Vector3(1, 0, 0), 0.5)
	_ok("2 un empujoncito (el retroceso de lanzar) no", int(Sensacion3D.cuenta["polvo"]) == p0 + 1)
	p0 = int(Sensacion3D.cuenta["polvo"])
	_ok("2 el mazazo del gólem: tres nubes de polvo (dos puños y el centro)", Sensacion3D.mazazo(j, j.position + Vector3(2, 0, 0), Vector3(1, 0, 0)) and int(Sensacion3D.cuenta["polvo"]) == p0 + 3)
	_limpiar()
	await avanzar_s(1.5)


# --- 3 · esquiva perfecta ----------------------------------------------------------------------------------------------

func _caso_esquiva() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	var av: AvisoAtaque3D = AvisoAtaque3D.circulo(maqueta, j.position, 1.5, 0.15, null)
	await avanzar(1)
	var e0: int = int(Sensacion3D.cuenta["esquiva"])
	var tic0: int = int(Sensacion3D.cuenta["tic"])
	j._iniciar_voltereta(Vector3(-1, 0, 0))
	_ok("3 rodar a tiempo abre el tiempo bruja y pide la esquiva vistosa", TiempoBruja.activa() and int(Sensacion3D.cuenta["esquiva"]) == e0 + 1)
	var ef: Node = j.get_node_or_null("EfectoBruja")
	_ok("3 cuelga el efecto de la jugadora y suena el tic", ef != null and int(Sensacion3D.cuenta["tic"]) > tic0 and Sfx._ultima.has("tiempo_tic"))
	await avanzar_s(0.12)            # s de juego: a 0,3 son ~0,4 s reales
	var fuerza: float = float(ef.get("fuerza")) if is_instance_valid(ef) else 0.0
	var copias: int = int(ef.get("copias")) if is_instance_valid(ef) else 0
	_ok("3 el filtro violeta entra (%.2f)" % fuerza, fuerza > 0.9)
	_ok("3 deja una estela de copias (%d)" % copias, copias >= 3 and copias <= Sensacion3D.N_COPIAS)
	_ok("3 las copias están en la escena", maqueta.find_children("CopiaBruja", "Node3D", true, false).size() + j.get_parent().find_children("CopiaBruja", "Node3D", false, false).size() >= 1)
	var t: float = 0.0
	while TiempoBruja.activa() and t < 3.0:
		t += await avanzar_s(1.0 / 30.0)
	var tics: int = int(ef.get("tics")) if is_instance_valid(ef) else 0
	_ok("3 tic-tac mientras dura (%d)" % tics, tics >= 3)
	await avanzar_s(0.3)
	_ok("3 al acabar se va el efecto y el tiempo vuelve a 1", not is_instance_valid(ef) and is_equal_approx(Engine.time_scale, 1.0), "%s · %.2f" % [is_instance_valid(ef), Engine.time_scale])
	if is_instance_valid(av):
		av.cancelar()
	await avanzar_s(0.5)


# --- 4 · muerte y oro --------------------------------------------------------------------------------------------------

func _caso_muerte() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	var a: Combate3D = _goblin(Vector2i(9, 33), true, 10.0)
	var b: Combate3D = _goblin(Vector2i(9, 35), true, 10.0)
	b.oro = 7
	await avanzar(3)
	var m0: int = int(Sensacion3D.cuenta["muerte"])
	var u0: int = int(Sensacion3D.cuenta["ultimo"])
	a.receive_damage(100.0)
	_ok("4 cae uno: se pide la muerte con peso", a.muerto and int(Sensacion3D.cuenta["muerte"]) == m0 + 1)
	_ok("4 queda otro: sin cámara lenta", int(Sensacion3D.cuenta["ultimo"]) == u0 and is_equal_approx(Engine.time_scale, 1.0))
	var oro0: int = Estado.i().oro
	b.receive_damage(100.0)
	_ok("4 cae el último de la sala: cámara lenta", int(Sensacion3D.cuenta["ultimo"]) == u0 + 1 and is_equal_approx(Engine.time_scale, Sensacion3D.CAMARA_LENTA), "%.2f" % Engine.time_scale)
	var oro: Node = null
	for n in maqueta.get_children():
		if n.name.begins_with("Oro") and n.has_method("saltando"):
			oro = n
	_ok("4 el oro sale saltando del cuerpo", oro != null and bool(oro.call("saltando")))
	var y_max: float = 0.0
	var ts_min: float = 1.0
	var t: float = 0.0
	while t < 1.2:
		await avanzar(1)
		t += 1.0 / 30.0
		ts_min = minf(ts_min, Engine.time_scale)
		if is_instance_valid(oro):
			y_max = maxf(y_max, (oro as Node3D).position.y)
	_ok("4 la cámara lenta vuelve sola a 1", is_equal_approx(Engine.time_scale, 1.0), "%.2f" % Engine.time_scale)
	_ok("4 el arco sube (%.2f u sobre el cuerpo)" % (y_max - b.position.y), y_max - b.position.y > 0.6)
	# Ella a 2 casillas (4,6 u): fuera del imán. Se acerca a ~1,8 u: se imanta y se recoge sola.
	await avanzar_s(0.3)
	_ok("4 lejos de ella, el oro se queda (no se imanta)", is_instance_valid(oro) and not bool(oro.get("imantada")) and Estado.i().oro == oro0)
	if is_instance_valid(oro):
		var p_oro: Vector3 = (oro as Node3D).position
		j.position = Vector3(p_oro.x + 1.8, j.position.y, p_oro.z)
	var imanto: bool = false
	t = 0.0
	while is_instance_valid(oro) and t < 1.0:
		imanto = imanto or bool(oro.get("imantada"))
		t += await avanzar_s(1.0 / 30.0)
	_ok("4 a 1,8 u se imanta hacia ella", imanto)
	_ok("4 y se recoge al llegar (+7) con su sonido", not is_instance_valid(oro) and Estado.i().oro == oro0 + 7 and Sfx._ultima.has("moneda"), "%d → %d" % [oro0, Estado.i().oro])
	# Con el tiempo de otro (el libro a 0,3): el último no lo toca.
	var c: Combate3D = _goblin(Vector2i(9, 33), true, 10.0)
	await avanzar(2)
	Engine.time_scale = 0.3
	u0 = int(Sensacion3D.cuenta["ultimo"])
	c.receive_damage(100.0)
	await avanzar(5)
	_ok("4 si el tiempo ya era de otro (0,3), no lo pisa ni lo devuelve a 1", int(Sensacion3D.cuenta["ultimo"]) == u0 + 1 and is_equal_approx(Engine.time_scale, 0.3), "%.2f" % Engine.time_scale)
	Engine.time_scale = 1.0
	_limpiar()
	await avanzar_s(2.0)


# --- 5 · reacciones grandes ------------------------------------------------------------------------------------------

func _reaccion(elemento: String, rotulo: String) -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	var otro: Combate3D = _goblin(Vector2i(9, 36))
	await avanzar(3)
	g.mojado = 5.0
	var r0: int = int(Sensacion3D.cuenta["reaccion"])
	var e0: Array = _etiquetas()
	var v0: float = g.health
	_pagina(elemento, ["flecha"])
	lanzador.lanzar_pagina_ya(0, j.position, Vector3(-1, 0, 0))
	var t: float = 0.0
	while t < 1.5 and int(Sensacion3D.cuenta["reaccion"]) == r0:
		t += await avanzar_s(1.0 / 60.0)
	_ok("5 %s sobre mojado: reacción grande" % elemento, int(Sensacion3D.cuenta["reaccion"]) >= r0 + 1, "daño %.0f" % (v0 - g.health))
	var grande: Label3D = null
	for l in _etiquetas():
		if not e0.has(l) and (l as Label3D).text == rotulo:
			grande = l
	_ok("5 rótulo grande «%s»" % rotulo, grande != null and grande.scale.x > Sensacion3D.ESCALA_ROTULO * 0.9, str(_etiquetas().filter(func(l): return not e0.has(l)).map(func(l): return l.text)))
	_ok("5 hitstop del mundo: el OTRO goblin también se congela", otro._hitstop > 0.0, "%.3f" % otro._hitstop)
	_ok("5 y ella", j._t_hitstop > 0.0)
	_ok("5 con su sonido", Sfx._ultima.has("reaccion_grande"))
	_limpiar()
	await avanzar_s(1.0)


func _caso_reacciones() -> void:
	await _reaccion("rayo", "¡Descarga!")
	Sfx._ultima.erase("reaccion_grande")
	await _reaccion("fuego", "¡Vapor!")


# --- 6 · apagada -------------------------------------------------------------------------------------------------------

func _caso_apagada() -> void:
	Sensacion3D.ACTIVA = false
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33), true, 10.0)
	g.oro = 3
	await avanzar(3)
	var r0: int = int(Sensacion3D.cuenta["reaccion"])
	g.mojado = 5.0
	g.texto_grande("¡Vapor!", Color.WHITE)
	_ok("6 apagada: la reacción grande no se pide (sale el texto pequeño)", int(Sensacion3D.cuenta["reaccion"]) == r0)
	g.receive_damage(100.0)
	_ok("6 apagada: el último no pone cámara lenta", is_equal_approx(Engine.time_scale, 1.0))
	var oro: Node = null
	for n in maqueta.get_children():
		if n.name.begins_with("Oro") and n.has_method("saltando"):
			oro = n
	_ok("6 apagada: el oro aparece en su sitio, sin salto", oro != null and not bool(oro.call("saltando")))
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar_s(0.5)
