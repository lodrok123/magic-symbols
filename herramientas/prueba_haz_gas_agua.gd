extends "res://herramientas/escenario_base.gd"
## PRUEBA (y capturas) DEL HAZ DE AGUA CON GAS (10/11/2026; item 5 de docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md). El MISMO HazGas/HazGasSolver del haz de fuego con el
## juego de parámetros del agua (HazGas.PARAMS_AGUA) y el dibujo del AguaToy (raymarch_toon_agua.glsl), enganchado en VfxToyJuego._haz con el ajuste magic_symbols/vfx_haz_gas_agua.
##   godot --headless --path . --script res://herramientas/prueba_haz_gas_agua.gd        → sin GPU: configuración, parámetros, paleta y FALLBACK (el AguaToy HAZ de siempre)
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_agua.gd -- [carpeta] [casos: aire,muro]   → además, con GPU, en el Bosque 01:
## Con GPU, en cada caso (haz REAL: Lanzador3D → HechizoVivo → VfxToyJuego → HazGasJuego en modo agua): el chorro lleva agua en su eje; NO hay hollín, ni polvo, ni combustible en
## ningún sitio; el agua CAE (al aire: pasado el final del chorro está por debajo de la boquilla; contra el muro: la lámina baja por la cara); contra el muro el agua se APLASTA
## y se REPARTE en lámina (agua pegada a la cara, más ancha que el chorro y que llega al suelo); nada vuelve hacia la jugadora; ningún agua dentro de los sólidos reales; los
## píxeles del agua son turquesa (los de AguaPaleta) y no hay ni uno naranja. Además: el tope de 2 gases es de fuego y agua JUNTOS; con el ajuste del agua apagado el agua sale
## con el AguaToy entero y el fuego sigue con gas; la lógica no cambia (daño, largo y choques con y sin gas); y el coste en GPU por haz.
## Capturas: <carpeta>/<caso>_juego.jpg (cámara del juego), <caso>_juego_16.jpg (1,6 s) y <caso>_lateral.jpg (de lado).

const AguaPaletaP = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const T_MEDIDA: float = 0.8

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_agua_gas"
var _casos: PackedStringArray = ["aire", "muro"]
var _tabla: Array = []
var _hz_ultimo: Dictionary = {}
var _cam_lat: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	Flags.nuevo()
	Misiones.nuevo()
	_config_y_parametros()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, true)
	FuegoToy.haz_ideas = true
	if RenderingServer.get_rendering_device() == null:
		_aviso("sin RenderingDevice (--headless): se salta lo de GPU; se comprueba el fallback. Con ventana: godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_agua.gd")
		await _fallback_sin_gpu()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
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
	for caso in _casos:
		await _caso(caso, c)
	await _tope_mixto(c)
	await _fallback_ajuste(c)
	await _logica_igual(c)
	print("== TABLA (caso | dominio | agua eje · hollín/polvo/comb máx · cae · lámina (pegada, ancho/R1, llega al suelo) · vuelve · dentro · turquesa/naranja · ms GPU)")
	for f in _tabla:
		print("  " + f)
	print("capturas en ", _dir)


# ------------------------------------------------------------------------------------------------------------------------------------------------ sin GPU

## Lo que se comprueba siempre (también sin ventana): el ajuste, los parámetros del agua, que el fuego no ha cambiado, el dominio del agua y la paleta.
func _config_y_parametros() -> void:
	_ok("el ajuste magic_symbols/vfx_haz_gas_agua existe en project.godot", ProjectSettings.has_setting(HazGasJuego.AJUSTE_AGUA))
	_ok("su valor de serie es AGUA_DEFECTO (%s)" % str(HazGasJuego.AGUA_DEFECTO), bool(ProjectSettings.get_setting(HazGasJuego.AJUSTE_AGUA, not HazGasJuego.AGUA_DEFECTO)) == HazGasJuego.AGUA_DEFECTO)
	var pa: Dictionary = HazGas.PARAMS_AGUA
	_ok("agua: sin combustión (burnRate, expansión y hollín a 0)", float(pa["burnRate"]) == 0.0 and float(pa["expansion"]) == 0.0 and float(pa["sootYield"]) == 0.0, str(pa))
	_ok("agua: sin flotación por calor y con peso (cae)", float(pa["buoyancy"]) == 0.0 and float(pa["weight"]) > 0.0)
	var gf := HazGas.new()
	var p: Dictionary = gf.params
	_ok("fuego: los parámetros de la demo no cambian (burnRate 2,2 · heat 0,85 · hollín 1,3 · expansión 1,5 · cool 1,1 · flotación 2,8 · peso 0 · turbulencia 55)",
		float(p["burnRate"]) == 2.2 and float(p["heat"]) == 0.85 and float(p["sootYield"]) == 1.3 and float(p["expansion"]) == 1.5 and float(p["cool"]) == 1.1 and float(p["buoyancy"]) == 2.8 \
		and float(p["weight"]) == 0.0 and float(p["turbulence"]) == 55.0 and gf.elemento == "fuego")
	_ok("fuego: el UBO lleva el elemento 0 (key_pos.w)", gf.parametros_gpu(0.0)[55] == 0.0)
	var ga := HazGas.new()
	ga.elemento = "agua"
	ga._aplicar_elemento()
	var u: PackedFloat32Array = ga.parametros_gpu(0.0)
	_ok("agua: el UBO lleva el elemento 1 y los parámetros del agua (burnRate, flotación, peso)", u[55] == 1.0 and u[33] == 0.0 and u[40] == 0.0 and u[41] == float(pa["weight"]), "w %.1f burn %.2f flota %.2f peso %.2f" % [u[55], u[33], u[40], u[41]])
	_ok("agua: el dibujo es siempre toon", ga.toon)
	gf.free()
	ga.free()
	var cfg: Dictionary = {"largo": 9.2, "ancho": 0.6, "alto": 1.0, "juego": true, "tam": 1.15, "obstaculo": "campo", "dist": 4.6, "alto_solido": 3.45}
	var d0: Dictionary = HazGas.derivar_haz(cfg)
	var cf: Dictionary = cfg.duplicate()
	cf["agua"] = false
	var d1: Dictionary = HazGas.derivar_haz(cf)
	var ca: Dictionary = cfg.duplicate()
	ca["agua"] = true
	var d2: Dictionary = HazGas.derivar_haz(ca)
	_ok("fuego: el dominio derivado es el mismo de antes", d0["res"] == d1["res"] and d0["lo"] == d1["lo"] and d0["tam"] == d1["tam"], "%s / %s" % [str(d0["res"]), str(d1["res"])])
	_ok("agua: el dominio es más bajo y más corto que el del fuego (cae: no hace falta sitio para el humo) con la misma celda", (d2["tam"] as Vector3).y < (d0["tam"] as Vector3).y and (d2["tam"] as Vector3).x <= (d0["tam"] as Vector3).x \
		and float(d2["h"]) == float(d0["h"]), "fuego %s · agua %s" % [str(d0["res"]), str(d2["res"])])
	var pal: Image = HazGas.paleta_agua().get_image()
	var cols: Array = [AguaPaletaP.HONDO, AguaPaletaP.SOMERO, AguaPaletaP.ESPUMA, AguaPaletaP.CAUSTICAS, AguaPaletaP.LECHO, AguaPaletaP.FRESNEL]
	var pal_ok: bool = true
	for i in cols.size():
		var q: Color = pal.get_pixel(i, 0)
		var w: Color = cols[i]
		if absf(q.r - w.r) > 0.005 or absf(q.g - w.g) > 0.005 or absf(q.b - w.b) > 0.005:
			pal_ok = false
	_ok("agua: la paleta del dibujo es AguaPaleta (HONDO, SOMERO, ESPUMA, CAUSTICAS, LECHO, FRESNEL)", pal_ok)


func _fallback_sin_gpu() -> void:
	_ok("sin RenderingDevice HazGasJuego.disponible(\"agua\") es false", not HazGasJuego.disponible("agua"))
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		_aviso("no carga el Bosque 01 sin ventana: no se comprueba el haz")
		return
	lanzador.tinta = null
	var c: Vector2i = _buscar_claro()
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	var v: VfxToyJuego = _vfx()
	var t0: int = int(v.creados["agua"]) if v != null else 0
	_lanzar("agua", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(3)
	v = _vfx()
	_ok("fallback sin GPU: el haz de agua sale con el AguaToy entero (sin gas)", v != null and int(v.creados["agua"]) > t0 and v.gas == null and _toy_agua_entero(v),
		"toys %d → %d" % [t0, int(v.creados["agua"]) if v != null else -1])


# ------------------------------------------------------------------------------------------------------------------------------------------------ casos con GPU

func _al_hechizo(_estado: String, elemento: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void:
	if g.has("haz"):
		_hz_ultimo = g["haz"]


func _vfx() -> VfxToyJuego:
	return root.find_child("VfxToyJuego", true, false) as VfxToyJuego


func _caso(caso: String, c: Vector2i) -> void:
	colocar_jugador(c)
	var gob_todos: Array = get_nodes_in_group("combate3d")
	for k in gob_todos.size():
		(gob_todos[k] as Node3D).position = Terreno3D.centro_de(Vector2i(c.x - 3 - k, c.y), Terreno3D.y_pies(Vector2i(c.x - 3 - k, c.y)))
	var dir: Vector3 = Vector3.RIGHT
	if caso == "muro":
		_muro(Vector2i(c.x + 2, c.y), 2)
	await avanzar_s(0.4)
	var v: VfxToyJuego = _vfx()
	var antes: int = v.gas.creados if v != null and v.gas != null else 0
	_hz_ultimo = {}
	var salio: bool = _lanzar("agua", ["linea_x", "linea_x"], dir, jugador.position)
	_ok("%s: sale el haz de agua" % caso, salio)
	await avanzar(2)
	v = _vfx()
	var hay_gas: bool = v != null and v.gas != null and v.gas.vivos() > 0 and v.gas.creados > antes
	var g: HazGas = v.gas.gases().back() if hay_gas else null
	_ok("%s: el haz de agua se dibuja con GAS en modo agua y el AguaToy no se ve" % caso, hay_gas and g.es_agua() and v.ultimo is AguaToy and not (v.ultimo as Node3D).is_visible_in_tree())
	if g == null:
		await avanzar_s(3.0)
		return
	await avanzar_s(T_MEDIDA - 0.3)
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	var fin: Vector3 = (_hz_ultimo.get("hasta", jugador.position + dir * 4.0) as Vector3)
	var centro: Vector3 = (jugador.position + fin) * 0.5 + Vector3(0, 0.6, 0)
	_guardar(_recorte(centro), "%s_juego.jpg" % caso)
	var vis: Dictionary = _analiza_volumen(g)
	g.pausa = true
	var m: Dictionary = _medidas(g)
	await _lateral(jugador.position, fin, "%s_lateral.jpg" % caso)
	g.pausa = false
	var ms: float = float(g.gpu_ms.get("total", 0.0))
	var ms_vol: float = float(g.gpu_ms.get("volumen", 0.0))
	var ms_sim: float = float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)) + float(g.gpu_ms.get("chispas", 0.0))
	await avanzar_s(0.8)
	if is_instance_valid(g) and g.listo():
		await RenderingServer.frame_post_draw
		_ocultar_ui(root)
		_guardar(_recorte(centro), "%s_juego_16.jpg" % caso)
		# a 1,6 s el chorro ya se ha cortado: lo que queda en el aire CAE (al aire, con el chorro encendido la punta todavía va empujada)
		g.pausa = true
		var m2: Dictionary = _medidas(g)
		m["cae"] = maxf(float(m["cae"]), float(m2["cae"]))
		g.pausa = false
	_evaluar(caso, g, m, vis, [ms, ms_sim, ms_vol])
	await avanzar_s(2.4)


func _evaluar(caso: String, g: HazGas, m: Dictionary, vis: Dictionary, ms: Array) -> void:
	var con_tope: bool = String(g.haz_der["obstaculo"]) == "campo"
	var r: Vector3i = g.haz_der["res"]
	var fila: String = "%-5s | %s %dx%dx%d | agua eje %.2f · hollín %.3f polvo %.3f comb %.3f · cae %.2f u · lámina %.0f%% ancho %.1f suelo %s · vuelve %.1f%% · dentro %d · turquesa %d px naranja %d · %.2f ms (sim %.2f · volumen %.2f)" % [
		caso, String(g.haz_der["obstaculo"]), r.x, r.y, r.z, float(m["agua_eje"]), float(m["soot_max"]), float(m["dust_max"]), float(m["fuel_max"]), float(m["cae"]),
		float(m["pegada"]) * 100.0, float(m["ancho_r1"]), str(m["suelo"]), float(m["vuelve"]) * 100.0, int(m["dentro"]), int(vis["agua"]), int(vis["naranja"]), ms[0], ms[1], ms[2]]
	_tabla.append(fila)
	_ok("%s: el chorro lleva agua en su eje" % caso, float(m["agua_eje"]) > 0.5, fila)
	_ok("%s: sin combustión (ni hollín, ni polvo, ni combustible)" % caso, float(m["soot_max"]) < 0.001 and float(m["dust_max"]) < 0.001 and float(m["fuel_max"]) < 0.001, fila)
	_ok("%s: el agua CAE (por debajo de la boquilla pasado el chorro / en la cara)" % caso, float(m["cae"]) > 0.3, fila)
	if con_tope:
		_ok("%s: se aplasta contra la cara y se reparte en LÁMINA (pegada a la cara, más ancha que el chorro y hasta el suelo)" % caso,
			float(m["pegada"]) > 0.25 and float(m["ancho_r1"]) > 2.0 and bool(m["suelo"]), fila)
	_ok("%s: nada vuelve hacia la jugadora" % caso, float(m["vuelve"]) < 0.03, fila)
	_ok("%s: ningún agua dentro de los sólidos reales" % caso, int(m["dentro"]) == 0, fila)
	_ok("%s: se ve agua turquesa (AguaPaleta) y nada naranja" % caso, int(vis["agua"]) > 200 and int(vis["naranja"]) == 0, fila)
	_ok("%s: se mide el coste en GPU del haz" % caso, ms[0] > 0.0, fila)


## Invariantes en el dominio (unidades del dominio). x = agua; y, z, w deben ser 0 (sin hollín, polvo ni combustible).
func _medidas(g: HazGas) -> Dictionary:
	var s: HazGasSolver = g.solver
	var d: Dictionary = g.haz_der
	var res: Vector3i = s.res
	var gas: PackedByteArray = s.leer(s.gas[0])
	var sol: PackedByteArray = s.leer(s.solido)
	var noz: Vector3 = d["nozzle"]
	var tg: Vector3 = d["target"]
	var con_tope: bool = String(d["obstaculo"]) == "campo"
	var d_u: float = float(d["d_u"])
	var eje: Vector3 = (tg - noz).normalized()
	var l_choque: float = d_u if con_tope else (tg - noz).length()
	var r1: float = float(d["beamR1"])
	var celda: float = s.mundo_tam.x / res.x
	var r = {"agua_eje": 0.0, "soot_max": 0.0, "dust_max": 0.0, "fuel_max": 0.0, "cae": 0.0, "pegada": 0.0, "ancho_r1": 0.0, "suelo": false, "vuelve": 0.0, "dentro": 0}
	var n_eje: int = 0
	var n_agua: int = 0
	var n_vuelve: int = 0
	var n_cara: int = 0
	var n_lejos: int = 0
	var y_lejos: float = 0.0
	var z_min: float = INF
	var z_max: float = -INF
	var y_cara_min: float = INF
	var margen: float = -maxf(0.25 * float(d["M"]), 2.0 * celda)
	for z in res.z:
		for y in res.y:
			for x in res.x:
				var o: int = ((z * res.y + y) * res.x + x) * 8
				var W: float = gas.decode_half(o)
				r["soot_max"] = maxf(float(r["soot_max"]), gas.decode_half(o + 2))
				r["dust_max"] = maxf(float(r["dust_max"]), gas.decode_half(o + 4))
				r["fuel_max"] = maxf(float(r["fuel_max"]), gas.decode_half(o + 6))
				if W < 0.3:              # el umbral del toon: el agua que se VE
					continue
				var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(res) * s.mundo_tam + s.mundo_lo
				if sol.decode_half(o) < margen:
					r["dentro"] += 1
				var t: float = (w - noz).dot(eje)
				var rad: float = (w - noz - eje * t).length()
				var tr: float = t / maxf(l_choque, 0.01)
				n_agua += 1
				if tr > 0.1 and tr < 0.45 and rad < 0.5 * r1:
					r["agua_eje"] += W
					n_eje += 1
				if tr < 0.35 and rad > 1.5 * r1:
					n_vuelve += 1
				if con_tope:
					# la cara del tope está en x = -d_u: «pegada» = el agua a menos de ~1,5 R1 delante de la cara
					if w.x < -d_u + 1.5 * r1 and w.x > -d_u - 0.5 * r1:
						n_cara += 1
						z_min = minf(z_min, w.z)
						z_max = maxf(z_max, w.z)
						y_cara_min = minf(y_cara_min, w.y)
				elif tr > 1.05:
					n_lejos += 1
					y_lejos += w.y
	r["agua_eje"] = float(r["agua_eje"]) / maxf(n_eje, 1)
	r["vuelve"] = float(n_vuelve) / maxf(n_agua, 1)
	if con_tope:
		r["pegada"] = float(n_cara) / maxf(n_agua, 1)
		r["ancho_r1"] = (z_max - z_min) / maxf(2.0 * r1, 0.001) if n_cara > 0 else 0.0
		r["suelo"] = y_cara_min < 3.0 * celda
		r["cae"] = noz.y - y_cara_min if n_cara > 0 else 0.0
	else:
		r["cae"] = noz.y - y_lejos / n_lejos if n_lejos > 0 else 0.0
	return r


## Píxeles del volumen (opacos) en la pantalla: cuántos son del turquesa del agua (H 150-200°) y cuántos naranjas o rojos (H < 40° o > 340° con saturación).
func _analiza_volumen(g: HazGas) -> Dictionary:
	var img: Image = root.get_viewport().get_texture().get_image()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tv: Vector2i = g.efecto._tam_vol
	if not g.efecto._crudo.is_valid():
		return {"agua": 0, "naranja": 0}
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var esc: Vector2 = Vector2(img.get_width(), img.get_height()) / Vector2(tv)
	var agua: int = 0
	var naranja: int = 0
	for y in range(0, tv.y, 2):
		for x in range(0, tv.x, 2):
			var o: int = (y * tv.x + x) * 8
			var al: float = 1.0 - datos.decode_half(o + 6)
			if al < 0.5:
				continue
			var c: Color = img.get_pixel(clampi(int((x + 0.5) * esc.x), 0, img.get_width() - 1), clampi(int((y + 0.5) * esc.y), 0, img.get_height() - 1))
			var h: float = c.h * 360.0
			if c.s > 0.25 and h >= 150.0 and h <= 200.0:
				agua += 1
			elif c.s > 0.45 and c.v > 0.3 and (h < 40.0 or h > 340.0):
				naranja += 1
	return {"agua": agua, "naranja": naranja}


# ------------------------------------------------------------------------------------------------------------------------------------------------ tope, fallback, lógica

## El tope de 2 gases es de fuego y agua JUNTOS: fuego + agua + agua → el tercero sale con el AguaToy de siempre, entero.
func _tope_mixto(c: Vector2i) -> void:
	await avanzar_s(3.5)
	var v: VfxToyJuego = _vfx()
	var rech0: int = v.gas.rechazados if v.gas != null else 0
	var elems: Array = ["fuego", "agua", "agua"]
	for k in 3:
		colocar_jugador(Vector2i(c.x, c.y + k * 2 - 2))
		_lanzar(elems[k], ["linea_x", "linea_x"], Vector3.RIGHT if k != 1 else Vector3(1, 0, 0.6).normalized(), jugador.position)
		await avanzar(3)
	var elementos_vivos: Array = v.gas.gases().map(func(g: HazGas) -> String: return g.elemento)
	_ok("tope mixto: como mucho %d gases a la vez entre fuego y agua" % HazGasJuego.MAX_INSTANCIAS, v.gas.vivos() <= HazGasJuego.MAX_INSTANCIAS, "vivos %s" % str(elementos_vivos))
	_ok("tope mixto: el agua que no cabe sale con el AguaToy de siempre (entero y visible)", v.gas.rechazados > rech0 and _toy_agua_entero(v), "rechazados %d" % v.gas.rechazados)
	await avanzar_s(3.5)


func _toy_agua_entero(v: VfxToyJuego) -> bool:
	var t: Node3D = v.ultimo
	if not (t is AguaToy) or not is_instance_valid(t):
		return false
	var ch: Node = t.find_child("Chorro", true, false)
	return ch is GeometryInstance3D and (ch as GeometryInstance3D).is_visible_in_tree()


## Ajuste del agua apagado: el agua sale con el AguaToy entero y el FUEGO sigue con gas (cada elemento con su ajuste).
func _fallback_ajuste(c: Vector2i) -> void:
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, false)
	await avanzar_s(1.0)
	colocar_jugador(c)
	var v: VfxToyJuego = _vfx()
	var n0: int = v.gas.creados if v.gas != null else 0
	_lanzar("agua", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(3)
	_ok("fallback: con magic_symbols/vfx_haz_gas_agua = false no se crea gas y el AguaToy HAZ sale entero", v.gas.creados == n0 and _toy_agua_entero(v))
	await avanzar_s(3.5)
	_lanzar("fuego", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(3)
	_ok("fallback: con el ajuste del agua apagado, el fuego sigue con su gas", v.gas.creados == n0 + 1 and v.gas.gases().back().elemento == "fuego")
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, true)
	await avanzar_s(3.5)


## La lógica no cambia: el mismo haz de agua contra el mismo goblin, con y sin gas, da lo mismo (vida, largo, choques).
func _logica_igual(c: Vector2i) -> void:
	var res: Array = []
	for con_gas in [true, false]:
		ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, con_gas)
		colocar_jugador(c)
		var gob: Node3D = get_nodes_in_group("combate3d")[0] if not get_nodes_in_group("combate3d").is_empty() else null
		if gob == null:
			_aviso("no hay goblins para comparar la lógica")
			return
		(gob as Combate3D).quieto = true
		gob.set("vida_max", 100000.0)
		gob.set("health", 100000.0)
		gob.position = Terreno3D.centro_de(Vector2i(c.x + 2, c.y), Terreno3D.y_pies(Vector2i(c.x + 2, c.y)))
		await avanzar_s(0.5)
		var v0: float = float(gob.get("health"))
		_hz_ultimo = {}
		_lanzar("agua", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
		await avanzar_s(2.0)
		res.append({"dano": v0 - float(gob.get("health")), "largo": float(_hz_ultimo.get("largo", -1.0)), "choques": (_hz_ultimo.get("choques", []) as Array).size()})
		gob.position = Terreno3D.centro_de(Vector2i(c.x - 3, c.y), Terreno3D.y_pies(Vector2i(c.x - 3, c.y)))
		await avanzar_s(2.5)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, true)
	_ok("la lógica no cambia: mismo daño, largo y choques del haz de agua con y sin gas", absf(float(res[0]["dano"]) - float(res[1]["dano"])) < 0.001 and absf(float(res[0]["largo"]) - float(res[1]["largo"])) < 0.001 \
		and int(res[0]["choques"]) == int(res[1]["choques"]), "con gas %s · sin gas %s" % [str(res[0]), str(res[1])])


# ------------------------------------------------------------------------------------------------------------------------------------------------ utilidades (como prueba_haz_gas_juego.gd)

func _lanzar(elem: String, glifos: Array, dir: Vector3, origen: Vector3) -> bool:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elem)
	for gl in glifos:
		lanzador.place_sigil(String(gl))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, origen, dir, false)


func _muro(q: Vector2i, apilar: int) -> void:
	lanzador.construir_tierra(q, true, {"resta": 3.6, "color": Color(0.5, 0.4, 0.3), "v2": true, "apilar": apilar, "elemento": "tierra"})


func _cam_juego(k: float) -> void:
	var tam: float = float(maqueta.get("_tam_camara")) * k
	maqueta.set("_tam_camara", tam)
	(maqueta.get("_camara") as Camera3D).size = tam


func _lateral(desde: Vector3, hasta: Vector3, nombre: String) -> void:
	if _cam_lat == null:
		_cam_lat = Camera3D.new()
		_cam_lat.fov = 45.0
		_cam_lat.far = 300.0
		maqueta.add_child(_cam_lat)
	var previa: Camera3D = root.get_viewport().get_camera_3d()
	var d: Vector3 = Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	var largo: float = maxf(d.length(), 2.0)
	var perp: Vector3 = d.normalized().cross(Vector3.UP).normalized()
	var mira: Vector3 = (desde + hasta) * 0.5 + d.normalized() * largo * 0.15 + Vector3(0, 0.8, 0)
	_cam_lat.global_position = mira - perp * (largo * 1.1 + 3.0) + Vector3(0, largo * 0.35 + 1.5, 0)
	_cam_lat.look_at(mira, Vector3.UP)
	_cam_lat.make_current()
	await avanzar(3)
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	_guardar(root.get_viewport().get_texture().get_image(), nombre)
	if previa != null and is_instance_valid(previa):
		previa.make_current()
	await avanzar(1)


func _guardar(img: Image, nombre: String) -> void:
	img.save_jpg(ProjectSettings.globalize_path(_dir.path_join(nombre)), 0.9)


func _recorte(centro: Vector3, ancho: int = 1280, alto: int = 720) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro) * k
	var w: int = mini(ancho, img.get_width())
	var h: int = mini(alto, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	return img.get_region(Rect2i(x0, y0, w, h))


func _buscar_claro() -> Vector2i:
	for y in range(5, 38):
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


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
