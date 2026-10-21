extends SceneTree
## V8 «presupuesto», parte 2: TEXTURAS DE 2048 DE PERSONAJES Y BESTIAS a 1024. NECESITA VENTANA (con --headless no hay GPU: no hay memoria de vídeo ni imagen).
##   godot --path . --script res://herramientas/captura_texturas_v8.gd -- <carpeta> <etiqueta>
## 1) MEMORIA: carga uno a uno los modelos de la lista, dibuja unos fotogramas y apunta cuánta memoria de textura de la GPU sube con cada uno
##    (Performance.RENDER_TEXTURE_MEM_USED y RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED). Los modelos NO se liberan: la suma es la de tenerlos todos.
## 2) CAPTURAS a la distancia del juego, de la jugadora y de dos goblins (y el lobo), en una escena mínima y determinista (luz y suelo fijos, animación
##    parada en el primer fotograma de «idle»), para poder comparar «antes» y «despues» píxel a píxel con herramientas/comparar_capturas_v8.gd.
##    · zoom 6,0 = ZOOM_INICIAL de prueba_test2.gd (la distancia con la que arranca el juego) · zoom 2,0 = ZOOM_MINIMO (lo más cerca que deja el juego).
const IDS: Array = ["alchemist_elf", "canouro", "canouro_anim", "elemental_bosque", "emberheart", "emberstride", "gato_guardabosques",
	"goblin_archer_chibi", "grandmaster", "lince", "lince_gato", "loberno", "woodland_wanderer", "woodland_wanderer_suave", "woodland_wanderer_v1"]
const ALTO: Dictionary = {"woodland_wanderer": 1.0, "woodland_wanderer_suave": 1.0, "goblin_archer_chibi": 0.85, "goblin_warrior_chibi": 0.85,
	"emberheart": 0.75, "elemental_bosque": 2.5, "alchemist_elf": 0.95, "gato_guardabosques": 0.55}
const FILA: Array = ["woodland_wanderer", "goblin_archer_chibi", "goblin_warrior_chibi", "emberheart"]   # de izquierda a derecha en las capturas
const INCL: float = 60.0


func _initialize() -> void:
	_correr()


func _mem() -> Array:
	return [Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)]


func _mb(b: float) -> String:
	return "%.1f MB" % (b / 1048576.0)


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "docs/capturas/v8"
	var etiqueta: String = a[1] if a.size() > 1 else "actual"
	DirAccess.make_dir_recursive_absolute(carpeta)
	Pj3D.validar_al_cargar = false
	# Escena mínima: luz de sol inclinada con sombra, ambiente y un suelo verde.
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	luz.shadow_enabled = true
	root.add_child(luz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.42, 0.62, 0.28)
	pm.material = sm
	suelo.mesh = pm
	root.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	root.add_child(cam)
	for _i in 10:
		await process_frame
	var base: Array = _mem()
	print("MEM base (escena vacía) | %s | %s" % [_mb(base[0]), _mb(base[1])])

	# 1) Memoria, modelo a modelo.
	var holder := Node3D.new()
	root.add_child(holder)
	holder.position = Vector3(0, 0, -40.0)   # lejos de la cámara de la captura
	var previo: float = base[0]
	var suma: float = 0.0
	for id in IDS:
		var pj := Pj3D.new()
		holder.add_child(pj)
		if not pj.cargar(id):
			print("MEM %s | no carga" % id)
			continue
		pj.position = Vector3(float(IDS.find(id)) * 1.5 - 10.0, 0, 0)
		for _i in 6:
			await process_frame
		var m: Array = _mem()
		var d: float = float(m[0]) - previo
		previo = float(m[0])
		suma += d
		print("MEM %s | +%s (monitor) | total %s" % [id, _mb(d), _mb(m[0])])
	print("MEM TODOS (%d modelos) | +%s sobre la escena vacía | monitor %s · rendering_info %s" % [IDS.size(), _mb(suma), _mb(_mem()[0]), _mb(_mem()[1])])
	holder.queue_free()
	for _i in 10:
		await process_frame

	# 2) Capturas a la distancia del juego.
	var personajes: Array = []
	for i in FILA.size():
		var pj2 := Pj3D.new()
		root.add_child(pj2)
		pj2.cargar(FILA[i])
		pj2.set_alto(float(ALTO.get(FILA[i], 1.0)))
		pj2.position = Vector3(-2.4 + 1.6 * i, 0, 0)
		pj2.rotation.y = deg_to_rad(-20.0)
		personajes.append(pj2)
	for _i in 10:
		await process_frame
	# Parar las animaciones en su primer fotograma para que «antes» y «despues» salgan idénticas.
	for p in personajes:
		for ap in (p as Node).find_children("*", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).pause()
			(ap as AnimationPlayer).seek(0.0, true)
	var vistas: Array = [["zoom6", 6.0, Vector3(0.0, 0.5, 0.0)], ["zoom2_jugadora", 2.0, Vector3(-2.4, 0.55, 0.0)], ["zoom2_goblin", 2.0, Vector3(-0.8, 0.5, 0.0)]]
	for v in vistas:
		cam.size = float(v[1])
		var e: float = deg_to_rad(90.0 - INCL)
		var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
		cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (v[2] as Vector3) - dir * 40.0)
		for _i in 12:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/texturas_%s_%s.png" % [carpeta, v[0], etiqueta]
		img.save_png(ruta)
		print("CAPTURA %s | %dx%d | %s" % [v[0], img.get_width(), img.get_height(), ruta])
	var f: Array = _mem()
	print("MEM final con la fila de la captura | %s | %s · renderer %s" % [_mb(f[0]), _mb(f[1]), RenderingServer.get_current_rendering_method()])
	quit()
