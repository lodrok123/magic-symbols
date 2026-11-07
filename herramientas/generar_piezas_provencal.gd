extends SceneTree

## GENERADOR (7/11) de las piezas del pack Fantasy Provencal (Leartes Studios): crea `arte/piezas/prov_<nombre>.tscn` para cada pieza de `TablaProvencal.PIEZAS`
## con el mismo formato que `arte/piezas/barril.tscn`: raiz Node3D (origen = centro de la base, y = 0) con metadata, hijo `modelo` y `cuerpo` StaticBody3D (capa 1024).
## Reejecutable: sobrescribe las escenas prov_*. Colores, escalas y giros salen de `arte/provencal/tabla_provencal.gd` (cambiar alli y volver a lanzar):
##   godot --headless --path . --script res://herramientas/generar_piezas_provencal.gd
## Material: StandardMaterial3D de color plano por superficie (familia de su `usemtl`, ver TablaProvencal.familia_de) puesto como `surface_material_override` del
## MeshInstance3D; PruebaTest2 lo pasa luego por Ocluso3D.convertir al cargar la pieza (igual que las de Meshy). La malla es el .obj tal cual (recurso externo).
## NO registra los ids en MEDIDA ni en integrar_piezas.py: son piezas disponibles, no colocadas. Imprime una linea por pieza.

const CAPA_MUNDO: int = 1024
const ALTO_MIN_SOLIDO: float = 0.45        ## ColisionPieza.ALTO_MIN_SOLIDO: por debajo se pisa (sin cuerpo)
const S: float = 2.3


func _initialize() -> void:
	var nombres: Array = TablaProvencal.PIEZAS.keys()
	nombres.sort()
	var hechas: int = 0
	var cuenta: Dictionary = {}
	var filtro: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--material="):
			filtro = a.substr(11)
	for nombre in nombres:
		if filtro != "" and not _usa_material(String(nombre), filtro):
			continue
		var info: Dictionary = _generar(String(nombre))
		if not info.is_empty():
			hechas += 1
			cuenta[info["cat"]] = int(cuenta.get(info["cat"], 0)) + 1
	print("RESULTADO piezas generadas: %d  %s" % [hechas, str(cuenta)])
	quit(0)


## ¿El OBJ de la pieza (o el de sus aspas) usa ese material de Unity (`usemtl`)? Para regenerar solo las piezas afectadas: `-- --material=M_Windows`.
func _usa_material(nombre: String, material: String) -> bool:
	var d: Dictionary = TablaProvencal.PIEZAS[nombre]
	var objs: Array = [nombre]
	if d.has("aspas"):
		objs.append(String((d["aspas"] as Dictionary)["obj"]))
	for o in objs:
		if FileAccess.get_file_as_string(TablaProvencal.CARPETA_OBJ + String(o) + ".obj").contains("usemtl " + material + "\n"):
			return true
	return false


func _generar(nombre: String) -> Dictionary:
	var d: Dictionary = TablaProvencal.PIEZAS[nombre]
	var ruta_obj: String = TablaProvencal.CARPETA_OBJ + nombre + ".obj"
	var malla: Mesh = load(ruta_obj) as Mesh
	if malla == null:
		print("FALLO  sin malla ", ruta_obj)
		return {}
	var caja: AABB = malla.get_aabb()
	var esc: Array = d["esc"]
	var modo: String = esc[0]
	var valor: float = float(esc[1])
	var horiz: float = maxf(caja.size.x, caja.size.z)
	var f: float
	match modo:
		"alto":
			f = valor / caja.size.y
		"ancho":
			f = valor / horiz
		"largo":                           # el eje mas largo de la malla (vigas: vertical; puente, vallas: horizontal)
			f = valor / maxf(horiz, caja.size.y)
		_:
			f = valor
	var giro: float = float(d["giro"])
	if modo == "largo" and caja.size.z > caja.size.x:
		giro += 90.0                       # el largo (eje Z de la malla) pasa a X: horizontal en pantalla
	var base: Basis = Basis(Vector3.UP, deg_to_rad(giro)) * Basis.from_scale(Vector3.ONE * f)
	var caja2: AABB = Transform3D(base, Vector3.ZERO) * caja
	var pos: Vector3 = -Vector3(caja2.position.x + caja2.size.x * 0.5, caja2.position.y, caja2.position.z + caja2.size.z * 0.5)
	var t := Transform3D(base, pos)
	var id: String = TablaProvencal.id_de(nombre)
	var alto: float = caja2.size.y
	var solido: bool = bool(d["col"]) and alto > ALTO_MIN_SOLIDO + 0.0001

	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", solido)
	raiz.set_meta("reactivo", false)
	var familias: Array = []
	var extra: MeshInstance3D = null
	var mi := MeshInstance3D.new()
	mi.name = "malla"
	mi.mesh = malla
	mi.transform = t
	_materiales(mi, nombre, String(d["mats"]), familias, String(d.get("fam", "")))
	var aspas: Dictionary = d.get("aspas", {})
	if not aspas.is_empty():
		var ma: Mesh = load(TablaProvencal.CARPETA_OBJ + String(aspas["obj"]) + ".obj") as Mesh
		var mia := MeshInstance3D.new()
		mia.name = "aspas"
		mia.mesh = ma
		mia.transform = t * Transform3D(Basis.IDENTITY, aspas["pos"] as Vector3)
		_materiales(mia, String(aspas["obj"]), String(aspas["mats"]), familias)
		extra = mia
	raiz.set_meta("inflamable", familias.all(func(x): return x == "madera"))
	raiz.set_meta("origen", TablaProvencal.ORIGEN)
	raiz.set_meta("pieza_original", nombre)
	raiz.set_meta("lod", int(d["lod"]))
	raiz.set_meta("triangulos", int(d["tris"]))
	raiz.set_meta("categoria", String(d["cat"]))
	var modelo := Node3D.new()
	modelo.name = "modelo"
	raiz.add_child(modelo)
	modelo.add_child(mi)
	if extra != null:
		modelo.add_child(extra)
	if solido:
		var forma: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		var puntos: PackedVector3Array = (malla as ArrayMesh).create_convex_shape(true, true).points if malla is ArrayMesh else PackedVector3Array()
		var fuera := PackedVector3Array()
		for p in puntos:
			fuera.append(t * p)
		forma.points = fuera
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "cuerpo"
		cuerpo.collision_layer = CAPA_MUNDO
		cuerpo.collision_mask = 0
		raiz.add_child(cuerpo)
		var cs := CollisionShape3D.new()
		cs.name = "forma_0"
		cs.shape = forma
		cuerpo.add_child(cs)
	_propietario(raiz, raiz)
	var ps := PackedScene.new()
	ps.pack(raiz)
	var salida: String = TablaProvencal.CARPETA_PIEZAS + id + ".tscn"
	var err: int = ResourceSaver.save(ps, salida)
	raiz.free()
	if err != OK:
		print("FALLO  no se pudo guardar ", salida, " error ", err)
		return {}
	print("OK     %-22s %-18s x%.4f %4.2f x %4.2f casillas (%.2f x %.2f u) %5d tris  col=%s  %s" % [
		id, d["cat"], f, maxf(caja2.size.x, caja2.size.z) / S, alto / S, maxf(caja2.size.x, caja2.size.z), alto, int(d["tris"]), str(solido), str(familias)])
	return {"cat": d["cat"]}


## Un StandardMaterial3D por superficie: COLOR de la paleta (familia de su usemtl) x DETALLE en gris del albedo del pack (media = 1) y su normal aplanada. Si el detalle lleva alfa
## (hojas, aspas) recorta (alpha scissor 0,5) a doble cara. Sin detalle para ese material (o en SIN_DETALLE): solo color.
func _materiales(mi: MeshInstance3D, nombre: String, mats: String, familias: Array, fam_hoja: String = "") -> void:
	var malla: Mesh = mi.mesh
	for s in range(malla.get_surface_count()):
		var mat_unity: String = malla.surface_get_name(s)
		if not mat_unity.begins_with("M_"):
			mat_unity = mats                   # superficie unica sin nombre de material: el primero del catalogo
		var fam: String = TablaProvencal.familia_de(mat_unity)
		if fam == "hoja" and fam_hoja != "":
			fam = fam_hoja
		familias.append(fam)
		var m := StandardMaterial3D.new()
		var color: Color = TablaProvencal.COLORES[fam]
		m.albedo_color = color
		m.roughness = 1.0
		if TablaProvencal.SIN_CULL.has(fam) or TablaProvencal.DOBLE_CARA.has(nombre):
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var det: Array = TablaProvencal.DETALLE.get(mat_unity, [])
		if not det.is_empty() and not TablaProvencal.SIN_DETALLE.has(mat_unity):
			var ruta: String = TablaProvencal.CARPETA_DETALLE + String(det[0]) + ".png"
			if ResourceLoader.exists(ruta):
				m.albedo_texture = load(ruta) as Texture2D
				m.albedo_color = Color(color.r * TablaProvencal.BRILLO_DETALLE, color.g * TablaProvencal.BRILLO_DETALLE, color.b * TablaProvencal.BRILLO_DETALLE)
				if TablaProvencal.RECORTE.has(String(det[0])):
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m.alpha_scissor_threshold = 0.5
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
				elif String(det[1]) != "" and ResourceLoader.exists(TablaProvencal.CARPETA_DETALLE + String(det[1]) + ".png"):
					m.normal_enabled = true
					m.normal_texture = load(TablaProvencal.CARPETA_DETALLE + String(det[1]) + ".png") as Texture2D
		mi.set_surface_override_material(s, m)


func _propietario(n: Node, duenio: Node) -> void:
	for h in n.get_children():
		h.owner = duenio
		_propietario(h, duenio)
