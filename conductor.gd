class_name Conductor
extends Area2D

## LA PLACA CONDUCTORA: un cable que se pisa.
##
## Es la pieza que le faltaba al rayo. Hasta ahora la corriente solo
## podía viajar por agua, y el agua está donde está el puzle la ponga;
## con esto la corriente se puede LLEVAR, que es lo que convierte al rayo
## de "daño en área" en una herramienta.
##
## No estorba y no es suelo: se planta encima de la losa que ya hubiera,
## igual que un adorno. Una placa metida en el suelo no debería cambiar
## por dónde se puede andar — lo único que cambia es por dónde pasa la
## corriente.
##
## Vive muy poco a propósito (Circuit.TIME). Un circuito que se queda
## encendido es un interruptor; uno que se apaga solo es una carrera, y
## eso es un puzle con reloj en vez de una casilla que se marca.

const LIGHTNING_RUNE: RuneData = preload("res://lightning_rune.tres")

const COLOR_APAGADO: Color = Color(1, 1, 1)
const COLOR_VIVO: Color = Color(1.5, 1.45, 0.7)

var is_live: bool = false

var visual: Sprite2D = null


func _ready() -> void:
	add_to_group(Circuit.GROUP)

	visual = Sprite2D.new()
	visual.texture = load("res://art/conductor.png")
	add_child(visual)

	var deteccion := CollisionShape2D.new()
	deteccion.shape = IsoGrid.diamond()
	add_child(deteccion)


func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if not Circuit.is_current(rune_data):
		return
	if is_live:
		# EL CORTAFUEGOS. Sin esto, dos placas contiguas se pasarían la
		# corriente la una a la otra sin parar. No hace falta contar
		# saltos ni llevar un registro: basta con que una placa ya viva
		# no vuelva a encenderse, y la onda se apaga sola en el borde.
		return

	_energize()


func _energize() -> void:
	is_live = true
	visual.modulate = COLOR_VIVO
	BlockFx.burst(self, "chispas")
	Sfx.play(self, "chispa")
	# La corriente se VE recorrer el cable: cada placa suelta su fogonazo
	# al encenderse, asi que a oscuras el circuito entero se lee de un
	# vistazo aunque dure medio segundo.
	Glow.flash(self, Glow.LUZ_RAYO, 150.0, 1.6, Circuit.TIME)

	# La placa también hiere a quien la pise, y no con un bucle sobre los
	# cuerpos que tiene encima: lanza el mismo hechizo quieto que lanza el
	# agua. Así el jugador, el enemigo y lo que se invente mañana reciben
	# el golpe por el camino de siempre, y la placa no necesita saber a
	# quién está achicharrando.
	SpellFactory.cast(self, global_position, Vector2.ZERO,
		LIGHTNING_RUNE, Circuit.TIME)

	Circuit.spread(self, LIGHTNING_RUNE)

	get_tree().create_timer(Circuit.TIME).timeout.connect(_calm_down)


func _calm_down() -> void:
	is_live = false
	if is_instance_valid(visual):
		visual.modulate = COLOR_APAGADO


## Se planta desde código, como los adornos: una placa es un script, una
## textura y un rombo. Una escena no añadiría nada que mantener, solo
## algo más que pueda quedarse descuadrado.
static func make() -> Conductor:
	var c := Conductor.new()
	c.y_sort_enabled = true
	return c
