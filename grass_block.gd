extends Area2D

const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")

## La hierba es el único bloque que cambia de TEXTURA y no solo de
## tinte: crecida es una mata alta, no la misma hierba más oscura.
## Para el resto de estados (prendiendo, ardiendo, cenizas) basta con
## teñir la textura de hierba baja con `modulate`.
const TEXTURE_THIN: Texture2D = preload("res://art/grass.png")
const TEXTURE_GROWN: Texture2D = preload("res://art/grass_grown.png")

## --- Ciclo de vida de un incendio ---
## Antes la hierba se encendía y se quedaba ardiendo para siempre. Un
## fuego de verdad tiene fases, y cada fase es una oportunidad de
## puzzle distinta: te da un margen para reaccionar antes de que prenda
## del todo, y se apaga solo dejando cenizas si no haces nada.
##
##   THIN      hierba baja, se cruza sin peligro
##   GROWN     hierba tupida, bloquea el paso
##   IGNITING  ha prendido, aún no quema (tienes ~1s para apagarla)
##   BURNING   llamas: hace daño y CONTAGIA a la vegetación cercana
##   ASHES     se consumió: inerte, ya no puede arder otra vez
##
## Del ciclo se sale regando: las cenizas vuelven a ser hierba fina.
enum State { THIN, GROWN, IGNITING, BURNING, ASHES }

@export var initial_state: State = State.THIN

const IGNITE_TIME: float = 1.0        ## de "ha prendido" a "arde del todo"
const BURN_TIME: float = 5.0          ## cuánto arde antes de consumirse
const SPREAD_INTERVAL: float = 1.2    ## cada cuánto intenta contagiar
const SPREAD_RADIUS: float = 110.0    ## alcance del contagio (bloques ~90px)

## El viento no solo empuja el fuego: lo lanza mucho más lejos y solo
## hacia donde sopla. El "dot" mide cuánto coincide la dirección hacia
## el vecino con la del viento (1 = justo en esa dirección, 0 = de
## lado); 0.3 deja un cono amplio pero no contagia hacia atrás.
const WIND_SPREAD_RADIUS: float = 230.0
const WIND_SPREAD_DOT: float = 0.3

const FLAMMABLE_GROUP: String = "flammable"

var state: State = State.THIN
var damage_per_tick: float = 10.0

@onready var solid_shape: CollisionShape2D = $SolidBody/CollisionShape2D
@onready var damage_timer: Timer = $DamageTimer

## Estos dos temporizadores se crean por código en vez de en la escena:
## así cualquier GrassBlock creado al vuelo (por ejemplo, tierra regada
## que brota) los tiene sin depender de que alguien se acuerde de
## añadirlos en el editor.
var fire_timer: Timer
var spread_timer: Timer

var player_inside: Node = null

## Las llamas que se dibujan encima de la hierba mientras arde. No hace
## falta un PNG de fuego aparte: reutilizamos la animación que ya lleva
## la ficha del elemento fuego (FIRE_RUNE). Si mañana cambias la tira de
## fuego, cambia en los hechizos y en los incendios a la vez.
const FX_FPS: float = 24.0
var fx_time: float = 0.0


func _ready() -> void:
	add_to_group("ground")
	add_to_group(FLAMMABLE_GROUP)

	FIRE_RUNE.setup_sprite($Fx)

	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_phase_finished)
	add_child(fire_timer)

	spread_timer = Timer.new()
	spread_timer.wait_time = SPREAD_INTERVAL
	spread_timer.timeout.connect(_on_spread_tick)
	add_child(spread_timer)

	state = initial_state
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	damage_timer.timeout.connect(_on_damage_tick)
	_apply_state()


## Cada bloque anima sus llamas por su cuenta. Arrancar `fx_time` desde
## cero al prender hace que dos hierbas que se incendian en momentos
## distintos no ardan en sincronía perfecta, que es lo que delataría que
## son el mismo dibujo repetido.
func _process(delta: float) -> void:
	if not $Fx.visible or FIRE_RUNE.vfx_frames <= 0:
		return

	fx_time += delta
	$Fx.frame = int(fx_time * FX_FPS) % FIRE_RUNE.vfx_frames


## "calor" prende (si hay algo que quemar).
## "rayo" prende también, y sin fase previa: un relámpago no "va
##   calentando", cae y arde. Es la vía rápida y cara de iniciar un
##   incendio, frente al fuego que aún puedes apagar mientras prende.
## "agua" y "frio" apagan, riegan o rebrotan, según el punto del ciclo.
## "disipar" devuelve la hierba a su sitio sin regarla.
## "viento" aviva y esparce el fuego que ya existe.
func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("calor"):
		ignite()
	elif rune_data.tags.has("rayo"):
		_strike()
	elif rune_data.tags.has("disipar"):
		_dispel()
	elif rune_data.tags.has("agua") or rune_data.tags.has("frio"):
		# Antes esto miraba solo "frio", y era un accidente: la runa de
		# agua llevaba esa etiqueta de paso. Ahora que el frío es un
		# elemento propio, se dice lo que de verdad se quería decir —se
		# riega con agua, y el hielo también moja al derretirse.
		_water()
	elif rune_data.tags.has("viento"):
		_fan_flames(direction)


## QUÉ PUEDE LLEVARSE EL VIENTO DE AQUÍ.
##
## El bloque no sabe que existe el viento: solo declara qué elemento
## tiene activo ahora mismo. Quien pregunte decidirá qué hace con él.
## Es el mismo trato que on_spell_hit, pero al revés — allí el mundo
## recibe, aquí el mundo ofrece.
func carried_element() -> RuneData:
	if state == State.BURNING or state == State.IGNITING:
		return FIRE_RUNE
	return null


## Pública a propósito: es la forma en que un bloque en llamas contagia
## a sus vecinos, sin tener que fabricar un hechizo de fuego para cada
## contagio.
func ignite() -> void:
	if state == State.THIN or state == State.GROWN:
		_set_state(State.IGNITING)


## El rayo salta la fase de "prendiendo": pasa directo a arder. Sobre
## ceniza no hace nada — no queda nada que quemar.
func _strike() -> void:
	if state == State.THIN or state == State.GROWN or state == State.IGNITING:
		_set_state(State.BURNING)


## Disipar no es regar: apaga el incendio y deja la hierba como estaba,
## pero NO la hace crecer ni la resucita de la ceniza. El tiempo
## deshace magia, no obra milagros.
func _dispel() -> void:
	match state:
		State.IGNITING, State.BURNING:
			_set_state(State.THIN)
		_:
			pass


func _water() -> void:
	match state:
		State.IGNITING, State.BURNING:
			_set_state(State.THIN)   # apagas el incendio
		State.ASHES:
			_set_state(State.THIN)   # sobre las cenizas rebrota hierba
		State.THIN:
			_set_state(State.GROWN)  # regar hierba fina la hace crecer
		State.GROWN:
			pass


## El viento sobre llamas hace dos cosas, como en un incendio real:
## arrastra una lengua de fuego hacia delante (el hechizo que vuela) y
## además salta directamente a la vegetación que tenga a favor de
## viento, mucho más lejos de lo que se contagiaría por sí solo.
func _fan_flames(direction: Vector2) -> void:
	if direction == Vector2.ZERO or state != State.BURNING:
		return

	SpellFactory.cast(self, global_position, direction, FIRE_RUNE)
	_spread_fire(WIND_SPREAD_RADIUS, direction)
	print("¡El viento aviva las llamas y las lanza hacia delante!")


func _on_spread_tick() -> void:
	if state != State.BURNING:
		return
	_spread_fire(SPREAD_RADIUS, Vector2.ZERO)


## Si `wind` es ZERO, contagia en todas direcciones dentro del radio.
## Si no, solo a los vecinos que estén a favor del viento.
func _spread_fire(radius: float, wind: Vector2) -> void:
	for other in get_tree().get_nodes_in_group(FLAMMABLE_GROUP):
		if other == self or not is_instance_valid(other):
			continue

		var to_other: Vector2 = other.global_position - global_position
		if to_other.length() > radius:
			continue

		if wind != Vector2.ZERO and to_other.normalized().dot(wind.normalized()) < WIND_SPREAD_DOT:
			continue

		other.ignite()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return

	var anterior: State = state
	state = new_state
	_apply_state()
	_apply_particles(anterior)


## --- Partículas ---
## El fuego dibujado sobre el bloque ya estaba; lo que faltaba es que el
## bloque SUELTE cosas. En isométrico eso importa más que en cenital: el
## volumen es un engaño, y lo que lo sostiene no es el dibujo sino que
## el humo salga de la cara de arriba y suba. El cerebro se traga la
## profundidad en cuanto ve algo comportarse con ella.
##
## Se mira la TRANSICIÓN y no solo el estado nuevo, porque los
## estallidos marcan un instante —justo cuando algo cambia— mientras que
## el fuego y el humo son continuos mientras dure.
var flame_fx: GPUParticles2D = null
var smoke_fx: GPUParticles2D = null


func _apply_particles(anterior: State) -> void:
	_set_emitter(state == State.BURNING)

	if state == State.BURNING and anterior == State.IGNITING:
		BlockFx.burst(self, "chispas")      # prende de golpe
	elif state == State.ASHES:
		BlockFx.burst(self, "ceniza")       # se consume
	elif anterior == State.BURNING and state == State.THIN:
		BlockFx.burst(self, "ceniza")       # lo apagas: vaharada de humo


## Los emisores continuos se crean la PRIMERA vez que hacen falta y a
## partir de ahí solo se encienden y se apagan. Crearlos y destruirlos
## en cada cambio de estado daría tirones: montar un material de
## partículas no es gratis.
func _set_emitter(encendido: bool) -> void:
	if encendido and flame_fx == null:
		flame_fx = BlockFx.flames(self)
		smoke_fx = BlockFx.smoke(self)

	if flame_fx:
		flame_fx.emitting = encendido
		smoke_fx.emitting = encendido


## Todo el "qué aspecto, qué colisión y qué temporizadores tiene cada
## estado" vive en un único sitio. Añadir una fase nueva es añadirla al
## enum y a este match, nada más.
func _apply_state() -> void:
	fire_timer.stop()
	spread_timer.stop()
	_apply_flames()

	match state:
		State.THIN:
			_set_visual(TEXTURE_THIN, Color(1, 1, 1))
			solid_shape.set_deferred("disabled", true)
			_stop_burning_damage()
			print("La hierba está baja: se puede cruzar sin peligro.")

		State.GROWN:
			_set_visual(TEXTURE_GROWN, Color(1, 1, 1))
			solid_shape.set_deferred("disabled", false)
			_stop_burning_damage()
			print("La hierba ha crecido tupida: ahora bloquea el paso.")

		State.IGNITING:
			# Ahora que hay llamas dibujadas encima, la hierba de debajo
			# solo necesita insinuar el calor, no gritarlo.
			_set_visual(TEXTURE_THIN, Color(1.15, 1.0, 0.75))
			solid_shape.set_deferred("disabled", true)
			_stop_burning_damage()
			fire_timer.start(IGNITE_TIME)
			print("La hierba ha prendido... (aún puedes apagarla)")

		State.BURNING:
			_set_visual(TEXTURE_THIN, Color(0.75, 0.5, 0.4))  # hierba chamuscada bajo las llamas
			solid_shape.set_deferred("disabled", true)
			fire_timer.start(BURN_TIME)
			spread_timer.start()
			_start_burning_damage()
			Sfx.play(self, "prender")
			print("¡La hierba está en llamas!")

		State.ASHES:
			_set_visual(TEXTURE_THIN, Color(0.28, 0.26, 0.26))
			solid_shape.set_deferred("disabled", true)
			_stop_burning_damage()
			print("Solo quedan cenizas. (Riégalas para que rebrote)")


func _set_visual(texture: Texture2D, tint: Color) -> void:
	$Visual.texture = texture
	$Visual.modulate = tint


## Las llamas solo existen mientras hay fuego. En IGNITING se dibujan
## pequeñas y translúcidas (una lumbre que empieza), y en BURNING a
## tamaño completo.
func _apply_flames() -> void:
	match state:
		State.IGNITING:
			$Fx.show()
			$Fx.scale = Vector2(0.35, 0.35)
			$Fx.modulate = Color(1, 1, 1, 0.7)
			fx_time = 0.0
		State.BURNING:
			$Fx.show()
			$Fx.scale = Vector2(0.55, 0.55)
			$Fx.modulate = Color(1, 1, 1, 1)
		_:
			$Fx.hide()


## Un único temporizador de fase sirve para las dos transiciones
## automáticas del ciclo, porque nunca coinciden a la vez.
func _on_fire_phase_finished() -> void:
	match state:
		State.IGNITING:
			_set_state(State.BURNING)
		State.BURNING:
			_set_state(State.ASHES)


## --- Daño por pisar las llamas ---
## Si el jugador ya estaba encima cuando la hierba pasó a arder, el
## aviso "body_entered" nunca llegará (nunca entró: ya estaba dentro).
## Por eso al entrar en BURNING miramos quién hay dentro ahora mismo.
func _start_burning_damage() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("receive_damage"):
			player_inside = body
			_on_damage_tick()
			damage_timer.start()
			return


func _stop_burning_damage() -> void:
	damage_timer.stop()
	player_inside = null


func _on_body_entered(body: Node) -> void:
	if state != State.BURNING:
		return
	if body.has_method("receive_damage"):
		player_inside = body
		_on_damage_tick()      # daño inmediato al pisar las llamas
		damage_timer.start()   # y daño repetido mientras siga dentro


func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
		damage_timer.stop()


func _on_damage_tick() -> void:
	if player_inside and player_inside.has_method("receive_damage"):
		player_inside.receive_damage(damage_per_tick)
