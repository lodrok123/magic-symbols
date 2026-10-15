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
	var lanzados: Array = []
	lanzador.lanzado.connect(func(elem: String, forma: String, n: int) -> void: lanzados.append([elem, forma, n]))
	var salio: bool = lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT)
	_ok("3 sale un hechizo", salio)
	_ok("3 el Lanzador avisa (señal `lanzado`): fuego, proyectil, al menos una manifestación", lanzados.size() == 1 and lanzados[0][0] == "fuego" and lanzados[0][1] == "proyectil" and int(lanzados[0][2]) >= 1, str(lanzados))
	_ok("3 y no se queda en el modo de apuntar (el tiempo vuelve a la normalidad)", not lanzador.modo_lanzar and is_equal_approx(Engine.time_scale, 1.0), "time_scale %.2f" % Engine.time_scale)
	var casts: Array = eventos("cast")
	_ok("3 el diario anota el lanzamiento con elemento, forma y glifos", casts.size() == antes + 1 and String(casts.back().get("elemento", "")) == "fuego"
		and String(casts.back().get("forma", "")) == "proyectil" and casts.back().get("glifos", []) == ["flecha"], str(casts.back()) if not casts.is_empty() else "sin eventos")

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
	var sin: int = eventos("cast_sin_tinta").size()
	lanzador.cast_page(0)
	_ok("5 con 5 de tinta una flecha (10) no entra en el modo de apuntar", not lanzador.modo_lanzar)
	_ok("5 no se gasta nada", is_equal_approx(tinta.actual, 5.0), "%.2f" % tinta.actual)
	_ok("5 y el diario anota «cast_sin_tinta»", eventos("cast_sin_tinta").size() == sin + 1)
	tinta.actual = 100.0
	_ok("6 con la tinta llena la flecha sale", lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT))
	_ok("6 y cuesta 10", tinta.actual > 89.9 and tinta.actual < 90.5, "%.2f" % tinta.actual)
