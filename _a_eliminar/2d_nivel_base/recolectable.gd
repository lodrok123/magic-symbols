class_name Recolectable
extends Area2D

## UN ELEMENTO DEL ESCENARIO QUE SE PUEDE RECOGER (lavanda, bayas, helecho, flores, piedras...).
## Solo se recogen las cosas con sentido: una caja o un barril NO (eso no tiene lógica).
##
## Se coge con E estando cerca. Al cogerlo, el dibujo se apaga (queda un "mate") y vuelve a
## crecer pasado un rato. Por fuera tiene un brillo suave y un rótulo al acercarse.
## nivel_base.gd los crea a partir de los props del decorado (ver RECOGIBLES_PROP allí).

const RADIO: float = 85.0
const REBROTE: float = 45.0

var id: String = "lavanda"
var cantidad: int = 1
var sprite: Sprite2D = null           ## el dibujo del decorado que representa a la planta
var _listo: bool = true
var _t: float = 0.0
var _rotulo: float = 0.0


func _ready() -> void:
	add_to_group("recolectables")
	collision_layer = 0
	collision_mask = 0
	_t = randf() * TAU
	if sprite != null:
		Glow.attach(sprite.get_parent(), Objetos.color(id), 44.0, 0.18)


func listo() -> bool:
	return _listo


func _process(delta: float) -> void:
	_t += delta
	var jugador: Node = get_tree().get_first_node_in_group("player")
	var cerca: bool = _listo and jugador != null and (jugador as Node2D).global_position.distance_to(global_position) < RADIO
	_rotulo = move_toward(_rotulo, 1.0 if cerca else 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	if _rotulo <= 0.01:
		return
	var f: Font = ThemeDB.fallback_font
	var txt: String = "[E] " + Objetos.nombre(id)
	var ancho: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var y: float = -70.0 - 4.0 * sin(_t * 3.0)
	draw_rect(Rect2(-ancho * 0.5 - 6.0, y - 15.0, ancho + 12.0, 20.0), Color(0, 0, 0, 0.62 * _rotulo))
	draw_string(f, Vector2(-ancho * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, _rotulo))


## Lo coge el jugador. Devuelve si lo consiguió.
func intentar_coger(jugador: Node) -> bool:
	if not _listo:
		return false
	var entra: int = Estado.i().agregar(id, cantidad)
	if entra <= 0:
		CombateComun.flotante(self, global_position + Vector2(0, -50), "Mochila llena", Color(1, 0.5, 0.4))
		return false
	_listo = false
	Sonidos.play(self, "recoger", -8.0)
	CombateComun.flotante(self, global_position + Vector2(0, -50), "+%d %s" % [entra, Objetos.nombre(id)], Objetos.color(id).lightened(0.3))
	if jugador != null and jugador.has_method("recoger_anim"):
		jugador.call("recoger_anim")
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(0.45, 0.45, 0.45, 0.35), 0.25)
		tw.tween_interval(REBROTE)
		tw.tween_callback(func(): _listo = true)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.8)
	else:
		get_tree().create_timer(REBROTE).timeout.connect(func(): _listo = true)
	return true


## El recolectable listo más cercano al punto.
static func cercano(arbol: SceneTree, pos: Vector2) -> Recolectable:
	var mejor: Recolectable = null
	var dmin: float = RADIO
	for r in arbol.get_nodes_in_group("recolectables"):
		var rr := r as Recolectable
		if rr == null or not rr._listo:
			continue
		var d: float = pos.distance_to(rr.global_position)
		if d < dmin:
			dmin = d
			mejor = rr
	return mejor
