class_name FlechaTrampa3D
extends Node3D

## FLECHA NORMAL DE LA TRAMPA DE FLECHAS (5/11/2026; `elemento=ninguno`): un palo que vuela recto desde la ranura del mascarón. No es un hechizo (no tiene elemento): hace lo que la flecha de un goblin
## (`Combate3D.DANO_FLECHA` a la jugadora por `recibir_dano`, con su invulnerabilidad) y a los enemigos les llega por `receive_damage`. Vuela a `VEL_U` u/s, recto y a la altura de la ranura, y se para en:
## una casilla sólida (muro, árbol, bloque empujable, torre de tierra), el volumen con solidez de un hechizo (una barrera, que aguanta el golpe), la burbuja de la jugadora (que revienta), la jugadora o un enemigo.
## Se libera sola al pararse o al llegar a su alcance (los nodos no se acumulan).

signal fin(causa: String)                  ## «muro» | «jugadora» | «enemigo» | «barrera» | «burbuja» | «alcance»

const VEL_U: float = 8.0                   ## u/s (la del goblin, 9, algo más lenta: el aviso del mascarón da tiempo)
const LARGO_U: float = 0.6
const RADIO_U: float = 0.6                 ## radio con el que acierta (horizontal)
const ALTO_ACIERTO_U: float = 1.7
const COLOR: Color = Color(0.62, 0.45, 0.25)

var dir: Vector3 = Vector3.RIGHT
var alcance_u: float = 18.4
var lanz: Lanzador3D = null
var dueno: Node = null
var recorrido: float = 0.0
var causa_fin: String = ""
var vivo: bool = true


## Dispara una flecha desde `origen` hacia `d`. Devuelve el nodo, colgado del padre de `dueno`.
static func disparar(dueno_: Node, origen: Vector3, d: Vector3, alcance: float, lanzador_: Lanzador3D) -> FlechaTrampa3D:
	var f := FlechaTrampa3D.new()
	f.name = "FlechaTrampa"
	f.dir = d.normalized()
	f.alcance_u = alcance
	f.lanz = lanzador_
	f.dueno = dueno_
	var padre: Node = dueno_.get_parent() if dueno_ != null and dueno_.get_parent() != null else dueno_
	padre.add_child(f)
	f.global_position = origen
	f.look_at(origen + f.dir, Vector3.UP)
	return f


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.05, 0.05, LARGO_U)
	mi.mesh = caja
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var punta := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.12, 0.12, 0.14)
	punta.mesh = pm
	punta.rotation.x = -PI * 0.5
	punta.position = Vector3(0.0, 0.0, -LARGO_U * 0.5 - 0.05)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.7, 0.72, 0.76)
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	punta.material_override = mp
	add_child(punta)


func _physics_process(delta: float) -> void:
	if not vivo:
		return
	var paso: float = VEL_U * delta
	var nuevo: Vector3 = global_position + dir * paso
	if lanz != null and is_instance_valid(lanz):
		if lanz.burbuja_contiene(nuevo):
			lanz.burbuja_recibe("", nuevo, null)
			_acabar("burbuja")
			return
		if lanz.solidez_para(nuevo, Combate3D.DANO_FLECHA):
			_acabar("barrera")
			return
	if Lanzador3D.celda_solida(Terreno3D.celda_de(nuevo), 0):
		_acabar("muro")
		return
	# La jugadora.
	var j: Node3D = lanz.jugador if lanz != null and is_instance_valid(lanz) else null
	if j != null and is_instance_valid(j) and not bool(j.get("muerto")):
		var d: Vector3 = nuevo - j.position
		if Vector2(d.x, d.z).length() <= RADIO_U and d.y >= -0.1 and d.y <= ALTO_ACIERTO_U:
			j.call("recibir_dano", Combate3D.DANO_FLECHA, global_position)
			_acabar("jugadora")
			return
	# Los enemigos.
	for g in get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		var c: Vector3 = (g as Node3D).global_position + Vector3(0.0, HechizoVivo.CENTRO_ENEMIGO_U, 0.0)
		var q: Vector3 = c - nuevo
		if Vector2(q.x, q.z).length() <= RADIO_U and absf(q.y) <= 1.0 and g.has_method("receive_damage"):
			g.call("receive_damage", Combate3D.DANO_FLECHA)
			_acabar("enemigo")
			return
	recorrido += paso
	global_position = nuevo
	if recorrido >= alcance_u:
		_acabar("alcance")


func _acabar(causa: String) -> void:
	vivo = false
	causa_fin = causa
	fin.emit(causa)
	queue_free()
