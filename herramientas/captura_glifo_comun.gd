extends "res://herramientas/prueba_trayectorias.gd"
## FOTOS DE LOS EFECTOS COMUNES DE GLIFO (24/11, sesión HECHIZOS; GlifoComunVfx) en el Bosque, lanzando de verdad con la cámara del juego. NECESITA VENTANA:
##   godot --resolution 1280x720 --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/captura_glifo_comun.gd -- <carpeta>


var _dir: String = ""


func _foto_png(nombre: String, dir: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var centro: Vector2 = lanzador.camara.unproject_position(jugador.position + dir.normalized() * 1.2 * Terreno3D.casilla + Vector3(0, 0.6, 0))
	var w: int = 720
	var h: int = 460
	var x0: int = clampi(int(centro.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(centro.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.resize(int(w * 1.3), int(h * 1.3), Image.INTERPOLATE_LANCZOS)
	rec.save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for hijo in n.get_children():
		if hijo is CanvasLayer:
			(hijo as CanvasLayer).visible = false
		_ocultar_ui(hijo)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	_dir = a[0] if a.size() > 0 and a[0] != "" else "res://docs/capturas/glifo_comun_2026-11-24"
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	maqueta.set("_tam_camara", 8.0)
	(maqueta.get("_camara") as Camera3D).size = 8.0
	await avanzar_s(1.0)
	var oeste := Vector3(-1, 0, 0)
	_ocultar_ui(root)
	await _tiro("1_fuego_abanico_repeticion", Vector2i(12, 34), "fuego", ["repeticion", "repeticion", "flecha"], oeste, 4)
	await _tiro("2_agua_rafaga_repeticion", Vector2i(12, 34), "agua", ["flecha", "repeticion", "repeticion"], oeste, 4)
	var c: Vector2i = _sitio_contra_pared(2)
	if c.x >= 0:
		await _tiro_rebote("3_tierra_rebote", c, "tierra", oeste)
	# El hijo: con el prototipo no hay libro rojo aquí; se llama al dibujo directamente donde caería.
	var gc: GlifoComunVfx = root.find_child("GlifoComunVfx", true, false) as GlifoComunVfx
	colocar_jugador(Vector2i(12, 34))
	await avanzar(3)
	if gc != null:
		gc.hijo_nace(maqueta, jugador.position + oeste * 1.6 * Terreno3D.casilla, "tierra")
		await avanzar(4)
		await _foto_png("4_nace_un_hijo_de_tierra_cerrando", oeste)
		await avanzar(6)
		await _foto_png("5_nace_un_hijo_de_tierra_runa", oeste)


func _tiro(nombre: String, c: Vector2i, el: String, glifos: Array, dir: Vector3, espera: int) -> void:
	var d: Dictionary = _preparar(c, el, glifos)
	lanzador.ultimo_disparo = {"dir": dir}
	_lanzar(d, dir)
	await avanzar(espera)
	await _foto_png(nombre, dir)
	await avanzar_s(1.2)
	_limpiar()


func _tiro_rebote(nombre: String, c: Vector2i, el: String, dir: Vector3) -> void:
	var d: Dictionary = _preparar(c, el, ["flecha", "rebote"])
	var antes: Array = lanzador.get_children().filter(func(n): return n is HechizoVivo)
	_lanzar(d, dir)
	var vivo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo and not antes.has(n):
			vivo = n
	var reboto: Array = [false]
	if vivo != null:
		vivo.rebotado.connect(func(_p, _n): reboto[0] = true)
	for _k in range(90):
		if reboto[0]:
			break
		await avanzar(1)
	await avanzar(3)
	await _foto_png(nombre, dir)
	await avanzar_s(1.2)
	_limpiar()
