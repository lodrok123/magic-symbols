extends "res://herramientas/escenario_base.gd"
## G1 (22/11, PLAN_GAMEFEEL_2026-11-22 §2.2): BUFFER DEL GOLPE F, PRIORIDAD ENTRE ACCIONES Y FASES. Sobre la escena real del Bosque:
##   1 F pulsada al final de una voltereta: golpea en cuanto acaba de rodar;
##   2 F pulsada al empezar a rodar: pasados 0,15 s caduca y no golpea al acabar;
##   3 F pulsada con la recarga del golpe lejos de acabar (aporrear F): no se guarda;
##   4 F pulsada con la recarga a punto de acabar: golpea al acabar la recarga;
##   5 PRIORIDAD: Ctrl y F a la vez mientras algo breve lo impide: sale la voltereta y el golpe guardado se descarta;
##   6 FASES (`Jugador3D.fase_accion`): golpe preparación → ejecución → recuperación; voltereta = ejecución; lanzar con conjuro: preparación y luego recuperación.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_buffer_golpe.gd


func _jugadora(c: Vector2i) -> Jugador3D:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._t_pegar = 0.0
	j._pegar_cd = 0.0
	j._pegar_guardado = 0.0
	j._roll_guardado = 0.0
	j._t_gesto = 0.0
	j._t_hitstop = 0.0
	j._empuje = Vector3.ZERO
	return j


## Pulsa y suelta una tecla (el evento se ve en el fotograma siguiente).
func _pulsar(tecla: Key) -> void:
	_tecla(tecla, true)
	await avanzar(2)
	_tecla(tecla, false)
	await avanzar(1)


## Espera hasta `max_s` a que empiece un golpe F; devuelve los segundos que pasaron (o > max_s si no empezó).
func _esperar_golpe(j: Jugador3D, max_s: float) -> float:
	var t: float = 0.0
	while t <= max_s and j._t_pegar <= 0.0:
		t += await avanzar_s(1.0 / 30.0)
	return t


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	var c := Vector2i(11, 33)

	# 1 · F al final de la voltereta
	var j: Jugador3D = _jugadora(c)
	j._iniciar_voltereta(Vector3(1, 0, 0))
	while j._t_roll > 0.1:
		await avanzar(1)
	await _pulsar(KEY_F)
	_ok("1 F al final de la voltereta no golpea todavía, se guarda", j._t_pegar <= 0.0 and j._pegar_guardado > 0.0 or j._t_roll <= 0.0 and j._t_pegar > 0.0)
	var t: float = await _esperar_golpe(j, 0.4)
	_ok("1 y golpea en cuanto acaba de rodar (%.2f s)" % t, j._t_pegar > 0.0 and t <= 0.2)
	await avanzar_s(1.5)

	# 2 · F al empezar a rodar: caduca
	j = _jugadora(c)
	j._iniciar_voltereta(Vector3(1, 0, 0))
	await avanzar(1)
	await _pulsar(KEY_F)
	_ok("2 F al empezar a rodar se guarda", j._pegar_guardado > 0.0)
	while j._t_roll > 0.0:
		await avanzar(1)
	t = await _esperar_golpe(j, 0.4)
	_ok("2 pasados 0,15 s caduca: no golpea al acabar de rodar", j._t_pegar <= 0.0 and j._pegar_guardado <= 0.0)
	await avanzar_s(1.5)

	# 3 · aporrear F durante un golpe: no se guarda
	j = _jugadora(c)
	_ok("3 hay golpe F", j._iniciar_golpe_cuerpo())
	await avanzar(3)
	await _pulsar(KEY_F)
	_ok("3 F con la recarga lejos de acabar (%.2f s) no se guarda" % j._pegar_cd, j._pegar_guardado <= 0.0)
	await avanzar_s(1.5)

	# 4 · F con la recarga a punto de acabar
	j = _jugadora(c)
	j._pegar_cd = 0.12
	await _pulsar(KEY_F)
	t = await _esperar_golpe(j, 0.4)
	_ok("4 F con la recarga a punto de acabar golpea al acabar la recarga (%.2f s)" % t, j._t_pegar > 0.0 and t <= 0.2)
	await avanzar_s(1.5)

	# 5 · prioridad: voltereta antes que golpe
	j = _jugadora(c)
	j._t_gesto = 0.12                                     # algo breve que impide las dos (un gesto)
	_tecla(KEY_CTRL, true)
	_tecla(KEY_F, true)
	await avanzar(2)
	_tecla(KEY_CTRL, false)
	_tecla(KEY_F, false)
	_ok("5 Ctrl y F a la vez durante el gesto: las dos quedan guardadas", j._roll_guardado > 0.0 and j._pegar_guardado > 0.0, "roll %.2f · golpe %.2f" % [j._roll_guardado, j._pegar_guardado])
	t = 0.0
	var rodo: bool = false
	var golpeo: bool = false
	while t < 1.2:
		t += await avanzar_s(1.0 / 30.0)
		rodo = rodo or j._t_roll > 0.0
		golpeo = golpeo or j._t_pegar > 0.0
	_ok("5 sale la voltereta", rodo)
	_ok("5 y el golpe guardado se descarta (no golpea ni durante ni después)", not golpeo and j._pegar_guardado <= 0.0)
	await avanzar_s(1.0)

	# 6 · fases
	j = _jugadora(c)
	j._iniciar_golpe_cuerpo()
	var vistas: Array = []
	while j._t_pegar > 0.0:
		var f: Dictionary = j.fase_accion()
		if f["accion"] == "golpe" and (vistas.is_empty() or vistas[-1] != f["fase"]):
			vistas.append(f["fase"])
		await avanzar(1)
	_ok("6 golpe F: preparación → ejecución → recuperación", vistas == ["preparacion", "ejecucion", "recuperacion"], str(vistas))
	await avanzar_s(1.0)
	j = _jugadora(c)
	j._iniciar_voltereta(Vector3(1, 0, 0))
	_ok("6 voltereta: ejecución", j.fase_accion() == {"accion": "voltereta", "fase": "ejecucion"}, str(j.fase_accion()))
	while j._t_roll > 0.0:
		await avanzar(1)
	_ok("6 sin nada en curso: vacía", j.fase_accion()["accion"] == "", str(j.fase_accion()))
	await avanzar_s(1.6)
	j = _jugadora(c)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	var lanzo: bool = lanzador.lanzar_pagina_ya(0, j.position, Vector3(1, 0, 0), true)
	_ok("6 se lanza con conjuro", lanzo)
	var fases_l: Array = []
	t = 0.0
	while t < 4.0:
		var fl: Dictionary = j.fase_accion()
		if fl["accion"] == "lanzar" and (fases_l.is_empty() or fases_l[-1] != fl["fase"]):
			fases_l.append(fl["fase"])
		if fl["accion"] == "" and not fases_l.is_empty():
			break
		t += await avanzar_s(1.0 / 30.0)
	_ok("6 lanzar: preparación (conjuro) → recuperación (hechizo ya fuera)", fases_l == ["preparacion", "recuperacion"], str(fases_l))
