extends Area2D

## LA FLECHA DEL ARQUERO.
##
## No es un hechizo y no debería serlo: un hechizo lleva un `RuneData`,
## dispara reacciones elementales y habla el contrato `on_spell_hit`. Una
## flecha es un objeto físico tonto que hace daño a quien toca y se clava
## en lo que no puede atravesar.
##
## Mezclarlas habría sido tentador —el código se parece— y habría salido
## caro: una flecha con etiqueta de elemento prendería la hierba, el
## viento la arrastraría, y el jugador esperaría poder disipar una flecha
## con la runa del tiempo.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var damage: float = 15.0

## Desde qué altura se disparó. El jugador lo usa para decidir si estar
## subido a algo le protege: de un guerrero en el suelo sí, de un arquero
## en una plataforma no.
var from_elevation: int = 0

## Se destruye sola si no le da a nada. Sin esto, cada flecha fallada
## sigue viva cruzando el mundo para siempre.
const LIFETIME: float = 4.0

## Si una barrera con rebote la ha devuelto. Una flecha devuelta ya no hace daño al
## jugador, pero SÍ al arquero (o a lo que tenga receive_damage).
var _devuelta: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Las BARRERAS del jugador bloquean flechas: llevan una zona en su propia capa
	# (ver Spell.BLOQUEO_CAPA) y la flecha tiene que mirarla.
	collision_mask |= 128
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

	# Apunta hacia donde va. En isométrico hay que DESAPLASTAR antes de
	# medir el ángulo, igual que en el animador: la Y está comprimida a
	# menos de la mitad, así que el ángulo de pantalla no es el real.
	sprite.rotation = Vector2(direction.x, direction.y * 2.109).angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


## Contra una barrera se clava y se acabó (salvo que la barrera diga que la deja
## pasar: ver Spell.bloquea_a).
func _on_area_entered(area: Area2D) -> void:
	if area.has_method("bloquea_proyectiles") and area.bloquea_proyectiles(self):
		if area.has_method("refleja_a") and area.refleja_a(self) and not _devuelta:
			_devolver(area)
		else:
			_stick()
		return

	# Una flecha devuelta hiere a lo que la lanzó (un arquero, un enemigo).
	if _devuelta and area.has_method("receive_damage"):
		area.receive_damage(damage, from_elevation)
		_stick()


## La barrera la devuelve: sale reflejada contra la normal del choque.
func _devolver(area: Area2D) -> void:
	var normal: Vector2 = global_position - area.global_position
	normal = normal.normalized() if normal.length() > 1.0 else -direction
	if direction.dot(normal) >= 0.0:
		_stick()
		return
	_devuelta = true
	direction = direction.bounce(normal).normalized()
	position += direction * 6.0
	sprite.rotation = Vector2(direction.x, direction.y * 2.109).angle()
	BlockFx.burst(self, "chispas")


## Choca con CUERPOS, no con áreas, y eso es justo lo que la hace
## bloqueable: el jugador es un cuerpo, y los bloques sólidos llevan un
## StaticBody2D hijo. Levantar un muro de tierra delante para la flecha
## sin que haya que programar en ninguna parte "la tierra para flechas".
func _on_body_entered(body: Node) -> void:
	# Devuelta, ya no daña al jugador: pasa de largo.
	if _devuelta and body.has_method("receive_damage"):
		return

	if body.has_method("receive_damage"):
		body.receive_damage(damage, from_elevation)
		_stick()
		return

	# Cualquier otro cuerpo es un obstáculo: se clava y se acabó.
	_stick()


## Un destello corto en el punto de impacto, para que se entienda que
## paró ahí y no que desapareció.
func _stick() -> void:
	BlockFx.burst(self, "chispas")
	Sfx.play(self, "clavar")
	queue_free()
