extends "res://herramientas/escenario_base.gd"
## TRAMPAS DE PARED · CAPTURAS (5/11/2026; docs/TRAMPAS_PARED_2026-11-05.md): el dragón en reposo, en aviso y escupiendo, y la flecha de fuego en vuelo, con la cámara del juego (fija al norte). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_trampas_pared.gd -- [carpeta]   (por defecto res://docs/capturas/trampas_pared)
## Saca: dragon_ciclo_cerca.png y dragon_ciclo_juego.png (reposo · aviso · fuego al empezar · fuego a tope · fuego al final), dragon_pasillo.png (F7 entera con los dos dragones y la jugadora),
## mascaron_flecha_secuencia.png (F9 de canto: ranura apagada · avisando · flecha recién salida · en vuelo · prendiendo el seto) y mascaron_frente_cerca.png / _juego.png (los dos mascarones de frente: reposo · avisando · fogonazo · flecha en vuelo).
## El tiempo va a cámara lenta (`Engine.time_scale`) y cada foto espera al instante que se pide.

var _dir: String = "res://docs/capturas/trampas_pared"
var _pz: Puzle3D = null


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
	_pz = (maqueta.get_node("Reglas").get("_puzle_nodo")) as Puzle3D
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	(jugador as Jugador3D).vida = 100000.0
	var tam_juego: float = float(maqueta.get("_tam_camara"))
	print("cámara del juego: tamaño %.2f" % tam_juego)
	await _dragon(tam_juego)
	await _flecha(tam_juego)
	await _frente(tam_juego)


func _cam(tam: float) -> void:
	maqueta.set("_tam_camara", tam)
	(maqueta.get("_camara") as Camera3D).size = tam


func _poner_j(c: Vector2i) -> void:
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p


# ---------------------------------------------------------------------------------------------------------------------

func _dragon(tam_juego: float) -> void:
	var a: TrampaDragon3D = _pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	# El pasillo con los dos dragones tal como lo ve el juego (con los árboles de los muros): una foto cuando A escupe.
	_cam(tam_juego * 1.15)
	_poner_j(Vector2i(28, 11))
	await avanzar_s(0.8)
	_ocultar_ui(root)
	await _foto_pasillo(a, "dragon_pasillo.png")
	_despejar(maqueta)
	_poner_j(Vector2i(28, 10))
	await avanzar_s(0.5)
	await _foto_pasillo(a, "dragon_pasillo_limpio.png")
	b.apagar(0.0)                                   # para el ciclo de A solo: B se apaga (se vuelve a encender al final)
	for modo in ["cerca", "juego"]:
		_cam(4.2 if modo == "cerca" else tam_juego)
		_poner_j(Vector2i(27, 10))
		a.encender()
		await avanzar_s(3.5)                             # que acabe lo que quedara del chorro anterior
		_ocultar_ui(root)
		Engine.time_scale = 0.25
		var fotos: Array = []
		var centro: Vector3 = a.global_position + Vector3(0.0, 1.6, 1.0)
		# 1 reposo (a ~0,6 s del ciclo), 2 aviso (a ~0,35 s de aviso), 3 fuego al empezar (0,25 s), 4 fuego a tope (1,0 s), 5 fuego al final (1,45 s)
		var pasos: Array = [["reposo", TrampaDragon3D.Fase.REPOSO, 0.6], ["aviso", TrampaDragon3D.Fase.AVISO, 0.35], ["fuego al empezar", TrampaDragon3D.Fase.FUEGO, 0.25],
				["fuego a tope", TrampaDragon3D.Fase.FUEGO, 1.0], ["fuego al final", TrampaDragon3D.Fase.FUEGO, 1.45]]
		for paso in pasos:
			var seguro: int = 0
			while seguro < 9000:
				seguro += 1
				await process_frame
				var t_fase: float = _t_en_fase(a)
				if a.fase == int(paso[1]) and t_fase >= float(paso[2]):
					break
			await RenderingServer.frame_post_draw
			fotos.append(_recorte(centro, modo))
			print("dragón %s · %s · fase %d t_ciclo %.2f" % [modo, paso[0], a.fase, a._t_ciclo])
		Engine.time_scale = 1.0
		_tira(fotos, _dir.path_join("dragon_ciclo_%s.png" % modo))
		await avanzar_s(2.0)
	a.apagar(0.0)
	_cam(tam_juego)
	await avanzar_s(1.0)


## La foto del pasillo entero (los dos ciclando, la jugadora delante), a cámara lenta, cuando A lleva 0,6 s escupiendo.
func _foto_pasillo(a: TrampaDragon3D, nombre: String) -> void:
	var b: TrampaDragon3D = _pz.nodo("t_drg_b") as TrampaDragon3D
	b.encender()
	a.encender()
	Engine.time_scale = 0.3
	var seguro: int = 0
	while seguro < 6000 and not (a.fase == TrampaDragon3D.Fase.FUEGO and _t_en_fase(a) > 0.6):
		seguro += 1
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(1000, int(1000.0 * float(img.get_height()) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(_dir.path_join(nombre)))
	print("foto %s · A fase %d, B fase %d" % [nombre, a.fase, b.fase])
	Engine.time_scale = 1.0


## Esconde los árboles (los muros del laboratorio son pinos) para ver las trampas limpias: los MultiMesh de pinos y las piezas altas del decorado, menos las trampas.
func _despejar(n: Node) -> void:
	for h in n.get_children():
		if h is TrampaPared3D or h is FlechaTrampa3D or h is Pj3D or h is Jugador3D or h is Lanzador3D or h is Combate3D or h is Camera3D or h is Light3D:
			continue
		if h is MeshInstance3D and (h as MeshInstance3D).get_aabb().size.y * (h as Node3D).global_transform.basis.get_scale().y > 1.8:
			(h as Node3D).visible = false
		if h is MultiMeshInstance3D and String(h.name).begins_with("lote_pino"):
			(h as Node3D).visible = false
		_despejar(h)


## Segundos que lleva el dragón en su fase actual (desde el inicio de la fase dentro del ciclo).
func _t_en_fase(d: TrampaDragon3D) -> float:
	var r: float = d.apagada_s
	var aviso: float = minf(TrampaDragon3D.AVISO_S, r)
	match d.fase:
		TrampaDragon3D.Fase.REPOSO:
			return d._t_ciclo
		TrampaDragon3D.Fase.AVISO:
			return d._t_ciclo - (r - aviso)
		TrampaDragon3D.Fase.FUEGO:
			return d._t_ciclo - r
	return 0.0


# ---------------------------------------------------------------------------------------------------------------------

func _flecha(tam_juego: float) -> void:
	var f: TrampaFlechas3D = _pz.nodo("t_fl_fuego") as TrampaFlechas3D
	var s1: Node = _pz.nodo("t_fl_s1")
	# La de fuego: la jugadora al lado de la fila (11,21), las fotos con el seto al fondo.
	for modo in ["ancho"]:
		_cam(7.4)
		_poner_j(Vector2i(10, 21))
		f.encender()
		f._t = 0.0
		await avanzar_s(0.2)
		_ocultar_ui(root)
		Engine.time_scale = 0.2
		var centro: Vector3 = Vector3(25.0, Terreno3D.y_pies(Vector2i(11, 22)) + 0.6, 22.5 * Terreno3D.casilla)
		var fotos: Array = []
		# 1 ranura apagada (justo tras un disparo), 2 ranura avisando (a 0,3 s del disparo), 3 flecha recién salida (+0,15 s), 4 en vuelo (+0,7 s), 5 al prender el seto
		var seguro: int = 0
		while seguro < 9000 and not (f.disparos == 0 and f._t > 0.5 and f._t < 1.0):
			seguro += 1
			await process_frame
		await RenderingServer.frame_post_draw
		fotos.append(_recorte(centro, modo))
		seguro = 0
		while seguro < 9000 and not (f.en_aviso and f._t >= f.cada_s - 0.1):
			seguro += 1
			await process_frame
		await RenderingServer.frame_post_draw
		fotos.append(_recorte(centro, modo))
		var d0: int = f.disparos
		seguro = 0
		while seguro < 9000 and f.disparos == d0:
			seguro += 1
			await process_frame
		var t_disparo: float = reloj.t
		for k in [0.15, 0.7]:
			seguro = 0
			while seguro < 9000 and (reloj.t - t_disparo) < float(k) * 0.2:
				seguro += 1
				await process_frame
			await RenderingServer.frame_post_draw
			fotos.append(_recorte(centro, modo))
		seguro = 0
		while seguro < 9000 and is_instance_valid(s1) and not bool(s1.get("is_lit")):
			seguro += 1
			await process_frame
		await avanzar(8)
		await RenderingServer.frame_post_draw
		fotos.append(_recorte(centro, modo))
		Engine.time_scale = 1.0
		_tira(fotos, _dir.path_join("mascaron_flecha_secuencia.png"))
		f.apagar(0.0)
		await avanzar_s(0.5)


# ---------------------------------------------------------------------------------------------------------------------

## Los dos mascarones de FRENTE (dos trampas de prueba en el muro norte de la sala (2,2), mirando al sur: la cámara del juego ve su cara): el de fuego y el de flecha normal.
## Fotos: ranura en reposo · ranura avisando · fogonazo al salir · flecha en vuelo (dos instantes).
func _frente(tam_juego: float) -> void:
	var fuego := TrampaFlechas3D.new()
	fuego.name = "FrenteFuego"
	fuego.preparar(Vector2i(23, 16), "s", "fuego", 6, maqueta)
	fuego.preparar_ciclo(3.0, 0.0, 3.5)
	(maqueta.get("_props") as Node).add_child(fuego)
	var normal := TrampaFlechas3D.new()
	normal.name = "FrenteNormal"
	normal.preparar(Vector2i(21, 16), "s", "ninguno", 6, maqueta)
	normal.preparar_ciclo(3.0, 0.0, 3.5)
	(maqueta.get("_props") as Node).add_child(normal)
	for modo in ["cerca", "juego"]:
		_cam(4.2 if modo == "cerca" else tam_juego)
		_poner_j(Vector2i(22, 17))
		await avanzar_s(0.6)
		_ocultar_ui(root)
		var centro: Vector3 = fuego.global_position.lerp(normal.global_position, 0.5) + Vector3(0.0, 1.2, 1.2)
		Engine.time_scale = 0.2
		var fotos: Array = []
		var seguro: int = 0
		# 1 reposo (justo tras un disparo)
		while seguro < 9000 and not (fuego.disparos >= 1 and fuego._t > 0.6 and fuego._t < 1.2):
			seguro += 1
			await process_frame
		await RenderingServer.frame_post_draw
		fotos.append(_recorte(centro, modo))
		# 2 avisando
		seguro = 0
		while seguro < 9000 and not (fuego.en_aviso and fuego._t >= fuego.cada_s - 0.12):
			seguro += 1
			await process_frame
		await RenderingServer.frame_post_draw
		fotos.append(_recorte(centro, modo))
		# 3 fogonazo, 4 y 5 en vuelo
		var d0: int = fuego.disparos
		seguro = 0
		while seguro < 9000 and fuego.disparos == d0:
			seguro += 1
			await process_frame
		var t0: float = reloj.t
		for k in [0.04, 0.5, 0.9]:
			seguro = 0
			while seguro < 9000 and (reloj.t - t0) < float(k) * 0.2:
				seguro += 1
				await process_frame
			await RenderingServer.frame_post_draw
			fotos.append(_recorte(centro, modo))
		Engine.time_scale = 1.0
		_tira(fotos, _dir.path_join("mascaron_frente_%s.png" % modo))
		await avanzar_s(1.5)
	fuego.queue_free()
	normal.queue_free()
# ---------------------------------------------------------------------------------------------------------------------

## Recorte alrededor de un punto del mundo: 700 × 520 px (la cámara del juego) o 900 × 640 de cerca.
func _recorte(centro: Vector3, modo: String) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	if modo == "ancho":
		img.resize(800, int(800.0 * float(img.get_height()) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)          # toda la pantalla
		return img
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro) * k
	var w: int = mini(1150 if modo == "cerca" else 960, img.get_width())
	var h: int = mini(640 if modo == "cerca" else 540, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	if modo == "cerca":
		rec.resize(int(w * 0.7), int(h * 0.7), Image.INTERPOLATE_LANCZOS)
	return rec


func _tira(fotos: Array, ruta: String) -> void:
	if fotos.is_empty():
		return
	var f0: Image = fotos[0]
	var w: int = f0.get_width()
	var h: int = f0.get_height()
	var cols: int = 3
	var filas: int = int(ceil(float(fotos.size()) / float(cols)))
	var tira: Image = Image.create(w * mini(cols, fotos.size()), h * filas, false, f0.get_format())
	for i in fotos.size():
		tira.blit_rect(fotos[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	tira.save_png(ProjectSettings.globalize_path(ruta))
	print("tira " + ruta)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
