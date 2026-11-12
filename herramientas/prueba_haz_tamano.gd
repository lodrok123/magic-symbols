extends "res://herramientas/prueba_haz_gas_viento_rayo.gd"
## PRUEBA DEL TAMAÑO DE LOS HACES (12/11/2026, Pablo: «reduce el tamaño en general en todos los haces, un 50 %, así tenemos espacio para que en valores máximos esté
## como está ahora mismo cada haz»). El tamaño TRANSVERSAL del haz (grosor del chorro y todo lo del choque: lámina, abanico, envoltura, lazos, chispas, gotas) sale de
## HazGas.escala_de(h): ESCALA_BASE (0,5) con una sola ᛁ y ESCALA_MAX (1,0 = el tamaño de antes) con Hechizo.MAX_GLIFOS glifos. El LARGO y la lógica no cambian.
##   godot --headless --path . --script res://herramientas/prueba_haz_tamano.gd
##       → sin GPU: la escala de cada receta, el radio del chorro y la escala de la masa (M · s) del dominio de gas, el radio de los toys y el tamaño de sus choques
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_tamano.gd -- [carpeta] [etiqueta] [--costes]
##       → además, con GPU, en el Bosque 01 con hechizos REALES contra un muro, para fuego, agua, viento y rayo, un haz BÁSICO (ᛁ) y uno MÁXIMO (el haz de la lógica
##         de ᛁ ᛁ dibujado con un Hechizo de Hechizo.MAX_GLIFOS glifos: el lanzador de la prueba no admite tantos):
##         mide en METROS el grosor del chorro (p90 de la distancia al eje en el tramo medio) y el choque (p90 de lo que se aparta del contacto a los lados y hacia
##         la jugadora), comprueba básico ≈ 50 % del máximo, y si hay una medida de antes (<carpeta>/hoy.json), máximo ≈ 100 % de la de antes.
##         Capturas con la cámara del juego: <carpeta>/<etiqueta>_<elemento>_<basico|max>.jpg; medidas en <carpeta>/<etiqueta>.json. Carpeta de serie:
##         docs/capturas/vfx_en_juego/haz_gas_elementos/tamano (hoy.json y hoy_*.jpg = el código de antes, 2f20cfb8). Con --costes, además, la tabla de coste
##         (RONDAS rondas alternando básico y máximo, mediana). La hoja: python herramientas/hoja_tamano_haces.py.

const BASICO: Array = ["linea_x"]
const MAXIMO: Array = ["linea_x", "linea_x"]      ## el haz de la lógica del máximo; se DIBUJA con un Hechizo de Hechizo.MAX_GLIFOS glifos (ver _medir_haz)
const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "viento": "wind", "rayo": "lightning"}
const UMBRAL: Dictionary = {"fuego": 0.3, "agua": 0.3, "viento": 0.22, "rayo": 0.3}
const FRAMES: int = 75                 ## pasos de simulación (1,25 s) antes de medir
const RONDAS: int = 3                  ## rondas de la tabla de coste (-- ... --costes)
var _etiqueta: String = "nuevo"
var _medidas_t: Dictionary = {}


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	_dir = "res://docs/capturas/vfx_en_juego/haz_gas_elementos/tamano"
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_etiqueta = a[1]
	Flags.nuevo()
	Misiones.nuevo()
	_sin_gpu_tamano()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, true)
	for e in ["viento", "rayo"]:
		ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[e][0], true)
	FuegoToy.haz_ideas = true
	if RenderingServer.get_rendering_device() == null:
		_aviso("sin RenderingDevice (--headless): se salta lo de GPU. Con ventana: godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_tamano.gd")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = Vector2i(1280, 720)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		_ok("carga el Bosque 01", false)
		return
	lanzador.tinta = null
	(jugador as Jugador3D).vida = 100000.0
	lanzador.hechizo_v2.connect(_al_hechizo)
	_ocultar_ui(root)
	_cam_juego(1.6)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro llano en el Bosque 01", c != Vector2i(-1, -1), str(c))
	if c == Vector2i(-1, -1):
		return
	_c = c
	var gob: Array = get_nodes_in_group("combate3d")
	for k in gob.size():
		(gob[k] as Node3D).position = Terreno3D.centro_de(Vector2i(c.x - 3 - k, c.y), Terreno3D.y_pies(Vector2i(c.x - 3 - k, c.y)))
	for elem in ["fuego", "agua", "viento", "rayo"]:
		for nombre in ["basico", "max"]:
			var m: Dictionary = await _medir_haz(elem, nombre, BASICO if nombre == "basico" else MAXIMO)
			_medidas_t["%s_%s" % [elem, nombre]] = m
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(_dir.path_join(_etiqueta + ".json")), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_medidas_t, "\t"))
		f.close()
	var hoy: Dictionary = {}
	var ruta_hoy: String = ProjectSettings.globalize_path(_dir.path_join("hoy.json"))
	if _etiqueta != "hoy" and FileAccess.file_exists(ruta_hoy):
		hoy = JSON.parse_string(FileAccess.get_file_as_string(ruta_hoy)) as Dictionary
	print("== TAMAÑO (elemento | receta | escala | chorro p90 m | choque a los lados p90 m | choque hacia la jugadora p90 m | píxeles del volumen | ms GPU | rejilla)")
	for clave in _medidas_t:
		var m: Dictionary = _medidas_t[clave]
		print("  TAMANO %-14s | k %.2f | chorro %.3f | lados %.3f | atras %.3f | px %6d | %5.2f ms (sim %.2f · volumen %.2f) | %s" % [clave, float(m.get("k", 1.0)), float(m["chorro"]),
			float(m["lados"]), float(m["atras"]), int(m["px"]), float(m["ms"]), float(m.get("ms_sim", 0.0)), float(m.get("ms_vol", 0.0)), str(m["res"])])
	for elem in ["fuego", "agua", "viento", "rayo"]:
		var b: Dictionary = _medidas_t.get(elem + "_basico", {})
		var x: Dictionary = _medidas_t.get(elem + "_max", {})
		if b.is_empty() or x.is_empty():
			continue
		var rc: float = float(b["chorro"]) / maxf(float(x["chorro"]), 1e-4)
		if elem == "rayo":
			# el trazo del rayo es ANALÍTICO (raymarch_toon_rayo.glsl: grosor y zigzag × M); el gas solo lleva el halo de aire cargado, con la celda de antes
			# (HazGas.CELDA_EXP_ELEMENTO) y demasiado gruesa para medir un grosor de 0,2 m. Se mide lo que se dibuja: M en metros.
			rc = float(b["M"]) * float(b["s"]) / maxf(float(x["M"]) * float(x["s"]), 1e-4)
		var rl: float = float(b["lados"]) / maxf(float(x["lados"]), 1e-4)
		var ra: float = float(b["atras"]) / maxf(float(x["atras"]), 1e-4)
		var fila: String = "chorro %.2f · choque a los lados %.2f · hacia la jugadora %.2f (básico / máximo)" % [rc, rl, ra]
		_ok("%s: el chorro básico mide ~50 %% del máximo" % elem, rc > 0.35 and rc < 0.7, fila)
		_ok("%s: el choque básico mide ~50 %% del máximo (a los lados)" % elem, rl > 0.3 and rl < 0.75, fila)
		if not hoy.is_empty() and hoy.has(elem + "_max"):
			var h0: Dictionary = hoy[elem + "_max"]
			var qc: float = float(x["chorro"]) / maxf(float(h0["chorro"]), 1e-4)
			var ql: float = float(x["lados"]) / maxf(float(h0["lados"]), 1e-4)
			_ok("%s: el haz máximo mide ~100 %% del de antes" % elem, qc > 0.75 and qc < 1.33 and ql > 0.7 and ql < 1.4, "chorro %.2f · choque a los lados %.2f (máximo / antes)" % [qc, ql])
	if "--costes" in a:
		# COSTE: el reloj de la GPU del portátil baila (±30 % de una medida a otra): RONDAS rondas alternando básico y máximo, mediana de cada uno
		var tiempos: Dictionary = {}
		for ronda in RONDAS:
			for elem in ["fuego", "agua", "viento", "rayo"]:
				for nombre in ["basico", "max"]:
					var mc: Dictionary = await _medir_haz(elem, nombre, BASICO if nombre == "basico" else MAXIMO, true)
					var cl: String = "%s_%s" % [elem, nombre]
					if not tiempos.has(cl):
						tiempos[cl] = []
					(tiempos[cl] as Array).append(mc.get("ms", [0.0, 0.0, 0.0]))
		print("== COSTE (mediana de %d rondas; ms de GPU del haz: total · sim · volumen; contra el muro, 1280 × 720)" % RONDAS)
		for cl in tiempos:
			var l: Array = tiempos[cl]
			var med: Array = []
			for j in 3:
				var col: Array = l.map(func(x: Array) -> float: return float(x[j]))
				col.sort()
				med.append(col[col.size() / 2])
			print("  COSTE %-14s | %5.2f ms (sim %.2f · volumen %.2f) | %s" % [cl, med[0], med[1], med[2], str(l.map(func(x: Array) -> String: return "%.2f" % float(x[0])))])
	print("capturas en ", _dir)


## Lanza la receta contra un muro de tierra a 2 casillas, sujeta el chorro, espera FRAMES pasos, hace la captura de juego y mide el gas en metros.
func _medir_haz(elem: String, nombre: String, glifos: Array, solo_coste: bool = false) -> Dictionary:
	colocar_jugador(_c)
	_muro(Vector2i(_c.x + 2, _c.y), 2)
	await avanzar_s(0.4)
	var v: VfxToyJuego = _vfx()
	var antes: int = v.gas.creados if v != null and v.gas != null else 0
	_hz_ultimo = {}
	var salio: bool = _lanzar(elem, glifos, Vector3.RIGHT, jugador.position)
	await avanzar(2)
	v = _vfx()
	var hay_gas: bool = salio and v != null and v.gas != null and v.gas.vivos() > 0 and v.gas.creados > antes
	_ok("%s %s: sale el haz con gas" % [elem, nombre], hay_gas)
	if not hay_gas:
		await avanzar_s(4.0)
		return {}
	if nombre == "max" and not _hz_ultimo.is_empty():
		# el lanzador de la prueba no admite tantos glifos: el MISMO haz de la lógica se dibuja con un Hechizo de MAX_GLIFOS glifos (HazGasJuego.haz, como
		# hace VfxToyJuego). El gas del lanzado se suelta antes (si no, se reutilizaría con su tamaño).
		for e0 in v.gas._gases:
			e0["fin_haz"] = Time.get_ticks_msec()
			e0["fin_todo"] = Time.get_ticks_msec()
		var tope0: int = 0
		while v.gas.vivos() > 0 and tope0 < 60:
			await avanzar(1)
			tope0 += 1
		var hmax: Hechizo = Hechizo.construir(load("res://nucleo/%s_rune.tres" % RUNAS[elem]) as RuneData, {"linea_x": 2, "permanencia": Hechizo.MAX_GLIFOS - 2})
		if v.gas.haz(hmax, _hz_ultimo, Terreno3D.y_pies(_c), 0.9, elem) == null:
			_ok("%s %s: se dibuja el haz máximo" % [elem, nombre], false)
			return {}
	var g: HazGas = v.gas.gases().back()
	var e: Dictionary = v.gas._gases.back()
	e["fin_haz"] = Time.get_ticks_msec() + 600000
	e["fin_todo"] = int(e["fin_haz"]) + 2500
	g.chorro(true)
	var tope: int = 0
	if solo_coste:
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2100:
			await process_frame
		var r_c: Array = [float(g.gpu_ms.get("total", 0.0)), float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)) + float(g.gpu_ms.get("chispas", 0.0))
			+ float(g.gpu_ms.get("luz", 0.0)), float(g.gpu_ms.get("volumen", 0.0))]
		e["fin_haz"] = Time.get_ticks_msec()
		e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
		while v.gas.vivos() > 0 and tope < 600:
			await avanzar(1)
			tope += 1
		await avanzar_s(0.5)
		return {"ms": r_c}
	while g.frame < FRAMES and tope < 1200:
		await avanzar(1)
		tope += 1
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	var fin: Vector3 = (_hz_ultimo.get("hasta", jugador.position + Vector3.RIGHT * 4.0) as Vector3)
	_guardar(_recorte((jugador.position + fin) * 0.5 + Vector3(0, 0.6, 0), 900, 560), "%s_%s_%s.jpg" % [_etiqueta, elem, nombre])
	var px: int = _px_volumen(g)
	g.pausa = true
	var m: Dictionary = await _medir_gas_metros(elem, g)
	g.pausa = false
	m["px"] = px
	m["ms"] = float(g.gpu_ms.get("total", 0.0))
	m["ms_sim"] = float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)) + float(g.gpu_ms.get("chispas", 0.0)) + float(g.gpu_ms.get("luz", 0.0))
	m["ms_vol"] = float(g.gpu_ms.get("volumen", 0.0))
	m["res"] = str(g.solver.res)
	m["k"] = float(g.haz_cfg.get("escala", 1.0))
	m["M"] = float(g.escala_masa)
	m["s"] = float(g.metros_por_unidad)
	print("  %s %s: %s · %s" % [elem, nombre, str(m), g._texto_haz()])
	e["fin_haz"] = Time.get_ticks_msec()
	e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
	tope = 0
	while v.gas.vivos() > 0 and tope < 600:
		await avanzar(1)
		tope += 1
	await avanzar_s(1.5)
	return m


## Píxeles opacos del volumen en la pantalla (la textura del dibujo, antes de componer).
func _px_volumen(g: HazGas) -> int:
	if not g.efecto._crudo.is_valid():
		return 0
	var datos: PackedByteArray = RenderingServer.get_rendering_device().texture_get_data(g.efecto._crudo, 0)
	var tv: Vector2i = g.efecto._tam_vol
	var n: int = 0
	for i in range(tv.x * tv.y):
		if 1.0 - datos.decode_half(i * 8 + 6) >= 0.5:
			n += 1
	return n


## El gas en METROS: chorro = p90 de la distancia al eje del canal x por encima del umbral en el tramo medio (t 0,25-0,6); choque = lo que hay pasado t 0,75 y
## fuera del núcleo del chorro (más de 1,5 R1 del eje): p90 de su distancia al contacto en el plano de la sección (lados y arriba) y p90 de cuánto se aparta del
## contacto hacia la jugadora.
func _medir_gas_metros(elem: String, g: HazGas) -> Dictionary:
	var caja: Array = [PackedByteArray()]
	RenderingServer.call_on_render_thread(func() -> void: caja[0] = g.solver.leer(g.solver.gas[0]))
	await avanzar(2)
	var datos: PackedByteArray = caja[0]
	var r: Vector3i = g.solver.res
	if datos.size() != r.x * r.y * r.z * 8:
		return {"chorro": 0.0, "lados": 0.0, "atras": 0.0}
	var noz: Vector3 = g.params["nozzle"]
	var tg: Vector3 = g._target_base
	var ab: Vector3 = tg - noz
	var largo: float = ab.length()
	var dir: Vector3 = ab / largo
	var cont: Vector3 = g.contacto()
	var r1: float = float(g.params["beamR1"])
	var h: float = g.mundo_tam.x / float(r.x)
	var umbral: float = float(UMBRAL.get(elem, 0.3))
	var chorro: Array = []
	var lados: Array = []
	var atras: Array = []
	for z in range(0, r.z):
		for y in range(0, r.y):
			for x in range(0, r.x):
				var i: int = (x + r.x * (y + r.y * z)) * 8
				var vx: float = datos.decode_half(i)
				if not (vx > umbral):
					continue
				var w: Vector3 = g.mundo_lo + (Vector3(x, y, z) + Vector3.ONE * 0.5) * h
				var rel: Vector3 = w - noz
				var a: float = rel.dot(dir)
				var t: float = a / largo
				var d: float = (rel - dir * a).length()
				if t > 0.25 and t < 0.6:
					chorro.append(d)
				if t > 0.75 and d > 1.5 * r1:
					var rc: Vector3 = w - cont
					var ac: float = rc.dot(dir)
					lados.append((rc - dir * ac).length())
					if ac < 0.0:
						atras.append(-ac)
	var s: float = g.metros_por_unidad
	return {"chorro": _p90(chorro) * s, "lados": _p90(lados) * s, "atras": _p90(atras) * s, "n_chorro": chorro.size(), "n_choque": lados.size()}


static func _p90(v: Array) -> float:
	if v.is_empty():
		return 0.0
	v.sort()
	return float(v[int(v.size() * 0.9)])


## Sin GPU: la escala por receta, el dominio derivado (radio del chorro y escala de la masa EN METROS) y los toys (radio y choques).
func _sin_gpu_tamano() -> void:
	var consts: Dictionary = (load("res://laboratorios/haz_gas/haz_gas.gd") as Script).get_script_constant_map()
	if not consts.has("ESCALA_BASE"):
		_aviso("HazGas no tiene ESCALA_BASE (código de antes): solo se mide")
		return
	var runa: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	var hb: Hechizo = Hechizo.construir(runa, {"linea_x": 1})
	var hm: Hechizo = Hechizo.construir(runa, {"linea_x": 2, "permanencia": 4})
	var kb: float = HazGas.escala_de(hb)
	var km: float = HazGas.escala_de(hm)
	_ok("escala: un haz básico (ᛁ) = ESCALA_BASE (%.2f)" % HazGas.ESCALA_BASE, is_equal_approx(kb, HazGas.ESCALA_BASE), "%.3f" % kb)
	_ok("escala: un haz de %d glifos = ESCALA_MAX (%.2f, el tamaño de antes)" % [Hechizo.MAX_GLIFOS, HazGas.ESCALA_MAX], is_equal_approx(km, HazGas.ESCALA_MAX), "%.3f" % km)
	var anterior: float = 0.0
	var crece: bool = true
	for n in range(1, Hechizo.MAX_GLIFOS + 1):
		var hn: Hechizo = Hechizo.construir(runa, {"linea_x": 1, "permanencia": n - 1} if n > 1 else {"linea_x": 1})
		var kn: float = HazGas.escala_de(hn)
		if kn <= anterior:
			crece = false
		anterior = kn
	_ok("escala: crece con cada glifo, de la básica a la máxima", crece)
	var cas: float = Terreno3D.casilla
	var db: Dictionary = FuegoToy.describir(hb, cas)
	var dm: Dictionary = FuegoToy.describir(hm, cas)
	var z0: float = Hechizo.HAZ_ANCHO * cas * 0.5
	_ok("toy: el radio del haz básico es la mitad del de antes y el del máximo, el de antes", is_equal_approx(float(db["z"]), z0 * HazGas.ESCALA_BASE) and is_equal_approx(float(dm["z"]), z0),
		"%.3f / %.3f m (antes %.3f)" % [float(db["z"]), float(dm["z"]), z0])
	_ok("toy: el largo no cambia con la escala", is_equal_approx(float(db["x"]), hb.alcance_haz * cas * 0.5) and is_equal_approx(float(dm["x"]), hm.alcance_haz * cas * 0.5))
	for elem in ["fuego", "agua", "viento", "rayo"]:
		for tope in [false, true]:
			var largo: float = 6.9
			var cfg_b: Dictionary = {"largo": largo, "ancho": float(db["z"]), "alto": 1.2, "juego": true, "tam": cas * 0.5, "elemento": elem, "agua": elem == "agua",
				"escala": kb, "obstaculo": "campo" if tope else "nada", "dist": 4.0 if tope else largo, "alto_solido": cas * 1.5}
			var cfg_m: Dictionary = cfg_b.duplicate()
			cfg_m["ancho"] = float(dm["z"])
			cfg_m["escala"] = km
			var cfg_0: Dictionary = cfg_m.duplicate()
			cfg_0.erase("escala")
			var d_b: Dictionary = HazGas.derivar_haz(cfg_b)
			var d_m: Dictionary = HazGas.derivar_haz(cfg_m)
			var d_0: Dictionary = HazGas.derivar_haz(cfg_0)
			var rb: float = float(d_b["beamR1"]) * float(d_b["s"])
			var rm: float = float(d_m["beamR1"]) * float(d_m["s"])
			var mb: float = float(d_b["M"]) * float(d_b["s"])
			var mm: float = float(d_m["M"]) * float(d_m["s"])
			var celdas_b: int = (d_b["res"] as Vector3i).x * (d_b["res"] as Vector3i).y * (d_b["res"] as Vector3i).z
			var celdas_m: int = (d_m["res"] as Vector3i).x * (d_m["res"] as Vector3i).y * (d_m["res"] as Vector3i).z
			var caso: String = "%s %s" % [elem, "contra un tope" if tope else "al aire"]
			_ok("dominio %s: el máximo es el de antes (mismo dominio, rejilla y M)" % caso, d_m["res"] == d_0["res"] and d_m["lo"] == d_0["lo"] and is_equal_approx(float(d_m["M"]), float(d_0["M"])))
			_ok("dominio %s: radio del chorro y escala de la masa en metros del básico = %.0f %% del máximo" % [caso, HazGas.ESCALA_BASE * 100.0],
				is_equal_approx(rb / rm, kb / km) and absf(mb / mm - kb / km) < 0.02, "R1 %.3f / %.3f m · M·s %.3f / %.3f m" % [rb, rm, mb, mm])
			_ok("dominio %s: el largo (s) no cambia" % caso, is_equal_approx(float(d_b["s"]), float(d_m["s"])))
			_ok("dominio %s: el básico no tiene más celdas que el máximo (+5 %% como mucho)" % caso, celdas_b <= celdas_m * 1.05, "%s (%d) / %s (%d) · celda %.3f / %.3f u" % [str(d_b["res"]), celdas_b, str(d_m["res"]), celdas_m, float(d_b["h"]), float(d_m["h"])])
	# toys de respaldo: el radio sale de describir y el tamaño de la salpicadura / las hojas del choque, de escala_haz
	# (VientoToy, TierraToy y MagmaToy no dibujan choque en el haz: solo cambia su radio, que sale de describir)
	var hb_agua: Hechizo = Hechizo.construir(load("res://nucleo/water_rune.tres") as RuneData, {"linea_x": 1})
	for clase in [FuegoToy, AguaToy, RayoToy]:
		var t: Node3D = clase.new()
		t.call("desde_hechizo", hb_agua)
		_ok("toy %s: el choque del haz básico se escala (escala_haz = %.2f)" % [(t.get_script() as Script).resource_path.get_file(), kb], is_equal_approx(float(t.get("escala_haz")), kb))
		t.free()
	_ok("choque del toy: la salpicadura del fuego básico mide ~%.0f %% de la de antes" % (HazGas.ESCALA_BASE * 100.0),
		is_equal_approx(FuegoToy.tam_salpicadura(float(db["z"]) * FuegoToy.HAZ_ABRE, kb), FuegoToy.tam_salpicadura(z0 * FuegoToy.HAZ_ABRE, 1.0) * kb))
