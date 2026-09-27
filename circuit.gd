class_name Circuit
extends RefCounted

## EL CIRCUITO: por dónde puede viajar la corriente.
##
## El rayo tenía un problema de diseño, no de implementación: ya
## electrificaba el agua, pero esa reacción solo servía para hacer daño
## en área, y el juego todavía no tiene nada a lo que convenga hacer daño
## en área. Era una llave sin cerradura.
##
## Lo que faltaba no era otra reacción del rayo: era algo que la corriente
## pudiera ALCANZAR. Por eso esto no es "el sistema eléctrico" con sus
## reglas propias, sino una sola idea compartida — hay piezas conectadas,
## y la corriente salta entre las vecinas. Quién es pieza lo dice el
## grupo; qué hace cada una al recibirla lo decide ella.
##
## Un conductor pasa corriente. Una puerta se abre. Una charca hiere a
## quien esté dentro. Ninguna de las tres sabe que las otras existen, y
## por eso se pueden encadenar en cualquier orden sin escribir ni una
## combinación.
##
## LA JUGADA INVERSA SALE GRATIS: el hielo no conduce (ya estaba escrito
## en water_block), así que congelar el canal es a la vez la forma de
## cruzarlo andando y la forma de CORTAR el circuito. Elegir entre las
## dos es un puzle que nadie tuvo que diseñar.

## Quién participa. El agua, los conductores y las puertas se apuntan en
## _ready(); cualquier pieza futura que quiera electricidad solo tiene
## que apuntarse y saber reaccionar a la etiqueta "rayo".
const GROUP: String = "circuito"

## Hasta dónde salta la corriente, en píxeles de pantalla.
##
## 80 no es un número redondo elegido a ojo: en la rejilla isométrica una
## casilla vecina en X o en Y está a 64 px, y la diagonal de pantalla a
## 116. Con 80 la corriente pasa a las contiguas y NO salta en diagonal,
## que es lo que hace que un cable se lea como un cable y no como una
## mancha que se expande.
const RADIUS: float = 80.0

## Cuánto dura un pulso en una pieza. También es el cortafuegos: una
## pieza ya viva IGNORA la corriente, así que la onda avanza hacia fuera
## y se apaga sola al llegar al borde. Sin esto, dos vecinas se rebotarían
## el rayo la una a la otra para siempre y el juego se colgaría en el
## primer relámpago — que es exactamente el fallo que ya tuvimos.
const TIME: float = 0.6


## Pasa la corriente a las vecinas. Es lo ÚNICO que comparten las piezas:
## a quién avisar. Qué hacer al recibirla es cosa de cada una.
static func spread(origen: Node2D, rayo: RuneData) -> void:
	for otra in origen.get_tree().get_nodes_in_group(GROUP):
		if otra == origen or not is_instance_valid(otra):
			continue
		if not otra.has_method("on_spell_hit"):
			continue
		if origen.global_position.distance_to(otra.global_position) <= RADIUS:
			otra.on_spell_hit(rayo)


## ¿Este hechizo lleva corriente? Se pregunta por las dos etiquetas
## porque el rayo lleva las dos y una pieza futura podría llevar solo
## una: "rayo" es el elemento, "electrico" es la propiedad.
static func is_current(rune_data: RuneData) -> bool:
	if rune_data == null:
		return false
	return rune_data.tags.has("rayo") or rune_data.tags.has("electrico")
