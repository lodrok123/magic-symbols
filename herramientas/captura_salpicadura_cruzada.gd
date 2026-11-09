extends SceneTree

## CAPTURA (9/11/2026): la salpicadura del haz de fuego contra el muro del lab (F7 x5 = haz, F = muro), vista de LADO (perpendicular al haz) y con la cámara del juego. NECESITA VENTANA.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_salpicadura_cruzada.gd -- <carpeta> <prefijo: antes|despues>
## Escribe <carpeta>/<prefijo>_lado_<t>.png y <prefijo>_juego_<t>.png (t = 0,9 y 1,6 s tras lanzar).

var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = ProjectSettings.globalize_path("res://" + (a[0] if a.size() > 0 else "docs/capturas/vfx_en_juego/haz_fuego_ideas/salpicadura_cruzada"))
	var pre: String = a[1] if a.size() > 1 else "despues"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	await _esperar(20)
	_lab.call("alternar_muro_haz")
	var e: Node3D = _lab.call("fuego_param", 4) as Node3D
	var p: Vector3 = Vector3.ZERO
	for k in [0.9, 1.6]:
		await _esperar(int(60.0 * (float(k) - (0.0 if k == 0.9 else 0.9))))
		var t: String = "%03d" % int(round(float(k) * 100.0))
		if p == Vector3.ZERO:
			var ch: Dictionary = (e.get("choques") as Array)[0] as Dictionary
			p = e.global_transform * Vector3(float(ch["x"]), 1.0, -float(ch["d"]))
			print("choque en ", p)
		_lab.set("camara_fija", {"desde": p + Vector3(3.2, 0.7, 0.0), "mira": p + Vector3(0, 0.6, 0.0)})
		_lab.call("poner_camara", 1)
		await _esperar(3)
		_guardar(dir, "%s_lado_%s.png" % [pre, t])
		_lab.set("camara_fija", {})
		_lab.call("poner_camara", 0)
		await _esperar(3)
		_guardar(dir, "%s_juego_%s.png" % [pre, t])
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame


func _guardar(dir: String, nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(nombre))
	print("captura " + nombre)