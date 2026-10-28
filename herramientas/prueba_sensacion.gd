extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, LOTE 1 (28/10; presentacion/sensacion_3d.gd). Sobre la escena real del Bosque:
##   1 al DISPARAR: retroceso de la jugadora contra la dirección, golpe de zoom de la cámara que vuelve, destello en la mano y el sonido de salida;
##   2 al NO PODER (recarga): el golpe seco y la página que tiembla en el HUD;
##   3 la PULSACIÓN GUARDADA: la tecla de página pulsada al final de una voltereta entra al acabar (y si se soltó, lanza); pasados 0,15 s se niega; Ctrl pulsado durante un golpe F rueda al acabar;
##   4 contra un enemigo: hitstop proporcional al daño y compartido con la jugadora, número con «pop» (con «!» si es su debilidad), daño continuo sumado, partículas en la dirección;
##   5 el aviso de un enemigo: el cuerpo se encoge y suena;
##   6 al RECIBIR daño: viñeta roja, hitstop corto.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sensacion.gd

var _comprobaciones: int = 0
var _creados: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i, quieto: bool = true, debil: String = "") -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.quieto = quieto
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	g.debil = debil
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if lista is Array:
				(lista as Array).erase(n)
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()


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


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	await _caso_disparo()
	await _caso_no_puedes()
	await _caso_pulsacion_guardada()
	await _caso_enemigo()
	await _caso_aviso()
	await _caso_dano_recibido()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso_disparo() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(3)
	var cam: Camera3D = maqueta.get_viewport().get_camera_3d()
	var base: float = cam.size if cam != null else 0.0
	var antes: int = int(Sensacion3D.cuenta["disparo"])
	_pagina("fuego", ["flecha"])
	var este := Vector3(1, 0, 0)
	var lanzo: bool = lanzador.lanzar_pagina_ya(0, j.position, este)
	_ok("1 se lanza", lanzo)
	_ok("1 el disparo pide la sensación una vez", int(Sensacion3D.cuenta["disparo"]) == antes + 1)
	_ok("1 retroceso: la jugadora recibe un empujón CONTRA la dirección del disparo", j._empuje.dot(este) < -0.5, str(j._empuje))
	_ok("1 la cámara se acerca (golpe de zoom)", cam != null and cam.size < base - 0.001, "%.3f → %.3f" % [base, cam.size if cam != null else 0.0])
	_ok("1 suena la salida común", Sfx._ultima.has("lanzar_salida"))
	var p0: Vector3 = j.position
	await avanzar_s(0.5)
	var atras: float = (p0 - j.position).dot(este)
	_ok("1 retrocede poco (%.2f u)" % atras, atras > 0.05 and atras < 0.4)
	_ok("1 la cámara vuelve a su tamaño", cam == null or absf(cam.size - base) < 0.001, "%.3f vs %.3f" % [cam.size if cam != null else 0.0, base])
	await avanzar_s(1.0)


func _caso_no_puedes() -> void:
	_jugadora(Vector2i(11, 33))
	_pagina("fuego", ["flecha"])
	lanzador.cooldown_left[0] = 5.0
	var antes: int = int(Sensacion3D.cuenta["no_puedes"])
	lanzador.pulsar_pagina(0)
	_ok("2 en recarga, pulsar la página no entra", not lanzador.modo_lanzar)
	_ok("2 y da el «no puedes»", int(Sensacion3D.cuenta["no_puedes"]) == antes + 1 and Sfx._ultima.has("no_puedes"))
	var hud: Control = lanzador._page_hud
	_ok("2 la página 1 tiembla en el HUD", hud != null and int(hud.get("_temblor_i")) == 0 and int(hud.get("_temblor_hasta")) > Time.get_ticks_msec())
	lanzador.soltar_pagina(0)
	lanzador.cooldown_left[0] = 0.0
	await avanzar(3)


func _caso_pulsacion_guardada() -> void:
	# a) al final de la voltereta: entra al acabar
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	_pagina("fuego", ["flecha"])
	j._iniciar_voltereta(Vector3(1, 0, 0))
	while j._t_roll > 0.1:
		await avanzar(1)
	var no0: int = int(Sensacion3D.cuenta["no_puedes"])
	lanzador.pulsar_pagina(0)
	_ok("3a pulsar la página al final de la voltereta no se niega", not lanzador.modo_lanzar and lanzador._buffer_pagina == 0 and int(Sensacion3D.cuenta["no_puedes"]) == no0)
	var t: float = 0.0
	while t < 0.4 and not lanzador.modo_lanzar:
		t += await avanzar_s(1.0 / 30.0)
	_ok("3a al acabar de rodar entra en el modo rápido (%.2f s)" % t, lanzador.modo_lanzar and lanzador._rapido and t <= 0.2)
	lanzador.soltar_pagina(0)
	await avanzar_s(1.0)
	# b) pulsada y soltada mientras rueda: lanza al acabar
	j = _jugadora(Vector2i(11, 33))
	_pagina("fuego", ["flecha"])
	j._iniciar_voltereta(Vector3(1, 0, 0))
	while j._t_roll > 0.1:
		await avanzar(1)
	var disp0: int = int(Sensacion3D.cuenta["disparo"])
	lanzador.pulsar_pagina(0)
	lanzador.soltar_pagina(0)
	t = 0.0
	while t < 0.3 and lanzador.cooldown_left[0] <= 0.0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("3b pulsar y soltar durante la voltereta: al acabar de rodar se suelta (cobra la recarga a los %.2f s)" % t, lanzador.cooldown_left[0] > 0.0 and t <= 0.2 and not lanzador.modo_lanzar)
	await avanzar_s(1.5)                                   # el conjuro (el clip de lanzar) tarda en soltar el hechizo
	_ok("3b y el hechizo sale", int(Sensacion3D.cuenta["disparo"]) == disp0 + 1)
	await avanzar_s(1.0)
	# c) pulsada al empezar la voltereta: a los 0,15 s se niega
	j = _jugadora(Vector2i(11, 33))
	_pagina("fuego", ["flecha"])
	j._iniciar_voltereta(Vector3(1, 0, 0))
	await avanzar(1)
	no0 = int(Sensacion3D.cuenta["no_puedes"])
	lanzador.pulsar_pagina(0)
	await avanzar_s(0.3)
	_ok("3c pulsada al empezar a rodar, pasados 0,15 s se niega", lanzador._buffer_pagina == -1 and not lanzador.modo_lanzar and int(Sensacion3D.cuenta["no_puedes"]) == no0 + 1)
	lanzador.soltar_pagina(0)
	await avanzar_s(1.0)
	# d) Ctrl durante un golpe F: rueda al acabar
	j = _jugadora(Vector2i(11, 33))
	_ok("3d hay golpe F", j._iniciar_golpe_cuerpo())
	while j._t_pegar > 0.2:
		await avanzar(1)
	_tecla(KEY_CTRL, true)
	await avanzar(2)                                       # el evento de tecla se ve en el fotograma siguiente
	_tecla(KEY_CTRL, false)
	_ok("3d Ctrl en el final del golpe no rueda todavía", j._t_roll <= 0.0 and j._roll_guardado > 0.0)
	t = 0.0
	while t < 0.4 and j._t_roll <= 0.0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("3d y rueda en cuanto acaba el golpe (%.2f s)" % t, j._t_roll > 0.0 and t <= 0.2)
	await avanzar_s(1.0)


func _caso_enemigo() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(10, 33), true, "fuego")
	await avanzar(3)
	var fx: Vfx3D = lanzador.fx
	var n_part0: int = fx.get_children().filter(func(n): return n is GPUParticles3D).size() if fx != null else 0
	var etiquetas0: Array = maqueta.get_children().filter(func(n): return n is Label3D)
	var v0: float = g.health
	_pagina("fuego", ["flecha"])
	lanzador.lanzar_pagina_ya(0, j.position, Vector3(-1, 0, 0))
	var t: float = 0.0
	while t < 1.0 and g.health >= v0:
		t += await avanzar_s(1.0 / 60.0)
	var dano: float = v0 - g.health
	_ok("4 el fuego le da (%.0f; es su debilidad)" % dano, dano > 0.0)
	_ok("4 hitstop del enemigo = el proporcional (el máximo: débil)", absf(g._hitstop - Combate3D.HITSTOP_DEBIL) < 0.02, "%.3f" % g._hitstop)
	_ok("4 la jugadora se congela también (hitstop compartido)", j._t_hitstop > 0.0 and j._t_hitstop <= Combate3D.HITSTOP_DEBIL * Sensacion3D.HITSTOP_COMPARTIDO + 0.001, "%.3f" % j._t_hitstop)
	var nuevas: Array = maqueta.get_children().filter(func(n): return n is Label3D and not etiquetas0.has(n))
	var num: Label3D = null
	for l in nuevas:
		if (l as Label3D).text.ends_with("!"):
			num = l
	_ok("4 el número sale con «!» por ser su debilidad, del color del fuego", num != null and (num.modulate.r > 0.9 and num.modulate.b < 0.7), str(nuevas.map(func(l): return l.text)))
	_ok("4 y con «pop»: más grande que su tamaño final, encogiendo", num != null and num.scale.x > 1.45, str(num.scale if num != null else null))
	var dir_ok: bool = false
	if fx != null:
		for n in fx.get_children():
			if n is GPUParticles3D and ((n as GPUParticles3D).process_material as ParticleProcessMaterial).spread == 35.0:
				var d: Vector3 = ((n as GPUParticles3D).process_material as ParticleProcessMaterial).direction
				dir_ok = d.x < -0.5
	_ok("4 partículas en la dirección del golpe (hacia el oeste)", dir_ok)
	# daño continuo: la quemadura suma en un solo número
	await avanzar_s(1.6)
	_ok("4 la quemadura se SUMA en un número (%.0f)" % g._suma_continua, g._suma_continua >= 6.0 and is_instance_valid(g._num_continuo), "")
	_limpiar()
	await avanzar_s(0.5)


func _caso_aviso() -> void:
	_jugadora(Vector2i(10, 33))
	var g: Combate3D = _goblin(Vector2i(11, 33), false)
	var t: float = 0.0
	while t < 8.0 and g.avisos_dados == 0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("5 el guerrero avisa", g.avisos_dados >= 1)
	var min_y: float = 99.0
	for i in range(6):
		await avanzar(1)
		min_y = minf(min_y, g.pj.scale.y / maxf(g._squash.y, 0.001) * g._squash.y)
	_ok("5 al avisar se encoge (escala y mínima %.2f de %.2f)" % [min_y, g.pj.scale.y], g._squash.y < 0.99 or min_y < g.pj.scale.y)
	_ok("5 el aviso suena", Sfx._ultima.has("aviso_ataque"))
	_limpiar()
	await avanzar_s(0.5)


func _caso_dano_recibido() -> void:
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar(2)
	var antes: int = int(Sensacion3D.cuenta["dano"])
	j.recibir_dano(15.0, j.position + Vector3(1, 0, 0))
	_ok("6 recibir un golpe pide la sensación", int(Sensacion3D.cuenta["dano"]) == antes + 1)
	var capa: CanvasLayer = j.get_meta("vineta_dano") if j.has_meta("vineta_dano") else null
	var fuerza: float = float(((capa.get_node("R") as ColorRect).material as ShaderMaterial).get_shader_parameter("fuerza")) if capa != null else 0.0
	_ok("6 viñeta roja encendida (%.2f)" % fuerza, capa != null and fuerza > 0.2)
	_ok("6 hitstop corto de la jugadora", j._t_hitstop > 0.0 and j._t_hitstop <= Sensacion3D.HITSTOP_DANO + 0.001)
	await avanzar_s(0.5)
	fuerza = float(((capa.get_node("R") as ColorRect).material as ShaderMaterial).get_shader_parameter("fuerza")) if capa != null else 1.0
	_ok("6 y se apaga sola (%.2f)" % fuerza, fuerza < 0.01)
