extends CharacterBody2D

## Se emite cada vez que la vida cambia, con el valor nuevo y el máximo.
## La barra de vida (health_bar.gd) escucha esta señal para actualizarse
## sin que player.gd necesite saber que existe una barra de vida.
signal health_changed(new_health: float, max_health: float)

var velocidad = 200.0
var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false

## --- Salto ---
## Este es un juego en vista cenital (top-down), no una plataforma con
## gravedad, así que "saltar" no significa subir en Y. Aquí lo tratamos
## como un impulso corto en la última dirección en la que te moviste,
## durante el cual el jugador ignora colisiones físicas (bloques
## sólidos como un GrassBlock crecido) y no activa detecciones de área
## (como el fuego de una GrassBlock en llamas). Sirve para cruzar un
## hueco pequeño o esquivar un bloque, mejorando la movilidad.
var is_jumping: bool = false
var jump_speed: float = 500.0
var jump_duration: float = 0.2
var jump_cooldown: float = 0.5
var jump_timer: float = 0.0
var cooldown_timer: float = 0.0
var last_direction: Vector2 = Vector2.RIGHT

## --- Hielo ---
## Sobre hielo no se pierde velocidad: se pierde AGARRE. En vez de que
## la velocidad sea exactamente la que pidan las teclas, se acerca poco
## a poco a ella (lerp), así al soltar sigues deslizándote y al girar
## el cambio no es instantáneo.
const ICE_GRIP: float = 1.8

## Contamos contactos en vez de guardar un simple true/false porque el
## jugador puede estar tocando dos bloques helados a la vez; si uno se
## derrite, el otro debe seguir haciéndole resbalar.
var ice_contacts: int = 0

## --- Altura ---
## Este juego es cenital: no existe un eje vertical de verdad. La altura
## es, por tanto, una CONVENCIÓN que montamos con tres piezas:
##   1. Un número (`elevation`): 0 = suelo, 1 = subido a algo.
##   2. Un truco visual: dibujar el sprite más arriba y encender una
##      sombra debajo. Sin la sombra, el sprite desplazado solo parece
##      mal colocado; con ella, el cerebro lee "está en alto".
##   3. Una regla física: arriba dejas de chocar con el mundo, y lo que
##      te limita no son las paredes sino el borde de la estructura —
##      si te sales de ella, caes.
##
## Se sube saltando encima de algo trepable, y se baja andando hasta
## salirse. Un solo nivel de altura basta para todo lo que hay ahora;
## apilar varios sería ampliar este número, no rehacer la idea.
const CLIMBABLE_GROUP: String = "climbable"
const ELEVATION_OFFSET: float = 16.0

var elevation: int = 0

## Las estructuras trepables que ahora mismo pisan los pies del jugador.
## Es una lista y no un simple contador porque un bloque puede
## desaparecer solo (al convertirse en vegetación, o al desmoronarse por
## el tope de 20) y hay que poder quitarlo de aquí aunque nunca haya
## llegado a avisar de que salíamos de él.
var supports: Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var feet: Area2D = $Feet
@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow


func _ready() -> void:
	# El grupo permite que otros nodos (como la barra de vida) encuentren
	# al jugador sin necesitar una referencia directa al nodo.
	add_to_group("player")

	# Un CharacterBody2D no puede preguntar por sí mismo con qué áreas se
	# solapa, así que le colgamos un Area2D pequeño a los pies que sí
	# puede. Es lo que nos dice si hay algo debajo sobre lo que estar.
	feet.area_entered.connect(_on_feet_entered)
	feet.area_exited.connect(_on_feet_exited)

	_apply_elevation()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var direccion = Vector2.ZERO

	# Movimiento libre en los dos ejes: WASD para las cuatro direcciones.
	if Input.is_key_pressed(KEY_A):
		direccion.x -= 1

	if Input.is_key_pressed(KEY_D):
		direccion.x += 1

	if Input.is_key_pressed(KEY_W):
		direccion.y -= 1

	if Input.is_key_pressed(KEY_S):
		direccion.y += 1

	if direccion != Vector2.ZERO:
		last_direction = direccion.normalized()

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if Input.is_key_pressed(KEY_SHIFT) and not is_jumping and cooldown_timer <= 0.0:
		_start_jump()

	if is_jumping:
		# Un salto manda sobre el hielo: en el aire no resbalas.
		jump_timer -= delta
		velocity = last_direction * jump_speed
		if jump_timer <= 0.0:
			_end_jump()
	elif is_on_ice():
		velocity = velocity.lerp(direccion * velocidad, ICE_GRIP * delta)
	else:
		velocity = direccion * velocidad

	move_and_slide()
	_update_elevation()


func is_on_ice() -> bool:
	return ice_contacts > 0


## Los llama NeutralBlock cuando está helado. max(0, ...) es una red de
## seguridad: si por algún caso raro llegan más "salidas" que
## "entradas", el contador no se queda en negativo dejando al jugador
## permanentemente sin hielo.
func add_ice_contact() -> void:
	ice_contacts += 1


func remove_ice_contact() -> void:
	ice_contacts = maxi(0, ice_contacts - 1)


func _start_jump() -> void:
	is_jumping = true
	jump_timer = jump_duration
	cooldown_timer = jump_cooldown
	# set_deferred porque estamos dentro de _physics_process: cambiar la
	# forma de colisión en mitad del paso de física puede ser inestable.
	collision_shape.set_deferred("disabled", true)
	print("¡Salto!")


func _end_jump() -> void:
	is_jumping = false
	collision_shape.set_deferred("disabled", false)

	# Si el salto termina sobre algo trepable, te quedas encima. Esto es
	# lo que convierte el salto en "escalar": no hace falta una tecla
	# nueva ni una animación de trepar, basta con mirar dónde caes.
	if not _current_supports().is_empty():
		_set_elevation(1)


## --- Altura ---

func _on_feet_entered(area: Area2D) -> void:
	if area.is_in_group(CLIMBABLE_GROUP) and not supports.has(area):
		supports.append(area)


func _on_feet_exited(area: Area2D) -> void:
	supports.erase(area)


## Un bloque puede desaparecer sin avisar (se convierte en vegetación, o
## se desmorona al llegar al tope de 20). En ese caso nunca llega el
## aviso de "has salido de mí", así que la lista se queda con un nodo
## fantasma. Filtrar por is_instance_valid() antes de usarla es lo que
## hace que, si te quitan el suelo de debajo, te caigas.
func _current_supports() -> Array:
	supports = supports.filter(func(s): return is_instance_valid(s))
	return supports


func _update_elevation() -> void:
	if is_jumping:
		return

	if elevation > 0 and _current_supports().is_empty():
		_set_elevation(0)


func _set_elevation(value: int) -> void:
	if value == elevation:
		return

	elevation = value
	_apply_elevation()

	if elevation == 0:
		print("Bajas al suelo.")
	else:
		print("Te encaramas a la estructura.")


func _apply_elevation() -> void:
	# El sprite sube y aparece su sombra en el suelo: ese par es todo el
	# truco de la altura.
	sprite.position.y = -ELEVATION_OFFSET * elevation
	shadow.visible = elevation > 0

	# Arriba se apaga la colisión con el mundo. No es que "atravieses"
	# las cosas: es que estás por encima de ellas. Lo que te sostiene es
	# la estructura, y lo que te limita es su borde — en cuanto lo pasas,
	# _update_elevation() te devuelve al suelo.
	set_collision_mask_value(1, elevation == 0)


## Misma idea que Enemy.receive_damage(), pero aquí en el jugador.
## Cualquier cosa del mundo que quiera hacerte daño (un enemigo,
## un bloque de hierba ardiendo...) solo necesita llamar a esto.
func receive_damage(amount: float) -> void:
	# Sin esta guarda, los temporizadores de daño que ya estaban en
	# marcha (las llamas, un enemigo encima) seguirían llamando aquí
	# después de morir y dispararían _die() una y otra vez.
	if is_dead:
		return

	# Subido a una estructura, las amenazas del suelo no te alcanzan: ni
	# las llamas de la hierba ni el contacto de un enemigo. Es el motivo
	# de ser de la altura, y de momento la regla es así de tajante. El
	# día que haya enemigos voladores o a distancia, habrá que decirle a
	# esta función desde qué altura viene el golpe.
	if elevation > 0:
		return

	health -= amount
	health = max(health, 0.0)
	print("El jugador ha recibido ", amount, " de daño. Vida: ", health)
	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	print("¡Has muerto!")

	# Mismo patrón que la victoria: el cartel se busca por grupo, así
	# este script no necesita conocer la estructura de la interfaz.
	var game_over_label = get_tree().get_first_node_in_group("gameover_ui")
	if game_over_label:
		game_over_label.visible = true

	# Congela el nivel entero (enemigos, temporizadores, hechizos).
	# Quien sigue escuchando teclas en pausa es LevelController, para
	# que la R de reiniciar siga funcionando.
	get_tree().paused = true
