extends "res://herramientas/escenario_base.gd"
## B1 de docs/PLAN_COMBATE_2026-11-22.md (C1, escudos de elemento; 22/11): las CORAZAS DE ELEMENTO (`enemigos/coraza_elemento_3d.gd`) en la ArenaCombate, con hechizos de verdad.
##   · goblin con CORAZA DE BARRO (pieza `goblin_coraza`): el fuego la endurece (contraproducente), la tierra la agrieta, el agua la ablanda y entonces la tierra la rompe; mientras
##     está entera nada le quita vida; rota, el fuego sí. Su rombo va del color de la tierra mientras la lleva.
##   · limo de FUEGO con COSTRA DE BRASA (`limo … coraza=brasa`): la tierra rebota, el fuego la aviva, el agua la rompe; rota, el agua le hace daño.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_coraza_elemento.gd

const RUTA_ARENA: String = "res://escenas/PruebaArenaCombate.tscn"
var _z: Puzle3D = null


func _disparar(desde: Vector2i, elemento: String, objetivo: Node3D, espera: float = 1.4) -> void:
	colocar_jugador(desde)
	(jugador as Jugador3D).vida = 100000.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	var d: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	var dir: Vector3 = objetivo.global_position - jugador.position
	dir.y = 0.0
	# Como `escenario_base.lanzar`: sin gravedad (la flecha de tierra caería antes de llegar). Se prueba la coraza, no la balística.
	var previos: Dictionary = lanzador.cambios_hechizo.duplicate()
	lanzador.cambios_hechizo["gravedad"] = 0.0
	var ok: bool = not d.is_empty() and lanzador.lanzar_ahora(d, jugador.position, dir.normalized())
	lanzador.cambios_hechizo = previos
	if not ok:
		print("  NO SE LANZÓ ", elemento)
	await avanzar_s(espera)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_ARENA, true)
	if maqueta == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(10)
	var g: Combate3D = _z.nodo("coraza_arena") as Combate3D if _z != null else null
	_ok("0 la arena monta el goblin con coraza de barro", g != null and g.coraza != null and g.coraza.material == "barro")
	if g != null and g.coraza != null:
		g.quieto = true
		g.health = 1000.0
		g.vida_max = 1000.0
		var k: CorazaElemento3D = g.coraza
		var desde := Vector2i(9, 11)
		_ok("B1 barro: el rombo va del color de la tierra mientras la lleva", g._marca_debil != null and g._marca_debil.modulate.is_equal_approx(Combate3D.COLORES["tierra"]))
		var v0: float = g.health
		await _disparar(desde, "fuego", g)
		_ok("B1 barro: el fuego la ENDURECE (contraproducente) y no le quita vida", k.golpes == 3 and k.endurecidas == 1 and is_equal_approx(g.health, v0), "golpes %d · vida %.0f" % [k.golpes, g.health])
		await _disparar(desde, "tierra", g)
		_ok("B1 barro: la tierra la agrieta (le quita un golpe) sin herirle", k.golpes == 2 and k.estado == "entera" and is_equal_approx(g.health, v0), "golpes %d" % k.golpes)
		await _disparar(desde, "agua", g)
		_ok("B1 barro: el agua la ablanda", k.ablandada_t > 0.0 and k.estado == "entera" and is_equal_approx(g.health, v0))
		await _disparar(desde, "tierra", g)
		_ok("B1 barro: ablandada, un golpe de tierra la rompe", k.estado == "rota", "estado %s · golpes %d" % [k.estado, k.golpes])
		_ok("B1 barro: rota, el rombo vuelve a su debilidad", g._marca_debil.modulate.is_equal_approx(Combate3D.COLORES.get(g.debil, Color.WHITE)))
		await _disparar(desde, "tierra", g)       # (no fuego: sigue mojado del agua de antes y fuego sobre mojado es vapor, la regla de siempre)
		_ok("B1 barro: sin coraza, la tierra ya le quita vida", g.health < v0, "vida %.0f → %.0f" % [v0, g.health])
	var li: Combate3D = _z.nodo("limo_brasa_arena") as Combate3D if _z != null else null
	_ok("0 la arena monta el limo de fuego con costra de brasa", li != null and li.coraza != null and li.coraza.material == "brasa")
	if li != null and li.coraza != null:
		li.quieto = true
		li.health = 1000.0
		li.vida_max = 1000.0
		var kb: CorazaElemento3D = li.coraza
		var desde_b := Vector2i(14, 10)
		var vb: float = li.health
		await _disparar(desde_b, "tierra", li)
		_ok("B1 brasa: la tierra rebota", kb.rebotes >= 1 and kb.estado == "entera" and is_equal_approx(li.health, vb), "rebotes %d" % kb.rebotes)
		await _disparar(desde_b, "fuego", li)
		_ok("B1 brasa: el fuego la AVIVA (contraproducente)", kb.golpes == 2 and kb.endurecidas == 1, "golpes %d" % kb.golpes)
		await _disparar(desde_b, "agua", li)
		await _disparar(desde_b, "agua", li)
		_ok("B1 brasa: el agua la rompe (avivada, en dos)", kb.estado == "rota" and is_equal_approx(li.health, vb), "estado %s · vida %.0f" % [kb.estado, li.health])
		await _disparar(desde_b, "agua", li)
		_ok("B1 brasa: rota, el agua ya le hace daño al limo", li.health < vb, "vida %.0f → %.0f" % [vb, li.health])
