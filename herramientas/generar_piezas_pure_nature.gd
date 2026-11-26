extends SceneTree

## GENERADOR (26/11/2026) de las piezas de los packs «Pure Nature» de BK (Fab) para Godot, con los materiales traducidos por MaterialesUE
## (presentacion/fab_ue/materiales_ue.gd): los MISMOS arreglos que se calibraron en LabComparativaBosque contra Unreal (colores lineales,
## hojas de una cara y aclaradas, capas de hierba sobre rocas, musgo al pie de los troncos). Sin teñir: el color es el del pack.
## Antes: tools/ue_exportar_pure_nature.py (Unreal), tools/preparar_pure_nature.py e importar en Godot. Crea, sin tocar nada del juego:
##   arte/pure_nature/materiales/<clave>.tres      el material de cada receta de Unreal
##   arte/pure_nature/mallas_res/<pieza>_<n>.res   las mallas
##   arte/pure_nature/piezas/pn_<pack>_<malla>.tscn con el formato de arte/piezas: raíz con metadata y `modelo/malla_<n>`
##   arte/pure_nature/indice.json                  pieza -> pack, categoría, caja (para el muestrario del laboratorio)
## Escala del juego: 0,575 u por metro (como Stylescape). Base en y = 0 tal cual viene en el pack (el pivote de BK ya está en el suelo).
## Sin cuerpo de colisión (son para mirar y colocar a mano; el bloqueo lo decide el mapa).
## Reejecutable: sobrescribe.   godot --headless --path . --script res://herramientas/generar_piezas_pure_nature.gd

const RAIZ: String = "res://arte/pure_nature/"
const ESCALA: float = 0.575
const ORIGEN: String = "Pure Nature (BK, Fab)"
## Categoría por la carpeta del pack (Models/<Trees|Rocks|Plants|...>/).
const CATEGORIAS: Dictionary = {"Trees": "arbol", "Rocks": "roca", "Plants": "planta", "Mushroom": "seta", "Props": "adorno", "Ground": "suelo"}

var _traductor: MaterialesUE
var _guardados: Dictionary = {}


func _initialize() -> void:
	var ruta_inf: String = RAIZ + "informe.json"
	if not FileAccess.file_exists(ruta_inf):
		print("FALLO  no hay %s: antes, tools/preparar_pure_nature.py e importar" % ruta_inf)
		quit(1)
		return
	var informe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta_inf))
	_traductor = MaterialesUE.new(informe, RAIZ + "texturas/")
	_traductor.escala = ESCALA
	for d in ["materiales", "mallas_res", "piezas"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAIZ + d))
	var indice: Dictionary = {}
	var bien: int = 0
	var total: int = 0
	for ruta in informe["mallas"]:
		total += 1
		var r: Dictionary = _pieza(String(ruta), informe["mallas"][ruta])
		if not r.is_empty():
			indice[r["id"]] = r
			bien += 1
	var f := FileAccess.open(RAIZ + "indice.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(indice, " "))
	f.close()
	for k in _traductor.sin_receta:
		print("AVISO  material sin receta (sale gris): %s  (maestro %s)" % [k, _traductor.sin_receta[k]])
	print("RESULTADO piezas=%d de %d · materiales=%d · sin receta=%d" % [bien, total, _guardados.size(), _traductor.sin_receta.size()])
	quit(0 if bien == total else 1)


func _xf(n: Node, raiz: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Guarda el material traducido como recurso (para que las piezas lo referencien y no lo repitan).
func _material(clave: String, alto: float) -> Material:
	var mat: Material = _traductor.material(clave, alto)
	if mat == null:
		return null
	var nombre: String = clave + ("_h%d" % int(round(alto * 10.0)) if mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("bk_follaje.gdshader") else "")
	if not _guardados.has(nombre):
		var ruta: String = RAIZ + "materiales/" + nombre + ".tres"
		ResourceSaver.save(mat, ruta)
		_guardados[nombre] = load(ruta)
	return _guardados[nombre]


func _pieza(ruta: String, d: Dictionary) -> Dictionary:
	var partes: PackedStringArray = ruta.split("/")
	var pack: String = partes[2]                                   # PureNature_Meadows
	var corto: String = pack.trim_prefix("PureNature_").to_lower()  # meadows
	var nombre: String = partes[partes.size() - 1]                  # SM_Oak2
	var id: String = "pn_%s_%s" % [corto, nombre.trim_prefix("SM_").to_lower()]
	var categoria: String = "adorno"
	for c in CATEGORIAS:
		if "/%s/" % c in ruta:
			categoria = CATEGORIAS[c]
	var ps: PackedScene = load(RAIZ + "mallas/" + String(d["fbx"])) as PackedScene
	if ps == null:
		print("FALLO  no se importó ", d["fbx"])
		return {}
	var esc: Node = ps.instantiate()
	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", false)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", categoria in ["arbol", "planta"])
	raiz.set_meta("origen", ORIGEN)
	raiz.set_meta("pack", pack)
	raiz.set_meta("pieza_original", nombre)
	raiz.set_meta("categoria", categoria)
	var modelo := Node3D.new()
	modelo.name = "modelo"
	modelo.scale = Vector3.ONE * ESCALA
	raiz.add_child(modelo)
	modelo.owner = raiz
	var caja := AABB()
	var n: int = 0
	var mats_usados: Array = []
	for mi_orig in esc.find_children("*", "MeshInstance3D", true, false):
		var malla: Mesh = (mi_orig as MeshInstance3D).mesh
		var xf: Transform3D = _xf(mi_orig, esc)
		var ruta_malla: String = RAIZ + "mallas_res/%s_%d.res" % [id, n]
		ResourceSaver.save(malla, ruta_malla)
		malla = load(ruta_malla) as Mesh
		var mi := MeshInstance3D.new()
		mi.name = "malla_%d" % n
		mi.mesh = malla
		mi.transform = xf
		modelo.add_child(mi)
		mi.owner = raiz
		var aabb: AABB = malla.get_aabb()
		for s in range(malla.get_surface_count()):
			var orig: Material = malla.surface_get_material(s)
			var clave: String = pack + "__" + (orig.resource_name if orig != null else "")
			var mat: Material = _material(clave, aabb.end.y)
			if mat != null:
				mi.set_surface_override_material(s, mat)
			mats_usados.append(clave.trim_prefix(pack + "__"))
		var c: AABB = (modelo.transform * xf) * aabb
		caja = c if n == 0 else caja.merge(c)
		n += 1
	esc.free()
	raiz.set_meta("caja", caja)
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, RAIZ + "piezas/" + id + ".tscn")
	raiz.free()
	if err != OK:
		print("FALLO  no se pudo guardar ", id)
		return {}
	print("OK     %-34s %-8s %5.2f x %5.2f x %5.2f u  %s" % [id, categoria, caja.size.x, caja.size.y, caja.size.z, str(mats_usados)])
	return {"id": id, "pack": pack, "ruta_ue": ruta, "categoria": categoria, "caja": [caja.position.x, caja.position.y, caja.position.z, caja.size.x, caja.size.y, caja.size.z]}
