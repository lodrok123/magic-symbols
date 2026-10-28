extends SceneTree
## Fotos del chamán goblin (sin rig). NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_chaman.gd -- [carpeta]   (por defecto res://docs/capturas/chaman)

const ALTO_JUEGO: float = 0.85
const BASTON_ALTO: float = 0.95
var _dir: String = "res://docs/capturas/chaman"
var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	root.add_child(_cam)
	var m: Node3D = _poner("goblin_chaman", Vector3.ZERO)
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 14.0
	var foco := Vector3(0, ALTO_JUEGO * 0.5, 0)
	var vistas: Array = [["frente", 0.0], ["lado", 90.0], ["espalda", 180.0], ["tres_cuartos", 40.0]]
	for v in vistas:
		var d := Vector3(sin(deg_to_rad(v[1])), 0.12, cos(deg_to_rad(v[1]))).normalized() * 4.0
		_cam.look_at_from_position(foco + d, foco)
		await _foto(v[0])
	# Cámara del juego: ortogonal, 60°, tamaño 6, junto a los otros goblins.
	m.position = Vector3(0, 0, 0)
	_poner("goblin_warrior_chibi", Vector3(-1.2, 0, 0))
	_poner("goblin_asesino", Vector3(1.2, 0, 0))
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.2
	var e: float = deg_to_rad(90.0 - 60.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.4, 0) - dir * 40.0)
	await _foto("juego")
	# Bastón (pieza aparte, 1,0 de largo con el centro en el origen y el eje largo en Y) en la mano derecha (-X): vertical, punta en el suelo, a ojo.
	var b: Node3D = (load("res://arte/modelos/baston_chaman.glb") as PackedScene).instantiate()
	var cb := Node3D.new()
	cb.add_child(b)
	b.position = Vector3(0, 0.5, 0)
	cb.scale = Vector3.ONE * BASTON_ALTO
	cb.position = Vector3(-0.235, 0.0, 0.03)
	m.add_child(cb)
	await _foto("con_baston_juego")
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 14.0
	m.position = Vector3.ZERO
	_cam.look_at_from_position(foco + Vector3(0, 0.12, 4.0).normalized() * 4.0, foco)
	await _foto("con_baston")
	quit(0)


func _poner(nombre: String, pos: Vector3) -> Node3D:
	var n: Node3D = (load("res://arte/modelos/%s.glb" % nombre) as PackedScene).instantiate()
	var caja: AABB = _caja(n)
	var s: float = ALTO_JUEGO / caja.size.y
	var cont := Node3D.new()
	root.add_child(cont)
	cont.add_child(n)
	n.scale = Vector3.ONE * s
	n.position = Vector3(-(caja.position.x + caja.size.x * 0.5) * s, -caja.position.y * s, -(caja.position.z + caja.size.z * 0.5) * s)
	cont.position = pos
	return cont


func _caja(n: Node) -> AABB:
	var r := AABB()
	var primero := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var c: Node = mi
		while c != null and c != n:
			if c is Node3D:
				t = (c as Node3D).transform * t
			c = c.get_parent()
		var b: AABB = t * (mi as MeshInstance3D).get_aabb()
		r = b if primero else r.merge(b)
		primero = false
	return r


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(20, 20)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.32, 0.36)
	suelo.material_override = mt
	root.add_child(suelo)


func _foto(nombre: String) -> void:
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)
