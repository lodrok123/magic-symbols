extends "res://herramientas/escenario_base.gd"
## Escenario 13.10 · telaraña: el fuego la quema y la casilla deja de estar bloqueada. Lo escribe el Juego (15/10).
##
## El Bosque tiene tres telarañas (letra `r`) en (4,33), (4,34) y (4,35): cierran el paso al este de la franja de hierba. Una telaraña es
## un Reactivo3D «telarana» que BLOQUEA su casilla (Lanzador3D.bloqueada) hasta que arde: entonces chamusca, desaparece con su cuerpo y
## `Terreno3D` libera la casilla. Se dispara fuego + flecha desde el oeste y luego el jugador ANDA (teclas, `mover_hacia`) hasta la casilla.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_telarana.gd

const WEB := Vector2i(4, 33)
const OTRA := Vector2i(4, 34)                          ## una telaraña vecina que NO se apunta
const DESDE := Vector2i(1, 33)


func _escenario() -> void:
	await cargar()
	var telas: Array = maqueta.find_children("*", "Reactivo3D", true, false).filter(func(r: Reactivo3D) -> bool: return r.tipo == "telarana")
	_ok("1 la escena tiene las tres telarañas del mapa", telas.size() == 3, "%d" % telas.size())
	_ok("1 la telaraña (4,33) bloquea su casilla", Lanzador3D.bloqueada(WEB) and not Terreno3D.pisable(WEB, 0, false, 0, false))
	_ok("1 la de al lado (4,34) también", Lanzador3D.bloqueada(OTRA))

	var salio: bool = lanzar_a_celda("fuego", ["flecha"], WEB, DESDE)
	_ok("2 el hechizo fuego + flecha sale", salio)
	await avanzar_s(8.0)
	var golpes: Array = eventos("golpe_objeto").filter(func(e: Dictionary) -> bool: return String(e.get("objeto", "")) == "telarana")
	_ok("3 el diario dice que el fuego golpeó una «telarana»", not golpes.is_empty() and String((golpes[0] as Dictionary).get("elemento", "")) == "fuego", "%d golpes" % golpes.size())
	_ok("3 y la telaraña reaccionó", not golpes.is_empty() and bool((golpes[0] as Dictionary).get("reacciona", false)))
	_ok("4 la casilla (4,33) ya no está bloqueada", not Lanzador3D.bloqueada(WEB))
	_ok("4 se puede pisar", Terreno3D.pisable(WEB, 0, false, 0, false))
	# La vecina NO se afirma: el fuego se contagia entre cosas que arden (es diseño de Objetos), y en 8 s la de (4,34) suele arder también.
	# Se enseña para que se vea qué pasa, sin que sea un contrato.
	_aviso("4 estado de la telaraña vecina (4,34) tras 8 s", "bloqueada = %s" % Lanzador3D.bloqueada(OTRA))

	var llego: bool = await mover_hacia(WEB, 15.0)
	_ok("5 el jugador ANDA con las teclas hasta la casilla liberada", llego and celda_jugador() == WEB, "está en %s" % celda_jugador())
