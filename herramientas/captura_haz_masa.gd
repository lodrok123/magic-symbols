extends SceneTree

## CAPTURAS del prototipo de la MASA DE FUEGO del haz en el LabVfxComparativa3D (NECESITA VENTANA):
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_haz_masa.gd -- [carpeta] [casos: actual,muro,esfera] [vistas: lateral,juego]
## «actual» = el haz de ahora contra el muro de la tecla F; «muro» / «esfera» = F12 (masa). Escribe <carpeta>/<caso>_<vista>_<t>.png con t = 020, 060, 120 (s tras lanzar) y «apagado» (1 s tras quitar el haz).

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_fuego_masa"
var _casos: PackedStringArray = ["actual", "muro", "esfera"]
var _vistas: PackedStringArray = ["lateral", "juego"]
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_vistas = a[2].split(",")
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	await _esperar(20)
	for caso in _casos:
		for vista in _vistas:
			_lab.call("limpiar")
			await _esperar(30)
			_lab.set("_muro_haz_activo", false)
			_lab.set("_obst_esfera", false)
			var pie: Vector3 = (_lab.get("_pj") as Node3D).global_position
			if vista == "lateral":
				_lab.set("camara_fija", {"desde": pie + Vector3(5.2, 1.7, -1.6), "mira": pie + Vector3(0.0, 0.9, -1.7)})
				_lab.call("poner_camara", 1)
			else:
				_lab.set("camara_fija", {})
				_lab.call("poner_camara", 0)
			if caso == "actual":
				_lab.call("alternar_muro_haz")
				_lab.call("fuego_param", 4)
			else:
				_lab.call("haz_masa", 1 if caso == "muro" else 2)
			var t0: int = Time.get_ticks_msec()
			for t in [0.2, 0.6, 1.2, 2.4]:
				while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
					await process_frame
				await RenderingServer.frame_post_draw
				_guardar("%s_%s_%03d.png" % [caso, vista, int(t * 100.0)])
			# apagarse: quitar el haz (la masa sigue un rato y se deshace)
			_lab.call("_quitar_param")
			await _esperar(60)
			await RenderingServer.frame_post_draw
			_guardar("%s_%s_apagado.png" % [caso, vista])
	print("CAPTURAS en " + _dir)
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)
