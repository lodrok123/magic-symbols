extends "res://herramientas/escenario_base.gd"
## X2 de docs/PLAN_COMBATE_2026-11-22.md · EL VERRACO (enemigos/verraco_3d.gd) en la Sala del Verraco (mapas/SalaVerraco.txt), y D1 (daño contra pared).
##   1. con armadura: un hechizo al cuerpo (fuego, agua o tierra) no le quita vida;
##   2. embiste contra la pared: pose (con su línea en el suelo y ventana de 0,25 s) → embestida → hiere a la jugadora que pilla → le arranca una placa y queda aturdido;
##   3. una barrera que aparece mientras se prepara lo hace FRENAR; una que aparece cuando ya ha arrancado lo para y le arranca una placa;
##   4. sin agua se para antes de la pared; con el suelo mojado PATINA y se estrella;
##   5. al tercer choque cae la armadura y NO vuelve (tras 10 s sigue sin ella); sin armadura recibe daño de los tres elementos (×1; aturdido ×1,5) y un choque le quita DANO_CHOQUE;
##   6. la voltereta a 0,4 s de arrancar no da tiempo bruja; a 0,2 s, sí;
##   7. al morir la jugadora vuelve a su sitio entero y con la armadura puesta (G1);
##   8. D1: un goblin empujado fuerte contra la pared pierde vida y queda aturdido; empujado flojo, no.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_verraco.gd

const RUTA: String = "res://escenas/PruebaSalaVerraco.tscn"
var vr: Verraco3D = null
var j: Jugador3D = null


func _poner(c_verraco: Vector2i, c_jugadora: Vector2i) -> void:
	vr._quitar_aviso()
	vr.global_position = Terreno3D.centro_de(c_verraco, Terreno3D.y_pies(c_verraco))
	vr._cambiar(Verraco3D.Fase.ACECHA)
	vr._t = 99.0                                            # sin el reposo
	colocar_jugador(c_jugadora)
	j.vida = 1.0e6
	j._t_inv = 0.0


func _esperar_fase(f: int, max_s: float) -> bool:
	var t: float = 0.0
	while vr.fase != f and t < max_s:
		t += await avanzar_s(1.0 / 30.0)
	return vr.fase == f


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	vr = z.nodo("verraco") as Verraco3D if z != null else null
	j = jugador as Jugador3D
	_ok("0 la pieza `verraco` lo monta en (14,2)", vr != null and Terreno3D.celda_de(vr.global_position) == Vector2i(14, 2), str(z.avisos) if z != null else "")
	if vr == null:
		return
	Repertoire.activate_all()
	var fuego: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {"flecha": 1})
	# --- 1 · con armadura ---
	var elementos: Array = ["fire", "water", "earth"]
	var sin_dano: bool = true
	var v0: float = vr.vida
	var golpes0: int = vr.golpes_sin_efecto
	for e in elementos:
		var rd: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
		vr.on_spell_hit(rd, Vector3.LEFT, Hechizo.construir(rd, {"flecha": 1}))
		sin_dano = sin_dano and is_equal_approx(vr.vida, v0)
	_ok("1 con armadura: fuego, agua y tierra no le quitan vida", sin_dano and vr.golpes_sin_efecto == golpes0 + 3 and not vr.sin_armadura and vr.placas_rotas == 0)
	# --- 2 · contra la pared (la jugadora junto a ella: la embestida se pasa 2 casillas y llega al muro) ---
	await _poner(Vector2i(6, 2), Vector2i(2, 2))
	var en_pose: bool = await _esperar_fase(Verraco3D.Fase.POSE, 2.0)
	var av: AvisoAtaque3D = vr._aviso
	_ok("2 al verla se pone en pose con una línea en el suelo (ventana de esquiva de %.2f s)" % AvisoAtaque3D.VENTANA_CUERPO,
		en_pose and av != null and av.forma == "rect" and is_equal_approx(av.ventana, AvisoAtaque3D.VENTANA_CUERPO))
	var p_pose: Vector3 = vr.global_position
	await avanzar_s(Verraco3D.POSE_S * 0.6)
	_ok("2 en la pose se queda quieto", vr.fase == Verraco3D.Fase.POSE and vr.global_position.distance_to(p_pose) < 0.01)
	await _esperar_fase(Verraco3D.Fase.ATURDIDO, 3.0)
	_ok("2 embiste, la pilla y se estrella contra la pared: 1 placa y aturdido", vr.embestidas == 1 and vr.golpes_jugadora == 1 and vr.choques == 1 and vr.placas_rotas == 1
		and vr.fase == Verraco3D.Fase.ATURDIDO and vr.ultimo_choque == "muro", "embestidas %d · golpes %d · choques %d · placas %d · %s" % [vr.embestidas, vr.golpes_jugadora, vr.choques, vr.placas_rotas, vr.ultimo_choque])
	await avanzar_s(Verraco3D.ATURDIDO_S + 0.1)
	# --- 3 · barreras ---
	await _poner(Vector2i(8, 2), Vector2i(4, 2))
	await _esperar_fase(Verraco3D.Fase.POSE, 2.0)
	Terreno3D.bloquear_celda(Vector2i(6, 2))               # una barrera NUEVA mientras se prepara
	await avanzar_s(0.2)
	_ok("3 una barrera que aparece mientras se prepara lo hace frenar", vr.frenazos == 1 and vr.fase == Verraco3D.Fase.ACECHA and vr.choques == 1)
	Terreno3D.liberar_celda(Vector2i(6, 2))
	await _poner(Vector2i(8, 2), Vector2i(4, 2))
	await _esperar_fase(Verraco3D.Fase.EMBISTE, 2.0)
	Terreno3D.bloquear_celda(Vector2i(6, 2))               # y ahora cuando ya ha arrancado
	await _esperar_fase(Verraco3D.Fase.ATURDIDO, 2.0)
	_ok("3 una barrera puesta cuando ya ha arrancado lo para y le arranca una placa", vr.choques == 2 and vr.placas_rotas == 2 and vr.frenazos == 1)
	Terreno3D.liberar_celda(Vector2i(6, 2))
	await avanzar_s(Verraco3D.ATURDIDO_S + 0.1)
	vr.placas_rotas = 0
	vr._pintar_placas()
	# --- 4 · suelo mojado ---
	await _poner(Vector2i(12, 6), Vector2i(6, 6))
	await _esperar_fase(Verraco3D.Fase.EMBISTE, 2.0)
	await _esperar_fase(Verraco3D.Fase.ACECHA, 3.0)
	_ok("4 sin agua se para antes de la pared (no choca)", vr.choques == 2, "choques %d · en %s" % [vr.choques, Terreno3D.celda_de(vr.global_position)])
	for x in range(2, 12):
		Terreno3D.estados.poner(Vector2i(x, 6), EstadosSuelo3D.MOJADA, true)
	await _poner(Vector2i(12, 6), Vector2i(6, 6))
	await _esperar_fase(Verraco3D.Fase.EMBISTE, 2.0)
	await _esperar_fase(Verraco3D.Fase.ATURDIDO, 3.0)
	_ok("4 con el suelo mojado patina y se estrella más lejos", vr.patinazos >= 1 and vr.choques == 3, "patinazos %d · choques %d · en %s" % [vr.patinazos, vr.choques, Terreno3D.celda_de(vr.global_position)])
	for x in range(2, 12):
		Terreno3D.estados.poner(Vector2i(x, 6), EstadosSuelo3D.MOJADA, false)
	await avanzar_s(Verraco3D.ATURDIDO_S + 0.1)
	# --- 5 · la armadura cae y no vuelve; sin ella, daño ---
	vr.placas_rotas = Verraco3D.PLACAS - 1
	vr._pintar_placas()
	await _poner(Vector2i(6, 2), Vector2i(2, 2))
	await _esperar_fase(Verraco3D.Fase.ATURDIDO, 5.0)
	_ok("5 al tercer choque cae la armadura", vr.sin_armadura and vr.placas_rotas == Verraco3D.PLACAS and vr.fase == Verraco3D.Fase.ATURDIDO and not vr._placas[0].visible and not vr._placas[2].visible)
	var v1: float = vr.vida
	var ok_el: bool = true
	var detalle: String = ""
	for e in elementos:
		var rd2: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
		var hz: Hechizo = Hechizo.construir(rd2, {"flecha": 1})
		var antes: float = vr.vida
		vr.on_spell_hit(rd2, Vector3.LEFT, hz)
		var esperado: float = hz.dano * Verraco3D.MULT_NUCLEO            # sigue aturdido
		ok_el = ok_el and absf((antes - vr.vida) - esperado) < 0.01
		detalle += " %s %.1f/%.1f" % [e, antes - vr.vida, esperado]
	_ok("5 sin armadura y aturdido: los tres elementos le quitan vida (×%.1f)" % Verraco3D.MULT_NUCLEO, ok_el and vr.vida < v1, detalle)
	await avanzar_s(Verraco3D.ATURDIDO_S + 0.1)
	vr.vida = vr.vida_max
	var vf: float = vr.vida
	vr.on_spell_hit(load("res://nucleo/fire_rune.tres") as RuneData, Vector3.LEFT, fuego)
	_ok("5 sin armadura y sin aturdir: daño ×1", vr.fase != Verraco3D.Fase.ATURDIDO and absf((vf - vr.vida) - fuego.dano) < 0.01, "%.1f → %.1f" % [vf, vr.vida])
	vr.vida = vr.vida_max
	var choques0: int = vr.choques
	await _poner(Vector2i(6, 2), Vector2i(2, 2))
	await _esperar_fase(Verraco3D.Fase.ATURDIDO, 5.0)
	_ok("5 un choque sin armadura quita DANO_CHOQUE y aturde", vr.choques == choques0 + 1 and absf((vr.vida_max - vr.vida) - Verraco3D.DANO_CHOQUE) < 0.01 and vr.fase == Verraco3D.Fase.ATURDIDO, "vida %.1f" % vr.vida)
	vr.vida_max = 1000.0                                    # que las embestidas de estos 10 s no lo maten
	vr.vida = vr.vida_max
	await avanzar_s(10.0)
	_ok("5 pasados 10 s la armadura no ha vuelto", vr.sin_armadura and vr.placas_rotas == Verraco3D.PLACAS and not vr._placas[1].visible)
	# --- 6 · voltereta perfecta ---
	for caso in [[0.4, false], [0.2, true]]:
		TiempoBruja.terminar(lanzador)
		await _poner(Vector2i(8, 6), Vector2i(4, 6))
		await _esperar_fase(Verraco3D.Fase.POSE, 2.0)
		var a: AvisoAtaque3D = vr._aviso
		while a != null and is_instance_valid(a) and a.queda() > float(caso[0]):
			await avanzar(1)
		var veces: int = TiempoBruja.veces
		j._t_roll = 0.0
		j._iniciar_voltereta(Vector3(0, 0, -1))
		_ok("6 voltereta a %.1f s de arrancar: %s" % [float(caso[0]), "tiempo bruja" if bool(caso[1]) else "nada"], (TiempoBruja.veces == veces + 1) == bool(caso[1]))
		TiempoBruja.terminar(lanzador)
		await _esperar_fase(Verraco3D.Fase.ACECHA, 4.0)
		await avanzar_s(Verraco3D.ATURDIDO_S + 0.2)
	# --- 7 · reintentar ---
	vr.vida = 10.0
	j.vida = 0.0
	j._morir()
	await avanzar(3)
	j.reaparecer()
	await avanzar(3)
	_ok("7 al reaparecer vuelve a su sitio entero y con la armadura puesta (G1)", vr.reinicios >= 1 and vr.placas_rotas == 0 and not vr.sin_armadura and vr._placas[0].visible and vr._placas[1].visible and vr._placas[2].visible and is_equal_approx(vr.vida, vr.vida_max) and Terreno3D.celda_de(vr.global_position) == Vector2i(14, 2))
	# --- 8 · D1: daño contra pared ---
	vr.set_physics_process(false)                           # que no estorbe
	var r: Dictionary = {"clase": "combate", "id": "goblin_warrior_chibi", "casa": Terreno3D.centro_de(Vector2i(2, 4), Terreno3D.y_pies(Vector2i(2, 4))), "nombre_nodo": "GoblinPared",
		"nombre": "Goblin guerrero", "debil": "", "resiste": "", "fijo": false, "quieto": true, "premia_tinta": true, "suelta_recogibles": false, "puestos_disparo": [],
		"puesto_cubierto": Vector3.ZERO, "escudo": false, "coraza": ""}
	var g: Combate3D = Combate3D.recrear(r, maqueta as Node3D, j, lanzador)
	colocar_jugador(Vector2i(10, 6))
	await avanzar(3)
	g.health = 100.0
	g.vida_max = 100.0
	g.position = Terreno3D.centro_de(Vector2i(1, 4), Terreno3D.y_pies(Vector2i(1, 4))) + Vector3(-0.75, 0, 0)    # pegado a la pared oeste
	g._empuje = Vector3(-1.5, 0, 0)                         # flojo
	await avanzar_s(0.8)
	_ok("8 D1: empujado flojo contra la pared no pierde vida", g.choques_pared == 0 and is_equal_approx(g.health, 100.0), "choques %d · vida %.1f" % [g.choques_pared, g.health])
	g.stun_timer = 0.0
	g.position = Terreno3D.centro_de(Vector2i(1, 4), Terreno3D.y_pies(Vector2i(1, 4))) + Vector3(-0.75, 0, 0)
	g._empuje = Vector3(-9.0, 0, 0)                         # fuerte, hacia la pared oeste
	await avanzar_s(0.8)
	_ok("8 D1: empujado fuerte contra la pared pierde vida y queda aturdido", g.choques_pared == 1 and g.health < 100.0, "choques %d · vida %.1f" % [g.choques_pared, g.health])
