class_name EmisorRayo3D
extends Node3D

## EMISOR DE RAYO AMBIENTAL EN 3D (9.10, Juego). La FUENTE ELÉCTRICA del bosque (letra `e`): cada PERIODO segundos suelta una
## descarga que recorre el AGUA conectada a la suya. Es la cadena de Pablo (10/10): fuente → cauce (cuando el surtidor lo ha
## llenado) → río → tótem de rayo en la orilla. El jugador NO tiene rayo: el tótem solo se activa por esta conducción.
##
## POR QUÉ UNA BÚSQUEDA POR CASILLAS y no un hechizo de rayo con salto. El rayo del Lanzador salta entre ENEMIGOS mojados;
## aquí no hay enemigos de por medio, hay un trozo de agua. Lo que se pide es una pregunta de conectividad («¿llega el agua
## de la fuente hasta esta casilla?»), y las preguntas de conectividad en una rejilla se resuelven con un relleno (BFS) por
## las casillas de agua. Costó decidir una regla de vecindad: se usan las 4 vecinas (sin diagonales), de modo que dos charcos
## que solo se tocan por una esquina NO conducen. Con 8 vecinas un río y un cauce que se rozan en diagonal se unirían sin que
## el jugador lo vea unido.
##
## Qué cuenta como agua: `Lanzador3D.es_agua(c)` (la letra `~` sin hielo encima). Por eso un tramo helado CORTA la corriente
## y un puente no la lleva. Es la misma pregunta que se hacen el jugador al nadar y los goblins, y no se duplica la regla.
##
## Qué hace una descarga: (1) calcula el agua conectada AHORA (el cauce puede haberse llenado desde la última); (2) la ilumina
## DURACION segundos; (3) activa los tótems de rayo que estén en su orilla; (4) hiere a quien esté DENTRO del agua
## electrificada cada TICK_DANO segundos. Entre descargas el agua es segura: se puede cruzar nadando si se mide el ritmo.
##
## Lo coloca Bosque3D.colocar() leyendo las `e` del mapa; no hace falta código en el cargador. Dueño: Juego (PROPIETARIOS.md).

signal descarga(celdas: Array)

const PERIODO: float = 4.0            ## s entre una descarga y la siguiente (medidas desde el final de la anterior)
const DURACION: float = 1.6           ## s que el agua está electrificada
const TICK_DANO: float = 0.4          ## s entre dos daños a quien está dentro
const DANO: float = 8.0               ## por tick (el jugador tiene 100 de vida: ~4 s dentro del agua y a la orilla)
const MAX_CHISPAS: int = 6            ## chispazos por tick: más de eso no se ve y cuesta
const LIMITE_BUSQUEDA: int = 4096     ## casillas máximas del relleno (corta un bug que dejase la búsqueda sin fin)
const COLOR: Color = Color(1.0, 0.92, 0.4)

var m: Variant = null                 ## la maqueta (PruebaTest2)
var celda: Vector2i = Vector2i.ZERO   ## dónde está la fuente
var electrificada: Array = []         ## Vector2i que ahora llevan corriente (vacío entre descargas)

var _t: float = 0.0                   ## cuenta atrás hasta la próxima descarga (o hasta que acabe la actual)
var _activa: bool = false
var _t_dano: float = 0.0
var _chispas: int = 0
var _malla: MultiMeshInstance3D = null
var _jug: Node = null


func preparar(p_mundo: Variant, p_celda: Vector2i) -> void:
	m = p_mundo
	celda = p_celda
	position = Lanzador3D.centro_de(celda, Lanzador3D.alto_suelo)
	_t = 1.0                          # la primera descarga a poco de empezar, para que se vea que está viva


## Casillas de agua conectadas (por las 4 vecinas) a las vecinas de `origen`. `es_agua` es un Callable(Vector2i) -> bool;
## estática y sin árbol para poder medirla sin escena. El origen es TIERRA (la fuente): la corriente entra por el agua que
## toca; si no toca ninguna, no hay corriente. Si `origen` fuese agua, entra también.
static func agua_conectada(origen: Vector2i, es_agua: Callable) -> Array:
	var visto: Dictionary = {}
	var cola: Array = []
	var arranque: Array = [origen, origen + Vector2i(1, 0), origen + Vector2i(-1, 0), origen + Vector2i(0, 1), origen + Vector2i(0, -1)]
	for c in arranque:
		if bool(es_agua.call(c)) and not visto.has(c):
			visto[c] = true
			cola.append(c)
	var i: int = 0
	while i < cola.size() and cola.size() < LIMITE_BUSQUEDA:
		var c: Vector2i = cola[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if not visto.has(v) and bool(es_agua.call(v)):
				visto[v] = true
				cola.append(v)
	return cola


## ¿Toca `c` (o alguna de sus 8 vecinas) alguna casilla de `agua`? Para el tótem de la orilla: pegado al agua, en diagonal incluido.
static func toca_agua(c: Vector2i, agua: Dictionary) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if agua.has(c + Vector2i(dx, dy)):
				return true
	return false


static func runa_rayo() -> RuneData:
	var r := RuneData.new()
	r.display_name = "Rayo"
	var t: Array[String] = ["rayo", "electrico"]
	r.tags = t
	return r


func _process(delta: float) -> void:
	if m == null:
		return
	_t -= delta
	if _activa:
		_t_dano -= delta
		if _t_dano <= 0.0:
			_t_dano = TICK_DANO
			_golpear()
		if _t <= 0.0:
			_apagar()
	elif _t <= 0.0:
		_soltar()


## Empieza una descarga con el agua que esté conectada ahora mismo.
func _soltar() -> void:
	var f := func(c: Vector2i) -> bool: return Lanzador3D.en_mapa(c) and Lanzador3D.es_agua(c)
	electrificada = EmisorRayo3D.agua_conectada(celda, f)
	_t = DURACION
	if electrificada.is_empty():
		_t = PERIODO                  # sin agua conectada no hay nada que iluminar; se vuelve a mirar en un rato
		return
	_activa = true
	_t_dano = 0.0
	_pintar()
	_activar_totems()
	descarga.emit(electrificada)


func _apagar() -> void:
	_activa = false
	electrificada = []
	_t = PERIODO
	if _malla != null:
		_malla.visible = false


## Los tótems de rayo pegados al agua electrificada se activan (contrato on_spell_hit: él decide con sus etiquetas).
func _activar_totems() -> void:
	var agua: Dictionary = {}
	for c in electrificada:
		agua[c] = true
	for r in get_tree().get_nodes_in_group("reactivo3d"):
		if not is_instance_valid(r) or String(r.get("tipo")) != "totem" or String(r.get("elemento")) != "rayo":
			continue
		if bool(r.get("activo")):
			continue
		if EmisorRayo3D.toca_agua(r.get("celda"), agua):
			(r as Node).call("on_spell_hit", EmisorRayo3D.runa_rayo(), Vector3.ZERO)


## Hiere a quien esté dentro del agua electrificada: el jugador y los goblins (Combate3D).
func _golpear() -> void:
	var agua: Dictionary = {}
	for c in electrificada:
		agua[c] = true
	if _jug == null or not is_instance_valid(_jug):
		_jug = get_tree().get_first_node_in_group("player")
		_jug = (_jug.get("jugador") as Node) if _jug != null and _jug.get("jugador") != null else null
	if _jug != null and agua.has(Lanzador3D.celda_de((_jug as Node3D).position)):
		_jug.call("recibir_dano", DANO, position)
	for g in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and agua.has(Lanzador3D.celda_de((g as Node3D).position)):
			g.call("receive_damage", DANO)
	_chispas = 0
	for c in electrificada:
		if _chispas >= MAX_CHISPAS:
			break
		if randf() < 0.25 and m != null and m.get("_fx") != null:
			(m.get("_fx") as Vfx3D).chispazo(Lanzador3D.centro_de(c, Lanzador3D.alto_agua + 0.1), "rayo")
			_chispas += 1


## Una losa amarilla por casilla electrificada, sobre el agua (un solo MultiMesh: son decenas de casillas).
func _pintar() -> void:
	if _malla == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(COLOR, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = COLOR
		mat.emission_energy_multiplier = 1.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(Lanzador3D.casilla * 0.92, Lanzador3D.casilla * 0.92)
		q.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = q
		_malla = MultiMeshInstance3D.new()
		_malla.multimesh = mm
		_malla.top_level = true               # sus transformaciones son del mundo, no de la fuente
		_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_malla)
	var mm2: MultiMesh = _malla.multimesh
	mm2.instance_count = electrificada.size()
	for i in range(electrificada.size()):
		mm2.set_instance_transform(i, Transform3D(Basis(), Lanzador3D.centro_de(electrificada[i], Lanzador3D.alto_agua + 0.06)))
	_malla.visible = true
