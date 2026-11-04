extends SceneTree
## 4/11 (Pablo, Bosque 02: «revisa todas las colisiones: se tienen que sentir ajustadas a sus proporciones»). Sin ventana:
##   godot --headless --path . -s res://herramientas/prueba_colisiones_proporcion.gd
## Para cada pieza que usa el Bosque 02 (las instancias de Nivel_Bosque_02.tscn) y para toda la tabla `ColisionPieza.MODO`, mide la HUELLA de la colisión real (los cascos de `ColisionPieza`,
## los mismos que se hornean en arte/piezas/<id>.tscn) frente a la HUELLA VISUAL del modelo a su escala, en el plano XZ, y falla si la colisión sobra o falta más de MARGEN_REL (15 %) o MARGEN_ABS (0,1 u):
##   · «cuerpo» = la huella del modelo en la franja por la que pasa un personaje (y 0,12–1,6): es lo que el contorno debe reproducir. Mide el ancho y el fondo de su caja y el área que cubre (casillas de 0,1).
##   · colisión «sobra» si su caja es más ancha que el cuerpo + margen, o su área (suma de cascos) pasa de AREA_SOBRA_MAX · el área del cuerpo.
##   · «falta» si su caja es más estrecha que el cuerpo − margen, o su área baja de AREA_FALTA_MIN · el área del cuerpo.
## Los árboles (modo tronco / tronco_bajo) se miden contra su tronco (franja del tronco), no contra la copa. Los que bloquean la casilla entera por diseño (anillo exterior de árboles) se listan aparte.
## Además: la pieza horneada (arte/piezas/<id>.tscn) tiene tantos cascos como la medida de ahora (si no, hay que volver a generar las piezas) y las piezas ≤ ALTO_MIN_SOLIDO no llevan cuerpo.

const NIVEL: String = "res://mundo/datos_nivel/Nivel_Bosque_02.tscn"
const MARGEN_REL: float = 0.15
const MARGEN_ABS: float = 0.10
## 4/11 (Pablo): margen propio de las piezas que se aceptan algo más justas. La valla enderezada (-7° en Pieza3D.GIRO_MODELO) deja su contorno 0,11 u más estrecho que el modelo.
const MARGEN_ABS_ID: Dictionary = {"valla": 0.12}
const AREA_SOBRA_MAX: float = 1.45       ## el casco convexo de un trozo cóncavo (una L) sobra hasta SOBRA_MAX = 1,35 por diseño; + holgura de la malla
const AREA_FALTA_MIN: float = 0.60
const PEORES: int = 8

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  ok   ", texto)
	else:
		fallos += 1
		print("  FALLO ", texto)


func _init() -> void:
	var ids: Array = []
	var de_nivel: Dictionary = {}
	var ps: PackedScene = load(NIVEL) as PackedScene
	var raiz: Node = ps.instantiate()
	for n in raiz.find_children("*", "Node3D", true, false):
		if n.has_meta("id") and n.has_meta("bloquea"):
			var id: String = String(n.get_meta("id"))
			de_nivel[id] = int(de_nivel.get(id, 0)) + 1
	raiz.free()
	for id in de_nivel.keys():
		ids.append(id)
	for id in ColisionPieza.MODO.keys():
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	print("# %d piezas (%d del Bosque 02 + las de la tabla)" % [ids.size(), de_nivel.size()])
	var filas: Array = []
	for id in ids:
		var f: Dictionary = _medir(String(id))
		if f.is_empty():
			continue
		f["id"] = id
		f["en_nivel"] = int(de_nivel.get(id, 0))
		filas.append(f)
	# --- tabla y fallos ---
	for f in filas:
		var motivo: String = String(f["motivo"])
		var linea: String = "%-22s %-11s x%-3d modelo %.2f x %.2f · cuerpo %.2f x %.2f (A %.2f) · colisión %.2f x %.2f (A %.2f) · dif %+.2f/%+.2f · A× %.2f  %s" % [f["id"], f["modo"], f["en_nivel"],
			f["vw"], f["vd"], f["cw"], f["cd"], f["ca"], f["kw"], f["kd"], f["ka"], f["dw"], f["dd"], f["razon"], motivo if motivo != "" else "ok"]
		if motivo != "":
			_ok(false, linea)
		elif int(f["en_nivel"]) > 0:
			print("       ", linea)
	# --- los peores ---
	var con_cuerpo: Array = filas.filter(func(x: Dictionary) -> bool: return int(x["n_cascos"]) > 0)
	con_cuerpo.sort_custom(func(a, b): return float(a["peor"]) > float(b["peor"]))
	print("# los %d peores entre las %d piezas con colisión (mayor desajuste de caja, en u)" % [PEORES, con_cuerpo.size()])
	for i in range(mini(PEORES, con_cuerpo.size())):
		var f2: Dictionary = con_cuerpo[i]
		print("  %-22s %-11s peor %+.2f u   (cuerpo %.2f x %.2f · colisión %.2f x %.2f · A× %.2f)" % [f2["id"], f2["modo"], f2["peor"], f2["cw"], f2["cd"], f2["kw"], f2["kd"], f2["razon"]])
	# --- horneado al día y piezas bajas sin cuerpo ---
	print("# las piezas horneadas (arte/piezas) coinciden con la medida de ahora")
	for f3 in filas:
		var id3: String = String(f3["id"])
		var ruta: String = "res://arte/piezas/%s.tscn" % id3
		if not ResourceLoader.exists(ruta):
			continue
		var pz: Node = (load(ruta) as PackedScene).instantiate()
		var cuerpo: Node = pz.get_node_or_null("cuerpo")
		var n_horneados: int = 0 if cuerpo == null else cuerpo.get_child_count()
		var tipo_cuerpo: bool = ColisionPieza.modo(id3) == "ninguna"
		var esperado: int = int(f3["n_cascos"])
		_ok(n_horneados == esperado or tipo_cuerpo or id3.begins_with("cofre") or id3 == "puente" or id3 == "pasadero", "%s: %d cascos horneados, %d medidos" % [id3, n_horneados, esperado])
		pz.free()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


## Huella del cuerpo del modelo frente a la de su colisión (a escala 1: la escala de la instancia multiplica las dos por igual).
func _medir(id: String) -> Dictionary:
	var vis: Node3D = Pieza3D.crear_visual(id)
	if vis == null:
		return {}
	var tris: PackedVector3Array = ColisionPieza._triangulos(vis, Transform3D.IDENTITY)
	vis.free()
	if tris.is_empty():
		return {}
	var modo: String = ColisionPieza.modo(id)
	var ymax: float = 0.0
	for p in tris:
		ymax = maxf(ymax, p.y)
	var lista: Array = Pieza3D.cascos_colision(id)
	# franja del cuerpo: la completa para los contornos; la del tronco (la que eligió ColisionPieza) para los árboles
	var celdas_ref: Dictionary = {}
	var pts_ref := PackedVector3Array()
	var es_arbol: bool = modo == "tronco" or modo == "tronco_bajo"
	if es_arbol:
		var mejor: float = INF
		for banda in (ColisionPieza.TRONCO_BANDAS_BAJO if modo == "tronco_bajo" else ColisionPieza.TRONCO_BANDAS):
			var rec: PackedVector3Array = ColisionPieza._recortar(tris, banda[0], banda[1])
			var planta: Dictionary = ColisionPieza._planta(rec)
			var trozos: Array = ColisionPieza._solo_eje(ColisionPieza._componentes(planta))
			var cel: Dictionary = {}
			for g in trozos:
				for c in (g as Array):
					cel[c] = true
			var area: float = cel.size() * ColisionPieza.CELDA * ColisionPieza.CELDA
			if area >= ColisionPieza.AREA_MIN and area < mejor:
				mejor = area
				celdas_ref = cel
				pts_ref = ColisionPieza._puntos_de(cel.keys(), planta)
	else:
		var rec2: PackedVector3Array = ColisionPieza._recortar(tris, ColisionPieza.banda_min(id), ColisionPieza.BANDA_MAX)
		var pl2: Dictionary = ColisionPieza._planta(rec2)
		# los trozos diminutos (ramitas) no cuentan, igual que en ColisionPieza
		for g in ColisionPieza._componentes(pl2):
			if (g as Array).size() * ColisionPieza.CELDA * ColisionPieza.CELDA >= ColisionPieza.AREA_MIN:
				for c in (g as Array):
					celdas_ref[c] = true
				pts_ref.append_array(ColisionPieza._puntos_de(g as Array, pl2))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts_ref:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var cw: float = 0.0 if pts_ref.is_empty() else hi.x - lo.x
	var cd: float = 0.0 if pts_ref.is_empty() else hi.y - lo.y
	# área del cuerpo: los árboles son una cáscara en la planta (el tronco es macizo): su casco; el resto, las casillas finas cubiertas (sesgadas por arriba en las piezas pequeñas: ~perímetro · 0,05)
	var ca: float = ColisionPieza._area_planta(pts_ref) if es_arbol else celdas_ref.size() * ColisionPieza.CELDA * ColisionPieza.CELDA
	var klo := Vector2(INF, INF)
	var khi := Vector2(-INF, -INF)
	var ka: float = 0.0
	for nube in lista:
		var pts: PackedVector3Array = nube
		ka += ColisionPieza._area_planta(pts)
		for p in pts:
			klo = klo.min(Vector2(p.x, p.z))
			khi = khi.max(Vector2(p.x, p.z))
	var kw: float = 0.0 if lista.is_empty() else khi.x - klo.x
	var kd: float = 0.0 if lista.is_empty() else khi.y - klo.y
	var dw: float = kw - cw
	var dd: float = kd - cd
	var razon: float = ka / maxf(ca, 0.0001)
	var motivo: String = ""
	if lista.is_empty():
		# sin cuerpo: bien si es más baja que el umbral o si la tabla dice «ninguna»; mal si debía tenerlo
		if modo != "ninguna" and ymax > ColisionPieza.ALTO_MIN_SOLIDO + ColisionPieza.ALTO_TOLERANCIA and ca > 0.0:
			motivo = "FALTA el cuerpo entero (modo %s, alto %.2f)" % [modo, ymax]
	elif ca > 0.0:
		var m_w: float = maxf(float(MARGEN_ABS_ID.get(id, MARGEN_ABS)), MARGEN_REL * cw)
		var m_d: float = maxf(float(MARGEN_ABS_ID.get(id, MARGEN_ABS)), MARGEN_REL * cd)
		if dw > m_w or dd > m_d:
			motivo = "SOBRA caja (%+.2f / %+.2f u)" % [dw, dd]
		elif -dw > m_w or -dd > m_d:
			motivo = "FALTA caja (%+.2f / %+.2f u)" % [dw, dd]
		elif razon > AREA_SOBRA_MAX:
			motivo = "SOBRA área (×%.2f)" % razon
		elif razon < AREA_FALTA_MIN:
			motivo = "FALTA área (×%.2f)" % razon
	# --- 2.º nivel: la caja del modelo ENTERO (lo que se ve), solo en piezas que caben en la franja del personaje (≤ BANDA_MAX de alto: no hay copa ni toldo que se pase por debajo) ---
	var vlo := Vector2(INF, INF)
	var vhi := Vector2(-INF, -INF)
	for p in tris:
		vlo = vlo.min(Vector2(p.x, p.z))
		vhi = vhi.max(Vector2(p.x, p.z))
	var vw: float = vhi.x - vlo.x
	var vd: float = vhi.y - vlo.y
	var ew: float = kw - vw
	var ed: float = kd - vd
	if motivo == "" and not lista.is_empty() and ymax <= ColisionPieza.BANDA_MAX and not es_arbol:
		var mv_w: float = maxf(float(MARGEN_ABS_ID.get(id, MARGEN_ABS)), MARGEN_REL * vw)
		var mv_d: float = maxf(float(MARGEN_ABS_ID.get(id, MARGEN_ABS)), MARGEN_REL * vd)
		if ew > mv_w or ed > mv_d:
			motivo = "SOBRA frente al modelo entero (%+.2f / %+.2f u)" % [ew, ed]
		elif -ew > mv_w or -ed > mv_d:
			motivo = "FALTA frente al modelo entero (%+.2f / %+.2f u)" % [ew, ed]
	var peor: float = maxf(absf(dw), absf(dd))
	if not lista.is_empty() and ymax <= ColisionPieza.BANDA_MAX and not es_arbol:
		peor = maxf(peor, maxf(absf(ew), absf(ed)))
	return {"vw": vw, "vd": vd,"modo": modo, "cw": cw, "cd": cd, "ca": ca, "kw": kw, "kd": kd, "ka": ka, "dw": dw, "dd": dd, "razon": razon, "motivo": motivo, "peor": peor, "n_cascos": lista.size()}
