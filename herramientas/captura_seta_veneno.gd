extends "res://herramientas/escenario_base.gd"
## SETA DE VENENO · CAPTURAS (18/11/2026; objetos/respiradero_3d.gd, mundo/nube_veneno_3d.gd, presentacion/vfx/toy/nube_veneno_vfx.gd): la sala F12 del laboratorio de fuego con la cámara del juego.
## NECESITA VENTANA (sin --headless):
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_seta_veneno.gd -- [carpeta]   (por defecto res://docs/capturas/2026-11-18_seta_veneno)
## Saca cuatro fotogramas de la seta de (28,19): 1_aviso.png (hinchada y brillando, un instante antes de exhalar) · 2_exhala_0_5s.png (0,5 s tras exhalar: la nube apenas ha empezado a extenderse) ·
## 3_nube_con_ondas.png (la nube ya completa, con los anillos viajando desde la seta) · 4_ardiendo.png (el fuego prendió el gas: llama sobre el sombrero y la nube consumiéndose); más tira.png con los cuatro.
## La otra seta (28,21) se deja lejos de su ciclo para que no tape la foto.

var _dir: String = "res://docs/capturas/2026-11-18_seta_veneno"
var _r1: Respiradero3D = null
var _r2: Respiradero3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://laboratorios/LabPuzlesFuego3D.tscn")
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	var pz: Puzle3D = maqueta.get_node("Reglas").get("_puzle_nodo") as Puzle3D
	_r1 = pz.nodo("f12_r1") as Respiradero3D
	_r2 = pz.nodo("f12_r2") as Respiradero3D
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	(jugador as Jugador3D).vida = 100000.0
	for n in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(n):
			(n as NubeVeneno3D).retirar()
	var tam_juego: float = float(maqueta.get("_tam_camara"))
	print("cámara del juego: tamaño %.2f" % tam_juego)
	maqueta.set("_tam_camara", tam_juego * 1.0)
	# La cámara del juego sigue a la jugadora: se la pone en la casilla de la seta y se la esconde (con el cartel del laboratorio) para ver la seta y su nube sin nada encima. Los pinos de los muros se dejan: es lo que se ve en el juego.
	_poner_j(Vector2i(28, 19))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.visible = false
	(jugador as Node3D).visible = false
	for l in root.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	_r1._t = 0.0
	_r2._t = 0.0
	_r1.desfase_s = 0.0
	await avanzar_s(1.0)
	var fotos: Array = []
	var centro: Vector3 = Terreno3D.centro_de(Vector2i(28, 19), Terreno3D.y_pies(Vector2i(28, 19))) + Vector3(0.0, 0.6, 0.0)
	# 1 · AVISO: la seta hinchada, justo antes de exhalar
	_r1._t = _r1.cada - 1.0
	var seguro: int = 0
	while seguro < 4000 and not (_r1.en_aviso and _r1._t >= _r1.cada - 0.18):
		seguro += 1
		await process_frame
	await RenderingServer.frame_post_draw
	fotos.append(_foto("1_aviso", centro))
	# 2 · 0,5 s tras exhalar
	seguro = 0
	while seguro < 4000 and not (is_instance_valid(_r1.ultima) and _r1.ultima._edad >= 0.5):
		seguro += 1
		await process_frame
	await RenderingServer.frame_post_draw
	fotos.append(_foto("2_exhala_0_5s", centro))
	# 3 · nube completa (ya creció) con las ondas en marcha
	seguro = 0
	while seguro < 4000 and not (is_instance_valid(_r1.ultima) and _r1.ultima._edad >= 2.6):
		seguro += 1
		await process_frame
	await RenderingServer.frame_post_draw
	fotos.append(_foto("3_nube_con_ondas", centro))
	# 4 · ardiendo: el fuego prende el gas
	_r1.prender()
	var t0: float = reloj.t
	while reloj.t - t0 < 0.3:
		await process_frame
	await RenderingServer.frame_post_draw
	fotos.append(_foto("4_ardiendo", centro))
	_tira(fotos)
	quit()


func _poner_j(c: Vector2i) -> void:
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p


func _foto(nombre: String, centro: Vector3) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro) * k
	var w: int = mini(960, img.get_width())
	var h: int = mini(640, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.save_png(ProjectSettings.globalize_path(_dir.path_join(nombre + ".png")))
	print("foto %s · edad de la nube %.2f · hinchada %.2f" % [nombre, _r1.ultima._edad if is_instance_valid(_r1.ultima) else -1.0, _r1.hinchazon()])
	return rec


func _tira(fotos: Array) -> void:
	var f0: Image = fotos[0]
	var w: int = f0.get_width()
	var h: int = f0.get_height()
	var tira: Image = Image.create(w * 2, h * 2, false, f0.get_format())
	for i in fotos.size():
		tira.blit_rect(fotos[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	tira.save_png(ProjectSettings.globalize_path(_dir.path_join("tira.png")))


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
