class_name GeodaPulso3D
extends Node3D

## GEODA EXPLOSIVA (26/10, Cueva; decisión de Pablo: «una geoda que al recibir un pulso del cristal explota, y su explosión tumba la columna que hace de puente»). Un reactivo del PULSO
## (grupo `Pulso3D.GRUPO_PULSABLE`, `on_pulso`, como la estalagmita): el frente de un pulso que la alcanza (por su casilla o la de la veta de al lado) la CARGA y, `T_MECHA` s después,
## EXPLOTA una sola vez.
##
## QUÉ HACE, CON NÚMEROS
##   · Carga (`T_MECHA` = 0,9 s): tiembla, brilla con una luz que sube del azul del pulso al blanco, y suena la nota del pulso. Más pulsos mientras carga no hacen nada.
##   · Explosión: a `RADIO` u (algo más de una casilla: la pieza de al lado, no la de dos más allá) llama a `recibir_explosion(punto)` de todo lo del grupo `explosionable` (la columna agrietada, el
##     jarrón, la caja, el barril, el muro agrietado…), igual que `Barril3D`. A los enemigos (`Combate3D`) del radio les hace `DANO` y los aturde `ATURDE_S` s; a la jugadora no (como la estalagmita).
##   · Después de explotar se retira (no es una mina recargable): la geoda desaparece y deja el polvo y el golpe de pantalla. Con `flag` se acuerda: si ya está puesta al montar, nace ya explotada.
## Señal `explota(punto, radio)`; condición `explotada`.
##
## Se coloca desde un mapa con `; pieza <id> geoda <x> <y> [flag=<nombre>] [escala=<x>] [cerca=<casillas>]` (escenas/puzle.gd) o con `preparar` desde código. No bloquea su casilla.

signal explota(punto: Vector3, radio: float)

const MODELO: String = "geoda_resonante"
const T_MECHA: float = 0.9              ## s entre el pulso y la explosión
const RADIO: float = 2.8                ## u (la casilla de al lado, no la de dos más allá)
const DANO: float = 30.0                ## a los enemigos del radio
const ATURDE_S: float = 2.0
const AMPLITUD: float = 0.04            ## u que tiembla al cargar
const LUZ_ENERGIA: float = 3.0
const LUZ_ALCANCE: float = 4.0
const COLOR_PULSO: Color = Color(0.35, 0.8, 1.0)

var celda: Vector2i = Vector2i.ZERO
var flag: String = ""
var escala: float = 1.0
var cerca: float = 0.0                  ## casillas: solo reacciona a los pulsos si la jugadora está a esta distancia o menos (0 = siempre). La demostración de C1 espera a que la veas
var pulsos_recibidos: int = 0           ## los que la cargaron (los que llegaron con la jugadora lejos no cuentan)
var cargando: bool = false
var explotada: bool = false
var ceniza: Array = []                  ## F1: lo que soltó al explotar ([{que, n}]: `ceniza_geoda` 1–2, lo dice `reactivos_mapa.tsv`); las pruebas lo leen
var golpeados: Array = []               ## los Combate3D que alcanzó (las pruebas)
var rotos: Array = []                   ## lo que había en el grupo `explosionable` al alcance y recibió la explosión (las pruebas)
var _mundo: Node = null
var _visual: Node3D = null
var _luz: OmniLight3D = null


func preparar(p_celda: Vector2i, p_flag: String = "", p_escala: float = 1.0, mundo: Node = null, p_cerca: float = 0.0) -> void:
	celda = p_celda
	flag = p_flag
	escala = p_escala
	cerca = p_cerca
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	if flag != "" and Flags.i().tiene(flag):
		explotada = true                    # ya explotó en otra visita: no queda nada
		remove_from_group(Pulso3D.GRUPO_PULSABLE)
		return
	_visual = _pieza(MODELO)
	if _visual != null:
		_visual.name = "geoda"
		_visual.scale *= escala             # el modelo ya viene a su medida (Pieza3D.MEDIDA): `escala` se multiplica, no la pisa
		_visual.position.y = -0.02
		add_child(_visual)


func _pieza(id: String) -> Node3D:
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", id) as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % id):
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		n = escena.instantiate() as Node3D if escena != null else null
	return n


## Contrato con el pulso: el primero la carga. Devuelve true si empezó a cargar.
func on_pulso(pulso: Pulso3D) -> bool:
	if explotada or cargando or pulso == null:
		return false
	if cerca > 0.0 and not _jugadora_cerca():
		return false                        # la demostración espera a que la jugadora esté a la vista: el latido siguiente la carga
	pulsos_recibidos += 1
	_cargar()
	return true


## ¿Está la jugadora a `cerca` casillas o menos (en casillas, máximo de las dos distancias)? Sin jugadora, no.
func _jugadora_cerca() -> bool:
	if not is_inside_tree():
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Node3D = lanz.get("jugador") as Node3D if lanz != null else null
	if j == null or not is_instance_valid(j):
		return false
	var d: Vector2i = Terreno3D.celda_de(j.global_position) - celda
	return float(maxi(absi(d.x), absi(d.y))) <= cerca


func _cargar() -> void:
	cargando = true
	Sfx.play(self, Pulso3D.SFX_PULSO, 1.3)
	_luz = OmniLight3D.new()
	_luz.light_color = COLOR_PULSO
	_luz.light_energy = 0.0
	_luz.omni_range = LUZ_ALCANCE
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, 0.4, 0.0)
	add_child(_luz)
	var tw: Tween = create_tween()
	tw.tween_method(_pulsar, 0.0, 1.0, T_MECHA)
	tw.tween_callback(_explotar)


## Mientras carga: la luz sube y vira al blanco, y la geoda tiembla cada vez más.
func _pulsar(f: float) -> void:
	if _luz != null and is_instance_valid(_luz):
		_luz.light_energy = LUZ_ENERGIA * f * f
		_luz.light_color = COLOR_PULSO.lerp(Color.WHITE, f)
	if _visual != null and is_instance_valid(_visual):
		var a: float = AMPLITUD * f
		_visual.position = Vector3(randf_range(-a, a), -0.02, randf_range(-a, a))


func _explotar() -> void:
	explotada = true
	cargando = false
	remove_from_group(Pulso3D.GRUPO_PULSABLE)
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	var punto: Vector3 = global_position
	rotos.clear()
	# Lo que está al alcance y sabe recibir una explosión (como Barril3D._explotar).
	for n in get_tree().get_nodes_in_group("explosionable"):
		if is_instance_valid(n) and n != self and n is Node3D and (n as Node3D).global_position.distance_to(punto) <= RADIO and n.has_method("recibir_explosion"):
			n.call("recibir_explosion", punto)
			rotos.append(n)
	_golpear(punto)
	# F1 (29/10): además del empujón, el polvo de la geoda queda en el suelo (`ceniza_geoda`).
	var fila: Dictionary = Botin.fila_reactivo("geoda", "pulso")
	ceniza = Botin.desde_texto(String(fila.get("botin", "ceniza_geoda:1-2")))
	if get_parent() is Node3D:
		Botin.soltar(get_parent(), Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)), ceniza)
	explota.emit(punto, RADIO)
	Sfx.play(self, "explosion")
	PulsoPantalla3D.lanzar_en(get_tree(), punto, 0.6, 0.3)
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, punto + Vector3(0.0, 0.2, 0.0), 1.6)
	_fogonazo()
	if _visual != null and is_instance_valid(_visual):
		_visual.visible = false


## Daño y aturdimiento a los enemigos (`Combate3D`) a `RADIO` u. La jugadora no es un Combate3D: no se toca.
func _golpear(punto: Vector3) -> void:
	golpeados.clear()
	for n in get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(n) or not (n is Node3D) or bool(n.get("muerto")):
			continue
		var d: Vector3 = (n as Node3D).global_position - punto
		d.y = 0.0
		if d.length() > RADIO:
			continue
		if (n as Object).has_method("aturdir_pulso"):
			(n as Object).call("aturdir_pulso", ATURDE_S)
		if (n as Object).has_method("receive_damage"):
			(n as Object).call("receive_damage", DANO)
		golpeados.append(n)


## Un fogonazo azulado que crece y se apaga (la luz de la carga sube un instante al máximo y se va).
func _fogonazo() -> void:
	var fog := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.3
	esf.height = 0.6
	fog.mesh = esf
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = COLOR_PULSO
	m.emission_energy_multiplier = 2.5
	fog.material_override = m
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog.position = Vector3(0.0, 0.3, 0.0)
	add_child(fog)
	var tw: Tween = create_tween()
	tw.tween_property(fog, "scale", Vector3.ONE * (RADIO / 0.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	if _luz != null and is_instance_valid(_luz):
		tw.parallel().tween_property(_luz, "light_energy", 0.0, 0.35)
	tw.tween_callback(fog.queue_free)
