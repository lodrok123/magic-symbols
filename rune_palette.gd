extends PanelContainer

## PALETA DE PRUEBAS: poner runas con un clic, sin dibujarlas.
##
## SOLO PARA PROBAR. Mientras los trazos de cada glifo no estén definidos, esto deja
## componer una página directamente: eliges la página, pulsas un elemento y los
## glifos que quieras, y la lanzas con 1, 2 o 3 como siempre. Pasa por las MISMAS
## funciones que el reconocedor (Spellcaster.place_element / place_sigil -> add_sigil),
## así que valen igual el límite de glifos por página, las runas bloqueadas y el
## deshacer: lo único que se salta es el dibujo.
##
## F1 la esconde y la muestra. Los botones no cogen el foco, para que Espacio, T y
## los números sigan llegando al juego.

const TECLA: Key = KEY_F1

var _caster: Node = null
var _cuerpo: VBoxContainer = null
var _resumen: Label = null
var _botones_pagina: Array = []
var _firma: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cuerpo = VBoxContainer.new()
	_cuerpo.add_theme_constant_override("separation", 4)
	add_child(_cuerpo)


func _process(_delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		_caster = get_tree().get_first_node_in_group("spellcaster")
		if _caster == null:
			return

	# Se reconstruye si cambian las runas activas (la progresión las abre después
	# de que nazca la interfaz).
	var firma: String = ",".join(Repertoire.active_elements()) + "|" + ",".join(Repertoire.active_sigils())
	if firma != _firma:
		_firma = firma
		_construir()

	_refrescar()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == TECLA:
		visible = not visible
		get_viewport().set_input_as_handled()


func _construir() -> void:
	for h in _cuerpo.get_children():
		h.queue_free()
	_botones_pagina.clear()

	_cuerpo.add_child(_etiqueta("PALETA DE PRUEBAS  (F1 oculta)"))

	# Páginas.
	var fila_paginas := HBoxContainer.new()
	fila_paginas.add_child(_etiqueta("Página:"))
	for i in range(_caster.PAGES):
		var b := _boton(str(i + 1))
		b.pressed.connect(func(): _caster.select_page(i))
		fila_paginas.add_child(b)
		_botones_pagina.append(b)
	_cuerpo.add_child(fila_paginas)

	# Elementos.
	_cuerpo.add_child(_etiqueta("Elemento:"))
	var rejilla_e := GridContainer.new()
	rejilla_e.columns = 4
	for nombre in GestureLibrary.ELEMENTS:
		if not Repertoire.element_active(nombre):
			continue
		var tipo: int = _caster.GESTURE_TO_RUNE.get(nombre, Runes.Type.NONE)
		var datos: RuneData = _caster.rune_database.get(tipo)
		if datos == null:
			continue
		var b := _boton(String(nombre).capitalize())
		b.add_theme_color_override("font_color", datos.color.lightened(0.25))
		b.pressed.connect(func(): _caster.place_element(nombre))
		rejilla_e.add_child(b)
	_cuerpo.add_child(rejilla_e)

	# Glifos.
	_cuerpo.add_child(_etiqueta("Glifos:"))
	var rejilla_g := GridContainer.new()
	rejilla_g.columns = 4
	for nombre in GestureLibrary.SIGILS:
		if not Repertoire.sigil_active(nombre):
			continue
		var b := _boton(String(nombre).capitalize())
		var icono: Texture2D = Sigils.GLYPHS.get(nombre)
		if icono != null:
			b.icon = icono
			b.add_theme_constant_override("icon_max_width", 16)
		b.pressed.connect(func(): _caster.place_sigil(nombre))
		rejilla_g.add_child(b)
	_cuerpo.add_child(rejilla_g)

	# Deshacer y vaciar (la página activa).
	var fila_fin := HBoxContainer.new()
	var deshacer := _boton("Deshacer")
	deshacer.pressed.connect(func(): _caster.undo_last())
	fila_fin.add_child(deshacer)
	var vaciar := _boton("Vaciar página")
	vaciar.pressed.connect(func(): _caster.clear_sequence())
	fila_fin.add_child(vaciar)
	_cuerpo.add_child(fila_fin)

	# PRUEBAS: de golpe, todos los sellos, todos los glifos y todos los huecos.
	var todo := _boton("Añadir todos (sellos, glifos y huecos)")
	todo.pressed.connect(func():
		Repertoire.activate_all()
		Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
		_construir())
	_cuerpo.add_child(todo)

	_resumen = _etiqueta("")
	_cuerpo.add_child(_resumen)
	_cuerpo.add_child(_etiqueta("Lanza con 1 / 2 / 3"))

	# A la esquina de abajo a la izquierda, ya con su tamaño.
	reset_size()
	call_deferred("_colocar")


func _colocar() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)


func _refrescar() -> void:
	if _resumen == null:
		return
	for i in range(_botones_pagina.size()):
		(_botones_pagina[i] as Button).modulate = Color(1, 1, 1) if i == _caster.page else Color(1, 1, 1, 0.5)

	var datos: RuneData = _caster.current_element_data()
	var partes: Array = []
	for c in _caster.components():
		for g in c["sigils"]:
			partes.append(String(g).capitalize())
	_resumen.text = "Pág. %d: %s + %s  (%d/%d)" % [
		_caster.page + 1,
		datos.display_name if datos != null else "—",
		" + ".join(partes) if not partes.is_empty() else "—",
		_caster.sigils_used(), Repertoire.max_sigils_per_page]


func _boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


func _etiqueta(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 13)
	return l
