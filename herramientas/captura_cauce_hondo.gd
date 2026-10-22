extends "res://herramientas/escenario_base.gd"
## CAPTURAS del CAUCE HONDO (22/10; Terreno3D.PROF_CAUCE 0,94, cauce_hondo). NECESITA VENTANA y Godot CERRADO (sin GPU no hay imagen).
##   godot --path . --script res://herramientas/captura_cauce_hondo.gd -- <carpeta>        (por defecto res://docs/capturas/cauce_hondo)
## Carga el Bosque 01 de verdad (PruebaBosque01.tscn: agua física, filtro, cámara del juego) y hace, por orden:
##   fijas_*     antes (cauce_hondo = false) / despues (true) a z6 y z3.2 (y z6 solo suelo)
##   entra_1..6  el jugador entra andando, cae, anda por el fondo y sale trepando (CÁMARA DEL JUEGO, siguiéndole)
##   labio_1..4  el jugador anda junto al borde (sombra del labio) con la cámara del juego
##   agua_t<s>_ancha / _cerca   el agua llenando el cauce (se pisa la losa T_C; fotos a 4, 9, 12, 16, 24 y 45 s)
## Escribe también el cuaderno de la caída (y del jugador y del foco de la cámara) y los objetos que cortan al tronco del estanque.
## Una foto IDÉNTICA a la anterior se avisa: es que la ventana no dibujaba (minimizada o tapada).

var _carpeta: String = "res://docs/capturas/cauce_hondo"
var _hash_prev: int = 0
var _fotos: int = 0
var _m: Node3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_carpeta = a[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	var gi: FileAccess = FileAccess.open(_carpeta.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await cargar("res://escenas/PruebaBosque01.tscn", true)
	if maqueta == null or jugador == null:
		return
	_m = maqueta as Node3D
	_ocultar_ui(root)
	await avanzar(60)
	await _fijas()
	await _entra()
	await _labio()
	await _tronco()
	await _agua()
	print("FOTOS %d en %s" % [_fotos, _carpeta])


# ---------------------------------------------------------------------------------------------------------------------
func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var hsh: int = hash(img.get_data())
	if hsh == _hash_prev:
		print("AVISO: %s es IDENTICA a la foto anterior (ventana sin dibujar, o nada cambió)" % nombre)
	_hash_prev = hsh
	img.save_png("%s/%s.png" % [_carpeta, nombre])
	_fotos += 1
	var cam: Node3D = _m.get("_camara") as Node3D
	var foco: Vector3 = _m.get("_foco")
	var yj: Vector3 = jugador.position
	print("FOTO %s | jugador (%.2f %.2f %.2f) | foco cámara (%.2f %.2f %.2f) | t %.1f s" % [nombre, yj.x, yj.y, yj.z, foco.x, foco.y, foco.z, reloj.t])


## Congela la cámara en `c` (en casillas, centro) con el tamaño de vista `tam`: el jugador deja de mandar en ella.
func _fija(c: Vector2, tam: float) -> void:
	_m.set("_jugador", null)
	_m.set("_foco", Vector3((c.x + 0.5) * Terreno3D.casilla, 0.5, (c.y + 0.5) * Terreno3D.casilla))
	_m.set("_tam_camara", tam)
	(_m.get("_camara") as Camera3D).size = tam
	_m.call("_colocar_camara")


var _pj: Variant = null      ## el Pj3D de la maqueta, para devolverle el seguimiento


func _suelta_camara() -> void:
	_m.set("_jugador", _pj)
	_m.set("_tam_camara", float(_m.get("ZOOM_INICIAL")))
	(_m.get("_camara") as Camera3D).size = float(_m.get("ZOOM_INICIAL"))


# ---------------------------------------------------------------------------------------------------------------------
func _fijas() -> void:
	_pj = _m.get("_jugador")
	var fondo: float = Terreno3D.fondo_cauce()
	print("DATOS alto_suelo %.3f fondo %.3f PROF_CAUCE %.3f ALTO_NIVEL %.3f" % [Terreno3D.alto_suelo, fondo, Terreno3D.PROF_CAUCE, Terreno3D.ALTO_NIVEL])
	colocar_jugador(Vector2i(10, 5))
	await avanzar(5)
	for modo in [true, false]:
		_m.set("cauce_hondo", modo)
		for t in [[6.0, false, "z6"], [3.2, false, "z3"], [6.0, true, "z6_suelo"]]:
			var solo: bool = t[1]
			for nodo in ["Decorado", "Piezas", "Borde"]:
				var nd: Node = _m.get_node_or_null(nodo)
				if nd is Node3D:
					(nd as Node3D).visible = not solo
			if _m.get("_hierba") != null:
				(_m.get("_hierba") as Node3D).visible = not solo
			_fija(Vector2(16.0, 13.5), float(t[0]))
			await avanzar(70)
			await _foto("fija_%s_%s" % ["despues" if modo else "antes", t[2]])
	for nodo in ["Decorado", "Piezas", "Borde"]:
		var nd2: Node = _m.get_node_or_null(nodo)
		if nd2 is Node3D:
			(nd2 as Node3D).visible = true
	if _m.get("_hierba") != null:
		(_m.get("_hierba") as Node3D).visible = true
	_m.set("cauce_hondo", true)
	await avanzar(10)


# ---------------------------------------------------------------------------------------------------------------------
var _w: Vector2 = Vector2.ZERO
var _d: Vector2 = Vector2.ZERO
var _lag_max: float = 0.0
var _traza: Array = []


## Anda de verdad (teclas) hasta la casilla `c`; cada fotograma mira los `disparos` [{n, f: Callable() -> bool}] y hace la foto la primera vez que cumplen.
func _caminar(c: Variant, disparos: Array, max_s: float = 14.0) -> bool:
	var meta: Vector3 = Terreno3D.centro_de(c, 0.0) if c is Vector2i else (c as Vector3)
	var inicio: float = reloj.t
	var llego: bool = false
	var hechos: Dictionary = {}
	while reloj.t - inicio < max_s:
		var a := Vector2(meta.x - jugador.position.x, meta.z - jugador.position.z)
		if a.length() <= 0.25 * Terreno3D.casilla:
			llego = true
			break
		var adelante: float = a.dot(_w)
		var lado: float = a.dot(_d)
		_tecla(KEY_W, adelante > 0.15 * a.length())
		_tecla(KEY_S, adelante < -0.15 * a.length())
		_tecla(KEY_D, lado > 0.15 * a.length())
		_tecla(KEY_A, lado < -0.15 * a.length())
		await process_frame
		var foco: Vector3 = _m.get("_foco")
		var centro: Vector3 = jugador.position + Vector3(0.0, 0.85, 0.0)
		_lag_max = maxf(_lag_max, foco.distance_to(centro))
		_traza.append([snappedf(reloj.t, 0.01), snappedf(jugador.position.x / Terreno3D.casilla, 0.01), snappedf(jugador.position.y, 0.01), snappedf(foco.y - centro.y, 0.01)])
		for dsp in disparos:
			if not hechos.has(dsp["n"]) and (dsp["f"] as Callable).call():
				hechos[dsp["n"]] = true
				await _foto(dsp["n"])
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	return llego


func _entra() -> void:
	var alto: float = Terreno3D.alto_suelo
	var fondo: float = Terreno3D.fondo_cauce()
	_suelta_camara()
	var S: float = Terreno3D.casilla
	colocar_jugador(Vector2i(14, 16))      # fila 16: el tronco del estanque (16,14) bloquea el fondo más al norte (22/10)
	await avanzar(40)
	_w = await _empuje(KEY_W)
	_d = await _empuje(KEY_D)
	await avanzar(30)
	var fx := func() -> float: return jugador.position.x / S
	var fz := func() -> float: return jugador.position.z / S
	var y := func() -> float: return jugador.position.y
	var ok1: bool = await _caminar(Vector2i(16, 16), [
		{"n": "entra_1_borde", "f": func() -> bool: return fx.call() >= 15.45 and y.call() >= alto - 0.02},
		{"n": "entra_2_cayendo", "f": func() -> bool: return y.call() < alto - 0.3 and y.call() > fondo + 0.2},
		{"n": "entra_3_fondo", "f": func() -> bool: return y.call() <= fondo + 0.04 and bool(jugador.get("en_suelo"))},
	], 10.0)
	var ok2: bool = await _caminar(Vector2i(16, 15), [
		{"n": "entra_4_anda_fondo", "f": func() -> bool: return fz.call() <= 15.75},
	], 10.0)
	await _caminar(Vector2i(16, 16), [], 10.0)
	var ok3: bool = await _caminar(Vector2i(18, 16), [
		{"n": "entra_5_trepa", "f": func() -> bool: return fx.call() > 17.0 and y.call() > fondo + 0.25 and y.call() < alto - 0.15},
		{"n": "entra_6_fuera", "f": func() -> bool: return y.call() >= alto - 0.03 and fx.call() > 17.15},
	], 10.0)
	print("ENTRA final: celda %s pos %s; cola de la traza %s" % [str(celda_jugador()), str(jugador.position), str(_traza.slice(-3))])
	print("ENTRA llega %s %s %s | desfase máximo foco-jugador %.2f u | y mín %.3f (fondo %.3f)" % [ok1, ok2, ok3, _lag_max, _y_min(), fondo])
	# Cuaderno de la caída: un muestreo cada ~0,1 s, de la entrada al fondo.
	var s: String = ""
	var ult: float = -1.0
	for p in _traza:
		if float(p[0]) - ult >= 0.12 and float(p[2]) < alto - 0.01 + 0.0 and float(p[2]) > fondo - 0.01 and float(p[1]) < 17.3:
			s += "(t%.2f x%.2f y%.2f dfoco%.2f) " % [p[0], p[1], p[2], p[3]]
			ult = float(p[0])
	print("TRAZA caída/fondo/trepada: " + s)


func _y_min() -> float:
	var m: float = INF
	for p in _traza:
		m = minf(m, float(p[2]))
	return m


# ---------------------------------------------------------------------------------------------------------------------
func _labio() -> void:
	var S: float = Terreno3D.casilla
	colocar_jugador(Vector2i(15, 11))
	var x_borde: float = 16.0 * S - 0.45        # a 0,45 u del labio (el centro de la casilla 15 está a 1,15)
	jugador.position.x = x_borde
	(jugador.get("pj") as Node3D).position.x = x_borde
	await avanzar(50)
	var fz := func() -> float: return jugador.position.z / S
	var nombres: Array = []
	var disp: Array = []
	for i in range(4):
		var z0: float = 11.9 + 2.0 * float(i)
		disp.append({"n": "labio_%d" % (i + 1), "f": (func() -> bool: return fz.call() >= z0)})
	await _caminar(Vector3(x_borde, 0.0, 19.5 * S), disp, 14.0)
	nombres.clear()


# ---------------------------------------------------------------------------------------------------------------------
## ¿Qué atraviesa al tronco del estanque? Cajas globales de todas las mallas del nivel que se cortan con la del tronco (sin él).
func _tronco() -> void:
	var tr: TroncoEstanque3D = maqueta.get_node("Reglas").get("_tronco_estanque") as TroncoEstanque3D
	if tr == null:
		print("TRONCO: no hay")
		return
	var cajas_t: Array = []
	for mi in tr.find_children("*", "MeshInstance3D", true, false):
		cajas_t.append((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb())
	var cortan: Array = []
	for mi in maqueta.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or tr.is_ancestor_of(m) or m.is_ancestor_of(tr) or not m.is_visible_in_tree():
			continue
		var cb: AABB = m.global_transform * m.get_aabb()
		for ct in cajas_t:
			if (ct as AABB).intersects(cb):
				cortan.append("%s (%s) y %.2f..%.2f" % [str(m.get_path()).get_slice("/", 3) + "/…/" + m.name, m.get_class(), cb.position.y, cb.position.y + cb.size.y])
				break
	print("TRONCO en (%.2f %.2f %.2f), abierto %s; mallas que cortan su caja: %d" % [tr.position.x, tr.position.y, tr.position.z, str(tr.abierto), cortan.size()])
	for c in cortan.slice(0, 15):
		print("   · " + c)
	var cel: Vector2i = Terreno3D.celda_de(tr.position)
	_fija(Vector2(float(cel.x), float(cel.y)), 3.2)
	await avanzar(50)
	await _foto("tronco_seco_cerca")


# ---------------------------------------------------------------------------------------------------------------------
func _agua() -> void:
	_suelta_camara()
	colocar_jugador(Vector2i(16, 9))      # la losa T_C (presencia): abre el manantial
	await avanzar(20)
	_fija(Vector2(17.0, 13.0), 12.0)
	var t0: float = reloj.t
	for seg in [4, 9, 12, 16, 24, 45]:
		while reloj.t - t0 < float(seg):
			await process_frame
		_fija(Vector2(17.0, 13.0), 12.0)
		await _foto("agua_t%02d_ancha" % seg)
		_fija(Vector2(16.0, 13.5), 4.5)
		await avanzar(3)
		await _foto("agua_t%02d_cerca" % seg)
	var sim: AguaSim3D = Terreno3D.agua_sim
	print("AGUA al final: profundidad (16,13) %.2f, (16,18) %.2f; abierta %s" % [sim.profundidad_casilla(Vector2i(16, 13)), sim.profundidad_casilla(Vector2i(16, 18)), str(Terreno3D.cauces_abiertos.has(Vector2i(16, 13)))])


