extends "res://herramientas/escenario_base.gd"
## LIBRO ROJO (libro de PRUEBA, 22/11, sesión HECHIZOS; PLAN_HECHIZOS §6.5) sin ventana. Carga `laboratorios/LabLibroRojo.tscn` de verdad.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_libro_rojo.gd
## Comprueba: que se abre y se cierra (L) y pausa; que un trazo de sello en el núcleo y de glifo en un hueco entran en la página del lanzador por el reconocedor de siempre
## y la tinta los escribe; que un trazo NO reconocido se queda para corregirlo; el orden de los glifos «dibujo» frente a «huecos» (cambia la ráfaga); combinar dos sellos
## (magma) y separarlos; la capacidad visible del catálogo; la maqueta de anidación; que lo escrito se LANZA con el mismo Hechizo; y que los libros de siempre no cambian.

const RUTA_LAB: String = "res://laboratorios/LabLibroRojo.tscn"
var _lr: LibroRojo = null


## Los trazos de un símbolo como los dibujaría la jugadora: los de `LibroRojo.polilineas`, en píxeles, en la zona de trazado.
func _trazos(nombre: String, escala: float = 120.0, temblor: float = 0.0, rng: RandomNumberGenerator = null) -> Array:
	var z: Dictionary = _lr.zona_trazado()
	var c: Vector2 = z["centro"]
	var salida: Array = []
	for poli in LibroRojo.polilineas(nombre):
		var pts := PackedVector2Array()
		for q in poli:
			# Puntos intermedios: un trazo de verdad no son solo vértices.
			pts.append(c + (q as Vector2) * escala)
		var denso := PackedVector2Array([pts[0]])
		for j in range(1, pts.size()):
			for k in range(1, 9):
				var q2: Vector2 = pts[j - 1].lerp(pts[j], float(k) / 8.0)
				if rng != null and temblor > 0.0:
					q2 += Vector2(rng.randf_range(-temblor, temblor), rng.randf_range(-temblor, temblor))
				denso.append(q2)
		salida.append(denso)
	return salida


func _ficha() -> Dictionary:
	return lanzador.pages[lanzador.page]


func _hechizo_pagina() -> Hechizo:
	return lanzador.resumen_pagina(lanzador.page).get("hechizo") as Hechizo


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	var libro_inicial: String = Repertoire.libro
	await cargar(RUTA_LAB, false)
	if lanzador == null:
		_ok("el lanzador existe", false)
		return
	for _i in range(60):                       # el lab abre el libro en cuanto se levanta el velo
		if paused:
			break
		await process_frame
	_lr = get_first_node_in_group("spellcaster").get_tree().root.find_child("LibroRojo", true, false) as LibroRojo
	_ok("1 el lab monta el libro rojo y lo abre al empezar", _lr != null and _lr.abierto and _lr.visible)
	if _lr == null:
		return
	_ok("1 abierto, el juego queda en pausa (como el libro de siempre)", paused)
	_lr.cerrar()
	_ok("1 cerrarlo quita la pausa", not paused and not _lr.abierto)
	_lr.abrir()
	lanzador.select_page(0)
	lanzador.clear_sequence()

	# 2 · Sello en el núcleo y glifo en un hueco, por el reconocedor de siempre.
	_lr.elegir_destino("nucleo")
	_ok("2 en el núcleo se espera un SELLO", _lr.familia_esperada() == "sello")
	var ok_fuego: bool = _lr.cerrar_gesto(_trazos("fuego"))
	_ok("2 el trazo de ᚲ en el núcleo pone fuego en la página del lanzador", ok_fuego and lanzador._gesture_name_of(_ficha()["element"]) == "fuego", lanzador.feedback_text)
	_ok("2 y la tinta empieza a escribirlo", _lr.escribiendo())
	_lr.elegir_destino("hueco:0")
	_ok("2 en un hueco se espera un GLIFO", _lr.familia_esperada() == "glifo")
	var ok_flecha: bool = _lr.cerrar_gesto(_trazos("flecha"))
	var en_hueco0: bool = false
	for comp in (_ficha()["components"] as Array):
		if (comp["direction"] as Vector2).is_equal_approx(Grimorio.dir_corona(0)) and (comp["sigils"] as Array).has("flecha"):
			en_hueco0 = true
	_ok("2 el trazo de ᛇ en el hueco 1 pone la flecha EN ESE hueco", ok_flecha and en_hueco0, lanzador.feedback_text)
	_ok("2 tras escribir, el destino pasa al siguiente hueco libre", _lr.destino == "hueco:1", _lr.destino)
	_ok("2 la cabecera tiene nombre (H16): «Flecha de fuego»", lanzador.nombre_pagina(lanzador.page) == "Flecha de fuego", lanzador.nombre_pagina(lanzador.page))

	# 3 · Un trazo que no se reconoce se queda.
	_lr.elegir_destino("hueco:1")
	# Un garabato largo (no «demasiado corto»): espiral que no es ninguna runa.
	var c0: Vector2 = _lr.zona_trazado()["centro"]
	var espiral := PackedVector2Array()
	for k in range(60):
		var a: float = float(k) * 0.45
		espiral.append(c0 + Vector2(cos(a), sin(a)) * (10.0 + float(k) * 2.0))
	var basura: Array = [espiral]
	var antes_rech: String = str(_ficha()["components"])
	var ok_basura: bool = _lr.cerrar_gesto(basura)
	_ok("3 un garabato no entra en la página", not ok_basura and str(_ficha()["components"]) == antes_rech)
	_ok("3 y el trazo se QUEDA para corregirlo, con un aviso", _lr._trazos.size() == 1 and _lr.aviso != "", _lr.aviso)

	# 4 · El orden de los glifos: dibujo (hoy) frente a huecos (§17.1). ᚠ en el hueco 3 dibujada ANTES que ᛇ en el hueco 1.
	lanzador.clear_sequence()
	_lr.elegir_destino("nucleo")
	_lr.cerrar_gesto(_trazos("fuego"))
	_lr.cambiar_orden(false)
	_lr.elegir_destino("hueco:2")
	var ok_rep: bool = _lr.cerrar_gesto(_trazos("repeticion"))
	_lr.elegir_destino("hueco:0")
	var ok_fl: bool = _lr.cerrar_gesto(_trazos("flecha"))
	_ok("4 ᚠ (hueco 3) y luego ᛇ (hueco 1) entran", ok_rep and ok_fl, lanzador.feedback_text)
	var h_dibujo: Hechizo = _hechizo_pagina()
	_ok("4 orden de DIBUJO: ᚠ antes que ᛇ, no hay ráfaga (copias a la vez)", h_dibujo != null and not h_dibujo.rafaga, str(h_dibujo.orden_glifos) if h_dibujo != null else "")
	_lr.cambiar_orden(true)
	var h_huecos: Hechizo = _hechizo_pagina()
	_ok("4 orden de HUECOS: ᛇ (hueco 1) antes que ᚠ (hueco 3) = ráfaga", h_huecos != null and h_huecos.rafaga, str(h_huecos.orden_glifos) if h_huecos != null else "")
	_ok("4 y queda guardado así en la página (Repertoire.paginas)", (Repertoire.paginas[lanzador.page]["glifos"] as Array) == ["flecha", "repeticion"], str(Repertoire.paginas[lanzador.page]["glifos"]))
	_lr.cambiar_orden(false)

	# 5 · Combinar dos sellos (estructura B) y separarlos.
	lanzador.clear_sequence()
	_lr.elegir_destino("nucleo")
	_lr.cerrar_gesto(_trazos("fuego"))
	_lr.elegir_destino("nucleo2")
	var ok_tierra: bool = _lr.cerrar_gesto(_trazos("tierra"))
	_ok("5 el segundo sello (ᛗ) se combina en el MISMO contorno: element2 = tierra", ok_tierra and lanzador._gesture_name_of(_ficha()["element2"]) == "tierra", lanzador.feedback_text)
	_ok("5 la combinación es la del libro avanzado: fuego + tierra = Magma", String(lanzador.rune_de_ficha(_ficha())["nombre"]) == "Magma", String(lanzador.rune_de_ficha(_ficha())["nombre"]))
	_ok("5 la transición de combinar arranca (≈ %.2f s)" % LibroRojo.T_COMBINAR, _lr._t_combinar >= 0.0 and LibroRojo.T_COMBINAR >= 0.6 and LibroRojo.T_COMBINAR <= 0.9)
	_ok("5 y los dos alojamientos se separan dentro del contorno", _lr.pos_sellos().size() == 2)
	_lr.separar_sellos()
	_ok("5 separar deja un solo sello y el libro de antes", int(_ficha()["element2"]) == Runes.Type.NONE and Repertoire.libro != "avanzado", Repertoire.libro)

	# 6 · Catálogo con la capacidad, y la maqueta de anidación.
	_ok("6 el catálogo enseña la capacidad (sellos y glifos)", _lr.texto_capacidad().begins_with("sellos ") and _lr.texto_capacidad().contains("glifos "), _lr.texto_capacidad())
	_lr._pulsar("catalogo")
	_ok("6 la pestaña abre el catálogo", _lr.catalogo_abierto)
	_lr._pulsar("catalogo")
	_lr._pulsar("anidacion")
	_ok("6 la anidación es solo maqueta: no toca la página", _lr.ver_anidacion and int(_ficha()["element2"]) == Runes.Type.NONE)
	_lr._pulsar("anidacion")

	# 7 · Lo escrito se lanza igual (el mismo Hechizo).
	lanzador.clear_sequence()
	_lr.elegir_destino("nucleo")
	_lr.cerrar_gesto(_trazos("fuego"))
	_lr.elegir_destino("hueco:0")
	_lr.cerrar_gesto(_trazos("flecha"))
	var esperado: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {"flecha": 1})
	var h_lib: Hechizo = _hechizo_pagina()
	_ok("7 el Hechizo de la página es el mismo que el de fuego + ᛇ construido a mano (daño, tinta, forma)", h_lib != null and is_equal_approx(h_lib.dano, esperado.dano) and is_equal_approx(h_lib.coste_tinta, esperado.coste_tinta) and h_lib.proyectil == esperado.proyectil)
	_lr.cerrar()
	await avanzar(3)
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	var salio: bool = lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT)
	_ok("7 y se LANZA con la página 1, como siempre", salio)

	# 8 · Las polilíneas de la tinta y los libros de siempre.
	var dentro: bool = true
	for n in ["fuego", "agua", "tierra", "flecha", "barrera", "repeticion", "linea_x", "suelo"]:
		var polis: Array = LibroRojo.polilineas(n)
		dentro = dentro and not polis.is_empty()
		for poli in polis:
			for q in poli:
				dentro = dentro and absf((q as Vector2).x) <= 0.5001 and absf((q as Vector2).y) <= 0.5001
	_ok("8 cada símbolo tiene sus trazos de tinta y caben en su caja", dentro)
	var sb: GDScript = load("res://presentacion/ui/spellbook.gd") as GDScript
	_ok("8 los libros de siempre siguen ahí («bosque» y «avanzado»)", (sb.get_script_constant_map()["LIBROS"] as Dictionary).has("bosque") and (sb.get_script_constant_map()["LIBROS"] as Dictionary).has("avanzado"))
	# 9 · (2.ª vuelta, 22/11) RECONOCIMIENTO: cada runa activa con temblor, pequeña y grande, se rectifica a la escala de la zona y se lee bien (antes, en crudo, 12/72).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bien: int = 0
	var total: int = 0
	var malos: PackedStringArray = []
	for fam in [["sello", Repertoire.active_elements()], ["glifo", Repertoire.active_sigils()]]:
		_lr.elegir_destino("nucleo" if fam[0] == "sello" else "hueco:0")
		for n in (fam[1] as PackedStringArray):
			if TrazosRectos.texto_guia(String(n), fam[0] == "sello") == "" or String(n) == "linea":
				continue
			for escala in [45.0, 90.0, 150.0]:
				var tr: Array = _trazos(String(n), escala, 3.0, rng)
				var lec: Dictionary = _lr._leer(_lr.preparar_trazos(tr))
				total += 1
				if bool(lec["accepted"]) and String(lec["name"]) == String(n):
					bien += 1
				elif not malos.has(n):
					malos.append(n)
	# Umbral: ≥ 95 % (medido: 268/270; ᛒ suelo, la runa de más tramos, falla alguna vez con temblor). Se imprime cuáles fallan.
	_ok("9 cada runa activa (pequeña, media y grande, con temblor) se reconoce tras rectificar: %d/%d (≥ 95 %%)" % [bien, total], total > 0 and float(bien) >= 0.95 * float(total), "fallan: " + ", ".join(malos))
	_lr.elegir_destino("hueco:0")
	lanzador.clear_sequence()
	_lr.cerrar_gesto(_trazos("barrera"))
	_ok("9 cada intento queda apuntado (PlayLog «libro_rojo_trazo»): qué se esperaba, qué se leyó y si entró", String(_lr.ultimo_intento.get("espera", "")) == "glifo" and String(_lr.ultimo_intento.get("leido", "")) == "barrera" and _lr.ultimo_intento.has("aceptado"), str(_lr.ultimo_intento))

	# 10 · AYUDA AL DIBUJO: practicar un símbolo del catálogo no lo inscribe.
	var antes_pr: String = str(_ficha()["components"])
	_lr._pulsar("catalogo")
	_lr._pulsar("practica:flecha")
	_ok("10 elegir un símbolo del catálogo lo pone en práctica y cierra el catálogo", _lr.practica == "flecha" and not _lr.catalogo_abierto)
	_ok("10 y NO lo inscribe en la página", str(_ficha()["components"]) == antes_pr)
	_lr._pulsar("sin_practica")
	_ok("10 «Quitar práctica» la quita", _lr.practica == "")
	# 10b · La HOJA DE CATÁLOGO (3.ª vuelta): familias fijas, candados, ficha y recientes.
	var todos: Array = LibroRojo.FAMILIA_FORMA + LibroRojo.FAMILIA_POTENCIA
	var en_tabla: bool = true
	for id in todos:
		en_tabla = en_tabla and Sigils.GLIFOS.has(Sigils.glifo_v2(String(id))) or String(id) == "linea" or String(id) == "altura"
	_ok("10b FORMA (9) y POTENCIA (5) son glifos del juego", LibroRojo.FAMILIA_FORMA.size() == 9 and LibroRojo.FAMILIA_POTENCIA.size() == 5 and en_tabla)
	_ok("10b FORMA son los que no suben el daño (B9a) y POTENCIA los que sí (salvo ᛃ, sin decidir)",
		LibroRojo.FAMILIA_POTENCIA.all(func(g): return Sigils.cuenta_dano(String(g))) and ["flecha", "pulso", "permanencia", "rebote", "buscar", "repeticion"].all(func(g): return not Sigils.cuenta_dano(String(g))))
	_ok("10b cada símbolo de las familias tiene su ficha", (LibroRojo.FAMILIA_SELLOS + todos).all(func(g): return LibroRojo.FICHAS.has(String(g))))
	_ok("10b lo que no se tiene sale bloqueado (ᛉ permanencia no está en el kit de pruebas)", not LibroRojo.conocido("permanencia") and LibroRojo.conocido("flecha"))
	var antes_cat: String = str(_ficha()["components"])
	_lr._pulsar("catalogo")
	_lr._pulsar("cat:barrera")
	_ok("10b clic en un símbolo elige su ficha, sin cerrar el catálogo ni inscribir", _lr.sel_catalogo == "barrera" and _lr.catalogo_abierto and str(_ficha()["components"]) == antes_cat)
	_lr._pulsar("cat:permanencia")
	_lr._pulsar("practicar_sel")
	_ok("10b «Practicar» no hace nada con un símbolo bloqueado", _lr.practica == "" and _lr.catalogo_abierto)
	_lr._pulsar("cat:barrera")
	_lr._pulsar("practicar_sel")
	_ok("10b «Practicar» con uno conocido lo lleva a la zona de trazado y cierra el catálogo", _lr.practica == "barrera" and not _lr.catalogo_abierto)
	_ok("10b y queda entre los recientes (la chuleta mínima, como mucho 4)", _lr.recientes.size() <= 4 and String(_lr.recientes[0]) == "barrera", str(_lr.recientes))
	_lr._pulsar("sin_practica")

	# 11 · ANIDACIÓN EDITABLE: sello y glifos del hijo, condición, tope de 6 en total, mover y guardar.
	lanzador.clear_sequence()
	_lr._pulsar("vaciar")
	_lr._pulsar("anidacion")
	_ok("11 la anidación se abre en modo editable", _lr.ver_anidacion)
	_lr.elegir_destino("nucleo")
	_ok("11 el texto dice qué círculo y qué hueco: «Principal · sello»", _lr.texto_destino() == "Principal · sello", _lr.texto_destino())
	_lr.cerrar_gesto(_trazos("fuego"))
	_lr.elegir_destino("hijo_nucleo")
	_ok("11 «Hijo · sello»", _lr.texto_destino() == "Hijo · sello", _lr.texto_destino())
	var ok_hijo: bool = _lr.cerrar_gesto(_trazos("agua"))
	_ok("11 el sello del hijo se dibuja y se escribe (agua)", ok_hijo and String(_lr.hijo()["elemento"]) == "agua", _lr.aviso)
	_lr.elegir_destino("hijo_hueco:1")
	_ok("11 «Hijo · hueco 2»", _lr.texto_destino() == "Hijo · hueco 2", _lr.texto_destino())
	var ok_hg: bool = _lr.cerrar_gesto(_trazos("barrera"))
	_ok("11 un glifo en el hueco 2 del hijo (barrera)", ok_hg and String((_lr.hijo()["glifos"] as Array)[1]) == "barrera", _lr.aviso)
	_lr.elegir_destino("hijo_hueco:2")
	var ok_hl: bool = _lr.cerrar_gesto([PackedVector2Array([Vector2(300, 400), Vector2(360, 400), Vector2(420, 400), Vector2(480, 400)])])
	_ok("11 la raya también vale en el hijo (ᛁ)", ok_hl and String((_lr.hijo()["glifos"] as Array)[2]).begins_with("linea"), str(_lr.hijo()["glifos"]))
	var cond0: String = _lr.condicion()
	_lr.siguiente_condicion()
	_ok("11 la condición se elige (al impactar → al acabar → a la vez)", cond0 == "al_impactar" and _lr.condicion() == "al_acabar", _lr.condicion())
	# El tope: 4 en el principal + 2 en el hijo = 6.
	for k in range(4):
		_lr.elegir_destino("hueco:%d" % k)
		_lr.cerrar_gesto(_trazos(["flecha", "repeticion", "rebote", "perforar"][k]))
	_ok("11 6 glifos en total (4 + 2)", _lr.n_glifos_total() == 6, "%d + %d" % [_lr.n_glifos_principal(), _lr.n_glifos_hijo()])
	_lr.elegir_destino("hijo_hueco:3")
	var ok_septimo: bool = _lr.cerrar_gesto(_trazos("flecha"))
	_ok("11 un séptimo glifo NO entra, con aviso de quitar o mover", not ok_septimo and _lr.aviso.contains("en total"), _lr.aviso)
	_lr.elegir_destino("hueco:0")
	var mov: bool = _lr.mover_glifo_al_otro_circulo()
	_ok("11 MOVER: la flecha del principal pasa al hijo y el total no cambia", mov and _lr.n_glifos_principal() == 3 and _lr.n_glifos_hijo() == 3 and (_lr.hijo()["glifos"] as Array).has("flecha"), str(_lr.hijo()["glifos"]))
	var mov2: bool = _lr.mover_glifo_al_otro_circulo()
	_ok("11 y de vuelta al principal", mov2 and _lr.n_glifos_principal() == 4 and _lr.n_glifos_hijo() == 2)
	_ok("11 se guarda en la página (Repertoire.paginas: hijo y condición)", (Repertoire.paginas[lanzador.page] as Dictionary).has("hijo") and String(Repertoire.paginas[lanzador.page]["condicion"]) == "al_acabar")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Repertoire.a_dic()))
	Repertoire.desde_dic(guardado)
	_ok("11 y sobrevive a guardar y cargar (desde_dic)", String((Repertoire.paginas[lanzador.page]["hijo"] as Dictionary)["elemento"]) == "agua")
	_ok("11 el principal sigue lanzándose como siempre (el hijo, no aún)", _hechizo_pagina() != null and _hechizo_pagina().elemento == "fuego")
	_lr._pulsar("vaciar")
	_ok("11 «Vaciar página» borra también el hijo", not (_ficha() as Dictionary).has("hijo") or String(_lr.hijo()["elemento"]) == "")
	_lr._pulsar("anidacion")

	# 12 · (5.ª vuelta) LAS NOTAS DEL PERSONAJE y EL CUADERNO.
	lanzador.clear_sequence()
	_lr.elegir_destino("nucleo")
	_ok("12 con el núcleo elegido, delante la hoja de SELLOS", _lr.tab_notas() == "sellos")
	_lr.elegir_destino("hueco:0")
	_ok("12 con un hueco, la de GLIFOS", _lr.tab_notas() == "glifos")
	_lr._pulsar("anidacion")
	_lr.elegir_destino("condicion")
	_ok("12 con el enlace, la de UNIÓN", _lr.tab_notas() == "union")
	_lr._pulsar("anidacion")
	_lr.elegir_destino("hueco:0")
	_ok("12 solo apunta lo que se conoce, y cuenta lo que falta", not _lr.ids_de_tab("glifos").has("permanencia") and _lr.ids_de_tab("glifos").has("flecha") and _lr.por_descubrir("glifos") >= 1, "faltan %d" % _lr.por_descubrir("glifos"))
	_ok("12 cada runa de las notas tiene su verbo", (_lr.ids_de_tab("sellos") + _lr.ids_de_tab("glifos")).all(func(g): return LibroRojo.VERBOS.has(String(g))))
	# En vivo: medio rombo (los dos primeros tramos de ◇) deja viva la barrera y apaga lo que ya no puede salir.
	var rombo: Array = _trazos("barrera")
	var medio := PackedVector2Array()
	var pts_r: PackedVector2Array = rombo[0]
	for j in range(int(pts_r.size() * 0.5)):
		medio.append(pts_r[j])
	_lr._trazos = [medio]
	_lr.actualizar_candidatos()
	var apagados: int = 0
	for g in _lr.ids_de_tab("glifos"):
		if not _lr.candidato_vivo(String(g)):
			apagados += 1
	_ok("12 a medio dibujar, la barrera sigue viva y otras se apagan", _lr.candidato_vivo("barrera") and apagados > 0, "apagadas %d" % apagados)
	_lr._trazos = rombo
	_lr.actualizar_candidatos()
	_ok("12 con el rombo entero, la barrera va ganando (✓)", _lr.candidato_lider() == "barrera", _lr.candidato_lider())
	_lr._trazos.clear()
	_lr.actualizar_candidatos()
	var c_esp: Vector2 = _lr.zona_trazado()["centro"]
	var esp := PackedVector2Array()
	for k in range(60):
		esp.append(c_esp + Vector2(cos(float(k) * 0.45), sin(float(k) * 0.45)) * (10.0 + float(k) * 2.0))
	_lr.cerrar_gesto([esp])
	_ok("12 el intento fallido queda para el TACHÓN, junto a la runa que parecía", not _lr.ultimo_rechazo.is_empty() and String(_lr.ultimo_rechazo["parece"]) != "" and String(_lr.ultimo_rechazo["tab"]) == "glifos", str(_lr.ultimo_rechazo.get("parece", "")))
	_lr._trazos.clear()
	_lr._trazo_rechazado = false
	_lr.aviso = ""
	# El cuaderno.
	_lr._pulsar("nota:barrera")
	_ok("12 un clic en una nota abre el CUADERNO en esa runa", _lr.catalogo_abierto and _lr.sel_catalogo == "barrera" and _lr.cuaderno_tab == "glifos")
	var antes_cu: String = str(_ficha()["components"])
	var pc: Vector2 = _lr.caja_practica().get_center()
	var esc_p: float = _lr.caja_practica().size.x * 0.6
	var prac: Array = []
	for poli in LibroRojo.polilineas("barrera"):
		var d := PackedVector2Array()
		for j in range(1, (poli as PackedVector2Array).size()):
			for k in range(8):
				d.append(pc + (poli[j - 1] as Vector2).lerp(poli[j], float(k) / 8.0) * esc_p)
		d.append(pc + (poli[poli.size() - 1] as Vector2) * esc_p)
		prac.append(d)
	_ok("12 practicar la barrera en el cuaderno: «¡Bien!»", _lr.evaluar_practica(prac) and _lr.prac_resultado.begins_with("¡Bien!"), _lr.prac_resultado)
	var prac_f: Array = []
	for poli in LibroRojo.polilineas("flecha"):
		var d2 := PackedVector2Array()
		for j in range(1, (poli as PackedVector2Array).size()):
			for k in range(8):
				d2.append(pc + (poli[j - 1] as Vector2).lerp(poli[j], float(k) / 8.0) * esc_p)
		d2.append(pc + (poli[poli.size() - 1] as Vector2) * esc_p)
		prac_f.append(d2)
	_ok("12 dibujar otra runa dice cuál es: «Eso es «Viaja», no «Solidez»»", not _lr.evaluar_practica(prac_f) and _lr.prac_resultado.contains("Viaja") and _lr.prac_resultado.contains("Solidez"), _lr.prac_resultado)
	_ok("12 practicar NO toca el conjuro", str(_ficha()["components"]) == antes_cu)
	_lr._pulsar("tabc:sellos")
	_ok("12 las pestañas del cuaderno cambian de hoja", _lr.cuaderno_tab == "sellos")
	_lr._pulsar("cerrar_cuaderno")
	_ok("12 «Cerrar» vuelve al libro", not _lr.catalogo_abierto)

	lanzador.clear_sequence()
	maqueta.queue_free()
	await avanzar(3)
	_ok("8 al salir del lab, Repertoire.libro vuelve a como estaba", Repertoire.libro == libro_inicial or Repertoire.libro != "avanzado", Repertoire.libro)
