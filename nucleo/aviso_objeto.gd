class_name AvisoObjeto
extends RefCounted

## AVISO AL COGER UN OBJETO, POR CALIDAD (PLAN_PULSO_RESONANTE §7; docs/MATERIALES_CUEVA.md).
##   común      el `avisar("X (+1)")` de siempre.
##   épico      aviso con el borde morado, más largo, y un destello corto de luz morada sobre la jugadora.
##   legendario aviso dorado aún más largo; la secuencia del cofre pone el espectáculo (SecuenciaCofreLegendario3D), aquí solo el color.
## Lo llaman quienes dan objetos al suelo del mundo (Recolectable3D, el botín de los goblins). `lanz` = el Lanzador3D (grupo «spellcaster»).

const MAS_CLARO_TEXTO: float = 0.85         ## cuánto se aclara el color del texto respecto al de la calidad (el borde lleva el color puro)
const DESTELLO_ENERGIA: float = 3.0          ## fuerza de la luz del destello épico
const DESTELLO_ALCANCE: float = 5.0          ## u
const DESTELLO_SUBE_S: float = 0.08
const DESTELLO_BAJA_S: float = 0.45
const DESTELLO_ALTURA: float = 1.4           ## u sobre los pies de la jugadora


## Texto del aviso: «Nombre (+n)».
static func texto(id: String, n: int = 1) -> String:
	return "%s (+%d)" % [Objetos.nombre(id), n]


## Avisa de que se ha cogido `n` de `id`. Devuelve el color de la calidad (para las pruebas). Sin lanzador no hace nada.
static func mostrar(lanz: Node, id: String, n: int = 1) -> Color:
	var cal: String = Objetos.calidad(id)
	var color: Color = Objetos.color_calidad(id)
	if lanz == null or not lanz.has_method("avisar"):
		return color
	if cal == Objetos.CALIDAD_COMUN:
		lanz.call("avisar", texto(id, n))
		return color
	lanz.call("avisar", texto(id, n), color.lightened(MAS_CLARO_TEXTO), color, Objetos.duracion_aviso(id))
	if cal == Objetos.CALIDAD_EPICO:
		var j: Variant = lanz.get("jugador")
		if j is Node3D and (j as Node3D).is_inside_tree():
			destello(j as Node3D, color)
	return color


## Luz de color que sube y baja rápido sobre `donde`. Se borra sola.
static func destello(donde: Node3D, color: Color) -> OmniLight3D:
	var luz := OmniLight3D.new()
	luz.name = "DestelloMaterial"
	luz.light_color = color
	luz.omni_range = DESTELLO_ALCANCE
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	luz.position = Vector3(0.0, DESTELLO_ALTURA, 0.0)
	donde.add_child(luz)
	var tw: Tween = luz.create_tween()
	tw.tween_property(luz, "light_energy", DESTELLO_ENERGIA, DESTELLO_SUBE_S)
	tw.tween_property(luz, "light_energy", 0.0, DESTELLO_BAJA_S)
	tw.tween_callback(luz.queue_free)
	return luz
