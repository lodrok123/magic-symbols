class_name ParedHuecaPulso3D
extends Node3D

## PARED HUECA (23/10, FASE 2 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4, §5 y §10 punto 5): una roca que tapa un paso y SUENA hueca cuando le llega un pulso. Es el REACTIVO del
## pulso. Dos respuestas, a propósito distintas:
##   · cualquier pulso (el del escenario, un cristal, la fuente) le arranca un ECO: un anillo, un destello azul y dos notas graves que se repiten. Es la pista: «aquí detrás hay hueco».
##   · un pulso del JUGADOR (el glifo ᚱ, `Pulso3D.del_jugador`) la ABRE: la roca se agrieta, suelta polvo y se hunde, y la casilla queda libre. Es el primer uso obligatorio del glifo
##     (la salida de la Cueva): no hay pulsador de reserva (decisión de Pablo, §10 punto 5).
## Pone la flag `flag=` al abrirse, y con ella ya puesta al montar nace abierta y sin efecto (partida cargada). Está en el grupo `Pulso3D.GRUPO_PULSABLE`, tiene `celda` y `on_pulso(pulso)`.
## Bloquea su casilla mientras está cerrada. Señales `eco(pulso)` y `abierto`.
##
## Se coloca con `; pieza <id> pared_hueca <x> <y> [flag=<nombre>]` (escenas/puzle.gd).

signal eco(pulso: Pulso3D)
signal abierto

const T_ECO: float = 0.55                 ## s que dura el destello del eco
const T_REPETICION: float = 0.22          ## s entre la nota del eco y su repetición
const TONO_ECO: float = 0.5               ## tono de la nota (grave: suena a hueco)
const TONO_REPETICION: float = 0.42
const T_ABRIR: float = 1.1                ## s que tarda en hundirse
const HUNDIR_Y: float = 1.9               ## u que baja al abrirse (más que su altura: queda bajo el suelo)
const TEMBLOR_ABRIR: float = 0.045        ## u de temblor mientras se agrieta
const ESCALA_MODELO: float = 3.1          ## el modelo `roca_hueca` mide 0,7 de alto: se escala para cubrir el hueco del paso
const ENERGIA_ECO: float = 1.6
const ALCANCE_LUZ: float = 3.8
const ALTO_LUZ: float = 0.9

var celda: Vector2i = Vector2i.ZERO
var flag: String = ""
var abierta: bool = false
var ecos: int = 0                         ## cuántos pulsos le han arrancado un eco (las pruebas)
var destello: float = 0.0
var ultimo_pulso_propio: bool = false     ## ¿el último pulso que la tocó era del jugador? (las pruebas)
var _mundo: Node = null
var _modelo: Node3D = null
var _mat_primitiva: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _luz_reposo: bool = false            ## ¿tiene el cupo de luz azul de reposo?
var _bloqueada: bool = false
var _y0: float = 0.0
var _t_abrir: float = -1.0
var _color: Color = BrilloPulso3D.COLOR_REPOSO


func preparar(p_celda: Vector2i, p_flag: String = "", mundo: Node = null) -> void:
	celda = p_celda
	flag = p_flag
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	_y0 = position.y


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	_dibujar()
	if flag != "" and Flags.i().tiene(flag):
		_abrir_ya()                       # partida cargada: ya estaba abierta
	else:
		_bloquear(true)
	set_process(true)


func _exit_tree() -> void:
	_bloquear(false)
	if _luz_reposo:
		_luz_reposo = false
		BrilloPulso3D.liberar_luz()


func _dibujar() -> void:
	# Es un trozo de la propia pared de la cueva (el kit `cueva_pared`, girado hacia la sala como lo haría la maqueta con un tabique): del lado de C6 solo se distingue por
	# las vetas que llevan hasta él, la luz azul tenue y el eco. (La primera versión usaba `roca_hueca`, 0,7 de alto: se leía como una bola de musgo en la puerta.)
	var n: Node3D = BrilloPulso3D.modelo("cueva_pared", _mundo)
	if n != null:
		n.name = "modelo"
		n.rotation_degrees.y = _giro_hacia_la_sala()
		add_child(n)
		_modelo = n
	else:
		var caja := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Terreno3D.casilla * 0.95, Terreno3D.casilla * 0.9, Terreno3D.casilla * 0.5)
		caja.mesh = bm
		_mat_primitiva = StandardMaterial3D.new()
		_mat_primitiva.albedo_color = Color(0.36, 0.34, 0.33)
		_mat_primitiva.emission_enabled = true
		_mat_primitiva.emission = BrilloPulso3D.COLOR_REPOSO
		_mat_primitiva.emission_energy_multiplier = 0.0
		caja.material_override = _mat_primitiva
		caja.position = Vector3(0.0, Terreno3D.casilla * 0.45, 0.0)
		add_child(caja)
		_modelo = caja
	_luz = OmniLight3D.new()
	_luz.light_color = BrilloPulso3D.COLOR_REPOSO
	_luz.omni_range = ALCANCE_LUZ
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, ALTO_LUZ, 0.0)
	add_child(_luz)
	_luz_reposo = BrilloPulso3D.reservar_luz()      # un resplandor azul tenue: es lo que distingue esta pared de las demás sin gritarlo
	_pintar()


## El giro (grados, sobre Y) con que la maqueta pone un `cueva_pared` de tabique: de frente a una de las dos salas (se elige la primera en el orden sur, este, norte, oeste).
func _giro_hacia_la_sala() -> float:
	var dirs: Array = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i in range(4):
		var l: String = Terreno3D.letra_de(celda + (dirs[i] as Vector2i))
		if l != "#" and l != " ":
			return 90.0 * float(i)
	return 0.0


func _bloquear(si: bool) -> void:
	if si and not _bloqueada:
		Terreno3D.bloquear_celda(celda)
		_bloqueada = true
	elif not si and _bloqueada:
		Terreno3D.liberar_celda(celda)
		_bloqueada = false


## El aviso del pulso: SIEMPRE eco; si es del jugador, además abre. Devuelve true si la abrió.
func on_pulso(pulso: Pulso3D) -> bool:
	if pulso == null:
		return false
	ultimo_pulso_propio = pulso.del_jugador
	_eco(pulso)
	if pulso.del_jugador and not abierta:
		abrir()
		return true
	return false


func _eco(pulso: Pulso3D) -> void:
	ecos += 1
	destello = 1.0
	_color = pulso.color
	if is_inside_tree() and Terreno3D.hay_mundo():
		Pulso3D.anillo(self, global_position, pulso.color)
		Sfx.play(self, Pulso3D.SFX_PULSO, TONO_ECO)
		get_tree().create_timer(T_REPETICION, false).timeout.connect(_repetir_eco.bind(weakref(self)))
	_pintar()
	eco.emit(pulso)


static func _repetir_eco(yo_ref: WeakRef) -> void:
	var yo: Variant = yo_ref.get_ref()
	if yo != null and is_instance_valid(yo) and (yo as Node).is_inside_tree():
		Sfx.play(yo as Node, Pulso3D.SFX_PULSO, TONO_REPETICION)


## Se abre (el pulso del jugador, o la acción `abrir` de una regla). false si ya estaba abierta.
func abrir() -> bool:
	if abierta:
		return false
	abierta = true
	_bloquear(false)                       # el paso queda libre ya: el hundimiento es un efecto
	_t_abrir = 0.0
	if is_inside_tree() and Terreno3D.hay_mundo():
		VfxKit3D.oro_motas(self, global_position + Vector3(0.0, Terreno3D.casilla * 0.4, 0.0), 30, 0.9, 0.09, 1.6, false, false, Terreno3D.casilla * 0.4, Vector3.UP, 60.0)
		Sfx.play(self, Pulso3D.SFX_PULSO, 0.38)
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	Puzle3D._logro("puerta_abierta", self)
	abierto.emit()
	return true


func _abrir_ya() -> void:
	abierta = true
	_bloquear(false)
	_t_abrir = T_ABRIR
	position.y = _y0 - HUNDIR_Y
	if _modelo != null:
		visible = false


func _process(delta: float) -> void:
	if destello > 0.0:
		destello = maxf(destello - delta / T_ECO, 0.0)
		_pintar()
	if _t_abrir >= 0.0 and _t_abrir < T_ABRIR:
		_t_abrir = minf(_t_abrir + delta, T_ABRIR)
		var u: float = _t_abrir / T_ABRIR
		var temblor: float = TEMBLOR_ABRIR * (1.0 - u) * sin(_t_abrir * 60.0)
		position.y = _y0 - HUNDIR_Y * smoothstep(0.25, 1.0, u)
		if _modelo != null:
			_modelo.position.x = temblor                                   # se agrieta: tiembla de lado mientras se hunde
		if u >= 1.0:
			visible = false


## El aspecto del eco: el modelo no tiene cristal que encender, así que el destello es una luz azul y un resplandor en la roca si el modelo es de primitivas.
func _pintar() -> void:
	var e: float = destello * destello
	if _mat_primitiva != null:
		_mat_primitiva.emission = _color
		_mat_primitiva.emission_energy_multiplier = ENERGIA_ECO * e
	if _luz != null:
		_luz.light_color = BrilloPulso3D.COLOR_REPOSO.lerp(_color, e) if _luz_reposo else _color
		_luz.light_energy = (BrilloPulso3D.LUZ_REPOSO_ENERGIA * (0.0 if abierta else 1.0) if _luz_reposo else 0.0) + ENERGIA_ECO * e
