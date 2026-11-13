extends SceneTree

## SECUENCIA AL SOLTAR EL HAZ DE GAS DE VIENTO en el LabVfxComparativa3D (13/11/2026; Pablo: «al soltarlo se rompe en demasiados trozos y algo recortados»). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_viento_soltar.gd -- [carpeta] [escalas: 0.5,1.0] [casos: nada,muro] [vistas: lateral,juego]
## Es lo que se ve con Z (VIENTO) + Mayús+F12 / B (obstáculo) / C (cámara) / E (básico ↔ máximo) y ESPACIO (soltar). Por cada combinación, 2 s de chorro y luego
## fotos a los TIEMPOS_MS de soltarlo: <carpeta>/k<escala>_<caso>_<vista>_<ms>.jpg (0 = justo antes de soltar) y su opacidad <...>_a.png. Hoja y medidas:
## python herramientas/hoja_viento_soltar.py. Al final imprime el coste (ms de GPU) con el chorro
## puesto y durante la disolución.

const TIEMPOS_MS: PackedInt32Array = [0, 100, 200, 300, 400, 500, 650, 800]
var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_elementos/viento_soltar/ahora"
var _escalas: PackedFloat32Array = [0.5, 1.0]
var _casos: PackedStringArray = ["nada", "muro"]
var _vistas: PackedStringArray = ["lateral", "juego"]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_escalas = PackedFloat32Array(Array(a[1].split(",")).map(func(s: String) -> float: return float(s)))
	if a.size() > 2 and a[2] != "":
		_casos = a[2].split(",")
	if a.size() > 3 and a[3] != "":
		_vistas = a[3].split(",")
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(10)
	lab.call("poner_elemento", "viento")
	var tipos: Dictionary = {"muro": [2, "caja", 1.2], "esfera": [1, "esfera", 0.8], "nada": [2, "nada", 0.8]}
	for k in _escalas:
		for caso in _casos:
			for vista in _vistas:
				lab.call("haz_gas", 0)
				await _esperar(3)
				var cfg: Dictionary = HazGas.HAZ_REF.duplicate()
				cfg["obstaculo"] = tipos[caso][1]
				cfg["tam"] = tipos[caso][2]
				cfg["escala"] = k
				cfg["ancho"] = float(HazGas.HAZ_REF["ancho"]) * k
				var g: HazGas = lab.call("haz_gas", tipos[caso][0], vista, true, cfg)
				if g == null or not g.listo():
					print("FALLO: el gas no arranca")
					quit(1)
					return
				g.get_node("HudGas").visible = false
				var on_ms: Array = []
				while g.frame < 120:
					await process_frame
					if g.frame > 90:
						on_ms.append(float(g.gpu_ms.get("total", 0.0)))
				var nombre: String = "k%.1f_%s_%s" % [k, caso, vista]
				await _foto(g, "%s_%03d" % [nombre, 0])
				g.chorro(false)
				var f0: int = g.frame
				var off_ms: Array = []
				for ms in TIEMPOS_MS:
					if ms == 0:
						continue
					while g.frame < f0 + int(round(ms * 0.06)):
						await process_frame
						off_ms.append(float(g.gpu_ms.get("total", 0.0)))
					await _foto(g, "%s_%03d" % [nombre, ms])
				print("COSTE %s  encendido %.3f ms · soltando %.3f ms" % [nombre, _media(on_ms), _media(off_ms)])
	lab.call("haz_gas", 0)
	quit()


## Guarda la foto de la pantalla y la OPACIDAD del volumen (1 - lo que queda del fondo, del raymarch a media resolución) en gris: <nombre>.jpg y <nombre>_a.png.
## Con la opacidad se cuentan los trozos y se mide lo duro del borde sin que cuente el fondo del lab (herramientas/hoja_viento_soltar.py).
func _foto(g: HazGas, nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_jpg(_dir.path_join(nombre + ".jpg"), 0.88)
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if not g.efecto._crudo.is_valid():
		return
	# la opacidad se mide solo con los TRAZOS: sin el polvo ni el brillo de la mano (solo dibujo: con la simulación en pausa, el gas es el mismo de la foto)
	g.pausa = true
	var tv0: Dictionary = g.toon_viento.duplicate()
	g.toon_viento["polvo"] = 0.0
	g.toon_viento["mano"] = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	g.toon_viento = tv0
	g.pausa = false
	var tv: Vector2i = g.efecto._tam_vol
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var img: Image = Image.create(tv.x, tv.y, false, Image.FORMAT_L8)
	for y in tv.y:
		for x in tv.x:
			img.set_pixel(x, y, Color.from_hsv(0.0, 0.0, clampf(1.0 - datos.decode_half((y * tv.x + x) * 8 + 6), 0.0, 1.0)))
	img.save_png(_dir.path_join(nombre + "_a.png"))


func _media(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s: float = 0.0
	for x in v:
		s += float(x)
	return s / float(v.size())


func _esperar(n: int) -> void:
	for i in range(n):
		await process_frame
