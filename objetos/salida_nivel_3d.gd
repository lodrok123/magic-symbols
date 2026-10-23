class_name SalidaNivel3D
extends Node3D

## SALIDA A OTRO NIVEL (mapas abiertos al estilo EoW, 23/10). Una o varias casillas que, al pisarlas (o al pulsar E estando cerca, `modo=usar`), cargan otro nivel y dejan a la jugadora en
## una ENTRADA con nombre de ese nivel (`Niveles.ir_a`). La otra mitad es `EntradaNivel3D` (más abajo, en este mismo archivo).
##
## Se coloca desde un mapa con (escenas/puzle.gd):
##   ; pieza <id> salida <x> <y> a=<Nivel>:<entrada> [celdas=<lista>] [modo=pisar|usar] [marca=si|no]
## `celdas` = las casillas que cuentan como salida (por defecto la propia x,y: una puerta ancha puede ser un rectángulo `celdas=4,18..6,18`). `marca=no` quita la losa tenue del suelo.
##
## NO SE DISPARA AL APARECER. Una salida nace DESARMADA y se arma cuando la jugadora no está en ninguna de sus casillas: llegar a una entrada que está junto a una salida no te devuelve
## al instante, y salir de una zona de salida y volver a pisarla sí. `modo=usar` no necesita armarse: la tecla E es una orden clara.
## Si el nivel de destino no existe todavía, avisa en pantalla y en consola (`Niveles.ir_a`), se vuelve a desarmar y no rompe nada.

signal usada(destino: String)

const MODO_PISAR: String = "pisar"
const MODO_USAR: String = "usar"
const CADA: float = 0.1
const ALCANCE_USAR: float = 3.0               ## u: a cuánto del centro de una casilla de salida vale E (la casilla mide 2,3)
const COLOR_MARCA: Color = Color(0.75, 0.92, 1.0, 0.16)
const COLOR_RAYA: Color = Color(0.85, 0.97, 1.0, 0.5)
const ALTO_MARCA: float = 0.03
const AVISO_COLOR: Color = Color(1.0, 0.85, 0.6)

var celdas: Array = []
var destino: String = ""
var modo: String = MODO_PISAR
var armada: bool = false
var veces: int = 0                             ## cuántas veces se ha disparado (las pruebas)
var _mundo: Node = null
var _t: float = 0.0
var _marca: bool = true


func preparar(p_celdas: Array, p_destino: String, p_modo: String, p_marca: bool, p_mundo: Node) -> void:
	celdas = p_celdas
	destino = p_destino
	modo = p_modo
	_marca = p_marca
	_mundo = p_mundo
	position = Terreno3D.centro_de(celdas[0] as Vector2i, Terreno3D.y_pies(celdas[0] as Vector2i))


func _ready() -> void:
	add_to_group("salida_nivel")
	if _marca:
		_poner_marca()


## Una losa tenue sobre cada casilla de salida (sin colisión): se ve por dónde se sale sin tapar el suelo.
func _poner_marca() -> void:
	var lado: float = Terreno3D.casilla * 0.92
	for c in celdas:
		var m := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(lado, lado)
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = COLOR_MARCA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.name = "marca_%d_%d" % [(c as Vector2i).x, (c as Vector2i).y]
		m.position = Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)) - position + Vector3(0.0, ALTO_MARCA, 0.0)
		add_child(m)


## La casilla de la jugadora (Vector2i(-9999,-9999) si no hay jugadora).
func _celda_jugador() -> Vector2i:
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), _mundo)
	return Terreno3D.celda_de(j.global_position) if j != null else Vector2i(-9999, -9999)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CADA
	var c: Vector2i = _celda_jugador()
	var dentro: bool = celdas.has(c)
	if not dentro:
		armada = true
		return
	if armada and modo == MODO_PISAR:
		usar()


func _unhandled_input(ev: InputEvent) -> void:
	if modo != MODO_USAR or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	if cerca() and usar():
		get_viewport().set_input_as_handled()


## ¿Está la jugadora a tiro de E de alguna casilla de salida?
func cerca() -> bool:
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), _mundo)
	if j == null:
		return false
	for c in celdas:
		var d: Vector3 = j.global_position - Terreno3D.centro_de(c as Vector2i, j.global_position.y)
		d.y = 0.0
		if d.length() <= ALCANCE_USAR:
			return true
	return false


## Dispara la salida (la pisada, E, o una regla/prueba). Devuelve true si el viaje ha empezado; si el nivel no existe, avisa y se desarma.
func usar() -> bool:
	veces += 1
	if Niveles.ir_a(_mundo, destino):
		usada.emit(destino)
		return true
	armada = false
	var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	if lz != null and lz.has_method("avisar") and not Niveles.en_curso:
		lz.call("avisar", Niveles.TXT_SIN_NIVEL, AVISO_COLOR)
	return false


## El punto de LLEGADA de otro nivel (`; pieza <id> entrada <x> <y> [mira=n|e|s|o]`): el id de la pieza es su nombre. No dibuja ni bloquea nada. Mira hacia `mira` o, si no se dice,
## hacia donde hay más suelo libre seguido (hacia dentro del nivel: la boca de una cueva mira al interior, no a la pared).
class EntradaNivel3D extends Node3D:
	const DIRS: Dictionary = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "o": Vector2i(-1, 0)}
	var nombre: String = ""
	var celda: Vector2i = Vector2i.ZERO
	var mira: String = ""                   ## n|e|s|o, o vacío = hacia dentro

	func preparar(p_celda: Vector2i, p_nombre: String, p_mira: String) -> void:
		celda = p_celda
		nombre = p_nombre
		mira = p_mira
		position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
		add_to_group("entrada_nivel")

	## La dirección en casillas (n|e|s|o) en la que mira: la pedida o la que tiene más suelo libre delante.
	func dir_celda() -> Vector2i:
		if DIRS.has(mira):
			return DIRS[mira]
		var mejor: Vector2i = DIRS["s"]
		var largo_mejor: int = -1
		for k in ["s", "n", "e", "o"]:
			var d: Vector2i = DIRS[k]
			var largo: int = 0
			var c: Vector2i = celda + d
			while largo < Niveles.LARGO_MAX_MIRADA and Terreno3D.en_mapa(c) and _libre(c):
				largo += 1
				c += d
			if largo > largo_mejor:
				largo_mejor = largo
				mejor = d
		return mejor

	## Esa casilla no es pared ni vacío.
	func _libre(c: Vector2i) -> bool:
		var l: String = Terreno3D.letra_de(c)
		return l != "#" and l != " "

	## La dirección en el mundo (horizontal, unitaria) para `Jugador3D.mirar_hacia`.
	func direccion_mirada() -> Vector3:
		var d: Vector2i = dir_celda()
		var a: Vector3 = Terreno3D.centro_de(celda, 0.0)
		var b: Vector3 = Terreno3D.centro_de(celda + d, 0.0)
		var v := Vector3(b.x - a.x, 0.0, b.z - a.z)
		return v.normalized() if v.length() > 0.001 else Vector3(0.0, 0.0, 1.0)
