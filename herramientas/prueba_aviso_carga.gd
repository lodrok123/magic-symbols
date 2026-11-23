extends "res://herramientas/escenario_base.gd"
## A1 de docs/PLAN_COMBATE_2026-11-22.md (C22, 22/11): el aviso del guerrero y del arquero sale al EMPEZAR la carga previa, no al arrancar el clip.
## Antes: el guerrero esperaba PREPARAR_GOLPE (0,6 s) quieto sin marca y luego avisaba ~0,6 s; el arquero tensaba PREPARAR_FLECHA (0,9 s) sin aviso ni sonido.
## Comprueba, para un guerrero (goblin con escudo de la ArenaCombate) y un arquero (Gruta Batida):
##   · el aviso aparece en el mismo instante en que empieza la carga (±1 fotograma);
##   · es el MISMO aviso hasta el golpe (no se rehace al arrancar el clip) y el golpe cae cuando el aviso se llena (±0,1 s);
##   · si la carga se corta (la jugadora se aleja), el aviso se cancela.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_aviso_carga.gd


func _buscar(arquero: bool) -> Combate3D:
	for n in get_nodes_in_group("combate3d"):
		var c: Combate3D = n as Combate3D
		if c != null and not c.muerto and not c.elemental and c.es_goblin and c.arquero == arquero:
			return c
	return null


## Coloca a la jugadora a `dist` casillas del enemigo (por el lado libre) y mide un ataque completo. Devuelve {t_carga, t_aviso, mismo, desfase, aviso_total}.
func _medir(c: Combate3D, dist: int, max_s: float = 8.0) -> Dictionary:
	var res: Dictionary = {"t_carga": -1.0, "t_aviso": -1.0, "mismo": false, "desfase": 99.0, "aviso_total": 0.0}
	var ce: Vector2i = Terreno3D.celda_de(c.global_position)
	var puesto: Vector2i = ce
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = ce + d * dist
		if Terreno3D.en_mapa(p) and not Terreno3D.celda_solida(p, 0) and not Lanzador3D.es_agua(p):
			puesto = p
			break
	colocar_jugador(puesto)
	(jugador as Jugador3D).vida = 100000.0
	c.estado = "persigue"
	c.objetivo = jugador
	var t0: float = reloj.t
	var carga_prev: float = c._carga
	var aviso: AvisoAtaque3D = null
	var pendiente_visto: bool = false
	while reloj.t - t0 < max_s:
		await process_frame
		if c.arquero:
			colocar_jugador(puesto)                          # que no la empujen ni se mueva
		else:
			# el guerrero patrulla y se mueve: la jugadora se queda pegada a él, dentro de su alcance, y él la persigue
			var hacia: Vector3 = (Terreno3D.centro_de(puesto, 0.0) - c.global_position)
			hacia.y = 0.0
			hacia = hacia.normalized() if hacia.length() > 0.01 else Vector3.RIGHT
			jugador.global_position = Vector3(c.global_position.x, jugador.global_position.y, c.global_position.z) + hacia * (Combate3D.RANGO_ATAQUE * 0.7)
			if c.estado != "persigue" and not c._golpe_pendiente:
				c.estado = "persigue"
				c.objetivo = jugador
		# Empieza la carga: `_carga` sube (arquero, guerrero de antes) o, con el golpe seco del guerrero (C25), arranca el ataque con la espera dentro (`_golpe_pendiente`).
		if res["t_carga"] < 0.0 and ((carga_prev <= 0.0 and c._carga > 0.0) or (c._golpe_pendiente and not pendiente_visto)):
			res["t_carga"] = reloj.t
		carga_prev = c._carga
		if res["t_carga"] >= 0.0 and aviso == null and c._aviso != null and is_instance_valid(c._aviso):
			aviso = c._aviso
			res["t_aviso"] = reloj.t
		if c._golpe_pendiente:
			pendiente_visto = true
			res["mismo"] = aviso != null and c._aviso == aviso
		elif pendiente_visto:
			# el golpe (o la suelta de la flecha) acaba de ocurrir
			if aviso != null and is_instance_valid(aviso):
				res["desfase"] = absf(aviso.t - aviso.t_impacto) if not c.arquero else 0.0
				res["aviso_total"] = aviso.t if not c.arquero else reloj.t - float(res["t_aviso"])
			elif aviso != null:
				res["desfase"] = 0.0                         # ya se borró en su instante (el destello acabó)
				res["aviso_total"] = reloj.t - float(res["t_aviso"])
			break
	if res["t_carga"] < 0.0:
		print("   (sin carga) estado=%s en_rango=%s descanso=%.2f dist=%.2f ataque=%.2f quieto=%s stun=%.2f" % [c.estado, c._en_rango, c._descanso, c.global_position.distance_to(jugador.global_position),
			c._ataque, str(c.get("quieto")), c.stun_timer])
		print("   ve=%s linea=%s mismo_jugador=%s cegado=%.2f interrupcion=%.2f fase_empuje=%s procesa=%s" % [c._ve(5.0), Terreno3D.linea_libre(c.position, jugador.position), str(c.jugador),
			c.cegado, c.interrupcion, str(c._fase_empuje), c.can_process()])
	return res


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	var fot: float = 1.0 / 30.0 + 0.01
	# --- GUERRERO ---
	await cargar("res://escenas/PruebaArenaCombate.tscn", true)
	if lanzador == null:
		return
	var g: Combate3D = _buscar(false)
	_ok("0 hay un goblin cuerpo a cuerpo en la arena", g != null)
	if g != null:
		await avanzar(10)
		var r: Dictionary = await _medir(g, 1)
		print("   guerrero: ", r)
		_ok("A1 guerrero: el aviso sale al empezar la carga", float(r["t_carga"]) >= 0.0 and float(r["t_aviso"]) >= 0.0 and float(r["t_aviso"]) - float(r["t_carga"]) <= fot,
			"carga %.2f · aviso %.2f" % [r["t_carga"], r["t_aviso"]])
		_ok("A1 guerrero: es el mismo aviso hasta el golpe", bool(r["mismo"]))
		_ok("A1 guerrero: el golpe cae cuando el aviso se llena (±0,1 s)", float(r["desfase"]) <= 0.1, "desfase %.3f s" % float(r["desfase"]))
		_ok("A1 guerrero: el aviso dura toda la carga (≥ %.1f s; C25: carga + golpe seco)" % Combate3D.PREPARAR_GOLPE, float(r["aviso_total"]) >= Combate3D.PREPARAR_GOLPE - 0.05,
			"%.2f s" % float(r["aviso_total"]))
		# Carga cortada: empieza a cargar y la jugadora se va lejos
		var espera: float = 0.0
		while g._carga <= 0.0 and not g._golpe_pendiente and espera < 6.0:
			jugador.global_position = Vector3(g.global_position.x + Combate3D.RANGO_ATAQUE * 0.7, jugador.global_position.y, g.global_position.z)
			if g.estado != "persigue":
				g.estado = "persigue"
			espera += await avanzar_s(1.0 / 30.0)
		var av: AvisoAtaque3D = g._aviso
		var habia: bool = av != null and is_instance_valid(av)
		colocar_jugador(Vector2i(2, 2))
		await avanzar(3)
		_ok("A1 guerrero: si la carga se corta, el aviso se cancela", habia and (not is_instance_valid(av) or av.cancelado) and not g._aviso_carga and not g._golpe_pendiente,
			"aviso al cargar: %s" % ("sí" if habia else "no"))
	maqueta.queue_free()
	await avanzar(5)
	# --- ARQUERO ---
	await cargar("res://escenas/PruebaGrutaBatida.tscn", true)
	var a: Combate3D = _buscar(true)
	_ok("0 hay un goblin arquero en la Gruta Batida", a != null)
	if a != null:
		await avanzar(10)
		var ra: Dictionary = await _medir(a, 4)
		print("   arquero: ", ra)
		_ok("A1 arquero: el aviso sale al empezar a tensar", float(ra["t_carga"]) >= 0.0 and float(ra["t_aviso"]) >= 0.0 and float(ra["t_aviso"]) - float(ra["t_carga"]) <= fot,
			"tensa %.2f · aviso %.2f" % [ra["t_carga"], ra["t_aviso"]])
		_ok("A1 arquero: es el mismo aviso hasta soltar", bool(ra["mismo"]))
		_ok("A1 arquero: el aviso ya cubre los %.1f s de tensar" % Combate3D.PREPARAR_FLECHA, float(ra["aviso_total"]) >= Combate3D.PREPARAR_FLECHA - 0.05, "%.2f s hasta soltar" % float(ra["aviso_total"]))
