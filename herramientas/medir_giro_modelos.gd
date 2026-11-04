extends SceneTree
## 4/11 (Pipeline): mide cuánto está TORCIDO cada modelo de Meshy respecto de los ejes. SIN ventana.
##   godot --headless --path . --script res://herramientas/medir_giro_modelos.gd -- [salida.tsv]
## Recorre todas las piezas que puede dibujar la maqueta (Pieza3D.MEDIDA, MEDIDA_ANCHO, las sueltas de arte/meshy/piezas/*.glb y los
## hijos de las bibliotecas Pieza3D.BIBLIOTECAS), instancia cada una con Pieza3D.crear_visual (con su GIRO_MODELO ya aplicado, así que tras
## corregir salen ~0) y mide, en el espacio de la pieza:
##   giro_y     grados de giro en Y (valor para Pieza3D.GIRO_MODELO) que alinean el rectángulo de área mínima del casco convexo XZ con los ejes
##              (rango -45..45). Es lo que hay que APLICAR al modelo para enderezarlo.
##   cabeceo / alabeo   inclinación del eje vertical: ángulo (grados) de la normal media de las caras que miran hacia arriba, sobre Z y sobre X.
##   fiabilidad  alta / media / baja del giro: una caja o un cartel tienen un giro claro; una roca redonda, no (el área del rectángulo
##              mínimo casi no cambia al girarlo = nitidez ~0, y el casco llena poco el rectángulo = relleno bajo).
##   inc_fiab    lo mismo para la inclinación (cuánta área mira hacia arriba y cuánto se dispersan sus normales).
const CARPETA_SALIDA: String = "res://docs/GIRO_MODELOS_2026-11-04.tsv"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var salida: String = a[0] if a.size() > 0 else CARPETA_SALIDA
	if a.has("--sin-giro"):       # mide los modelos tal como vienen de Meshy (sin GIRO_MODELO)
		Pieza3D.giro_activo = false
		if salida == "--sin-giro":
			salida = CARPETA_SALIDA
	Pieza3D._cargar_bibliotecas()
	var ids: Array = _ids()
	var filas: Array = []
	for id in ids:
		var v: Node3D = Pieza3D.crear_visual(String(id))
		if v == null:
			continue
		var m: Dictionary = medir(v)
		v.free()
		if m.is_empty():
			continue
		m["id"] = id
		m["origen"] = _origen(String(id))
		filas.append(m)
	filas.sort_custom(func(x, y): return absf(float(x["giro_y"])) > absf(float(y["giro_y"])))
	var f := FileAccess.open(salida, FileAccess.WRITE)
	f.store_line("id\tgiro_y\tcabeceo\talabeo\tfiabilidad\tinc_fiab\tnitidez\trelleno\tarea_arriba\tdisp_normal\torigen")
	var altas: int = 0
	for m in filas:
		if m["fiab"] == "alta":
			altas += 1
		f.store_line("%s\t%.1f\t%.1f\t%.1f\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.1f\t%s" % [m["id"], m["giro_y"], m["cabeceo"], m["alabeo"], m["fiab"], m["inc_fiab"],
			m["nitidez"], m["relleno"], m["area_arriba"], m["disp"], m["origen"]])
	f.close()
	print("MEDIDAS: ", filas.size(), " piezas (fiabilidad alta: ", altas, ") -> ", salida)
	quit()


func _ids() -> Array:
	var res: Array = []
	var t: Dictionary = Pieza3D._constantes()
	for k in (t.get("MEDIDA", {}) as Dictionary).keys():
		if not res.has(k):
			res.append(k)
	for k in (t.get("MEDIDA_ANCHO", {}) as Dictionary).keys():
		if not res.has(k):
			res.append(k)
	for b in Pieza3D._bibliotecas:
		var nombre: String = String((b as Node).scene_file_path).get_file().get_basename()
		if String((b as Node).scene_file_path).begins_with(Pieza3D.CARPETA_PIEZAS) and not res.has(nombre):
			res.append(nombre)
		for h in (b as Node).get_children():
			if h is Node3D and not res.has(String(h.name)):
				res.append(String(h.name))
			if String(h.name) == "raiz":
				for hh in h.get_children():
					if hh is Node3D and not res.has(String(hh.name)):
						res.append(String(hh.name))
	return res


func _origen(id: String) -> String:
	var real: String = Pieza3D.id_real(id)
	var suelto: String = Pieza3D.CARPETA_PIEZAS + real + ".glb"
	if ResourceLoader.exists(suelto):
		return suelto.trim_prefix("res://")
	for b in Pieza3D._bibliotecas:
		if (b as Node).find_child(real, true, false) is Node3D:
			return String((b as Node).scene_file_path).trim_prefix("res://") + (("  (" + real + ")") if real != id else "")
	return "?"


## Recoge vértices y triángulos de todas las mallas del visual, en el espacio de su raíz.
func _geometria(n: Node, acum: Transform3D, verts: PackedVector3Array, tris: PackedVector3Array) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var malla: Mesh = (n as MeshInstance3D).mesh
		for s in malla.get_surface_count():
			var arr: Array = malla.surface_get_arrays(s)
			if arr.size() <= Mesh.ARRAY_VERTEX or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: Variant = arr[Mesh.ARRAY_INDEX]
			var w := PackedVector3Array()
			w.resize(vs.size())
			for i in vs.size():
				w[i] = t * vs[i]
			verts.append_array(w)
			if ix is PackedInt32Array and (ix as PackedInt32Array).size() >= 3:
				var idx: PackedInt32Array = ix
				for i in range(0, idx.size() - 2, 3):
					tris.append(w[idx[i]]); tris.append(w[idx[i + 1]]); tris.append(w[idx[i + 2]])
			else:
				for i in range(0, w.size() - 2, 3):
					tris.append(w[i]); tris.append(w[i + 1]); tris.append(w[i + 2])
	for h in n.get_children():
		_geometria(h, t, verts, tris)


func medir(v: Node3D) -> Dictionary:
	var verts := PackedVector3Array()
	var tris := PackedVector3Array()
	_geometria(v, Transform3D.IDENTITY, verts, tris)
	if verts.size() < 4:
		return {}
	# --- (a) giro en Y: rectángulo de área mínima del casco convexo XZ ---
	var p2 := PackedVector2Array()
	p2.resize(verts.size())
	for i in verts.size():
		p2[i] = Vector2(verts[i].x, verts[i].z)
	var casco: PackedVector2Array = Geometry2D.convex_hull(p2)
	if casco.size() < 3:
		return {}
	var area_casco: float = 0.0
	for i in casco.size():
		var q: Vector2 = casco[(i + 1) % casco.size()]
		area_casco += casco[i].x * q.y - q.x * casco[i].y
	area_casco = absf(area_casco) * 0.5
	var mejor_a: float = INF
	var mejor_phi: float = 0.0
	for i in casco.size():
		var d: Vector2 = casco[(i + 1) % casco.size()] - casco[i]
		if d.length() < 0.00001:
			continue
		var phi: float = atan2(d.y, d.x)
		var ar: float = _area_rotada(casco, phi)
		if ar < mejor_a:
			mejor_a = ar
			mejor_phi = phi
	# se lleva a -45..45 (los lados de un rectángulo se repiten cada 90°)
	var g: float = fposmod(rad_to_deg(mejor_phi) + 45.0, 90.0) - 45.0
	# nitidez: cuánto cambia el área del rectángulo al girarlo (0 = redondo; 0,5 = cuadrado perfecto)
	var amax: float = 0.0
	var amin: float = INF
	var area_actual: float = _area_rotada(casco, 0.0)
	var phi_i: float = 0.0
	while phi_i < PI * 0.5:
		var ar2: float = _area_rotada(casco, phi_i)
		amax = maxf(amax, ar2)
		amin = minf(amin, ar2)
		phi_i += deg_to_rad(1.0)
	var nitidez: float = (amax - amin) / maxf(amax, 0.000001)
	var relleno: float = area_casco / maxf(mejor_a, 0.000001)
	var ganancia: float = area_actual / maxf(mejor_a, 0.000001)       # 1 = ya está alineado
	var fiab: String = "baja"
	if nitidez >= 0.12 and relleno >= 0.85:
		fiab = "alta"
	elif nitidez >= 0.07 and relleno >= 0.78:
		fiab = "media"
	# --- (b) inclinación: normal media de las caras que miran hacia arriba (<= 25° de Y), ponderada por área ---
	var suma := Vector3.ZERO
	var area_arriba: float = 0.0
	var area_total: float = 0.0
	var normales: Array = []
	for i in range(0, tris.size() - 2, 3):
		var n: Vector3 = (tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])
		var ar3: float = n.length() * 0.5
		if ar3 < 0.0000001:
			continue
		n = n.normalized()
		area_total += ar3
		if n.y > cos(deg_to_rad(25.0)):
			suma += n * ar3
			area_arriba += ar3
			normales.append([n, ar3])
	var cab: float = 0.0
	var ala: float = 0.0
	var disp: float = 0.0
	if area_arriba > 0.0:
		var nm: Vector3 = suma.normalized()
		cab = rad_to_deg(atan2(nm.z, nm.y))
		ala = rad_to_deg(atan2(nm.x, nm.y))
		var acc: float = 0.0
		for e in normales:
			var ang: float = rad_to_deg(acos(clampf((e[0] as Vector3).dot(nm), -1.0, 1.0)))
			acc += ang * ang * float(e[1])
		disp = sqrt(acc / area_arriba)
	var frac: float = area_arriba / maxf(area_total, 0.000001)
	var inc_fiab: String = "baja"
	if frac >= 0.06 and disp < 4.0:
		inc_fiab = "alta"
	elif frac >= 0.03 and disp < 8.0:
		inc_fiab = "media"
	return {"giro_y": g, "cabeceo": cab, "alabeo": ala, "fiab": fiab, "inc_fiab": inc_fiab, "nitidez": nitidez, "relleno": relleno,
		"area_arriba": frac, "disp": disp}


## Área del rectángulo alineado a los ejes que envuelve el casco tras girarlo `phi` radianes (rotation.y = phi).
func _area_rotada(casco: PackedVector2Array, phi: float) -> float:
	var c: float = cos(phi)
	var s: float = sin(phi)
	var x0: float = INF
	var x1: float = -INF
	var z0: float = INF
	var z1: float = -INF
	for p in casco:
		var x: float = p.x * c + p.y * s
		var z: float = -p.x * s + p.y * c
		x0 = minf(x0, x); x1 = maxf(x1, x)
		z0 = minf(z0, z); z1 = maxf(z1, z)
	return (x1 - x0) * (z1 - z0)
