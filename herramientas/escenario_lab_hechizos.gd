extends "res://herramientas/escenario_base.gd"
## Escenario H1 · el LABORATORIO DE HECHIZOS (laboratorios/LabHechizos3D.tscn), sin ventana (18/10, Juego). Antes era escenario_lab_recetas (R4, 17/10): las
## secciones 0–6 son aquellas, intactas (sala, goblins quietos, contadores y HUD, lanzamiento rápido, barrido, tiempo) y de la 7 en adelante lo nuevo:
## pestañas F1–F3 y las constantes de Combate3D en vivo, el MODO CONJURO COMPLETO (las 4 fases salen en orden y el disparo llega), tinta infinita y
## recarga apagada (y sus interruptores), el goblin que ataca y la limpieza de la sala entre rondas del barrido.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_lab_hechizos.gd
## Lo que el barrido anota como «rara» se imprime como AVISO (es información para Pablo, no un fallo).

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"
const SEMIEJE_TIERRA_LAB: float = 0.7      ## semieje en X y Z del bloque de tierra de la prueba 10 (con la base 0,25 y paso 0,15 eran 3 glifos de cada, el límite del lab)


## Los glifos de un eje que hacen falta para llegar a `semieje` casillas con la base y el paso de hoy.
func _glifos_hasta(semieje: float) -> int:
	return ceili((semieje - Sigils.RADIO_BASE_V2) / Sigils.PASO_EJE_V2 - 0.0001)

var lab: Node = null


class ContadorFisica extends Node:
	var n: int = 0
	func _physics_process(_d: float) -> void:
		n += 1


func _tecla_lab(k: Key, shift: bool = false, ctrl: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	lab._unhandled_input(ev)


func _escenario() -> void:
	LabHechizos3D.cargar_al_abrir = false                  # 19/10: el lab recarga user://lab_hechizos.json al abrir; la prueba no debe leer lo que dejó una sesión de diseño
	CapaBases.limpiar()
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena y se ha iniciado", lab != null and lab.get("tiempo") != null and lab.get("_l") != null)
	if lab == null or lab.get("tiempo") == null:
		return
	_ok("0 el mapa tiene lo que el lab espera (sin avisos de Puzle3D)", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	_ok("0 Espacio no salta (salto_activo = false)", jugador.get("salto_activo") == false)

	# --- La sala: dianas, goblins, combustibles, agua ---
	var muneco: int = 0
	for n in get_nodes_en_arbol():
		if n.name.begins_with("dummy") or n.is_in_group("dummy"):
			muneco += 1
	var combates: Array = root.get_tree().get_nodes_in_group("combate3d")
	_ok("1 hay cuatro goblins en la sala (tres quietos y uno que puede atacar)", combates.size() == 4, "%d" % combates.size())
	var libres: int = 0
	for c in combates:
		if not (c as Combate3D).quieto:
			libres += 1
	_ok("1 los cuatro goblins empiezan quietos (el interruptor del que ataca está apagado)", libres == 0, "libres %d" % libres)
	colocar_jugador(Vector2i(4, 8))
	var antes: Array = []
	for c in combates:
		antes.append((c as Node3D).position)
	await avanzar_s(4.0)       # el jugador está a 15-19 casillas: sin `quieto` ya habrían ido a por él (RADIO_DETECCION)
	var movidos: int = 0
	for i in range(combates.size()):
		if ((combates[i] as Node3D).position - (antes[i] as Vector3)).length() > 0.05:
			movidos += 1
	_ok("1 tras 4 s los goblins no se han movido", movidos == 0, "movidos %d" % movidos)
	# Aun cerca de ellos siguen sin atacar ni perseguir.
	colocar_jugador(Vector2i(20, 8))
	await avanzar_s(3.0)
	var hp0: float = float(jugador.get("vida")) if jugador.get("vida") != null else 0.0
	movidos = 0
	for i in range(combates.size()):
		if ((combates[i] as Node3D).position - (antes[i] as Vector3)).length() > 0.3:
			movidos += 1
	_ok("1 con el jugador a su lado tampoco se mueven (ni persiguen)", movidos == 0, "movidos %d" % movidos)
	colocar_jugador(Vector2i(4, 8))
	await avanzar_s(0.5)

	# --- Contadores y glifos ---
	var glifos: Array = Sigils.GLIFOS_V2.keys()
	_ok("2 el panel tiene un contador por glifo de GLIFOS_V2", (lab.get("_panel_cuentas") as Dictionary).size() == glifos.size() and glifos.size() == 10, str(glifos))        # 19/10: + permanencia (ᛉ) · 23/10: + raido (ᚱ «pulso»)
	lab.limpiar()
	lab.sumar("linea_z", 1)
	lab.sumar("linea_z", 1)
	_ok("2 sumar dos linea_z da z = base + 2 pasos (%.2f)" % (Sigils.RADIO_BASE_V2 + 2.0 * Sigils.PASO_EJE_V2), is_equal_approx(float(lab.receta().geo()["z"]), Sigils.RADIO_BASE_V2 + 2.0 * Sigils.PASO_EJE_V2), str(lab.receta().geo()["z"]))
	lab.limite_glifos = false                              # 19/10: con el límite de 6 glifos no se llegaría al tope de ᛁ (19): aquí se mide el tope de cada glifo, no el límite
	for _i in range(lab.glifos_hasta_tope("linea_z") + 3):
		lab.sumar("linea_z", 1)
	lab.limite_glifos = true
	_ok("2 el contador se para en tope + 1", int(lab.contadores["linea_z"]) == lab.glifos_hasta_tope("linea_z") + 1, "%d" % int(lab.contadores["linea_z"]))
	_ok("2 más allá del tope la geometría no crece", float(lab.receta().geo()["z"]) <= 3.0 + 0.0001, str(lab.receta().geo()["z"]))
	lab.sumar("linea_z", -100)
	_ok("2 restar hasta cero borra el glifo", not lab.contadores.has("linea_z"))
	for g in glifos:
		_ok("2 tope de %s sale de la tabla y es ≥ 1" % g, lab.glifos_hasta_tope(String(g)) >= 1, "%d" % lab.glifos_hasta_tope(String(g)))
	_tecla_lab(KEY_KP_1)
	_tecla_lab(KEY_KP_1)
	_tecla_lab(KEY_KP_1, true)
	_ok("2 Numpad 1 suma y Mayús+Numpad 1 resta", int(lab.contadores.get(String(glifos[0]), 0)) == 1, str(lab.contadores))
	_tecla_lab(KEY_KP_0)
	_ok("2 Numpad 0 limpia", lab.contadores.is_empty())
	# 23/10: el panel muestra el nombre que ve el jugador (ᚷ «crecer», ᚱ «pulso»), no el id interno («pulso», «raido»); y ᚱ (el 10.º glifo) tiene su tecla del Numpad
	var nombres_ok: bool = true
	for g in glifos:
		var fila: Node = (lab.get("_panel_cuentas") as Dictionary)[g].get_parent()
		nombres_ok = nombres_ok and (fila.get_child(0) as Label).text == Sigils.nombre_visible(String(g))
	_ok("2 cada fila del panel lleva el nombre visible del glifo (nombre_visible)", nombres_ok and Sigils.nombre_visible("pulso") == "crecer" and Sigils.nombre_visible("raido") == "pulso")
	_tecla_lab(KEY_F1)
	_tecla_lab(KEY_KP_PERIOD)
	_tecla_lab(KEY_KP_9)
	_ok("2 Numpad . suma el 10.º glifo (ᚱ raido) y Numpad 9 el 9.º (permanencia)", int(lab.contadores.get("raido", 0)) == 1 and int(lab.contadores.get(String(glifos[8]), 0)) == 1, str(lab.contadores))
	_tecla_lab(KEY_KP_PERIOD, true)
	_ok("2 Mayús+Numpad . lo resta", not lab.contadores.has("raido"), str(lab.contadores))
	lab.sumar("pulso", 1)
	lab.sumar("raido", 1)
	var texto_glifos: String = String(lab.call("_glifos_texto"))
	_ok("2 el texto de la receta dice «crecer×1 pulso×1» y no los ids internos", texto_glifos.contains("crecer×1") and texto_glifos.contains("pulso×1") and not texto_glifos.contains("raido"), texto_glifos)
	_tecla_lab(KEY_KP_0)
	lab.poner_elemento("water")
	_tecla_lab(KEY_TAB)
	_ok("2 Tab pasa al siguiente elemento (water → earth)", String(lab.elemento) == "earth", String(lab.elemento))
	lab.poner_elemento("fire")

	# --- HUD ---
	lab.limpiar()
	lab.sumar("linea_z", 1)
	lab.sumar("flecha", 1)
	var hud: String = lab.texto_hud()
	_ok("3 el HUD enseña el coste (relativo y en tinta)", hud.contains("Coste") and hud.contains("de tinta"), hud.get_slice("\n", 2))
	_ok("3 el HUD enseña el nombre derivado", hud.contains("Nombre derivado: x_mano"), hud.get_slice("\n", 3))
	_ok("3 el HUD enseña el estado de la materia", hud.contains("Estado: "), hud.get_slice("\n", 4))
	_ok("3 el HUD enseña los semiejes del elipsoide", hud.contains("Elipsoide") and hud.contains("z %.2f" % (Sigils.RADIO_BASE_V2 + Sigils.PASO_EJE_V2)), hud.get_slice("\n", 1))
	var alambre: ImmediateMesh = (lab.get("_alambre") as MeshInstance3D).mesh as ImmediateMesh
	var casillas: ImmediateMesh = (lab.get("_casillas") as MeshInstance3D).mesh as ImmediateMesh
	_ok("3 el elipsoide está dibujado (alambre) y las casillas también", alambre.get_surface_count() == 1 and casillas.get_surface_count() == 1)
	lab.limpiar()
	lab.sumar("altura", 1)
	_ok("3 el nombre derivado de altura es «alto»", lab.texto_hud().contains("Nombre derivado: alto"))
	lab.limpiar()

	# --- Lanzar ---
	lab.poner_elemento("fire")
	lab.sumar("linea_z", 1)
	jugador.call("mirar_hacia", Vector3.RIGHT)
	await avanzar(2)
	var ficha: Dictionary = lab.lanzar()
	_ok("4 lanzar devuelve la ficha medida (casillas, ms, estado)", int(ficha["n"]) > 0 and int(ficha["celdas"]) > 0 and float(ficha["ms"]) >= 0.0 and String(ficha["estado"]) != "", str(ficha))
	_ok("4 se anota como lanzada", int(lab.lanzadas) == 1)
	await avanzar_s(1.5)
	_ok("4 la vigilancia se cierra sola a los 0,8 s", (lab.get("_obs") as Dictionary).is_empty())
	_ok("4 la vigilancia vio nodos nuevos (el indicador de «algo visible» funciona)", int(ficha["nodos_pico"]) > 0, "pico %d, motivos %s" % [int(ficha["nodos_pico"]), str(ficha["motivos"])])
	_ok("4 lo lanzado se pinta en verde", ((lab.get("_lanzado") as MeshInstance3D).mesh as ImmediateMesh).get_surface_count() == 1)
	# Espacio lanza igual que el botón.
	lab.limpiar()
	await avanzar_s(1.0)
	var antes_l: int = int(lab.lanzadas)
	_tecla_lab(KEY_SPACE)
	_ok("4 Espacio lanza", int(lab.lanzadas) == antes_l + 1)
	await avanzar_s(1.0)
	# Un sólido demasiado alto se rechaza y queda anotado como rara.
	lab.limpiar()
	lab.poner_elemento("earth")
	lab.limite_glifos = false                # 24/10: con base 0,10 los 2 niveles (y ≥ 0,75) piden 7 glifos, más que el límite de 6
	for _i in range(_glifos_hasta(0.75)):    # 2 niveles (el tope de altura es 1,0): más de los que se pueden pisar
		lab.sumar("altura", 1)
	lab.limite_glifos = true
	var n_raras: int = (lab.raras as Array).size()
	var f2: Dictionary = lab.lanzar()
	await avanzar_s(1.2)
	_ok("4 un sólido demasiado alto no se lanza (n = 0) y se anota receta_rara «rechazada»", int(f2["n"]) == 0 and (lab.raras as Array).size() == n_raras + 1 and (lab.raras.back()["motivos"] as Array).has("rechazada"), str(lab.raras.back() if not (lab.raras as Array).is_empty() else {}))
	_ok("4 PlayLog tiene el evento receta_rara", eventos("receta_rara").size() >= 1)
	lab.limpiar()
	lab.poner_elemento("fire")

	# --- Barrido ---
	lab.set("semilla", 7)
	lab.get("_rng").seed = 7
	var a: Array = []
	for _i in range(5):
		var r: Dictionary = lab.receta_al_azar()
		a.append(str(r))
	lab.get("_rng").seed = 7
	var b: Array = []
	for _i in range(5):
		b.append(str(lab.receta_al_azar()))
	_ok("5 la misma semilla da el mismo barrido", a == b)
	_ok("5 las recetas al azar no se pasan de MAX_GLIFOS_BARRIDO ni del tope + 1", _barrido_valido(lab))
	lab.iniciar_barrido(5, 42)
	_ok("5 B arranca el barrido y escribe barrido_inicio", lab.barrido and eventos("barrido_inicio").size() >= 1)
	var t_ini: float = reloj.t
	var guard: int = 0
	while lab.barrido and reloj.t - t_ini < 40.0 and guard < 4000:
		await process_frame
		guard += 1
	_ok("5 el barrido hace sus 5 rondas y se para solo", int(lab.rondas) == 5 and not lab.barrido, "rondas %d" % int(lab.rondas))
	_ok("5 cada ronda tarda ≥ 2 s de juego (5 rondas ≥ 8 s)", reloj.t - t_ini >= 8.0, "%.1f s" % (reloj.t - t_ini))
	_ok("5 barrido_fin queda en PlayLog con las rondas", eventos("barrido_fin").size() >= 1)
	for r in lab.raras:
		_aviso("receta_rara del barrido", JSON.stringify(r))
	_aviso("barrido", "5 rondas, %d raras, semilla 42" % (lab.raras as Array).size())
	_tecla_lab(KEY_B)
	_ok("5 la tecla B alterna el barrido", lab.barrido)
	_tecla_lab(KEY_B)
	_ok("5 y otra vez B lo para", not lab.barrido)

	# --- Tiempo compartido (L, ., ,) ---
	var tiempo: TiempoLab3D = lab.tiempo
	var cuenta := ContadorFisica.new()
	root.add_child(cuenta)
	var ev_l := InputEventKey.new()
	ev_l.keycode = KEY_L
	ev_l.pressed = true
	tiempo._unhandled_input(ev_l)
	_ok("6 L pone cámara lenta a 0,25×", is_equal_approx(Engine.time_scale, 0.25) and tiempo.lenta)
	tiempo._unhandled_input(ev_l)
	_ok("6 otra L la quita", is_equal_approx(Engine.time_scale, 1.0) and not tiempo.lenta)
	tiempo.paso()
	_ok("6 la primera `.` pausa", get_root_pausado())
	await avanzar(3)
	var n0: int = cuenta.n
	await avanzar(5)
	_ok("6 en pausa no corre la física", cuenta.n == n0, "%d → %d" % [n0, cuenta.n])
	tiempo.paso()
	await avanzar(6)
	var dado: int = cuenta.n - n0
	_ok("6 cada `.` siguiente avanza un fotograma de física", dado >= 1 and dado <= 2, "%d" % dado)
	if dado != 1:
		_aviso("paso a paso", "avanzó %d fotogramas de física por pulsación (a --fixed-fps 30 el fotograma físico son 2 de 60)" % dado)
	_ok("6 sigue en pausa tras el paso", get_root_pausado())
	tiempo.reanudar()
	var n1: int = cuenta.n
	await avanzar(6)
	_ok("6 `,` reanuda la física", cuenta.n > n1 and not get_root_pausado())
	cuenta.queue_free()
	tiempo._exit_tree()
	_ok("6 al salir se devuelve la velocidad normal", is_equal_approx(Engine.time_scale, 1.0))

	# =====================================================================================================================
	#  H1: lo nuevo
	# =====================================================================================================================
	lab.limpiar()
	lab.poner_elemento("fire")

	# --- 7 · Pestañas y F3 Impacto ---
	_ok("7 empieza en F1 Receta", int(lab.pestana) == LabHechizos3D.Pestana.RECETA)
	_tecla_lab(KEY_F3)
	_ok("7 F3 abre la pestaña Impacto", int(lab.pestana) == LabHechizos3D.Pestana.IMPACTO)
	_ok("7 el HUD de F3 lista las constantes de Combate3D", lab.texto_hud().contains("MULT_EMPUJE") and lab.texto_hud().contains("HITSTOP") and lab.texto_hud().contains("EMPUJE_MIN_CASILLAS"))
	var mult0: float = Combate3D.MULT_EMPUJE
	_ok("7 la tabla F3 lee el valor real de Combate3D", is_equal_approx(LabHechizos3D.impacto_valor("MULT_EMPUJE"), mult0))
	lab.impacto_sel = 0
	_tecla_lab(KEY_RIGHT)
	_ok("7 → sube MULT_EMPUJE un paso EN VIVO (la estática de Combate3D cambia)", is_equal_approx(Combate3D.MULT_EMPUJE, mult0 + 0.25), "%f" % Combate3D.MULT_EMPUJE)
	_tecla_lab(KEY_RIGHT, true)
	_ok("7 Mayús+→ sube diez pasos", is_equal_approx(Combate3D.MULT_EMPUJE, minf(mult0 + 0.25 + 2.5, 10.0)), "%f" % Combate3D.MULT_EMPUJE)
	_tecla_lab(KEY_DOWN)
	_ok("7 ↓ elige la siguiente constante", int(lab.impacto_sel) == 1)
	var sq0: Vector3 = Combate3D.SQUASH_ESCALA
	lab.impacto_cambiar(7, 1)
	_ok("7 SQUASH_XZ cambia X y Z de SQUASH_ESCALA y deja la Y", is_equal_approx(Combate3D.SQUASH_ESCALA.x, sq0.x + 0.05) and is_equal_approx(Combate3D.SQUASH_ESCALA.z, sq0.z + 0.05) and is_equal_approx(Combate3D.SQUASH_ESCALA.y, sq0.y))
	for _i in range(100):
		lab.impacto_cambiar(0, 1)
	_ok("7 los topes se respetan (MULT_EMPUJE ≤ 10)", is_equal_approx(Combate3D.MULT_EMPUJE, 10.0), "%f" % Combate3D.MULT_EMPUJE)
	_ok("7 la tabla para volcar dice «antes» de lo cambiado", lab.tabla_texto().contains("MULT_EMPUJE = 10") and lab.tabla_texto().contains("(antes"))
	_tecla_lab(KEY_BACKSPACE)
	_ok("7 Retroceso restaura todo lo de F3", is_equal_approx(Combate3D.MULT_EMPUJE, mult0) and Combate3D.SQUASH_ESCALA.is_equal_approx(sq0))
	_tecla_lab(KEY_G)
	var f_json := FileAccess.open(LabHechizos3D.RUTA_GUARDADO, FileAccess.READ)
	var json: Variant = JSON.parse_string(f_json.get_as_text()) if f_json != null else null
	_ok("7 G guarda user://lab_hechizos.json con la tabla de impacto", json is Dictionary and (json as Dictionary).has("impacto") and ((json as Dictionary)["impacto"] as Dictionary).has("HITSTOP"))
	_tecla_lab(KEY_F2)
	_ok("7 F2 abre Cast point", int(lab.pestana) == LabHechizos3D.Pestana.CAST_POINT)
	_tecla_lab(KEY_F1)
	_ok("7 F1 vuelve a Receta y su HUD es el de siempre", int(lab.pestana) == LabHechizos3D.Pestana.RECETA and lab.texto_hud().contains("Nombre derivado"))

	# --- 8 · Modo conjuro completo ---
	_ok("8 el modo por defecto es el rápido", not lab.modo_completo)
	_tecla_lab(KEY_C)
	_ok("8 C activa el CONJURO COMPLETO", lab.modo_completo and lab.texto_hud().contains("CONJURO COMPLETO"))
	_ok("8 tinta infinita y recarga apagada por defecto", lab.tinta_infinita and not lab.recarga_activa)
	lab.limpiar()
	lab.sumar("linea_z", 1)
	lab.poner_elemento("fire")
	jugador.call("mirar_hacia", Vector3.RIGHT)
	colocar_jugador(Vector2i(4, 8))
	await avanzar_s(1.0)
	if lanzador.tinta != null:
		lanzador.tinta.actual = 3.0              # casi sin tinta: con la tinta infinita igual lanza
	var celdas_hechizo: Array = []
	var capturar := func(_e: String, _el: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void: celdas_hechizo.assign(g["celdas"])
	lanzador.hechizo_v2.connect(capturar)
	var n_conj: int = eventos("conjuro").size()
	var ficha_c: Dictionary = lab.lanzar()
	_ok("8 el lanzamiento completo no se rechaza", String(ficha_c.get("rechazo", "x")) == "" and bool(ficha_c.get("completo", false)), str(ficha_c))
	await avanzar(2)
	_ok("8 mientras conjura NO ha salido aún el hechizo (el disparo llega después)", lanzador.conjurando and celdas_hechizo.is_empty())
	var t_esp: float = 0.0
	while lanzador.conjurando and t_esp < 6.0:
		t_esp += await avanzar_s(0.1)
	await avanzar(2)
	var nombres: Array = []
	for f in lab.fases_vistas:
		nombres.append(String(f["fase"]))
	_ok("8 las 4 fases salen EN ORDEN: runa, voluta, forma, disparo", nombres == ["runa", "voluta", "forma", "disparo"], str(nombres))
	var crec: bool = true
	for i in range(1, lab.fases_vistas.size()):
		crec = crec and int(lab.fases_vistas[i]["t_ms"]) >= int(lab.fases_vistas[i - 1]["t_ms"])
	_ok("8 los tiempos de las fases no retroceden", crec, str(lab.fases_vistas))
	_ok("8 el disparo llega: salió el hechizo (señal hechizo_v2 con casillas)", not celdas_hechizo.is_empty(), "%d casillas" % celdas_hechizo.size())
	_ok("8 la ficha se completa al disparar (n, ms)", int(ficha_c["n"]) > 0 and float(ficha_c["ms"]) >= 0.0, str(ficha_c))
	_ok("8 el conjuro tardó lo previsto: runa + voluta + forma (± 0,3 s de juego)", absf(float(lab.fases_vistas.back()["t_ms"]) / 1000.0 - lanzador.retardo_total("fuego")) < 0.3 or absf(float(lab.fases_vistas.back()["t_ms"]) / 1000.0 - lanzador.retardo_total("fire")) < 0.3, "%d ms; previsto %.2f" % [int(lab.fases_vistas.back()["t_ms"]), lanzador.retardo_total("fuego")])
	_ok("8 PlayLog anota el conjuro (el camino real)", eventos("conjuro").size() > n_conj)
	if lanzador.tinta != null:
		_ok("8 con la tinta infinita se rellena antes de lanzar (quedó > 50 tras gastar)", lanzador.tinta.actual > 50.0, "%.1f" % lanzador.tinta.actual)
	_ok("8 con la recarga apagada no queda recarga", float(lanzador.cooldown_left[0]) == 0.0)
	await avanzar_s(1.0)
	_ok("8 la vigilancia empezó al disparar y vio nodos nuevos (no es un falso «sin efecto visible»)", int(ficha_c["nodos_pico"]) > 0 and not (ficha_c["motivos"] as Array).has("sin_efecto_visible"), str(ficha_c["motivos"]) + " pico %d" % int(ficha_c["nodos_pico"]))
	# Una segunda tirada mientras conjura se rechaza como «conjurando».
	var f_a: Dictionary = lab.lanzar()
	await avanzar(2)
	var f_b: Dictionary = lab.lanzar()
	_ok("8 lanzar otra vez mientras conjura se rechaza («conjurando»)", String(f_b.get("rechazo", "")) == "conjurando", str(f_b.get("rechazo", "")))
	t_esp = 0.0
	while lanzador.conjurando and t_esp < 6.0:
		t_esp += await avanzar_s(0.1)
	await avanzar_s(1.0)
	# Interruptores de medida: tinta real y recarga real.
	_tecla_lab(KEY_KP_ADD)
	_ok("8 Numpad + pasa a tinta real", not lab.tinta_infinita)
	if lanzador.tinta != null:
		lanzador.tinta.actual = 0.0
		var f_t: Dictionary = lab.lanzar()
		_ok("8 con tinta real y sin tinta NO lanza («sin_tinta») y no sale ninguna fase", String(f_t.get("rechazo", "")) == "sin_tinta" and not lanzador.conjurando, str(f_t.get("rechazo", "")))
		lanzador.tinta.actual = lanzador.tinta.maxima
	_tecla_lab(KEY_KP_ADD)
	_ok("8 Numpad + vuelve a tinta infinita", lab.tinta_infinita)
	_tecla_lab(KEY_KP_SUBTRACT)
	_ok("8 Numpad − pasa a recarga real", lab.recarga_activa)
	var f_r1: Dictionary = lab.lanzar()
	t_esp = 0.0
	while lanzador.conjurando and t_esp < 6.0:
		t_esp += await avanzar_s(0.1)
	var cd: float = float(lanzador.cooldown_left[0])
	if cd > 0.0:
		var f_r2: Dictionary = lab.lanzar()
		_ok("8 con recarga real la segunda tirada espera a que acabe la recarga", String(f_r2.get("rechazo", "")) == "recarga", "%s (queda %.2f)" % [str(f_r2.get("rechazo", "")), cd])
	else:
		_aviso("recarga real", "la receta lanzada no tiene recarga (cooldown 0): no se puede comprobar el rechazo")
	_tecla_lab(KEY_KP_SUBTRACT)
	_ok("8 Numpad − vuelve a recarga apagada", not lab.recarga_activa)
	lanzador.hechizo_v2.disconnect(capturar)
	await avanzar_s(1.5)
	# Modo rápido otra vez: sale en el mismo fotograma.
	_tecla_lab(KEY_C)
	_ok("8 otra C vuelve al modo rápido", not lab.modo_completo)
	var celdas_r: Array = []
	var capt2 := func(_e: String, _el: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void: celdas_r.assign(g["celdas"])
	lanzador.hechizo_v2.connect(capt2)
	lab.lanzar()
	_ok("8 en el modo rápido el hechizo sale en el mismo fotograma (sin fases)", not celdas_r.is_empty() and not lanzador.conjurando)
	lanzador.hechizo_v2.disconnect(capt2)
	await avanzar_s(1.0)

	# --- 9 · Goblin que ataca ---
	var atq: Combate3D = lab.atacante
	_ok("9 el lab sabe cuál es el goblin que ataca (el de la celda GOBLIN_ATACANTE)", atq != null and Terreno3D.celda_de(atq.position).distance_to(Vector2(LabHechizos3D.GOBLIN_ATACANTE)) < 2.5, str(Terreno3D.celda_de(atq.position) if atq != null else "null"))
	_ok("9 empieza quieto (Combate3D.quieto = true)", atq != null and atq.quieto and not lab.atacar_goblin)
	var pos_q: Vector3 = atq.position
	colocar_jugador(Vector2i(21, 12))
	await avanzar_s(2.0)
	_ok("9 quieto no se acerca aunque el jugador esté a 2 casillas", (atq.position - pos_q).length() < 0.1, "%.2f" % (atq.position - pos_q).length())
	_tecla_lab(KEY_KP_MULTIPLY)
	_ok("9 Numpad × lo enciende (quieto = false)", lab.atacar_goblin and not atq.quieto)
	var d0: float = (atq.position - jugador.position).length()
	await avanzar_s(3.0)
	var d1: float = (atq.position - jugador.position).length()
	_ok("9 el goblin va a por el jugador (la distancia baja) o ya está encima", d1 < d0 - 0.3 or d1 < 3.0, "%.2f → %.2f" % [d0, d1])
	_ok("9 mientras ataca el lab mantiene vivo al jugador", not bool(jugador.get("muerto")) and float(jugador.get("vida")) > 0.0)
	_tecla_lab(KEY_KP_MULTIPLY)
	_ok("9 Numpad × lo vuelve a apagar (quieto = true)", not lab.atacar_goblin and atq.quieto)
	colocar_jugador(Vector2i(4, 8))
	await avanzar_s(0.5)

	# --- 10 · Limpieza de la sala entre rondas ---
	Sigils.HAZ_ACTIVO = false         # 21/10: ᛁ sola es ahora un rayo (prueba_haz.gd), sin bloques ni agua; aquí se mide la limpieza de lo que dejan los VOLÚMENES estirados
	var sim: AguaSim3D = Terreno3D.agua_sim
	var vol0: float = sim.volumen_total() if sim != null else 0.0
	lab.limpiar()
	lab.poner_elemento("earth")
	lab.limite_glifos = false                  # 24/10: con base 0,10 hacen falta más glifos que el límite de 6 para llegar al mismo bloque de tierra que antes
	for _i in range(_glifos_hasta(SEMIEJE_TIERRA_LAB)):
		lab.sumar("linea_x", 1)
		lab.sumar("linea_z", 1)
	lab.limite_glifos = true
	colocar_jugador(Vector2i(4, 8))
	jugador.call("mirar_hacia", Vector3.RIGHT)
	lab.lanzar()
	await avanzar_s(0.5)
	var bloques_antes: int = lanzador._bloques.size()
	lab.limpiar()
	lab.poner_elemento("water")
	for _i in range(6):
		lab.sumar("linea_z", 1)
		lab.sumar("linea_x", 1)
	lab.lanzar()
	await avanzar_s(0.8)
	Terreno3D.estados.poner(Vector2i(8, 8), EstadosSuelo3D.QUEMADA, true)
	Terreno3D.estados.poner(Vector2i(9, 8), EstadosSuelo3D.MOJADA, true)
	var vol1: float = sim.volumen_total() if sim != null else 0.0
	var r_l: Dictionary = lab.limpiar_sala()
	await avanzar_s(2.5)        # el agua se asienta (la sim sigue repartiendo lo que quitó)
	_ok("10 hay tierra construida antes de limpiar (la prueba mide algo)", bloques_antes > 0, "%d" % bloques_antes)
	_ok("10 limpiar_sala deshace los bloques de tierra", lanzador._bloques.size() == 0 and int(r_l["bloques"]) > 0, str(r_l))
	_ok("10 limpiar_sala borra los estados de suelo", Terreno3D.estados.cuantas(EstadosSuelo3D.QUEMADA) == 0 and Terreno3D.estados.cuantas(EstadosSuelo3D.MOJADA) == 0 and int(r_l["estados"]) >= 2, str(r_l))
	if sim != null:
		var vol2: float = sim.volumen_total()
		_ok("10 el agua vuelve a lo que había (±5 %)", absf(vol2 - vol0) <= maxf(vol0 * 0.05, 0.05), "antes %.2f · con el hechizo %.2f · limpio %.2f" % [vol0, vol1, vol2])
	# El barrido en modo completo limpia antes de cada ronda y las rondas salen sin falsos «sin_efecto_visible» por acumulación.
	lab.poner_modo_completo(true)
	var lim0: int = int(lab.limpiezas)
	var raras0: int = (lab.raras as Array).size()
	lab.iniciar_barrido(4, 5)
	t_ini = reloj.t
	guard = 0
	while lab.barrido and reloj.t - t_ini < 90.0 and guard < 8000:
		await process_frame
		guard += 1
	_ok("10 el barrido en modo completo hace sus 4 rondas y se para", int(lab.rondas) == 4 and not lab.barrido, "rondas %d" % int(lab.rondas))
	Sigils.HAZ_ACTIVO = true
	_ok("10 limpió la sala antes de cada ronda (4 limpiezas)", int(lab.limpiezas) - lim0 == 4, "%d" % (int(lab.limpiezas) - lim0))
	_ok("10 el barrido completo usó el camino real (fases vistas en alguna ronda)", int(lab.conjuros) >= 2, "conjuros %d" % int(lab.conjuros))
	for i in range(raras0, (lab.raras as Array).size()):
		_aviso("receta_rara del barrido completo", JSON.stringify(lab.raras[i]))
	lab.poner_modo_completo(false)

	# --- 11 · F2: cast points ---
	lab.poner_pestana(1)
	_ok("11 F2 cargó el laboratorio de cast points", lab.f2 != null and String(lab.f2.texto()).begins_with("F2 · CAST POINT"), "")
	lab.f2.elegir(2)                                  # alto_cielo
	var inst0: float = float(CastPoints.VARIACIONES["alto_cielo"]["instante"])
	_tecla_lab(KEY_Q)
	_ok("11 Q sube el instante del disparo", float(CastPoints.VARIACIONES["alto_cielo"]["instante"]) > inst0, "")
	_tecla_lab(KEY_A)
	_ok("11 A lo baja otra vez", is_equal_approx(float(CastPoints.VARIACIONES["alto_cielo"]["instante"]), inst0), "")
	_tecla_lab(KEY_UP)
	_ok("11 las flechas mueven el origen (adelante)", CastPoints.desplazamiento("alto_cielo").x > 0.0, str(CastPoints.desplazamiento("alto_cielo")))
	CastPoints.VARIACIONES["alto_cielo"]["desplazamiento"] = [0.0, 0.0, 0.0]
	var m0: bool = CastPoints.brazo_activo
	_tecla_lab(KEY_B)
	_ok("11 B conmuta el modificador del brazo", CastPoints.brazo_activo != m0, "")
	_tecla_lab(KEY_B)
	_tecla_lab(KEY_C)
	var tiene_una_mano: bool = String(CastPoints.VARIACIONES["alto_cielo"].get("clip_una_mano", "")) != ""
	_ok("11 C conmuta la fuente una mano si la variación tiene clip a una mano", CastPoints.usar_una_mano == tiene_una_mano, "")
	CastPoints.usar_una_mano = false
	lab.f2.elegir(0)
	colocar_jugador(Vector2i(4, 8))
	jugador.call("mirar_hacia", Vector3.RIGHT)
	_tecla_lab(KEY_SPACE)
	await avanzar_s(1.6)
	var fv: Array = []
	for f in lab.fases_vistas:
		fv.append(String(f["fase"]))
	_ok("11 Espacio en F2 lanza por el camino real (runa, voluta, forma, disparo)", fv == ["runa", "voluta", "forma", "disparo"], str(fv))
	var cp: Dictionary = lanzador.ultimo_castpoint
	_ok("11 el lanzamiento queda medido (desfase ≤ 1 fotograma)", not cp.is_empty() and absf(float(cp.get("desfase_fotogramas", 99.0))) <= 1.0, str(cp))
	_ok("11 el texto de F2 muestra la medida", String(lab.f2.texto()).contains("desfase"), "")
	_tecla_lab(KEY_V)
	_ok("11 V anota la valoración", lab.f2.valoraciones.size() == 1, "")
	CastPoints.usar_una_mano = false
	lab.poner_pestana(0)
	lab.poner_modo_completo(false)

	# --- 12 · Sonido por fase y golpe visual (MEJORAS_POTENCIA §1; Sfx es del Pipeline: aquí solo se comprueba qué se le pide) ---
	lab.poner_modo_completo(true)
	lab.limpiar()
	lab.poner_elemento("fire")
	colocar_jugador(Vector2i(4, 8))
	jugador.call("mirar_hacia", Vector3.RIGHT)
	await avanzar_s(0.3)
	lanzador.sonidos_fase.clear()
	lab.lanzar()
	await avanzar_s(1.6)
	var por_fase: Dictionary = {}
	for sf in lanzador.sonidos_fase:
		por_fase[sf["fase"]] = int(por_fase.get(sf["fase"], 0)) + 1
	_ok("12 cada fase pide su sonido UNA vez (carga, disparo, impacto)", por_fase.get("carga", 0) == 1 and por_fase.get("disparo", 0) == 1 and por_fase.get("impacto", 0) == 1 and por_fase.size() == 3, str(por_fase))
	var pedidos: Array = []
	for sf in lanzador.sonidos_fase:
		pedidos.append(String(sf["pedido"]))
	_ok("12 los pedidos pedidos son <elemento>_carga, <elemento>_disparo y <derivado>_impacto", pedidos.has("fuego_carga") and pedidos.has("fuego_disparo") and pedidos.has("x_mano_impacto"), str(pedidos))
	var todos_caen: bool = true
	for sf in lanzador.sonidos_fase:
		todos_caen = todos_caen and (Sfx.CATALOGO.has(String(sf["pedido"])) or String(sf["suena"]) == "fuego")
	_ok("12 si el nombre no está en Sfx.CATALOGO cae en el elem_* actual", todos_caen, str(lanzador.sonidos_fase))
	var gob12: Combate3D = null
	for n12 in root.get_tree().get_nodes_in_group("combate3d"):
		if not (n12 as Combate3D).muerto:
			gob12 = n12 as Combate3D
			break
	var fx_v12: Variant = maqueta.get("_fx")
	if gob12 != null and fx_v12 is Vfx3D:
		var antes12: int = gob12.impactos_visuales
		gob12.golpe(Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {}), Vector3.RIGHT)
		_ok("12 Combate3D.golpe pide la estrella de impacto y el temblor al Vfx3D", gob12.impactos_visuales == antes12 + 1, "%d → %d" % [antes12, gob12.impactos_visuales])
	else:
		_aviso("12 golpe visual no comprobado", "la maqueta no tiene Vfx3D (_fx) o no hay goblins")
	lab.poner_modo_completo(false)

	# --- 13 · HC5: la tabla del hechizo en F1 (ver, tocar en vivo, restaurar, guardar, imprimir) ---
	lab.poner_pestana(0)
	lab.limpiar()
	lab.poner_elemento("fire")
	lab.cambios_hechizo.clear()
	lab.tabla_sel = 0
	var filas13: Array = lab.tabla_filas()
	var idx13: Dictionary = {}
	for i13 in range(filas13.size()):
		idx13[String(filas13[i13]["campo"])] = i13
	_ok("13 F1 enseña la tabla completa del Hechizo (campos, semiejes en 3 y derivados): %d filas" % filas13.size(), filas13.size() == Hechizo.CAMPOS.size() - 1 + 3 + Hechizo.DERIVADOS.size())
	var txt13: String = lab.texto_tabla()
	_ok("13 el texto de la tabla marca la fila elegida (►) y trae valor, defecto y origen", txt13.contains("►") and txt13.contains("semiejes.x") and txt13.contains("origen") and txt13.contains("defecto"))
	lab.tabla_sel = int(idx13["dano"])
	_ok("13 lo que difiere del defecto sale resaltado (daño del fuego: negrita y color del elemento)", lab.texto_tabla().contains("[b]") and lab.texto_tabla().contains("#ffb070"))
	lab.sumar("linea_x", 2)
	var fx13: Dictionary = lab.tabla_filas()[int(idx13["semiejes.x"])]
	_ok("13 al dibujar glifos la tabla cambia y dice de qué glifo viene (%s)" % str(fx13["origen"]), String(fx13["origen"]) == "glifo:linea_x" and bool(fx13["difiere"]))
	lab.limpiar()
	# ↑/↓ elige, ←/→ cambia, Mayús ×10, X restaura (19/10: antes Retroceso; ahora Retroceso quita el último glifo)
	lab.tabla_sel = int(idx13["velocidad"]) - 1
	_tecla_lab(KEY_DOWN)
	_ok("13 ↓ elige la fila siguiente (velocidad)", int(lab.tabla_sel) == int(idx13["velocidad"]))
	_tecla_lab(KEY_RIGHT)
	_ok("13 → sube velocidad un paso y queda como sobrescritura (%s)" % str(lab.cambios_hechizo), is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 0.5))     # el paso de la velocidad es 0,5 m/s (ESPEC §0.1)
	var fv13: Dictionary = lab.tabla_filas()[int(idx13["velocidad"])]
	_ok("13 la tabla enseña lo tocado con origen «lab»", String(fv13["origen"]) == "lab" and is_equal_approx(float(fv13["valor"]), 0.5))
	_tecla_lab(KEY_RIGHT, true)
	_ok("13 Mayús+→ cambia ×10 (%s)" % str(lab.cambios_hechizo.get("velocidad")), is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 5.5))
	_tecla_lab(KEY_LEFT)
	_ok("13 ← baja un paso", is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 5.0))
	_tecla_lab(KEY_X)
	_ok("13 X restaura la fila (sin sobrescritura)", not lab.cambios_hechizo.has("velocidad"))
	# un bool, una lista, un tope y una fila que no se toca
	lab.tabla_sel = int(idx13["retorna"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 un bool se alterna (retorna → true)", lab.cambios_hechizo.get("retorna") == true)
	_tecla_lab(KEY_LEFT)
	_ok("13 y al volver al valor original la sobrescritura se quita", not lab.cambios_hechizo.has("retorna"))
	lab.tabla_sel = int(idx13["estado_materia"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 una lista avanza (plasma → %s)" % str(lab.cambios_hechizo.get("estado_materia")), lab.cambios_hechizo.get("estado_materia") == "energia")
	_tecla_lab(KEY_X)
	lab.tabla_sel = int(idx13["copias"])
	_tecla_lab(KEY_LEFT)
	_ok("13 un número no baja de su mínimo (copias 1 ← sigue en el original)", not lab.cambios_hechizo.has("copias"))
	lab.tabla_sel = int(idx13["color"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 una fila de solo lectura (color) no se toca", lab.cambios_hechizo.is_empty())
	# lo tocado se usa en el SIGUIENTE lanzamiento
	lab.tabla_sel = int(idx13["velocidad"])
	for _k13 in range(10):
		_tecla_lab(KEY_RIGHT)
	lab.tabla_sel = int(idx13["distancia_max"])
	for _k13 in range(6):
		_tecla_lab(KEY_RIGHT)
	_ok("13 el lanzador ve las sobrescrituras (el mismo diccionario)", lanzador.cambios_hechizo.has("velocidad") and lanzador.cambios_hechizo.has("distancia_max"))
	colocar_jugador(Vector2i(4, 8))
	jugador.call("mirar_hacia", Vector3.RIGHT)
	await avanzar_s(0.3)
	lab.lanzar()
	var proyectiles13: int = 0
	for c13 in lanzador.get_children():
		if c13 is HechizoVivo and (c13 as HechizoVivo).proyectil:
			proyectiles13 += 1
	_ok("13 el siguiente hechizo sale con lo tocado: velocidad 5 → es un proyectil (%d)" % proyectiles13, proyectiles13 == 1)
	await avanzar_s(0.5)
	# G guarda, P imprime
	_tecla_lab(KEY_G)
	var fg13 := FileAccess.open("user://lab_hechizos.json", FileAccess.READ)
	var js13: Variant = JSON.parse_string(fg13.get_as_text()) if fg13 != null else null
	_ok("13 G guarda las sobrescrituras en user://lab_hechizos.json", js13 is Dictionary and (js13 as Dictionary).has("hechizo") and is_equal_approx(float(js13["hechizo"].get("velocidad", -1.0)), 5.0), str(js13["hechizo"] if js13 is Dictionary and js13.has("hechizo") else js13))
	var tabla13: String = lab.tabla_texto()
	_ok("13 P imprime lo tocado como modificadores listos para pegar", tabla13.contains("\"campo\": \"velocidad\", \"op\": \"fija\", \"valor\": 5") and tabla13.contains("\"distancia_max\": {\"op\": \"fija\", \"valor\": 3"), tabla13.substr(maxi(0, tabla13.find("F1 Hechizo")), 400))
	# Mayús+X restaura todo y el siguiente hechizo vuelve a ser el de siempre
	_tecla_lab(KEY_X, true)
	_ok("13 Mayús+X restaura todas las filas", lab.cambios_hechizo.is_empty() and lanzador.cambios_hechizo.is_empty())
	for c13 in lanzador.get_children():
		if c13 is HechizoVivo:
			(c13 as HechizoVivo).activo = false
			(c13 as HechizoVivo).queue_free()
	await avanzar(2)
	lab.lanzar()
	var proy_dopo: int = 0
	for c13 in lanzador.get_children():
		if c13 is HechizoVivo and (c13 as HechizoVivo).proyectil:
			proy_dopo += 1
	_ok("13 sin sobrescrituras el hechizo vuelve a ser el de siempre (no es proyectil)", proy_dopo == 0)
	# 19/10: con la interfaz COMPACTA (la de por defecto desde que el Pipeline la montó) la tabla de «Este lanzamiento» se esconde; esta comprobación es de la interfaz completa (F6).
	lab.ui_compacta = false
	lab.call("_aplicar_ui")
	lab.call("_refrescar_hud")
	_ok("13 la tabla solo se ve en F1 (interfaz completa)", lab.texto_hud().length() > 0 and lab.get("_tabla_label") != null and (lab.get("_tabla_label") as Control).visible)
	lab.poner_pestana(2)
	_ok("13 y se oculta en F3", not (lab.get("_tabla_label") as Control).visible)
	lab.poner_pestana(0)
	lab.ui_compacta = true
	lab.call("_aplicar_ui")
	_ok("13 con la interfaz compacta la tabla de «Este lanzamiento» se esconde (y «Bases» la enseña, ver 14)", not (lab.get("_tabla_label") as Control).visible)

	# --- 14 · DISEÑAR (19/10): «Bases» en memoria, glifos en orden, recetas con nombre, exportar, G y comparar ---
	LabHechizos3D.cargar_al_abrir = false
	lab.limpiar()
	lab.cambios_hechizo.clear()
	lab.poner_elemento("fire")
	_ok("14 al abrir el lab la capa de bases está vacía (el juego normal no la usa)", CapaBases.vacia())
	_ok("14 el lab empieza en «Este lanzamiento»", int(lab.nivel) == LabHechizos3D.Nivel.LANZAMIENTO and lab.texto_tabla().contains("Este lanzamiento"))
	var md5_sigils: String = FileAccess.get_file_as_string("res://nucleo/sigils.gd").md5_text()
	var md5_fire: String = FileAccess.get_file_as_string("res://nucleo/fire_rune.tres").md5_text()
	var md5_hechizo: String = FileAccess.get_file_as_string("res://nucleo/hechizo.gd").md5_text()
	var flecha_orig: String = var_to_str(Sigils.GLIFOS["flecha"]["modificadores"])
	var rune_fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	var h14_orig: Hechizo = Hechizo.construir(rune_fuego, {"flecha": 3})
	# N alterna el nivel y el título de la tabla dice cuál está activo
	_tecla_lab(KEY_N)
	_ok("14 N pasa a «Bases» y el título de la tabla lo dice", int(lab.nivel) == LabHechizos3D.Nivel.BASES and lab.texto_tabla().contains("BASES") and not lab.texto_tabla().contains("HECHIZO · «Este lanzamiento»"))
	_ok("14 en «Bases» la tabla se ve aunque la interfaz sea la compacta", (lab.get("_tabla_label") as Control).visible)
	# --- glifo: elegir página, ver su lista y cambiar valor / tope
	var nombres_glifo: Array = Sigils.GLIFOS.keys()
	lab.bases_pag = 1 + nombres_glifo.find("flecha")
	var filas14: Array = lab.bases_filas()
	var i_dist: int = -1
	for i14 in range(filas14.size()):
		if String(filas14[i14]["campo"]) == "distancia_max":
			i_dist = i14
	_ok("14 la página de la flecha lista sus modificadores (campo, op, valor, tope, desde, salta)", filas14.size() == 2 and i_dist >= 0 and filas14[i_dist]["op"] == "suma" and is_equal_approx(float(filas14[i_dist]["tope"]), 6.0) and is_equal_approx(float(filas14[i_dist]["desde"]), 1.0), str(filas14))
	_ok("14 el texto de la página enseña esas columnas", lab.texto_tabla().contains("distancia_max") and lab.texto_tabla().contains("tope") and lab.texto_tabla().contains("salta") and lab.texto_tabla().contains("desde"))
	lab.bases_sel = i_dist
	_tecla_lab(KEY_RIGHT)
	var f_dist: Dictionary = lab.bases_filas()[i_dist]
	_ok("14 → sube el VALOR del modificador un paso (1,0 → 1,25)", is_equal_approx(float(f_dist["valor"]), 1.25) and bool(f_dist["difiere"]), str(f_dist))
	_ok("14 y queda en la capa, no en Sigils.GLIFOS", CapaBases.glifos.has("flecha") and var_to_str(Sigils.GLIFOS["flecha"]["modificadores"]) == flecha_orig)
	_tecla_lab(KEY_T)
	_tecla_lab(KEY_LEFT)
	var f_dist2: Dictionary = lab.bases_filas()[i_dist]
	_ok("14 T cambia a editar el TOPE y ← lo baja (6,0 → 5,75)", is_equal_approx(float(f_dist2["tope"]), 5.75) and is_equal_approx(float(f_dist2["valor"]), 1.25), str(f_dist2))
	_tecla_lab(KEY_T)
	var h14_capa: Hechizo = Hechizo.construir(rune_fuego, {"flecha": 3})
	_ok("14 la capa de bases cambia el Hechizo construido (distancia_max %s → %s)" % [h14_orig.distancia_max, h14_capa.distancia_max], not is_equal_approx(h14_orig.distancia_max, h14_capa.distancia_max) and is_equal_approx(h14_capa.distancia_max, h14_orig.distancia_max + 3.0 * 0.25), "%s / %s" % [h14_orig.distancia_max, h14_capa.distancia_max])
	lab.limpiar()
	lab.sumar("flecha", 3)
	_ok("14 y el que construye el lab (hechizo_base) usa la capa", is_equal_approx(lab.hechizo_base().distancia_max, h14_capa.distancia_max))
	# --- elemento: sus modificadores del .tres
	lab.bases_pag = lab.bases_paginas().size() - 1
	var filas_el: Array = lab.bases_filas()
	var i_dp: int = -1
	for ie in range(filas_el.size()):
		if String(filas_el[ie]["campo"]) == "dano_periodico":
			i_dp = ie
	_ok("14 la página del elemento lista los modificadores de fire_rune.tres (dano_periodico)", i_dp >= 0 and is_equal_approx(float(filas_el[i_dp]["valor"]), 40.0), str(filas_el))
	lab.bases_sel = i_dp
	_tecla_lab(KEY_RIGHT)
	var h14_fuego: Hechizo = Hechizo.construir(rune_fuego, {})
	_ok("14 cambiar el modificador del elemento cambia el Hechizo del fuego (dano_periodico %s)" % h14_fuego.dano_periodico, h14_fuego.dano_periodico > 40.0 and CapaBases.elementos.has(Objetos.elemento_de(rune_fuego)), str(h14_fuego.dano_periodico))
	_ok("14 el hielo no cambia: la capa es por elemento", is_equal_approx(Hechizo.construir(load("res://nucleo/ice_rune.tres") as RuneData, {}).dano_periodico, Hechizo.defecto_original("dano_periodico")) or Hechizo.construir(load("res://nucleo/ice_rune.tres") as RuneData, {}).dano_periodico != h14_fuego.dano_periodico)
	# --- defectos
	lab.bases_pag = 0
	var filas_d: Array = lab.bases_filas()
	var i_g: int = -1
	for idd in range(filas_d.size()):
		if String(filas_d[idd]["campo"]) == "gravedad":
			i_g = idd
	_ok("14 la página 1 son los valores por defecto del Hechizo (gravedad)", i_g >= 0 and is_equal_approx(float(filas_d[i_g]["valor"]), Hechizo.defecto_original("gravedad")))
	lab.bases_sel = i_g
	_tecla_lab(KEY_RIGHT)
	_ok("14 cambiar un defecto lo aplica a todo lo que se construya (Hechizo.construir y Hechizo.defecto)", not is_equal_approx(Hechizo.construir(load("res://nucleo/earth_rune.tres") as RuneData, {}).gravedad, Hechizo.defecto_original("gravedad")) or CapaBases.defectos.has("gravedad"))
	_ok("14 Hechizo.defecto refleja la capa y defecto_original no", CapaBases.defectos.has("gravedad") and not is_equal_approx(float(Hechizo.defecto("gravedad")), float(Hechizo.defecto_original("gravedad"))))
	_ok("14 NADA de lo anterior tocó res:// (sigils.gd, hechizo.gd y fire_rune.tres iguales; Sigils.GLIFOS intacto)",
		FileAccess.get_file_as_string("res://nucleo/sigils.gd").md5_text() == md5_sigils and FileAccess.get_file_as_string("res://nucleo/fire_rune.tres").md5_text() == md5_fire
		and FileAccess.get_file_as_string("res://nucleo/hechizo.gd").md5_text() == md5_hechizo and var_to_str(Sigils.GLIFOS["flecha"]["modificadores"]) == flecha_orig)
	# --- exportar (P en «Bases»)
	var txt14: String = lab.texto_bases()
	_ok("14 el texto de «Bases» trae el glifo (Sigils.GLIFOS), el elemento (modificadores = {…}) y el defecto", txt14.contains("Sigils.GLIFOS[\"flecha\"]") and txt14.contains("\"campo\": \"distancia_max\"") and txt14.contains("modificadores = {") and txt14.contains("defecto gravedad = "), txt14)
	_ok("14 en «Bases» P imprime ese texto", lab.tabla_texto().contains("F1 Bases") and lab.tabla_texto().contains(txt14))
	var casos14: Array = []
	for el14 in ["fire", "water", "earth", "ice", "lightning", "wind"]:
		for gl14 in [{}, {"flecha": 1}, {"flecha": 3}, {"barrera": 2, "permanencia": 1}, {"linea_x": 2, "altura": 1, "repeticion": 2}, {"pulso": 2, "rebote": 1, "flecha": 2}]:
			casos14.append([el14, gl14])
	var antes14: Array = []
	for c14 in casos14:
		antes14.append(var_to_str(Hechizo.construir(load("res://nucleo/%s_rune.tres" % c14[0]) as RuneData, c14[1]).a_diccionario()))
	var cap14: Dictionary = CapaBases.copia()
	CapaBases.limpiar()
	var distintos14: int = 0
	for i14b in range(casos14.size()):
		if var_to_str(Hechizo.construir(load("res://nucleo/%s_rune.tres" % casos14[i14b][0]) as RuneData, casos14[i14b][1]).a_diccionario()) != antes14[i14b]:
			distintos14 += 1
	_ok("14 (control) sin la capa los hechizos construidos son otros: la capa cambia %d de %d" % [distintos14, casos14.size()], distintos14 > 0)
	var avisos14: PackedStringArray = CapaBases.desde_texto(txt14)
	var iguales14: int = 0
	for i14c in range(casos14.size()):
		if var_to_str(Hechizo.construir(load("res://nucleo/%s_rune.tres" % casos14[i14c][0]) as RuneData, casos14[i14c][1]).a_diccionario()) == antes14[i14c]:
			iguales14 += 1
	_ok("14 el texto exportado, cargado de nuevo, da el MISMO Hechizo en %d combinaciones (%d/%d)" % [casos14.size(), iguales14, casos14.size()], avisos14.is_empty() and iguales14 == casos14.size(), str(avisos14))
	_ok("14 y al volver a exportarlo sale el mismo texto", lab.texto_bases() == txt14)
	# --- restaurar
	lab.bases_pag = 0
	lab.bases_sel = i_g
	_tecla_lab(KEY_X)
	_ok("14 X restaura la fila de «Bases» (gravedad vuelve a su original)", not CapaBases.defectos.has("gravedad"))
	lab.bases_pag = 1 + nombres_glifo.find("flecha")
	_tecla_lab(KEY_X, true)
	_ok("14 Mayús+X restaura la página (la flecha vuelve a Sigils)", not CapaBases.glifos.has("flecha"))
	lab.bases_pag = lab.bases_paginas().size() - 1
	_tecla_lab(KEY_X, true)
	_ok("14 …y la del elemento: la capa queda vacía", CapaBases.vacia() and lab.texto_bases().contains("sin cambios"))
	_tecla_lab(KEY_PAGEDOWN)
	_ok("14 AvPág pasa a la página siguiente (de la del elemento, la última, vuelve a los defectos)", int(lab.bases_pag) == 0)
	_tecla_lab(KEY_PAGEUP)
	_ok("14 RePág vuelve a la anterior", int(lab.bases_pag) == lab.bases_paginas().size() - 1)
	_tecla_lab(KEY_N)
	_ok("14 N vuelve a «Este lanzamiento»", int(lab.nivel) == LabHechizos3D.Nivel.LANZAMIENTO and lab.texto_tabla().contains("Este lanzamiento"))
	# --- glifos en orden
	lab.limpiar()
	for k14 in [KEY_KP_4, KEY_KP_5, KEY_KP_1, KEY_KP_8]:
		_tecla_lab(k14)
	var ks: Array = Sigils.GLIFOS_V2.keys()
	_ok("14 Numpad 1–8 añade al FINAL, en orden (%s)" % str(lab.orden), lab.orden == [ks[3], ks[4], ks[0], ks[7]], str(lab.orden))
	_ok("14 y el multiconjunto sale de esa fila", lab.contadores == {ks[3]: 1, ks[4]: 1, ks[0]: 1, ks[7]: 1}, str(lab.contadores))
	_tecla_lab(KEY_KP_9)
	_ok("14 Numpad 9 añade el 9.º glifo (permanencia ᛉ)", String(lab.orden.back()) == "permanencia" and ks.size() == 10 and ks[9] == "raido", str(lab.orden))        # 23/10: el 10.º es ᚱ «pulso» (raido): sin tecla de Numpad, se suma con el panel
	_ok("14 la fila se enseña en pantalla en orden", lab.texto_orden().contains("5/6") and lab.texto_diseno().contains("permanencia"))
	_tecla_lab(KEY_KP_1)
	_tecla_lab(KEY_KP_1)
	_ok("14 el límite es de 6 glifos (Hechizo.MAX_GLIFOS): el séptimo no entra (%d)" % lab.orden.size(), lab.orden.size() == 6 and Hechizo.MAX_GLIFOS == 6, str(lab.orden))
	_tecla_lab(KEY_L, true)
	_ok("14 Mayús+L quita el límite y avisa en pantalla", not lab.limite_glifos and lab.texto_diseno().contains("LÍMITE DE GLIFOS DESACTIVADO"))
	_tecla_lab(KEY_KP_1)
	_tecla_lab(KEY_KP_1)
	_ok("14 sin límite entran más de 6 (%d)" % lab.orden.size(), lab.orden.size() == 8, str(lab.orden))
	_tecla_lab(KEY_L, true)
	_ok("14 al volver a poner el límite la fila se recorta a 6", lab.limite_glifos and lab.orden.size() == 6 and not lab.texto_diseno().contains("DESACTIVADO"))
	_tecla_lab(KEY_BACKSPACE)
	_ok("14 Retroceso quita el último glifo", lab.orden.size() == 5 and String(lab.orden.back()) == "permanencia", str(lab.orden))
	_tecla_lab(KEY_KP_4, true)
	_ok("14 Mayús+Numpad quita el último de ESE glifo (flecha)", not lab.orden.has(ks[3]) and lab.orden.size() == 4, str(lab.orden))
	_tecla_lab(KEY_DELETE)
	_ok("14 Supr vacía la fila y el multiconjunto", lab.orden.is_empty() and lab.contadores.is_empty())
	lab.poner_orden(["flecha", "barrera", "linea_x"])
	var da14: Dictionary = lab.hechizo_base().a_diccionario()
	lab.poner_orden(["linea_x", "barrera", "flecha"])
	var db14: Dictionary = lab.hechizo_base().a_diccionario()
	_ok("14 el orden no cambia el resultado de hoy (mismo multiconjunto → mismo Hechizo)", var_to_str(da14) == var_to_str(db14) and lab.orden == ["linea_x", "barrera", "flecha"])
	lab.limpiar()
	# --- recetas con nombre
	lab.ruta_recetas = "user://lab_recetas_prueba.json"
	if FileAccess.file_exists(lab.ruta_recetas):
		DirAccess.remove_absolute(lab.ruta_recetas)
	lab.cargar_recetas()
	var nombres14: Array = []
	for r14 in lab.recetas:
		nombres14.append(String(r14["nombre"]))
	_ok("14 vienen 6 recetas por defecto con sus nombres", nombres14 == ["bola de fuego", "flecha triple de hielo", "muro de tierra", "barrera de agua", "pilar de rayo", "onda de viento"], str(nombres14))
	var todas_ok14: bool = true
	for r14b in lab.recetas:
		for g14 in (r14b["glifos"] as Array):
			todas_ok14 = todas_ok14 and Sigils.GLIFOS_V2.has(String(g14))
		todas_ok14 = todas_ok14 and (r14b["glifos"] as Array).size() <= Hechizo.MAX_GLIFOS and lab.ELEMENTOS.has(String(r14b["elemento"]))
	_ok("14 todas usan glifos y elementos que existen y caben en 6", todas_ok14)
	_ok("14 la lista visible trae sus nombres y el atajo (Ctrl+1…)", lab.texto_diseno().contains("Ctrl+1  bola de fuego") and lab.texto_diseno().contains("onda de viento"))
	colocar_jugador(Vector2i(4, 8))
	jugador.call("mirar_hacia", Vector3.RIGHT)
	await avanzar_s(0.3)
	for c14d in lanzador.get_children():
		if c14d is HechizoVivo:
			(c14d as HechizoVivo).activo = false
			(c14d as HechizoVivo).queue_free()
	await avanzar(2)
	_tecla_lab(KEY_1, false, true)
	_ok("14 Ctrl+1 relanza «bola de fuego»: pone elemento y glifos en orden", lab.elemento == "fire" and lab.orden == ["flecha", "linea_x", "linea_z", "altura"] and not lab.ultimo.is_empty(), str(lab.orden))
	var vivos14: int = 0
	for c14e in lanzador.get_children():
		if c14e is HechizoVivo:
			vivos14 += 1
	_ok("14 y el hechizo sale (hay un HechizoVivo)", vivos14 >= 1, str(vivos14))
	# guardar una receta nueva con lo que hay (elemento, orden y un cambio de lanzamiento)
	lab.poner_elemento("ice")
	lab.poner_orden(["barrera", "barrera", "permanencia"])
	lab.cambios_hechizo["solidez"] = 2.0
	_tecla_lab(KEY_S, false, true)
	_ok("14 Ctrl+S guarda una receta nueva (7 en la lista) con el primer nombre libre", lab.recetas.size() == 7 and String(lab.recetas[6]["nombre"]) == "Receta 1", str(lab.recetas.back()))
	var del14: Array = RecetasLab.cargar("user://lab_recetas_prueba.json")
	_ok("14 …en user://lab_recetas.json: glifos en orden, elemento y cambios de lanzamiento", del14.size() == 7 and del14[6]["glifos"] == ["barrera", "barrera", "permanencia"] and del14[6]["elemento"] == "ice" and is_equal_approx(float(del14[6]["cambios"]["solidez"]), 2.0), str(del14.back()))
	# cambiar todo y relanzar por Ctrl+7
	lab.limpiar()
	lab.cambios_hechizo.clear()
	lab.poner_elemento("wind")
	_tecla_lab(KEY_7, false, true)
	_ok("14 Ctrl+7 relanza la guardada: vuelve elemento, orden y cambios", lab.elemento == "ice" and lab.orden == ["barrera", "barrera", "permanencia"] and is_equal_approx(float(lab.cambios_hechizo.get("solidez", -1.0)), 2.0), "%s %s %s" % [lab.elemento, lab.orden, lab.cambios_hechizo])
	_ok("14 …y lo lanzado lleva ese cambio (el Hechizo del lanzamiento tiene solidez 2)", is_equal_approx(lab.hechizo_actual().solidez, 2.0))
	lab.recetas = RecetasLab.cargar("user://lab_recetas_prueba.json")
	_ok("14 al reabrir se leen las 7 recetas del archivo", lab.recetas.size() == 7)
	lab.receta_sel = 6
	lab.poner_orden(["barrera"])
	_tecla_lab(KEY_S, true, true)
	_ok("14 Ctrl+Mayús+S sobrescribe la última lanzada (sigue habiendo 7)", lab.recetas.size() == 7 and lab.recetas[6]["glifos"] == ["barrera"] and String(lab.recetas[6]["nombre"]) == "Receta 1")
	DirAccess.remove_absolute("user://lab_recetas_prueba.json")
	lab.cambios_hechizo.clear()
	# --- G guarda todo y se recarga
	CapaBases.limpiar()
	lab.bases_pag = 1 + nombres_glifo.find("flecha")
	lab.nivel = LabHechizos3D.Nivel.BASES
	lab.bases_sel = i_dist
	_tecla_lab(KEY_RIGHT)
	lab.poner_elemento("earth")
	lab.poner_orden(["flecha", "flecha", "linea_z"])
	lab.cambios_hechizo["velocidad"] = 3.0
	var h_antes_g: Dictionary = lab.hechizo_actual().a_diccionario()
	_tecla_lab(KEY_G)
	var fg14 := FileAccess.open(LabHechizos3D.RUTA_GUARDADO, FileAccess.READ)
	var jg14: Variant = JSON.parse_string(fg14.get_as_text()) if fg14 != null else null
	_ok("14 G guarda también las bases, la fila de glifos y el elemento", jg14 is Dictionary and String(jg14.get("bases", "")).contains("distancia_max") and jg14.get("orden") == ["flecha", "flecha", "linea_z"] and jg14.get("elemento") == "earth", str(jg14))
	CapaBases.limpiar()
	lab.limpiar()
	lab.cambios_hechizo.clear()
	lab.poner_elemento("fire")
	_ok("14 (control) tras limpiarlo todo el hechizo es otro", var_to_str(lab.hechizo_actual().a_diccionario()) != var_to_str(h_antes_g))
	_ok("14 al abrir el lab se recarga (cargar): vuelve el mismo Hechizo", lab.cargar() and var_to_str(lab.hechizo_actual().a_diccionario()) == var_to_str(h_antes_g) and lab.orden == ["flecha", "flecha", "linea_z"] and lab.elemento == "earth")
	DirAccess.remove_absolute(LabHechizos3D.RUTA_GUARDADO)
	# --- K comparar
	lab.nivel = LabHechizos3D.Nivel.LANZAMIENTO
	lab.cambios_hechizo.clear()
	lab.poner_elemento("fire")
	lab.poner_orden(["flecha", "flecha", "flecha"])
	for c14f in lanzador.get_children():
		if c14f is HechizoVivo:
			(c14f as HechizoVivo).activo = false
			(c14f as HechizoVivo).queue_free()
	await avanzar(2)
	var capa_k: Dictionary = CapaBases.copia()
	_ok("14 (control) la capa de la comparación está tocada (flecha)", CapaBases.glifos.has("flecha"))
	_tecla_lab(KEY_K)
	_ok("14 K lanza la receta actual dos veces (original y tocada)", not lab.comparacion.is_empty() and int(lab.comparacion["original"]) > 0 and int(lab.comparacion["tocadas"]) > 0, str(lab.comparacion))
	var nodos_k: Array = []
	for c14g in lanzador.get_children():
		if c14g is HechizoVivo:
			nodos_k.append(c14g)
	_ok("14 …salen dos HechizoVivo (%d)" % nodos_k.size(), nodos_k.size() == 2)
	if nodos_k.size() == 2:
		var sep14: float = (nodos_k[0] as HechizoVivo).p.distance_to((nodos_k[1] as HechizoVivo).p)
		_ok("14 …separados dos casillas, uno al lado del otro (%.2f de %.2f)" % [sep14, 2.0 * Terreno3D.casilla], is_equal_approx(sep14, 2.0 * Terreno3D.casilla), "%s" % sep14)
		var dist0: float = (nodos_k[0] as HechizoVivo).h.distancia_max
		var dist1: float = (nodos_k[1] as HechizoVivo).h.distancia_max
		_ok("14 …uno con las bases originales y otro con las tocadas (alcance %s y %s)" % [dist0, dist1], not is_equal_approx(dist0, dist1), "%s / %s" % [dist0, dist1])
	_ok("14 la comparación deja la capa como estaba", var_to_str(CapaBases.copia()) == var_to_str(capa_k))
	for c14h in lanzador.get_children():
		if c14h is HechizoVivo:
			(c14h as HechizoVivo).activo = false
			(c14h as HechizoVivo).queue_free()
	CapaBases.limpiar()
	lab.limpiar()
	lab.poner_elemento("fire")
	# --- 15 · F4: la matriz de aprobación de VFX (lab_vfx_3d.gd, 19/10)
	var f4: Variant = lab.get("f4")
	_ok("15 el lab monta la pestaña F4 (LabVfx3D)", f4 != null and f4 is LabVfx3D)
	if f4 != null and f4 is LabVfx3D:
		var vfx: LabVfx3D = f4 as LabVfx3D
		var marcas_user: Dictionary = vfx.marcas.duplicate(true)       # lo que Pablo tuviera guardado: se devuelve al final
		vfx.guardar_al_marcar = false                                  # la prueba no escribe en user://vfx_aprobados.json
		vfx.marcas.clear()
		lab.ui_compacta = true
		_tecla_lab(KEY_F4)
		_ok("15 F4 abre la pestaña VFX", lab.pestana == LabHechizos3D.Pestana.VFX)
		_ok("15 …y la interfaz compacta NO cambia (F4 ya no es el interruptor)", lab.ui_compacta)
		_ok("15 el HUD de F4 enseña la matriz y el criterio", lab.texto_hud().contains("F4 VFX") and lab.texto_hud().contains("Criterio"))
		_tecla_lab(KEY_F6)
		_ok("15 F6 sí alterna la interfaz completa ↔ compacta", not lab.ui_compacta)
		_tecla_lab(KEY_F6)
		_ok("15 …y vuelve", lab.ui_compacta)
		_ok("15 la matriz tiene 6×4×5×4 = 480 celdas y 24 de criterio", LabVfx3D.total_celdas() == 480 and LabVfx3D.celdas_base().size() == 24)
		var claves: Dictionary = {}
		for e in range(6):
			for v in range(4):
				for p in range(5):
					for i in range(4):
						claves[LabVfx3D.clave_de(e, v, p, i)] = true
		_ok("15 cada celda tiene una clave distinta (%d)" % claves.size(), claves.size() == 480)

		# El hechizo de cada celda: elemento, volumen y propiedad.
		var malos: PackedStringArray = []
		var base_r: float = Sigils.RADIO_BASE_V2
		var saltadas15: int = 0
		for e in range(6):
			# 20/10: «campo» sale de la runa del tiempo, que ahora es cinemática: LabVfx3D.hechizo (Pipeline) no pide permitir_cinematico y recibe null. Se salta con aviso
			# hasta que el Pipeline retire o corrija esa celda (ver diario): no es una regresión de lo que el jugador puede lanzar.
			if (load("res://nucleo/%s_rune.tres" % String(LabVfx3D.ESTADOS[e][1])) as RuneData).cinematico:
				saltadas15 += 20
				print("  AVISO  15 se salta el estado «%s» (runa cinemática): LabVfx3D.hechizo aún no la pide con permitir_cinematico" % String(LabVfx3D.ESTADOS[e][0]))
				continue
			for v in range(4):
				for p in range(5):
					var h: Hechizo = vfx.hechizo([e, v, p, 0])
					var vol: Array = LabVfx3D.VOLUMENES[v]
					if h.estado_materia != String(LabVfx3D.ESTADOS[e][0]):
						malos.append("%s: estado %s" % [LabVfx3D.clave_de(e, v, p, 0), h.estado_materia])
					if not (is_equal_approx(h.semieje_x, base_r * float(vol[1])) and is_equal_approx(h.semieje_y, base_r * float(vol[2])) and is_equal_approx(h.semieje_z, base_r * float(vol[3]))):
						malos.append("%s: semiejes %s" % [LabVfx3D.clave_de(e, v, p, 0), str(h.semiejes)])
					var viaja_ok: bool = (h.distancia_max > 0.0) == (p == 1)
					var copias_ok: bool = (h.copias == LabVfx3D.COPIAS) == (p == 2)
					var crece_ok: bool = (h.crece > 0.0) == (p == 3)
					var solidez_ok: bool = is_equal_approx(h.solidez, LabVfx3D.SOLIDEZ) == (p == 4)
					if not (viaja_ok and copias_ok and crece_ok and solidez_ok):
						malos.append("%s: propiedad (dist %s, copias %d, crece %s, solidez %s)" % [LabVfx3D.clave_de(e, v, p, 0), h.distancia_max, h.copias, h.crece, h.solidez])
		_ok("15 las %d combinaciones de estado·volumen·propiedad dan el hechizo que dicen" % (120 - saltadas15), malos.is_empty(), "; ".join(malos.slice(0, 4)))

		# De dónde sale y hacia dónde va: a 3 casillas del objetivo en línea recta.
		var sal_ok: bool = true
		for i in range(4):
			var imp: Dictionary = LabVfx3D.IMPACTOS[i]
			var s_viaja: Dictionary = vfx.salida([0, 0, 1, i])
			var s_quieta: Dictionary = vfx.salida([0, 0, 0, i])
			var d_cas: float = (Terreno3D.centro_de(imp["objetivo"], 0.0) - Terreno3D.centro_de(imp["desde"], 0.0)).length() / Terreno3D.casilla
			sal_ok = sal_ok and is_equal_approx(d_cas, LabVfx3D.DISTANCIA_VIAJE) and (s_viaja["dir"] as Vector3).is_equal_approx(s_quieta["dir"] as Vector3)
			sal_ok = sal_ok and absf((s_viaja["origen"] as Vector3).x - Terreno3D.centro_de(imp["desde"], 0.0).x) < 0.01 and (s_quieta["origen"] as Vector3).distance_to(Terreno3D.centro_de(imp["objetivo"], (s_quieta["origen"] as Vector3).y)) < Terreno3D.casilla * 1.01 and (s_quieta["origen"] as Vector3).distance_to(Terreno3D.centro_de(imp["objetivo"], (s_quieta["origen"] as Vector3).y)) > Terreno3D.casilla * 0.99
		_ok("15 los cuatro impactos están a %d casillas del jugador y «viaja» sale de él mientras lo demás nace pegado a él" % int(LabVfx3D.DISTANCIA_VIAJE), sal_ok)

		# Sin medir no se aprueba.
		vfx.poner(0, 0, 0, 0)
		_tecla_lab(KEY_A)
		_ok("15 A sin haber lanzado la celda no aprueba (falta medir)", vfx.valor_marca(vfx.clave()) == "")

		# Lanzar y medir una celda base.
		var cas_lanzadas: int = vfx.lanzar()
		_ok("15 Espacio lanza la celda elegida (sólido·esfera·ninguna·suelo): %d casillas" % cas_lanzadas, cas_lanzadas > 0)
		_ok("15 …y empieza a medir", vfx.midiendo())
		await avanzar_s(LabVfx3D.VENTANA_MEDIDA_S + 0.3)
		var f_med: Dictionary = vfx.marcas.get(vfx.clave(), {})
		_ok("15 la medida termina y queda en la celda (luces %s, partículas %s)" % [str(f_med.get("luces")), str(f_med.get("particulas"))], not vfx.midiendo() and f_med.has("luces") and f_med.has("particulas"))
		var cabe: bool = vfx.en_presupuesto(vfx.clave())
		_tecla_lab(KEY_A)
		_ok("15 A aprueba si cabe en el presupuesto y no si se pasa (cabe: %s)" % str(cabe), (vfx.valor_marca(vfx.clave()) == LabVfx3D.APROBADO) == cabe)
		_tecla_lab(KEY_R)
		_ok("15 R rechaza", vfx.valor_marca(vfx.clave()) == LabVfx3D.RECHAZADO)
		_tecla_lab(KEY_N)
		_ok("15 N pone la primera nota rápida", String((vfx.marcas[vfx.clave()] as Dictionary)["nota"]) == String(LabVfx3D.NOTAS_RAPIDAS[1]))
		_tecla_lab(KEY_DELETE)
		_ok("15 Supr borra marca y nota pero deja la medida", vfx.valor_marca(vfx.clave()) == "" and String((vfx.marcas[vfx.clave()] as Dictionary)["nota"]) == "" and (vfx.marcas[vfx.clave()] as Dictionary).has("luces"))
		# Los flechas mueven el eje y el valor.
		var antes_sel: Array = vfx.sel.duplicate()
		_tecla_lab(KEY_RIGHT)
		_tecla_lab(KEY_DOWN)
		_tecla_lab(KEY_RIGHT)
		_ok("15 ← → cambian el valor del eje y ↑ ↓ el eje", int(vfx.sel[0]) == (int(antes_sel[0]) + 1) % 6 and vfx.eje == 1 and int(vfx.sel[1]) == 1)
		vfx.poner(0, 0, 0, 0)
		vfx.eje = 0
		lab.cambios_hechizo["velocidad"] = 7.0
		vfx.lanzar()
		_ok("15 …lanzar de F4 aparta y devuelve lo tocado en F1", is_equal_approx(float(lab.cambios_hechizo.get("velocidad", 0.0)), 7.0) and lab.cambios_hechizo.size() == 1)
		lab.cambios_hechizo.clear()

		# Las 24 celdas del criterio: se lanzan, se miden y se informa de las que se pasan.
		var fuera: PackedStringArray = []
		var sin_salir: PackedStringArray = []
		for c in LabVfx3D.celdas_base():
			vfx.poner(c[0], c[1], c[2], c[3])
			if vfx.lanzar() <= 0:
				sin_salir.append(vfx.clave())
			await avanzar_s(LabVfx3D.VENTANA_MEDIDA_S + 0.1)
			if not vfx.en_presupuesto(vfx.clave()):
				var fm: Dictionary = vfx.marcas.get(vfx.clave(), {})
				fuera.append("%s (%s luces, %s partículas)" % [vfx.clave(), str(fm.get("luces")), str(fm.get("particulas"))])
		_ok("15 las 24 celdas del criterio salen (casillas > 0)", sin_salir.is_empty(), ", ".join(sin_salir))
		if fuera.is_empty():
			var max_l: int = 0
			var max_p: int = 0
			for c in LabVfx3D.celdas_base():
				var fb: Dictionary = vfx.marcas.get(LabVfx3D.clave_de(c[0], c[1], c[2], c[3]), {})
				max_l = maxi(max_l, int(fb.get("luces", 0)))
				max_p = maxi(max_p, int(fb.get("particulas", 0)))
			_aviso("F4 presupuesto de las 24 celdas base", "todas dentro de ≤ %d luces y ≤ %d partículas (máximo medido: %d luces, %d partículas)" % [LabVfx3D.MAX_LUCES, LabVfx3D.MAX_PARTICULAS, max_l, max_p])
		else:
			_aviso("F4 celdas base fuera de presupuesto (%d de 24)" % fuera.size(), "; ".join(fuera))
		_ok("15 se midieron las 24", vfx.marcas.size() >= 24)

		# Humo de la matriz entera: las 480 celdas se lanzan sin romper nada.
		var cero: int = 0
		var ceros_de: PackedStringArray = []
		for e in range(6):
			for v in range(4):
				for p in range(5):
					for i in range(4):
						vfx.poner(e, v, p, i)
						if vfx.lanzar() <= 0:
							cero += 1
							ceros_de.append(vfx.clave())
						await avanzar(1)
		if cero > 0:
			_aviso("F4 celdas que no salieron al lanzarlas (casillas = 0)", "%d de 480: %s" % [cero, ", ".join(ceros_de)])
		_ok("15 las 480 celdas se pueden lanzar una tras otra sin romper el lab", lab.get("_l") != null)
		lab.limpiar_sala()
		await avanzar_s(LabVfx3D.VENTANA_MEDIDA_S + 0.2)

		# Cuentas, criterio y guardado.
		vfx.marcas.clear()
		_ok("15 con la matriz vacía el criterio no se cumple (0/24)", vfx.base_aprobadas() == 0 and not vfx.criterio_cumplido())
		for c in LabVfx3D.celdas_base():
			vfx.marcas[LabVfx3D.clave_de(c[0], c[1], c[2], c[3])] = {"estado": LabVfx3D.APROBADO, "nota": ""}
		_ok("15 con las 24 base aprobadas el criterio se cumple", vfx.base_aprobadas() == 24 and vfx.criterio_cumplido())
		_ok("15 …y por estado salen 4/4", vfx.base_aprobadas_de(0) == 4 and vfx.base_aprobadas_de(5) == 4)
		vfx.marcas[LabVfx3D.clave_de(2, 0, 0, 1)]["estado"] = LabVfx3D.RECHAZADO
		_ok("15 rechazar una base lo rompe (23/24)", vfx.base_aprobadas() == 23 and not vfx.criterio_cumplido() and vfx.base_aprobadas_de(2) == 3)
		vfx.marcas[LabVfx3D.clave_de(2, 0, 0, 1)]["estado"] = ""
		vfx.poner(0, 0, 0, 0)
		_ok("15 Tab salta a la base sin marcar (plasma·esfera·ninguna·goblin)", vfx.siguiente_base_pendiente() and vfx.clave() == LabVfx3D.clave_de(2, 0, 0, 1))
		vfx.marcas[LabVfx3D.clave_de(2, 0, 0, 1)]["estado"] = LabVfx3D.APROBADO
		_ok("15 …y avisa cuando ya no queda ninguna", not vfx.siguiente_base_pendiente())
		vfx.marcas[LabVfx3D.clave_de(1, 2, 3, 2)] = {"estado": LabVfx3D.RECHAZADO, "nota": "color", "luces": 1, "particulas": 120}
		vfx.marcas["gas|X3|ninguna|suelo"] = {"estado": "", "nota": "", "luces": 0, "particulas": 10}
		var ruta_vfx: String = "user://prueba_vfx_aprobados.json"
		_ok("15 guardar escribe el archivo", vfx.guardar(ruta_vfx) and FileAccess.file_exists(ruta_vfx))
		var jv: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta_vfx))
		_ok("15 …con las cuentas del criterio y solo las celdas con marca o nota", jv is Dictionary and int(jv["cuentas"]["aprobadas"]) == 24 and bool(jv["cuentas"]["criterio_cumplido"]) and (jv["celdas"] as Dictionary).has("liquido|Y2|crece|agua") and not (jv["celdas"] as Dictionary).has("gas|X3|ninguna|suelo"))
		var copia_m: Dictionary = vfx.marcas.duplicate(true)
		vfx.marcas.clear()
		_ok("15 cargar devuelve las marcas (%d)" % copia_m.size(), vfx.cargar(ruta_vfx) and vfx.valor_marca("liquido|Y2|crece|agua") == LabVfx3D.RECHAZADO and vfx.base_aprobadas() == 24 and String(vfx.marcas["liquido|Y2|crece|agua"]["nota"]) == "color")
		DirAccess.remove_absolute(ruta_vfx)
		# Con el presupuesto: aprobar una celda medida por encima no se deja.
		vfx.poner(3, 0, 0, 0)
		vfx.marcas[vfx.clave()] = {"estado": "", "nota": "", "luces": LabVfx3D.MAX_LUCES + 1, "particulas": 10}
		_ok("15 una celda con más luces que el presupuesto no se aprueba", not vfx.aprobar() and vfx.valor_marca(vfx.clave()) == "")
		vfx.marcas[vfx.clave()] = {"estado": "", "nota": "", "luces": 1, "particulas": LabVfx3D.MAX_PARTICULAS + 1}
		_ok("15 …ni con más partículas", not vfx.aprobar() and vfx.valor_marca(vfx.clave()) == "")
		vfx.marcas[vfx.clave()] = {"estado": "", "nota": "", "luces": LabVfx3D.MAX_LUCES, "particulas": LabVfx3D.MAX_PARTICULAS}
		_ok("15 …y en el límite exacto sí", vfx.aprobar())
		vfx.marcas = marcas_user
		vfx.guardar_al_marcar = true
		lab.poner_pestana(0)
	# --- 16 · F5: los estados de animación en vivo (lab_estados_3d.gd, A1+A2 20/10)
	var f5: Variant = lab.get("f5")
	_ok("16 el lab monta la pestaña F5 (LabEstados3D)", f5 != null and f5 is LabEstados3D)
	var jug5: Variant = lab.get("_jug")
	var pj5: Pj3D = (jug5.get("pj") as Pj3D) if jug5 != null else null
	if f5 != null and f5 is LabEstados3D and pj5 != null and pj5.arbol() != null:
		var est: LabEstados3D = f5 as LabEstados3D
		var ar5: ArbolAnimPj = pj5.arbol()
		_tecla_lab(KEY_F5)
		_ok("16 F5 abre la pestaña de estados", lab.pestana == LabHechizos3D.Pestana.ESTADOS)
		_ok("16 …y el panel tiene los cinco botones de pestaña", lab.get("_panel_extra").has("pestana4"))
		var hud5: String = lab.texto_hud()
		_ok("16 el HUD de F5 enseña el árbol, el libro y los roles", hud5.contains("F5 ESTADOS") and hud5.contains("ÁRBOL") and hud5.contains("LIBRO") and hud5.contains("ROLES"))
		# Elegir y forzar: correr.
		est.sel = 0
		_tecla_lab(KEY_DOWN)
		_tecla_lab(KEY_UP)
		_ok("16 ↑ ↓ mueven el rol elegido y dan la vuelta", est.sel == 0)
		_tecla_lab(KEY_UP)
		_ok("16 …(↑ desde el primero va al último)", est.sel == LabEstados3D.ROLES.size() - 1)
		for i in range(LabEstados3D.ROLES.size()):
			if String(LabEstados3D.ROLES[i][0]) == "run":
				est.sel = i
		_tecla_lab(KEY_ENTER)
		await avanzar_s(0.4)
		_ok("16 Intro fuerza «run» → estado «correr» y el árbol está ahí de verdad", pj5.estado_anim() == "correr" and ar5.estado_real() == "correr" and est.ultimo_mensaje.begins_with("✓"), est.ultimo_mensaje)
		_ok("16 el HUD marca el estado actual (●) y enseña el clip", lab.texto_hud().contains("●") and lab.texto_hud().contains(pj5.clip_actual()))
		# Una prohibida: muerto → rodar.
		for i in range(LabEstados3D.ROLES.size()):
			if String(LabEstados3D.ROLES[i][0]) == "death":
				est.sel = i
		_tecla_lab(KEY_ENTER)
		await avanzar_s(0.4)
		_ok("16 forzar «death» → «muerto»", pj5.estado_anim() == "muerto")
		for i in range(LabEstados3D.ROLES.size()):
			if String(LabEstados3D.ROLES[i][0]) == "roll":
				est.sel = i
		var rech5: int = ar5.rechazos
		_tecla_lab(KEY_ENTER)
		await avanzar_s(0.3)
		_ok("16 muerto → rodar está PROHIBIDO: no cambia nada, se cuenta y el HUD dice por qué", pj5.estado_anim() == "muerto" and ar5.rechazos == rech5 + 1 and est.ultimo_mensaje.contains("PROHIBIDA") and lab.texto_hud().contains("✗"), est.ultimo_mensaje)
		_tecla_lab(KEY_DELETE)
		_ok("16 Supr limpia el historial", ar5.historial.is_empty())
		_tecla_lab(KEY_I)
		await avanzar_s(0.4)
		_ok("16 I vuelve a idle (reaparecer: de muerto solo se sale a idle)", pj5.estado_anim() == "idle" and ar5.estado_real() == "idle")
		# El libro.
		_tecla_lab(KEY_B)
		_ok("16 B saca el libro (en_mano_abierto)", pj5.libro_estado() == "en_mano_abierto" and pj5.libro_valido() and lab.texto_hud().contains("en_mano_abierto"))
		_tecla_lab(KEY_B)
		_ok("16 B otra vez lo manda al cinto volando", pj5.libro_estado() == "volando" and pj5.libro_valido())
		await avanzar_s(0.8)
		_ok("16 …y al acabar el vuelo está en el cinto", pj5.libro_estado() == "cinto" and pj5.libro_valido())
		# Velocidad del mundo.
		_tecla_lab(KEY_V)
		_ok("16 V: velocidad del mundo ×0,25", is_equal_approx(pj5.velocidad_animacion(), 0.25))
		_tecla_lab(KEY_V)
		_ok("16 V: ×0 (hitstop: congelado)", is_equal_approx(pj5.velocidad_animacion(), 0.0))
		_tecla_lab(KEY_V)
		_tecla_lab(KEY_V)
		_ok("16 V: tras cuatro pulsaciones vuelve a ×1", is_equal_approx(pj5.velocidad_animacion(), 1.0))
		# Datos para el diario / P.
		var d5: Dictionary = est.datos()
		_ok("16 datos() resume estado, clip, libro y historial", d5.has("estado") and d5.has("libro") and d5.has("historial") and String(d5["estado"]) == "idle")
		# Nadando no se ruedan ni se bebe: el HUD lo enseña con ✗ y el motivo.
		for i in range(LabEstados3D.ROLES.size()):
			if String(LabEstados3D.ROLES[i][0]) == "swim":
				est.sel = i
		_tecla_lab(KEY_ENTER)
		await avanzar_s(0.4)
		_ok("16 nadando, el HUD marca rodar/beber como prohibidos con el motivo", pj5.estado_anim() == "nadar" and lab.texto_hud().contains("no se entra en"))
		_tecla_lab(KEY_I)
		await avanzar_s(0.4)
		_ok("16 al volver a idle el árbol queda en el estado pedido", ar5.estado_real() == ar5.estado and ar5.estado == "idle")
		pj5.set_velocidad_animacion(1.0)
		lab.poner_pestana(0)
	LabHechizos3D.cargar_al_abrir = true

func get_root_pausado() -> bool:
	return root.get_tree().paused


func get_nodes_en_arbol() -> Array:
	return maqueta.get_children()


## Las recetas del azar respetan los topes de la tabla.
func _barrido_valido(l: Node) -> bool:
	l.get("_rng").seed = 99
	for _i in range(200):
		var r: Dictionary = l.receta_al_azar()
		var total: int = 0
		for g in (r["glifos"] as Dictionary):
			var n: int = int(r["glifos"][g])
			total += n
			if n < 1 or n > l.glifos_hasta_tope(String(g)) + 1:
				return false
		if total > l.MAX_GLIFOS_BARRIDO or not l.ELEMENTOS.has(r["elemento"]):
			return false
	return true
