extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, TAREA Pa (1/11; presentacion/ui/menu_pausa.gd, magia/lanzador_3d.gd): el menú de pausa y de volumen. Sobre la escena real del Bosque, con --fixed-fps 30 y `Sfx.REGISTRAR`.
## Escape pausa el árbol y abre con tween y `libro_abre`; el segundo cierra y despausa; con la mochila abierta Escape cierra la mochila y NO abre la pausa; con el libro abierto no se abre;
## el deslizador de Interfaz cambia el AudioServer y se guarda en el .cfg (aquí `user://ajustes_prueba.cfg`, para no pisar los ajustes de nadie) y recargar lo recupera;
## el interruptor Sensación escribe `ACTIVA`; «Salir» pide confirmación (y no cierra); «Reiniciar» pide confirmación y recarga la escena (la raíz cambia de instancia);
## `ACTIVA = false` abre sin tween.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_menu_pausa.gd

const RUTA_PRUEBA: String = "user://ajustes_prueba.cfg"


func _pulsar(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	root.push_input(ev)
	await avanzar(1)


func _pausa_de_veda() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 40)
	await avanzar(1)


func _escenario() -> void:
	MenuPausa.RUTA_AJUSTES = RUTA_PRUEBA
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PRUEBA))
	var sens0: bool = Sensacion3D.ACTIVA
	Sensacion3D.ACTIVA = true
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	current_scene = maqueta
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	var p: MenuPausa = lanzador.pausa
	_ok("0 el lanzador monta el MenuPausa", p != null)
	if p == null:
		return
	_ok("0 es ALWAYS y está en la capa de la interfaz, tras el menú con pestañas", p.process_mode == Node.PROCESS_MODE_ALWAYS and p.get_parent() == lanzador.menu.get_parent()
		and p.get_index() == lanzador.menu.get_index() + 1)
	_ok("0 nace cerrado y el árbol sin pausa", not p.abierta and not get_root_pausado())
	var bus_i0: float = Sfx.volumen_bus("Interfaz")
	var bus_m0: float = Sfx.volumen_bus("Master")
	var bus_w0: float = Sfx.volumen_bus("Mundo")

	# --- 1 · Escape abre con tween y libro_abre ---
	await _pulsar(KEY_ESCAPE)
	_ok("1 Escape abre el menú", p.abierta and p.visible_ahora())
	_ok("1 y pausa el árbol", get_root_pausado())
	_ok("1 abre con tween (en marcha, panel aún transparente o a medias)", p.animando() and p._panel.modulate.a < 1.0, "alfa %.2f" % p._panel.modulate.a)
	_ok("1 suena libro_abre", Sfx.veces("libro_abre") == 1, str(Sfx.veces("libro_abre")))
	_ok("1 a −12 dB", Sfx.ULTIMOS.size() > 0 and _db_ultimo("libro_abre") == -12.0, str(_db_ultimo("libro_abre")))
	await avanzar(12)                                 # 0,4 s a 30 fps con el árbol en pausa: el tween (TWEEN_PAUSE_PROCESS) sigue vivo
	_ok("1 el tween termina (panel opaco, escala 1, fondo al 55 %)", not p.animando() and is_equal_approx(p._panel.modulate.a, 1.0) and p._panel.scale.is_equal_approx(Vector2.ONE)
		and is_equal_approx(p._velo.color.a, 0.55), "alfa %.2f escala %s fondo %.2f" % [p._panel.modulate.a, str(p._panel.scale), p._velo.color.a])

	# --- 2 · Escape cierra ---
	await _pausa_de_veda()
	await _pulsar(KEY_ESCAPE)
	_ok("2 el segundo Escape cierra", not p.abierta)
	_ok("2 y despausa el árbol", not get_root_pausado())
	_ok("2 suena libro_cierra", Sfx.veces("libro_cierra") == 1, str(Sfx.veces("libro_cierra")))
	await avanzar(12)
	_ok("2 acabado el tween ya no se ve", not p.visible_ahora())

	# --- 3 · con la mochila abierta, Escape cierra la mochila y no abre la pausa ---
	lanzador.menu.abrir()
	await avanzar(2)
	_ok("3 la mochila está abierta y pausa", lanzador.menu.abierta and get_root_pausado())
	await _pulsar(KEY_ESCAPE)
	_ok("3 Escape cierra la mochila", not lanzador.menu.abierta)
	_ok("3 y NO abre la pausa", not p.abierta)
	_ok("3 y el árbol queda sin pausa", not get_root_pausado())
	await avanzar(10)

	# --- 4 · con el libro abierto no se abre ---
	lanzador.libro.call("_toggle")
	await avanzar(3)
	_ok("4 el libro está abierto", lanzador.libro_abierto())
	await _pulsar(KEY_ESCAPE)
	_ok("4 con el libro abierto Escape no abre la pausa", not p.abierta)
	if lanzador.libro_abierto():
		lanzador.libro.call("_toggle")
	await avanzar(10)
	_ok("4 (control) cerrado el libro, Escape vuelve a abrirla", true)
	await _pulsar(KEY_ESCAPE)
	_ok("4 cerrado el libro Escape la abre", p.abierta)
	await avanzar(12)

	# --- 5 · navegación y deslizadores ---
	_ok("5 empieza en «Continuar»", p.id_fila(p.fila) == "continuar")
	await _pausa_de_veda()
	await _pulsar(KEY_DOWN)
	_ok("5 ↓ baja a «Volumen general»", p.id_fila(p.fila) == "master")
	await _pulsar(KEY_UP)
	await _pulsar(KEY_UP)
	_ok("5 ↑ desde la primera da la vuelta a «Salir»", p.id_fila(p.fila) == "salir")
	p.fila = 0
	p.mover(3)
	_ok("5 «Volumen de la interfaz» es la fila 3", p.id_fila(p.fila) == "interfaz")
	var antes: float = Sfx.volumen_bus("Interfaz")
	await _pulsar(KEY_LEFT)
	_ok("5 ← baja el volumen de la interfaz en 2 dB (y cambia el AudioServer)", is_equal_approx(Sfx.volumen_bus("Interfaz"), antes - MenuPausa.PASO_DB), "%.1f → %.1f" % [antes, Sfx.volumen_bus("Interfaz")])
	p.poner_volumen("interfaz", -12.0)
	_ok("5 poner_volumen(interfaz, −12): el bus de verdad está a −12", is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Interfaz")), -12.0))
	_ok("5 se guardó en el .cfg", FileAccess.file_exists(RUTA_PRUEBA) and is_equal_approx(_leer("volumen", "interfaz"), -12.0), str(_leer("volumen", "interfaz")))
	p.poner_volumen("master", -8.0)
	p.poner_volumen("mundo", -4.0)
	_ok("5 Master y Mundo también (en vivo)", is_equal_approx(Sfx.volumen_bus("Master"), -8.0) and is_equal_approx(Sfx.volumen_bus("Mundo"), -4.0))
	p.poner_volumen("interfaz", -100.0)
	_ok("5 el deslizador no baja de −30 dB", is_equal_approx(Sfx.volumen_bus("Interfaz"), -30.0))
	p.poner_volumen("interfaz", 50.0)
	_ok("5 ni sube de +6 dB", is_equal_approx(Sfx.volumen_bus("Interfaz"), 6.0))
	p.poner_volumen("interfaz", -12.0)
	# Recargar: se estropean los buses a mano y cargar_ajustes() los recupera.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Interfaz"), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Mundo"), 0.0)
	_ok("5 cargar_ajustes() encuentra el archivo", MenuPausa.cargar_ajustes())
	_ok("5 y recupera Interfaz −12, Master −8 y Mundo −4", is_equal_approx(Sfx.volumen_bus("Interfaz"), -12.0) and is_equal_approx(Sfx.volumen_bus("Master"), -8.0)
		and is_equal_approx(Sfx.volumen_bus("Mundo"), -4.0), "%.1f %.1f %.1f" % [Sfx.volumen_bus("Interfaz"), Sfx.volumen_bus("Master"), Sfx.volumen_bus("Mundo")])
	p._refrescar()
	_ok("5 el deslizador de la fila vuelve a mostrar −12", is_equal_approx((p._filas[3]["deslizador"] as HSlider).value, -12.0))

	# --- 6 · interruptor Sensación ---
	p.fila = 0
	p.mover(4)
	_ok("6 la fila 4 es «Sensación»", p.id_fila(p.fila) == "sensacion")
	await _pausa_de_veda()
	await _pulsar(KEY_ENTER)
	_ok("6 Enter apaga Sensacion3D.ACTIVA", not Sensacion3D.ACTIVA)
	_ok("6 y se guarda", not bool(_leer("sensacion", "activa")))
	await _pausa_de_veda()
	await _pulsar(KEY_ENTER)
	_ok("6 otro Enter la vuelve a encender", Sensacion3D.ACTIVA and bool(_leer("sensacion", "activa")))

	# --- 7 · Salir pide confirmación y no cierra ---
	p.fila = 0
	p.mover(6)
	_ok("7 la fila 6 es «Salir»", p.id_fila(p.fila) == "salir")
	await _pausa_de_veda()
	await _pulsar(KEY_ENTER)
	_ok("7 el primer Enter solo pide confirmación", p.confirmando == "salir")
	_ok("7 y el menú sigue abierto (no se salió)", p.abierta)
	await _pulsar(KEY_ESCAPE)
	_ok("7 Escape cancela la confirmación sin cerrar el menú", p.confirmando == "" and p.abierta)
	p.mover(-1)
	_ok("7 cambiar de fila también cancela la confirmación", p.confirmando == "")

	# --- 8 · ACTIVA = false abre sin tween ---
	await _pulsar(KEY_ESCAPE)                          # cierra
	await avanzar(12)
	_ok("8 (preparación) cerrada", not p.abierta)
	Sensacion3D.ACTIVA = false
	await _pausa_de_veda()
	await _pulsar(KEY_ESCAPE)
	_ok("8 con ACTIVA = false abre sin tween (opaca y quieta al instante)", p.abierta and p.visible_ahora() and not p.animando() and is_equal_approx(p._panel.modulate.a, 1.0)
		and p._panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(p._velo.color.a, 0.55))
	_ok("8 y el sonido de abrir suena igual", Sfx.veces("libro_abre") >= 2, str(Sfx.veces("libro_abre")))
	await _pulsar(KEY_ESCAPE)
	_ok("8 cierra al instante, sin tween", not p.abierta and not p.visible_ahora() and not p.animando())
	Sensacion3D.ACTIVA = true
	await avanzar(2)

	# --- 9 · Reiniciar: pide confirmación y recarga la escena ---
	await _pausa_de_veda()
	await _pulsar(KEY_ESCAPE)
	p.fila = 0
	p.mover(5)
	_ok("9 la fila 5 es «Reiniciar nivel»", p.id_fila(p.fila) == "reiniciar")
	await _pulsar(KEY_ENTER)
	_ok("9 el primer Enter pide confirmación y no reinicia", p.confirmando == "reiniciar" and p.reinicios == 0 and is_instance_valid(maqueta) and current_scene == maqueta)
	var vieja: Node = maqueta
	var id_viejo: int = vieja.get_instance_id()
	await _pausa_de_veda()
	p.accion()                                         # el segundo Enter (directo: la recarga libera el menú en el fotograma siguiente)
	_ok("9 el segundo Enter confirma", p.reinicios == 1)
	var n: int = 0
	while n < 600 and (current_scene == null or current_scene.get_instance_id() == id_viejo):
		await process_frame
		n += 1
	await avanzar(5)
	_ok("9 la raíz de la escena es otra instancia", current_scene != null and current_scene.get_instance_id() != id_viejo, "tras %d fotogramas" % n)
	_ok("9 la vieja se liberó", not is_instance_valid(vieja) or vieja.is_queued_for_deletion())
	_ok("9 el árbol no se quedó pausado", not get_root_pausado())
	var l2: Lanzador3D = get_first_node_in_group("spellcaster") as Lanzador3D
	_ok("9 la escena nueva trae su propio MenuPausa cerrado", l2 != null and l2.pausa != null and l2.pausa != p and not l2.pausa.abierta)

	# --- limpieza ---
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Interfaz"), bus_i0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), bus_m0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Mundo"), bus_w0)
	Sensacion3D.ACTIVA = sens0
	Sfx.REGISTRAR = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PRUEBA))


func get_root_pausado() -> bool:
	return paused


func _db_ultimo(nombre: String) -> float:
	for i in range(Sfx.ULTIMOS.size() - 1, -1, -1):
		if String(Sfx.ULTIMOS[i]["nombre"]) == nombre:
			return float(Sfx.ULTIMOS[i]["db"])
	return 99.0


func _leer(seccion: String, clave: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(RUTA_PRUEBA) != OK:
		return null
	return c.get_value(seccion, clave, null)
