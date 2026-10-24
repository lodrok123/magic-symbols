extends "res://herramientas/escenario_base.gd"
## EL PROYECTIL `en_punto` NACE EN EL PUNTO APUNTADO (24/10, lote 1 de la auditoría de Hechizo; 05_auditoria_hechizo.md D-5 y propuesta 6), con la escena de verdad y una jugadora con esqueleto:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_en_punto_proyectil.gd
## ESPEC §1.2: `en_punto` = el hechizo nace donde apunta el cursor (dentro del anillo de alcance) y no en el lanzador. El commit 7a91ea36 («los proyectiles salen de la mano») hizo que `HechizoVivo.
## _iniciar_proyectil` sumara el desplazamiento de la mano a TODO proyectil, así que «barrera + flecha» (que es en_punto y viaja) nacía en la mano de la jugadora y no en el punto: ninguna prueba lo miraba
## porque `prueba_cast_points` solo lanza flechas sin barrera.
## Aquí: por el camino de verdad (`Lanzador3D.lanzar_ahora` → `_disparar` → `_salida_de_mano` → `HechizoVivo.crear`)
##   1. flecha sola: nace en la mano (control: lo de 7a91ea36 sigue funcionando);
##   2. barrera + flecha: nace en el punto apuntado (x, z) y NO en la mano;
##   3. el punto apuntado queda dentro del anillo de alcance de la barrera y lejos de la mano (la prueba distingue de verdad una cosa de la otra);
##   4. flecha + ᚠ: salen 2 proyectiles y la tinta se cobra UNA vez (la de la receta), no una por copia.

const DESDE := Vector2i(6, 24)
const CASILLAS_AL_PUNTO: int = 2                ## a cuántas casillas delante de la jugadora se apunta
const ALCANCE_ANILLO_CASILLAS: float = Lanzador3D.ALCANCE_ORIGEN      ## el anillo de alcance de lo que se apunta (cast_page recorta el punto a él)
const TOL_PUNTO_U: float = 0.05                 ## u: cuánto se puede apartar del punto apuntado en planta
const TOL_MANO_U: float = 0.15                  ## u: lo mismo que pide prueba_cast_points (E2) para «nace en la mano»
const MIN_SEPARACION_MANO_U: float = 0.8        ## u: el punto apuntado tiene que estar al menos así de lejos de la mano, o la prueba no distinguiría nada
const TOL_TINTA: float = 0.01


## Los datos de un lanzamiento (lo que `cast_page` prepara) para unos glifos y un elemento.
func _datos(glifos: Array, elem: String) -> Dictionary:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in glifos:
		r.apply(String(g))
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % elem) as RuneData
	return {"indice": 0, "receta": r, "rune": rune, "calidad": 1.0, "glifos": glifos, "elemento_nombre": elem}


func _vivos() -> Array:
	var r: Array = []
	for n in lanzador.get_children():
		if n is HechizoVivo and not n.is_queued_for_deletion():
			r.append(n)
	return r


func _limpiar() -> void:
	for v in _vivos():
		(v as Node).queue_free()
	lanzador.cooldown_left[0] = 0.0
	lanzador.cooldown_left[1] = 0.0
	if jugador.tinta != null:
		jugador.tinta.actual = 100.0
	var t: float = 0.0
	while lanzador.conjurando and t < 4.0:
		t += await avanzar_s(0.1)
	await avanzar(3)


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)
	var pj: Node3D = jugador.get("pj") as Node3D
	_ok("0 la jugadora tiene modelo con esqueleto (sin él `_salida_de_mano` no hace nada y la prueba no mediría el fallo)", pj != null and lanzador.jugador.get("pj") is Node3D)
	if pj == null:
		return
	var punto: Vector3 = Terreno3D.centro_de(DESDE + Vector2i(CASILLAS_AL_PUNTO, 0), Terreno3D.y_pies(DESDE + Vector2i(CASILLAS_AL_PUNTO, 0)))
	var pies: Vector3 = jugador.position

	# --- 1 · flecha sola: en la mano ---
	await _limpiar()
	lanzador.lanzar_ahora(_datos(["flecha"], "fire"), pies, Vector3.RIGHT, false)
	var flecha: Array = _vivos()
	var mano: Vector3 = lanzador._pos_cast_point()
	_ok("1 flecha sola: sale un proyectil", flecha.size() == 1)
	if flecha.size() == 1:
		var f: HechizoVivo = flecha[0]
		_ok("1 …y NACE EN LA MANO de la jugadora (a %.3f u en planta, tolerancia %.2f; altura %.2f u sobre los pies)" % [_plano(f.p, mano), TOL_MANO_U, f.p.y - pies.y], _plano(f.p, mano) <= TOL_MANO_U and f.p.y > pies.y + 0.1)
		_ok("1 …y la mano está a un paso de los pies, no en el punto apuntado (mano a %.2f u de los pies)" % _plano(mano, pies), _plano(mano, pies) < MIN_SEPARACION_MANO_U)

	# --- 2 · barrera + flecha: en el punto apuntado ---
	await _limpiar()
	var datos_bf: Dictionary = _datos(["barrera", "flecha"], "fire")
	lanzador.lanzar_ahora(datos_bf, punto, Vector3.RIGHT, false)
	var bf: Array = _vivos()
	var mano_bf: Vector3 = lanzador._pos_cast_point()
	_ok("2 barrera + flecha: sale un proyectil", bf.size() == 1)
	if bf.size() == 1:
		var b: HechizoVivo = bf[0]
		_ok("2 …es en_punto (el hechizo lo dice) y viaja", b.h.en_punto and b.h.velocidad > 0.0)
		_ok("2 …y NACE EN EL PUNTO APUNTADO (a %.3f u en planta del punto, tolerancia %.2f)" % [_plano(b.p, punto), TOL_PUNTO_U], _plano(b.p, punto) <= TOL_PUNTO_U, "nace en %s, punto %s" % [str(b.p), str(punto)])
		_ok("2 …y NO en la mano (la mano está a %.2f u del punto y el proyectil a %.2f u de la mano)" % [_plano(mano_bf, punto), _plano(b.p, mano_bf)], _plano(b.p, mano_bf) > MIN_SEPARACION_MANO_U)
		_ok("2 …y no sale de la altura de la mano (su salida es la de siempre, %.2f u sobre su casilla: no el %.2f de la mano)" % [b.p.y - Terreno3D.y_pies(Terreno3D.celda_de(b.p)), mano_bf.y - Terreno3D.y_pies(Terreno3D.celda_de(mano_bf))],
			absf((b.p.y - Terreno3D.y_pies(Terreno3D.celda_de(b.p))) - Hechizo.ALTURA_MANO_U) < 0.05)

	# --- 3 · el punto está dentro del anillo y lejos de la mano ---
	var casillas_al_punto: float = _plano(punto, pies) / Terreno3D.casilla
	_ok("3 el punto apuntado (%.1f casillas) está dentro del anillo de alcance (%.0f)" % [casillas_al_punto, ALCANCE_ANILLO_CASILLAS], casillas_al_punto <= ALCANCE_ANILLO_CASILLAS + 0.01)
	_ok("3 y a más de %.1f u de la mano (%.2f u): la prueba distingue un origen del otro" % [MIN_SEPARACION_MANO_U, _plano(punto, mano_bf)], _plano(punto, mano_bf) > MIN_SEPARACION_MANO_U)

	# --- 4 · flecha + ᚠ: dos proyectiles y la tinta UNA vez ---
	await _limpiar()
	var datos_f2: Dictionary = _datos(["flecha", "repeticion"], "fire")
	var receta_f2: Lanzador3D.Receta3D = datos_f2["receta"]
	var esperado: float = Tinta.coste_receta(receta_f2.coste_v2())
	var antes: float = jugador.tinta.actual if jugador.tinta != null else -1.0
	lanzador.lanzar_ahora(datos_f2, pies, Vector3.RIGHT, false)
	var despues: float = jugador.tinta.actual if jugador.tinta != null else -1.0
	var par: Array = _vivos()
	_ok("4 flecha + ᚠ por el camino de verdad: salen 2 proyectiles (copias %d)" % (par[0] as HechizoVivo).h.copias if not par.is_empty() else "4 flecha + ᚠ: no salió nada", par.size() == 2)
	_ok("4 …y la tinta se cobra UNA vez, la de la receta (%.2f gastada, %.2f esperada)" % [antes - despues, esperado], jugador.tinta != null and absf((antes - despues) - esperado) <= TOL_TINTA)
	_ok("4 …y la recarga de la página se pone UNA vez (%.2f s)" % lanzador.cooldown_left[0], absf(lanzador.cooldown_left[0] - receta_f2.cooldown) < 0.01)
	await _limpiar()

	# --- 5 · un sólido quieto (tierra + ᛏ) nace donde apuntas, y si no cabe se avisa y NO se cobra (24/10, decisión de Pablo) ---
	# Antes nacía en la casilla de la jugadora, `construir_tierra` lo rechazaba («encima del jugador») sin avisar y la tinta y la recarga ya estaban cobradas.
	await _limpiar()
	_deshacer_tierra()
	var celda_libre: Vector2i = DESDE + Vector2i(CASILLAS_AL_PUNTO, 0)
	_ok("5 la casilla apuntada (%s) está libre para construir (si no, la prueba no mide nada)" % str(celda_libre), lanzador.puede_construir_en(celda_libre) == "", lanzador.puede_construir_en(celda_libre))
	var datos_t: Dictionary = _datos(["altura"], "earth")
	var receta_t: Lanzador3D.Receta3D = datos_t["receta"]
	var hz_t: Hechizo = receta_t.hechizo(datos_t["rune"] as RuneData)
	_ok("5 tierra + ᛏ es un sólido quieto y nace en el punto (en_punto, origen «%s»)" % String(hz_t.origen.get("en_punto", "")), hz_t.solido_quieto and hz_t.en_punto)
	var tinta_antes: float = jugador.tinta.actual
	var salio_t: bool = lanzador.lanzar_ahora(datos_t, punto, Vector3.RIGHT, false)
	var recarga_t: float = lanzador.cooldown_left[0]         # justo al lanzar: después baja con el tiempo
	await avanzar_s(0.5)
	var tinta_t: float = tinta_antes - jugador.tinta.actual
	var esperado_t: float = Tinta.coste_receta(receta_t.coste_v2())
	_ok("5 apuntando a una casilla libre sale (lanzar_ahora devuelve true)", salio_t)
	_ok("5 …y construye AHÍ: altura %d en %s, y nada en la casilla de la jugadora (altura %d)" % [Terreno3D.altura_en(celda_libre), str(celda_libre), Terreno3D.altura_en(Terreno3D.celda_de(pies))],
		Terreno3D.altura_en(celda_libre) >= 1 and Terreno3D.altura_en(Terreno3D.celda_de(pies)) == 0)
	_ok("5 …y cobra la tinta UNA vez (%.2f gastada, %.2f esperada)" % [tinta_t, esperado_t], absf(tinta_t - esperado_t) <= TOL_TINTA and esperado_t > 0.0)
	_ok("5 …y pone la recarga (%.2f s)" % recarga_t, absf(recarga_t - receta_t.cooldown) < 0.01)

	# 5b · a una casilla de agua: aviso y nada cobrado
	await _limpiar()
	_deshacer_tierra()
	var agua: Vector2i = _casilla_de_agua_con_orilla()
	_ok("5b hay en el mapa una casilla de agua con orilla libre a 2 casillas (si no, la prueba no mide nada)", agua != Vector2i(-1, -1))
	if agua != Vector2i(-1, -1):
		var orilla: Vector2i = agua - Vector2i(CASILLAS_AL_PUNTO, 0)
		colocar_jugador(orilla)
		await avanzar(5)
		await _limpiar()
		var punto_agua: Vector3 = Terreno3D.centro_de(agua, Terreno3D.y_pies(agua))
		var tinta_a: float = jugador.tinta.actual
		lanzador.feedback_text = ""
		var salio_a: bool = lanzador.lanzar_ahora(_datos(["altura"], "earth"), punto_agua, Vector3.RIGHT, false)
		await avanzar_s(0.3)
		_ok("5b tierra + ᛏ apuntando al agua (%s): no sale (lanzar_ahora devuelve false)" % str(agua), not salio_a)
		_ok("5b …con el aviso «Ahí no se puede construir: …» (fue «%s»)" % lanzador.feedback_text, lanzador.feedback_text.begins_with("Ahí no se puede construir"))
		_ok("5b …sin gastar tinta (%.3f) ni poner recarga (%.2f)" % [tinta_a - jugador.tinta.actual, lanzador.cooldown_left[0]], absf(tinta_a - jugador.tinta.actual) < 0.0001 and lanzador.cooldown_left[0] == 0.0)
		_ok("5b …y no nace nada (ni hechizo vivo ni bloque)", _vivos().is_empty() and lanzador.bloques_de_tierra() == 0)
		# el hielo SÍ cabe sobre el agua (la hiela): el mismo punto no se le rechaza
		_ok("5b el hielo quieto sobre el agua NO se rechaza (hiela el agua)", lanzador.rechazo_de_construccion(_datos(["altura"], "ice"), punto_agua) == "", lanzador.rechazo_de_construccion(_datos(["altura"], "ice"), punto_agua))
		colocar_jugador(DESDE)
		await avanzar(5)

	# 5c · fuera del anillo de alcance: aviso y nada cobrado
	await _limpiar()
	_deshacer_tierra()
	var lejos: Vector3 = pies + Vector3.RIGHT * Terreno3D.casilla * (ALCANCE_ANILLO_CASILLAS + 2.0)
	var tinta_l: float = jugador.tinta.actual
	lanzador.feedback_text = ""
	var salio_l: bool = lanzador.lanzar_ahora(_datos(["altura"], "earth"), lejos, Vector3.RIGHT, false)
	await avanzar_s(0.3)
	_ok("5c tierra + ᛏ apuntando fuera del anillo (%.0f casillas): no sale, avisa («%s») y no cobra (%.3f)" % [ALCANCE_ANILLO_CASILLAS + 2.0, lanzador.feedback_text, tinta_l - jugador.tinta.actual],
		not salio_l and lanzador.feedback_text.begins_with("Ahí no se puede construir") and absf(tinta_l - jugador.tinta.actual) < 0.0001 and lanzador.cooldown_left[0] == 0.0)

	# 5d · apuntando a la propia casilla de la jugadora (lo que antes pasaba en silencio con la tinta ya cobrada)
	await _limpiar()
	var tinta_p: float = jugador.tinta.actual
	var salio_p: bool = lanzador.lanzar_ahora(_datos(["altura"], "earth"), pies, Vector3.RIGHT, false)
	_ok("5d tierra + ᛏ en la casilla de la jugadora: no sale, avisa y no cobra (aviso «%s»)" % lanzador.feedback_text, not salio_p and lanzador.feedback_text.contains("estás encima") and absf(tinta_p - jugador.tinta.actual) < 0.0001)
	_deshacer_tierra()
	await _limpiar()


## Deshace la tierra que dejó una prueba (el Lanzador la guarda 25 s) y la altura que dejó en el mapa.
func _deshacer_tierra() -> void:
	for b in lanzador._bloques.duplicate():
		lanzador._deshacer_bloque(b)


## Una casilla de agua cuya casilla a 2 hacia la izquierda es suelo libre (para colocar a la jugadora a 2 casillas del agua, dentro del anillo). (-1, -1) si no hay.
func _casilla_de_agua_con_orilla() -> Vector2i:
	for z in range(Terreno3D.mapa.size()):
		for x in range(2, Terreno3D.mapa[z].length()):
			var a := Vector2i(x, z)
			var o := Vector2i(x - CASILLAS_AL_PUNTO, z)
			var m := Vector2i(x - 1, z)
			if Terreno3D.es_agua(a) and Terreno3D.letra_de(a) != "b" and not Terreno3D.es_agua(o) and not Terreno3D.es_agua(m) and not Terreno3D.bloqueada(o) and not Terreno3D.bloqueada(m) and lanzador.puede_construir_en(o) == "" and Terreno3D.altura_en(o) == 0:
				return a
	return Vector2i(-1, -1)
