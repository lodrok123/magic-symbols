class_name MenuPausa
extends CanvasLayer

## EL MENÚ DE PAUSA (1/11, gamefeel tarea Pa). Escape con nada abierto lo abre; Escape o «Continuar» lo cierra. Pausa el árbol con el mismo patrón que `MenuPestanas`
## (`get_tree().paused`, `_pausado_por_mi`; no se abre si ya hay pausa ni con el libro abierto, ni mientras el lanzador está apuntando: ahí Escape cancela el apuntado).
## Prioridad de Escape: libro → mochila → pausa (el libro y la mochila siguen cerrándose como siempre; esto solo toma el Escape que nadie quería).
##
## Filas (flechas ↑↓ y Enter, ←→ ajustan un deslizador, o el ratón): Continuar · Volumen general / Mundo / Interfaz (−30 a +6 dB, en vivo con `Sfx.fijar_volumen_bus`) ·
## Sensación (interruptor de `Sensacion3D.ACTIVA`) · Reiniciar nivel (recarga la escena, pide confirmación) · Salir (cierra el juego, pide confirmación).
## Los volúmenes y la sensación se guardan en `user://ajustes.cfg` (`RUTA_AJUSTES`) al cambiarlos y se cargan al montar el primer menú de la sesión (`cargar_ajustes`).
## Entra y sale en `T_S` s con fundido y escala 0,96 → 1 como el grimorio (U1); con `Sensacion3D.ACTIVA = false` aparece y desaparece de golpe (los sonidos quedan).
## No existe menú principal y esto no lo crea.
## Para las pruebas: `abrir()`, `cerrar()`, `mover(dir)`, `ajustar(dir)`, `accion()`, `abierta`, `fila`, `confirmando`, `valor_de(id)`, `poner_volumen(id, db)`.

const FILAS: Array = [
	{"id": "continuar", "texto": "Continuar", "tipo": "boton"},
	{"id": "master", "texto": "Volumen general", "tipo": "volumen", "bus": "Master"},
	{"id": "mundo", "texto": "Volumen del mundo", "tipo": "volumen", "bus": "Mundo"},
	{"id": "interfaz", "texto": "Volumen de la interfaz", "tipo": "volumen", "bus": "Interfaz"},
	{"id": "sensacion", "texto": "Sensación", "tipo": "interruptor"},
	{"id": "reiniciar", "texto": "Reiniciar nivel", "tipo": "peligro"},
	{"id": "salir", "texto": "Salir", "tipo": "peligro"},
]

static var RUTA_AJUSTES: String = "user://ajustes.cfg"
static var T_S: float = 0.15                    ## duración de abrir y de cerrar
static var ESCALA_CERRADO: float = 0.96         ## escala de partida al abrir y de llegada al cerrar
static var ALFA_FONDO: float = 0.55             ## cuánto se oscurece el juego (sin desenfoque)
static var VOL_MIN_DB: float = -30.0
static var VOL_MAX_DB: float = 6.0
static var PASO_DB: float = 2.0                 ## lo que mueve ← → un deslizador
static var DB_SONIDO: float = -12.0             ## libro_abre / libro_cierra

var abierta: bool = false
var fila: int = 0                               ## la fila elegida
var confirmando: String = ""                    ## «reiniciar» o «salir» mientras espera el segundo Enter; "" si no
var reinicios: int = 0                          ## cuántas veces se confirmó «Reiniciar» (las pruebas lo miran)
var _pausado_por_mi: bool = false
var _velo: ColorRect
var _centro: CenterContainer
var _panel: PanelContainer
var _tw: Tween = null
var _filas: Array = []                          ## por fila: {panel, etiqueta, valor, deslizador, ctrl}
static var _cargado: bool = false


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _cargado:
		cargar_ajustes()
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.visible = false
	add_child(_velo)
	_centro = CenterContainer.new()
	_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centro.theme = TemaInterfaz.tema()
	_centro.visible = false
	add_child(_centro)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_centro.add_child(_panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = "Pausa"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", TemaInterfaz.BORDE_CALIDO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	for i in range(FILAS.size()):
		caja.add_child(_crear_fila(i))
	var pie := Label.new()
	pie.text = "[↑↓] elegir   [←→] ajustar   [Enter] aceptar   [Esc] continuar"
	pie.add_theme_font_size_override("font_size", TemaInterfaz.TAM_FUENTE_PEQUENO)
	pie.add_theme_color_override("font_color", TemaInterfaz.TEXTO_SUAVE)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(pie)
	_refrescar()


func _exit_tree() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false


func _crear_fila(i: int) -> Control:
	var d: Dictionary = FILAS[i]
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var et := Label.new()
	et.text = String(d["texto"])
	et.custom_minimum_size = Vector2(190.0, 0.0)
	et.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(et)
	var reg: Dictionary = {"panel": p, "etiqueta": et, "valor": null, "deslizador": null}
	if String(d["tipo"]) == "volumen":
		var s := HSlider.new()
		s.min_value = VOL_MIN_DB
		s.max_value = VOL_MAX_DB
		s.step = 1.0
		s.focus_mode = Control.FOCUS_NONE
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(150.0, 20.0)
		_estilo_deslizador(s)
		s.value_changed.connect(func(v: float) -> void: _al_mover_deslizador(i, v))
		h.add_child(s)
		var val := Label.new()
		val.custom_minimum_size = Vector2(64.0, 0.0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(val)
		reg["valor"] = val
		reg["deslizador"] = s
	elif String(d["tipo"]) == "interruptor":
		var val := Label.new()
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(val)
		reg["valor"] = val
	else:
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ratón: pasar por encima elige la fila; un clic en una fila que no es deslizador actúa.
	p.mouse_entered.connect(func() -> void: _elegir(i))
	p.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and String(FILAS[i]["tipo"]) != "volumen":
			_elegir(i, false)
			accion())
	_filas.append(reg)
	return p


func _estilo_deslizador(s: HSlider) -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.03, 0.03, 0.05, 0.9)
	fondo.set_corner_radius_all(3)
	fondo.content_margin_top = 3.0
	fondo.content_margin_bottom = 3.0
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = TemaInterfaz.BORDE_CALIDO
	relleno.set_corner_radius_all(3)
	relleno.content_margin_top = 3.0
	relleno.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", fondo)
	s.add_theme_stylebox_override("grabber_area", relleno)
	s.add_theme_stylebox_override("grabber_area_highlight", relleno)


## --- Datos (y lo que usan las pruebas) ---

func id_fila(i: int) -> String:
	return String((FILAS[i] as Dictionary)["id"])


func _indice(id: String) -> int:
	for i in range(FILAS.size()):
		if String((FILAS[i] as Dictionary)["id"]) == id:
			return i
	return -1


## dB del bus de una fila de volumen.
func valor_de(id: String) -> float:
	var i: int = _indice(id)
	if i < 0 or String(FILAS[i]["tipo"]) != "volumen":
		return 0.0
	return volumen_bus_de(String(FILAS[i]["bus"]))


static func volumen_bus_de(bus: String) -> float:
	if bus == Sfx3D.BUS_MUNDO or bus == Sfx3D.BUS_OCLUIDO:
		Sfx3D._asegurar_buses()
	return Sfx.volumen_bus(bus) if AudioServer.get_bus_index(bus) >= 0 or bus == Sfx.BUS_INTERFAZ else 0.0


## Fija el volumen de la fila `id` ("master", "mundo", "interfaz") como si se moviera el deslizador (aplica, guarda y refresca).
func poner_volumen(id: String, db: float) -> void:
	var i: int = _indice(id)
	if i < 0 or _filas[i]["deslizador"] == null:
		return
	(_filas[i]["deslizador"] as HSlider).value = clampf(db, VOL_MIN_DB, VOL_MAX_DB)


func _al_mover_deslizador(i: int, v: float) -> void:
	_aplicar_bus(String(FILAS[i]["bus"]), v)
	_refrescar()
	guardar_ajustes()


static func _aplicar_bus(bus: String, db: float) -> void:
	if bus == Sfx3D.BUS_MUNDO or bus == Sfx3D.BUS_OCLUIDO:
		Sfx3D._asegurar_buses()
	Sfx.fijar_volumen_bus(bus, db)


## --- Ajustes en disco ---

static func guardar_ajustes() -> bool:
	var c := ConfigFile.new()
	for d in FILAS:
		if String(d["tipo"]) == "volumen":
			c.set_value("volumen", String(d["id"]), volumen_bus_de(String(d["bus"])))
	c.set_value("sensacion", "activa", Sensacion3D.ACTIVA)
	return c.save(RUTA_AJUSTES) == OK


## Lee `RUTA_AJUSTES` y lo aplica (buses y Sensacion3D.ACTIVA). Sin archivo no toca nada. Devuelve true si había.
static func cargar_ajustes() -> bool:
	_cargado = true
	var c := ConfigFile.new()
	if c.load(RUTA_AJUSTES) != OK:
		return false
	for d in FILAS:
		if String(d["tipo"]) == "volumen" and c.has_section_key("volumen", String(d["id"])):
			_aplicar_bus(String(d["bus"]), clampf(float(c.get_value("volumen", String(d["id"]))), VOL_MIN_DB, VOL_MAX_DB))
	if c.has_section_key("sensacion", "activa"):
		Sensacion3D.ACTIVA = bool(c.get_value("sensacion", "activa"))
	return true


## --- Abrir y cerrar ---

func abrir() -> void:
	if abierta:
		return
	if not _puede_abrir():
		return
	abierta = true
	confirmando = ""
	fila = 0
	_refrescar()
	if is_inside_tree():
		get_tree().paused = true
		_pausado_por_mi = true
		Sfx.play_ui("libro_abre", DB_SONIDO)
	_animar(true)


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	confirmando = ""
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false
	_pausado_por_mi = false
	if is_inside_tree():
		Sfx.play_ui("libro_cierra", DB_SONIDO)
	_animar(false)


## Sin otra pantalla que ya pause, sin el libro abierto y sin el lanzador apuntando (ahí Escape cancela el apuntado).
func _puede_abrir() -> bool:
	if not is_inside_tree():
		return true
	if get_tree().paused:
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	if lanz != null:
		if lanz.has_method("libro_abierto") and bool(lanz.call("libro_abierto")):
			return false
		if bool(lanz.get("modo_lanzar")):
			return false
	return true


func _animar(abre: bool) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	if not Sensacion3D.ACTIVA or not is_inside_tree():
		_velo.visible = abre
		_velo.color.a = ALFA_FONDO if abre else 0.0
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP if abre else Control.MOUSE_FILTER_IGNORE
		_centro.visible = abre
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		return
	_panel.pivot_offset = _panel.size * 0.5
	if abre:
		_velo.visible = true
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_centro.visible = true
		_velo.color.a = 0.0
		_panel.modulate.a = 0.0
		_panel.scale = Vector2.ONE * ESCALA_CERRADO
	else:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw.tween_property(_panel, "scale", Vector2.ONE if abre else Vector2.ONE * ESCALA_CERRADO, T_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_panel, "modulate:a", 1.0 if abre else 0.0, T_S)
	_tw.tween_property(_velo, "color:a", ALFA_FONDO if abre else 0.0, T_S)
	if not abre:
		_tw.chain().tween_callback(_ocultar)


func _ocultar() -> void:
	if abierta:
		return
	_velo.visible = false
	_centro.visible = false
	_panel.modulate.a = 1.0
	_panel.scale = Vector2.ONE


## ¿Se ve el menú (aunque sea a medio fundido)?
func visible_ahora() -> bool:
	return _centro != null and _centro.visible


## ¿Está el tween de entrada o salida en marcha?
func animando() -> bool:
	return _tw != null and _tw.is_valid() and _tw.is_running()


## --- Elegir y actuar ---

func _elegir(i: int, sonar: bool = true) -> void:
	i = clampi(i, 0, FILAS.size() - 1)
	if i != fila:
		confirmando = ""
		fila = i
		if sonar and abierta:
			Sfx.play_ui("ui_tick")
	_refrescar()


func mover(dir: int) -> void:
	_elegir((fila + dir + FILAS.size()) % FILAS.size())


## ← → en un deslizador: ±PASO_DB. En una fila que no es deslizador: «no puedes». En el límite también.
func ajustar(dir: int) -> void:
	var d: Dictionary = FILAS[fila]
	if String(d["tipo"]) == "interruptor" and abierta:
		_alternar_sensacion()
		return
	if String(d["tipo"]) != "volumen":
		Sfx.play_ui("no_puedes")
		return
	var s: HSlider = _filas[fila]["deslizador"]
	var nuevo: float = clampf(s.value + float(dir) * PASO_DB, VOL_MIN_DB, VOL_MAX_DB)
	if is_equal_approx(nuevo, s.value):
		Sfx.play_ui("no_puedes")
		return
	s.value = nuevo
	Sfx.play_ui("ui_tick")


## Enter / clic: Continuar cierra, el interruptor se invierte, Reiniciar y Salir piden confirmación (un segundo Enter confirma), el deslizador no se acciona («no puedes»).
func accion() -> void:
	var d: Dictionary = FILAS[fila]
	match String(d["tipo"]):
		"boton":
			Sfx.play_ui("ui_equipar")
			cerrar()
		"interruptor":
			_alternar_sensacion()
		"volumen":
			Sfx.play_ui("no_puedes")
		"peligro":
			var id: String = String(d["id"])
			if confirmando != id:
				confirmando = id
				Sfx.play_ui("ui_tick")
				_refrescar()
				return
			Sfx.play_ui("ui_equipar")
			confirmando = ""
			if id == "reiniciar":
				_reiniciar()
			else:
				_salir()


func _alternar_sensacion() -> void:
	Sensacion3D.ACTIVA = not Sensacion3D.ACTIVA
	Sfx.play_ui("ui_equipar")
	guardar_ajustes()
	_refrescar()


func _reiniciar() -> void:
	reinicios += 1
	if not is_inside_tree():
		return
	var arbol: SceneTree = get_tree()
	abierta = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_velo.visible = false
	_centro.visible = false
	_pausado_por_mi = false
	arbol.paused = false
	arbol.reload_current_scene()


func _salir() -> void:
	if is_inside_tree():
		get_tree().quit()


## Escape con una confirmación pendiente la cancela; si no, cierra el menú.
func _escape() -> void:
	if confirmando != "":
		confirmando = ""
		Sfx.play_ui("ui_tick")
		_refrescar()
	else:
		cerrar()


## --- Dibujo de las filas ---

func _refrescar() -> void:
	if _filas.is_empty():
		return
	for i in range(FILAS.size()):
		var d: Dictionary = FILAS[i]
		var reg: Dictionary = _filas[i]
		var elegida: bool = i == fila
		var p: PanelContainer = reg["panel"]
		if elegida:
			var caja: StyleBoxFlat = TemaInterfaz.caja_panel(TemaInterfaz.FONDO_PANEL.lightened(0.14), TemaInterfaz.BORDE_CALIDO, 2)
			caja.shadow_size = 0
			p.add_theme_stylebox_override("panel", caja)
		else:
			var libre := StyleBoxFlat.new()
			libre.bg_color = Color(0, 0, 0, 0)
			libre.set_content_margin_all(TemaInterfaz.MARGEN_Y_PX)
			libre.content_margin_left = TemaInterfaz.MARGEN_X_PX
			libre.content_margin_right = TemaInterfaz.MARGEN_X_PX
			p.add_theme_stylebox_override("panel", libre)
		var et: Label = reg["etiqueta"]
		match String(d["tipo"]):
			"volumen":
				var s: HSlider = reg["deslizador"]
				var db: float = volumen_bus_de(String(d["bus"]))
				s.set_value_no_signal(clampf(db, VOL_MIN_DB, VOL_MAX_DB))
				(reg["valor"] as Label).text = "%+d dB" % int(round(db))
			"interruptor":
				(reg["valor"] as Label).text = "sí" if Sensacion3D.ACTIVA else "no"
			"peligro":
				et.text = ("¿Seguro? Enter confirma, Esc cancela" if confirmando == String(d["id"]) else String(d["texto"]))
				et.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if confirmando == String(d["id"]) else TemaInterfaz.TEXTO)


## --- Teclado ---

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if not abierta:
		if k.keycode == KEY_ESCAPE and _puede_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return
	match k.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_escape()
		KEY_UP:
			get_viewport().set_input_as_handled()
			mover(-1)
		KEY_DOWN:
			get_viewport().set_input_as_handled()
			mover(1)
		KEY_LEFT:
			get_viewport().set_input_as_handled()
			ajustar(-1)
		KEY_RIGHT:
			get_viewport().set_input_as_handled()
			ajustar(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			accion()
