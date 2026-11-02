class_name MenuPrincipal
extends Control

## EL MENÚ PRINCIPAL (2/11, gamefeel tercera tanda A1). Es la `run/main_scene`: fondo de degradado del tema, el título y cinco opciones navegables con flechas, Enter, Escape y ratón:
##   · Continuar   solo si hay partida: carga la ranura más reciente entre la 1 y la «auto» (`Partida.ranura_mas_reciente`)
##   · Nueva partida   con una partida guardada pide confirmación (Enter otra vez) y borra la ranura 1 y la «auto»; deja todo a cero (`Partida.nueva`) y entra en `Niveles.NIVEL_INICIAL`
##   · Cargar   lista las ranuras que existen con su mapa y el tiempo jugado; Enter carga, Supr borra (con confirmación), Escape vuelve
##   · Ajustes   abre `MenuPausa` en modo `sin_partida` (volúmenes y sensación; sin Reiniciar ni Salir al menú)
##   · Salir
## Entra con fundido y escala 0,96 → 1 en `T_S` s como la pausa. `Sensacion3D.ACTIVA = false` aparece de golpe (los sonidos quedan: `ui_tick` al moverse, `ui_equipar` al aceptar, `no_puedes` al rechazar).
## Qué escena era la principal antes: `PruebaBosque01_v01.tscn`, que sigue siendo la de «Nueva partida» (`Niveles.ESCENAS["Bosque_01_v01"]`).
## Para las pruebas: `CAMBIAR_ESCENA = false` no cambia de escena ni cierra el juego (apunta en `destino`, `salio`); `modo`, `fila`, `confirmando`, `ids()`, `texto_fila(i)`, `mover(dir)`, `accion()`,
## `borrar_elegida()`, `escape()`, `ajustes`.

static var T_S: float = 0.15
static var ESCALA_CERRADO: float = 0.96
static var CAMBIAR_ESCENA: bool = true
static var DB_SONIDO: float = INF

const MODO_PRINCIPAL: String = "principal"
const MODO_CARGAR: String = "cargar"
const MODO_AJUSTES: String = "ajustes"
const TXT_VACIO: String = "No hay partidas guardadas"

var modo: String = MODO_PRINCIPAL
var fila: int = 0
var confirmando: String = ""                 ## «nueva» o «borrar» mientras espera el segundo Enter; "" si no
var destino: String = ""                     ## la escena a la que se iba a ir (con CAMBIAR_ESCENA = false)
var salio: bool = false
var ajustes: MenuPausa = null
var _items: Array = []                       ## [{id, texto, ranura?}]
var _paneles: Array = []
var _etiquetas: Array = []
var _caja: VBoxContainer
var _panel: PanelContainer
var _centro: CenterContainer
var _tw: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not MenuPausa._cargado:
		MenuPausa.cargar_ajustes()                # los volúmenes y la sensación guardados valen ya desde el menú
	_fondo()
	_centro = CenterContainer.new()
	_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centro.theme = TemaInterfaz.tema()
	add_child(_centro)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480.0, 0.0)
	_centro.add_child(_panel)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 8)
	_panel.add_child(_caja)
	_construir()
	_entrada()


func _exit_tree() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()


## El degradado del tema (oscuro, con un toque cálido abajo) y el título grande encima.
func _fondo() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.025, 0.07))
	g.set_color(1, Color(0.16, 0.09, 0.07))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	var fondo := TextureRect.new()
	fondo.name = "Fondo"
	fondo.texture = gt
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "Magic Symbols"
	titulo.theme = TemaInterfaz.tema()
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", TemaInterfaz.BORDE_CALIDO)
	titulo.add_theme_color_override("font_outline_color", TemaInterfaz.CONTORNO)
	titulo.add_theme_constant_override("outline_size", 10)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titulo.anchor_left = 0.0
	titulo.anchor_right = 1.0
	titulo.offset_left = 0.0
	titulo.offset_right = 0.0
	titulo.offset_top = 56.0
	titulo.offset_bottom = 150.0
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titulo)


# ---------------------------------------------------------------------------------------------------------------------
#  Filas
# ---------------------------------------------------------------------------------------------------------------------

func _items_principal() -> Array:
	var r: Array = []
	if Partida.ranura_mas_reciente() >= 0:
		r.append({"id": "continuar", "texto": "Continuar"})
	r.append({"id": "nueva", "texto": "Nueva partida"})
	r.append({"id": "cargar", "texto": "Cargar"})
	r.append({"id": "ajustes", "texto": "Ajustes"})
	r.append({"id": "salir", "texto": "Salir"})
	return r


func _items_cargar() -> Array:
	var r: Array = []
	for s in Partida.resumen_ranuras():
		var nombre: String = "Auto" if int(s["ranura"]) == Partida.RANURA_AUTO else "Ranura %d" % int(s["ranura"])
		var mapa: String = String(s["mapa"]).replace("_", " ") if String(s["mapa"]) != "" else "—"
		r.append({"id": "slot", "ranura": int(s["ranura"]), "texto": "%s  ·  %s  ·  %s" % [nombre, mapa, Estadisticas.texto_tiempo(float(s["segundos"]))]})
	if r.is_empty():
		r.append({"id": "vacio", "texto": TXT_VACIO})
	r.append({"id": "volver", "texto": "Volver"})
	return r


## Vuelve a dibujar la lista de filas del modo de ahora.
func _construir() -> void:
	for p in _paneles:
		_caja.remove_child(p)
		(p as Node).queue_free()
	_paneles.clear()
	_etiquetas.clear()
	_items = _items_cargar() if modo == MODO_CARGAR else _items_principal()
	fila = clampi(fila, 0, _items.size() - 1)
	for i in range(_items.size()):
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var et := Label.new()
		et.text = String(_items[i]["texto"])
		et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		et.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(et)
		p.mouse_entered.connect(func() -> void: _elegir(i))
		p.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_elegir(i, false)
				accion())
		_caja.add_child(p)
		_paneles.append(p)
		_etiquetas.append(et)
	_pie()
	_refrescar()


func _pie() -> void:
	var viejo: Node = _caja.get_node_or_null("Pie")
	if viejo != null:
		_caja.remove_child(viejo)
		viejo.queue_free()
	var pie := Label.new()
	pie.name = "Pie"
	pie.text = "[↑↓] elegir   [Enter] aceptar" + ("   [Supr] borrar   [Esc] volver" if modo == MODO_CARGAR else "")
	pie.add_theme_font_size_override("font_size", TemaInterfaz.TAM_FUENTE_PEQUENO)
	pie.add_theme_color_override("font_color", TemaInterfaz.TEXTO_SUAVE)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caja.add_child(pie)


func _refrescar() -> void:
	for i in range(_paneles.size()):
		var p: PanelContainer = _paneles[i]
		if i == fila:
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
		var et: Label = _etiquetas[i]
		var id: String = String(_items[i]["id"])
		var pregunta: bool = (id == "nueva" and confirmando == "nueva") or (id == "slot" and confirmando == "borrar" and i == fila)
		if pregunta:
			et.text = "¿Seguro? Enter confirma, Esc cancela" if id == "nueva" else "¿Borrar? Supr o Enter confirma, Esc cancela"
		else:
			et.text = String(_items[i]["texto"])
		et.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if pregunta else TemaInterfaz.TEXTO)


# ---------------------------------------------------------------------------------------------------------------------
#  Datos para las pruebas
# ---------------------------------------------------------------------------------------------------------------------

## Las ids de las filas de ahora, en orden («continuar», «nueva», «cargar», «ajustes», «salir»; o «slot»/«vacio» y «volver»).
func ids() -> Array:
	var r: Array = []
	for it in _items:
		r.append(String(it["id"]))
	return r


func texto_fila(i: int) -> String:
	return String(_items[i]["texto"]) if i >= 0 and i < _items.size() else ""


func id_elegida() -> String:
	return String(_items[fila]["id"]) if fila < _items.size() else ""


## Las ranuras que lista «Cargar» (números), en orden.
func ranuras_listadas() -> Array:
	var r: Array = []
	for it in _items:
		if String(it["id"]) == "slot":
			r.append(int(it["ranura"]))
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  Entrada animada
# ---------------------------------------------------------------------------------------------------------------------

func _entrada() -> void:
	if not Sensacion3D.ACTIVA or not is_inside_tree():
		return
	_panel.pivot_offset = Vector2(240.0, 120.0)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ESCALA_CERRADO
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw.tween_property(_panel, "modulate:a", 1.0, T_S)
	_tw.tween_property(_panel, "scale", Vector2.ONE, T_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func animando() -> bool:
	return _tw != null and _tw.is_valid() and _tw.is_running()


# ---------------------------------------------------------------------------------------------------------------------
#  Elegir y actuar
# ---------------------------------------------------------------------------------------------------------------------

func _elegir(i: int, sonar: bool = true) -> void:
	i = clampi(i, 0, maxi(_items.size() - 1, 0))
	if i != fila:
		confirmando = ""
		fila = i
		if sonar:
			Sfx.play_ui("ui_tick", DB_SONIDO)
	_refrescar()


func mover(dir: int) -> void:
	if _items.is_empty() or (ajustes != null and ajustes.abierta):
		return
	_elegir((fila + dir + _items.size()) % _items.size())


func accion() -> void:
	if _items.is_empty() or (ajustes != null and ajustes.abierta):
		return
	var id: String = id_elegida()
	match id:
		"continuar":
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_continuar()
		"nueva":
			if (Partida.existe(1) or Partida.existe(Partida.RANURA_AUTO)) and confirmando != "nueva":
				confirmando = "nueva"
				Sfx.play_ui("ui_tick", DB_SONIDO)
				_refrescar()
				return
			confirmando = ""
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_nueva_partida()
		"cargar":
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_cambiar_modo(MODO_CARGAR)
		"ajustes":
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_abrir_ajustes()
		"salir":
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			salio = true
			if CAMBIAR_ESCENA and is_inside_tree():
				get_tree().quit()
		"slot":
			if confirmando == "borrar":
				_borrar_confirmado()
				return
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_cargar_ranura(int(_items[fila]["ranura"]))
		"vacio":
			Sfx.play_ui("no_puedes", DB_SONIDO)
		"volver":
			Sfx.play_ui("ui_equipar", DB_SONIDO)
			_cambiar_modo(MODO_PRINCIPAL)


## Supr en «Cargar»: la primera vez pide confirmación; la segunda (Supr o Enter) borra la ranura. Fuera de una ranura, «no puedes».
func borrar_elegida() -> void:
	if modo != MODO_CARGAR or id_elegida() != "slot":
		Sfx.play_ui("no_puedes", DB_SONIDO)
		return
	if confirmando != "borrar":
		confirmando = "borrar"
		Sfx.play_ui("ui_tick", DB_SONIDO)
		_refrescar()
		return
	_borrar_confirmado()


func _borrar_confirmado() -> void:
	var n: int = int(_items[fila]["ranura"])
	confirmando = ""
	Partida.borrar(n)
	Sfx.play_ui("ui_equipar", DB_SONIDO)
	_construir()


## Escape: cancela una confirmación; en «Cargar» vuelve a lo principal; en lo principal no hace nada.
func escape() -> void:
	if ajustes != null and ajustes.abierta:
		return
	if confirmando != "":
		confirmando = ""
		Sfx.play_ui("ui_tick", DB_SONIDO)
		_refrescar()
	elif modo == MODO_CARGAR:
		Sfx.play_ui("ui_tick", DB_SONIDO)
		_cambiar_modo(MODO_PRINCIPAL)


func _cambiar_modo(m: String) -> void:
	var antes: String = modo
	modo = m
	confirmando = ""
	fila = 0
	if m == MODO_PRINCIPAL and antes == MODO_CARGAR:
		var its: Array = _items_principal()
		for i in range(its.size()):
			if String(its[i]["id"]) == "cargar":      # vuelve a quedar sobre «Cargar»
				fila = i
	_construir()


func _abrir_ajustes() -> void:
	if ajustes != null and is_instance_valid(ajustes):
		ajustes.free()
	ajustes = MenuPausa.new()
	ajustes.sin_partida = true
	ajustes.cerrada.connect(_al_cerrar_ajustes)
	add_child(ajustes)
	modo = MODO_AJUSTES
	ajustes.abrir()


func _al_cerrar_ajustes() -> void:
	modo = MODO_PRINCIPAL
	# El menú de ajustes se libera cuando acaba su tween de salida, no aquí (acaba de emitir).
	var viejo: MenuPausa = ajustes
	ajustes = null
	if is_inside_tree():
		get_tree().create_timer(MenuPausa.T_S + 0.05, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(viejo):
				viejo.queue_free())
	else:
		viejo.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que hace cada opción
# ---------------------------------------------------------------------------------------------------------------------

func _continuar() -> void:
	var r: int = Partida.ranura_mas_reciente()
	if r < 0:
		Sfx.play_ui("no_puedes", DB_SONIDO)
		return
	_cargar_ranura(r)


## Pone todo a cero, avisa de qué ranura cargar y entra en el nivel donde estaba la jugadora (o en el inicial si el archivo no lo dice o ese nivel no existe).
func _cargar_ranura(n: int) -> void:
	var d: Dictionary = Partida.leer(n)
	if d.is_empty():
		Sfx.play_ui("no_puedes", DB_SONIDO)
		return
	var mapa: String = Niveles.nivel_de(String((d.get("jugadora", {}) as Dictionary).get("mapa_actual", "")))
	var escena: String = Niveles.escena_de(mapa) if Niveles.existe(mapa) else Niveles.escena_de(Niveles.NIVEL_INICIAL)
	Partida.nueva()
	Partida.ranura_actual = 1                     # los puntos de guardado siguen escribiendo en la ranura 1
	Partida.preparar_carga(n)
	_ir_a(escena)


func _nueva_partida() -> void:
	Partida.borrar(1)
	Partida.borrar(Partida.RANURA_AUTO)
	Partida.nueva()
	Partida.ranura_actual = 1
	_ir_a(Niveles.escena_de(Niveles.NIVEL_INICIAL))


func _ir_a(escena: String) -> void:
	destino = escena
	if CAMBIAR_ESCENA and is_inside_tree():
		get_tree().change_scene_to_file(escena)


# ---------------------------------------------------------------------------------------------------------------------
#  Teclado
# ---------------------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if ajustes != null and is_instance_valid(ajustes) and ajustes.abierta:
		return
	match k.keycode:
		KEY_UP:
			get_viewport().set_input_as_handled()
			mover(-1)
		KEY_DOWN:
			get_viewport().set_input_as_handled()
			mover(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			accion()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			escape()
		KEY_DELETE:
			get_viewport().set_input_as_handled()
			borrar_elegida()
