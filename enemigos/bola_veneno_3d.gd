class_name BolaVeneno3D
extends Node3D

## LA BOLA DE VENENO DEL CHAMÁN (28/10; Pablo: ataque propio a distancia con el bastón, legible como la flecha del arquero): sale del orbe, va por un ARCO hasta donde estaba la jugadora
## al soltarla (tarda en llegar: si se mueve, falla) y estalla en un charco verde. Antes de salir marca en el suelo dónde va a caer (C3, `AvisoAtaque3D.circulo`, el mismo radio con el que luego
## comprueba el daño), y rodar en la ventana del aviso da el tiempo bruja (C4). Daño pequeño al caer (DANO) y VENENO (`Jugador3D.envenenar`: VENENO_DPS por segundo durante VENENO_S s, sin
## empuje ni invulnerabilidad). La burbuja del lanzador la para en el aire como a la flecha.
## F4 (29/10): al estallar deja además una NUBE DE VENENO (`NubeVeneno3D`, `T_NUBE` s, el mismo radio que el charco) que envenena a quien se quede dentro y se deja empujar por el viento o quemar por el fuego.

signal impacto(acerto: bool)

const DANO: float = 6.0
const VENENO_DPS: float = 3.0
const VENENO_S: float = 3.0
const RADIO: float = 0.9                       ## u: lo que cubre el charco (y el aviso)
const VEL: float = 5.0                         ## u/s a lo largo del tiro
const T_MIN: float = AvisoAtaque3D.T_MIN + 0.2 ## s mínimos de vuelo (que el aviso se lea)
const ALTURA_ARCO: float = 0.22                ## el arco sube esto × la distancia (máx ALTURA_ARCO_MAX)
const ALTURA_ARCO_MAX: float = 1.6
const COLOR: Color = Color(0.55, 0.92, 0.3)
const T_CHARCO: float = 0.7
const T_NUBE: float = 3.0                      ## s que dura la nube que deja

var dueno: Node3D = null
var jugador: Jugador3D = null
var lanz: Lanzador3D = null
var origen: Vector3 = Vector3.ZERO
var destino: Vector3 = Vector3.ZERO             ## donde cae (a ras del suelo de la jugadora)
var t_vuelo: float = 1.0
var t: float = 0.0
var aviso: AvisoAtaque3D = null
var parada: bool = false
var llego: bool = false
var acerto: bool = false
var _malla: MeshInstance3D = null
var _luz: OmniLight3D = null


## Lanza una bola de `p_origen` a `p_destino` (mundo). `p_dueno` = el chamán; devuelve la bola.
static func lanzar(en: Node, p_origen: Vector3, p_destino: Vector3, p_dueno: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D = null) -> BolaVeneno3D:
	var b := BolaVeneno3D.new()
	b.name = "BolaVeneno"
	b.dueno = p_dueno
	b.jugador = p_jugador
	b.lanz = p_lanz
	b.origen = p_origen
	b.destino = p_destino
	b.t_vuelo = maxf(p_origen.distance_to(p_destino) / VEL, T_MIN)
	en.add_child(b)
	b.global_position = p_origen
	b._construir()
	b.aviso = AvisoAtaque3D.circulo(en, Vector3(p_destino.x, p_destino.y, p_destino.z), RADIO, b.t_vuelo, p_dueno)
	return b


func _construir() -> void:
	var esf := SphereMesh.new()
	esf.radius = 0.11
	esf.height = 0.22
	esf.radial_segments = 14
	esf.rings = 7
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR
	m.emission_enabled = true
	m.emission = COLOR
	m.emission_energy_multiplier = 2.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_malla = MeshInstance3D.new()
	_malla.mesh = esf
	_malla.material_override = m
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)
	_luz = OmniLight3D.new()
	_luz.light_color = COLOR
	_luz.light_energy = 1.2
	_luz.omni_range = 2.0
	_luz.shadow_enabled = false
	add_child(_luz)


## Punto del arco a la fracción `k` (0..1).
func punto_en(k: float) -> Vector3:
	var p: Vector3 = origen.lerp(destino, k)
	var h: float = minf(ALTURA_ARCO * origen.distance_to(destino), ALTURA_ARCO_MAX)
	p.y += 4.0 * h * k * (1.0 - k)
	return p


func _physics_process(delta: float) -> void:
	if llego:
		return
	t += delta
	var k: float = clampf(t / t_vuelo, 0.0, 1.0)
	var p: Vector3 = punto_en(k)
	global_position = p
	if lanz != null and is_instance_valid(lanz) and k < 1.0:
		if lanz.burbuja_contiene(p):
			parada = true
			lanz.burbuja_recibe("", p, dueno as Combate3D)
			_terminar(false)
			return
	if k >= 1.0:
		_caer()


func _caer() -> void:
	llego = true
	if jugador != null and is_instance_valid(jugador) and not jugador.muerto:
		var d := Vector2(jugador.position.x - destino.x, jugador.position.z - destino.z)
		if d.length() <= RADIO and absf(jugador.position.y - destino.y) < Terreno3D.ALTO_NIVEL * 0.9:
			acerto = true
			jugador.recibir_dano(DANO, global_position)
			jugador.envenenar(VENENO_DPS, VENENO_S)
	PlayLog.event("bola_veneno", {"acierta": acerto})
	_dejar_nube()
	_terminar(true)


## F4: la nube cuelga del padre de la bola (la bola se libera al acabar el charco; la nube no).
func _dejar_nube() -> void:
	var padre: Node = get_parent()
	if padre == null:
		return
	NubeVeneno3D.crear(padre, Vector3(destino.x, destino.y, destino.z), T_NUBE, RADIO / Terreno3D.casilla, jugador)


func _terminar(charco: bool) -> void:
	llego = true
	if _malla != null:
		_malla.visible = false
	if _luz != null:
		_luz.visible = false
	if aviso != null and is_instance_valid(aviso) and parada:
		aviso.cancelar()
	if charco:
		_charco()
	impacto.emit(acerto)
	var tw: Tween = create_tween()
	tw.tween_interval(T_CHARCO + 0.1)
	tw.tween_callback(queue_free)


func _charco() -> void:
	var disco := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(RADIO * 2.0, RADIO * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	disco.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.7)
	disco.material_override = m
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disco)
	disco.top_level = true
	disco.global_position = Vector3(destino.x, destino.y + 0.06, destino.z)
	disco.scale = Vector3(0.4, 1, 0.4)
	var tw: Tween = disco.create_tween()
	tw.set_parallel(true)
	tw.tween_property(disco, "scale", Vector3.ONE, 0.2)
	tw.tween_property(m, "albedo_color:a", 0.0, T_CHARCO)
