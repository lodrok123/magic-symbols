extends SceneTree

## CAPTURA DE LA PRUEBA 3 (1/11, docs/PRUEBA3_VFX_TOY_2026-11-01.md §3): saca los PNG de los cinco efectos de fuego toy en el LabVfxComparativa3D con los nombres
## del diseño (bola_cerca, bola_juego, bola_vuelo, bola_impacto, muro_cerca, muro_juego, pilar_cerca, pilar_juego, barrera_cerca, barrera_juego, diez_muros).
## Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) pero no espera clics:
##   godot --path . --script res://herramientas/captura_vfx_toy.gd -- docs/capturas/comparativa_vfx/godot_toy [todo | bola | muro | pilar | barrera | diez]
## Secuencia de 3 s de un efecto con Movie Maker (a 24 fps; los PNG luego se juntan en GIF con herramientas/gif_desde_secuencia.py):
##   godot --path . --resolution 960x540 --write-movie E:/tmp/prueba3_godot/sec_bola/f.png --fixed-fps 24 --script res://herramientas/captura_vfx_toy.gd -- sec bola

const TAM: Vector2i = Vector2i(1600, 1000)
const TAM_1080: Vector2i = Vector2i(1920, 1080)

var _dir: String = "docs/capturas/comparativa_vfx/godot_toy"
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = "todo"
	var secuencia: bool = a.size() > 0 and a[0] == "sec"
	if secuencia:
		que = a[1] if a.size() > 1 else "bola"
	else:
		if a.size() > 0:
			_dir = a[0]
		if a.size() > 1:
			que = a[1]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	if not secuencia:
		root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	if a.size() > 2 and a[2] == "singlow":
		(_lab.get_node("Ambiente") as WorldEnvironment).environment.glow_enabled = false
	await _seg(0.4)
	if secuencia:
		await _secuencia(que)
		quit()
		return
	if que in ["todo", "bola"]:
		await _bola()
	if que in ["todo", "muro"]:
		await _simple("muro_toy", "muro")
	if que in ["todo", "pilar"]:
		await _simple("pilar_toy", "pilar")
	if que in ["todo", "barrera"]:
		await _simple("barrera_toy", "barrera")
	if que in ["todo", "diez"]:
		await _diez()
	print("CAPTURAS en " + _dir)
	quit()


func _secuencia(que: String) -> void:
	var clave: String = {"bola": "bola_toy", "vuelo": "bola_vuelo_toy", "muro": "muro_toy", "pilar": "pilar_toy", "barrera": "barrera_toy"}.get(que, "bola_toy")
	_lab.set("_panel_visible", false)
	_lab.call("efecto", clave)
	_lab.call("poner_camara", 1)
	await _seg(3.6)


func _bola() -> void:
	_lab.call("efecto", "bola_toy")
	await _seg(1.2)
	_lab.call("poner_camara", 1)
	await _seg(0.1)
	_guardar("bola_cerca.png")
	_lab.call("poner_camara", 0)
	await _seg(0.1)
	_guardar("bola_juego.png")
	_lab.call("limpiar")
	await _seg(0.3)
	_lab.call("poner_camara", 1)
	_lab.call("efecto", "bola_vuelo_toy")
	await _seg(0.4)
	_guardar("bola_vuelo.png")
	await _seg(0.55)            # cae a los 6 m: 0,75 s
	_guardar("bola_impacto.png")
	_lab.call("limpiar")
	await _seg(0.3)


func _simple(clave: String, nombre: String) -> void:
	_lab.call("efecto", clave)
	await _seg(1.4)
	_lab.call("poner_camara", 1)
	await _seg(0.1)
	_guardar(nombre + "_cerca.png")
	_lab.call("poner_camara", 0)
	await _seg(0.1)
	_guardar(nombre + "_juego.png")
	_lab.call("limpiar")
	await _seg(0.3)


func _diez() -> void:
	root.get_window().size = TAM_1080
	await _seg(0.3)
	_lab.call("poner_camara", 2)
	_lab.call("diez_muros", false, true)
	await _seg(3.0)
	var n: int = 0
	var suma: float = 0.0
	for k in 60:
		await process_frame
		suma += Engine.get_frames_per_second()
		n += 1
	var fps: float = suma / float(n)
	print("diez_muros fps=%.1f ventana=%s viewport=%s" % [fps, str(root.get_window().size), str(root.get_viewport().get_visible_rect().size)])
	var f: FileAccess = FileAccess.open(_dir.path_join("diez_muros_fps.txt"), FileAccess.WRITE)
	f.store_string("fps medios sobre 60 fotogramas: %.1f\nresolución de la ventana: %s\nGPU: %s\n" % [fps, str(root.get_window().size), RenderingServer.get_video_adapter_name()])
	f.close()
	_guardar("diez_muros.png")
	_lab.call("limpiar")


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)
