extends "res://herramientas/escenario_base.gd"
## GAMEFEEL TERCERA TANDA, LOTE 2 · B4 DESCRIPCIONES DE OBJETOS Y GLIFOS (2/11; nucleo/textos_objetos.gd, nucleo/objetos.gd `descripcion`, menu_pestanas.gd `Detalle.mostrar`, spellbook.gd `glifo_elegido`).
## Sin escena: cada id de `Objetos` tiene descripción PROPIA en `TextosObjetos` (no la corta de la tabla), de 1-2 frases; los consumibles dicen lo que dice su `efecto` (40 de vida, 20 s, 12 s…); cada glifo de
## `Sigils` (GLIFOS, FORM, OPERATOR, GLYPHS, el alias y los de la chuleta del libro) tiene texto; los números de los textos de ᛁ, ᛏ y ᚷ coinciden con las constantes de `Sigils`.
## Con la escena del Bosque: el detalle de la mochila muestra la descripción del objeto elegido (y cambia al elegir otro; «Usos conocidos» baja si el texto ocupa más líneas), y el grimorio muestra el
## texto del glifo elegido (por la API de pruebas y por la casilla de la chuleta), sin romper el dibujo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_textos_objetos.gd

var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _ev(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	return ev


func _escenario() -> void:
	_objetos()
	_glifos()
	await _mochila_y_libro()
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
func _objetos() -> void:
	var ids: Array = Objetos.DATOS.keys()
	_ok("1 hay objetos en el catálogo (%d)" % ids.size(), ids.size() >= 70)
	var sin: PackedStringArray = []
	var cortos: PackedStringArray = []
	var largos: PackedStringArray = []
	for id in ids:
		var t: String = TextosObjetos.descripcion(String(id))
		if t.strip_edges() == "":
			sin.append(String(id))
		elif t.length() < 15:
			cortos.append(String(id))
		if t.length() > 260:
			largos.append(String(id))
	_ok("1 TODOS los ids de Objetos tienen descripción propia no vacía en TextosObjetos", sin.is_empty(), "faltan: " + ", ".join(sin))
	_ok("1 ninguna es una palabra suelta (≥ 15 caracteres)", cortos.is_empty(), ", ".join(cortos))
	_ok("1 ni cabe un párrafo (≤ 260 caracteres: 1-2 frases)", largos.is_empty(), ", ".join(largos))
	var sobran: PackedStringArray = []
	for id in TextosObjetos.DESCRIPCION:
		if not Objetos.existe(String(id)):
			sobran.append(String(id))
	_ok("1 y la tabla no tiene ids que no existan", sobran.is_empty(), ", ".join(sobran))
	var igual: bool = true
	for id in ids:
		if Objetos.descripcion(String(id)) != TextosObjetos.descripcion(String(id)):
			igual = false
	_ok("1 Objetos.descripcion(id) devuelve la de la tabla de textos", igual)
	_ok("1 un id desconocido cae en «» (sin texto ni tabla)", Objetos.descripcion("inventado") == "")

	# Los consumibles dicen lo que hace su `efecto` (los números salen de la tabla, no de la memoria).
	var c: Dictionary = {}
	for id in Objetos.CONSUMIBLES:
		c[String(id)] = Objetos.efecto(String(id))
	_ok("2 la poción dice 40 y su efecto cura 40", int(c["pocion"]["cura"]) == 40 and TextosObjetos.descripcion("pocion").contains("40"))
	_ok("2 la poción grande dice 80 y su efecto cura 80", int(c["pocion_grande"]["cura"]) == 80 and TextosObjetos.descripcion("pocion_grande").contains("80"))
	_ok("2 el bálsamo dice 20 s y su efecto dura 20", int(c["balsamo_protector"]["dura"]) == 20 and TextosObjetos.descripcion("balsamo_protector").contains("20 s"))
	_ok("2 la infusión dice 3 de vida por segundo durante 12 s y su efecto tasa 3 dura 12", int(c["infusion_brezo"]["tasa"]) == 3 and int(c["infusion_brezo"]["dura"]) == 12
		and TextosObjetos.descripcion("infusion_brezo").contains("3 de vida") and TextosObjetos.descripcion("infusion_brezo").contains("12 s"))
	_ok("2 el antídoto dice 90 s y su efecto dura 90", int(c["antidoto"]["dura"]) == 90 and TextosObjetos.descripcion("antidoto").contains("90 s"))      # 10/11: los antídotos protegen 90 s
	_ok("2 la poción mayor dice 120 y 2 por segundo durante 10 s, como su efecto", int(c["pocion_mayor"]["cura"]) == 120 and int(c["pocion_mayor"]["regen"]) == 2
		and int(c["pocion_mayor"]["dura"]) == 10 and TextosObjetos.descripcion("pocion_mayor").contains("120") and TextosObjetos.descripcion("pocion_mayor").contains("10 s"))
	_ok("2 la savia aislante y los dos elixires dicen su duración", TextosObjetos.descripcion("savia_aislante").contains("%d s" % int(c["savia_aislante"]["dura"]))
		and TextosObjetos.descripcion("elixir_filtro").contains("%d s" % int(c["elixir_filtro"]["dura"])) and TextosObjetos.descripcion("elixir_templado").contains("%d s" % int(c["elixir_templado"]["dura"])))
	_ok("2 frescor y abrigo dicen 90 s y sus efectos duran 90", int(c["frescor"]["dura"]) == 90 and int(c["abrigo"]["dura"]) == 90
		and TextosObjetos.descripcion("frescor").contains("90 s") and TextosObjetos.descripcion("abrigo").contains("90 s"))
	var pig_ok: bool = true
	for id in ["pigmento_carmesi", "pigmento_rocio", "pigmento_ocre", "pigmento_escarcha", "pigmento_ambar", "pigmento_musgo", "pigmento_eco"]:
		if not TextosObjetos.descripcion(id).contains("siguiente hechizo"):
			pig_ok = false
	_ok("2 los siete pigmentos dicen que valen para el siguiente hechizo (10/11: una carga)", pig_ok)
	var ropa_ok: bool = TextosObjetos.descripcion("capa_escarcha").contains("frío") and TextosObjetos.descripcion("tunica_salamandra").contains("calor") and TextosObjetos.descripcion("capucha_musgo").contains("veneno")
	_ok("2 la ropa épica dice de qué protege (frío, calor, veneno) como su `inmune`", ropa_ok)
	var ing_ok: bool = true
	var mal: PackedStringArray = []
	for id in Objetos.DATOS:
		if Objetos.categoria_bd(String(id)) in ["hongo", "planta", "raiz", "mineral", "animal"]:
			var d: String = TextosObjetos.descripcion(String(id)).to_lower()
			var tags: Array = Objetos.etiquetas(String(id))
			if d.contains("aporta") or d.contains("aportan"):
				continue
			if not (d.contains("material") or d.contains("épico")):
				ing_ok = false
				mal.append(String(id))
	_ok("2 cada ingrediente cuenta qué aporta a las recetas (o es un material épico)", ing_ok, ", ".join(mal))


# ---------------------------------------------------------------------------------------------------------------------
func _glifos() -> void:
	var nombres: Dictionary = {}
	for k in Sigils.GLIFOS.keys():
		nombres[String(k)] = true
	for k in Sigils.FORM.keys():
		nombres[String(k)] = true
	for k in Sigils.OPERATOR.keys():
		nombres[String(k)] = true
	for k in Sigils.GLYPHS.keys():
		nombres[String(k)] = true
	for k in Sigils.ALIAS_V2.keys():
		nombres[String(k)] = true
	for k in GestureLibrary.SIGILS:
		nombres[String(k)] = true
	var sin: PackedStringArray = []
	for n in nombres.keys():
		if TextosObjetos.glifo(String(n)).strip_edges().length() < 15:
			sin.append(String(n))
	_ok("3 cada glifo de Sigils (%d nombres: GLIFOS, FORM, OPERATOR, GLYPHS, alias y chuleta del libro) tiene su texto" % nombres.size(), sin.is_empty(), "faltan: " + ", ".join(sin))
	var sobran: PackedStringArray = []
	for n in TextosObjetos.GLIFO:
		if not Sigils.is_known(String(n)) and not Sigils.GLYPHS.has(String(n)):
			sobran.append(String(n))
	_ok("3 y la tabla no tiene glifos que Sigils no conozca", sobran.is_empty(), ", ".join(sobran))
	_ok("3 un glifo desconocido no tiene texto", TextosObjetos.glifo("inventado") == "")

	# Los números de los textos son los del código.
	var x: String = TextosObjetos.glifo("linea_x")
	_ok("4 ᛁ (3/11): la 1.ª alarga 1 casilla (semieje %.2f) y cada siguiente 0,5 casillas (semieje %.2f)" % [Sigils.PASO_ANCHO_V2, Sigils.PASO_LUEGO_V2],
		is_equal_approx(Sigils.PASO_ANCHO_V2, 0.5) and is_equal_approx(Sigils.PASO_LUEGO_V2, 0.25) and x.contains("1 casilla") and x.contains("0,5 casillas"))
	_ok("4 ᛁ: un muro de 3 casillas pide %d (GLIFOS_ANCHO_MURO_3_V2) y el texto dice 9" % Sigils.GLIFOS_ANCHO_MURO_3_V2, Sigils.GLIFOS_ANCHO_MURO_3_V2 == 3 and x.contains("pide 3"))
	var h: String = TextosObjetos.glifo("altura")
	_ok("4 ᛏ (3/11): %.2f m el 1.º y cada siguiente un 15 %% menos, sin tope; 3 = 2 niveles, 6 = 3" % Sigils.PASO_ALTURA_V2, is_equal_approx(Sigils.PASO_ALTURA_V2, 0.30) and Sigils.GLIFOS_ALTURA_DOS_NIVELES_V2 == 3 and Sigils.GLIFOS_ALTURA_CUATRO_NIVELES_V2 == 11
		and h.contains("0,30") and h.contains("3 = 2 niveles") and h.contains("6 = 3 niveles") and h.contains("decreciente"))
	var g: String = TextosObjetos.glifo("pulso")
	_ok("4 ᚷ «crecer»: ×%.2f (CRECER_TOPE_V2) y +0,5 m/s con tope 1,5" % Sigils.CRECER_TOPE_V2, is_equal_approx(Sigils.CRECER_TOPE_V2, 1.30) and g.contains("1,30") and g.contains("0,5") and g.contains("1,5"))
	var r: String = TextosObjetos.glifo("raido")
	_ok("4 ᚱ «pulso»: +%.0f casillas por glifo, tope %.0f" % [Sigils.PASO_RESUENA_V2, Sigils.TOPE_RESUENA_V2], r.contains("4 casillas") and r.contains("12"))
	var s: String = TextosObjetos.glifo("permanencia")
	_ok("4 ᛉ: 2 s por glifo y tope 25 s", s.contains("2 s") and s.contains("25 s"))
	var carga: String = TextosObjetos.glifo("retardo")
	_ok("4 ⧖ «carga»: ×1,2 y ×1,25 como en Sigils.GLIFOS", carga.contains("20 %") and carga.contains("25 %"))
	var f: String = TextosObjetos.glifo("flecha")
	_ok("4 ᚠ flecha: 2 casillas la primera, +1 cada una, tope 6", f.contains("2 casillas") and f.contains("1") and f.contains("6"))
	var b: String = TextosObjetos.glifo("barrera")
	_ok("4 barrera: ×1,5 con tope 3", b.contains("1,5") and b.contains("3"))
	_ok("4 los nombres que ve la jugadora: ᚷ se ve «%s», ᚱ «%s», ⧖ «%s»" % [Sigils.nombre_visible("pulso"), Sigils.nombre_visible("raido"), Sigils.nombre_visible("retardo")],
		TextosObjetos.glifo("pulso").begins_with("Crecer") and TextosObjetos.glifo("raido").begins_with("Pulso") and TextosObjetos.glifo("retardo").begins_with("Carga"))


# ---------------------------------------------------------------------------------------------------------------------
func _mochila_y_libro() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	current_scene = maqueta
	Repertoire.activate_all()
	var menu: MenuPestanas = lanzador.menu
	_ok("5 hay menú con pestañas", menu != null)
	if menu == null:
		return
	var e: Estado = Estado.i()
	e.capacidad = 12
	for id in ["lavanda", "pocion", "nucleo_eco", "llave", "seta", "pigmento_carmesi"]:
		e.agregar(id, 1)
	await avanzar(4)
	menu.abrir()
	await avanzar(12)
	var det: Control = menu._detalle
	var vistos: int = 0
	var todos_iguales: bool = true
	var bajo: bool = true
	var lista: PackedStringArray = []
	for i in range(menu.pilas().size()):
		menu._elegir(i, false)
		await avanzar(1)
		var d: Dictionary = menu.detalle()
		var id: String = String(d["id"])
		var texto: String = (det.get("_desc") as Label).text
		vistos += 1
		lista.append(id)
		if texto != TextosObjetos.descripcion(id) or texto == "":
			todos_iguales = false
		var y_usos: float = (det.get("_titulo_usos") as Label).position.y
		var y_fin_desc: float = (det.get("_desc") as Label).position.y + maxf((det.get("_desc") as Label).get_minimum_size().y, 24.0)
		if y_usos < y_fin_desc:
			bajo = false
	_ok("5 el detalle de la mochila muestra la descripción del objeto elegido en cada hueco (%d: %s)" % [vistos, ", ".join(lista)], vistos >= 6 and todos_iguales)
	_ok("5 «Usos conocidos» queda siempre por debajo de la descripción (no se pisan)", bajo)
	var i_lav: int = -1
	var i_pocion: int = -1
	for i in range(menu.pilas().size()):
		if String(menu.pilas()[i][0]) == "lavanda":
			i_lav = i
		if String(menu.pilas()[i][0]) == "pocion":
			i_pocion = i
	menu._elegir(i_lav, false)
	await avanzar(1)
	var t1: String = (det.get("_desc") as Label).text
	menu._elegir(i_pocion, false)
	await avanzar(1)
	var t2: String = (det.get("_desc") as Label).text
	_ok("5 la lavanda y la poción enseñan textos distintos", t1 != t2 and t1.contains("calma") and t2.contains("40"), t1 + " | " + t2)
	menu.cerrar()
	await avanzar(12)

	# --- el libro ---
	var libro: Control = lanzador.libro
	_ok("6 el libro existe y no tiene ningún glifo elegido al principio", libro != null and String(libro.get("glifo_elegido")) == "" and libro.call("pie_glifo_texto") == "")
	if libro == null:
		return
	lanzador.libro.call("_toggle")
	await avanzar(6)
	_ok("6 abierto el libro, la chuleta registra las casillas de glifo", lanzador.libro_abierto() and (libro.get("_casillas_leyenda") as Array).size() > 0, str((libro.get("_casillas_leyenda") as Array).size()))
	libro.call("elegir_glifo", "linea")
	await avanzar(2)
	_ok("6 elegir ᛁ: el libro muestra su texto de pie", libro.call("pie_glifo_texto") == TextosObjetos.glifo("linea") and TextosObjetos.glifo("linea") != "")
	libro.call("elegir_glifo", "flecha")
	_ok("6 elegir la flecha cambia el texto", libro.call("pie_glifo_texto") == TextosObjetos.glifo("flecha"))
	# Por la casilla de la chuleta (lo que haría el ratón al pasar por encima).
	var cas: Array = libro.get("_casillas_leyenda")
	var hallado: bool = false
	var coincide: bool = true
	for c in cas:
		var rect: Rect2 = c["rect"]
		var nombre: String = String(libro.call("_glifo_bajo", rect.get_center()))
		hallado = true
		if nombre != String(c["nombre"]):
			coincide = false
	_ok("6 el centro de cada casilla de la chuleta elige su glifo (%d casillas)" % cas.size(), hallado and coincide)
	_ok("6 fuera de las casillas no hay ninguno", String(libro.call("_glifo_bajo", Vector2(-50, -50))) == "")
	libro.call("elegir_glifo", "")
	_ok("6 sin glifo elegido, el pie no dice nada", libro.call("pie_glifo_texto") == "")
	libro.call("elegir_glifo", "flecha")
	await avanzar(3)                                   # varios dibujos con el pie puesto: no rompe
	_ok("6 con el pie puesto el libro sigue dibujando", lanzador.libro_abierto())
	libro.call("elegir_glifo", "")
	lanzador.libro.call("_toggle")
	await avanzar(6)
