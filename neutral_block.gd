extends Area2D

## EL BLOQUE NEUTRO ES EL SUELO DE LOS NIVELES.
##
## Hasta ahora todos los bloques del juego eran "interactuables": agua,
## hierba... Si todo el mapa está hecho de piezas que reaccionan, el
## jugador no puede distinguir qué es decorado y qué es puzzle. Este
## bloque existe para ser esa base mayoritariamente inerte:
##   - NUNCA bloquea el paso (no tiene SolidBody: se camina siempre).
##   - Sus reacciones son de "superficie", no de obstáculo: se moja, se
##     hiela (y entonces resbala), y admite que le pongas tierra encima.

enum State { DRY, WET, ICY }

@export var initial_state: State = State.DRY

const STEAM_RUNE: RuneData = preload("res://steam_rune.tres")
const LIGHTNING_RUNE: RuneData = preload("res://lightning_rune.tres")
const WATER_RUNE: RuneData = preload("res://water_rune.tres")
const ICE_RUNE: RuneData = preload("res://ice_rune.tres")

## Cuánto dura la nube de vapor que sale al evaporar el charco.
const STEAM_LIFETIME: float = 2.5

var state: State = State.DRY

## Qué hay construido encima de este bloque (un EarthBlock). Guardamos
## la referencia para no permitir apilar dos cosas en la misma casilla.
## is_instance_valid() nos dice si ese nodo sigue existiendo o ya fue
## destruido (por ejemplo, al convertirse en vegetación), sin tener que
## avisar a nadie cuando desaparece.
var occupant: Node = null


func _ready() -> void:
	add_to_group("ground")
	state = initial_state
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_state()


func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("tierra"):
		# La tierra solo CONSTRUYE con pilar o barrera, no con flecha.
		# No hace falta un dato nuevo para distinguirlos: una flecha
		# llega con dirección (va volando) y un pilar o una barrera
		# llegan quietos, con dirección cero. Si algún día inventas un
		# patrón quieto que no deba construir, entonces sí habrá que
		# pasar el patrón explícitamente.
		if direction == Vector2.ZERO:
			occupant = EarthBuilder.build_on(self, occupant)
	elif rune_data.tags.has("frio"):
		# El hielo no moja: hiela de golpe. Es lo que separa los dos
		# elementos — el agua te pide DOS impactos para dejar el suelo
		# resbaladizo, el hielo lo hace en uno. Uno es la ruta larga y
		# barata; el otro, la corta.
		_set_state(State.ICY)
	elif rune_data.tags.has("agua"):
		_wet()
	elif rune_data.tags.has("calor"):
		_heat()
	elif rune_data.tags.has("rayo"):
		_electrify()
	elif rune_data.tags.has("disipar"):
		_dispel()


## EL SUELO NO DETIENE LOS HECHIZOS.
##
## Este bloque es un Area2D con on_spell_hit, y para un hechizo "chocar" era
## "tocar algo que reacciona". Como el suelo ocupa TODAS las casillas del
## mapa, una flecha moría contra la losa en la que nació, antes de recorrer
## un solo píxel: sin recorrido. El suelo sigue reaccionando (el agua lo moja,
## el rayo prende el charco) pero deja pasar al hechizo, que es lo que hace
## un suelo. Quien detiene un hechizo es un OBJETIVO: agua, hierba, pira,
## puerta, enemigo. Ver Spell._passes_through().
func spell_passes_through() -> bool:
	return true


## Un charco o una placa de hielo sí tienen algo que el viento pueda
## llevarse; el suelo seco no.
func carried_element() -> RuneData:
	match state:
		State.WET: return WATER_RUNE
		State.ICY: return ICE_RUNE
		_: return null


## El agua avanza un escalón cada vez, igual que hace la hierba al
## regarla: primero moja el suelo, y un segundo impacto congela ese
## charco. Quién sabe si es el primer o el segundo impacto no es la
## etiqueta del hechizo —los dos son "agua"—, sino el estado en el que
## ya estaba el bloque.
func _wet() -> void:
	match state:
		State.DRY:
			_set_state(State.WET)
		State.WET:
			_set_state(State.ICY)
		State.ICY:
			pass  # ya está helado del todo


## El calor deshace lo anterior, y de un charco caliente sale vapor.
func _heat() -> void:
	match state:
		State.ICY:
			_set_state(State.WET)
		State.WET:
			_set_state(State.DRY)
			_emit_steam()
		State.DRY:
			pass


## Un charco también conduce, pero el suelo seco no. Así el agua deja de
## ser solo "el paso previo al hielo" y pasa a ser una preparación del
## terreno: mojas por donde va a pasar el enemigo y luego sueltas el rayo.
##
## El charco no encadena a sus vecinos como sí hacen las balsas de agua:
## es un dedo de agua en el suelo, no una masa. Que las dos superficies
## conduzcan distinto es lo que hace que elijas una u otra.
## El pestillo no es opcional: la descarga que suelta este charco nace
## ENCIMA de él, así que en cuanto la física corre un ciclo el hechizo
## le golpea a él mismo, que volvería a soltar otra descarga, y otra.
## Es exactamente el bucle infinito que cuelga el juego al primer rayo.
const ELECTRIFY_TIME: float = 0.6

var is_electrified: bool = false


func _electrify() -> void:
	if state != State.WET or is_electrified:
		return

	is_electrified = true
	SpellFactory.cast(self, global_position, Vector2.ZERO, LIGHTNING_RUNE, ELECTRIFY_TIME)
	print("¡El charco conduce la descarga!")

	get_tree().create_timer(ELECTRIFY_TIME).timeout.connect(_calm_down)


func _calm_down() -> void:
	is_electrified = false


## Revierte el bloque a su estado de fábrica: ni mojado, ni helado, ni
## con nada construido encima.
func _dispel() -> void:
	_set_state(State.DRY)

	if is_instance_valid(occupant):
		occupant.queue_free()
		print("El tiempo se lleva lo que había construido encima.")

	occupant = null


## El vapor no es una escena nueva: es un hechizo quieto con la ficha
## del vapor. Cualquier objeto del mundo que implemente on_spell_hit y
## mire la etiqueta "vapor" reaccionará (la futura rueda hidráulica,
## por ejemplo) sin que este bloque sepa que existe.
func _emit_steam() -> void:
	SpellFactory.cast(self, global_position, Vector2.ZERO, STEAM_RUNE, STEAM_LIFETIME)
	print("El charco se evapora: ¡vapor!")


## Avisar de "entras/sales del hielo" tiene que hacerse mirando la
## TRANSICIÓN, no el estado nuevo. Si avisáramos de "sales del hielo"
## en cada cambio a seco o mojado, un bloque que pasa de seco a mojado
## le restaría al jugador un contacto de hielo que nunca le había
## sumado, y el contador acabaría descuadrado.
func _set_state(new_state: State) -> void:
	if new_state == state:
		return

	var previous: State = state
	state = new_state
	_apply_state()

	if previous != State.ICY and state == State.ICY:
		_grab_ice_contacts()
	elif previous == State.ICY and state != State.ICY:
		_release_ice_contacts()


## Con arte real ya no pintamos un rectángulo de color: teñimos la
## textura con `modulate`, que multiplica el color del sprite. Blanco
## (1,1,1) = textura tal cual; valores por debajo de 1 la oscurecen y
## por encima de 1 la aclaran. Así el suelo mojado es el mismo suelo
## pero más oscuro y azulado, sin necesitar una textura por estado.
func _apply_state() -> void:
	match state:
		State.DRY:
			$Visual.modulate = Color(1, 1, 1)
		State.WET:
			$Visual.modulate = Color(0.62, 0.66, 0.78)
		State.ICY:
			$Visual.modulate = Color(0.8, 0.95, 1.05)


## --- Hielo resbaladizo ---
## El bloque no "empuja" al jugador: solo le avisa de que está pisando
## hielo. Es el jugador quien decide qué significa eso (en player.gd,
## perder agarre). Mismo criterio que on_spell_hit: quien recibe el
## aviso decide cómo reacciona.
func _on_body_entered(body: Node) -> void:
	if state == State.ICY and body.has_method("add_ice_contact"):
		body.add_ice_contact()


func _on_body_exited(body: Node) -> void:
	if state == State.ICY and body.has_method("remove_ice_contact"):
		body.remove_ice_contact()


## Si el bloque se congela con el jugador ya encima, "entrar" nunca
## llegó a ocurrir, así que hay que avisarle ahora.
func _grab_ice_contacts() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("add_ice_contact"):
			body.add_ice_contact()


## Y al derretirse, lo contrario: el jugador nunca "salió" del bloque,
## pero ya no está sobre hielo.
func _release_ice_contacts() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("remove_ice_contact"):
			body.remove_ice_contact()
