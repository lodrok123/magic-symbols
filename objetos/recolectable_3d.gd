class_name Recolectable3D
extends Area3D

## RECOLECTABLE (la Cueva, 23/10; docs/PLAN_BOSQUE_EOW.md §6). Una planta del suelo (hoy, las setas de la cueva) que se COGE con `E` estando
## cerca y da un INGREDIENTE a la mochila (`Estado.agregar`). Antes de cogerla se le puede lanzar un elemento: se transforma en el ingrediente
## de `Objetos.PLANTAS` (fuego → seta asada, rayo → seta electrificada, hielo → helada, agua → empapada, viento → esporas), cambia de color y
## ya no vuelve a cambiar. Así el ingrediente que se lleva depende del hechizo que se le lanzó: el recolectable habla el idioma del juego.
##
## El aspecto es una pieza del decorado (`setas_rojas`, `setas_azules`, `setas_marrones`): se INTERCALAN por casilla si no se dice cuál, para
## que un corro de setas no sea el mismo modelo repetido. No bloquea el paso.
##
## `rebrota` > 0: a los `rebrota` s vuelve a salir, otra vez sin transformar. 0 = se coge una vez.
## Se coloca desde un mapa con `; pieza <id> seta <x> <y> [variante=roja|azul|marron] [rebrota=<s>]` (escenas/puzle.gd).

signal recogido(objeto: String)

const ALCANCE: float = 2.0              ## u: a cuánto hay que estar para cogerla con E (la jugadora mide ~1)
const VARIANTES: Dictionary = {"roja": "setas_rojas", "azul": "setas_azules", "marron": "setas_marrones"}
const ORDEN_VARIANTES: Array = ["roja", "azul", "marron"]

var celda: Vector2i = Vector2i.ZERO
var planta: String = "seta"             ## fila de `Objetos.PLANTAS`
var objeto: String = "seta"             ## lo que da al cogerla (cambia si se le lanza un elemento)
var variante: String = ""
var rebrota: float = 0.0
var recogido_ya: bool = false
var _mundo: Node = null
var _visual: Node3D = null
var _t: float = 0.0


## `p_variante` vacío = la que toque por casilla (intercaladas). `mundo` = la maqueta (pone el modelo con su escala de `Pieza3D.MEDIDA`).
func preparar(p_celda: Vector2i, p_variante: String = "", p_rebrota: float = 0.0, mundo: Node = null, p_planta: String = "seta") -> void:
	celda = p_celda
	planta = p_planta
	objeto = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	variante = p_variante if VARIANTES.has(p_variante) else String(ORDEN_VARIANTES[absi(celda.x * 7 + celda.y * 13) % ORDEN_VARIANTES.size()])
	rebrota = p_rebrota
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("recolectable")
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.45
	forma.shape = esfera
	forma.position = Vector3(0.0, 0.3, 0.0)
	add_child(forma)
	_poner_visual()
	set_process(false)


func _poner_visual() -> void:
	var id: String = String(VARIANTES[variante])
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", id) as Node3D
	if n == null:
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		if escena != null:
			n = escena.instantiate() as Node3D
	if n == null:
		return
	n.name = "visual"
	n.rotation.y = deg_to_rad(float(absi(celda.x * 31 + celda.y * 17) % 360))
	add_child(n)
	_visual = n


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if not spell_reacts(rune_data):
		return
	var nuevo: String = String(_tabla()[Objetos.elemento_de(rune_data)])
	objeto = nuevo
	var c: Color = (Objetos.DATOS.get(nuevo, {}) as Dictionary).get("color", Color.WHITE)
	if _visual != null:
		Paleta3D.tintar(_visual, c)
	if get_parent() is Node3D:
		VfxKit3D.oro_motas(get_parent() as Node3D, global_position + Vector3(0.0, 0.4, 0.0), 8, 0.8, 0.1, 1.0, false, false, 0.2, Vector3.UP, 70.0)
	Sfx.play(self, "sello_ok")


## Reacciona si aún está sin transformar y su planta tiene algo para ese elemento.
func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null or recogido_ya:
		return false
	var base: String = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	return objeto == base and _tabla().has(Objetos.elemento_de(rune_data))


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0


func _tabla() -> Dictionary:
	return (Objetos.PLANTAS.get(planta, {}) as Dictionary).get("tabla", {})


## --- Cogerla ---

func _unhandled_input(ev: InputEvent) -> void:
	if recogido_ya or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var pj: Vector3 = _pos_jugador()
	if pj == Vector3.INF:
		return
	# Con varias a mano solo la más cercana responde (cada una recibe la tecla).
	var mia: float = _dist(pj, global_position)
	if mia > ALCANCE:
		return
	for o in get_tree().get_nodes_in_group("recolectable"):
		if o != self and is_instance_valid(o) and not bool(o.get("recogido_ya")) and _dist(pj, (o as Node3D).global_position) < mia:
			return
	recoger()


## La coge (sin mirar distancias: también la usan las pruebas y las reglas). Devuelve false si la mochila está llena.
func recoger() -> bool:
	if recogido_ya:
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	if Estado.i().agregar(objeto, 1) <= 0:
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", "Mochila llena")
		return false
	recogido_ya = true
	collision_layer = 0
	if _visual != null:
		_visual.visible = false
	var nombre: String = String((Objetos.DATOS.get(objeto, {}) as Dictionary).get("nombre", objeto))
	if lanz != null and lanz.has_method("avisar"):
		lanz.call("avisar", "%s (+1)" % nombre)
	Sfx.play(self, "logro_brillo")
	recogido.emit(objeto)
	if rebrota > 0.0:
		_t = 0.0
		set_process(true)
	return true


func _process(delta: float) -> void:
	_t += delta
	if _t < rebrota:
		return
	set_process(false)
	recogido_ya = false
	collision_layer = Lanzador3D.CAPA_REACTIVO
	objeto = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_poner_visual()


func _pos_jugador() -> Vector3:
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Node3D = lanz.get("jugador") as Node3D if lanz != null else null
	return j.global_position if j != null else Vector3.INF


func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
