extends SceneTree

## SOLO CAPTURA (Pipeline, 18/10): los seis estados de VfxEstado3D con los cuatro volúmenes (esfera, X×3, Y×2, Z×3) en fila, para MIRAR cómo quedan
## (no prueba nada; la prueba es `prueba_vfx_v2.gd`). Necesita ventana (GPU o xvfb):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_vfx_v2.gd -- <prefijo_salida> [ancho alto] [estado]
## Escribe `<prefijo>_<estado>_<momento>.png`. Con `estado` solo hace ese; `todas` hace además la fila de «todas las firmas».
class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)

const ESTADOS: Array = [["solido", "tierra"], ["solido", "hielo"], ["liquido", "agua"], ["plasma", "fuego"], ["energia", "rayo"], ["gas", "viento"], ["campo", "tiempo"]]
const VOLS: Array = [[0.5, 0.5, 0.5, 1], [3.0, 0.5, 0.5, 1], [0.5, 2.0, 0.5, 4], [0.5, 0.5, 3.0, 1]]
const MOMENTOS: Array = [0.3, 0.9]
const MOMENTOS_ENERGIA: Array = [0.04, 0.1]
const MOMENTOS_LIQUIDO: Array = [0.3, 0.62]   # cayendo y salpicando (la caída dura 0,4–0,8 s según el alto)

func _initialize() -> void:
	_correr()

func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.is_empty():
		print("uso: -- <prefijo_salida> [ancho alto] [estado|todas]")
		quit(1)
		return
	var salida: String = a[0]
	var tam := Vector2i(int(a[1]) if a.size() > 2 else 1280, int(a[2]) if a.size() > 2 else 720)
	var filtro: String = a[3] if a.size() > 3 else ""
	var firmas: bool = filtro == "todas"
	var vp := SubViewport.new()
	vp.size = tam
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	vp.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120.0, 60.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.30, 0.38, 0.27)
	suelo.material_override = ms
	vp.add_child(suelo)
	var cam := Camera3D.new()
	cam.fov = 46.0
	vp.add_child(cam)
	# look_at_from_position y no look_at: dentro de _initialize el nodo aún no cuenta como «dentro del árbol» y look_at falla sin avisar de más
	cam.look_at_from_position(Vector3(0.0, 9.0, 40.0), Vector3(0.0, 2.2, 3.0), Vector3.UP)
	cam.current = true
	# una cápsula de 1,1 u hace de jugador al lado de cada volumen para ver la escala (casilla = 2,3 u)
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	var vfx: VfxEstado3D = VfxEstado3D.conectar(l, mundo)
	await process_frame
	await process_frame
	for par in ESTADOS:
		if filtro != "" and filtro != "todas" and filtro != par[0] and filtro != par[1]:
			continue
		var ms_: Array = MOMENTOS_ENERGIA if par[0] == "energia" else (MOMENTOS_LIQUIDO if par[0] == "liquido" else MOMENTOS)
		var props: Dictionary = {"viaja": 1.0, "solidez": 1.0, "copias": 3.0, "rebotes": 2.0, "crece": 1.0} if firmas else {}
		var x: float = -27.0
		for v in VOLS:
			var g: Dictionary = {"x": v[0], "y": v[1], "z": v[2], "niveles": v[3], "celdas": [], "props": props}
			# el jugador queda en el origen del hechizo: se ve de qué tamaño es el volumen frente a él
			var jug := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.28
			cap.height = 1.1
			jug.mesh = cap
			jug.position = Vector3(x, 0.55, -1.2)
			jug.name = "jugador"
			mundo.add_child(jug)
			l.hechizo_v2.emit(par[0], par[1], g, Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), props)
			x += 18.0
		var previo: float = 0.0
		for m in ms_:
			await create_timer(float(m) - previo).timeout
			previo = float(m)
			var ruta: String = "%s_%s%s_%s.png" % [salida, par[1] if par[0] == "solido" else par[0], "_firmas" if firmas else "", ("%.2f" % m).replace(".", "")]
			vp.get_texture().get_image().save_png(ruta)
			print("capturado ", ruta)
		await create_timer(10.0).timeout
		for n in mundo.get_children():
			if n.name == "jugador":
				n.queue_free()
		print("%s: quedan %d hechizos" % [par[0], vfx.activos()])
	quit()
