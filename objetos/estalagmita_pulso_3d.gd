class_name EstalagmitaPulso3D
extends Node3D

## ESTALAGMITA RESONANTE (24/10, fase 3 del Pulso, C4; PLAN_PULSO_RESONANTE §4 y docs/MATERIALES_CUEVA.md). Un reactivo del PULSO (grupo `Pulso3D.GRUPO_PULSABLE`, `on_pulso`, como la columna agrietada
## de `MuroAgrietado3D`): el frente de un pulso que la alcanza (por su casilla o por la veta de al lado: el pulso «toca» las casillas vecinas de lo que conduce) la hace VIBRAR; al
## segundo pulso CAE y se convierte en `estalagmita_rota`.
##
## QUÉ HACE, CON NÚMEROS
##   · 1.er pulso: tiembla `T_VIBRA` s (± `AMPLITUD` u), suena y suelta un poco de polvo. No pasa nada más.
##   · 2.º pulso (`PULSOS_PARA_CAER`): se tumba hacia `cae` en `T_CAER` s (como la columna), levanta polvo y suena el derrumbe. `cae` = n|e|s|o del mapa; sin él, la opuesta de por donde llegó el pulso
##     (se cae «alejándose» de la veta: la casilla vecina alcanzada que el frente tocó antes, y se cae al lado contrario).
##   · Al aterrizar golpea lo que haya en la CASILLA donde cae (los `Combate3D` de esa casilla): `DANO_GOLPE` de daño y `ATURDE_S` s de aturdimiento (`aturdir_pulso`, sin pasar por el escudo). A
##     la jugadora no le hace nada (no es un `Combate3D`, y la estalagmita ni la empuja): en C4 sirve para el combate, como en EoW.
##   · Rota queda la pieza `estalagmita_rota` (0,7 de alto) en la casilla donde cayó. DECISIÓN: es un escombro BAJO que NO bloquea el paso (se pisa): una sala cerrada con goblins no necesita un
##     bloqueo más que pueda dejar a uno encajado, y a 0,7 no hace de muro. La estalagmita EN PIE tampoco bloquea su casilla (las flechas se paran en lo sólido y en las esquinas de C4 estorbaban al
##     combate): es un adorno que se rodea.
##   · Persistencia: con `flag`, al caer la pone; si ya está puesta al montar, nace ya caída (solo el escombro, sin efectos ni golpe).
##
## Se coloca desde un mapa con `; pieza <id> estalagmita <x> <y> [cae=n|e|s|o] [flag=<nombre>]` (escenas/puzle.gd) o con `preparar` desde código.

signal cae

const MODELO: String = "estalagmita_resonante"
const MODELO_ROTA: String = "estalagmita_rota"
const PULSOS_PARA_CAER: int = 2
const T_VIBRA: float = 0.5               ## s que dura el temblor
const AMPLITUD: float = 0.05             ## u que se mueve al temblar
const T_CAER: float = 0.6                ## s que tarda en tumbarse
const DANO_GOLPE: float = 25.0           ## daño al que está en la casilla donde cae
const ATURDE_S: float = 3.0              ## s sin sentido
const DIRS: Dictionary = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "o": Vector2i(-1, 0)}

var celda: Vector2i = Vector2i.ZERO
var flag: String = ""
var cae_a: String = ""                   ## del mapa; "" = la opuesta de por donde llegó el pulso
var dir_caida: String = "s"              ## hacia dónde cae (o cayó) de verdad
var pulsos_recibidos: int = 0
var vibrando: bool = false
var cayendo: bool = false
var caida_ya: bool = false
var golpeados: Array = []                ## los Combate3D que golpeó al caer (las pruebas)
var _mundo: Node = null
var _visual: Node3D = null


func preparar(p_celda: Vector2i, p_cae: String = "", p_flag: String = "", mundo: Node = null) -> void:
	celda = p_celda
	cae_a = p_cae if DIRS.has(p_cae) else ""
	dir_caida = cae_a if cae_a != "" else "s"
	flag = p_flag
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	if flag != "" and Flags.i().tiene(flag):
		caida_ya = true
		_poner_rota()
		return
	_visual = _pieza(MODELO)
	if _visual != null:
		_visual.name = "estalagmita"
		add_child(_visual)
	# No bloquea la casilla: en C4 las flechas de fuego se paran en lo sólido (`celda_solida`) y tres estalagmitas en las esquinas de la sala cerrada estorbaban a la jugadora
	# y los goblins, cuyo combate no debe cambiar. Se rodean porque ocupan poco (0,9 de ancho), pero la caída sigue golpeando la casilla.


func _pieza(id: String) -> Node3D:
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", id) as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % id):
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		n = escena.instantiate() as Node3D if escena != null else null
	return n


func _vec(d: String) -> Vector3:
	var v: Vector2i = DIRS[d]
	return Vector3(float(v.x), 0.0, float(v.y))


## La casilla donde cae (o cayó).
func celda_caida() -> Vector2i:
	return celda + (DIRS[dir_caida] as Vector2i)


## Contrato con el pulso: el 1.º hace vibrar, el 2.º la tira. Devuelve true si la hizo caer.
func on_pulso(pulso: Pulso3D) -> bool:
	if caida_ya or cayendo or pulso == null:
		return false
	pulsos_recibidos += 1
	if pulsos_recibidos >= PULSOS_PARA_CAER:
		if cae_a == "":
			dir_caida = _opuesta_a_la_llegada(pulso)
		_caer()
		return true
	_vibrar()
	return false


## Hacia dónde cae si el mapa no lo dice: la opuesta de la vecina que el frente alcanzó antes (la veta de la que vino el pulso). Sin vecina alcanzada, al sur.
func _opuesta_a_la_llegada(pulso: Pulso3D) -> String:
	var mejor_paso: int = 1 << 30
	var mejor: String = ""
	for k in DIRS:
		var v: Vector2i = celda + (DIRS[k] as Vector2i)
		if pulso.alcanzadas.has(v) and int(pulso.alcanzadas[v]) < mejor_paso:
			mejor_paso = int(pulso.alcanzadas[v])
			mejor = String(k)
	if mejor == "":
		return "s"
	var contraria: Dictionary = {"n": "s", "s": "n", "e": "o", "o": "e"}
	return String(contraria[mejor])


func _vibrar() -> void:
	vibrando = true
	Sfx.play(self, "tierra")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.5)
	if _visual == null:
		vibrando = false
		return
	var base: Vector3 = _visual.position
	var tw: Tween = create_tween()
	for i in range(8):
		tw.tween_property(_visual, "position", base + Vector3(randf_range(-AMPLITUD, AMPLITUD), 0.0, randf_range(-AMPLITUD, AMPLITUD)), T_VIBRA / 9.0)
	tw.tween_property(_visual, "position", base, T_VIBRA / 9.0)
	tw.tween_callback(func() -> void: vibrando = false)


func _caer() -> void:
	cayendo = true
	caida_ya = true
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	if _visual == null:
		_aterrizar()
		return
	var dir: Vector3 = _vec(dir_caida)
	var eje: Vector3 = Vector3.UP.cross(dir)
	var base: Basis = _visual.basis
	var tw: Tween = create_tween()
	tw.tween_method(func(a: float) -> void: _visual.basis = Basis(eje, a) * base, 0.0, PI * 0.5, T_CAER).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_aterrizar)


## Aterriza: derrumbe, polvo, golpe a lo que haya en la casilla de caída y el escombro en su sitio.
func _aterrizar() -> void:
	cayendo = false
	Sfx.play(self, "derrumbe")
	var donde: Vector3 = global_position + _vec(dir_caida) * Terreno3D.casilla
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, donde + Vector3(0.0, 0.1, 0.0), 1.4)
	_golpear(celda_caida())
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null
	_poner_rota()
	cae.emit()


## Daño y aturdimiento a los enemigos (`Combate3D`) de la casilla `c`. La jugadora no es un Combate3D: no se toca.
func _golpear(c: Vector2i) -> void:
	golpeados.clear()
	if get_tree() == null:
		return
	for n in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Node3D and not bool(n.get("muerto")) and Terreno3D.celda_de((n as Node3D).global_position) == c:
			if (n as Object).has_method("aturdir_pulso"):
				(n as Object).call("aturdir_pulso", ATURDE_S)
			if (n as Object).has_method("receive_damage"):
				(n as Object).call("receive_damage", DANO_GOLPE)
			golpeados.append(n)


## El escombro (`estalagmita_rota`) en la casilla donde cayó, tumbado hacia donde cayó.
func _poner_rota() -> void:
	var rota: Node3D = _pieza(MODELO_ROTA)
	if rota == null:
		return
	rota.name = "rota"
	rota.position = _vec(dir_caida) * Terreno3D.casilla
	rota.rotation.y = atan2(_vec(dir_caida).x, _vec(dir_caida).z)
	add_child(rota)
