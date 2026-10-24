extends SceneTree
## PESOS DE LA CAPA (y de la capucha) POR ZONAS (25/10, Pablo: «Revisa la capa. Los pesos están mal. No funciona en ninguna animación, ni idle ni walking»).
## Lee arte/modelos/ropa_capa.glb (o el .glb que se pase) tal cual lo carga el juego y saca una tabla: por zona de la capa (cuello y nuca, hombros, pecho, espalda,
## borde) el % del peso que va a cada grupo de huesos (Head, Neck, Spine2, Spine1/Spine, brazo, cadenas `capa_*`), la altura de cada zona y cuántos vértices
## por debajo del cuello llevan peso de Head. Las zonas, en u del modelo (coronilla 1,70) con la capa en reposo. Sin ventana:
##   godot --headless --path . --script res://herramientas/pesos_capa.gd [-- <glb> [<glb capucha>]]

const GLB_CAPA: String = "res://arte/modelos/ropa_capa.glb"
const GLB_CAPUCHA: String = "res://arte/modelos/ropa_capucha.glb"
const GRUPOS: Array = ["Head", "Neck", "Spine2", "Spine1", "Spine", "brazo", "capa_*", "otro"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var ruta: String = a[0] if a.size() > 0 else GLB_CAPA
	var ruta_cap: String = a[1] if a.size() > 1 else GLB_CAPUCHA
	var d: Dictionary = leer(ruta)
	print("== CAPA %s: %d vértices" % [ruta, (d["pts"] as PackedVector3Array).size()])
	_tabla(d, zonas_capa(d))
	print("CAPA vértices bajo el cuello (y < %.3f) con peso en Head > %.2f: %d (máx %.3f)" % [float(d["y_cuello"]), CapaMuelles3D.HEAD_MAX_BAJO_CUELLO,
		head_bajo_cuello(d, CapaMuelles3D.HEAD_MAX_BAJO_CUELLO), max_head_bajo_cuello(d)])
	var c: Dictionary = leer(ruta_cap)
	print("== CAPUCHA %s: %d vértices" % [ruta_cap, (c["pts"] as PackedVector3Array).size()])
	_tabla(c, zonas_capucha(c))
	quit(0)


## {pts (u del modelo, reposo), grupos: Array[Dictionary grupo->peso], y_cuello, y_cabeza, y_hombro, centro}
static func leer(ruta: String) -> Dictionary:
	var escena: Node = null
	if ruta.begins_with("res://") and ResourceLoader.exists(ruta):
		escena = (load(ruta) as PackedScene).instantiate()
	else:
		# un .glb fuera del proyecto (o sin importar): se lee a pelo
		var doc := GLTFDocument.new()
		var estado := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path(ruta), estado)
		escena = doc.generate_scene(estado)
	var sk: Skeleton3D = escena.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var escala: float = (sk.get_parent() as Node3D).scale.y
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por: int = bones.size() / verts.size()
	var nombre_de: Array = []
	var xf: Array = []
	for b in mi.skin.get_bind_count():
		var n: String = mi.skin.get_bind_name(b)
		if n == "" and mi.skin.get_bind_bone(b) >= 0:
			n = sk.get_bone_name(mi.skin.get_bind_bone(b))
		nombre_de.append(n)
		var i: int = sk.find_bone(n)
		xf.append(sk.get_bone_global_rest(i) * mi.skin.get_bind_pose(b) if i >= 0 else Transform3D.IDENTITY)
	var pts := PackedVector3Array()
	var grupos: Array = []
	for v in verts.size():
		var p := Vector3.ZERO
		var g: Dictionary = {}
		for k in por:
			var w: float = pesos[v * por + k]
			if w <= 0.0:
				continue
			var b: int = bones[v * por + k]
			p += ((xf[b] as Transform3D) * verts[v]) * w
			var gr: String = grupo(String(nombre_de[b]))
			g[gr] = float(g.get(gr, 0.0)) + w
		pts.append(p * escala)
		grupos.append(g)
	var res: Dictionary = {"pts": pts, "grupos": grupos,
		"y_cuello": sk.get_bone_global_rest(sk.find_bone("mixamorig_Neck")).origin.y * escala,
		"y_cabeza": sk.get_bone_global_rest(sk.find_bone("mixamorig_Head")).origin.y * escala,
		"y_hombro": sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftArm")).origin.y * escala,
		"x_hombro": absf(sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftArm")).origin.x * escala),
		"z_cuello": sk.get_bone_global_rest(sk.find_bone("mixamorig_Neck")).origin.z * escala}
	escena.free()
	return res


static func grupo(n: String) -> String:
	if n.begins_with(CapaMuelles3D.PREFIJO):
		return "capa_*"
	var s: String = n.replace("mixamorig_", "")
	if s in ["Head", "HeadTop_End", "headfront"]:
		return "Head"
	if s in ["Neck", "Spine2", "Spine1", "Spine"]:
		return s
	if CapaMuelles3D.es_hueso_brazo(n):
		return "brazo"
	return "otro"


## Zonas de la capa: nombre -> índices, por altura y ángulo alrededor del eje del cuello (0° = delante). Por encima de ALTO_CUELLO: «cierre» (mitad de delante) y
## «nuca» (mitad de atrás); entre ALTO_HOMBROS y ALTO_CUELLO: «pecho» (±45°), «hombros» (45–135°) y «espalda» (> 135°); debajo, «borde».
const ALTO_CUELLO: float = 1.10
const ALTO_HOMBROS: float = 1.00


static func zonas_capa(d: Dictionary) -> Dictionary:
	var z: Dictionary = {"cierre": [], "nuca": [], "pecho": [], "hombros": [], "espalda": [], "borde": []}
	var pts: PackedVector3Array = d["pts"]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var a: float = absf(rad_to_deg(atan2(p.x, p.z - float(d["z_cuello"]))))
		if p.y < ALTO_HOMBROS:
			z["borde"].append(i)
		elif p.y >= ALTO_CUELLO:
			z["cierre" if a < 90.0 else "nuca"].append(i)
		elif a < 45.0:
			z["pecho"].append(i)
		elif a < 135.0:
			z["hombros"].append(i)
		else:
			z["espalda"].append(i)
	return z


## Capucha: faldón (por debajo de la base del cuello + 3 cm) y el resto (la capucha de la cabeza).
static func zonas_capucha(d: Dictionary) -> Dictionary:
	var z: Dictionary = {"faldon_cuello": [], "cabeza": []}
	var pts: PackedVector3Array = d["pts"]
	for i in pts.size():
		z["faldon_cuello" if pts[i].y < float(d["y_cuello"]) + 0.03 else "cabeza"].append(i)
	return z


static func head_bajo_cuello(d: Dictionary, umbral: float) -> int:
	var n: int = 0
	for i in (d["pts"] as PackedVector3Array).size():
		if (d["pts"][i] as Vector3).y < float(d["y_cuello"]) and float((d["grupos"][i] as Dictionary).get("Head", 0.0)) > umbral:
			n += 1
	return n


static func max_head_bajo_cuello(d: Dictionary) -> float:
	var m: float = 0.0
	for i in (d["pts"] as PackedVector3Array).size():
		if (d["pts"][i] as Vector3).y < float(d["y_cuello"]):
			m = maxf(m, float((d["grupos"][i] as Dictionary).get("Head", 0.0)))
	return m


func _tabla(d: Dictionary, zonas: Dictionary) -> void:
	print("  (Neck y %.3f · Head y %.3f · hombro y %.3f x %.3f)" % [float(d["y_cuello"]), float(d["y_cabeza"]), float(d["y_hombro"]), float(d["x_hombro"])])
	var cab: String = "  %-12s %6s %11s" % ["zona", "verts", "y"]
	for g in GRUPOS:
		cab += " %7s" % g
	print(cab)
	for zn in zonas:
		var ids: Array = zonas[zn]
		if ids.is_empty():
			continue
		var tot: Dictionary = {}
		var y0: float = INF
		var y1: float = -INF
		for i in ids:
			y0 = minf(y0, (d["pts"][i] as Vector3).y)
			y1 = maxf(y1, (d["pts"][i] as Vector3).y)
			for g in (d["grupos"][i] as Dictionary):
				tot[g] = float(tot.get(g, 0.0)) + float(d["grupos"][i][g])
		var fila: String = "  %-12s %6d %5.2f–%4.2f" % [zn, ids.size(), y0, y1]
		for g in GRUPOS:
			fila += " %6.1f%%" % (100.0 * float(tot.get(g, 0.0)) / ids.size())
		print(fila)
