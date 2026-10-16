extends "res://herramientas/escenario_base.gd"
## Escenario 14.3 · pantalla de muerte (A3): al morir, la UI se esconde, el mundo se desenfoca, sale «Has muerto» (0,6 s de fundido + 1,5 s)
## y el jugador reaparece en el último guardado con la UI de vuelta. Lo escribe el Juego (16/10). Mide con tiempo de juego, no de pared.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_muerte.gd

const DESDE := Vector2i(6, 24)


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)
	var pj: Node = jugador
	var pm: PantallaMuerte = pj.pantalla_muerte
	_ok("1 el jugador tiene pantalla de muerte", pm != null)
	if pm == null:
		return
	var capas_visibles: Array = []
	for n in get_root().find_children("*", "CanvasLayer", true, false):
		if n != pm and (n as CanvasLayer).visible:
			capas_visibles.append(n)
	_ok("1 hay interfaz visible antes de morir", capas_visibles.size() > 0, str(capas_visibles.size()))
	_ok("1 la pantalla está apagada", not pm.visible and not pm.activa)

	var inicio: Vector3 = pj.puntos_inicio
	pj.global_position = inicio + Vector3(3, 0, 0)
	await avanzar(2)
	var vida_max: float = float(pj.get("vida_max")) if pj.get("vida_max") != null else 100.0
	pj.recibir_dano(100000)
	await avanzar(2)
	_ok("2 el jugador está muerto", bool(pj.muerto))
	_ok("2 sale la pantalla de muerte", pm.visible and pm.activa and pm.fase == "fundido", pm.fase)
	var ocultas: bool = true
	for n in capas_visibles:
		if (n as CanvasLayer).visible:
			ocultas = false
	_ok("2 toda la interfaz queda fuera", ocultas)
	await avanzar_s(0.7)
	_ok("3 pasado el fundido (0,6 s) se mantiene", pm.fase == "mantiene", pm.fase)
	_ok("3 «Has muerto» es visible y rojo apagado", pm.get("_texto").modulate.a > 0.95 and pm.COLOR_TEXTO == Color("8a2a2a"))
	_ok("3 sigue muerto (no reaparece solo a los 2,2 s)", bool(pj.muerto))
	await avanzar_s(1.4)
	_ok("4 a los ~2,1 s empieza el fundido a negro", pm.fase == "negro" or pm.fase == "salida", pm.fase)
	await avanzar_s(0.6)
	_ok("5 el jugador reaparece", not bool(pj.muerto))
	_ok("5 reaparece en el último guardado", pj.global_position.distance_to(inicio) < 1.0, str(pj.global_position))
	await avanzar_s(0.8)
	_ok("6 la pantalla se apaga", not pm.visible and not pm.activa)
	var vueltas: bool = true
	for n in capas_visibles:
		if is_instance_valid(n) and not (n as CanvasLayer).visible:
			vueltas = false
	_ok("6 la interfaz vuelve como estaba", vueltas)
	_ok("6 PlayLog anota inicio y reaparición", eventos("pantalla_muerte").size() >= 2, str(eventos("pantalla_muerte").size()))

	# Con espera de tecla: no reaparece hasta pulsar, y no antes de 2 s
	pm.esperar_tecla = true
	pj.set("_t_inv", 0.0)                  # tras reaparecer hay 1,2 s de invulnerabilidad
	pj.recibir_dano(100000)
	await avanzar_s(1.0)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await avanzar(2)
	_ok("7 antes de 2 s la tecla no hace nada", bool(pj.muerto) and pm.fase == "mantiene", pm.fase)
	await avanzar_s(2.0)
	_ok("7 sin pulsar sigue esperando", bool(pj.muerto) and pm.fase == "mantiene")
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_SPACE
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await avanzar_s(1.3)
	_ok("7 al pulsar una tecla (pasados 2 s) reaparece", not bool(pj.muerto))
	pm.esperar_tecla = false
