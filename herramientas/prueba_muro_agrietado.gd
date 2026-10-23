extends SceneTree
## MuroAgrietado3D (bloque 2 de la revisión EoW, 23/10), sin escena ni ventana y con el mundo falso de `prueba_puzle.gd`:
##   · bloquea su casilla y solo «reacciona» a la tierra (el resto de hechizos no le hace nada);
##   · con `golpes` impactos de tierra se rompe: libera la casilla, deja de recibir golpes y emite `roto` UNA vez;
##   · una explosión de barril al alcance lo rompe de una vez;
##   · desde un mapa: `; pieza m muro x y golpes=n`, su señal `roto`, la condición `muro.roto` y la acción `romper`.
##   godot --headless --path . --script res://herramientas/prueba_muro_agrietado.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
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
	var tierra := RuneData.new()
	tierra.tags = ["tierra"]
	var fuego := RuneData.new()
	fuego.tags = ["fuego", "calor"]

	# 1 · Golpes de tierra
	var mu := MuroAgrietado3D.new()
	mu.preparar(Vector2i(2, 4), 2)
	m._props.add_child(mu)
	await process_frame
	var veces: Array = [0]
	mu.roto.connect(func() -> void: veces[0] += 1)
	_ok("1 bloquea su casilla", Terreno3D.bloqueada(Vector2i(2, 4)))
	_ok("1 solo reacciona a la tierra", mu.spell_reacts(tierra) and not mu.spell_reacts(fuego))
	mu.on_spell_hit(fuego)
	_ok("1 el fuego no le hace nada", mu.recibidos == 0 and not mu.roto_ya)
	mu.on_spell_hit(tierra)
	_ok("1 un golpe de tierra lo agrieta pero no lo rompe", mu.recibidos == 1 and not mu.roto_ya and mu.grietas > MuroAgrietado3D.GRIETAS_INICIO)
	mu.on_spell_hit(tierra)
	_ok("1 el segundo golpe lo rompe y libera la casilla", mu.roto_ya and not Terreno3D.bloqueada(Vector2i(2, 4)) and mu.collision_layer == 0)
	mu.on_spell_hit(tierra)
	mu.romper()
	_ok("1 `roto` se emite una sola vez", veces[0] == 1, str(veces[0]))

	# 2 · Explosión
	var mu2 := MuroAgrietado3D.new()
	mu2.preparar(Vector2i(4, 4), 3)
	m._props.add_child(mu2)
	var ba := Barril3D.new()
	ba.preparar(Vector2i(5, 4))
	m._props.add_child(ba)
	await process_frame
	_ok("2 está en el grupo de lo que recibe explosiones", mu2.is_in_group("explosionable"))
	ba.encender()
	var t0: int = Time.get_ticks_msec()
	while not mu2.roto_ya and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	_ok("2 la explosión del barril de al lado lo rompe de una vez", mu2.roto_ya and ba.explotado)

	# 3 · Desde un mapa
	var texto: String = "\n".join([
		"; pieza mm muro 2 5 golpes=1",
		"; pieza boton pulsador 4 5 modo=magia",
		"; pieza puerta puerta 5 5",
		"; puzle r1 cuando=mm.roto hace=puerta.abrir",
		"; puzle r2 cuando=boton.pulsado si=mm.entero hace=mm.romper",
	])
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "", texto)
	await process_frame
	var mm: MuroAgrietado3D = z.nodo("mm") as MuroAgrietado3D
	var puerta: Node = z.nodo("puerta")
	_ok("3 la pieza «muro» se monta sin avisos", mm != null and mm.golpes == 1 and z.avisos.is_empty(), str(z.avisos))
	(z.nodo("boton") as Pulsador3D).pulsar()
	await process_frame
	_ok("3 la acción romper (con si=mm.entero) lo rompe y su señal abre la puerta", mm != null and mm.roto_ya and bool(puerta.get("abierta")))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
