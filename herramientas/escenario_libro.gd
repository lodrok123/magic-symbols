extends "res://herramientas/escenario_base.gd"
## Escenario 13.10 · libro: se compone un hechizo (elemento + glifo) y se lanza; sale un hechizo. Lo escribe el Juego (15/10).
##
## Lo que hace el jugador con el libro, por código y con la escena entera: elige la página 1, pone el elemento y el glifo (lo que hace
## la paleta F1 o el dibujo reconocido), lanza, y el juego lo anota. Mira también los dos casos que NO deben lanzar: una página vacía
## y una página que aún está recargando. Dibujar el trazo con el ratón (Grimorio.add_gesture) queda fuera: es reconocimiento de formas
## y tiene su propia prueba (prueba_grimorio).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_libro.gd

const DESDE := Vector2i(6, 24)


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)

	# --- Una página vacía no lanza nada ---
	lanzador.select_page(1)
	var antes: int = eventos("cast").size()
	lanzador.cast_page(1)
	_ok("1 una página vacía no entra en el modo de lanzar", not lanzador.modo_lanzar)
	_ok("1 y no se anota ningún lanzamiento", eventos("cast").size() == antes)
	lanzador.select_page(0)

	# --- Componer: elemento + glifo ---
	lanzador.clear_sequence()
	_ok("2 la página 1 empieza vacía", not lanzador.page_ready(0))
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	_ok("2 con elemento y glifo la página está lista", lanzador.page_ready(0))
	_ok("2 el glifo quedó en un sector", lanzador.components().size() == 1 and (lanzador.components()[0]["sigils"] as Array) == ["flecha"], str(lanzador.components()))
	_ok("2 el elemento es fuego", lanzador.page_element_data(0) != null and Objetos.elemento_de(lanzador.page_element_data(0)) == "fuego")

	# --- Lanzar ---
	# R3 (17/10): la forma ya no es «proyectil» sino el nombre DERIVADO de las medidas (flecha = viaja ⇒ «x_mano»).
	var lanzados: Array = []
	lanzador.lanzado.connect(func(elem: String, forma: String, n: int) -> void: lanzados.append([elem, forma, n]))
	var salio: bool = lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT)
	_ok("3 sale un hechizo", salio)
	_ok("3 el Lanzador avisa (señal `lanzado`): fuego, x_mano, al menos una manifestación", lanzados.size() == 1 and lanzados[0][0] == "fuego" and lanzados[0][1] == "x_mano" and int(lanzados[0][2]) >= 1, str(lanzados))
	_ok("3 y no se queda en el modo de apuntar (el tiempo vuelve a la normalidad)", not lanzador.modo_lanzar and is_equal_approx(Engine.time_scale, 1.0), "time_scale %.2f" % Engine.time_scale)
	var casts: Array = eventos("cast")
	_ok("3 el diario anota el lanzamiento con elemento, forma y glifos", casts.size() == antes + 1 and String(casts.back().get("elemento", "")) == "fuego"
		and String(casts.back().get("forma", "")) == "x_mano" and casts.back().get("glifos", []) == ["flecha"], str(casts.back()) if not casts.is_empty() else "sin eventos")

	# R3: el diario anota la receta en números (`receta_v2`): dimensiones, propiedades, estado y coste.
	var rv: Array = eventos("receta_v2")
	var rv_ok: bool = not rv.is_empty()
	if rv_ok:
		var e: Dictionary = rv.back()
		var props: Dictionary = e.get("propiedades", {})
		rv_ok = String(e.get("estado", "")) == "plasma" and String(e.get("nombre", "")) == "x_mano" and is_equal_approx(float(props.get("viaja", 0.0)), 2.0) \
			and float(e.get("x", 0.0)) > 0.0 and float(e.get("coste_relativo", 0.0)) >= 1.0 and float(e.get("coste_tinta", 0.0)) >= Dano.tinta(0)
	_ok("3 el diario anota `receta_v2` con dimensiones, propiedades (viaja 2: una flecha), estado (plasma) y coste", rv_ok, str(rv.back()) if not rv.is_empty() else "sin eventos")

	# --- Recarga ---
	_ok("4 la página queda recargando", lanzador.cooldown_left[0] > 0.0, "%.2f s" % lanzador.cooldown_left[0])
	var antes_bloq: int = eventos("cast_bloqueado").size()
	lanzador.cast_page(0)
	_ok("4 mientras recarga, lanzar otra vez no hace nada", not lanzador.modo_lanzar)
	_ok("4 y el diario anota «cast_bloqueado»", eventos("cast_bloqueado").size() == antes_bloq + 1)
	await avanzar_s(lanzador.cooldown_total[0] + 0.5)
	_ok("4 pasada la recarga se puede volver a lanzar", lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT))

	# --- Tinta (15/10): cada hechizo cuesta según su forma; sin tinta no se lanza y no se gasta nada ---
	await avanzar_s(lanzador.cooldown_total[0] + 0.5)
	var tinta: Tinta = jugador.tinta
	_ok("5 el Lanzador y el jugador comparten la misma tinta", lanzador.tinta == tinta)
	tinta.actual = 5.0
	var frascos0: int = tinta.frascos
	tinta.frascos = 0                      # 24/10: la partida empieza con 3 frascos de reserva, que pagan la flecha; sin ellos, 5 de tinta no alcanza
	var sin: int = eventos("cast_sin_tinta").size()
	lanzador.cast_page(0)
	_ok("5 con 5 de tinta una flecha (10) no entra en el modo de apuntar", not lanzador.modo_lanzar)
	_ok("5 no se gasta nada", is_equal_approx(tinta.actual, 5.0), "%.2f" % tinta.actual)
	_ok("5 y el diario anota «cast_sin_tinta»", eventos("cast_sin_tinta").size() == sin + 1)
	tinta.frascos = frascos0
	tinta.actual = 100.0
	_ok("6 con la tinta llena la flecha sale", lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT))
	# 29/10 (DANO_Y_TINTA): la tinta sale de la potencia: una flecha sola es 1 glifo = ligera = 8 (antes, por volumen: 10 × 1,25 = 12,5).
	_ok("6 y cuesta 8", tinta.actual > 91.0 and tinta.actual < 93.0, "%.2f" % tinta.actual)

	# --- El libro enseña los ejes (diario 156, 18/10): contadores de la página, ᛁ girada, cubo X·Y·Z y chuleta ---
	await avanzar_s(lanzador.cooldown_total[0] + 0.5)
	var libro: Control = lanzador.libro
	_ok("7 el Lanzador tiene el libro", libro != null)
	if libro != null:
		lanzador.clear_sequence()
		_ok("7 la página vacía no lleva ningún glifo", (libro.call("_contadores_pagina") as Dictionary).is_empty())
		Repertoire.activate_all()           # ᛁ (`linea`) no está en el repertorio inicial P0 y `add_sigil` rechaza lo inactivo
		Repertoire.max_sigils_per_page = 0  # sin tope de sellos por página (con el ratón además es UN glifo por sector: abajo, cuatro sectores)
		lanzador.place_element("fuego")
		lanzador.add_sigil(Vector2.RIGHT, "linea_x", 1.0)
		lanzador.add_sigil(Vector2.LEFT, "linea_x", 1.0)
		lanzador.add_sigil(Vector2.UP, "levitacion", 1.0)
		lanzador.add_sigil(Vector2.DOWN, "linea_z", 1.0)
		var cont: Dictionary = libro.call("_contadores_pagina")
		_ok("7 los contadores de la página: ᛁ ancho ×2, ᛁ fondo ×1 y la levitación como altura ×1", cont == {"linea_x": 2, "linea_z": 1, "altura": 1}, str(cont))
		var g: Dictionary = Sigils.aplicar_v2(cont)
		var dim: Vector3 = EjesRecetaUi.dimensiones(g)
		var rb: float = Sigils.RADIO_BASE_V2
		_ok("7 el cubo del núcleo sale de esos contadores (ᛁ ancho ×2, ᛁ fondo ×1, altura ×1: cada glifo suma el paso de su eje a RADIO_BASE_V2)", is_equal_approx(dim.x, 2.0 * Sigils.semieje_horizontal_v2(2)) and is_equal_approx(dim.y, 2.0 * (rb + Sigils.PASO_ALTURA_V2)) and is_equal_approx(dim.z, 2.0 * Sigils.semieje_horizontal_v2(1, Sigils.PASO_FONDO_V2)), str(dim))
		_ok("7 el libro conoce las dos lecturas de ᛁ (mismo PNG, se gira al pintar)", Sigils.GLYPHS.has("linea_x") and Sigils.GLYPHS.has("linea_z") and Sigils.GLYPHS["linea_x"] == Sigils.GLYPHS["linea"])
		_ok("7 ᛁ ancho se pinta a 90° y ᛁ fondo a 0° (exentas del giro hacia el centro)", EjesRecetaUi.exenta_del_giro("linea_x") and is_equal_approx(EjesRecetaUi.giro_linea("linea_x"), PI * 0.5) and is_equal_approx(EjesRecetaUi.giro_linea("linea_z"), 0.0))
		# Se abre y se repinta con la página cargada: si la chuleta, el sello o el cubo fallaran, saldría un error de script y el escenario no acaba en 0.
		libro.visible = true
		for _i in range(4):
			libro.queue_redraw()
			await process_frame
		libro.visible = false
		_ok("7 el libro se repinta con la página compuesta sin romper", true)
		# La raya recta de UN trazo entra en la página como `linea_x` (horizontal) o `linea_z` (vertical) en el Grimorio del juego 3D
		# (antes solo lo hacía spellcaster.gd, el 2D, y en 3D `linea` no llegaba nunca a la receta).
		lanzador.clear_sequence()
		var raya_h: Array[Vector2] = [Vector2(0, 0), Vector2(40, 0), Vector2(80, 0)]
		lanzador.stroke_points = raya_h
		lanzador.call("_add_sigil_gesture", [raya_h], Vector2.RIGHT)
		var raya_v: Array[Vector2] = [Vector2(0, 0), Vector2(0, 40), Vector2(0, 80)]
		lanzador.stroke_points = raya_v
		lanzador.call("_add_sigil_gesture", [raya_v], Vector2.UP)
		var nombres_raya: Array = []
		for comp in lanzador.components():
			nombres_raya.append_array(comp["sigils"] as Array)
		if lanzador.gesture_library.has_any(GestureLibrary.SIGILS):
			_ok("7 una raya horizontal y otra vertical entran como linea_x y linea_z", nombres_raya == ["linea_x", "linea_z"], str(nombres_raya))
		else:
			_aviso("raya recta", "la biblioteca de gestos de este equipo no tiene sellos grabados: la raya queda como componente sin sello (%s)" % str(nombres_raya))
		lanzador.clear_sequence()
