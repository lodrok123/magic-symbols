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

## Los sellos de FORMA dicen dónde y cómo se manifiesta la magia.
##   origin  distancia a la que aparece, en casillas de 64px
##   travels si recorre el camino en vez de quedarse quieto
##   ring    si además rodea el punto con un corro
const FORM: Dictionary = {
	"flecha": {"travels": true},
	"pilar": {"origin": 128.0},
	# La barrera NO pone distancia, solo anillo: así, sola, el corro te
	# rodea a TI (encerrarse en piedras), y combinada con el pilar el
	# corro se centra donde el pilar diga. El mismo sello da las dos
	# lecturas que pediste sin decidir nada.
	"barrera": {"ring": true},
}

## Los sellos OPERADORES no dicen dónde, sino cuánto: transforman lo que
## haya. Por eso "repetición + pilar" y "repetición + flecha" funcionan
## los dos sin decidir nada — la repetición no sabe qué está repitiendo.
const OPERATOR: Dictionary = {
	"repeticion": {"copies": 2},
	"rombo": {"power": 2.0},
}

## Cuántas manifestaciones forman un anillo.
const RING_POINTS: int = 6

## Un trazo recto simple sigue valiendo como atajo del sello
## equivalente: dibujas una raya y sale una flecha. El trazo es azúcar;
## el sello es el lenguaje, y solo el sello se puede combinar.
const PATTERN_AS_SIGIL: Dictionary = {
	Runes.Pattern.ARROW: "flecha",
	Runes.Pattern.PILLAR: "pilar",
	Runes.Pattern.BARRIER: "barrera",
}


static func is_known(sigil_name: String) -> bool:
	return FORM.has(sigil_name) or OPERATOR.has(sigil_name)
