extends Node3D

const MEDIA_ALTURA := 0.32
const ENTRADA := Vector2i(0, 1)
const SALIDA := Vector2i(0, 2)
const VECINO := Vector2i(-1, -1)
const COFRE := Vector2i(1, 1)
const MESA := Vector2i(1, -1)
const RADIO_MURO := 2.2

@export var centro := Vector2i.ZERO
@export var tienda := false
@export var casa_brais := false
@export var gremio := false

var entrada := ENTRADA
var salida := SALIDA
var torre := false
@onready var camara: Camera3D = $Camara
var _montada := false
@onready var _tapa := get_node_or_null("Cofre/Tapa") as Node3D
var _tapa_cerrada: Transform3D


func montar() -> void:
	if _montada:
		return
	_montada = true
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	_registrar_suelo()
	if _tapa != null:
		_tapa_cerrada = _tapa.transform
	_montar_colisiones(self)
	_ajustar_camara()


func _registrar_suelo() -> void:
	# El gremio está fuera del suelo horneado. Todas las salas conservan el desnivel del Ástrago.
	for z in range(-2, 3):
		for x in range(-2, 3):
			var c := centro + Vector2i(x, z)
			if Terreno3D.letra_de(c).strip_edges().is_empty():
				Terreno3D.poner_letra(c, "g")
				Terreno3D.liberar_celda(c)
			if z < 0:
				Terreno3D.realces_terreno[c] = MEDIA_ALTURA


func _ajustar_camara() -> void:
	camara.look_at(global_position + Vector3.UP * 0.35)
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


## Las mallas editables se miden en su posición final. Las cajas que acompañan a sus grupos ya vienen en la escena.
func _montar_colisiones(sala: Node3D) -> void:
	for n in sala.find_children("*", "Node3D", true, false):
		if n.has_meta("colision_malla") or n.is_in_group("solido_interior"):
			_solido_de(n, sala)


func _solido_de(n: Node3D, sala: Node3D) -> void:
	# La forma se mide con la escala y orientación completas del mueble, incluidas las de sus padres.
	var marco := Transform3D(n.global_basis, Vector3.ZERO)
	var tris := PackedVector3Array()
	if n is MeshInstance3D and n.mesh != null and n.visible:
		for v in n.mesh.get_faces():
			tris.append(marco * v)
	for h in n.get_children():
		tris.append_array(ColisionPieza._triangulos(h, marco))
	var lista := ColisionPieza.cascos_triangulos(tris, "contorno")
	if lista.is_empty():
		return
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Solido" + String(n.get_meta("colision_malla", n.name))
	cuerpo.collision_layer = Terreno3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	sala.add_child(cuerpo, true)
	cuerpo.global_transform = Transform3D(Basis.IDENTITY, n.global_position)
	for nube in lista:
		var cs := CollisionShape3D.new()
		var forma := ConvexPolygonShape3D.new()
		forma.points = nube
		cs.shape = forma
		cuerpo.add_child(cs)


func _encuadrar() -> void:
	var ventana := get_viewport().get_visible_rect().size
	var aspecto := ventana.x / maxf(ventana.y, 1.0)
	# En la referencia los cinco módulos ocupan el ancho y el suelo entre muros, tres quintos.
	var ancho_palloza := Terreno3D.casilla * 5.0
	# En panorámico se puede recortar el exterior, con margen vertical para la salida.
	var alto_minimo := Terreno3D.casilla * 3.85
	camara.size = maxf(ancho_palloza / maxf(aspecto, 0.01), alto_minimo)


func contiene(c: Vector2i) -> bool:
	return Rect2i(centro - Vector2i(2, 2), Vector2i(5, 5)).has_point(c)


func mostrar_cofre(abierto: bool) -> void:
	if _tapa == null:
		return
	_tapa.transform = _tapa_cerrada
	if abierto:
		if not _tapa.get_meta("tiene_bisagra", false):
			_tapa.position += Vector3(0, 0.21, -0.27)
		_tapa.rotate_object_local(Vector3.RIGHT, -1.15)
