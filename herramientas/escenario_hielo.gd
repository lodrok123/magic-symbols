extends "res://herramientas/escenario_base.gd"
## Escenario 13.10 · hielo: hielo sobre el estanque con un goblin encima → queda preso; a los 20 s se suelta. Lo escribe el Juego (15/10).
##
## Con la escena entera: se coloca a un goblin REAL del Bosque (Combate3D) sobre el río de la fila 29 y se lanza hielo + flecha sobre
## esa casilla. Se espera: la casilla se hiela (Terreno3D.helada, ya no es agua, se pisa), el goblin queda con `preso_hielo` y
## `congelado` > 0, y a los DURACION_HIELO (20 s) el hielo se funde solo y lo suelta. El camino es el del jugador; solo se coloca el goblin.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_hielo.gd

const ESTANQUE := Vector2i(4, 29)                      ## el río del Bosque (fila 29, columnas 1–7)
const DESDE := Vector2i(4, 26)                         ## al norte del río, en hierba
const MARGEN: float = 3.0                              ## s de tolerancia al esperar los 20 s


func _escenario() -> void:
	await cargar()
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("1 el estanque (4,29) es agua y no está helado", Terreno3D.es_agua(ESTANQUE) and not Terreno3D.helada(ESTANQUE))
	var goblins: Array = get_nodes_in_group("combate3d")
	_ok("1 la escena tiene goblins (grupo combate3d)", not goblins.is_empty(), "%d" % goblins.size())
	if goblins.is_empty():
		return
	var g: Node3D = goblins[0] as Node3D
	# El goblin, dentro del agua del estanque. Un goblin SUELTO no entra en el agua (Combate3D._ajustar_al_suelo lo devuelve a su puesto en
	# cuanto pisa agua), así que la única forma de tener uno dentro cuando se hiela es ponerlo y quitarle la IA: se queda donde lo dejo.
	# Lo que se mide después (hielo, preso, suelta) es todo del juego, no de este montaje.
	g.set_physics_process(false)
	g.global_position = Terreno3D.centro_de(ESTANQUE, sim.superficie_en(Terreno3D.centro_de(ESTANQUE, 0.0)))
	await avanzar(2)
	_ok("2 el goblin está sobre la casilla del estanque", Terreno3D.celda_de(g.global_position) == ESTANQUE, str(Terreno3D.celda_de(g.global_position)))
	_ok("2 y todavía no está preso", not g.has_meta("preso_hielo"))

	colocar_jugador(DESDE)
	var salio: bool = lanzar_a_celda("hielo", ["flecha"], ESTANQUE, DESDE)
	_ok("3 el hechizo hielo + flecha sale", salio)
	var t0: float = reloj.t
	await avanzar_s(2.0)
	_ok("4 la casilla del estanque se hiela", Terreno3D.helada(ESTANQUE) and sim.casilla_helada(ESTANQUE))
	_ok("4 ya no es agua para el juego y se pisa (pisable)", not Terreno3D.es_agua(ESTANQUE) and Terreno3D.pisable(ESTANQUE, 0, false, 0, false))
	_ok("5 el goblin queda PRESO en el hielo (preso_hielo)", g.has_meta("preso_hielo"))
	var congelado: float = float(g.get("congelado"))
	_ok("5 y congelado > 0", congelado > 0.0, "%.1f s" % congelado)

	# --- Se suelta solo a los 20 s del hechizo ---
	await avanzar_s(Lanzador3D.DURACION_HIELO - (reloj.t - t0) - MARGEN)
	_ok("6 a falta de %.0f s el hielo sigue y el goblin sigue preso" % MARGEN, Terreno3D.helada(ESTANQUE) and g.has_meta("preso_hielo"))
	await avanzar_s(2.0 * MARGEN)
	_ok("7 pasados los %.0f s el hielo se ha fundido" % Lanzador3D.DURACION_HIELO, not Terreno3D.helada(ESTANQUE) and not sim.casilla_helada(ESTANQUE), "t = %.1f s" % (reloj.t - t0))
	_ok("7 la casilla vuelve a ser agua", Terreno3D.es_agua(ESTANQUE))
	_ok("7 el goblin queda libre: sin preso_hielo y congelado = 0", not g.has_meta("preso_hielo") and float(g.get("congelado")) == 0.0, "congelado %.1f" % float(g.get("congelado")))
