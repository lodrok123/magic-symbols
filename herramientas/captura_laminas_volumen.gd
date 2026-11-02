extends SceneTree

## CAPTURAS CON VENTANA de la revisión «las láminas se notan muy 2D» (rama fuego-toy-carga-impacto). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_laminas_volumen.gd -- docs/capturas/comparativa_vfx/godot_toy/laminas_volumen _antes|_despues [fps]
## `_antes` = FuegoToy.volumen = false (el estado del diario 311: bandas con fundido de canto, sin láminas Y-billboard); `_despues` = lo nuevo.
## Figuras: muro (largo en X), muro_eje (muro puesto a lo largo del eje de la cámara del juego), pilar, barrera, bola quieta y bola en vuelo.
## Cámaras: juego (ortogonal, 30° de elevación), az0 / az45 / az90 (perspectiva a 7° de elevación; en az90 se mira A LO LARGO del muro) y cerca (perspectiva a ~22°).
## Con el tercer argumento «fps» no captura: mide los fps con diez muros FuegoToy (dos filas, cámara del juego y cámara baja).

const TAM: Vector2i = Vector2i(1280, 720)

var _dir: String = "docs/capturas/comparativa_vfx/godot_toy/laminas_volumen"
var _lab: Node3D = null
var _sufijo: String = "_despues"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		_sufijo = a[1]
	FuegoToy.volumen = _sufijo != "_antes"
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
	if a.size() > 2 and a[2] == "ab":
		await _ab()
	elif a.size() > 2 and a[2] == "fps":
		await _fps()
	else:
		await _tomas()
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})
	_lab.call("poner_camara", 1)


func _juego() -> void:
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + _sufijo + ".png"))
	print("captura " + nombre + _sufijo)


func _limpiar() -> void:
	_lab.call("limpiar")
	await _seg(0.3)


func _poner(fig: int, x: float, y: float, z: float, pos: Vector3, viaja: bool = false) -> FuegoToy:
	var e: FuegoToy = FuegoToy.new()
	e.definir(fig, x, y, z, viaja)
	(_lab.get_node("Efectos") as Node3D).add_child(e)
	e.global_position = pos
	e.call("lanzar", -1.0)
	return e


## Pone la figura y devuelve [efecto, punto al que mira la cámara, distancia]
func _figura(caso: String, p0: Vector3) -> Array:
	match caso:
		"muro":
			var m: FuegoToy = _poner(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3, p0)
			m.look_at(m.global_position + Vector3(0, 0, 1), Vector3.UP)
			return [m, p0 + Vector3(0, 0.7, 0), 8.0]
		"muro_eje":
			var m2: FuegoToy = _poner(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3, p0)
			m2.look_at(m2.global_position + Vector3(1, 0, 0), Vector3.UP)      # el largo va a lo largo del eje de la cámara
			return [m2, p0 + Vector3(0, 0.7, 0), 8.0]
		"pilar":
			var pi: FuegoToy = _poner(FuegoToy.Figura.PILAR, 0.5, 4.0, 0.5, p0)
			return [pi, p0 + Vector3(0, 1.8, 0), 9.0]
		"barrera":
			var ba: FuegoToy = _poner(FuegoToy.Figura.BARRERA, 1.5, 1.5, 1.5, p0)
			return [ba, p0 + Vector3(0, 0.8, 0), 6.5]
		"vuelo":
			var vu: FuegoToy = _poner(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, p0 + Vector3(0, 0.55, 0), true)
			vu.look_at(vu.global_position + Vector3(1, 0, 0), Vector3.UP)
			return [vu, p0 + Vector3(0, 0.55, 0), 2.6]
	var bo: FuegoToy = _poner(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, p0 + Vector3(0, 0.55, 0))
	return [bo, p0 + Vector3(0, 0.55, 0), 2.4]


func _tomas() -> void:
	var casos: Array = ["muro", "muro_eje", "pilar", "barrera", "bola", "vuelo"]
	# [nombre, azimut (grados) o -1 = cámara del juego, elevación (grados), factor de distancia]
	var camaras: Array = [["juego", -1, 0, 1.0], ["az0", 0, 7, 1.0], ["az45", 45, 7, 1.0], ["az90", 90, 7, 1.0], ["cerca", 30, 22, 0.55]]
	for caso in casos:
		for cam in camaras:
			if (caso == "muro_eje") and (cam[0] != "juego" and cam[0] != "cerca"):
				continue             # el muro puesto de eje solo interesa con la cámara del juego y la cercana
			var pj: Vector3 = (_lab.get("_pj") as Node3D).global_position
			var p0: Vector3 = Vector3(pj.x, 0.0, pj.z) + Vector3(0, 0, -2.0)
			if caso in ["bola", "vuelo"]:
				p0 = Vector3(pj.x, 0.0, pj.z) + Vector3(4.0, 0, -3.0)         # lateral: las cámaras bajas y cercanas no se meten dentro del personaje
			var d: Array = _figura(caso, p0)
			var objetivo: Vector3 = d[1]
			var dist: float = float(d[2]) * float(cam[3])
			if int(cam[1]) < 0:
				_juego()
			else:
				var az: float = deg_to_rad(float(cam[1]))
				var el: float = deg_to_rad(float(cam[2]))
				_cam(objetivo + Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * dist, objetivo)
			await _seg(1.2)
			_guardar("%s_%s" % [caso, cam[0]])
			await _limpiar()


## Control de la cámara del juego: el mismo muro con y sin láminas, dos veces cada uno y en el mismo proceso (mide cuánto cambia el aspecto con la cámara del juego frente al azar de la animación).
func _ab() -> void:
	# Las animaciones dependen de TIME (el scroll de las lenguas repite cada ~2,9 s): dos tomas distintas caen en fases distintas y parecen «otro fuego». Por eso van JUNTOS en el mismo
	# fotograma: el muro de delante CON láminas (volumen = true) y el de detrás SIN ellas.
	var pj: Vector3 = (_lab.get("_pj") as Node3D).global_position
	for caso in ["muro", "muro_eje"]:
		for v in [true, false]:
			FuegoToy.volumen = v
			var e: FuegoToy = FuegoToy.new()
			e.definir(FuegoToy.Figura.MURO, 2.2 if caso == "muro" else 3.45, 1.5, 0.3)
			(_lab.get_node("Efectos") as Node3D).add_child(e)
			var dx: float = (-2.4 if v else 2.4) if caso == "muro" else (-1.5 if v else 4.0)
			e.global_position = Vector3(pj.x + dx, 0.0, pj.z - 2.0)
			e.look_at(e.global_position + (Vector3(0, 0, 1) if caso == "muro" else Vector3(1, 0, 0)), Vector3.UP)
			e.call("lanzar", -1.0)
		_juego()
		await _seg(1.5)
		_guardar("ab_%s_con_delante_sin_detras" % caso)
		await _limpiar()


## Diez muros FuegoToy (dos filas de cinco) y la media de fps en unos segundos. Cámara del juego y cámara baja.
func _fps() -> void:
	var ef: Node3D = _lab.get_node("Efectos") as Node3D
	var pj: Vector3 = (_lab.get("_pj") as Node3D).global_position
	for i in 10:
		var e: FuegoToy = FuegoToy.new()
		e.definir(FuegoToy.Figura.MURO, 3.45, 1.5, 0.3)
		ef.add_child(e)
		e.global_position = Vector3(pj.x - 7.0 + float(i % 5) * 3.5, 0.0, pj.z - 6.0 + float(i / 5) * 5.0)
		e.rotation_degrees = Vector3(0, 90.0, 0)
		e.call("lanzar", 60.0)
	var n_mi: int = ef.find_children("*", "MeshInstance3D", true, false).size() + ef.find_children("*", "MultiMeshInstance3D", true, false).size()
	var n_gp: int = ef.find_children("*", "GPUParticles3D", true, false).size()
	print("FPS_NODOS mallas+multimallas %d · partículas %d" % [n_mi, n_gp])
	for cam in ["juego", "baja"]:
		if cam == "juego":
			_juego()
		else:
			_cam(Vector3(pj.x + 14.0, 1.0, pj.z - 3.0), Vector3(pj.x, 0.8, pj.z - 3.0))
		await _seg(1.5)
		var t0: int = Time.get_ticks_msec()
		var f0: int = Engine.get_process_frames()
		await _seg(5.0)
		var seg: float = float(Time.get_ticks_msec() - t0) / 1000.0
		print("FPS%s %s: %.1f fps (%d fotogramas en %.1f s) · draw calls %d · objetos %d" % [_sufijo, cam, float(Engine.get_process_frames() - f0) / seg, Engine.get_process_frames() - f0, seg,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	_guardar("fps_diez_muros")
