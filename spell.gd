extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

## Cuánto dura un hechizo "quieto" (pilar, barrera, nube de vapor)
## antes de desaparecer solo, ya que a diferencia de una flecha nunca
## sale de la pantalla por sí mismo. Lo pone SpellFactory.cast() ANTES
## de meter el hechizo en la escena, porque _ready() ya lo necesita.
var stationary_lifetime: float = 0.6

# En vez de guardar solo un color y un daño sueltos, el hechizo
# lleva la ficha completa del elemento (RuneData). Así, cuando
# choque con algo, puede pasarle TODAS sus propiedades de golpe,
# no solo el daño.
var rune_data: RuneData = null

## Multiplicador de potencia que le pone la receta (el sello de
## aumento). Escala lo que se ve; el daño ya viene multiplicado en el
## RuneData duplicado, porque tocarlo aquí no serviría: quien lo lee es
## el objeto golpeado, no el hechizo.
## Es una propiedad con setter y no una variable a secas por la misma
## razón que ya nos mordió con `direction`: la receta pone la potencia
## DESPUÉS de crear el hechizo, así que calcular el tamaño en cualquier
## otro sitio llegaría tarde. Aquí, se aplique cuando se aplique, el
## tamaño va detrás. La raíz cuadrada es para que doblar la potencia no
## cuadruplique el área que ocupa en pantalla.
var power: float = 1.0:
	set(value):
		power = value
		scale = Vector2.ONE * sqrt(maxf(power, 0.01))
		# Y la hoja de la intensidad, por la MISMA razón que el tamaño:
		# set_rune_data() ya eligió una cuando aún no se sabía la
		# potencia, así que hay que volver a preguntar ahora que sí.
		_refresh_vfx()

var is_stationary: bool = false

## --- Lo que permanece, atraviesa ---
## Un hechizo normal muere contra lo primero que reacciona. Uno que
## lleva levitación no: un tornado no se deshace contra el primer
## arbusto, lo arrastra y sigue. No es una regla nueva, es leer el
## parámetro de permanencia que ya pone la receta.
var piercing: bool = false

## Si ya recogió un elemento por el camino (ver _try_carry).
var carried: bool = false

## Cuánto empuja el viento. Es fuerza, no distancia: quien la recibe la
## va gastando, así que empujar a alguien que anda contra el viento
## cuesta más que empujar a alguien parado.
const PUSH_FORCE: float = 320.0

## Velocidad de reproducción del efecto visual. Las tiras se muestrearon
## desde animaciones de 28 FPS quedándonos con ~18 fotogramas, así que a
## 24 FPS se ven a un ritmo parecido al original.
const VFX_FPS: float = 24.0
var vfx_time: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# El viento tiene que poder empujar CUERPOS (el jugador, un enemigo),
	# no solo áreas. Es la única razón por la que un hechizo mira los
	# cuerpos: para todo lo demás sigue hablando solo con áreas y su
	# contrato on_spell_hit.
	body_entered.connect(_on_body_entered)

	# Se decide UNA vez, al nacer, y se guarda. Antes esto se consultaba
	# leyendo `direction` en cada sitio, lo cual era frágil: bastaba con
	# que alguien asignase la dirección un instante tarde para que el
	# hechizo se creyera quieto siendo una flecha.
	is_stationary = direction == Vector2.ZERO

	if is_stationary:
		# Un Area2D solo avisa con "area_entered" cuando algo ENTRA de
		# nuevo en su zona. Si el pilar/barrera/vapor nace ya solapado
		# con un bloque, ese aviso nunca llegaría, así que lo miramos a
		# mano en cuanto la física haya procesado un ciclo.
		_check_initial_overlaps()
		get_tree().create_timer(stationary_lifetime).timeout.connect(queue_free)
	elif piercing:
		# Los que vuelan normalmente mueren al chocar o al salirse de la
		# pantalla. Uno que atraviesa no hace ninguna de las dos cosas a
		# tiempo, así que necesita su propio plazo o se queda dando
		# vueltas por el mundo para siempre.
		get_tree().create_timer(stationary_lifetime).timeout.connect(queue_free)


## Movimiento del hechizo (una flecha). Si es quieto, no se mueve, pero
## su efecto visual sigue animándose igualmente.
func _process(delta: float) -> void:
	_animate_vfx(delta)

	if is_stationary:
		return

	position += direction * speed * delta

	# Si se aleja mucho, se destruye para no acumular basura
	if position.length() > 2000:
		queue_free()


## Asigna el elemento de este hechizo y con él su aspecto. Fíjate en que
## este código no sabe qué elemento es: solo pregunta a la ficha si trae
## animación. El día que añadas un elemento nuevo con su tira, se verá
## animado aquí sin tocar esta función.
func set_rune_data(data: RuneData) -> void:
	rune_data = data

	# El elemento se configura a sí mismo en el sprite (ver
	# RuneData.setup_sprite) y nos dice si tenía animación o no.
	# El sonido del elemento sale de aquí y no de la receta: así suena
	# igual lo lance el jugador, lo propague el viento o lo escupa una
	# charca electrificada. El antirráfaga de Sfx se encarga de que un
	# corro de 24 manifestaciones suene UNA vez.
	Sfx.for_element(self, data)

	# CADA HECHIZO LLEVA SU LUZ, y el color lo pone el propio elemento
	# (RuneData.color), no una tabla aparte: un elemento nuevo alumbrará
	# del color que le toca sin que nadie lo apunte en ningún sitio.
	#
	# A oscuras esto deja de ser un adorno: una bola de fuego cruzando
	# una cueva es, literalmente, por dónde ves.
	Glow.attach(self, data.color, 110.0, 0.9)

	if data.setup_sprite($Vfx, power):
		$Vfx.show()
		$ColorRect.hide()
	else:
		# Elementos sin animación propia (el vapor) siguen usando el
		# cuadrado de color, que al menos transmite de qué elemento son.
		$ColorRect.color = data.color


## Vuelve a elegir la hoja ahora que se sabe la potencia.
##
## Se protege con get_node_or_null porque el orden en que llegan el
## elemento y la potencia no está garantizado: si alguien pusiera la
## potencia antes de meter el hechizo en el árbol, $Vfx todavía no
## existiría. Callar aquí es correcto — set_rune_data vendrá después y
## hará el trabajo con la potencia ya puesta.
func _refresh_vfx() -> void:
	if rune_data == null:
		return
	var vfx := get_node_or_null("Vfx") as Sprite2D
	if vfx == null:
		return
	if rune_data.setup_sprite(vfx, power):
		vfx.show()
		var fondo := get_node_or_null("ColorRect")
		if fondo:
			fondo.hide()


func _animate_vfx(delta: float) -> void:
	if not $Vfx.visible or rune_data == null:
		return

	# Los fotogramas son los de LA HOJA QUE TOCA, no los de la normal: el
	# remolino del fuego amplificado podría tener otra cuenta, y usar la
	# de la hoja base dejaría celdas sin recorrer o recorrería celdas
	# vacías, que se ven como un parpadeo.
	var cuantos: int = rune_data.frames_for(power)
	if cuantos <= 0:
		return

	vfx_time += delta
	# El módulo se hace sobre los fotogramas REALES, no sobre las celdas
	# de la rejilla: la última fila puede tener celdas vacías y saltarían
	# como parpadeos si las recorriéramos.
	$Vfx.frame = int(vfx_time * VFX_FPS) % cuantos


## `await get_tree().physics_frame` espera a que termine el siguiente
## ciclo de física, que es cuando Godot ya sabe qué áreas se solapan
## con esta. Antes de eso, get_overlapping_areas() devolvería vacío.
func _check_initial_overlaps() -> void:
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	for area in get_overlapping_areas():
		_hit(area)


## Cuando el hechizo toca cualquier Area2D del mundo (enemigo, agua,
## una puerta...), le avisamos usando un "contrato" común: si ese
## objeto sabe reaccionar a un hechizo (tiene la función on_spell_hit),
## se lo pasamos junto con la dirección del hechizo (útil para el
## viento, que empuja/propaga cosas en esa dirección) y dejamos que
## decida qué hacer. El hechizo no necesita saber si era un enemigo o
## un bloque de agua.
func _on_area_entered(area: Area2D) -> void:
	var reacted: bool = _hit(area)

	# Una flecha desaparece al golpear algo QUE REACCIONA, no contra
	# cualquier área que se cruce. La diferencia importa: el jugador
	# lleva un Area2D en los pies (para saber sobre qué está subido) y el
	# hechizo nace justo encima de ella. Con la regla ingenua, toda
	# flecha se autodestruía contra los pies de quien la lanzaba antes de
	# recorrer un solo píxel.
	#
	# Un pilar, una barrera o una nube de vapor no desaparecen al primer
	# impacto: se quedan su tiempo y pueden afectar a varias cosas.
	if reacted and not is_stationary and not piercing:
		queue_free()


## EL VIENTO EMPUJA.
##
## Y ahí está lo que lo hace un arma: no hace falta que el viento haga
## daño si puede tirarte por un borde. El empujón es la mitad del
## hechizo; la otra mitad la pone el nivel.
##
## Se pregunta por el método, no por el tipo: cualquier cosa que sepa
## recibir un empujón lo recibirá, sin que el viento tenga una lista de
## qué cosas existen. Es el mismo trato que on_spell_hit.
func _on_body_entered(body: Node) -> void:
	_try_push(body)


## Se llama desde los DOS caminos —cuerpos y áreas— porque el mundo tiene
## las dos cosas: el jugador es un CharacterBody2D pero el arquero es un
## Area2D. Preguntar por el método y no por el tipo hace que dé igual.
func _try_push(nodo: Node) -> void:
	if rune_data == null or not rune_data.tags.has("viento"):
		return
	if not nodo.has_method("push"):
		return

	var empuje: Vector2 = direction
	if empuje == Vector2.ZERO:
		# Un remolino quieto tira de lo que tiene cerca hacia fuera: no
		# tiene dirección propia, así que usa la que va de él al objeto.
		empuje = (nodo.global_position - global_position).normalized()

	nodo.push(empuje, PUSH_FORCE * power)


## Devuelve si el área golpeada sabía reaccionar a un hechizo.
func _hit(area: Area2D) -> bool:
	_try_carry(area)
	_try_push(area)

	if not area.has_method("on_spell_hit"):
		return false

	area.on_spell_hit(rune_data, direction)
	return true


## EL VIENTO SE LLEVA LO QUE TOCA.
##
## Un hechizo de viento que cruza fuego deja de ser viento a secas: pasa
## a ser viento CARGADO de fuego, con su color, su daño y sus etiquetas.
## Sigue volando, pero ahora prende lo que encuentra más allá.
##
## No es un caso especial del viento contra el fuego: el viento pregunta
## "¿llevas algo que se pueda arrastrar?" y el bloque responde. Un
## bloque futuro que devuelva veneno hará viento venenoso sin que ni el
## viento ni el veneno se enteren el uno del otro.
##
## Solo se carga UNA vez. Si no, al cruzar una hoguera larga iría
## cambiando de elemento casilla a casilla y no se leería nada.
func _try_carry(area: Area2D) -> void:
	if rune_data == null or carried or is_stationary:
		return
	if not rune_data.tags.has("viento"):
		return
	if not area.has_method("carried_element"):
		return

	var cargado: RuneData = area.carried_element()
	if cargado == null:
		return

	carried = true
	set_rune_data(cargado)
	print("El viento arrastra ", cargado.display_name)
