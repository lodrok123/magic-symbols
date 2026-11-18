class_name Respiradero3D
extends Area3D

## RESPIRADERO (18/11/2026, puzle «Respiraderos» del laboratorio de fuego). Una reja en el suelo que EXHALA una nube de veneno (`NubeVeneno3D`) cada `cada` s: la nube dura `vida` s, tiene `radio` casillas
## y, con `dir=n|e|s|o`, nace media casilla hacia ese lado (el gas sale «hacia fuera»; sin `dir` brota centrada en la reja). Un segundo antes de cada exhalación (AVISO_S) la reja se enciende de verde
## y brilla cada vez más: se ve venir. No bloquea su casilla (se pisa; lo peligroso es la nube).
##
## QUÉ LE HACE CADA ELEMENTO (decisión de esta pieza, lo más barato que es coherente con lo que ya hace la nube):
##   · FUEGO: no apaga el respiradero (el gas sigue saliendo) pero SÍ quema la nube que ya hay: `NubeVeneno3D` baja su vida a `consume_s` (4 s) en 1,5 casillas. El hueco que abre depende de cuándo se queme:
##     lo que falte hasta la siguiente exhalación menos lo que tarde la nube en consumirse. Con `cada=10 vida=8`: sin quemar, 2 s de aire limpio entre nube y nube; quemándola al poco de nacer, unos 5 s.
##   · AGUA o HIELO (`Materia.via`, como la trampa de pared): atascan la reja `T_AGUA_S` s (8): no exhala ni avisa. `agua=no` en la pieza lo impide. La TIERRA y el resto no le hacen nada.
##   · `apagar(s)` / `encender()` (acciones del mapa, igual que `trampa_flechas`).
## Pieza `respiradero` del mapa (escenas/puzle.gd); dueño: Juego.

signal exhala                       ## acaba de salir una nube
signal apagado                      ## se atascó (agua, hielo o una regla)
signal encendido_otra_vez           ## volvió a funcionar

const CADA_DEFECTO: float = 8.0
const VIDA_DEFECTO: float = 5.0
const RADIO_DEFECTO: float = 1.0    ## casillas
const AVISO_S: float = 1.0
const ALTO_CAJA_U: float = 1.5      ## alto de la caja con la que recibe hechizos (la reja mide 0,2; la caja, lo que un barril)
const T_AGUA_S: float = 8.0
const COLOR_REJA: Color = Color(0.26, 0.28, 0.22)
const COLOR_GAS: Color = Color(0.55, 0.85, 0.25)
const DIRS: Dictionary = {"n": Vector3(0.0, 0.0, -1.0), "e": Vector3(1.0, 0.0, 0.0), "s": Vector3(0.0, 0.0, 1.0), "o": Vector3(-1.0, 0.0, 0.0)}

var celda: Vector2i = Vector2i.ZERO
var cada: float = CADA_DEFECTO
var vida: float = VIDA_DEFECTO
var radio: float = RADIO_DEFECTO
var dir: String = ""                ## "" = centrada; n|e|s|o = media casilla hacia ese lado
var desfase_s: float = 0.0
var apaga_con_agua: bool = true
var activo: bool = true             ## false = atascado (agua, hielo o una regla)
var exhalaciones: int = 0           ## cuántas nubes ha soltado (las pruebas)
var ultima: NubeVeneno3D = null     ## la última nube que soltó (las pruebas)
var en_aviso: bool = false

var _t: float = 0.0                 ## s desde la última exhalación
var _apagado_t: float = 0.0
var _apagado_fijo: bool = false
var _mat_gas: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _mundo: Node = null


## `p_mundo`: la maqueta (para colgar las nubes de su contenedor de piezas; sin ella, del padre de la reja).
func preparar(p_celda: Vector2i, p_cada: float, p_vida: float, p_radio: float, p_dir: String, p_desfase: float, p_mundo: Node = null) -> void:
	celda = p_celda
	cada = maxf(p_cada, 1.0)
	vida = maxf(p_vida, 0.5)
	radio = maxf(p_radio, 0.2)
	dir = p_dir if DIRS.has(p_dir) else ""
	desfase_s = p_desfase
	_mundo = p_mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	add_to_group("respiradero")
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(Terreno3D.casilla * 0.7, ALTO_CAJA_U, Terreno3D.casilla * 0.7)      # alta como la de un barril: una flecha vuela a la altura de la mano y a ras no la tocaría
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO_CAJA_U * 0.5, 0.0)
	add_child(forma)
	_t = fposmod(desfase_s, cada)
	_construir()
	_pintar(0.0)
	set_physics_process(true)


## Un marco de piedra, la boca oscura y la reja de tres barrotes con un fulgor verde debajo. Todo primitivas.
func _construir() -> void:
	var marco := MeshInstance3D.new()
	marco.name = "Marco"
	var cil := CylinderMesh.new()
	cil.top_radius = 0.85
	cil.bottom_radius = 0.95
	cil.height = 0.12
	marco.mesh = cil
	var m_marco := StandardMaterial3D.new()
	m_marco.albedo_color = Color(0.42, 0.38, 0.34)
	m_marco.roughness = 0.9
	marco.material_override = m_marco
	marco.position = Vector3(0.0, 0.06, 0.0)
	add_child(marco)
	var boca := MeshInstance3D.new()
	boca.name = "Boca"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.66
	disco.bottom_radius = 0.66
	disco.height = 0.02
	boca.mesh = disco
	_mat_gas = StandardMaterial3D.new()
	_mat_gas.albedo_color = Color(0.05, 0.08, 0.04)
	_mat_gas.emission_enabled = true
	_mat_gas.emission = COLOR_GAS
	_mat_gas.emission_energy_multiplier = 0.2
	boca.material_override = _mat_gas
	boca.position = Vector3(0.0, 0.125, 0.0)
	add_child(boca)
	var m_reja := StandardMaterial3D.new()
	m_reja.albedo_color = COLOR_REJA
	m_reja.roughness = 0.8
	for i in range(3):
		var barra := MeshInstance3D.new()
		barra.name = "Barrote%d" % i
		var b := BoxMesh.new()
		b.size = Vector3(1.4, 0.07, 0.1)
		barra.mesh = b
		barra.material_override = m_reja
		barra.position = Vector3(0.0, 0.17, -0.38 + 0.38 * float(i))
		add_child(barra)
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = COLOR_GAS
	_luz.light_energy = 0.0
	_luz.omni_range = 3.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, 0.5, 0.0)
	add_child(_luz)


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not activo:
		if not _apagado_fijo:
			_apagado_t -= delta
			if _apagado_t <= 0.0:
				encender()
		en_aviso = false
		_pintar(0.0)
		return
	_t += delta
	if _t >= cada:
		_t = fposmod(_t, cada)
		exhalar()
	var aviso: float = minf(AVISO_S, cada)
	en_aviso = _t >= cada - aviso
	_pintar(clampf((_t - (cada - aviso)) / aviso, 0.0, 1.0) if en_aviso else 0.0)


## Suelta una nube ahora (el reloj lo hace solo; público para las pruebas).
func exhalar() -> NubeVeneno3D:
	exhalaciones += 1
	var donde: Vector3 = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	if dir != "":
		donde += (DIRS[dir] as Vector3) * Terreno3D.casilla * 0.5
	var padre: Node = _contenedor()
	var nube: NubeVeneno3D = NubeVeneno3D.crear(padre, donde, vida, radio)
	ultima = nube
	exhala.emit()
	return nube


func _contenedor() -> Node:
	if _mundo is Object:
		var pr: Variant = (_mundo as Object).get("_props")
		if pr is Node:
			return pr
	return get_parent() if get_parent() != null else self


func _pintar(k: float) -> void:
	if _mat_gas != null:
		_mat_gas.emission_energy_multiplier = (0.2 + 2.8 * k) if activo else 0.0
	if _luz != null:
		_luz.light_energy = 1.4 * k if activo else 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  Apagar / encender (reglas del mapa, agua, hielo)
# ---------------------------------------------------------------------------------------------------------------------

## La atasca `segundos` s (0 o menos = hasta `encender`).
func apagar(segundos: float = 0.0) -> void:
	var estaba: bool = activo
	activo = false
	if segundos > 0.0:
		_apagado_fijo = false
		_apagado_t = maxf(_apagado_t, segundos)
	else:
		_apagado_fijo = true
		_apagado_t = 0.0
	if estaba:
		apagado.emit()


func encender() -> void:
	if activo:
		return
	activo = true
	_apagado_fijo = false
	_apagado_t = 0.0
	_t = 0.0
	encendido_otra_vez.emit()


# --- Contrato con los hechizos (el agua y el hielo la atascan) ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if not apaga_con_agua:
		return
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "agua" or e == "hielo":
		apagar(T_AGUA_S)


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if not apaga_con_agua or not activo:
		return false
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	return e == "agua" or e == "hielo"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, 0.2, 0.0))
