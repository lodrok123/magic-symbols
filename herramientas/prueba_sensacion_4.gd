extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, LOTE 4 (29/10; presentacion/sensacion_3d.gd). Sobre la escena real del Bosque:
##   1 el CUERPO que encaja un hechizo suena (goblin: carne; gólem: piedra; limo: su chapoteo) y el golpe F no vuelve a sonar por aquí; el limo al morir suena;
##   2 la JUGADORA suena al encajar un golpe; con la vida baja el LATIDO entra (bucle), sube con lo que falta y se va al curarse;
##   3 la VOLTERETA levanta polvo y suena; `roll_cooldown_fraction` baja de 1 a 0 y, al llegar, suena «recarga_lista»; una página que recarga también (con destello);
##   4 ANDAR: `velocidad_suelo` arranca y frena sin saltos; apagada o con ACEL_SUELO = 0 es instantánea; andando con la tecla, `vel_suelo` sube hasta la de andar;
##   5 CÁMARA: `meta_adelanto` se adelanta hacia donde anda (más corriendo), hacia donde mira apuntando, y nunca pasa de ADELANTO_MAX; el director lo deja en `adelanto_actual`;
##   6 un proyectil que se PARA contra una pared pide `impacto_mundo` (y uno que acierta a un enemigo, no);
##   7 CARGA: entrar en el modo de lanzar monta el aro y su zumbido; salir lo apaga;
##   8 con la sensación apagada, nada de esto.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sensacion_4.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	await _caso_golpes_suenan()
	await _caso_jugadora_y_latido()
	await _caso_voltereta_y_recargas()
	await _caso_andar()
	await _caso_camara()
	await _caso_impacto_mundo()
	await _caso_carga()
	await _caso_apagada()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _director() -> Node:
	return (jugador as Node).get_node_or_null("DirectorSensacion")


func _hechizo(el: String = "fuego") -> Hechizo:
	var h := Hechizo.new()
	h.elemento = el
	h.dano = 5.0
	h.fuerza_golpe = 0.0
	return h


func _reproductores(nombre_contiene: String) -> int:
	var n: int = 0
	for c in root.get_children():
		if (c is AudioStreamPlayer3D or c is AudioStreamPlayer2D) and (c as Node).get("stream") != null:
			var rp: String = String(((c as Node).get("stream") as Resource).resource_path)
			if rp.contains(nombre_contiene):
				n += 1
	return n


# --- 1 · el cuerpo suena ---------------------------------------------------------------------------------------------

func _caso_golpes_suenan() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	_ok("1 el goblin trae su sonido de golpe (carne)", g.snd_golpe == "golpe_carne" and Sfx3D.CATALOGO.has("golpe_carne"))
	var s0: int = int(Sensacion3D.cuenta["golpe_son"])
	g.golpe(_hechizo(), Vector3(-1, 0, 0))
	_ok("1 un hechizo que acierta: el cuerpo suena", int(Sensacion3D.cuenta["golpe_son"]) == s0 + 1)
	await avanzar(3)
	g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 0.0)
	_ok("1 el golpe F no suena por aquí (ya suena en GolpeCuerpo)", int(Sensacion3D.cuenta["golpe_son"]) == s0 + 1)
	await avanzar(3)
	var l: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(13, 33)), "", false)
	l.quieto = true
	_creados.append(l)
	await avanzar(3)
	_ok("1 el limo trae chapoteo de golpe y de muerte", l.snd_golpe == "limo_golpe" and l.snd_muere == "limo_muere" and Sfx3D.CATALOGO.has("limo_muere"))
	s0 = int(Sensacion3D.cuenta["golpe_son"])
	l.golpe(_hechizo("fuego"), Vector3(1, 0, 0))
	_ok("1 el limo golpeado suena", int(Sensacion3D.cuenta["golpe_son"]) == s0 + 1)
	await avanzar(2)
	l.receive_damage(100000.0)
	await avanzar(2)
	_ok("1 el limo al morir suena (limo_muere)", _reproductores("limo_muere") >= 1)
	_limpiar()
	await avanzar(3)


# --- 2 · la jugadora y el latido ---------------------------------------------------------------------------------------

func _caso_jugadora_y_latido() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	j.vida = Estado.i().vida_max
	await avanzar(3)
	var d: Node = _director()
	var s0: int = int(Sensacion3D.cuenta["dano_son"])
	j.recibir_dano(10.0)
	_ok("2 encajar un golpe suena", int(Sensacion3D.cuenta["dano_son"]) == s0 + 1 and _reproductores("dano_jugadora") >= 1)
	await avanzar_s(0.3)
	_ok("2 con la vida alta no late", float(d.get("vol_latido")) <= 0.0 and d.get_node_or_null("Latido") == null and j.vida > Estado.i().vida_max * Sensacion3D.VIDA_LATIDO)
	var l0: int = int(Sensacion3D.cuenta["latido"])
	j._t_inv = 0.0
	j.vida = Estado.i().vida_max * Sensacion3D.VIDA_LATIDO * 0.5
	await avanzar(2)
	_ok("2 con la vida baja entra el latido (bucle)", int(Sensacion3D.cuenta["latido"]) == l0 + 1 and float(d.get("vol_latido")) > 0.0)
	await avanzar_s(Sensacion3D.T_LATIDO_ENTRA + 0.2)
	var lat: Node = d.get("_latido") as Node         # el bucle es un duplicado (sin resource_path): se mira el del director
	_ok("2 el latido suena en bucle y a tope", lat != null and float(d.get("vol_latido")) >= 1.0 and (lat.get("stream") as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, str(d.get("vol_latido")))
	var tono_medio: float = float(lat.get("pitch_scale")) if lat != null else 0.0
	j.vida = 1.0
	await avanzar(2)
	_ok("2 con menos vida late más deprisa", lat != null and float(lat.get("pitch_scale")) > tono_medio, "%.2f → %.2f" % [tono_medio, float(lat.get("pitch_scale")) if lat != null else 0.0])
	j.curar(Estado.i().vida_max)
	await avanzar_s(Sensacion3D.T_LATIDO_ENTRA + 0.3)
	_ok("2 curada, el latido se va", float(d.get("vol_latido")) <= 0.0 and (lat == null or not is_instance_valid(lat)))
	_limpiar()
	await avanzar(3)


# --- 3 · voltereta y recargas ------------------------------------------------------------------------------------------

func _caso_voltereta_y_recargas() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	j._roll_cd = 0.0
	await avanzar(2)
	_ok("3 lista: roll_cooldown_fraction = 0", is_zero_approx(j.roll_cooldown_fraction()))
	var v0: int = int(Sensacion3D.cuenta["voltereta"])
	var p0: int = int(Sensacion3D.cuenta["polvo"])
	j._iniciar_voltereta(Vector3(1, 0, 0))
	_ok("3 la voltereta suena y levanta polvo", int(Sensacion3D.cuenta["voltereta"]) == v0 + 1 and int(Sensacion3D.cuenta["polvo"]) == p0 + 1)
	await avanzar(2)
	var fr: float = j.roll_cooldown_fraction()
	_ok("3 recién usada, la fracción va cerca de 1 y baja", fr > 0.9 and fr <= 1.0, str(fr))
	var r0: int = int(Sensacion3D.cuenta["recarga_lista"])
	j._roll_cd = 0.1
	await avanzar_s(0.3)
	_ok("3 al volver a estar lista suena el clic", int(Sensacion3D.cuenta["recarga_lista"]) == r0 + 1 and is_zero_approx(j.roll_cooldown_fraction()))
	# Una página que recarga.
	_pagina("fuego", ["flecha"])
	lanzador.cooldown_total[0] = 1.0
	lanzador.cooldown_left[0] = 1.0
	await avanzar(2)
	r0 = int(Sensacion3D.cuenta["recarga_lista"])
	lanzador.cooldown_left[0] = 0.05
	await avanzar_s(0.3)
	_ok("3 una página que vuelve a estar lista también", int(Sensacion3D.cuenta["recarga_lista"]) == r0 + 1)
	# Puesta a cero DE GOLPE (una prueba, un laboratorio, el reinicio): sin clic.
	lanzador.cooldown_left[0] = 1.0
	await avanzar(2)
	r0 = int(Sensacion3D.cuenta["recarga_lista"])
	lanzador.cooldown_left[0] = 0.0
	await avanzar_s(0.3)
	_ok("3 una recarga puesta a cero de golpe no suena", int(Sensacion3D.cuenta["recarga_lista"]) == r0)
	_limpiar()
	await avanzar(3)


# --- 4 · andar con arranque y frenada ----------------------------------------------------------------------------------

func _caso_andar() -> void:
	var meta := Vector3(1.6, 0.0, 0.0)
	var v: Vector3 = Vector3.ZERO
	var t: float = 0.0
	var pasos: int = 0
	while v.distance_to(meta) > 0.001 and pasos < 200:
		v = Sensacion3D.velocidad_suelo(v, meta, 1.0 / 60.0)
		t += 1.0 / 60.0
		pasos += 1
	_ok("4 arranca hasta la velocidad de andar en ~%.2f s" % t, v.is_equal_approx(meta) and t > 0.08 and t < 0.2, str(t))
	var v1: Vector3 = Sensacion3D.velocidad_suelo(meta, meta, 0.5)
	_ok("4 a su velocidad no la pasa", v1.is_equal_approx(meta))
	t = 0.0
	v = meta
	while v.length() > 0.001 and t < 2.0:
		v = Sensacion3D.velocidad_suelo(v, Vector3.ZERO, 1.0 / 60.0)
		t += 1.0 / 60.0
	_ok("4 frena en ~%.2f s (más deprisa que arranca)" % t, v.length() < 0.001 and t < 0.1, str(t))
	var guardado: float = Sensacion3D.ACEL_SUELO
	Sensacion3D.ACEL_SUELO = 0.0
	_ok("4 con ACEL_SUELO = 0 es instantánea", Sensacion3D.velocidad_suelo(Vector3.ZERO, meta, 0.001).is_equal_approx(meta))
	Sensacion3D.ACEL_SUELO = guardado
	# Con la tecla pulsada de verdad: `vel_suelo` sube hasta la de andar.
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	_tecla(KEY_D, true)
	await avanzar(1)
	var v_primer: float = j.vel_suelo.length()
	await avanzar_s(0.4)
	var v_luego: float = j.vel_suelo.length()
	_tecla(KEY_D, false)
	_ok("4 con la tecla, vel_suelo arranca por debajo (%.2f) y llega a andar (%.2f)" % [v_primer, v_luego], v_primer < 1.6 and absf(v_luego - 1.6) < 0.05)
	await avanzar_s(0.3)
	_ok("4 al soltar, vel_suelo vuelve a cero", j.vel_suelo.length() < 0.001)
	_limpiar()
	await avanzar(3)


# --- 5 · cámara con adelanto -------------------------------------------------------------------------------------------

func _caso_camara() -> void:
	var m: Vector3 = Sensacion3D.meta_adelanto(Vector3(3.0, 0, 0), Vector3(0, 0, 1), false, true)
	_ok("5 corriendo hacia +X el foco se adelanta ADELANTO_MOV hacia +X", m.is_equal_approx(Vector3(Sensacion3D.ADELANTO_MOV, 0, 0)), str(m))
	var mc: Vector3 = Sensacion3D.meta_adelanto(Vector3(1.5, 0, 0), Vector3(0, 0, 1), false, true)
	_ok("5 arrancando a correr, la mitad (crece con la velocidad real)", absf(mc.x - m.x * 0.5) < 0.01, str(mc))
	_ok("5 andando (sin correr), nada: es un juego de leer el suelo", Sensacion3D.meta_adelanto(Vector3(1.6, 0, 0), Vector3(0, 0, 1), false, false).is_zero_approx())
	var ma: Vector3 = Sensacion3D.meta_adelanto(Vector3.ZERO, Vector3(0, 0, 1), true, false)
	_ok("5 quieta y apuntando: hacia donde mira, ADELANTO_APUNTA", ma.is_equal_approx(Vector3(0, 0, Sensacion3D.ADELANTO_APUNTA)), str(ma))
	var grande: Vector3 = Sensacion3D.meta_adelanto(Vector3(3.0, 0, 0), Vector3(1, 0, 0), true, true)
	_ok("5 nunca pasa de ADELANTO_MAX", grande.length() <= Sensacion3D.ADELANTO_MAX + 0.001, str(grande.length()))
	_ok("5 quieta sin apuntar: cero", Sensacion3D.meta_adelanto(Vector3.ZERO, Vector3(1, 0, 0), false, false).is_zero_approx())
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar_s(1.5)
	_ok("5 quieta, adelanto_actual ≈ 0", Sensacion3D.adelanto_actual.length() < 0.05, str(Sensacion3D.adelanto_actual))
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_D, true)
	await avanzar_s(1.2)
	var a: Vector3 = Sensacion3D.adelanto_actual
	_tecla(KEY_D, false)
	_tecla(KEY_SHIFT, false)
	_ok("5 corriendo con Mayús+D, el director adelanta el foco hacia donde va (%.2f u)" % a.length(), a.length() > Sensacion3D.ADELANTO_MOV * 0.8 and a.normalized().dot(j.vel_suelo.normalized() if j.vel_suelo.length() > 0.01 else a.normalized()) > 0.9)
	await avanzar_s(1.5)
	_ok("5 parada, vuelve a cero", Sensacion3D.adelanto_actual.length() < 0.05, str(Sensacion3D.adelanto_actual))
	_limpiar()
	await avanzar(3)


# --- 6 · impacto contra el mundo ---------------------------------------------------------------------------------------

func _caso_impacto_mundo() -> void:
	# Una pared: un muro de barrera de otro lanzamiento bloquea el proyectil («muro»).
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	var i0: int = int(Sensacion3D.cuenta["impacto_mundo"])
	var c: Vector2i = celda_jugador()
	var pared: Vector2i = Vector2i(c.x + 2, c.y)
	var encontrada: bool = false
	for k in range(2, 9):
		if Lanzador3D.celda_solida(Vector2i(c.x + k, c.y), 0):
			pared = Vector2i(c.x + k, c.y)
			encontrada = true
			break
	if not encontrada:
		# No hay pared cerca: la levanta un muro de tierra (nace donde se apunta y es sólido).
		lanzar_a_celda("tierra", ["barrera", "flecha"], Vector2i(c.x + 3, c.y), c)
		await avanzar_s(1.5)
		pared = Vector2i(c.x + 3, c.y)
	i0 = int(Sensacion3D.cuenta["impacto_mundo"])
	colocar_jugador(c)
	lanzar("fuego", ["flecha"], Vector3(1, 0, 0))
	await avanzar_s(2.5)
	_ok("6 un proyectil que se para contra una pared pide el impacto contra el mundo", int(Sensacion3D.cuenta["impacto_mundo"]) >= i0 + 1, "pared en %s" % str(pared))
	# Contra un enemigo: no es «mundo».
	_limpiar()
	await avanzar(3)
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))        # al oeste: al este está la pared de antes
	await avanzar(3)
	i0 = int(Sensacion3D.cuenta["impacto_mundo"])
	lanzar("fuego", ["flecha"], Vector3(-1, 0, 0))
	await avanzar_s(1.5)
	_ok("6 uno que acierta a un enemigo, no", int(Sensacion3D.cuenta["impacto_mundo"]) == i0 and g.impactos_visuales >= 1, str(g.impactos_visuales))
	_limpiar()
	await avanzar(3)


# --- 7 · carga -----------------------------------------------------------------------------------------------------------

func _caso_carga() -> void:
	_jugadora(Vector2i(11, 33))
	_pagina("fuego", ["flecha"])
	await avanzar(3)
	var c0: int = int(Sensacion3D.cuenta["carga"])
	lanzador.cast_page(0)
	await avanzar(1)
	var aro: Node = lanzador.get_node_or_null("AroCarga")
	_ok("7 entrar en el modo de lanzar monta el aro de carga", lanzador.modo_lanzar and aro != null and int(Sensacion3D.cuenta["carga"]) == c0 + 1)
	var zumbido: Node = aro.get("_zumbido") as Node if aro != null else null
	_ok("7 y su zumbido en bucle", zumbido != null and is_instance_valid(zumbido) and bool(zumbido.get("playing")) and (zumbido.get("stream") as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var r_antes: float = (aro as Node3D).scale.x if aro != null else 0.0
	await avanzar_s(Sensacion3D.T_CARGA + 0.1)
	var r_despues: float = (aro as Node3D).scale.x if aro != null and is_instance_valid(aro) else 0.0
	_ok("7 el aro se cierra (%.2f → %.2f u)" % [r_antes, r_despues], r_despues < r_antes and absf(r_despues - Sensacion3D.RADIO_CARGA.y) < 0.03)
	lanzador.call("_cancelar_modo")
	await avanzar_s(0.3)
	_ok("7 salir del modo apaga el aro", not lanzador.modo_lanzar and lanzador.get_node_or_null("AroCarga") == null and lanzador.get_node_or_null("AroCargaViejo") == null)
	_limpiar()
	await avanzar(3)


# --- 8 · apagada -----------------------------------------------------------------------------------------------------------

func _caso_apagada() -> void:
	Sensacion3D.ACTIVA = false
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	var s0: int = int(Sensacion3D.cuenta["golpe_son"])
	var d0: int = int(Sensacion3D.cuenta["dano_son"])
	var v0: int = int(Sensacion3D.cuenta["voltereta"])
	var c0: int = int(Sensacion3D.cuenta["carga"])
	g.golpe(_hechizo(), Vector3(-1, 0, 0))
	j._t_inv = 0.0
	j.recibir_dano(5.0)
	j._roll_cd = 0.0
	j._iniciar_voltereta(Vector3(1, 0, 0))
	_pagina("fuego", ["flecha"])
	lanzador.cast_page(0)
	await avanzar(2)
	_ok("8 apagada: ni golpe, ni daño, ni voltereta, ni aro", int(Sensacion3D.cuenta["golpe_son"]) == s0 and int(Sensacion3D.cuenta["dano_son"]) == d0
		and int(Sensacion3D.cuenta["voltereta"]) == v0 and int(Sensacion3D.cuenta["carga"]) == c0 and lanzador.get_node_or_null("AroCarga") == null)
	lanzador.call("_cancelar_modo")
	_ok("8 apagada: andar instantáneo y sin adelanto", Sensacion3D.velocidad_suelo(Vector3.ZERO, Vector3(1.6, 0, 0), 0.001).is_equal_approx(Vector3(1.6, 0, 0)))
	await avanzar_s(0.5)
	_ok("8 apagada: adelanto_actual a cero", Sensacion3D.adelanto_actual.length() < 0.05)
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar(3)
