extends SceneTree

## PRUEBA DEL LIBRO GUARDADO (libro avanzado, fase 2: L5 y L6 de docs/LIBRO_AVANZADO_2026-11-06.md; 6/11/2026). Sin ventana:
## `Godot --headless --path . --script res://herramientas/prueba_libro_guardado.gd`
##
## Comprueba:
##   1. `Repertoire.a_dic` / `desde_dic` (también tras pasar por JSON, que es lo que hace el archivo de partida) conservan libro, libro conseguido, derivados descubiertos y
##      las páginas con sus DOS sellos y los glifos en orden; `Partida.reunir` los lleva y `Partida.nueva` los olvida;
##   2. el Grimorio VUELCA sus páginas a `Repertoire.paginas` al cambiarlas y las LEE al arrancar (avanzado: corona por orden; «bosque»: sectores por `orden_huecos`);
##   3. `Repertoire.cambiar_libro("avanzado")` conserva las páginas, abre 4 huecos (+ los de Mejoras) y el Grimorio las rehace al oír la señal;
##   4. descubrir una runa derivada (poniendo dos sellos que reaccionan) la anota, la encola para que la mano la escriba y el libro la pone en su cola de escritura.
## NO comprueba el aspecto de la lámina (el color de la runa descubierta, el gris de las que faltan): sin ventana no hay dibujo que leer; se mira en LabLibroAvanzado.tscn.

var fallos: int = 0


func _init() -> void:
	Estado.nuevo()
	Partida.nueva()
	Repertoire.activate_all()
	Repertoire.max_pages = 0
	_dic_y_json()
	_partida()
	await _grimorio_avanzado()
	await _grimorio_bosque()
	await _cambio_de_libro()
	await _derivados()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


func _nuevo_grimorio() -> Grimorio:
	var g := Grimorio.new()
	root.add_child(g)
	await process_frame      # el _ready del Grimorio (crea las páginas y lee las guardadas) corre en el primer fotograma
	return g


## El glifo del hueco `i` de la corona de la página `p` ("" si está vacío).
func _glifo_corona(g: Grimorio, p: int, i: int) -> String:
	for c in (g.pages[p]["components"] as Array):
		if (c["direction"] as Vector2).is_equal_approx(Grimorio.dir_corona(i)) and not (c["sigils"] as Array).is_empty():
			return String((c["sigils"] as Array)[0])
	return ""


## --- 1. Repertoire ---
func _dic_y_json() -> void:
	Repertoire.libro = "avanzado"
	Repertoire.libro_conseguido = true
	Repertoire.derivados_descubiertos = ["hielo", "magma"] as Array[String]
	Repertoire.paginas = [{"elemento": "fuego", "elemento2": "tierra", "glifos": ["flecha", "barrera", "rebote"]}, {"elemento": "agua", "glifos": []}, {"elemento": "", "glifos": []}]
	var d: Dictionary = JSON.parse_string(JSON.stringify(Repertoire.a_dic()))      # lo que hace el archivo de partida
	Repertoire.libro = ""
	Repertoire.libro_conseguido = false
	Repertoire.derivados_descubiertos = [] as Array[String]
	Repertoire.paginas = []
	Repertoire.desde_dic(d)
	_ok(Repertoire.libro == "avanzado" and Repertoire.libro_conseguido, "guardar y cargar conserva el libro y que lo dio la aventura", "%s / %s" % [Repertoire.libro, Repertoire.libro_conseguido])
	_ok(Array(Repertoire.derivados_descubiertos) == ["hielo", "magma"], "y las runas derivadas descubiertas", str(Repertoire.derivados_descubiertos))
	_ok(Repertoire.paginas.size() == 3 and Repertoire.paginas[0] == {"elemento": "fuego", "elemento2": "tierra", "glifos": ["flecha", "barrera", "rebote"]}, "y la página 1 con sus dos sellos y el orden de los glifos", str(Repertoire.paginas[0]))
	_ok(Repertoire.paginas[1] == {"elemento": "agua", "glifos": []}, "una página de un solo sello no gana la clave elemento2", str(Repertoire.paginas[1]))
	# Una partida de antes de la fase 2 no trae libro ni derivados: se queda lo que había.
	Repertoire.libro = "bosque"
	Repertoire.desde_dic({"sellos": ["fuego"], "glifos": ["flecha"]})
	_ok(Repertoire.libro == "bosque" and Repertoire.derivados_descubiertos.size() == 2, "un guardado antiguo (sin libro ni derivados) no los borra")


## --- 1b. Partida ---
func _partida() -> void:
	Repertoire.libro = "avanzado"
	Repertoire.libro_conseguido = true
	Repertoire.derivados_descubiertos = ["rayo"] as Array[String]
	var dic: Dictionary = Partida.reunir(1)
	var gr: Dictionary = dic["grimorio"]
	_ok(gr.get("libro") == "avanzado" and gr.get("libro_conseguido") == true and gr.get("derivados") == ["rayo"], "Partida.reunir lleva libro, libro_conseguido y derivados en la sección grimorio", str(gr.keys()))
	Partida.nueva()
	_ok(Repertoire.libro == "" and not Repertoire.libro_conseguido and Repertoire.derivados_descubiertos.is_empty(), "Partida.nueva los olvida (una partida nueva no empieza con el libro avanzado)")
	Repertoire.activate_all()


## --- 2a. Grimorio: avanzado ---
func _grimorio_avanzado() -> void:
	Repertoire.libro = "avanzado"
	Repertoire.paginas = []
	Repertoire.max_sigils_per_page = 6
	var g: Grimorio = await _nuevo_grimorio()
	g.place_element("fuego")
	g.place_element("viento")
	g.add_sigil(Grimorio.dir_corona(0), "flecha")
	g.add_sigil(Grimorio.dir_corona(1), "rebote")
	g.add_sigil(Grimorio.dir_corona(2), "barrera")
	var p0: Dictionary = Repertoire.paginas[0]
	_ok(p0.get("elemento") == "fuego" and p0.get("elemento2") == "viento" and p0.get("glifos") == ["flecha", "rebote", "barrera"], "el Grimorio vuelca su página a Repertoire.paginas: dos sellos y glifos en orden de dibujo", str(p0))
	g.undo_last()
	_ok(Repertoire.paginas[0]["glifos"] == ["flecha", "rebote"], "deshacer también se vuelca", str(Repertoire.paginas[0]))
	g.select_page(1)
	g.place_element("agua")
	g.select_page(0)
	g.free()
	# Otro Grimorio (otro nivel, partida cargada) lee lo guardado.
	var h: Grimorio = await _nuevo_grimorio()
	_ok(h.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and h.pages[0]["element2"] == Runes.Type.SHAPE_LINES, "un Grimorio nuevo lee los dos sellos de su página 1")
	_ok(_glifo_corona(h, 0, 0) == "flecha" and _glifo_corona(h, 0, 1) == "rebote" and _glifo_corona(h, 0, 2) == "", "y los glifos en los huecos de la corona, por orden", "%s %s %s" % [_glifo_corona(h, 0, 0), _glifo_corona(h, 0, 1), _glifo_corona(h, 0, 2)])
	_ok(h.pages[1]["element"] == Runes.Type.SHAPE_CIRCLE and h.pages[2]["element"] == Runes.Type.NONE, "y las otras páginas por separado (agua en la 2, la 3 vacía)")
	_ok(String(h.resumen_pagina(0)["elemento"]) == "rayo", "el resumen de la página cargada ya sabe que fuego + viento es rayo", String(h.resumen_pagina(0)["elemento"]))
	h.free()


## --- 2b. Grimorio: «bosque» carga por sectores ---
func _grimorio_bosque() -> void:
	Repertoire.libro = "bosque"
	Repertoire.max_sigils_per_page = 3
	Repertoire.paginas = [{"elemento": "fuego", "elemento2": "agua", "glifos": ["flecha", "barrera", "rebote", "pulso"]}, {"elemento": "", "glifos": []}, {"elemento": "", "glifos": []}]
	var g: Grimorio = await _nuevo_grimorio()
	var spellbook_script: GDScript = load("res://presentacion/ui/spellbook.gd")
	var orden_lamina: Array = (spellbook_script.LIBROS["bosque"] as Dictionary)["orden_huecos"]
	_ok(Grimorio.ORDEN_HUECOS_LIBRO["bosque"] == orden_lamina, "el orden de huecos del Grimorio es el `orden_huecos` de la lámina bosque (no se separan)", str(orden_lamina))
	_ok(g.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and g.pages[0]["element2"] == Runes.Type.NONE, "en «bosque» solo cuenta el sello 1 (elemento2 se ignora)")
	var comps: Array = g.pages[0]["components"]
	var angulos: Array = []
	for c in comps:
		angulos.append(snappedf(rad_to_deg((c["direction"] as Vector2).angle()), 1.0))
	_ok(comps.size() == 3 and angulos == [90.0, 135.0, 45.0], "«bosque»: los glifos van a los huecos abiertos por orden (sectores 2, 3, 1) y el cuarto, que no cabe, se queda fuera", str(angulos))
	_ok((comps[0]["sigils"] as Array)[0] == "flecha" and (comps[1]["sigils"] as Array)[0] == "barrera" and (comps[2]["sigils"] as Array)[0] == "rebote", "con el glifo que toca en cada uno")
	g.free()


## --- 3. Cambio de libro ---
func _cambio_de_libro() -> void:
	Estado.nuevo()
	Repertoire.libro = "bosque"
	Repertoire.libro_conseguido = false
	Repertoire.max_sigils_per_page = 1
	Repertoire.paginas = [{"elemento": "fuego", "glifos": ["flecha", "barrera"]}, {"elemento": "agua", "glifos": ["rebote"]}, {"elemento": "", "glifos": []}]
	var g: Grimorio = await _nuevo_grimorio()
	var extra: int = int(Mejoras.valor("huecos_glifo", Estado.i()))
	Repertoire.cambiar_libro("avanzado")
	_ok(Repertoire.libro == "avanzado" and Repertoire.libro_conseguido, "cambiar_libro fija el libro y marca libro_conseguido")
	_ok(Repertoire.max_sigils_per_page == 4 + extra, "el avanzado abre 4 huecos de base (+ %d de Mejoras)" % extra, str(Repertoire.max_sigils_per_page))
	_ok(g.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and _glifo_corona(g, 0, 0) == "flecha" and _glifo_corona(g, 0, 1) == "barrera", "el Grimorio se entera por la señal y rehace la página 1: fuego en el sello 1, los glifos en la corona")
	_ok(g.pages[1]["element"] == Runes.Type.SHAPE_CIRCLE and _glifo_corona(g, 1, 0) == "rebote", "y la página 2 (agua, rebote)")
	_ok(Repertoire.paginas[0]["glifos"] == ["flecha", "barrera"], "y lo guardado sigue igual")
	# Con mejoras ganadas se suman encima sin pisar, y repetir el cambio no las suma dos veces.
	Estado.i().mejoras = {"huecos_glifo": 2}
	var con_mejora: int = int(Mejoras.valor("huecos_glifo", Estado.i()))
	Repertoire.cambiar_libro("avanzado")
	_ok(Repertoire.max_sigils_per_page == 4 + con_mejora, "con huecos ganados (+%d) se suman a la base" % con_mejora, str(Repertoire.max_sigils_per_page))
	Repertoire.cambiar_libro("avanzado")
	_ok(Repertoire.max_sigils_per_page == 4 + con_mejora, "y cambiar otra vez no los suma dos veces", str(Repertoire.max_sigils_per_page))
	Repertoire.cambiar_libro("bosque")
	_ok(Repertoire.max_sigils_per_page == 1 + con_mejora, "volver a «bosque» deja su base (1) más lo ganado", str(Repertoire.max_sigils_per_page))
	g.free()
	Repertoire.cambiar_libro("avanzado")       # sin Grimorio vivo: la señal ya no apunta a un nodo liberado
	_ok(true, "cambiar de libro con el Grimorio liberado no falla (la señal se soltó)")
	Estado.nuevo()


## --- 4. Runas derivadas ---
func _derivados() -> void:
	Repertoire.libro = "avanzado"
	Repertoire.derivados_descubiertos = [] as Array[String]
	Repertoire.tomar_por_escribir()
	Repertoire.paginas = []
	var g: Grimorio = await _nuevo_grimorio()
	g.place_element("fuego")
	_ok(not Repertoire.derivado_descubierto("magma"), "con un solo sello no se descubre nada")
	g.place_element("tierra")
	_ok(Repertoire.derivado_descubierto("magma") and Repertoire.derivados_descubiertos.size() == 1, "fuego + tierra descubre el magma", str(Repertoire.derivados_descubiertos))
	g.clear_sequence()
	g.place_element("fuego")
	g.place_element("agua")
	_ok(Repertoire.derivados_descubiertos.size() == 1, "fuego + agua (se anulan) no descubre nada")
	g.place_element("viento")        # fuego + agua, el viento sustituye al más antiguo (fuego): agua + viento = hielo
	_ok(Repertoire.derivado_descubierto("hielo") and Repertoire.derivados_descubiertos.size() == 2, "agua + viento descubre el hielo", str(Repertoire.derivados_descubiertos))
	_ok(not Repertoire.descubrir_derivado("magma"), "descubrir otra vez uno ya descubierto devuelve false")
	var cola: PackedStringArray = Repertoire.tomar_por_escribir()
	_ok(cola == PackedStringArray(["derivado:magma", "derivado:hielo"]), "los dos quedan en la cola de la mano, una vez cada uno", str(cola))
	_ok(Repertoire.tomar_por_escribir().is_empty(), "y tomarlos vacía la cola")
	# El libro los recoge y los pone a escribirse.
	Repertoire.derivados_descubiertos = [] as Array[String]
	Repertoire.descubrir_derivado("barro")
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	_ok(libro._empezar_escrituras() == 1 and libro._escribiendo.has("derivado:barro"), "Spellbook._empezar_escrituras pone el derivado en su cola de escritura", str(libro._escribiendo))
	libro.free()
	g.free()
	Repertoire.libro = ""


func _ok(bien: bool, nombre: String, info: String = "") -> void:
	print(("  OK    " if bien else "  FALLO ") + nombre + ("" if info == "" else "  [" + info + "]"))
	if not bien:
		fallos += 1
