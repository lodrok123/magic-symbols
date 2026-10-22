extends SceneTree
## CAPTURAS del EMPUJADO + LEVANTARSE de los goblins (22/10). NECESITA VENTANA (no sirve --headless).
##   godot --path . --fixed-fps 30 --script res://herramientas/captura_empujado_goblin.gd -- <carpeta> [tam_juego]
## Para cada goblin (guerrero con escudo y arquero) y cada cámara (la del juego y una lateral) guarda una hoja de contacto de 6 fotogramas
## (<id>_<camara>.png) con el empujado y el levantarse, y los PNG sueltos (<id>_<camara>_<n>.png).
const S: float = 2.3
const LADO: int = 14
const IDS: Array = ["goblin_warrior_chibi", "goblin_archer_chibi"]
## Segundos desde el empujón de cada fotograma: subida, cima, bajada, ya tumbado, levantándose, de pie.
const TIEMPOS: Array = [0.2, 0.5, 0.9, 1.5, 2.1, 2.9]
const PASO_X: float = 4.0
const RECORTE: Vector2i = Vector2i(380, 380)

var _mundo: Node3D = null
var _carpeta: String = "docs/capturas/empujado_goblin"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_carpeta = a[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	var esc: PackedScene = load("res://escenas/PruebaBosque01.tscn")
	_mundo = esc.instantiate()
	root.add_child(_mundo)
	for _i in 150:
		await process_frame
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var jug: Pj3D = _mundo.get("_jugador") as Pj3D
	var tam_juego: float = float(a[1]) if a.size() > 1 else 2.6
	for id in IDS:
		for cam in ["juego", "lateral"]:
			await _secuencia(id, cam, jug, tam_juego)
	quit()



func _secuencia(id: String, cam: String, jug: Pj3D, tam_juego: float) -> void:
	var lateral: bool = cam == "lateral"
	# Cámara del juego: junto a la jugadora, en el bosque, con un Combate3D de verdad (empuje, escudo...). Lateral: el mismo modelo SOLO, en un rincón vacío sobre un
	# suelo plano (el bosque lo tapa con las copas), reproduciendo los clips en la misma cadencia que el juego (empujado 1,5 s → levantarse → idle).
	var p: Vector3 = jug.position + Vector3(PASO_X, 0.0, 0.0)
	var suelo_plano: MeshInstance3D = null
	if lateral:
		p = Vector3(300.0, 0.0, 300.0)
		suelo_plano = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(30.0, 30.0)
		suelo_plano.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.45, 0.3)
		suelo_plano.material_override = mat
		_mundo.add_child(suelo_plano)
		suelo_plano.global_position = p
	else:
		p.y = Terreno3D.y_pies(Terreno3D.celda_de(p))
	var modelo := Pj3D.new()
	_mundo.add_child(modelo)
	modelo.cargar(id)
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = null
	if not lateral:
		g = Combate3D.equipar(modelo, _mundo, Jugador3D.new(), null)
		g.altura = 0.85
		g.quieto = true
		g.position = p
		g.casa = p
		if id.begins_with("goblin_warrior"):
			Escudo3D.equipar(g)
			g.mirada = Vector3(0, 0, 1)
			modelo.mirar(Vector3(0, 0, 1), 1.0)
	else:
		modelo.mirar(Vector3(1, 0, 0), 1.0)         # de perfil a la cámara; el clip lo tira hacia atrás (hacia -x)
	var camara: Camera3D = null
	if not lateral:
		_mundo.set("_jugador", null)
		_mundo.set("_foco", p + Vector3(-0.2, 0.3, 0.0))
		_mundo.set("_tam_camara", tam_juego)
		_mundo.get("_camara").size = tam_juego
		_mundo.call("_colocar_camara")
		camara = _mundo.get("_camara") as Camera3D
	else:
		camara = Camera3D.new()
		camara.projection = Camera3D.PROJECTION_ORTHOGONAL
		camara.size = 2.0
		_mundo.add_child(camara)
		camara.global_position = p + Vector3(-0.35, 1.3, 3.0)
		camara.look_at(p + Vector3(-0.35, 0.6, 0.0), Vector3.UP)
		camara.make_current()
	for _i in 20:
		await process_frame
	# Empuje desde +x hacia -x.
	var dur_vuelo: float = modelo.duracion("empujado")
	var dur_alzar: float = modelo.duracion("levantarse")
	if g != null:
		g.push(Vector3(-1, 0, 0), 1500.0, true)
	else:
		modelo.jugar("empujado", true)
	var t: float = 0.0
	var fase: int = 0
	var imgs: Array = []
	var idx: int = 0
	while idx < TIEMPOS.size():
		await process_frame
		t += 1.0 / 30.0
		if g == null:
			if fase == 0 and t >= dur_vuelo:
				fase = 1
				modelo.jugar("levantarse", true)
			elif fase == 1 and t >= dur_vuelo + dur_alzar:
				fase = 2
				modelo.jugar("idle")
		if t >= float(TIEMPOS[idx]) - 0.0001:
			await RenderingServer.frame_post_draw
			var img: Image = root.get_viewport().get_texture().get_image()
			var centro: Vector2 = camara.unproject_position(modelo.global_position + Vector3(0.0, 0.45, 0.0))
			if lateral:
				centro = camara.unproject_position(p + Vector3(-0.35, 0.6, 0.0))
			var x0: int = clampi(int(centro.x) - RECORTE.x / 2, 0, maxi(img.get_width() - RECORTE.x, 0))
			var y0: int = clampi(int(centro.y) - RECORTE.y / 2, 0, maxi(img.get_height() - RECORTE.y, 0))
			var rec: Image = img.get_region(Rect2i(x0, y0, RECORTE.x, RECORTE.y))
			if lateral:
				# El centro de la vista es el objetivo de la cámara: se corta un cuadrado centrado y se reduce al tamaño de las demás.
				var lado: int = mini(img.get_height(), img.get_width())
				rec = img.get_region(Rect2i((img.get_width() - lado) / 2, (img.get_height() - lado) / 2, lado, lado))
				rec.resize(RECORTE.x, RECORTE.y, Image.INTERPOLATE_LANCZOS)
			rec.save_png("%s/%s_%s_%d.png" % [_carpeta, id, cam, idx + 1])
			imgs.append(rec)
			var cd: Array = modelo.cadera_mundo()
			print("%s %s fotograma %d t=%.2f estado=%s hips_y=%.2f" % [id, cam, idx + 1, t, modelo.estado_anim(), (cd[0] as Transform3D).origin.y - modelo.global_position.y])
			idx += 1
	var hoja := Image.create(RECORTE.x * 3, RECORTE.y * 2, false, (imgs[0] as Image).get_format())
	for i in range(imgs.size()):
		hoja.blit_rect(imgs[i] as Image, Rect2i(0, 0, RECORTE.x, RECORTE.y), Vector2i((i % 3) * RECORTE.x, (i / 3) * RECORTE.y))
	hoja.save_png("%s/%s_%s.png" % [_carpeta, id, cam])
	_mundo.set("_jugador", jug)
	if lateral:
		camara.queue_free()
		suelo_plano.queue_free()
	modelo.queue_free()
	if g != null:
		g.queue_free()
	for _i in 5:
		await process_frame