extends "res://herramientas/escenario_base.gd"
## PÚAS DE TIERRA: JUEGO CONTRA LAB (12/11/2026). NECESITA VENTANA. Lanza el haz de tierra (ᛁ ᛁ: la línea de púas) en el Bosque 01 v01 con la cámara DEL JUEGO, o lo pone en el
## LabVfxComparativa3D (F7 → haz) con la cámara de `captura_viento_tierra_toy.gd`, y MIDE la luminancia de las púas: con el árbol en pausa saca el fotograma, oculta los MultiMesh de las púas y
## las lajas (`Bloques*` de cada TierraToy), saca otro y la máscara de las púas son los píxeles que cambian. Imprime `PUAS <modo> lum_puas=… lum_fondo=… ratio=… negras=…%` (luminancia sRGB
## Rec. 709 en 0..1; «negras» = píxeles de púa con lum < 0,2) y guarda <carpeta>/<modo>_<sufijo>.png y <modo>_<sufijo>_mascara.png.
## En el juego se puede fijar la hora del ciclo de día (y pararlo): el sol gira 8° por hora alrededor de la vertical y cambia qué caras de las púas ve la cámara al sol.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_pinchos_tierra.gd -- [juego|lab] [sufijo] [hora|""] [carpeta]

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const UMBRAL: float = 0.06            ## diferencia (máx. de canal) para que un píxel cuente como púa
const T_JUEGO: float = 1.0            ## s tras lanzar (todas las púas fuera; tierra_linea_procedural_120 ya las tiene)
const T_LAB: float = 1.25             ## s tras F7 → haz en el lab (lo mismo que tierra_haz_completo)

var _dir: String = "res://docs/capturas/vfx_en_juego/pinchos_tierra"
var _modo: String = "juego"
var _suf: String = "antes"
var _hora: float = -1.0               ## juego: hora del ciclo de día (CicloDia3D.HORA) fijada para la foto; < 0 = la de serie (10 h)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_modo = a[0]
	if a.size() > 1 and a[1] != "":
		_suf = a[1]
	if a.size() > 2 and a[2] != "":
		_hora = float(a[2])
	if a.size() > 3 and a[3] != "":
		_dir = a[3]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	if _modo == "lab":
		await _lab()
	else:
		await _juego()


func _juego() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro llano para la captura (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	if _hora >= 0.0:
		CicloDia3D.HORA = _hora
		CicloDia3D.DURACION_DIA_S = 0.0           # parada: la misma luz en el «antes» y el «después»
		_suf += "_%02dh" % int(_hora)
	await avanzar_s(2.0)
	var rd: RuneData = load("res://nucleo/earth_rune.tres") as RuneData
	var h: Hechizo = Hechizo.construir(rd, {"linea_x": 2})
	HechizoVivo.crear(h, jugador.position + Vector3(0.0, 0.8, 0.0), Vector3.RIGHT, lanzador)
	await avanzar_s(T_JUEGO)
	_ocultar_ui(root)
	await _medir()


func _lab() -> void:
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	lab.set("_panel_visible", false)
	await create_timer(0.4).timeout
	lab.call("poner_elemento", "tierra")
	lab.set("camara_fija", {"desde": Vector3(2.4, 1.7, 0.6), "mira": Vector3(0.0, 0.3, -2.0)})
	lab.call("poner_camara", 1)
	lab.call("fuego_param", 4)
	await create_timer(T_LAB).timeout
	await _medir()


## Pausa, foto con púas, foto sin púas (mismo instante), máscara y luminancias.
func _medir() -> void:
	paused = true
	await avanzar(3)
	var con: Image = root.get_viewport().get_texture().get_image()
	var mms: Array = []
	for t in root.find_children("*", "Node3D", true, false):
		if t is TierraToy:
			for h in t.find_children("Bloques*", "MultiMeshInstance3D", true, false):
				if (h as MultiMeshInstance3D).visible:
					mms.append(h)
	_ok("1 %s: hay púas que medir (%d MultiMesh)" % [_modo, mms.size()], not mms.is_empty())
	# la máscara se limita al rectángulo de pantalla de las púas (+ margen): las copas de los árboles se mecen con TIME aunque el árbol esté en pausa
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var caja: Rect2 = Rect2()
	var hay_caja: bool = false
	for m in mms:
		var mi: MultiMeshInstance3D = m
		for i in mi.multimesh.instance_count:
			var xf: Transform3D = mi.global_transform * mi.multimesh.get_instance_transform(i)
			if xf.basis.get_scale().length() < 0.01:
				continue                                            # instancia oculta
			for p in [xf.origin, xf.origin + xf.basis.y]:
				if cam.is_position_behind(p):
					continue
				var s: Vector2 = cam.unproject_position(p)
				caja = caja.expand(s) if hay_caja else Rect2(s, Vector2.ZERO)
				hay_caja = true
	caja = caja.grow(70.0)
	for m in mms:
		(m as MultiMeshInstance3D).visible = false
	await avanzar(3)
	var sin: Image = root.get_viewport().get_texture().get_image()
	for m in mms:
		(m as MultiMeshInstance3D).visible = true
	paused = false
	con.convert(Image.FORMAT_RGB8)
	sin.convert(Image.FORMAT_RGB8)
	var mascara: Image = Image.create(con.get_width(), con.get_height(), false, Image.FORMAT_L8)
	var n: int = 0
	var negras: int = 0
	var lp: float = 0.0
	var lf: float = 0.0
	for y in con.get_height():
		for x in con.get_width():
			if not caja.has_point(Vector2(x, y)):
				continue
			var p: Color = con.get_pixel(x, y)
			var q: Color = sin.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) < UMBRAL:
				continue
			var l: float = _lum(p)
			n += 1
			lp += l
			lf += _lum(q)
			if l < 0.2:
				negras += 1
			mascara.set_pixel(x, y, Color.WHITE)
	var ruta: String = _dir.path_join("%s_%s" % [_modo, _suf])
	con.save_png(ruta + ".png")
	mascara.save_png(ruta + "_mascara.png")
	if n == 0:
		_ok("1 %s: la máscara de púas tiene píxeles" % _modo, false)
		return
	lp /= float(n)
	lf /= float(n)
	print("PUAS %s %s px=%d lum_puas=%.3f lum_fondo=%.3f ratio=%.2f negras=%.1f%%" % [_modo, _suf, n, lp, lf, lp / maxf(lf, 0.001), 100.0 * float(negras) / float(n)])


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _buscar_claro() -> Vector2i:
	for y in range(4, 38):
		for x in range(2, 40):
			var ok: bool = true
			var base: float = Terreno3D.y_pies(Vector2i(x, y))
			for dx in range(-1, 10):
				for dz in range(-2, 3):
					var q := Vector2i(x + dx, y + dz)
					if not Terreno3D.en_mapa(q) or Terreno3D.celda_solida(q, 0) or Terreno3D.bloqueada(q) or Lanzador3D.es_agua(q) or absf(Terreno3D.y_pies(q) - base) > 0.01:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
