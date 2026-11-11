extends RefCounted

## LAB del CAMPO DE VIENTO y de la NUBE DE VENENO como gas pesado (11/11/2026). Va aparte para que lab_vfx_comparativa_3d.gd solo lleve dos teclas y una línea del panel.
## Teclas (integración 11/11: «,» y «.» se quedaron para las chispas de ChispasRepo, así que esto va en Inicio / Fin):
##   Inicio    alterna CampoViento.en_viento_toy (hojas, jirones y cintas del VientoToy siguen el campo) y pone/quita dos obstáculos delante: un «goblin» (cápsula) y un bloque.
##             Para verlo: Z hasta VIENTO, F7 hasta HAZ (o PILAR / MURO) e Inicio: las cintas se abren alrededor de la cápsula y el bloque y se cierran detrás, y las hojas giran con la turbulencia.
##             Los obstáculos se colocan por la figura VIVA (posiciones_obstaculos): si cambias de figura con el campo puesto, Inicio dos veces los recoloca.
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
	for p in posiciones_obstaculos(lab.get("_param"), pie, d):
		if (p as Array)[0] == "capsula":
			capsula(raiz, (p as Array)[1], 0.38, 1.3)
		else:
			bloque(raiz, (p as Array)[1], Vector3(0.7, 0.9, 0.7))


## Dónde van la cápsula y el bloque (pies en el suelo): [["capsula", pie], ["bloque", pie]]. 11/11 («no veo diferencia en viento»): antes iban a 1,9 y 3,1 m de la JUGADORA
## fuera cual fuera la figura, así que con el PILAR y el MURO (a 3 m) la cápsula quedaba 1,1 m por delante, fuera de las cintas, tapándolas desde la cámara, y el bloque dentro de la
## cortina o del torbellino; y en el HAZ el bloque caía junto a la punta, donde el haz mide 6 cm, y la cápsula de lleno delante del eje, tapando el rodeo. Ahora van por la figura viva:
##   HAZ    cápsula al 34 % del largo, casi en el eje (las cintas se abren a los dos lados y se cierran detrás) · bloque al 76 %, a un lado (el haz ya cerrado lo rodea por fuera y por encima).
##   PILAR  cápsula y bloque a los lados del torbellino, a ~0,6 m del eje: su cara entra en el anillo de las cintas bajas (0,3–0,45 m de radio).
##   MURO   cápsula y bloque sobre la línea de la cortina, a un lado y a otro del centro.
## Sin figura viva, lo de antes (por la jugadora).
static func posiciones_obstaculos(fig: Variant, pie: Vector3, d: Vector3) -> Array:
	var lado: Vector3 = Vector3.UP.cross(d).normalized()
	var base: Vector3 = Vector3(pie.x, 0.0, pie.z)
	if fig is VientoToy and is_instance_valid(fig) and (fig as Node3D).is_inside_tree():
		var vt: VientoToy = fig
		var o: Vector3 = vt.global_position
		o.y = 0.0
		var fd: Vector3 = -vt.global_basis.z
		fd = Vector3(fd.x, 0.0, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 0.01 else d
		var fl: Vector3 = Vector3.UP.cross(fd).normalized()
		match vt.figura:
			VientoToy.Figura.HAZ:
				var largo: float = vt.semieje_x * 2.0
				return [["capsula", o + fd * largo * 0.34 + fl * 0.08], ["bloque", o + fd * largo * 0.76 - fl * 0.3]]
			VientoToy.Figura.PILAR:
				var r: float = maxf(vt.semieje_x, 0.3) * 1.2
				return [["capsula", o + fl * r], ["bloque", o - fl * (r + 0.05) - fd * 0.15]]
			VientoToy.Figura.MURO:
				var ancho: float = vt.semieje_x
				return [["capsula", o + fl * ancho * 0.3 - fd * 0.25], ["bloque", o - fl * ancho * 0.5 - fd * 0.25]]     # un poco hacia la jugadora: la cortina se inclina hacia ella al subir
	return [["capsula", base + d * 1.9 + lado * 0.15], ["bloque", base + d * 3.1 - lado * 0.55]]


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
