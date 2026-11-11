extends SceneTree

## CAMPO DE VIENTO EN EL LAB (11/11/2026, «no veo diferencia en viento»). NECESITA VENTANA. Reproduce lo que hace Pablo en LabVfxComparativa3D con las funciones reales
## de las teclas: Z hasta VIENTO (poner_elemento), F7 hasta HAZ / PILAR / MURO (fuego_param) e Inicio (el mismo _unhandled_input con KEY_HOME) para comparar sin y con campo.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_viento_visible.gd -- [carpeta] [etiqueta] [figuras separadas por comas] [cenital]
## («cenital» añade <figura>_<etiqueta>_<con|sin>_cenital.png desde arriba, para ver el rodeo sin que la cápsula lo tape.) Los «antes» se sacaron con el código de main 4b9cb490.
## Escribe <carpeta>/<figura>_<etiqueta>_<sin|con>.png (cámara del juego del lab, recortada sobre los obstáculos) y, si la etiqueta es «despues» y existen las «antes»,
## HOJA_RESUMEN.png (una fila por figura: antes sin campo | antes con campo | después con campo). Imprime los números del diagnóstico: sólidos que ve el campo, puntos de las
## cintas que cruzan los obstáculos sin campo, desplazamiento medio y máximo de los puntos con campo, hojas y jirones arrastrados, y el coste del paso del toy.

const LAB: String = "res://laboratorios/LabVfxComparativa3D.tscn"
const FIGURAS: Dictionary = {"haz": 4, "pilar": 2, "muro": 1}

var _dir: String = "res://docs/capturas/vfx_en_juego/viento_visible"
var _etq: String = "despues"
var _figs: PackedStringArray = ["haz", "pilar", "muro"]
var lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_etq = a[1]
	if a.size() > 2 and a[2] != "":
		_figs = a[2].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	CampoViento.en_viento_toy = false
	await process_frame
	lab = (load(LAB) as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	lab.set("_panel_visible", false)
	lab.call("poner_elemento", "viento")
	for f in _figs:
		await _figura(f)
	if _etq == "despues":
		await _hoja(_dir.path_join("HOJA_RESUMEN.png"))
	CampoViento.en_viento_toy = false
	print("escrito ", _dir)
	quit(0)


func _tecla(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	lab.call("_unhandled_input", ev)


func _figura(f: String) -> void:
	lab.call("limpiar")
	await _esperar(0.3)
	var vt: VientoToy = lab.call("fuego_param", int(FIGURAS[f])) as VientoToy
	await _esperar(1.2)
	var pj: Vector3 = (lab.get("_pj") as Node3D).global_position
	var d: Vector3 = lab.get("_dir")
	var foco: Vector3 = Vector3(pj.x, 0.6, pj.z) + d * 2.3
	if f != "haz":
		foco = Vector3(vt.global_position.x, 1.3 if f == "pilar" else 0.8, vt.global_position.z)
	var cor: Node3D = vt.get_node_or_null("Cuerpo/CorrientesViento") as Node3D
	await _foto(f + "_" + _etq + "_sin", foco)
	# sonda con los obstáculos que pondrá Inicio (para contar los puntos que los cruzan SIN campo)
	_tecla(KEY_HOME)                      # campo SÍ + cápsula y bloque
	await process_frame
	var sonda := CampoViento.new()
	var obs: Node = lab.get_node_or_null("ObstaculosViento")
	sonda.recoger_de(obs if obs != null else lab, vt.global_position, 6.0, 0.0)
	await _esperar(1.2)
	var c: CampoViento = vt.campo()
	var n_sol: int = c.solidos() if c != null else -1
	# desplazamiento de los puntos: el mismo dibujo con el campo y sin él
	var dif: Array = _desplazamiento(vt, cor, sonda)
	var arr: Array = _arrastradas(vt)
	var cruzan: int = dif[4]
	var dentro_on: int = dif[5]
	await _foto(f + "_" + _etq + "_con", foco)
	if OS.get_cmdline_user_args().has("cenital"):
		var mira: Vector3 = Vector3(foco.x, 0.3, foco.z)
		lab.set("camara_fija", {"desde": mira + Vector3(0.0, 6.0, 0.6), "mira": mira})
		lab.call("poner_camara", 1)
		await _esperar(0.1)
		await _foto(f + "_" + _etq + "_con_cenital", mira)
		_tecla(KEY_HOME)
		await _esperar(0.3)
		await _foto(f + "_" + _etq + "_sin_cenital", mira)
		_tecla(KEY_HOME)
		await _esperar(1.0)
		lab.set("camara_fija", {})
		lab.call("poner_camara", 0)
	var coste: Array = _coste(vt)
	print("DIAG %s [%s]: sólidos que ve el campo %d (sonda %d) · puntos de cintas que cruzan los obstáculos SIN campo %d, CON campo %d · desplazamiento de los puntos con campo: medio %.3f m, máximo %.3f m, %.0f %% > 0,15 m (de %d puntos) · hojas/jirones vivos %d, con el campo %s · coste del paso: %.3f ms con campo, %.3f sin (+%.3f)" % [
		f, _etq, n_sol, sonda.solidos(), cruzan, dentro_on, dif[0], dif[1], dif[2] * 100.0, dif[3], arr[0], str(arr[1]), coste[0], coste[1], coste[0] - coste[1]])
	_tecla(KEY_HOME)                      # campo no
	await process_frame


func _dentro(cor: Node3D, sonda: CampoViento, _x) -> int:
	if cor == null:
		return -1
	var xf: Transform3D = cor.global_transform
	var k: int = 0
	for tz in (cor.get("_trazos") as Array):
		for p in ((tz as Dictionary)["puntos"] as PackedVector3Array):
			if sonda.sdf(xf * p) < -0.01:
				k += 1
	return k


## [medio, máximo, fracción > 0,15 m, puntos]: los trazos del último dibujo (con campo) frente al mismo dibujo con campo = null.
func _desplazamiento(vt: VientoToy, cor: Node3D, sonda: CampoViento) -> Array:
	if cor == null or vt.campo() == null:
		return [0.0, 0.0, 0.0, 0, -1, -1]
	vt._actualizar_corrientes(0.0)
	var con: Array = (cor.get("_trazos") as Array).duplicate(true)
	var dentro_con: int = _dentro(cor, sonda, null)
	var campo: CampoViento = cor.get("campo")
	cor.set("campo", null)
	vt._actualizar_corrientes(0.0)
	var sin: Array = (cor.get("_trazos") as Array).duplicate(true)
	var dentro_sin: int = _dentro(cor, sonda, null)
	cor.set("campo", campo)
	vt._actualizar_corrientes(0.0)
	var suma: float = 0.0
	var mx: float = 0.0
	var n: int = 0
	var grandes: int = 0
	for i in mini(con.size(), sin.size()):
		var a: PackedVector3Array = (con[i] as Dictionary)["puntos"]
		var b: PackedVector3Array = (sin[i] as Dictionary)["puntos"]
		for j in mini(a.size(), b.size()):
			var dd: float = a[j].distance_to(b[j])
			suma += dd
			mx = maxf(mx, dd)
			n += 1
			if dd > 0.15:
				grandes += 1
	return [suma / float(maxi(n, 1)), mx, float(grandes) / float(maxi(n, 1)), n, dentro_sin, dentro_con]


## [vivas, el campo las arrastra (el toy las mira)] de hojas y jirones.
func _arrastradas(vt: VientoToy) -> Array:
	var vivas: int = 0
	var vis: Array = []
	for nombre in ["_humo", "_hojas", "_estela"]:
		var h: Variant = vt.get(nombre)
		if h == null or not is_instance_valid(h):
			continue
		var lista: Variant = (h as Node).get("_s")
		var v: int = 0
		if lista is Array:
			for e in lista:
				if bool((e as Dictionary).get("vivo", false)):
					v += 1
		vivas += v
		vis.append("%s:%d%s" % [nombre, v, "" if (h as Node3D).is_visible_in_tree() else "(oculto)"])
	return [vivas, " ".join(vis)]


## [ms con campo, ms sin campo] del _process del toy (mínimo de 6 rondas de 15 pasos, alternando).
func _coste(vt: VientoToy) -> Array:
	var on: float = 1.0e9
	var off: float = 1.0e9
	for rep in 6:
		CampoViento.en_viento_toy = true
		vt._process(1.0 / 60.0)
		on = minf(on, _medir(vt, 15))
		CampoViento.en_viento_toy = false
		vt._process(1.0 / 60.0)
		off = minf(off, _medir(vt, 15))
	CampoViento.en_viento_toy = true
	vt._process(1.0 / 60.0)
	return [on, off]


func _medir(vt: VientoToy, pasos: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in pasos:
		vt._process(1.0 / 60.0)
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(pasos)


func _esperar(s: float) -> void:
	await create_timer(s).timeout


func _foto(nombre: String, foco: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = (lab.get("_cam") as Camera3D).unproject_position(foco) * k
	var w: int = mini(int(img.get_width() * 0.62), img.get_width())
	var h: int = mini(int(w * 9 / 16), img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	var z: Image = img.get_region(Rect2i(x0, y0, w, h))
	z.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	z.save_png(ProjectSettings.globalize_path(_dir.path_join(nombre + ".png")))
	print("foto ", nombre)


## Una fila por figura: antes sin campo | antes con campo | después con campo (el «después sin campo» es igual al «antes sin campo»: el apagado no cambia).
func _hoja(ruta: String) -> void:
	var ancho: int = 480
	var alto: int = 270
	var cols: Array = [["antes", "sin"], ["antes", "con"], ["despues", "con"]]
	var titulos: PackedStringArray = ["campo NO (igual antes y después)", "campo SÍ, antes", "campo SÍ, después"]
	var filas: Array = []                 ## [figura, sufijo del archivo, rótulo]
	for f in _figs:
		filas.append([f, "", "cámara del juego"])
	for f in _figs:
		if FileAccess.file_exists(ProjectSettings.globalize_path(_dir.path_join("%s_despues_con_cenital.png" % f))):
			filas.append([f, "_cenital", "desde arriba"])
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(140 + cols.size() * (ancho + 4), 30 + filas.size() * (alto + 4))
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(sv)
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.1, 0.1, 0.12)
	fondo.size = Vector2(sv.size)
	sv.add_child(fondo)
	for j in cols.size():
		var lt: Label = Label.new()
		lt.text = titulos[j]
		lt.position = Vector2(140 + j * (ancho + 4) + 6, 4)
		lt.add_theme_font_size_override("font_size", 16)
		sv.add_child(lt)
	for i in filas.size():
		var l: Label = Label.new()
		l.text = "VIENTO\n" + String(filas[i][0]).to_upper() + "\n" + String(filas[i][2]) + "\n\nInicio:\nno | sí | sí"
		l.position = Vector2(6, 30 + i * (alto + 4) + 6)
		l.size = Vector2(130, alto)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		sv.add_child(l)
		for j in cols.size():
			var r: String = ProjectSettings.globalize_path(_dir.path_join("%s_%s_%s%s.png" % [filas[i][0], cols[j][0], cols[j][1], filas[i][1]]))
			if not FileAccess.file_exists(r):
				continue
			var im: Image = Image.load_from_file(r)
			if im == null:
				continue
			im.resize(ancho, alto, Image.INTERPOLATE_LANCZOS)
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(im)
			tr.position = Vector2(140 + j * (ancho + 4), 30 + i * (alto + 4))
			sv.add_child(tr)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(ProjectSettings.globalize_path(ruta))
	sv.queue_free()
