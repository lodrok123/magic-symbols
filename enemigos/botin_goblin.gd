class_name BotinGoblin
extends RefCounted

## BOTÍN DE MATERIALES DEL GOBLIN (docs/MATERIALES_CUEVA.md). Al caer, un goblin puede soltar un material además del oro que ya da. Hoy: `colmillo_goblin`
## (C4 de la Cueva). El material va directo a la mochila de la jugadora con el aviso de su calidad (AvisoObjeto) y un texto flotante donde cayó el goblin.
## Combate3D._morir llama a `soltar`; no se llama si muere ahogado (sin botín) ni si es elemental.

const MATERIAL: String = "colmillo_goblin"
const PROB_COLMILLO: float = 0.6             ## probabilidad de que un goblin suelte el colmillo al caer
const ALTURA_TEXTO: float = 0.9              ## u sobre el cuerpo donde sale el texto flotante

## Solo para las pruebas: >= 0 sustituye al azar en todas las tiradas de `soltar` (los goblins de verdad llaman sin tirada). -1 = al azar.
static var tirada_forzada: float = -1.0


## ¿Gana esta tirada (0..1)? Pura, para poder medirla sin azar.
static func gana(tirada: float, probabilidad: float = PROB_COLMILLO) -> bool:
	return tirada < probabilidad


## Hace la tirada y, si sale, da el material. Devuelve el id que se dio ("" si no salió o no cupo en la mochila).
## `tirada` < 0 = al azar (lo normal); las pruebas pasan un valor fijo.
static func soltar(mundo: Node3D, pos: Vector3, tirada: float = -1.0) -> String:
	var t: float = tirada
	if t < 0.0:
		t = randf() if tirada_forzada < 0.0 else tirada_forzada
	if not gana(t):
		return ""
	var lanz: Node = mundo.get_tree().get_first_node_in_group("spellcaster") if mundo != null and mundo.is_inside_tree() else null
	if Estado.i().agregar(MATERIAL, 1) <= 0:
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", "Mochila llena")
		return ""
	AvisoObjeto.mostrar(lanz, MATERIAL, 1)
	if mundo != null:
		Combate3D.flotante(mundo, pos + Vector3(0.0, ALTURA_TEXTO, 0.0), AvisoObjeto.texto(MATERIAL, 1), Objetos.color_calidad(MATERIAL))
	return MATERIAL
