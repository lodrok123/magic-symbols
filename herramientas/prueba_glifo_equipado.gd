extends SceneTree
## GLIFO EQUIPADO AL MOMENTO + PISTA DE USO INMEDIATO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4.5 H6) sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_glifo_equipado.gd
## Comprueba: `Grimorio.equipar_glifo_nuevo` (la página activa con sello y hueco; si no, la primera que cabe; con todas llenas no toca nada; el nombre automático se rehace y la partida lo guarda;
## el libro sigue anotando el glifo en `_por_escribir`); `PistaGlifo` (el texto del HUD con la tecla y el nombre, se va al lanzar un hechizo CON el glifo y no con uno sin él, con `reto=` solo con la
## flag, el marcador de `reto_en`, el destello, el registro `glifo_primer_uso`, que no sale en `modo_prueba`); la ceremonia (`_confirmar` + `_mostrar_pista`); y las claves `reto`/`reto_en` del parser de Puzle3D.

var _fallos: int = 0

## Un Grimorio con la señal que oye la pista y un `avisar` que apunta lo que se avisa (el Lanzador3D real las tiene; aquí no hace falta montar un nivel).
const FUENTE_LANZADOR: String = "extends Grimorio\nsignal glifos_lanzados(glifos: Array)\nvar avisos: Array = []\nfunc avisar(texto: String, _color: Color = Color.WHITE) -> void:\n\tavisos.append(texto)\n"


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _lanzador(paginas: Array, activa: int = 0) -> Grimorio:
	Repertoire.paginas = paginas
	var s := GDScript.new()
	s.source_code = FUENTE_LANZADOR
	s.reload()
	var g: Grimorio = s.new() as Grimorio
	root.add_child(g)
	g.page = activa
	return g


func _glifos_de(g: Grimorio, i: int) -> Array:
	var r: Array = []
	for c in (g.pages[i]["components"] as Array):
		r.append_array(c["sigils"])
	return r


func _log_contiene(buscar: String) -> bool:
	var dir: DirAccess = DirAccess.open(PlayLog.CARPETA)
	if dir == null:
		return false
	var mejor: String = ""
	for f in dir.get_files():
		if f.ends_with(".jsonl") and f > mejor:
			mejor = f
	if mejor == "":
		return false
	return FileAccess.get_file_as_string(PlayLog.CARPETA.path_join(mejor)).contains(buscar)


func _alfa_aro(p: PistaGlifo) -> float:
	return ((p.marcador.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a


func _initialize() -> void:
	await process_frame
	Flags.nuevo()
	Repertoire.activate_all()
	Repertoire.max_pages = 0
	Repertoire.max_sigils_per_page = 0
	Repertoire.libro = ""
	Repertoire.aim_with_mouse = false
	var paginas0: Array = Repertoire.paginas.duplicate(true)
	var mapa0: PackedStringArray = Terreno3D.mapa
	var propios0: bool = Terreno3D.datos_propios
	var filas: PackedStringArray = PackedStringArray()
	for _y in range(20):
		filas.append(".".repeat(24))
	Terreno3D.mapa = filas
	Terreno3D.datos_propios = true                 # un suelo llano para el marcador (y_pies)

	# 1 · La página ACTIVA, con sello y hueco: el glifo va ahí, queda seleccionada y su nombre automático cambia.
	Repertoire.lock_sigil("barrera")
	_ok("1 ᛜ barrera se consigue como nuevo", Repertoire.conseguir_sigil("barrera"))
	var g1: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": ["flecha"]}, {"elemento": "tierra", "glifos": ["flecha"]}], 0)
	await process_frame
	var nombre_antes: String = g1.nombre_pagina(0)
	var r1: int = g1.equipar_glifo_nuevo("barrera")
	_ok("1 devuelve la página activa (0)", r1 == 0, str(r1))
	_ok("1 la página 0 lleva la barrera además de la flecha", _glifos_de(g1, 0).has("barrera") and _glifos_de(g1, 0).has("flecha"), str(_glifos_de(g1, 0)))
	_ok("1 y sigue seleccionada", g1.page == 0)
	_ok("1 su nombre automático cambió («%s» → «%s»)" % [nombre_antes, g1.nombre_pagina(0)], g1.nombre_pagina(0) != nombre_antes and g1.nombre_pagina(0) != "")
	_ok("1 y la partida lo guarda (Repertoire.paginas)", ((Repertoire.paginas[0] as Dictionary)["glifos"] as Array).has("barrera"))
	_ok("1 el libro sigue anotando el glifo como nuevo (`_por_escribir`)", Repertoire.tomar_por_escribir().has("barrera"))
	_ok("1 un glifo que no está activo no se equipa", g1.equipar_glifo_nuevo("glifo_inventado") == -1)
	var g1b: Grimorio = _lanzador(Repertoire.paginas.duplicate(true), 0)
	await process_frame
	_ok("1 una recarga lo conserva con el mismo nombre", _glifos_de(g1b, 0).has("barrera") and g1b.nombre_pagina(0) == g1.nombre_pagina(0))
	g1.queue_free()
	g1b.queue_free()

	# 2 · La activa llena: va a la primera que cabe, y esa queda seleccionada.
	Repertoire.max_sigils_per_page = 2
	var g2: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha", "altura"]}, {"elemento": "agua", "glifos": ["flecha"]}, {"elemento": "tierra", "glifos": ["flecha"]}], 0)
	await process_frame
	var r2: int = g2.equipar_glifo_nuevo("barrera")
	_ok("2 con la activa llena va a la página 1", r2 == 1 and _glifos_de(g2, 1).has("barrera"), str(r2))
	_ok("2 la página 1 queda seleccionada", g2.page == 1)
	_ok("2 la llena no cambió", _glifos_de(g2, 0) == ["flecha", "altura"])
	var r2b: int = g2.equipar_glifo_nuevo("rebote")
	_ok("2 el siguiente ya no cabe en la 1 (2/2) y va a la 2", r2b == 2 and g2.page == 2, str(r2b))
	g2.queue_free()

	# 3 · a) Una página SIN glifos estrena su propio botón: sello + el glifo solo, y queda seleccionada.
	Repertoire.max_sigils_per_page = 0
	var g3: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "", "glifos": []}, {"elemento": "", "glifos": []}], 0)
	await process_frame
	var r3: int = g3.equipar_glifo_nuevo("barrera")
	_ok("3a con la activa ocupada y una página vacía, el glifo estrena la vacía (1)", r3 == 1 and g3.page == 1, str(r3))
	_ok("3a la receta es el sello de la activa (fuego) + el glifo SOLO", _glifos_de(g3, 1) == ["barrera"] and g3.pages[1]["element"] == g3.pages[0]["element"] and g3.pages[1]["element"] != Runes.Type.NONE)
	_ok("3a la página activa de antes no se tocó", _glifos_de(g3, 0) == ["flecha"])
	_ok("3a su nombre automático es el de la receta simple («%s»)" % g3.nombre_pagina(1), g3.nombre_pagina(1) == "Escudo de fuego")
	_ok("3a y se guarda con el sello", ((Repertoire.paginas[1] as Dictionary)["glifos"] as Array) == ["barrera"] and String((Repertoire.paginas[1] as Dictionary)["elemento"]) == "fuego")
	g3.queue_free()
	var g3b: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": []}, {"elemento": "", "glifos": []}], 0)
	await process_frame
	var r3b: int = g3b.equipar_glifo_nuevo("barrera")
	_ok("3a una página con solo sello conserva SU sello (agua) y recibe el glifo", r3b == 1 and _glifos_de(g3b, 1) == ["barrera"] and g3b.nombre_pagina(1) == "Escudo de agua", g3b.nombre_pagina(1))
	g3b.queue_free()
	# 3 · b) Sin ninguna página libre de glifos: lo de siempre (la activa con hueco, luego la siguiente).
	Repertoire.max_sigils_per_page = 3
	var g3c: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": ["flecha"]}, {"elemento": "tierra", "glifos": ["flecha"]}], 1)
	await process_frame
	var r3c: int = g3c.equipar_glifo_nuevo("barrera")
	_ok("3b sin páginas libres de glifos cae en la activa con hueco (1)", r3c == 1 and _glifos_de(g3c, 1) == ["flecha", "barrera"], str(r3c))
	g3c.queue_free()
	Repertoire.max_sigils_per_page = 0

	# 4 · Todas llenas (o sin sello): no cambia nada, ni la página seleccionada ni lo guardado.
	Repertoire.max_sigils_per_page = 2
	var llenas: Array = [{"elemento": "fuego", "glifos": ["flecha", "altura"]}, {"elemento": "agua", "glifos": ["flecha", "linea"]}, {"elemento": "tierra", "glifos": ["flecha", "altura"]}]
	var g4: Grimorio = _lanzador(llenas, 1)
	await process_frame
	var antes_json: String = JSON.stringify(Repertoire.paginas)
	var r4: int = g4.equipar_glifo_nuevo("barrera")
	_ok("4 con todas llenas devuelve -1", r4 == -1, str(r4))
	_ok("4 no cambia la página seleccionada", g4.page == 1)
	_ok("4 no toca las páginas ni lo guardado", JSON.stringify(Repertoire.paginas) == antes_json and _glifos_de(g4, 0) == ["flecha", "altura"] and _glifos_de(g4, 1) == ["flecha", "linea"])
	g4.queue_free()

	# 5 · Con el libro de sectores y el ratón (un glifo por hueco): respeta los huecos abiertos.
	Repertoire.aim_with_mouse = true
	Repertoire.libro = "bosque"
	Repertoire.max_sigils_per_page = 1
	var g5: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": []}, {"elemento": "", "glifos": []}], 0)
	await process_frame
	var r5: int = g5.equipar_glifo_nuevo("barrera")
	_ok("5 libro con 1 hueco por página: la 0 está llena y va a la 1", r5 == 1 and _glifos_de(g5, 1) == ["barrera"], str(r5))
	var r5b: int = g5.equipar_glifo_nuevo("rebote")
	var r5c: int = g5.equipar_glifo_nuevo("perforar")
	_ok("5 el siguiente estrena la página 2 (sin glifos, con el sello prestado de la activa) y el tercero ya no cabe", r5b == 2 and r5c == -1, str([r5b, r5c]))
	g5.queue_free()
	Repertoire.aim_with_mouse = false
	Repertoire.libro = ""
	Repertoire.max_sigils_per_page = 0

	# 6 · La pista (sin reto): HUD, lanzar sin y con el glifo.
	Flags.nuevo()
	var g6: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha", "barrera"]}, {"elemento": "agua", "glifos": ["flecha"]}, {"elemento": "", "glifos": []}], 1)
	await process_frame
	var hud: Control = Control.new()
	hud.set_script(load("res://presentacion/ui/page_hud.gd"))
	hud.size = Vector2(1280.0, 720.0)
	root.add_child(hud)
	var p6: PistaGlifo = PistaGlifo.crear(g6, "barrera", 0)
	_ok("6 la pista se crea", p6 != null and p6.is_inside_tree())
	await process_frame
	await process_frame
	var esperado: String = "Pulsa %s" % Controles.texto_teclas("pagina_1")
	_ok("6 el texto del HUD lleva solo la tecla real (el nombre sale debajo) («%s»)" % esperado, p6.texto_hud() == esperado and p6.texto_hud().contains(Controles.texto_teclas("pagina_1")))
	_ok("6 el HUD la pinta encima de las pestañas", String(hud.get("ultima_pista")) == esperado, "«%s»" % str(hud.get("ultima_pista")))
	_ok("6 la pista tiene el color de la runa y su textura", p6.color() == LaminaGlifo.color_de("barrera") and p6.textura() != null)
	g6.glifos_lanzados.emit(["flecha", "altura"])
	await process_frame
	_ok("6 un hechizo SIN el glifo no la quita", not p6.cumplido and p6.texto_hud() != "")
	g6.glifos_lanzados.emit(["flecha", "barrera"])
	_ok("6 un hechizo CON el glifo la cumple", p6.cumplido and p6.texto_hud() == "")
	_ok("6 anota los segundos desde que se obtuvo", p6.segundos_al_cumplir >= 0.0)
	await process_frame
	await process_frame
	_ok("6 el HUD deja de pintarla", String(hud.get("ultima_pista")) == "")
	_ok("6 PlayLog recibió glifo_primer_uso del glifo barrera", _log_contiene("\"evento\":\"glifo_primer_uso\"") and _log_contiene("\"glifo\":\"barrera\""))
	await create_timer(PistaGlifo.T_DESTELLO + 0.3).timeout
	_ok("6 sin marcador, tras el destello de la pestaña, la pista se retira sola", not is_instance_valid(p6))
	# Alias: ᛏ levitacion vale como altura; linea_x como linea.
	var pa: PistaGlifo = PistaGlifo.crear(g6, "altura", 0)
	g6.glifos_lanzados.emit(["levitacion"])
	_ok("6 un hechizo con ᛏ levitacion cumple la pista de altura", pa.cumplido)
	await create_timer(PistaGlifo.T_DESTELLO + 0.3).timeout
	var pl: PistaGlifo = PistaGlifo.crear(g6, "linea", 0)
	g6.glifos_lanzados.emit(["linea_x"])
	_ok("6 un hechizo con linea_x cumple la pista de línea", pl.cumplido)
	await create_timer(PistaGlifo.T_DESTELLO + 0.3).timeout

	# 7 · Con reto=: no se va al lanzar, sino con la flag. Y el marcador de reto_en.
	var reto: String = "gruta.g6.atajo"
	var celda := Vector2i(9, 13)
	var p7: PistaGlifo = PistaGlifo.crear(g6, "barrera", 0, reto, celda)
	await process_frame
	await process_frame
	_ok("7 el marcador de reto_en existe, en el suelo de la casilla", p7.marcador != null and p7.marcador.is_inside_tree()
		and absf(p7.marcador.global_position.x - Terreno3D.centro_de(celda).x) < 0.01 and absf(p7.marcador.global_position.z - Terreno3D.centro_de(celda).z) < 0.01)
	_ok("7 lleva un aro y la runa, del color de la runa", p7.marcador.get_child_count() == 2 and ((p7.marcador.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(p7.color(), _alfa_aro(p7))))
	var a0: float = _alfa_aro(p7)
	await create_timer(0.9).timeout
	var a1: float = _alfa_aro(p7)
	_ok("7 late despacio (su opacidad cambia: %.2f → %.2f)" % [a0, a1], absf(a1 - a0) > 0.02 and a0 > 0.2 and a1 > 0.2)
	g6.glifos_lanzados.emit(["flecha", "barrera"])
	await process_frame
	_ok("7 con reto, lanzar con el glifo NO la quita", not p7.cumplido and p7.texto_hud() != "" and p7.marcador != null)
	Flags.i().poner(reto)
	await process_frame
	await process_frame
	_ok("7 al ponerse la flag del reto, se cumple", p7.cumplido and p7.texto_hud() == "")
	_ok("7 y el marcador sigue un instante (el destello)", is_instance_valid(p7) and p7.marcador != null)
	await create_timer(PistaGlifo.T_DESTELLO + 0.3).timeout
	_ok("7 el marcador y la pista ya no están", not is_instance_valid(p7))
	_ok("7 el registro lleva el reto", _log_contiene("\"reto\":\"gruta.g6.atajo\""))
	_ok("7 si la flag ya estaba puesta no hay pista que enseñar", PistaGlifo.crear(g6, "barrera", 0, reto, celda) == null)

	# 8 · La ceremonia: equipa y deja la pista al cerrarse; en modo_prueba no hace nada de esto.
	Flags.nuevo()
	Repertoire.lock_sigil("rebote")
	var g8: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "", "glifos": []}, {"elemento": "", "glifos": []}], 0)
	await process_frame
	var c8 := CeremoniaCofre3D.new()
	root.add_child(c8)
	c8.glifo = "rebote"
	c8._lanz = g8
	c8.reto = "gruta.g6.atajo"
	c8.reto_en = Vector2i(9, 13)
	c8._confirmar()
	_ok("8 la ceremonia entrega el glifo nuevo y lo equipa en la página 1 (la primera sin glifos)", c8.glifo_nuevo and c8.pagina_equipada == 1 and _glifos_de(g8, 1) == ["rebote"], str(c8.pagina_equipada))
	_ok("8 el libro lo sigue teniendo por escribir", Repertoire.tomar_por_escribir().has("rebote"))
	c8._mostrar_pista()
	await process_frame
	_ok("8 al cerrarse deja la pista con su reto y su marcador", c8.pista != null and c8.pista.reto == "gruta.g6.atajo" and c8.pista.marcador != null and c8.pista.pagina == 1)
	c8.pista.queue_free()
	var c8b := CeremoniaCofre3D.new()
	root.add_child(c8b)
	c8b.glifo = "rebote"
	c8b._lanz = g8
	c8b._confirmar()
	_ok("8 un glifo que ya se tenía no se vuelve a equipar", not c8b.glifo_nuevo and c8b.pagina_equipada == -1)
	c8b._mostrar_pista()
	_ok("8 …y no hay pista", c8b.pista == null)
	Repertoire.lock_sigil("perforar")
	var c8c := CeremoniaCofre3D.new()
	root.add_child(c8c)
	c8c.glifo = "perforar"
	c8c.modo_prueba = true
	c8c._lanz = g8
	var json_antes: String = JSON.stringify(Repertoire.paginas)
	c8c._confirmar()
	c8c._mostrar_pista()
	_ok("8 en modo_prueba no equipa, no da el glifo y no hay pista", c8c.pagina_equipada == -1 and c8c.pista == null and JSON.stringify(Repertoire.paginas) == json_antes and not Repertoire.sigil_active("perforar"))
	# Sin sitio: el aviso de siempre, no toca nada.
	Repertoire.max_sigils_per_page = 2
	var g8d: Grimorio = _lanzador([{"elemento": "fuego", "glifos": ["flecha", "altura"]}, {"elemento": "agua", "glifos": ["flecha", "altura"]}, {"elemento": "tierra", "glifos": ["flecha", "altura"]}], 0)
	await process_frame
	Repertoire.lock_sigil("buscar")
	var c8d := CeremoniaCofre3D.new()
	root.add_child(c8d)
	c8d.glifo = "buscar"
	c8d._lanz = g8d
	var json_d: String = JSON.stringify(Repertoire.paginas)
	c8d._confirmar()
	_ok("8 sin sitio: no toca las páginas (pagina_equipada = -1)", c8d.glifo_nuevo and c8d.pagina_equipada == -1 and JSON.stringify(Repertoire.paginas) == json_d)
	c8d._mostrar_pista()
	_ok("8 sin sitio: tampoco hay pista", c8d.pista == null)
	await create_timer(2.7).timeout
	_ok("8 sin sitio: avisa «Escríbelo en el libro (%s)»" % Controles.texto_teclas("libro"), g8d.get("avisos").has("Escríbelo en el libro (%s)" % Controles.texto_teclas("libro")), str(g8d.get("avisos")))
	Repertoire.max_sigils_per_page = 0

	# 9 · El parser de Puzle3D conoce reto / reto_en, y el Lanzador3D real tiene la señal que oye la pista.
	var claves: Variant = null
	var mapa_const: Dictionary = (load("res://escenas/puzle.gd") as GDScript).get_script_constant_map()
	for k in mapa_const:
		var v: Variant = mapa_const[k]
		if v is Dictionary and (v as Dictionary).has("brasero") and (v as Dictionary).has("cofre"):
			claves = v
	_ok("9 la tabla de claves por tipo trae reto (flag) y reto_en (celdas) para el cofre", claves != null and ((claves as Dictionary)["cofre"] as Dictionary).get("reto", "") == "flag" and ((claves as Dictionary)["cofre"] as Dictionary).get("reto_en", "") == "celdas")
	var senales: Array = (load("res://magia/lanzador_3d.gd") as GDScript).get_script_signal_list()
	_ok("9 Lanzador3D tiene la señal glifos_lanzados", senales.any(func(s): return String(s["name"]) == "glifos_lanzados"))
	_ok("9 las claves nuevas pasan por Puzle3D._valor (flag y casilla)", _parsear_cofre())

	Repertoire.paginas = paginas0
	Terreno3D.mapa = mapa0
	Terreno3D.datos_propios = propios0
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Las claves nuevas del cofre pasan por `Puzle3D._valor` como una flag y una lista de casillas.
func _parsear_cofre() -> bool:
	var P: GDScript = load("res://escenas/puzle.gd") as GDScript
	var f: Array = P.call("_valor", "flag", "gruta.g6.atajo")
	var c: Array = P.call("_valor", "celdas", "9,13")
	var mala: Array = P.call("_valor", "flag", "atajo")
	return bool(f[0]) and bool(c[0]) and (c[1] as Array)[0] == Vector2i(9, 13) and not bool(mala[0])
