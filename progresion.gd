class_name Progresion
extends Node

## LA PROGRESIÓN DEL TEST: qué runas tienes y cuándo las consigues.
##
## Vocabulario: SELLO = elemento (fuego, agua...), GLIFO = forma (flecha,
## barrera...). El código llama al revés a algunas cosas (Repertoire.sigils son
## los glifos), pero aquí se habla como en el diseño.
##
## Orden de adquisición:
##   Al empezar ............ fuego + flecha
##   Al prender una hierba ... agua + barrera
##   Al apagar un fuego ...... viento + rayo
##
## Lo que no se ha conseguido NO SE VE en el libro y no se puede usar: de eso
## se encarga Repertoire, este archivo solo decide cuándo abrir cada cosa.
##
## SE USA AÑADIÉNDOLO AL NIVEL, con una línea al final de Blockout._ready():
##     add_child(Progresion.new())
## No conoce el mapa: mira el mundo. "Apagar un fuego" es cualquier hoguera,
## antorcha, barrera de fuego o pira que estuviera encendida y deje de estarlo.

const INICIO_SELLOS: PackedStringArray = ["fuego"]
## TEMPORAL, para probar el lenguaje nuevo: levitación y repetición desde el
## principio. Cuando tengan su sitio en la progresión, se mueven a un premio.
const INICIO_GLIFOS: PackedStringArray = ["flecha", "levitacion", "repeticion"]

## TEMPORAL, para probar todo a la vez: con true se abre TODO desde el principio
## (los seis elementos y los diez glifos con icono), sin esperar a los premios. Con
## false vale la progresión de siempre. Los glifos nuevos necesitan que grabes sus
## gestos en el libro (modo de grabación) para poder dibujarse en el juego.
const PRUEBA_TODO: bool = true
const PRUEBA_SELLOS: PackedStringArray = ["fuego", "agua", "viento", "rayo", "tierra", "hielo"]
const PRUEBA_GLIFOS: PackedStringArray = ["flecha", "barrera", "levitacion", "repeticion",
		"amplificar", "rebote", "retardo", "pulso", "atraccion", "espejo"]

const PREMIO_HIERBA_SELLOS: PackedStringArray = ["agua"]
const PREMIO_HIERBA_GLIFOS: PackedStringArray = ["barrera"]

const PREMIO_APAGAR_SELLOS: PackedStringArray = ["viento", "rayo"]
const PREMIO_APAGAR_GLIFOS: PackedStringArray = []

## Estados de la hierba que cuentan como "prendida" (ver GrassBlock.State):
## IGNITING = 2, BURNING = 3, ASHES = 4.
const HIERBA_PRENDIDA: int = 2

var _hierba_lograda: bool = false
var _apagado_logrado: bool = false

## instance_id de cada hoguera -> si estaba encendida la última vez que se miró.
var _encendidas: Dictionary = {}


func _ready() -> void:
	if PRUEBA_TODO:
		Repertoire.set_active(PRUEBA_SELLOS, PRUEBA_GLIFOS)
	else:
		Repertoire.set_active(INICIO_SELLOS, INICIO_GLIFOS)
	# Se apunta cómo está cada fuego AHORA, para que solo cuente lo que cambie
	# a partir de aquí.
	_mirar_fuegos()
	_avisar_hud()


func _physics_process(_delta: float) -> void:
	if not _hierba_lograda and _hay_hierba_prendida():
		_hierba_lograda = true
		_dar(PREMIO_HIERBA_SELLOS, PREMIO_HIERBA_GLIFOS)

	if _mirar_fuegos() and not _apagado_logrado:
		_apagado_logrado = true
		_dar(PREMIO_APAGAR_SELLOS, PREMIO_APAGAR_GLIFOS)


## Toda la hierba se busca por su grupo, igual que hace ella para contagiar.
func _hay_hierba_prendida() -> bool:
	for hierba in get_tree().get_nodes_in_group("flammable"):
		var estado = hierba.get("state")
		if estado != null and int(estado) >= HIERBA_PRENDIDA:
			return true
	return false


## Recorre las hogueras y devuelve true si alguna PASÓ de encendida a apagada
## desde la última vez. Una hoguera es cualquier cosa del suelo que tenga
## `is_lit` (Brazier lo tiene; el resto del suelo, no).
func _mirar_fuegos() -> bool:
	var se_apago: bool = false
	for nodo in get_tree().get_nodes_in_group("ground"):
		if not ("is_lit" in nodo):
			continue
		var ahora: bool = bool(nodo.get("is_lit"))
		var id: int = nodo.get_instance_id()
		if _encendidas.get(id, false) and not ahora:
			se_apago = true
		_encendidas[id] = ahora
	return se_apago


func _dar(sellos: PackedStringArray, glifos: PackedStringArray) -> void:
	var nuevos: Array = []
	for s in sellos:
		if Repertoire.unlock_element(s):
			nuevos.append(s.capitalize())
	for g in glifos:
		if Repertoire.unlock_sigil(g):
			nuevos.append(g.capitalize())
	if nuevos.is_empty():
		return

	var texto: String = "Nuevas runas: %s" % " + ".join(nuevos)
	print(texto)
	PlayLog.event("runas", {"nuevas": nuevos})
	# El nivel sabe enseñar avisos en pantalla; si no hay nivel (esto suelto en
	# otra escena) se queda en la consola.
	var nivel: Node = get_parent()
	if nivel != null and nivel.has_method("_avisar"):
		nivel.call("_avisar", texto)


func _avisar_hud() -> void:
	var nivel: Node = get_parent()
	if nivel != null and nivel.has_method("_refrescar_hud"):
		nivel.call("_refrescar_hud")
