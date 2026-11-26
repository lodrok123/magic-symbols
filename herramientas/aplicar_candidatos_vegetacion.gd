extends SceneTree

## APLICAR CANDIDATOS DE VEGETACIÓN (26/11/2026). Lleva al juego lo que Pablo eligió en docs/fab_ue/candidatos_vegetacion.json
## (vista de candidatos de LabComparativaBosque, tecla 4): sustituir piezas de vegetación por las del pack Pure Nature, al tamaño de la
## pieza actual y con el MATERIAL DEL JUEGO (para que se quemen, se mojen, se hielen y reaccionen como las demás).
##
##   godot --headless --path . --script res://herramientas/aplicar_candidatos_vegetacion.gd
##
## Hace tres cosas (reejecutable: sobrescribe):
##   1. arte/pure_nature/juego/pn_*.tscn   cada pieza del pack que se usa, con StandardMaterial3D (MaterialesUE.material_juego) en vez de
##                                          los shaders del pack. Fuera de git, como todo arte/pure_nature (licencia de Fab).
##   2. presentacion/fab_ue/tabla_variantes.gd   la tabla pieza -> variantes ("" = la original).
##   3. arte/piezas/<id>.tscn               a las piezas que cambian les pone VarianteVegetal en la raíz y la caja de su modelo original.
## Necesita el pack generado (arte/pure_nature/LEEME.md). Sin él, el juego sigue con las piezas originales.

const CANDIDATOS: String = "res://docs/fab_ue/candidatos_vegetacion.json"
const PN: String = "res://arte/pure_nature/"
const JUEGO: String = "res://arte/pure_nature/juego/"
const TABLA: String = "res://presentacion/fab_ue/tabla_variantes.gd"

var _traductor: MaterialesUE


func _initialize() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATOS))
	var informe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PN + "informe.json"))
	_traductor = MaterialesUE.new(informe, PN + "texturas/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JUEGO + "materiales"))
	var tabla: Dictionary = {}
	var usados: Dictionary = {}
	var fallos: int = 0
	for g in d["grupos"]:
		for f in g["filas"]:
			var actual: String = f["actual"]
			var eleg: Array = f.get("elegido", [])
			if eleg.is_empty() or eleg == [actual]:
				continue
			var lista: Array = []
			for e in eleg:
				if String(e) == actual:
					lista.append("")
				else:
					lista.append(JUEGO + String(e) + ".tscn")
					usados[String(e)] = true
			tabla[actual] = lista
	# también las que van a ser piezas nuevas o decoración (se preparan ya; se colocan en otro paso)
	for g in d["grupos"]:
		for f in g["filas"]:
			for e in f.get("nuevas", []):
				usados[String(e)] = true
	for e in d.get("decorar_suelo", []) + d.get("hierba_corta_suelo", []):
		usados[String(e)] = true
	for pz in d.get("piezas_nuevas", []):
		usados[String(pz["pieza"])] = true
	# 1. variantes con material del juego
	for pn in usados:
		if not _variante_juego(String(pn)):
			fallos += 1
	# 1b. piezas NUEVAS (26/11): su tabla, su medida y su escena en arte/piezas
	var medidas: Dictionary = {}
	for pz in d.get("piezas_nuevas", []):
		var r: Dictionary = _pieza_nueva(pz)
		if r.is_empty():
			fallos += 1
			continue
		tabla[String(pz["id"])] = [JUEGO + String(pz["pieza"]) + ".tscn"]
		medidas[String(pz["id"])] = r
	# 2. la tabla
	_escribir_tabla(tabla, medidas)
	# 3. las piezas del juego que cambian
	for id in tabla:
		if not _marcar_pieza(String(id)):
			fallos += 1
	print("RESULTADO variantes=%d piezas_cambiadas=%d fallos=%d" % [usados.size(), tabla.size(), fallos])
	quit(0 if fallos == 0 else 1)


## arte/pure_nature/juego/<pn>.tscn: el «modelo» de la pieza del pack con los materiales del juego.
func _variante_juego(pn: String) -> bool:
	var ps: PackedScene = load(PN + "piezas/" + pn + ".tscn") as PackedScene
	if ps == null:
		print("FALLO  no existe la pieza del pack ", pn)
		return false
	var pieza: Node3D = ps.instantiate() as Node3D
	var pack: String = String(pieza.get_meta("pack", ""))
	var modelo: Node3D = pieza.get_node("modelo") as Node3D
	pieza.remove_child(modelo)
	pieza.free()
	var raiz := Node3D.new()
	raiz.name = pn
	raiz.set_meta("pieza_pack", pn)
	raiz.add_child(modelo)
	for n in modelo.find_children("*", "", true, false):
		n.owner = raiz
	modelo.owner = raiz
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in range(m.mesh.get_surface_count()):
			var orig: Material = m.mesh.surface_get_material(s)
			var clave: String = pack + "__" + (orig.resource_name if orig != null else "")
			var mat: Material = _traductor.material_juego(clave)
			if mat == null:
				continue
			if mat is StandardMaterial3D:
				var ruta_mat: String = JUEGO + "materiales/" + clave + ".tres"
				if not ResourceLoader.exists(ruta_mat):
					ResourceSaver.save(mat, ruta_mat)
				mat = load(ruta_mat)
			m.set_surface_override_material(s, mat)
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, JUEGO + pn + ".tscn")
	raiz.free()
	print("%s    %s" % ["OK " if err == OK else "FALLO", pn])
	return err == OK


func _escribir_tabla(tabla: Dictionary, medidas: Dictionary) -> void:
	var texto: String = FileAccess.get_file_as_string(TABLA)
	texto = _sustituir_dict(texto, "VARIANTES", tabla)
	texto = _sustituir_dict(texto, "MEDIDAS", medidas)
	var f := FileAccess.open(TABLA, FileAccess.WRITE)
	f.store_string(texto)
	f.close()
	print("tabla: %d piezas (%d nuevas) -> %s" % [tabla.size(), medidas.size(), TABLA])


## Reescribe `const <nombre>: Dictionary = {...}` (vacío `{}` o de varias líneas) con `dic`, una entrada por línea y en orden.
func _sustituir_dict(texto: String, nombre: String, dic: Dictionary) -> String:
	var cab: String = "const %s: Dictionary = {" % nombre
	var i: int = texto.find(cab)
	if i < 0:
		return texto
	var j: int
	if texto.substr(i + cab.length(), 1) == "}":
		j = i + cab.length() + 1
	else:
		j = texto.find("\n}", i) + 2
	var ids: Array = dic.keys()
	ids.sort()
	var lineas: PackedStringArray = []
	for id in ids:
		lineas.append("\t\"%s\": %s," % [id, JSON.stringify(dic[id])])
	var bloque: String = (cab + "}") if lineas.is_empty() else (cab + "\n" + "\n".join(lineas) + "\n}")
	return texto.substr(0, i) + bloque + texto.substr(j)


## Una pieza NUEVA (no existía en el juego): su medida («al tamaño de» la pieza de referencia, o N casillas con «@Ncasillas»/«@1casilla»)
## y su escena arte/piezas/<id>.tscn (VarianteVegetal, sin modelo propio: sale del pack al instanciarla; las que bloquean llevan cuerpo).
## Devuelve la medida ({"alto"} o {"planta"}) o {} si falla.
func _pieza_nueva(pz: Dictionary) -> Dictionary:
	var id: String = pz["id"]
	var ref: String = pz["tamano_de"]
	var medida: Dictionary
	# ¿la pieza del pack es plana? (las margaritas son mantos de 9 cm de alto: igualadas por la ALTURA de la flor de referencia salían
	# cinco veces más anchas, puntitos sueltos por todo el suelo; las planas se igualan por lo que ocupa en planta la referencia)
	var ps0: PackedScene = load(JUEGO + String(pz["pieza"]) + ".tscn") as PackedScene
	var plana: bool = false
	if ps0 != null:
		var v0: Node3D = ps0.instantiate() as Node3D
		var c0: AABB = TablaVariantes.caja(v0)
		plana = c0.size.y < maxf(c0.size.x, c0.size.z) * 0.15
		v0.free()
	if ref.begins_with("@"):
		var n: float = float(ref.trim_prefix("@").to_int())
		medida = {"planta": snappedf(maxf(n, 1.0) * Pieza3D.S, 0.01)}
	else:
		var orig: Node3D = Pieza3D.crear_visual_original(ref)
		if orig == null:
			print("FALLO  %s: no existe la pieza de referencia %s" % [id, ref])
			return {}
		var c: AABB = Pieza3D._caja(orig, Transform3D.IDENTITY)
		orig.free()
		var alta: bool = c.size.y > maxf(c.size.x, c.size.z) * 0.35 and not plana
		medida = {"alto": snappedf(c.size.y, 0.01)} if alta else {"planta": snappedf(maxf(c.size.x, c.size.z), 0.01)}
	# la caja que tendrá ya escalada (para VarianteVegetal y para el cuerpo)
	var ps: PackedScene = load(JUEGO + String(pz["pieza"]) + ".tscn") as PackedScene
	if ps == null:
		print("FALLO  %s: falta la variante %s" % [id, pz["pieza"]])
		return {}
	var v: Node3D = ps.instantiate() as Node3D
	var cv: AABB = TablaVariantes.caja(v)
	v.free()
	var k: float = (float(medida["alto"]) / maxf(cv.size.y, 0.0001)) if medida.has("alto") else (float(medida["planta"]) / maxf(maxf(cv.size.x, cv.size.z), 0.0001))
	var tam: Vector3 = cv.size * k
	var bloquea: bool = String(pz["uso"]).contains("bloquea")
	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_script(load("res://presentacion/fab_ue/variante_vegetal.gd"))
	raiz.set("caja_original", AABB(Vector3(-tam.x * 0.5, 0.0, -tam.z * 0.5), tam))
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", bloquea)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", not id.begins_with("seta") and not id.begins_with("musgo"))
	raiz.set_meta("origen", "Pure Nature (BK, Fab) · elección de Pablo 26/11: %s" % pz["de"])
	raiz.set_meta("uso", pz["uso"])
	var modelo := Node3D.new()
	modelo.name = "modelo"
	raiz.add_child(modelo)
	modelo.owner = raiz
	if bloquea:
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "cuerpo"
		cuerpo.collision_layer = 1024
		cuerpo.collision_mask = 0
		raiz.add_child(cuerpo)
		cuerpo.owner = raiz
		var forma := CollisionShape3D.new()
		forma.name = "forma_0"
		var caja := BoxShape3D.new()
		caja.size = Vector3(tam.x, minf(tam.y, 1.2), tam.z)
		forma.shape = caja
		forma.position = Vector3(0.0, caja.size.y * 0.5, 0.0)
		cuerpo.add_child(forma)
		forma.owner = raiz
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, "res://arte/piezas/%s.tscn" % id)
	raiz.free()
	print("%s    nueva %-24s %s  %s" % ["OK " if err == OK else "FALLO", id, str(medida), "(bloquea)" if bloquea else ""])
	return medida if err == OK else {}


## Pone VarianteVegetal en la raíz de arte/piezas/<id>.tscn y le guarda la caja del modelo original (en el espacio de «modelo»).
func _marcar_pieza(id: String) -> bool:
	var ruta: String = "res://arte/piezas/%s.tscn" % id
	# ya marcada en una pasada anterior: el modelo original y su caja no cambian; no se vuelve a guardar (al instanciarla ya cambiaría)
	if FileAccess.get_file_as_string(ruta).contains("variante_vegetal.gd"):
		print("OK     %-16s (ya tenía VarianteVegetal)" % id)
		return true
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		print("FALLO  no existe ", ruta)
		return false
	# instanciar sin que VarianteVegetal cambie nada: la tabla puede estar ya cargada; se mide el modelo que trae el archivo
	var raiz: Node3D = ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	var modelo: Node3D = raiz.get_node_or_null("modelo") as Node3D
	var caja: AABB
	if modelo == null:
		# mallas sueltas en la raíz (arbol_sumicio): la caja de esas mallas, en el espacio de la raíz
		var sueltas := Node3D.new()
		var hay: bool = false
		for c in raiz.get_children():
			if c is MeshInstance3D:
				var copia: MeshInstance3D = (c as MeshInstance3D).duplicate() as MeshInstance3D
				sueltas.add_child(copia)
				hay = true
		caja = TablaVariantes.caja(sueltas)
		sueltas.free()
		if not hay:
			# sin mallas (hierba_crecida es una zona; su aspecto lo pone el código): le basta la tabla, que actúa en Pieza3D.crear_visual
			raiz.free()
			print("OK     %-16s (sin modelo propio: solo por la tabla)" % id)
			return true
	else:
		caja = TablaVariantes.caja(modelo)
	if raiz.get_node_or_null("modelo/variante") != null:
		raiz.free()
		print("FALLO  %s: al instanciar ya se cambió el modelo; reintenta (la tabla debe estar vacía al medir)" % id)
		return false
	raiz.set_script(load("res://presentacion/fab_ue/variante_vegetal.gd"))
	raiz.set("caja_original", caja)
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, ruta)
	raiz.free()
	print("%s    %-16s caja %s" % ["OK " if err == OK else "FALLO", id, str(caja)])
	return err == OK
