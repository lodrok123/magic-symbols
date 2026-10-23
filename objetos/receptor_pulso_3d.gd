class_name ReceptorPulso3D
extends Node3D

## RECEPTOR (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4): reacciona a un pulso. Un pedestal rúnico con un engaste de cristal: cuando el frente de un
## `Pulso3D` llega a su casilla (o a una vecina de la veta que lo toca) se ACTIVA: el cristal se enciende y se queda encendido con el color del pulso, suelta un anillo y suena
## el tono de llegada (lo pone el pulso). `elemento` opcional: con uno, solo lo activa un pulso de ESE elemento y en reposo el engaste lleva un resplandor tenue de su color
## (el jugador ve qué pide); sin él lo activa cualquiera. Pone la flag `flag=` con la forma de siempre (`nivel.sala.hecho`), y con la flag ya puesta al montar nace activado
## y sin efecto (partida cargada), como el cofre. `rearme=<s>` > 0 lo apaga solo pasado ese tiempo. Señal `activado` / `apagado`.
##
## AVISOS DEL PULSO: está en el grupo `Pulso3D.GRUPO_PULSABLE` y tiene `celda` y `on_pulso(pulso)`. Bloquea su casilla (es un pedestal).
##
## Se coloca desde un mapa con `; pieza <id> receptor <x> <y> [elemento=<e>] [flag=<nombre>] [rearme=<s>]` (escenas/puzle.gd).

signal activado
signal apagado

const ENERGIA_ACTIVO: float = 1.7       ## brillo del engaste mientras está activado
const ENERGIA_DESTELLO: float = 3.0     ## el destello de la activación (baja a ENERGIA_ACTIVO)
const ENERGIA_PISTA: float = 0.45       ## el resplandor tenue de un receptor de elemento en reposo
const T_DESTELLO: float = 0.6
const ENERGIA_LUZ: float = 1.3
const ALCANCE_LUZ: float = 4.0
const ALTO_LUZ: float = 0.9

var celda: Vector2i = Vector2i.ZERO
var elemento: String = ""
var flag: String = ""
var rearme: float = 0.0
var activo: bool = false
var activaciones: int = 0               ## las pruebas
var _mundo: Node = null
var _t_rearme: float = 0.0
var _destello: float = 0.0              ## 1 al activarse, baja a 0
var _color: Color = Pulso3D.COLOR_BASE
var _mats: Array[ShaderMaterial] = []
var _mat_primitiva: StandardMaterial3D = null
var _luz: OmniLight3D = null


func preparar(p_celda: Vector2i, p_elemento: String = "", p_flag: String = "", p_rearme: float = 0.0, mundo: Node = null) -> void:
	celda = p_celda
	elemento = p_elemento
	flag = p_flag
	rearme = maxf(p_rearme, 0.0)
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	_dibujar()
	if elemento != "":
		_color = Pulso3D.color_de(elemento)
	if flag != "" and Flags.i().tiene(flag):
		_poner(true, Pulso3D.color_de(elemento), false)          # partida cargada: ya estaba activado
	else:
		_pintar()
	set_process(true)


func _dibujar() -> void:
	var n: Node3D = BrilloPulso3D.modelo("receptor_runico", _mundo)
	if n != null:
		n.name = "modelo"
		add_child(n)
		_mats = BrilloPulso3D.preparar(n)
	if n == null or _mats.is_empty():
		var pedestal := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.3
		cil.bottom_radius = 0.38
		cil.height = 0.8
		pedestal.mesh = cil
		_mat_primitiva = StandardMaterial3D.new()
		_mat_primitiva.albedo_color = Color(0.45, 0.47, 0.5)
		_mat_primitiva.emission_enabled = true
		_mat_primitiva.emission = Pulso3D.COLOR_BASE
		_mat_primitiva.emission_energy_multiplier = 0.0
		pedestal.material_override = _mat_primitiva
		pedestal.position = Vector3(0.0, 0.4, 0.0)
		add_child(pedestal)
	_luz = OmniLight3D.new()
	_luz.omni_range = ALCANCE_LUZ
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, ALTO_LUZ, 0.0)
	add_child(_luz)


## El aviso del pulso. Devuelve true si lo activó.
func on_pulso(pulso: Pulso3D) -> bool:
	if activo or pulso == null:
		return false
	if elemento != "" and pulso.elemento != elemento:
		return false
	_poner(true, pulso.color, true)
	return true


## Activa o apaga a mano (la acción `activar` / `apagar` de una regla y las pruebas).
func activar() -> void:
	if not activo:
		_poner(true, Pulso3D.color_de(elemento), true)


func apagar() -> void:
	if activo:
		_poner(false, _color, true)


func _poner(si: bool, color: Color, con_efecto: bool) -> void:
	activo = si
	_color = color
	_t_rearme = rearme if si else 0.0
	if si:
		activaciones += 1
		if con_efecto:
			_destello = 1.0
			if is_inside_tree() and Terreno3D.hay_mundo():
				Pulso3D.anillo(self, global_position, color)
			Puzle3D._logro("paso_puzle", self)            # el aviso de «vas bien» de siempre
	_pintar()
	if si:
		if flag != "" and not Flags.i().tiene(flag):
			Flags.i().poner(flag)
		activado.emit()
	else:
		apagado.emit()


func _process(delta: float) -> void:
	if activo and rearme > 0.0:
		_t_rearme -= delta
		if _t_rearme <= 0.0:
			_poner(false, _color, true)
			return
	if _destello > 0.0:
		_destello = maxf(_destello - delta / T_DESTELLO, 0.0)
		_pintar()


## La energía del engaste ahora: el destello baja hacia el brillo del activo; en reposo, nada (o la pista del elemento).
func energia() -> float:
	var base: float = ENERGIA_ACTIVO if activo else (ENERGIA_PISTA if elemento != "" else 0.0)
	return lerpf(base, ENERGIA_DESTELLO, _destello * _destello) if activo else base


func _pintar() -> void:
	var e: float = energia()
	var c: Color = _color if (activo or elemento != "") else Pulso3D.COLOR_BASE
	BrilloPulso3D.poner(_mats, c, e)
	if _mat_primitiva != null:
		_mat_primitiva.emission = c
		_mat_primitiva.emission_energy_multiplier = e
	if _luz != null:
		_luz.light_color = c
		_luz.light_energy = ENERGIA_LUZ * (e / ENERGIA_ACTIVO) if activo else 0.0
