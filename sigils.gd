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
##   cooldown  segundos que tarda en poder lanzarse otra vez la PÁGINA que lo
##             lleva (con varios sellos manda el mayor, no la suma)
##   blocks    si lo que sale BLOQUEA proyectiles (flechas de arqueros, flechas
##             y rayos del jugador...). Es un dato del glifo: una excepción
##             futura (un elemento que atraviesa barreras) se escribe aquí o en
##             Spell.bloquea_a(), no repartida por el código
const FORM: Dictionary = {
	"flecha": {"travels": true, "reach": 1, "cooldown": 1.0},
	"pilar": {"origin": 128.0, "cooldown": 2.0},

	# La barrera no dice dónde: dice QUE OCUPA SITIO. Sola, el corro te
	# rodea a ti; con flecha el área se pone de través y sale un muro;
	# con levitación crece hacia arriba y sale una columna. Tres
	# lecturas del mismo sello, y ninguna está escrita.
	"barrera": {"spread": true, "cooldown": 3.0, "blocks": true},

	# Levitación es lo que faltaba para que no todo fuera disparar.
	# Aporta las dos cosas que van juntas en lo que flota: que SE QUEDA
	# (lifetime) y que está POR ENCIMA (height). De ahí salen el tornado
	# quieto, el chorro que permanece y la columna.
	"levitacion": {"lifetime": 2.0, "height": 1, "cooldown": 2.0},

	# --- LENGUAJE NUEVO: cada uno es UN parámetro más de la receta ---
	#   rebote     bounces  el proyectil rebota en barreras y en lo que golpea; con
	#                       una barrera, la barrera REFLEJA en vez de absorber
	#   retardo    delay    lo que sale tarda en salir (y se ve una marca en el suelo)
	#   pulso      pulse    el área NACE en ti y se EXPANDE; sola es una onda, con
	#                       barrera es una onda que además bloquea
	#   atraccion  pull     lo que toca es TIRADO (hacia ti si viaja, hacia el centro
	#                       si se queda); con viento es un gancho, con barrera un vórtice
	#   espejo     mirror   lo que viaja o nace lejos sale TAMBIÉN hacia atrás
	"rebote": {"bounces": 2, "cooldown": 1.5},
	"retardo": {"delay": 1.5, "cooldown": 1.0},
	"pulso": {"spread": true, "pulse": true, "cooldown": 2.5},
	"atraccion": {"pull": true, "cooldown": 1.5},
	"espejo": {"mirror": true, "cooldown": 1.5},
	"linea": {"spread": true, "blocks": true, "cooldown": 2.0},
	# Fase 8 (glifos como geometría): en 3D el significado lo pone Receta3D/GeometriaHechizo; aquí solo la recarga.
	"altura": {"cooldown": 2.0},
	"tamano": {"cooldown": 1.5}
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
	"repeticion": {"copies": 2, "cooldown": 1.5},
	"amplificar": {"power": 2.0, "cooldown": 2.0},
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
	"rebote": preload("res://art/ui/glyphs/rebote.png"),
	"retardo": preload("res://art/ui/glyphs/retardo.png"),
	"pulso": preload("res://art/ui/glyphs/pulso.png"),
	"atraccion": preload("res://art/ui/glyphs/atraccion.png"),
	"espejo": preload("res://art/ui/glyphs/espejo.png"),
}

## --- LA BARRERA QUE AVANZA (barrera + flecha) ---
##
## La flecha NO crea una flecha cuando va con una barrera: le da a la barrera su
## DIRECCIÓN y su AVANCE. Lo que sale es una barrera plana, de frente a la marcha,
## que se desplaza hacia donde apuntas, más despacio que una flecha, y que aplica
## su elemento a cada casilla que cruza. Dura poco: unas 4 casillas de camino.
##   WALL_SPEED     píxeles por segundo (una flecha va a 300)
##   WALL_LIFETIME  segundos que dura; recorre WALL_SPEED x WALL_LIFETIME = ~240 px
const WALL_SPEED: float = 110.0
const WALL_LIFETIME: float = 2.2

## --- APILAR EL MISMO GLIFO ---
##
## Repetir un glifo no crea una forma nueva: sube la INTENSIDAD de lo que ya hace,
## y lo hace por la misma regla para cualquier número, sin escribir "2 flechas" ni
## "3 barreras" en ninguna parte. Cada unidad extra aporta menos que la anterior
## (raíz cuadrada) y hay techos duros, para que el sexto glifo no sea siempre la
## respuesta ni llene la pantalla.
##   barreras  el aro crece de radio y la barrera que avanza se ensancha
##   flechas   el chorro llega más lejos y se queda más rato
##   cada glifo repetido suma STACK_COOLDOWN a la recarga: lo grande no es gratis
const STACK_SIZE_GAIN: float = 0.6      ## cuánto crece el radio del aro por raíz de barreras extra
const MAX_SIZE_FACTOR: float = 3.0      ## techo del radio, en veces el aro normal
const MAX_WALL_HALF: int = 4            ## techo de la anchura: 2 x esto + 1 casillas
const STACK_HOLD_GAIN: float = 0.8      ## segundos de retención por raíz de flechas extra
const MAX_JET_CELLS: int = 8            ## techo del largo del chorro, en casillas
const STACK_COOLDOWN: float = 0.5       ## recarga extra por cada glifo repetido

## Cuánto crece el aro con `n` barreras (1 = normal).
static func size_factor(n: int) -> float:
	return minf(1.0 + STACK_SIZE_GAIN * sqrt(float(maxi(n - 1, 0))), MAX_SIZE_FACTOR)


## Un paso de lo que flota y te sigue: va hacia `objetivo` con suavidad (llega
## con un poco de retraso, como si flotara) y se mece arriba y abajo. Lo usan el
## hechizo y su campo con la MISMA fórmula, para que no se separen.
static func flotar(actual: Vector2, objetivo: Vector2, delta: float) -> Vector2:
	var balanceo := Vector2(0.0, sin(float(Time.get_ticks_msec()) * 0.004) * 3.0)
	return actual.lerp(objetivo, 1.0 - exp(-FOLLOW_RATE * delta)) + balanceo * delta * 6.0


## Casillas a cada lado del centro de la barrera plana (1 = 3 casillas de ancho).
static func wall_half(n: int) -> int:
	return mini(roundi(1.0 + 0.9 * sqrt(float(maxi(n - 1, 0)))), MAX_WALL_HALF)


## Casillas que ocupa el chorro de `n` flechas (con 2 o más).
static func jet_cells(n: int) -> int:
	return mini(roundi(2.0 * sqrt(float(n))), MAX_JET_CELLS)


## Segundos EXTRA que se queda el chorro de `n` flechas.
static func jet_hold(n: int) -> float:
	return STACK_HOLD_GAIN * sqrt(float(maxi(n - 1, 0)))


## --- LA CALIDAD DEL TRAZO ---
##
## Un trazo apenas reconocido hace un hechizo más flojo: dura y llega menos.
## QUALITY_MIN es el factor con el trazo justo en el límite de ser aceptado; un
## trazo limpio da 1.0. El factor multiplica la duración de lo que se queda y el
## alcance del muro y de la flecha.
const QUALITY_MIN: float = 0.6

## Cuántas manifestaciones forman un corro.
const RING_POINTS: int = 6

## Cuánto dura un hechizo quieto normal. Levitación suma sobre esto.
const BASE_LIFETIME: float = 1.5

## Tope duro de manifestaciones por componente.
##
## Hace falta porque los parámetros se MULTIPLICAN entre sí: un corro de
## 6 con dos alturas y dos repeticiones son 6 x 3 x 4 = 72 hechizos de
## un solo trazo. Sin tope, la combinación más creativa sería también la
## que tira los fotogramas, y eso enseña justo lo contrario de lo que
## queremos: a no experimentar.
const PULSE_SPEED: float = 95.0         ## píxeles por segundo a los que se abre una onda
const WAVE_GAP: float = 0.5             ## segundos entre una onda y la siguiente (repetición + pulso)
const FOLLOW_LIFETIME: float = 6.0      ## segundos que te sigue lo que levita solo
const FOLLOW_RATE: float = 7.0          ## lo rápido que te alcanza (más = más pegado)
const MAX_MANIFESTATIONS: int = 48

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


## De calidad del trazo (0..1) a factor de potencia (QUALITY_MIN..1).
static func quality_factor(quality: float) -> float:
	return lerpf(QUALITY_MIN, 1.0, clampf(quality, 0.0, 1.0))


static func is_known(sigil_name: String) -> bool:
	return FORM.has(sigil_name) or OPERATOR.has(sigil_name)


## ¿Puede este sello usarse hacia ahí? Lo que no aparece en AXIS vale en
## cualquier sector, que es el caso de casi todos: la restricción es la
## excepción y se declara; lo normal no se declara.
static func allowed_on(sigil_name: String, sector: Vector2) -> bool:
	if AXIS.get(sigil_name, "") != "plano":
		return true
	return absf(sector.y) <= FLAT_TOLERANCE
