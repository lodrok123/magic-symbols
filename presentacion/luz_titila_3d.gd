class_name LuzTitila3D
extends Node
## La luz de un fuego que TITILA (bloque 1 de la revisión EoW, 23/10): energía y color que bailan con un ruido barato.
##
## POR QUÉ. Las `OmniLight3D` de llamas, braseros y fogatas tenían la energía fija: el fuego se movía y su luz no. En Echoes of Wisdom la luz de
## cada fuego anima energía y color, y es lo que hace que una sala con antorchas parezca viva (docs/estudios/eow/EOW_4_ASSETS.md §6.4).
##
## CÓMO. Un nodo hijo de la luz que, cada fotograma, multiplica `light_energy` por 1 ± `AMPLITUD` (tres senos de frecuencias que no se repiten,
## con una fase al azar por luz para que dos fuegos no titilen a la vez) y la acerca a un rojo más hondo cuando baja. Si alguien cambia la
## energía o el color de la luz por su cuenta (un tween que la apaga, `PiezaFuego3D._luz_calor`), lo detecta y lo toma como la nueva base: no se
## pelea con nadie. Sin luz padre, o con `activo = false`, no hace nada.
##
## Solo para fuegos que DURAN. Los destellos de un golpe (luces con tween que se apagan en décimas) no lo necesitan.
##
## Uso: `LuzTitila3D.aplicar(luz)` después de crearla (antes o después de meterla en el árbol).

static var activo: bool = true

const AMPLITUD: float = 0.18            ## cuánto sube y baja la energía (0,18 = ±18 %)
const ROJO_HONDO: Color = Color(1.0, 0.36, 0.12)
const VIRAJE_COLOR: float = 0.25        ## cuánto vira el color hacia ROJO_HONDO en el punto más bajo

var fuerza: float = 1.0
var _luz: OmniLight3D = null
var _t: float = 0.0
var _fase: Vector3 = Vector3.ZERO
var _base_energia: float = 0.0
var _base_color: Color = Color.WHITE
var _escrita_energia: float = -1.0
var _escrito_color: Color = Color(-1.0, -1.0, -1.0)


## Cuelga el titileo de `luz` y lo devuelve. `fuerza` escala la amplitud (0,5 = brasa tranquila, 1 = llama).
static func aplicar(luz: OmniLight3D, fuerza_titileo: float = 1.0) -> LuzTitila3D:
	var n := LuzTitila3D.new()
	n.name = "titila"
	n.fuerza = fuerza_titileo
	luz.add_child(n)
	return n


func _ready() -> void:
	_luz = get_parent() as OmniLight3D
	_fase = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_t = randf() * 10.0
	set_process(_luz != null)


func _process(delta: float) -> void:
	if not activo or _luz == null:
		return
	# Lo que haya puesto otro desde el último fotograma es la base nueva.
	if not is_equal_approx(_luz.light_energy, _escrita_energia):
		_base_energia = _luz.light_energy
	if not _luz.light_color.is_equal_approx(_escrito_color):
		_base_color = _luz.light_color
	_t += delta
	var n: float = sin(_t * 7.3 + _fase.x) * 0.5 + sin(_t * 13.1 + _fase.y) * 0.3 + sin(_t * 23.7 + _fase.z) * 0.2    # -1..1
	var f: float = 1.0 + AMPLITUD * fuerza * n
	_escrita_energia = _base_energia * f
	_escrito_color = _base_color.lerp(ROJO_HONDO, VIRAJE_COLOR * fuerza * maxf(-n, 0.0))
	_luz.light_energy = _escrita_energia
	_luz.light_color = _escrito_color
