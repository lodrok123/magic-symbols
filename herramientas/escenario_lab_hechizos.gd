extends "res://herramientas/escenario_base.gd"
## Escenario H1 · el LABORATORIO DE HECHIZOS (laboratorios/LabHechizos3D.tscn), sin ventana (18/10, Juego). Antes era escenario_lab_recetas (R4, 17/10): las
## secciones 0–6 son aquellas, intactas (sala, goblins quietos, contadores y HUD, lanzamiento rápido, barrido, tiempo) y de la 7 en adelante lo nuevo:
## pestañas F1–F3 y las constantes de Combate3D en vivo, el MODO CONJURO COMPLETO (las 4 fases salen en orden y el disparo llega), tinta infinita y
## recarga apagada (y sus interruptores), el goblin que ataca y la limpieza de la sala entre rondas del barrido.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_lab_hechizos.gd
## Lo que el barrido anota como «rara» se imprime como AVISO (es información para Pablo, no un fallo).

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"

var lab: Node = null


class ContadorFisica extends Node:
	var n: int = 0
	func _physics_process(_d: float) -> void:
		n += 1


func _tecla_lab(k: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	lab._unhandled_input(ev)


func _escenario() -> void:
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
	_ok("2 el panel tiene un contador por glifo de GLIFOS_V2", (lab.get("_panel_cuentas") as Dictionary).size() == glifos.size() and glifos.size() == 8, str(glifos))
	lab.limpiar()
	lab.sumar("linea_z", 1)
	lab.sumar("linea_z", 1)
	_ok("2 sumar dos linea_z da z = base + 2·base (%.2f)" % (Sigils.RADIO_BASE_V2 * 3.0), is_equal_approx(float(lab.receta().geo()["z"]), Sigils.RADIO_BASE_V2 * 3.0), str(lab.receta().geo()["z"]))
	for _i in range(20):
		lab.sumar("linea_z", 1)
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
	_ok("3 el HUD enseña los semiejes del elipsoide", hud.contains("Elipsoide") and hud.contains("z %.2f" % (Sigils.RADIO_BASE_V2 * 2.0)), hud.get_slice("\n", 1))
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
	for _i in range(8):                      # y = 0,15 · 9 = 1,35 → 3 niveles (más de los 1 que se pueden pisar)
		lab.sumar("altura", 1)
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
	var sim: AguaSim3D = Terreno3D.agua_sim
	var vol0: float = sim.volumen_total() if sim != null else 0.0
	lab.limpiar()
	lab.poner_elemento("earth")
	for _i in range(8):
		lab.sumar("linea_x", 1)
		lab.sumar("linea_z", 1)
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
	# ↑/↓ elige, ←/→ cambia, Mayús ×10, Retroceso restaura
	lab.tabla_sel = int(idx13["velocidad"]) - 1
	_tecla_lab(KEY_DOWN)
	_ok("13 ↓ elige la fila siguiente (velocidad)", int(lab.tabla_sel) == int(idx13["velocidad"]))
	_tecla_lab(KEY_RIGHT)
	_ok("13 → sube velocidad un paso y queda como sobrescritura (%s)" % str(lab.cambios_hechizo), is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 1.0))
	var fv13: Dictionary = lab.tabla_filas()[int(idx13["velocidad"])]
	_ok("13 la tabla enseña lo tocado con origen «lab»", String(fv13["origen"]) == "lab" and is_equal_approx(float(fv13["valor"]), 1.0))
	_tecla_lab(KEY_RIGHT, true)
	_ok("13 Mayús+→ cambia ×10 (%s)" % str(lab.cambios_hechizo.get("velocidad")), is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 11.0))
	_tecla_lab(KEY_LEFT)
	_ok("13 ← baja un paso", is_equal_approx(float(lab.cambios_hechizo.get("velocidad", -1.0)), 10.0))
	_tecla_lab(KEY_BACKSPACE)
	_ok("13 Retroceso restaura la fila (sin sobrescritura)", not lab.cambios_hechizo.has("velocidad"))
	# un bool, una lista, un tope y una fila que no se toca
	lab.tabla_sel = int(idx13["retorna"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 un bool se alterna (retorna → true)", lab.cambios_hechizo.get("retorna") == true)
	_tecla_lab(KEY_LEFT)
	_ok("13 y al volver al valor original la sobrescritura se quita", not lab.cambios_hechizo.has("retorna"))
	lab.tabla_sel = int(idx13["estado_materia"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 una lista avanza (plasma → %s)" % str(lab.cambios_hechizo.get("estado_materia")), lab.cambios_hechizo.get("estado_materia") == "energia")
	_tecla_lab(KEY_BACKSPACE)
	lab.tabla_sel = int(idx13["copias"])
	_tecla_lab(KEY_LEFT)
	_ok("13 un número no baja de su mínimo (copias 1 ← sigue en el original)", not lab.cambios_hechizo.has("copias"))
	lab.tabla_sel = int(idx13["color"])
	_tecla_lab(KEY_RIGHT)
	_ok("13 una fila de solo lectura (color) no se toca", lab.cambios_hechizo.is_empty())
	# lo tocado se usa en el SIGUIENTE lanzamiento
	lab.tabla_sel = int(idx13["velocidad"])
	for _k13 in range(5):
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
	# Mayús+Retroceso restaura todo y el siguiente hechizo vuelve a ser el de siempre
	_tecla_lab(KEY_BACKSPACE, true)
	_ok("13 Mayús+Retroceso restaura todas las filas", lab.cambios_hechizo.is_empty() and lanzador.cambios_hechizo.is_empty())
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
	_ok("13 la tabla solo se ve en F1", lab.texto_hud().length() > 0 and lab.get("_tabla_label") != null and (lab.get("_tabla_label") as Control).visible)
	lab.poner_pestana(2)
	_ok("13 y se oculta en F3", not (lab.get("_tabla_label") as Control).visible)
	lab.poner_pestana(0)

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
