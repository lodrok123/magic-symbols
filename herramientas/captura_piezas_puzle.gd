extends SceneTree
## Captura de las piezas de puzle con modelos: tres filas (estado inicial · estado activo · primitivas de respaldo).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1800x1000 --path . --script res://herramientas/captura_piezas_puzle.gd -- salida.png [fila]
## fila: 0 = todas (por defecto) · 1, 2 o 3 = solo esa, más cerca. Opcional: `desde` y `cuantas` (qué piezas de la fila) para verlas de cerca.

const FAMILIAS: Array = [
	["pulsador", {"tinte": "magia"}, "hundido"], ["pulsador", {"tinte": "agua"}, "hundido"], ["placa", {}, "hundida"],
	["compuerta", {}, "abierta"], ["compuerta", {"material": "hierro"}, "abierta"], ["compuerta_hielo", {}, "derritiendose"],
	["roca", {}, "rota"], ["barril", {}, "mecha"], ["molino", {}, "quieto"], ["pila", {}, "electrificada"],
	["poste_nivel", {"marca": 1.0}, "encendido"], ["reja", {}, "abierta"], ["tapon_hielo", {}, "derritiendose"],
]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var salida: String = a[0] if a.size() > 0 else "/tmp/captura_piezas.png"
	var fila: int = int(a[1]) if a.size() > 1 else 0
	var desde: int = int(a[2]) if a.size() > 2 else 0
	var cuantas: int = int(a[3]) if a.size() > 3 else FAMILIAS.size()
	var e := WorldEnvironment.new()
	e.environment = Environment.new()
	e.environment.background_mode = Environment.BG_COLOR
	e.environment.background_color = Color(0.55, 0.68, 0.78)
	e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.environment.ambient_light_energy = 0.7
	root.add_child(e)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -30, 0)
	luz.light_energy = 1.1
	luz.shadow_enabled = true
	root.add_child(luz)
	var suelo := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(80, 30)
	suelo.mesh = q
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.36, 0.46, 0.26)
	suelo.material_override = ms
	suelo.position.z = -6
	root.add_child(suelo)
	var sep: float = 3.3
	var n: int = mini(cuantas, FAMILIAS.size() - desde)
	var x0: float = -float(n - 1) * sep * 0.5
	for f in range(3):
		if fila != 0 and fila != f + 1:
			continue
		for i in range(n):
			var d: Array = FAMILIAS[desde + i]
			var opc: Dictionary = (d[1] as Dictionary).duplicate()
			if f == 2:
				opc["modelos"] = false
			var p: PiezaPuzle3D = PiezaPuzle3D.crear(d[0], opc)
			p.sonido = false
			root.add_child(p)
			p.position = Vector3(x0 + i * sep, 0, -float(f) * 4.0)
			if f > 0:
				p.poner_estado(d[2], false)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	if fila == 0:
		cam.look_at_from_position(Vector3(0, 11, 9), Vector3(0, 0.3, -4.0))
		cam.fov = 62
	else:
		var zf: float = -float(fila - 1) * 4.0
		cam.look_at_from_position(Vector3(0, 2.6 + float(n) * 0.25, zf + 3.5 + float(n) * 1.6), Vector3(0, 0.5, zf))
		cam.fov = 45
	for _i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(salida)
	quit()
