extends CharacterBody2D

## Se emite cada vez que la vida cambia, con el valor nuevo y el máximo.
## La barra de vida (health_bar.gd) escucha esta señal para actualizarse
## sin que player.gd necesite saber que existe una barra de vida.
signal health_changed(new_health: float, max_health: float)

var velocidad = 100.0
var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false

## Tamaño al que se dibuja el sprite (la caída lo encoge y luego lo restaura). Un nivel
## con arte de otra escala lo cambia; por defecto, tamaño natural.
var visual_scale: Vector2 = Vector2.ONE

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

## --- VOLTERETA (Espacio) ---
##
## Un arranque corto en la dirección en que andas, con un momento de
## invulnerabilidad y recarga de 1 s. A DIFERENCIA DEL SALTO NO APAGA LA
## COLISIÓN: sigues chocando con los muros, así que no se puede usar para
## atravesarlos. Sin tecla de dirección, rueda hacia donde mirabas.
const ROLL_SPEED: float = 330.0
const ROLL_DURATION: float = 0.20
const ROLL_COOLDOWN: float = 1.0
const ROLL_INVULN: float = 0.30
var _roll_timer: float = 0.0
var _roll_cd: float = 0.0
var _invuln: float = 0.0
var _roll_dir: Vector2 = Vector2.RIGHT

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
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var old_sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

## --- Animación isométrica de 8 direcciones ---
## Las animaciones generadas por el pipeline de Meshy/Blender se llaman
## "<clip>_<dirección>", por ejemplo "walk_S" o "idle_NE". Aquí traducimos
## el vector de movimiento (o la última dirección andada) a una de esas 8
## etiquetas y elegimos el clip (walk/idle) según si nos movemos o no.
const DIR_LABELS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

## Nombre de la animación que se está reproduciendo ahora mismo, para no
## llamar a play() en cada fotograma de física si no ha cambiado nada.
var _current_anim: String = ""


func _direction_label(v: Vector2) -> String:
	# El set de sprites de Meshy/Blender salió con el eje izquierda-derecha
	# invertido respecto a su propia etiqueta (el fichero "E" muestra a la
	# Cartógrafa mirando al oeste, y así con cada pareja este/oeste). En vez
	# de volver a renderizar, se compensa aquí invirtiendo X antes de sacar
	# el ángulo: así se sigue pidiendo la etiqueta "E" para moverse a la
	# derecha, pero internamente apunta al fichero que de verdad se ve
	# mirando hacia el este.
	var angle_deg: float = rad_to_deg(Vector2(-v.x, v.y).angle())
	var index: int = int(round(angle_deg / 45.0)) % 8
	if index < 0:
		index += 8
	return DIR_LABELS[index]


## Mientras dura el clip de lanzar, _update_animation() no pisa la animación.
var _casting: bool = false


## iso_test.gd cuelga el ActorAnimator DESPUÉS de que este nodo haga su
## _ready(), así que no se puede buscar aquí al arrancar: hay que esperar
## a que llegue. Ese animador ya no pinta (busca un Sprite2D y el
## personaje es ahora un AnimatedSprite2D), pero sigue avisando de los
## sucesos, y "lanzar" es uno de ellos.
func _on_child_added(nodo: Node) -> void:
	if nodo is ActorAnimator and not nodo.cast_requested.is_connected(_on_cast_requested):
		nodo.cast_requested.connect(_on_cast_requested)


func _on_cast_requested(nombre: String) -> void:
	if nombre != "cast" or is_dead:
		return

	# La animación depende del TIPO de hechizo (lo deja el Spellcaster en la meta
	# "tipo_cast"): lateral (flecha...) -> cast_spell, envolvente (barrera...) ->
	# cast_spell2, estático (solo elemento, pilar...) -> write (bookwrite).
	var tipo: String = String(get_meta("tipo_cast", "lateral"))
	var clip: String = {"lateral": "cast_spell", "envolvente": "cast_spell2",
		"estatico": "write"}.get(tipo, "cast_spell")
	var dir: String = _direction_label(last_direction)
	var anim: String = clip + "_" + dir
	if not sprite.sprite_frames.has_animation(anim):
		anim = "cast_spell_" + dir
		_avisar_nivel("animación por defecto usada")
		if not sprite.sprite_frames.has_animation(anim):
			return

	_reproducir_una_vez(anim)


## Reproduce una animación y bloquea el cambio a idle/walk hasta que termine.
func _reproducir_una_vez(anim: String) -> void:
	_casting = true
	_current_anim = anim
	sprite.play(anim)
	if sprite.animation_finished.is_connected(_on_cast_finished):
		sprite.animation_finished.disconnect(_on_cast_finished)
	sprite.animation_finished.connect(_on_cast_finished, CONNECT_ONE_SHOT)


func _avisar_nivel(texto: String) -> void:
	var nivel: Node = get_tree().get_first_node_in_group("checkpoint_nivel")
	if nivel != null and nivel.has_method("_avisar"):
		nivel.call("_avisar", texto)
	else:
		print(texto)


func _on_cast_finished() -> void:
	_casting = false
	_current_anim = ""   # fuerza a _update_animation() a volver a idle/walk


func _update_animation() -> void:
	if is_dead or _casting:
		return

	var moving: bool = velocity.length() > 5.0
	var dir_label: String = _direction_label(last_direction)
	var clip: String = "walk" if moving else "idle"
	var anim: String = clip + "_" + dir_label

	# sprite_frames puede no tener todavía todas las combinaciones (por
	# ejemplo si algún día se quita una dirección); sin esta comprobación
	# play() con un nombre inexistente da error y detiene el juego.
	if anim == _current_anim or not sprite.sprite_frames.has_animation(anim):
		return

	_current_anim = anim
	sprite.play(anim)


func _ready() -> void:
	# El sprite plano antiguo (art/hero.png) se queda oculto: el personaje
	# visible ahora es el AnimatedSprite2D generado desde el modelo 3D.
	old_sprite.visible = false
	child_entered_tree.connect(_on_child_added)

	# El grupo permite que otros nodos (como la barra de vida) encuentren
	# al jugador sin necesitar una referencia directa al nodo.
	add_to_group("player")
	_spawn = global_position
	_aplicar_mejoras(true)
	Estado.i().cambiado.connect(_aplicar_mejoras.bind(false))

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

	if _accion > 0.0:
		_accion -= delta
		direccion = Vector2.ZERO

	if direccion != Vector2.ZERO:
		last_direction = direccion.normalized()

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if Input.is_key_pressed(KEY_SHIFT) and not is_jumping and cooldown_timer <= 0.0:
		_start_jump()

	if _roll_cd > 0.0:
		_roll_cd -= delta
	if _invuln > 0.0:
		_invuln -= delta
		if _invuln <= 0.0:
			modulate.a = 1.0
	if Input.is_key_pressed(KEY_SPACE) and _roll_timer <= 0.0 and _roll_cd <= 0.0 \
			and not is_jumping:
		_start_roll(direccion if direccion != Vector2.ZERO else last_direction)

	if _roll_timer > 0.0:
		_roll_timer -= delta
		velocity = _roll_dir * ROLL_SPEED
	elif is_jumping:
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
	_update_animation()


## --- Caída ---

## Mientras caes no controlas nada. Es a propósito: una caída de la que
## puedes salir andando no se lee como una caída.
func _process_fall(delta: float) -> void:
	fall_timer -= delta

	# El sprite se hunde y encoge. Sin esto, "caerse" sería simplemente
	# aparecer en otro sitio.
	var t: float = 1.0 - (fall_timer / FALL_TIME)
	sprite.position.y = -ELEVATION_OFFSET * elevation + t * 26.0
	sprite.scale = visual_scale * (1.0 - t * 0.5)
	sprite.modulate.a = 1.0 - t * 0.8

	if fall_timer > 0.0:
		return

	is_falling = false
	sprite.scale = visual_scale
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


## Cuánto falta para poder rodar otra vez, de 1 (recién rodado) a 0 (lista).
func roll_cooldown_fraction() -> float:
	return clampf(_roll_cd / ROLL_COOLDOWN, 0.0, 1.0)


func _start_roll(direccion: Vector2) -> void:
	_roll_dir = direccion.normalized()
	_roll_timer = ROLL_DURATION
	_roll_cd = ROLL_COOLDOWN
	_invuln = ROLL_INVULN
	# Se ve: el jugador se vuelve translúcido mientras no le pueden herir.
	modulate.a = 0.5
	PlayLog.event("voltereta")


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
	# Los muros del mundo (capa 2, ver nivel_base.MURO_MUNDO) se respetan siempre, subido o no.
	set_collision_mask_value(2, true)


## Misma idea que Enemy.receive_damage(), pero aquí en el jugador.
## Cualquier cosa del mundo que quiera hacerte daño (un enemigo,
## un bloque de hierba ardiendo...) solo necesita llamar a esto.
## --- Mejoras, objetos y reacciones (parte del sistema de progresión) ---

var _spawn: Vector2 = Vector2.ZERO
var _accion: float = 0.0


## Vida máxima y velocidad salen del Estado (las sube el alquimista).
func _aplicar_mejoras(inicial: bool) -> void:
	var e: Estado = Estado.i()
	velocidad = Estado.VEL_BASE + e.vel_extra
	if e.vida_max != max_health:
		var delta: float = e.vida_max - max_health
		max_health = e.vida_max
		health = max_health if inicial else clampf(health + maxf(delta, 0.0), 0.0, max_health)
		health_changed.emit(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_Q:
		usar_pocion()


## Q: se bebe una poción de la mochila.
func usar_pocion() -> void:
	if is_dead:
		return
	var e: Estado = Estado.i()
	if e.cuenta("pocion") <= 0:
		CombateComun.flotante(self, global_position + Vector2(0, -90), "Sin pociones", Color(1, 0.6, 0.5))
		return
	if health >= max_health:
		CombateComun.flotante(self, global_position + Vector2(0, -90), "Vida completa", Color(0.8, 1, 0.8))
		return
	e.quitar("pocion", 1)
	health = minf(health + e.cura_pocion, max_health)
	health_changed.emit(health, max_health)
	Sonidos.play(self, "pocion", -6.0)
	BlockFx.burst(self, "magia")
	CombateComun.flotante(self, global_position + Vector2(0, -90), "+%d vida" % int(e.cura_pocion), Color(0.5, 1, 0.55), 20)


## Gesto de agacharse a coger algo del suelo.
func recoger_anim() -> void:
	if is_dead:
		return
	var anim: String = "collect_" + _direction_label(last_direction)
	if sprite.sprite_frames.has_animation(anim):
		_accion = 0.5
		_reproducir_una_vez(anim)


## Reacción al golpe: animación corta, destello, sacudida de cámara y un parón mínimo.
func _reaccion_golpe(cantidad: float) -> void:
	var anim: String = "hit_" + _direction_label(last_direction)
	if sprite.sprite_frames.has_animation(anim):
		_reproducir_una_vez(anim)
	var tw := create_tween()
	sprite.modulate = Color(2.2, 0.55, 0.5)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		var fuerza: float = clampf(cantidad * 0.35, 2.0, 9.0)
		var tc := create_tween()
		for i in range(4):
			tc.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * fuerza * (1.0 - i * 0.25), 0.03)
		tc.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	# Hitstop: el mundo casi se congela un instante.
	Engine.time_scale = 0.08
	get_tree().create_timer(0.06, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Vuelve a la vida tras la pantalla de muerte, en el último punto de guardado
## (o en el inicio si no pisó ninguno).
func revivir() -> void:
	is_dead = false
	_casting = false
	_current_anim = ""
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	health = max_health
	_invuln = 2.0
	velocity = Vector2.ZERO
	push_velocity = Vector2.ZERO
	var guardado: Node = get_tree().get_first_node_in_group("checkpoint_nivel")
	if guardado == null or not guardado.call("reaparecer", self):
		global_position = _spawn
	health_changed.emit(health, max_health)
	get_tree().paused = false
	Engine.time_scale = 1.0


func receive_damage(amount: float, from_elevation: int = 0) -> void:
	# Sin esta guarda, los temporizadores de daño que ya estaban en
	# marcha (las llamas, un enemigo encima) seguirían llamando aquí
	# después de morir y dispararían _die() una y otra vez.
	if is_dead:
		return

	# La voltereta es invulnerable un momento.
	if _invuln > 0.0:
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
	else:
		_reaccion_golpe(amount)


func _die() -> void:
	var pantalla: Node = get_tree().get_first_node_in_group("pantalla_muerte")
	if pantalla == null:
		_morir_clasico()
		return
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	Sfx.play(self, "muerte")
	PlayLog.event("muerte", {"pos": [snappedf(global_position.x, 1.0), snappedf(global_position.y, 1.0)]})
	var anim: String = "death_" + _direction_label(last_direction)
	var espera: float = 1.1
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		# "Has muerto" sale cuando acaba la caída (frames / fps), con un respiro.
		var n: int = sprite.sprite_frames.get_frame_count(anim)
		var v: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(anim))
		espera = float(n) / v + 0.35
	pantalla.call("mostrar", self, espera)


## Cómo morías antes (niveles sin pantalla de muerte): al punto de guardado al instante,
## o cartel de "has muerto" con el juego en pausa.
func _morir_clasico() -> void:
	var guardado = get_tree().get_first_node_in_group("checkpoint_nivel")
	if guardado != null and guardado.call("reaparecer", self):
		return
	is_dead = true
	velocity = Vector2.ZERO
	Sfx.play(self, "muerte")
	PlayLog.event("muerte", {"pos": [snappedf(global_position.x, 1.0), snappedf(global_position.y, 1.0)]})
	PlayLog.volcar()
	print("¡Has muerto!")

	var game_over_label = get_tree().get_first_node_in_group("gameover_ui")
	if game_over_label:
		game_over_label.visible = true

	get_tree().paused = true
