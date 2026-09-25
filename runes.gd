class_name Runes
extends RefCounted

## Este script no se instancia nunca: solo existe para tener un
## "enum" (Type) que cualquier otro script del proyecto pueda usar,
## sin depender del nodo Spellcaster. Así RuneData, Enemy, Spell,
## WaterBlock, etc. pueden hablar todos el mismo idioma de runas.

## ⚠️ El ORDEN de este enum no se puede tocar: los .tres guardan estos
## valores como números, así que reordenarlo cambiaría qué elemento es
## cada ficha. Los DIRECTION_* ya no se usan (la dirección la da ahora el
## sector del grimorio), pero se quedan para no mover los de abajo.
enum Type {
	NONE,
	DIRECTION_UP,
	DIRECTION_DOWN,
	DIRECTION_LEFT,
	DIRECTION_RIGHT,
	SHAPE_CIRCLE,
	SHAPE_TRIANGLE,
	SHAPE_LINES,
	SHAPE_ARC,
	## Los tres nuevos van AL FINAL por la misma razón de siempre: los
	## .tres guardan el número, no el nombre. Meter RAYO entre medias
	## convertiría silenciosamente el fuego en tierra en todos los
	## archivos ya guardados.
	##
	## Los de arriba se llaman SHAPE_* porque nacieron cuando el nombre
	## del gesto ERA su forma (un triángulo = fuego). Ya no: la forma es
	## un dato grabado, así que estos se llaman por lo que significan.
	## No renombro los viejos para no tocar los .tres que los usan.
	ELEMENT_LIGHTNING,
	ELEMENT_ICE,
	ELEMENT_TIME,
}

## Cómo se despliega un elemento. Cada uno lleva además su propia
## dirección (el sector del grimorio donde se dibujó), así que se pueden
## mezclar: una flecha al este y dos pilares al norte y al oeste.
enum Pattern {
	ARROW,    ## proyectil que sale volando
	PILLAR,   ## aparece lejos, a dos casillas: un sitio al que llegar
	BARRIER,  ## aparece pegado a ti, a una casilla: un escudo
}
