extends SceneTree
## SOLO CAPTURA (Pipeline, 17/10, T-CP3): los tres orígenes de cast point de `ConjuroVfx3D`, para MIRAR cómo quedan (no prueba nada; la prueba sin
## ventana es `prueba_conjuro_vfx.gd`). Con ventana (necesita GPU o xvfb), igual que `captura_mano_pluma_3d.gd`:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_conjuro_vfx.gd -- <carpeta_salida> [ancho alto]
## Escribe 9 PNG `<salida>_<origen>_<momento>.png`: mano_libre (fuego), manos_alto (hielo) y suelo_delante (agua), cada uno creciendo,
## sostenido y a los 0,06 s del disparo. Un cápsula de 1,1 u hace de jugador para ver la altura a la que nace cada forma.
class FalsoLanzador:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	var origen: String = "mano_libre"
	var destino: Vector3 = Vector3.INF
	func tiempos_conjuro(_e: String) -> Array:
		return [0.05, 0.25, 0.9]
	func origen_conjuro(_e: String) -> Dictionary:
		return {"origen": origen, "destino": destino}

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.is_empty():
		print("uso: -- <carpeta_salida> [ancho alto]")
		quit(1)
		return
	var salida: String = a[0]
	var tam := Vector2i(int(a[1]) if a.size() > 2 else 1280, int(a[2]) if a.size() > 2 else 720)
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
	pm.size = Vector2(14.0, 14.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.30, 0.38, 0.27)
	suelo.material_override = ms
	vp.add_child(suelo)
	var jug := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	jug.mesh = cap
	jug.position = Vector3(0.0, 0.55, 0.0)
	var mj := StandardMaterial3D.new()
	mj.albedo_color = Color(0.75, 0.7, 0.62)
	jug.material_override = mj
	vp.add_child(jug)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.position = Vector3(4.6, 3.4, 5.0)
	cam.look_at(Vector3(0.5, 0.9, 1.0), Vector3.UP)
	cam.current = true
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	var c: ConjuroVfx3D = ConjuroVfx3D.conectar(l, mundo)
	# origen, elemento, posición del cast point, destino en el suelo
	var casos: Array = [
		["mano_libre", "fuego", Vector3(0.4, 0.85, 0.35), Vector3.INF],
		["manos_alto", "hielo", Vector3(0.0, 1.75, 0.15), Vector3(0.3, 0.0, 2.0)],
		["suelo_delante", "agua", Vector3(0.3, 0.0, 1.7), Vector3.INF]]
	await _frames(5)
	for caso in casos:
		l.origen = caso[0]
		l.destino = caso[3]
		l.conjuro_fase.emit("runa", caso[1], caso[2])
		l.conjuro_fase.emit("voluta", caso[1], Vector3(-0.3, 0.6, 0.1))
		await create_timer(0.3).timeout
		l.conjuro_fase.emit("forma", caso[1], caso[2])
		await create_timer(0.45).timeout
		_guardar(vp, "%s_%s_creciendo.png" % [salida, caso[0]])
		await create_timer(0.7).timeout
		_guardar(vp, "%s_%s_sostenido.png" % [salida, caso[0]])
		l.conjuro_fase.emit("disparo", caso[1], caso[2])
		await create_timer(0.06).timeout
		_guardar(vp, "%s_%s_disparo.png" % [salida, caso[0]])
		await create_timer(0.7).timeout
		print("%s: quedan %d nodos tras el disparo" % [caso[0], c.get_child_count()])
	quit()

func _guardar(vp: SubViewport, ruta: String) -> void:
	vp.get_texture().get_image().save_png(ruta)
	print("capturado ", ruta)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame
