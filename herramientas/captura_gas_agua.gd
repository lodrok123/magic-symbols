extends SceneTree

## CAPTURAS DEL HAZ DE GAS EN MODO AGUA en el LabVfxComparativa3D (10/11/2026). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_agua.gd -- [carpeta] [segundos: 2]
## Es lo mismo que ve Pablo con Z (elemento AGUA) + Mayús+F12 (muro de prueba) / B (obstáculo) / C (cámara). Escribe <carpeta>/lab_<muro|esfera|nada>_<lateral|juego>.png.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_agua_gas"
var _seg: float = 2.0


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_seg = float(a[1])
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(10)
	lab.call("poner_elemento", "agua")
	for caso in [["muro", 2, "caja"], ["esfera", 1, "esfera"], ["nada", 2, "nada"]]:
		for vista in ["lateral", "juego"]:
			lab.call("haz_gas", 0)
			await _esperar(3)
			var cfg: Dictionary = HazGas.HAZ_REF.duplicate()
			cfg["obstaculo"] = caso[2]
			cfg["tam"] = 1.2 if caso[2] == "caja" else 0.8
			var g: HazGas = lab.call("haz_gas", caso[1], vista, true, cfg)
			if g == null or not g.listo():
				print("FALLO: el gas no arranca")
				quit(1)
				return
			g.get_node("HudGas").visible = false
			while g.frame < int(_seg * 60.0):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(_dir.path_join("lab_%s_%s.png" % [caso[0], vista]))
			print("captura lab_%s_%s  gpu %.2f ms (%s)" % [caso[0], vista, float(g.gpu_ms.get("total", 0.0)), g._texto_haz()])
	lab.call("haz_gas", 0)
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame
