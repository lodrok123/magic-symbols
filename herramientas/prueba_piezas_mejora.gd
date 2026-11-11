extends SceneTree
## PIEZAS DE MEJORA (11/11, Juego; tabla de mejoras de Pablo en docs/REVISION_OBJETOS_SINTESIS.md §6):
##   1 · trozo de corazón ×4 → +20 de vida máxima (hasta 200: 20 trozos); los trozos que sobran se quedan
##   2 · frasco vacío → un frasco de reserva más, lleno (hasta 6)
##   3 · engarce de glifo → los engarces fijan el total de huecos (máx(base del libro, 1 + engarces), tope 6)
##   4 · hoja de grimorio → una página más (3 → 8)
##   5 · las piezas no ocupan hueco en la mochila (entran con la mochila llena)
##   6 · ya no hay recetas de vida, frascos, huecos ni páginas
##   7 · dónde están: cofres de Bosque_02 y de la Cueva, y el jefe elemental
##   8 · se guardan con la partida
##   godot --headless --path . --script res://herramientas/prueba_piezas_mejora.gd

var _fallos: int = 0


func _initialize() -> void:
	_probar()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _probar() -> void:
	# 1 · corazón
	Estado.nuevo()
	var e: Estado = Estado.i()
	var completadas: Array = []
	e.pieza_completada.connect(func(o: String, m: String) -> void: completadas.append(m))
	e.agregar("trozo_corazon", 3)
	_ok("1 con 3 trozos todavía no sube nada", is_equal_approx(e.vida_max, 100.0) and e.cuenta("trozo_corazon") == 3)
	e.agregar("trozo_corazon", 1)
	_ok("1 el cuarto trozo da +20 de vida máxima y se gastan los cuatro", is_equal_approx(e.vida_max, 120.0) and e.cuenta("trozo_corazon") == 0 and e.nivel("vida_max") == 1 and completadas == ["vida_max"], "%s · %d" % [str(e.vida_max), e.cuenta("trozo_corazon")])
	e.agregar("trozo_corazon", 17)
	_ok("1 con 20 trozos en total, 200 de vida y sobra 1", is_equal_approx(e.vida_max, 200.0) and e.nivel("vida_max") == 5 and e.cuenta("trozo_corazon") == 1, "%s · %d" % [str(e.vida_max), e.cuenta("trozo_corazon")])
	e.agregar("trozo_corazon", 3)
	_ok("1 en el tope los trozos se quedan (no se pierden)", e.cuenta("trozo_corazon") == 4 and e.nivel("vida_max") == 5)
	# 2 · frasco
	Estado.nuevo()
	e = Estado.i()
	var t := Tinta.new()
	t.partida = e
	Partida.tinta = t
	var antes: int = Tinta.frascos_max(e)
	e.agregar("frasco_vacio", 1)
	_ok("2 el frasco vacío da un frasco más (3 → 4) y no se queda en la mochila", Tinta.frascos_max(e) == antes + 1 and e.cuenta("frasco_vacio") == 0, "%d → %d" % [antes, Tinta.frascos_max(e)])
	_ok("2 y el frasco nuevo nace lleno", t.frascos == Tinta.frascos_max(e), "%d/%d" % [t.frascos, Tinta.frascos_max(e)])
	Partida.tinta = null
	# 3 · engarce
	Estado.nuevo()
	e = Estado.i()
	Repertoire.cambiar_libro("bosque")
	e.agregar("engarce_glifo", 1)
	_ok("3 un engarce con el libro del bosque: 2 huecos (1 + 1)", Repertoire.max_sigils_per_page == 2 and e.nivel("huecos_glifo") == 1, str(Repertoire.max_sigils_per_page))
	e.agregar("engarce_glifo", 4)
	_ok("3 con los cinco engarces, 6 huecos", Repertoire.max_sigils_per_page == 6 and e.nivel("huecos_glifo") == 5, str(Repertoire.max_sigils_per_page))
	# 4 · hoja
	Estado.nuevo()
	e = Estado.i()
	Repertoire.max_pages = 3
	Mejoras.aplicar_todas(e)
	for _i in range(5):
		e.agregar("hoja_grimorio", 1)
	_ok("4 cinco hojas: el grimorio pasa de 3 a 8 páginas", Repertoire.max_pages == 8 and e.nivel("paginas") == 5, str(Repertoire.max_pages))
	e.agregar("hoja_grimorio", 1)
	_ok("4 una sexta no pasa de 8", Repertoire.max_pages == 8 and e.cuenta("hoja_grimorio") == 1)
	Repertoire.max_pages = 0
	# 5 · mochila llena
	Estado.nuevo()
	e = Estado.i()
	e.capacidad = 1
	e.agregar("piedra", Objetos.pila("piedra"))
	_ok("5 con la mochila llena, una piedra más no entra", e.agregar("piedra", 1) == 0)
	_ok("5 pero un trozo de corazón sí, y no ocupa hueco", e.agregar("trozo_corazon", 1) == 1 and e.huecos_usados() == 1)
	_ok("5 las piezas van a la pestaña de objetos clave", Objetos.categoria("trozo_corazon") == "clave" and Objetos.es_pieza("engarce_glifo") and not Objetos.es_pieza("pocion"))
	# 6 · recetas
	var quedan: Array = []
	for r in ["vida_1", "vida_2", "vida_3", "frascos_1", "frascos_2", "huecos_1", "paginas_1"]:
		if not BD.receta(r).is_empty():
			quedan.append(r)
	_ok("6 no quedan recetas de vida, frascos, huecos ni páginas", quedan.is_empty(), str(quedan))
	# 7 · dónde están
	var b02: String = FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/Bosque_02.txt")
	var cue: String = FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/CuevaResonante.txt")
	_ok("7 Bosque_02: 4 trozos, 1 frasco y 1 hoja en sus cofres", b02.count("trozo_corazon:1") == 4 and b02.count("frasco_vacio:1") == 1 and b02.count("hoja_grimorio:1") == 1)
	_ok("7 Cueva Resonante: 2 trozos, 1 frasco y 1 engarce", cue.count("trozo_corazon:1") == 2 and cue.count("frasco_vacio:1") == 1 and cue.count("engarce_glifo:1") == 1)
	var jefe: Array = []
	for _i in range(5):
		for r in Botin.tirar("elemental"):
			jefe.append(String(r["que"]))
	_ok("7 el jefe elemental suelta siempre un engarce", jefe.count("engarce_glifo") == 5, str(jefe))
	for mapa in ["Bosque_02", "CuevaResonante"]:
		var r: Dictionary = Puzle3D.parsear(FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/%s.txt" % mapa))
		var malos: Array = []
		for a in (r.get("avisos", []) as Array):
			if String(a).contains("trozo_corazon") or String(a).contains("frasco_vacio") or String(a).contains("engarce_glifo") or String(a).contains("hoja_grimorio"):
				malos.append(a)
		_ok("7 %s: los cofres con piezas se leen sin avisos" % mapa, malos.is_empty(), str(malos))
	# 8 · partida
	Estado.nuevo()
	e = Estado.i()
	e.agregar("trozo_corazon", 6)
	var d: Dictionary = e.a_dic()
	var g := Estado.new()
	g.desde_dic(d)
	_ok("8 la partida guarda los trozos sueltos y la vida ganada", g.cuenta("trozo_corazon") == 2 and is_equal_approx(g.vida_max, 120.0), "%d · %s" % [g.cuenta("trozo_corazon"), str(g.vida_max)])
	Estado.nuevo()
