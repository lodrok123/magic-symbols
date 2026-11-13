class_name CofreMagico
extends Node3D
## Un COFRE MÁGICO del mundo (14/11): el modelo de cofre con un brillo azul y su rótulo. Todos abren el mismo almacén (AlmacenUI, Estado.almacen).
## No lo abre él: el nivel mira `cerca()` en su E y llama a `AlmacenUI.abrir_en`. Bloquea su casilla como los demás cofres.

const ALCANCE := 2.4
const COLOR := Color(0.45, 0.75, 1.0)
const ESCENA := preload("res://arte/piezas/cofre.tscn")


static func poner(mundo: Node3D, c: Vector2i, giro_y: float = 0.0) -> CofreMagico:
	var cofre := CofreMagico.new()
	cofre.name = "CofreMagico_%d_%d" % [c.x, c.y]
	mundo.add_child(cofre)
	cofre.global_position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	cofre.rotation.y = giro_y
	Terreno3D.bloquear_celda_completa(c)
	return cofre


## Igual que `poner`, pero en un punto cualquiera (interiores que no son casillas del terreno).
static func poner_en(padre: Node3D, posicion: Vector3, giro_y: float = 0.0) -> CofreMagico:
	var cofre := CofreMagico.new()
	padre.add_child(cofre)
	cofre.global_position = posicion
	cofre.rotation.y = giro_y
	return cofre


func _ready() -> void:
	add_to_group("cofre_magico")
	var modelo := ESCENA.instantiate() as Node3D
	add_child(modelo)
	var luz := OmniLight3D.new()
	luz.light_color = COLOR
	luz.light_energy = 1.4
	luz.omni_range = 2.6
	luz.position = Vector3(0, 0.9, 0)
	add_child(luz)
	var rotulo := Label3D.new()
	rotulo.text = "Cofre mágico"
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.pixel_size = 0.010
	rotulo.modulate = COLOR.lightened(0.4)
	rotulo.outline_size = 8
	rotulo.position = Vector3(0, 1.45, 0)
	add_child(rotulo)


## ¿Hay un cofre mágico a tiro de E de `yo`?
static func cerca(arbol: SceneTree, yo: Vector3) -> bool:
	for c in arbol.get_nodes_in_group("cofre_magico"):
		var d: Vector3 = (c as Node3D).global_position - yo
		d.y = 0.0
		if (c as Node3D).is_visible_in_tree() and d.length() <= ALCANCE:
			return true
	return false
