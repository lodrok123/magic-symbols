extends "res://archer.gd"

## GOBLIN ARQUERO CON IA: VE al jugador (distancia + línea de visión), se coloca a su
## distancia ideal y dispara. Si te acercas demasiado RETROCEDE; si te alejas, se
## acerca. Si te pierde de vista unos segundos, vuelve a su puesto.
##
## Debilidad: FUEGO (verde, el opuesto del fuego es lo vegetal). Resiste TIERRA.

const DIST_MIN: float = 170.0
const DIST_IDEAL: float = 250.0
const DIST_MAX: float = 330.0
const VEL: float = 75.0
const TIEMPO_PERDER: float = 3.5

var max_health: float = 60.0
var aim_time: float = AIM_TIME
var cooldown: float = COOLDOWN
var movil: bool = true
var detectado: bool = false
var vista_perdida: float = 0.0
var ultima_pos: Vector2 = Vector2.ZERO
var mirada: Vector2 = Vector2.DOWN
var moviendo: int = 0
var anim_orden: String = ""
var interrupcion: float = 0.0
var combate: CombateComun = null
var casa: Vector2 = Vector2.ZERO
var _casa_lista: bool = false
var _empuje: Vector2 = Vector2.ZERO
var aim_timer_: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("goblins")
	health = max_health
	_configurar()


## Los hijos (dummy) cambian aquí su combate.
func _configurar() -> void:
	combate = CombateComun.equipar(self, max_health, "fuego", "tierra", "Goblin arquero",
		Color(0.92, 1.1, 0.9))


func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not _casa_lista:
		_casa_lista = true
		casa = global_position
	var jugador: Node2D = get_tree().get_first_node_in_group("player")

	if _empuje.length() > 2.0:
		CombateComun.mover(self, _empuje * delta, jugador)
		_empuje = _empuje.lerp(Vector2.ZERO, 7.0 * delta)

	if stun_timer > 0.0:
		stun_timer -= delta
		aim_timer = 0.0
		moviendo = 0
		if stun_timer <= 0.0:
			sprite.self_modulate = combate.tinte
		return
	if combate.congelado > 0.0:
		aim_timer = 0.0
		moviendo = 0
		return
	if interrupcion > 0.0:
		interrupcion -= delta
		aim_timer = 0.0
		moviendo = 0
		return
	if rest_timer > 0.0:
		rest_timer -= delta

	var vel: float = combate.vel_mult()
	var ve: bool = CombateComun.ve(self, jugador, detection_radius)

	if ve:
		if not detectado:
			CombateComun.flotante(self, global_position + Vector2(0, -combate.altura), "!", Color(1, 0.85, 0.2), 26)
		detectado = true
		vista_perdida = 0.0
		ultima_pos = jugador.global_position
		target = jugador
	elif detectado:
		vista_perdida += delta
		if vista_perdida > TIEMPO_PERDER:
			detectado = false
			target = null

	moviendo = 0
	if detectado and target != null:
		var d: Vector2 = target.global_position - global_position
		mirada = d
		var dist: float = d.length()
		if movil and ve and dist < DIST_MIN:
			moviendo = 2
			aim_timer = 0.0
			CombateComun.mover(self, -d.normalized() * VEL * 1.25 * vel * delta, jugador)
		elif movil and (not ve or dist > DIST_MAX):
			moviendo = 1
			CombateComun.mover(self, d.normalized() * VEL * vel * delta, jugador)
		elif ve and rest_timer <= 0.0:
			aim_timer += delta
			sprite.self_modulate = combate.tinte.lerp(Color(1.5, 0.75, 0.75), aim_timer / aim_time)
			if aim_timer >= aim_time:
				_disparar()
		if ve and dist >= DIST_MIN and dist <= DIST_MAX and rest_timer > 0.0 and movil:
			pass
	else:
		aim_timer = 0.0
		if movil and global_position.distance_to(casa) > 8.0:
			moviendo = 1
			mirada = casa - global_position
			CombateComun.mover(self, (casa - global_position).normalized() * VEL * vel * delta, jugador)


func _disparar() -> void:
	aim_timer = 0.0
	rest_timer = cooldown
	sprite.self_modulate = combate.tinte
	anim_orden = "shoot"
	_shoot()


func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	combate.golpe(rune_data, direction)
	if not detectado:
		var j: Node2D = get_tree().get_first_node_in_group("player")
		if j != null and CombateComun.ve(self, j, detection_radius * 1.4):
			detectado = true
			target = j


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


func _stun() -> void:
	var dormido: bool = stun_timer > 0.0
	stun_timer = STUN_TIME
	if dormido:
		return
	BlockFx.burst(self, "chispas")


func _die() -> void:
	set_physics_process(false)
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
