class_name AvisoObjeto
extends RefCounted

## AVISO AL COGER UN OBJETO, POR CALIDAD (PLAN_PULSO_RESONANTE §7; docs/MATERIALES_CUEVA.md).
##   común      el `avisar("X (+1)")` de siempre.
##   épico      aviso con el borde morado, más largo, y un destello corto de luz morada sobre la jugadora.
##   legendario aviso dorado aún más largo; la secuencia del cofre pone el espectáculo (SecuenciaCofreLegendario3D), aquí solo el color.
## Lo llaman quienes dan objetos al suelo del mundo (Recolectable3D, el botín de los goblins). `lanz` = el Lanzador3D (grupo «spellcaster»).

## Legibilidad (24/10): el aviso lleva SU PROPIO fondo oscuro, así que se lee igual sobre hielo, arena, hierba o cueva. El color de la
## calidad va en el borde y en dos franjas laterales (no depende de lo que haya detrás); el texto es casi blanco con contorno oscuro.
const COLOR_TEXTO: Color = Color(1.0, 0.98, 0.94)          ## texto de los avisos de calidad (claro, sin teñir de rosa ni de amarillo)
const COLOR_CONTORNO: Color = Color(0.0, 0.0, 0.0, 0.95)   ## contorno del texto
const CONTORNO_PX: int = 6
const FONDO_CALIDAD: Color = Color(0.05, 0.04, 0.09, 0.94) ## panel de los avisos épico y legendario (casi opaco)
const FONDO_COMUN: Color = Color(0.04, 0.04, 0.07, 0.78)   ## respaldo del aviso común: sin borde de color, pero lo bastante oscuro para leerse sobre hierba o hielo
const SOMBRA_PANEL: Color = Color(0.0, 0.0, 0.0, 0.75)     ## contorno oscuro por fuera del borde de color
const SOMBRA_PANEL_PX: int = 4
const BORDE_PX: int = 4                                    ## grosor del borde de color de la calidad
const FRANJA_PX: int = 14                                  ## grosor de las franjas laterales (izquierda y derecha) con el color de la calidad
const BORDE_SATURACION_MIN: float = 0.9                    ## el borde sube a esta saturación (y a brillo pleno) aunque el color de calidad sea más pálido
const ESQUINA_PX: int = 8
const MARGEN_X_PX: float = 12.0                            ## aire entre la franja y el texto
const MARGEN_Y_PX: float = 5.0
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
	mostrar_texto(lanz, texto(id, n), cal)
	if cal == Objetos.CALIDAD_EPICO and lanz != null and lanz.has_method("avisar"):
		var j: Variant = lanz.get("jugador")
		if j is Node3D and (j as Node3D).is_inside_tree():
			destello(j as Node3D, color)
	return color


## Avisa con el aspecto de una calidad (para lo que no es un objeto de DATOS: el glifo legendario del cofre). Sin lanzador no hace nada.
static func mostrar_texto(lanz: Node, txt: String, cal: String) -> void:
	if lanz == null or not lanz.has_method("avisar"):
		return
	if cal == Objetos.CALIDAD_COMUN or not Objetos.CALIDADES.has(cal):
		lanz.call("avisar", txt)
		return
	var datos: Dictionary = Objetos.CALIDADES[cal]
	var color: Color = datos["color"]
	lanz.call("avisar", txt, COLOR_TEXTO, color, float(datos["aviso_s"]))
	var etiqueta: Variant = lanz.get("_aviso")
	if etiqueta is Label:
		estilo_calidad(etiqueta as Label, color)


## Color del borde y de las franjas: el de la calidad, subido a saturación y brillo altos para que destaque sobre el panel oscuro.
static func color_borde(color: Color) -> Color:
	return Color.from_hsv(color.h, maxf(color.s, BORDE_SATURACION_MIN), 1.0)


## El aviso de siempre, con un respaldo oscuro suave. Lo llama Lanzador3D.avisar antes de cada aviso (así el de calidad anterior no se hereda).
static func estilo_comun(etiqueta: Label) -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = FONDO_COMUN
	caja.set_corner_radius_all(ESQUINA_PX)
	_margenes(caja)
	_aplicar(etiqueta, caja)


## Panel de calidad: fondo casi opaco, borde grueso y franjas laterales con el color saturado, sombra negra por fuera y texto claro.
static func estilo_calidad(etiqueta: Label, color: Color) -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = FONDO_CALIDAD
	caja.set_border_width_all(BORDE_PX)
	caja.border_width_left = FRANJA_PX
	caja.border_width_right = FRANJA_PX
	caja.border_color = color_borde(color)
	caja.set_corner_radius_all(ESQUINA_PX)
	caja.shadow_color = SOMBRA_PANEL
	caja.shadow_size = SOMBRA_PANEL_PX
	_margenes(caja)
	_aplicar(etiqueta, caja)


static func _margenes(caja: StyleBoxFlat) -> void:
	caja.content_margin_left = MARGEN_X_PX
	caja.content_margin_right = MARGEN_X_PX
	caja.content_margin_top = MARGEN_Y_PX
	caja.content_margin_bottom = MARGEN_Y_PX


## Pone el panel y el contorno oscuro, y encoge la etiqueta al texto (centrada arriba) para que el panel no sea una barra de lado a lado.
static func _aplicar(etiqueta: Label, caja: StyleBoxFlat) -> void:
	etiqueta.add_theme_stylebox_override("normal", caja)
	etiqueta.add_theme_color_override("font_outline_color", COLOR_CONTORNO)
	etiqueta.add_theme_constant_override("outline_size", CONTORNO_PX)
	var arriba: float = etiqueta.offset_top
	etiqueta.anchor_left = 0.5
	etiqueta.anchor_right = 0.5
	etiqueta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	etiqueta.offset_left = 0.0
	etiqueta.offset_right = 0.0
	etiqueta.offset_top = arriba
	etiqueta.reset_size()


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
