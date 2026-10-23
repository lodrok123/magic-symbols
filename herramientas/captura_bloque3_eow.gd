extends "res://herramientas/escenario_base.gd"
## BLOQUE 3 de la revisión EoW (23/10): luz y cámara por zona, lava y niebla en los fosos. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_bloque3_eow.gd -- [carpeta] [escena]
##   (por defecto res://docs/capturas/bloque3_eow y el Bosque; con res://escenas/PruebaBosque01.tscn, que tiene cauces hondos, sale la niebla)
##   1 · zona: una zona de FUEGO con zoom alrededor del jugador; foto antes y 2 s después (la luz ya ha cambiado).
##   2 · lava: un charco de 3 × 2 al lado; foto, agua (por el impacto del mundo, como cualquier hechizo) y fotos de la roca caliente y fría.
##   3 · niebla: si el nivel tiene cauces hondos, el jugador junto al primero y foto.

var _dir: String = "res://docs/capturas/bloque3_eow"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(a[1] if a.size() > 1 else RUTA_BOSQUE)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(20)
	var c0: Vector2i = celda_jugador()

	# 1 · Zona de fuego con zoom
	var zonas: Zonas3D = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	_ok("1 la escena monta las zonas", zonas != null)
	if zonas != null:
		var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
		var antes: Color = sol.light_color
		var zoom_antes: float = float(maqueta.get("_tam_camara"))
		_foto("zona_antes")
		zonas.agregar(Rect2i(c0 - Vector2i(3, 3), Vector2i(7, 7)), "fuego", {"zoom": "4.5"})
		await avanzar_s(2.0)
		_ok("1 al entrar, la luz pasa a la de fuego", sol.light_color.is_equal_approx(LuzZona3D.ZONAS["fuego"]["sol_color"]), "%s → %s" % [antes, sol.light_color])
		_ok("1 y la cámara va al zoom de la zona", absf(float(maqueta.get("_tam_camara")) - 4.5) < 0.05, "%.2f → %.2f" % [zoom_antes, float(maqueta.get("_tam_camara"))])
		_foto("zona_fuego")
		(zonas.zonas[0] as Dictionary)["rect"] = Rect2i(-100, -100, 1, 1)     # la zona se va lejos: el jugador queda fuera de todas
		await avanzar_s(2.0)
		_ok("1 al salir vuelve la luz de la escena y el zoom del jugador", sol.light_color.is_equal_approx(LuzZona3D.ZONAS[String(maqueta.get("zona_luz"))]["sol_color"]) and absf(float(maqueta.get("_tam_camara")) - zoom_antes) < 0.05)

	# 2 · Lava al lado del jugador (casillas libres)
	var libres: Array = []
	for dy in range(-2, 3):
		for dx in range(1, 5):
			var q: Vector2i = c0 + Vector2i(dx, dy)
			if not Terreno3D.bloqueada(q) and not Terreno3D.es_agua(q) and libres.size() < 6:
				libres.append(q)
	var lv := Lava3D.new()
	lv.preparar(libres)
	(maqueta.get("_props") as Node).add_child(lv)
	await avanzar_s(0.5)
	_ok("2 la lava se monta y bloquea", lv.is_lit and libres.all(func(q): return Terreno3D.bloqueada(q)), "%d casillas" % libres.size())
	_foto("lava")
	var p: Vector3 = Terreno3D.centro_de(libres[0], Terreno3D.y_pies(libres[0]))
	Mundo3D.actual.impacto.emit(p, "agua", 0.5)
	await avanzar_s(0.6)
	_ok("2 el agua que cae en el suelo la enfría", not Terreno3D.bloqueada(libres[0]))
	_foto("lava_enfriada_caliente")
	await avanzar_s(4.0)
	_foto("lava_enfriada_fria")

	# 3 · Niebla de los fosos
	var niebla: NieblaFoso3D = maqueta.get_node_or_null("NieblaFoso3D") as NieblaFoso3D
	if niebla == null:
		_aviso("3 este nivel no tiene cauces hondos: sin niebla")
		return
	var c: Vector2i = niebla._celdas[niebla._celdas.size() / 2]
	colocar_jugador(c + Vector2i(0, 2))
	await avanzar_s(1.0)
	_ok("3 hay niebla en %d casillas de foso" % niebla._celdas.size(), niebla._celdas.size() > 0)
	_foto("niebla")


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
