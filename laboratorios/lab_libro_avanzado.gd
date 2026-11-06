extends Node

## LABORATORIO DEL LIBRO AVANZADO (6/11/2026, Juego): el libro de DOS SELLOS y DOS ZONAS DE DIBUJO, suelto, sin jugadora, sin mundo y sin cámara lenta.
## Abrir: `laboratorios/LabLibroAvanzado.tscn` (F6 en el editor, o `Godot --path . res://laboratorios/LabLibroAvanzado.tscn`).
##
## Se dibuja con el ratón en los dos círculos de ABAJO: el de la izquierda es de SELLOS (elementos) y el de la derecha de GLIFOS. Lo reconocido se coloca solo en el
## círculo mágico de ARRIBA: un sello en el medallón 1 o 2 (el tercero sustituye al más antiguo) y un glifo en el primer hueco libre de la corona.
## Fuego + agua y tierra + viento se anulan; agua + viento = hielo, fuego + viento = rayo, fuego + tierra = magma, agua + tierra = naturaleza (veneno).
## Las medidas de todo (círculo mágico, medallones, huecos, zonas) están en `LIBROS["avanzado"]` de `presentacion/ui/spellbook.gd`: se ajustan ahí y se vuelve a abrir.
##
## Sin lanzador del juego: la página es la de un `Grimorio` pelado (no lanza nada ni gasta tinta); el resumen de arriba sale de él. Para probar el LANZAMIENTO (que los
## opuestos no lancen, que magma salga de fuego + tierra) está `herramientas/prueba_libro_avanzado.gd`.

const AYUDA: String = "LIBRO AVANZADO · dibuja en los círculos de abajo: SELLO a la izquierda, GLIFO a la derecha · clic derecho o Z deshacen · Retroceso vacía la página · 1 2 3 cambian de página"

var _grimorio: Grimorio = null
var _libro: Control = null
var _texto: Label = null


func _ready() -> void:
	Estado.nuevo()
	Repertoire.libro = "avanzado"
	Repertoire.activate_all()
	Repertoire.max_pages = 0
	Repertoire.max_sigils_per_page = 6
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Engine.time_scale = 1.0

	_grimorio = Grimorio.new()
	add_child(_grimorio)

	var capa := CanvasLayer.new()
	add_child(capa)
	_libro = Control.new()
	_libro.process_mode = Node.PROCESS_MODE_ALWAYS
	_libro.set_script(load("res://presentacion/ui/spellbook.gd"))
	capa.add_child(_libro)
	_libro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_libro.is_open = true
	_libro.visible = true

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 15)
	_texto.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_texto.add_theme_constant_override("outline_size", 5)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_texto)
	_texto.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_texto.offset_left = 12.0
	_texto.offset_top = 6.0
	_texto.offset_right = -12.0
	_texto.offset_bottom = 60.0


func _process(_delta: float) -> void:
	# La tecla del libro lo cerraría (y despausaría): en este laboratorio siempre está abierto.
	if not _libro.is_open:
		_libro.is_open = true
		_libro.visible = true
		_libro.modulate.a = 1.0
		_libro.scale = Vector2.ONE
	if get_tree().paused:
		get_tree().paused = false
	_texto.text = "%s\n%s" % [AYUDA, _estado()]


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z:
		_grimorio.undo_last()
		_libro.queue_redraw()


## Lo que dice la página activa ahora mismo: los dos sellos, qué sale de la pareja y el resumen del libro.
func _estado() -> String:
	var ficha: Dictionary = _grimorio.pages[_grimorio.page]
	var par: Dictionary = CombosSellos.de_ficha(ficha)
	var sellos: String = "sin sellos"
	if int(ficha["element"]) != Runes.Type.NONE:
		sellos = "sello 1: %s" % _grimorio.rune_database[ficha["element"]].display_name
		if int(ficha["element2"]) != Runes.Type.NONE:
			sellos += " · sello 2: %s" % _grimorio.rune_database[ficha["element2"]].display_name
	var r: Dictionary = _grimorio.resumen_pagina()
	var titulo: String = String(r.get("titulo", ""))
	var reaccion: String = ""
	match String(par["estado"]):
		CombosSellos.REACCION:
			reaccion = "reacción → %s" % titulo
		CombosSellos.SE_ANULAN:
			reaccion = "SE ANULAN"
		CombosSellos.SIN_REACCION:
			reaccion = "sin reacción (se lanzaría el sello 1)"
	return "Página %d · %s%s · glifos %d/6" % [_grimorio.page + 1, sellos, "" if reaccion == "" else " · " + reaccion, _grimorio.sigils_used()]
