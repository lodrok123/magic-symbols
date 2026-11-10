extends RefCounted

## LAB del CAMPO DE VIENTO y de la NUBE DE VENENO como gas pesado (11/11/2026). Va aparte para que lab_vfx_comparativa_3d.gd solo lleve dos teclas y una línea del panel.
## Teclas (integración 11/11: «,» y «.» se quedaron para las chispas de ChispasRepo, así que esto va en Inicio / Fin):
##   Inicio    alterna CampoViento.en_viento_toy (hojas, jirones y cintas del VientoToy siguen el campo) y pone/quita dos obstáculos delante: un «goblin» (cápsula) y un bloque.
##             Para verlo: Z hasta VIENTO, F7 hasta HAZ (o PILAR / MURO) e Inicio: las cintas tiemblan con la turbulencia y rodean la cápsula y el bloque en vez de atravesarlos.
##   Fin       nube de veneno, paso a paso: 1) nube permanente con un bloque y una cápsula dentro de su radio (gas pesado y humo al arder encendidos) · 2) soplo de viento (se deshilacha)
##             · 3) fuego (humo pardo de HumoRegla) · 4) la quita.
##   Mayús+Fin alterna el gas pesado (y el humo al arder) para comparar con la nube de siempre.

const PIEDRA: Color = Color(0.56, 0.52, 0.47)        ## el gris de la pared de impacto del lab
const VERDE_GOBLIN: Color = Color(0.45, 0.62, 0.36)

static var _paso: int = 0
static var _nube: NubeVeneno3D = null


static func alternar_campo(lab: Node3D, pie: Vector3, dir: Vector3) -> void:
	CampoViento.en_viento_toy = not CampoViento.en_viento_toy
	var viejo: Node = lab.get_node_or_null("ObstaculosViento")
	if viejo != null:
		viejo.queue_free()
	if not CampoViento.en_viento_toy:
		return
	var raiz: Node3D = Node3D.new()
	raiz.name = "ObstaculosViento"
	lab.add_child(raiz)
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var lado: Vector3 = Vector3.UP.cross(d).normalized()
	capsula(raiz, Vector3(pie.x, 0.0, pie.z) + d * 1.9 + lado * 0.15, 0.38, 1.3)
	bloque(raiz, Vector3(pie.x, 0.0, pie.z) + d * 3.1 - lado * 0.55, Vector3(0.7, 0.9, 0.7))


static func paso_veneno(efectos: Node3D, pie: Vector3, dir: Vector3, mayus: bool) -> void:
	if mayus:
		NubeVenenoVfx.gas_pesado = not NubeVenenoVfx.gas_pesado
		NubeVenenoVfx.humo_al_arder = NubeVenenoVfx.gas_pesado
		return
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var lado: Vector3 = Vector3.UP.cross(d).normalized()
	var viva: bool = _nube != null and is_instance_valid(_nube) and NubeVeneno3D.vivas.has(_nube)
	if not viva and _paso != 0:
		_paso = 0
	match _paso:
		0:
			NubeVenenoVfx.gas_pesado = true
			NubeVenenoVfx.humo_al_arder = true
			var c: Vector3 = Vector3(pie.x, 0.0, pie.z) + d * 3.4
			var viejo: Node = efectos.get_node_or_null("ObstaculosVeneno")
			if viejo != null:
				viejo.queue_free()
			var raiz: Node3D = Node3D.new()
			raiz.name = "ObstaculosVeneno"
			efectos.add_child(raiz)
			var r: float = Terreno3D.casilla
			bloque(raiz, c + lado * r * 0.75, Vector3(0.8, 0.8, 0.8))
			capsula(raiz, c - lado * r * 0.55 - d * 0.3, 0.38, 1.3)
			_nube = NubeVeneno3D.crear(efectos, c, 0.0, 1.0)
		1:
			_nube.soplar(lado)
		2:
			_nube.quemar(4.0)
		_:
			_nube.retirar()
			var o: Node = efectos.get_node_or_null("ObstaculosVeneno")
			if o != null:
				o.queue_free()
	_paso = (_paso + 1) % 4


static func texto() -> String:
	return "\nInicio campo de viento del VientoToy (con obstáculos): %s · Fin nube de veneno paso a paso (nube > soplo > fuego > quitar) · Mayús+Fin gas pesado: %s" % [
		"SÍ" if CampoViento.en_viento_toy else "no", "SÍ" if NubeVenenoVfx.gas_pesado else "no"]


## Una cápsula de pie (como la de un goblin) que el campo lee como sólido (grupo solido_viento).
static func capsula(padre: Node3D, pie: Vector3, radio: float, alto: float) -> StaticBody3D:
	var cuerpo: StaticBody3D = _cuerpo(padre, "Capsula", pie + Vector3(0, alto * 0.5, 0))
	var forma: CapsuleShape3D = CapsuleShape3D.new()
	forma.radius = radio
	forma.height = alto
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	var malla: CapsuleMesh = CapsuleMesh.new()
	malla.radius = radio
	malla.height = alto
	cuerpo.add_child(_malla(malla, VERDE_GOBLIN))
	return cuerpo


## Un bloque (caja) apoyado en el suelo.
static func bloque(padre: Node3D, pie: Vector3, tam: Vector3) -> StaticBody3D:
	var cuerpo: StaticBody3D = _cuerpo(padre, "Bloque", pie + Vector3(0, tam.y * 0.5, 0))
	var forma: BoxShape3D = BoxShape3D.new()
	forma.size = tam
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	var malla: BoxMesh = BoxMesh.new()
	malla.size = tam
	cuerpo.add_child(_malla(malla, PIEDRA))
	return cuerpo


static func _cuerpo(padre: Node3D, nombre: String, pos: Vector3) -> StaticBody3D:
	var cuerpo: StaticBody3D = StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.collision_layer = 0
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("solido_viento")
	padre.add_child(cuerpo)
	cuerpo.global_position = pos
	return cuerpo


static func _malla(m: Mesh, col: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	var mt: StandardMaterial3D = StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 0.95
	mi.material_override = mt
	return mi
