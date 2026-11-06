extends SceneTree
## C1 punto 3 (2/11, lote 3 de la auditoría del 24/10, cambio 8): GUARDAR Y CARGAR LA PARTIDA ENTERA, ida y vuelta completa por el camino de «Continuar»
## (`Partida.extra_de` → `guardar` → limpiar todo → `preparar_carga` → `aplicar_continuar`, lo que hace `MenuPrincipal` + `PruebaTest2`).
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_partida_entera.gd
## Todo va a una carpeta de prueba que se borra al acabar (no toca user://partidas/).
##
## Mide, sección por sección, qué viaja: oro, bolsa, mejoras, tinta, flags, misiones, estadísticas, posición, vida, aguante, ropa, grimorio (sellos, glifos, páginas), recetas,
## y lo que ANTES no viajaba (C1): el ESTADO DEL SUELO (`EstadosSuelo3D`: mojado con lo que le queda, escarcha, quemado, segado, electrificado) y la HORA del ciclo de día.
## El hielo sobre agua NO se guarda (lo llevan `Terreno3D.poner_helada` y la simulación del agua). Un archivo anterior (sin `suelo` ni `hora_dia`) sigue cargando.

const CARPETA: String = "user://prueba_partida_entera/"
const NIVEL: String = "Bosque_prueba"
const SECCIONES: Array = ["version", "meta", "jugadora", "tinta", "bolsa", "mejoras", "grimorio", "recetas_conocidas", "estados", "flags", "mundo", "misiones", "estadisticas"]

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_borrar()
	Partida.carpeta = CARPETA
	Partida.ranura_actual = 1
	Partida.continuar = false
	_vaciar()
	await _ida_y_vuelta()
	_estados_suelo_solos()
	_archivo_antiguo()
	_borrar()
	Partida.carpeta = Partida.CARPETA_DEFECTO
	Partida.tinta = null
	Partida.mundo = {}
	_vaciar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _borrar() -> void:
	var dir_abs: String = ProjectSettings.globalize_path(CARPETA)
	if DirAccess.dir_exists_absolute(dir_abs):
		for f in DirAccess.get_files_at(dir_abs):
			DirAccess.remove_absolute(dir_abs.path_join(f))
		DirAccess.remove_absolute(dir_abs)


func _vaciar() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Repertoire.reset_to_p0()
	Repertoire.paginas = []
	Estadisticas.reiniciar()
	Partida.tinta = Tinta.new()
	Partida.recetas_conocidas = []
	Partida.mundo = {}
	Partida.tinta_pendiente = {}
	Terreno3D.estados.limpiar()
	CicloDia3D.HORA = 10.0


func _falso(codigo: String) -> Node3D:
	var s := GDScript.new()
	s.source_code = codigo
	s.reload()
	var n := Node3D.new()
	n.set_script(s)
	return n


func _poner_suelo() -> void:
	var e: EstadosSuelo3D = Terreno3D.estados
	e.poner(Vector2i(3, 4), EstadosSuelo3D.MOJADA, true)                       # 20 s de DURA
	e.avanzar(7.0)                                                              # le quedan 13
	e.poner(Vector2i(5, 5), EstadosSuelo3D.MOJADA, true, 0.5, 8.0)               # hierba mojada: 8 s, intensidad 0,5
	e.aplicar(Vector2i(6, 6), "frio")                                            # suelo → helada (escarcha)
	e.poner(Vector2i(8, 2), EstadosSuelo3D.QUEMADA, true)
	e.poner(Vector2i(9, 2), EstadosSuelo3D.SEGADA, true)
	e.poner(Vector2i(10, 2), EstadosSuelo3D.ELECTRIFICADA, true)
	e.poner(Vector2i(11, 11), EstadosSuelo3D.HELADA, true)                       # hielo sobre agua (no escarcha): NO se guarda


func _ida_y_vuelta() -> void:
	_poner_suelo()
	var e: Estado = Estado.i()
	e.oro = 143
	e.capacidad = 12
	e.items = {"pocion": 2, "baya": 7}
	e.mejoras = {"vida_max": 1}
	e.consumible_equipado = "pocion"
	Partida.tinta.actual = 62.0
	Partida.tinta.frascos = 2
	Flags.i().poner("bosque1.s1.cofre_01", "abierto")
	Flags.i().poner("bosque1.s3.antorchas", 3)
	Misiones.i().definir({"id": "m1", "titulo": "Goblins", "tipo": "principal", "objetivos": ["a", "b"]})
	Misiones.i().activar("m1")
	Misiones.i().objetivo_hecho("m1", 0)
	Estadisticas.desde_dic({"muertes": 3, "cofres": 5, "oro_ganado": 90})
	Repertoire.set_active(GestureLibrary.ELEMENTS.slice(0, 3), GestureLibrary.SIGILS.slice(0, 3))
	Repertoire.paginas = [{"elemento": "fuego", "glifos": ["flecha"]}]
	Partida.recetas_conocidas = ["pocion"]
	CicloDia3D.HORA = 17.25
	var misiones_antes: Dictionary = Misiones.i().a_dic()
	var sellos: Array = Array(Repertoire.active_elements())
	var suelo_antes: Dictionary = Terreno3D.estados.a_dic()

	# Un nivel y una jugadora de mentira con lo que `extra_de` y `aplicar_continuar` leen.
	var nivel := _falso("extends Node3D\nvar _jugador: Node3D\nvar nivel: String = \"%s\"\nfunc _celda_de(p):\n\treturn Vector2i(int(p.x), int(p.z))\nfunc ir_a(_c):\n\tpass\n" % NIVEL)
	root.add_child(nivel)
	var cuerpo := Node3D.new()
	cuerpo.position = Vector3(12.5, 0.25, 34.0)
	nivel.set("_jugador", cuerpo)
	nivel.add_child(cuerpo)
	var jug := _falso("extends Node3D\nsignal vida_cambiada(a, b)\nvar vida: float = 85.0\nvar aguante: float = 55.0\nvar pj = null\nvar puntos_inicio: Vector3 = Vector3.ZERO\nvar muerto: bool = false\n")
	nivel.add_child(jug)

	var extra: Dictionary = Partida.extra_de(nivel, jug, Vector2i(3, 4))
	_ok("1 guardar escribe la ranura", Partida.guardar(1, extra) and Partida.existe(1))
	var d0: Dictionary = Partida.leer(1)
	var faltan: PackedStringArray = []
	for s in SECCIONES:
		if not d0.has(s):
			faltan.append(s)
	_ok("1 el archivo trae todas las secciones", faltan.is_empty(), str(faltan))
	var suelo_guardado: Dictionary = (((d0.get("mundo", {}) as Dictionary).get(NIVEL, {}) as Dictionary).get("suelo", {}) as Dictionary)
	_ok("1 mundo.<nivel>.suelo trae el estado del suelo", not suelo_guardado.is_empty(), str(suelo_guardado))
	_ok("1 meta.hora_dia = 17,25", is_equal_approx(float((d0["meta"] as Dictionary).get("hora_dia", -1.0)), 17.25))
	_ok("1 el hielo sobre agua NO se guarda (solo escarcha)", not ((suelo_guardado.get("estados", {}) as Dictionary).get("helada", []) as Array).has([11, 11, 1.0, 0.0]) and ((suelo_guardado.get("estados", {}) as Dictionary).get("helada", []) as Array).size() == 1, str(suelo_guardado.get("estados", {})))

	# Otra partida: todo a cero, la jugadora en otro sitio.
	_vaciar()
	nivel.queue_free()
	await process_frame
	var nivel2 := _falso("extends Node3D\nvar _jugador: Node3D\nvar nivel: String = \"%s\"\nvar ido: Array = []\nfunc _celda_de(p):\n\treturn Vector2i(int(p.x), int(p.z))\nfunc ir_a(c):\n\tido.append(c)\n" % NIVEL)
	root.add_child(nivel2)
	var cuerpo2 := Node3D.new()
	nivel2.set("_jugador", cuerpo2)
	nivel2.add_child(cuerpo2)
	var jug2 := _falso("extends Node3D\nsignal vida_cambiada(a, b)\nvar vida: float = 100.0\nvar aguante: float = 100.0\nvar pj = null\nvar puntos_inicio: Vector3 = Vector3.ZERO\nvar muerto: bool = false\n")
	nivel2.add_child(jug2)
	_ok("2 tras vaciar no queda nada", Estado.i().oro == 0 and Flags.i().nombres().is_empty() and Terreno3D.estados.cuantas(EstadosSuelo3D.MOJADA) == 0 and is_equal_approx(CicloDia3D.HORA, 10.0))

	Partida.preparar_carga(1)                         # lo que hace MenuPrincipal al pulsar «Continuar»
	var cargo: bool = Partida.aplicar_continuar(nivel2, jug2)
	var est: Estado = Estado.i()
	_ok("2 aplicar_continuar carga y baja `continuar` (un solo uso)", cargo and not Partida.continuar and Partida.ranura_a_cargar == -1)
	_ok("2 oro, bolsa, mejoras y consumible", est.oro == 143 and est.capacidad == 12 and est.items == {"pocion": 2, "baya": 7} and est.mejoras == {"vida_max": 1} and est.consumible_equipado == "pocion")
	_ok("2 tinta (barra y frascos)", is_equal_approx(Partida.tinta.actual, 62.0) and Partida.tinta.frascos == 2)
	_ok("2 flags y misiones", Flags.i().valor("bosque1.s1.cofre_01") == "abierto" and Flags.i().valor("bosque1.s3.antorchas") == 3 and Misiones.i().a_dic() == misiones_antes)
	_ok("2 estadísticas", int(Estadisticas.a_dic().get("muertes", 0)) == 3 and int(Estadisticas.a_dic().get("cofres", 0)) == 5 and int(Estadisticas.a_dic().get("oro_ganado", 0)) == 90, str(Estadisticas.a_dic()))
	_ok("2 sellos, páginas y recetas", Array(Repertoire.active_elements()) == sellos and Repertoire.paginas.size() == 1 and Partida.recetas_conocidas == ["pocion"])
	_ok("2 vida y aguante de la jugadora", is_equal_approx(float(jug2.get("vida")), 85.0) and is_equal_approx(float(jug2.get("aguante")), 55.0))
	_ok("2 posición: la jugadora vuelve a su sitio", jug2.position.is_equal_approx(Vector3(12.5, 0.25, 34.0)) and cuerpo2.position.is_equal_approx(Vector3(12.5, 0.25, 34.0)))
	_ok("2 hora del ciclo de día", is_equal_approx(CicloDia3D.HORA, 17.25), str(CicloDia3D.HORA))
	var s: EstadosSuelo3D = Terreno3D.estados
	_ok("2 suelo: mojado con lo que le quedaba (13 s), la hierba mojada con su intensidad y 8 s", absf(s.queda(Vector2i(3, 4), EstadosSuelo3D.MOJADA) - 13.0) < 0.05 and absf(s.queda(Vector2i(5, 5), EstadosSuelo3D.MOJADA) - 8.0) < 0.05 and is_equal_approx(s.intensidad(Vector2i(5, 5), EstadosSuelo3D.MOJADA), 0.5),
		"%s %s" % [str(s.queda(Vector2i(3, 4), EstadosSuelo3D.MOJADA)), str(s.queda(Vector2i(5, 5), EstadosSuelo3D.MOJADA))])
	_ok("2 suelo: escarcha, quemado, segado y electrificado", s.es_escarcha(Vector2i(6, 6)) and s.tiene(Vector2i(8, 2), EstadosSuelo3D.QUEMADA) and s.tiene(Vector2i(9, 2), EstadosSuelo3D.SEGADA) and s.tiene(Vector2i(10, 2), EstadosSuelo3D.ELECTRIFICADA))
	_ok("2 suelo: el hielo sobre agua no vuelve", not s.tiene(Vector2i(11, 11), EstadosSuelo3D.HELADA))
	_ok("2 suelo: el diccionario es idéntico al de antes de guardar (menos el hielo de agua)", s.a_dic() == suelo_antes, "")
	# El reloj sigue corriendo sobre lo cargado: a los 13 s se seca la casilla.
	s.avanzar(13.1)
	# 6/11 (bloque A5): la quemada ya caduca (8 s), así que a los 13,1 s ya no está; lo que no caduca es la segada (DURA 0). Antes se comprobaba la quemada, que era permanente.
	_ok("2 y lo cargado sigue caducando: a los 13 s la casilla se seca, la quemada (8 s) se ha ido y la segada sigue", not s.tiene(Vector2i(3, 4), EstadosSuelo3D.MOJADA) and not s.tiene(Vector2i(8, 2), EstadosSuelo3D.QUEMADA) and s.tiene(Vector2i(9, 2), EstadosSuelo3D.SEGADA))
	nivel2.queue_free()
	await process_frame


func _estados_suelo_solos() -> void:
	var e := EstadosSuelo3D.new()
	var avisos: Array = []
	e.cambio.connect(func(c: Vector2i, est: String, si: bool) -> void: avisos.append([c, est, si]))
	e.poner(Vector2i(1, 1), EstadosSuelo3D.QUEMADA, true)
	e.desde_dic({"estados": {"mojada": [[2, 2, 1.0, 5.0]]}, "escarcha": []})
	_ok("3 desde_dic sustituye lo que había y avisa de lo que se va y de lo que llega", not e.tiene(Vector2i(1, 1), EstadosSuelo3D.QUEMADA) and e.tiene(Vector2i(2, 2), EstadosSuelo3D.MOJADA) and avisos.size() == 3, str(avisos))
	e.desde_dic({"estados": {"inventado": [[0, 0, 1.0, 0.0]], "quemada": "roto", "segada": [[1], [2, 3, 1.0, 0.0]]}, "escarcha": "roto"})
	_ok("3 un diccionario ilegible no rompe (estado desconocido, listas rotas)", e.cuantas(EstadosSuelo3D.QUEMADA) == 0 and e.cuantas(EstadosSuelo3D.SEGADA) == 1)
	e.desde_dic({})
	_ok("3 vacío = suelo limpio", e.cuantas(EstadosSuelo3D.SEGADA) == 0 and e.cuantas(EstadosSuelo3D.MOJADA) == 0)


func _archivo_antiguo() -> void:
	# Un archivo de antes de C1 (sin `suelo` ni `hora_dia`): carga, no toca el suelo ni la hora.
	_vaciar()
	CicloDia3D.HORA = 12.0
	Partida.guardar(2, {"mapa_actual": NIVEL, "posicion": Vector3.ZERO})
	var d: Dictionary = Partida.leer(2)
	(d["meta"] as Dictionary).erase("hora_dia")
	var fa := FileAccess.open(CARPETA + "ranura_2.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(d))
	fa.close()
	CicloDia3D.HORA = 15.0
	Terreno3D.estados.poner(Vector2i(1, 1), EstadosSuelo3D.QUEMADA, true)
	var cargado: Dictionary = Partida.cargar(2)
	_ok("4 un archivo sin `suelo` ni `hora_dia` carga", not cargado.is_empty() and is_equal_approx(CicloDia3D.HORA, 15.0))
	Terreno3D.estados.limpiar()
