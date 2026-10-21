extends SceneTree
## CAPTURAS de V6 (quemado y disolver por celdas, docs/PLAN_EOW_VISUAL.md). NECESITA VENTANA (en --headless no hay GPU: ni se compila el shader ni hay imagen).
##   godot --path . --script res://herramientas/captura_v6.gd -- <carpeta>
## Saca, con el seto de verdad (arte/piezas/seto_seco.tscn dentro de un Reactivo3D) y el escudo quemado (PiezaFuego3D):
##   seto_ardiendo_1..3     el fuego REAL (`ignite`) cuando lleva el 25 %, el 60 % y el 95 % de su combustión (llamas incluidas)
##   seto_disolver_1..3     ya carbonizado, deshaciéndose por celdas al 25 %, 55 % y 85 % (fijados a mano: el tween real dura 0,5 s)
##   escudo_disolver_1..3   la malla quemada del escudo al 25 %, 55 % y 85 % de su desintegración
##   seto_oclusion          seto a medio quemar entre la cámara y el jugador, con el círculo de transparencia activo
##   seto_apagado_v6        mismo seto con `Ocluso3D.usar_quemado_disolver = false` al 60 % (el tinte de antes)
## Además imprime el color medio del seto en cada toma (para comprobar que NO es uniforme: que hay brasas y manchas).

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
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/v6"
	DirAccess.make_dir_recursive_absolute(_carpeta)
	await process_frame
	Ocluso3D.preparar()
	_escena()
	await _frames(20)
	# --- seto ardiendo (fuego real) ---
	var r: Reactivo3D = _seto(Vector3.ZERO)
	await _frames(10)
	_cam_a(Vector3(0.0, 0.45, 0.0), 2.3)
	r.ignite()
	var dur: float = float(r._num_combustible()[0])
	var i: int = 1
	for k in [0.25, 0.6, 0.95]:
		while r._t < dur * k:
			await process_frame
		await _frames(2)
		_foto("seto_ardiendo_%d" % i, "quemado %.2f" % Ocluso3D.quemado_de(_mat(r)))
		i += 1
	r._quitar_fuego()
	r.queue_free()
	await _frames(5)
	# --- seto disolviéndose ---
	var d: Reactivo3D = _seto(Vector3.ZERO)
	await _frames(10)
	d._poner_quemado(1.0)
	i = 1
	for v in [0.25, 0.55, 0.85]:
		d._poner_disolver(v)
		await _frames(3)
		_foto("seto_disolver_%d" % i, "disolver %.2f" % v)
		i += 1
	d.queue_free()
	await _frames(5)
	# --- escudo ---
	var e: PiezaFuego3D = PiezaFuego3D.crear("goblin_escudo_quemado")
	_mundo.add_child(e)
	e.position = Vector3(0.0, 0.7, 0.0)
	var mats: Array[ShaderMaterial] = Ocluso3D.convertir_nodo(e)
	for m in mats:
		Ocluso3D.configurar_disolver(m, Ocluso3D.DISOLVER_COLOR, Ocluso3D.DISOLVER_CELDA_ESCUDO)
	print("escudo: %d materiales comunes" % mats.size())
	_cam_a(Vector3(0.0, 0.7, 0.0), 1.5)
	i = 1
	for v in [0.25, 0.55, 0.85]:
		for m in mats:
			Ocluso3D.poner_disolver(m, v)
		await _frames(3)
		_foto("escudo_disolver_%d" % i, "disolver %.2f" % v)
		i += 1
	e.queue_free()
	await _frames(5)
	# --- oclusión: el círculo del jugador sobre un seto a medio quemar ---
	var o: Reactivo3D = _seto(Vector3.ZERO)
	await _frames(10)
	o._poner_quemado(0.55)
	var jugador := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.0
	jugador.mesh = cap
	var mj := StandardMaterial3D.new()
	mj.albedo_color = Color(0.9, 0.2, 0.2)
	jugador.material_override = mj
	jugador.position = Vector3(0.0, 0.5, -1.4)
	_mundo.add_child(jugador)
	_cam_a(Vector3(0.0, 0.5, -0.5), 3.0)
	Ocluso3D.actualizar(jugador.global_position + Vector3(0.0, 0.3, 0.0), 0.9)
	await _frames(4)
	_foto("seto_oclusion", "con el círculo del jugador")
	Ocluso3D.actualizar(Vector3.ZERO, 0.0)
	# --- el interruptor apagado: el tinte uniforme de antes ---
	o.queue_free()
	jugador.queue_free()
	await _frames(5)
	Ocluso3D.usar_quemado_disolver = false
	var z: Reactivo3D = _seto(Vector3.ZERO)
	await _frames(10)
	_cam_a(Vector3(0.0, 0.45, 0.0), 2.3)
	z.ignite()
	while z._t < dur * 0.6:
		await process_frame
	await _frames(2)
	_foto("seto_antes_de_v6", "tinte uniforme (interruptor apagado)")
	Ocluso3D.usar_quemado_disolver = true
	quit()


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


func _seto(pos: Vector3) -> Reactivo3D:
	var r := Reactivo3D.new()
	var vis := Node3D.new()
	var ps: PackedScene = load("res://arte/piezas/seto_seco.tscn") as PackedScene
	if ps != null:
		vis.add_child(ps.instantiate())
	else:
		push_error("falta arte/piezas/seto_seco.tscn")
	r.add_child(vis)
	r.preparar("seto", Vector2i(5, 5), "", _fx, vis)
	r.position = pos
	_mundo.add_child(r)
	return r


func _mat(r: Reactivo3D) -> Material:
	return r._mats[0][0] as Material if not r._mats.is_empty() else null


func _foto(nombre: String, nota: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_carpeta, nombre])
	# Color medio y dispersión del centro de la imagen (donde está el seto): si fuera un tinte uniforme la dispersión sería la del modelo sano.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = 0
	var s := Vector3.ZERO
	var s2 := Vector3.ZERO
	var rojo: int = 0
	for y in range(h / 4, h * 3 / 4, 3):
		for x in range(w / 3, w * 2 / 3, 3):
			var c: Color = img.get_pixel(x, y)
			var v := Vector3(c.r, c.g, c.b)
			s += v
			s2 += v * v
			n += 1
			if c.r > 0.8 and c.g > 0.25 and c.g < 0.65 and c.b < 0.3:
				rojo += 1                               # píxeles «brasa» (naranja intenso)
	var m: Vector3 = s / float(maxi(n, 1))
	var sd: Vector3 = (s2 / float(maxi(n, 1)) - m * m)
	print("FOTO %s | %s | media (%.2f %.2f %.2f) | varianza %.4f | px brasa %d" % [nombre, nota, m.x, m.y, m.z, sd.x + sd.y + sd.z, rojo])
