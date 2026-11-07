extends SceneTree

## CAPTURA DE LAS ROCAS DE LELU (7/11/2026; a imagen de captura_viento_tierra_toy.gd): lamina de contacto de las DIEZ formas de `arte/rocas_lelu/sm_rocks_objects.glb` (la variante sin sufijo)
## en fila, de frente, con luz direccional sobre suelo gris claro. fila.png: todas a 1 m de alto; fila_estiradas.png: las mismas a 2,5 m de alto SIN tocar el ancho (como el video hace las puas).
## Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) pero no espera clics:
##   godot --path . --script res://herramientas/captura_rocas_lelu.gd -- docs/capturas/rocas_lelu

const TAM: Vector2i = Vector2i(2000, 700)
const FORMAS: Array = ["stone1", "stone2", "stone3", "stone4", "stone5", "stone6", "stoneB1", "stoneB2", "stoneG", "stoneK"]
const HUECO: float = 0.2                                               # separacion entre cajas (m)

var _dir: String = "docs/capturas/rocas_lelu"
var _mundo: Node3D = null
var _filas: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_montar_escena()
	var glb: Node = (load("res://arte/rocas_lelu/sm_rocks_objects.glb") as PackedScene).instantiate()
	var mallas: Dictionary = {}
	_buscar(glb, mallas)
	# ---- foto 1: a 1 m ----
	_poner_fila(mallas, 1.0)
	await create_timer(0.5).timeout
	_guardar("fila.png")
	# ---- foto 2: estiradas a 2,5 m ----
	_poner_fila(mallas, 2.5)
	await create_timer(0.5).timeout
	_guardar("fila_estiradas.png")
	glb.free()
	quit(0)


func _montar_escena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.8, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -25, 0)
	sol.light_energy = 1.1
	_mundo.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(40, 12)
	suelo.mesh = pl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.72, 0.72)
	m.roughness = 1.0
	suelo.material_override = m
	_mundo.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.2
	cam.position = Vector3(0, 1.45, 10)
	_mundo.add_child(cam)
	cam.current = true
	_filas = Node3D.new()
	_mundo.add_child(_filas)


func _buscar(n: Node, d: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and FORMAS.has(String(n.name)):
		d[String(n.name)] = n
	for c in n.get_children():
		_buscar(c, d)


func _poner_fila(mallas: Dictionary, alto: float) -> void:
	for c in _filas.get_children():
		c.free()
	var total: float = HUECO * (FORMAS.size() - 1)
	for n in FORMAS:
		if mallas.has(n):
			var cb: AABB = (mallas[n] as MeshInstance3D).mesh.get_aabb()
			total += cb.size.x / cb.size.y
	var x: float = -total * 0.5                                            # borde izquierdo de la fila (cada forma ocupa su ancho a 1 m de alto)
	for i in range(FORMAS.size()):
		var nombre: String = FORMAS[i]
		if not mallas.has(nombre):
			print("FALTA ", nombre)
			continue
		var mi: MeshInstance3D = mallas[nombre]
		var caja: AABB = mi.mesh.get_aabb()
		var k: float = 1.0 / caja.size.y                                   # ancho que tendria a 1 m de alto
		var cx: float = x + caja.size.x * k * 0.5
		x += caja.size.x * k + HUECO
		var pieza := MeshInstance3D.new()
		pieza.mesh = mi.mesh
		pieza.scale = Vector3(k, alto * k, k)
		# base apoyada en el suelo y centrada en x/z
		var c: Vector3 = caja.get_center()
		pieza.position = Vector3(cx - c.x * k, -caja.position.y * k * alto, -c.z * k)
		_filas.add_child(pieza)
		var et := Label3D.new()
		et.text = nombre
		et.font_size = 56
		et.pixel_size = 0.004
		et.modulate = Color(0.1, 0.1, 0.12)
		et.outline_size = 0
		et.position = Vector3(cx, -0.2, 1.2)
		_filas.add_child(et)


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)


