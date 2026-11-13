extends SceneTree

## ¿EL CHOQUE DEL VIENTO ENVUELVE EL OBSTÁCULO O SE AMONTONA DELANTE? (13/11/2026; Pablo: «los jirones se aglutinan delante, deberían envolver el elemento»).
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_choque_envuelve.gd -- [carpeta] [escalas: 0.5,1.0] [casos: esfera,muro] [vistas: lateral,juego]
## LabVfxComparativa3D con el gas de VIENTO (Z hasta VIENTO + Mayús+F12; B obstáculo, E básico / máximo, C cámara). A los 2 s de chorro escribe
## <carpeta>/k<escala>_<caso>_<vista>.jpg, la OPACIDAD de los trazos (sin polvo ni brillo de la mano) en <...>_a.png y, en <carpeta>/medidas.json, dónde cae el
## obstáculo en esa opacidad (centro, radio en píxeles, la cara delantera y el eje del haz en la pantalla): herramientas/hoja_choque_envuelve.py lo mide.

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_elementos/choque_envuelve/ahora"
var _escalas: PackedFloat32Array = [0.5, 1.0]
var _casos: PackedStringArray = ["esfera", "muro"]
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
	var medidas: Dictionary = {}
	var tipos: Dictionary = {"muro": [2, "caja", 1.2], "esfera": [1, "esfera", 0.8]}
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
				var ms: Array = []
				while g.frame < 120:
					await process_frame
					if g.frame > 90:
						ms.append(float(g.gpu_ms.get("total", 0.0)))
				var nombre: String = "k%.1f_%s_%s" % [k, caso, vista]
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_jpg(_dir.path_join(nombre + ".jpg"), 0.9)
				await _alfa(g, nombre)
				medidas[nombre] = _obstaculo_en_pantalla(g)
				var m: float = 0.0
				for x in ms:
					m += float(x)
				medidas[nombre]["gpu_ms"] = m / maxf(ms.size(), 1.0)
				print("COSTE %s  %.3f ms" % [nombre, medidas[nombre]["gpu_ms"]])
	var f: FileAccess = FileAccess.open(_dir.path_join("medidas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(medidas, "  "))
	f.close()
	lab.call("haz_gas", 0)
	quit()


## La opacidad de los trazos (como prueba_haz_gas_viento_rayo.alfa_viento): un fotograma en pausa sin polvo ni mano.
func _alfa(g: HazGas, nombre: String) -> void:
	g.pausa = true
	var tv0: Dictionary = g.toon_viento.duplicate()
	g.toon_viento["polvo"] = 0.0
	g.toon_viento["mano"] = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	g.toon_viento = tv0
	g.pausa = false
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tv: Vector2i = g.efecto._tam_vol
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var img: Image = Image.create(tv.x, tv.y, false, Image.FORMAT_L8)
	for y in tv.y:
		for x in tv.x:
			img.set_pixel(x, y, Color.from_hsv(0.0, 0.0, clampf(1.0 - datos.decode_half((y * tv.x + x) * 8 + 6), 0.0, 1.0)))
	img.save_png(_dir.path_join(nombre + "_a.png"))


## Centro, radio, cara delantera y mano del obstáculo, proyectados a la imagen de opacidad (media resolución).
func _obstaculo_en_pantalla(g: HazGas) -> Dictionary:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var tv: Vector2i = g.efecto._tam_vol
	var esc: Vector2 = Vector2(tv) / root.get_viewport().get_visible_rect().size
	var noz: Vector3 = g.global_transform * (g.params["nozzle"] as Vector3)
	var c_d: Vector3
	var r_d: float
	var cara_d: float
	if g.obstaculo == "esfera":
		c_d = g.params["shieldC"]
		r_d = float(g.params["shieldR"])
		cara_d = r_d
	else:
		c_d = g.muro_c
		r_d = maxf(g.muro_h.y, g.muro_h.z)
		cara_d = g.muro_h.x
	var c: Vector3 = g.global_transform * c_d
	var d: Vector3 = (c - noz).normalized()
	var sm: float = g.metros_por_unidad
	var cara: Vector3 = c - d * cara_d * sm
	var arriba: Vector3 = c + Vector3.UP * r_d * sm
	var p_c: Vector2 = cam.unproject_position(c) * esc
	return {"centro": [p_c.x, p_c.y], "radio": (cam.unproject_position(arriba) * esc).distance_to(p_c),
		"cara": [(cam.unproject_position(cara) * esc).x, (cam.unproject_position(cara) * esc).y],
		"mano": [(cam.unproject_position(noz) * esc).x, (cam.unproject_position(noz) * esc).y], "tam": [tv.x, tv.y]}


func _esperar(n: int) -> void:
	for i in range(n):
		await process_frame
