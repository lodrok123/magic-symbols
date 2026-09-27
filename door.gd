class_name Door
extends Area2D

## LA PUERTA: la cerradura que le faltaba a la llave.
##
## Se abre con corriente y se cierra sola. NO es un interruptor que se
## queda puesto, y la diferencia importa: un interruptor convierte el
## puzle en una casilla que marcas y te olvidas, mientras que una puerta
## con reloj te obliga a resolver el circuito DESDE DONDE PUEDAS CRUZARLO
## a tiempo. El problema deja de ser "cómo la abro" y pasa a ser "desde
## dónde la abro", que es una pregunta mucho mejor.
##
## OJO CON LA TENTACIÓN DE HACERLA "LA PUERTA DEL RAYO". No lo es: la
## puerta no sabe qué es el rayo, sabe que le ha llegado corriente. Si
## mañana hay un generador, una trampa de presión o un enemigo que suelta
## chispas al morir, abrirán esta puerta sin tocar este archivo. Una
## cerradura de una sola llave sería justo lo contrario de lo que hace el
## resto del juego.

const LIGHTNING_RUNE: RuneData = preload("res://lightning_rune.tres")

## Lo que aguanta abierta. Es el mando de dificultad de cualquier puzle
## que la use: con 4 s se cruza desde la orilla de enfrente si no te
## entretienes, y no da para ir a buscar nada.
const OPEN_TIME: float = 4.0

var is_open: bool = false
var close_timer: float = 0.0

var visual: Sprite2D = null
var solido: StaticBody2D = null


func _ready() -> void:
	add_to_group(Circuit.GROUP)

	visual = Sprite2D.new()
	add_child(visual)

	var deteccion := CollisionShape2D.new()
	deteccion.shape = IsoGrid.diamond()
	add_child(deteccion)

	_apply()


func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if not Circuit.is_current(rune_data):
		return

	# Abierta y le vuelve a llegar corriente: NO se reabre, se le renueva
	# el plazo. Así mantener el circuito vivo mantiene la puerta abierta,
	# que es la lectura natural, y de paso no se reinicia la animación
	# delante de quien está cruzando.
	close_timer = OPEN_TIME

	if is_open:
		return

	is_open = true
	_apply()
	BlockFx.burst(self, "chispas")
	Sfx.play(self, "puerta_abre")
	Glow.flash(self, Glow.LUZ_RAYO, 170.0, 1.8, 0.6)
	print("La puerta se abre.")

	# La puerta NO propaga. Es el final del cable: si pasara corriente,
	# una puerta pegada a otra las abriría en cadena y el circuito dejaría
	# de tener forma. Quien quiera encadenar, que ponga conductores.


func _process(delta: float) -> void:
	if not is_open:
		return

	close_timer -= delta
	if close_timer <= 0.0:
		is_open = false
		_apply()
		Sfx.play(self, "puerta_cierra")
		print("La puerta se cierra.")


## Abierta o cerrada son DOS TEXTURAS del pack, no un tinte ni un nodo
## escondido: un arco abierto y un portón cerrado se leen de reojo, que
## es como se van a mirar mientras corres hacia ella.
##
## El cuerpo sólido se crea y se destruye entero en vez de deshabilitar
## su forma, igual que en los adornos: una puerta abierta no es "una
## puerta con la colisión apagada", es otra cosa.
func _apply() -> void:
	visual.texture = load("res://art/door_open.png" if is_open
		else "res://art/door_closed.png")

	if solido:
		solido.queue_free()
		solido = null

	if is_open:
		return

	solido = StaticBody2D.new()
	var forma := CollisionShape2D.new()
	# Casi la casilla entera: una puerta que se puede bordear en diagonal
	# no es una puerta. Es la excepción a la regla de los adornos, y por
	# eso se dice aquí en voz alta.
	forma.shape = IsoGrid.footprint(0.95)
	solido.add_child(forma)
	add_child(solido)


static func make() -> Door:
	var p := Door.new()
	p.y_sort_enabled = true
	return p
