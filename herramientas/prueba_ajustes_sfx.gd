extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, TAREA S1 (31/10; nucleo/sfx.gd, nucleo/sfx_3d.gd, default_bus_layout.tres, laboratorios/lab_hechizos_3d.gd): el mando de volumen en vivo.
## `Sfx.AJUSTES` manda sobre los dB del catálogo en play, play_en, bucle, play_ui y Sfx3D; `imprimir_ajustes` lista solo lo cambiado; el bus «Interfaz» sale del layout del proyecto
## (−6 dB); y el panel F3 del LabHechizos3D tiene una entrada «dB:nombre» por sonido (alfabético), la del bus y la acción de imprimir, SIN mover los índices de siempre (SQUASH_XZ = 7).
## Los sonidos se miran con `Sfx.REGISTRAR` / `ULTIMOS` (headless no se oye nada); entre dos sonidos iguales se espera más que la veda de 70 ms.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ajustes_sfx.gd

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"


func _pausa() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 40)                    # la veda cuenta con el reloj de pared
	await avanzar(1)


func _ultimo(nombre: String) -> Dictionary:
	for i in range(Sfx.ULTIMOS.size() - 1, -1, -1):
		if String(Sfx.ULTIMOS[i]["nombre"]) == nombre:
			return Sfx.ULTIMOS[i]
	return {}


func _escenario() -> void:
	# --- El bus, antes de que nadie lo toque: viene del layout del proyecto ---
	var ib: int = AudioServer.get_bus_index(Sfx.BUS_INTERFAZ)
	_ok("1 el bus «Interfaz» existe nada más cargar el proyecto (default_bus_layout.tres)", ib >= 0, "índice %d" % ib)
	_ok("1 y está a −6 dB", ib >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(ib), -6.0), "%.2f" % (AudioServer.get_bus_volume_db(ib) if ib >= 0 else 99.0))
	_ok("1 y envía a Master", ib >= 0 and String(AudioServer.get_bus_send(ib)) == "Master")
	_ok("1 volumen_bus lee lo mismo", is_equal_approx(Sfx.volumen_bus(Sfx.BUS_INTERFAZ), -6.0))

	CapaBases.limpiar()
	LabHechizos3D.cargar_al_abrir = false
	await cargar(RUTA_LAB)
	var lab: Node = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio está abierto", lab != null and lab.get("_l") != null)
	if lab == null:
		return

	Sfx.REGISTRAR = true
	Sfx.AJUSTES.clear()
	Sfx.vaciar_registro()

	# --- db_de y AJUSTES ---
	_ok("2 AJUSTES vacío: db_de = catálogo (explosion)", is_equal_approx(Sfx.db_de("explosion"), -6.0))
	var todos_igual: bool = true
	for n in Sfx.CATALOGO:
		if not is_equal_approx(Sfx.db_de(String(n)), float(Sfx.CATALOGO[n]["db"])):
			todos_igual = false
	_ok("2 con AJUSTES vacío todos los sonidos dan su db del catálogo", todos_igual)
	_ok("2 un nombre desconocido da 0", is_equal_approx(Sfx.db_de("no_existe_jamas"), 0.0))
	Sfx.play(lab, "explosion")
	_ok("2 play suena a −6 dB (catálogo)", _ultimo("explosion").has("db") and is_equal_approx(float(_ultimo("explosion")["db"]), -6.0), str(_ultimo("explosion")))

	await _pausa()
	Sfx.AJUSTES["explosion"] = -20.0
	_ok("3 db_de respeta AJUSTES", is_equal_approx(Sfx.db_de("explosion"), -20.0))
	Sfx.play(lab, "explosion")
	_ok("3 play suena a −20 dB", is_equal_approx(float(_ultimo("explosion").get("db", 99.0)), -20.0), str(_ultimo("explosion")))
	# El reproductor de verdad lleva ese volumen (el último AudioStreamPlayer que cuelga de la escena con ese flujo).
	var vol_real: float = 99.0
	for h in lab.get_tree().current_scene.get_children() if lab.get_tree().current_scene != null else lab.get_tree().root.get_children():
		if h is AudioStreamPlayer3D or h is AudioStreamPlayer2D:
			vol_real = float(h.get("volume_db"))
	_ok("3 y el nodo reproductor lleva −20 dB de verdad", is_equal_approx(vol_real, -20.0), "%.2f" % vol_real)

	await _pausa()
	Sfx.vaciar_registro()
	Sfx.play_en(lab, "explosion", Vector3.ZERO)
	_ok("3 play_en también", is_equal_approx(float(_ultimo("explosion").get("db", 99.0)), -20.0))

	await _pausa()
	Sfx.play_ui("explosion")
	_ok("3 play_ui respeta AJUSTES", is_equal_approx(float(_ultimo("explosion").get("db", 99.0)), -20.0), str(_ultimo("explosion")))
	await _pausa()
	Sfx.play_ui("explosion", -5.0)
	_ok("3 play_ui con db explícito manda sobre AJUSTES", is_equal_approx(float(_ultimo("explosion").get("db", 99.0)), -5.0))

	Sfx.AJUSTES["fuego_carga_bucle"] = -30.0
	var bucle: Node = Sfx.bucle(lab, "fuego_carga_bucle")
	_ok("3 bucle respeta AJUSTES", bucle != null and is_equal_approx(float(bucle.get("volume_db")), -30.0), str(bucle.get("volume_db")) if bucle != null else "null")
	Sfx.parar(bucle, 0.0)
	Sfx.AJUSTES.erase("fuego_carga_bucle")

	# Sfx3D (su catálogo propio) consulta los mismos AJUSTES.
	var emisor := Node3D.new()
	root.add_child(emisor)
	Sfx.AJUSTES["golpe_carne"] = -33.0
	var antes3d: int = root.get_child_count()
	Sfx3D.play(emisor, "golpe_carne")
	var v3d: float = 99.0
	for h in root.get_children():
		if h is AudioStreamPlayer3D:
			v3d = float(h.volume_db)
	_ok("3 Sfx3D.play respeta AJUSTES (−33 dB)", root.get_child_count() > antes3d and is_equal_approx(v3d, -33.0), "%.2f" % v3d)
	Sfx.AJUSTES.erase("golpe_carne")

	# --- imprimir_ajustes: solo lo cambiado ---
	Sfx.AJUSTES.clear()
	Sfx.AJUSTES["explosion"] = -20.0
	Sfx.AJUSTES["chispa"] = float(Sfx.CATALOGO["chispa"]["db"])        # igual al catálogo: no cuenta
	Sfx.AJUSTES["moneda"] = -9.5
	var texto: String = Sfx.imprimir_ajustes()
	_ok("4 imprime la explosión en formato de catálogo", texto.contains("\"explosion\": {\"db\": -20"), texto)
	_ok("4 imprime la moneda", texto.contains("\"moneda\": {\"db\": -9.5"))
	_ok("4 NO imprime la chispa (igual al catálogo)", not texto.contains("\"chispa\""))
	_ok("4 NO imprime sonidos sin tocar", not texto.contains("\"fuego\""))
	Sfx.AJUSTES.clear()
	_ok("4 sin cambios dice que no hay ninguno", Sfx.imprimir_ajustes().contains("ningún sonido cambiado"))

	# --- El panel F3 ---
	var todas: Array = LabHechizos3D.entradas()
	var base: Array = LabHechizos3D.IMPACTO
	var prefijo_igual: bool = true
	for i in range(base.size()):
		if String((todas[i] as Dictionary)["n"]) != String((base[i] as Dictionary)["n"]):
			prefijo_igual = false
	_ok("5 las entradas de siempre siguen en su sitio", prefijo_igual and todas.size() > base.size())
	_ok("5 el índice 7 sigue siendo SQUASH_XZ", String(todas[7]["n"]) == "SQUASH_XZ")
	var nombres_db: Array = []
	for i in range(base.size(), todas.size()):
		nombres_db.append(String(todas[i]["n"]))
	# 2/11 (tercera tanda, N): detrás de los buses van las dos filas del ciclo día/noche (S:HORA y S:DURACION_DIA_S), siempre al final para no mover índices.
	# 2/11 (tareas L y W): detrás de las tres dB nuevas van las filas L:, Mp:, S:BALANCEO, W:, Hb: y Hu: (las static var de la mano pasando página y del caminar), siempre al final.
	var n_lw: int = LabHechizos3D.FILAS_L.size() + LabHechizos3D.FILAS_MP.size() + LabHechizos3D.FILAS_S_W.size() + LabHechizos3D.FILAS_W.size() + LabHechizos3D.FILAS_HB.size() + LabHechizos3D.FILAS_HU.size()
	var fin_r: int = nombres_db.size() - n_lw              # índice justo después de la cola de la tarea R
	# 12/11/2026: 76d94b95 (10/11, foley de Sonniss) añadió la fila «S:SONNISS» justo detrás de S:GRABADOS: ahora son 8 filas fijas (antes 7).
	_ok("5 hay una entrada «dB:» por sonido del catálogo, más el bus, la acción, (tarea O, 1/11) los buses «Mundo» y «Ocluido» y (tercera tanda N) las dos del ciclo día/noche y (2/11, tarea R) S:GRABADOS, (10/11) S:SONNISS y las tres filas dB nuevas, y (tareas L y W) las filas L:/Mp:/S:/W:/Hb:/Hu: del final", nombres_db.size() == Sfx.CATALOGO.size() + 8 + n_lw, "%d vs %d" % [nombres_db.size(), Sfx.CATALOGO.size() + 8 + n_lw])
	_ok("5 tras los sonidos van «dB:Interfaz (bus)» y «dB:imprimir ajustes», luego (tarea O) «dB:Mundo (bus)» y «dB:Ocluido (bus)», «S:HORA» y «S:DURACION_DIA_S», S:GRABADOS, S:SONNISS y las tres dB de la tarea R", nombres_db[fin_r - 11] == "dB:Interfaz (bus)" and nombres_db[fin_r - 10] == "dB:imprimir ajustes" and nombres_db[fin_r - 9] == "dB:Mundo (bus)" and nombres_db[fin_r - 8] == "dB:Ocluido (bus)" and nombres_db[fin_r - 7] == "S:HORA" and nombres_db[fin_r - 6] == "S:DURACION_DIA_S" and nombres_db[fin_r - 5] == "S:GRABADOS" and nombres_db[fin_r - 4] == "S:SONNISS" and nombres_db[fin_r - 3] == "dB:no_puedes_ui" and nombres_db[fin_r - 2] == "dB:paginas_bucle" and nombres_db[fin_r - 1] == "dB:pluma_bucle")
	_ok("5 (tareas L y W) el bloque del final empieza por «L:PASAR_PAGINA_ANIMADO» y acaba en «Hu:ALTO_HUELLA», y ninguna fila suya es «dB:»", nombres_db[fin_r] == "L:PASAR_PAGINA_ANIMADO" and nombres_db[nombres_db.size() - 1] == "Hu:ALTO_HUELLA" and not nombres_db.slice(fin_r).any(func(n: String) -> bool: return n.begins_with("dB:")))
	_ok("5 «W:PISADO_CORRER» lee y escribe Caminar3D (0,55 de partida)", is_equal_approx(LabHechizos3D.impacto_valor("W:PISADO_CORRER"), 0.55))
	var alfabetico: bool = true
	for i in range(1, fin_r - 11):
		if String(nombres_db[i - 1]) > String(nombres_db[i]):
			alfabetico = false
	_ok("5 los sonidos van en orden alfabético", alfabetico)
	var i_exp: int = nombres_db.find("dB:explosion") + base.size()
	_ok("5 «dB:explosion» está", i_exp >= base.size())
	_ok("5 su valor inicial es el del catálogo (−6)", is_equal_approx(LabHechizos3D.impacto_valor("dB:explosion"), -6.0))

	Sfx.AJUSTES.clear()
	Sfx.vaciar_registro()
	await _pausa()                                     # la veda de play_ui: el «explosion» de arriba acaba de sonar
	lab.set("impacto_sel", i_exp)                      # la ventana del panel sigue a la elegida
	var v_nuevo: float = float(lab.call("impacto_cambiar", i_exp, -4))
	_ok("5 ← cuatro pasos de 1 dB deja −10 dB", is_equal_approx(v_nuevo, -10.0), str(v_nuevo))
	_ok("5 y lo escribe en Sfx.AJUSTES", Sfx.AJUSTES.has("explosion") and is_equal_approx(float(Sfx.AJUSTES["explosion"]), -10.0), str(Sfx.AJUSTES))
	_ok("5 y lo reproduce al instante (play_ui, −10 dB)", Sfx.veces("explosion") == 1 and is_equal_approx(float(_ultimo("explosion").get("db", 99.0)), -10.0), str(Sfx.CONTEO))
	_ok("5 el panel de texto muestra el cambio", String(lab.call("_texto_impacto")).contains("dB:explosion") and String(lab.call("_texto_impacto")).contains("era -6.000"))
	await _pausa()
	lab.call("impacto_cambiar", i_exp, 4)
	_ok("5 volver al valor del catálogo borra el ajuste", not Sfx.AJUSTES.has("explosion"), str(Sfx.AJUSTES))

	# El bus.
	var i_bus: int = nombres_db.find("dB:Interfaz (bus)") + base.size()
	ib = AudioServer.get_bus_index(Sfx.BUS_INTERFAZ)
	_ok("6 «dB:Interfaz (bus)» arranca en −6", is_equal_approx(LabHechizos3D.impacto_valor("dB:Interfaz (bus)"), -6.0))
	lab.call("impacto_cambiar", i_bus, -3)
	_ok("6 la entrada del bus mueve AudioServer (−9 dB)", is_equal_approx(AudioServer.get_bus_volume_db(ib), -9.0), "%.2f" % AudioServer.get_bus_volume_db(ib))
	_ok("6 y volumen_bus lo confirma", is_equal_approx(Sfx.volumen_bus(Sfx.BUS_INTERFAZ), -9.0))
	_ok("6 imprimir_ajustes avisa de que el bus no está a su partida", Sfx.imprimir_ajustes().contains("bus «Interfaz»"))
	lab.call("impacto_restaurar")
	_ok("6 Retroceso (restaurar) devuelve el bus a −6", is_equal_approx(AudioServer.get_bus_volume_db(ib), -6.0), "%.2f" % AudioServer.get_bus_volume_db(ib))
	_ok("6 fijar_volumen_bus sobre un bus inexistente devuelve false", not Sfx.fijar_volumen_bus("No_Existe", -1.0))

	# La acción de imprimir.
	var i_imp: int = nombres_db.find("dB:imprimir ajustes") + base.size()
	Sfx.AJUSTES["moneda"] = -9.5
	var r: float = float(lab.call("impacto_cambiar", i_imp, 1))
	_ok("7 «dB:imprimir ajustes» a 1 imprime y vuelve a 0", is_equal_approx(r, 1.0) and is_equal_approx(LabHechizos3D.impacto_valor("dB:imprimir ajustes"), 0.0))
	Sfx.AJUSTES.clear()

	# Teclas: ↑ desde la primera da la vuelta al final; la ventana sigue a la elegida y no enseña más de VENTANA filas.
	lab.set("impacto_sel", 0)
	lab.set("pestana", LabHechizos3D.Pestana.IMPACTO)
	# 12/11/2026: desde b87ca18e el lab abre con el CATÁLOGO (F7) delante y, mientras está abierto, solo atiende F1–F5 y R: ↑ no llegaba al panel F3.
	# Se cierra como lo haría Pablo (F3 lo cierra al cambiar de pestaña; aquí, directo).
	lab.call("poner_catalogo", false)
	var ev := InputEventKey.new()
	ev.keycode = KEY_UP
	ev.pressed = true
	lab._unhandled_input(ev)
	_ok("8 ↑ desde la primera da la vuelta a la última entrada", int(lab.get("impacto_sel")) == todas.size() - 1 and String(todas[todas.size() - 1]["n"]) == "Hu:ALTO_HUELLA", str(lab.get("impacto_sel")))
	var txt: String = String(lab.call("_texto_impacto"))
	var filas: int = 0
	for l in txt.split("\n"):
		if l.begins_with("►") or l.begins_with(" ") and l.length() > 30:
			filas += 1
	_ok("8 el panel enseña la elegida y un máximo de %d filas" % LabHechizos3D.VENTANA_IMPACTO, txt.contains("► Hu:ALTO_HUELLA") and filas <= LabHechizos3D.VENTANA_IMPACTO + 2, "%d filas" % filas)
	_ok("8 y avisa de que hay más arriba", txt.contains("más arriba"))
	lab.set("impacto_sel", 0)
	_ok("8 con la primera elegida avisa de que hay más abajo", String(lab.call("_texto_impacto")).contains("más abajo"))

	# Lo guardado no arrastra volúmenes sin tocar ni la acción.
	var tabla: Dictionary = lab.call("impacto_tabla")
	var hay_db: bool = false
	for n in tabla:
		if String(n).begins_with("dB:"):
			hay_db = true
	_ok("9 impacto_tabla no guarda volúmenes sin tocar", not hay_db)
	Sfx.AJUSTES.clear()
	Sfx.REGISTRAR = false
