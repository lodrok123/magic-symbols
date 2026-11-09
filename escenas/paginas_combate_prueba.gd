extends CanvasLayer

## Tres formas para comparar el origen local y el glifo de posición.
const FUEGO: int = Runes.Type.SHAPE_TRIANGLE
const AGUA: int = Runes.Type.SHAPE_CIRCLE
const VIENTO: int = Runes.Type.SHAPE_LINES
const MURO: Array = ["barrera", "linea_x", "linea_x", "altura", "altura", "altura"]
const FUEGO_ASCENDENTE: Array = ["altura", "altura", "altura", "pulso"]
const AGUA_MAX_POR_MURO: float = 0.18  ## casillas cúbicas por lanzamiento de prueba
const MODOS: Array[String] = ["Botón", "Icono", "Dibujo"]

@export var patio_tactico: bool = false

var _lanzador: Lanzador3D
var _panel: PanelContainer
var _texto: Label
var _a_distancia: bool = false
var _recetas: Array[Dictionary] = []
var _modo: int = 0
var _edicion: PanelContainer
var _instruccion: Label
var _icono: Button
var _confirmar: Button
var _lienzo: Control
var _trazo := PackedVector2Array()
var _dibujando: bool = false
var _inicio_ms: int = 0
var _intentos: int = 0
var _plantillas: Dictionary = {}
var _flecha: bool = false
var _muro_agua: bool = false
var _avisos: Dictionary = {}
var _refresco_avisos: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar.call_deferred()


func _montar() -> void:
	_lanzador = get_parent().get_node_or_null("Lanzador3D") as Lanzador3D
	if _lanzador == null:
		return
	_lanzador.limite_agua_muro = AGUA_MAX_POR_MURO
	if patio_tactico:
		_configurar_patio()
	_actualizar_paginas()
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_right = -16.0
	_panel.offset_left = -390.0
	_panel.offset_top = 16.0
	add_child(_panel)
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	_panel.add_child(margen)
	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 15)
	margen.add_child(_texto)
	_montar_editor()


func _actualizar_paginas() -> void:
	var segunda: Dictionary = _ficha(FUEGO, ["flecha", "flecha", "flecha"] if _flecha else FUEGO_ASCENDENTE, not _flecha)
	var tercera: Dictionary = _ficha(VIENTO, ["flecha", "flecha"], false) if patio_tactico and not _muro_agua else _ficha(AGUA, MURO, true)
	_lanzador.fichas_combate = [_ficha(FUEGO, MURO, _a_distancia), segunda, tercera]
	_recetas.clear()
	for ficha in _lanzador.fichas_combate:
		_recetas.append(_montar_receta(ficha))


func _ficha(elemento: int, glifos: Array, a_distancia: bool) -> Dictionary:
	var receta: Array = glifos + ["posicion"] if a_distancia else glifos
	return {"element": elemento, "components": [{"sigils": receta}], "origen_explicito": true}


func _unhandled_key_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if _lanzador == null or _lanzador.libro_abierto() or _lanzador.modo_lanzar or get_tree().paused:
		return
	if evento.keycode == KEY_M:
		_modo = (_modo + 1) % MODOS.size()
		get_viewport().set_input_as_handled()
	elif patio_tactico and evento.keycode == KEY_4:
		_flecha = not _flecha
		_actualizar_paginas()
		get_viewport().set_input_as_handled()
	elif patio_tactico and evento.keycode == KEY_5:
		_muro_agua = not _muro_agua
		_actualizar_paginas()
		get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_X and not _lanzador.jugador.muerto:
		if _modo == 0:
			_aplicar_cambio()
		else:
			_abrir_editor()
		get_viewport().set_input_as_handled()


func _aplicar_cambio() -> void:
	_a_distancia = not _a_distancia
	_actualizar_paginas()
	PlayLog.event("variante_combate", {"pagina": 1, "posicion": _a_distancia, "entrada": MODOS[_modo]})


func _input(evento: InputEvent) -> void:
	if _edicion != null and _edicion.visible and evento.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		_cerrar_editor(false)


func _montar_editor() -> void:
	_edicion = PanelContainer.new()
	_edicion.hide()
	_edicion.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_edicion.position.x = 20.0
	add_child(_edicion)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size.x = 290.0
	_edicion.add_child(caja)
	_instruccion = Label.new()
	caja.add_child(_instruccion)
	_icono = Button.new()
	_icono.custom_minimum_size.y = 110.0
	_icono.pressed.connect(_validar_entrada)
	caja.add_child(_icono)
	_lienzo = Control.new()
	_lienzo.custom_minimum_size.y = 110.0
	_lienzo.gui_input.connect(_entrada_trazo)
	_lienzo.draw.connect(_dibujar_trazo)
	caja.add_child(_lienzo)
	var acciones := HBoxContainer.new()
	caja.add_child(acciones)
	_confirmar = Button.new()
	_confirmar.text = "Aplicar"
	_confirmar.pressed.connect(_cerrar_editor.bind(true))
	acciones.add_child(_confirmar)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(_cerrar_editor.bind(false))
	acciones.add_child(cancelar)
	_plantillas = {
		"posicion": [GestureRecognizer.normalize([PackedVector2Array([Vector2.ZERO, Vector2(0, 1), Vector2(1, 1)])])],
		"horizontal": [GestureRecognizer.normalize([PackedVector2Array([Vector2.ZERO, Vector2.RIGHT])])],
		"vertical": [GestureRecognizer.normalize([PackedVector2Array([Vector2.ZERO, Vector2.DOWN])])],
		"diagonal": [GestureRecognizer.normalize([PackedVector2Array([Vector2.ZERO, Vector2.ONE])])],
	}


func _abrir_editor() -> void:
	_inicio_ms = Time.get_ticks_msec()
	_intentos = 0
	_trazo.clear()
	_dibujando = false
	_confirmar.disabled = true
	_icono.visible = _modo == 1
	_lienzo.visible = _modo == 2
	_icono.text = "Quitar Posición" if _a_distancia else "+ Posición"
	_instruccion.text = "Página 1 · Muro de fuego\n" + ("Dibuja └ de arriba a abajo y a la derecha" if _modo == 2 else "Elige el cambio de glifo")
	_lienzo.queue_redraw()
	_edicion.show()
	get_tree().paused = true


func _cerrar_editor(aplicar: bool) -> void:
	if aplicar:
		_aplicar_cambio()
	PlayLog.event("edicion_combate", {"entrada": MODOS[_modo], "aplicada": aplicar, "intentos": _intentos, "ms": Time.get_ticks_msec() - _inicio_ms})
	_edicion.hide()
	get_tree().paused = false


func _validar_entrada() -> void:
	_confirmar.disabled = false
	_instruccion.text = "Página 1 · Muro de fuego\n" + ("Quitar Posición" if _a_distancia else "Añadir Posición")


func _entrada_trazo(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_trazo = PackedVector2Array([evento.position])
			_dibujando = true
			_confirmar.disabled = true
		elif _dibujando:
			_dibujando = false
			_trazo.append(evento.position)
			_intentos += 1
			var resultado: Dictionary = GestureRecognizer.recognize([_trazo], _plantillas)
			if _trazo.size() >= 4 and _trazo[0].distance_to(_trazo[-1]) >= 24.0 and resultado["name"] == "posicion" and resultado["accepted"] and float(resultado["score"]) >= 0.8:
				_validar_entrada()
			else:
				_instruccion.text = "Trazo sin reconocer. Prueba otra vez · └"
		_lienzo.queue_redraw()
	elif evento is InputEventMouseMotion and _dibujando:
		_trazo.append(evento.position)
		_lienzo.queue_redraw()


func _dibujar_trazo() -> void:
	_lienzo.draw_rect(Rect2(Vector2.ZERO, _lienzo.size), Color(0.11, 0.12, 0.16))
	if _trazo.size() >= 2:
		_lienzo.draw_polyline(_trazo, Color(1.0, 0.83, 0.52), 3.0, true)


func _process(delta: float) -> void:
	if _texto == null:
		return
	if patio_tactico and not get_tree().paused:
		_refresco_avisos -= delta
		if _refresco_avisos <= 0.0:
			_refresco_avisos = 0.15
			_actualizar_avisos()
	_panel.visible = not _lanzador.libro_abierto()
	if not _panel.visible:
		return
	var origen: String = "POSICIÓN" if _a_distancia else "LOCAL"
	_texto.text = "%s  ·  M cambia la prueba\nX edita el muro · %s\n%s  %s\n%s  %s\n%s  %s\nMantén para apuntar · suelta para lanzar" % [
		MODOS[_modo], origen,
		Controles.texto_teclas("pagina_1"), _resumen(0, "Muro de fuego"),
		Controles.texto_teclas("pagina_2"), _resumen(1, "Flecha de fuego" if _flecha else "Fuego ascendente"),
		Controles.texto_teclas("pagina_3"), _resumen(2, "Empuje de viento" if patio_tactico and not _muro_agua else "Muro de agua")]
	if patio_tactico:
		_texto.text += "\n4 Flecha / pilar   ·   5 Viento / agua\n≈ Suelo mojado   ·   ≋ Agua honda"


func _configurar_patio() -> void:
	for nodo in get_tree().get_nodes_in_group("combate3d"):
		var enemigo := nodo as Combate3D
		if enemigo == null or enemigo.mundo != get_parent():
			continue
		enemigo.combate_tactico = true
		if enemigo.arquero:
			enemigo.fijo = true
			enemigo.puesto_cubierto = Terreno3D.centro_de(Vector2i(14, 2), enemigo.position.y)
			enemigo.puestos_disparo = [
				Terreno3D.centro_de(Vector2i(14, 3), enemigo.position.y),
				Terreno3D.centro_de(Vector2i(14, 1), enemigo.position.y)]


func _actualizar_avisos() -> void:
	var visibles: Dictionary = {}
	for muro: Lanzador3D.SolidezV2 in _lanzador._solideces_v2:
		if not is_instance_valid(muro) or muro.is_queued_for_deletion() or muro.celdas.is_empty():
			continue
		if muro.vida > 1.25 and muro.aguante > 10.0:
			continue
		var centro := Vector3.ZERO
		for c: Vector2i in muro.celdas:
			centro += Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		centro /= muro.celdas.size()
		centro.y += Terreno3D.ALTO_NIVEL * muro.niveles
		var texto: String = "Cede en %.1f s" % muro.vida if muro.vida <= 1.25 else "Muro agrietado"
		_aviso(muro.get_instance_id(), centro, texto, Color(1.0, 0.66, 0.25), visibles)
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim != null:
		var origen: Vector2i = Terreno3D.celda_de(_lanzador.jugador.position)
		for z in range(origen.y - 4, origen.y + 5):
			for x in range(origen.x - 4, origen.x + 5):
				var c := Vector2i(x, z)
				if not Terreno3D.en_mapa(c) or sim.casilla_helada(c) or sim.profundidad_casilla(c) < 0.04:
					continue
				var honda: bool = Terreno3D.se_nada(c)
				var pos: Vector3 = Terreno3D.centro_de(c)
				pos.y = sim.superficie_en(pos) + 0.1
				_aviso(c, pos, "≋" if honda else "≈", Color(0.36, 0.89, 1.0) if honda else Color(0.78, 0.92, 0.96), visibles)
	for clave in _avisos.keys():
		if not visibles.has(clave):
			_avisos[clave].queue_free()
			_avisos.erase(clave)


func _aviso(clave: Variant, pos: Vector3, texto: String, color: Color, visibles: Dictionary) -> void:
	var etiqueta: Label3D = _avisos.get(clave)
	if etiqueta == null:
		etiqueta = Label3D.new()
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.font_size = 28
		etiqueta.pixel_size = 0.01
		get_parent().add_child(etiqueta)
		_avisos[clave] = etiqueta
	etiqueta.position = pos
	etiqueta.text = texto
	etiqueta.modulate = color
	visibles[clave] = true


func _montar_receta(ficha: Dictionary) -> Dictionary:
	var rune: RuneData = _lanzador.rune_database.get(ficha["element"])
	return Lanzador3D.receta_de_ficha(ficha, rune)


func _resumen(indice: int, titulo: String) -> String:
	var montada: Dictionary = _recetas[indice]
	var hechizo: Hechizo = montada["hechizo"]
	if hechizo == null:
		return titulo
	var coste: float = Lanzador3D.tinta_prevista(hechizo, montada["rune"], _lanzador.tinta)
	var recarga: float = _lanzador.cooldown_left[indice]
	var estado: String = "  ·  %.1f s" % recarga if recarga > 0.0 else ""
	var glifo: String = " + Posición" if hechizo.glifos.has("posicion") else ""
	return "%s%s  ·  %.0f tinta%s" % [titulo, glifo, coste, estado]
