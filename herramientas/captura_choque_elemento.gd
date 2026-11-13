extends SceneTree

## ¿SALE FUEGO EN EL CHOQUE DE OTRO ELEMENTO? (13/11/2026; Pablo: «todo vs muro da fuego»). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_choque_elemento.gd -- [carpeta] [elementos: fuego,viento,agua,rayo]
## En el LabVfxComparativa3D, para cada elemento (Z), lo mismo que con las teclas:
##   gas_esfera / gas_muro = Mayús+F12 (una vez = esfera, otra = muro): el haz de GAS 3D del elemento contra el obstáculo;
##   masa_muro / masa_esfera = F12 SIN Mayús (una vez = muro, otra = esfera): el haz TOY del elemento + la «masa de fuego» (HazMasaVista, prototipo del 9/11).
## A los 2 s escribe <carpeta>/<elemento>_<caso>.jpg e imprime los píxeles NARANJA DE FUEGO (H < 40° o > 340°, S > 0,65, V > 0,4) de la pantalla.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_elementos/choque_elemento/ahora"
var _elementos: PackedStringArray = ["fuego", "viento", "agua", "rayo"]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_elementos = a[1].split(",")
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = Vector2i(1280, 720)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(10)
	for elem in _elementos:
		lab.call("poner_elemento", elem)
		for caso in ["gas_esfera", "gas_muro", "masa_muro", "masa_esfera"]:
			lab.call("haz_gas", 0)
			lab.call("haz_masa", 0)
			lab.call("limpiar")
			await _esperar(5)
			if caso.begins_with("gas"):
				var g: HazGas = lab.call("haz_gas", 1 if caso == "gas_esfera" else 2)
				if g == null or not g.listo():
					print("FALLO: el gas no arranca (%s)" % elem)
					continue
				g.get_node("HudGas").visible = false
				while g.frame < 120:
					await process_frame
			else:
				lab.call("haz_masa", 1 if caso == "masa_muro" else 2)
				await _esperar_s(2.0)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_jpg(_dir.path_join("%s_%s.jpg" % [elem, caso]), 0.88)
			print("CHOQUE %-6s %-11s naranja de fuego %6d px" % [elem, caso, _naranja(img)])
	lab.call("haz_gas", 0)
	lab.call("haz_masa", 0)
	quit()


func _naranja(img: Image) -> int:
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			var h: float = c.h * 360.0
			if c.s > 0.65 and c.v > 0.4 and (h < 40.0 or h > 340.0):
				n += 1
	return n


func _esperar(n: int) -> void:
	for i in range(n):
		await process_frame


func _esperar_s(s: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame
