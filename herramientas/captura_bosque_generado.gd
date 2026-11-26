extends "res://herramientas/escenario_base.gd"

## PRUEBA DE PUNTA A PUNTA (26/11/2026): un BOSQUE del generador de mapas, con la variedad de decorado por bioma (`tabla_decorado_bioma.gd`) y la capa de
## riqueza del suelo de hierba (`riqueza_suelo_3d.gd`). Genera «BosqueGenPrueba» (algoritmo bosque, estilo bosque, 60×50), lo exporta como el botón
## «Exportar» (escenas/PruebaBosqueGenPrueba.tscn + mapas/BosqueGenPrueba.txt), lo carga con la maqueta y comprueba:
##   · que la escena pide la variedad y la riqueza (y que con `decorado = false` no),
##   · que Puzle3D no da avisos, que salen árboles y flores del pack y matas de hierba corta,
##   · que el decorado NUEVO no bloquea nada: las casillas bloqueadas son las mismas que en la versión SIN decorado, y todo lo pisable se alcanza,
##   · que ningún resto de la capa de riqueza cae en un camino `g`, en el agua ni en una casilla de pieza de puzle,
##   · que las juntas y bordes que lleva el suelo son los de Monte Sumicio (`presentacion/acabado_suelo.gd`),
##   · el rendimiento ANTES (la misma escena sin variedad ni riqueza) y DESPUÉS: llamadas de dibujo, objetos, lotes y fotogramas por segundo.
## Fotos con la cámara del juego y desde arriba en docs/capturas/bosque_generado_2026-11-26/. NECESITA VENTANA (no --headless):
##   godot --path . --script res://herramientas/captura_bosque_generado.gd [-- borrar] [-- semilla=N]
## DEJA exportado «BosqueGenPrueba» para pasearlo (con `-- borrar` lo borra al acabar). La versión «sin» (`BosqueGenPruebaSin`) se borra siempre.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const AcabadoSuelo = preload("res://presentacion/acabado_suelo.gd")
const DIR: String = "res://docs/capturas/bosque_generado_2026-11-26"
const S: float = 2.3
const CASO: Dictionary = {"nombre": "BosqueGenPrueba", "algoritmo": "bosque", "semilla": 7, "ancho": 60, "alto": 50, "estilo": "bosque", "luz": "bosque"}

var _dir: String = ""


func _escenario() -> void:
	var borrar: bool = OS.get_cmdline_user_args().has("borrar")
	var par: Dictionary = Generador.parametros_defecto()
	par.merge(CASO, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("semilla="):
			par["semilla"] = int(a.substr(8))
		if a.begins_with("estilo="):         # bosque (por defecto) | pantano | ruinas: el mismo mapa con otro bioma
			par["estilo"] = a.substr(7)
			par["nombre"] = "BosqueGenPrueba" + String(par["estilo"]).capitalize()
	_dir = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)       # medir fotogramas por segundo sin el tope del monitor
	root.get_window().size = Vector2i(1600, 900)      # el mismo tamaño en el «antes» y en el «después»
	var m: Dictionary = Generador.new().generar(par)
	var nombre: String = String(par["nombre"])
	# 1. la escena exportada
	var txt: String = Exportador.texto_escena(m)
	_ok("1 la escena pide la variedad de decorado y la riqueza", txt.contains("decorado_bioma = true") and txt.contains("riqueza_suelo = true") and txt.contains("semilla_decorado = %d" % int(par["semilla"])))
	var par_sin: Dictionary = par.duplicate()
	par_sin["decorado"] = false
	par_sin["nombre"] = nombre + "Sin"
	var m_sin: Dictionary = Generador.new().generar(par_sin)
	_ok("1 con decorado = false la escena NO lo pide", not Exportador.texto_escena(m_sin).contains("decorado_bioma") and not Exportador.texto_escena(m_sin).contains("riqueza_suelo"))
	_ok("1 el plano es el mismo con y sin decorado", "\n".join(m["filas"]) == "\n".join(m_sin["filas"]))
	for q in [m, m_sin]:
		var res: Dictionary = Exportador.exportar(q, true)
		_ok("1 se exporta " + String((q["parametros"] as Dictionary)["nombre"]), bool(res["ok"]), String(res.get("error", "")))
		if not bool(res["ok"]):
			return
	var filas: PackedStringArray = m["filas"]

	# 2. la versión SIN (el «antes»): rendimiento y casillas bloqueadas
	var antes: Dictionary = await _medir(nombre + "Sin", false)
	var bloq_antes: Dictionary = antes["bloqueadas"]
	# las mismas fotos que se harán después, de la versión SIN (el «antes»), en los sitios que salen solo del plano
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(10)
	for s in [["claro_centro", _centro_de_claro(filas, maqueta)], ["claro_borde", _borde_de_claro(filas, maqueta)], ["camino", _junto_a_camino(filas, maqueta)]]:
		var cs: Vector2i = s[1]
		if cs.x >= 0:
			colocar_jugador(cs)
			await avanzar(70)
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s_antes.png" % [_dir, nombre, s[0]])
	# 3. la versión CON (el «después»)
	var desp: Dictionary = await _medir(nombre, true)
	var bloq_desp: Dictionary = desp["bloqueadas"]
	var mq: Node = maqueta
	var pz: Puzle3D = mq.get_node_or_null("Puzles") as Puzle3D
	var n_av: int = pz.avisos.size() if pz != null else -1
	_ok("3 Puzle3D sin avisos", n_av == 0, "%d %s" % [n_av, str(pz.avisos.slice(0, 4)) if pz != null else ""])
	var cuentas: Dictionary = mq.riqueza_cuentas
	_ok("3 la capa de riqueza sembró hierba corta y flores", int(cuentas.get("hierba", 0)) > 50 and int(cuentas.get("flores", 0)) > 20, str(cuentas))
	var lotes: Dictionary = mq._lotes
	var del_pack: int = 0
	var arboles_pack: int = 0
	var ids_pack: Dictionary = {}
	for id in lotes:
		if String(id).begins_with("pn_"):
			del_pack += (lotes[id] as Array).size()
			ids_pack[id] = true
			if String(id).contains("_oak") or String(id).contains("_elm") or String(id).contains("_birch") or String(id).contains("_pine") or String(id).contains("_fir") or String(id).contains("_spruce") or String(id).contains("_bigtree"):
				arboles_pack += (lotes[id] as Array).size()
	_ok("3 salen piezas del pack Pure Nature (árboles incluidos)", del_pack > 100 and arboles_pack > 20, "%d piezas de %d modelos, %d son árboles" % [del_pack, ids_pack.size(), arboles_pack])
	# 4. nada nuevo bloquea
	var solo_antes: int = 0
	var solo_desp: int = 0
	for c in bloq_antes:
		if not bloq_desp.has(c):
			solo_antes += 1
	for c in bloq_desp:
		if not bloq_antes.has(c):
			solo_desp += 1
	_ok("4 las casillas bloqueadas son las mismas con y sin decorado", solo_antes == 0 and solo_desp == 0, "%d y %d casillas distintas, %d bloqueadas" % [solo_antes, solo_desp, bloq_desp.size()])
	var ini: Vector2i = m["inicio"]
	var alcanzables: int = _alcanzables(filas, bloq_desp, ini)
	var pisables: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if filas[y][x] != "#" and (not bloq_desp.has(Vector2i(x, y)) or "~b ".contains(filas[y][x])):
				pisables += 1
	_ok("4 todo lo pisable se alcanza desde el inicio", alcanzables == pisables, "%d de %d" % [alcanzables, pisables])
	# 5. la riqueza no cae donde no debe
	var malas: Array = _riqueza_mal_puesta(mq)
	_ok("5 ni un resto de la riqueza en camino, losa, agua ni pieza de puzle", malas.is_empty(), str(malas.slice(0, 6)))
	# 6. juntas y bordes de Sumicio
	var mat: ShaderMaterial = mq._mat_suelo
	var igual: bool = true
	var detalle: String = ""
	var valores: Dictionary = {"relieve_hierba": AcabadoSuelo.RELIEVE_HIERBA, "relieve_junta": AcabadoSuelo.RELIEVE_JUNTA, "borde_extiende": AcabadoSuelo.BORDE_EXTIENDE,
		"borde_fundido": AcabadoSuelo.BORDE_FUNDIDO, "borde_fuerza": AcabadoSuelo.BORDE_FUERZA, "mezcla_hierba": AcabadoSuelo.MEZCLA_HIERBA}
	if not AcabadoSuelo.ESTILOS_SIN_RUGOSIDAD.has(String((m["parametros"] as Dictionary)["estilo"])):
		valores["rugosidad"] = AcabadoSuelo.RUGOSIDAD       # (en el Pantano la rugosidad se queda en la de siempre: ver AcabadoSuelo.ESTILOS_SIN_RUGOSIDAD)
	for kv in valores:
		var real: float = float(mat.get_shader_parameter(kv))
		detalle += "%s=%.2f " % [kv, real]
		if absf(real - float(valores[kv])) > 0.0001:
			igual = false
	var tinte: Variant = mat.get_shader_parameter("borde_tinte")
	igual = igual and (tinte is Color) and (tinte as Color).is_equal_approx(AcabadoSuelo.BORDE_TINTE)
	_ok("6 el suelo del nivel generado lleva las juntas y los bordes de Monte Sumicio", igual, detalle)
	# 7. rendimiento
	print("RENDIMIENTO antes (sin variedad ni riqueza): ", _resumen(antes))
	print("RENDIMIENTO después (con variedad y riqueza): ", _resumen(desp))
	# 8. fotos
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(30)
	await _fotos(m, mq)
	mq.queue_free()
	await avanzar(3)
	for rn in [nombre + "Sin"] + ([nombre] if borrar else []):
		for ruta in [Exportador.ruta_mapa(rn), Exportador.ruta_escena(rn)]:
			if FileAccess.file_exists(ruta):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Carga la escena exportada de `nombre` y mide: llamadas de dibujo, objetos y fotogramas por segundo con la cámara del juego quieta sobre la jugadora.
func _medir(nombre: String, _con: bool) -> Dictionary:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
		await avanzar(5)
	Flags.nuevo()
	Estado.nuevo()
	var t0: int = Time.get_ticks_msec()
	await cargar(Exportador.ruta_escena(nombre), false)
	var carga_ms: int = Time.get_ticks_msec() - t0
	await avanzar(60)
	var llamadas: Array = []
	var objetos: Array = []
	var prim: Array = []
	var t_ini: int = Time.get_ticks_usec()
	var n: int = 120
	for i in range(n):
		await process_frame
		llamadas.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objetos.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		prim.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var seg: float = float(Time.get_ticks_usec() - t_ini) / 1.0e6
	var res: Dictionary = {
		"llamadas": _media(llamadas), "objetos": _media(objetos), "primitivas": _media(prim), "fps": float(n) / maxf(seg, 0.001),
		"carga_ms": carga_ms, "lotes": int(maqueta._n_lotes), "bloqueadas": (maqueta._bloqueadas as Dictionary).duplicate(),
	}
	return res


func _media(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


func _resumen(d: Dictionary) -> String:
	return "%d llamadas de dibujo · %d objetos · %.0f mil primitivas · %.1f fps · %d lotes · carga %d ms" % [roundi(d["llamadas"]), roundi(d["objetos"]), float(d["primitivas"]) / 1000.0, d["fps"], d["lotes"], d["carga_ms"]]


func _alcanzables(filas: PackedStringArray, bloq: Dictionary, ini: Vector2i) -> int:
	var visto: Dictionary = {ini: true}
	var cola: Array = [ini]
	var k: int = 0
	while k < cola.size():
		var c: Vector2i = cola[k]
		k += 1
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var v: Vector2i = c + d
			if v.x < 0 or v.y < 0 or v.y >= filas.size() or v.x >= filas[v.y].length() or visto.has(v) or filas[v.y][v.x] == "#":
				continue
			if bloq.has(v) and not "~b ".contains(filas[v.y][v.x]):      # el agua se nada y el precipicio se cruza con el puente de tierra (como en `Exportador.validar`)
				continue
			visto[v] = true
			cola.append(v)
	return visto.size()


## Piezas de la capa de riqueza (matas, flores, rocas y ramas de los papeles de la tabla) que cayeron en una casilla que no es de hierba o es de un puzle.
func _riqueza_mal_puesta(mq: Node) -> Array:
	var TablaDec = preload("res://presentacion/tabla_decorado_bioma.gd")
	var ids: Dictionary = {}
	for papel in ["hierba_corta", "flor", "roca", "tronco"]:
		for f in TablaDec.TABLA["bosque"][papel]:
			if TablaDec.es_externa(String(f[0])):
				ids[String(f[0])] = true
	var puzle: Dictionary = {}
	for q in mq._celdas_puzle_del_mapa():
		puzle[q] = true
	var malas: Array = []
	for id in ids:
		for t in (mq._lotes.get(id, []) as Array):
			var c := Vector2i(floori((t as Transform3D).origin.x / S), floori((t as Transform3D).origin.z / S))
			var l: String = mq._letra(c)
			if not (l == "." or l == "," or l == "v") or puzle.has(c):
				malas.append("%s en %s (%s)" % [id, str(c), l])
	return malas


func _fotos(m: Dictionary, mq: Node) -> void:
	var filas: PackedStringArray = m["filas"]
	# la jugadora a donde hay cosas nuevas que ver: el centro de un claro, el borde de otro, donde más flores hay y donde está el resto de ruina
	var sitios: Array = [
		["claro_centro", _centro_de_claro(filas, mq)],
		["claro_borde", _borde_de_claro(filas, mq)],
		["flores", _donde_mas(mq, ["pn_meadows_daisy", "pn_meadows_commonblue", "pn_meadows_commonpink", "pn_meadows_commonyellow", "pn_meadows_flowermeadow1", "pn_meadows_flowermeadow2", "pn_mountains_daisy"], filas)],
		["arboles", _donde_mas(mq, ["pn_meadows_oak2", "pn_meadows_oak3", "pn_meadows_elm2", "pn_meadows_birch4", "pn_mountains_pine4", "pn_mountains_pine5"], filas)],
		["camino", _junto_a_camino(filas, mq)],
	]
	var hay_ruina: Vector2i = _donde_mas(mq, ["ss_stone_01", "ss_stone_02", "ss_rubble_01", "ss_rubble_02", "ss_edge_stones_01", "ss_pillar_01_dmg", "ss_wall_dmg_03_half_01"], filas)
	if hay_ruina.x >= 0:
		sitios.append(["ruina_suelta", hay_ruina])
	await _general(Rect2i(0, 0, int(m["ancho"]), int(m["alto"])), 2000, "%s/%s_arriba.png" % [_dir, String((m["parametros"] as Dictionary)["nombre"])])
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(10)
	for s in sitios:
		var c: Vector2i = s[1]
		if c.x < 0:
			print("sin sitio para la foto ", s[0])
			continue
		colocar_jugador(c)
		await avanzar(70)
		var f: String = "%s/%s_%s.png" % [_dir, String((m["parametros"] as Dictionary)["nombre"]), s[0]]
		root.get_viewport().get_texture().get_image().save_png(f)
		print("captura: ", f, " jugadora en ", c)


## El centro de un claro: una casilla `.` con hierba alrededor (radio 4) y sin nada.
func _centro_de_claro(filas: PackedStringArray, mq: Node) -> Vector2i:
	var mejor: Vector2i = Vector2i(-1, -1)
	var mejor_n: int = 0
	for y in range(4, filas.size() - 4):
		for x in range(4, filas[y].length() - 4):
			if filas[y][x] != "." or mq._bloqueadas.has(Vector2i(x, y)):
				continue
			var n: int = 0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if ".,v".contains(filas[y + dy][x + dx]):
						n += 1
			if n > mejor_n:
				mejor_n = n
				mejor = Vector2i(x, y)
	return mejor


## Una casilla `.` a dos de la masa `#`, con hierba a su alrededor.
func _borde_de_claro(filas: PackedStringArray, mq: Node) -> Vector2i:
	var c0: Vector2i = _centro_de_claro(filas, mq)
	var mejor: Vector2i = Vector2i(-1, -1)
	var mejor_d: float = 1.0e9
	for y in range(3, filas.size() - 3):
		for x in range(3, filas[y].length() - 3):
			if filas[y][x] != "." or mq._bloqueadas.has(Vector2i(x, y)) or filas[y][x + 2] != "#":
				continue
			var d: float = Vector2(x, y).distance_to(Vector2(c0))
			if d < mejor_d and d > 3.0:
				mejor_d = d
				mejor = Vector2i(x, y)
	return mejor


func _junto_a_camino(filas: PackedStringArray, mq: Node) -> Vector2i:
	for y in range(3, filas.size() - 3):
		for x in range(3, filas[y].length() - 3):
			if filas[y][x] == "g" and filas[y][x + 1] == "g" and ".,".contains(filas[y - 1][x]) and ".,".contains(filas[y - 2][x]) and not mq._bloqueadas.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## La casilla donde más piezas de esos ids hay en un cuadrado de 5×5 (y que se puede pisar).
func _donde_mas(mq: Node, ids: Array, filas: PackedStringArray) -> Vector2i:
	var cuenta: Dictionary = {}
	for id in ids:
		for t in (mq._lotes.get(id, []) as Array):
			var c := Vector2i(floori((t as Transform3D).origin.x / S), floori((t as Transform3D).origin.z / S))
			cuenta[c] = int(cuenta.get(c, 0)) + 1
		for r in mq._registro:
			if String((r as Array)[0]) == String(id):
				var c2: Vector2i = (r as Array)[1]
				cuenta[c2] = int(cuenta.get(c2, 0)) + 1
	var mejor: Vector2i = Vector2i(-1, -1)
	var mejor_n: int = 0
	for y in range(2, filas.size() - 2):
		for x in range(2, filas[y].length() - 2):
			if filas[y][x] == "#" or filas[y][x] == "~" or mq._bloqueadas.has(Vector2i(x, y)):
				continue
			var n: int = 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					n += int(cuenta.get(Vector2i(x + dx, y + dy), 0))
			if n > mejor_n:
				mejor_n = n
				mejor = Vector2i(x, y)
	return mejor


func _general(r: Rect2i, ancho_px: int, ruta: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 400.0
	maqueta.add_child(cam)
	var alto_px: int = clampi(int(round(float(ancho_px) * float(r.size.y) / float(r.size.x))), 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro := Vector3(float(r.size.x) * 0.5 * S, 0.0, float(r.size.y) * 0.5 * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(25)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura: ", ruta, " ", img.get_size())
	cam.queue_free()
