class_name VarianteVegetal
extends Node3D
## VARIANTE VEGETAL (26/11/2026). Va en la RAÍZ de las piezas de arte/piezas cuya vegetación Pablo eligió sustituir por la del pack
## Pure Nature (docs/fab_ue/candidatos_vegetacion.json; lo pone herramientas/aplicar_candidatos_vegetacion.gd).
##
## En el mismo instante en que se crea la pieza (NOTIFICATION_SCENE_INSTANTIATED: antes de que nadie la toque), elige una de sus
## variantes (TablaVariantes) y pone su modelo en lugar del original dentro de «modelo», escalado para ocupar lo mismo que el original
## («al tamaño de la actual»). Tiene que ser en ese instante: el juego convierte los materiales a los suyos (Ocluso3D) y prepara el fuego,
## el mojado, el hielo y las reacciones sobre las mallas que encuentra al colocar la pieza; si el cambio llegara después, los efectos se
## quedarían en el modelo viejo. Los metadatos, el «cuerpo» (colisión) y la mecánica de la pieza no se tocan.
##
## Las variantes del pack llevan StandardMaterial3D (MaterialesUE.material_juego): el juego los convierte como los de cualquier pieza.
## Si la variante elegida es la pieza original, o el pack no está en esta máquina (arte/pure_nature/LEEME.md), no cambia nada.

## La caja del modelo ORIGINAL en el espacio del nodo «modelo» (la mide la herramienta al aplicar).
@export var caja_original: AABB = AABB()

## La variante que se está viendo ("" = la original).
var variante: String = ""


func _notification(que: int) -> void:
	if que == NOTIFICATION_SCENE_INSTANTIATED:
		_cambiar()


func _cambiar() -> void:
	var ruta: String = TablaVariantes.elegir(String(get_meta("id", name)))
	if ruta == "":
		return
	# Sin «modelo» (p. ej. arbol_sumicio, con las mallas sueltas en la raíz): se sustituyen las mallas que cuelgan directamente de la raíz.
	var modelo: Node3D = get_node_or_null("modelo") as Node3D
	var sueltas: bool = modelo == null
	if sueltas:
		modelo = self
	if caja_original.size.length() < 0.0001:
		return
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return
	var nuevo: Node3D = ps.instantiate() as Node3D
	var caja_n: AABB = TablaVariantes.caja(nuevo)
	if caja_n.size.length() < 0.0001:
		nuevo.free()
		return
	# Escala: lo alto se iguala por la ALTURA; lo plano (nenúfares, musgo) por lo que ocupa en planta.
	var o: AABB = caja_original
	var planta_o: float = maxf(o.size.x, o.size.z)
	# 26/11 (prueba_variantes_vegetacion): también hay que mirar la VARIANTE: el musgo de agua (26b) es plano y la planta que sustituye no;
	# igualándolo por la altura (casi 0) salía cientos de veces más grande.
	var alta: bool = o.size.y > planta_o * 0.35 and caja_n.size.y > maxf(caja_n.size.x, caja_n.size.z) * 0.15
	var k: float = (o.size.y / maxf(caja_n.size.y, 0.001)) if alta else (planta_o / maxf(maxf(caja_n.size.x, caja_n.size.z), 0.001))
	for c in modelo.get_children():
		if sueltas and not c is MeshInstance3D:
			continue
		modelo.remove_child(c)
		c.free()
	nuevo.name = "variante"
	nuevo.scale = Vector3.ONE * k
	var base_n := Vector3(caja_n.position.x + caja_n.size.x * 0.5, caja_n.position.y, caja_n.position.z + caja_n.size.z * 0.5)
	var base_o := Vector3(o.position.x + o.size.x * 0.5, o.position.y, o.position.z + o.size.z * 0.5)
	nuevo.position = base_o - base_n * k
	# casi sin grosor (el musgo de agua): un poco por encima del suelo para que no se pelee con él
	if caja_n.size.y * k < Pieza3D.ALZAR_PLANA:
		nuevo.position.y += Pieza3D.ALZAR_PLANA
	modelo.add_child(nuevo)
	variante = ruta
	set_meta("variante_pack", ruta)
