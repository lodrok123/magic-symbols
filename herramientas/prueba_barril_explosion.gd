extends "res://herramientas/escenario_base.gd"
## BARRIL DE PÓLVORA · EXPLOSIÓN Y ÁREA (4/11/2026, decisión de Pablo: como las bombas de Echoes of Wisdom). Sobre la ESCENA REAL (PruebaBosque: Jugador3D, Lanzador3D, Combate3D reales), sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_barril_explosion.gd
## Comprueba:
##   1. el AVISO aparece al encender con radio = Barril3D.RADIO, avanza con la mecha (llenado y ritmo del latido suben) y desaparece al apagar con agua;
##   2. la explosión pone UNA sola ExplosionFuegoToy; el frente de su onda llega a RADIO en T_ONDA; el aviso se va; no queda ningún nodo del VFX vivo a los 1,6 s;
##   3. un enemigo dentro pierde vida (y sale despedido) y uno fuera no; la jugadora dentro pierde vida, fuera no, y con invulnerabilidad no pierde más;
##   4. la CADENA: un barril vecino se enciende, enseña su aviso y explota a su vez; 5. un muro agrietado vecino se rompe; 6. los colores de la rampa que usa el VFX no pasan a amarillo.
## 5/11/2026: 8. el MODELO de Meshy (mide, centrado, sin girar, colisión, mecha, chispas, parpadeo sin saturar) y el fuego añadido a la explosión (6 lenguas, 5 brasas, envolventes);
##   9-15. el BARRIL PEQUEÑO lanzable: datos y mapa (`tam=pequeno`), se coge, encendido en brazos explota en las manos dañando a la jugadora, lanzado sin encender no explota, encendido explota al impactar
##   (daño y radio menores), al acabar la mecha en el aire, contra una pared, y la cadena con un barril grande.

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


func _peq(c: Vector2i) -> Barril3D:
	var b := Barril3D.new()
	b.preparar(c, true)
	maqueta.add_child(b)
	return b


## Apunta la explosión de `b` (el barril pequeño se libera al explotar: se lee todo en el momento de la señal).
func _vigilar(b: Barril3D) -> Dictionary:
	var rec: Dictionary = {"n": 0, "punto": Vector3.ZERO, "radio": 0.0, "t": 0.0, "alcanzada": false, "golpeados": [], "en_brazos": false}
	b.explota.connect(func(p: Vector3, r: float) -> void:
		rec["n"] = int(rec["n"]) + 1
		rec["punto"] = p
		rec["radio"] = r
		rec["t"] = reloj.t
		rec["alcanzada"] = b.jugadora_alcanzada
		rec["golpeados"] = b.golpeados.duplicate()
		rec["en_brazos"] = b.en_brazos)
	return rec


func _espera_rec(rec: Dictionary, max_s: float = 5.0) -> void:
	var t0: float = reloj.t
	while int(rec["n"]) == 0 and reloj.t - t0 < max_s:
		await process_frame


func _hasta_estado(c: CargarObjeto3D, e: int, max_s: float = 3.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and c.estado != e:
		await process_frame
	return c.estado == e


## La jugadora de cara a +X en `cel`, con la vida llena y sin invulnerabilidad.
func _preparar_j(cel: Vector2i) -> void:
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(cel)
	j.mirar_hacia(Vector3.RIGHT)
	(j.pj as Pj3D).mirar(Vector3.RIGHT, 1.0)
	j.vida = Estado.i().vida_max
	await avanzar_s(1.0)


## Coge el barril pequeño `b` (la jugadora a su lado) y espera a que lo lleve sobre la cabeza.
func _coger_peq(b: Barril3D) -> bool:
	var j: Jugador3D = jugador as Jugador3D
	var c: CargarObjeto3D = j.carga
	var hecho: bool = c.coger(b)
	var ok: bool = await _hasta_estado(c, CargarObjeto3D.Estado.CARGANDO)
	await avanzar(3)
	return hecho and ok


func _pequeno(lejos_j: Vector2i) -> void:
	var j: Jugador3D = jugador as Jugador3D
	var c: CargarObjeto3D = j.carga
	var oeste: Vector2i = _claro + Vector2i(-2, 0)
	var pc: Vector2i = _claro + Vector2i(-1, 0)
	await _preparar_j(oeste)
	lanzador.tinta = null

	# ---------- 9 · El barril pequeño: medidas, datos y mapa ----------
	var s1: Barril3D = _peq(pc)
	await avanzar(3)
	_modelo(s1)
	_ok("9 el pequeño: radio %.1f (grande %.1f), daño %.0f/%.0f (grande %.0f/%.0f), mecha %.1f s" % [s1.radio, Barril3D.RADIO, s1.dano_enemigo, s1.dano_jugadora, Barril3D.DANO_ENEMIGO, Barril3D.DANO_JUGADORA, s1.t_mecha],
		s1.radio == Barril3D.RADIO_PEQUENO and s1.radio < Barril3D.RADIO and s1.dano_enemigo == Barril3D.DANO_ENEMIGO_PEQUENO and s1.dano_enemigo < Barril3D.DANO_ENEMIGO
		and s1.dano_jugadora == Barril3D.DANO_JUGADORA_PEQUENO and s1.dano_jugadora < Barril3D.DANO_JUGADORA and absf(s1.t_mecha - Barril3D.T_MECHA_PEQUENO) < 0.001)
	var fila: Dictionary = CargarObjeto3D.COGIBLES.get("barril_pequeno", {})
	_ok("9 nace cogible: grupo, metadato = barril_pequeno, fila de COGIBLES que NO es ligera (se carga sobre la cabeza) y tapa su casilla", s1.is_in_group("cogible") and String(s1.get_meta("cogible", "")) == "barril_pequeno"
		and not fila.is_empty() and not CargarObjeto3D.es_ligero(fila) and not bool(fila["rompe"]) and Terreno3D.bloqueada(pc))
	var gr0: Barril3D = _barril(_claro + Vector2i(2, 2))
	await avanzar(2)
	_ok("9 el grande NO es cogible", not gr0.is_in_group("cogible") and not gr0.has_meta("cogible") and not gr0.pequeno)
	Terreno3D.liberar_celda(gr0.celda)
	gr0.queue_free()
	var tex: Dictionary = Puzle3D.parsear("; pieza bp barril 3 4 tam=pequeno\n; pieza bg barril 5 4\n; pieza bm barril 6 4 tam=enorme")
	var piezas: Array = tex["piezas"]
	_ok("9 el mapa entiende «; pieza bp barril 3 4 tam=pequeno» (y el grande sin clave; una talla que no existe da aviso)", piezas.size() == 2 and (piezas[0] as Puzle3D.Pieza).p.get("tam", "") == "pequeno"
		and not (piezas[1] as Puzle3D.Pieza).p.has("tam") and (tex["avisos"] as Array).size() == 1, str(tex["avisos"]))
	_ok("9 la jugadora lo tiene de candidato y la pista dice Coger", c.candidato() == s1 and c.accion_pista() == "Coger")

	# ---------- 10 · En brazos y encendido: explota en las manos ----------
	var coge: bool = await _coger_peq(s1)
	_ok("10 se coge con E (clip de levantar), se lleva sobre la cabeza, libera su casilla y no se puede golpear", coge and s1.en_brazos and not Terreno3D.bloqueada(pc) and s1.collision_layer == 0
		and s1.global_position.y - j.position.y > 0.7 and Vector2(s1.global_position.x - j.position.x, s1.global_position.z - j.position.z).length() < 0.7,
		"estado %d · y sobre los pies %.2f" % [c.estado, s1.global_position.y - j.position.y])
	var vj0: float = j.vida
	var rec1: Dictionary = _vigilar(s1)
	var t_enc: float = reloj.t
	s1.encender()
	await avanzar(3)
	var av: AvisoAreaFuego = s1.aviso
	_ok("10 encendido en brazos: aviso de radio %.1f u, a ras del suelo bajo ella y sin girar con el barril" % Barril3D.RADIO_PEQUENO, av != null and absf(av.radio - Barril3D.RADIO_PEQUENO) < 0.001 and absf(av.radio_dibujado() - Barril3D.RADIO_PEQUENO) < 0.001
		and absf(av.global_position.y - Terreno3D.y_pies(Terreno3D.celda_de(j.position))) < 0.05 and Vector2(av.global_position.x - j.position.x, av.global_position.z - j.position.z).length() < 0.8 and av.global_rotation == Vector3.ZERO)
	await avanzar_s(0.9)
	_ok("10 la mecha sigue corriendo en brazos (queda %.2f)" % s1.mecha_restante(), s1.encendido and s1.mecha_restante() < 0.75 and c.estado == CargarObjeto3D.Estado.CARGANDO)
	await _espera_rec(rec1)
	var t_arde: float = float(rec1["t"]) - t_enc
	await avanzar(3)
	var perdida: float = vj0 - j.vida
	var vfx: Array = get_nodes_in_group(ExplosionFuegoToy.GRUPO)
	_ok("10 explota en las manos al acabar la mecha (%.2f s de %.1f)" % [t_arde, Barril3D.T_MECHA_PEQUENO], int(rec1["n"]) == 1 and absf(t_arde - Barril3D.T_MECHA_PEQUENO) < 0.25)
	_ok("10 la jugadora que lo llevaba pierde vida (%.0f de %.0f máx.)" % [perdida, Barril3D.DANO_JUGADORA_PEQUENO], bool(rec1["alcanzada"]) and perdida > 5.0 and perdida <= Barril3D.DANO_JUGADORA_PEQUENO + 0.01)
	_ok("10 la explosión nace a ras de suelo bajo ella, con radio %.1f, y es UNA sola de ExplosionFuegoToy de ese tamaño" % Barril3D.RADIO_PEQUENO, absf(float(rec1["radio"]) - Barril3D.RADIO_PEQUENO) < 0.001 and vfx.size() == 1
		and absf((vfx[0] as ExplosionFuegoToy).radio - Barril3D.RADIO_PEQUENO) < 0.001 and absf((rec1["punto"] as Vector3).y - Terreno3D.y_pies(Terreno3D.celda_de(j.position))) < 0.05
		and Vector2((rec1["punto"] as Vector3).x - j.position.x, (rec1["punto"] as Vector3).z - j.position.z).length() < 1.0)
	_ok("10 el barril desaparece y la jugadora queda con las manos libres (estado LIBRE, sin casilla bloqueada)", not is_instance_valid(s1) and c.estado == CargarObjeto3D.Estado.LIBRE and not c.ocupa_manos() and not Terreno3D.bloqueada(pc))
	await avanzar_s(1.8)

	# ---------- 11 · Lanzado sin encender: no explota ----------
	await _preparar_j(oeste)
	var s2: Barril3D = _peq(pc)
	await avanzar(3)
	await _coger_peq(s2)
	var rec2: Dictionary = _vigilar(s2)
	var org2: Vector3 = j.position
	j.mirar_hacia(Vector3.RIGHT)
	c.lanzar()
	await avanzar_s(1.4)
	var celda2: Vector2i = Terreno3D.celda_de(s2.global_position)
	_ok("11 lanzado SIN encender no explota: queda en el suelo a %.1f u (alcance de la tabla %.1f u), entero y con su casilla" % [Vector2(s2.global_position.x - org2.x, s2.global_position.z - org2.z).length(), float(fila["alcance"]) * Terreno3D.casilla],
		int(rec2["n"]) == 0 and not s2.explotado and not s2.en_brazos and s2.collision_layer != 0 and Terreno3D.bloqueada(s2.celda) and s2.celda == celda2 and String(c.ultimo.get("accion", "")) == "impacto"
		and absf(Vector2(s2.global_position.x - org2.x, s2.global_position.z - org2.z).length() - float(fila["alcance"]) * Terreno3D.casilla) < 1.7)
	await avanzar_s(Barril3D.T_MECHA_PEQUENO + 0.5)
	_ok("11 y sigue sin explotar pasado el tiempo de la mecha", int(rec2["n"]) == 0 and not s2.explotado and int(_vivos_vfx()["explosion"]) == 0)
	Terreno3D.liberar_celda(s2.celda)
	s2.queue_free()
	await avanzar(2)

	# ---------- 12 · Lanzado y encendido: explota al caer, con daño menor y radio menor ----------
	await _preparar_j(oeste)
	var meta: Vector3 = _pos(oeste) + Vector3(float(fila["alcance"]) * Terreno3D.casilla, 0.0, 0.0)
	var g_in: Combate3D = _goblin(meta + Vector3(0.5, 0.0, 0.7))
	var g_out: Combate3D = _goblin(meta + Vector3(0.0, 0.0, -2.1))      # a ≈ 2,1 u: fuera del radio pequeño (1,6) pero dentro del grande (2,6)
	await avanzar_s(0.3)
	var h_in: float = g_in.health
	var h_out: float = g_out.health
	var s3: Barril3D = _peq(pc)
	await avanzar(3)
	await _coger_peq(s3)
	var rec3: Dictionary = _vigilar(s3)
	var enc3: float = reloj.t
	s3.encender()
	j.mirar_hacia(Vector3.RIGHT)
	var t_lanza: float = reloj.t
	c.lanzar()
	await _espera_rec(rec3)
	await avanzar(3)
	var d_in: float = h_in - g_in.health
	_ok("12 lanzado ENCENDIDO explota al impactar (%.2f s tras lanzarlo; la mecha duraba %.1f)" % [float(rec3["t"]) - t_lanza, Barril3D.T_MECHA_PEQUENO], int(rec3["n"]) == 1 and float(rec3["t"]) - enc3 < Barril3D.T_MECHA_PEQUENO - 0.5 and not bool(rec3["en_brazos"]))
	_ok("12 el enemigo cerca del impacto pierde vida (%.0f: la explosión de %.0f más el golpe de la tabla) y es menos que con el barril grande (%.0f)" % [d_in, Barril3D.DANO_ENEMIGO_PEQUENO, Barril3D.DANO_ENEMIGO], d_in >= 12.0 and d_in <= 30.0 and (rec3["golpeados"] as Array).has(g_in))
	_ok("12 el enemigo a 2,1 u NO la nota (radio %.1f) y la jugadora, a %.1f u, tampoco" % [Barril3D.RADIO_PEQUENO, Vector2(float((rec3["punto"] as Vector3).x) - j.position.x, float((rec3["punto"] as Vector3).z) - j.position.z).length()], g_out.health == h_out and not (rec3["golpeados"] as Array).has(g_out) and not bool(rec3["alcanzada"]) and j.vida >= Estado.i().vida_max - 0.01)
	await avanzar_s(1.7)

	# ---------- 13 · Se le acaba la mecha en el aire: explota donde esté ----------
	await _preparar_j(oeste)
	var s4: Barril3D = _peq(pc)
	await avanzar(3)
	await _coger_peq(s4)
	var rec4: Dictionary = _vigilar(s4)
	s4.encender()
	j.mirar_hacia(Vector3.RIGHT)
	c.lanzar()
	s4._t = 0.5                                       # queda medio segundo: se acaba a mitad del vuelo (el vuelo entero dura ≈ 0,6 s tras los 0,18 s de soltarlo)
	await _espera_rec(rec4)
	await avanzar(3)
	var dx4: float = float((rec4["punto"] as Vector3).x) - _pos(oeste).x
	_ok("13 con la mecha casi acabada explota EN EL AIRE (a %.1f u de la jugadora; el suelo estaba a %.1f)" % [dx4, float(fila["alcance"]) * Terreno3D.casilla], int(rec4["n"]) == 1 and dx4 > 1.0 and dx4 < float(fila["alcance"]) * Terreno3D.casilla - 1.5)
	await avanzar_s(1.7)

	# ---------- 14 · Choca con una pared: explota contra ella ----------
	await _preparar_j(oeste)
	var pared: Vector2i = oeste + Vector2i(2, 0)
	Terreno3D.bloquear_celda(pared)
	var s5: Barril3D = _peq(pc)
	await avanzar(3)
	await _coger_peq(s5)
	var rec5: Dictionary = _vigilar(s5)
	s5.encender()
	j.mirar_hacia(Vector3.RIGHT)
	c.lanzar()
	await _espera_rec(rec5)
	await avanzar(3)
	var dx5: float = float((rec5["punto"] as Vector3).x) - _pos(oeste).x
	_ok("14 lanzado encendido contra una pared (casilla a 2 de distancia) explota delante de ella, a %.1f u, y no al final del alcance (%.1f u)" % [dx5, float(fila["alcance"]) * Terreno3D.casilla],
		int(rec5["n"]) == 1 and dx5 > 1.5 and dx5 < Terreno3D.casilla * 2.0 + 0.1)
	Terreno3D.liberar_celda(pared)
	await avanzar_s(1.7)

	# ---------- 15 · Suelto y encendido en el suelo: radio y daño menores que el grande; la cadena con barriles grandes ----------
	colocar_jugador(lejos_j)
	await avanzar_s(1.0)
	var s6: Barril3D = _peq(_claro)
	var f_in: Combate3D = _goblin(_pos(_claro) + Vector3(1.3, 0.0, 0.0))
	var f_mid: Combate3D = _goblin(_pos(_claro) + Vector3(0.0, 0.0, 2.1))
	await avanzar_s(0.4)
	var hi: float = f_in.health
	var hm: float = f_mid.health
	var rec6: Dictionary = _vigilar(s6)
	s6.encender()
	await _espera_rec(rec6)
	await avanzar(3)
	_ok("15 en el suelo: el enemigo a 1,3 u pierde %.0f (menos que los 33 del grande) y el de 2,1 u (dentro del radio grande) no" % (hi - f_in.health), hi - f_in.health >= 12.0 and hi - f_in.health <= 24.0 and f_mid.health == hm)
	await avanzar_s(1.7)
	for g in _goblins:
		if is_instance_valid(g):
			g.position = Vector3(-500.0, 0.0, -500.0)
	_goblins.clear()
	var grande: Barril3D = _barril(_claro)
	var s7: Barril3D = _peq(_claro + Vector2i(1, 0))               # a 2,3 u del grande
	var rec7: Dictionary = _vigilar(s7)
	await avanzar(3)
	grande.encender()
	await _espera_explosion(grande)
	var t_g: float = reloj.t
	await avanzar(2)
	_ok("15 la CADENA: el barril grande enciende al pequeño vecino (2,3 u), con su aviso de radio %.1f" % Barril3D.RADIO_PEQUENO, s7.encendido and s7.aviso != null and absf(s7.aviso.radio - Barril3D.RADIO_PEQUENO) < 0.001)
	await _espera_rec(rec7)
	_ok("15 y el pequeño explota a su vez ≈ %.1f s después" % Barril3D.T_MECHA_PEQUENO, int(rec7["n"]) == 1 and absf(float(rec7["t"]) - t_g - Barril3D.T_MECHA_PEQUENO) < 0.4 and absf(float(rec7["radio"]) - Barril3D.RADIO_PEQUENO) < 0.001)
	await avanzar_s(1.8)
	var f2: Dictionary = _vivos_vfx()
	_ok("15 al final no queda nada vivo del VFX ni casillas bloqueadas de barriles", int(f2["explosion"]) == 0 and int(f2["aviso"]) == 0 and not Terreno3D.bloqueada(_claro) and not Terreno3D.bloqueada(_claro + Vector2i(1, 0)), str(f2))
	colocar_jugador(lejos_j)
	await avanzar_s(0.5)


## El MODELO de Meshy: se carga, mide lo que debe (Ø ≤ 1,0 × 0,95 el grande; ×0,58 el pequeño), mira a +Z (la cámara del juego mira al norte) y la caja de colisión es la de siempre.
func _modelo(b: Barril3D) -> void:
	var tipo: String = "pequeño" if b.pequeno else "grande"
	var mi: MeshInstance3D = b._cuerpo as MeshInstance3D
	_ok("8 el barril %s se dibuja con el modelo de Meshy (puzle_terrain «barril»)" % tipo, b._modelo_ok and mi != null and mi.mesh == PiezaPuzle3D.malla_modelo("barril"))
	if mi == null or mi.mesh == null:
		return
	var aabb: AABB = mi.mesh.get_aabb()
	var k: float = b.escala_modelo()
	_ok("8 %s: el modelo mide %.2f de alto (esperado %.2f) y Ø %.2f × %.2f" % [tipo, aabb.size.y * mi.scale.y, b.alto, aabb.size.x * mi.scale.x, aabb.size.z * mi.scale.z],
		absf(aabb.size.y * mi.scale.y - b.alto) < 0.02 and aabb.size.x * mi.scale.x <= 1.0 * k + 0.001 and aabb.size.z * mi.scale.z <= 1.0 * k + 0.001 and absf(aabb.position.y) < 0.01)
	_ok("8 %s: el modelo está centrado en la base y sin girar (la calavera mira a +Z, a la cámara)" % tipo,
		absf(aabb.position.x + aabb.size.x * 0.5) < 0.05 and absf(aabb.position.z + aabb.size.z * 0.5) < 0.05 and mi.rotation == Vector3.ZERO and b.rotation == Vector3.ZERO)
	var forma: CollisionShape3D = null
	for h in b.get_children():
		if h is CollisionShape3D:
			forma = h
	_ok("8 %s: la colisión es una caja de %.2f × %.2f × %.2f" % [tipo, k, b.alto, k], forma != null and forma.shape is BoxShape3D and (forma.shape as BoxShape3D).size.is_equal_approx(Vector3(k, b.alto, k)))
	_ok("8 %s: la mecha se ve (cordón sobre la tapa) y apagada no hay chispas ni brasa en la punta" % tipo, b._mecha != null and b._mecha.visible and b._mecha.position.y > b.alto - 0.05 and b._chispas == null and not b._punta.visible)


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
	_modelo(b)
	b.encender()
	await avanzar(2)
	_ok("1 al encender aparece UN aviso", b.aviso != null and int(_vivos_vfx()["aviso"]) == 1)
	_ok("1 el aviso es de radio = Barril3D.RADIO (%.2f u)" % Barril3D.RADIO, b.aviso != null and absf(b.aviso.radio - Barril3D.RADIO) < 0.001 and absf(b.aviso.radio_dibujado() - Barril3D.RADIO) < 0.001,
		"radio %.3f · dibujado %.3f" % [b.aviso.radio if b.aviso != null else -1.0, b.aviso.radio_dibujado() if b.aviso != null else -1.0])
	_ok("1 el aviso cuelga a ras del suelo del barril", b.aviso != null and absf(b.aviso.global_position.y - b.global_position.y) < 0.01 and Vector2(b.aviso.global_position.x - centro.x, b.aviso.global_position.z - centro.z).length() < 0.01)
	_ok("1 encendido: chispas y brasa en la punta de la mecha, el cordón se acorta y la madera se tiñe de rojo sin saturarse (albedo mín %.2f, sin emisión)" % minf(b._mat.albedo_color.g, b._mat.albedo_color.b),
		b._chispas != null and b._punta.visible and b._mecha.visible and (b._mecha.mesh as CylinderMesh).height < Barril3D.CORDON_LARGO + 0.001 and not b._mat.emission_enabled
		and b._mat.albedo_color.r > 0.99 and minf(b._mat.albedo_color.g, b._mat.albedo_color.b) >= 0.6 and b._mat.albedo_color.g < 0.995)
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
	_ok("1 apagada con agua: no arde, no hay aviso ni chispas, la madera vuelve a su color y no explota", not b.encendido and b.aviso == null and int(_vivos_vfx()["aviso"]) == 0 and not b.explotado
		and b._chispas == null and not b._punta.visible and b._mat.albedo_color == Color.WHITE)
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
	_ok("2 el barril ya no se ve (modelo, mecha y brasa) y no se puede golpear", not b._cuerpo.visible and (b._aro == null or not b._aro.visible) and not b._mecha.visible and b.collision_layer == 0)
	var ex: ExplosionFuegoToy = b.explosion_vfx
	_ok("2 la explosión trae su fuego de FuegoToy: %d lenguas y %d brasas, y no son amarillas (escala de rampa %.2f)" % [ex._lenguas.size(), ex._brasas.size(), ExplosionFuegoToy.ESCALA_RAMPA_LENGUA],
		ex._lenguas.size() == ExplosionFuegoToy.LENGUAS.size() and ex._brasas.size() == ExplosionFuegoToy.BRASAS.size() and ExplosionFuegoToy.ESCALA_RAMPA_LENGUA < 0.8
		and float(((ex._lenguas[0]["nodo"] as FuegoToy)._mats[0] as ShaderMaterial).get_shader_parameter("escala_rampa")) < 0.8)
	_ok("2 las lenguas suben y se deshacen (envolvente: 0 al nacer, 1 en pleno, 0 al irse) y las brasas duran ≈ 1 s en el suelo",
		ExplosionFuegoToy.envolvente(0.0, 0.04, 0.46, 0.88) == 0.0 and ExplosionFuegoToy.envolvente(0.3, 0.04, 0.46, 0.88) > 0.99 and ExplosionFuegoToy.envolvente(0.9, 0.04, 0.46, 0.88) == 0.0
		and ExplosionFuegoToy.envolvente(0.5, 0.22, 0.9, 1.35) > 0.99 and ExplosionFuegoToy.envolvente(1.0, 0.22, 0.9, 1.35) > 0.2 and ExplosionFuegoToy.envolvente(1.4, 0.22, 0.9, 1.35) == 0.0
		and float(ExplosionFuegoToy.BRASAS[0][4]) - float(ExplosionFuegoToy.BRASAS[0][2]) > 0.9 and ExplosionFuegoToy.T_TOTAL >= float(ExplosionFuegoToy.BRASAS[0][4]))
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

	await _pequeno(lejos_j)

	# ---------- 6 · Colores ----------
	FuegoToy._rampas()
	var g_alto: Color = FuegoToy._rampa_bola.gradient.sample(0.85)
	var g_med: Color = FuegoToy._rampa_bola.gradient.sample(0.5)
	_ok("6 el tono más alto que usa el decal (rampa de la bola en 0,85) es naranja, no amarillo: g/r %.2f, b %.2f" % [g_alto.g / g_alto.r, g_alto.b], g_alto.g / g_alto.r < 0.72 and g_alto.b < 0.25)
	_ok("6 la masa del decal (rampa en 0,5) es rojo-naranja: g/r %.2f" % (g_med.g / g_med.r), g_med.g / g_med.r < 0.5)
	var f: Dictionary = _vivos_vfx()
	_ok("7 al final no queda nada vivo del VFX", int(f["explosion"]) == 0 and int(f["impacto"]) == 0 and int(f["aviso"]) == 0, str(f))
