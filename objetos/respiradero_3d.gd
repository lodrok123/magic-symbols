class_name Respiradero3D
extends Area3D

## RESPIRADERO (18/11/2026, puzle «Respiraderos» del laboratorio de fuego). Una reja en el suelo que EXHALA una nube de veneno (`NubeVeneno3D`) cada `cada` s: la nube dura `vida` s, tiene `radio` casillas
## y, con `dir=n|e|s|o`, nace media casilla hacia ese lado (el gas sale «hacia fuera»; sin `dir` brota centrada en la reja). Un segundo antes de cada exhalación (AVISO_S) la reja se enciende de verde
## y brilla cada vez más: se ve venir. No bloquea su casilla (se pisa; lo peligroso es la nube).
##
## QUÉ LE HACE CADA ELEMENTO (decisión de esta pieza, lo más barato que es coherente con lo que ya hace la nube):
##   · FUEGO (a la reja o a una nube suya): PRENDE EL GAS (`prender`). Estado «ardiendo» durante `arde_s` s (clave `arde=`, 6): la reja no exhala ni avisa, su nube viva se consume al instante (las nubes que suelta
##     llevan `consume_propio_s = quema_s`, clave `quema=`, 0,5 s, en vez de los 4 s de la tabla `veneno`, que siguen valiendo para el chamán, la colmena y la pieza `nube_veneno`) y se ve: una llama pequeña de
##     primitivas rojo-naranja (nunca amarilla) y luz cálida en vez de la verde. Al acabar (`se_apaga_llama`) vuelve a su ciclo DESDE 0 (la primera nube, `cada` s después). La nube de una reja que arde avisa a su reja
##     (`NubeVeneno3D.quemar` → `prender`): fuego a la niebla o a la reja es lo mismo, y el fuego a una nube prende también la reja vecina si su nube cae en el radio (1,5 casillas). Una reja ATASCADA no prende
##     (mojada); `spell_reacts` es true para el fuego siempre (el proyectil se gasta en la reja). El hueco limpio que deja es `arde_s` + `cada` s (el aviso de la siguiente nube va en el último segundo).
##   · AGUA o HIELO (`Materia.via`, como la trampa de pared): atascan la reja `T_AGUA_S` s (8): no exhala ni avisa; SOBRE UNA REJA ARDIENDO apagan además la llama (`se_apaga_llama`) y la dejan atascada.
##     `agua=no` en la pieza lo impide. La TIERRA y el resto no le hacen nada.
##   · `apagar(s)` / `encender()` (acciones del mapa, igual que `trampa_flechas`). `apagar` también quita la llama.
## Señales `exhala`, `apagado`, `encendido_otra_vez`, `prende` (empieza a arder) y `se_apaga_llama`; condiciones de la pieza `activo` | `apagado` | `ardiendo`.
## Pieza `respiradero` del mapa (escenas/puzle.gd); dueño: Juego.

signal exhala                       ## acaba de salir una nube
signal apagado                      ## se atascó (agua, hielo o una regla)
signal encendido_otra_vez           ## volvió a funcionar
signal prende                       ## el fuego prendió el gas: empieza a arder
signal se_apaga_llama               ## la llama se acabó (`arde_s`) o la apagó el agua / una regla

const CADA_DEFECTO: float = 8.0
const VIDA_DEFECTO: float = 5.0
const RADIO_DEFECTO: float = 1.0    ## casillas
const AVISO_S: float = 1.0
const ALTO_CAJA_U: float = 1.5      ## alto de la caja con la que recibe hechizos (la reja mide 0,2; la caja, lo que un barril)
const T_AGUA_S: float = 8.0
const COLOR_REJA: Color = Color(0.26, 0.28, 0.22)
const COLOR_GAS: Color = Color(0.55, 0.85, 0.25)
const QUEMA_DEFECTO: float = 0.5    ## s que tarda en consumirse una nube suya cuando arde (`consume_propio_s`)
const ARDE_DEFECTO: float = 6.0     ## s que arde la reja tras prenderla el fuego
const COLOR_LLAMA: Color = Color(1.0, 0.36, 0.08)          ## rojo-naranja (nunca amarillo)
const COLOR_LLAMA_FONDO: Color = Color(0.82, 0.14, 0.05)
const COLOR_LLAMA_LUZ: Color = Color(1.0, 0.42, 0.14)
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
var quema_s: float = QUEMA_DEFECTO  ## lo que tardan en consumirse sus nubes cuando arden
var arde_s: float = ARDE_DEFECTO    ## lo que arde la reja tras prenderla el fuego
var ardiendo: bool = false          ## el gas está prendido: no exhala ni avisa

var _t: float = 0.0                 ## s desde la última exhalación
var _arde_t: float = 0.0            ## s que le quedan de arder
var _t_llama: float = 0.0
var _llama: Node3D = null
var _conos: Array = []
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
	# La llama (solo mientras arde): tres lenguas de primitivas, rojo-naranja.
	_llama = Node3D.new()
	_llama.name = "Llama"
	_llama.position = Vector3(0.0, 0.15, 0.0)
	_llama.visible = false
	add_child(_llama)
	var lenguas: Array = [[Vector3(0.0, 0.0, 0.0), 0.30, 0.95, COLOR_LLAMA], [Vector3(0.32, 0.0, 0.12), 0.22, 0.65, COLOR_LLAMA_FONDO], [Vector3(-0.30, 0.0, -0.18), 0.24, 0.72, COLOR_LLAMA]]
	for l in lenguas:
		var cono := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = float(l[1])
		cm.height = float(l[2])
		cm.radial_segments = 8
		cono.mesh = cm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = l[3]
		mt.emission_enabled = true
		mt.emission = l[3]
		mt.emission_energy_multiplier = 2.2
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cono.material_override = mt
		cono.position = (l[0] as Vector3) + Vector3(0.0, float(l[2]) * 0.5, 0.0)
		_llama.add_child(cono)
		_conos.append(cono)


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
	if ardiendo:
		_arde_t -= delta
		en_aviso = false
		_quemar_nubes()                  # por si le quedara alguna nube viva
		if _arde_t <= 0.0:
			_quitar_llama(true)
		else:
			_pintar(0.0, delta)
		return
	_t += delta
	if _t >= cada:
		_t = fposmod(_t, cada)
		exhalar()
	var aviso: float = minf(AVISO_S, cada)
	en_aviso = _t >= cada - aviso
	_pintar(clampf((_t - (cada - aviso)) / aviso, 0.0, 1.0) if en_aviso else 0.0)


## Suelta una nube ahora (el reloj lo hace solo; público para las pruebas). Ardiendo no exhala (null).
func exhalar() -> NubeVeneno3D:
	if ardiendo:
		return null
	exhalaciones += 1
	var donde: Vector3 = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	if dir != "":
		donde += (DIRS[dir] as Vector3) * Terreno3D.casilla * 0.5
	var padre: Node = _contenedor()
	var nube: NubeVeneno3D = NubeVeneno3D.crear(padre, donde, vida, radio)
	nube.consume_propio_s = quema_s
	nube.respiradero = self
	ultima = nube
	exhala.emit()
	return nube


func _contenedor() -> Node:
	if _mundo is Object:
		var pr: Variant = (_mundo as Object).get("_props")
		if pr is Node:
			return pr
	return get_parent() if get_parent() != null else self


func _pintar(k: float, delta: float = 0.0) -> void:
	if ardiendo:
		# La llama (luz cálida y la boca rojiza en vez de verde) parpadea con el reloj de la reja.
		_t_llama += delta
		if _mat_gas != null:
			_mat_gas.emission = COLOR_LLAMA_FONDO
			_mat_gas.emission_energy_multiplier = 1.6
		if _luz != null:
			_luz.light_color = COLOR_LLAMA_LUZ
			_luz.light_energy = 1.7 + 0.4 * sin(_t_llama * 17.0) + 0.2 * sin(_t_llama * 29.0)
		for i in range(_conos.size()):
			var cn: MeshInstance3D = _conos[i]
			var f: float = _t_llama * (11.0 + 3.0 * float(i)) + float(i) * 2.1
			cn.scale = Vector3(1.0 + 0.10 * sin(f * 1.3), 1.0 + 0.22 * sin(f), 1.0 + 0.10 * sin(f * 1.3 + 1.0))
		return
	if _mat_gas != null:
		_mat_gas.emission = COLOR_GAS
		_mat_gas.emission_energy_multiplier = (0.2 + 2.8 * k) if activo else 0.0
	if _luz != null:
		_luz.light_color = COLOR_GAS
		_luz.light_energy = 1.4 * k if activo else 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  Prender el gas
# ---------------------------------------------------------------------------------------------------------------------

## El fuego prende el gas: arde `arde_s` s (no exhala ni avisa) y su nube viva se consume al instante. false si ya ardía o está atascada (mojada).
func prender() -> bool:
	if ardiendo or not activo:
		return false
	ardiendo = true
	_arde_t = arde_s
	_t_llama = 0.0
	en_aviso = false
	if _llama != null:
		_llama.visible = true
	_quemar_nubes()
	_pintar(0.0)
	prende.emit()
	return true


## Quema al instante las nubes vivas que soltó esta reja (cada una tarda `quema_s`, por su `consume_propio_s`).
func _quemar_nubes() -> void:
	for v in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(v) and (v as NubeVeneno3D).respiradero == self and not (v as NubeVeneno3D).ardiendo:
			(v as NubeVeneno3D).quemar(quema_s)


## Quita la llama. `ciclo_nuevo`: acabó de arder (vuelve a su ciclo desde 0); si no, la apagó el agua o una regla (el ciclo lo gobierna el atasco).
func _quitar_llama(ciclo_nuevo: bool) -> void:
	if not ardiendo:
		return
	ardiendo = false
	_arde_t = 0.0
	if _llama != null:
		_llama.visible = false
	if ciclo_nuevo:
		_t = 0.0
	_pintar(0.0)
	se_apaga_llama.emit()


# ---------------------------------------------------------------------------------------------------------------------
#  Apagar / encender (reglas del mapa, agua, hielo)
# ---------------------------------------------------------------------------------------------------------------------

## La atasca `segundos` s (0 o menos = hasta `encender`).
func apagar(segundos: float = 0.0) -> void:
	var estaba: bool = activo
	activo = false
	_quitar_llama(false)
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
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "fuego":
		prender()
	elif apaga_con_agua and (e == "agua" or e == "hielo"):
		apagar(T_AGUA_S)


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "fuego":
		return true
	if not apaga_con_agua or not activo:
		return false
	return e == "agua" or e == "hielo"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, 0.2, 0.0))
