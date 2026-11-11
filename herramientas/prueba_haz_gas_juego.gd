extends "res://herramientas/escenario_base.gd"
## PRUEBA (y capturas) DEL HAZ DE GAS TOON EN EL JUEGO (9/11/2026; presentacion/vfx/toy/haz_gas_juego.gd + laboratorios/haz_gas/). NECESITA VENTANA para lo de GPU:
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_juego.gd -- [carpeta] [casos separados por comas]
##   godot --headless --path . --script res://herramientas/prueba_haz_gas_juego.gd        → sin RenderingDevice: AVISO y comprueba el FALLBACK (el FuegoToy de siempre)
## Casos (Bosque 01 y el lab de puzles de fuego): aire, aire_diagonal, muro, muro_diagonal, esquina, roca, bloque, goblin, goblins_fila, barrera, cornisa, largo (ᛁ×6), dragon.
## En cada uno, con el haz REAL (Lanzador3D → HechizoVivo → VfxToyJuego → HazGasJuego), al final del haz se miran las invariantes del barrido del lab, en el dominio y
## relativas a su tamaño: chorro limpio y caliente en su primer tramo; con tope, masa que pasa del plano de la cara (rodea por los lados o por encima); humo en la masa y no en el
## chorro; nada vuelve hacia la jugadora; NINGÚN gas dentro de los sólidos reales (casillas, enemigos, bloques: se lee el propio campo de sólidos de la GPU); sin amarillo en el
## toon. Además: el fallback (ajuste apagado → FuegoToy entero), el tope de instancias y que la LÓGICA no cambia (daño a un goblin y largo/choques del haz iguales con y sin gas).
## Capturas: <carpeta>/<caso>_juego.jpg (cámara del juego) y <caso>_lateral.jpg (cámara de lado) y HOJA_RESUMEN.jpg (la compone tools: ver el final).

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"
const T_MEDIDA: float = 0.8

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_gas_juego"
var _casos: PackedStringArray = ["aire", "aire_diagonal", "muro", "muro_diagonal", "esquina", "roca", "bloque", "goblin", "goblins_fila", "barrera", "cornisa", "largo", "dragon"]
var _tabla: Array = []
var _hz_ultimo: Dictionary = {}
var _extras: Array = []
var _cam_lat: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	FuegoToy.haz_ideas = true
	if RenderingServer.get_rendering_device() == null:
		_aviso("sin RenderingDevice (--headless): se salta lo de GPU; se comprueba el fallback. Con ventana: godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_juego.gd")
		await _fallback_sin_gpu()
		return
	var bosque: Array = Array(_casos).filter(func(c: String) -> bool: return c != "dragon")
	if not bosque.is_empty():
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
		for caso in bosque:
			await _caso(caso, c)
		await _tope_instancias(c)
		await _logica_igual(c)
		await _fallback_ajuste(c)
	if _casos.has("dragon"):
		await _dragon()
	print("== TABLA (caso | dominio | T_eje · hollín eje/masa · pasa la cara · vuelve · dentro · amarillo · ms)")
	for f in _tabla:
		print("  " + f)
	print("capturas en ", _dir)


func _al_hechizo(_estado: String, elemento: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void:
	if elemento == "fuego" and g.has("haz"):
		_hz_ultimo = g["haz"]


func _vfx() -> VfxToyJuego:
	return root.find_child("VfxToyJuego", true, false) as VfxToyJuego


# ------------------------------------------------------------------------------------------------------------------------------------------------ casos

func _caso(caso: String, c: Vector2i) -> void:
	_quitar_extras()
	colocar_jugador(c)
	var gob_todos: Array = get_nodes_in_group("combate3d")
	for k in gob_todos.size():
		(gob_todos[k] as Node3D).position = Terreno3D.centro_de(Vector2i(c.x - 3 - k, c.y), Terreno3D.y_pies(Vector2i(c.x - 3 - k, c.y)))       # detrás de la jugadora: fuera de todo dominio
	var dir: Vector3 = Vector3.RIGHT
	var glifos: Array = ["linea_x", "linea_x"]
	match caso:
		"aire_diagonal":
			dir = Vector3(1, 0, 1).normalized()
		"muro":
			_muro(Vector2i(c.x + 2, c.y), 2)
		"muro_diagonal":
			for dz in range(-1, 3):
				_muro(Vector2i(c.x + 3, c.y + dz), 2)
			dir = Vector3(1, 0, 0.45).normalized()
		"esquina":
			_muro(Vector2i(c.x + 3, c.y), 2)
			_muro(Vector2i(c.x + 3, c.y + 1), 2)
			_muro(Vector2i(c.x + 2, c.y + 1), 2)
			_muro(Vector2i(c.x + 3, c.y - 1), 2)
			dir = Vector3(1, 0, 0.5).normalized()
		"roca", "bloque":
			var b := BloqueEmpujable3D.new()
			b.preparar(Vector2i(c.x + 2, c.y), "roca" if caso == "roca" else "piedra", maqueta)
			maqueta.add_child(b)
			_extras.append(b)
		"goblin":
			_goblins([Vector2i(c.x + 2, c.y)])
		"goblins_fila":
			_goblins([Vector2i(c.x + 1, c.y), Vector2i(c.x + 2, c.y), Vector2i(c.x + 3, c.y)])
			_muro(Vector2i(c.x + 5, c.y), 2)
			glifos = ["linea_x", "linea_x", "linea_x"]
		"barrera":
			_lanzar(["barrera", "linea_x", "linea_z", "altura"], Vector3.RIGHT, jugador.position + Vector3.RIGHT * Terreno3D.casilla * 2.0)
			await avanzar_s(0.8)
		"cornisa":
			_muro(Vector2i(c.x + 2, c.y), 1)
		"largo":
			glifos = ["linea_x", "linea_x", "linea_x", "linea_x", "linea_x", "linea_x"]
	await avanzar_s(0.4)
	var v: VfxToyJuego = _vfx()
	var antes: int = v.gas.creados if v != null and v.gas != null else 0
	_hz_ultimo = {}
	var salio: bool = _lanzar(glifos, dir, jugador.position)
	_ok("%s: sale el haz" % caso, salio)
	await avanzar(2)
	v = _vfx()
	var hay_gas: bool = v != null and v.gas != null and v.gas.vivos() > 0 and v.gas.creados > antes
	_ok("%s: el haz se dibuja con GAS (HazGasJuego)" % caso, hay_gas)
	if not hay_gas:
		await avanzar_s(3.0)
		return
	var g: HazGas = v.gas.gases().back()
	# 11/11 (3070): HazGasJuego corta el chorro por RELOJ REAL y esta prueba avanza a pasos fijos. Si un fotograma tarda (en el caso del goblin, el primer
	# «quemado» del enemigo compila lo suyo justo después del lanzamiento), el chorro llegaba a la medida ya cortado y el eje salía frío (T_eje 0,17).
	# Como en prueba_haz_gas_viento_rayo: se sujeta el chorro hasta que la SIMULACIÓN ha dado los pasos de T_MEDIDA y luego se suelta como siempre.
	var e_gas: Dictionary = v.gas._gases.back()
	var fin_real: int = int(e_gas["fin_haz"])
	e_gas["fin_haz"] = Time.get_ticks_msec() + 600000
	e_gas["fin_todo"] = int(e_gas["fin_haz"]) + 2500
	g.chorro(true)
	var tope: int = 0
	while g.frame < int((T_MEDIDA - 0.3) * 60.0) + 2 and tope < 900:
		await avanzar(1)
		tope += 1
	var ahora_ms: int = Time.get_ticks_msec()
	e_gas["fin_haz"] = maxi(fin_real, ahora_ms + int((Hechizo.HAZ_DURA_S - T_MEDIDA) * 1000.0))
	e_gas["fin_todo"] = int(e_gas["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
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
	# el humo nace donde el fuego FRENA: sobre todo cuando el chorro ya se ha apagado. La masa se vuelve a mirar a 1,6 s (lo que se ve mientras se deshace)
	await avanzar_s(0.8)
	if is_instance_valid(g) and g.listo():
		g.pausa = true
		var m2: Dictionary = _medidas(g)
		m["soot_masa"] = maxf(float(m["soot_masa"]), float(m2["soot_masa"]))
		await RenderingServer.frame_post_draw
		_guardar(_recorte(centro), "%s_juego_16.jpg" % caso)
		g.pausa = false
	_evaluar(caso, g, m, vis)
	await avanzar_s(2.4)


func _evaluar(caso: String, g: HazGas, m: Dictionary, vis: Dictionary) -> void:
	var con_tope: bool = String(g.haz_der["obstaculo"]) == "campo"
	var ok_eje: bool = float(m["T_eje"]) > 0.5 and float(m["soot_eje"]) < maxf(float(m["soot_masa"]), 0.02) / 1.5
	var ok_cara: bool = (not con_tope) or float(m["pasa"]) > 0.01
	var ok_vuelve: bool = float(m["vuelve"]) < 0.03
	var ok_dentro: bool = int(m["dentro"]) == 0
	var ok_amar: bool = float(vis["amarillo"]) < 0.01 and int(vis["fuego"]) > 200
	var r: Vector3i = g.haz_der["res"]
	var fila: String = "%-14s | %s %dx%dx%d s %.2f M %.2f | T_eje %.2f · hollín %.3f/%.3f · pasa la cara %.1f%% · vuelve %.1f%% · dentro %d · amarillo %.2f%% (%d px) · %.2f ms" % [
		caso, String(g.haz_der["obstaculo"]), r.x, r.y, r.z, float(g.haz_der["s"]), float(g.haz_der["M"]), float(m["T_eje"]), float(m["soot_eje"]), float(m["soot_masa"]),
		float(m["pasa"]) * 100.0, float(m["vuelve"]) * 100.0, int(m["dentro"]), float(vis["amarillo"]) * 100.0, int(vis["fuego"]), float(g.gpu_ms.get("total", 0.0))]
	_tabla.append(fila)
	_ok("%s: chorro limpio y caliente en su primer tramo" % caso, ok_eje, fila)
	_ok("%s: la masa pasa del plano del tope (envuelve el sólido real)" % caso, ok_cara, fila)
	_ok("%s: nada vuelve hacia la jugadora" % caso, ok_vuelve, fila)
	_ok("%s: ningún gas dentro de los sólidos reales" % caso, ok_dentro, fila)
	_ok("%s: sin amarillo en el toon" % caso, ok_amar, fila)


func _lanzar(glifos: Array, dir: Vector3, origen: Vector3) -> bool:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	for gl in glifos:
		lanzador.place_sigil(String(gl))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, origen, dir, false)


func _muro(q: Vector2i, apilar: int) -> void:
	lanzador.construir_tierra(q, true, {"resta": 3.6, "color": Color(0.5, 0.4, 0.3), "v2": true, "apilar": apilar, "elemento": "tierra"})       # caduca antes del caso siguiente


func _goblins(celdas: Array) -> void:
	var todos: Array = get_nodes_in_group("combate3d")
	for i in mini(celdas.size(), todos.size()):
		var gob: Node3D = todos[i]
		(gob as Combate3D).quieto = true
		gob.set("vida_max", 100000.0)
		gob.set("health", 100000.0)
		gob.position = Terreno3D.centro_de(celdas[i], Terreno3D.y_pies(celdas[i]))
	if todos.size() < celdas.size():
		_aviso("solo hay %d goblins en el nivel para %d casillas" % [todos.size(), celdas.size()])


func _quitar_extras() -> void:
	for e in _extras:
		if is_instance_valid(e):
			if e is BloqueEmpujable3D:
				Terreno3D.liberar_celda((e as BloqueEmpujable3D).celda)       # el bloque no suelta su casilla al irse (en el juego no se quita nunca)
			(e as Node).queue_free()
	_extras.clear()
	# los muros de tierra del caso anterior caducan solos («resta» 3,6 s)


# ------------------------------------------------------------------------------------------------------------------------------------------------ medidas

## Invariantes en el dominio (unidades del dominio). El sólido se lee del propio campo de la GPU (solver.solido), así «dentro» es exactamente lo que ve la simulación.
func _medidas(g: HazGas) -> Dictionary:
	var s: HazGasSolver = g.solver
	var d: Dictionary = g.haz_der
	var res: Vector3i = s.res
	var half: Vector3i = res / 2
	var gas: PackedByteArray = s.leer(s.gas[0])
	var vel: PackedByteArray = s.leer(s.vel[0])
	var sol: PackedByteArray = s.leer(s.solido)
	var paso: int = 2 if s.celdas > 1500000 else 1
	var noz: Vector3 = d["nozzle"]
	var tg: Vector3 = d["target"]
	var mm: float = float(d["M"])
	var con_tope: bool = String(d["obstaculo"]) == "campo"
	var d_u: float = float(d["d_u"])
	var eje: Vector3 = (tg - noz).normalized()
	var l_choque: float = d_u if con_tope else (tg - noz).length()
	var alto_u: float = float(d["centro"].y) * 2.0
	var r = {"T_eje": 0.0, "soot_eje": 0.0, "soot_masa": 0.0, "pasa": 0.0, "vuelve": 0.0, "dentro": 0}
	var n_eje: int = 0
	var n_masa: int = 0
	var n_cal: int = 0
	var n_pasa: int = 0
	var n_vuelve: int = 0
	var margen: float = -maxf(0.25 * mm, 2.0 * s.mundo_tam.x / res.x)
	for z in range(0, res.z, paso):
		for y in range(0, res.y, paso):
			for x in range(0, res.x, paso):
				var o: int = ((z * res.y + y) * res.x + x) * 8
				var T: float = gas.decode_half(o)
				var so: float = gas.decode_half(o + 2)
				if T < 0.02 and so < 0.005:
					continue
				var sd: float = sol.decode_half(o)
				if sd < margen and T + so > 0.03:          # gas que se VE (con el gas en pausa para medir, el campo se puede rehacer sin un paso que limpie restos de 0,01)
					r["dentro"] += 1
				var w: Vector3 = (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) / Vector3(res) * s.mundo_tam + s.mundo_lo
				var t: float = (w - noz).dot(eje)
				var rad: float = (w - noz - eje * t).length()
				var tr: float = t / maxf(l_choque, 0.01)
				if tr > 0.1 and tr < 0.45 and rad < 0.5 * float(d["beamR1"]):
					r["T_eje"] += T
					r["soot_eje"] += so
					n_eje += 1
				if tr > 0.75:
					r["soot_masa"] += so
					n_masa += 1
				if T > 0.15:
					n_cal += 1
					var vi: Vector3i = (Vector3i(x, y, z) / 2).clamp(Vector3i.ZERO, half - Vector3i.ONE)
					var vo: int = ((vi.z * half.y + vi.y) * half.x + vi.x) * 8
					# «vuelve»: gas caliente que LLEGA hacia la jugadora: en el primer 35 % del camino y fuera del chorro (a más de 1,5 R del eje)
					if tr < 0.35 and rad > 1.5 * float(d["beamR1"]):
						n_vuelve += 1
					if con_tope and (w.x < -d_u - 0.3 or w.y > alto_u + 0.2):
						n_pasa += 1
	r["T_eje"] = float(r["T_eje"]) / maxf(n_eje, 1)
	r["soot_eje"] = float(r["soot_eje"]) / maxf(n_eje, 1)
	r["soot_masa"] = float(r["soot_masa"]) / maxf(n_masa, 1)
	r["pasa"] = float(n_pasa) / maxf(n_cal, 1)
	r["vuelve"] = float(n_vuelve) / maxf(n_cal, 1)
	return r


## El volumen toon (rgb premultiplicado, a = fondo) y la pantalla: píxeles de fuego y cuántos caen en el amarillo (H 45-70°).
func _analiza_volumen(g: HazGas) -> Dictionary:
	var img: Image = root.get_viewport().get_texture().get_image()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tv: Vector2i = g.efecto._tam_vol
	if not g.efecto._crudo.is_valid():
		return {"fuego": 0, "amarillo": 0.0}
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var esc: Vector2 = Vector2(img.get_width(), img.get_height()) / Vector2(tv)
	var fuego: int = 0
	var amarillo: int = 0
	for y in range(0, tv.y, 2):
		for x in range(0, tv.x, 2):
			var o: int = (y * tv.x + x) * 8
			var al: float = 1.0 - datos.decode_half(o + 6)
			if al < 0.9:
				continue
			var c: Color = img.get_pixel(clampi(int((x + 0.5) * esc.x), 0, img.get_width() - 1), clampi(int((y + 0.5) * esc.y), 0, img.get_height() - 1))
			var lin: float = maxf(datos.decode_half(o), maxf(datos.decode_half(o + 2), datos.decode_half(o + 4))) / al
			if c.s > 0.5 and c.v > 0.45 and lin > 0.15:
				fuego += 1
				var h: float = c.h * 360.0
				if h >= 45.0 and h <= 70.0:
					amarillo += 1
	return {"fuego": fuego, "amarillo": float(amarillo) / maxf(fuego, 1)}


# ------------------------------------------------------------------------------------------------------------------------------------------------ fallback, tope, lógica

func _tope_instancias(c: Vector2i) -> void:
	_quitar_extras()
	await avanzar_s(3.5)
	var v: VfxToyJuego = _vfx()
	var rech0: int = v.gas.rechazados if v.gas != null else 0
	var toys0: int = int(v.creados["fuego"])
	for k in 3:
		colocar_jugador(Vector2i(c.x, c.y + k * 2 - 2))
		_lanzar(["linea_x", "linea_x"], Vector3.RIGHT if k != 1 else Vector3(1, 0, 0.6).normalized(), jugador.position)
		await avanzar(3)
	_ok("tope de instancias: como mucho %d gases a la vez" % HazGasJuego.MAX_INSTANCIAS, v.gas.vivos() <= HazGasJuego.MAX_INSTANCIAS, "vivos %d" % v.gas.vivos())
	_ok("tope de instancias: el que no cabe sale con el FuegoToy de siempre (con su chorro visible)", v.gas.rechazados > rech0 and _ultimo_toy_entero(v), "rechazados %d · toys %d → %d" % [v.gas.rechazados, toys0, int(v.creados["fuego"])])
	await avanzar_s(3.5)


func _ultimo_toy_entero(v: VfxToyJuego) -> bool:
	var t: Node3D = v.ultimo
	if t == null or not is_instance_valid(t):
		return false
	var ch: Node = t.find_child("Chorro", true, false)
	return ch is GeometryInstance3D and (ch as GeometryInstance3D).visible


## La lógica no cambia: el mismo haz contra el mismo goblin, con y sin gas, quita la misma vida y da el mismo largo y los mismos choques.
func _logica_igual(c: Vector2i) -> void:
	var res: Array = []
	for con_gas in [true, false]:
		ProjectSettings.set_setting(HazGasJuego.AJUSTE, con_gas)
		_quitar_extras()
		colocar_jugador(c)
		var gob: Node3D = get_nodes_in_group("combate3d")[0] if not get_nodes_in_group("combate3d").is_empty() else null
		if gob == null:
			_aviso("no hay goblins para comparar el daño")
			return
		_goblins([Vector2i(c.x + 2, c.y)])
		await avanzar_s(0.5)
		var v0: float = float(gob.get("health"))
		_hz_ultimo = {}
		_lanzar(["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
		await avanzar_s(2.0)
		res.append({"dano": v0 - float(gob.get("health")), "largo": float(_hz_ultimo.get("largo", -1.0)), "choques": (_hz_ultimo.get("choques", []) as Array).size()})
		await avanzar_s(2.5)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	_ok("la lógica no cambia: mismo daño, largo y choques con y sin gas", absf(float(res[0]["dano"]) - float(res[1]["dano"])) < 0.001 and absf(float(res[0]["largo"]) - float(res[1]["largo"])) < 0.001 and int(res[0]["choques"]) == int(res[1]["choques"]),
		"con gas %s · sin gas %s" % [str(res[0]), str(res[1])])


## Ajuste apagado (o sin GPU): el haz sale con el FuegoToy de siempre, entero.
func _fallback_ajuste(c: Vector2i) -> void:
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, false)
	_quitar_extras()
	await avanzar_s(3.5)
	colocar_jugador(c)
	var v: VfxToyJuego = _vfx()
	var n0: int = v.gas.creados if v.gas != null else 0
	_lanzar(["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(3)
	_ok("fallback: con magic_symbols/vfx_haz_gas = false no se crea gas y el FuegoToy sale entero", (v.gas == null or v.gas.creados == n0) and _ultimo_toy_entero(v))
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	await avanzar_s(2.0)


func _fallback_sin_gpu() -> void:
	_ok("sin RenderingDevice HazGasJuego.disponible() es false", not HazGasJuego.disponible())
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
	var t0: int = int(v.creados["fuego"]) if v != null else 0
	_lanzar(["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(3)
	v = _vfx()
	_ok("fallback sin GPU: el haz sale con el FuegoToy (sin gas)", v != null and int(v.creados["fuego"]) > t0 and (v.gas == null) and _ultimo_toy_entero(v), "toys %d → %d" % [t0, int(v.creados["fuego"]) if v != null else -1])


# ------------------------------------------------------------------------------------------------------------------------------------------------ dragón

func _dragon() -> void:
	await cargar(LAB)
	if maqueta == null or jugador == null:
		_ok("carga el lab de puzles de fuego", false)
		return
	_ocultar_ui(root)
	var pz: Puzle3D = (maqueta.get_node("Reglas").get("_puzle_nodo")) as Puzle3D
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	(jugador as Jugador3D).vida = 100000.0
	var a: TrampaDragon3D = pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = pz.nodo("t_drg_b") as TrampaDragon3D
	b.apagar(0.0)
	_despejar(maqueta)
	var cel := Vector2i(27, 10)
	var p: Vector3 = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p
	a.encender()
	await avanzar_s(3.0)
	var v: VfxToyJuego = _vfx()
	var max_vivos: int = 0
	var fotos: int = 0
	var seguro: int = 0
	var g_visto: HazGas = null
	while fotos < 3 and seguro < 9000:
		seguro += 1
		await process_frame
		if v != null and v.gas != null:
			max_vivos = maxi(max_vivos, v.gas.vivos())
			if v.gas.vivos() > 0:
				g_visto = v.gas.gases()[0]
		if a.fase == TrampaDragon3D.Fase.FUEGO and a._t_ciclo - a.apagada_s >= 0.35 + 0.5 * fotos:
			await RenderingServer.frame_post_draw
			_ocultar_ui(root)
			var img: Image = _recorte(a.global_position + Vector3(0.0, 0.6, 2.2), 900, 506)
			img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			_guardar(img, "dragon_juego_%d.jpg" % fotos)
			fotos += 1
	_ok("dragón: el chorro se dibuja con gas", v != null and v.gas != null and v.gas.creados > 0)
	_ok("dragón: el dominio PERSISTE entre relanzamientos (se reutiliza, la masa no parpadea)", v != null and v.gas != null and v.gas.reusados > 0 and max_vivos <= 1,
		"creados %d · reusados %d · vivos máx %d" % [v.gas.creados if v and v.gas else -1, v.gas.reusados if v and v.gas else -1, max_vivos])
	if g_visto != null and is_instance_valid(g_visto):
		var hz: Dictionary = {"hasta": g_visto.global_transform * (g_visto.haz_der["target"] as Vector3)}
		var vis: Dictionary = _analiza_volumen(g_visto)
		g_visto.pausa = true
		var m: Dictionary = _medidas(g_visto)
		await _lateral(g_visto.global_transform * (g_visto.haz_der["nozzle"] as Vector3), hz["hasta"], "dragon_lateral.jpg")
		g_visto.pausa = false
		_evaluar("dragon", g_visto, m, vis)
	a.apagar(0.0)


# ------------------------------------------------------------------------------------------------------------------------------------------------ cámaras y archivos

func _cam_juego(k: float) -> void:
	var tam: float = float(maqueta.get("_tam_camara")) * k
	maqueta.set("_tam_camara", tam)
	(maqueta.get("_camara") as Camera3D).size = tam


## Foto de lado: una cámara propia perpendicular al haz, que abarca de la mano al final con margen; luego vuelve la del juego.
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


## Esconde los árboles y las piezas altas del decorado (como captura_haz_fuego_ideas.gd) para ver la trampa limpia en la foto.
func _despejar(n: Node) -> void:
	for h in n.get_children():
		if h is TrampaPared3D or h is FlechaTrampa3D or h is Pj3D or h is Jugador3D or h is Lanzador3D or h is Combate3D or h is Camera3D or h is Light3D or h is HazGas:
			continue
		if h is MeshInstance3D and (h as MeshInstance3D).get_aabb().size.y * (h as Node3D).global_transform.basis.get_scale().y > 1.8:
			(h as Node3D).visible = false
		if h is MultiMeshInstance3D and String(h.name).begins_with("lote_pino"):
			(h as Node3D).visible = false
		_despejar(h)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
