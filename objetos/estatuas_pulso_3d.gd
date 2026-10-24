class_name EstatuasPulso3D
extends Node3D

## LAS ESTATUAS DEL SECRETO DE C1 (24/10, fase 3 del Pulso resonante; PLAN_PULSO_RESONANTE §5 «El secreto (épico)» y docs/MATERIALES_CUEVA.md). Tres estatuas de piedra (modelo
## `estatua_piedra`) que piden una SECUENCIA de pulsos de elemento (en la Cueva: fuego, hielo, fuego) y, al cumplirla, ponen la flag `flag=` (`cueva.c1.estatuas`), que hace aparecer el cofre
## ÉPICO. Solo se puede hacer con el glifo ᚱ (el pulso del jugador lleva el elemento de la receta): por eso es la razón para volver a C1 tras el cofre legendario.
##
## CÓMO SE JUEGA. Cada estatua es un receptor del pulso (grupo `Pulso3D.GRUPO_PULSABLE`, `celda`, `on_pulso`). Las estatuas se encienden EN ORDEN, de la primera a la última de `celdas`:
## la estatua `paso` espera un pulso de `secuencia[paso]`. Acierto: se enciende con el color de su elemento (anillo, nota que sube, motas). Fallo (otro elemento, o una estatua que aún no
## toca): TODAS se apagan con un temblor y una nota grave, y se empieza de nuevo. La pista está a la vista: cada estatua lleva a sus pies un resplandor tenue del color del elemento que pide
## (como el receptor de elemento), y el orden es el de izquierda a derecha. Hecha, se queda encendida para siempre (con la flag puesta al montar nace ya hecha, sin efecto: partida cargada).
## Señales `acierta(indice, paso)`, `falla`, `completa`.
##
## Se coloca desde un mapa con `; pieza <id> estatuas <x> <y> celdas=<lista> secuencia=<e1,e2,…> [flag=<nombre>]` (escenas/puzle.gd): una estatua por casilla de `celdas`, y la secuencia tiene
## tantos elementos como casillas. Bloquean sus casillas.

signal acierta(indice: int, paso: int)
signal falla
signal completa

const ELEMENTOS_VALIDOS: Array = ["fuego", "agua", "hielo", "rayo", "tierra", "viento"]
const ENERGIA_LUZ_PISTA: float = 0.35         ## el resplandor del elemento que pide una estatua apagada
const ENERGIA_LUZ_ENCENDIDA: float = 1.5
const ENERGIA_LUZ_DESTELLO: float = 3.2
const ALCANCE_LUZ: float = 4.0
const ALTO_LUZ: float = 1.1
const HALO_PISTA: float = 0.0                 ## `e` de `BrilloPulso3D.pintar_suelo` con la estatua apagada (solo el reposo)
const HALO_ENCENDIDA: float = 0.7
const HALO_DESTELLO: float = 1.4
const T_DESTELLO: float = 0.7
const T_TEMBLOR: float = 0.4
const TEMBLOR: float = 0.06
const COLOR_FALLO: Color = Color(0.55, 0.55, 0.62)
const TONO_FALLO: float = 0.38
const TONO_PASO: Array = [0.85, 1.05, 1.3, 1.55]
const MOTAS_ACIERTO: int = 12
const MOTAS_FINAL: int = 26

var celdas: Array = []
var secuencia: Array = []
var flag: String = ""
var paso: int = 0                             ## cuántas llevan encendidas
var hecha: bool = false
var aciertos: int = 0                         ## las pruebas
var fallos: int = 0                           ## las pruebas
var _mundo: Node = null
var _estatuas: Array = []


func preparar(p_celdas: Array, p_secuencia: Array, p_flag: String, mundo: Node = null) -> void:
	celdas = p_celdas
	secuencia = p_secuencia
	flag = p_flag
	_mundo = mundo


func _ready() -> void:
	for i in range(celdas.size()):
		var e := Estatua.new()
		e.name = "estatua_%d" % i
		e.jefe = self
		e.indice = i
		e.celda = celdas[i] as Vector2i
		e.elemento = String(secuencia[i])
		add_child(e)
		_estatuas.append(e)
	if flag != "" and Flags.i().tiene(flag):
		hecha = true                         # partida cargada: ya estaban hechas, sin efecto
		paso = celdas.size()
		for e in _estatuas:
			(e as Estatua).poner(true, false)


## ¿Cuántas estatuas hay y cuál es la i-ésima? (las pruebas)
func estatua(i: int) -> Estatua:
	return _estatuas[i] as Estatua if i >= 0 and i < _estatuas.size() else null


## Un pulso toca a la estatua `e`. Devuelve true si fue un acierto.
func _golpe(e: Estatua, pulso: Pulso3D) -> bool:
	if hecha or pulso == null:
		return false
	if e.indice < paso:
		return false                         # ya encendida: tocarla otra vez no es un fallo
	if e.indice == paso and pulso.elemento == String(secuencia[paso]):
		paso += 1
		aciertos += 1
		e.poner(true, true)
		if is_inside_tree():
			Sfx.play(e, Pulso3D.SFX_PULSO, float(TONO_PASO[mini(paso - 1, TONO_PASO.size() - 1)]))
			if get_parent() is Node3D:
				VfxCalidad3D.motas(get_parent() as Node3D, e.global_position + Vector3(0.0, 1.2, 0.0), Pulso3D.color_de(e.elemento), MOTAS_ACIERTO, 1.0, 0.08, 1.4, 0.3)
		acierta.emit(e.indice, paso)
		if paso >= secuencia.size():
			_completar()
		return true
	_fallar()
	return false


func _fallar() -> void:
	fallos += 1
	paso = 0
	for e in _estatuas:
		(e as Estatua).fallo()
	if is_inside_tree():
		Sfx.play(self, Pulso3D.SFX_PULSO, TONO_FALLO)
	falla.emit()


func _completar() -> void:
	hecha = true
	for e in _estatuas:
		(e as Estatua).destello_final()
	if is_inside_tree() and Terreno3D.hay_mundo():
		Sfx.play(self, Pulso3D.SFX_PULSO, 1.8)
		if get_parent() is Node3D:
			for e in _estatuas:
				VfxCalidad3D.motas(get_parent() as Node3D, (e as Estatua).global_position + Vector3(0.0, 1.0, 0.0), Objetos.CALIDADES["epico"]["color"], MOTAS_FINAL, 1.4, 0.1, 1.8, 0.4)
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	Puzle3D._logro("puzle_resuelto", self)
	completa.emit()


## Una estatua: receptor del pulso con el color del elemento que pide.
class Estatua extends Node3D:
	var jefe: EstatuasPulso3D = null
	var indice: int = 0
	var celda: Vector2i = Vector2i.ZERO
	var elemento: String = ""
	var encendida: bool = false
	var destello: float = 0.0
	var _modelo: Node3D = null
	var _mats: Array[ShaderMaterial] = []
	var _luz: OmniLight3D = null
	var _halo: MeshInstance3D = null
	var _color: Color = Pulso3D.COLOR_BASE
	var _temblor: float = 0.0
	var _x0: float = 0.0

	func _ready() -> void:
		add_to_group(Pulso3D.GRUPO_PULSABLE)
		position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
		Terreno3D.bloquear_celda(celda)
		_color = Pulso3D.color_de(elemento)
		var n: Node3D = BrilloPulso3D.modelo("estatua_piedra", jefe._mundo if jefe != null else null)
		if n != null:
			n.name = "modelo"
			add_child(n)
			_modelo = n
		else:
			var cil := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.28
			cm.bottom_radius = 0.4
			cm.height = 1.6
			cil.mesh = cm
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.5, 0.5, 0.52)
			cil.material_override = sm
			cil.position = Vector3(0.0, 0.8, 0.0)
			add_child(cil)
			_modelo = cil
		_x0 = _modelo.position.x
		_luz = OmniLight3D.new()
		_luz.light_color = _color
		_luz.omni_range = EstatuasPulso3D.ALCANCE_LUZ
		_luz.light_energy = EstatuasPulso3D.ENERGIA_LUZ_PISTA
		_luz.shadow_enabled = false
		_luz.position = Vector3(0.0, EstatuasPulso3D.ALTO_LUZ, 0.0)
		add_child(_luz)
		_halo = BrilloPulso3D.suelo_azul(self)
		_pintar()
		set_process(true)

	func _exit_tree() -> void:
		Terreno3D.liberar_celda(celda)

	func on_pulso(pulso: Pulso3D) -> bool:
		return jefe != null and jefe._golpe(self, pulso)

	## Enciende o apaga (con o sin efecto).
	func poner(si: bool, con_efecto: bool) -> void:
		encendida = si
		if si and con_efecto:
			destello = 1.0
			if is_inside_tree() and Terreno3D.hay_mundo():
				Pulso3D.anillo(self, global_position, _color)
		_pintar()

	## La secuencia falló: se apaga con un temblor.
	func fallo() -> void:
		var estaba: bool = encendida
		encendida = false
		destello = 0.0
		_temblor = 1.0 if (estaba or indice == 0) else 0.0
		_pintar()

	func destello_final() -> void:
		destello = 1.0
		if is_inside_tree() and Terreno3D.hay_mundo():
			Pulso3D.anillo(self, global_position, Objetos.CALIDADES["epico"]["color"])

	## Brillo del conjunto ahora (0 apagada con su pista, 1 encendida, más en el destello).
	func nivel() -> float:
		var base: float = 1.0 if encendida else 0.0
		return lerpf(base, 2.0, destello * destello)

	func _process(delta: float) -> void:
		if destello > 0.0:
			destello = maxf(destello - delta / EstatuasPulso3D.T_DESTELLO, 0.0)
			_pintar()
		if _temblor > 0.0:
			_temblor = maxf(_temblor - delta / EstatuasPulso3D.T_TEMBLOR, 0.0)
			if _modelo != null:
				_modelo.position.x = _x0 + EstatuasPulso3D.TEMBLOR * _temblor * sin(_temblor * 70.0)

	func _pintar() -> void:
		var k: float = nivel()
		var sube: float = minf(k, 1.0)
		var extra: float = maxf(k - 1.0, 0.0)
		if _luz != null:
			_luz.light_energy = lerpf(EstatuasPulso3D.ENERGIA_LUZ_PISTA, EstatuasPulso3D.ENERGIA_LUZ_ENCENDIDA, sube) + (EstatuasPulso3D.ENERGIA_LUZ_DESTELLO - EstatuasPulso3D.ENERGIA_LUZ_ENCENDIDA) * extra
		BrilloPulso3D.pintar_suelo(_halo, _color, lerpf(EstatuasPulso3D.HALO_PISTA, EstatuasPulso3D.HALO_ENCENDIDA, sube) + (EstatuasPulso3D.HALO_DESTELLO - EstatuasPulso3D.HALO_ENCENDIDA) * extra)
