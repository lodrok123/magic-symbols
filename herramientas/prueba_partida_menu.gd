extends "res://herramientas/escenario_base.gd"
## GAMEFEEL TERCERA TANDA, LOTE 1 · PARTIDA (2/11; docs/REVISION_GAMEFEEL_30-10.md §9): A1 menú principal y continuar, A2 autoguardado, A3 estadísticas, A4 resumen de nivel.
## Todo contra una carpeta de ranuras de prueba (`user://partidas_prueba/`) y un .cfg de ajustes de prueba: NUNCA toca `user://partidas/` ni `user://ajustes.cfg`; limpia al acabar.
## Primero lo que no necesita nivel (menú principal, Continuar elige la más reciente, versión 3 y archivo v2, estadísticas sueltas, resumen en vacío); luego sobre la escena real del Bosque:
## estadísticas alimentadas por las señales de verdad, la pestaña, autoguardado (misión, pausa diferida, icono 1 s), el viaje de nivel (autoguardado + resumen) y «Salir al menú principal».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_partida_menu.gd

const CARPETA: String = "user://partidas_prueba/"
const AJUSTES: String = "user://ajustes_prueba_partida_menu.cfg"

var _menu: MenuPrincipal = null


func _pulsar(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	root.push_input(ev)
	await avanzar(1)


func _veda() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 20)


func _abrir_menu() -> MenuPrincipal:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = MenuPrincipal.new()
	root.add_child(_menu)
	return _menu


func _limpiar() -> void:
	for n in range(Partida.RANURAS_MAX + 2):
		Partida.borrar(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA + "ranura_0.json.tmp"))


func _db_ultimo(nombre: String) -> float:
	for i in range(Sfx.ULTIMOS.size() - 1, -1, -1):
		if String(Sfx.ULTIMOS[i]["nombre"]) == nombre:
			return float(Sfx.ULTIMOS[i]["db"])
	return 99.0


func _escenario() -> void:
	var sens0: bool = Sensacion3D.ACTIVA
	Sensacion3D.ACTIVA = true
	MenuPausa.RUTA_AJUSTES = AJUSTES
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AJUSTES))
	Partida.carpeta = CARPETA
	Partida.ruta_flags_v1 = CARPETA + "flags.json"
	Partida.ruta_misiones_v1 = CARPETA + "misiones.json"
	Partida.ranura_actual = 1
	Partida.AUTOGUARDADO = true
	Partida.AUTOGUARDADO_EN_HEADLESS = true
	MenuPrincipal.CAMBIAR_ESCENA = false
	_limpiar()
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	var vol0: Array = [Sfx.volumen_bus("Master"), Sfx.volumen_bus("Interfaz")]

	await _menu_principal()
	await _continuar_reciente_y_versiones()
	await _estadisticas_sueltas()
	await _en_el_nivel()

	# --- limpieza ---
	_limpiar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AJUSTES))
	Partida.carpeta = Partida.CARPETA_DEFECTO
	Partida.ruta_flags_v1 = Partida.RUTA_FLAGS_V1
	Partida.ruta_misiones_v1 = Partida.RUTA_MISIONES_V1
	Partida.AUTOGUARDADO_EN_HEADLESS = false
	Partida.continuar = false
	Partida.ranura_a_cargar = -1
	MenuPrincipal.CAMBIAR_ESCENA = true
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), vol0[0])
	Sfx.fijar_volumen_bus("Interfaz", vol0[1])
	Sensacion3D.ACTIVA = sens0
	Sfx.REGISTRAR = false


# ---------------------------------------------------------------------------------------------------------------------
#  A1 · menú principal
# ---------------------------------------------------------------------------------------------------------------------

func _menu_principal() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Estadisticas.reiniciar()
	var m: MenuPrincipal = _abrir_menu()
	await avanzar(2)
	_ok("A1 sin ninguna ranura: no hay «Continuar»", m.ids() == ["nueva", "cargar", "ajustes", "salir"], str(m.ids()))
	_ok("A1 (control) ni siquiera existe la ranura más reciente", Partida.ranura_mas_reciente() == -1)
	_ok("A1 la escena es la principal del proyecto", ProjectSettings.get_setting("application/run/main_scene") == "res://escenas/MenuPrincipal.tscn")
	_ok("A1 el fondo y el título están", m.get_node_or_null("Fondo") != null and m.get_node_or_null("Titulo") != null)
	_ok("A1 entra con tween (en marcha, panel aún transparente)", m.animando() and m._panel.modulate.a < 1.0, "alfa %.2f" % m._panel.modulate.a)
	await avanzar(10)
	_ok("A1 el tween de 0,15 s termina (opaco y a escala 1)", not m.animando() and is_equal_approx(m._panel.modulate.a, 1.0) and m._panel.scale.is_equal_approx(Vector2.ONE))

	# Con una ranura 1: aparece «Continuar» el primero.
	Partida.guardar(1, {"mapa_actual": "Bosque_01_v01", "punto": "x"})
	m = _abrir_menu()
	await avanzar(1)
	_ok("A1 con ranura: «Continuar» aparece la primera", m.ids() == ["continuar", "nueva", "cargar", "ajustes", "salir"], str(m.ids()))

	# Navegación y sonidos.
	Sfx.vaciar_registro()
	_veda()
	await _pulsar(KEY_DOWN)
	_ok("A1 ↓ baja a «Nueva partida»", m.id_elegida() == "nueva")
	_ok("A1 y suena ui_tick", Sfx.veces("ui_tick") == 1, str(Sfx.veces("ui_tick")))
	await _pulsar(KEY_UP)
	await _pulsar(KEY_UP)
	_ok("A1 ↑ desde la primera da la vuelta a «Salir»", m.id_elegida() == "salir")
	m.fila = 0
	m.mover(1)

	# Nueva partida con ranura: pide confirmación y no borra.
	_veda()
	await _pulsar(KEY_ENTER)
	_ok("A1 Nueva partida con ranura: el primer Enter solo pide confirmación", m.confirmando == "nueva" and Partida.existe(1) and m.destino == "")
	_ok("A1 y la fila lo dice", m.texto_fila(m.fila) == "Nueva partida" and String((m._etiquetas[m.fila] as Label).text).begins_with("¿Seguro?"))
	await _pulsar(KEY_ESCAPE)
	_ok("A1 Escape cancela la confirmación sin tocar nada", m.confirmando == "" and Partida.existe(1) and m.destino == "")
	_veda()
	m.accion()
	_veda()
	m.accion()
	_ok("A1 el segundo Enter borra la ranura 1 y entra en el nivel inicial", not Partida.existe(1) and m.destino == Niveles.escena_de(Niveles.NIVEL_INICIAL) and m.destino.ends_with("PruebaBosque02.tscn"), m.destino)
	_ok("A1 la partida nueva no hereda: no queda Continuar ni «continuar» puesto", not Partida.continuar and Partida.ranura_mas_reciente() == -1)
	m = _abrir_menu()
	m.fila = 0
	m.destino = ""
	m.accion()
	_ok("A1 sin ranuras, Nueva partida entra a la primera", m.confirmando == "" and m.destino != "")

	# Cargar: lista con mapa y tiempo.
	_limpiar()
	Partida.guardar(1, {"mapa_actual": "Bosque_01", "punto": "p"})
	Partida.guardar(0, {"mapa_actual": "Bosque_01_v01", "punto": "auto"})
	Partida._segundos_base = 3725.0
	Partida._t0_ms = Time.get_ticks_msec()
	Partida.guardar(3, {"mapa_actual": "Cueva", "punto": "c"})
	m = _abrir_menu()
	m.fila = m.ids().find("cargar")
	await avanzar(1)
	m.accion()
	await avanzar(1)
	_ok("A1 Cargar lista las ranuras que existen (auto, 1 y 3)", m.modo == "cargar" and m.ranuras_listadas() == [0, 1, 3], str(m.ranuras_listadas()))
	var t3: String = ""
	for i in range(m.ids().size()):
		if m.ids()[i] == "slot" and int(m._items[i]["ranura"]) == 3:
			t3 = m.texto_fila(i)
	_ok("A1 cada fila lleva mapa y tiempo jugado (Ranura 3 · Cueva · 1 h 02 min)", t3.contains("Ranura 3") and t3.contains("Cueva") and t3.contains("1 h 02 min"), t3)
	_ok("A1 la «auto» se llama Auto y acaba con «Volver»", m.texto_fila(0).begins_with("Auto") and m.ids()[m.ids().size() - 1] == "volver")
	m.fila = 1                                                 # Ranura 1
	m._refrescar()
	_veda()
	await _pulsar(KEY_DELETE)
	_ok("A1 Supr pide confirmación y no borra", m.confirmando == "borrar" and Partida.existe(1))
	await _pulsar(KEY_ESCAPE)
	_ok("A1 Escape la cancela y se queda en Cargar", m.confirmando == "" and m.modo == "cargar" and Partida.existe(1))
	_veda()
	await _pulsar(KEY_DELETE)
	_veda()
	await _pulsar(KEY_DELETE)
	_ok("A1 el segundo Supr borra la ranura 1", not Partida.existe(1) and m.ranuras_listadas() == [0, 3], str(m.ranuras_listadas()))
	m.fila = 0
	_veda()
	m.accion()
	_ok("A1 Enter sobre una ranura la carga (continuar + ranura_a_cargar) y apunta al nivel", Partida.continuar and Partida.ranura_a_cargar == 0 and m.destino.ends_with("PruebaBosque01_v01.tscn"), "%s %d" % [m.destino, Partida.ranura_a_cargar])
	_ok("A1 los puntos de guardado siguen escribiendo en la ranura 1", Partida.ranura_actual == 1)
	Partida.continuar = false
	Partida.ranura_a_cargar = -1
	await _pulsar(KEY_ESCAPE)
	_ok("A1 Escape en Cargar vuelve a lo principal, sobre «Cargar»", m.modo == "principal" and m.id_elegida() == "cargar")
	# Cargar sin nada: fila «No hay partidas» y no puedes.
	_limpiar()
	m = _abrir_menu()
	m.fila = m.ids().find("cargar")
	m.accion()
	_ok("A1 Cargar sin ranuras enseña «No hay partidas guardadas»", m.ids() == ["vacio", "volver"] and m.texto_fila(0) == MenuPrincipal.TXT_VACIO)
	Sfx.vaciar_registro()
	_veda()
	m.accion()
	# Desde 8acc7119 (tarea R) el menú suena la grabación «no_puedes_ui», no «no_puedes».
	_ok("A1 y Enter ahí suena no_puedes_ui", Sfx.veces("no_puedes_ui") == 1)
	_veda()
	m.borrar_elegida()
	_ok("A1 Supr fuera de una ranura también suena no_puedes_ui", Sfx.veces("no_puedes_ui") == 2)

	# Continuar de verdad.
	Partida.guardar(1, {"mapa_actual": "Cueva"})
	m = _abrir_menu()
	m.destino = ""
	Sfx.vaciar_registro()
	_veda()
	m.accion()                                               # fila 0 = Continuar
	_ok("A1 Continuar carga la ranura y va al nivel guardado (Cueva)", Partida.continuar and Partida.ranura_a_cargar == 1 and m.destino.ends_with("PruebaCueva.tscn"), m.destino)
	_ok("A1 y suena ui_equipar", Sfx.veces("ui_equipar") == 1)
	Partida.continuar = false
	Partida.ranura_a_cargar = -1

	# Ajustes: MenuPausa sin partida.
	m = _abrir_menu()
	m.fila = m.ids().find("ajustes")
	await avanzar(1)
	m.accion()
	await avanzar(2)
	_ok("A1 Ajustes abre MenuPausa en modo sin partida", m.ajustes != null and m.ajustes.abierta and m.ajustes.sin_partida and m.modo == "ajustes")
	var vis: Array = m.ajustes.ids_visibles()
	_ok("A1 sin Reiniciar ni Salir al menú", not vis.has("reiniciar") and not vis.has("menu") and vis.has("master") and vis.has("sensacion"), str(vis))
	_ok("A1 (el «Continuar» de la pausa pasa a llamarse «Volver»)", String((m.ajustes._filas[0]["etiqueta"] as Label).text) == "Volver")
	_ok("A1 las filas ocultas no se ven y ↓ las salta", not (m.ajustes._filas[m.ajustes._indice("reiniciar")]["panel"] as Control).visible)
	m.ajustes.fila = m.ajustes._indice("sensacion")
	m.ajustes.mover(1)
	_ok("B1 desde Sensación ↓ cae en «Controles» (fila nueva del 2/11, antes caía en «Salir»)", m.ajustes.id_fila(m.ajustes.fila) == "controles")
	m.ajustes.mover(1)
	_ok("A1 desde Controles ↓ salta Reiniciar y Salir al menú y cae en «Salir»", m.ajustes.id_fila(m.ajustes.fila) == "salir")
	var ajus: MenuPausa = m.ajustes
	await _pausa_aj_cerrar(m)
	_ok("A1 Escape cierra Ajustes y el menú principal sigue ahí", ajus != null and not ajus.abierta and m.modo == "principal" and m.ajustes == null)
	_ok("A1 el árbol no queda en pausa", not paused)
	await avanzar(14)

	# ACTIVA = false: sin tween.
	Sensacion3D.ACTIVA = false
	m = _abrir_menu()
	_ok("A1 con ACTIVA = false el menú principal aparece de golpe (sin tween, opaco)", not m.animando() and is_equal_approx(m._panel.modulate.a, 1.0) and m._panel.scale.is_equal_approx(Vector2.ONE))
	Sfx.vaciar_registro()
	_veda()
	m.mover(1)
	_ok("A1 y los sonidos siguen sonando", Sfx.veces("ui_tick") == 1)
	Sensacion3D.ACTIVA = true
	m.free()
	_menu = null
	_limpiar()


func _pausa_aj_cerrar(m: MenuPrincipal) -> void:
	await _pulsar(KEY_ESCAPE)


# ---------------------------------------------------------------------------------------------------------------------
#  A2 · Continuar elige la más reciente · versión 3 · archivo v2
# ---------------------------------------------------------------------------------------------------------------------

func _continuar_reciente_y_versiones() -> void:
	_limpiar()
	Partida.guardar(1, {"mapa_actual": "Bosque_01", "punto": "manual"})
	OS.delay_msec(30)
	Partida.guardar(0, {"mapa_actual": "Bosque_01_v01", "punto": "auto"})
	_ok("A2 Continuar elige la más reciente: la «auto» guardada después", Partida.ranura_mas_reciente() == 0)
	OS.delay_msec(30)
	Partida.guardar(1, {"mapa_actual": "Bosque_01", "punto": "manual2"})
	_ok("A2 …y si luego se guarda a mano, la 1", Partida.ranura_mas_reciente() == 1)
	var d: Dictionary = Partida.leer(1)
	_ok("A2 el archivo es versión 3 y lleva la sección estadisticas y meta.guardado_unix", int(d["version"]) == 3 and d.has("estadisticas") and (d["meta"] as Dictionary).has("guardado_unix"))
	# Una ranura v2 (sin estadísticas ni guardado_unix) también se lee.
	var v2: Dictionary = d.duplicate(true)
	v2["version"] = 2
	v2.erase("estadisticas")
	(v2["meta"] as Dictionary).erase("guardado_unix")
	(v2["jugadora"] as Dictionary)["mapa_actual"] = "Cueva"
	var fa := FileAccess.open(CARPETA + "ranura_5.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(v2))
	fa.close()
	Estadisticas.reiniciar()
	Estadisticas.contar_enemigo("Goblin")
	Estadisticas.contar_cofre()
	_ok("A2/A3 (preparación) hay cifras antes de cargar el v2", Estadisticas.total_enemigos(Estadisticas.total) == 1)
	var c: Dictionary = Partida.cargar(5)
	_ok("A2/A3 un archivo v2 carga (no vacío) y deja las estadísticas a cero", not c.is_empty() and int(c["version"]) == 2 and Estadisticas.total_enemigos(Estadisticas.total) == 0 and int(Estadisticas.total["cofres"]) == 0 and not Estadisticas.hay_actividad(Estadisticas.total))
	# v2 sin guardado_unix frente a v3: la v3 gana.
	var v2b: Dictionary = v2.duplicate(true)
	fa = FileAccess.open(CARPETA + "ranura_0.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(v2b))
	fa.close()
	_ok("A2 una ranura v2 sin guardado_unix pierde frente a una v3", Partida.ranura_mas_reciente() == 1)
	Partida.borrar(1)
	_ok("A2 con solo la v2 (auto) Continuar la elige", Partida.ranura_mas_reciente() == 0)
	_limpiar()


# ---------------------------------------------------------------------------------------------------------------------
#  A3 · estadísticas sueltas · A4 · resumen en vacío
# ---------------------------------------------------------------------------------------------------------------------

func _estadisticas_sueltas() -> void:
	Estadisticas.reiniciar()
	_ok("A3 de partida nueva todo está a cero y no hay actividad", Estadisticas.total_enemigos(Estadisticas.total) == 0 and not Estadisticas.hay_actividad(Estadisticas.total) and not Estadisticas.hay_actividad(Estadisticas.por_nivel))
	Estadisticas.contar_enemigo("Goblin")
	Estadisticas.contar_enemigo("Goblin")
	Estadisticas.contar_enemigo("Limo")
	Estadisticas.contar_hechizo("fuego")
	Estadisticas.dano_hecho(12.5)
	Estadisticas.dano_recibido(4.0)
	Estadisticas.contar_oro(9)
	Estadisticas.contar_muerte()
	Estadisticas.contar_cofre()
	_ok("A3 enemigos por tipo", int(Estadisticas.total["enemigos"]["Goblin"]) == 2 and int(Estadisticas.total["enemigos"]["Limo"]) == 1 and Estadisticas.total_enemigos(Estadisticas.total) == 3)
	_ok("A3 hechizos, daño, oro, muertes y cofres", int(Estadisticas.total["hechizos"]["fuego"]) == 1 and is_equal_approx(float(Estadisticas.total["dano_hecho"]), 12.5) and is_equal_approx(float(Estadisticas.total["dano_recibido"]), 4.0)
		and int(Estadisticas.total["oro_ganado"]) == 9 and int(Estadisticas.total["muertes"]) == 1 and int(Estadisticas.total["cofres"]) == 1)
	_ok("A3 `por_nivel` cuenta lo mismo (mismas claves)", Estadisticas.por_nivel["enemigos"] == Estadisticas.total["enemigos"] and int(Estadisticas.por_nivel["oro_ganado"]) == 9)
	# Guardar y cargar (v3).
	var ruta_seg: float = Estadisticas.segundos_total()
	Partida.guardar(2, {})
	var d: Dictionary = Partida.leer(2)
	var e: Dictionary = d["estadisticas"]
	_ok("A3 se guarda en la sección estadisticas", int((e["enemigos"] as Dictionary)["Goblin"]) == 2 and int(e["muertes"]) == 1 and is_equal_approx(float(e["dano_hecho"]), 12.5) and float(e["segundos"]) >= ruta_seg)
	Estadisticas.reiniciar()
	_ok("A3 (control) reiniciar deja ceros", not Estadisticas.hay_actividad(Estadisticas.total))
	Partida.cargar(2)
	_ok("A3 cargar la recupera (v3)", int(Estadisticas.total["enemigos"]["Goblin"]) == 2 and int(Estadisticas.total["hechizos"]["fuego"]) == 1 and int(Estadisticas.total["oro_ganado"]) == 9 and is_equal_approx(float(Estadisticas.total["dano_recibido"]), 4.0))
	_ok("A3 y `por_nivel` empieza vacío tras cargar", not Estadisticas.hay_actividad(Estadisticas.por_nivel))
	# cerrar_nivel entrega y vacía.
	Estadisticas.contar_enemigo("Goblin")
	var n: Dictionary = Estadisticas.cerrar_nivel()
	_ok("A3/A4 cerrar_nivel entrega lo del nivel (1 goblin) con segundos y lo vacía", Estadisticas.total_enemigos(n) == 1 and n.has("segundos") and not Estadisticas.hay_actividad(Estadisticas.por_nivel))
	_ok("A3 …y el total no se vacía (3 cargados + 1 de ahora)", Estadisticas.total_enemigos(Estadisticas.total) == 4)
	_ok("A3 texto de tiempo", Estadisticas.texto_tiempo(45.0) == "45 s" and Estadisticas.texto_tiempo(727.0) == "12 min 07 s" and Estadisticas.texto_tiempo(3900.0) == "1 h 05 min")
	# A4 en vacío.
	var r: ResumenNivel = ResumenNivel.mostrar(self, "Laboratorio", Estadisticas.vacio())
	_ok("A4 si el nivel no registró nada, no se muestra", r == null and ResumenNivel.activo == null and root.get_node_or_null(ResumenNivel.NOMBRE) == null)
	var solo_tiempo: Dictionary = Estadisticas.vacio()
	solo_tiempo["segundos"] = 600.0
	_ok("A4 …ni con solo tiempo", ResumenNivel.mostrar(self, "Lab", solo_tiempo) == null)
	Partida.borrar(2)
	Estadisticas.reiniciar()


# ---------------------------------------------------------------------------------------------------------------------
#  Sobre el nivel real
# ---------------------------------------------------------------------------------------------------------------------

func _en_el_nivel() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Estadisticas.reiniciar()
	Partida.nueva()
	Partida.carpeta = CARPETA
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	current_scene = maqueta
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	Niveles.registrar("DestinoPrueba", RUTA_BOSQUE)

	# --- A3 · las cifras salen de las señales de verdad ---
	_ok("A3 el nivel arranca con las estadísticas a cero", not Estadisticas.hay_actividad(Estadisticas.total))
	Estado.i().enemigo_muerto.emit(Vector2.ZERO, "Goblin")
	_ok("A3 un enemigo muerto (Estado.enemigo_muerto) se cuenta por tipo", int(Estadisticas.total["enemigos"].get("Goblin", 0)) == 1 and int(Estadisticas.por_nivel["enemigos"].get("Goblin", 0)) == 1)
	var salio: bool = lanzar("fuego", ["flecha"], Vector3.RIGHT)
	await avanzar(2)
	_ok("A3 un hechizo lanzado de verdad se cuenta por elemento", salio and Estadisticas.total_hechizos(Estadisticas.total) >= 1, str(Estadisticas.total["hechizos"]))
	var goblin: Combate3D = null
	for g in get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and not (g as Combate3D).muerto and (g as Combate3D).health > 3.0:
			goblin = g as Combate3D
			break
	_ok("A3 (preparación) hay un enemigo con vida en el nivel", goblin != null)
	if goblin != null:
		var hecho0: float = float(Estadisticas.total["dano_hecho"])
		goblin.receive_damage(3.0)
		_ok("A3 el daño hecho suma lo que de verdad quita", is_equal_approx(float(Estadisticas.total["dano_hecho"]) - hecho0, 3.0), str(float(Estadisticas.total["dano_hecho"]) - hecho0))
	await avanzar(40)                                           # que pase la invulnerabilidad tras cualquier golpe
	var rec0: float = float(Estadisticas.total["dano_recibido"])
	var vida0: float = jugador.vida
	jugador.set("_t_inv", 0.0)
	jugador.recibir_dano(10.0)
	var rec: float = float(Estadisticas.total["dano_recibido"]) - rec0
	_ok("A3 el daño recibido se cuenta y es justo la vida que perdió la jugadora (tras la defensa)", rec > 0.0 and is_equal_approx(rec, vida0 - jugador.vida), "contado %.2f, perdido %.2f" % [rec, vida0 - jugador.vida])
	Estado.i().dar_oro(7)
	Estado.i().gastar_oro(2)
	_ok("A3 el oro ganado suma lo que sube y gastar no resta", int(Estadisticas.total["oro_ganado"]) == 7, str(Estadisticas.total["oro_ganado"]))
	Mundo3D.avisar_logro("cofre_abierto", Vector3.ZERO)
	_ok("A3 un cofre abierto (logro cofre_abierto) se cuenta", int(Estadisticas.total["cofres"]) == 1)
	Mundo3D.avisar_logro("paso_puzle", Vector3.ZERO)
	_ok("A3 otro logro no cuenta como cofre", int(Estadisticas.total["cofres"]) == 1)
	jugador.set("_t_inv", 0.0)
	jugador.recibir_dano(100000.0)
	await avanzar(2)
	_ok("A3 la muerte de la jugadora se cuenta", int(Estadisticas.total["muertes"]) == 1 and jugador.muerto)
	jugador.reaparecer()
	await avanzar(2)

	# --- A3 · la pestaña ---
	var menu: MenuPestanas = lanzador.menu
	_ok("A3 la pestaña Estadísticas va tras Misiones y antes de Ajustes", String(MenuPestanas.PESTANAS[MenuPestanas.INDICE_MISIONES + 1]["id"]) == "estadisticas" and String(MenuPestanas.PESTANAS[MenuPestanas.PESTANAS.size() - 1]["id"]) == "ajustes")
	menu.abrir(MenuPestanas.INDICE_ESTADISTICAS)
	await avanzar(3)
	_ok("A3 se abre y es funcional (no «Próximamente»)", menu.abierta and menu.pestana_id() == "estadisticas" and menu.funcional(MenuPestanas.INDICE_ESTADISTICAS) and menu._pag_est.visible and not menu._pag_prox.visible and not menu._pag_inv.visible and not menu._pag_mis.visible)
	var f: Dictionary = menu.estadisticas_filas()
	var colt: PackedStringArray = []
	for h in menu._col_total.get_children():
		colt.append((h as Label).text)
	_ok("A3 muestra las cifras de la partida (enemigos 1, cofres 1, oro 7, muertes 1)", colt.has("Enemigos vencidos") and colt[colt.find("Enemigos vencidos") + 1] == "1" and colt[colt.find("Oro ganado") + 1] == "7"
		and colt[colt.find("Cofres abiertos") + 1] == "1" and colt[colt.find("Veces caída") + 1] == "1", str(colt))
	_ok("A3 en dos columnas: la partida y este nivel", menu._col_total.get_child_count() == f["total"].size() * 2 and menu._col_nivel.get_child_count() == f["nivel"].size() * 2 and f["total"].size() == 8)
	_ok("A3 (el pie desglosa por tipo y elemento)", menu._pie_est.text.contains("Goblin 1") and menu._pie_est.text.contains("fuego"))
	menu.cambiar_pestana(MenuPestanas.INDICE_ESTADISTICAS + 1)
	_ok("A3 la pestaña siguiente (Ajustes) sí es «Próximamente»", menu.pestana_id() == "ajustes" and menu._pag_prox.visible and not menu._pag_est.visible)
	menu.cerrar()
	await avanzar(12)

	# --- A2 · autoguardado: misión, pausa diferida, icono ---
	Partida.borrar(0)
	Partida.autoguardados = 0
	var icono: IconoGuardado = get_first_node_in_group("icono_guardado") as IconoGuardado
	_ok("A2 el HUD tiene el icono de guardado, oculto", icono != null and not icono.visible)
	Misiones.i().definir({"id": "prueba_auto", "titulo": "Prueba", "tipo": "secundaria", "objetivos": ["uno"]})
	Misiones.i().activar("prueba_auto")
	_ok("A2 (control) activar la misión no guarda nada", not Partida.existe(0))
	Sfx.vaciar_registro()
	_veda()
	Misiones.i().objetivo_hecho("prueba_auto", 0)
	_ok("A2 completar una misión autoguarda en la ranura 0 (auto)", Misiones.i().estado("prueba_auto") == "completa" and Partida.existe(0) and Partida.ultimo_motivo_auto == "mision" and Partida.autoguardados == 1, "%s %d" % [Partida.ultimo_motivo_auto, Partida.autoguardados])
	var auto: Dictionary = Partida.leer(0)
	_ok("A2 la ranura auto lleva el mapa, la posición y las estadísticas", String(auto["jugadora"]["mapa_actual"]) == String(maqueta.get("nivel")) and (auto["jugadora"]["posicion"] as Array).size() == 3 and int(auto["estadisticas"]["cofres"]) == 1 and String(auto["meta"]["punto"]) == "auto")
	_ok("A2 …y la misión completada", String(auto["misiones"]["misiones"]["prueba_auto"]["estado"]) == "completa")
	_ok("A2 la ranura 1 sigue sin escribirse (solo los puntos de guardado)", not Partida.existe(1))
	_ok("A2 el icono aparece", icono.visible and icono.restante_s > 0.9, "%.2f" % icono.restante_s)
	_ok("A2 y suena ui_tick a −24 dB", Sfx.veces("ui_tick") >= 1 and _db_ultimo("ui_tick") == -24.0, str(_db_ultimo("ui_tick")))
	await avanzar(18)                                           # 0,6 s a 30 fps
	_ok("A2 sigue a media vida (0,6 s)", icono.visible)
	await avanzar(14)                                           # ya >1 s
	_ok("A2 desaparece al cabo de T_ICONO_GUARDADO = 1 s", not icono.visible and IconoGuardado.T_ICONO_GUARDADO == 1.0)

	# Pausa: se difiere.
	Partida.borrar(0)
	Partida.autoguardados = 0
	paused = true
	var ok_pausa: bool = Partida.autoguardar(self, "mision")
	_ok("A2 con el árbol en pausa NO se autoguarda: se difiere", not ok_pausa and not Partida.existe(0) and Partida.diferido and Partida.autoguardados == 0)
	await avanzar(3)
	_ok("A2 sigue sin guardar mientras dure la pausa", not Partida.existe(0) and Partida.diferido)
	paused = false
	await avanzar(3)
	_ok("A2 al despausar se hace lo diferido", Partida.existe(0) and not Partida.diferido and Partida.autoguardados == 1 and icono.visible)
	await avanzar(34)

	# Apagado.
	Partida.borrar(0)
	Partida.AUTOGUARDADO = false
	_ok("A2 con AUTOGUARDADO = false no se guarda", not Partida.autoguardar(self, "mision") and not Partida.existe(0))
	Partida.AUTOGUARDADO = true
	Partida.AUTOGUARDADO_EN_HEADLESS = false
	_ok("A2 en headless sin permiso tampoco (las pruebas no pisan la auto de nadie)", not Partida.autoguardar(self, "mision") and not Partida.existe(0))
	Partida.AUTOGUARDADO_EN_HEADLESS = true

	# --- A2 + A4 · cambio de nivel ---
	Partida.borrar(0)
	Partida.autoguardados = 0
	var maq_vieja: Node = maqueta
	var t_res0: float = ResumenNivel.T_RESUMEN
	ResumenNivel.T_RESUMEN = 999.0                              # que la tarjeta no se quite sola mientras carga el nivel (los fotogramas de headless no son segundos de pared)
	var cifras: Dictionary = Estadisticas.por_nivel.duplicate(true)
	var enem: int = Estadisticas.total_enemigos(cifras)
	var oro_n: int = int(cifras["oro_ganado"])
	Sfx.vaciar_registro()
	_veda()
	var arranco: bool = Niveles.ir_a(maqueta, "DestinoPrueba:entrada_x")
	_ok("A2/A4 el viaje arranca", arranco and Niveles.en_curso)
	_ok("A2 AL SALIR (antes del fundido) autoguarda en la ranura 0, apuntando al nivel nuevo", Partida.existe(0) and Partida.ultimo_motivo_auto == "nivel" and String(Partida.leer(0)["jugadora"]["mapa_actual"]) == "DestinoPrueba" and String(Partida.leer(0)["meta"]["punto"]) == Partida.PUNTO_VIAJE)
	_ok("A2 …y aún no ha empezado el fundido", Niveles.alfa_fundido(self) <= 0.01)
	var res: ResumenNivel = ResumenNivel.activo
	_ok("A4 sale el resumen del nivel que se deja", res != null and res.is_inside_tree() and res.get_parent() == root and res.layer > Niveles.CAPA_FUNDIDO)
	if res != null:
		var fil: Array = res.filas()
		_ok("A4 con las cifras de por_nivel: tiempo, enemigos, cofres, oro y daño recibido", fil.size() == 5 and String(fil[1][1]) == str(enem) and String(fil[3][1]) == str(oro_n) and String(fil[2][1]) == "1" and String(fil[0][0]) == "Tiempo" and String(fil[4][0]) == "Daño recibido", str(fil))
		_ok("A4 suena logro_pista al aparecer", Sfx.veces("logro_pista") >= 1)
		_ok("A4 entra con tween (transparente al principio)", res._tw != null and res._panel.modulate.a < 1.0)
	_ok("A4 por_nivel se vacía tras emitir el resumen y el total sigue", not Estadisticas.hay_actividad(Estadisticas.por_nivel) and Estadisticas.total_enemigos(Estadisticas.total) == enem)
	var t0: int = Time.get_ticks_msec()
	while Niveles.en_curso and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	_ok("A2 el viaje acaba", not Niveles.en_curso, "%d ms" % (Time.get_ticks_msec() - t0))
	await avanzar(5)
	_ok("A2/A4 la escena vieja se libró y hay otra", not is_instance_valid(maq_vieja) or maq_vieja.is_queued_for_deletion())
	_ok("A4 la tarjeta SOBREVIVE al cambio de escena (sigue en la raíz)", res != null and is_instance_valid(res) and res.is_inside_tree())
	# Saltarla con una tecla (tras la gracia).
	await avanzar(10)                                           # > GRACIA_S
	if res != null and is_instance_valid(res):
		_ok("A4 pasada la gracia, cualquier tecla la quita", res.segundos_vista > ResumenNivel.GRACIA_S)
		await _pulsar(KEY_W)
		_ok("A4 al pulsar una tecla empieza a cerrarse", res.cerrandose)
		await avanzar(10)
		_ok("A4 y se libera (fundido de 0,2 s)", not is_instance_valid(res) and ResumenNivel.activo == null and root.get_node_or_null(ResumenNivel.NOMBRE) == null)
	# Se quita sola a los T_RESUMEN s.
	ResumenNivel.T_RESUMEN = 0.5
	var d2: Dictionary = Estadisticas.vacio()
	d2["cofres"] = 2
	d2["segundos"] = 75.0
	var r2: ResumenNivel = ResumenNivel.mostrar(self, "Prueba_Nivel", d2)
	_ok("A4 con actividad se muestra (título sin guiones bajos)", r2 != null and r2.is_inside_tree())
	var lbl_titulo: String = ""
	for h in r2._panel.get_child(0).get_children():
		if h is Label and lbl_titulo == "":
			lbl_titulo = (h as Label).text
	_ok("A4 el título es el nombre del nivel", lbl_titulo == "Prueba Nivel", lbl_titulo)
	await _pulsar(KEY_W)
	_ok("A4 (gracia) la tecla inmediata no la cierra", not r2.cerrandose)
	await avanzar(22)
	_ok("A4 se quita sola pasados T_RESUMEN s", not is_instance_valid(r2) or r2.cerrandose or r2.is_queued_for_deletion())
	await avanzar(10)
	ResumenNivel.T_RESUMEN = t_res0
	_ok("A4 T_RESUMEN por defecto son 3 s", ResumenNivel.T_RESUMEN == 3.0)
	# ACTIVA = false.
	Sensacion3D.ACTIVA = false
	var r3: ResumenNivel = ResumenNivel.mostrar(self, "Otro", d2)
	_ok("A4 con ACTIVA = false aparece sin tween, opaca", r3 != null and r3._tw == null and is_equal_approx(r3._panel.modulate.a, 1.0) and r3._panel.scale.is_equal_approx(Vector2.ONE))
	r3.segundos_vista = 1.0
	r3.saltar()
	_ok("A4 y se quita de golpe", r3.cerrandose and r3.is_queued_for_deletion())
	Sensacion3D.ACTIVA = true
	await avanzar(2)

	# --- A1 · Salir al menú principal desde la pausa ---
	maqueta = current_scene
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	_ok("A1 (preparación) el nivel de destino está montado", lanzador != null and jugador != null and maqueta != null)
	if lanzador == null:
		return
	var p: MenuPausa = lanzador.pausa
	_ok("A1 la pausa tiene la fila «Salir al menú principal» antes de «Salir»", p.ids_visibles().find("menu") == p.ids_visibles().find("salir") - 1 and p.ids_visibles().has("reiniciar"))
	Partida.borrar(0)
	Partida.autoguardados = 0
	await _pulsar(KEY_ESCAPE)
	_ok("A1 (preparación) Escape abre la pausa", p.abierta and paused)
	p.fila = p._indice("menu")
	p._refrescar()
	_veda()
	p.accion()
	_ok("A1 el primer Enter pide confirmación y no sale", p.confirmando == "menu" and p.salidas_menu == 0 and not Partida.existe(0))
	_ok("A1 la fila lo dice", String((p._filas[p._indice("menu")]["etiqueta"] as Label).text).begins_with("¿Seguro?"))
	_veda()
	p.accion()
	_ok("A1 el segundo Enter confirma: despausa y AUTOGUARDA en la ranura 0", p.salidas_menu == 1 and not paused and Partida.existe(0) and Partida.ultimo_motivo_auto == "menu" and Partida.autoguardados == 1)
	var n: int = 0
	while n < 600 and not (current_scene is MenuPrincipal):
		await process_frame
		n += 1
	_ok("A1 y cambia a la escena del menú principal", current_scene is MenuPrincipal, "tras %d fotogramas" % n)
	if current_scene is MenuPrincipal:
		var mp: MenuPrincipal = current_scene as MenuPrincipal
		await avanzar(2)
		_ok("A1 que ahora ofrece «Continuar» (hay ranura auto)", mp.ids().has("continuar") and Partida.ranura_mas_reciente() == 0, str(mp.ids()))
		mp.free()
	_limpiar()
