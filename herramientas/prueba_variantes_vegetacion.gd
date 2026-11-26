extends SceneTree

## PRUEBA (26/11/2026) de la vegetación sustituida por el pack Pure Nature (TablaVariantes, VarianteVegetal, Pieza3D.crear_visual).
##   godot --headless --path . --script res://herramientas/prueba_variantes_vegetacion.gd
## Para cada pieza de la tabla, por los DOS caminos por los que el juego pone piezas:
##   A · escena arte/piezas/<id>.tscn (decorados de los puzles): 12 veces. Que salgan variantes del pack (y la original si está en la lista),
##       que el modelo nuevo mida lo mismo que el original (alto, o planta si es plano; ±8 %) y que el juego pueda convertir TODOS sus
##       materiales a su material propio (Ocluso3D: el que se quema, se moja, se hiela y reacciona).
##   B · Pieza3D.crear_visual(id) (maqueta): 12 veces. Que el alto sea el mismo que el del visual original (crear_visual sin variantes).
## No toca nada. Termina con «RESULTADO ok=N fallos=M».

const REPETIR: int = 12
const TOLERANCIA: float = 0.08


func _initialize() -> void:
	Ocluso3D.preparar()
	var ok: int = 0
	var fallos: int = 0
	var ids: Array = TablaVariantes.VARIANTES.keys()
	ids.sort()
	for id in ids:
		var r: String = _probar(String(id))
		if r.begins_with("OK"):
			ok += 1
		else:
			fallos += 1
		print(r)
	print("RESULTADO ok=%d fallos=%d" % [ok, fallos])
	quit(0 if fallos == 0 else 1)


func _medida(c: AABB, alta: bool) -> float:
	return c.size.y if alta else maxf(c.size.x, c.size.z)


func _probar(id: String) -> String:
	var problemas: Array = []
	var vistas: Dictionary = {}
	# --- A: escena de arte/piezas
	var ruta: String = "res://arte/piezas/%s.tscn" % id
	var ps: PackedScene = load(ruta) as PackedScene
	if ps != null:
		for i in range(REPETIR):
			var n: Node3D = ps.instantiate() as Node3D
			var v: String = String(n.get_meta("variante_pack", ""))
			vistas[v.get_file().get_basename() if v != "" else "(original)"] = true
			if v != "" and n is VarianteVegetal:
				var o: AABB = (n as VarianteVegetal).caja_original
				var cont: Node3D = n.get_node_or_null("modelo") as Node3D
				if cont == null:
					cont = n
				var var_n: Node3D = cont.get_node_or_null("variante") as Node3D
				var c: AABB = TablaVariantes.caja(cont) if var_n == null else (var_n.transform * TablaVariantes.caja(var_n))
				# misma regla que VarianteVegetal: por la altura si las dos son altas; si no, por lo que ocupan en planta
				var alta: bool = o.size.y > maxf(o.size.x, o.size.z) * 0.35 and c.size.y > maxf(c.size.x, c.size.z) * 0.15
				var mo: float = _medida(o, alta)
				var mc: float = _medida(c, alta)
				if absf(mc - mo) > mo * TOLERANCIA:
					problemas.append("A %s mide %.2f y la original %.2f" % [v.get_file(), mc, mo])
				for mi in cont.find_children("*", "MeshInstance3D", true, false):
					var m: MeshInstance3D = mi
					for s in range(m.mesh.get_surface_count()):
						var mat: Material = m.get_active_material(s)
						var conv: Material = Ocluso3D.convertir(mat)
						if not Ocluso3D.es_comun(conv):
							problemas.append("A %s: un material no pasa al del juego (%s)" % [v.get_file(), mat.get_class() if mat else "null"])
			n.free()
	# --- B: Pieza3D.crear_visual
	var orig: Node3D = Pieza3D.crear_visual_original(id)
	var co: AABB = Pieza3D._caja(orig, Transform3D.IDENTITY) if orig != null else AABB()
	if orig != null:
		orig.free()
	# pieza NUEVA (no tiene original): se compara con su medida de TablaVariantes.MEDIDAS
	if TablaVariantes.MEDIDAS.has(id):
		var md: Dictionary = TablaVariantes.MEDIDAS[id]
		co = AABB(Vector3.ZERO, Vector3(float(md.get("planta", 0.0)), float(md.get("alto", 0.0)), 0.0))
		if ps != null and String(id) == "raices_obstaculo":
			var r: Node3D = ps.instantiate() as Node3D
			if r.get_node_or_null("cuerpo/forma_0") == null or not bool(r.get_meta("bloquea", false)):
				problemas.append("las raíces no llevan cuerpo o no bloquean")
			r.free()
	for i in range(REPETIR):
		var vis: Node3D = Pieza3D.crear_visual(id)
		if vis == null:
			problemas.append("B crear_visual devuelve null")
			break
		var cb: AABB = Pieza3D._caja(vis, Transform3D.IDENTITY)
		# plana (el musgo de agua): se compara lo que ocupa en planta; si no, el alto
		var plana: bool = cb.size.y < maxf(cb.size.x, cb.size.z) * 0.15
		if TablaVariantes.MEDIDAS.has(id):
			plana = (TablaVariantes.MEDIDAS[id] as Dictionary).has("planta")
		var mo: float = maxf(co.size.x, co.size.z) if plana else co.size.y
		var mb: float = maxf(cb.size.x, cb.size.z) if plana else cb.size.y
		if mo > 0.0 and Pieza3D.PLANAS.get(id) == null and absf(mb - mo) > mo * TOLERANCIA:
			problemas.append("B %s %.2f y el original %.2f" % ["planta" if plana else "alto", mb, mo])
			vis.free()
			break
		vis.free()
	var lista: String = ", ".join(vistas.keys())
	if problemas.is_empty():
		return "OK     %-16s variantes vistas: %s" % [id, lista]
	return "FALLO  %-16s %s  (vistas: %s)" % [id, " · ".join(problemas.slice(0, 3)), lista]
