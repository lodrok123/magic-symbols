extends SceneTree

## CAPTURAS DEL HUMO DE MAGMA POR REGLA Y DE LAS CHISPAS TIPO REPO (11/11/2026). NECESITA VENTANA. Antes / después con la cámara del JUEGO del lab (ortogonal, 30° de elevación):
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_magma_chispas.gd -- [carpeta] [casos separados por comas]
## «antes» = HumoRegla «magma» y ChispasRepo todas apagadas (el dibujo de siempre); «después» = encendidas. Escribe <carpeta>/<caso>_<antes|despues>.png y HOJA_RESUMEN.png.
## Casos: crater_magma (Z = magma, N), muro_magma (F7 muro), bola_magma (G), impacto_rayo (Z = rayo, N), pilar_rayo (F7 pilar), electrificado («,»).
## Modelo: herramientas/captura_humo_regla.gd.

const LAB: String = "res://laboratorios/LabVfxComparativa3D.tscn"

var _dir: String = "res://docs/capturas/vfx_en_juego/magma_chispas"
var _casos: PackedStringArray = ["crater_magma", "muro_magma", "impacto_rayo", "electrificado"]
var lab: Node3D = null
var _fotos: Array = []           ## [[caso, ruta antes, ruta después]]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	await process_frame
	lab = (load(LAB) as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	lab.set("_panel_visible", false)
	for caso in _casos:
		var r: Array = [caso]
		for modo in ["antes", "despues"]:
			r.append(await _toma(caso, modo))
		_fotos.append(r)
	await _hoja(_dir.path_join("HOJA_RESUMEN.png"))
	HumoRegla.capas = HumoRegla.DE_SERIE.duplicate()
	ChispasRepo.de_serie()
	print("escrito ", _dir)
	quit(0)


## {cam (tamaño), foco, crop (px), t (s desde que se lanza)}
func _def(caso: String) -> Dictionary:
	var pj: Vector3 = (lab.get("_pj") as Node3D).global_position
	var dir: Vector3 = lab.get("_dir")
	match caso:
		"crater_magma":
			return {"cam": 6.0, "foco": pj + dir * 3.0 + Vector3(0, 0.8, 0), "crop": Vector2i(900, 506), "t": 0.75}
		"muro_magma":
			return {"cam": 8.0, "foco": pj + dir * 3.0 + Vector3(0, 1.8, 0), "crop": Vector2i(1000, 562), "t": 2.4}
		"bola_magma":
			return {"cam": 9.0, "foco": pj + dir * 3.5 + Vector3(0, 0.8, 0), "crop": Vector2i(1000, 562), "t": 2.75}
		"impacto_rayo":
			return {"cam": 5.0, "foco": pj + dir * 3.0 + Vector3(0, 0.5, 0), "crop": Vector2i(800, 450), "t": 0.35}
		"pilar_rayo":
			return {"cam": 12.0, "foco": pj + dir * 3.0 + Vector3(0, 2.5, 0), "crop": Vector2i(800, 600), "t": 0.9}
		"electrificado":
			return {"cam": 6.0, "foco": pj + dir * 3.0 + dir.cross(Vector3.UP).normalized() * 0.9 + Vector3(0, 0.7, 0), "crop": Vector2i(900, 506), "t": 1.0}
	return {}


func _lanzar(caso: String) -> void:
	match caso:
		"crater_magma":
			lab.call("poner_elemento", "magma")
			lab.call("impacto_suelo")
		"muro_magma":
			lab.call("poner_elemento", "magma")
			lab.call("fuego_param", 1)
		"bola_magma":
			lab.call("poner_elemento", "magma")
			lab.call("carga_completa")
		"impacto_rayo":
			lab.call("poner_elemento", "rayo")
			lab.call("impacto_suelo")
		"pilar_rayo":
			lab.call("poner_elemento", "rayo")
			lab.call("fuego_param", 2)
		"electrificado":
			lab.call("electrificar")


func _toma(caso: String, modo: String) -> String:
	var d: Dictionary = _def(caso)
	lab.call("limpiar")
	HumoRegla.poner_todas(false)
	ChispasRepo.poner_todas(false)
	if modo == "despues":
		HumoRegla.capas["magma"] = true
		ChispasRepo.poner_todas(true)
	await process_frame
	var cam: Camera3D = lab.get("_cam")
	cam.size = float(d["cam"])
	_lanzar(caso)
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < float(d["t"]):
		await process_frame
	await RenderingServer.frame_post_draw
	var ruta: String = _dir.path_join("%s_%s.png" % [caso, modo])
	_recorte(d["foco"], d["crop"], ruta)
	lab.call("limpiar")
	await _esperar(1.5)
	cam.size = 6.0
	return ruta


func _esperar(s: float) -> void:
	await create_timer(s).timeout


func _recorte(foco: Vector3, crop: Vector2i, ruta: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = (lab.get("_cam") as Camera3D).unproject_position(foco) * k
	var w: int = mini(crop.x, img.get_width())
	var h: int = mini(crop.y, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	var z: Image = img.get_region(Rect2i(x0, y0, w, h))
	z.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	z.save_png(ProjectSettings.globalize_path(ruta))


## Una fila por caso: antes | después.
func _hoja(ruta: String) -> void:
	var ancho: int = 480
	var alto: int = 270
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(140 + 2 * (ancho + 4), _fotos.size() * (alto + 4))
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(sv)
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.1, 0.1, 0.12)
	fondo.size = Vector2(sv.size)
	sv.add_child(fondo)
	for i in _fotos.size():
		var l: Label = Label.new()
		l.text = String(_fotos[i][0]) + "\nantes | después"
		l.position = Vector2(6, i * (alto + 4) + 6)
		l.size = Vector2(130, alto)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		sv.add_child(l)
		for j in 2:
			var im: Image = Image.load_from_file(ProjectSettings.globalize_path(String(_fotos[i][j + 1])))
			if im == null:
				continue
			im.resize(ancho, alto, Image.INTERPOLATE_LANCZOS)
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(im)
			tr.position = Vector2(140 + j * (ancho + 4), i * (alto + 4))
			sv.add_child(tr)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(ProjectSettings.globalize_path(ruta))
	sv.queue_free()
