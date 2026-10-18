class_name PiezaBosque3D
extends RefCounted

## PIEZAS DEL BOSQUE CON MODELO (16/10, Pipeline): tronco-puente en pie y caído, bloqueo de enredaderas vivo y quemado y restos quemados (lámina «Verdant Timber Ruins»,
## `bosque_ruinas.glb`, docs/ARTE.md §15), más la orilla del estanque (`bosque_orilla.glb`) y el sendero (`bosque_sendero.glb`) (docs/ARTE.md §18). En cada GLB hay un nodo
## por pieza con su id, ya orientado, a escala y con el origen puesto. Sin los GLB, `malla_modelo` devuelve null y quien lo use sigue con su primitiva (como `PiezaPuzle3D`).
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
## ORILLA DEL ESTANQUE (origen: centro de la base salvo el tronco; ya sin la capa plana de hierba bajo cada pieza):
##   tronco_estanque  CENTRO DEL EJE, tumbado a lo largo de +X · 2,6 × 0,65 × 0,79 (salió achaparrado: se alargó 1,6× en X; es más grueso que el cilindro provisional de 0,6)
##   juncos_a 0,8 × 0,55 × 0,82 · juncos_b 0,8 × 0,44 × 0,58 · tocon_musgo 0,9 × 0,45 × 0,67 · setas_grupo 0,5 × 0,3 × 0,31
##   roca_musgo_g 1,2 × 0,8 × 0,94 · roca_musgo_m 0,7 × 0,44 × 0,83 · roca_musgo_p 0,35 × 0,16 × 0,35 · nenufar_a 0,56 × 0,26 × 0,7 (con capullo) · nenufar_b 0,46 × 0,1 × 0,5 (plano)
## SENDERO:
##   arbusto_hojas 1,2 × 0,68 × 1,16 · arbusto_frutos 1,4 × 0,86 × 1,31 · raiz_grande 1,4 × 0,72 × 1,45 · hojas_monton 0,7 × 0,19 × 0,9 · tronco_hueco 0,89 × 1,1 × 1,0
##   valla_tramo 2,0 × 0,93 × 1,55 (las hojas la ensanchan en Z) · troncos_apilados 1,0 × 0,54 × 1,0 · cartel_bosque 0,93 × 1,6 × 1,15 (tablilla en blanco)
##   hojas_suelo_a/b/c ≈ 0,55 × 0,05 × 0,7 (hojas esparcidas, planas)

const RUTAS: PackedStringArray = ["res://arte/meshy/bosque/bosque_ruinas.glb", "res://arte/meshy/bosque/bosque_orilla.glb", "res://arte/meshy/bosque/bosque_sendero.glb"]
const IDS: PackedStringArray = ["tronco_puente_pie", "tronco_puente_caido", "bloqueo_enredaderas", "bloqueo_enredaderas_quemado",
	"enredadera_quemada_a", "enredadera_quemada_b", "ceniza_enredadera",
	"tronco_estanque", "juncos_a", "juncos_b", "tocon_musgo", "setas_grupo", "roca_musgo_g", "roca_musgo_m", "roca_musgo_p", "nenufar_a", "nenufar_b",
	"arbusto_hojas", "arbusto_frutos", "raiz_grande", "hojas_monton", "tronco_hueco", "valla_tramo", "troncos_apilados", "cartel_bosque",
	"hojas_suelo_a", "hojas_suelo_b", "hojas_suelo_c"]

static var _mallas: Dictionary = {}          ## id -> Mesh (se lee la lámina una sola vez)
static var _leida: bool = false


## El `Mesh` de la pieza (ya orientado y a escala) o null si la lámina no existe o no trae ese nodo.
static func malla_modelo(id: String) -> Mesh:
	if not _leida:
		_leida = true
		for ruta in RUTAS:
			if ResourceLoader.exists(ruta):
				var ps: PackedScene = load(ruta) as PackedScene
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
