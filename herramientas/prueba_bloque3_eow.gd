extends SceneTree
## Bloque 3 de la revisión EoW (23/10), sin ventana y con el mundo falso de `prueba_puzle.gd`:
##   1 · Zonas3D: las líneas `; zona` (buenas y malas), qué zona manda en cada casilla y la mezcla de luces de LuzZona3D.
##   2 · Lava3D: bloquea, se enfría con agua (la casilla y sus vecinas), se apaga entera, y con `vuelve` la roca vuelve a ser lava.
##   3 · Desde un mapa: `; pieza l lava x y celdas=…`, su señal `apagada` abriendo una puerta y la acción `enfriar`.
##   godot --headless --path . --script res://herramientas/prueba_bloque3_eow.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_zonas()
	var m := MundoFalso.new()
	m._props = Node3D.new()
	m.add_child(m._props)
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(8):
		for x in range(8):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	Lanzador3D.montar_agua_sim()
	await _lava(m)
	await _lava_mapa(m)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _zonas() -> void:
	var z := Zonas3D.new()
	z.leer_texto("\n".join([
		"; comentario cualquiera",
		"; zona 1,1..4,3 fuego zoom=4.5 tilt=no",
		"; zona 3,2..6,6 agua",
		"; zona 1,1..2,2 lava_inventada",
		"; zona 9,9 hielo",
	]))
	_ok("1 lee las zonas buenas (2) y avisa de las malas (2)", z.zonas.size() == 2 and z.avisos.size() == 2, str(z.avisos))
	_ok("1 en la casilla de una sola zona manda esa", String(z.zona_en(Vector2i(1, 1)).get("luz", "")) == "fuego" and float(z.zona_en(Vector2i(1, 1))["zoom"]) == 4.5 and int(z.zona_en(Vector2i(1, 1))["tilt"]) == 0)
	_ok("1 donde se pisan manda la última declarada", String(z.zona_en(Vector2i(3, 2)).get("luz", "")) == "agua")
	_ok("1 fuera de todas no hay zona", z.zona_en(Vector2i(7, 7)).is_empty())
	var a: Dictionary = LuzZona3D.valores("bosque")
	var b: Dictionary = LuzZona3D.valores("fuego")
	var medio: Dictionary = LuzZona3D.mezclar(a, b, 0.5)
	_ok("1 la mezcla a mitad está entre las dos luces", is_equal_approx(float(medio["sol_energia"]), (float(a["sol_energia"]) + float(b["sol_energia"])) * 0.5)
		and (medio["sol_color"] as Color).is_equal_approx((a["sol_color"] as Color).lerp(b["sol_color"], 0.5)))
	_ok("1 la mezcla en 1 es la luz de destino", (LuzZona3D.mezclar(a, b, 1.0)["ambiente_abajo"] as Color).is_equal_approx(b["ambiente_abajo"]))
	z.free()


func _lava(m: MundoFalso) -> void:
	var lv := Lava3D.new()
	var celdas: Array = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5)]
	lv.preparar(celdas)
	m._props.add_child(lv)
	await process_frame
	var enfriadas: Array = []
	var apagadas: Array = [0]
	lv.enfriada.connect(func(c: Vector2i) -> void: enfriadas.append(c))
	lv.apagada.connect(func() -> void: apagadas[0] += 1)
	_ok("2 bloquea todas sus casillas", celdas.all(func(c): return Terreno3D.bloqueada(c)))
	var agua := RuneData.new()
	agua.tags = ["agua"]
	var fuego := RuneData.new()
	fuego.tags = ["fuego", "calor"]
	_ok("2 el agua la enfría y el fuego no", lv.spell_reacts(agua) and not lv.spell_reacts(fuego))
	lv.enfriar_en(Vector2i(1, 4))
	_ok("2 el agua enfría la casilla y sus vecinas de lava (3) y las libera", enfriadas.size() == 3 and not Terreno3D.bloqueada(Vector2i(1, 4))
		and not Terreno3D.bloqueada(Vector2i(2, 4)) and not Terreno3D.bloqueada(Vector2i(1, 5)) and Terreno3D.bloqueada(Vector2i(3, 4)), str(enfriadas))
	_ok("2 todavía queda lava", lv.is_lit and apagadas[0] == 0)
	lv.enfriar_en(Vector2i(3, 4))
	lv.enfriar_en(Vector2i(2, 5))
	_ok("2 al enfriar lo que quedaba se apaga una vez", not lv.is_lit and apagadas[0] == 1 and enfriadas.size() == 5)
	# Con `vuelve`: la roca vuelve a ser lava
	var lv2 := Lava3D.new()
	lv2.preparar([Vector2i(5, 5)], 0.4)
	m._props.add_child(lv2)
	await process_frame
	lv2.enfriar_en(Vector2i(5, 5))
	_ok("2 con vuelve: enfriada, se pisa", not Terreno3D.bloqueada(Vector2i(5, 5)) and not lv2.is_lit)
	var t0: int = Time.get_ticks_msec()
	while not lv2.is_lit and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	_ok("2 con vuelve: a los `vuelve` s es lava otra vez y bloquea", lv2.is_lit and Terreno3D.bloqueada(Vector2i(5, 5)))
	lv.queue_free()
	lv2.queue_free()
	await process_frame


func _lava_mapa(m: MundoFalso) -> void:
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "", "\n".join([
		"; pieza l lava 1 4 celdas=1,4..2,4",
		"; pieza p puerta 5 5",
		"; pieza b pulsador 4 4 modo=magia",
		"; puzle r1 cuando=l.apagada hace=p.abrir",
		"; puzle r2 cuando=b.pulsado si=l.activa hace=l.enfriar",
	]))
	await process_frame
	var l: Lava3D = z.nodo("l") as Lava3D
	_ok("3 la pieza «lava» se monta sin avisos y con sus dos casillas", l != null and l.celdas.size() == 2 and z.avisos.is_empty(), str(z.avisos))
	(z.nodo("b") as Pulsador3D).pulsar()
	await process_frame
	_ok("3 la acción enfriar (con si=l.activa) la apaga y su señal abre la puerta", l != null and not l.is_lit and bool(z.nodo("p").get("abierta")))
	z.queue_free()
