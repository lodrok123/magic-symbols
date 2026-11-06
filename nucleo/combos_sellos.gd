class_name CombosSellos
extends RefCounted

## PAREJAS DE SELLOS (libro «avanzado», 6/11/2026; docs/LIBRO_AVANZADO_2026-11-06.md y PROPUESTAS_COMBATE §5.2).
##
## Una página del libro avanzado lleva DOS sellos. Qué hechizo sale de la pareja es esta tabla, datos y no condicionales: añadir o cambiar una
## reacción es tocar una línea de TABLA. `Hechizo.construir` sigue recibiendo UN solo RuneData (el derivado), así que nada de lo que hay debajo
## (glifos, tinta, previsión) se entera de que hubo dos sellos.
##
## La clave es la pareja ORDENADA ALFABÉTICAMENTE («agua|fuego», nunca «fuego|agua»): el orden en que se dibujan los sellos no importa y con una sola
## entrada por pareja no puede quedarse una mitad sin escribir.
##
## Valores: el id del elemento derivado, o ANULAN (los opuestos se cancelan: no se lanza nada y no se cobra tinta).
## Una pareja que NO está aquí (hielo con algo, rayo con algo, dos iguales) no reacciona: `resolver` devuelve "" y el libro lanza el sello 1 como siempre.

const ANULAN: String = "anulan"

const TABLA: Dictionary = {
	"agua|fuego": ANULAN,
	"tierra|viento": ANULAN,
	"agua|viento": "hielo",
	"fuego|viento": "rayo",
	"fuego|tierra": "magma",
	"agua|tierra": "naturaleza",     # 6/11: era «barro»; Pablo lo cambió por naturaleza para reaprovechar el veneno de los goblins
}

## La runa de cada derivado. Hielo y rayo ya existían como sellos dibujables; magma y naturaleza son provisionales (ver sus .tres).
const RUNAS: Dictionary = {
	"hielo": preload("res://nucleo/ice_rune.tres"),
	"rayo": preload("res://nucleo/lightning_rune.tres"),
	"magma": preload("res://nucleo/magma_rune.tres"),
	"naturaleza": preload("res://nucleo/naturaleza_rune.tres"),
}

## Estados de una página con dos sellos (`de_ficha`).
const SIN_PAREJA: String = ""              ## uno o ningún sello: el comportamiento de siempre
const REACCION: String = "reaccion"        ## la pareja da un derivado
const SE_ANULAN: String = "anulan"         ## opuestos: no se lanza
const SIN_REACCION: String = "sin_reaccion"  ## pareja fuera de la tabla: se lanza el sello 1


## La clave de la pareja, ordenada alfabéticamente.
static func clave(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a <= b else "%s|%s" % [b, a]


## El id del derivado de la pareja, `ANULAN` ("anulan") si se cancelan, o "" si la pareja no está en la tabla. El orden de `a` y `b` da igual.
static func resolver(a: String, b: String) -> String:
	return String(TABLA.get(clave(a, b), ""))


## La runa del derivado `id`, o null si no es uno.
static func runa_de(id: String) -> RuneData:
	return RUNAS.get(id) as RuneData


## Lo que dice la pareja de sellos de una ficha de página (`{element, element2, ...}`): {estado, id, rune, a, b}.
## `a` y `b` son los ids de los dos sellos ("fuego", "agua"...). `rune` solo viene rellena en REACCION. Con menos de dos sellos, estado SIN_PAREJA.
## Es estática y no mira el libro activo: quien la llama decide si la ficha puede tener dos sellos (solo la del libro avanzado los guarda).
static func de_ficha(ficha: Dictionary) -> Dictionary:
	var t1: int = int(ficha.get("element", Runes.Type.NONE))
	var t2: int = int(ficha.get("element2", Runes.Type.NONE))
	var salida: Dictionary = {"estado": SIN_PAREJA, "id": "", "rune": null, "a": "", "b": ""}
	if t1 == Runes.Type.NONE or t2 == Runes.Type.NONE:
		return salida
	var a: String = _id_de_tipo(t1)
	var b: String = _id_de_tipo(t2)
	salida["a"] = a
	salida["b"] = b
	var id: String = resolver(a, b)
	if id == ANULAN:
		salida["estado"] = SE_ANULAN
	elif id == "":
		salida["estado"] = SIN_REACCION
	else:
		salida["estado"] = REACCION
		salida["id"] = id
		salida["rune"] = runa_de(id)
	return salida


## El id de un elemento ("fuego"...) a partir de su tipo: GESTURE_TO_RUNE al revés (la tabla vive en Grimorio, que es quien conoce los gestos).
static func _id_de_tipo(tipo: int) -> String:
	for nombre in Grimorio.GESTURE_TO_RUNE:
		if int(Grimorio.GESTURE_TO_RUNE[nombre]) == tipo:
			return String(nombre)
	return ""
