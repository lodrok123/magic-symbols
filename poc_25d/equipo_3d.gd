class_name Equipo3D
extends RefCounted

## ARMAS Y ESCUDOS de quita y pon para los personajes Mixamo (Pj3D): se cuelgan de un hueso de la mano
## con un BoneAttachment3D y siguen todas las animaciones.
##
## Mientras no haya modelos de Meshy (ver meshy/PROMPTS_EQUIPO.md), las piezas se hacen aquí con formas
## sencillas en la paleta pastel. Cuando lleguen, basta con dejar el GLB en poc_25d/equipo/<id>.glb:
## `pieza()` lo usa en lugar de la versión hecha por código.
##
## Medidas en unidades del modelo (el goblin chibi mide 1,7).

const CARPETA: String = "res://poc_25d/equipo/"

## Grimorio de la elfa: equipo/grimorio_<nivel>.glb (Meshy, horneados con meshy en el marco del de código).
## 1 botánico (marrón y verde) · 2 rúnico (azul y gris) · 3 legendario (rojo y oro). Cada uno trae su pluma.
const NIVELES_GRIMORIO: Array = ["", "botánico", "rúnico", "legendario"]
static var nivel_grimorio: int = 1

## Por personaje: [id de la pieza, hueso (final del nombre), posición, giro en grados] en el espacio del hueso.
## Los huesos de mano de Mixamo apuntan con +Y hacia los dedos.
const EQUIPO: Dictionary = {
	"goblin_warrior_chibi": [
		["garrote", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
	# Espadachín: el mismo goblin (Pj3D.MODELO_DE) con la espada de armas_goblin.glb en vez de la porra.
	"goblin_espadachin": [
		["espada_goblin", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
	# La elfa: el grimorio colgado a la espalda, a la altura de la cadera y centrado (con la pluma metida en el
	# lomo). Antes iba en la cadera izquierda; atrás se ve más desde la cámara y tapa el solape del vestido con
	# los brazos. En el espacio de Hips de Mixamo: +Y arriba, +Z delante, +X izquierda del personaje.
	"chibi_elf": [
		["grimorio", "Hips", Vector3(0.0, 0.06, -0.20), Vector3(6.0, 180.0, 0.0)],
	],
	"chibi_test": [
		["grimorio", "Hips", Vector3(0.36, 0.02, -0.06), Vector3(0.0, 90.0, -8.0)],
	],
	"goblin_warrior": [
		["garrote", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
}

const MADERA: Color = Color(0.62, 0.42, 0.26)
const MADERA_CLARA: Color = Color(0.78, 0.58, 0.36)
const HIERRO: Color = Color(0.62, 0.64, 0.70)
const CUERDA: Color = Color(0.85, 0.76, 0.56)
const TAPA: Color = Color(0.22, 0.47, 0.47)        ## verde azulado, como el vestido de la elfa
const ORO: Color = Color(0.86, 0.70, 0.40)
const PAPEL: Color = Color(0.96, 0.92, 0.83)
const CUERO: Color = Color(0.45, 0.30, 0.20)


## Cuelga del esqueleto de `modelo` las piezas que tenga `id` en EQUIPO. Devuelve las piezas puestas.
static func equipar(id: String, modelo: Node3D) -> Array[Node3D]:
	var puestas: Array[Node3D] = []
	if not EQUIPO.has(id):
		return puestas
	var sks: Array[Node] = modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return puestas
	var sk: Skeleton3D = sks[0] as Skeleton3D
	# Escala del esqueleto respecto al modelo (para que las piezas midan lo mismo en cualquier rig).
	var escala: float = 1.0
	var n: Node = sk
	while n != null and n != modelo:
		if n is Node3D:
			escala *= (n as Node3D).scale.y
		n = n.get_parent()
	for e in EQUIPO[id]:
		var datos: Array = e
		var hueso: int = _hueso(sk, String(datos[1]))
		if hueso < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = sk.get_bone_name(hueso)
		sk.add_child(at)
		var p: Node3D = pieza(String(datos[0]))
		p.position = (datos[2] as Vector3) / maxf(escala, 0.0001)
		p.rotation_degrees = datos[3] as Vector3
		p.scale = Vector3.ONE / maxf(escala, 0.0001)
		at.add_child(p)
		puestas.append(p)
	return puestas


static func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var nombre: String = sk.get_bone_name(i)
		if nombre == fin or nombre.ends_with(":" + fin) or nombre.ends_with("_" + fin):
			return i
	return -1


## La pieza `id`, por este orden:
##   1. poc_25d/equipo/<id>.glb, si existe (ya orientado: mango en el origen hacia +Y; escudo con la cara a +Y).
##      garrote.glb, escudo.glb y daga.glb salen de armas_goblin.glb con el mismo giro y medida que _orientar,
##      horneados en la malla y con la textura a 1024 (las armas se ven pequeñas).
##   2. la pieza <id> de una biblioteca de equipo (armas_goblin.glb), que se orienta y escala aquí (MEDIDA_PIEZA)
##   3. la versión sencilla hecha por código
static func pieza(id: String) -> Node3D:
	if id == "grimorio" and ResourceLoader.exists(CARPETA + "grimorio_%d.glb" % nivel_grimorio):
		var g: Node3D = (load(CARPETA + "grimorio_%d.glb" % nivel_grimorio) as PackedScene).instantiate() as Node3D
		g.name = "grimorio"
		return g
	var ruta: String = CARPETA + id + ".glb"
	if ResourceLoader.exists(ruta):
		var ps: PackedScene = load(ruta) as PackedScene
		if ps != null:
			return ps.instantiate() as Node3D
	var de_biblioteca: Node3D = _de_biblioteca(id)
	if de_biblioteca != null:
		return de_biblioteca
	match id:
		"garrote":
			return _garrote()
		"escudo":
			return _escudo()
		"grimorio":
			return _grimorio()
		"pluma":
			return _pluma()
	return Node3D.new()


## Bibliotecas de equipo (un GLB con una pieza por nodo, separadas con meshy/agrupar_3d.py).
const BIBLIOTECAS_EQUIPO: Array = ["res://poc_25d/equipo/armas_goblin.glb"]
## Medida de cada pieza de biblioteca, en unidades del goblin (mide 1,7): largo de las armas, diámetro del escudo.
const MEDIDA_PIEZA: Dictionary = {"garrote": 0.62, "espada_goblin": 0.58, "daga": 0.5, "escudo": 0.5}
## Dónde se agarra un arma, en fracción de su largo desde abajo.
const AGARRE: float = 0.14

static func _de_biblioteca(id: String) -> Node3D:
	for r in BIBLIOTECAS_EQUIPO:
		if not ResourceLoader.exists(String(r)):
			continue
		var lib: Node = (load(String(r)) as PackedScene).instantiate()
		var n: Node = lib.find_child(id, true, false)
		var res: Node3D = null
		if n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			res = _orientar(copia, id)
		lib.free()
		if res != null:
			return res
	return null


## Meshy las deja de pie y de frente: armas con la hoja/cabeza hacia +Y y escudo con la cara hacia +Z.
## Aquí: armas con el agarre en el origen; escudo centrado y con la cara hacia +Y (como las de código).
static func _orientar(modelo: Node3D, id: String) -> Node3D:
	var caja: AABB = _caja_de(modelo, Transform3D.IDENTITY)
	var raiz := Node3D.new()
	raiz.name = id
	var giro := Node3D.new()
	raiz.add_child(giro)
	giro.add_child(modelo)
	var medida: float = float(MEDIDA_PIEZA.get(id, 0.5))
	if id == "escudo":
		var f: float = medida / maxf(caja.size.x, caja.size.y)
		modelo.scale = Vector3.ONE * f
		modelo.position = -caja.get_center() * f
		giro.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	else:
		var f2: float = medida / maxf(caja.size.y, 0.0001)
		modelo.scale = Vector3.ONE * f2
		var agarre := Vector3(caja.get_center().x, caja.position.y + caja.size.y * AGARRE, caja.get_center().z)
		modelo.position = -agarre * f2
	return raiz


static func _caja_de(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja_de(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Garrote de madera con dos tachuelas y una venda de cuerda en el mango. Mango en el origen, a lo largo de +Y.
static func _garrote() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "garrote"
	_parte(raiz, _cilindro(0.022, 0.028, 0.26), MADERA, Vector3(0.0, 0.0, 0.0))
	_parte(raiz, _cilindro(0.032, 0.032, 0.06), CUERDA, Vector3(0.0, -0.02, 0.0))
	_parte(raiz, _cilindro(0.07, 0.04, 0.26), MADERA_CLARA, Vector3(0.0, 0.24, 0.0))
	_parte(raiz, _esfera(0.07), MADERA_CLARA, Vector3(0.0, 0.37, 0.0))
	for i in range(3):
		var ang: float = float(i) / 3.0 * TAU
		var cono := _parte(raiz, _cilindro(0.0, 0.022, 0.06), HIERRO,
			Vector3(cos(ang) * 0.07, 0.29 + float(i) * 0.03, sin(ang) * 0.07))
		cono.rotation = Vector3(sin(ang) * PI * 0.5, 0.0, -cos(ang) * PI * 0.5)
	return raiz


## Escudo redondo de tablas con aro de hierro y bollón. La cara mira a +Y; la correa, en el origen.
static func _escudo() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "escudo"
	_parte(raiz, _cilindro(0.2, 0.2, 0.035), MADERA, Vector3(0.0, 0.0, 0.0))
	for i in range(3):
		var tabla := _parte(raiz, _caja(Vector3(0.012, 0.004, 0.36)), MADERA_CLARA.darkened(0.15),
			Vector3(-0.1 + float(i) * 0.1, 0.019, 0.0))
		tabla.scale = Vector3(1.0, 1.0, 1.0 - absf(float(i) - 1.0) * 0.18)
	var aro := TorusMesh.new()
	aro.inner_radius = 0.185
	aro.outer_radius = 0.215
	aro.rings = 24
	aro.ring_segments = 8
	_parte(raiz, aro, HIERRO, Vector3(0.0, 0.0, 0.0))
	_parte(raiz, _esfera(0.05), HIERRO, Vector3(0.0, 0.02, 0.0)).scale = Vector3(1.0, 0.6, 1.0)
	return raiz


## Grimorio cerrado, de pie (alto +Y, lomo hacia -X, tapa hacia +Z): tapas verde azulado con esquinas y
## medallón de hoja dorados, el canto de papel, una correa de cuero y la pluma metida junto al lomo.
static func _grimorio() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "grimorio"
	var alto: float = 0.30
	var ancho: float = 0.22
	var grueso: float = 0.08
	_parte(raiz, _caja(Vector3(ancho - 0.012, alto - 0.014, grueso - 0.012)), PAPEL, Vector3(0.006, 0.0, 0.0))
	for z: float in [-1.0, 1.0]:
		_parte(raiz, _caja(Vector3(ancho, alto, 0.008)), TAPA, Vector3(0.0, 0.0, z * (grueso * 0.5 - 0.004)))
		_parte(raiz, _esfera(0.026), ORO, Vector3(0.008, 0.0, z * grueso * 0.5)).scale = Vector3(1.0, 1.0, 0.25)
		for e: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			_parte(raiz, _caja(Vector3(0.024, 0.024, 0.01)), ORO,
				Vector3(e.x * (ancho * 0.5 - 0.012), e.y * (alto * 0.5 - 0.012), z * (grueso * 0.5 - 0.002)))
	_parte(raiz, _caja(Vector3(0.012, alto, grueso)), TAPA.darkened(0.2), Vector3(-ancho * 0.5, 0.0, 0.0))
	_parte(raiz, _caja(Vector3(0.022, 0.03, grueso + 0.006)), CUERO, Vector3(ancho * 0.5 - 0.004, 0.0, 0.0))
	var p := _pluma()
	p.position = Vector3(-ancho * 0.5 + 0.01, alto * 0.35, 0.0)
	p.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	raiz.add_child(p)
	return raiz


## Pluma de escribir: cañón dorado y pluma crema con la punta verde azulada. Base en el origen, hacia +Y.
static func _pluma() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "pluma"
	_parte(raiz, _cilindro(0.004, 0.002, 0.05), ORO, Vector3(0.0, 0.025, 0.0))
	var aleta := _parte(raiz, _esfera(0.03), PAPEL, Vector3(0.0, 0.11, 0.0))
	aleta.scale = Vector3(0.75, 2.4, 0.12)
	var punta := _parte(raiz, _esfera(0.018), TAPA, Vector3(0.0, 0.17, 0.0))
	punta.scale = Vector3(0.8, 1.6, 0.12)
	return raiz


static func _parte(padre: Node3D, malla: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic_specular = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	return mi


static func _cilindro(arriba: float, abajo: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = arriba
	c.bottom_radius = abajo
	c.height = alto
	c.radial_segments = 10
	c.rings = 1
	return c


static func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


static func _caja(t: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	return b
