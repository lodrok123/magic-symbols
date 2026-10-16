extends SceneTree

## PRUEBA DE LAS MISIONES (Fase 14.3, 16/10, Juego): los DATOS, sin ventana. `tools\prueba_una.cmd prueba_misiones`.
## Define, activa, marca objetivos, completa, paga la recompensa una sola vez, sigue una misión, y guarda y carga sin perder nada.

var fallos: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


func _init() -> void:
	var cambios: Array = []
	var seguidas: Array = []
	var M: Misiones = Misiones.nuevo()
	M.mision_cambio.connect(func(id: String) -> void: cambios.append(id))
	M.seguida_cambio.connect(func(id: String) -> void: seguidas.append(id))
	Estado.nuevo()

	print("== Definir")
	M.definir({"id": "a", "titulo": "Las cuatro tareas", "tipo": "principal", "texto": "El guardabosques pide ayuda.", "origen": "Guardabosques",
		"objetivos": ["Pisar la baldosa", "Matar a los goblins", "Hablar"], "recompensa": {"oro": 50, "items": {"pocion": 2}}})
	M.definir({"id": "b", "titulo": "Una flor", "objetivos": ["Coger la flor"]})
	M.definir({"id": "c", "titulo": "Sin objetivos", "tipo": "secundaria"})
	_ok(M.existe("a") and M.existe("b") and M.existe("c") and not M.existe("z"), "existen las tres misiones definidas")
	_ok(M.estado("a") == "oculta", "una misión nace oculta")
	_ok(M.ids().is_empty(), "las ocultas no salen en la lista normal")
	_ok(M.ids("oculta").size() == 3, "pero se pueden pedir por estado")
	_ok(M.get_mision("b")["tipo"] == "secundaria", "el tipo por defecto es secundaria")
	var copia: Dictionary = M.get_mision("a")
	copia["titulo"] = "tocado"
	_ok(M.get_mision("a")["titulo"] == "Las cuatro tareas", "get_mision devuelve una copia")
	_ok(cambios.size() == 3, "cada definición avisa (mision_cambio): %d" % cambios.size())

	print("== Activar y seguir")
	M.activar("a")
	_ok(M.estado("a") == "activa", "activar la pasa a activa")
	_ok(M.seguida_id() == "a" and seguidas == ["a"], "la primera que se activa pasa a ser la seguida")
	M.activar("b")
	_ok(M.seguida_id() == "a", "activar otra no le quita el seguimiento")
	_ok(M.linea_hud() == "Las cuatro tareas · Pisar la baldosa", "la línea del HUD: título · objetivo actual (%s)" % M.linea_hud())
	M.seguir("c")
	_ok(M.seguida_id() == "a", "una misión que no está activa no se puede seguir")
	M.seguir("b")
	_ok(M.seguida_id() == "b" and M.linea_hud() == "Una flor · Coger la flor", "se puede cambiar la seguida")
	M.seguir("a")

	print("== Objetivos")
	var antes: int = cambios.size()
	_ok(M.objetivo_hecho("a", 0), "marcar un objetivo devuelve true")
	_ok(not M.objetivo_hecho("a", 0), "marcarlo otra vez no cambia nada")
	_ok(cambios.size() == antes + 1, "y solo avisa la primera vez")
	_ok(M.progreso("a") == Vector2i(1, 3), "progreso 1/3")
	_ok(M.linea_hud() == "Las cuatro tareas · Matar a los goblins", "la línea pasa al siguiente objetivo pendiente")
	M.objetivo_texto("a", 1, "Matar a los goblins (2/3)")
	_ok(M.objetivo_actual("a") == "Matar a los goblins (2/3)", "el texto de un objetivo con cuenta se puede cambiar")
	_ok(not M.objetivo_hecho("a", 9) and not M.objetivo_hecho("zz", 0), "índices o ids que no existen no rompen nada")
	var oro0: int = Estado.i().oro
	M.objetivo_hecho("a", 1)
	_ok(M.estado("a") == "activa" and M.progreso("a") == Vector2i(2, 3), "con 2 de 3 sigue activa")
	M.objetivo_hecho("a", 2)
	_ok(M.estado("a") == "completa", "al hacer el último objetivo se completa sola")
	_ok(Estado.i().oro == oro0 + 50 and Estado.i().cuenta("pocion") == 2, "paga la recompensa: +50 de oro y 2 pociones (oro %d, pociones %d)" % [Estado.i().oro, Estado.i().cuenta("pocion")])
	M.completar("a")
	_ok(Estado.i().oro == oro0 + 50, "completar otra vez NO vuelve a pagar")
	_ok(not M.objetivo_hecho("a", 0, false), "una misión completa no se reabre desmarcando un objetivo")
	_ok(M.seguida_id() == "b", "al completar la seguida se sigue la siguiente activa sola")
	M.completar("b")
	_ok(M.seguida_id() == "" and M.linea_hud() == "", "sin misiones activas el HUD no enseña nada")
	M.activar("c")
	M.completar("c")
	_ok(M.estado("c") == "completa", "una misión sin objetivos se completa a mano")

	print("== Lista del diario")
	M.definir({"id": "d", "titulo": "Principal nueva", "tipo": "principal", "estado": "activa", "objetivos": ["x"]})
	M.definir({"id": "e", "titulo": "Secundaria nueva", "estado": "activa", "objetivos": ["y"]})
	var lista: Array = M.lista_para_diario()
	_ok(lista == ["d", "a", "e", "b", "c"], "principales antes que secundarias; activas antes que completas: %s" % str(lista))

	print("== Guardado y carga")
	var ruta: String = "user://prueba_misiones.json"
	M.objetivo_hecho("e", 0, false)
	M.seguir("d")
	_ok(M.guardar(ruta), "guarda en %s" % ruta)
	var M2: Misiones = Misiones.nuevo()
	_ok(M2.cargar(ruta), "carga lo guardado en una instancia nueva")
	_ok(M2.ids() == M.ids() and M2.lista_para_diario() == lista, "mismas misiones y mismo orden")
	_ok(M2.estado("a") == "completa" and M2.estado("d") == "activa", "mismos estados")
	_ok(M2.get_mision("a")["objetivos"][2]["hecho"] == true and M2.progreso("a") == Vector2i(3, 3), "mismos objetivos hechos")
	_ok(M2.seguida_id() == "d", "misma misión seguida")
	_ok(M2.get_mision("a")["recompensa"] == {"oro": 50, "items": {"pocion": 2}} and typeof(M2.get_mision("a")["recompensa"]["oro"]) == TYPE_INT, "la recompensa vuelve con sus tipos (int, no float)")
	_ok(typeof(M2.get_mision("a")["orden"]) == TYPE_INT, "el orden vuelve como int")
	var oro1: int = Estado.i().oro
	M2.completar("a")
	_ok(Estado.i().oro == oro1, "una misión pagada antes de guardar no se vuelve a pagar tras cargar")
	_ok(not Misiones.nuevo().cargar("user://no_existe_jamas.json"), "cargar un archivo que no existe devuelve false y no rompe")

	print("== Un nivel que se redefine tras cargar conserva el progreso; sin cargar, empieza limpio")
	M2.definir({"id": "a", "titulo": "Las cuatro tareas (texto nuevo)", "tipo": "principal", "objetivos": ["Pisar la baldosa", "Matar a los goblins", "Hablar"]})
	_ok(M2.estado("a") == "completa" and M2.progreso("a") == Vector2i(3, 3), "tras cargar, definir conserva estado y objetivos hechos")
	_ok(M2.get_mision("a")["titulo"] == "Las cuatro tareas (texto nuevo)", "pero refresca el texto")
	M2.definir({"id": "a", "titulo": "Otra vez", "tipo": "principal", "objetivos": ["Pisar la baldosa", "Matar a los goblins", "Hablar"]})
	_ok(M2.estado("a") == "oculta" and M2.progreso("a") == Vector2i(0, 3), "la segunda definición (ya no viene del guardado) empieza limpia")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))

	await _diario()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


## La pantalla (J) y la línea del HUD, por código: leen de Misiones, se mueven con el teclado y pausan el mundo.
func _diario() -> void:
	print("== Diario (pantalla) y HUD")
	var M: Misiones = Misiones.nuevo()
	M.definir({"id": "p1", "titulo": "Principal uno", "tipo": "principal", "texto": "Habla con el guardabosques en el claro.", "origen": "Guardabosques",
		"objetivos": ["Hablar", "Volver"], "recompensa": {"oro": 25}})
	M.definir({"id": "s1", "titulo": "Secundaria uno", "objetivos": ["Cosa"]})
	M.definir({"id": "s2", "titulo": "Secundaria oculta"})
	M.activar("p1")
	M.activar("s1")
	var d := DiarioMisiones.new()
	root.add_child(d)
	var hud := MisionHud.new()
	root.add_child(hud)
	await process_frame
	_ok(hud.visible and hud.text == "◆ Principal uno · Hablar", "la línea del HUD enseña la seguida: «%s»" % hud.text)
	var filas: Array = d.filas()
	_ok(filas.size() == 2 and filas[0]["id"] == "p1" and filas[1]["id"] == "s1", "la lista no enseña la oculta y pone la principal primero")
	_ok(filas[0]["seguida"] and not filas[1]["seguida"], "la fila de la seguida va marcada")
	_ok(d.seleccionada == "p1", "se abre con la primera seleccionada")
	var f: Dictionary = d.ficha("p1")
	_ok(f["titulo"] == "Principal uno" and f["origen"] == "Guardabosques" and f["recompensa"] == "25 de oro" and f["objetivos"].size() == 2, "la ficha trae título, origen, recompensa y objetivos")
	d.mover(1)
	_ok(d.seleccionada == "s1", "↓ pasa a la siguiente")
	d.mover(1)
	_ok(d.seleccionada == "s1", "y no da la vuelta por abajo")
	d.alternar_seguida()
	_ok(M.seguida_id() == "s1" and hud.text == "◆ Secundaria uno · Cosa", "Enter sigue la abierta y el HUD cambia")
	d.alternar_seguida()
	_ok(M.seguida_id() == "" and not hud.visible, "Enter otra vez deja de seguirla y la línea desaparece")
	d.mover(-1)
	_ok(d.seleccionada == "p1", "↑ vuelve a la primera")
	d.abrir()
	_ok(d.abierto and paused, "abrir el diario pausa el mundo")
	d.cerrar()
	_ok(not d.abierto and not paused, "cerrarlo lo reanuda")
	paused = true
	d.abrir()
	_ok(not d.abierto, "con otra pantalla ya pausando, no se abre encima")
	paused = false
	M.objetivo_hecho("p1", 0)
	_ok(d.ficha("p1")["objetivos"][0]["hecho"] == true, "un cambio en Misiones se ve en la ficha sin hacer nada")
	d.queue_free()
	hud.queue_free()
	await process_frame
