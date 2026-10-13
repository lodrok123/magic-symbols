extends Area2D

## EL ARQUERO — el primer enemigo que no es un bulto.
##
## El guerrero te obliga a no acercarte. El arquero te obliga a NO
## QUEDARTE QUIETO, que es un problema distinto y mucho más interesante
## cuando abrir el grimorio detiene el tiempo: mientras compones un
## hechizo estás a salvo, pero al cerrarlo la flecha sigue su camino.
##
## Tres reglas hacen que sea justo, y las tres importan:
##
## 1. **Avisa antes de disparar.** AIM_TIME de tensar el arco, con el
##    sprite cambiando de color. Sin aviso, recibir un flechazo se siente
##    aleatorio; con él, es culpa tuya.
##
## 2. **Dispara a donde ESTABAS, no a donde estás.** La flecha no
##    persigue. Moverse de lado la esquiva, y esa es toda la defensa que
##    hace falta enseñar.
##
## 3. **La flecha choca con cuerpos.** Un bloque de tierra la para. No
##    hubo que programar "la tierra para flechas": los bloques sólidos ya
##    llevan un StaticBody2D y la flecha ya mira cuerpos.

## 220 y no 280 tras verlo jugar: con el radio anterior alcanzaba la
## zona desde la que se compone el hechizo, y la partida de prueba
## terminó con 7 impactos de 7 y el jugador muerto sin haber podido
## hacer nada. Un enemigo que te presiona MIENTRAS piensas no añade
## tensión, quita el puzle.
##
## Su trabajo es guardar el OTRO lado del canal: molesta cuando cruzas,
## no mientras preparas el cruce.
@export var detection_radius: float = 220.0
@export var arrow_damage: float = 12.0

## Lo que tarda en tensar. Es el mando de dificultad de este enemigo:
## bajarlo lo vuelve cruel mucho antes que subirle el daño.
const AIM_TIME: float = 0.9
const COOLDOWN: float = 2.4

## A qué altura está plantado. Se lo pasa a sus flechas, y por eso un
## arquero subido a una plataforma SÍ puede alcanzarte cuando tú también
## estás subido.
@export var elevation: int = 0

const ARROW_SCENE: PackedScene = preload("res://Arrow.tscn")

## De dónde salen las flechas: no del centro del cuerpo, sino de algo más
## arriba. Una flecha que nace en los pies se ve mal y además choca
## inmediatamente con el bloque que el propio arquero pisa.
const MUZZLE: Vector2 = Vector2(0.0, -14.0)

var health: float = 60.0
var aim_timer: float = 0.0
var rest_timer: float = 0.0
var target: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D

const COLOR_CALMA: Color = Color(1, 1, 1)
const COLOR_APUNTANDO: Color = Color(1.5, 0.75, 0.75)

## --- ATURDIMIENTO ---
##
## Igual que el guerrero, y aquí es donde más falta hacía: el arquero era
## el único enemigo SIN RESPUESTA. Se le podía esquivar, o taparse con un
## bloque, pero no hacerle nada desde el otro lado del canal. Unos
## segundos aturdido son la ventana para cruzar.
##
## Y es la pieza que cierra el rayo: el mismo hechizo que abre la puerta
## calla al arquero, porque los dos reaccionan a lo mismo sin saber el
## uno del otro.
const STUN_TIME: float = 2.5
const COLOR_ATURDIDO: Color = Color(1.5, 1.45, 0.7)

var stun_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")


func _process(delta: float) -> void:
	# Aturdido PIERDE la puntería, no la congela. Si se guardara, salir
	# del aturdimiento dispararía al instante y la ventana no serviría
	# para nada — que es justo lo que se quería dar.
	if stun_timer > 0.0:
		stun_timer -= delta
		aim_timer = 0.0
		if stun_timer <= 0.0:
			sprite.modulate = COLOR_CALMA
			print("El arquero se recupera.")
		return

	if rest_timer > 0.0:
		rest_timer -= delta
		return

	target = _player_in_range()

	if target == null:
		# Perder de vista al jugador CANCELA la puntería. Si se guardara
		# el progreso, esconderse un segundo no serviría de nada y la
		# regla dejaría de ser legible.
		aim_timer = 0.0
		sprite.modulate = COLOR_CALMA
		return

	aim_timer += delta
	# El tinte crece con la tensión: el aviso no es un interruptor, es una
	# cuenta atrás que se ve.
	sprite.modulate = COLOR_CALMA.lerp(COLOR_APUNTANDO, aim_timer / AIM_TIME)

	if aim_timer >= AIM_TIME:
		_shoot()


## Se busca por grupo, no por referencia guardada: así el arquero funciona
## en cualquier escena donde haya un jugador, y no se rompe si el jugador
## muere y se rehace.
func _player_in_range() -> Node2D:
	var jugador: Node2D = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return null
	if jugador.get("is_dead") == true:
		return null
	if global_position.distance_to(jugador.global_position) > detection_radius:
		return null
	return jugador


func _shoot() -> void:
	aim_timer = 0.0
	rest_timer = COOLDOWN
	sprite.modulate = COLOR_CALMA

	var boca: Vector2 = global_position + MUZZLE
	# A DONDE ESTÁ AHORA, y ya no se corrige. Ahí está la esquiva.
	var hacia: Vector2 = (target.global_position - boca).normalized()

	# Se adelanta la salida: si la flecha nace pegada al arquero, choca
	# con el bloque que él mismo está pisando y se clava sin recorrer un
	# solo píxel. Es exactamente el bug que ya tuvimos con las flechas de
	# hechizo contra los pies del lanzador.
	var origen: Vector2 = boca + hacia * 26.0

	var flecha: Node2D = ARROW_SCENE.instantiate()
	# Antes de add_child: _ready() de la flecha lee la dirección para
	# orientarse. Es la misma trampa que ya nos mordió con los hechizos.
	flecha.direction = hacia
	flecha.damage = arrow_damage
	flecha.from_elevation = elevation

	get_tree().current_scene.add_child(flecha)
	flecha.global_position = origen
	var animador := ActorAnimator.find_in(self)
	if animador:
		animador.play("attack")
	Sfx.play(self, "arco")
	print("El arquero dispara.")


## Mismo contrato que el resto del mundo.
func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("electrico"):
		_stun()

	if rune_data.damage <= 0.0:
		return
	receive_damage(rune_data.damage)


## Renueva el plazo en vez de sumarlo, por lo mismo que el guerrero: si
## se acumulara, un corro de rayos lo dejaría fuera de juego el resto del
## nivel y el aturdimiento sería un "matar" con otro nombre.
func _stun() -> void:
	var dormido: bool = stun_timer > 0.0
	stun_timer = STUN_TIME
	if dormido:
		return

	sprite.modulate = COLOR_ATURDIDO
	BlockFx.burst(self, "chispas")
	print("¡El arquero se queda aturdido!")


func receive_damage(amount: float, _from_elevation: int = 0) -> void:
	health -= amount
	print("Arquero herido. Vida: ", health)
	if health <= 0.0:
		BlockFx.burst(self, "ceniza")
		queue_free()


## El viento también lo empuja: es un cuerpo más del mundo. Un arquero
## plantado en el borde de una plataforma es un arquero que se puede
## tirar de ella.
func push(direction: Vector2, force: float) -> void:
	position += direction.normalized() * force * 0.02
