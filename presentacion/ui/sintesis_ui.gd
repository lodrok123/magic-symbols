extends CanvasLayer

const TINTA := Color("#f2e4cb")
const DORADO := Color("#dec185")

var _lugar := ""
var _receta := ""
var _mezcla: Dictionary = {}
var _pausa_propia := false
var _fondo: ColorRect
var _recetas: ItemList
var _ids: Array[String] = []
var _bolsa: VBoxContainer
var _mesa: VBoxContainer
var _resultado: Label
var _requisitos: Label
var _aviso: Label
var _crear: Button


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	Sintesis.i().sintesis_abierta.connect(abrir)
	Sintesis.i().aviso.connect(_mostrar_aviso)


func abrir(lugar: String) -> void:
	if _fondo.visible or get_tree().paused:
		return
	_lugar = lugar
	_pausa_propia = true
	get_tree().paused = true
	_fondo.show()
	_ids = Sintesis.conocidas(lugar)
	_recetas.clear()
	for id in _ids:
		_recetas.add_item(String(BD.receta(id).get("nombre", id)))
	_receta = ""
	_mezcla.clear()
	_aviso.text = ""
	if not _ids.is_empty():
		_recetas.select(0)
		_receta = _ids[0]
	_recetas.grab_focus()
	_actualizar()


func cerrar() -> void:
	_fondo.hide()
	_mezcla.clear()
	if _pausa_propia:
		get_tree().paused = false
		_pausa_propia = false


func _exit_tree() -> void:
	if _pausa_propia:
		get_tree().paused = false


func _input(evento: InputEvent) -> void:
	if is_instance_valid(_fondo) and _fondo.visible and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func _elegir(indice: int) -> void:
	_receta = _ids[indice]
	_mezcla.clear()
	_aviso.text = ""
	_actualizar()


func _poner(id: String) -> void:
	if _receta.is_empty() or Estado.i().cuenta(id) <= int(_mezcla.get(id, 0)):
		return
	_mezcla[id] = int(_mezcla.get(id, 0)) + 1
	_aviso.text = ""
	_actualizar()


func _quitar(id: String) -> void:
	var quedan := int(_mezcla[id]) - 1
	if quedan == 0:
		_mezcla.erase(id)
	else:
		_mezcla[id] = quedan
	_aviso.text = ""
	_actualizar()


func _sintetizar() -> void:
	if not Sintesis.hacer(_receta, _mezcla, _lugar):
		return
	_mezcla.clear()
	_aviso.text = "Síntesis completada. El resultado está en tu inventario."
	_actualizar()
	Partida.autoguardar(get_tree(), "sintesis", {}, true)


func _mostrar_aviso(texto: String) -> void:
	if _fondo.visible:
		_aviso.text = texto


func _actualizar() -> void:
	for lista in [_bolsa, _mesa]:
		for hijo in lista.get_children():
			lista.remove_child(hijo)
			hijo.queue_free()
	var requisitos := Sintesis.requisitos(_receta)
	var ancla := Sintesis.ancla(_receta)
	for objeto in Estado.i().items:
		var id := String(objeto)
		var disponibles := Estado.i().cuenta(id) - int(_mezcla.get(id, 0))
		if disponibles <= 0:
			continue
		var fila := Ingrediente.new()
		fila.id = id
		fila.text = "%s  ×%d" % [Objetos.nombre(id), disponibles]
		var aportes := PackedStringArray()
		var admite := id == ancla
		for etiqueta in Objetos.etiquetas(id):
			aportes.append("%s +%d" % [etiqueta.capitalize(), Objetos.potencia(id)])
			admite = admite or requisitos.has(etiqueta)
		fila.disabled = not admite
		fila.tooltip_text = ", ".join(aportes)
		if Objetos.tiene_icono(id):
			fila.icon = Objetos.icono(id, 48.0)
			fila.add_theme_constant_override("icon_max_width", 28)
		fila.pressed.connect(_poner.bind(id))
		_bolsa.add_child(fila)
	for objeto in _mezcla:
		var quitar := Button.new()
		quitar.mouse_filter = Control.MOUSE_FILTER_PASS
		quitar.text = "%s  ×%d   −" % [Objetos.nombre(objeto), _mezcla[objeto]]
		quitar.pressed.connect(_quitar.bind(objeto))
		_mesa.add_child(quitar)
	if _mezcla.is_empty():
		_etiqueta(_mesa, "Arrastra ingredientes aquí\no selecciónalos en la mochila.")
	if _receta.is_empty():
		_resultado.text = "Sin recetas conocidas"
		_requisitos.text = ""
		_crear.disabled = true
		return
	var receta := BD.receta(_receta)
	var salida := String(receta.get("da", "")).split(":")
	var nombre := "Mejora · " + salida[1].capitalize() if salida.size() > 1 and salida[0] == "mejora" else Objetos.nombre(salida[0])
	var cantidad := " ×" + salida[1] if salida.size() > 1 and salida[0] != "mejora" else ""
	_resultado.text = nombre + cantidad
	var totales := Sintesis.totales(_mezcla)
	var lineas := PackedStringArray()
	for etiqueta in requisitos:
		var actual := int(totales.get(etiqueta, 0))
		var meta := int(requisitos[etiqueta])
		var estado := "Listo" if actual >= meta else "Faltan %d" % (meta - actual)
		lineas.append("%s  %d/%d  ·  %s" % [String(etiqueta).capitalize(), actual, meta, estado])
	if not ancla.is_empty():
		lineas.append("Base · %s  %d/1" % [Objetos.nombre(ancla), mini(1, int(_mezcla.get(ancla, 0)))])
	lineas.append("Coste · %d de oro   |   Tienes %d" % [int(receta.get("oro", 0)), Estado.i().oro])
	_requisitos.text = "\n".join(lineas)
	_crear.disabled = not bool(Sintesis.puede(_receta, _mezcla, _lugar)["ok"])


func _montar() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color("#17151bee")
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tema := Theme.new()
	tema.default_font_size = 16
	tema.set_color("font_color", "Label", TINTA)
	tema.set_color("font_color", "Button", TINTA)
	tema.set_color("font_color", "ItemList", TINTA)
	_fondo.theme = tema
	var margen := MarginContainer.new()
	_fondo.add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	var pagina := VBoxContainer.new()
	pagina.add_theme_constant_override("separation", 14)
	margen.add_child(pagina)
	var cabecera := HBoxContainer.new()
	pagina.add_child(cabecera)
	var titulo := _etiqueta(cabecera, "Síntesis", 30)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var salir := Button.new()
	salir.text = "Cerrar · Esc"
	salir.pressed.connect(cerrar)
	cabecera.add_child(salir)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 16)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pagina.add_child(columnas)
	var libro := _columna(columnas, "Recetas")
	_recetas = ItemList.new()
	_recetas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recetas.item_selected.connect(_elegir)
	libro.add_child(_recetas)
	_bolsa = _lista(_columna(columnas, "Mochila"))
	var trabajo := _columna(columnas, "Mesa de síntesis")
	_resultado = _etiqueta(trabajo, "", 23)
	_requisitos = _etiqueta(trabajo, "")
	var destino := Bandeja.new()
	destino.recibir = _poner
	destino.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trabajo.add_child(destino)
	_mesa = _lista(destino)
	_crear = Button.new()
	_crear.text = "Sintetizar"
	_crear.pressed.connect(_sintetizar)
	trabajo.add_child(_crear)
	_aviso = _etiqueta(pagina, "")
	_fondo.hide()


func _columna(padre: Container, titulo: String) -> VBoxContainer:
	var marco := PanelContainer.new()
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#29242b")
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	marco.add_theme_stylebox_override("panel", estilo)
	padre.add_child(marco)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 10)
	marco.add_child(contenido)
	_etiqueta(contenido, titulo, 20).add_theme_color_override("font_color", DORADO)
	return contenido


func _lista(padre: Container) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	padre.add_child(scroll)
	var lista := VBoxContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	lista.mouse_filter = Control.MOUSE_FILTER_PASS
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	return lista


func _etiqueta(padre: Container, texto: String, tam := 16) -> Label:
	var nodo := Label.new()
	nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nodo.text = texto
	nodo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nodo.add_theme_font_size_override("font_size", tam)
	padre.add_child(nodo)
	return nodo


class Ingrediente extends Button:
	var id := ""

	func _get_drag_data(_pos: Vector2) -> Variant:
		if disabled:
			return null
		var vista := Label.new()
		vista.text = Objetos.nombre(id)
		set_drag_preview(vista)
		return {"ingrediente_sintesis": id}


class Bandeja extends PanelContainer:
	var recibir: Callable

	func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
		return datos is Dictionary and datos.has("ingrediente_sintesis")

	func _drop_data(_pos: Vector2, datos: Variant) -> void:
		recibir.call_deferred(String(datos["ingrediente_sintesis"]))
