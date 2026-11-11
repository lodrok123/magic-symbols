extends "res://herramientas/prueba_haz_gas_agua.gd"
## PRUEBA (y capturas) DE LOS HACES DE VIENTO Y DE RAYO CON GAS (11/11/2026). El MISMO HazGas/HazGasSolver del fuego y del agua con HazGas.PARAMS_VIENTO / PARAMS_RAYO y sus
## dibujos (raymarch_toon_viento.glsl, raymarch_toon_rayo.glsl), enganchados en VfxToyJuego._haz con los ajustes magic_symbols/vfx_haz_gas_viento y vfx_haz_gas_rayo
## (APAGADOS de serie). Reutiliza las ayudas de la prueba del agua.
##   godot --headless --path . --script res://herramientas/prueba_haz_gas_viento_rayo.gd      → sin GPU: parámetros, dominio, ajustes de serie y que el fuego y el agua no cambian
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_viento_rayo.gd -- [carpeta]
##       → además, con GPU, en el Bosque 01 con hechizos REALES (Lanzador3D → HechizoVivo → VfxToyJuego → HazGasJuego), al aire y contra un muro:
##         sale con gas del elemento; no hay NaN; el canal x tiene materia en el eje del chorro; nada dentro de los sólidos; con el ajuste apagado sale el toy de siempre;
##         la lógica (largo y choques del haz) es la misma con y sin gas. Capturas: <carpeta>/<elemento>_<aire|muro>_juego.jpg y _lateral.jpg.
## 11/11 (3070): además, el COLOR de lo que se ve (viento: trazos blancos; rayo: azul; nunca naranja de fuego), el rayo que SALTA a un goblin golpeado
## (rayo_cuerpo_juego.jpg), el rayo de UN SOLO DESTELLO (hechizo de 0,1 s; rayo_destello_juego.jpg) y la tabla de COSTE de los cuatro haces (fuego, agua,
## viento, rayo; al aire y contra el muro; ventana de 1280 × 720). `-- <carpeta> --sin-costes` se salta la tabla.


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	_dir = "res://docs/capturas/vfx_en_juego/haz_gas_elementos"
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	Flags.nuevo()
	Misiones.nuevo()
	_sin_gpu()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	if RenderingServer.get_rendering_device() == null:
		_aviso("sin RenderingDevice (--headless): se salta lo de GPU. Con ventana: godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_viento_rayo.gd")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	root.get_window().mode = Window.MODE_WINDOWED            # a veces se abre maximizada (2560 × 1369): capturas y costes, siempre a 1280 × 720
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
	colocar_jugador(c)
	var gob: Array = get_nodes_in_group("combate3d")
	for k in gob.size():
		(gob[k] as Node3D).position = Terreno3D.centro_de(Vector2i(c.x - 3 - k, c.y), Terreno3D.y_pies(Vector2i(c.x - 3 - k, c.y)))
	_c = c
	for caso in ["aire", "muro"]:
		for elem in ["viento", "rayo"]:
			# con el ajuste apagado (el plan B; de serie está encendido desde el 11/11): el toy de siempre, sin gas, y lo que dice la lógica
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], false)
			var sin: Dictionary = await _un_haz(elem, caso, false)
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], true)
			var con: Dictionary = await _un_haz(elem, caso, true)
			# contra el muro solo se comparan los choques: el muro de tierra de la prueba sube y se hunde, y el largo depende del instante en que lo pilla cada haz
			_ok("%s %s: la lógica no cambia con el gas (%s)" % [elem, caso, "largo y choques" if caso == "aire" else "choques"], not sin.is_empty() and not con.is_empty()
				and (caso == "muro" or absf(float(sin["largo"]) - float(con["largo"])) < 0.01) and int(sin["choques"]) == int(con["choques"]), "%s / %s" % [str(sin), str(con)])
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], false)
	await _rayo_cuerpo()
	await _rayo_destello()
	if not "--sin-costes" in OS.get_cmdline_user_args():
		await _costes()
	print("capturas en ", _dir)


# ------------------------------------------------------------------------------------------------------------------------------------------------ 11/11 (3070)

## Píxeles del volumen (opacos) en la pantalla, por color: BLANCO (trazos del viento: poca saturación, claros), AZUL (el rayo: H 185-235°) y NARANJA DE FUEGO
## (H < 40° o > 340°, saturación > 0,65: el polvo del viento, pardo y apagado, no cuenta). `cerca` (opcional, píxeles de pantalla): solo alrededor de ese punto.
func _colores(g: HazGas, cerca: Vector2 = Vector2(-1, -1), radio: float = 0.0) -> Dictionary:
	var img: Image = root.get_viewport().get_texture().get_image()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tv: Vector2i = g.efecto._tam_vol
	var r: Dictionary = {"blanco": 0, "azul": 0, "naranja": 0}
	if not g.efecto._crudo.is_valid():
		return r
	var datos: PackedByteArray = rd.texture_get_data(g.efecto._crudo, 0)
	var esc: Vector2 = Vector2(img.get_width(), img.get_height()) / Vector2(tv)
	for y in range(0, tv.y):
		for x in range(0, tv.x):
			var o: int = (y * tv.x + x) * 8
			if 1.0 - datos.decode_half(o + 6) < 0.5:
				continue
			var px: Vector2 = Vector2((x + 0.5) * esc.x, (y + 0.5) * esc.y)
			if radio > 0.0 and px.distance_to(cerca) > radio:
				continue
			var c: Color = img.get_pixel(clampi(int(px.x), 0, img.get_width() - 1), clampi(int(px.y), 0, img.get_height() - 1))
			var h: float = c.h * 360.0
			if c.s < 0.16 and c.v > 0.8:
				r["blanco"] += 1
			elif c.s > 0.2 and h >= 185.0 and h <= 235.0:
				r["azul"] += 1
			elif c.s > 0.65 and c.v > 0.4 and (h < 40.0 or h > 340.0):
				r["naranja"] += 1
	return r


## Comprueba el color del volumen del elemento (lo que se ve en la pantalla de juego).
func _ok_colores(elem: String, caso: String, g: HazGas) -> void:
	var col: Dictionary = _colores(g)
	var fila: String = "blanco %d · azul %d · naranja %d px" % [int(col["blanco"]), int(col["azul"]), int(col["naranja"])]
	if elem == "viento":
		_ok("viento %s: se ven trazos BLANCOS y nada naranja de fuego" % caso, int(col["blanco"]) > 40 and int(col["naranja"]) == 0, fila)
	else:
		_ok("rayo %s: el trazo es AZUL (no el amarillo de RayoPaleta.CUERPO) y nada naranja de fuego" % caso, int(col["azul"]) > 150 and int(col["naranja"]) == 0, fila)


## Rayo contra un goblin en la línea del haz: la rama salta al CUERPO (HazGas.rayo_cuerpos sale de los choques de la lógica) y alrededor de él hay trazo azul.
func _rayo_cuerpo() -> void:
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_RAYO, true)
	colocar_jugador(_c)
	var gob: Array = get_nodes_in_group("combate3d")
	if gob.is_empty():
		_aviso("no hay goblins en el nivel: no se prueba el salto a los cuerpos")
		return
	var gb: Node3D = gob[0]
	gb.set("vida_max", 100000.0)
	gb.set("health", 100000.0)
	gb.position = Terreno3D.centro_de(Vector2i(_c.x + 2, _c.y), Terreno3D.y_pies(Vector2i(_c.x + 2, _c.y)))
	await avanzar_s(0.3)
	var v: VfxToyJuego = _vfx()
	var antes: int = v.gas.creados if v != null and v.gas != null else 0
	_hz_ultimo = {}
	_lanzar("rayo", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	await avanzar(2)
	v = _vfx()
	var hay: bool = v != null and v.gas != null and v.gas.vivos() > 0 and v.gas.creados > antes
	var g: HazGas = v.gas.gases().back() if hay else null
	var choques: Array = (_hz_ultimo.get("choques", []) as Array)
	var golpea: bool = choques.any(func(ch: Dictionary) -> bool: return String(ch.get("tipo", "")) != "muro")
	_ok("rayo cuerpo: la lógica golpea al goblin", golpea, str(choques.map(func(ch: Dictionary) -> String: return String(ch.get("tipo", "")))))
	_ok("rayo cuerpo: la rama del dibujo conoce el cuerpo (rayo_cuerpos)", g != null and g.rayo_cuerpos.size() >= 1, str(g.rayo_cuerpos if g != null else []))
	if g == null:
		return
	var e: Dictionary = v.gas._gases.back()
	e["fin_haz"] = Time.get_ticks_msec() + 600000
	g.chorro(true)
	var tope: int = 0
	while g.frame < 30 and tope < 900:
		await avanzar(1)
		tope += 1
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var img_w: float = float(root.get_viewport().get_texture().get_width())
	# el cuerpo que golpea la lógica (puede no ser el goblin puesto en la línea: el haz se para en el primero que cruza)
	var cb: Vector4 = g.rayo_cuerpos[0] if not g.rayo_cuerpos.is_empty() else Vector4.ZERO
	var cuerpo_w: Vector3 = g.global_transform * Vector3(cb.x, cb.y, cb.z)
	var p: Vector2 = lanzador.camara.unproject_position(cuerpo_w + Vector3(0, 0.3, 0)) * (img_w / maxf(vis.x, 1.0))
	var col: Dictionary = _colores(g, p, 60.0 * img_w / 1280.0)
	var col_todo: Dictionary = _colores(g)
	_guardar(_recorte((jugador.position + cuerpo_w) * 0.5 + Vector3(0, 0.6, 0)), "rayo_cuerpo_juego.jpg")
	_ok("rayo cuerpo: hay trazo (azul o su núcleo blanco) sobre el cuerpo y nada naranja", int(col["azul"]) + int(col["blanco"]) > 20 and int(col_todo["naranja"]) == 0,
		"junto al cuerpo azul %d + blanco %d px · en todo el haz azul %d · naranja %d" % [int(col["azul"]), int(col["blanco"]), int(col_todo["azul"]), int(col_todo["naranja"])])
	e["fin_haz"] = Time.get_ticks_msec()
	e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
	tope = 0
	while v.gas.vivos() > 0 and tope < 600:
		await avanzar(1)
		tope += 1
	gb.position = Terreno3D.centro_de(Vector2i(_c.x - 3, _c.y), Terreno3D.y_pies(Vector2i(_c.x - 3, _c.y)))
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_RAYO, false)
	await avanzar_s(0.5)


## Rayo de UN SOLO DESTELLO (hechizo de 0,1 s): HazGasJuego.haz con vida 0,1 → HazGas.destello; el trazo se ve al principio y ya no a los 0,4 s.
func _rayo_destello() -> void:
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_RAYO, true)
	colocar_jugador(_c)
	_hz_ultimo = {}
	_lanzar("rayo", ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)      # solo para tener el haz de la lógica (desde, hasta, choques)
	await avanzar(2)
	var v: VfxToyJuego = _vfx()
	var hz: Dictionary = _hz_ultimo.duplicate()
	var tope: int = 0
	while v.gas != null and v.gas.vivos() > 0 and tope < 900:            # se deja ir el haz normal
		var e0: Dictionary = v.gas._gases.back()
		e0["fin_haz"] = mini(int(e0["fin_haz"]), Time.get_ticks_msec())
		e0["fin_todo"] = mini(int(e0["fin_todo"]), Time.get_ticks_msec())
		await avanzar(1)
		tope += 1
	await avanzar_s(0.3)
	if hz.is_empty() or v.gas == null:
		_ok("rayo destello: hay un haz de la lógica para dibujarlo", false)
		return
	var suelo: float = Terreno3D.y_pies(_c)
	var g: HazGas = v.gas.haz(null, hz, suelo, 0.1, "rayo")
	_ok("rayo destello: un hechizo de 0,1 s sale como UN SOLO DESTELLO", g != null and g.rayo_destello > 0.0 and g.rayo_destello <= HazGasJuego.DESTELLO_MAX_S,
		"destello %.2f s" % (g.rayo_destello if g != null else -1.0))
	if g == null:
		return
	# el chorro se sujeta encendido (reloj real): lo que se prueba es que el TRAZO se apaga solo, con el tiempo de la simulación, aunque el haz siga
	var e: Dictionary = v.gas._gases.back()
	e["fin_haz"] = Time.get_ticks_msec() + 600000
	e["fin_todo"] = int(e["fin_haz"]) + 2500
	while g.frame < 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	var c0: Dictionary = _colores(g)
	_guardar(_recorte((jugador.position + (hz["hasta"] as Vector3)) * 0.5 + Vector3(0, 0.6, 0)), "rayo_destello_juego.jpg")
	var f1: int = g.frame
	while is_instance_valid(g) and g.frame < f1 + 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var c1: Dictionary = _colores(g) if is_instance_valid(g) and g.listo() else {"azul": 0, "naranja": 0}
	_ok("rayo destello: el trazo se ve al salir y se ha ido a los 0,4 s (no se redibuja)", int(c0["azul"]) > 150 and int(c1["azul"]) < int(c0["azul"]) / 4,
		"azul al salir %d px · a los 0,4 s %d px" % [int(c0["azul"]), int(c1["azul"])])
	if is_instance_valid(g):
		e["fin_haz"] = Time.get_ticks_msec()
		e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
	tope = 0
	while v.gas.vivos() > 0 and tope < 600:
		await avanzar(1)
		tope += 1
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_RAYO, false)


## COSTE en la GPU de cada haz (fuego, agua, viento y rayo; al aire y contra el muro), con hechizos reales y la cámara del juego. La ventana se fija a 1280 × 720
## (el gestor de ventanas a veces la abre maximizada y el volumen va a media resolución de la pantalla: el coste cambia). Chorro sujeto encendido, media de las
## marcas del RenderingDevice de los últimos 0,5 s tras 1,5 s de simulación.
func _costes() -> void:
	var w: Window = root.get_window()
	w.mode = Window.MODE_WINDOWED
	w.size = Vector2i(1280, 720)
	await avanzar(10)
	for e in ["viento", "rayo"]:
		ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[e][0], true)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE, true)
	ProjectSettings.set_setting(HazGasJuego.AJUSTE_AGUA, true)
	var filas: Array = []
	for caso in ["aire", "muro"]:
		for elem in ["fuego", "agua", "viento", "rayo"]:
			colocar_jugador(_c)
			if caso == "muro":
				_muro(Vector2i(_c.x + 2, _c.y), 2)
			await avanzar_s(0.4)
			var v: VfxToyJuego = _vfx()
			var antes: int = v.gas.creados if v != null and v.gas != null else 0
			_lanzar(elem, ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
			await avanzar(2)
			v = _vfx()
			if v == null or v.gas == null or v.gas.vivos() == 0 or v.gas.creados <= antes:
				filas.append("%-6s | %-4s | sin gas" % [elem, caso])
				await avanzar_s(3.0)
				continue
			var g: HazGas = v.gas.gases().back()
			var e: Dictionary = v.gas._gases.back()
			e["fin_haz"] = Time.get_ticks_msec() + 600000
			e["fin_todo"] = int(e["fin_haz"]) + 2500
			g.chorro(true)
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 2100:
				await process_frame
			var vp: Vector2i = root.get_viewport().get_texture().get_size()
			var tot: float = float(g.gpu_ms.get("total", 0.0))
			var sim: float = float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)) + float(g.gpu_ms.get("chispas", 0.0)) + float(g.gpu_ms.get("luz", 0.0))
			var vol: float = float(g.gpu_ms.get("volumen", 0.0))
			var r: Vector3i = g.solver.res
			filas.append("%-6s | %-4s | %5.2f ms (sim %.2f · volumen %.2f) | %4.0f fps desde 60 · %4.0f fps desde 120 | rejilla %dx%dx%d · pantalla %dx%d · fotograma entero %.2f ms" % [
				elem, caso, tot, sim, vol, 1000.0 / (1000.0 / 60.0 + tot), 1000.0 / (1000.0 / 120.0 + tot), r.x, r.y, r.z, vp.x, vp.y, g.gpu_viewport_ms])
			_ok("coste %s %s: se mide" % [elem, caso], tot > 0.0, filas.back())
			e["fin_haz"] = Time.get_ticks_msec()
			e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
			var tope: int = 0
			while v.gas.vivos() > 0 and tope < 600:
				await avanzar(1)
				tope += 1
			await avanzar_s(0.5)
	print("== COSTE (elemento | caso | ms de GPU del haz | fps equivalentes | rejilla, pantalla)")
	for f in filas:
		print("  COSTE " + f)
	for e in ["viento", "rayo"]:
		ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[e][0], false)


func _sin_gpu() -> void:
	for e in ["viento", "rayo"]:
		_ok("%s: encendido de serie (11/11)" % e, bool(HazGasJuego.AJUSTES_ELEMENTO[e][1]) and bool(ProjectSettings.get_setting(HazGasJuego.AJUSTES_ELEMENTO[e][0], false)) and e in HazGas.ELEMENTOS)
		var pe: Dictionary = HazGas.PARAMS_ELEMENTO[e]
		_ok("%s: sin combustión ni expansión ni peso" % e, float(pe["burnRate"]) == 0.0 and float(pe["expansion"]) == 0.0 and float(pe["weight"]) == 0.0)
		var cf: Dictionary = HazGas.HAZ_REF.duplicate()
		cf["obstaculo"] = "caja"
		cf["tam"] = 1.2
		var df: Dictionary = HazGas.derivar_haz(cf)
		cf["elemento"] = e
		var de: Dictionary = HazGas.derivar_haz(cf)
		var rf: Vector3i = df["res"]
		var r: Vector3i = de["res"]
		_ok("%s: dominio propio, más pequeño que el del fuego y con la misma celda" % e, r.x * r.y * r.z < rf.x * rf.y * rf.z and is_equal_approx(float(de["h"]), float(df["h"])),
			"%s frente a %s" % [str(r), str(rf)])
	var g := HazGas.new()
	var p0: Dictionary = g.params.duplicate()
	for e in ["viento", "rayo", "agua", "fuego"]:
		g.elemento = e
		g._params_fuego = p0.duplicate()
		g._aplicar_elemento()
	var igual: bool = true
	for k in p0:
		if typeof(p0[k]) == TYPE_FLOAT and not is_equal_approx(float(p0[k]), float(g.params[k])):
			igual = false
	_ok("al volver a fuego, los parámetros son los de la demo", igual)
	g.free()


## Lanza un haz real del elemento y devuelve {largo, choques} de la lógica. Con gas: comprueba la simulación y hace las capturas.
var _c: Vector2i = Vector2i.ZERO


func _un_haz(elem: String, caso: String, con_gas: bool) -> Dictionary:
	if caso == "muro":                     # el muro de tierra de la prueba dura 3,6 s: uno nuevo para cada haz, lanzado en el mismo instante de su vida
		_muro(Vector2i(_c.x + 2, _c.y), 2)
		await avanzar_s(0.4)
	var v: VfxToyJuego = _vfx()
	var antes: int = v.gas.creados if v != null and v.gas != null else 0
	_hz_ultimo = {}
	var salio: bool = _lanzar(elem, ["linea_x", "linea_x"], Vector3.RIGHT, jugador.position)
	_ok("%s %s (%s): sale el haz" % [elem, caso, "gas" if con_gas else "toy"], salio)
	await avanzar(2)
	v = _vfx()
	var hay_gas: bool = v != null and v.gas != null and v.gas.vivos() > 0 and v.gas.creados > antes
	var res: Dictionary = {}
	if not _hz_ultimo.is_empty():
		res = {"largo": float(_hz_ultimo.get("largo", 0.0)), "choques": (_hz_ultimo.get("choques", []) as Array).size()}
	if not con_gas:
		_ok("%s %s: con el ajuste apagado NO hay gas y el toy se ve" % [elem, caso], not hay_gas and v.ultimo != null and (v.ultimo as Node3D).visible)
		await avanzar_s(4.2)
		return res
	var g: HazGas = v.gas.gases().back() if hay_gas else null
	_ok("%s %s: el haz se dibuja con GAS en modo %s" % [elem, caso, elem], hay_gas and g.elemento == elem)
	if g == null:
		await avanzar_s(3.0)
		return res
	# HazGasJuego apaga el chorro por RELOJ REAL y esta prueba avanza a pasos fijos (con los tirones de la primera compilación la foto llegaba con el chorro ya
	# cortado): se sujeta el chorro encendido, se espera a que la SIMULACIÓN haya dado 45 pasos (0,75 s de gas) y entonces se mide y se fotografía.
	var e: Dictionary = v.gas._gases.back()
	e["fin_haz"] = Time.get_ticks_msec() + 600000
	e["fin_todo"] = int(e["fin_haz"]) + 2500
	g.chorro(true)
	var tope: int = 0
	while g.frame < 45 and tope < 900:
		await avanzar(1)
		tope += 1
	await RenderingServer.frame_post_draw
	_ocultar_ui(root)
	var fin: Vector3 = (_hz_ultimo.get("hasta", jugador.position + Vector3.RIGHT * 4.0) as Vector3)
	var centro: Vector3 = (jugador.position + fin) * 0.5 + Vector3(0, 0.6, 0)
	_guardar(_recorte(centro), "%s_%s_juego.jpg" % [elem, caso])
	_ok_colores(elem, caso, g)
	g.pausa = true
	_medir_gas(elem, caso, g)
	await _lateral(jugador.position, fin, "%s_%s_lateral.jpg" % [elem, caso])
	g.pausa = false
	print("  %s %s: gpu %.2f ms (sim %.2f · volumen %.2f) · %s" % [elem, caso, float(g.gpu_ms.get("total", 0.0)),
		float(g.gpu_ms.get("gas", 0.0)) + float(g.gpu_ms.get("velocidad", 0.0)), float(g.gpu_ms.get("volumen", 0.0)), g._texto_haz()])
	e["fin_haz"] = Time.get_ticks_msec()
	e["fin_todo"] = int(e["fin_haz"]) + int(HazGasJuego.APAGADO_S * 1000.0)
	tope = 0
	while v.gas.vivos() > 0 and tope < 600:
		await avanzar(1)
		tope += 1
	await avanzar_s(1.5)
	_ok("%s %s: el dominio se libera al acabar" % [elem, caso], v.gas.vivos() == 0)
	return res


## Lee el gas: sin NaN, materia en el eje del chorro, canales que el elemento no usa a cero y nada dentro de los sólidos.
func _medir_gas(elem: String, caso: String, g: HazGas) -> void:
	var caja: Array = [PackedByteArray()]            # las lambdas de GDScript capturan por valor: el resultado vuelve dentro de un Array
	RenderingServer.call_on_render_thread(func() -> void: caja[0] = g.solver.leer(g.solver.gas[0]))
	await avanzar(2)
	var datos: PackedByteArray = caja[0]
	var r: Vector3i = g.solver.res
	if datos.size() != r.x * r.y * r.z * 8:
		_ok("%s %s: se puede leer el gas" % [elem, caso], false, "%d bytes" % datos.size())
		return
	var noz: Vector3 = g.params["nozzle"]
	var tg: Vector3 = g.params["target"]
	var h: float = g.mundo_tam.x / float(r.x)
	var malos: int = 0
	var eje: float = 0.0
	var otros: float = 0.0
	var dentro: int = 0
	for z in range(0, r.z, 2):
		for y in range(0, r.y, 2):
			for x in range(0, r.x, 2):
				var i: int = (x + r.x * (y + r.y * z)) * 8
				var vx: float = datos.decode_half(i)
				if is_nan(vx) or is_inf(vx):
					malos += 1
					continue
				otros = maxf(otros, maxf(absf(datos.decode_half(i + 2)), absf(datos.decode_half(i + 6))))
				var w: Vector3 = g.mundo_lo + (Vector3(x, y, z) + Vector3.ONE * 0.5) * h
				var t: float = clampf((w - noz).dot(tg - noz) / (tg - noz).length_squared(), 0.0, 1.0)
				if t > 0.2 and t < 0.8 and (w - (noz + (tg - noz) * t)).length() < float(g.params["beamR1"]) * 1.6:
					eje = maxf(eje, vx)
				if vx > 0.3 and float(g.sd_obstaculo(w)[0]) < -1.5 * h:
					dentro += 1
	var fila: String = "x en el chorro %.2f · canales sin uso %.3f · celdas dentro %d · NaN %d" % [eje, otros, dentro, malos]
	_ok("%s %s: sin NaN ni infinitos" % [elem, caso], malos == 0, fila)
	_ok("%s %s: hay %s en el chorro" % [elem, caso, "ráfaga" if elem == "viento" else "ionización"], eje > 0.25, fila)
	if elem != "viento":               # en el viento los canales y / w son las etiquetas de línea de corriente
		_ok("%s %s: sin hollín ni combustible" % [elem, caso], otros < 0.001, fila)
	_ok("%s %s: nada dentro de los sólidos" % [elem, caso], dentro == 0, fila)
