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
