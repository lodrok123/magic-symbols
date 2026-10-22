extends SceneTree
## CAPTURAS de V6 restos: ENREDADERA (brotando, ardiendo en 3 momentos, disolviéndose) y COFRE apareciendo (4 momentos). NECESITA VENTANA
## (en --headless no hay GPU: ni se compila el shader ni hay imagen). Con Godot CERRADO (el editor de Pablo no puede estar abierto):
##   godot --path . --script res://herramientas/captura_v6_restos.gd -- <carpeta>      (por defecto res://docs/capturas/v6_restos)
## Salida: enredadera_brota, enredadera_ardiendo_1..3, enredadera_disolver, cofre_aparece_1..4 (+ una línea FOTO por toma con color medio y píxeles «brasa»).
## Si salen fotos IDÉNTICAS y «Parameter "material" is null» es que la ventana no se dibujaba (minimizada/tapada): el script avisa con AVISO. Con ventana visible sale bien.

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _carpeta: String = ""
var _mundo: MundoFalso = null
var _fx: Vfx3D = null
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/v6_restos"
	DirAccess.make_dir_recursive_absolute(_carpeta)
	await process_frame
	Ocluso3D.preparar()
	_escena()
	await _frames(20)
	# --- enredadera: brota (una toma a mitad del brote), arde (3), se deshace (1) ---
	var e := Enredadera3D.new()
	_mundo.add_child(e)
	e.preparar(_fx, 1.6, "")
	_cam_a(Vector3(0.0, 0.2, 0.0), 1.6)
	e.brotar()
	await _esperar(Enredadera3D.DURA_BROTE * 0.35)
	await _foto("enredadera_brota", "brotando (recorte del suelo)")
	await _esperar(Enredadera3D.DURA_BROTE)
	e.quemar()
	var t0: float = _t()
	var i: int = 1
	for k in [0.3, 0.85, 1.0]:
		var obj: float = (Enredadera3D.DURA_ARDER + Enredadera3D.DURA_QUEMADA) * (k if k < 1.0 else 0.97)
		if i == 3:
			obj = Enredadera3D.DURA_ARDER + Enredadera3D.DURA_QUEMADA * 0.9
		while _t() - t0 < obj:
			await process_frame
		await _foto("enredadera_ardiendo_%d" % i, "quemado %.2f fase %d" % [Ocluso3D.quemado_de(e._mat), e.fase])
		i += 1
	while is_instance_valid(e) and e.fase != Enredadera3D.Fase.DESHACIENDO:
		await process_frame
	await _esperar(Enredadera3D.DURA_DESHACER * 0.5)
	if is_instance_valid(e):
		await _foto("enredadera_disolver", "disolver %.2f" % Ocluso3D.disolver_de(e._mat))
	await _esperar(Enredadera3D.DURA_DESHACER)
	await _frames(5)
	# --- cofre apareciendo ---
	var ps: PackedScene = load("res://arte/piezas/cofre.tscn") as PackedScene
	var pieza: Node3D = ps.instantiate() as Node3D
	_mundo.add_child(pieza)
	await _frames(5)
	var c: Cofre3D = Cofre3D.en(pieza)
	c.ocultar()
	_cam_a(Vector3(0.0, 0.4, 0.0), 2.2)
	c.aparecer()
	t0 = _t()
	i = 1
	for k in [0.12, 0.4, 0.7, 0.98]:
		while _t() - t0 < Cofre3D.T_APARECE_DISOLVER * k:
			await process_frame
		await _foto("cofre_aparece_%d" % i, "disolver %.2f" % c.disolver_v)
		i += 1
	quit()


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0


func _esperar(seg: float) -> void:
	var t: float = _t()
	while _t() - t < seg:
		await process_frame


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _escena() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	_fx = Vfx3D.new()
	root.add_child(_fx)
	var suelo := MeshInstance3D.new()
	var plano := BoxMesh.new()
	plano.size = Vector3(14.0, 0.2, 14.0)
	suelo.mesh = plano
	suelo.position = Vector3(0.0, -0.1, 0.0)
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.55, 0.58, 0.42)
	suelo.material_override = ms
	root.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sol.shadow_enabled = true
	root.add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.5, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_cam = Camera3D.new()
	_cam.current = true
	root.add_child(_cam)


func _cam_a(objetivo: Vector3, dist: float) -> void:
	_cam.position = objetivo + Vector3(0.0, 0.9, 1.0).normalized() * dist
	_cam.look_at(objetivo)


var _hash_prev: int = 0


func _foto(nombre: String, nota: String) -> void:
	await RenderingServer.frame_post_draw           # la imagen es la del cuadro YA dibujado (sin esto puede ser la anterior)
	var img: Image = root.get_viewport().get_texture().get_image()
	var hsh: int = hash(img.get_data())
	if hsh == _hash_prev:
		print("AVISO: %s es IDENTICA a la foto anterior: la ventana no esta dibujando (minimizada/tapada) o nada ha cambiado" % nombre)
	_hash_prev = hsh
	img.save_png("%s/%s.png" % [_carpeta, nombre])
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = 0
	var s := Vector3.ZERO
	var rojo: int = 0
	for y in range(h / 4, h * 3 / 4, 3):
		for x in range(w / 3, w * 2 / 3, 3):
			var c: Color = img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b)
			n += 1
			if c.r > 0.8 and c.g > 0.25 and c.g < 0.65 and c.b < 0.3:
				rojo += 1
	var m: Vector3 = s / float(maxi(n, 1))
	print("FOTO %s | %s | media (%.2f %.2f %.2f) | px brasa %d" % [nombre, nota, m.x, m.y, m.z, rojo])
