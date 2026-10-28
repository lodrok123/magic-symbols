class_name TintaReaccion
extends Node

## C2 (28/10): el que MIRA las reacciones del mundo y le dice a la tinta cuáles son de combo. Cuelga del `Mundo3D` (escucha `reaccion`) y traduce cada aviso
## al tipo de `Tinta.REACCIONES_PREMIADAS`; el cobro y el tope los lleva `Tinta.premiar_reaccion`. Lo monta `Jugador3D.montar`.
##   hundido        aviso «hundido» (empujado o caído al agua honda)
##   electrocutado  aviso «electrocutado» de un enemigo que YA estaba mojado (rayo sobre mojado: salta y hace ×1,5)
##   congelado      aviso «congelado» (el hielo lo deja preso)
##   mano_quemada   aviso «consumido» de un `Escudo3D` que se quema y le quema la mano a su goblin vivo
##   apagado        aviso «apagado_agua» (agua o hielo a un enemigo que ardía)
## NO cuentan: quemado normal («prendido»), mojado, aturdido, empujado (el viento suelto es el hechizo básico; no hay aviso de «contra algo»), daño simple.
## Nota: los avisos salen de golpes de hechizo y empujes, que en la práctica son del jugador; un empuje de gas también puede hundir y se cuenta igual.

var tinta: Tinta = null


## Engancha `tinta` al `mundo` (idempotente: una sola escucha por mundo). Devuelve el detector.
static func conectar(mundo: Mundo3D, p_tinta: Tinta) -> TintaReaccion:
	if mundo == null or p_tinta == null:
		return null
	var previo: Node = mundo.get_node_or_null("TintaReaccion")
	if previo is TintaReaccion:
		(previo as TintaReaccion).tinta = p_tinta
		return previo as TintaReaccion
	var d := TintaReaccion.new()
	d.name = "TintaReaccion"
	d.tinta = p_tinta
	mundo.add_child(d)
	mundo.reaccion.connect(d._al_reaccionar)
	return d


func _al_reaccionar(nombre: String, _punto: Vector3, nodo: Node) -> void:
	if tinta == null or nodo == null or not is_instance_valid(nodo):
		return
	if nodo is Escudo3D:
		var e := nodo as Escudo3D
		if nombre == "consumido" and e.estado == "quemado" and e.combate != null and is_instance_valid(e.combate) and not e.combate.muerto:
			tinta.premiar_reaccion(e.combate, "mano_quemada")
		return
	if not (nodo is Combate3D):
		return
	var c := nodo as Combate3D
	match nombre:
		"hundido":
			tinta.premiar_reaccion(c, "hundido")
		"electrocutado":
			if c.mojado > 0.0:                      # el aviso sale tras el golpe y el rayo no cambia el mojado: sigue como estaba
				tinta.premiar_reaccion(c, "electrocutado")
		"congelado":
			tinta.premiar_reaccion(c, "congelado")
		"apagado_agua":
			tinta.premiar_reaccion(c, "apagado")
