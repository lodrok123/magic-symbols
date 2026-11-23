extends SceneTree
## M1 · CIFRAS DEL LIBRO (22/11, docs/PLAN_HECHIZOS_2026-11-22.md §9) sin ventana. Lo escribe la sesión HECHIZOS.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_cifras_libro.gd
## Comprueba: aperturas y tiempo abierto, páginas reescritas (solo las que cambian de receta), lanzamientos por página y receta, encuentros con
## más de una página, trazos reconocidos y no, intentos en combate, el guardado (a_dic / desde_dic, también un archivo sin `libro`), que
## `cerrar_nivel` vacía lo del nivel y no el total, y que los scripts enganchados cargan.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Estadisticas.reiniciar()
	var paginas0: Array = Repertoire.paginas.duplicate(true)

	# 1 · Abrir y cerrar sin tocar nada.
	Repertoire.paginas = [{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "", "glifos": []}, {"elemento": "", "glifos": []}]
	Estadisticas.libro_abierto()
	Estadisticas.libro_abierto()            # una segunda llamada con el libro abierto no cuenta otra apertura
	OS.delay_msec(300)                       # tiempo de PARED (el libro pausa el árbol: se mide con Time.get_ticks_msec, no con el reloj del juego)
	Estadisticas.libro_cerrado()
	var l: Dictionary = Estadisticas.total["libro"]
	_ok("1 una apertura", int(l["aperturas"]) == 1, str(l["aperturas"]))
	_ok("1 segundos abierto ≈ 0,3", float(l["seg_abierto"]) > 0.2 and float(l["seg_abierto"]) < 1.0, "%.2f" % float(l["seg_abierto"]))
	_ok("1 sin cambios no hay páginas reescritas", int(l["paginas_reescritas"]) == 0 and float(l["seg_dibujando"]) == 0.0)

	# 2 · Abrir, reescribir la 1 y estrenar la 2.
	Estadisticas.libro_abierto()
	Repertoire.paginas = [{"elemento": "fuego", "glifos": ["flecha", "flecha"]}, {"elemento": "agua", "glifos": ["barrera"]}, {"elemento": "", "glifos": []}]
	Estadisticas.libro_cerrado()
	_ok("2 dos páginas reescritas", int(l["paginas_reescritas"]) == 2, str(l["paginas_reescritas"]))
	_ok("2 dos aperturas", int(l["aperturas"]) == 2)
	_ok("2 segundos por página > 0", Estadisticas.seg_por_pagina(Estadisticas.total) >= 0.0)
	_ok("2 cerrar con el libro ya cerrado no hace nada", (func() -> bool: Estadisticas.libro_cerrado(); return int(l["aperturas"]) == 2 and int(l["paginas_reescritas"]) == 2).call())
	_ok("2 la misma receta en otro orden de claves no cuenta", Estadisticas.paginas_distintas([{"glifos": ["flecha"], "elemento": "fuego"}], [{"elemento": "fuego", "glifos": ["flecha"]}]) == 0)
	_ok("2 el orden de los glifos sí cuenta (es otra receta: ráfaga)", Estadisticas.paginas_distintas([{"elemento": "fuego", "glifos": ["flecha", "repeticion"]}], [{"elemento": "fuego", "glifos": ["repeticion", "flecha"]}]) == 1)

	# 3 · Lanzamientos y encuentros.
	Estadisticas.contar_lanzamiento(1, "fuego", ["flecha"])                 # fuera de encuentro
	Estadisticas.empieza_encuentro()
	Estadisticas.contar_lanzamiento(1, "fuego", ["flecha"])
	Estadisticas.contar_lanzamiento(1, "fuego", ["flecha"])
	Estadisticas.acaba_encuentro()                                          # solo la página 1
	Estadisticas.empieza_encuentro()
	Estadisticas.empieza_encuentro()                                        # repetido: no cuenta otro
	Estadisticas.contar_lanzamiento(1, "fuego", ["flecha"])
	Estadisticas.contar_lanzamiento(2, "agua", ["barrera"])
	Estadisticas.acaba_encuentro()                                          # páginas 1 y 2
	_ok("3 por página: la 1 cinco veces y la 2 una", int((l["por_pagina"] as Dictionary).get("1", 0)) == 4 and int((l["por_pagina"] as Dictionary).get("2", 0)) == 1, str(l["por_pagina"]))
	_ok("3 por receta", int((l["por_receta"] as Dictionary).get("fuego:flecha", 0)) == 4 and int((l["por_receta"] as Dictionary).get("agua:barrera", 0)) == 1, str(l["por_receta"]))
	_ok("3 dos encuentros, uno con más de una página", int(l["encuentros"]) == 2 and int(l["encuentros_varias"]) == 1, "%d / %d" % [int(l["encuentros"]), int(l["encuentros_varias"])])
	_ok("3 cuota de la página más usada = 4/5", is_equal_approx(Estadisticas.cuota_pagina_mas_usada(Estadisticas.total), 0.8), "%.2f" % Estadisticas.cuota_pagina_mas_usada(Estadisticas.total))

	# 4 · Trazos e intentos en combate.
	Estadisticas.contar_trazo(true)
	Estadisticas.contar_trazo(true)
	Estadisticas.contar_trazo(false)
	Estadisticas.contar_intento_libro_en_combate()
	_ok("4 dos trazos reconocidos y uno no", int(l["trazos_reconocidos"]) == 2 and int(l["trazos_rechazados"]) == 1)
	_ok("4 un intento de abrir el libro en combate", int(l["intentos_combate"]) == 1)
	var filas: Array = Estadisticas.filas_libro(Estadisticas.total)
	_ok("4 filas_libro da 10 líneas y la de trazos dice «1 de 3 (33 %)»", filas.size() == 10 and String(filas[8][1]) == "1 de 3 (33 %)", str(filas[8]))
	_ok("4 lo mismo va en las cifras del nivel", int((Estadisticas.por_nivel["libro"] as Dictionary)["aperturas"]) == 2)

	# 5 · Guardado.
	var d: Dictionary = Estadisticas.a_dic()
	var texto: String = JSON.stringify(d)
	Estadisticas.reiniciar()
	_ok("5 reiniciar deja el libro a cero", int((Estadisticas.total["libro"] as Dictionary)["aperturas"]) == 0)
	Estadisticas.desde_dic(JSON.parse_string(texto))
	var l2: Dictionary = Estadisticas.total["libro"]
	_ok("5 desde_dic (tras JSON) recupera aperturas, reescritas y encuentros", int(l2["aperturas"]) == 2 and int(l2["paginas_reescritas"]) == 2 and int(l2["encuentros_varias"]) == 1)
	_ok("5 y las tablas por página y receta, como enteros", int((l2["por_pagina"] as Dictionary)["1"]) == 4 and typeof((l2["por_receta"] as Dictionary)["fuego:flecha"]) == TYPE_INT)
	Estadisticas.desde_dic({"enemigos": {}, "segundos": 10.0})
	_ok("5 un archivo sin `libro` (anterior a M1) deja el libro a cero", int((Estadisticas.total["libro"] as Dictionary)["aperturas"]) == 0 and (Estadisticas.total["libro"] as Dictionary).has("por_receta"))

	# 6 · Cerrar nivel.
	Estadisticas.reiniciar()
	Estadisticas.libro_abierto()
	Estadisticas.libro_cerrado()
	var nivel: Dictionary = Estadisticas.cerrar_nivel()
	_ok("6 cerrar_nivel entrega el libro del nivel", int((nivel["libro"] as Dictionary)["aperturas"]) == 1)
	_ok("6 y lo vacía, sin tocar el total", int((Estadisticas.por_nivel["libro"] as Dictionary)["aperturas"]) == 0 and int((Estadisticas.total["libro"] as Dictionary)["aperturas"]) == 1)

	# 7 · Los scripts enganchados cargan (un error de sintaxis en ellos rompería el juego, no esta prueba).
	for ruta in ["res://presentacion/ui/spellbook.gd", "res://magia/lanzador_3d.gd", "res://presentacion/sensacion_3d.gd"]:
		var s: Script = load(ruta) as Script
		_ok("7 carga %s" % ruta, s != null and s.can_instantiate())
		var src: String = FileAccess.get_file_as_string(ruta)
		_ok("7 %s llama a Estadisticas (M1)" % ruta.get_file(), src.contains("Estadisticas.libro_abierto") or src.contains("Estadisticas.contar_lanzamiento") or src.contains("Estadisticas.empieza_encuentro"))

	Repertoire.paginas = paginas0
	Estadisticas.reiniciar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
