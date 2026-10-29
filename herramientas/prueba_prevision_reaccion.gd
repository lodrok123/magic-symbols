extends "res://herramientas/prueba_prevision_hechizo.gd"
## A3 · PREVISUALIZAR LA REACCIÓN EN EL INDICADOR (28/10; docs/PROPUESTA_COMBATE.md §7; presentacion/prevision_reaccion_3d.gd).
## Sobre la ESCENA REAL (PruebaBosque) y con el modo de apuntar de verdad (`cast_page`, y `pulsar_pagina` para el rápido): la jugadora apunta y, sin soltar, se mira lo que pinta
## `PrevisionReaccion3D` (`pintado` y sus nodos). Comprueba que lo pintado es EXACTAMENTE lo que `PrevisionHechizo.prever` dice (una marca por enemigo y pieza, un grupo por reacción de
## suelo), con el texto, el multiplicador y el sitio correctos; que sigue al enemigo y al cambio de puntería; que no pinta nada si no hay reacción; que se va al salir del modo y que no crea
## nodos nuevos fotograma a fotograma. Los montajes (goblins, brasero, bloque, orilla) son los de la prueba de A2, de la que hereda.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_prevision_reaccion.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(30)
	_ok("0 el Lanzador pinta reacciones (PREVER_REACCIONES)", Lanzador3D.PREVER_REACCIONES)
	await _caso_enemigo()
	await _caso_multiplicadores()
	await _caso_hunde()
	await _caso_suelo_hielo()          # antes que las piezas: el bloque de (9,33) deja su casilla bloqueada y taparía la flecha (como en la prueba de A2)
	await _caso_pieza()
	await _caso_nada()
	await _caso_sigue()
	await _caso_rapido()
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- apuntar sin soltar --------------------------------------------------------------------------------------------

## Prepara la página con `cast_page` (el modo de apuntar de siempre) y pone el puntero a `casillas` de la jugadora en `dir`. Devuelve la vista tras unos fotogramas.
func _apuntar(c_j: Vector2i, elemento: String, glifos: Array, dir: Vector3 = Vector3(-1, 0, 0), casillas: float = 2.0) -> PrevisionReaccion3D:
	_preparar(c_j, elemento, glifos)
	_ok("apuntar %s %s: entra en el modo de lanzar" % [elemento, str(glifos)], lanzador.modo_lanzar)
	_mover_puntero(dir, casillas)
	await avanzar(4)
	return lanzador._vista_reaccion


func _mover_puntero(dir: Vector3, casillas: float) -> void:
	lanzador._punto_vivo = jugador.position + dir.normalized() * casillas * Terreno3D.casilla
	lanzador._calcular_origen_vivo()


func _soltar_sin_lanzar() -> void:
	lanzador._cancelar_modo()
	await avanzar(2)


## Lo que `prever` dice AHORA para lo preparado, con el origen y la dirección del indicador.
func _prever_ahora() -> Array[Dictionary]:
	PrevisionHechizo.olvidar()
	var o: Vector3 = lanzador._origen_fijo if lanzador._fijado else lanzador._origen_vivo
	return PrevisionHechizo.prever(lanzador, lanzador._preparado, o, lanzador._direccion_actual())


func _pintada(v: PrevisionReaccion3D, que: String, nodo: Variant = null) -> Dictionary:
	if v == null:
		return {}
	for p in v.pintado:
		if String(p["que"]) == que and (nodo == null or p["nodo"] == nodo):
			return p
	return {}


func _rotulos_visibles(v: PrevisionReaccion3D) -> Array:
	var r: Array = []
	if v == null:
		return r
	for l in v._rotulos:
		if l.visible:
			r.append(l)
	return r


func _visibles(poza: Array) -> int:
	return poza.filter(func(n): return (n as Node3D).visible).size()


## Lo pintado y lo previsto son lo mismo: una marca por enemigo y por pieza, y un grupo por reacción de suelo con las mismas casillas.
func _coinciden(nombre: String, v: PrevisionReaccion3D, prev: Array[Dictionary]) -> void:
	var esperado: Array = []
	var suelo: Dictionary = {}
	for e in prev:
		if String(e["que"]) == "suelo":
			var r: String = String(e["reaccion"])
			if not suelo.has(r):
				suelo[r] = []
			(suelo[r] as Array).append(e["celda"])
		else:
			esperado.append("%s:%s:%d" % [e["que"], e["reaccion"], (e["nodo"] as Node).get_instance_id() if e["nodo"] != null else 0])
	for r in suelo:
		var cs: Array = suelo[r]
		cs.sort()
		esperado.append("suelo:%s:%s" % [r, str(cs)])
	var pintado: Array = []
	if v != null:
		for p in v.pintado:
			if String(p["que"]) == "suelo":
				var cs2: Array = (p["celdas"] as Array).duplicate()
				cs2.sort()
				pintado.append("suelo:%s:%s" % [p["reaccion"], str(cs2)])
			else:
				pintado.append("%s:%s:%d" % [p["que"], p["reaccion"], (p["nodo"] as Node).get_instance_id() if p["nodo"] != null else 0])
	esperado.sort()
	pintado.sort()
	_ok("%s · lo pintado es lo previsto" % nombre, esperado == pintado, "previsto %s · pintado %s" % [str(esperado), str(pintado)])


# --- casos ---------------------------------------------------------------------------------------------------------

func _caso_enemigo() -> void:
	var g: Combate3D = _goblin(Vector2i(9, 31))
	await avanzar(3)
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(11, 31), "fuego", ["flecha"])
	_ok("1 al apuntar existe la vista de la reacción", v != null and is_instance_valid(v) and v.is_inside_tree())
	_coinciden("1 fuego a goblin", v, _prever_ahora())
	var p: Dictionary = _pintada(v, "enemigo", g)
	_ok("1 el goblin lleva «Prende» (sin multiplicador)", not p.is_empty() and p["texto"] == "Prende", str(p))
	var rot: Array = _rotulos_visibles(v).filter(func(l): return (l as Label3D).text.begins_with("Prende"))
	_ok("1 hay un solo rótulo «Prende» (la hierba que prende bajo él lleva cuadro, no otro rótulo)", rot.size() == 1, str(_rotulos_visibles(v).map(func(l): return l.text)))
	if rot.size() == 1:
		var l: Label3D = rot[0]
		var dxz: float = Vector2(l.global_position.x - g.global_position.x, l.global_position.z - g.global_position.z).length()
		_ok("1 el rótulo está sobre su cabeza (en x/z a %.2f u; %.2f u por encima de los pies)" % [dxz, l.global_position.y - g.global_position.y],
			dxz < 0.05 and l.global_position.y > g.global_position.y + g.altura)
		_ok("1 el rótulo es del color de «prende» y se ve a través de todo", l.modulate.is_equal_approx(PrevisionReaccion3D._color("prende")) and l.no_depth_test)
	_ok("1 hay un anillo bajo el goblin", _visibles(v._anillos) >= 1)
	await _soltar_sin_lanzar()
	_ok("1 al salir del modo la vista se va", lanzador._vista_reaccion == null and not is_instance_valid(v))
	_limpiar()
	await avanzar(3)


func _caso_multiplicadores() -> void:
	var g: Combate3D = _goblin(Vector2i(9, 31), "agua", "")
	await avanzar(3)
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(11, 31), "agua", ["flecha"])
	var p: Dictionary = _pintada(v, "enemigo", g)
	_ok("2 agua a un goblin débil al agua: «Moja ×1,5»", not p.is_empty() and p["texto"] == "Moja ×1,5", str(p))
	var rot: Array = _rotulos_visibles(v).filter(func(l): return (l as Label3D).text.begins_with("Moja ×1,5"))
	_ok("2 el rótulo ×1,5 sale del color de la debilidad", rot.size() == 1 and (rot[0] as Label3D).modulate.is_equal_approx(PrevisionReaccion3D.COLOR_DEBIL))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)
	g = _goblin(Vector2i(9, 31), "", "fuego")
	await avanzar(3)
	v = await _apuntar(Vector2i(11, 31), "fuego", ["flecha"])
	p = _pintada(v, "enemigo", g)
	_ok("3 fuego a un goblin que resiste el fuego: «Prende ×0,75»", not p.is_empty() and p["texto"] == "Prende ×0,75", str(p))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)
	# escudo de frente: «Bloquea», en gris, sin ×
	g = _goblin(Vector2i(9, 32), "", "", true, true)
	await avanzar(3)
	v = await _apuntar(Vector2i(11, 32), "fuego", ["flecha"])
	p = _pintada(v, "enemigo", g)
	_ok("4 fuego a un escudo de frente: «Bloquea»", not p.is_empty() and p["reaccion"] == "bloquea" and String(p["texto"]).begins_with("Bloquea"), str(p))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _caso_hunde() -> void:
	var g: Combate3D = _goblin(Vector2i(8, 31))
	await avanzar(3)
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(10, 31), "viento", ["flecha"])
	var prev: Array[Dictionary] = _prever_ahora()
	_coinciden("5 viento junto al agua", v, prev)
	var p: Dictionary = _pintada(v, "enemigo", g)
	_ok("5 viento a un goblin junto al agua honda: «¡Hunde!»", not p.is_empty() and p["reaccion"] == "hunde" and String(p["texto"]).begins_with("¡Hunde!"), str(p))
	var e: Dictionary = _entrada(prev, "enemigo", g)
	if not p.is_empty() and not e.is_empty():
		var dest: Vector3 = e["extra"]["destino"]
		_ok("5 el disco del destino está donde la previsión dice que acaba", (p["destino"] as Vector3).is_equal_approx(dest), "%s · %s" % [p["destino"], dest])
		_ok("5 el destino cae en el agua", Terreno3D.es_agua(Terreno3D.celda_de(dest)), str(Terreno3D.celda_de(dest)))
		# A4 (28/10): el disco del destino es ahora la silueta del enemigo (el fantasma), con la flecha (asta y punta) hasta ella.
		var cerca: bool = false
		for f in v._fantasmas:
			if f.visible and Vector2(f.global_position.x - dest.x, f.global_position.z - dest.z).length() < 0.05:
				cerca = true
				_ok("5 la silueta del destino es del color de «hunde»", ((f.mesh as CapsuleMesh).material as StandardMaterial3D).albedo_color.is_equal_approx(Color(PrevisionReaccion3D._color("hunde"), 0.32)))
		_ok("5 hay una silueta en el destino y una flecha hasta ella", cerca and _visibles(v._lineas) == 1 and _visibles(v._puntas) == 1)
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _caso_pieza() -> void:
	var br: Reactivo3D = _reactivo("brasero", Vector2i(9, 33))
	await avanzar(3)
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(11, 33), "fuego", ["flecha"])
	_coinciden("6 fuego al brasero", v, _prever_ahora())
	var p: Dictionary = _pintada(v, "pieza", br)
	_ok("6 el brasero lleva «Enciende»", not p.is_empty() and p["texto"] == "Enciende", str(v.pintado if v != null else []))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)
	var b := BloqueEmpujable3D.new()
	b.preparar(Vector2i(9, 33), "piedra", maqueta)
	maqueta.add_child(b)
	_creados.append(b)
	await avanzar(3)
	v = await _apuntar(Vector2i(11, 33), "viento", ["flecha"])
	_coinciden("7 viento al bloque", v, _prever_ahora())
	p = _pintada(v, "pieza", b)
	_ok("7 el bloque lleva «Mueve», con disco en su destino y una línea", not p.is_empty() and p["reaccion"] == "mueve" and _visibles(v._lineas) == 1 and _visibles(v._anillos) == 2, str(p))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _caso_suelo_hielo() -> void:
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(9, 33), "hielo", ["flecha"])
	var prev: Array[Dictionary] = _prever_ahora()
	_coinciden("8 hielo al agua", v, prev)
	var p: Dictionary = _pintada(v, "suelo")
	_ok("8 el agua lleva «Hiela» en (7,33)", not p.is_empty() and p["reaccion"] == "hiela" and (p["celdas"] as Array).has(Vector2i(7, 33)), str(v.pintado if v != null else []))
	var n_hiela: int = prev.filter(func(e): return String(e["que"]) == "suelo" and String(e["reaccion"]) == "hiela").size()
	var cuadros: int = _visibles(v._cuadros) if v != null else 0
	_ok("8 un cuadro por casilla que se hiela (%d) y un solo rótulo para todas" % n_hiela, cuadros >= n_hiela and _rotulos_visibles(v).filter(func(l): return l.text == "Hiela").size() == 1)
	if v != null:
		for q in v._cuadros:
			if q.visible:
				var c: Vector2i = Terreno3D.celda_de(q.global_position)
				_ok("8 el cuadro de %s queda pegado al suelo de su casilla" % str(c), absf(q.global_position.y - (Terreno3D.y_pies(c) + 0.09)) < 0.01)
				break
	await _soltar_sin_lanzar()


func _caso_nada() -> void:
	# fuego hacia el este, a tierra desnuda y sin nadie: nada que pintar
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(11, 35), "tierra", ["flecha"], Vector3(1, 0, 0))
	var prev: Array[Dictionary] = _prever_ahora()
	_coinciden("9 nada delante", v, prev)
	_ok("9 sin reacción no se pinta nada (ni rótulos ni anillos ni cuadros)", v != null and _rotulos_visibles(v).is_empty() and _visibles(v._anillos) == 0 and _visibles(v._cuadros) == 0 and _visibles(v._lineas) == 0,
		"previsto %d" % prev.size())
	await _soltar_sin_lanzar()


func _caso_sigue() -> void:
	# apuntar al goblin y luego apartar la puntería: la marca desaparece; volver: reaparece; el goblin se mueve: el rótulo lo sigue. Sin crear nodos nuevos.
	var g: Combate3D = _goblin(Vector2i(9, 31))
	await avanzar(3)
	var v: PrevisionReaccion3D = await _apuntar(Vector2i(11, 31), "fuego", ["flecha"])
	_ok("10 apuntando al goblin se pinta", not _pintada(v, "enemigo", g).is_empty())
	var hijos0: int = v.get_child_count()
	_mover_puntero(Vector3(0, 0, 1), 2.0)
	await avanzar(6)
	_ok("10 apuntando a otro lado se deja de pintar", _pintada(v, "enemigo", g).is_empty(), str(v.pintado))
	_mover_puntero(Vector3(-1, 0, 0), 2.0)
	await avanzar(6)
	_ok("10 volviendo a apuntarle, vuelve", not _pintada(v, "enemigo", g).is_empty())
	g.position += Vector3(0, 0, 0.6)
	await avanzar(6)
	var rot: Array = _rotulos_visibles(v).filter(func(l): return (l as Label3D).text.begins_with("Prende"))
	_ok("10 el rótulo sigue al goblin cuando se mueve", rot.size() == 1 and absf((rot[0] as Label3D).global_position.z - g.global_position.z) < 0.05,
		"%s · goblin %s" % [rot.map(func(l): return l.global_position), g.global_position])
	var t0: int = Time.get_ticks_usec()
	for _i in range(60):
		v.mostrar(PrevisionHechizo.prever_rapido(lanzador, lanzador._preparado, lanzador._origen_vivo, lanzador._direccion_actual()))
	var us: float = float(Time.get_ticks_usec() - t0) / 60.0
	_ok("10 pintar cada fotograma no crea nodos (%d → %d) y cuesta poco (%.0f µs con la previsión en caché)" % [hijos0, v.get_child_count(), us], v.get_child_count() == hijos0 and us < 500.0)
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _caso_rapido() -> void:
	# el lanzamiento rápido (A1, mantener 1) usa el mismo indicador: también pinta, y soltar lanza y se lleva la vista
	var g: Combate3D = _goblin(Vector2i(9, 31))
	await avanzar(3)
	colocar_jugador(Vector2i(11, 31))
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.pulsar_pagina(0)
	_ok("11 rápido: entra en el modo rápido", lanzador.modo_lanzar and lanzador._rapido)
	await avanzar(2)
	var v: PrevisionReaccion3D = lanzador._vista_reaccion
	_ok("11 rápido: hay vista de la reacción", v != null and is_instance_valid(v))
	# en headless el ratón no apunta: se le da el punto a mano, como haría `_actualizar_raton_rapido`, y se pinta un fotograma
	lanzador._punto_vivo = jugador.position + Vector3(-2.0 * Terreno3D.casilla, 0, 0)
	lanzador._calcular_origen_vivo()
	lanzador._pintar_marcadores()
	_ok("11 rápido: el goblin al que se apunta lleva «Prende»", not _pintada(v, "enemigo", g).is_empty(), str(v.pintado if v != null else []))
	lanzador._soltar()
	await avanzar(2)
	_ok("11 rápido: al soltar se lanza y la vista se va", not lanzador.modo_lanzar and lanzador._vista_reaccion == null)
	await avanzar_s(2.0)
	_limpiar()
	await avanzar(3)
