class_name PiezaEscritura3D
extends RefCounted

## PLUMA Y MANO CON MODELO (16/10, Pipeline): salen de dos GLB de Meshy ("Verdant Quill" y "Pointing Hand Emerging") separados y puestos a escala
## (docs/ARTE.md §17). Cada nodo trae su malla ya a escala y con el origen puesto. Sin el GLB, `malla_modelo` devuelve null (como `PiezaBosque3D`).
##
## Uso:   var m: MeshInstance3D = PiezaEscritura3D.crear("pluma"); padre.add_child(m)      # null si no hay modelo
##
## ORIGEN y MEDIDA (X × Y × Z):
##   pluma           la PUNTA del plumín, de pie (la pluma sube por +Y) · 0,21 × 0,7 × 0,045 · la cara plana de la pluma mira a +Z
##   mano_apuntando  la punta del DEDO ÍNDICE (que apunta hacia abajo, −Y) · 0,39 × 0,5 × 0,54. OJO: es un puño con el índice estirado, NO sujeta la pluma
##   manga_mano      el mismo origen que la mano: añadida al mismo padre, mano y manga forman el brazo tal como salió del modelo
##   mano_agarre     (la buena para escribir) mano en pose de agarre, con el pellizco abierto: el origen es el CENTRO DEL PELLIZCO, entre la yema del pulgar y la del índice ·
##                   0,27 × 0,23 × 0,5. Los dedos apuntan a +Z, la palma mira a −Y y la espalda de la mano a +Y. El pulgar está cerrado un poco hacia el índice (ver docs/ARTE.md §17)
##   manga_agarre    el mismo origen que `mano_agarre` · 0,29 × 0,29 × 0,26 (la muñeca queda hacia −Z)
##
## LA PLUMA EN LA MANO: `pluma_en_agarre()` da el `Transform3D` de la pluma (en el espacio de `mano_agarre`) para que quede sujeta: la punta del plumín asoma
## 10 cm hacia delante y abajo del pellizco y la pluma se tumba hacia atrás y arriba sobre el dorso de la mano, a 50° de la horizontal, girada 40° sobre su eje
## para que se vea el plano de la pluma. Para escribir se gira el conjunto (mano + manga + pluma) y se apoya el plumín; para no escribir se oculta la pluma.

const RUTAS: Dictionary = {
	"pluma": "res://arte/meshy/escritura/pluma.glb",
	"mano_apuntando": "res://arte/meshy/escritura/mano.glb",
	"manga_mano": "res://arte/meshy/escritura/mano.glb",
	"mano_agarre": "res://arte/meshy/escritura/mano_agarre.glb",
	"manga_agarre": "res://arte/meshy/escritura/mano_agarre.glb",
}

static var _mallas: Dictionary = {}          ## id -> Mesh
static var _leidas: Dictionary = {}          ## ruta -> true (cada GLB se lee una sola vez)


## El `Mesh` de la pieza (ya a escala y con su origen) o null si no existe el GLB o no trae ese nodo.
static func malla_modelo(id: String) -> Mesh:
	var ruta: String = String(RUTAS.get(id, ""))
	if ruta == "":
		return null
	if not _leidas.has(ruta):
		_leidas[ruta] = true
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


const AGARRE_ANGULO_GRADOS: float = 50.0      ## inclinación de la pluma sobre la horizontal (con la punta hacia delante y abajo)
const AGARRE_PUNTA: float = 0.10              ## cuánto asoma el plumín por delante del pellizco
const AGARRE_GIRO_GRADOS: float = 40.0        ## giro de la pluma sobre su propio eje


## Dónde va la pluma (su origen es el plumín) para que la tenga la `mano_agarre`, en el espacio de esa mano. Medido con el render lado/arriba, no calculado a ojo.
static func pluma_en_agarre() -> Transform3D:
	var ang: float = deg_to_rad(AGARRE_ANGULO_GRADOS)
	var d := Vector3(0.0, -sin(ang), cos(ang))        # hacia donde mira el plumín
	var u: Vector3 = -d                                # hacia donde sube la pluma
	var ex: Vector3 = Vector3(1.0, 0.0, 0.0).rotated(u, deg_to_rad(AGARRE_GIRO_GRADOS))
	var ez: Vector3 = ex.cross(u).normalized()
	ex = u.cross(ez).normalized()
	return Transform3D(Basis(ex, u, ez), d * AGARRE_PUNTA)
