class_name SpellRecipe
extends RefCounted

## LA RECETA DE UN COMPONENTE DEL HECHIZO.
##
## Los sellos dibujados en un sector escriben aquí su aportación, y
## luego quien lanza (Lanzador3D) lee la receta terminada y decide qué
## sale. Ningún sello sabe de la existencia de los demás.
##
## Ahí está la diferencia entre un sistema que escala y uno que no: las
## combinaciones no están escritas en ninguna parte, EMERGEN de leer
## juntos unos pocos parámetros.

const TILE: float = 64.0

var direction: Vector2 = Vector2.RIGHT

var origin: float = 0.0     ## a qué distancia aparece (0 = encima de ti)
var travels: bool = false   ## ¿recorre el camino o se queda quieto?
var reach: int = 0          ## casillas que abarca a lo largo
var spread: bool = false    ## ¿ocupa área en vez de un punto?
var lifetime: float = 0.0   ## segundos de más en el mundo
var height: int = 0         ## niveles que sube
var copies: int = 1
var power: float = 1.0

## Segundos de recarga de la página (el mayor de sus sellos).
var cooldown: float = 0.0

## Si lo que sale bloquea proyectiles (ver Sigils.FORM, "blocks").
var blocks: bool = false

## Cuántas barreras hay apiladas (ver Sigils, "APILAR EL MISMO GLIFO"), y cuántas
## veces se ha aplicado cada glifo (para cobrar la recarga de los repetidos).
var barriers: int = 0
var _aplicados: Dictionary = {}

## --- LENGUAJE NUEVO (ver Sigils.FORM) ---
var bounces: int = 0        ## rebotes del proyectil (y si hay barrera, la hace reflejar)
var delay: float = 0.0      ## segundos que tarda en salir lo que se lanza
var pulse: bool = false     ## el área nace en ti y se expande
var pull: bool = false      ## lo que toca es tirado en vez de apartado
var mirror: bool = false    ## sale también hacia atrás

## Dónde se lanzó, en coordenadas de mundo. Lo que nace tarde (retardo, ondas
## sucesivas) nace AQUÍ y no donde estés después.
var _base: Vector2 = Vector2.ZERO

## Calidad del trazo, de 0 (justo aceptado) a 1 (limpio). La pone quien lanza.
var calidad: float = 1.0


func _init(sector: Vector2) -> void:
	direction = sector


## Cada sello vuelca lo suyo. Cómo se acumula cada parámetro NO es
## arbitrario: dice qué significa apilar ese sello.
##
##   travels, spread    se encienden (o)    — o viaja o no
##   origin             se queda el mayor   — manda el más lejano
##   reach, lifetime,   SE SUMAN            — más flechas, más lejos;
##   height                                   más levitaciones, más rato
##   copies, power      SE MULTIPLICAN      — dos repeticiones son cuatro
func apply(sigil_name: String) -> void:
	var repetido: bool = _aplicados.has(sigil_name)
	_aplicados[sigil_name] = int(_aplicados.get(sigil_name, 0)) + 1

	if Sigils.FORM.has(sigil_name):
		var form: Dictionary = Sigils.FORM[sigil_name]
		origin = maxf(origin, form.get("origin", 0.0))
		travels = travels or form.get("travels", false)
		spread = spread or form.get("spread", false)
		# El pulso también ocupa área, pero no es una BARRERA: no agranda el aro.
		if form.get("spread", false) and not form.get("pulse", false):
			barriers += 1
		bounces += int(form.get("bounces", 0))
		delay += float(form.get("delay", 0.0))
		pulse = pulse or form.get("pulse", false)
		pull = pull or form.get("pull", false)
		mirror = mirror or form.get("mirror", false)
		reach += int(form.get("reach", 0))
		lifetime += float(form.get("lifetime", 0.0))
		height += int(form.get("height", 0))
		cooldown = maxf(cooldown, float(form.get("cooldown", 0.0)))
		blocks = blocks or form.get("blocks", false)

	elif Sigils.OPERATOR.has(sigil_name):
		var op: Dictionary = Sigils.OPERATOR[sigil_name]
		copies *= int(op.get("copies", 1))
		power *= float(op.get("power", 1.0))
		cooldown = maxf(cooldown, float(op.get("cooldown", 0.0)))

	# Lo grande no sale gratis: cada glifo repetido alarga la recarga.
	if repetido:
		cooldown += Sigils.STACK_COOLDOWN


## --- El lanzamiento 2D se retiró (L2.2, 13/10) ---
## `build()`, `_construir()`, `_manifest()` y la marca de retardo creaban los nodos del hechizo 2D (proyectil y campo). El 3D no
## pasa por ahí: `Receta3D` (dentro de lanzador_3d.gd) hereda de esta clase y lee la receta en CASILLAS. Aquí quedan los datos de la receta
## (`apply`) y las preguntas que se le hacen (`_points`, `_fan`, `_es_*`, `_powered`…), sin ningún nodo.



## LEVITACIÓN SOLA: el elemento flota y te sigue un rato. Si algo más dice dónde
## (flecha, pilar, barrera), manda eso y la levitación solo lo eleva.
func _sigue() -> bool:
	return height > 0 and not travels and not spread and origin <= 0.0 and reach <= 1



## Ocupar área significa algo distinto según se mueva o no.


