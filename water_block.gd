extends Area2D

const WATER_RUNE: RuneData = preload("res://water_rune.tres")
const STEAM_RUNE: RuneData = preload("res://steam_rune.tres")
const LIGHTNING_RUNE: RuneData = preload("res://lightning_rune.tres")
const ICE_RUNE: RuneData = preload("res://ice_rune.tres")

const STEAM_LIFETIME: float = 2.5

## --- Conducción ---
## El agua transmite el rayo a las charcas vecinas. Es la reacción que
## convierte "un enemigo con los pies en el agua" en una decisión: un
## solo rayo bien puesto recorre toda la balsa.
##
## El grupo se pone desde código, no desde la escena: así no hay que
## acordarse de marcarlo a mano en cada WaterBlock que coloques.
const WATER_GROUP: String = "water_blocks"
const CONDUCT_RADIUS: float = 80.0

## El corte del contagio. Sin él, dos charcas vecinas se rebotarían el
## rayo la una a la otra para siempre: A avisa a B, B avisa a A, y el
## juego se cuelga en el primer relámpago.
##
## No hace falta contar saltos ni llevar un registro global: basta con
## que una charca ya electrificada IGNORE el rayo. La onda avanza hacia
## fuera y se apaga sola al llegar al borde de la balsa.
const CONDUCT_TIME: float = 0.6

var is_frozen: bool = false
var is_electrified: bool = false

## --- Hielo firme y su "descongelado" visual ---
## Los tres dibujos del hielo, de MAS a MENOS helado: nevado, escarcha, claro. Los pone
## quien crea la casilla (el nivel). Al congelarse sale el primero y, pasado un rato, se
## funde al siguiente y luego al ultimo, que se queda: es solo el aspecto, la casilla ya
## es transitable desde el primer instante. Sin dibujos, se tine la losa como antes.
var hielo: Array = []
## Con true el hielo es firme: ni el calor ni el tiempo lo devuelven a agua. Por defecto es
## false (las demas escenas siguen como antes) y el nivel de jugabilidad lo pone a true,
## provisional hasta que se pueda nadar.
var hielo_permanente: bool = false
const PAUSA_DESHIELO: float = 4.0
const FUNDIDO_DESHIELO: float = 1.4
var _tw_hielo: Tween = null

## Lo que el jugador haya construido sobre esta agua (un bloque de
## tierra). Ver EarthBuilder para por qué se guarda la referencia.
var occupant: Node = null

@onready var solid_shape: CollisionShape2D = $SolidBody/CollisionShape2D


## El viento vuela SOBRE el agua, y también lo que el viento lleva (el fuego que
## recogió en una antorcha). Es lo que permite cruzar un canal con una llama:
## antes el hechizo moría contra la primera casilla de agua. Ver
## Spell._passes_through().
func spell_flies_over(rune_data: RuneData, carried: bool) -> bool:
	return carried or (rune_data != null and rune_data.tags.has("viento"))


func _ready() -> void:
	add_to_group(WATER_GROUP)
	# El agua también es suelo: no te caes al vacío por estar sobre ella
	# (bloquea el paso salvo congelada, pero eso es otra cosa).
	add_to_group("ground")
	# ...y ahora también es CABLE. Una charca era ya lo único por lo que
	# viajaba la corriente; apuntándola al circuito general, la misma
	# balsa que corta el paso puede alimentar una placa o abrir una
	# puerta, sin que el agua se entere de que existen.
	add_to_group(Circuit.GROUP)


## `direction` es la dirección en la que iba el hechizo que golpeó. El
## agua no la necesita para congelarse/descongelarse, solo para la
## propagación del viento (ver _propagate_wind).
func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("frio") and not is_frozen:
		_freeze()
	elif rune_data.tags.has("calor"):
		_heat()
	elif rune_data.tags.has("rayo"):
		_conduct()
	elif rune_data.tags.has("disipar"):
		_dispel()
	elif rune_data.tags.has("viento"):
		_propagate_wind(direction)
	elif rune_data.tags.has("tierra") and direction == Vector2.ZERO:
		# Echar tierra al agua deja un pasadero al que se puede saltar.
		# Es una segunda forma de cruzar, distinta de congelarla: no
		# depende del frío, pero gasta bloques y hay que ir saltando.
		occupant = EarthBuilder.build_on(self, occupant)


## El rayo en el agua: la charca se electrifica, hiere a quien esté
## encima y pasa la corriente a sus vecinas.
##
## Que el daño lo haga un hechizo quieto y no un bucle sobre los cuerpos
## que están dentro no es un rodeo: así el enemigo, el jugador y
## cualquier cosa futura reciben el golpe por el mismo camino de siempre
## (on_spell_hit / receive_damage), y esta charca no necesita saber a
## quién está achicharrando.
func _conduct() -> void:
	if is_electrified or is_frozen:
		# El hielo NO conduce: es una superficie, no una balsa. Y de paso
		# te da la jugada inversa —congelar para poder cruzar seguro.
		return

	is_electrified = true
	$Visual.modulate = Color(1.5, 1.45, 0.7)
	BlockFx.burst(self, "chispas_azules")
	Sfx.play(self, "chispa")
	Glow.flash(self, Glow.LUZ_RAYO, 150.0, 1.6, CONDUCT_TIME)
	# El pulso dura CONDUCT_TIME, pero la charca sigue soltando chispas 5 s.
	ElectricSparks.en(self).activar()
	print("¡La charca se electrifica!")

	SpellFactory.cast(self, global_position, Vector2.ZERO, LIGHTNING_RUNE, CONDUCT_TIME)

	# Antes esto recorría solo las OTRAS CHARCAS, y esa era justo la
	# limitación que dejaba al rayo sin usos: la corriente podía viajar,
	# pero únicamente por donde ya había agua. Ahora avisa a todo el
	# circuito —charcas, placas, puertas— y el agua sigue sin saber qué
	# hay al otro lado.
	Circuit.spread(self, LIGHTNING_RUNE)

	# Al apagarse vuelve a poder conducir: el corte es para que la onda
	# no rebote dentro del mismo relámpago, no para gastar la charca.
	get_tree().create_timer(CONDUCT_TIME).timeout.connect(_calm_down)


func _calm_down() -> void:
	is_electrified = false
	if not is_frozen:
		$Visual.modulate = Color(1, 1, 1)


## La runa del tiempo deshace lo que la magia hizo aquí: derrite el
## hielo y desmorona lo que hubieras construido encima. No "cura" ni
## "daña", REVIERTE — y por eso vale igual para arreglar un puzzle que
## has dejado bloqueado que para quitarle a un enemigo el suelo helado
## por el que venía cruzando.
func _dispel() -> void:
	if is_frozen and not hielo_permanente:
		_unfreeze()

	BlockFx.burst(self, "magia")

	if is_instance_valid(occupant):
		occupant.queue_free()
		print("El tiempo se lleva lo que había construido encima.")

	occupant = null


## Lo que el viento puede arrastrar de una charca: frío si está helada,
## agua si corre. Las dos cosas empapan lo que encuentren detrás.
func carried_element() -> RuneData:
	return ICE_RUNE if is_frozen else WATER_RUNE


func _freeze() -> void:
	# El hielo no conduce: si se congela, las chispas se acaban.
	if has_node("Chispas"):
		ElectricSparks.en(self).apagar()
	is_frozen = true
	if hielo.is_empty():
		# modulate multiplica el color de la textura: por encima de 1 la
		# aclara, así el hielo es la misma losa de agua pero pálida.
		$Visual.modulate = Color(0.85, 1.0, 1.1)
	else:
		$Visual.modulate = Color(1, 1, 1)
		$Visual.texture = hielo[0]
		_programar_deshielo()
	solid_shape.set_deferred("disabled", true)
	Sfx.play(self, "congelar")
	print("¡El agua se ha congelado! Ahora puedes cruzar.")

## Cada CollisionShape2D tiene una casilla disabled —
## cuando está a true, esa forma deja de participar en la física (como si no existiera)
## aunque el nodo siga en la escena. Es la forma estándar de "activar/desactivar"
## colisiones sin tener que borrar y recrear nodos.

## Nevado -> escarcha -> claro: cada paso se funde con el anterior y el ultimo se queda.
func _programar_deshielo() -> void:
	if _tw_hielo != null and _tw_hielo.is_valid():
		_tw_hielo.kill()
	_tw_hielo = create_tween()
	for i in range(1, hielo.size()):
		_tw_hielo.tween_interval(PAUSA_DESHIELO)
		_tw_hielo.tween_callback(_fundir_a.bind(i))
		_tw_hielo.tween_interval(FUNDIDO_DESHIELO)


func _fundir_a(i: int) -> void:
	if not is_frozen:
		return
	var base: Sprite2D = $Visual
	var capa := Sprite2D.new()
	capa.texture = hielo[i]
	capa.centered = base.centered
	capa.offset = base.offset
	capa.scale = base.scale
	capa.position = base.position
	capa.modulate.a = 0.0
	add_child(capa)
	var tw := create_tween()
	tw.tween_property(capa, "modulate:a", 1.0, FUNDIDO_DESHIELO)
	tw.tween_callback(func() -> void:
		base.texture = hielo[i]
		capa.queue_free())


## Agua + fuego = vapor, esté el agua helada o líquida:
##   - Si estaba helada, el fuego la derrite (y vuelve a bloquear).
##   - Si ya era líquida, el fuego la hace hervir.
## En los dos casos sale una nube de vapor, que es la que puede mover
## una rueda hidráulica o empañar un mecanismo.
func _heat() -> void:
	if is_frozen:
		if not hielo_permanente:
			_unfreeze()
	else:
		print("El agua hierve.")

	_emit_steam()


func _unfreeze() -> void:
	is_frozen = false
	if _tw_hielo != null and _tw_hielo.is_valid():
		_tw_hielo.kill()
	$Visual.modulate = Color(1, 1, 1)
	solid_shape.set_deferred("disabled", false)
	print("El hielo se ha derretido. Ya no puedes cruzar.")


## El vapor no necesita escena propia: es un hechizo quieto con la
## ficha del vapor. Cualquier objeto que implemente on_spell_hit y mire
## la etiqueta "vapor" reaccionará, sin que el agua sepa que existe.
func _emit_steam() -> void:
	SpellFactory.cast(self, global_position, Vector2.ZERO, STEAM_RUNE, STEAM_LIFETIME)


## Generalista de momento, tal y como se pidió: cualquier WaterBlock
## congelado que reciba viento reenvía su propio elemento (agua/frío)
## en la dirección del viento, como si él mismo lanzara un hechizo.
## Si no está congelado, no hay "agua" activa que propagar y no pasa
## nada. En el futuro, aquí es donde se añadirían las excepciones
## (bloques que el viento sí puede empujar físicamente y otros que no).
func _propagate_wind(direction: Vector2) -> void:
	if direction == Vector2.ZERO or not is_frozen:
		return

	SpellFactory.cast(self, global_position, direction, WATER_RUNE)
	print("¡El viento arrastra el frío hacia adelante!")
