class_name NubeVeneno3D
extends Area3D

## LA NUBE DE VENENO (F4 de docs/PLAN_BASE_DATOS.md §6, 29/10, Juego): el estado `veneno` del mundo, el único DINÁMICO que nace de un hechizo ENEMIGO. Una nube tiene VIDA propia: nace, dura y se
## dispersa. Los números (daño, cuánto sigue envenenando, cuánto tarda el viento, cuánto el fuego, el radio del fuego) viven en la fila `veneno` de `estados_mundo.tsv`.
##
## DE DÓNDE NACE: de la bola del chamán al estallar (`BolaVeneno3D._caer`, 3 s), de la colmena quemada (`Colmena3D.arder`, 3 s) y de la pieza `; pieza <id> nube_veneno x y [vida=s] [radio=casillas]`
## de Puzle3D (`vida=0` = permanente hasta que el viento o el fuego la quiten). `NubeVeneno3D.crear(en, pos, vida, radio)`.
## QUÉ HACE: a quien entra (la jugadora si no `protegida("veneno")`; un enemigo si no `inmune_a("veneno")`: los goblins sí, el limo, el chamán y el gólem no) lo envenena con `dano_s` por segundo durante
## `sigue_s` s más (el `envenenar` que ya había). Se comprueba en horizontal (radio en CASILLAS) y con una altura parecida.
## EL VIENTO la empuja en su dirección durante `T_SOPLO` s y la dispersa: su vida baja a `dispersa_s` como mucho (`on_spell_hit` de viento y `push`). EL FUEGO la consume: su vida baja a `consume_s`;
## y cualquier casilla que PRENDA a ≤ `consume_casillas` de ella también (`EstadoZona3D._al_cambiar_suelo` → `quemar_en`). Es un reactivo de hechizos más (capa `Lanzador3D.CAPA_REACTIVO`).
## SE REGISTRA en `vivas` al entrar en el árbol: `EstadoZona3D.estados_en` dice que una casilla bajo una nube tiene `veneno`, y `a_dic` / `desde_dic` la guardan y la recrean.

signal disipada
signal envenenado_a(quien: Node)

const VIDA_DEFECTO: float = 6.0
const RADIO_DEFECTO: float = 1.0               ## casillas
const DERIVA: float = 1.4                      ## u/s a los que el viento la mueve mientras sopla
const T_SOPLO: float = 1.2                     ## s que sigue a la deriva tras un soplo
const ALTO_VERTICAL: float = 1.6               ## u de diferencia en altura a los que aún está «dentro»
const COLOR: Color = Color(0.45, 0.75, 0.25, 0.35)

## Las nubes vivas (en el árbol). Estático: lo lee `EstadoZona3D` sin conocerlas una a una.
static var vivas: Array = []

var vida: float = VIDA_DEFECTO                 ## s que le quedan (ignorado mientras `permanente`)
var vida_max: float = VIDA_DEFECTO
var radio: float = RADIO_DEFECTO               ## casillas
var permanente: bool = false
var ardiendo: bool = false
var deriva: Vector3 = Vector3.ZERO
var jugador: Jugador3D = null                  ## null = la del lanzador del nivel (`Botin.jugador_de`)
var envenenadas: int = 0                       ## veces que envenenó a la jugadora (las pruebas)
var envenenados: int = 0                       ## veces que envenenó a un enemigo
var _soplo: float = 0.0
var _malla: MeshInstance3D = null
var _muerta: bool = false


## Crea una nube en `pos` (mundo) colgada de `en`. `p_vida` <= 0 = permanente. `p_radio` en casillas.
static func crear(en: Node, pos: Vector3, p_vida: float = VIDA_DEFECTO, p_radio: float = RADIO_DEFECTO, p_jugador: Jugador3D = null) -> NubeVeneno3D:
	var n := NubeVeneno3D.new()
	n.name = "NubeVeneno"
	n.permanente = p_vida <= 0.0
	n.vida = p_vida if p_vida > 0.0 else 60.0
	n.vida_max = n.vida
	n.radio = maxf(p_radio, 0.05)
	n.jugador = p_jugador
	en.add_child(n)
	if n.is_inside_tree():
		n.global_position = pos
	else:
		n.position = pos
	return n


func _enter_tree() -> void:
	if not NubeVeneno3D.vivas.has(self):
		NubeVeneno3D.vivas.append(self)


func _exit_tree() -> void:
	NubeVeneno3D.vivas.erase(self)


func _ready() -> void:
	add_to_group("nube_veneno")
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio * Terreno3D.casilla
	forma.shape = esfera
	forma.position = Vector3(0.0, 0.8, 0.0)
	add_child(forma)
	_malla = MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = radio * Terreno3D.casilla
	es.height = es.radius * 1.4
	es.radial_segments = 16
	es.rings = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	es.material = m
	_malla.mesh = es
	_malla.position = Vector3(0.0, 0.7, 0.0)
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)


func _process(delta: float) -> void:
	avanzar(delta)


## Un paso del reloj: deriva si sopla el viento, pierde vida, envenena a quien esté dentro y se desvanece al acabarse. Público para que las pruebas la lleven a mano.
func avanzar(dt: float) -> void:
	if _muerta:
		return
	if _soplo > 0.0:
		var t: float = minf(dt, _soplo)
		_soplo -= dt
		var p: Vector3 = _pos()
		_poner_pos(p + deriva * t)
	if not permanente:
		vida -= dt
		if vida <= 0.0:
			retirar()
			return
	_envenenar_dentro()
	if _malla != null:
		var a: float = 1.0 if permanente else clampf(vida / maxf(vida_max, 0.01), 0.0, 1.0)
		((_malla.mesh as SphereMesh).material as StandardMaterial3D).albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, COLOR.a * (0.4 + 0.6 * a))


func _pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _poner_pos(p: Vector3) -> void:
	if is_inside_tree():
		global_position = p
	else:
		position = p


## Envenena a la jugadora y a los enemigos que están dentro (cada fotograma: `envenenar` se queda con el mayor, no se acumula).
func _envenenar_dentro() -> void:
	var fila: Dictionary = BD.estado_mundo("veneno")
	var dps: float = float(fila.get("dano_s", 2))
	var sigue: float = float(fila.get("sigue_s", 3))
	var j: Jugador3D = jugador if jugador != null and is_instance_valid(jugador) else Botin.jugador_de(self)
	if j != null and not j.muerto and dentro(j.position) and not j.protegida("veneno"):
		j.envenenar(dps, sigue)
		envenenadas += 1
		envenenado_a.emit(j)
	if not is_inside_tree():
		return
	for g in get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(g) or bool(g.get("muerto")) or not dentro((g as Node3D).position):
			continue
		if g.has_method("inmune_a") and bool(g.call("inmune_a", "veneno")):
			continue
		if g.has_method("envenenar") and bool(g.call("envenenar", dps, sigue)):
			envenenados += 1
			envenenado_a.emit(g)


## ¿Está el punto `p` (mundo) dentro de la nube? Horizontal a ≤ radio casillas y a una altura parecida.
func dentro(p: Vector3) -> bool:
	var c: Vector3 = _pos()
	return Vector2(p.x - c.x, p.z - c.z).length() <= radio * Terreno3D.casilla and absf(p.y - c.y) <= ALTO_VERTICAL


## ¿Cubre la casilla `celda`? (el punto de la casilla más cercano al centro de la nube está dentro de su radio.)
func cubre_celda(celda: Vector2i) -> bool:
	var c: Vector3 = _pos()
	var lado: float = Terreno3D.casilla
	var x0: float = float(celda.x) * lado
	var z0: float = float(celda.y) * lado
	var cx: float = clampf(c.x, x0, x0 + lado)
	var cz: float = clampf(c.z, z0, z0 + lado)
	return Vector2(c.x - cx, c.z - cz).length() <= radio * Terreno3D.casilla


## ¿Hay alguna nube viva sobre `celda`?
static func cubre(celda: Vector2i) -> bool:
	for n in vivas:
		if is_instance_valid(n) and not (n as NubeVeneno3D)._muerta and (n as NubeVeneno3D).cubre_celda(celda):
			return true
	return false


## --- El viento y el fuego ---

## Un soplo: la mueve en `dir` (plano XZ) durante `T_SOPLO` s y la dispersa (su vida baja a `dispersa_s` como mucho).
func soplar(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01 or _muerta:
		return
	deriva = d.normalized() * DERIVA
	_soplo = T_SOPLO
	var disp: float = float(BD.estado_mundo("veneno").get("dispersa_s", 8))
	permanente = false
	vida = minf(vida, disp)


## El fuego la consume: su vida baja a `segundos` como mucho y arde (la presentación puede teñirla).
func quemar(segundos: float) -> void:
	if _muerta:
		return
	ardiendo = true
	permanente = false
	vida = minf(vida, segundos)


## Las nubes a ≤ `casillas` casillas de `punto` arden y se consumen en `segundos`. Devuelve cuántas. Lo llama el suelo al prenderse (`EstadoZona3D`).
static func quemar_en(punto: Vector3, casillas: float, segundos: float) -> int:
	var n: int = 0
	for v in vivas.duplicate():
		if not is_instance_valid(v):
			continue
		var nube: NubeVeneno3D = v
		var c: Vector3 = nube._pos()
		if Vector2(c.x - punto.x, c.z - punto.z).length() <= casillas * Terreno3D.casilla + nube.radio * Terreno3D.casilla:
			nube.quemar(segundos)
			n += 1
	return n


# --- Contrato con los hechizos (duck typing, como Colmena3D) ---

func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO) -> void:
	match Objetos.elemento_de(rune_data):
		"viento":
			soplar(direccion)
		"fuego":
			var fila: Dictionary = BD.estado_mundo("veneno")
			quemar_en(_pos(), float(fila.get("consume_casillas", 1.5)), float(fila.get("consume_s", 4)))


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	var e: String = Objetos.elemento_de(rune_data)
	return not _muerta and (e == "viento" or e == "fuego")


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## El contrato `push` (el viento del Lanzador empuja a quien lo implemente): lo mismo que un soplo.
func push(direccion: Vector3, _fuerza: float, _suelo: bool = false) -> void:
	soplar(direccion)


# --- Fin y guardado ---

func retirar() -> void:
	if _muerta:
		return
	_muerta = true
	NubeVeneno3D.vivas.erase(self)
	disipada.emit()
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()


func a_dic() -> Dictionary:
	var p: Vector3 = _pos()
	return {"pos": [p.x, p.y, p.z], "vida": vida, "vida_max": vida_max, "radio": radio, "permanente": permanente, "ardiendo": ardiendo}


static func desde_dic(en: Node, d: Dictionary) -> NubeVeneno3D:
	var pv: Variant = d.get("pos", [])
	if not (pv is Array) or (pv as Array).size() < 3:
		return null                                  # una nube mal guardada no se recrea
	var pos: Array = pv
	var n: NubeVeneno3D = crear(en, Vector3(float(pos[0]), float(pos[1]), float(pos[2])), maxf(float(d.get("vida", VIDA_DEFECTO)), 0.1), float(d.get("radio", RADIO_DEFECTO)))
	n.vida_max = float(d.get("vida_max", n.vida))
	n.permanente = bool(d.get("permanente", false))
	n.ardiendo = bool(d.get("ardiendo", false))
	return n
