extends "res://herramientas/escenario_base.gd"
## C25 de docs/PLAN_COMBATE_2026-11-22.md (22/11, Pablo: «busquemos de inicio este output lag», Mystralia O23): el GUERRERO goblin anticipa QUIETO y golpea SECO.
## En la ArenaCombate, un guerrero sin escudo junto a la jugadora. Se mide un ataque, fotograma a fotograma:
##   · el círculo del suelo dura justo la anticipación + el golpe seco (PREPARAR_GOLPE + GOLPE_SECO_EJECUTA), y el golpe cae cuando se llena;
##   · durante la pose (de GOLPE_SECO_LLEGA a PREPARAR_GOLPE) el clip está CONGELADO en la carga y el cuerpo ENCOGIDO (ANTICIPA_ESCALA sostenido, no un pulso);
##   · de soltar la pose al contacto pasan ≤ 0,1 s;
##   · después hay recuperación (sigue en su clip un rato) y el daño llega a la jugadora.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_golpe_seco.gd

func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaArenaCombate.tscn", true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	for id in ["escudo_a", "escudo_b", "coraza_arena", "limo_brasa_arena"]:
		var n: Node = z.nodo(id) if z != null else null
		if n is Combate3D:
			(n as Combate3D).retirar()
	var c := Vector2i(11, 10)
	var r: Dictionary = {"clase": "combate", "id": "goblin_warrior_chibi", "casa": Terreno3D.centro_de(c, Terreno3D.y_pies(c)), "nombre_nodo": "GuerreroSeco", "nombre": "Goblin guerrero",
		"debil": "", "resiste": "", "fijo": false, "quieto": false, "premia_tinta": true, "suelta_recogibles": false, "puestos_disparo": [], "puesto_cubierto": Vector3.ZERO, "escudo": false, "coraza": ""}
	var g: Combate3D = Combate3D.recrear(r, maqueta as Node3D, jugador as Jugador3D, lanzador)
	_ok("0 hay un guerrero y usa el golpe seco", g != null and g._usa_golpe_seco())
	if g == null:
		return
	g.health = 1.0e6
	g.vida_max = 1.0e6
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1.0e6
	var junto: Vector3 = g.global_position + Vector3(-Combate3D.RANGO_ATAQUE * 0.7, 0.0, 0.0)
	var t: float = 0.0
	while not g._golpe_pendiente and t < 6.0:
		j.global_position = Vector3(junto.x, j.global_position.y, junto.z)
		j._t_inv = 0.0
		if g.estado != "persigue":
			g.estado = "persigue"
			g.objetivo = j
		t += await avanzar_s(1.0 / 30.0)
	_ok("1 empieza un ataque", g._golpe_pendiente, "%.1f s" % t)
	var av: AvisoAtaque3D = g._aviso
	var t_aviso: float = av.t_impacto if av != null else -1.0
	var ventana1: float = av.ventana if av != null else -1.0
	var esperado: float = Combate3D.PREPARAR_GOLPE + Combate3D.GOLPE_SECO_EJECUTA
	_ok("1 el círculo dura justo la anticipación + el golpe seco (%.2f s)" % esperado, av != null and absf(t_aviso - esperado) <= 0.04, "%.2f s" % t_aviso)
	# Fotograma a fotograma: posición del clip, escala y daño.
	var t0: float = reloj.t
	var vida0: float = j.vida
	var muestras: Array = []
	var t_dano: float = -1.0
	while reloj.t - t0 < esperado + 0.6:
		j.global_position = Vector3(junto.x, j.global_position.y, junto.z)
		await avanzar(1)
		var tt: float = reloj.t - t0
		muestras.append([tt, g.pj.arbol().posicion() / maxf(g.pj.duracion("attack"), 0.001), g.pj.scale.y / maxf(g.pj.scale.x, 0.001)])
		if t_dano < 0.0 and j.vida < vida0:
			t_dano = tt
	var quieto: bool = true
	var encogido: bool = true
	var f_pose: float = -1.0
	var t_suelta: float = -1.0
	var t_contacto_clip: float = -1.0
	for m in muestras:
		var tt: float = float(m[0])
		if tt >= Combate3D.GOLPE_SECO_LLEGA + 0.05 and tt <= Combate3D.PREPARAR_GOLPE - 0.05:
			if f_pose < 0.0:
				f_pose = float(m[1])
			quieto = quieto and absf(float(m[1]) - f_pose) < 0.004
			encogido = encogido and float(m[2]) < 0.93
		if t_suelta < 0.0 and tt > Combate3D.GOLPE_SECO_LLEGA + 0.05 and f_pose >= 0.0 and float(m[1]) > f_pose + 0.004:
			t_suelta = tt
		if t_contacto_clip < 0.0 and float(m[1]) >= Combate3D.MOMENTO_GOLPE_GUERRERO - 0.002:
			t_contacto_clip = tt
	_ok("2 durante la pose el clip está congelado en la carga (fracción %.3f ≈ %.2f)" % [f_pose, Combate3D.MOMENTO_CARGA_GUERRERO], quieto and absf(f_pose - Combate3D.MOMENTO_CARGA_GUERRERO) < 0.03)
	_ok("2 y el cuerpo sigue encogido (pose sostenida, no un pulso)", encogido)
	_ok("3 de soltar la pose al contacto pasan ≤ 0,1 s", t_suelta > 0.0 and t_contacto_clip > 0.0 and t_contacto_clip - t_suelta <= 0.1 + 1.0 / 30.0,
		"suelta %.2f · contacto %.2f" % [t_suelta, t_contacto_clip])
	_ok("3 el daño llega cuando el círculo se llena (±0,07 s)", t_dano > 0.0 and absf(t_dano - esperado) <= 0.07, "daño a %.2f s de %.2f" % [t_dano, esperado])
	_ok("4 después hay recuperación: sigue en su clip un rato", g._ataque > 0.0 or g._t_anim > 0.0 or float(muestras.back()[1]) > Combate3D.MOMENTO_GOLPE_GUERRERO)
	print("   muestras (t, fracción, alto/ancho): ", muestras.slice(0, 30).map(func(m: Array) -> String: return "%.2f:%.3f/%.2f" % [m[0], m[1], m[2]]))
	_ok("5 la ventana de esquiva del golpe seco es de %.2f s (la de los ataques lentos sigue en %.1f)" % [AvisoAtaque3D.VENTANA_CUERPO, AvisoAtaque3D.VENTANA_ESQUIVA],
		is_equal_approx(ventana1, AvisoAtaque3D.VENTANA_CUERPO), "%.2f" % ventana1)
	# A5 (Pablo, 22/11: «Sí, a 0,25 s»): una voltereta 0,4 s antes del golpe no da tiempo bruja; una 0,2 s antes, sí.
	for caso in [[0.4, false], [0.2, true]]:
		var antes: float = float(caso[0])
		var debe: bool = bool(caso[1])
		TiempoBruja.terminar(lanzador)
		await avanzar_s(Combate3D.DESCANSO_GOLPE + 0.5)
		t = 0.0
		while not g._golpe_pendiente and t < 6.0:
			j.global_position = Vector3(junto.x, j.global_position.y, junto.z)
			j._t_roll = 0.0
			if g.estado != "persigue":
				g.estado = "persigue"
				g.objetivo = j
			t += await avanzar_s(1.0 / 30.0)
		var a2: AvisoAtaque3D = g._aviso
		while a2 != null and is_instance_valid(a2) and a2.queda() > antes:
			j.global_position = Vector3(junto.x, j.global_position.y, junto.z)
			await avanzar(1)
		var queda: float = a2.queda() if a2 != null and is_instance_valid(a2) else -1.0
		var veces: int = TiempoBruja.veces
		var blanco: bool = a2 != null and is_instance_valid(a2) and a2.queda() <= a2.ventana
		j._iniciar_voltereta(Vector3(-1, 0, 0))
		var hubo: bool = TiempoBruja.veces == veces + 1
		_ok("5 voltereta a %.2f s del golpe: %s" % [antes, "SÍ da tiempo bruja" if debe else "NO da tiempo bruja"], hubo == debe and queda >= 0.0, "quedaba %.2f · tiempo bruja %s" % [queda, hubo])
		_ok("5 el parpadeo blanco %s a %.2f s del golpe" % ["ya ha empezado" if debe else "aún no ha empezado", antes], blanco == debe)
		await avanzar_s(1.0)
	TiempoBruja.terminar(lanzador)
