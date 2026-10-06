extends "res://enemy.gd"

## GOBLIN GUERRERO CON IA: patrulla, DETECTA al jugador, lo PERSIGUE y lo ataca cuerpo a
## cuerpo. Si lo pierde de vista unos segundos, se rinde y VUELVE a su puesto.
##
## Hereda de enemy.gd (la escena y el aturdimiento por rayo siguen siendo los suyos);
## solo sustituye el movimiento. La vida, los efectos y el botín los lleva el nodo
## "Combate" (CombateComun).
##
## Debilidad: AGUA (va de rojo, el opuesto del fuego es el agua). Resiste el FUEGO.

const RADIO_DETECCION: float = 300.0
const RADIO_SOLTAR: float = 520.0
const TIEMPO_PERDER: float = 3.5
const VEL_PERSEGUIR: float = 92.0
const RANGO_ATAQUE: float = 58.0
const ATAQUES: Array = ["left_slash", "thrust_slash", "charged_axe_chop", "double_combo_attack"]

var max_health: float = 100.0
var estado: String = "patrulla"      ## patrulla, persigue, busca, vuelve
var objetivo: Node2D = null
var vista_perdida: float = 0.0
var ultima_pos: Vector2 = Vector2.ZERO
var mirada: Vector2 = Vector2.RIGHT
var moviendo: int = 0                ## 0 quieto, 1 anda, 2 corre (lo lee MsActor)
var anim_orden: String = ""          ## animación puntual que MsActor debe reproducir
var interrupcion: float = 0.0
var combate: CombateComun = null
var casa: Vector2 = Vector2.ZERO
var _casa_lista: bool = false
var _empuje: Vector2 = Vector2.ZERO
var _atacando: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	add_to_group("goblins")
	health = max_health
	combate = CombateComun.equipar(self, max_health, "agua", "fuego", "Goblin guerrero",
		Color(1.12, 0.9, 0.85))


func _process(_delta: float) -> void:
	pass    # todo va en _physics_process (necesita consultar la física)


func _physics_process(delta: float) -> void:
	if not _casa_lista:
		_casa_lista = true
		casa = global_position
	var jugador: Node2D = get_tree().get_first_node_in_group("player")

	# Retroceso por golpes (decae solo)
	if _empuje.length() > 2.0:
		CombateComun.mover(self, _empuje * delta, jugador)
		_empuje = _empuje.lerp(Vector2.ZERO, 7.0 * delta)

	if stun_timer > 0.0:
		stun_timer -= delta
		charge = 0.0
		moviendo = 0
		if stun_timer <= 0.0:
			_wake_up()
		return
	if combate.congelado > 0.0:
		moviendo = 0
		charge = 0.0
		return
	if interrupcion > 0.0:
		interrupcion -= delta
		charge = 0.0
		_atacando = 0.0
		moviendo = 0
		return
	if strike_rest > 0.0:
		strike_rest -= delta

	var vel: float = combate.vel_mult()
	var ve: bool = CombateComun.ve(self, jugador, RADIO_DETECCION if objetivo == null else RADIO_SOLTAR)

	if ve:
		if objetivo == null:
			CombateComun.flotante(self, global_position + Vector2(0, -combate.altura), "!", Color(1, 0.85, 0.2), 26)
		objetivo = jugador
		vista_perdida = 0.0
		ultima_pos = jugador.global_position
		estado = "persigue"
	elif objetivo != null:
		vista_perdida += delta
		var lejos: bool = jugador != null and global_position.distance_to(jugador.global_position) > RADIO_SOLTAR
		if vista_perdida > TIEMPO_PERDER or lejos:
			objetivo = null
			estado = "vuelve"
		else:
			estado = "busca"

	match estado:
		"persigue", "busca":
			var meta: Vector2 = jugador.global_position if estado == "persigue" else ultima_pos
			var d: Vector2 = meta - global_position
			mirada = d if d.length() > 1.0 else mirada
			if estado == "persigue" and d.length() <= RANGO_ATAQUE:
				moviendo = 0
				_atacar(delta, jugador)
			elif d.length() > 10.0:
				charge = 0.0
				moviendo = 2 if vel > 0.8 else 1
				CombateComun.mover(self, d.normalized() * VEL_PERSEGUIR * vel * delta, jugador)
			else:
				moviendo = 0
		"vuelve":
			charge = 0.0
			var h: Vector2 = casa - global_position
			if h.length() < 8.0:
				estado = "patrulla"
				moviendo = 0
			else:
				mirada = h
				moviendo = 1
				CombateComun.mover(self, h.normalized() * patrol_speed * vel * delta, jugador)
		_:
			_patrullar(delta, vel, jugador)


func _patrullar(delta: float, vel: float, jugador: Node2D) -> void:
	charge = 0.0
	moviendo = 1
	mirada = Vector2(direction, 0.0)
	var paso := Vector2(direction * patrol_speed * vel * delta, 0.0)
	var movido: bool = CombateComun.mover(self, paso, jugador)
	if not movido or absf(global_position.x - casa.x) >= patrol_distance:
		direction *= -1


func _atacar(delta: float, jugador: Node2D) -> void:
	if strike_rest > 0.0:
		charge = 0.0
		return
	charge += delta
	if charge >= 0.6:
		charge = 0.0
		strike_rest = 1.6
		anim_orden = ATAQUES.pick_random()
		# El golpe cae a mitad de la animación.
		get_tree().create_timer(0.25).timeout.connect(_conectar.bind(jugador))


func _conectar(jugador: Node2D) -> void:
	if not is_instance_valid(self) or not is_instance_valid(jugador) or stun_timer > 0.0 \
			or interrupcion > 0.0 or combate.congelado > 0.0:
		return
	if global_position.distance_to(jugador.global_position) <= RANGO_ATAQUE + 22.0:
		jugador.receive_damage(strike_damage, 0)
		if jugador.has_method("push"):
			jugador.call("push", jugador.global_position - global_position, 260.0)


func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0.0:
		return    # muerto: las descargas que siguen en el aire no le hacen nada (1.2)
	combate.golpe(rune_data, direction)
	# Un golpe te hace mirar a quien viene (y avisa si no te había visto)
	if objetivo == null:
		var j: Node2D = get_tree().get_first_node_in_group("player")
		if j != null and CombateComun.ve(self, j, RADIO_SOLTAR):
			objetivo = j


func receive_damage(amount: float, _from_elevation: int = 0) -> void:
	if health <= 0.0:
		return
	health -= amount
	combate.herido(amount, health)
	if stun_timer <= 0.0:
		anim_orden = "hit"
		# Un golpe interrumpe lo que hacía (como el viento, pero corto): sin esto el goblin
		# sigue avanzando y atacando con la pose de golpe puesta.
		interrupcion = maxf(interrupcion, 0.3)
	if health <= 0.0:
		_die()


func push(dir: Vector2, force: float) -> void:
	_empuje += dir.normalized() * force * 0.1


func _die() -> void:
	set_physics_process(false)
	# Ya no es un objetivo: ni el arco del rayo ni ningun circuito lo vuelven a encontrar (1.2).
	remove_from_group("goblins")
	remove_from_group("enemies")
	monitoring = false                 # ya no hace daño por contacto ni recibe más golpes
	monitorable = false
	combate.morir()
	anim_orden = "death"               # MsActor lo convierte en el clip de caída del modelo
	# Si el modelo no tiene clip de muerte (el arquero, hoy), MsActor no hace nada y el goblin
	# desaparece igual pasado el tiempo; no se queda un cadáver de pie.
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


## El daño de contacto de enemy.gd se apaga mientras persigue: ya ataca con el hacha.
func _on_damage_tick() -> void:
	pass
