extends SceneTree

## CAPTURAS CON VENTANA de la ronda de Pablo (2/11, rama fuego-toy-carga-impacto): bola en vuelo, barrera, haz (con el corte) y base del pilar, en el lab (LabVfxComparativa3D).
##   godot --path . --script res://herramientas/captura_ronda_pablo_0211.gd -- <carpeta> <etiqueta antes|despues> [todo | bola | barrera | haz | pilar | secuencias]
## Escribe <carpeta>/<figura>_<vista>_<etiqueta>.png y, para `secuencias`, <carpeta>/seq_<figura>/<etiqueta>_NN.png (12 fps).

const TAM: Vector2i = Vector2i(1280, 720)

var _dir: String = "docs/capturas/comparativa_vfx/godot_toy/ronda_pablo_0211"
var _tag: String = "despues"
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = "todo"
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		_tag = a[1]
	if a.size() > 2:
		que = a[2]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	await _seg(0.8)
	if que in ["todo", "bola"]:
		await _bola()
	if que in ["todo", "barrera"]:
		await _barrera()
	if que in ["todo", "haz"]:
		await _haz()
	if que in ["todo", "pilar"]:
		await _pilar()
	if que in ["todo", "secuencias"]:
		await _secuencias()
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam_juego() -> void:
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.call("poner_camara", 1)
	_lab.set("camara_fija", {"desde": desde, "mira": mira})


func _guardar(nombre: String, sub: String = "") -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = _dir if sub == "" else _dir.path_join(sub)
	DirAccess.make_dir_recursive_absolute(ruta)
	img.save_png(ruta.path_join(nombre + ".png"))
	print("captura " + nombre)


func _limpiar() -> void:
	_lab.call("limpiar")
	await _seg(0.3)


## Espera a que la bola en vuelo pase por z <= zobj (la jugadora está en el origen, el tiro va a -Z).
func _esperar_z(e: Node3D, zobj: float) -> void:
	var lim: int = Time.get_ticks_msec() + 4000
	while is_instance_valid(e) and e.global_position.z > zobj and Time.get_ticks_msec() < lim:
		await process_frame
	await process_frame


func _bola() -> void:
	for vista in ["juego", "cerca", "lado"]:
		var e: FuegoToy = _lab.call("fuego_param", 0)
		await process_frame
		_lab.call("viaja_param")
		await _seg(0.3)
		match vista:
			"juego":
				_cam_juego()
			"cerca":
				_cam(Vector3(1.5, 1.0, -3.0), Vector3(0, 0.75, -3.6))
			"lado":
				_cam(Vector3(0.0, 0.8, -3.6) + Vector3(2.6, 0.2, 0.0), Vector3(0, 0.75, -3.6))
		for intento in 6:                        # el lab devuelve la bola a la mano cada 6 m: si da la vuelta entre medias, se repite
			await _esperar_z(e, -3.2)
			await process_frame
			if e.global_position.z < -2.4:
				_guardar("bola_%s_%s" % [vista, _tag])
				if vista == "lado":
					_medir_bola(root.get_viewport().get_texture().get_image())
				break
		await _limpiar()


func _barrera() -> void:
	_lab.call("fuego_param", 3)
	await _seg(1.0)
	_cam_juego()
	await _seg(0.4)
	_guardar("barrera_juego_%s" % _tag)
	_cam(Vector3(3.0, 1.7, 3.6), Vector3(0, 0.9, 0))
	await _seg(0.4)
	_guardar("barrera_cerca_%s" % _tag)
	_cam(Vector3(0.0, 1.0, 4.2), Vector3(0, 0.9, 0))
	await _seg(0.3)
	_guardar("barrera_frente_%s" % _tag)
	await _limpiar()


func _haz() -> void:
	var e: FuegoToy = _lab.call("fuego_param", 4)
	await _seg(1.2)
	_cam(Vector3(3.5, 1.0, -1.7), Vector3(0, 0.55, -1.7))
	await _seg(0.5)
	_guardar("haz_lado_%s" % _tag)
	_cam_juego()
	await _seg(0.4)
	_guardar("haz_juego_%s" % _tag)
	_cam(Vector3(1.2, 1.1, 1.2), Vector3(0, 0.5, -1.8))
	await _seg(0.4)
	_guardar("haz_cerca_%s" % _tag)
	_cam(Vector3(3.5, 1.0, -1.7), Vector3(0, 0.55, -1.7))
	await _seg(0.2)
	e.call("morir")
	var t0: int = Time.get_ticks_msec()
	for t in [0.0, 0.15, 0.3, 0.5]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		await process_frame
		_guardar("haz_corte_%03d_%s" % [int(t * 1000.0), _tag])
	await _limpiar()


func _pilar() -> void:
	_lab.call("fuego_param", 2)
	await _seg(1.0)
	_cam_juego()
	await _seg(0.4)
	_guardar("pilar_juego_%s" % _tag)
	_cam(Vector3(1.3, 0.8, -1.6), Vector3(0, 0.3, -3.0))
	await _seg(0.4)
	_guardar("pilar_base_cerca_%s" % _tag)
	_cam(Vector3(0.0, 1.6, -0.6), Vector3(0, 0.1, -3.0))
	await _seg(0.4)
	_guardar("pilar_base_alta_%s" % _tag)
	await _limpiar()


## Secuencias a 12 fps (se mide con el reloj: el lab corre en tiempo real).
func _secuencias() -> void:
	# barrera: 2,5 s con la cámara cercana
	_lab.call("fuego_param", 3)
	_cam(Vector3(3.0, 1.7, 3.6), Vector3(0, 0.9, 0))
	await _seg(0.8)
	await _grabar("barrera", 30)
	await _limpiar()
	# haz: 0,8 s de chorro y luego el corte (2,5 s en total)
	var e: FuegoToy = _lab.call("fuego_param", 4)
	_cam(Vector3(3.5, 1.0, -1.7), Vector3(0, 0.55, -1.7))
	await _seg(0.2)
	await _grabar("haz", 30, 0.8, e)
	await _limpiar()


func _grabar(fig: String, n: int, corte_en: float = -1.0, e: Node = null) -> void:
	var t0: int = Time.get_ticks_msec()
	var cortado: bool = false
	for i in n:
		var t: float = float(i) / 12.0
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		if corte_en >= 0.0 and not cortado and t >= corte_en and is_instance_valid(e):
			e.call("morir")
			cortado = true
		await process_frame
		_guardar("%s_%02d" % [_tag, i], "seq_" + fig)


## Mide en una captura LATERAL de la bola en vuelo (va hacia la izquierda de la imagen): altura en píxeles del fuego en la columna más alta de la cabeza (el tercio derecho del fuego)
## frente a la columna más alta de la cola (el resto). «Fuego» = píxel naranja saturado (r > 190, r - b > 110) que el fondo (cielo, suelo, cubos) no tiene.
func _medir_bola(img: Image) -> void:
	var cols: Array = []
	for x in img.get_width():
		var n: int = 0
		for y in img.get_height():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.75 and c.r - c.b > 0.43 and c.g < 0.85 and c.g > 0.2:
				n += 1
		cols.append(n)
	var x0: int = -1
	var x1: int = -1
	for x in cols.size():
		if int(cols[x]) >= 3:
			if x0 < 0:
				x0 = x
			x1 = x
	if x0 < 0:
		print("MEDIDA bola: sin fuego")
		return
	var corte: int = x0 + int(float(x1 - x0) * 0.6)
	var m_cab: int = 0
	var m_cola: int = 0
	for x in range(x0, x1 + 1):
		if x >= corte:
			m_cab = maxi(m_cab, int(cols[x]))
		else:
			m_cola = maxi(m_cola, int(cols[x]))
	print("MEDIDA bola (%s): fuego de x %d a %d; ancho máx. de la cabeza (40 %% delantero) %d px, de la cola (60 %% trasero) %d px → cabeza/cola = %.2f" % [_tag, x0, x1, m_cab, m_cola, float(m_cab) / float(maxi(m_cola, 1))])

