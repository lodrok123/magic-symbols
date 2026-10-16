class_name PiezaBosque3D
extends RefCounted

## PIEZAS DEL BOSQUE CON MODELO (16/10, Pipeline): tronco-puente en pie y caído, bloqueo de enredaderas vivo y quemado, y restos quemados. Salen de la lámina
## «Verdant Timber Ruins» de Meshy, separada (docs/ARTE.md §15) en `res://arte/meshy/bosque/bosque_ruinas.glb`: un nodo por pieza con su id, ya orientado,
## a escala y con el origen puesto. Sin la lámina, `malla_modelo` devuelve null y quien lo use sigue con su primitiva (como `PiezaPuzle3D`).
##
## Uso:   var m: MeshInstance3D = PiezaBosque3D.crear("tronco_puente_pie"); padre.add_child(m)      # null si no hay lámina
##
## ORIGEN y MEDIDA (X × Y × Z, tal como salen del modelo):
##   tronco_puente_pie            centro de la base · 1,43 × 2,6 × 1,58 (la base lleva piedras y vainas sueltas: la huella es mayor que el tronco)
##   tronco_puente_caido          el PIE del tronco, a ras de suelo, tumbado hacia +X · 2,6 × 0,56 × 0,5 (cara de arriba para caminar)
##   bloqueo_enredaderas          centro de la base · 2,2 × 1,08 × 1,09 (un tronco cubierto de enredaderas: más ancho y bajo que lo pedido en los prompts)
##   bloqueo_enredaderas_quemado  centro de la base · 1,83 × 0,66 × 1,02 (mismo factor de escala que el vivo; es la mata hundida, no tiene el mismo ancho)
##   enredadera_quemada_a / _b    centro de la base · 0,6 × 0,22 × 0,62 / 0,5 × 0,3 × 0,56
##   ceniza_enredadera            centro de la base · 0,9 × 0,1 × 1,03

const RUTA: String = "res://arte/meshy/bosque/bosque_ruinas.glb"
const IDS: PackedStringArray = ["tronco_puente_pie", "tronco_puente_caido", "bloqueo_enredaderas", "bloqueo_enredaderas_quemado",
	"enredadera_quemada_a", "enredadera_quemada_b", "ceniza_enredadera"]

static var _mallas: Dictionary = {}          ## id -> Mesh (se lee la lámina una sola vez)
static var _leida: bool = false


## El `Mesh` de la pieza (ya orientado y a escala) o null si la lámina no existe o no trae ese nodo.
static func malla_modelo(id: String) -> Mesh:
	if not _leida:
		_leida = true
		if ResourceLoader.exists(RUTA):
			var ps: PackedScene = load(RUTA) as PackedScene
			if ps != null:
				var raiz: Node = ps.instantiate()
				for n in raiz.get_children():
					if n is MeshInstance3D:
						_mallas[String(n.name)] = (n as MeshInstance3D).mesh
				raiz.queue_free()
	return _mallas.get(id, null)


## Un `MeshInstance3D` con la pieza, o null si no hay modelo.
static func crear(id: String) -> MeshInstance3D:
	var malla: Mesh = malla_modelo(id)
	if malla == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = malla
	return mi
