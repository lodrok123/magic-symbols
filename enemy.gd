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


func _ready() -> void:
	print("Enemigo listo. Vida: ", health)
	start_position = position

	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_on_damage_tick)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
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

	# Ahora hay elementos que no hacen daño (viento, tierra, vapor). En
	# vez de ir listando cuáles ignorar uno a uno —y tener que volver
	# aquí cada vez que inventemos otro—, el enemigo mira el dato que de
	# verdad le importa: si ese elemento hace daño o no.
	if rune_data.damage <= 0.0:
		return

	receive_damage(rune_data.damage)


func receive_damage(amount: float) -> void:
	health -= amount
	print("Me dieron ", amount, " de daño")
	print("Vida restante: ", health)

	if health <= 0:
		_die()


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
	if player_inside and player_inside.has_method("receive_damage"):
		player_inside.receive_damage(damage_per_second)
