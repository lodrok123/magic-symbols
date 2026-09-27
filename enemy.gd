extends Area2D

## --- Patrulla ---
## El enemigo se mueve en línea recta entre dos puntos: su posición
## inicial y esa misma posición desplazada `patrol_distance` en X.
## Al llegar a cualquiera de los dos extremos, invierte la dirección.
## No usa move_and_slide() porque un Area2D no tiene física de cuerpo,
## así que simplemente desplazamos su `position` cada frame.
@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 80.0

var start_position: Vector2
var direction: int = 1

## --- Daño de contacto ---
## Mismo patrón que GrassBlock (Area2D + Timer): mientras el jugador
## esté dentro del área del enemigo, un Timer repetido va llamando a
## receive_damage() cada segundo. Al salir, se para el temporizador.
@export var damage_per_second: float = 5.0
@onready var damage_timer: Timer = $DamageTimer
var player_inside: Node = null

## --- Golpe frontal ---
## Rozarse con el enemigo hace un daño de mantenimiento; quedarse
## PLANTADO delante de él es lo que sale caro. La zona de golpe es un
## área aparte que va siempre por delante, en el sentido de la patrulla.
##
## El golpe no es instantáneo: hay que llevar STRIKE_CHARGE segundos ahí
## para que caiga. Esa espera es lo que lo hace justo — te da tiempo a
## apartarte, y convierte "estar delante" en una decisión y no en un
## accidente.
@export var strike_damage: float = 20.0
const STRIKE_CHARGE: float = 0.5
const STRIKE_COOLDOWN: float = 1.5
const STRIKE_REACH: float = 46.0

@onready var strike_area: Area2D = $StrikeArea

var charge: float = 0.0
var strike_rest: float = 0.0

var health: float = 100.0

## --- ATURDIMIENTO ---
##
## La tercera cosa que le faltaba al rayo. El fuego quema, el viento
## empuja, el hielo corta el paso... y el rayo solo hacía daño, que es lo
## que ya hacían todos. Aturdir le da una respuesta que ningún otro
## elemento da: PARAR A ALGUIEN SIN MATARLO.
##
## Contra el guerrero significa poder pasarle por delante. Contra el
## arquero, unos segundos sin flechas mientras cruzas — que es justo la
## respuesta que le faltaba, porque hasta ahora al arquero solo se le
## podía esquivar o taparse de él.
##
## 2.5 s es lo justo para atravesar dos o tres casillas. Bastante más lo
## convertiría en "matar sin matar", y entonces el rayo volvería a ser
## solo daño, con otro nombre.
const STUN_TIME: float = 2.5
const COLOR_ATURDIDO: Color = Color(1.5, 1.45, 0.7)

var stun_timer: float = 0.0


func _ready() -> void:
	print("Enemigo listo. Vida: ", health)
	start_position = position

	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_on_damage_tick)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	# Aturdido no patrulla NI carga el golpe. Se sale de la función
	# entera y no se le quita solo la velocidad, porque un enemigo que se
	# queda quieto pero sigue cargando el puñetazo es peor que uno que no
	# se para: parece parado y te mata igual.
	if stun_timer > 0.0:
		stun_timer -= delta
		charge = 0.0
		if stun_timer <= 0.0:
			_wake_up()
		return

	position.x += direction * patrol_speed * delta

	if abs(position.x - start_position.x) >= patrol_distance:
		# Lo dejamos exactamente en el límite (en vez de pasarse un poco)
		# y le damos la vuelta.
		position.x = start_position.x + patrol_distance * direction
		direction *= -1

	_update_strike(delta)


## La zona de golpe se coloca siempre delante, así que al darse la vuelta
## el enemigo la lleva consigo sin necesidad de dos áreas ni de espejar
## nada a mano.
func _update_strike(delta: float) -> void:
	strike_area.position.x = STRIKE_REACH * direction

	if strike_rest > 0.0:
		strike_rest -= delta
		charge = 0.0
		return

	# Se consulta el solapamiento en vez de usar señales de entrada y
	# salida porque el área SE MUEVE cada fotograma: con señales habría
	# que confiar en que entran y salen en el orden correcto al girar,
	# y preguntar directamente no deja lugar a dudas.
	var target: Node = null
	for body in strike_area.get_overlapping_bodies():
		if body.has_method("receive_damage"):
			target = body
			break

	if target == null:
		charge = 0.0
		return

	charge += delta
	if charge >= STRIKE_CHARGE:
		target.receive_damage(strike_damage)
		# El garrotazo es un SUCESO: no se deduce mirando la posición, hay
		# que avisar. Mismo patrón que el Spellcaster al lanzar.
		var animador := ActorAnimator.find_in(self)
		if animador:
			animador.play("attack")
		print("¡Golpe frontal! ", strike_damage, " de daño")
		charge = 0.0
		strike_rest = STRIKE_COOLDOWN


## Esta es la función que Spell.gd busca automáticamente al chocar.
## Cualquier objeto del mundo que la implemente puede reaccionar a
## un hechizo de la misma forma: agua, puertas, plataformas... `direction`
## es la dirección en la que iba el hechizo; el enemigo no la usa
## todavía (no le afecta el viento), pero forma parte del contrato
## común para quien sí la necesite (WaterBlock, GrassBlock).
func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	# El aturdimiento va ANTES de la comprobación del daño y aparte de
	# ella: son dos efectos distintos del mismo impacto, y atarlos haría
	# que una fuente de corriente sin daño —una placa, una trampa— no
	# aturdiera, que es justo al revés de lo que se espera.
	if rune_data.tags.has("electrico"):
		_stun()

	# Ahora hay elementos que no hacen daño (viento, tierra, vapor). En
	# vez de ir listando cuáles ignorar uno a uno —y tener que volver
	# aquí cada vez que inventemos otro—, el enemigo mira el dato que de
	# verdad le importa: si ese elemento hace daño o no.
	if rune_data.damage <= 0.0:
		return

	receive_damage(rune_data.damage)


## Recibir corriente estando ya aturdido RENUEVA el plazo, no lo suma:
## si se acumulara, un corro de rayos dejaría al enemigo parado medio
## minuto y el hechizo pasaría a ser un "matar" disfrazado.
func _stun() -> void:
	var dormido: bool = stun_timer > 0.0
	stun_timer = STUN_TIME

	if dormido:
		return

	modulate = COLOR_ATURDIDO
	BlockFx.burst(self, "chispas")
	print("¡El guerrero se queda aturdido!")


func _wake_up() -> void:
	modulate = Color(1, 1, 1)
	print("El guerrero se recupera.")


## `from_elevation` llega de quien pega. El guerrero no lo usa —él sí
## recibe golpes de cualquier altura— pero la firma tiene que coincidir
## con la del jugador para que una flecha pueda pegarle a cualquiera de
## los dos sin preguntar qué es.
func receive_damage(amount: float, _from_elevation: int = 0) -> void:
	health -= amount
	print("Me dieron ", amount, " de daño")
	print("Vida restante: ", health)

	if health <= 0:
		_die()


## El viento también mueve al guerrero. Un enemigo plantado al borde de
## la isla es un enemigo al que se puede tirar por el borde — que es
## justo lo que hace que el viento merezca la pena aunque no haga daño.
##
## Se mueve la posición directamente porque un Area2D no tiene física de
## cuerpo: no hay velocidad que empujar, hay sitio que cambiar.
func push(direction: Vector2, force: float) -> void:
	position += direction.normalized() * force * 0.02
	# Al empujarlo se lleva consigo su punto de patrulla, o volvería
	# andando al sitio de antes como si nada hubiera pasado.
	start_position += direction.normalized() * force * 0.02


func _die() -> void:
	print("Enemigo derrotado")
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("receive_damage"):
		player_inside = body
		_on_damage_tick()     # daño inmediato al tocarlo
		damage_timer.start()  # y daño repetido cada segundo mientras siga dentro


func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
		damage_timer.stop()


func _on_damage_tick() -> void:
	# Aturdido tampoco hace daño por contacto. Es lo que da sentido a
	# pasarle por delante: si siguiera quemando al rozarlo, aturdirlo no
	# abriría ningún paso y volvería a ser un hechizo de daño.
	if stun_timer > 0.0:
		return
	if player_inside and player_inside.has_method("receive_damage"):
		player_inside.receive_damage(damage_per_second)
