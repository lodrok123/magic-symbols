class_name Atuendos
extends RefCounted

## ATUENDOS (12/11, encargo de Pablo: «un sistema de equipamiento del personaje donde podrás ponerte cada uno de los 3 vestidos»). Un atuendo es un objeto de
## `nucleo/datos/objetos.tsv` con `uso = atuendo` y, en `efecto`, `prendas=<ids separados por comas>` (prendas de `arte/modelos/ropa.json`, cada una con su
## ranura) y opcionalmente `inicial` (se tiene desde el principio sin ocupar hueco de la mochila: el atuendo de viaje verde). Los demás se consiguen como
## objetos normales (la librera vende el uniforme de Monte Sumicio y el atuendo del lobo, `tiendas.tsv`): está en la mochila = se tiene.
## Ponerse uno = quitar TODA la ropa puesta y poner sus prendas (`Pj3D.poner_ropa`); la partida guarda lo puesto como siempre (`ropa_puesta`). La pestaña
## «Vestuario» del menú (`MenuPestanas`) los enseña (icono `arte/iconos/<id>.png`, prendas, si lo tienes y si lo llevas) y lo pone con Enter; Enter sobre
## el objeto en Inventario hace lo mismo. Aquí solo las reglas; sin escena.

const USO: String = "atuendo"


## Los ids de los atuendos, en el orden de la tabla.
static func ids() -> Array:
	var r: Array = []
	for id in Objetos.DATOS:
		if String((Objetos.DATOS[id] as Dictionary).get("uso", "")) == USO:
			r.append(String(id))
	return r


static func es_atuendo(id: String) -> bool:
	return String((Objetos.DATOS.get(id, {}) as Dictionary).get("uso", "")) == USO


## Las prendas (ids de ropa.json) del atuendo; [] si no es un atuendo.
static func prendas(id: String) -> Array:
	var r: Array = []
	for p in String(Objetos.efecto(id).get("prendas", "")).split(","):
		var s: String = p.strip_edges()
		if s != "":
			r.append(s)
	return r


## ¿Se tiene desde el principio (sin objeto en la mochila)?
static func inicial(id: String) -> bool:
	return Objetos.efecto(id).has("inicial")


## ¿Se tiene (es inicial o está en la mochila)?
static func tiene(id: String, e: Estado = null) -> bool:
	if not es_atuendo(id):
		return false
	if inicial(id):
		return true
	return (e if e != null else Estado.i()).cuenta(id) > 0


## El atuendo que lleva puesto `pj` (todas sus prendas puestas); "" si lleva otra cosa o nada.
static func puesto(pj: Node) -> String:
	if pj == null:
		return ""
	var puestas: Array = pj.call("ropa_puesta")
	for id in ids():
		var ps: Array = prendas(String(id))
		if ps.is_empty():
			continue
		var todas: bool = true
		for p in ps:
			if not puestas.has(p):
				todas = false
				break
		if todas:
			return String(id)
	return ""


## Se pone el atuendo `id` en `pj` (Pj3D): quita lo puesto y pone sus prendas. false si no se tiene o alguna prenda no carga.
static func poner(pj: Node, id: String, e: Estado = null) -> bool:
	if pj == null or not tiene(id, e):
		return false
	for p in (pj.call("ropa_puesta") as Array).duplicate():
		pj.call("quitar_ropa", String(p))
	var bien: bool = true
	for p in prendas(id):
		bien = bool(pj.call("poner_ropa", String(p))) and bien
	return bien


## El Pj3D de la jugadora en el árbol (por el lanzador, como hace Partida); null si no hay.
static func pj_de(arbol: SceneTree) -> Node:
	if arbol == null:
		return null
	var lanz: Node = arbol.get_first_node_in_group("spellcaster")
	if lanz == null:
		return null
	var jug: Variant = lanz.get("jugador")
	if jug == null or not (jug is Object):
		return null
	return (jug as Object).get("pj") as Node


## Dónde se consigue (para la ficha): el nombre de la tienda que lo vende, o "".
static func vendedor(id: String) -> String:
	for t in BD.tiendas():
		for fila in BD.tienda(String(t)):
			if String((fila as Dictionary).get("objeto", "")) == id:
				return String(t)
	return ""
