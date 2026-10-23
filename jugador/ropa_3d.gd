class_name Ropa3D
extends RefCounted

## ROPA POR PIEZAS sobre un personaje con el esqueleto de `jugadora_base` (arte/meshy/PROMPTS_JUGADORA_BASE.md, docs/PLAN_RIGGING.md).
## Cada prenda es un .glb de arte/modelos con el MISMO esqueleto y el mismo Skin que el cuerpo (los monta `herramientas/montar_ropa_glb.gd`; los pesos los
## pasa `herramientas/rig/encajar_ropa.py`). Aquí se saca su MeshInstance3D del .glb y se cuelga del Skeleton3D del personaje con `skeleton = ".."`: sigue los
## mismos huesos y por tanto TODAS las animaciones, sin código por prenda. Qué prendas existen sale de `arte/modelos/ropa.json` (id -> datos); equipar una más
## es añadir su .glb y una línea al json.
##
## Zonas: cada prenda dice en `oculta` qué zonas del cuerpo tapa (cabeza, pelo, torso, chaleco, cinturon, brazos, piernas, botas). El cuerpo de jugadora_base es una
## sola malla en el .glb; al poner la primera prenda se cambia por `jugadora_base_zonas.res` (herramientas/partir_base_zonas.gd: mismos vértices y pesos, una
## superficie por zona) y `actualizar_zonas` apaga las superficies que tapan las prendas puestas: se quita la prenda y vuelven. Una superficie apagada lleva un
## material cuyo vértice sale fuera de pantalla (no se dibuja ni da sombra). Si no hay malla de zonas (otro modelo), no se oculta nada.

const RUTA_DATOS: String = "res://arte/modelos/ropa.json"
const CARPETA_MODELOS: String = "res://arte/modelos/"
const RUTA_ZONAS: String = "res://arte/modelos/jugadora_base_zonas.res"
## Prefijo del nombre del nodo de cada prenda puesta (el id va detrás).
const PREFIJO_NODO: String = "Ropa_"
## Metadato de la malla del cuerpo: el material con que se dibuja cada superficie de zona cuando no está oculta.
const META_MATERIAL_ZONAS: String = "ropa_material_zonas"
const SHADER_OCULTO: String = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid vertex() {\n\tPOSITION = vec4(2.0, 2.0, 2.0, 1.0);\n}\n"

static var _datos: Dictionary = {}
static var _cargado: bool = false
static var _malla_zonas: ArrayMesh = null
static var _zonas_cargadas: bool = false
static var _material_oculto: ShaderMaterial = null


## Todas las prendas conocidas: id -> {nombre, glb, oculta}.
static func prendas() -> Dictionary:
	if not _cargado:
		_cargado = true
		var f := FileAccess.open(RUTA_DATOS, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_datos = d
	return _datos


static func existe(id: String) -> bool:
	return prendas().has(id)


## Cuelga la prenda `id` del esqueleto del `modelo` (raíz de un personaje con el esqueleto de la jugadora base). Devuelve su MeshInstance3D o null.
## `preparar` (opcional) recibe un nodo temporal con la malla antes de colgarla: Pj3D lo usa para pasarle sus materiales (juguete, rim).
static func poner(modelo: Node3D, id: String, preparar: Callable = Callable()) -> MeshInstance3D:
	var actual: MeshInstance3D = puesta(modelo, id)
	if actual != null:
		return actual
	if not existe(id):
		push_warning("Ropa3D: no hay prenda «%s» en %s" % [id, RUTA_DATOS])
		return null
	var ruta: String = CARPETA_MODELOS + String((prendas()[id] as Dictionary).get("glb", id)) + ".glb"
	if not ResourceLoader.exists(ruta):
		push_warning("Ropa3D: falta %s" % ruta)
		return null
	var sks: Array[Node] = modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0] as Skeleton3D
	var escena: Node = (load(ruta) as PackedScene).instantiate()
	var mallas: Array[Node] = escena.find_children("*", "MeshInstance3D", true, false)
	if mallas.is_empty():
		escena.free()
		return null
	var mi: MeshInstance3D = mallas[0] as MeshInstance3D
	mi.get_parent().remove_child(mi)
	escena.free()
	mi.name = PREFIJO_NODO + id
	mi.set_meta("ropa_id", id)
	if preparar.is_valid():
		var tmp := Node3D.new()
		tmp.add_child(mi)
		preparar.call(tmp)
		tmp.remove_child(mi)
		tmp.free()
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.transform = Transform3D.IDENTITY
	actualizar_zonas(modelo)
	return mi


## Quita la prenda `id` (no hace nada si no está puesta).
static func quitar(modelo: Node3D, id: String) -> void:
	var mi: MeshInstance3D = puesta(modelo, id)
	if mi != null:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
		actualizar_zonas(modelo)


## La prenda `id` si está puesta en `modelo`, o null.
static func puesta(modelo: Node3D, id: String) -> MeshInstance3D:
	for n in modelo.find_children(PREFIJO_NODO + id, "MeshInstance3D", true, false):
		return n as MeshInstance3D
	return null


## Ids de las prendas puestas en `modelo`.
static func puestas(modelo: Node3D) -> Array[String]:
	var res: Array[String] = []
	for n in modelo.find_children(PREFIJO_NODO + "*", "MeshInstance3D", true, false):
		res.append(String((n as Node).get_meta("ropa_id", "")))
	return res


## Zonas del cuerpo que tapan las prendas puestas (unión de sus `oculta`).
static func zonas_tapadas(modelo: Node3D) -> Array[String]:
	var res: Array[String] = []
	for id in puestas(modelo):
		for z in ((prendas().get(id, {}) as Dictionary).get("oculta", []) as Array):
			if not res.has(String(z)):
				res.append(String(z))
	return res


## La malla del cuerpo: el MeshInstance3D con Skin colgado del esqueleto que no es una prenda. null si no hay.
static func cuerpo(modelo: Node3D) -> MeshInstance3D:
	for sk in modelo.find_children("*", "Skeleton3D", true, false):
		for h in sk.get_children():
			if h is MeshInstance3D and not (h as MeshInstance3D).has_meta("ropa_id") and (h as MeshInstance3D).skin != null:
				return h as MeshInstance3D
	return null


## Nombres de las zonas del cuerpo que están apagadas ahora mismo (vacío si el cuerpo no está partido).
static func zonas_apagadas(modelo: Node3D) -> Array[String]:
	var res: Array[String] = []
	var c: MeshInstance3D = cuerpo(modelo)
	if c == null or not c.has_meta(META_MATERIAL_ZONAS):
		return res
	for s in c.mesh.get_surface_count():
		if c.get_surface_override_material(s) == _material_apagado():
			res.append(c.mesh.surface_get_name(s))
	return res


## Parte el cuerpo en zonas (la primera vez) y apaga las que tapan las prendas puestas. Se llama sola al poner y quitar prendas. false si el cuerpo no se puede partir.
static func actualizar_zonas(modelo: Node3D) -> bool:
	var c: MeshInstance3D = cuerpo(modelo)
	if c == null or not _partir_cuerpo(c):
		return false
	var tapadas: Array[String] = zonas_tapadas(modelo)
	var normal: Material = c.get_meta(META_MATERIAL_ZONAS) as Material
	for s in c.mesh.get_surface_count():
		c.set_surface_override_material(s, _material_apagado() if tapadas.has(c.mesh.surface_get_name(s)) else normal)
	return true


static func _partir_cuerpo(c: MeshInstance3D) -> bool:
	if c.has_meta(META_MATERIAL_ZONAS):
		return true
	if not _zonas_cargadas:
		_zonas_cargadas = true
		if ResourceLoader.exists(RUTA_ZONAS):
			_malla_zonas = load(RUTA_ZONAS) as ArrayMesh
	# Solo el cuerpo de jugadora_base: una superficie con los vértices de los que salió la malla de zonas.
	if _malla_zonas == null or c.mesh == null or c.mesh.get_surface_count() != 1 \
			or c.mesh.surface_get_array_len(0) != int(_malla_zonas.get_meta("vertices_origen", -1)):
		return false
	var original: Material = c.get_surface_override_material(0)
	if original == null:
		original = c.mesh.surface_get_material(0)
	c.mesh = _malla_zonas
	c.set_meta(META_MATERIAL_ZONAS, original)
	return true


static func _material_apagado() -> ShaderMaterial:
	if _material_oculto == null:
		var sh := Shader.new()
		sh.code = SHADER_OCULTO
		_material_oculto = ShaderMaterial.new()
		_material_oculto.shader = sh
	return _material_oculto
