class_name CristalPulso3D
extends Area3D

## CRISTAL (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4): el EMISOR. Un cristal resonante sobre su base de roca que LATE: suelta un `Pulso3D` desde su
## casilla cada `cada` s (0 = solo cuando se le golpea) y también cuando le da un hechizo (el pulso lleva el elemento del hechizo y toma el color de su runa; un hechizo sin
## elemento da el pulso base). Entre golpes pasa `ENFRIAR` s: un hechizo continuo no lo convierte en una metralleta. Señal `late(pulso)`.
##
## EL ASPECTO es el modelo `cristal_resonante` (Meshy) con el brillo del pulso (`BrilloPulso3D`: en reposo APAGADO —se le baja la saturación al turquesa— y el destello lo pone la
## emisión del color del pulso) y una luz pequeña que sube con el destello, para que la sala se vea latir. Sin modelo, un prisma de primitivas con emisión.
##
## Se coloca desde un mapa con `; pieza <id> cristal <x> <y> [cada=<s>] [alcance=<casillas>]` (escenas/puzle.gd). Bloquea su casilla.

signal late(pulso: Pulso3D)

const CADA_DEFECTO: float = 3.0         ## s entre latidos (PLAN §5, C1: «late cada 3 s»)
const FASE_INICIAL: float = 1.0         ## s hasta el primer latido al montar (que se vea que está vivo)
const ENFRIAR: float = 0.6              ## s mínimos entre dos pulsos (golpes incluidos)
const T_DESTELLO: float = 0.55          ## s que tarda en apagarse el destello del latido
const ENERGIA_LUZ: float = 1.6          ## energía de la luz en el destello pleno
const ALCANCE_LUZ: float = 4.5          ## u
const ALTO_LUZ: float = 1.0             ## u sobre la base
const ANCHO_CUERPO: float = 1.0
const ALTO_CUERPO: float = 1.6

var celda: Vector2i = Vector2i.ZERO
var cada: float = CADA_DEFECTO
var alcance: int = Pulso3D.ALCANCE_DEFECTO
var latidos: int = 0                    ## cuántos pulsos ha soltado (las pruebas)
var destello: float = 0.0               ## 1 en el latido, baja a 0
var ultimo: Pulso3D = null              ## el último pulso que soltó
var nivel: String = ""                  ## el nivel (para la flag de la esquirla)
var golpes_recibidos: int = 0           ## golpes de hechizo que lo hicieron latir
var esquirla_dada: bool = false         ## ya soltó su esquirla (también con la flag puesta al montar)
var _mundo: Node = null
var _t: float = FASE_INICIAL
var _enfriando: float = 0.0
var _color: Color = Pulso3D.COLOR_BASE
var _mats: Array[ShaderMaterial] = []
var _mat_primitiva: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _luz_reposo: bool = false           ## ¿tiene el cupo de luz azul de reposo?
var _suelo: MeshInstance3D = null       ## la mancha de luz azul en el suelo a su pie (BrilloPulso3D.suelo_azul)


func preparar(p_celda: Vector2i, p_cada: float = CADA_DEFECTO, p_alcance: int = Pulso3D.ALCANCE_DEFECTO, mundo: Node = null) -> void:
	celda = p_celda
	cada = maxf(p_cada, 0.0)
	alcance = p_alcance
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO_CUERPO, ALTO_CUERPO, ANCHO_CUERPO)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO_CUERPO * 0.5, 0.0)
	add_child(forma)
	_dibujar()
	esquirla_dada = nivel != "" and Flags.i().tiene(flag_esquirla())
	set_process(true)


func _dibujar() -> void:
	var n: Node3D = BrilloPulso3D.modelo("cristal_resonante", _mundo)
	if n != null:
		n.name = "modelo"
		add_child(n)
		_mats = BrilloPulso3D.preparar(n)
	if n == null or _mats.is_empty():
		# Sin modelo (o sin textura que leer): un prisma de primitivas que brilla por emisión.
		var prisma := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.06
		cil.bottom_radius = 0.34
		cil.height = ALTO_CUERPO * 0.85
		cil.radial_segments = 6
		prisma.mesh = cil
		_mat_primitiva = StandardMaterial3D.new()
		_mat_primitiva.albedo_color = Color(0.45, 0.55, 0.6)
		_mat_primitiva.emission_enabled = true
		_mat_primitiva.emission = Pulso3D.COLOR_BASE
		_mat_primitiva.emission_energy_multiplier = 0.0
		prisma.material_override = _mat_primitiva
		prisma.position = Vector3(0.0, ALTO_CUERPO * 0.42, 0.0)
		add_child(prisma)
	_luz = OmniLight3D.new()
	_luz.omni_range = ALCANCE_LUZ
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, ALTO_LUZ, 0.0)
	add_child(_luz)
	_luz_reposo = BrilloPulso3D.reservar_luz()          # cristal grande: luz azul tenue en reposo (la Cueva se lee iluminada por ellos); sin cupo, solo brilla por emisión
	if _luz_reposo:
		_luz.light_color = BrilloPulso3D.COLOR_REPOSO
		_luz.light_energy = BrilloPulso3D.LUZ_REPOSO_ENERGIA
		_luz.omni_range = maxf(ALCANCE_LUZ, BrilloPulso3D.LUZ_REPOSO_ALCANCE)
	if _mat_primitiva != null:
		_mat_primitiva.emission_energy_multiplier = BrilloPulso3D.ENERGIA_REPOSO
	_suelo = BrilloPulso3D.suelo_azul(self)


func _exit_tree() -> void:
	if _luz_reposo:
		_luz_reposo = false
		BrilloPulso3D.liberar_luz()


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if latir(Objetos.elemento_de(rune_data)) != null:
		_contar_golpe()


## Fase 3 (docs/MATERIALES_CUEVA.md): el cristal resonante suelta una ESQUIRLA a los 2 golpes de hechizo (`Objetos.mineral_de("cristal_resonante", "golpe")`), una vez por cristal. Cuentan
## los golpes que lo hacen latir (los que caen en su enfriamiento no).
func _contar_golpe() -> void:
	golpes_recibidos += 1
	var hace_falta: int = int((Objetos.MINERALES.get("cristal_resonante", {}) as Dictionary).get("golpes", 2))
	if esquirla_dada or golpes_recibidos < hace_falta:
		return
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	if MineralPulso.dar(lanz, Objetos.mineral_de("cristal_resonante", "golpe"), self) != "":
		esquirla_dada = true
		Flags.i().poner(flag_esquirla())


## La flag de la esquirla: `<nivel>.mineral.<id>` (como la de la veta y la de los rompibles).
func flag_esquirla() -> String:
	return "%s.mineral.%s" % [Rompible3D._limpio(nivel), Rompible3D._limpio(String(name))]


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return _enfriando <= 0.0


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO_LUZ, 0.0))


## --- Latir ---

## Suelta un pulso (del `elemento`, «» = base). Devuelve el pulso, o null si está en `ENFRIAR`.
func latir(elemento: String = "") -> Pulso3D:
	if _enfriando > 0.0:
		return null
	_enfriando = ENFRIAR
	_t = cada if cada > 0.0 else 0.0
	latidos += 1
	destello = 1.0
	_color = Pulso3D.color_de(elemento)
	_pintar()
	var cont: Node = get_parent() if get_parent() != null else self
	ultimo = Pulso3D.emitir(cont, [celda], elemento, alcance, self)
	late.emit(ultimo)
	return ultimo


func _process(delta: float) -> void:
	if _enfriando > 0.0:
		_enfriando = maxf(_enfriando - delta, 0.0)
	if cada > 0.0:
		_t -= delta
		if _t <= 0.0:
			latir("")
	if destello > 0.0:
		destello = maxf(destello - delta / T_DESTELLO, 0.0)
		_pintar()


func _pintar() -> void:
	var e: float = destello * destello          # baja rápido y deja una cola corta
	BrilloPulso3D.poner(_mats, _color, BrilloPulso3D.ENERGIA_MAX * e)
	if _mat_primitiva != null:
		_mat_primitiva.emission = _color
		_mat_primitiva.emission_energy_multiplier = BrilloPulso3D.ENERGIA_MAX * e + BrilloPulso3D.ENERGIA_REPOSO
	if _luz != null:
		var reposo: float = BrilloPulso3D.LUZ_REPOSO_ENERGIA if _luz_reposo else 0.0
		_luz.light_color = BrilloPulso3D.COLOR_REPOSO.lerp(_color, e) if _luz_reposo else _color
		_luz.light_energy = reposo + ENERGIA_LUZ * e
	BrilloPulso3D.pintar_suelo(_suelo, BrilloPulso3D.COLOR_REPOSO.lerp(_color, e), e)
