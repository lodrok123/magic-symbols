extends SceneTree
## PIEZAS DE MEJORA (11/11, Juego; tabla de mejoras de Pablo en docs/REVISION_OBJETOS_SINTESIS.md §6):
##   1 · fragmento de savia ×3 → +20 de vida máxima (hasta 200: 15 fragmentos); los que sobran se quedan (24/11: antes, 4 trozos de corazón)
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
	e.agregar("fragmento_savia", 2)
	_ok("1 con 2 fragmentos todavía no sube nada", is_equal_approx(e.vida_max, 100.0) and e.cuenta("fragmento_savia") == 2)
	e.agregar("fragmento_savia", 1)
	_ok("1 el tercer fragmento da +20 de vida máxima y se gastan los tres", is_equal_approx(e.vida_max, 120.0) and e.cuenta("fragmento_savia") == 0 and e.nivel("vida_max") == 1 and completadas == ["vida_max"], "%s · %d" % [str(e.vida_max), e.cuenta("fragmento_savia")])
	e.agregar("fragmento_savia", 13)
	_ok("1 con 16 fragmentos en total, 200 de vida y sobra 1", is_equal_approx(e.vida_max, 200.0) and e.nivel("vida_max") == 5 and e.cuenta("fragmento_savia") == 1, "%s · %d" % [str(e.vida_max), e.cuenta("fragmento_savia")])
	e.agregar("fragmento_savia", 3)
	_ok("1 en el tope los fragmentos se quedan (no se pierden)", e.cuenta("fragmento_savia") == 4 and e.nivel("vida_max") == 5)
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
	_ok("5 pero un fragmento de savia sí, y no ocupa hueco", e.agregar("fragmento_savia", 1) == 1 and e.huecos_usados() == 1)
	_ok("5 las piezas van a la pestaña de objetos clave", Objetos.categoria("fragmento_savia") == "clave" and Objetos.es_pieza("engarce_glifo") and not Objetos.es_pieza("pocion"))
	# 6 · recetas
	var quedan: Array = []
	for r in ["vida_1", "vida_2", "vida_3", "frascos_1", "frascos_2", "huecos_1", "paginas_1"]:
		if not BD.receta(r).is_empty():
			quedan.append(r)
	_ok("6 no quedan recetas de vida, frascos, huecos ni páginas", quedan.is_empty(), str(quedan))
	# 7 · dónde están
	var b02: String = FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/Bosque_02.txt")
	var cue: String = FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/CuevaResonante.txt")
	_ok("7 Bosque_02: 3 fragmentos (una savia), 1 frasco y 1 hoja en sus cofres", b02.count("fragmento_savia:1") == 3 and not b02.contains("trozo_corazon") and b02.count("frasco_vacio:1") == 1 and b02.count("hoja_grimorio:1") == 1)
	_ok("7 Cueva Resonante: 3 fragmentos (una savia), 1 frasco y 1 engarce", cue.count("fragmento_savia:1") == 3 and not cue.contains("trozo_corazon") and cue.count("frasco_vacio:1") == 1 and cue.count("engarce_glifo:1") == 1)
	var epicos: int = 0
	for linea in (b02 + "\n" + cue).split("\n"):
		if linea.contains("fragmento_savia:1") and linea.contains("modelo=epico"):
			epicos += 1
	_ok("7 los seis fragmentos están en cofres épicos", epicos == 6, str(epicos))
	var jefe: Array = []
	for _i in range(5):
		for r in Botin.tirar("elemental"):
			jefe.append(String(r["que"]))
	_ok("7 el jefe elemental suelta siempre un engarce", jefe.count("engarce_glifo") == 5, str(jefe))
	for mapa in ["Bosque_02", "CuevaResonante"]:
		var r: Dictionary = Puzle3D.parsear(FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/%s.txt" % mapa))
		var malos: Array = []
		for a in (r.get("avisos", []) as Array):
			if String(a).contains("fragmento_savia") or String(a).contains("frasco_vacio") or String(a).contains("engarce_glifo") or String(a).contains("hoja_grimorio"):
				malos.append(a)
		_ok("7 %s: los cofres con piezas se leen sin avisos" % mapa, malos.is_empty(), str(malos))
	# 8 · partida
	Estado.nuevo()
	e = Estado.i()
	e.agregar("fragmento_savia", 5)
	var d: Dictionary = e.a_dic()
	var g := Estado.new()
	g.desde_dic(d)
	_ok("8 la partida guarda los fragmentos sueltos y la vida ganada", g.cuenta("fragmento_savia") == 2 and is_equal_approx(g.vida_max, 120.0), "%d · %s" % [g.cuenta("fragmento_savia"), str(g.vida_max)])
	# 9 · partidas viejas con trozos de corazón (24/11): pasan a fragmentos y, si llegan a 3, suben la vida al cargar
	var vieja: Dictionary = g.a_dic()
	vieja["bolsa"]["items"].erase("fragmento_savia")
	vieja["bolsa"]["items"]["trozo_corazon"] = 3
	var h := Estado.new()
	h.desde_dic(vieja)
	_ok("9 tres trozos viejos = una savia: 140 de vida y nada suelto", h.cuenta("trozo_corazon") == 0 and h.cuenta("fragmento_savia") == 0 and is_equal_approx(h.vida_max, 140.0), "%d · %d · %s" % [h.cuenta("trozo_corazon"), h.cuenta("fragmento_savia"), str(h.vida_max)])
	_ok("9 el icono de la savia es la gota", String(Objetos.DATOS.get("fragmento_savia", {}).get("forma", "")) == "gota")
	# 10 · la gota del inventario (MenuPestanas.SaviaMenu): fragmentos que llevas y los que faltan
	var s := MenuPestanas.SaviaMenu.new()
	s.poner(0, 0, 5)
	_ok("10 sin fragmentos: «Savia 0/3 · Te faltan 3»", s.texto() == "Savia 0/3" and s.subtexto() == "Te faltan 3", s.texto() + " · " + s.subtexto())
	s.poner(2, 1, 5)
	_ok("10 con dos: «Savia 2/3 · Te falta 1»", s.texto() == "Savia 2/3" and s.subtexto() == "Te falta 1" and s.faltan() == 1)
	s.poner(9, 1, 5)
	_ok("10 nunca más de tres", s.fragmentos == 3)
	s.poner(1, 5, 5)
	_ok("10 con las cinco savias: entera y «Vida al máximo»", s.completa() and s.faltan() == 0 and s.subtexto() == "Vida al máximo")
	_ok("10 la gota se parte en tres piezas", (s._piezas(Vector2(30, 30), 25.0) as Array).size() == 3)
	s.free()
	Estado.nuevo()
