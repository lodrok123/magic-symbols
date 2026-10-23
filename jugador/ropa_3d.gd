class_name Ropa3D
extends RefCounted

## ROPA POR PIEZAS sobre un personaje con el esqueleto de `jugadora_base` (arte/meshy/PROMPTS_JUGADORA_BASE.md, docs/PLAN_RIGGING.md).
## Cada prenda es un .glb de arte/modelos con el MISMO esqueleto y el mismo Skin que el cuerpo (los monta `herramientas/montar_ropa_glb.gd`; los pesos los
## pasa `herramientas/rig/encajar_ropa.py`). Aquí se saca su MeshInstance3D del .glb y se cuelga del Skeleton3D del personaje con `skeleton = ".."`: sigue los
## mismos huesos y por tanto TODAS las animaciones, sin código por prenda. Qué prendas existen sale de `arte/modelos/ropa.json` (id -> datos); equipar una más
## es añadir su .glb y una línea al json.
##
## Zonas: cada prenda dice en `oculta` qué zonas del cuerpo tapa (hoy sin efecto: el cuerpo es UNA malla, ver docs/PLAN_RIGGING.md «Ropa por piezas»);
## `ocultar_zonas` queda para cuando se parta el cuerpo por zonas.

const RUTA_DATOS: String = "res://arte/modelos/ropa.json"
const CARPETA_MODELOS: String = "res://arte/modelos/"
## Prefijo del nombre del nodo de cada prenda puesta (el id va detrás).
const PREFIJO_NODO: String = "Ropa_"

static var _datos: Dictionary = {}
static var _cargado: bool = false


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
	return mi


## Quita la prenda `id` (no hace nada si no está puesta).
static func quitar(modelo: Node3D, id: String) -> void:
	var mi: MeshInstance3D = puesta(modelo, id)
	if mi != null:
		mi.get_parent().remove_child(mi)
		mi.queue_free()


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


## Zonas del cuerpo que tapan las prendas puestas (unión de sus `oculta`). Para cuando el cuerpo vaya partido por zonas.
static func zonas_tapadas(modelo: Node3D) -> Array[String]:
	var res: Array[String] = []
	for id in puestas(modelo):
		for z in ((prendas().get(id, {}) as Dictionary).get("oculta", []) as Array):
			if not res.has(String(z)):
				res.append(String(z))
	return res
