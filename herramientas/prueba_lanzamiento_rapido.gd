extends "res://herramientas/escenario_base.gd"
## A1 · LANZAMIENTO RÁPIDO (27/10; docs/PROPUESTA_COMBATE.md §1.1 y §7): mantener 1/2/3 con el libro cerrado apunta (tiempo a `TIEMPO_PAGINA`, la jugadora NO se bloquea y anda),
## soltar esa tecla lanza hacia el ratón, clic derecho / Esc cancelan sin cobrar, y el «lanzamiento inteligente» lanza al pulsar. El modo del libro (`cast_page`) no cambia.
##
## Va sobre la ESCENA REAL (PruebaBosque: Jugador3D, Lanzador3D, cámara, libro) y por el camino REAL de entrada: las teclas KEY_1/KEY_2/KEY_W/Esc entran con
## `Input.parse_input_event(InputEventKey)` (las recibe el libro, `spellbook.gd::_input`), el ratón con `InputEventMouseMotion` (lo lee `Viewport.get_mouse_position()` cada
## fotograma) y el clic derecho con `InputEventMouseButton`. Lo único que NO es real es dónde está el ratón: en headless no hay puntero físico, así que se «mueve» con eventos
## de motion a la pantalla que da `Camera3D.unproject_position` para el punto del suelo que se quiere apuntar (la cámara y el rayo cámara→suelo son los reales).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_lanzamiento_rapido.gd

var _disparos: Array = []        ## [{origen, dir}] de cada hechizo que sale (señal hechizo_v2)
var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


# --- entrada real -------------------------------------------------------------------------------------------------

func _raton(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = root.get_final_transform() * p        # en headless la ventana mide 64×64 y el viewport se estira a 1152×648: el evento va en coordenadas de VENTANA
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _clic_derecho(p: Vector2, pulsado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pulsado
	ev.position = root.get_final_transform() * p
	ev.global_position = ev.position
	Input.parse_input_event(ev)


## Pantalla en la que el rayo de la cámara corta el plano de los pies justo en `p` (el mismo plano que usa `Lanzador3D.punto_en_suelo`).
func _pantalla_de(p: Vector3) -> Vector2:
	return lanzador.camara.unproject_position(Vector3(p.x, float(jugador.call("y_pies_actual")), p.z))


func _apuntar_a(p: Vector3) -> void:
	_raton(_pantalla_de(p))


## El punto del suelo a `casillas` casillas de la jugadora hacia `dir` (plano XZ).
func _punto(dir: Vector3, casillas: float) -> Vector3:
	return jugador.position + dir.normalized() * casillas * Terreno3D.casilla


func _tinta() -> float:
	return lanzador.tinta.actual if lanzador.tinta != null else 0.0


func _preparar(elemento: String, glifos: Array) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()


## Espera hasta `max_s` de reloj a que haya `n` disparos.
func _esperar_disparos(n: int, max_s: float = 2.0) -> void:
	var t: float = 0.0
	while _disparos.size() < n and t < max_s:
		t += await avanzar_s(0.1)


## Una casilla despejada con 7×7 de suelo llano alrededor (para que la barrera y la flecha no tropiecen con nada) y se pone a la jugadora ahí.
func _buscar_claro() -> bool:
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
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var v := c + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	if mejor.x < 0:
		return false
	colocar_jugador(mejor)
	return true


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	lanzador.conjuro_fase.connect(func(fase: String, _el: String, _pos: Vector3) -> void:
		if fase == "disparo":
			_disparos.append(lanzador.ultimo_disparo.duplicate()))
	_ok("0 hay cámara y el libro está cerrado", lanzador.camara != null and not lanzador.libro_abierto())
	_ok("0 TIEMPO_PAGINA es 0,7 y el del libro sigue en 0,3", is_equal_approx(Lanzador3D.TIEMPO_PAGINA, 0.7) and is_equal_approx(Lanzador3D.RALENTIZADO, 0.3))
	_ok("0 el lanzamiento inteligente empieza apagado", not lanzador.lanzamiento_inteligente)
	var claro: bool = _buscar_claro()
	_ok("0 hay un claro llano de 7×7 donde probar", claro)
	if not claro:
		return
	await avanzar(40)       # la cámara alcanza a la jugadora
	var este := Vector3.RIGHT
	var norte := Vector3(0, 0, -1)

	# --- 1 · el ratón entra por eventos de verdad ---
	var objetivo: Vector3 = _punto(este, 2.5)
	_apuntar_a(objetivo)
	await avanzar(2)
	var leido: Vector2 = root.get_mouse_position()
	var esperado: Vector2 = _pantalla_de(objetivo)
	_ok("1 el ratón de eventos llega a Viewport.get_mouse_position()", leido.distance_to(esperado) < 1.0, "%s vs %s" % [leido, esperado])
	var p_suelo: Vector3 = lanzador.punto_en_suelo(leido)
	_ok("1 y el rayo cámara→suelo devuelve el punto apuntado", p_suelo.distance_to(Vector3(objetivo.x, p_suelo.y, objetivo.z)) < 0.05, "%s vs %s" % [p_suelo, objetivo])

	# --- 2 · mantener 1: modo rápido, 0,7, previsualización, sin bloquear ---
	_preparar("fuego", ["flecha"])
	var tinta0: float = _tinta()
	_disparos.clear()
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("2 mantener 1 entra en el modo de lanzar RÁPIDO", lanzador.modo_lanzar and lanzador._rapido)
	_ok("2 el tiempo va a TIEMPO_PAGINA (0,7)", absf(Engine.time_scale - 0.7) < 0.01, "time_scale %.3f" % Engine.time_scale)
	_ok("2 la jugadora NO está bloqueada", not bool(jugador.get("bloqueado")))
	_ok("2 hay previsualización (una flecha enseña su recorrido real desde el 28/10, no la caja de su cuerpo)", _celdas_previa().size() > 0)
	_ok("2 la guía dice «Suelta [1] para lanzar…»", lanzador._guia != null and lanzador._guia.visible and lanzador._guia.text.begins_with("Suelta [1] para lanzar"), lanzador._guia.text if lanzador._guia != null else "")
	_ok("2 todavía no se ha cobrado nada ni salido nada", is_equal_approx(_tinta(), tinta0) and _disparos.is_empty())
	_ok("2 el punto vivo sigue al ratón", lanzador._punto_vivo.distance_to(Vector3(objetivo.x, lanzador._punto_vivo.y, objetivo.z)) < 0.1, str(lanzador._punto_vivo))
	_ok("2 el 1 mantenido hace que el eco de Godot no cambie nada (modo sigue)", lanzador.modo_lanzar and lanzador._pagina_rapida == 0)

	# --- 3 · otra página mientras tanto se ignora ---
	_tecla(KEY_2, true)
	await avanzar(2)
	_ok("3 pulsar 2 con el 1 mantenido se ignora (sigue la página 1, a 0,7)", lanzador.modo_lanzar and lanzador._pagina_rapida == 0 and absf(Engine.time_scale - 0.7) < 0.01)
	_tecla(KEY_2, false)
	await avanzar(2)
	_ok("3 soltar el 2 no lanza ni cancela", lanzador.modo_lanzar and _disparos.is_empty())

	# --- 4 · soltar lanza hacia el ratón y cobra ---
	_tecla(KEY_1, false)
	await avanzar(1)
	_ok("4 soltar sale del modo y el tiempo vuelve a 1", not lanzador.modo_lanzar and not lanzador._rapido and absf(Engine.time_scale - 1.0) < 0.01, "time_scale %.3f" % Engine.time_scale)
	_ok("4 se cobró la tinta al soltar", _tinta() < tinta0 - 0.5, "%.1f → %.1f" % [tinta0, _tinta()])
	_ok("4 la página queda en recarga", float(lanzador.cooldown_left[0]) > 0.0)
	await _esperar_disparos(1)
	_ok("4 sale UN hechizo", _disparos.size() == 1, str(_disparos.size()))
	if _disparos.size() == 1:
		var d: Vector3 = _disparos[0]["dir"]
		var quiere: Vector3 = (objetivo - jugador.position)
		quiere.y = 0.0
		quiere = quiere.normalized()
		_ok("4 va hacia el punto del ratón (este)", Vector3(d.x, 0, d.z).normalized().dot(quiere) > 0.98, "dir %s quiere %s" % [d, quiere])
		var o: Vector3 = _disparos[0]["origen"]
		_ok("4 y nace en la jugadora (la flecha no nace en el puntero)", Vector2(o.x - jugador.position.x, o.z - jugador.position.z).length() < 1.5 * Terreno3D.casilla)
	await avanzar_s(1.0)

	# --- 5 · Esc mientras se mantiene: no sale, no cobra, soltar luego no lanza ---
	_preparar("fuego", ["flecha"])
	tinta0 = _tinta()
	_disparos.clear()
	_apuntar_a(_punto(norte, 2.0))
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("5 mantener 1 entra en el modo rápido", lanzador.modo_lanzar and lanzador._rapido)
	_tecla(KEY_ESCAPE, true)
	await avanzar(1)
	_tecla(KEY_ESCAPE, false)
	await avanzar(1)
	_ok("5 Esc cancela el modo y devuelve el tiempo", not lanzador.modo_lanzar and absf(Engine.time_scale - 1.0) < 0.01, "time_scale %.3f" % Engine.time_scale)
	_ok("5 la jugadora queda desbloqueada y sin modo de apuntar rápido", not bool(jugador.get("bloqueado")) and not bool(jugador.get("apuntando_rapido")))
	_tecla(KEY_1, false)
	await avanzar_s(1.0)
	_ok("5 soltar la tecla después NO lanza, no cobra y no recarga", _disparos.is_empty() and is_equal_approx(_tinta(), tinta0) and float(lanzador.cooldown_left[0]) <= 0.0,
		"disparos %d · tinta %.1f/%.1f" % [_disparos.size(), _tinta(), tinta0])

	# --- 6 · clic derecho mientras se mantiene ---
	var pan: Vector2 = _pantalla_de(_punto(este, 2.0))
	_raton(pan)
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("6 mantener 1 entra en el modo rápido", lanzador.modo_lanzar and lanzador._rapido)
	_clic_derecho(pan, true)
	await avanzar(1)
	_clic_derecho(pan, false)
	await avanzar(1)
	_ok("6 el clic derecho cancela el modo", not lanzador.modo_lanzar and absf(Engine.time_scale - 1.0) < 0.01)
	_tecla(KEY_1, false)
	await avanzar_s(1.0)
	_ok("6 soltar después no lanza ni cobra", _disparos.is_empty() and is_equal_approx(_tinta(), tinta0))

	# --- 7 · toque corto: pulsar y soltar enseguida lanza hacia el ratón ---
	_preparar("fuego", ["flecha"])
	tinta0 = _tinta()
	_disparos.clear()
	var sur := Vector3(0, 0, 1)
	var objetivo7: Vector3 = _punto(sur, 3.0)
	_apuntar_a(objetivo7)
	await avanzar(1)
	_tecla(KEY_1, true)
	await avanzar(1)
	_tecla(KEY_1, false)
	await avanzar(1)
	_ok("7 el toque corto no deja el modo puesto", not lanzador.modo_lanzar)
	await _esperar_disparos(1)
	_ok("7 el toque corto lanza", _disparos.size() == 1 and _tinta() < tinta0 - 0.5, "disparos %d" % _disparos.size())
	if _disparos.size() == 1:
		var d7: Vector3 = _disparos[0]["dir"]
		_ok("7 hacia el ratón (sur)", Vector3(d7.x, 0, d7.z).normalized().dot(sur) > 0.98, str(d7))
	await avanzar_s(1.0)

	# --- 8 · barrera en punto con el ratón a 6 casillas: nace a ≤ ALCANCE_ORIGEN ---
	_preparar("tierra", ["barrera"])
	_disparos.clear()
	var lejos: Vector3 = _punto(este, 6.0)
	_apuntar_a(lejos)
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("8 la barrera entra en el modo rápido y es en_punto", lanzador.modo_lanzar and lanzador._rapido and bool(lanzador._preparado.get("en_punto", false)))
	var o_vivo: Vector3 = lanzador._origen_vivo
	var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla + Lanzador3D.TOLERANCIA_ALCANCE_U
	_ok("8 el origen vivo está recortado al anillo (≤ %.2f u)" % tope, Vector2(o_vivo.x - jugador.position.x, o_vivo.z - jugador.position.z).length() <= tope,
		"%.2f u" % Vector2(o_vivo.x - jugador.position.x, o_vivo.z - jugador.position.z).length())
	_tecla(KEY_1, false)
	await avanzar(1)
	await _esperar_disparos(1)
	_ok("8 la barrera sale", _disparos.size() == 1, "disparos %d · aviso «%s»" % [_disparos.size(), lanzador.feedback_text])
	if _disparos.size() == 1:
		var ob: Vector3 = _disparos[0]["origen"]
		var dist: float = Vector2(ob.x - jugador.position.x, ob.z - jugador.position.z).length()
		_ok("8 nace a ≤ ALCANCE_ORIGEN (%.2f u ≤ %.2f u) aunque el ratón estaba a 6 casillas" % [dist, tope], dist <= tope and dist > 1.0 * Terreno3D.casilla)
	await avanzar_s(1.0)

	# --- 9 · andar con W mientras se mantiene ---
	_preparar("fuego", ["flecha"])
	_disparos.clear()
	colocar_jugador(celda_jugador())
	await avanzar(10)
	var pos0: Vector3 = jugador.position
	_apuntar_a(_punto(este, 2.0))
	_tecla(KEY_1, true)
	await avanzar(3)
	var casillas0: Array = _celdas_previa()
	_tecla(KEY_W, true)
	var seguido: bool = true
	var max_desfase: float = 0.0
	var t9: float = 0.0
	while t9 < 2.0:
		t9 += await avanzar_s(0.1)
		var of: Vector3 = lanzador._origen_vivo
		var desfase: float = Vector2(of.x - jugador.position.x, of.z - jugador.position.z).length()
		max_desfase = maxf(max_desfase, desfase)
	_ok("9 andar con W mueve a la jugadora aunque esté apuntando", jugador.position.distance_to(pos0) > 0.8 * Terreno3D.casilla * 0.5, "%.2f u" % jugador.position.distance_to(pos0))
	_ok("9 el origen vivo la sigue fotograma a fotograma (desfase máx. %.2f u)" % max_desfase, max_desfase < 0.6, "%.2f" % max_desfase)
	_tecla(KEY_W, false)
	await avanzar(4)
	var of2: Vector3 = lanzador._origen_vivo
	_ok("9 y parada, el origen es ella", Vector2(of2.x - jugador.position.x, of2.z - jugador.position.z).length() < 0.05)
	_ok("9 el marcador de origen y el anillo de alcance están en ella",
		Vector2(lanzador._marca_origen.position.x - jugador.position.x, lanzador._marca_origen.position.z - jugador.position.z).length() < 0.05
		and Vector2(lanzador._marca_alcance.position.x - jugador.position.x, lanzador._marca_alcance.position.z - jugador.position.z).length() < 0.05)
	var casillas1: Array = _celdas_previa()
	casillas0.sort()
	casillas1.sort()
	_ok("9 la previsualización se movió con ella (%s → %s)" % [casillas0, casillas1], casillas0 != casillas1 and casillas1.size() > 0)
	var cj: Vector2i = celda_jugador()
	var cerca: bool = true
	for c in casillas1:
		if Vector2(c - cj).length() > 4.0:
			cerca = false
	_ok("9 y sus casillas están junto a ella", cerca)
	_ok("9 el modo sigue puesto tras andar y no se bloqueó", lanzador.modo_lanzar and not bool(jugador.get("bloqueado")))

	# 9b · sin correr, sin rodar, sin saltar
	var y0: float = jugador.position.y
	var a0: Vector3 = jugador.position
	_tecla(KEY_W, true)
	await avanzar_s(1.0)
	_tecla(KEY_W, false)
	var d_andar: float = Vector2(jugador.position.x - a0.x, jugador.position.z - a0.z).length()
	await avanzar(3)
	var a1: Vector3 = jugador.position
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await avanzar_s(1.0)
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	var d_shift: float = Vector2(jugador.position.x - a1.x, jugador.position.z - a1.z).length()
	_ok("9b Mayús no hace correr mientras apunta (%.2f u andando, %.2f u con Mayús)" % [d_andar, d_shift], d_andar > 0.2 and d_shift < d_andar * 1.25, "")
	_tecla(KEY_CTRL, true)
	_tecla(KEY_SPACE, true)
	await avanzar_s(0.4)
	var rodando: float = float(jugador.get("_t_roll"))
	_tecla(KEY_CTRL, false)
	_tecla(KEY_SPACE, false)
	_ok("9b Ctrl no hace rodar ni Espacio saltar mientras apunta", rodando <= 0.0 and absf(jugador.position.y - y0) < 0.1, "t_roll %.2f · Δy %.2f" % [rodando, jugador.position.y - y0])
	# soltar: lanza desde donde está ahora, hacia el ratón
	_disparos.clear()
	_tecla(KEY_1, false)
	await avanzar(1)
	await _esperar_disparos(1)
	_ok("9 soltar tras andar lanza desde la posición de ahora", _disparos.size() == 1 and Vector2((_disparos[0]["origen"] as Vector3).x - jugador.position.x, (_disparos[0]["origen"] as Vector3).z - jugador.position.z).length() < 1.5 * Terreno3D.casilla,
		"disparos %d" % _disparos.size())
	await avanzar_s(1.0)
	_ok("9 la jugadora vuelve a poder correr y rodar al salir (apuntando_rapido apagado)", not bool(jugador.get("apuntando_rapido")))

	# --- 10 · página en recarga: no entra y avisa ---
	_preparar("fuego", ["flecha"])
	lanzador.cooldown_left[0] = 4.0
	lanzador.feedback_text = ""
	_tecla(KEY_1, true)
	await avanzar(2)
	_ok("10 una página en recarga no entra en el modo", not lanzador.modo_lanzar and absf(Engine.time_scale - 1.0) < 0.01)
	_ok("10 y avisa «Recargando»", lanzador.feedback_text.begins_with("Recargando"), lanzador.feedback_text)
	_tecla(KEY_1, false)
	await avanzar(2)
	_ok("10 soltarla no lanza nada", _disparos.size() == 1)
	lanzador.cooldown_left[0] = 0.0

	# --- 11 · sin tinta: tampoco entra ---
	if lanzador.tinta != null:
		_preparar("fuego", ["flecha"])
		lanzador.tinta.actual = 0.0
		lanzador.tinta.frascos = 0          # con frascos de reserva SÍ se podría pagar
		lanzador.feedback_text = ""
		_tecla(KEY_1, true)
		await avanzar(2)
		_ok("11 sin tinta no entra en el modo y avisa", not lanzador.modo_lanzar and lanzador.feedback_text.begins_with("Tinta insuficiente"), lanzador.feedback_text)
		_tecla(KEY_1, false)
		await avanzar(2)
		lanzador.tinta.rellenar_barra()
		lanzador.tinta.frascos = Tinta.FRASCOS_INICIALES
		lanzador.cooldown_left[0] = 0.0

	# --- 12 · lanzamiento inteligente: pulsar lanza al instante, sin modo ---
	_preparar("fuego", ["flecha"])
	_disparos.clear()
	tinta0 = _tinta()
	lanzador.lanzamiento_inteligente = true
	_apuntar_a(_punto(norte, 3.0))
	await avanzar(1)
	var modo_visto: bool = false
	_tecla(KEY_1, true)
	for _i in range(3):
		await process_frame
		modo_visto = modo_visto or lanzador.modo_lanzar
	_ok("12 con el lanzamiento inteligente pulsar NO entra en ningún modo", not modo_visto and absf(Engine.time_scale - 1.0) < 0.01)
	await _esperar_disparos(1)
	_ok("12 pero lanza, y cobra", _disparos.size() == 1 and _tinta() < tinta0 - 0.5, "disparos %d" % _disparos.size())
	if _disparos.size() == 1:
		var d12: Vector3 = _disparos[0]["dir"]
		_ok("12 hacia el ratón (norte)", Vector3(d12.x, 0, d12.z).normalized().dot(norte) > 0.98, str(d12))
	_tecla(KEY_1, false)
	await avanzar_s(0.5)
	_ok("12 soltar no lanza otra vez", _disparos.size() == 1)
	_ok("12 el ajuste vive en Estado", Estado.i().lanzamiento_inteligente)
	lanzador.lanzamiento_inteligente = false
	_ok("12 y se apaga", not Estado.i().lanzamiento_inteligente and not lanzador.lanzamiento_inteligente)
	await avanzar_s(1.0)

	# --- 13 · el modo del libro (cast_page) no cambia: 0,3 y bloqueada ---
	_preparar("fuego", ["flecha"])
	lanzador.cast_page(0)
	await avanzar(3)
	_ok("13 cast_page entra en el modo de siempre (no rápido)", lanzador.modo_lanzar and not lanzador._rapido)
	_ok("13 a RALENTIZADO (0,3)", absf(Engine.time_scale - 0.3) < 0.01, "time_scale %.3f" % Engine.time_scale)
	_ok("13 y bloquea a la jugadora", bool(jugador.get("bloqueado")))
	_ok("13 con la guía de siempre", lanzador._guia != null and lanzador._guia.text.contains("arrastra para dirigir"))
	var p13: Vector3 = jugador.position
	_tecla(KEY_W, true)
	await avanzar_s(0.5)
	_tecla(KEY_W, false)
	_ok("13 y no se mueve con W", jugador.position.distance_to(p13) < 0.05, "%.2f u" % jugador.position.distance_to(p13))
	lanzador._cancelar_modo()
	await avanzar(2)
	_ok("13 cancelado: desbloqueada y tiempo a 1", not bool(jugador.get("bloqueado")) and absf(Engine.time_scale - 1.0) < 0.01)

	# --- 14 · el atajo por código de los escenarios sigue entrando en el modo de siempre ---
	_preparar("fuego", ["flecha"])
	_disparos.clear()
	var sale: bool = lanzador.lanzar_pagina_ya(0, jugador.position, este)
	await _esperar_disparos(1)
	_ok("14 lanzar_pagina_ya sigue lanzando sin ratón ni cámara", sale and _disparos.size() == 1)
	_ok("14 y no deja ningún modo puesto", not lanzador.modo_lanzar and absf(Engine.time_scale - 1.0) < 0.01)

	print("COMPROBACIONES: %d" % _comprobaciones)


## Las casillas de la previsualización: las cajas de lo que no vuela y, si vuela, las del recorrido dibujado (`Apuntado3D.caminos_dibujados`, desde el 28/10).
func _celdas_previa() -> Array:
	var r: Array = []
	for m in lanzador._prev_casillas:
		if (m as MeshInstance3D).visible:
			r.append(Terreno3D.celda_de((m as MeshInstance3D).position))
	if lanzador._apuntado != null and is_instance_valid(lanzador._apuntado):
		for c in lanzador._apuntado.caminos_dibujados:
			for q in (c as PackedVector3Array):
				var cq: Vector2i = Terreno3D.celda_de(q)
				if not r.has(cq):
					r.append(cq)
	return r
