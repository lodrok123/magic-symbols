class_name Coca3D
extends Node3D

## LA COCA DE REDONDELA (arte/meshy/PROMPTS_COCA.md §0; DC-04 de docs/INVENTARIO_MONTE_SUMICIO.md). Dueño: Juego. PROTOTIPO DE PRIMITIVAS (sin AnimationPlayer ni esqueleto).
##
## Serpiente de agua, jefe de la Cueva del Lago Termal. Para la historia es la amiga encantada de la Moura: NO MUERE, SE CALMA.
##   · SUMERGIDA (BAJO_AGUA_S): bajo el agua no se la ve ni reacciona a nada. Elige una POZA LIBRE (agua que no tapa un sólido de la jugadora), distinta de la última si hay más de una.
##     Si no queda ninguna libre, sale por el BAJÍO (la poza poco profunda de la orilla) y queda VARADA.
##   · EMERGE → ACECHA (gira hacia la jugadora) → POSE (quieta; el aviso `AvisoAtaque3D.rectangulo` del chorro, recortado en el primer sólido) → CHORRO (hiere y aparta a la
##     jugadora que esté en la línea sin sólido por medio; la voltereta la libra) → HUNDE → SUMERGIDA.
##   · VARADA (VARADA_S): la runa se enciende y recibe daño de CUALQUIER hechizo ×1. Al acabar se hunde y sigue el ciclo.
##   · En cualquier otra fase es INVULNERABLE (golpe sordo y «Escamas», lo ineficaz, C20).
##   · Vida a 0: NO muere, pasa a CALMA (se yergue, la runa gira 180° y se queda encendida), señal `calmada`, y deja de atacar y de reaccionar. `reiniciar` (G1) la devuelve al
##     principio salvo que ya esté calmada.
## DIBUJO POR CÓDIGO: el cuello son SEGMENTOS esferas colocadas sobre una Bézier cúbica de 4 puntos (coordenadas locales: Y arriba, +Z hacia donde mira, origen en la superficie del
## agua de la poza). Cada pose (`POSES`) son esos 4 puntos; cambiar de pose es interpolarlos. Encima, siempre, una onda lateral. La cabeza va al final, orientada con la tangente.

signal emerge(celda: Vector2i)
signal chorro
signal varada
signal calmada

enum Fase { SUMERGIDA, EMERGE, ACECHA, POSE, CHORRO, HUNDE, VARADA, CALMA }

static var VIDA: float = 150.0
static var BAJO_AGUA_S: float = 1.2
static var EMERGE_S: float = 0.7
static var ACECHA_S: float = 1.5
static var POSE_S: float = 0.6
static var CHORRO_S: float = 0.8
static var HUNDE_S: float = 0.6
static var VARADA_S: float = 4.0
static var ALCANCE_CHORRO_CASILLAS: float = 6.0
static var ANCHO_CHORRO: float = 0.5                ## media anchura del aviso y de su golpe
static var DANO_CHORRO: float = 20.0
static var EMPUJE_JUGADORA: float = 2200.0          ## la unidad de `Jugador3D.push` (la misma que el verraco)
static var GIRO_RAD_S: float = 2.5
static var TEMBLOR_CHORRO: float = 0.3
const RADIO_JUGADORA: float = 0.3                   ## lo que suma a la media anchura para saber si el chorro la pilla
const PUNTA_CABEZA_Z: float = 0.9                   ## el morro, en el eje de la cabeza (el cráneo, centrado en 0,4 y de largo 1,0)
const SEGMENTOS: int = 10
const RADIO_BASE: float = 0.45
const RADIO_PUNTA: float = 0.32
const T_POSE_A_RECOGIDA: float = 0.25               ## POSE: erguida → recogida y quieta el resto
const T_CHORRO_A_LANZADA: float = 0.15              ## CHORRO: recogida → lanzada y se sostiene
const T_VARADA_A_TENDIDA: float = 0.4
const T_CALMA: float = 1.0                          ## yergue el cuello y gira la runa 180° en este tiempo
const COLOR_TURQUESA: Color = Color(0.10, 0.55, 0.50)
const COLOR_CREMA: Color = Color(0.86, 0.78, 0.58)
const COLOR_AMBAR: Color = Color(1.0, 0.62, 0.12)
const COLOR_RUNA_APAGADA: Color = Color(0.13, 0.10, 0.07)
const COLOR_CHORRO: Color = Color(0.55, 0.82, 1.0, 0.55)
const COLOR_DANO: Color = Color(1.0, 0.55, 0.15)

## Poses del cuello: 4 puntos de control de una Bézier cúbica (local: Y arriba, +Z hacia donde mira, origen en el agua de la poza).
const POSES: Dictionary = {
	"hundida": [Vector3(0, -3.0, 0), Vector3(0, -2.6, 0), Vector3(0, -2.2, 0), Vector3(0, -1.8, 0)],
	"erguida": [Vector3(0, 0, 0), Vector3(0, 1.0, -0.3), Vector3(0, 2.0, -0.2), Vector3(0, 2.5, 0.4)],
	"recogida": [Vector3(0, 0, 0), Vector3(0, 1.2, -0.9), Vector3(0, 2.3, -1.1), Vector3(0, 2.2, -0.3)],
	"lanzada": [Vector3(0, 0, 0), Vector3(0, 0.9, 0.3), Vector3(0, 1.5, 1.2), Vector3(0, 1.4, 2.2)],
	"varada": [Vector3(0, 0, 0), Vector3(0, 0.5, 0.8), Vector3(0, 0.3, 2.0), Vector3(0, 0.35, 3.0)],
	"calma": [Vector3(0, 0, 0), Vector3(0, 1.0, -0.2), Vector3(0, 1.9, 0.1), Vector3(0, 1.9, 0.8)],
}
enum Suave { SUAVE, REBOTE }

var fase: int = Fase.SUMERGIDA
var vida: float = VIDA
var vida_max: float = VIDA
var pozas: Array[Vector2i] = []
var bajio: Vector2i = Vector2i.ZERO
var celda: Vector2i = Vector2i.ZERO                 ## la poza por la que está saliendo (o el bajío)
var casa: Vector3 = Vector3.ZERO
var dir: Vector3 = Vector3(0, 0, 1)
var _mundo: Node = null
var _t: float = 0.0
var _tiempo: float = 0.0
var _ultima: Vector2i = Vector2i(-9999, -9999)      ## la última poza por la que salió
var _por_bajio: bool = false
var _largo_u: float = 0.0                           ## largo del chorro (u), ya recortado en el primer sólido
var _aviso: AvisoAtaque3D = null
var _lanz: Lanzador3D = null
var _rng := RandomNumberGenerator.new()
# La pose que se dibuja y la interpolación hacia la siguiente
var _pose: Array[Vector3] = []
var _pose_desde: Array[Vector3] = []
var _pose_hasta: Array[Vector3] = []
var _pose_dur: float = 0.001
var _pose_t: float = 0.0
var _pose_suave: int = Suave.SUAVE
var _amp: float = 1.0                               ## amplitud de la onda (×0,3 varada)
var _k_fuera: float = 0.0                           ## 0 = sumergida, 1 = fuera (para los arcos)
var _runa_luz: float = 0.0                          ## 0 apagada, 1 encendida
var _runa_enciende: bool = false
var _apertura: float = 0.0                          ## mandíbula
# Para las pruebas
var emergencias: int = 0
var chorros: int = 0
var varadas: int = 0
var golpes_sin_efecto: int = 0
var golpes_dano: int = 0
var golpes_jugadora: int = 0
var reinicios: int = 0
var calmada_ya: bool = false
var ultimo_emerger: Vector2i = Vector2i(-9999, -9999)

var _raiz: Node3D = null
var _segmentos: Array[MeshInstance3D] = []
var _cabeza: Node3D = null
var _mandibula: Node3D = null
var _runa: Node3D = null
var _runa_giro: Node3D = null
var _mat_runa: StandardMaterial3D = null
var _mat_cuerpo: StandardMaterial3D = null
var _arcos: Array[Node3D] = []
var _chorro_mesh: MeshInstance3D = null
var _cuerpo: CuerpoCoca = null
var _forma: CollisionShape3D = null
var _destello: float = 0.0
var _registrada: bool = false                       ## las pozas ya están dichas al Lanzador (tierra tapable)
var _lanz_reg: Lanzador3D = null
var _marcas_raiz: Node3D = null                     ## las piedras y burbujas de las pozas (top_level: no siguen a la Coca)
var _burbujas: Dictionary = {}                      ## poza → Node3D con sus burbujas (visible solo si la poza está libre)
var _t_marcas: float = 0.0


## El cuerpo que reciben los hechizos (capa de reactivos, como el del verraco).
class CuerpoCoca extends Area3D:
	var coca: Coca3D = null

	func montar(c: Coca3D) -> void:
		coca = c
		monitoring = false
		monitorable = true
		collision_mask = 0
		collision_layer = Lanzador3D.CAPA_REACTIVO

	func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
		if coca != null:
			coca.on_spell_hit(rune_data, direccion, hechizo)

	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, _h: Hechizo = null) -> bool:
		return coca != null and coca.fase != Coca3D.Fase.SUMERGIDA and coca.fase != Coca3D.Fase.CALMA

	func carried_element() -> RuneData:
		return null


## Lo monta la pieza `coca` de Puzle3D: `p_pozas` son las casillas de agua por las que emerge, `p_bajio` la poza poco profunda de la orilla.
func preparar(p_pozas: Array, p_bajio: Vector2i, p_vida: float, p_mundo: Node) -> void:
	_mundo = p_mundo
	pozas.clear()
	for c in p_pozas:
		pozas.append(c as Vector2i)
	bajio = p_bajio
	vida = p_vida if p_vida > 0.0 else VIDA
	vida_max = vida
	celda = pozas[0] if not pozas.is_empty() else bajio
	casa = _centro_agua(celda)
	position = casa
	_poner_pose("hundida")
	_construir()
	_construir_marcas()
	_dibujar(0.0)
	_registrar_pozas()


func _ready() -> void:
	add_to_group("coca")
	_rng.randomize()


func _exit_tree() -> void:
	_olvidar_pozas()


## 27/11: la tierra de la jugadora puede levantarse sobre el agua de estas pozas (y solo de ellas; el bajío NO): se las dice al Lanzador. Si aún no existe, se reintenta en `_physics_process`.
func _registrar_pozas() -> void:
	if _registrada:
		return
	var l: Lanzador3D = lanzador()
	if l == null:
		return
	for c in pozas:
		l.registrar_poza(c)
	_lanz_reg = l
	_registrada = true


func _olvidar_pozas() -> void:
	if _registrada and _lanz_reg != null and is_instance_valid(_lanz_reg):
		for c in pozas:
			_lanz_reg.olvidar_poza(c)
	_registrada = false
	_lanz_reg = null


## ¿Está ella, emergida, en la casilla `c`? (La tierra no se levanta sobre ella.) Sumergida no ocupa nada.
func ocupa(c: Vector2i) -> bool:
	return fase != Fase.SUMERGIDA and c == celda


func lanzador() -> Lanzador3D:
	if _lanz == null or not is_instance_valid(_lanz):
		_lanz = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D if is_inside_tree() else null
	return _lanz


func jugadora() -> Node3D:
	var l: Lanzador3D = lanzador()
	return l.jugador as Node3D if l != null and l.jugador != null and is_instance_valid(l.jugador) else null


static func _centro_agua(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.alto_agua) if Terreno3D.en_mapa(c) else Vector3.ZERO


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_tiempo += delta
	_destello = maxf(0.0, _destello - delta)
	if not _registrada:
		_registrar_pozas()
	match fase:
		Fase.SUMERGIDA:
			if _t >= BAJO_AGUA_S:
				_elegir_poza()
		Fase.EMERGE:
			if _t >= EMERGE_S:
				_cambiar(Fase.VARADA if _por_bajio else Fase.ACECHA)
		Fase.ACECHA:
			_girar(delta)
			if _t >= ACECHA_S and _jugadora_viva():
				_empezar_pose()
		Fase.POSE:
			if _t >= POSE_S:
				_empezar_chorro()
		Fase.CHORRO:
			if _t >= CHORRO_S:
				_cambiar(Fase.HUNDE)
		Fase.HUNDE:
			if _t >= HUNDE_S:
				_cambiar(Fase.SUMERGIDA)
		Fase.VARADA:
			if _t >= VARADA_S:
				_cambiar(Fase.HUNDE)
	_animar(delta)


## Cambia de fase y deja dispuesto lo que ella hace en la nueva: la pose a la que va, la runa, el cuerpo que recibe hechizos.
func _cambiar(nueva: int) -> void:
	fase = nueva
	_t = 0.0
	if nueva != Fase.CHORRO:
		_quitar_chorro()
	if nueva != Fase.POSE and nueva != Fase.CHORRO:
		_quitar_aviso()                                          # el aviso del chorro solo vive en POSE (y su destello en CHORRO): en cualquier otra fase no hay ataque que avisar
	match nueva:
		Fase.SUMERGIDA:
			_poner_pose("hundida")
		Fase.EMERGE:
			_pose_hacia("erguida", EMERGE_S, Suave.REBOTE)
		Fase.POSE:
			_pose_hacia("recogida", T_POSE_A_RECOGIDA)
		Fase.CHORRO:
			_pose_hacia("lanzada", T_CHORRO_A_LANZADA)
		Fase.HUNDE:
			_runa_enciende = false
			_pose_hacia("hundida", HUNDE_S)
		Fase.VARADA:
			_runa_enciende = true
			_pose_hacia("varada", T_VARADA_A_TENDIDA)
			varadas += 1
			PlayLog.event("coca_varada", {"celda": [celda.x, celda.y]})
			varada.emit()
		Fase.CALMA:
			_runa_enciende = true
			_pose_hacia("calma", T_CALMA)
	_ajustar_cuerpo()


func _jugadora_viva() -> bool:
	var j: Node3D = jugadora()
	return j != null and not bool(j.get("muerto"))


## ¿Sigue siendo una poza por la que puede salir? Es agua y no la tapa un sólido de la jugadora (tierra apilada o una barrera viva).
func poza_libre(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or not Lanzador3D.es_agua(c):
		return false
	if Terreno3D.celda_solida(c, 0):
		return false
	var l: Lanzador3D = lanzador()
	return l == null or l.solidez_en(Vector3(_centro_agua(c).x, Terreno3D.alto_suelo + 0.8, _centro_agua(c).z)) == null


func pozas_libres() -> Array[Vector2i]:
	var libres: Array[Vector2i] = []
	for c in pozas:
		if poza_libre(c):
			libres.append(c)
	return libres


func _elegir_poza() -> void:
	var libres: Array[Vector2i] = pozas_libres()
	if libres.is_empty():
		_salir_por(bajio, true)
		return
	var candidatas: Array[Vector2i] = []
	for c in libres:
		if c != _ultima:
			candidatas.append(c)
	if candidatas.is_empty():
		candidatas = libres
	_salir_por(candidatas[_rng.randi() % candidatas.size()], false)


func _salir_por(c: Vector2i, por_bajio: bool) -> void:
	celda = c
	_ultima = c
	_por_bajio = por_bajio
	ultimo_emerger = c
	position = _centro_agua(c)
	_mirar_a_la_jugadora(true)
	emergencias += 1
	PlayLog.event("coca_emerge", {"celda": [c.x, c.y], "bajio": por_bajio})
	emerge.emit(c)
	_cambiar(Fase.EMERGE)


## Gira la raíz hacia la jugadora (de golpe si `de_golpe`, o a lo sumo GIRO_RAD_S) y deja `dir` al día.
func _mirar_a_la_jugadora(de_golpe: bool, delta: float = 0.0) -> void:
	var j: Node3D = jugadora()
	if j != null:
		var rel: Vector3 = j.global_position - global_position
		rel.y = 0.0
		if rel.length() > 0.1:
			var objetivo: float = atan2(rel.x, rel.z)
			var d: float = angle_difference(rotation.y, objetivo)
			rotation.y = objetivo if de_golpe else rotation.y + clampf(d, -GIRO_RAD_S * delta, GIRO_RAD_S * delta)
	dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y))


func _girar(delta: float) -> void:
	_mirar_a_la_jugadora(false, delta)


func _empezar_pose() -> void:
	dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y))      # se fija: en la pose y el chorro no gira
	_largo_u = _largo_chorro()
	_cambiar(Fase.POSE)
	_quitar_aviso()
	if _largo_u > 0.2 and is_inside_tree() and get_parent() != null:
		_aviso = AvisoAtaque3D.rectangulo(get_parent(), global_position, dir, _largo_u, ANCHO_CHORRO, POSE_S, self, 0.0)


func _empezar_chorro() -> void:
	# El aviso acaba solo en su instante (se guarda por si hay que quitarlo antes: `_cambiar` lo cancela al salir de CHORRO).
	_largo_u = _largo_chorro()                                 # por si ha aparecido (o ha caído) un sólido durante la pose
	_cambiar(Fase.CHORRO)
	chorros += 1
	_dibujar_chorro()
	_golpear_con_chorro()
	_temblar(TEMBLOR_CHORRO)
	PlayLog.event("coca_chorro", {"largo": snappedf(_largo_u, 0.01)})
	chorro.emit()


## ¿Hay algo sólido en `c` (donde el punto `p`) que pare el chorro? Pared, árbol, tierra apilada o una barrera viva de la jugadora.
func _solido_en(c: Vector2i, p: Vector3) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.celda_solida(c, 0):
		return true
	var l: Lanzador3D = lanzador()
	return l != null and l.solidez_en(Vector3(p.x, Terreno3D.alto_suelo + 0.8, p.z)) != null


## Largo (u) del chorro desde ella: ALCANCE_CHORRO_CASILLAS, recortado donde entra en la primera casilla sólida de la línea.
func _largo_chorro() -> float:
	var maximo: float = ALCANCE_CHORRO_CASILLAS * Terreno3D.casilla
	var paso: float = Terreno3D.casilla * 0.25
	var propia: Vector2i = Terreno3D.celda_de(global_position)
	var s: float = paso
	while s <= maximo:
		var p: Vector3 = global_position + dir * s
		var c: Vector2i = Terreno3D.celda_de(p)
		if c != propia and _solido_en(c, p):
			return maxf(s - paso, 0.0)
		s += paso
	return maximo


## Al empezar el chorro: si la jugadora está en el rectángulo (y no hay sólido por medio: el largo ya viene recortado), la hiere y la aparta. La voltereta la libra (`recibir_dano`).
func _golpear_con_chorro() -> void:
	var j: Node3D = jugadora()
	if j == null or bool(j.get("muerto")):
		return
	var rel: Vector3 = j.global_position - global_position
	rel.y = 0.0
	var lado: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	var a: float = rel.dot(dir)
	var l: float = rel.dot(lado)
	if a < 0.0 or a > _largo_u or absf(l) > ANCHO_CHORRO + RADIO_JUGADORA:
		return
	var vida0: float = float(j.get("vida"))
	if j.has_method("recibir_dano"):
		j.call("recibir_dano", DANO_CHORRO, global_position)
	if float(j.get("vida")) < vida0:
		golpes_jugadora += 1
		if j.has_method("push"):
			j.call("push", (dir + lado * signf(l) * 0.3).normalized(), EMPUJE_JUGADORA)


# ---------------------------------------------------------------------------------------------------------------------
#  Hechizos
# ---------------------------------------------------------------------------------------------------------------------

## Solo varada recibe daño (de cualquier elemento, ×1); en cualquier otra fase, golpe sordo y «Escamas». Sumergida y calmada no reaccionan.
func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if fase == Fase.SUMERGIDA or fase == Fase.CALMA:
		return
	if fase != Fase.VARADA:
		golpes_sin_efecto += 1
		Sensacion3D.golpe_sordo(self)
		if golpes_sin_efecto % 3 == 1:
			Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.4, 0), "Escamas", Contacto.COLOR_INEFICAZ, 0.9)
		return
	var d: float = hechizo.dano if hechizo != null else 0.0
	if d <= 0.0 and rune_data != null and rune_data.get("damage") != null:
		d = float(rune_data.get("damage"))
	golpes_dano += 1
	_destello = 0.1
	recibir(d)


func recibir(d: float) -> void:
	if d <= 0.0 or fase == Fase.CALMA:
		return
	vida = maxf(vida - d, 0.0)
	Combate3D.flotante(get_parent(), global_position + Vector3(0, 2.6, 0), str(int(round(d))), COLOR_DANO, 1.1)
	if vida <= 0.0:
		_calmar()


## Vida a 0: no muere. Se yergue, la runa da media vuelta y se queda encendida; deja de atacar y de reaccionar.
func _calmar() -> void:
	_quitar_aviso()
	calmada_ya = true
	_cambiar(Fase.CALMA)
	_temblar(0.3)
	PlayLog.event("coca_calmada", {})
	calmada.emit()


## G1 (morir y reintentar): vuelve al principio, entera y sumergida. Calmada, se queda calmada.
func reiniciar() -> void:
	if fase == Fase.CALMA:
		return
	_quitar_aviso()
	position = casa
	celda = pozas[0] if not pozas.is_empty() else bajio
	vida = vida_max
	_ultima = Vector2i(-9999, -9999)
	_por_bajio = false
	_runa_enciende = false
	_runa_luz = 0.0
	reinicios += 1
	_cambiar(Fase.SUMERGIDA)


func _quitar_aviso() -> void:
	if _aviso != null and is_instance_valid(_aviso):
		_aviso.cancelar()
	_aviso = null


func _quitar_chorro() -> void:
	if _chorro_mesh != null and is_instance_valid(_chorro_mesh):
		_chorro_mesh.queue_free()
	_chorro_mesh = null


func _temblar(intensidad: float) -> void:
	var fx: Variant = _mundo.get("_fx") if _mundo != null else null
	if fx is Vfx3D:
		(fx as Vfx3D).temblor(intensidad)


# ---------------------------------------------------------------------------------------------------------------------
#  Poses y dibujo (primitivas: una cadena de esferas sobre una Bézier cúbica)
# ---------------------------------------------------------------------------------------------------------------------

func _poner_pose(nombre: String) -> void:
	_pose.clear()
	for p in (POSES[nombre] as Array):
		_pose.append(p as Vector3)
	_pose_desde = _pose.duplicate()
	_pose_hasta = _pose.duplicate()
	_pose_t = 1.0
	_pose_dur = 0.001


## Cambiar de pose: interpola los 4 puntos desde la que se dibuja ahora hasta la de `nombre`, en `dur` s.
func _pose_hacia(nombre: String, dur: float, suave: int = Suave.SUAVE) -> void:
	_pose_desde = _pose.duplicate()
	_pose_hasta.clear()
	for p in (POSES[nombre] as Array):
		_pose_hasta.append(p as Vector3)
	_pose_dur = maxf(dur, 0.001)
	_pose_t = 0.0
	_pose_suave = suave


static func _suavizar(k: float, tipo: int) -> float:
	k = clampf(k, 0.0, 1.0)
	if tipo == Suave.REBOTE:
		var c1: float = 1.70158
		var c3: float = c1 + 1.0
		return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)      # ease out back
	return k * k * (3.0 - 2.0 * k)


static func bezier(p: Array, t: float) -> Vector3:
	var u: float = 1.0 - t
	return (p[0] as Vector3) * (u * u * u) + (p[1] as Vector3) * (3.0 * u * u * t) + (p[2] as Vector3) * (3.0 * u * t * t) + (p[3] as Vector3) * (t * t * t)


static func tangente(p: Array, t: float) -> Vector3:
	var u: float = 1.0 - t
	return ((p[1] as Vector3) - (p[0] as Vector3)) * (3.0 * u * u) + ((p[2] as Vector3) - (p[1] as Vector3)) * (6.0 * u * t) + ((p[3] as Vector3) - (p[2] as Vector3)) * (3.0 * t * t)


func _caja(nombre: String, tam: Vector3, pos: Vector3, mat: Material, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	padre.add_child(mi)
	return mi


func _esfera(nombre: String, radio: float, mat: Material, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var sm := SphereMesh.new()
	sm.radius = radio
	sm.height = radio * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	padre.add_child(mi)
	return mi


func _construir() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Raiz"
	add_child(_raiz)
	_mat_cuerpo = StandardMaterial3D.new()
	_mat_cuerpo.albedo_color = COLOR_TURQUESA
	_mat_cuerpo.roughness = 0.45
	var crema := StandardMaterial3D.new()
	crema.albedo_color = COLOR_CREMA
	crema.roughness = 0.8
	_mat_runa = StandardMaterial3D.new()
	_mat_runa.albedo_color = COLOR_RUNA_APAGADA
	_mat_runa.roughness = 0.6
	_mat_runa.emission_enabled = true
	_mat_runa.emission = COLOR_AMBAR
	_mat_runa.emission_energy_multiplier = 0.0
	# El cuello: SEGMENTOS esferas, de RADIO_BASE a RADIO_PUNTA.
	for i in range(SEGMENTOS):
		var r: float = lerpf(RADIO_BASE, RADIO_PUNTA, float(i) / float(SEGMENTOS - 1))
		_segmentos.append(_esfera("Segmento%d" % i, r, _mat_cuerpo, _raiz))
	# La cabeza: caja turquesa alargada, mandíbula crema que se abre, tres cajas finas de cresta y la runa en la frente.
	_cabeza = Node3D.new()
	_cabeza.name = "Cabeza"
	_raiz.add_child(_cabeza)
	_caja("Craneo", Vector3(0.55, 0.4, 1.0), Vector3(0.0, 0.0, 0.4), _mat_cuerpo, _cabeza)
	_mandibula = Node3D.new()
	_mandibula.name = "Mandibula"
	_mandibula.position = Vector3(0.0, -0.2, 0.0)
	_cabeza.add_child(_mandibula)
	_caja("MandibulaCaja", Vector3(0.45, 0.12, 0.85), Vector3(0.0, 0.0, 0.45), crema, _mandibula)
	for k in range(3):
		var cr: MeshInstance3D = _caja("Cresta%d" % k, Vector3(0.06, 0.34, 0.16), Vector3(0.0, 0.3, 0.05 + 0.25 * float(k)), _mat_cuerpo, _cabeza)
		cr.rotation.x = -0.35
	# La runa (ᛃ Jera, a grandes rasgos): un parche crema en la frente con dos trazos que son su material propio, oscuro apagado y emisivo ámbar encendido.
	_runa = Node3D.new()
	_runa.name = "Runa"
	_runa.position = Vector3(0.0, 0.21, 0.55)
	_runa.rotation.x = -PI * 0.5                                  # el quad mira hacia arriba
	_cabeza.add_child(_runa)
	var parche := MeshInstance3D.new()
	parche.name = "Parche"
	var qp := QuadMesh.new()
	qp.size = Vector2(0.3, 0.3)
	parche.mesh = qp
	parche.material_override = crema
	_runa.add_child(parche)
	_runa_giro = Node3D.new()
	_runa_giro.name = "Giro"
	_runa_giro.position = Vector3(0.0, 0.0, 0.005)
	_runa.add_child(_runa_giro)
	for lado in [-1.0, 1.0]:
		var trazo := MeshInstance3D.new()
		trazo.name = "Trazo"
		var qt := QuadMesh.new()
		qt.size = Vector2(0.05, 0.2)
		trazo.mesh = qt
		trazo.material_override = _mat_runa
		trazo.position = Vector3(0.05 * float(lado), 0.045 * float(lado), 0.0)
		trazo.rotation.z = 0.45
		_runa_giro.add_child(trazo)
	# Dos arcos de cuerpo detrás de la poza (5 esferas en semicírculo cada uno): suben y bajan con desfase y se hunden con ella.
	for k in range(2):
		var arco := Node3D.new()
		arco.name = "Arco%d" % k
		_raiz.add_child(arco)
		var zc: float = -2.4 - 2.2 * float(k)
		for j in range(5):
			var a: float = PI * float(j) / 4.0
			var e: MeshInstance3D = _esfera("Lomo%d" % j, 0.34, _mat_cuerpo, arco)
			e.position = Vector3(0.0, 0.9 * sin(a) - 0.2, zc + 0.9 * cos(a))
		_arcos.append(arco)
	# El cuerpo que recibe los hechizos.
	_cuerpo = CuerpoCoca.new()
	_cuerpo.name = "Cuerpo"
	add_child(_cuerpo)
	_cuerpo.montar(self)
	_forma = CollisionShape3D.new()
	_forma.shape = BoxShape3D.new()
	_cuerpo.add_child(_forma)
	_ajustar_cuerpo()


## La caja de los hechizos: alrededor del cuello erguido; varada, alargada hacia delante cubriendo el cuello tendido. Sumergida y calmada no reaccionan.
func _ajustar_cuerpo() -> void:
	if _cuerpo == null:
		return
	var caja: BoxShape3D = _forma.shape as BoxShape3D
	if fase == Fase.VARADA:
		caja.size = Vector3(1.4, 1.3, 4.0)
		_forma.position = Vector3(0.0, 0.45, 1.6)
	else:
		caja.size = Vector3(1.4, 3.0, 1.6)
		_forma.position = Vector3(0.0, 1.3, 0.1)
	_cuerpo.collision_layer = 0 if (fase == Fase.SUMERGIDA or fase == Fase.CALMA) else Lanzador3D.CAPA_REACTIVO


func _animar(delta: float) -> void:
	if _raiz == null:
		return
	# La pose hacia la que va.
	_pose_t = minf(_pose_t + delta, _pose_dur)
	var k: float = _suavizar(_pose_t / _pose_dur, _pose_suave)
	for i in range(4):
		_pose[i] = _pose_desde[i].lerp(_pose_hasta[i], k)
	# Lo que asoma del agua, la luz de la runa, la boca y la onda.
	var objetivo_fuera: float = 0.0 if (fase == Fase.SUMERGIDA or fase == Fase.HUNDE) else 1.0
	_k_fuera = move_toward(_k_fuera, objetivo_fuera, delta / maxf(EMERGE_S if objetivo_fuera > _k_fuera else HUNDE_S, 0.05))
	_runa_luz = move_toward(_runa_luz, 1.0 if _runa_enciende else 0.0, delta * 3.0)
	var abre: float = 0.55 if fase == Fase.CHORRO else (0.12 if fase == Fase.VARADA else 0.0)
	_apertura = move_toward(_apertura, abre, delta * 4.0)
	_amp = move_toward(_amp, 0.3 if fase == Fase.VARADA else 1.0, delta * 3.0)
	_runa_giro.rotation.z = PI * clampf(_t / T_CALMA, 0.0, 1.0) if fase == Fase.CALMA else 0.0     # en CALMA da media vuelta y se queda así
	_dibujar(delta)
	_colocar_chorro()
	_animar_marcas(delta)


## Coloca el cuello, la cabeza, los arcos y la runa según la pose actual y el reloj.
func _dibujar(_delta: float) -> void:
	if _raiz == null:
		return
	var visible_cuello: bool = fase != Fase.SUMERGIDA
	for i in range(SEGMENTOS):
		var t: float = float(i) / float(SEGMENTOS)
		var p: Vector3 = bezier(_pose, t)
		p.x += 0.08 * t * sin(_tiempo * 2.0 - t * 4.0) * _amp
		_segmentos[i].position = p
		_segmentos[i].visible = visible_cuello
	var pc: Vector3 = bezier(_pose, 1.0)
	pc.x += 0.08 * sin(_tiempo * 2.0 - 4.0) * _amp
	var tg: Vector3 = tangente(_pose, 1.0)
	_cabeza.position = pc
	_cabeza.visible = visible_cuello
	if tg.length() > 0.001:
		var z: Vector3 = tg.normalized()
		var ref: Vector3 = Vector3.UP if absf(z.dot(Vector3.UP)) < 0.98 else Vector3.BACK
		var x: Vector3 = ref.cross(z).normalized()
		_cabeza.basis = Basis(x, z.cross(x), z)
	_mandibula.rotation.x = _apertura
	_mat_runa.albedo_color = COLOR_RUNA_APAGADA.lerp(COLOR_AMBAR, _runa_luz)
	_mat_runa.emission_energy_multiplier = 3.0 * _runa_luz
	_mat_cuerpo.emission_enabled = _destello > 0.0
	_mat_cuerpo.emission = Color.WHITE
	_mat_cuerpo.emission_energy_multiplier = 1.5
	for n in range(_arcos.size()):
		var arco: Node3D = _arcos[n]
		arco.visible = _k_fuera > 0.01
		arco.position.y = 0.15 * sin(_tiempo * 1.8 + float(n) * 2.1) - (1.0 - _k_fuera) * 2.5


## El chorro: una caja azul claro semitransparente desde la boca hasta el primer sólido (o el alcance).
func _dibujar_chorro() -> void:
	_quitar_chorro()
	_chorro_mesh = MeshInstance3D.new()
	_chorro_mesh.name = "Chorro"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.45, 1.0)
	_chorro_mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CHORRO
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.2
	_chorro_mesh.material_override = mat
	add_child(_chorro_mesh)
	_colocar_chorro()


## La punta de la boca (local de la Coca): el morro del cráneo (centrado en z 0,4 y largo 1,0, así que acaba en 0,9), un poco por debajo del eje de la cabeza.
func punta_boca() -> Vector3:
	return _cabeza.position + _cabeza.basis * Vector3(0.0, -0.05, PUNTA_CABEZA_Z)


## Coloca la caja del chorro: arranca en la punta de la boca (la cabeza se mueve los primeros 0,15 s, así que se recoloca cada fotograma) y sigue la dirección HORIZONTAL del aviso (+Z local = `dir`),
## hasta `_largo_u` desde la poza (donde acaba el rectángulo), con una ligera caída desde la altura de la boca hasta el suelo.
func _colocar_chorro() -> void:
	if _chorro_mesh == null or not is_instance_valid(_chorro_mesh):
		return
	var boca: Vector3 = punta_boca()
	var y_suelo: float = Terreno3D.alto_suelo - position.y + 0.3                 # un poco por encima del suelo (la poza está más baja que la orilla)
	var fin: Vector3 = Vector3(boca.x, minf(boca.y, y_suelo), maxf(_largo_u, boca.z + 0.5))
	var largo: float = boca.distance_to(fin)
	_chorro_mesh.visible = largo >= 0.2
	(_chorro_mesh.mesh as BoxMesh).size = Vector3(0.6, 0.45, maxf(largo, 0.2))
	_chorro_mesh.transform = Transform3D(Basis.looking_at(fin - boca, Vector3.UP), (boca + fin) * 0.5)


# ---------------------------------------------------------------------------------------------------------------------
#  Marca de las pozas (primitivas): un anillo de piedras claras y, si la poza está libre, unas burbujas que suben y bajan. El bajío no lleva marca.
# ---------------------------------------------------------------------------------------------------------------------

const PIEDRAS_POR_POZA: int = 6
const RADIO_ANILLO: float = 1.15                    ## casi el borde de la casilla (2,3 u)
const BURBUJAS_POR_POZA: int = 3
const COLOR_PIEDRA: Color = Color(0.80, 0.78, 0.70)
const COLOR_BURBUJA: Color = Color(0.75, 0.93, 1.0, 0.6)


func _construir_marcas() -> void:
	if _marcas_raiz != null:
		return
	_marcas_raiz = Node3D.new()
	_marcas_raiz.name = "MarcasPozas"
	_marcas_raiz.top_level = true                                  # coordenadas del mundo: la Coca cambia de poza y no las arrastra
	add_child(_marcas_raiz)
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = COLOR_PIEDRA
	piedra.roughness = 0.9
	var burbuja := StandardMaterial3D.new()
	burbuja.albedo_color = COLOR_BURBUJA
	burbuja.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burbuja.roughness = 0.1
	burbuja.emission_enabled = true
	burbuja.emission = Color(0.6, 0.85, 1.0)
	burbuja.emission_energy_multiplier = 0.4
	for c in pozas:
		if not Terreno3D.en_mapa(c):
			continue
		var centro: Vector3 = _centro_agua(c)
		var anillo := Node3D.new()
		anillo.name = "Poza_%d_%d" % [c.x, c.y]
		_marcas_raiz.add_child(anillo)
		for k in range(PIEDRAS_POR_POZA):
			var a: float = TAU * float(k) / float(PIEDRAS_POR_POZA) + 0.3
			var tam: Vector3 = Vector3(0.42, 0.24, 0.32) * (0.85 + 0.3 * float((k * 7) % 5) / 4.0)
			var p: Vector3 = Vector3(centro.x + cos(a) * RADIO_ANILLO, centro.y + tam.y * 0.3, centro.z + sin(a) * RADIO_ANILLO)
			var mi: MeshInstance3D = _caja("Piedra%d" % k, tam, p, piedra, anillo)
			mi.rotation.y = a * 1.7
		var bs := Node3D.new()
		bs.name = "Burbujas"
		anillo.add_child(bs)
		for k in range(BURBUJAS_POR_POZA):
			var b: MeshInstance3D = _esfera("Burbuja%d" % k, 0.08 + 0.02 * float(k % 2), burbuja, bs)
			b.set_meta("base", centro + Vector3(cos(float(k) * 2.4 + 0.5) * 0.45, 0.0, sin(float(k) * 2.4 + 0.5) * 0.45))
			b.set_meta("fase", float(k) * 2.1)
		_burbujas[c] = bs


## Las burbujas suben y bajan; solo se ven en las pozas libres (sin sólido encima y sin la Coca en ella). El estado se mira cada 0,15 s.
func _animar_marcas(delta: float) -> void:
	if _marcas_raiz == null:
		return
	_t_marcas -= delta
	if _t_marcas <= 0.0:
		_t_marcas = 0.15
		for c in _burbujas.keys():
			(_burbujas[c] as Node3D).visible = poza_libre(c) and not ocupa(c)
	for c in _burbujas.keys():
		var bs: Node3D = _burbujas[c]
		if not bs.visible:
			continue
		for b in bs.get_children():
			var base: Vector3 = b.get_meta("base")
			var s: float = 0.5 + 0.5 * sin(_tiempo * 2.2 + float(b.get_meta("fase")))
			(b as Node3D).position = base + Vector3(0.0, 0.08 + 0.35 * s, 0.0)
