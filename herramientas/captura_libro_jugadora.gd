extends SceneTree
## CAPTURAS de la jugadora nueva (jugadora_base, a la derecha) junto a la elfa de antes (woodland_wanderer, a la izquierda) sobre un escenario liso: el libro en la mano (la pose del
## brazo y apuntando), en el instante de cada cast point, el grimorio colgado a la espalda y nadando. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_libro_jugadora.gd -- <carpeta> [<prefijo> [<secciones: brazo,apuntar,cast,espalda,nado>]]

const ALTO_JUEGO: float = 1.0
const TAM: float = 1.5
const CAMARA_PITCH: float = 8.0
const IDS: Array = ["woodland_wanderer", "jugadora_base"]
const SEPARACION: float = 0.9
const VISTAS: Array = [["frente", 0.0], ["tres_cuartos", 40.0], ["lado", 90.0]]
const VISTAS_ESPALDA: Array = [["espalda", 180.0], ["tres_cuartos_atras", 140.0], ["lado", 90.0]]
const VARIACIONES: Array = ["x_mano", "x_empuje", "alto_cielo", "abajo_golpe"]
## Nadando: los pies van a (superficie − HUNDIDO) y HUNDIDO = 0,35 u (ver Pj3D.NADO_CADERA): el agua cubre hasta esa altura.
const NIVEL_AGUA: float = 0.35
const COLOR_AGUA: Color = Color(0.25, 0.55, 0.85, 0.55)

var _carpeta: String = ""
var _prefijo: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/jugadora_integrada"
	_prefijo = a[1] if a.size() > 1 else ""
	var secciones: PackedStringArray = (a[2] if a.size() > 2 else "brazo,apuntar,cast,espalda,nado").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	Estado.nuevo()
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.68, 0.45)
	suelo.material_override = sm
	raiz.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(cam)
	cam.current = true
	root.size = Vector2i(1000, 700)
	var pjs: Array = []
	for i in IDS.size():
		var pj := Pj3D.new()
		pj.position = Vector3((float(i) - 0.5) * SEPARACION, 0, 0)
		raiz.add_child(pj)
		pj.cargar(String(IDS[i]))
		pj.set_alto(ALTO_JUEGO)
		pjs.append(pj)
	await _esperar(20)
	if secciones.has("brazo"):
		# la pose del brazo del libro (peso 1) en reposo, con el libro en cada mano
		for lado in ["izquierda", "derecha"]:
			for pj in pjs:
				var pp: Pj3D = pj as Pj3D
				pp.libro_en_manos(true, 0.3, String(lado), true)
				pp._brazo_libro_lado(String(lado))
				pp._brazo_libro_peso(1.0)
			await _esperar(20)
			for pj in pjs:
				(pj as Pj3D).libro_asentar()
			await _fotos("brazo_" + String(lado), cam, pjs, VISTAS)
			for pj in pjs:
				var pq: Pj3D = pj as Pj3D
				pq._brazo_libro_peso(0.0)
				pq.libro_en_manos(false, 0.1)
				pq.libro_asentar()
			await _esperar(10)
	if secciones.has("apuntar"):
		for pj in pjs:
			(pj as Pj3D).apuntar()
		await _esperar(30)
		for pj in pjs:
			(pj as Pj3D).libro_asentar()
		await _fotos("apuntar", cam, pjs, VISTAS)
	if secciones.has("cast"):
		# cast points: se congela el clip en el instante
		for id in VARIACIONES:
			for pj in pjs:
				(pj as Pj3D).soltar_lanzar()
			await _esperar(20)
			for pj in pjs:
				(pj as Pj3D).lanzar("proyectil", "fire", String(id))
			await _esperar(4)
			var dur: float = 0.0
			for pj in pjs:
				(pj as Pj3D).libro_asentar()
				dur = maxf(dur, (pj as Pj3D).tiempo_instante())
			await _esperar(int(ceil(dur * 30.0)))
			for pj in pjs:
				var p2: Pj3D = pj as Pj3D
				if p2._arbol != null:
					p2._arbol.retenido = true
			await _fotos("cast_" + String(id), cam, pjs, VISTAS)
			for pj in pjs:
				var p3: Pj3D = pj as Pj3D
				if p3._arbol != null:
					p3._arbol.retenido = false
		for pj in pjs:
			(pj as Pj3D).soltar_lanzar()
		await _esperar(30)
	if secciones.has("espalda"):
		# el grimorio colgado a la espalda (a la cadera)
		await _esperar(20)
		await _fotos("grimorio_cinto", cam, pjs, VISTAS_ESPALDA)
	if secciones.has("nado"):
		var agua := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(6.0, NIVEL_AGUA, 3.0)
		agua.mesh = caja
		var am := StandardMaterial3D.new()
		am.albedo_color = COLOR_AGUA
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		agua.material_override = am
		agua.position = Vector3(0, NIVEL_AGUA * 0.5, 0)
		raiz.add_child(agua)
		for pj in pjs:
			var pn: Pj3D = pj as Pj3D
			pn.animacion_actual = ""
			pn.jugar("swim")
		await _esperar(25)
		await _fotos("nadando", cam, pjs, VISTAS)
		agua.queue_free()
	quit()


func _esperar(n: int) -> void:
	for _i in n:
		await process_frame


func _fotos(nombre: String, cam: Camera3D, pjs: Array, vistas: Array) -> void:
	for v in vistas:
		for pj in pjs:
			(pj as Node3D).rotation_degrees.y = float(v[1])
		var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PITCH)), -cos(deg_to_rad(CAMARA_PITCH)))
		cam.size = TAM
		cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.5, 0) - dir * 20.0)
		for _i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/%s%s_%s.png" % [_carpeta, _prefijo, nombre, v[0]]
		img.save_png(ProjectSettings.globalize_path(ruta))
		print("captura ", ruta)
	for pj in pjs:
		(pj as Node3D).rotation_degrees.y = 0.0
