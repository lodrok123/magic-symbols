class_name ActorAnimator
extends Node

## ANIMA A CUALQUIER COSA QUE SE MUEVA, SIN QUE ELLA SE ENTERE.
##
## Se cuelga como hijo de un actor (el jugador, un enemigo) y mira cómo
## cambia su posición. No le pide nada: si el nodo se movió, anda; si
## no, respira.
##
## Mirar el resultado en vez de pedir el aviso es lo que hace que el
## mismo componente valga para el jugador, para un enemigo o para una
## caja empujada por el viento. La alternativa —que cada script avise
## "ahora ando"— hay que repetirla y mantenerla en todos.
##
## Lo que NO se puede observar son los SUCESOS: "he empezado a lanzar"
## no se deduce de una posición. Para eso está play(). Y aun así, el
## golpe y la muerte SÍ se observan, escuchando la señal de vida que el
## jugador ya emitía para la barra.


## --- QUÉ MUEVE CADA CLIP ---
## Andar avanza con los PÍXELES RECORRIDOS; respirar, lanzar y morir
## avanzan con el RELOJ. No es un detalle: si el paso fuera por tiempo,
## los pies patinarían en cuanto cambiase la velocidad, y si el aliento
## fuera por distancia, el personaje dejaría de respirar al pararse.
enum Driver { DISTANCIA, RELOJ }

## Un clip es puro dato. Añadir "nadar" es una entrada más aquí.
class Clip:
	var sheet: Texture2D
	var columns: int
	var driver: int
	var fps: float          ## solo para los de reloj
	var loop: bool
	var hold_last: bool     ## al acabar, se queda en el último fotograma

	func _init(s: Texture2D, c: int, d: int, f: float = 10.0,
			l: bool = false, h: bool = false) -> void:
		sheet = s; columns = c; driver = d; fps = f; loop = l; hold_last = h


## El juego de clips del mago. Se monta aquí y no en la escena porque
## son datos fijos del personaje, no algo que se ajuste por instancia.
static func hero() -> ActorAnimator:
	var a := ActorAnimator.new()
	a.clips = {
		"walk":  Clip.new(preload("res://art/hero_walk.png"),  8, Driver.DISTANCIA, 0.0, true),
		"idle":  Clip.new(preload("res://art/hero_idle.png"),  4, Driver.RELOJ, 4.0, true),
		"cast":  Clip.new(preload("res://art/hero_cast.png"),  6, Driver.RELOJ, 14.0),
		"hurt":  Clip.new(preload("res://art/hero_hurt.png"),  3, Driver.RELOJ, 12.0),
		"death": Clip.new(preload("res://art/hero_death.png"), 6, Driver.RELOJ, 8.0, false, true),
	}
	return a


## LA MAGA PINTADA. Convive con hero() a propósito: cambiar de arte es
## cambiar qué función llama el nivel, y volver atrás es la misma línea.
##
## Todos los clips son de UNA columna porque por ahora solo hay un
## dibujo. El personaje no se mueve, pero está BIEN PUESTO —bien
## escalado, con los pies donde toca y girando de fila con la
## dirección—, que es lo que hace falta para juzgar el arte dentro del
## mundo. En cuanto lleguen fotogramas de verdad, esto son números.
static func rita() -> ActorAnimator:
	var a := ActorAnimator.new()
	a.cell = 128
	# CELL/2 - (CELL - PIES) con la figura pisando en y=118.
	#
	# La celda es de 128 y no de 96 aunque la figura de pie mida 78: al
	# MORIRSE el personaje acaba tumbado, y un cuerpo tendido es bajo pero
	# muy ancho. En 96 se salia por los lados.
	a.foot_offset = 54.0
	a.clips = {
		# 12 FOTOGRAMAS PARA UN ANDAR DE 7, y no es un error: la hoja
		# viene de ida y vuelta (0..6,5..1).
		#
		# Hizo falta porque el andar dibujado no ALTERNA las piernas.
		# Medido en la vista de perfil, el mismo pie iba delante en los
		# siete fotogramas y la zancada solo se abria, de 105 a 136 px:
		# eso es medio paso, y al repetirlo pegaba un tiron. De ida y
		# vuelta el salto al cerrar baja de ser el mayor del ciclo a 33.4,
		# que es exactamente la media — o sea, deja de notarse.
		#
		# Se lee como andar: el cuerpo sube y baja y las piernas se abren
		# y se cierran. Pero es un vaiven, no una marcha, y eso se arregla
		# dibujando: hacen falta fotogramas donde la pierna de atras PASE
		# a estar delante.
		"walk":  Clip.new(preload("res://art/rita_walk.png"), 12, Driver.DISTANCIA, 0.0, true),
		"idle":  Clip.new(preload("res://art/rita_idle.png"),  6, Driver.RELOJ, 6.0, true),
		# Ya con arte propio los tres.
		#
		# `hurt` sale de los tres primeros fotogramas de la muerte, y no es
		# un apaño: el principio de caerse ES recibir un golpe. Lo unico
		# que cambia es que aqui no se llega al final.
		"cast":  Clip.new(preload("res://art/rita_cast.png"),  6, Driver.RELOJ, 12.0),
		"hurt":  Clip.new(preload("res://art/rita_hurt.png"),  3, Driver.RELOJ, 12.0),
		"death": Clip.new(preload("res://art/rita_death.png"), 7, Driver.RELOJ, 8.0, false, true),
	}
	return a


## LA MAGA NUEVA, sacada de vídeo. Convive con las otras dos por lo de
## siempre: cambiar de arte es cambiar qué función llama el nivel.
##
## ANDAR ES DE VERDAD, y es la diferencia que importa frente a rita().
## Aquella hoja tenía 12 columnas para un andar de 7 porque el dibujo no
## alternaba las piernas y había que montarlo de ida y vuelta. Aquí los
## 12 fotogramas son 12 poses distintas de un ciclo completo, sacadas del
## tramo del vídeo que mejor cierra el bucle: al repetirse no pega tirón
## porque el salto de la última a la primera es MENOR que el de un paso
## normal. Eso se midió, no se estimó — ver tools/video_a_fila.py.
##
## LOS OTROS CUATRO CLIPS SON DE UNA COLUMNA, igual que estuvo rita al
## principio: del personaje nuevo solo hay vídeo de andar. No respira ni
## se cae, pero está bien puesta —bien escalada, pisando donde toca y
## girando con la dirección—, que es lo que hace falta para juzgarla
## dentro del mundo mientras llega el resto del arte. Cada una de esas
## hojas es el fotograma del ciclo con los pies más juntos, que es el que
## más se parece a estar de pie.
##
## FILAS SE Y SO PROVISIONALES: no hay vídeo de las diagonales de abajo y
## llevan la fila S. Se nota poco porque S es la vecina, pero está ahí.
static func maga() -> ActorAnimator:
	var a := ActorAnimator.new()
	a.cell = 128
	# La figura pisa en y=117 dentro de la celda, y 117 - 64 = 53.
	a.foot_offset = 53.0
	a.clips = {
		"walk":  Clip.new(preload("res://art/maga_walk.png"), 12, Driver.DISTANCIA, 0.0, true),
		"idle":  Clip.new(preload("res://art/maga_idle.png"),   1, Driver.RELOJ, 6.0, true),
		"cast":  Clip.new(preload("res://art/maga_cast.png"),   1, Driver.RELOJ, 12.0),
		"hurt":  Clip.new(preload("res://art/maga_hurt.png"),   1, Driver.RELOJ, 12.0),
		"death": Clip.new(preload("res://art/maga_death.png"),  1, Driver.RELOJ, 8.0, false, true),
	}
	return a


## --- LOS GOBLINS ---
##
## Los enemigos pasan de un monigote generado de 64 px SIN GIRAR a ocho
## direcciones animadas. Es, con diferencia, el mayor salto visual de
## toda la tanda: el guerrero y el arquero eran lo unico del mundo que
## seguia siendo un dibujo de relleno.
##
## No tienen hoja de ANDAR, asi que el ciclo de andar usa la de reposo
## movida por distancia. Se nota poco porque el goblin patrulla despacio,
## y el dia que llegue un andar de verdad es cambiar una linea.
static func guerrero() -> ActorAnimator:
	var a := ActorAnimator.new()
	a.cell = 128
	a.foot_offset = 54.0
	a.clips = {
		"walk":   Clip.new(preload("res://art/goblin_idle.png"),   6, Driver.DISTANCIA, 0.0, true),
		"idle":   Clip.new(preload("res://art/goblin_idle.png"),   6, Driver.RELOJ, 6.0, true),
		# El garrotazo. Lo dispara enemy.gd cuando el golpe frontal sale,
		# igual que el Spellcaster avisa de que ha lanzado: un golpe es un
		# SUCESO y no se puede deducir mirando la posicion.
		"attack": Clip.new(preload("res://art/goblin_attack.png"), 6, Driver.RELOJ, 14.0),
	}
	return a


static func arquero() -> ActorAnimator:
	var a := ActorAnimator.new()
	a.cell = 128
	a.foot_offset = 54.0
	a.clips = {
		"walk":   Clip.new(preload("res://art/archer_idle.png"), 5, Driver.DISTANCIA, 0.0, true),
		"idle":   Clip.new(preload("res://art/archer_idle.png"), 5, Driver.RELOJ, 5.0, true),
		# La hoja del arquero ES tensar y soltar, asi que el mismo dibujo
		# vale de reposo y de disparo; lo unico que cambia es a que ritmo
		# se recorre y si se bloquea.
		"attack": Clip.new(preload("res://art/archer_idle.png"), 5, Driver.RELOJ, 10.0),
	}
	return a


## Encuentra el animador de un actor. Lo usa quien tiene que AVISAR de
## un suceso (el Spellcaster al lanzar) sin guardarse una referencia.
static func find_in(actor: Node) -> ActorAnimator:
	for hijo in actor.get_children():
		if hijo is ActorAnimator:
			return hijo
	return null


## Avisa de un clip de un disparo (play()) aunque este actor no tenga un
## Sprite2D compatible con el contrato de hoja —caso de la maga nueva,
## que se anima con un AnimatedSprite2D propio. Así quien SÍ sabe
## animarla (player.gd) puede reaccionar sin que ActorAnimator tenga
## que saber que existe.
signal cast_requested(nombre: String)

var clips: Dictionary = {}

## --- EL CONTRATO DE HOJA ---
## Lo que este nodo sabe leer, y lo único que tiene que cumplir un
## personaje futuro: celdas de 64, 8 filas en el orden E SE S SO O NO N
## NE, y los pies a 52 de la celda. Está escrito entero en
## docs/ANIMACION.md y lo genera tools/gen_actor.py.
##
## El animador NO sabe nada del mago. Sabe leer hojas con esta forma.
## Cambiar de personaje es cambiar los PNG y nada más.
## El tamaño de celda DEJA DE SER CONSTANTE. El mago generado usaba 64;
## el personaje pintado necesita 96, porque a 78 px de figura (que es lo
## que se midió componiéndolo sobre las losas) en una celda de 64 no
## cabe. Es @export y no const para que convivan los dos mientras se
## sustituye el arte pieza a pieza.
@export var cell: int = 64

@export var rows: int = 8

## Un fotograma cada tantos píxeles. Describe la ANATOMÍA del personaje
## —lo larga que es su zancada—, no su prisa: la velocidad va en
## player.gd y el ciclo se ajusta solo.
@export var stride: float = 11.0

@export var move_threshold: float = 0.6

## Dónde caen los pies dentro de la celda, contando desde su centro
## (el contrato los pone en y=52, y 52 - 32 = 20). En isométrico todo se
## ordena por donde se pisa, así que si esto está mal, el actor se
## dibuja delante o detrás de bloques que no le tocan.
@export var foot_offset: float = 20.0

## La proyección isométrica APLASTA la vertical: una casilla avanza 58
## px a lo ancho pero solo 27,5 a lo alto. El ángulo que se ve en
## pantalla no es el del mundo, así que se deshace el aplastamiento
## antes de medirlo o el personaje mira mal en las diagonales.
const UNSQUASH: float = 2.109  # IsoGrid.STEP.x / IsoGrid.STEP.y

var sprite: Sprite2D = null
var actor: Node2D = null

var current: String = "idle"
var locked: bool = false        ## un clip de un disparo manda hasta acabar
var travelled: float = 0.0
var clock: float = 0.0
var facing_row: int = 2         ## 2 = mirando al frente
var last_position: Vector2 = Vector2.ZERO
var last_health: float = -1.0


func _ready() -> void:
	actor = get_parent() as Node2D
	if actor == null:
		push_warning("ActorAnimator necesita colgar de un Node2D.")
		return

	sprite = _find_sprite(actor)
	if sprite == null:
		push_warning("ActorAnimator no encuentra Sprite2D visible en " + actor.name)
		return

	sprite.vframes = rows
	sprite.offset.y = -foot_offset
	last_position = actor.global_position

	_check_sheets()

	# El golpe y la muerte se OBSERVAN: el jugador ya emitía esta señal
	# para la barra de vida, así que no hace falta que avise dos veces
	# ni que sepa que existe un animador.
	if actor.has_signal("health_changed"):
		actor.health_changed.connect(_on_health_changed)

	_switch("idle")


## Comprueba que cada hoja cumple el contrato, y lo dice al arrancar.
##
## Esto existe pensando en el día que se cambie el mago por un
## personaje renderizado: un desajuste de una fila o de cuatro píxeles
## de celda no se ve como un error, se ve como fotogramas cortados y
## direcciones cruzadas, y eso se tarda una tarde en diagnosticar a ojo.
## Medio segundo de comprobación al arrancar lo convierte en una frase.
func _check_sheets() -> void:
	for nombre in clips:
		var clip: Clip = clips[nombre]
		if clip.sheet == null:
			push_warning("Clip '%s': falta la hoja." % nombre)
			continue

		var ancho_esperado: int = clip.columns * cell
		var alto_esperado: int = rows * cell
		var tam: Vector2i = clip.sheet.get_size()

		if tam.x != ancho_esperado or tam.y != alto_esperado:
			push_warning(
				"Clip '%s': la hoja mide %dx%d y el contrato pide %dx%d (%d columnas x %d filas de %d px). Ver docs/ANIMACION.md."
				% [nombre, tam.x, tam.y, ancho_esperado, alto_esperado,
					clip.columns, rows, cell])


## Coger "el primer Sprite2D" no vale: el jugador lleva una SOMBRA que
## también es Sprite2D y va antes en el árbol, así que se animaría la
## sombra —invisible— y el personaje se quedaría clavado.
func _find_sprite(parent: Node) -> Sprite2D:
	for hijo in parent.get_children():
		if hijo is Sprite2D and hijo.visible:
			return hijo
	return null


## --- Sucesos ---

## Lanza un clip de un disparo. Mientras dure manda sobre andar y
## respirar; al acabar se vuelve solo a lo automático.
func play(nombre: String) -> void:
	if not clips.has(nombre):
		return
	if current == "death":
		return          # de la muerte no se vuelve

	cast_requested.emit(nombre)

	# Sin Sprite2D compatible (la maga nueva usa AnimatedSprite2D, que no
	# cumple el contrato de hoja) no hay nada que este nodo pueda pintar:
	# el aviso de arriba ya deja que otro se encargue. Seguir de largo
	# hacia _switch() era justo lo que crasheaba, porque _switch() da por
	# hecho que sprite existe.
	if sprite == null:
		return

	_switch(nombre)
	locked = true


func _on_health_changed(nueva: float, _maxima: float) -> void:
	var bajo: bool = last_health >= 0.0 and nueva < last_health
	last_health = nueva

	if nueva <= 0.0:
		_switch("death")
		locked = true
	elif bajo:
		play("hurt")


## --- Bucle ---

func _process(delta: float) -> void:
	if sprite == null:
		return

	var movimiento: Vector2 = actor.global_position - last_position
	last_position = actor.global_position
	var andando: bool = movimiento.length() >= move_threshold

	# Mirar hacia donde se va, incluso mientras lanza o le pegan: si el
	# personaje se gira, tiene que notarse al instante.
	if andando:
		facing_row = _row_for(movimiento)

	if not locked:
		_switch("walk" if andando else "idle")

	var clip: Clip = clips[current]
	var columna: int = 0

	if clip.driver == Driver.DISTANCIA:
		travelled += movimiento.length()
		columna = int(travelled / stride) % clip.columns
	else:
		clock += delta
		var avance := int(clock * clip.fps)
		if clip.loop:
			columna = avance % clip.columns
		elif avance >= clip.columns:
			# Se acabó el disparo: o se queda clavado (muerte) o se
			# devuelve el mando a andar/respirar.
			columna = clip.columns - 1
			if not clip.hold_last:
				locked = false
		else:
			columna = avance

	sprite.frame = facing_row * clip.columns + columna


func _switch(nombre: String) -> void:
	if current == nombre and sprite.texture == clips[nombre].sheet:
		return

	current = nombre
	var clip: Clip = clips[nombre]
	sprite.texture = clip.sheet
	sprite.hframes = clip.columns
	clock = 0.0
	# El recorrido NO se resetea al pasar a andar: si se reseteara en
	# cada cambio, salir de un golpe reiniciaría la zancada a mitad de
	# paso y se vería un tirón.
	if nombre != "walk":
		travelled = 0.0


## Qué fila toca. El orden de las hojas es E, SE, S, SO, O, NO, N, NE,
## que es lo que sale de medir el ángulo desde "derecha" girando hacia
## abajo de 45 en 45.
func _row_for(movimiento: Vector2) -> int:
	var real := Vector2(movimiento.x, movimiento.y * UNSQUASH)
	return posmod(int(round(real.angle() / (TAU / 8.0))), 8)
