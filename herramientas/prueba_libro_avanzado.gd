extends SceneTree

## PRUEBA DEL LIBRO AVANZADO: DOS SELLOS Y DOS ZONAS DE DIBUJO (6/11/2026, Juego). Sin ventana: `tools\prueba_una.cmd prueba_libro_avanzado`.
##
## Comprueba lo que se pidió (docs/LIBRO_AVANZADO_2026-11-06.md, Pablo 6/11) con trazos de verdad dibujados por las funciones del libro y del Grimorio:
##   1. dónde dibujas decide qué es: un punto en la zona de sellos es un sello, en la de glifos un glifo, y fuera de las dos se descarta;
##   2. dos sellos por página (el 3.º sustituye al más antiguo, deshacer y vaciar lo respetan);
##   3. la tabla de parejas (`CombosSellos`), las seis, en los dos órdenes, y una pareja fuera de la tabla;
##   4. los glifos dibujados en su zona caen en el primer hueco libre de la corona, por orden;
##   5. al lanzar: la pareja se resuelve antes de construir el hechizo (magma), los opuestos no lanzan ni cobran tinta, un sello solo sigue igual;
##   6. el resumen de la página dice el derivado o «Se anulan»;
##   7. el libro «bosque» de siempre no se entera de nada de esto.
## No comprueba el aspecto (el vuelo de la runa, el dibujo de la corona): eso se mira en `laboratorios/LabLibroAvanzado.tscn`.

var fallos: int = 0
const PASO_PX: float = 4.0


func _init() -> void:
	Estado.nuevo()
	root.size = Vector2i(1280, 720)
	# El Lanzador3D, al montarse, aplica la progresión del nivel y pisa Repertoire.libro: se monta ANTES de elegir el libro.
	var l := Lanzador3D.new()
	root.add_child(l)
	await process_frame
	Repertoire.activate_all()
	Repertoire.max_pages = 0
	Repertoire.max_sigils_per_page = 6
	Repertoire.libro = "avanzado"
	l.tinta = Tinta.new()
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	libro.visible = true
	_ok(not libro._libro().is_empty() and libro._avanzado(), "el libro avanzado se carga y está activo (Repertoire.libro = «avanzado»)")
	if not libro._avanzado():
		print("FALLOS: ", fallos)
		quit(1)
		return

	_zonas(libro)
	_sellos(l)
	_tabla()
	_glifos(l, libro)
	await _lanzar(l)
	_resumen(l)
	_bosque_igual(l)

	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


## --- 1. ZONAS ---
func _zonas(libro: Control) -> void:
	var av: Dictionary = libro._av()
	var c_sello: Vector2 = av["zona_sellos"]["centro"]
	var c_glifo: Vector2 = av["zona_glifos"]["centro"]
	var r_sello: float = float(av["zona_sellos"]["radio"])
	var s_sello: Vector2 = libro._sector_of_point(libro._on_page(c_sello))
	_ok(s_sello == Vector2.ZERO, "un punto en el centro de la zona de sellos es un sello (sector cero)", str(s_sello))
	var s_glifo: Vector2 = libro._sector_of_point(libro._on_page(c_glifo))
	_ok(s_glifo != Vector2.ZERO and s_glifo != libro.SIN_HUECO, "un punto en el centro de la zona de glifos es un glifo (va a un hueco de la corona)", str(s_glifo))
	_ok(s_glifo.is_equal_approx(Grimorio.dir_corona(0)), "y, con la página vacía, al primer hueco de la corona")
	_ok(libro._sector_of_point(libro._on_page(av["circulo"]["centro"])) == libro.SIN_HUECO, "un punto en el círculo mágico de arriba (aquí no se dibuja) se descarta")
	_ok(libro._sector_of_point(libro._on_page(Vector2(60.0, 60.0))) == libro.SIN_HUECO, "un punto fuera de las dos zonas se descarta")
	_ok(libro._zona_de(libro._on_page(c_sello + Vector2(r_sello * 0.97, 0.0))) == "sello" and libro._zona_de(libro._on_page(c_sello + Vector2(r_sello * 1.05, 0.0))) == "", "el borde de la zona es el círculo: 3 % por dentro vale, 5 % por fuera no")
	# Un trazo solo nace dentro de una zona, y salirse de ella lo corta.
	libro._begin_stroke(libro._on_page(Vector2(60.0, 60.0)))
	_ok(not libro.is_drawing, "un trazo que nace fuera de las dos zonas no empieza")
	libro._begin_stroke(libro._on_page(c_sello))
	_ok(libro.is_drawing, "uno que nace en la zona de sellos sí")
	libro._add_point(libro._on_page(c_glifo))
	_ok(not libro.is_drawing, "y se corta al salir de su zona (aunque entre en la otra)")
	libro.pending_strokes = []
	libro.stroke = PackedVector2Array()
	libro._begin_stroke(libro._on_page(c_glifo))
	_ok(libro.is_drawing and libro._av_zona_gesto == "glifo", "uno que nace en la zona de glifos queda marcado como de glifos")
	libro._end_stroke()
	libro.pending_strokes = []
	# El método de pruebas de la paleta (F1): los 6 huecos de la corona.
	_ok(libro.restringe_huecos() and libro.sectores_abiertos().size() == 6, "la paleta de pruebas ve los 6 huecos de la corona")


## --- 2. DOS SELLOS POR PÁGINA ---
func _sellos(l: Lanzador3D) -> void:
	l.clear_sequence()
	l.add_gesture(_dibujar(String(TrazosRectos.ELEMENTOS["fuego"])), Vector2.ZERO)
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and l.pages[0]["element2"] == Runes.Type.NONE, "el primer sello dibujado (fuego) va al medallón 1")
	l.add_gesture(_dibujar(String(TrazosRectos.ELEMENTOS["agua"])), Vector2.ZERO)
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and l.pages[0]["element2"] == Runes.Type.SHAPE_CIRCLE, "el segundo (agua) va al medallón 2 y el 1 no se toca", "%s / %s" % [l.pages[0]["element"], l.pages[0]["element2"]])
	l.place_element("tierra")
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_ARC and l.pages[0]["element2"] == Runes.Type.SHAPE_CIRCLE, "el tercero (tierra) sustituye al MÁS ANTIGUO (fuego): tierra + agua")
	l.place_element("viento")
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_ARC and l.pages[0]["element2"] == Runes.Type.SHAPE_LINES, "el cuarto (viento) sustituye ahora al agua, que es el más viejo: tierra + viento")
	l.undo_last()
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_ARC and l.pages[0]["element2"] == Runes.Type.SHAPE_CIRCLE, "deshacer el cuarto devuelve tierra + agua")
	l.undo_last()
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and l.pages[0]["element2"] == Runes.Type.SHAPE_CIRCLE, "deshacer el tercero devuelve fuego + agua (el medallón 1 recupera el fuego)")
	l.undo_last()
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE and l.pages[0]["element2"] == Runes.Type.NONE, "deshacer el segundo deja solo el fuego")
	l.undo_last()
	_ok(l.pages[0]["element"] == Runes.Type.NONE and l.pages[0]["element2"] == Runes.Type.NONE, "y el primero deja la página sin sellos")
	l.place_element("fuego")
	l.place_element("agua")
	l.place_element("tierra")
	l.clear_sequence()
	_ok(l.pages[0]["element"] == Runes.Type.NONE and l.pages[0]["element2"] == Runes.Type.NONE and int(l.pages[0]["element_viejo"]) == 1, "clear_sequence vacía los dos medallones (y olvida cuál era el más viejo)")
	# El orden no importa para el resultado: fuego + tierra y tierra + fuego dan el mismo derivado.
	l.place_element("fuego")
	l.place_element("tierra")
	var a: String = String(CombosSellos.de_ficha(l.pages[0])["id"])
	l.clear_sequence()
	l.place_element("tierra")
	l.place_element("fuego")
	var b: String = String(CombosSellos.de_ficha(l.pages[0])["id"])
	_ok(a == "magma" and a == b, "el orden de los sellos no importa: fuego+tierra y tierra+fuego dan lo mismo", "%s / %s" % [a, b])
	# Otra página no se toca.
	l.clear_sequence()
	l.select_page(1)
	l.place_element("viento")
	l.select_page(0)
	_ok(l.pages[0]["element"] == Runes.Type.NONE and l.pages[1]["element"] == Runes.Type.SHAPE_LINES, "los medallones son de cada página")
	l.select_page(1)
	l.clear_sequence()
	l.select_page(0)


## --- 3. LA TABLA ---
func _tabla() -> void:
	var esperado: Dictionary = {["fuego", "agua"]: "anulan", ["tierra", "viento"]: "anulan", ["agua", "viento"]: "hielo",
		["fuego", "viento"]: "rayo", ["fuego", "tierra"]: "magma", ["agua", "tierra"]: "naturaleza"}
	for par in esperado:
		var directo: String = CombosSellos.resolver(par[0], par[1])
		var inverso: String = CombosSellos.resolver(par[1], par[0])
		_ok(directo == esperado[par] and inverso == esperado[par], "%s + %s = %s (y al revés)" % [par[0], par[1], esperado[par]], "%s / %s" % [directo, inverso])
	_ok(CombosSellos.resolver("hielo", "fuego") == "" and CombosSellos.resolver("rayo", "agua") == "" and CombosSellos.resolver("fuego", "fuego") == "", "una pareja fuera de la tabla (con hielo, con rayo, dos iguales) da «»")
	for id in ["hielo", "rayo", "magma", "naturaleza"]:
		var r: RuneData = CombosSellos.runa_de(id)
		_ok(r != null and Objetos.elemento_de(r) == id, "el derivado «%s» tiene su runa y se reconoce como %s" % [id, id], str(Objetos.elemento_de(r)) if r != null else "sin runa")
	var magma: RuneData = CombosSellos.runa_de("magma")
	var natura: RuneData = CombosSellos.runa_de("naturaleza")
	_ok(magma.estado == "plasma" and magma.tags.has("fuego") and magma.tags.has("tierra") and magma.tags.has("magma"), "magma: plasma, con las etiquetas fuego, tierra y magma")
	_ok(natura.estado == "liquido" and natura.tags.has("agua") and natura.tags.has("tierra") and natura.tags.has("naturaleza") and natura.modificadores.has("veneno") and natura.modificadores.has("veneno_dps"), "naturaleza: líquido, con las etiquetas agua, tierra y naturaleza, y envenena (reusa Hechizo.veneno)")
	_ok(magma.rune_type == Runes.Type.ELEMENT_MAGMA and natura.rune_type == Runes.Type.ELEMENT_NATURALEZA and Runes.Type.ELEMENT_TIME < Runes.Type.ELEMENT_MAGMA, "sus tipos están AL FINAL del enum (no mueven los de los .tres ya guardados)")
	# 6/11: naturaleza reaprovecha el veneno del chamán: el hechizo construido lleva `veneno` > 0, que es lo que Combate3D.golpe mira para envenenar.
	var hn: Hechizo = Hechizo.construir(natura, {})
	_ok(hn.elemento == "naturaleza" and hn.veneno > 0.0 and hn.veneno_dps > 0.0, "el hechizo de naturaleza envenena (Hechizo.veneno %.1f s a %.1f/s)" % [hn.veneno, hn.veneno_dps])


## --- 4. LOS GLIFOS VAN AL PRIMER HUECO LIBRE ---
func _glifos(l: Lanzador3D, libro: Control) -> void:
	l.clear_sequence()
	var zg: Vector2 = libro._on_page(libro._av()["zona_glifos"]["centro"])
	var sector: Vector2 = libro._sector_of_point(zg)
	l.add_gesture(_dibujar(String(TrazosRectos.SELLOS["barrera"])), sector)
	_ok(_glifo_en(l, 0) == "barrera", "el primer glifo dibujado en la zona de glifos va al hueco 1 de la corona", _glifo_en(l, 0))
	sector = libro._sector_of_point(zg)
	_ok(sector.is_equal_approx(Grimorio.dir_corona(1)), "con el hueco 1 ocupado, la zona de glifos apunta ya al 2")
	l.add_gesture(_dibujar(String(TrazosRectos.SELLOS["rebote"])), sector)
	_ok(_glifo_en(l, 1) == "rebote" and _glifo_en(l, 0) == "barrera", "el segundo va al hueco 2 y el primero se queda", "%s / %s" % [_glifo_en(l, 0), _glifo_en(l, 1)])
	l.undo_last()
	_ok(_glifo_en(l, 1) == "" and _glifo_en(l, 0) == "barrera" and libro._sector_of_point(zg).is_equal_approx(Grimorio.dir_corona(1)), "deshacer libera el hueco 2 y el siguiente glifo vuelve a ir ahí")
	# Un sello dibujado en la zona de glifos NO es un elemento: se compara solo con glifos.
	var antes: Dictionary = l.pages[0].duplicate()
	l.feedback_text = ""
	l.add_gesture(_dibujar(String(TrazosRectos.ELEMENTOS["tierra"])), libro._sector_of_point(zg))
	_ok(l.pages[0]["element"] == Runes.Type.NONE, "una forma de elemento (tierra) en la zona de glifos no pone ningún elemento", l.feedback_text)
	_ok(str(antes["element"]) == str(l.pages[0]["element"]), "(la página no ganó un sello)")
	# Y un glifo dibujado en la zona de sellos no es un glifo.
	var n_antes: int = l.sigils_used()
	l.add_gesture(_dibujar(String(TrazosRectos.SELLOS["pulso"])), libro._sector_of_point(libro._on_page(libro._av()["zona_sellos"]["centro"])))
	# OJO: no se afirma que no salga un elemento. La X del pulso (DR|DL) se lee en el vocabulario de ELEMENTOS como hielo (D|DR) con desviación 1 y se acepta:
	# es la tolerancia del reconocedor de siempre (en el núcleo del libro «bosque» pasaría igual), no de las zonas. Lo que garantizan las zonas es que NO es un glifo.
	_ok(l.sigils_used() == n_antes, "un glifo (pulso) dibujado en la zona de sellos no se cuela como glifo: se compara solo con elementos", "elemento resultante: %s" % str(l.pages[0]["element"]))
	l.clear_sequence()
	_ok(_glifo_en(l, 0) == "" and l.sigils_used() == 0, "clear_sequence vacía también la corona")
	# La corona se llena por orden hasta los 6 y el séptimo se rechaza.
	var nombres: Array = ["flecha", "barrera", "rebote", "altura", "pulso", "raido"]
	for i in range(6):
		l.add_sigil(libro._av_sector_glifo(), String(nombres[i]))
	var llenos: bool = true
	for i in range(6):
		llenos = llenos and _glifo_en(l, i) == String(nombres[i])
	_ok(llenos and l.sigils_used() == 6, "seis glifos llenan los seis huecos en el orden de dibujo")
	l.add_sigil(libro._av_sector_glifo(), "perforar")
	_ok(l.sigils_used() == 6, "un séptimo se rechaza (página llena)")
	l.clear_sequence()


## El glifo del hueco `i` de la corona de la página activa ("" si está vacío).
func _glifo_en(l: Lanzador3D, i: int) -> String:
	for c in l.components():
		if (c["direction"] as Vector2).is_equal_approx(Grimorio.dir_corona(i)) and not (c["sigils"] as Array).is_empty():
			return String((c["sigils"] as Array)[0])
	return ""


## --- 5. AL LANZAR ---
func _lanzar(l: Lanzador3D) -> void:
	l.clear_sequence()
	l.select_page(0)
	l.place_element("fuego")
	l.place_element("tierra")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	var ok_magma: bool = l._preparar_pagina(0)
	var h: Hechizo = l._preparado.get("hechizo") as Hechizo
	_ok(ok_magma and h != null and h.elemento == "magma", "página fuego + tierra: el Hechizo construido tiene elemento «magma»", "salió=%s elemento=%s" % [ok_magma, h.elemento if h != null else "nulo"])
	_ok(String(l._preparado.get("elemento_nombre", "")) == "magma" and (l._preparado["rune"] as RuneData).display_name == "Magma", "y la previsión lleva el derivado (nombre y runa)")
	var directo: Hechizo = Lanzador3D.receta_de_ficha(l.pages[0], l.rune_database.get(l.pages[0]["element"]), null)["hechizo"]
	_ok(directo != null and directo.elemento == "magma", "receta_de_ficha resuelve la pareja por sí sola (también la usa el libro para avisar)")

	l.clear_sequence()
	l.place_element("agua")
	l.place_element("tierra")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l._preparado = {}
	_ok(l._preparar_pagina(0) and (l._preparado["hechizo"] as Hechizo).elemento == "naturaleza", "agua + tierra: sale naturaleza")
	l.clear_sequence()
	l.place_element("agua")
	l.place_element("viento")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l._preparado = {}
	_ok(l._preparar_pagina(0) and (l._preparado["hechizo"] as Hechizo).elemento == "hielo", "agua + viento: sale hielo")
	l.clear_sequence()
	l.place_element("fuego")
	l.place_element("viento")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l._preparado = {}
	_ok(l._preparar_pagina(0) and (l._preparado["hechizo"] as Hechizo).elemento == "rayo", "fuego + viento: sale rayo")

	# Opuestos: no se lanza, no se cobra tinta, aviso «Se anulan».
	for par in [["fuego", "agua"], ["tierra", "viento"], ["agua", "fuego"]]:
		l.clear_sequence()
		l.place_element(par[0])
		l.place_element(par[1])
		l.add_sigil(Grimorio.dir_corona(0), "flecha")
		l._preparado = {}
		l.tinta.actual = 50.0
		l.feedback_text = ""
		var salio: bool = l._preparar_pagina(0)
		_ok(not salio and l._preparado.is_empty() and absf(l.tinta.actual - 50.0) < 1.0e-6 and l.feedback_text == "Se anulan",
			"%s + %s se anulan: no se lanza, no baja la tinta (%.1f) y avisa «Se anulan»" % [par[0], par[1], l.tinta.actual], "salió=%s aviso=«%s»" % [salio, l.feedback_text])

	# Pareja fuera de la tabla: se lanza el sello 1 y se avisa «Sin reacción».
	l.clear_sequence()
	l.place_element("fuego")
	l.place_element("hielo")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l._preparado = {}
	l.feedback_text = ""
	var salio_sr: bool = l._preparar_pagina(0)
	_ok(salio_sr and (l._preparado["hechizo"] as Hechizo).elemento == "fuego" and l.feedback_text == "Sin reacción", "fuego + hielo (fuera de la tabla): se lanza el fuego y avisa «Sin reacción»", "aviso=«%s»" % l.feedback_text)

	# Un sello solo vale igual que hoy.
	l.clear_sequence()
	l.place_element("agua")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l._preparado = {}
	l.feedback_text = ""
	var salio_solo: bool = l._preparar_pagina(0)
	_ok(salio_solo and (l._preparado["hechizo"] as Hechizo).elemento == "agua" and l.feedback_text == "", "un sello solo (agua) se lanza como siempre, sin aviso")
	l.clear_sequence()


## --- 6. RESUMEN ---
func _resumen(l: Lanzador3D) -> void:
	l.clear_sequence()
	l.place_element("fuego")
	l.place_element("tierra")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	l.add_sigil(Grimorio.dir_corona(1), "flecha")
	var r: Dictionary = l.resumen_pagina()
	_ok(String(r["elemento"]) == "magma" and String(r["nombre"]) == "Magma", "resumen_pagina de fuego + tierra dice Magma", "%s / %s" % [r["elemento"], r["nombre"]])
	_ok(String(r["titulo"]) == "Magma · Flecha ×2" or String(r["titulo"]).begins_with("Magma · "), "y su título es «Magma · glifos ×n»", String(r["titulo"]))
	_ok(not bool(r["vacia"]) and r["hechizo"] != null, "y la página no se da por vacía")
	_ok((l.page_element_data(0) as RuneData).display_name == "Magma" and l.page_ready(0), "la pestaña y el HUD (page_element_data) pintan el derivado, y la página está lista")
	# Se actualiza al cambiar el segundo sello (la caché no se queda con el magma).
	l.undo_last()
	l.undo_last()
	l.undo_last()
	_ok(String(l.resumen_pagina()["elemento"]) == "fuego", "al deshacer el segundo sello el resumen vuelve a decir fuego (la caché se invalida)", String(l.resumen_pagina()["elemento"]))
	l.clear_sequence()
	l.place_element("fuego")
	l.place_element("agua")
	l.add_sigil(Grimorio.dir_corona(0), "flecha")
	var a: Dictionary = l.resumen_pagina()
	_ok(String(a["pareja"]) == "anulan" and String(a["titulo"]) == "Se anulan" and (a["avisos"] as Array).has("Se anulan") and not bool(a["vacia"]), "resumen_pagina de fuego + agua dice «Se anulan» (y no «Sin elemento»)", str(a["avisos"]))
	_ok(l.page_element_data(0) == null and not l.page_ready(0) and l.pagina_anulada(0), "y la página anulada se pinta apagada y no cuenta como lista")
	l.clear_sequence()


## --- 7. EL LIBRO DE SIEMPRE NO CAMBIA ---
func _bosque_igual(l: Lanzador3D) -> void:
	Repertoire.libro = "bosque"
	l.clear_sequence()
	l.place_element("fuego")
	l.place_element("agua")
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_CIRCLE and l.pages[0]["element2"] == Runes.Type.NONE, "en el libro «bosque» el segundo sello SUSTITUYE al primero y no hay segundo medallón")
	_ok(String(l.resumen_pagina()["pareja"]) == "" and String(l.resumen_pagina()["elemento"]) == "agua" and String(l.resumen_pagina()["titulo"]) == "", "y el resumen no sabe nada de parejas")
	l.undo_last()
	_ok(l.pages[0]["element"] == Runes.Type.SHAPE_TRIANGLE, "deshacer vuelve al fuego, como siempre")
	# Un element2 suelto en una ficha de «bosque» (un libro cambiado) no manda.
	l.pages[0]["element2"] = Runes.Type.SHAPE_CIRCLE
	_ok(l.rune_de_ficha(l.pages[0])["estado"] == CombosSellos.SIN_PAREJA and String(l.rune_de_ficha(l.pages[0])["nombre"]) == "Fuego", "con otro libro un element2 suelto se ignora")
	l.pages[0]["element2"] = Runes.Type.NONE
	l.clear_sequence()
	Repertoire.libro = ""


## --- DIBUJO SINTÉTICO (limpio, sin ruido: el ruido lo mide prueba_trazos_rectos) ---
func _dibujar(texto: String) -> Array:
	var gesto: Array = TrazosRectos.texto_a_gesto(texto)
	var trazos: Array = []
	for k in range(gesto.size()):
		var p := Vector2(200.0, 200.0 + float(k) * 50.0)
		var pts: Array = [p]
		for d in (gesto[k] as Array):
			var v: Vector2 = TrazosRectos.vector_de(int(d)) * 60.0
			for i in range(1, int(60.0 / PASO_PX) + 1):
				pts.append(p + v * (float(i) * PASO_PX / 60.0))
			p += v
		trazos.append(pts)
	return trazos


func _ok(bien: bool, nombre: String, info: String = "") -> void:
	print(("  OK    " if bien else "  FALLO ") + nombre + ("" if info == "" else "  [" + info + "]"))
	if not bien:
		fallos += 1
