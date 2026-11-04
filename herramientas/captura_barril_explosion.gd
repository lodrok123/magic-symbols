extends "res://herramientas/escenario_base.gd"
## BARRIL DE PÓLVORA · EXPLOSIÓN Y AVISO DEL ÁREA (4/11/2026): tiras de fotogramas con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_barril_explosion.gd -- [carpeta]   (por defecto res://docs/capturas/barril_explosion)
## Saca: explosion_cerca.png y explosion_juego.png (tira de la explosión en 6 instantes, cámara cerca y a la distancia de juego), aviso_cerca.png y aviso_juego.png (tira del aviso a 15 %, 50 % y 90 % de la mecha).
## El tiempo va a cámara lenta (`Engine.time_scale`) y cada foto se hace cuando el efecto marca el instante que se pide, sin depender de la velocidad del equipo.

var _dir: String = "res://docs/capturas/barril_explosion"
const T_EXPLOSION: Array = [0.04, 0.10, 0.18, 0.30, 0.48, 0.72]
const P_AVISO: Array = [0.15, 0.5, 0.9]


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	var claro: Vector2i = _buscar_claro()
	var centro: Vector3 = Terreno3D.centro_de(claro, Terreno3D.y_pies(claro))
	_despejar(maqueta, centro)
	var tam_juego: float = float(maqueta.get("_tam_camara"))
	print("cámara del juego: tamaño %.2f · basis.z %s" % [tam_juego, lanzador.camara.global_transform.basis.z])
	for modo in ["cerca", "juego"]:
		var tam: float = 3.6 if modo == "cerca" else tam_juego
		maqueta.set("_tam_camara", tam)
		(maqueta.get("_camara") as Camera3D).size = tam
		# --- tira de la explosión ---
		_poner_j(centro + Vector3(0.0, 0.0, 3.6))
		await avanzar_s(1.0)
		_ocultar_ui(root)
		var b := Barril3D.new()
		b.preparar(claro)
		maqueta.add_child(b)
		await avanzar(2)
		Engine.time_scale = 0.1
		b.encender()
		var seguro: int = 0
		while not b.explotado and seguro < 6000:
			seguro += 1
			await process_frame
		var fotos: Array = []
		var ex: ExplosionFuegoToy = b.explosion_vfx
		for t in T_EXPLOSION:
			seguro = 0
			while ex != null and is_instance_valid(ex) and ex.tiempo() < float(t) and seguro < 6000:
				seguro += 1
				await process_frame
			await RenderingServer.frame_post_draw
			fotos.append(_recorte(centro, modo))
			print("explosion %s t=%.2f s (frente a %.2f u)" % [modo, ex.tiempo() if is_instance_valid(ex) else -1.0, ex.radio_onda(ex.tiempo()) if is_instance_valid(ex) else -1.0])
		Engine.time_scale = 1.0
		_tira(fotos, _dir.path_join("explosion_%s.png" % modo))
		await avanzar_s(1.8)
		# --- tira del aviso ---
		_poner_j(centro + Vector3(0.0, 0.0, 3.6))
		var b2 := Barril3D.new()
		b2.preparar(claro)
		maqueta.add_child(b2)
		await avanzar(2)
		Engine.time_scale = 0.2
		b2.encender()
		var fotos2: Array = []
		for p in P_AVISO:
			seguro = 0
			while b2.aviso != null and b2.aviso.progreso < float(p) and seguro < 6000:
				seguro += 1
				await process_frame
			await RenderingServer.frame_post_draw
			fotos2.append(_recorte(centro, modo))
			print("aviso %s progreso %.2f latido %.1f Hz" % [modo, b2.aviso.progreso if b2.aviso != null else -1.0, b2.aviso.ritmo_hz() if b2.aviso != null else -1.0])
		Engine.time_scale = 1.0
		_tira(fotos2, _dir.path_join("aviso_%s.png" % modo))
		await avanzar_s(2.0)


## Esconde los árboles y demás piezas altas a menos de 30 u del centro y de más de 1,8 u de alto (no el suelo, ni la jugadora, ni los enemigos): la cámara del juego los pone delante del barril y no se vería la explosión.
func _despejar(n: Node, centro: Vector3) -> void:
	for h in n.get_children():
		if h is Pj3D or h is Jugador3D or h is Lanzador3D or h is Combate3D or h is Camera3D or h is Light3D:
			continue
		if h is MeshInstance3D and (h as MeshInstance3D).get_aabb().size.y * (h as Node3D).global_transform.basis.get_scale().y > 1.8 and (h as Node3D).global_position.distance_to(centro) < 30.0:
			(h as Node3D).visible = false
		if h is MultiMeshInstance3D and String(h.name).begins_with("lote_pino"):
			(h as Node3D).visible = false          # los pinos del decorado (MultiMesh) tapan la explosión desde la cámara del juego
		_despejar(h, centro)


func _poner_j(p: Vector3) -> void:
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p


func _buscar_claro() -> Vector2i:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(3, alto - 3):
		for x in range(3, ancho - 3):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var v := c + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	return mejor


## Recorte alrededor del barril (el centro del área, algo más arriba para que entre la bola); la cámara de cerca se reduce al 70 % para que quepa en la tira. Con el factor entre el tamaño de la
## ventana y el de la imagen leído en el momento (la ventana puede escalar).
func _recorte(centro: Vector3, modo: String) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro + Vector3(0.0, 0.5, 0.0)) * k
	var w: int = 1000 if modo == "cerca" else 700
	var h: int = 640 if modo == "cerca" else 480
	w = mini(w, img.get_width())
	h = mini(h, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2 - 20, 0, img.get_height() - h)
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
