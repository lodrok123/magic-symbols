class_name Sigils
extends RefCounted

## QUÉ APORTA CADA SELLO.
##
## Cinco sellos son diez parejas; nueve son treinta y seis parejas y
## ochenta y cuatro tríos. Escribir a mano qué hace cada combinación
## mata el sistema: cada sello nuevo obligaría a decidir qué pasa con
## todos los anteriores.
##
## Por eso aquí NO hay combinaciones. Cada sello declara únicamente lo
## suyo, escribe su aportación en una receta común (SpellRecipe), y es
## la receta terminada la que se interpreta al final. Las combinaciones
## no se programan: SALEN.
##
## Añadir un sello es añadir una línea a esta tabla.

## Los sellos de FORMA dicen dónde, cuánto espacio y cuánto tiempo.
##
##   origin    a qué distancia nace, en píxeles (64 = una casilla)
##   travels   si recorre el camino en vez de quedarse quieto
##   reach     cuántas casillas abarca a lo largo de la dirección
##   spread    si ocupa un ÁREA en vez de un punto
##   lifetime  segundos de más que aguanta en el mundo
##   height    cuántos niveles sube
const FORM: Dictionary = {
	"flecha": {"travels": true, "reach": 1},
	"pilar": {"origin": 128.0},

	# La barrera no dice dónde: dice QUE OCUPA SITIO. Sola, el corro te
	# rodea a ti; con flecha el área se pone de través y sale un muro;
	# con levitación crece hacia arriba y sale una columna. Tres
	# lecturas del mismo sello, y ninguna está escrita.
	"barrera": {"spread": true},

	# Levitación es lo que faltaba para que no todo fuera disparar.
	# Aporta las dos cosas que van juntas en lo que flota: que SE QUEDA
	# (lifetime) y que está POR ENCIMA (height). De ahí salen el tornado
	# quieto, el chorro que permanece y la columna.
	"levitacion": {"lifetime": 2.0, "height": 1},
}

## Los sellos OPERADORES no dicen dónde, sino cuánto: transforman lo que
## haya. Por eso "repetición + pilar" y "repetición + flecha" funcionan
## los dos sin decidir nada — la repetición no sabe qué está repitiendo.
##
## 'amplificar' se llamaba 'rombo', y el nombre era un residuo: describía
## el DIBUJO del sello, no lo que hace. Cuando el trazo dejó de ser un
## rombo, el nombre pasó a mentir. Los demás sellos ya se llamaban por su
## efecto, así que este era el único que obligaba a recordar una forma
## para saber de qué se hablaba.
##
## `power` hace dos cosas de una: multiplica el daño (en SpellRecipe, que
## duplica el RuneData para no potenciar el elemento de por vida) y sube
## la INTENSIDAD del efecto (en RuneData, que cambia de hoja de
## animación). Ninguna de las dos está escrita aquí, y así debe ser: este
## sello solo declara un número.
const OPERATOR: Dictionary = {
	"repeticion": {"copies": 2},
	"amplificar": {"power": 2.0},
}

## --- CÓMO SE DIBUJA CADA SELLO ---
##
## El glifo con el que el grimorio anota el sello en su sector. Vive aquí
## y no en spellbook.gd por lo mismo que todo lo demás de este archivo:
## añadir un sello sigue siendo añadir UNA línea a una tabla, ahora con
## su dibujo incluido. El libro no sabe qué sellos existen; pinta lo que
## encuentre aquí.
##
## Son siluetas blancas sobre transparente, como los glifos de elemento,
## pero estos NO se tiñen: el color es del elemento, que va en el centro.
## En la corona solo importa qué sello es, así que van todos con la misma
## tinta del libro.
##
## 'pilar' no tiene entrada, y no es un olvido: se retira del repertorio
## (barrera + levitación ya dan la columna, tal como dice el comentario de
## FORM) y no vino icono para él en la lámina. Mientras siga existiendo en
## FORM, el libro lo dibuja con el trazo a mano de siempre.
const GLYPHS: Dictionary = {
	"flecha": preload("res://art/ui/glyphs/flecha.png"),
	"barrera": preload("res://art/ui/glyphs/barrera.png"),
	"levitacion": preload("res://art/ui/glyphs/levitacion.png"),
	"repeticion": preload("res://art/ui/glyphs/repeticion.png"),
	"amplificar": preload("res://art/ui/glyphs/amplificar.png"),
}

## Cuántas manifestaciones forman un corro.
const RING_POINTS: int = 6

## Cuánto dura un hechizo quieto normal. Levitación suma sobre esto.
const BASE_LIFETIME: float = 0.6

## Tope duro de manifestaciones por componente.
##
## Hace falta porque los parámetros se MULTIPLICAN entre sí: un corro de
## 6 con dos alturas y dos repeticiones son 6 x 3 x 4 = 72 hechizos de
## un solo trazo. Sin tope, la combinación más creativa sería también la
## que tira los fotogramas, y eso enseña justo lo contrario de lo que
## queremos: a no experimentar.
const MAX_MANIFESTATIONS: int = 24

## Un trazo recto simple sigue valiendo como atajo del sello
## equivalente: dibujas una raya y sale una flecha. El trazo es azúcar;
## el sello es el lenguaje, y solo el sello se puede combinar.
const PATTERN_AS_SIGIL: Dictionary = {
	Runes.Pattern.ARROW: "flecha",
	Runes.Pattern.PILLAR: "pilar",
	Runes.Pattern.BARRIER: "barrera",
}


## --- DÓNDE VALE CADA SELLO ---
##
## UNA FLECHA VUELA PLANA. Una bola de fuego no se lanza "hacia arriba",
## y hasta ahora se podía: los ocho sectores del grimorio admitían flecha,
## así que la respuesta a cualquier problema era apuntar y disparar.
##
## Prohibirla en los seis sectores que no son horizontales no es una
## limitación arbitraria: es lo que OBLIGA a que los demás sellos existan.
## Si quieres alcanzar algo que no cae en tu horizontal tienes que pensar
## — levitación para que se quede, barrera para ocupar el paso, pilar para
## que nazca lejos. El sistema ya tenía esas respuestas; lo que faltaba
## era quitar la respuesta fácil.
##
## Se declara como un dato más del sello y no como un `if` en el
## Spellcaster: el día que un sello nuevo solo tenga sentido en vertical,
## es una línea aquí y nada más.
const AXIS: Dictionary = {
	"flecha": "plano",
}

## Cuánto puede inclinarse un sector y seguir contando como horizontal.
##
## Con ocho sectores los valores posibles de `y` son 0, ±0.707 y ±1. Con
## 0.35 pasan exactamente los dos horizontales. ES EL ÚNICO MANDO: subirlo
## a 0.8 admitiría también las cuatro diagonales, por si al jugarlo la
## restricción resulta demasiado dura. Bajarlo no cambia nada.
const FLAT_TOLERANCE: float = 0.35


static func is_known(sigil_name: String) -> bool:
	return FORM.has(sigil_name) or OPERATOR.has(sigil_name)


## ¿Puede este sello usarse hacia ahí? Lo que no aparece en AXIS vale en
## cualquier sector, que es el caso de casi todos: la restricción es la
## excepción y se declara; lo normal no se declara.
static func allowed_on(sigil_name: String, sector: Vector2) -> bool:
	if AXIS.get(sigil_name, "") != "plano":
		return true
	return absf(sector.y) <= FLAT_TOLERANCE
