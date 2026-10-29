extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, LOTE 3 (29/10; presentacion/sensacion_3d.gd). Sobre la escena real del Bosque:
##   1 RESPINGO: un golpe tira del MODELO del goblin hacia donde va el golpe (el nodo no se mueve) y vuelve a cero; también con el golpe F;
##   2 FLECHAS: el aviso de un enemigo que no se ve lleva su flecha en el borde de la pantalla, hacia él; si se ve, o está lejos de ella, no;
##   3 MÚSICA DE COMBATE: entra cuando un enemigo la persigue cerca, sube hasta arriba; si caen todos suena «sala_limpia» y baja; si el enemigo deja de
##     perseguirla, acaba sin remate pasado T_SIGUE_COMBATE; con nadie, el reproductor se va;
##   4 con la sensación apagada, nada de esto.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sensacion_3.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	await _caso_respingo()
	await _caso_flechas()
	await _caso_musica()
	await _caso_apagada()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _director() -> Node:
	return (jugador as Node).get_node_or_null("DirectorSensacion")


# --- 1 · respingo ------------------------------------------------------------------------------------------------------

func _caso_respingo() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	var r0: int = int(Sensacion3D.cuenta["respingo"])
	var nodo0: Vector3 = g.position
	var h := Hechizo.new()
	h.elemento = "fuego"
	h.dano = 5.0
	h.fuerza_golpe = 0.0
	g.golpe(h, Vector3(-1, 0, 0))
	_ok("1 un golpe pide el respingo", int(Sensacion3D.cuenta["respingo"]) == r0 + 1)
	var maximo: float = 0.0
	var hacia: float = 0.0
	for i in range(4):
		await avanzar(1)
		if g.respingo.length() > maximo:
			maximo = g.respingo.length()
			hacia = g.respingo.normalized().dot(Vector3(-1, 0, 0))
	_ok("1 el modelo sale hacia donde va el golpe (%.2f u)" % maximo, maximo > Sensacion3D.RESPINGO * 0.5 and maximo <= Sensacion3D.RESPINGO * 1.2 and hacia > 0.9)
	_ok("1 el modelo lleva el respingo (pj = nodo + respingo)", g.pj.position.distance_to(g.position + g.respingo) < 0.02 or g._salto_y != 0.0)
	_ok("1 el nodo no se mueve (el golpe no empuja: fuerza 0)", Vector2(g.position.x - nodo0.x, g.position.z - nodo0.z).length() < 0.05)
	await avanzar_s(Sensacion3D.T_RESPINGO + 0.2)
	_ok("1 y vuelve a cero", g.respingo.length() < 0.005, str(g.respingo))
	# Golpe F (cuerpo a cuerpo).
	var r1: int = int(Sensacion3D.cuenta["respingo"])
	g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 0.0)
	_ok("1 el golpe F también", int(Sensacion3D.cuenta["respingo"]) == r1 + 1)
	_limpiar()
	await avanzar(3)


# --- 2 · flechas -------------------------------------------------------------------------------------------------------

func _caso_flechas() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	_ok("2 hay cámara y director", cam != null and _director() != null)
	if cam == null:
		return
	var tam: Vector2 = root.get_viewport().get_visible_rect().size
	var m: float = Sensacion3D.MARGEN_FLECHA
	var dentro := Rect2(Vector2(m, m), tam - Vector2(m, m) * 2.0)
	# Uno al lado: se ve, sin flecha.
	var cerca: Combate3D = _goblin(Vector2i(10, 33))
	var a1: AvisoAtaque3D = AvisoAtaque3D.circulo(maqueta, cerca.position, 1.0, 1.0, cerca)
	_ok("2 un enemigo que se ve: sin flecha", Sensacion3D.punta_flecha(cam, tam, dentro, a1, j.global_position) == null)
	# Uno fuera de pantalla a la derecha (a menos de RADIO_FLECHA): flecha en el borde derecho.
	var fuera: Combate3D = _goblin(Vector2i(11, 33))
	var paso: float = 0.0
	while paso < Sensacion3D.RADIO_FLECHA - 1.0:
		paso += 1.0
		fuera.position = j.position + Vector3(paso, 0.0, 0.0)
		var s: Vector2 = cam.unproject_position(fuera.position)
		if not Rect2(Vector2.ZERO, tam).has_point(s):
			break
	var a2: AvisoAtaque3D = AvisoAtaque3D.circulo(maqueta, fuera.position, 1.0, 1.0, fuera)
	var punta: Variant = Sensacion3D.punta_flecha(cam, tam, dentro, a2, j.global_position)
	_ok("2 un enemigo fuera de pantalla a %.0f u: su flecha" % paso, punta != null, str(paso))
	if punta != null:
		var p: Vector2 = punta
		_ok("2 la flecha está en el borde derecho, a MARGEN_FLECHA", absf(p.x - (tam.x - m)) < 1.0 and p.y > m - 1.0 and p.y < tam.y - m + 1.0, str(p))
	# Muy lejos: nada.
	fuera.position = j.position + Vector3(Sensacion3D.RADIO_FLECHA + 4.0, 0.0, 0.0)
	_ok("2 más lejos de RADIO_FLECHA: sin flecha", Sensacion3D.punta_flecha(cam, tam, dentro, a2, j.global_position) == null)
	a1.queue_free()
	a2.queue_free()
	_limpiar()
	await avanzar(3)


# --- 3 · música --------------------------------------------------------------------------------------------------------

func _caso_musica() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	var d: Node = _director()
	_ok("3 sin enemigos no hay combate ni música", not bool(d.get("en_combate")) and d.get_node_or_null("MusicaCombate") == null)
	var g: Combate3D = _goblin(Vector2i(14, 33), false, 60.0)
	g.objetivo = j
	var c0: int = int(Sensacion3D.cuenta["combate"])
	await avanzar(2)
	_ok("3 un enemigo la persigue: empieza el combate", bool(d.get("en_combate")) and int(Sensacion3D.cuenta["combate"]) == c0 + 1)
	var mus: AudioStreamPlayer = d.get_node_or_null("MusicaCombate") as AudioStreamPlayer
	_ok("3 suena la capa de combate, en bucle", mus != null and mus.playing and mus.stream is AudioStreamWAV and (mus.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	await avanzar_s(Sensacion3D.T_SUBE_MUSICA + 0.2)
	_ok("3 sube hasta arriba", is_equal_approx(float(d.get("volumen")), 1.0), str(d.get("volumen")))
	var l0: int = int(Sensacion3D.cuenta["sala_limpia"])
	g.receive_damage(10000.0)
	await avanzar(2)
	_ok("3 cae el último: «sala_limpia» y se acaba", not bool(d.get("en_combate")) and int(Sensacion3D.cuenta["sala_limpia"]) == l0 + 1)
	await avanzar_s(Sensacion3D.T_BAJA_MUSICA + 0.3)
	_ok("3 la música baja y el reproductor se va", float(d.get("volumen")) <= 0.0 and d.get_node_or_null("MusicaCombate") == null)
	_limpiar()
	await avanzar(3)
	# Deja de perseguirla: acaba sin remate tras T_SIGUE_COMBATE.
	var g2: Combate3D = _goblin(Vector2i(14, 33), false, 100000.0)
	g2.objetivo = j
	await avanzar(3)
	_ok("3 otro combate", bool(d.get("en_combate")))
	g2.quieto = true
	g2.objetivo = null
	l0 = int(Sensacion3D.cuenta["sala_limpia"])
	await avanzar_s(Sensacion3D.T_SIGUE_COMBATE * 0.5)
	_ok("3 recién perdida, el combate sigue", bool(d.get("en_combate")))
	await avanzar_s(Sensacion3D.T_SIGUE_COMBATE * 0.5 + 0.3)
	_ok("3 pasado T_SIGUE_COMBATE acaba, sin «sala_limpia»", not bool(d.get("en_combate")) and int(Sensacion3D.cuenta["sala_limpia"]) == l0)
	_limpiar()
	await avanzar_s(Sensacion3D.T_BAJA_MUSICA + 0.3)


# --- 4 · apagada -------------------------------------------------------------------------------------------------------

func _caso_apagada() -> void:
	Sensacion3D.ACTIVA = false
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	var r0: int = int(Sensacion3D.cuenta["respingo"])
	var h := Hechizo.new()
	h.elemento = "fuego"
	h.dano = 5.0
	g.golpe(h, Vector3(-1, 0, 0))
	await avanzar(2)
	_ok("4 apagada: sin respingo", int(Sensacion3D.cuenta["respingo"]) == r0 and g.respingo.length() < 0.001)
	g.quieto = false
	g.objetivo = j
	await avanzar(3)
	var d: Node = _director()
	_ok("4 apagada: sin combate ni música", not bool(d.get("en_combate")) and d.get_node_or_null("MusicaCombate") == null)
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar(3)
