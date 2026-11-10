extends "res://herramientas/escenario_base.gd"
## godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_plataforma_tierra.gd

func _escenario() -> void:
	await cargar()
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 0
	Repertoire.aim_with_mouse = true
	var ancla := Vector2i(-1, -1)
	var paso := Vector2i.ZERO
	var lado: int = Terreno3D.lado_del_mapa()
	for z in range(lado):
		for x in range(lado):
			var c := Vector2i(x, z)
			if lanzador.puede_construir_en(c) != "" or Terreno3D.altura_en(c) != 0:
				continue
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				if not Terreno3D.es_agua(c + d) or not Terreno3D.es_agua(c + d * 2):
					continue
				var suelo_continuo := true
				for i in range(1, 4):
					var tramo: Vector2i = c - d * i
					if lanzador._rechazo_anclaje_tierra(tramo) != "" or not is_equal_approx(Terreno3D.y_pies(tramo), Terreno3D.y_pies(c)):
						suelo_continuo = false
						break
				if suelo_continuo:
					ancla = c
					paso = d
					break
			if paso != Vector2i.ZERO:
				break
		if paso != Vector2i.ZERO:
			break
	_ok("cuatro casillas de tierra seguidas de dos de agua", paso != Vector2i.ZERO)
	if paso == Vector2i.ZERO:
		return
	var agua: Vector2i = ancla + paso
	var origen: Vector3 = Terreno3D.centro_de(ancla, Terreno3D.y_pies(ancla))
	var dir := Vector3(paso.x, 0, paso.y)
	colocar_jugador(ancla - paso)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("tierra")
	_ok("el sello solo prepara una página lanzable", lanzador.page_ready(0) and lanzador._preparar_pagina(0))
	var datos: Dictionary = lanzador._preparado.duplicate()
	if datos.is_empty():
		return
	var tinta_antes: float = jugador.tinta.actual
	_ok("el bloque rechaza agua antes del cobro", not lanzador.lanzar_ahora(datos, Terreno3D.centro_de(agua), dir) and is_equal_approx(jugador.tinta.actual, tinta_antes))
	_ok("Tierra sola crea un escalón pisable", lanzador.lanzar_ahora(datos, origen, dir) and is_equal_approx(Terreno3D.y_pies(ancla) - origen.y, Lanzador3D.ALTO_PLATAFORMA_TIERRA))
	_ok("se puede subir andando desde la orilla", jugador._puede_estar(origen))
	lanzador._avanzar_caducidades(30.0)
	lanzador.cooldown_left[0] = 0.0
	# Esta escena de partida lleva huecos cerrados. Se usan tres sectores del libro con los glifos ya activos.
	lanzador.add_sigil(Vector2.RIGHT, "linea_x")
	lanzador.add_sigil(Vector2.DOWN, "barrera")
	lanzador.add_sigil(Vector2.LEFT, "permanencia")
	_ok("se prepara el puente con permanencia", lanzador._preparar_pagina(0))
	datos = lanzador._preparado.duplicate()
	if datos.is_empty():
		return
	var h: Hechizo = datos["hechizo"]
	var larga: Hechizo = Hechizo.construir(datos["rune"], {"linea_x": 3, "barrera": 1})
	_ok("varias líneas se detienen antes del agua", lanzador.celdas_plataforma_tierra(larga, origen, dir) == [ancla])
	_ok("la receta reconoce el puente y suma permanencia", h.es_plataforma_tierra() and h.permanencia > 0.0, str(h.glifos))
	_ok("lanza el puente desde la orilla", lanzador.lanzar_ahora(datos, origen, dir))
	_ok("el lanzamiento conserva el agua libre", Terreno3D.plataformas_tierra.has(ancla) and not Terreno3D.plataformas_tierra.has(agua) and Terreno3D.es_agua(agua))
	lanzador._avanzar_caducidades(h.persiste + h.permanencia - 0.1)
	_ok("la permanencia mantiene la plataforma hasta su vencimiento", Terreno3D.plataformas_tierra.has(ancla))
	lanzador._avanzar_caducidades(0.2)
	var suelo_interior: Vector2i = ancla - paso
	colocar_jugador(suelo_interior + Vector2i(-paso.y, paso.x))
	var inicio: Vector3 = Terreno3D.centro_de(suelo_interior, Terreno3D.y_pies(suelo_interior))
	_ok("la plataforma enlaza dos casillas secas contiguas", lanzador.celdas_plataforma_tierra(h, inicio, dir) == [suelo_interior, ancla])
	lanzador.cooldown_left[0] = 0.0
	_ok("se construye el paso continuo en seco", lanzador.lanzar_ahora(datos, inicio, dir) and Terreno3D.plataformas_tierra.has(suelo_interior) and Terreno3D.plataformas_tierra.has(ancla))
	colocar_jugador(suelo_interior)
	_ok("el paso entre ambos tramos se hace andando", jugador._puede_estar(Terreno3D.centro_de(ancla)))
	var vacio := Vector2i(-1, ancla.y)
	jugador.position = Terreno3D.centro_de(vacio, origen.y)
	jugador.caer_de_plataforma(vacio, ancla)
	for i in range(60):
		jugador._vertical(1.0 / 30.0, false)
	var regreso: Vector2i = Terreno3D.celda_de(jugador.position)
	_ok("la caída al vacío también devuelve a terreno seguro", jugador.en_suelo and Terreno3D.pisable(regreso, 0, true, 1, false))
	lanzador._avanzar_caducidades(h.persiste + h.permanencia + 1.0)
	var primera: Vector2i = ancla - paso * 3
	colocar_jugador(primera + Vector2i(-paso.y, paso.x))
	var comienzo: Vector3 = Terreno3D.centro_de(primera, Terreno3D.y_pies(primera))
	for glifo in ["linea_z", "linea_x"]:
		var largo: int = 3 if glifo == "linea_z" else 4
		var sector: Vector2 = Vector2.UP if largo == 3 else Vector2(1, -1).normalized()
		lanzador.add_sigil(sector, glifo)
		lanzador.cooldown_left[0] = 0.0
		jugador.tinta.actual = jugador.tinta.maxima
		var preparada: bool = lanzador._preparar_pagina(0)
		_ok("el libro prepara el puente de %d casillas con líneas de ambos ejes" % largo, preparada)
		if not preparada:
			return
		datos = lanzador._preparado.duplicate()
		h = datos["hechizo"]
		var esperadas: Array[Vector2i] = []
		for i in range(largo):
			esperadas.append(primera + paso * i)
		_ok("la previsión ocupa %d casillas contiguas" % largo, lanzador.celdas_plataforma_tierra(h, comienzo, dir) == esperadas)
		_ok("el lanzamiento levanta el mismo tramo de %d casillas" % largo,
			lanzador.lanzar_ahora(datos, comienzo, dir) and Terreno3D.plataformas_tierra.size() == largo
			and esperadas.all(func(c: Vector2i) -> bool: return Terreno3D.plataformas_tierra.has(c)))
		lanzador._avanzar_caducidades(h.persiste + h.permanencia + 1.0)
