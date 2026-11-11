extends "res://herramientas/prueba_haz_gas_agua.gd"
## PRUEBA (y capturas) DE LOS HACES DE VIENTO Y DE RAYO CON GAS (11/11/2026). El MISMO HazGas/HazGasSolver del fuego y del agua con HazGas.PARAMS_VIENTO / PARAMS_RAYO y sus
## dibujos (raymarch_toon_viento.glsl, raymarch_toon_rayo.glsl), enganchados en VfxToyJuego._haz con los ajustes magic_symbols/vfx_haz_gas_viento y vfx_haz_gas_rayo
## (APAGADOS de serie). Reutiliza las ayudas de la prueba del agua.
##   godot --headless --path . --script res://herramientas/prueba_haz_gas_viento_rayo.gd      → sin GPU: parámetros, dominio, ajustes de serie y que el fuego y el agua no cambian
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_viento_rayo.gd -- [carpeta]
##       → además, con GPU, en el Bosque 01 con hechizos REALES (Lanzador3D → HechizoVivo → VfxToyJuego → HazGasJuego), al aire y contra un muro:
##         sale con gas del elemento; no hay NaN; el canal x tiene materia en el eje del chorro; nada dentro de los sólidos; con el ajuste apagado sale el toy de siempre;
##         la lógica (largo y choques del haz) es la misma con y sin gas. Capturas: <carpeta>/<elemento>_<aire|muro>_juego.jpg y _lateral.jpg.


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
			# con el ajuste apagado (lo de serie): el toy de siempre, sin gas, y lo que dice la lógica
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], false)
			var sin: Dictionary = await _un_haz(elem, caso, false)
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], true)
			var con: Dictionary = await _un_haz(elem, caso, true)
			# contra el muro solo se comparan los choques: el muro de tierra de la prueba sube y se hunde, y el largo depende del instante en que lo pilla cada haz
			_ok("%s %s: la lógica no cambia con el gas (%s)" % [elem, caso, "largo y choques" if caso == "aire" else "choques"], not sin.is_empty() and not con.is_empty()
				and (caso == "muro" or absf(float(sin["largo"]) - float(con["largo"])) < 0.01) and int(sin["choques"]) == int(con["choques"]), "%s / %s" % [str(sin), str(con)])
			ProjectSettings.set_setting(HazGasJuego.AJUSTES_ELEMENTO[elem][0], false)
	print("capturas en ", _dir)


func _sin_gpu() -> void:
	for e in ["viento", "rayo"]:
		_ok("%s: apagado de serie" % e, not bool(HazGasJuego.AJUSTES_ELEMENTO[e][1]) and e in HazGas.ELEMENTOS)
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
