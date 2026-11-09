extends SceneTree

## CAPTURAS DEL HUMO POR REGLA (9/11/2026). NECESITA VENTANA. Antes / después con la cámara del JUEGO (la del lab: ortogonal, 30° de elevación, alejada para que quepa el efecto):
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_humo_regla.gd -- [carpeta] [casos separados por comas]
## «antes» = HumoRegla.capas todas apagadas; «después» = solo las capas de ese efecto encendidas. Escribe <carpeta>/<caso>_<antes|despues>_<ms>.jpg y las hojas hoja_<caso>.jpg + HOJA_RESUMEN.jpg.
## Casos: bola (G: la bola vuela, choca con la pared), muro (F7), pilar, barril, haz (F7 haz + F: muro de prueba), suelo (hierba ardiendo), vapor (agua sobre una hierba ardiendo), polvo_tierra, polvo_viento.

const LAB: String = "res://laboratorios/LabVfxComparativa3D.tscn"
const Vfx3DClase = preload("res://presentacion/vfx_3d.gd")

var _dir: String = "res://docs/capturas/vfx_en_juego/humo_regla"
var _casos: PackedStringArray = ["bola", "muro", "pilar", "barril", "haz", "suelo", "vapor", "polvo_tierra", "polvo_viento"]
var lab: Node3D = null
var _fotos: Dictionary = {}          ## caso → {antes: [ruta], despues: [ruta]}
var _extra: Array = []


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
		_fotos[caso] = {"antes": [], "despues": []}
		for modo in ["antes", "despues"]:
			await _toma(caso, modo)
	await _hojas()
	print("escrito ", _dir)
	quit(0)


## [capas que enciende, tamaño de la cámara, foco (Callable → Vector3 mundo), recorte (px), instantes (s desde que se lanza)]
func _def(caso: String) -> Dictionary:
	var pj: Vector3 = (lab.get("_pj") as Node3D).global_position
	var dir: Vector3 = lab.get("_dir")
	match caso:
		"bola":
			return {"capas": ["impacto_bola"], "cam": 10.0, "foco": pj + dir * 5.6 + Vector3(0, 0.8, 0), "crop": Vector2i(640, 360), "t": [2.2, 2.65, 3.2, 4.0]}
		"muro":
			return {"capas": ["muro"], "cam": 8.0, "foco": pj + dir * 3.0 + Vector3(0, 1.8, 0), "crop": Vector2i(1000, 562), "t": [1.2, 2.6, 4.0]}
		"pilar":
			return {"capas": ["pilar"], "cam": 13.0, "foco": pj + dir * 3.0 + Vector3(0, 3.5, 0), "crop": Vector2i(760, 570), "t": [1.2, 2.6, 4.0]}
		"barril":
			return {"capas": ["barril"], "cam": 10.0, "foco": pj + dir * 3.5 + Vector3(0, 1.0, 0), "crop": Vector2i(960, 540), "t": [0.3, 0.8, 1.5, 2.3, 3.2]}
		"haz":
			return {"capas": ["haz"], "cam": 6.0, "foco": pj + dir * 2.5 + Vector3(0, 0.6, 0), "crop": Vector2i(960, 540), "t": [1.0, 2.0, 3.2]}
		"suelo":
			return {"capas": ["suelo"], "cam": 6.0, "foco": pj + dir * 3.0 + Vector3(0, 0.8, 0), "crop": Vector2i(960, 540), "t": [1.5, 3.0, 4.5]}
		"vapor":
			return {"capas": ["vapor"], "cam": 6.0, "foco": pj + dir * 3.0 + Vector3(0, 0.8, 0), "crop": Vector2i(800, 450), "t": [0.4, 0.9, 1.5, 2.2]}
		"polvo_tierra", "polvo_viento":
			return {"capas": [caso], "cam": 6.0, "foco": pj + dir * 3.0 + Vector3(0, 0.4, 0), "crop": Vector2i(800, 450), "t": [0.2, 0.5, 0.9, 1.5]}
	return {}


func _lanzar(caso: String) -> void:
	var pj: Vector3 = (lab.get("_pj") as Node3D).global_position
	var dir: Vector3 = lab.get("_dir")
	var efectos: Node3D = lab.get("_efectos")
	match caso:
		"bola":
			lab.call("poner_elemento", "fuego")
			lab.call("carga_completa")
		"muro":
			lab.call("poner_elemento", "fuego")
			lab.call("fuego_param", 1)
		"pilar":
			lab.call("poner_elemento", "fuego")
			lab.call("fuego_param", 2)
		"barril":
			var ex: ExplosionFuegoToy = ExplosionFuegoToy.crear(2.6)
			efectos.add_child(ex)
			ex.global_position = Vector3(pj.x, 0.0, pj.z) + dir * 3.5
		"haz":
			lab.call("poner_elemento", "fuego")
			if not bool(lab.get("_muro_haz_activo")):
				lab.call("alternar_muro_haz")                    # F
			lab.call("fuego_param", 4)
		"suelo":
			_llamas(efectos, Vector3(pj.x, 0.0, pj.z) + dir * 3.0, [Vector3(-0.9, 0, 0.3), Vector3(0.1, 0, -0.5), Vector3(1.0, 0, 0.4)])
		"vapor":
			lab.call("poner_elemento", "agua")
			_llamas(efectos, Vector3(pj.x, 0.0, pj.z) + dir * 3.0, [Vector3(-0.8, 0, 0.2), Vector3(0.8, 0, -0.2)])
			lab.call("impacto_suelo")
		"polvo_tierra":
			lab.call("poner_elemento", "tierra")
			lab.call("impacto_suelo")
		"polvo_viento":
			lab.call("poner_elemento", "viento")
			lab.call("impacto_suelo")


## Hierba ardiendo (Vfx3D.llamas, fuego pleno) en `centro` + cada desplazamiento.
func _llamas(padre: Node3D, centro: Vector3, desp: Array) -> void:
	var fx: Node3D = Vfx3DClase.new()
	padre.add_child(fx)
	for d in desp:
		fx.call("llamas", centro + (d as Vector3), 1.0, 0.45)


func _toma(caso: String, modo: String) -> void:
	var d: Dictionary = _def(caso)
	if d.is_empty():
		return
	lab.call("limpiar")
	HumoRegla.poner_todas(false)
	if modo == "despues":
		for k in d["capas"]:
			HumoRegla.capas[k] = true
	await process_frame
	var cam: Camera3D = lab.get("_cam")
	cam.size = float(d["cam"])
	await _lanzar(caso)
	var t0: int = Time.get_ticks_msec()
	for t in d["t"]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(t):
			await process_frame
		await RenderingServer.frame_post_draw
		var ruta: String = _dir.path_join("%s_%s_%04d.jpg" % [caso, modo, int(float(t) * 1000.0)])
		_recorte(d["foco"], d["crop"], ruta)
		(_fotos[caso][modo] as Array).append(ruta)
	if caso == "haz" and bool(lab.get("_muro_haz_activo")):
		lab.call("alternar_muro_haz")
	lab.call("limpiar")
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	HumoRegla.poner_todas(false)
	await _esperar(2.6)
	cam.size = 6.0


func _esperar(s: float) -> void:
	await create_timer(s).timeout


## Recorta `crop` px alrededor de `foco` (mundo) y lo guarda a 960 × 540.
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
	z.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	z.save_jpg(ProjectSettings.globalize_path(ruta), 0.9)


# ------------------------------------------------------------------ hojas ------------------------------------------------------------------

func _hojas() -> void:
	var resumen: Array = []
	for caso in _casos:
		var f: Dictionary = _fotos[caso]
		var a: Array = f["antes"]
		var b: Array = f["despues"]
		if a.is_empty():
			continue
		await _hoja(_dir.path_join("hoja_%s.jpg" % caso), [["antes " + caso, a], ["después " + caso, b]], 380)
		var n: int = a.size()
		var i1: int = clampi(n / 2, 0, n - 1)
		var i2: int = n - 2 if n > 2 else n - 1
		resumen.append([caso, [a[i1], b[i1], a[i2], b[i2]]])
	# HOJA_RESUMEN: una fila por efecto: antes / después en dos instantes
	var filas: Array = []
	for r in resumen:
		filas.append([String(r[0]) + "\nantes | después\n(2 instantes)", r[1]])
	await _hoja(_dir.path_join("HOJA_RESUMEN.jpg"), filas, 440)


## `filas`: [[título, [rutas]]]. Una fila por entrada, miniaturas de `ancho` px de ancho. Se dibuja en un SubViewport y se guarda.
func _hoja(ruta: String, filas: Array, ancho: int) -> void:
	var alto: int = int(round(float(ancho) * 9.0 / 16.0))
	var cols: int = 0
	for f in filas:
		cols = maxi(cols, (f[1] as Array).size())
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(130 + cols * (ancho + 4), filas.size() * (alto + 4))
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.transparent_bg = false
	root.add_child(sv)
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.1, 0.1, 0.12)
	fondo.size = Vector2(sv.size)
	sv.add_child(fondo)
	for i in filas.size():
		var l: Label = Label.new()
		l.text = String(filas[i][0])
		l.position = Vector2(6, i * (alto + 4) + 6)
		l.size = Vector2(120, alto)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		sv.add_child(l)
		var rutas: Array = filas[i][1]
		for j in rutas.size():
			var im: Image = Image.load_from_file(ProjectSettings.globalize_path(String(rutas[j])))
			if im == null:
				continue
			im.resize(ancho, alto, Image.INTERPOLATE_LANCZOS)
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(im)
			tr.position = Vector2(130 + j * (ancho + 4), i * (alto + 4))
			sv.add_child(tr)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(ruta), 0.88)
	sv.queue_free()
