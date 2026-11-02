extends SceneTree

## CAPTURAS DEL FUEGO PARAMÉTRICO (FuegoToy), para la lámina de ejes y propiedades. Basado en captura_vfx_toy.gd: usa el LabVfxComparativa3D (suelo, sol, glow del lab) con ventana,
## no espera clics. Dos modos:
##   godot --path . --script res://herramientas/captura_fuego_parametrico.gd -- <carpeta de celdas> celdas
##       una captura 800×600 por celda de la lámina (la misma dirección de cámara y el mismo FOV en todas; la DISTANCIA se ajusta para que quepan el efecto y un cubo de 1 m de referencia
##       a su lado) y celdas.json (figura, ejes y rótulos) para herramientas/lamina_vfx.py
##   godot --path . --script res://herramientas/captura_fuego_parametrico.gd -- <carpeta> tonos
##       las cuatro figuras de la prueba 3 con la cámara «cerca» del lab (la de siempre) y las escenas validadas con la misma cámara, 1600×1000, para herramientas/medir_tonos_fuego.py
##   godot --path . --script res://herramientas/captura_fuego_parametrico.gd -- <carpeta> hielo_rayo
##       (B1, 2/11/2026) las cinco figuras de HieloToy y de RayoToy con la cámara «cerca» del lab (tamaño de la prueba 3) y tres fotogramas del ciclo de cada uno (hielo: pilar que crece / vive / se rompe;
##       rayo: muro que nace / vive / muere, a cámara lenta: Engine.time_scale 0,1 porque el rayo nace en 0,06 s), para herramientas/lamina_vfx.py --hielo-rayo
##   Un tercer argumento opcional, el ELEMENTO (fuego, agua, hielo o rayo), vale para los modos «celdas» y «tonos»: lo mismo con la clase de ese elemento (las escenas validadas solo existen para el fuego).
## Las celdas no se guardan en el repositorio (pesan); se rehacen con este script.

const CELDA: Vector2i = Vector2i(800, 600)
const TAM_TONOS: Vector2i = Vector2i(1600, 1000)
const TAM_HR: Vector2i = Vector2i(1200, 900)
const FOV: float = 50.0
const MARGEN: float = 0.04
const ESPERA: float = 1.3
const DIR_CAMARA: Vector3 = Vector3(0.6, 0.35, 0.8)          # mismo ángulo que la cámara «cerca» del lab (lado 0,6/0,8 y 0,35 de altura por metro de distancia)

## [id, fila, columna, título corto, figura, x, y, z, propiedades, viaja, escena validada para comparar]
## Filas 0-3: figuras (bola, muro, pilar, barrera) × columnas de ejes. Filas 4 y 5: propiedades del muro 3,45·1,5·0,3 y de la bola 0,4.
var _celdas: Array = []
var _dir: String = "E:/tmp/celdas_fuego"
var _lab: Node3D = null
var _cam: Camera3D = null
var _json: Array = []


func _initialize() -> void:
	_correr()


func _def() -> void:
	var cols: Array = ["pequeño", "tamaño prueba 3", "grande", "anisótropo A", "anisótropo B", "escena validada"]
	var figs: Array = [
		["bola", 0, [[0.15, 0.15, 0.15], [0.4, 0.4, 0.4], [1.2, 1.2, 1.2], [0.4, 0.8, 0.4], [0.6, 0.25, 0.6]], "BolaFuegoToy", "en vuelo"],
		["muro", 1, [[0.8, 0.7, 0.2], [3.45, 1.5, 0.3], [6.0, 2.5, 0.5], [1.5, 1.5, 0.3], [6.0, 0.8, 0.3]], "MuroFuegoToy", ""],
		["pilar", 2, [[0.2, 1.0, 0.2], [0.5, 4.0, 0.5], [1.2, 4.6, 1.2], [0.3, 6.0, 0.3], [1.0, 1.5, 1.0]], "PilarFuegoToy", ""],
		["barrera", 3, [[0.5, 0.5, 0.5], [1.5, 1.5, 1.5], [3.0, 3.0, 3.0], [1.5, 0.8, 1.5], [2.5, 2.0, 1.2]], "BarreraFuegoToy", ""],
		["haz", 4, [[0.6, 0.5, 0.08], [1.5, 0.5, 0.15], [3.45, 0.9, 0.4], [3.0, 0.5, 0.06], [0.8, 0.5, 0.4]], "", ""]]
	var nombres_aniso: Dictionary = {"bola": ["alta", "baja y ancha"], "muro": ["corto", "largo y bajo"], "pilar": ["fino y alto", "gordo y bajo"], "barrera": ["achatada", "elíptica"], "haz": ["fino y largo", "grueso y corto"]}
	for f in figs.size():
		var fg: Array = figs[f]
		for c in 5:
			var s: Array = fg[2][c]
			var etiqueta: String = cols[c] if c < 3 else "%s (%s)" % [cols[c], nombres_aniso[fg[0]][c - 3]]
			_celdas.append({"id": "%s_%d" % [fg[0], c], "fila": f, "col": c, "titulo": etiqueta, "figura": fg[1], "x": s[0], "y": s[1], "z": s[2], "props": {}, "viaja": false, "validada": "", "prop": false})
		var s3: Array = fg[2][1]
		if fg[3] != "":
			_celdas.append({"id": "%s_val" % fg[0], "fila": f, "col": 5, "titulo": cols[5], "figura": fg[1], "x": s3[0], "y": s3[1], "z": s3[2], "props": {}, "viaja": false, "validada": fg[3], "prop": false})
	_celdas.append({"id": "bola_vuelo", "fila": 0, "col": 6, "titulo": "en vuelo (viaja)", "figura": 0, "x": 0.4, "y": 0.4, "z": 0.4, "props": {}, "viaja": true, "validada": "", "prop": false})
	var props: Array = [["base", {}], ["tono 1 (azul)", {"tono": 1.0}], ["altura 2", {"altura": 2.0}], ["chispas 0", {"chispas": 0.0}], ["brillo 0,5", {"brillo": 0.5}],
		["blandura 0,6", {"blandura": 0.6}], ["chisporroteo 0", {"chisporroteo": 0.0}]]
	for f in 2:
		for c in props.size():
			var muro: bool = f == 0
			_celdas.append({"id": "%s_prop%d" % ["muro" if muro else "bola", c], "fila": 5 + f, "prop": true, "col": c, "titulo": props[c][0], "figura": 1 if muro else 0,
				"x": 3.45 if muro else 0.4, "y": 1.5 if muro else 0.4, "z": 0.3 if muro else 0.4, "props": props[c][1], "viaja": false, "validada": ""})


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	var que: String = a[1] if a.size() > 1 else "celdas"
	var elem: String = a[2] if a.size() > 2 else "fuego"
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.call("poner_elemento", elem)
	if que == "hielo_rayo":
		root.get_window().size = TAM_HR
		_lab.set("_panel_visible", false)
		await _seg(0.5)
		await _hielo_rayo()
	elif que == "tonos":
		root.get_window().size = TAM_TONOS
		await _seg(0.5)
		await _tonos()
	else:
		root.get_window().size = CELDA
		_lab.set("_panel_visible", false)
		(_lab.get("_pj") as Node3D).visible = false
		for n in _lab.get_children():
			if String(n.name).begins_with("Cubo"):
				(n as Node3D).visible = false
		_cam = Camera3D.new()
		_cam.fov = FOV
		_lab.add_child(_cam)
		_cam.make_current()
		_def()
		if elem != "fuego":
			_celdas = _celdas.filter(func(c: Dictionary) -> bool: return c["validada"] == "")
		await _seg(0.5)
		await _celdas_todas()
	print("CAPTURAS en " + _dir)
	quit()


# ---------------------------------------------------------------- celdas ----------------------------------------------------------------

func _celdas_todas() -> void:
	for c in _celdas:
		await _celda(c)
	var f: FileAccess = FileAccess.open(_dir.path_join("celdas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_celdas, "\t"))
	f.close()


## Caja del efecto (m, centrada en el origen del efecto, que está en el suelo salvo la bola) y altura de su centro.
func _caja(fig: int, x: float, y: float, z: float, mult_y: float) -> AABB:
	match fig:
		0:
			var r: float = maxf(x, z)
			var cy: float = maxf(0.55, y + 0.1)
			return AABB(Vector3(-r, cy - y, -r), Vector3(2.0 * r, y * (2.0 + 0.7 * mult_y), 2.0 * r))
		1:
			return AABB(Vector3(-x - 0.2, 0.0, -z - 0.2), Vector3(2.0 * x + 0.4, y * 1.2 * mult_y, 2.0 * z + 0.4))
		2:
			return AABB(Vector3(-x, 0.0, -z), Vector3(2.0 * x, y * 1.1 * mult_y, 2.0 * z))
	if fig == 4:       # haz: sale del origen hacia -X (el nodo se gira 90° para verlo de lado), eje a la altura max(y, 0,4)
		return AABB(Vector3(-2.0 * x, 0.0, -z - 0.2), Vector3(2.0 * x + 0.3, maxf(y, 0.4) + z + 0.3, 2.0 * z + 0.4))
	return AABB(Vector3(-x, 0.0, -z), Vector3(2.0 * x, y * 1.45, 2.0 * z))


func _celda(c: Dictionary) -> void:
	var fig: int = c["figura"]
	var x: float = c["x"]
	var y: float = c["y"]
	var z: float = c["z"]
	var props: Dictionary = c["props"]
	var vuela: bool = c["viaja"]
	var mult_y: float = float(props.get("altura", 1.0))
	var caja: AABB = _caja(fig, x, y, z, mult_y)
	var pos: Vector3 = Vector3.ZERO
	if fig == 0:
		pos = Vector3(0, maxf(0.55, y + 0.1), 0)
	# cubo de 1 m de referencia a la izquierda del efecto (en el suelo)
	var cubo_x: float = caja.position.x - 0.8
	var cubo: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	cubo.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.72, 0.7)
	mat.roughness = 0.9
	cubo.material_override = mat
	cubo.position = Vector3(cubo_x, 0.5, 0.0)
	_lab.add_child(cubo)
	var union: AABB = caja.merge(AABB(cubo.position - Vector3(0.5, 0.5, 0.5), Vector3.ONE))
	var e: Node3D = null
	if c["validada"] != "":
		e = (load("res://presentacion/vfx/toy/%s.tscn" % c["validada"]) as PackedScene).instantiate() as Node3D
	else:
		e = _lab.call("_nuevo_toy") as Node3D
		e.call("definir", fig, x, y, z, vuela)
	for k in props:
		e.set(k, props[k])
	_lab.add_child(e)
	if fig == 4:
		e.rotation.y = PI * 0.5
	if vuela:
		# bola en vuelo hacia -X a 8 m/s; se fotografía a los 0,8 s de vuelo (la cola y las estelas ya están formadas)
		e.position = Vector3(2.6, pos.y, 0.0)
		e.look_at(e.position + Vector3(-1, 0, 0), Vector3.UP)
	else:
		e.position = pos
	e.call("lanzar", -1.0)
	if vuela:
		var t: float = 0.0
		var x0: float = e.position.x
		var ms0: int = Time.get_ticks_msec()
		while t < 0.8:
			t = float(Time.get_ticks_msec() - ms0) / 1000.0
			e.position.x = x0 - 8.0 * t
			await process_frame
		cubo.position = Vector3(e.position.x + 2.0, 0.5, -1.6)
		union = AABB(Vector3(e.position.x - 0.9, 0.0, -2.2), Vector3(4.2, 1.3, 2.6))       # cámara cerca, como bola_vuelo.png de la ronda 8: la bola y su cola
	else:
		await _seg(ESPERA)
	_encuadrar(union)
	await _seg(0.15)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("celda_%s.png" % c["id"]))
	print("celda %s  %.2f·%.2f·%.2f" % [c["id"], x, y, z])
	e.queue_free()
	cubo.queue_free()
	await _seg(0.1)


## Pone la cámara (misma dirección y FOV siempre) a la distancia mínima desde la que caben las 16 esquinas de la caja con un margen.
func _encuadrar(caja: AABB) -> void:
	var centro: Vector3 = caja.position + caja.size * 0.5
	var lado: Vector3 = Vector3(DIR_CAMARA.x, 0.0, DIR_CAMARA.z).normalized() * 1.0 + Vector3(0, DIR_CAMARA.y, 0)
	var vp: Vector2 = Vector2(CELDA)
	var lo: float = 0.6
	var hi: float = 90.0
	for i in 28:
		var m: float = (lo + hi) * 0.5
		_cam.global_position = centro + lado * m
		_cam.look_at(centro, Vector3.UP)
		var cabe: bool = true
		for k in 8:
			var p: Vector3 = caja.position + Vector3(caja.size.x * float(k & 1), caja.size.y * float((k >> 1) & 1), caja.size.z * float((k >> 2) & 1))
			if _cam.is_position_behind(p):
				cabe = false
				break
			var q: Vector2 = _cam.unproject_position(p)
			if q.x < vp.x * MARGEN or q.x > vp.x * (1.0 - MARGEN) or q.y < vp.y * MARGEN or q.y > vp.y * (1.0 - MARGEN):
				cabe = false
				break
		if cabe:
			hi = m
		else:
			lo = m
	_cam.global_position = centro + lado * hi
	_cam.look_at(centro, Vector3.UP)


# ---------------------------------------------------------------- tonos ----------------------------------------------------------------

## Cámara «cerca» del lab para las cuatro figuras de la prueba 3: FuegoToy (param_*) y la escena validada (val_*), con el mismo montaje.
func _tonos() -> void:
	var nombres: Array = ["bola", "muro", "pilar", "barrera"]
	var claves: Array = ["bola_toy", "muro_toy", "pilar_toy", "barrera_toy"]
	for i in 4:
		_lab.call("limpiar")
		_lab.call("fuego_param", i)
		await _seg(1.3)
		_lab.call("poner_camara", 1)
		await _seg(0.2)
		for k in 6:                     # seis fotos separadas 0,41 s: el fuego depende del tiempo y una sola foto engaña en la medida de tonos
			root.get_viewport().get_texture().get_image().save_png(_dir.path_join("param_%s_cerca_%d.png" % [nombres[i], k]))
			await _seg(0.41)
		_lab.call("limpiar")
		await _seg(0.3)
		_lab.call("efecto", claves[i])
		await _seg(1.3)
		_lab.call("poner_camara", 1)
		await _seg(0.2)
		for k in 6:
			root.get_viewport().get_texture().get_image().save_png(_dir.path_join("val_%s_cerca_%d.png" % [nombres[i], k]))
			await _seg(0.41)
		print("tonos " + nombres[i])
	# tamaños que cambiaron en la ronda de pulido: mismas 6 fotos con la cámara «cerca» (que se ajusta al tamaño)
	for ex in [["pilar_grande", 2, 1.2, 4.6, 1.2], ["pilar_gordo", 2, 1.0, 1.5, 1.0], ["barrera_pequena", 3, 0.5, 0.5, 0.5], ["barrera_grande", 3, 3.0, 3.0, 3.0], ["haz", 4, 1.5, 0.5, 0.15]]:
		_lab.call("limpiar")
		var e: FuegoToy = _lab.call("fuego_param", ex[1])
		e.definir(ex[1], ex[2], ex[3], ex[4], false)
		await _seg(1.5)
		_lab.call("poner_camara", 1)
		await _seg(0.2)
		for k in 6:
			root.get_viewport().get_texture().get_image().save_png(_dir.path_join("param_%s_cerca_%d.png" % [ex[0], k]))
			await _seg(0.41)
		print("tonos " + ex[0])
	_lab.call("limpiar")


func _seg(s: float) -> void:
	await create_timer(s, true, false, true).timeout        # ignora Engine.time_scale (el rayo se fotografía a cámara lenta)

# ---------------------------------------------------------------- hielo y rayo (B1, 2/11/2026) ----------------------------------------------------------------

const HR_FIGURAS: Array = ["bola", "muro", "pilar", "barrera", "haz"]


## Una foto con el estado actual del lab. Para el rayo espera a que la intensidad del redibujo sea alta (con 3 fotogramas por redibujo y un 10 % de redibujos casi apagados, una foto al azar puede salir oscura).
func _foto(ruta: String, e: Node3D, espera_rayo: bool) -> void:
	if espera_rayo and e.has_method("intensidad_actual"):
		for k in 40:
			await process_frame
			if float(e.call("intensidad_actual")) >= 0.7:
				break
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ruta)


## Las cinco figuras de la prueba 3 de cada elemento nuevo con la cámara «cerca» del lab, y tres fotogramas del ciclo (hielo: pilar crece / vive / se rompe; rayo: muro nace / vive / muere, a cámara lenta).
func _hielo_rayo() -> void:
	var celdas: Array = []
	for elem in ["hielo", "rayo"]:
		_lab.call("poner_elemento", elem)
		for i in 5:
			_lab.call("limpiar")
			var e: Node3D = _lab.call("fuego_param", i)
			await _seg(1.3)
			_lab.call("poner_camara", 1)
			await _seg(0.25)
			var id: String = "%s_%s" % [elem, HR_FIGURAS[i]]
			await _foto(_dir.path_join("hr_%s.png" % id), e, elem == "rayo")
			e.visible = false                                               # la misma foto sin el efecto: herramientas/medir_tonos_hielo_rayo.py resta las dos para medir solo los píxeles del efecto
			await process_frame
			await _foto(_dir.path_join("hr_%s_base.png" % id), e, false)
			e.visible = true
			celdas.append({"id": id, "elemento": elem, "tipo": "figura", "figura": i, "x": e.get("semieje_x"), "y": e.get("semieje_y"), "z": e.get("semieje_z"), "titulo": HR_FIGURAS[i]})
			print("hr " + id)
		# ciclo
		var fig_ciclo: int = 2 if elem == "hielo" else 1
		var lento: float = 1.0 if elem == "hielo" else 0.1
		_lab.call("limpiar")
		Engine.time_scale = lento
		var c: Node3D = _lab.call("fuego_param", fig_ciclo)
		var t_nace: float = 0.5 if elem == "hielo" else 0.3          # s reales: hielo nace en 0,9 s (a 0,5 s va por 0,55 de crece); rayo nace en 0,06 s a escala 0,1 (a 0,3 s reales va por 0,5)
		await _seg(t_nace)
		_lab.call("poner_camara", 1)
		await _seg(0.1)
		var nombres: Array = ["crece", "vive", "se rompe"] if elem == "hielo" else ["nace", "vive", "muere"]
		var info: Array = []
		await _foto(_dir.path_join("hr_%s_ciclo_0.png" % elem), c, false)
		info.append("crece = %.2f" % float(c.get("crece")))
		await _seg(1.4 if elem == "hielo" else 1.2)
		await _foto(_dir.path_join("hr_%s_ciclo_1.png" % elem), c, elem == "rayo")
		info.append("crece = %.2f, corte = %.2f" % [float(c.get("crece")), float(c.get("corte"))])
		c.call("morir")
		await _seg(0.55 if elem == "hielo" else 0.9)
		await _foto(_dir.path_join("hr_%s_ciclo_2.png" % elem), c, false)
		info.append("corte = %.2f" % float(c.get("corte")))
		Engine.time_scale = 1.0
		for k in 3:
			celdas.append({"id": "%s_ciclo_%d" % [elem, k], "elemento": elem, "tipo": "ciclo", "figura": fig_ciclo, "paso": k, "titulo": nombres[k], "info": info[k],
				"x": c.get("semieje_x") if is_instance_valid(c) else 0.0, "y": 0.0, "z": 0.0})
		print("hr ciclo " + elem)
		await _seg(1.0)
	_lab.call("limpiar")
	var f: FileAccess = FileAccess.open(_dir.path_join("celdas_hr.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(celdas, "\t"))
	f.close()
