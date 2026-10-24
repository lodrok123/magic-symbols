extends SceneTree
## MEDIDAS de la cabeza de los personajes humanoides (24/10, Pablo: «busca proporciones como las que tenemos en los otros personajes»), con el MISMO método para todos:
##  · cabeza = los vértices de las mallas con piel del GLB (pelo, orejas y capucha incluidos si el modelo los trae) con peso total ≥ 0,5 en el hueso Head, en reposo; alto de la
##    cabeza = de el más bajo (barbilla) al más alto, ancho = extensión en X (de oreja a oreja si las lleva);
##  · alto total = Pj3D.alto_modelo() (caja de las mallas, sin la ropa por piezas) → «alturas de cabeza» = alto total / alto de la cabeza;
##  · hombros = distancia en X entre LeftArm y RightArm (las articulaciones del hombro) → relación ancho de la cabeza / hombros.
## jugadora_base se mide dos veces: «desnuda» (cuerpo: cabeza + pelo, sin ropa) y «con capucha» (cuerpo sin pelo + la capucha, que va entera al hueso Head). Sin ventana:
##   godot --headless --path . --script res://herramientas/medidas_cabezas.gd -- [escala de la cabeza de jugadora_base, p. ej. 0.85]

const IDS: Array = ["woodland_wanderer", "elfo_base", "chibi_elf", "marimanta", "bookseller_chibi", "alchemist_elf", "goblin_warrior_chibi", "goblin_asesino", "ranger_human", "jugadora_base"]
const PESO_MIN: float = 0.5
const BAJO_ARTICULACION: float = 0.45          ## cuánto bajo la articulación Head (en alturas «articulación → HeadTop_End») se mira: la barbilla de jugadora_base está a 0,29


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var escalas: Array = [1.0]
	if args.size() > 0:
		escalas = []
		for a in args[0].split(",", false):
			escalas.append(float(a))
	var filas: PackedStringArray = PackedStringArray()
	filas.append("%-22s %-14s %7s %7s %9s %8s %8s %9s" % ["personaje", "variante", "alto", "cabeza", "alturas", "c.ancho", "hombros", "c/hombros"])
	for id in IDS:
		var p := Pj3D.new()
		mundo.add_child(p)
		if not p.cargar(String(id)):
			filas.append("%-22s (no carga)" % id)
			continue
		var variantes: Array = [["", true, true]]
		if id == "jugadora_base":
			variantes = [["desnuda", false, false], ["con capucha", false, true]]
		for v in variantes:
			for e in (escalas if id == "jugadora_base" else [1.0]):
				if id == "jugadora_base":
					p.set_proporcion(float(e), 1.0, 1.0)
				var m: Dictionary = _medir(p, bool(v[1]), bool(v[2]), String(id) == "jugadora_base")
				if id == "jugadora_base" and not m.is_empty():
					# La escala del hueso Head no cambia el reposo que se mide: la cabeza escalada mide el reposo × la escala (el alto total sí la lleva: alto_modelo).
					m["alto"] = float(m["alto"]) * float(e)
					m["ancho"] = float(m["ancho"]) * float(e)
				var nombre: String = String(v[0]) + ("" if id != "jugadora_base" or escalas.size() == 1 else " ×%.2f" % float(e))
				if m.is_empty():
					filas.append("%-22s %-14s (sin medida)" % [id, nombre])
					continue
				filas.append("%-22s %-14s %7.3f %7.3f %9.2f %8.3f %8.3f %9.2f" % [id, nombre, m["total"], m["alto"], m["total"] / m["alto"], m["ancho"], m["hombros"], m["ancho"] / m["hombros"]])
		p.queue_free()
	var salida: String = "\n".join(filas)
	print(salida)
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://docs/capturas/lab_jugadora/medidas_cabezas.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string(salida + "\n")
		f.close()
	print("RESULTADO medidas_cabezas · FALLOS: 0")
	quit()


## {total, alto, ancho, hombros} en unidades del modelo (el GLB tal como viene) con la pose de reposo.
## `con_ropa`: cuenta también las mallas Ropa_* (solo para jugadora_base: se mide su cuerpo y la capucha, nunca la capa ni la túnica: la capa va pesada casi entera a Head).
func _medir(p: Pj3D, _todo: bool, capucha: bool, vestida: bool) -> Dictionary:
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cab: int = _hueso(sk, "Head")
	var izq: int = _hueso(sk, "LeftArm")
	var der: int = _hueso(sk, "RightArm")
	if cab < 0 or izq < 0 or der < 0:
		return {}
	var a_modelo: Transform3D = p._modelo.global_transform.affine_inverse() * sk.global_transform
	# Los vértices de la cabeza por debajo de la barbilla (cuello, pelo largo, capa) no cuentan: solo los que están a menos de UNA_CABEZA × (articulación → coronilla) bajo la articulación Head.
	var punta: int = _hueso(sk, "HeadTop_End")
	var y_hueso: float = (a_modelo * sk.get_bone_global_rest(cab).origin).y
	var hh: float = (a_modelo * sk.get_bone_global_rest(punta).origin).y - y_hueso if punta >= 0 else 0.0
	var y_corte: float = y_hueso - BAJO_ARTICULACION * hh if hh > 0.0 else -INF
	var min_y: float = INF
	var max_y: float = -INF
	var min_x: float = INF
	var max_x: float = -INF
	for n in p._modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var es_ropa: bool = mi.name.begins_with("Ropa_")
		if vestida and es_ropa and not (capucha and mi.name == "Ropa_capucha"):
			continue
		var skin: Skin = mi.skin
		var huesos_skin: Array = []
		for b in range(skin.get_bind_count()):
			var nombre: String = skin.get_bind_name(b)
			huesos_skin.append(sk.find_bone(nombre) if nombre != "" else skin.get_bind_bone(b))
		for s in range(mi.mesh.get_surface_count()):
			# En el cuerpo partido en zonas de jugadora_base el pelo se cuenta solo si no se pone la capucha (la capucha lo tapa).
			if vestida and mi.mesh.surface_get_name(s) == "pelo" and capucha:
				continue
			if vestida and not es_ropa and mi.mesh.surface_get_name(s) != "" and not ["cabeza", "pelo"].has(mi.mesh.surface_get_name(s)):
				continue
			var arr: Array = mi.mesh.surface_get_arrays(s)
			if arr.size() <= Mesh.ARRAY_WEIGHTS or arr[Mesh.ARRAY_BONES] == null:
				continue
			var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var por: int = huesos.size() / maxi(verts.size(), 1)
			for v in range(verts.size()):
				var w: float = 0.0
				for k in range(por):
					if int(huesos_skin[huesos[v * por + k]]) == cab:
						w += pesos[v * por + k]
				if w < PESO_MIN:
					continue
				# posición en reposo: la del vértice skineado con las poses de enlace y el reposo del esqueleto
				var pos := Vector3.ZERO
				for k in range(por):
					var wk: float = pesos[v * por + k]
					if wk <= 0.0:
						continue
					var b2: int = huesos[v * por + k]
					pos += (sk.get_bone_global_rest(int(huesos_skin[b2])) * skin.get_bind_pose(b2) * verts[v]) * wk
				var q: Vector3 = a_modelo * pos
				if q.y < y_corte:
					continue
				min_y = minf(min_y, q.y)
				max_y = maxf(max_y, q.y)
				min_x = minf(min_x, q.x)
				max_x = maxf(max_x, q.x)
	if min_y == INF:
		return {}
	var hi: Vector3 = a_modelo * sk.get_bone_global_rest(izq).origin
	var hd: Vector3 = a_modelo * sk.get_bone_global_rest(der).origin
	return {"total": p.alto_modelo(), "alto": max_y - min_y, "ancho": max_x - min_x, "hombros": absf(hi.x - hd.x), "hh": hh}


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var n: String = sk.get_bone_name(i)
		if n == fin or n.ends_with(":" + fin) or n.ends_with("_" + fin):
			return i
	return -1
