extends "res://herramientas/escenario_base.gd"
## LÍNEA DE MIRA · CAPTURAS (21/11/2026; enemigos/aviso_ataque_3d.gd `linea`, objetos/trampa_flechas_3d.gd, objetos/estela_flecha_3d.gd): la cámara del juego.
## NECESITA VENTANA (sin --headless):
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_linea_mira.gd -- [carpeta]   (por defecto res://docs/capturas/2026-11-21_linea_mira)
## Saca: 1_arquero_apuntando.png (línea tenue siguiendo a la jugadora) · 2_arquero_fijado.png (la línea fijada: ancha, viva, con el círculo del destino) · 3_trampa_aviso_fijada.png (mascarón de flechas, línea
## fijada hasta el muro) · 4_trampa_flecha_estela.png (la flecha normal en vuelo con su estela) · 5_trampa_fuego_aviso.png (la de fuego, rojo-naranja); más tira.png con todas.

var _dir: String = "res://docs/capturas/2026-11-21_linea_mira"
var _fotos: Array = []
var _creados: Array = []


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	Repertoire.activate_all()
	_ocultar_ui(root)
	await avanzar(20)
	await _arquero()
	for n in _creados:
		if is_instance_valid(n):
			n.queue_free()
	maqueta.queue_free()
	await avanzar(5)
	maqueta = null
	lanzador = null
	jugador = null
	await cargar("res://laboratorios/LabPuzlesFuego3D.tscn")
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await _trampas()
	_tira()
	quit()


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _arquero() -> void:
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(Vector2i(9, 33))
	j.vida = 100000.0
	var p: Vector3 = _pos(Vector2i(12, 33))
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_archer_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, j, lanzador)
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	var ln: AvisoAtaque3D = null
	var seguro: int = 0
	while seguro < 2000 and ln == null:
		await process_frame
		seguro += 1
		for n in get_nodes_in_group(AvisoAtaque3D.GRUPO_LINEAS):
			if (n as AvisoAtaque3D).dueno == g:
				ln = n
	if ln == null:
		print("sin línea")
		return
	var t0: float = reloj.t
	while reloj.t - t0 < 0.12:
		await process_frame
	await RenderingServer.frame_post_draw
	_foto("1_arquero_apuntando", (ln.centro + ln.fin) * 0.5)
	seguro = 0
	while seguro < 2000 and is_instance_valid(ln) and not (ln.fijada and ln.t_fijada >= 0.15):
		await process_frame
		seguro += 1
	await RenderingServer.frame_post_draw
	if is_instance_valid(ln):
		_foto("2_arquero_fijado", (ln.centro + ln.fin) * 0.5)


func _trampas() -> void:
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var props: Node = maqueta.get("_props") as Node
	var pila: Array = [maqueta]                       # las demás salas del laboratorio (tótems, setas, dragones) funcionan solas: se callan
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		pila.append_array(n.get_children())
		if n is TrampaPared3D or n is Respiradero3D:
			n.call("apagar", 0.0)
	for v in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(v):
			(v as NubeVeneno3D).retirar()
	colocar_jugador(Vector2i(21, 20))
	(jugador.get("pj") as Node3D).visible = true
	var f := TrampaFlechas3D.new()
	f.preparar(Vector2i(16, 19), "e", "ninguno", 8, maqueta)
	f.preparar_ciclo(2.0, 0.0, 3.5)
	props.add_child(f)
	var ln: AvisoAtaque3D = null
	var seguro: int = 0
	while seguro < 4000 and not (f.linea != null and f.linea.fijada and f.linea.t_fijada >= 0.2):
		await process_frame
		seguro += 1
	ln = f.linea
	await RenderingServer.frame_post_draw
	if ln != null:
		_foto("3_trampa_aviso_fijada", (ln.centro + ln.fin) * 0.5)
	# la flecha en vuelo, a unas 3 casillas de la ranura
	var fl: FlechaTrampa3D = null
	seguro = 0
	while seguro < 4000 and not (fl != null and is_instance_valid(fl) and fl.recorrido >= 6.0):
		await process_frame
		seguro += 1
		if fl == null or not is_instance_valid(fl):
			for ch in props.get_children():
				if ch is FlechaTrampa3D:
					fl = ch
	await RenderingServer.frame_post_draw
	if fl != null and is_instance_valid(fl):
		_foto("4_trampa_flecha_estela", fl.global_position)
	f.queue_free()
	var ff := TrampaFlechas3D.new()
	ff.preparar(Vector2i(16, 21), "e", "fuego", 8, maqueta)
	ff.preparar_ciclo(2.0, 0.0, 3.5)
	props.add_child(ff)
	seguro = 0
	while seguro < 4000 and not (ff.linea != null and ff.linea.fijada and ff.linea.t_fijada >= 0.2):
		await process_frame
		seguro += 1
	await RenderingServer.frame_post_draw
	if ff.linea != null:
		_foto("5_trampa_fuego_aviso", (ff.linea.centro + ff.linea.fin) * 0.5)


func _foto(nombre: String, centro: Vector3) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro) * k
	var w: int = mini(1280, img.get_width())
	var h: int = mini(720, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.save_png(ProjectSettings.globalize_path(_dir.path_join(nombre + ".png")))
	_fotos.append(rec)
	print("foto %s" % nombre)


func _tira() -> void:
	if _fotos.is_empty():
		return
	var f0: Image = _fotos[0]
	var w: int = f0.get_width()
	var h: int = f0.get_height()
	var filas: int = int(ceil(_fotos.size() / 2.0))
	var tira: Image = Image.create(w * 2, h * filas, false, f0.get_format())
	for i in _fotos.size():
		tira.blit_rect(_fotos[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	tira.save_png(ProjectSettings.globalize_path(_dir.path_join("tira.png")))


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
