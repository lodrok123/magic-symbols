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
	if String(resultado.get("efecto", "")) in ["humo", "baba", "cebo"]:
		_queda(String(resultado["efecto"]))
		return
	queue_free()


## 11/11: humo, baba y cebo se quedan a la vista lo que dura su efecto (sin arte propio todavía: formas sencillas del color del objeto).
func _queda(tipo: String) -> void:
	var bola: Node3D = get_node_or_null("bola") as Node3D
	if bola != null:
		bola.visible = tipo == "cebo"
		bola.position.y = RADIO_BOLA
	var dura: float = float(Objetos.efecto(objeto).get("dura", 4.0))
	var col: Color = Objetos.color(objeto)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, 0.55 if tipo == "humo" else 0.7)
	var mi := MeshInstance3D.new()
	mi.name = "efecto"
	mi.material_override = m
	if tipo == "humo":
		var esfera := SphereMesh.new()
		var r: float = float(Objetos.efecto(objeto).get("radio", 2.0)) * Terreno3D.casilla * 0.55
		esfera.radius = r
		esfera.height = r * 1.4
		mi.mesh = esfera
		mi.position.y = r * 0.5
		mi.scale = Vector3.ONE * 0.3
		var tw: Tween = create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(dura - 1.3, 0.1))
		tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
	elif tipo == "baba":
		var disco := CylinderMesh.new()
		disco.top_radius = Terreno3D.casilla * 1.3
		disco.bottom_radius = disco.top_radius
		disco.height = 0.04
		mi.mesh = disco
		mi.position.y = 0.03
		var tw2: Tween = create_tween()
		tw2.tween_interval(maxf(dura - 0.8, 0.1))
		tw2.tween_property(m, "albedo_color:a", 0.0, 0.8)
	else:
		mi.visible = false                       # el cebo: basta la bola en el suelo
	add_child(mi)
	get_tree().create_timer(dura, false).timeout.connect(queue_free)
