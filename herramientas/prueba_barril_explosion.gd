extends "res://herramientas/escenario_base.gd"
## BARRIL DE PÓLVORA · EXPLOSIÓN Y ÁREA (4/11/2026, decisión de Pablo: como las bombas de Echoes of Wisdom). Sobre la ESCENA REAL (PruebaBosque: Jugador3D, Lanzador3D, Combate3D reales), sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_barril_explosion.gd
## Comprueba:
##   1. el AVISO aparece al encender con radio = Barril3D.RADIO, avanza con la mecha (llenado y ritmo del latido suben) y desaparece al apagar con agua;
##   2. la explosión pone UNA sola ExplosionFuegoToy; el frente de su onda llega a RADIO en T_ONDA; el aviso se va; no queda ningún nodo del VFX vivo a los 1,6 s;
##   3. un enemigo dentro pierde vida (y sale despedido) y uno fuera no; la jugadora dentro pierde vida, fuera no, y con invulnerabilidad no pierde más;
##   4. la CADENA: un barril vecino se enciende, enseña su aviso y explota a su vez; 5. un muro agrietado vecino se rompe; 6. los colores de la rampa que usa el VFX no pasan a amarillo.

var _claro: Vector2i = Vector2i.ZERO
var _goblins: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _poner_j(p: Vector3) -> void:
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p


func _barril(c: Vector2i) -> Barril3D:
	var b := Barril3D.new()
	b.preparar(c)
	maqueta.add_child(b)
	return b


func _goblin(p: Vector3) -> Combate3D:
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100.0
	g.vida_max = 100.0
	_goblins.append(g)
	return g


func _contar(clase_o_grupo: String) -> int:
	return get_nodes_in_group(clase_o_grupo).size()


## Cuántos nodos del VFX de explosión y del aviso siguen en el árbol (clase por nombre de clase global).
func _vivos_vfx() -> Dictionary:
	var r: Dictionary = {"explosion": 0, "impacto": 0, "aviso": 0, "gpu": 0}
	var pila: Array = [root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is ExplosionFuegoToy:
			r["explosion"] += 1
		elif n is ImpactoFuegoToy:
			r["impacto"] += 1
		elif n is AvisoAreaFuego:
			r["aviso"] += 1
		elif n is GPUParticles3D and n.get_parent() is ImpactoFuegoToy:
			r["gpu"] += 1
		pila.append_array(n.get_children())
	return r


func _espera_explosion(b: Barril3D, max_s: float = 3.0) -> float:
	var t0: float = reloj.t
	while not b.explotado and reloj.t - t0 < max_s:
		await process_frame
	return reloj.t - t0


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	for n in get_nodes_in_group("combate3d"):         # nadie más: los goblins del bosque no pintan nada aquí
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	# un claro llano de 5×5 casillas (la casilla mide 2,3 u: ±5,75 u alrededor del centro)
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(3, alto - 3):
		for x in range(3, ancho - 3):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var v := c + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	_ok("0 hay un claro llano de 5×5 casillas", mejor.x >= 0)
	if mejor.x < 0:
		return
	_claro = mejor
	var centro: Vector3 = _pos(_claro)
	var lejos_j: Vector2i = _claro + Vector2i(-2, -2)             # ≈ 6,5 u del barril: fuera del área
	colocar_jugador(lejos_j)
	await avanzar_s(0.5)

	# ---------- 1 · El aviso ----------
	var base: Dictionary = _vivos_vfx()
	_ok("1 sin barril encendido no hay aviso", int(base["aviso"]) == 0 and int(base["explosion"]) == 0)
	var b: Barril3D = _barril(_claro)
	await avanzar(2)
	_ok("1 un barril entero no lleva aviso", b.aviso == null and int(_vivos_vfx()["aviso"]) == 0)
	b.encender()
	await avanzar(2)
	_ok("1 al encender aparece UN aviso", b.aviso != null and int(_vivos_vfx()["aviso"]) == 1)
	_ok("1 el aviso es de radio = Barril3D.RADIO (%.2f u)" % Barril3D.RADIO, b.aviso != null and absf(b.aviso.radio - Barril3D.RADIO) < 0.001 and absf(b.aviso.radio_dibujado() - Barril3D.RADIO) < 0.001,
		"radio %.3f · dibujado %.3f" % [b.aviso.radio if b.aviso != null else -1.0, b.aviso.radio_dibujado() if b.aviso != null else -1.0])
	_ok("1 el aviso cuelga a ras del suelo del barril", b.aviso != null and absf(b.aviso.global_position.y - b.global_position.y) < 0.01 and Vector2(b.aviso.global_position.x - centro.x, b.aviso.global_position.z - centro.z).length() < 0.01)
	var p1: float = b.aviso.progreso if b.aviso != null else -1.0
	var hz1: float = b.aviso.ritmo_hz() if b.aviso != null else -1.0
	await avanzar_s(0.6)
	var p2: float = b.aviso.progreso if b.aviso != null else -1.0
	var hz2: float = b.aviso.ritmo_hz() if b.aviso != null else -1.0
	_ok("1 el aviso se llena con la mecha (progreso %.2f → %.2f, a medias ≈ 0,5)" % [p1, p2], p2 > p1 and absf(p2 - 0.5) < 0.15)
	_ok("1 el latido va más deprisa según se acaba la mecha (%.1f → %.1f Hz)" % [hz1, hz2], hz2 > hz1 + 1.0 and hz1 >= AvisoAreaFuego.LATIDO_INI_HZ - 0.01 and hz2 < AvisoAreaFuego.LATIDO_FIN_HZ)
	# el agua apaga la mecha: el aviso desaparece
	var agua := RuneData.new()
	agua.tags = ["agua"]
	_ok("1 el agua reacciona con la mecha encendida", b.spell_reacts(agua))
	b.on_spell_hit(agua)
	await avanzar(2)
	_ok("1 apagada con agua: no arde, no hay aviso y no explota", not b.encendido and b.aviso == null and int(_vivos_vfx()["aviso"]) == 0 and not b.explotado)
	await avanzar_s(1.0)
	_ok("1 sigue sin explotar tras el tiempo de la mecha", not b.explotado)

	# ---------- 2/3 · Explosión con enemigos y jugadora ----------
	var dentro: Combate3D = _goblin(centro + Vector3(1.4, 0.0, 0.0))
	var fuera: Combate3D = _goblin(centro + Vector3(0.0, 0.0, 4.0))
	var al_borde: Combate3D = _goblin(centro + Vector3(-(Barril3D.RADIO - 0.15), 0.0, 0.0))
	var mas_alla: Combate3D = _goblin(centro + Vector3(0.0, 0.0, -(Barril3D.RADIO + 0.3)))
	await avanzar_s(0.5)
	var vd: float = dentro.health
	var vf: float = fuera.health
	var vb: float = al_borde.health
	var vm: float = mas_alla.health
	var pd0: Vector3 = dentro.position
	var vj0: float = float(jugador.get("vida"))
	b.encender()
	var t_mecha: float = await _espera_explosion(b)
	var t_exp: float = reloj.t
	_ok("2 el barril explota a los T_MECHA s (%.2f s)" % t_mecha, b.explotado and absf(t_mecha - Barril3D.T_MECHA) < 0.2)
	await avanzar(1)
	var v: Dictionary = _vivos_vfx()
	_ok("2 sale UNA sola explosión de fuego y el aviso se ha ido", int(v["explosion"]) == 1 and int(v["aviso"]) == 0 and b.aviso == null, str(v))
	_ok("2 la explosión usa la bola (estilo B) y las chispas (estilo C) de ImpactoFuegoToy", int(v["impacto"]) == 2, str(v))
	_ok("2 el barril ya no se ve (cuerpo y aro) y no se puede golpear", not b._cuerpo.visible and not b._aro.visible and b.collision_layer == 0)
	var ex: ExplosionFuegoToy = b.explosion_vfx
	_ok("2 la explosión nace donde estaba el barril", ex != null and ex.global_position.distance_to(b.global_position) < 0.01)
	_ok("2 el frente de la onda llega a RADIO (%.2f u) en T_ONDA (%.2f s)" % [Barril3D.RADIO, ExplosionFuegoToy.T_ONDA], ex != null and absf(ex.radio_onda(ExplosionFuegoToy.T_ONDA) - Barril3D.RADIO) < 0.001 and ex.radio_onda(ExplosionFuegoToy.T_ONDA * 0.5) < Barril3D.RADIO and ex.radio_onda(ExplosionFuegoToy.T_ONDA * 0.5) > 0.0)
	var onda_ahora: float = -1.0
	var escala_caja: float = -1.0
	# avanza hasta que el frente debería estar al máximo y lee lo que de verdad está puesto en el shader
	await avanzar_s(ExplosionFuegoToy.T_ONDA + 0.05 - (reloj.t - t_exp))
	if ex != null and is_instance_valid(ex):
		var caja: MeshInstance3D = ex.get_node("Onda") as MeshInstance3D
		onda_ahora = float((caja.material_override as ShaderMaterial).get_shader_parameter("onda"))
		escala_caja = caja.scale.x * 0.5 * onda_ahora
	_ok("2 en el shader el frente está en 1,0 del radio y la caja mide 2·RADIO (alcance real %.2f u)" % escala_caja, absf(onda_ahora - 1.0) < 0.01 and absf(escala_caja - Barril3D.RADIO) < 0.03)
	_ok("2 el enemigo DENTRO (1,4 u) pierde vida (%.0f → %.0f)" % [vd, dentro.health], dentro.health < vd - 10.0 and b.golpeados.has(dentro))
	_ok("2 sale despedido (%.1f u)" % Vector2(dentro.position.x - pd0.x, dentro.position.z - pd0.z).length(), Vector2(dentro.position.x - pd0.x, dentro.position.z - pd0.z).length() > 0.5)
	_ok("2 el enemigo FUERA (4,0 u) no pierde vida", fuera.health == vf and not b.golpeados.has(fuera))
	_ok("2 el enemigo justo dentro del borde (%.2f u) pierde vida" % (Barril3D.RADIO - 0.15), al_borde.health < vb - 10.0)
	_ok("2 el enemigo justo fuera del borde (%.2f u) no" % (Barril3D.RADIO + 0.3), mas_alla.health == vm)
	_ok("2 la jugadora (6,5 u) no se entera", float(jugador.get("vida")) == vj0 and not b.jugadora_alcanzada)
	# limpiar la tanda y esperar a que no quede nada
	await avanzar_s(1.6 - (reloj.t - t_exp))
	var v2: Dictionary = _vivos_vfx()
	_ok("2 a los 1,6 s no queda ningún nodo del VFX vivo", int(v2["explosion"]) == 0 and int(v2["impacto"]) == 0 and int(v2["aviso"]) == 0 and int(v2["gpu"]) == 0, str(v2))
	for g in _goblins:
		if is_instance_valid(g):
			g.position = Vector3(-500.0, 0.0, -500.0)
	_goblins.clear()

	# ---------- 3 · La jugadora ----------
	_poner_j(centro + Vector3(1.2, 0.0, 0.0))
	await avanzar_s(1.0)                                  # que no le quede invulnerabilidad de nada
	var b2: Barril3D = _barril(_claro)
	var vj1: float = float(jugador.get("vida"))
	b2.encender()
	await _espera_explosion(b2)
	await avanzar(2)
	var vj2: float = float(jugador.get("vida"))
	_ok("3 la jugadora DENTRO (1,2 u) pierde %.0f de vida (%.0f → %.0f)" % [Barril3D.DANO_JUGADORA, vj1, vj2], b2.jugadora_alcanzada and vj2 < vj1 - 5.0 and vj2 >= vj1 - Barril3D.DANO_JUGADORA - 0.01)
	# invulnerabilidad: otra explosión enseguida no vuelve a quitarle
	var b3: Barril3D = _barril(_claro)
	b3.encender()
	b3._t = 0.05
	await _espera_explosion(b3)
	await avanzar(2)
	_ok("3 con la invulnerabilidad puesta, la segunda explosión no le quita más (%.0f)" % float(jugador.get("vida")), b3.jugadora_alcanzada and float(jugador.get("vida")) == vj2)
	await avanzar_s(2.0)
	# fuera del área (3,2 u en el plano) no
	_poner_j(centro + Vector3(0.0, 0.0, 3.2))
	await avanzar_s(1.0)
	var vj3: float = float(jugador.get("vida"))
	var b4: Barril3D = _barril(_claro)
	b4.encender()
	await _espera_explosion(b4)
	await avanzar(2)
	_ok("3 la jugadora FUERA (3,2 u) no pierde vida (%.0f)" % float(jugador.get("vida")), not b4.jugadora_alcanzada and float(jugador.get("vida")) == vj3)
	# a mucha altura (dos niveles: Δy 2,5 u) no la alcanza
	await avanzar_s(1.0)
	_poner_j(centro + Vector3(0.5, Barril3D.ALTO_AFECTA + 0.9, 0.0))
	var vj4: float = float(jugador.get("vida"))
	var b5: Barril3D = _barril(_claro)
	b5.encender()
	b5._t = 0.05
	await _espera_explosion(b5)
	_ok("3 en el plano dentro pero 2,5 u más arriba, la explosión no la alcanza", not b5.jugadora_alcanzada and float(jugador.get("vida")) == vj4)
	colocar_jugador(lejos_j)
	await avanzar_s(0.5)

	# ---------- 4 · La cadena ----------
	var c1: Barril3D = _barril(_claro)
	var c2: Barril3D = _barril(_claro + Vector2i(1, 0))               # a 2,3 u (< RADIO)
	var c3: Barril3D = _barril(_claro + Vector2i(-2, 2))               # lejos (> RADIO): no se entera
	await avanzar(2)
	c1.encender()
	await _espera_explosion(c1)
	await avanzar(2)
	_ok("4 el barril vecino (2,3 u) se enciende por la explosión y enseña SU aviso", c2.encendido and c2.aviso != null and not c2.explotado)
	_ok("4 el barril lejano no se entera", not c3.encendido and c3.aviso == null)
	var t2: float = await _espera_explosion(c2)
	_ok("4 el vecino explota a su vez ~T_MECHA s después (%.2f s)" % t2, c2.explotado and absf(t2 - Barril3D.T_MECHA) < 0.4)
	await avanzar_s(1.7)

	# ---------- 5 · Lo que se rompe ----------
	var mu := MuroAgrietado3D.new()
	mu.preparar(_claro + Vector2i(0, 1), 3)
	maqueta.add_child(mu)
	var r := _barril(_claro)
	await avanzar(2)
	_ok("5 el muro agrietado está en el grupo de lo que recibe explosiones", mu.is_in_group("explosionable"))
	r.encender()
	await _espera_explosion(r)
	await avanzar(2)
	_ok("5 la explosión rompe el muro agrietado vecino de una vez", mu.roto_ya)
	await avanzar_s(1.7)

	# ---------- 6 · Colores ----------
	FuegoToy._rampas()
	var g_alto: Color = FuegoToy._rampa_bola.gradient.sample(0.85)
	var g_med: Color = FuegoToy._rampa_bola.gradient.sample(0.5)
	_ok("6 el tono más alto que usa el decal (rampa de la bola en 0,85) es naranja, no amarillo: g/r %.2f, b %.2f" % [g_alto.g / g_alto.r, g_alto.b], g_alto.g / g_alto.r < 0.72 and g_alto.b < 0.25)
	_ok("6 la masa del decal (rampa en 0,5) es rojo-naranja: g/r %.2f" % (g_med.g / g_med.r), g_med.g / g_med.r < 0.5)
	var f: Dictionary = _vivos_vfx()
	_ok("7 al final no queda nada vivo del VFX", int(f["explosion"]) == 0 and int(f["impacto"]) == 0 and int(f["aviso"]) == 0, str(f))
