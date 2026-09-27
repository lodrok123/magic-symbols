extends CharacterBody2D

## Se emite cada vez que la vida cambia, con el valor nuevo y el máximo.
## La barra de vida (health_bar.gd) escucha esta señal para actualizarse
## sin que player.gd necesite saber que existe una barra de vida.
signal health_changed(new_health: float, max_health: float)

var velocidad = 80.0
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

## Lo que llevamos sumado a la Y por estar subidos. Se guarda para poder
## restarlo al bajar: si no, cada subida y bajada dejaría un poso y el
## jugador acabaría desalineado de su propia casilla.
var _ysort_extra: float = 0.0

## Las estructuras trepables que ahora mismo pisan los pies del jugador.
## Es una lista y no un simple contador porque un bloque puede
## desaparecer solo (al convertirse en vegetación, o al desmoronarse por
## el tope de 20) y hay que poder quitarlo de aquí aunque nunca haya
## llegado a avisar de que salíamos de él.
var supports: Array = []

## --- CAÍDA ---
## En isométrico no hay eje vertical de verdad, pero sí hay BORDE. Si los
## pies dejan de tocar suelo —te bajas de un bloque, te empujan fuera de
## la isla, o alguien te quita la losa de debajo— te caes.
##
## Esto es lo que convierte el empuje del viento en un arma de verdad en
## vez de un adorno: no hace falta que el viento haga daño si puede
## tirarte por un borde.
const GROUND_GROUP: String = "ground"
const FALL_DAMAGE: float = 25.0
const FALL_TIME: float = 0.45

## El suelo que pisan los pies ahora mismo. Misma idea que `supports` y
## por el mismo motivo: es una lista y no un contador porque un bloque
## puede desaparecer sin avisar de que has salido de él.
var ground: Array = []

var is_falling: bool = false
var fall_timer: float = 0.0

## Hasta que no se ha mirado el suelo por primera vez, no se puede
## decidir que no lo hay. Ver _seed_ground().
var ground_ready: bool = false

## MARGEN ANTES DE CAER ("coyote time").
##
## Sin él, cualquier parpadeo de un fotograma —una junta entre dos
## losas, un empujón que te descoloca medio píxel— se lee como vacío y
## te tira. Con él, hay que estar de verdad fuera.
##
## Es además la red que compensa que la pisada de los pies sea pequeña:
## si el rombo se queda corto en una esquina, el margen lo tapa.
const COYOTE_TIME: float = 0.12
var airborne_timer: float = 0.0

## Dónde devolverte tras caer. Se va guardando mientras pisas suelo
## firme, así que siempre es un sitio del que se puede volver a salir.
var last_safe_position: Vector2 = Vector2.ZERO

## --- Empuje ---
## Lo que te empuja (el viento) no te mueve de golpe: te deja una
## velocidad que se va gastando. Un empujón instantáneo te teletransporta
## y no se lee; uno que decae se ve como un empujón.
var push_velocity: Vector2 = Vector2.ZERO
const PUSH_DECAY: float = 4.0

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

	last_safe_position = global_position
	_apply_elevation()

	_seed_ground()


## MIRAR EL SUELO A MANO LA PRIMERA VEZ.
##
## Un Area2D solo avisa con `area_entered` cuando algo ENTRA en su zona.
## El jugador nace ya encima de los bloques, así que ese aviso no llega
## nunca y la lista de suelo arrancaba vacía: en el primer fotograma de
## física el jugador se creía en el vacío y se caía solo.
##
## Es EXACTAMENTE el mismo fallo que tuvimos con los hechizos quietos —
## un pilar que nace solapado con un bloque tampoco recibía el aviso— y
## se arregla igual: esperar un ciclo de física y preguntar a mano.
func _seed_ground() -> void:
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	for area in feet.get_overlapping_areas():
		_on_feet_entered(area)

	ground_ready = true
	last_safe_position = global_position


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_falling:
		_process_fall(delta)
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

	# El empuje se SUMA a lo que pidan las teclas, no lo sustituye: así
	# puedes resistirte andando contra el viento, que es lo que hace que
	# el empujón se sienta como una fuerza y no como una animación.
	velocity += push_velocity
	push_velocity = push_velocity.lerp(Vector2.ZERO, PUSH_DECAY * delta)

	move_and_slide()
	_update_elevation()
	_update_ground(delta)


## --- Caída ---

## Mientras caes no controlas nada. Es a propósito: una caída de la que
## puedes salir andando no se lee como una caída.
func _process_fall(delta: float) -> void:
	fall_timer -= delta

	# El sprite se hunde y encoge. Sin esto, "caerse" sería simplemente
	# aparecer en otro sitio.
	var t: float = 1.0 - (fall_timer / FALL_TIME)
	sprite.position.y = -ELEVATION_OFFSET * elevation + t * 26.0
	sprite.scale = Vector2.ONE * (1.0 - t * 0.5)
	sprite.modulate.a = 1.0 - t * 0.8

	if fall_timer > 0.0:
		return

	is_falling = false
	sprite.scale = Vector2.ONE
	sprite.modulate.a = 1.0
	global_position = last_safe_position
	velocity = Vector2.ZERO
	push_velocity = Vector2.ZERO
	_set_elevation(0)
	_apply_elevation()
	receive_damage(FALL_DAMAGE)


## Los pies no tocan nada: al vacío. El salto es la excepción — durante
## el salto SE ESPERA estar sobre la nada, es justo para lo que sirve.
func _update_ground(delta: float) -> void:
	# Antes de la primera comprobación no se sabe nada, y "no sé" no es
	# lo mismo que "no hay suelo".
	if not ground_ready:
		return

	ground = ground.filter(func(g): return is_instance_valid(g))

	if is_jumping:
		airborne_timer = 0.0
		return

	if ground.is_empty():
		airborne_timer += delta
		if airborne_timer >= COYOTE_TIME:
			_begin_fall()
		return

	airborne_timer = 0.0

	if velocity.length() < 5.0:
		# Solo se apunta como seguro un sitio donde estás QUIETO. Guardar
		# la posición en movimiento acabaría guardando el borde justo
		# antes de salirte, y te devolvería a caerte otra vez.
		last_safe_position = global_position


func _begin_fall() -> void:
	if is_falling or is_dead:
		return
	is_falling = true
	fall_timer = FALL_TIME
	airborne_timer = 0.0
	velocity = Vector2.ZERO
	print("¡Te caes al vacío!")


## Lo llama el viento. La dirección viene del hechizo; la fuerza, de su
## potencia. Cualquier cosa futura que empuje usa esto mismo.
func push(direction: Vector2, force: float) -> void:
	if is_dead:
		return
	push_velocity += direction.normalized() * force


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
	if area.is_in_group(GROUND_GROUP) and not ground.has(area):
		ground.append(area)


func _on_feet_exited(area: Area2D) -> void:
	supports.erase(area)
	ground.erase(area)


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

	# Y ADEMAS HAY QUE ADELANTARSE EN LA COLA DE DIBUJO.
	#
	# iso_test.gd empuja los bloques elevados 0,1 px hacia abajo para que
	# y_sort los pinte por delante de la losa que pisan. Subirse encima
	# sin hacer lo mismo te deja EMPATADO con esa losa y por DETRAS del
	# cubo: se te ve de pecho para arriba, enterrado en la plataforma
	# sobre la que estás de pie.
	#
	# 0,15 y no 0,1: tiene que ganarle al cubo, no empatar con él.
	position.y += 0.15 * elevation - _ysort_extra
	_ysort_extra = 0.15 * elevation

	# Arriba se apaga la colisión con el mundo. No es que "atravieses"
	# las cosas: es que estás por encima de ellas. Lo que te sostiene es
	# la estructura, y lo que te limita es su borde — en cuanto lo pasas,
	# _update_elevation() te devuelve al suelo.
	set_collision_mask_value(1, elevation == 0)


## Misma idea que Enemy.receive_damage(), pero aquí en el jugador.
## Cualquier cosa del mundo que quiera hacerte daño (un enemigo,
## un bloque de hierba ardiendo...) solo necesita llamar a esto.
func receive_damage(amount: float, from_elevation: int = 0) -> void:
	# Sin esta guarda, los temporizadores de daño que ya estaban en
	# marcha (las llamas, un enemigo encima) seguirían llamando aquí
	# después de morir y dispararían _die() una y otra vez.
	if is_dead:
		return

	# Subido a una estructura, las amenazas DEL SUELO no te alcanzan: ni
	# las llamas de la hierba ni el contacto de un enemigo. Pero una
	# flecha disparada desde una plataforma sí.
	#
	# Antes esto era `if elevation > 0: return` —tajante— con una nota
	# que decía "el día que haya enemigos a distancia habrá que decir
	# desde qué altura viene el golpe". Ese día llegó con el arquero.
	# Quien pega dice desde dónde; por defecto, desde el suelo.
	if elevation > from_elevation:
		return

	health -= amount
	health = max(health, 0.0)
	Sfx.play(self, "dano")
	print("El jugador ha recibido ", amount, " de daño. Vida: ", health)
	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	Sfx.play(self, "muerte")
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
