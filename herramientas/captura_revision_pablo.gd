extends SceneTree

## CAPTURAS CON VENTANA de la revisión de Pablo (rama fuego-toy-carga-impacto). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_revision_pablo.gd -- docs/capturas/comparativa_vfx/godot_toy/revision_pablo [bola | laminas | impacto | carga | todo]
## · bola:    la bola aprobada de la ronda 8 (BolaFuegoToy.tscn) y la FuegoToy de hoy (nacida por defecto, tras la carga, y soltada), lado a lado con la MISMA cámara.
## · laminas: bola quieta, bola en vuelo, muro, pilar e impacto con cámara del juego, cercana y HORIZONTAL (a ras de suelo, ~7° de elevación).
## · impacto: golpe + chispas en pared y suelo a 0,03 / 0,1 / 0,25 / 0,5 s con cámara del juego y cercana.
## · carga:   5 fotogramas de la carga (brillo + chispas junto a la mano) y el soltar.

const TAM: Vector2i = Vector2i(1280, 720)
const T_IMPACTO: Array = [0.03, 0.1, 0.25, 0.5]

var _dir: String = "docs/capturas/comparativa_vfx/godot_toy/revision_pablo"
var _lab: Node3D = null
var _sufijo: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = "todo"
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		que = a[1]
	if a.size() > 2:
		_sufijo = a[2]
		if _sufijo == "_antes":
			FuegoToy.suavizado = false          # láminas «antes»: sin fundido de canto ni fundido contra la geometría
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_camara", 1)
	await _seg(0.6)
	if que in ["todo", "bola"]:
		await _bola()
	if que in ["todo", "ciclo"]:
		await _ciclo()
	if que in ["todo", "laminas"]:
		await _laminas()
	if que in ["todo", "impacto"]:
		await _impacto()
	if que in ["todo", "carga"]:
		await _carga()
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})
	_lab.call("poner_camara", 1)


func _limpiar() -> void:
	_lab.call("limpiar")
	await _seg(0.3)


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + _sufijo + ".png"))
	print("captura " + nombre + _sufijo)


func _etiqueta(padre: Node3D, texto: String, y: float) -> void:
	var l: Label3D = Label3D.new()
	l.text = texto
	l.font_size = 30
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1, 1, 1)
	l.outline_size = 10
	l.position = Vector3(0, y, 0)
	padre.add_child(l)


func _efectos() -> Node3D:
	return _lab.get_node("Efectos") as Node3D


# ------------------------------------------------------------------ bola: ronda 8 vs hoy ------------------------------------------------------------------

func _bolas(vuelo: bool) -> void:
	var ef: Node3D = _efectos()
	var base: Vector3 = Vector3(0, 1.0, -1.6)
	# A: la escena aprobada
	var a: Node3D = (load("res://presentacion/vfx/toy/BolaFuegoToy.tscn") as PackedScene).instantiate() as Node3D
	ef.add_child(a)
	a.global_position = base + Vector3(-1.5, 0, 0)
	if vuelo:
		a.set("proyectil", true)
	a.call("lanzar", -1.0)
	_etiqueta(a, "ronda 8 (BolaFuegoToy.tscn)", 0.9)
	# B: FuegoToy tal cual nace
	var b: FuegoToy = FuegoToy.new()
	ef.add_child(b)
	b.global_position = base
	if vuelo:
		b.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	b.call("lanzar", -1.0)
	_etiqueta(b, "FuegoToy nace", 0.9)
	# C: FuegoToy tras carga (y soltada si vuelo)
	var c: FuegoToy = FuegoToy.new()
	ef.add_child(c)
	c.global_position = base + Vector3(1.5, 0, 0)
	c.empezar_carga(0.3, 0.4)
	_etiqueta(c, "FuegoToy tras carga" + (" + soltar" if vuelo else ""), 0.9)
	await _seg(1.0)
	if vuelo:
		c.soltar(Vector3(1, 0, 0))
		b.look_at(b.global_position + Vector3(1, 0, 0), Vector3.UP)
		a.look_at(a.global_position + Vector3(1, 0, 0), Vector3.UP)
	await _seg(0.6)


func _bola() -> void:
	_cam(Vector3(0, 1.3, 2.4), Vector3(0, 1.0, -1.6))
	await _bolas(false)
	_guardar("bola_comparativa_quieta_cerca")
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.2)
	_guardar("bola_comparativa_quieta_juego")
	_lab.call("poner_camara", 1)
	await _limpiar()
	_cam(Vector3(0, 1.3, 2.4), Vector3(0, 1.0, -1.6))
	await _bolas(true)
	_guardar("bola_comparativa_vuelo_cerca")
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.2)
	_guardar("bola_comparativa_vuelo_juego")
	await _limpiar()


# ------------------------------------------------------------------ láminas ------------------------------------------------------------------

func _poner_fuego(fig: int, x: float, y: float, z: float, pos: Vector3, viaja: bool = false) -> FuegoToy:
	var e: FuegoToy = FuegoToy.new()
	e.definir(fig, x, y, z, viaja)
	_efectos().add_child(e)
	e.global_position = pos
	e.call("lanzar", -1.0)
	return e


func _laminas() -> void:
	# cámaras: [nombre, desde, mira]; "juego" = null
	var camaras: Array = [["juego", null, null], ["cerca", Vector3(1.6, 1.2, 3.0), Vector3(0, 0.9, 0)], ["horizontal", Vector3(0.0, 0.35, 3.4), Vector3(0, 0.6, 0)]]
	var casos: Array = ["bola", "vuelo", "muro", "pilar"]
	for caso in casos:
		for cam in camaras:
			var pj: Vector3 = (_lab.get("_pj") as Node3D).global_position
			var p0: Vector3 = Vector3(pj.x, 0.0, pj.z) + Vector3(0, 0, -2.0)
			match caso:
				"bola":
					_poner_fuego(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, p0 + Vector3(0, 0.55, 0))
				"vuelo":
					var e: FuegoToy = _poner_fuego(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, p0 + Vector3(0, 0.55, 0), true)
					e.look_at(e.global_position + Vector3(1, 0, 0), Vector3.UP)
				"muro":
					var m: FuegoToy = _poner_fuego(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3, p0)
					m.look_at(m.global_position + Vector3(0, 0, 1), Vector3.UP)
				"pilar":
					_poner_fuego(FuegoToy.Figura.PILAR, 0.5, 4.0, 0.5, p0)
			if cam[1] == null:
				_lab.set("camara_fija", {})
				_lab.call("poner_camara", 0)
			else:
				_cam(p0 + (cam[1] as Vector3) * (1.0 if caso != "pilar" else 1.8) + Vector3(0, 0, 0), p0 + (cam[2] as Vector3) * (1.0 if caso != "pilar" else 2.2))
			await _seg(1.1)
			_guardar("laminas_%s_%s" % [caso, cam[0]])
			await _limpiar()


# ------------------------------------------------------------------ impacto ------------------------------------------------------------------

func _impacto() -> void:
	for sup in ["pared", "suelo"]:
		for cam in ["cercana", "juego"]:
			var imp: Node3D = _lab.call("impacto_pared") if sup == "pared" else _lab.call("impacto_suelo")
			var punto: Vector3 = imp.global_position
			if cam == "juego":
				_lab.set("camara_fija", {})
				_lab.call("poner_camara", 0)
			elif sup == "pared":
				_cam(punto + Vector3(2.0, 1.0, 1.9), punto + Vector3(0, 0.2, 0.3))
			else:
				_cam(punto + Vector3(1.8, 1.0, 1.8), punto + Vector3(0, 0.25, 0))
			await process_frame
			for t in T_IMPACTO:
				while is_instance_valid(imp) and imp.call("tiempo") < t:
					await process_frame
				_guardar("impacto_%s_%s_%03d" % [sup, cam, int(t * 1000.0)])
			await _limpiar()


# ------------------------------------------------------------------ carga y soltar ------------------------------------------------------------------

func _carga() -> void:
	var pie: Vector3 = (_lab.get("_pj") as Node3D).global_position
	var mano: Vector3 = pie + Vector3(0, 0.7, 0) + Vector3(0, 0, -1) * 0.5
	_cam(mano + Vector3(1.1, 0.35, 2.4), mano + Vector3(0, 0.05, 0))
	await _seg(0.3)
	var e: FuegoToy = _lab.call("carga_completa")
	var t0: int = Time.get_ticks_msec()
	for t in [0.1, 0.4, 0.75, 1.1, 1.5]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_guardar("carga_%03d" % int(t * 1000.0))
	while is_instance_valid(e) and not e.proyectil:
		await process_frame
	var ts: int = Time.get_ticks_msec()
	for t in [0.03, 0.12, 0.3]:
		while float(Time.get_ticks_msec() - ts) / 1000.0 < t:
			await process_frame
		_guardar("soltar_%03d" % int(t * 1000.0))
	await _limpiar()
	# cámara del juego
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.3)
	_lab.call("carga_completa")
	t0 = Time.get_ticks_msec()
	for t in [0.4, 1.1, 1.5]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_guardar("carga_juego_%03d" % int(t * 1000.0))
	await _limpiar()


## La bola aprobada (BolaFuegoToy.tscn en vuelo) y la FuegoToy cargada y soltada, volando juntas a 8 m/s, con la cámara pegada a ellas: se ve si la bola cambia al soltar.
func _ciclo() -> void:
	var ef: Node3D = _efectos()
	var pie: Vector3 = (_lab.get("_pj") as Node3D).global_position
	var mano: Vector3 = pie + Vector3(0, 0.9, 0)
	var a: Node3D = (load("res://presentacion/vfx/toy/BolaFuegoToy.tscn") as PackedScene).instantiate() as Node3D
	ef.add_child(a)
	a.global_position = mano + Vector3(-0.9, 0, 0)
	a.set("proyectil", true)
	a.look_at(a.global_position + Vector3(0, 0, -1), Vector3.UP)
	a.call("lanzar", -1.0)
	var c: FuegoToy = FuegoToy.new()
	ef.add_child(c)
	c.global_position = mano + Vector3(0.9, 0, 0)
	c.look_at(c.global_position + Vector3(0, 0, -1), Vector3.UP)
	c.empezar_carga(0.3, 0.4)
	var t0: int = Time.get_ticks_msec()
	var ult: int = t0
	var soltada: bool = false
	var ts: int = 0
	var objetivos: Array = [0.05, 0.15, 0.4, 0.8]
	var i: int = 0
	while i < objetivos.size():
		await process_frame
		var ahora: int = Time.get_ticks_msec()
		var dt: float = float(ahora - ult) / 1000.0
		ult = ahora
		var t: float = float(ahora - t0) / 1000.0
		if not soltada and t >= 0.5:
			soltada = true
			ts = ahora
			c.soltar(Vector3(0, 0, -1))
		if soltada:
			a.global_position += Vector3(0, 0, -8.0) * dt
			c.global_position += Vector3(0, 0, -8.0) * dt
			var mid: Vector3 = (a.global_position + c.global_position) * 0.5
			_cam(mid + Vector3(1.0, 0.45, 2.6), mid)
			if float(ahora - ts) / 1000.0 >= float(objetivos[i]):
				_guardar("ciclo_vuelo_%03d" % int(float(objetivos[i]) * 1000.0))
				i += 1
		else:
			_cam(mano + Vector3(1.0, 0.45, 2.6), mano)
	await _limpiar()