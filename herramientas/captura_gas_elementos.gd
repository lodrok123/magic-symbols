extends SceneTree

## CAPTURAS DEL HAZ DE GAS EN MODO AGUA, VIENTO y RAYO en el LabVfxComparativa3D (11/11/2026). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_elementos.gd -- [carpeta] [elementos: viento,rayo,agua] [segundos: 2] [casos: muro,esfera,nada] [vistas: lateral,juego]
## Es lo que se ve con Z (hasta el elemento) + Mayús+F12 / B (obstáculo) / C (cámara). Escribe <carpeta>/<elemento>_<muro|esfera|nada>_<lateral|juego>.png
## y, con el chorro recién cortado (0,25 s después), <...>_corte.png.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_elementos"
var _elementos: PackedStringArray = ["viento", "rayo", "agua"]
var _seg: float = 2.0
var _casos: PackedStringArray = ["muro", "esfera", "nada"]
var _vistas: PackedStringArray = ["lateral", "juego"]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_elementos = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_seg = float(a[2])
	if a.size() > 3 and a[3] != "":
		_casos = a[3].split(",")
	if a.size() > 4 and a[4] != "":
		_vistas = a[4].split(",")
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().mode = Window.MODE_WINDOWED          # 11/11: a veces se abría maximizada (2560 × 1369) y el coste del volumen cambiaba
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(10)
	var tipos: Dictionary = {"muro": [2, "caja", 1.2], "esfera": [1, "esfera", 0.8], "nada": [2, "nada", 0.8]}
	for elem in _elementos:
		lab.call("poner_elemento", elem)
		for caso in _casos:
			for vista in _vistas:
				lab.call("haz_gas", 0)
				await _esperar(3)
				var cfg: Dictionary = HazGas.HAZ_REF.duplicate()
				cfg["obstaculo"] = tipos[caso][1]
				cfg["tam"] = tipos[caso][2]
				var g: HazGas = lab.call("haz_gas", tipos[caso][0], vista, true, cfg)
				if g == null or not g.listo():
					print("FALLO: el gas no arranca (%s)" % elem)
					quit(1)
					return
				g.get_node("HudGas").visible = false
				while g.frame < int(_seg * 60.0):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s_%s.png" % [elem, caso, vista]))
				var ms: float = float(g.gpu_ms.get("total", 0.0))
				print("captura %s_%s_%s  gpu %.2f ms (sim %.2f · volumen %.2f) · %.0f fps desde 60 · %.0f desde 120 · pantalla %s (%s)" % [elem, caso, vista, ms,
					float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)) + float(g.gpu_ms.get("chispas", 0.0)) + float(g.gpu_ms.get("luz", 0.0)),
					float(g.gpu_ms.get("volumen", 0.0)), 1000.0 / (1000.0 / 60.0 + ms), 1000.0 / (1000.0 / 120.0 + ms), str(root.get_viewport().get_texture().get_size()), g._texto_haz()])
				g.chorro(false)
				var f0: int = g.frame
				while g.frame < f0 + 15:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s_%s_corte.png" % [elem, caso, vista]))
	lab.call("haz_gas", 0)
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame
