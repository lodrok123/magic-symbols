class_name Lanzable3D
extends Node3D

## UN LANZABLE EN EL AIRE (10/11, Juego; ver `Lanzables`): una bola del color del objeto que vuela en arco de `desde` a `hasta` y, al llegar, llama a
## `Lanzables.aplicar` y se libera. El bulbo de luz deja además una luz visible `dura` s donde cae (la regla de la oscuridad es `Mundo3D.iluminar`; esta luz
## es solo para verla). Sin modelo propio todavía: cuando el Pipeline lo dibuje, la columna `modelo` de la tabla lo dirá.

const RADIO_BOLA: float = 0.13

signal aterrizo(resultado: Dictionary)      ## al caer, con lo que devolvió `Lanzables.aplicar` (el nodo se libera justo después)

var objeto: String = ""
var lanz: Node = null
var jugador: Node3D = null
var desde: Vector3 = Vector3.ZERO
var hasta: Vector3 = Vector3.ZERO
var resultado: Dictionary = {}       ## lo que devolvió `Lanzables.aplicar` (lo leen las pruebas)
var aterrizado: bool = false
var _t: float = 0.0
var _dura: float = 0.5


func _ready() -> void:
	position = desde
	var plano: float = Vector2(hasta.x - desde.x, hasta.z - desde.z).length()
	_dura = maxf(0.2, plano / Lanzables.VEL)
	var esfera := SphereMesh.new()
	esfera.radius = RADIO_BOLA
	esfera.height = RADIO_BOLA * 2.0
	esfera.radial_segments = 12
	esfera.rings = 6
	var m := StandardMaterial3D.new()
	var col: Color = Objetos.color(objeto)
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.6
	esfera.material = m
	var mi := MeshInstance3D.new()
	mi.name = "bola"
	mi.mesh = esfera
	add_child(mi)


func _process(delta: float) -> void:
	if aterrizado:
		return
	_t += delta
	var u: float = clampf(_t / _dura, 0.0, 1.0)
	var p: Vector3 = desde.lerp(hasta, u)
	p.y += 4.0 * Lanzables.ALTO_ARCO * u * (1.0 - u)
	position = p
	if u >= 1.0:
		aterrizar()


## Llega al suelo: aplica el efecto y se va (el bulbo de luz se queda como luz `dura` s).
func aterrizar() -> void:
	if aterrizado:
		return
	aterrizado = true
	position = hasta
	resultado = Lanzables.aplicar(get_tree(), lanz, jugador, objeto, hasta)
	aterrizo.emit(resultado)
	if String(resultado.get("efecto", "")) == "luz":
		var bola: Node3D = get_node_or_null("bola") as Node3D
		if bola != null:
			bola.position.y = RADIO_BOLA
		var luz := OmniLight3D.new()
		luz.light_color = Objetos.color(objeto)
		luz.light_energy = Lanzables.LUZ_ENERGIA
		luz.omni_range = Lanzables.LUZ_ALCANCE_CASILLAS * Terreno3D.casilla
		luz.position = Vector3(0.0, 0.6, 0.0)
		add_child(luz)
		var t: SceneTreeTimer = get_tree().create_timer(float(Objetos.efecto(objeto).get("dura", 60.0)), false)
		t.timeout.connect(queue_free)
		return
	queue_free()
