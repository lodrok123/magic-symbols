extends "res://herramientas/escenario_base.gd"
## 23/11/2026 (Pablo, PLAN_COMBATE): la barrera sola es un ESCUDO DELANTE con tamaño y duración de base, y la jugadora se mueve libre con ella puesta.
##   · agua / fuego / viento + Barrera: 1 casilla de ancho, 2 niveles de alto, en la casilla de DELANTE (no en la suya), dura 6 s (+1 por cada Barrera de más) y aguanta 36 (tres flechas);
##   · la tinta no sube por el tamaño;
##   · Línea la ensancha desde ahí; la tierra sigue naciendo donde apuntas;
##   · la jugadora deja de estar «lanzando» enseguida y puede pisar las casillas del escudo (no la encierra).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_escudo_barrera.gd

const RUTA_SALA: String = "res://escenas/PruebaArenaCombate.tscn"


func _quitar_barreras() -> void:
	for s in lanzador._solideces_v2:
		if is_instance_valid(s):
			(s as Node).queue_free()
	lanzador.barreras_vivas.clear()
	await avanzar(2)


func _ultima() -> Lanzador3D.SolidezV2:
	var r: Lanzador3D.SolidezV2 = null
	for s in lanzador._solideces_v2:
		if is_instance_valid(s) and not (s as Node).is_queued_for_deletion():
			r = s
	return r


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	(jugador as Jugador3D).vida = 100000.0
	var rune_agua: RuneData = load("res://nucleo/water_rune.tres") as RuneData
	# --- 1 · la receta ---
	var h1: Hechizo = Hechizo.construir(rune_agua, {"barrera": 1})
	var h3: Hechizo = Hechizo.construir(rune_agua, {"barrera": 3})
	var hl: Hechizo = Hechizo.construir(rune_agua, {"barrera": 1, "linea_x": 1})
	var h0: Hechizo = Hechizo.construir(rune_agua, {"flecha": 1})
	_ok("1 barrera sola: semieje X 0,5 (1 casilla de ancho) e Y 1,0 (2 niveles)", is_equal_approx(h1.semieje_x, 0.5) and is_equal_approx(h1.semieje_y, 1.0) and h1.niveles == 2,
		"x %.2f · y %.2f · niveles %d" % [h1.semieje_x, h1.semieje_y, h1.niveles])
	_ok("1 es un escudo delante (muro), no rodea", bool(h1.geo()["muro"]) and Lanzador3D.GeometriaV2.adelanto(h1.geo()) > 0.5)
	_ok("1 dura 6 s de base y +1 s por Barrera de más", is_equal_approx(h1.permanencia, Sigils.BARRERA_DURA_BASE_S) and is_equal_approx(h3.permanencia - h1.permanencia, 2.0),
		"permanencia 1×: %.1f · 3×: %.1f" % [h1.permanencia, h3.permanencia])
	_ok("1 aguanta al menos tres flechas", h1.resistencia >= 3.0 * Combate3D.DANO_FLECHA, "%.1f" % h1.resistencia)
	_ok("1 Línea la ensancha (el ancho del muro es un mínimo: los muros con Línea miden lo de siempre)", hl.semieje_x > h1.semieje_x and is_equal_approx(hl.semieje_x, Sigils.RADIO_BASE_V2 + Sigils.PASO_ANCHO_V2),
		"x %.2f" % hl.semieje_x)
	var tinta_vieja: Hechizo = Hechizo.construir(rune_agua, {"barrera": 1}).con({"semiejes.x": Sigils.RADIO_BASE_V2, "semiejes.y": Sigils.RADIO_BASE_V2})
	_ok("1 el tamaño base no encarece (tinta igual que la bolita de antes)", is_equal_approx(h1.coste_tinta, tinta_vieja.coste_tinta), "%.1f / %.1f" % [h1.coste_tinta, tinta_vieja.coste_tinta])
	_ok("1 un hechizo sin barrera no cambia", is_equal_approx(h0.semieje_y, Sigils.RADIO_BASE_V2) and h0.permanencia == 0.0)
	var ht: Hechizo = Hechizo.construir(load("res://nucleo/earth_rune.tres") as RuneData, {"barrera": 1})
	_ok("1 la tierra sigue naciendo donde apuntas: no es un muro delante (su bloque), pero dura la base de la barrera", ht.en_punto and not ht.es_muro and is_equal_approx(ht.semieje_x, Sigils.RADIO_BASE_V2)
		and is_equal_approx(ht.permanencia, Sigils.BARRERA_DURA_BASE_S), "x %.2f · en_punto %s · permanencia %.1f" % [ht.semieje_x, ht.en_punto, ht.permanencia])
	# procedural: lo decide la forma (propiedades), no el elemento
	var mismos: bool = true
	for r in ["water", "fire", "wind", "lightning"]:
		var hr: Hechizo = Hechizo.construir(load("res://nucleo/%s_rune.tres" % r) as RuneData, {"barrera": 1})
		if not (hr.es_muro and is_equal_approx(hr.semieje_x, h1.semieje_x) and is_equal_approx(hr.semieje_y, h1.semieje_y) and hr.niveles == h1.niveles):
			mismos = false
	_ok("1 procedural: agua, fuego, viento y rayo dan el mismo muro (no hay casos por elemento)", mismos)
	var hm: Hechizo = Hechizo.construir(rune_agua, {"barrera": 1, "flecha": 1})
	_ok("1 la barrera que viaja (ᛜ + ᛇ) no es muro delante pero dura la base al plantarse", not hm.es_muro and is_equal_approx(hm.permanencia, Sigils.BARRERA_DURA_BASE_S), "permanencia %.1f" % hm.permanencia)
	var hla: Hechizo = Hechizo.construir(rune_agua, {"barrera": 1, "altura": 4})
	_ok("1 Altura manda cuando pasa del mínimo de 2 niveles", hla.semieje_y > Sigils.MURO_ALTO_MIN_V2, "y %.2f" % hla.semieje_y)
	_ok("1 el gesto (nombre derivado) no cambia por el mínimo del muro", h1.forma == Hechizo.construir(null, {"barrera": 1}).forma, "%s" % h1.forma)
	# --- 2 · en el juego ---
	for el in ["agua", "fuego", "viento"]:
		await _quitar_barreras()
		var cj := Vector2i(10, 10)
		colocar_jugador(cj)
		await avanzar(3)
		await avanzar_s(3.5)                                   # la recarga de la barrera anterior (3 s)
		if lanzador.tinta != null:
			lanzador.tinta.rellenar_barra()
		var salio: bool = lanzar(el, ["barrera"], Vector3(1, 0, 0))
		var t: float = 0.0
		while _ultima() == null and t < 3.0:
			t += await avanzar_s(0.1)
		var s: Lanzador3D.SolidezV2 = _ultima()
		if s == null:
			_ok("2 %s + barrera: sale el escudo" % el, false, "no salió (lanzar → %s)" % salio)
			continue
		var celdas: Array = s.celdas.keys()
		var cj_ahora: Vector2i = Terreno3D.celda_de(jugador.position)
		var delante: bool = celdas.has(cj_ahora + Vector2i(1, 0)) and not celdas.has(cj_ahora)
		_ok("2 %s + barrera: el escudo está en la casilla de delante, no en la tuya" % el, delante, "celdas %s · jugadora %s" % [str(celdas), str(cj_ahora)])
		_ok("2 %s + barrera: 2 niveles, dura ~6 s, aguanta tres flechas" % el, s.niveles >= 2 and s.vida >= 5.0 and s.aguante >= 3.0 * Combate3D.DANO_FLECHA, "niveles %d · vida %.1f · aguante %.1f" % [s.niveles, s.vida, s.aguante])
		var t_libre: float = 0.0
		while bool(jugador.get("_lanzando")) and t_libre < 5.0:
			t_libre += await avanzar_s(0.1)
		_ok("2 %s + barrera: la jugadora queda libre para moverse enseguida (%.1f s)" % [el, t_libre], t_libre <= 1.5 and is_instance_valid(s))
		var pisa: bool = true
		for c in celdas:
			if not Terreno3D.pisable(c as Vector2i, 0, true, 9, false):
				pisa = false
		_ok("2 %s + barrera: no encierra a la jugadora (sus casillas se pisan)" % el, pisa)
