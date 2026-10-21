extends "res://herramientas/escenario_base.gd"
## Escenario del LABORATORIO DE PLAYTEST DE EoW (21/10, Juego). Carga laboratorios/LabPlaytestEoW.tscn (la maqueta con el mapa PlaytestEoW, el jugador, el
## Lanzador3D, el agua y las piezas de verdad) y comprueba la BASE del laboratorio y la sala 1; sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_playtest_eow.gd
## (en Windows: tools\prueba_una.cmd escenario_playtest_eow).
## Estructura: una sección por sala (`_sala_N`). Las salas 2–7 están preparadas como secciones vacías: quien rellene una sala escribe su sección aquí y la
## añade a `_escenario`, sin tocar las demás. Lo que se mide y todavía no es contrato sale como AVISO.
##   · 0  base: el lab cuelga de la escena, el enganche de efectos devolvió true, el HUD existe, las teclas llevan a cada sala, guardar/cargar flags.
##   · 1  sala 1 · fuego por contacto (A2): brasero → goblin → seto, cortafuegos mojado, flecha del arquero a través de una llama, reacciones en el HUD.
##   · 2  sala 2 · al agua (A3): viento real empuja a goblins de la orilla a la parte honda (se hunden: señal, HUD, «drown», sin botín) y a la franja helada (no); el perseguidor no se mete.
##   · 3  sala 3 · escudo (A5): disparo de frente bloqueado, por la espalda y de lado pasa, el fuego lo prende y consume y después el de frente llega.
##   · 4  sala 4 · caminos (D2): sin helar no hay ruta; con una casilla helada la ruta rodea la pared, sube la terraza de 1 nivel (la de 2 no) y cruza el hielo; tecla X; tierra de 1 nivel no
##        es muro, de 2 niveles sí (la ruta cambia sola); el goblin de verdad recorre cada ruta. El olfato del lab (SALA4_OLFATO) y el hielo/tierra son lo que se mide aparte.
##   · 5  sala 5 · suelo y condiciones (B1+C2): puerta A (3 mojadas Y brasero apagado), B (O y NO con hielo/fuego), C y D (plantilla `$`), dos aguas hielan, el puente de estados del lab.
##   · D  el clip de ahogarse (`drown`) lo pide un goblin que se hunde (con el modelo de verdad cargado).

const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"

var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio (LabPlaytestEoW3D) cuelga de la escena", lab != null and lab is LabPlaytestEoW3D)
	if lab == null:
		return
	_base()
	await _teclas()
	await _sala_1()
	await _sala_2()
	await _sala_3()
	await _sala_4()
	await _sala_5()
	# --- Aquí, una línea por sala cuando se rellene: `await _sala_6()` y `await _sala_7()` ---
	await _ahogarse()


# ---------------------------------------------------------------------------------------------------------------------

func _arde(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and bool((n as Object).get("is_lit"))


func _hud_tiene_de(nombre: String, tipo: String) -> bool:
	for r in lab.reacciones():
		if String((r as Dictionary)["nombre"]) == nombre and String((r as Dictionary)["tipo"]) == tipo:
			return true
	return false


func _runa(etiquetas: Array) -> RuneData:
	return Puzle3D.runa(etiquetas)


## Un disparo de FUEGO a una casilla, desde otra, y lo que tarda la flecha en llegar (más de 1,2 s si está a 2 casillas largas).
func _fuego_a(objetivo: Vector2i, desde: Vector2i, espera: float = 2.0) -> bool:
	var ok: bool = lanzar_a_celda("fuego", ["flecha"], objetivo, desde)
	await avanzar_s(espera)
	return ok


func _agua_a(objetivo: Vector2i, desde: Vector2i, espera: float = 2.0) -> bool:
	var ok: bool = lanzar_a_celda("agua", ["flecha"], objetivo, desde)
	await avanzar_s(espera)
	return ok


## ¿Ha llegado al HUD una reacción de ese nombre?
func _hud_tiene(nombre: String) -> bool:
	for r in lab.reacciones():
		if String((r as Dictionary)["nombre"]) == nombre:
			return true
	return false


# ---------------------------------------------------------------------------------------------------------------------
#  0 · la base
# ---------------------------------------------------------------------------------------------------------------------

func _base() -> void:
	_ok("0.1 el enganche de efectos (ReaccionesVfx3D.conectar) devolvió true", lab.enganche_ok())
	_ok("0.2 el laboratorio no ha dejado avisos al montar (piezas del mapa, papeles de sala)", lab.avisos().is_empty(), str(lab.avisos()))
	_ok("0.3 el HUD existe y dice sala, efectos, reacciones, flags y ayuda de teclas", lab.hud() != null and lab.hud().is_inside_tree()
		and lab.texto_hud().contains("LAB PLAYTEST EoW") and lab.texto_hud().contains("efectos de reacciones: enganchados")
		and lab.texto_hud().contains("REACCIONES") and lab.texto_hud().contains("FLAGS") and lab.texto_hud().contains("Shift+1–7 sala"), lab.texto_hud())
	_ok("0.4 el HUD enseña la casilla del jugador (estados, agua, helada, altura)", lab.texto_hud().contains("CASILLA") and lab.texto_hud().contains("helada:") and lab.texto_hud().contains("altura:"))
	_ok("0.5 el mapa tiene 33 × 17 casillas y siete salas", int(maqueta.get("_ancho")) == 33 and int(maqueta.get("_alto")) == 17 and LabPlaytestEoW3D.SALAS.size() == 7,
		"%s × %s" % [str(maqueta.get("_ancho")), str(maqueta.get("_alto"))])
	var puzle: Puzle3D = lab.puzle_nodo()
	_ok("0.6 las piezas de la sala 1 se han montado desde el .txt", is_instance_valid(puzle.nodo("s1_brasero")) and is_instance_valid(puzle.nodo("s1_seto4")) and is_instance_valid(puzle.nodo("s1_brasero_arq")))
	_ok("0.7 el jugador nace en la sala 1", lab.sala_actual() == 1, str(celda_jugador()))
	_ok("0.8 hay un hook de preparación por sala (2–7 vacíos)", range(1, 8).all(func(n: int) -> bool: return lab.has_method("_preparar_sala_%d" % n)))


## Las teclas llevan a cada sala; guardar y cargar flags; rutas. El evento va por el sistema de entrada (llega a `_unhandled_input` como en el juego).
func _teclas() -> void:
	for i in range(LabPlaytestEoW3D.SALAS.size()):
		var entrada: Vector2i = LabPlaytestEoW3D.SALAS[i]["entrada"]
		# La cifra SUELTA ya no salta de sala (es del libro de hechizos): primero desde otra sala, sin Shift, y se queda donde estaba.
		var otra: int = 0 if i != 0 else 1
		lab.ir_a_sala(otra + 1)
		await avanzar(2)
		var antes: Vector2i = celda_jugador()
		_pulsar(LabPlaytestEoW3D.TECLAS_SALA[i])
		await avanzar(2)
		_ok("0.9.%d la cifra %d SIN Shift no cambia de sala" % [i + 1, i + 1], celda_jugador() == antes, "casilla %s → %s" % [str(antes), str(celda_jugador())])
		_pulsar(LabPlaytestEoW3D.TECLAS_SALA[i], true)
		await avanzar(2)
		_ok("0.9.%d Shift + %d lleva a la entrada de la sala %d" % [i + 1, i + 1, i + 1], celda_jugador() == entrada and lab.sala_actual() == i + 1, "casilla %s sala %d" % [str(celda_jugador()), lab.sala_actual()])
		lab.ir_a_sala(otra + 1)
		await avanzar(2)
		_pulsar(LabPlaytestEoW3D.TECLAS_SALA_KP[i])
		await avanzar(2)
		_ok("0.9.%d el teclado numérico KP %d (sin Shift) también lleva a la sala %d" % [i + 1, i + 1, i + 1], celda_jugador() == entrada and lab.sala_actual() == i + 1, "casilla %s" % str(celda_jugador()))
	# Guardar y cargar (en el archivo del lab, no en el de la partida).
	Flags.i().poner("playtest.prueba.marca")
	_pulsar(LabPlaytestEoW3D.TECLA_GUARDAR)
	await avanzar(2)
	_ok("0.10 la tecla de guardar escribe las flags en el archivo del lab", FileAccess.file_exists(LabPlaytestEoW3D.RUTA_GUARDADO) and lab.texto_hud().contains("flags guardadas"))
	Flags.i().quitar("playtest.prueba.marca")
	_ok("0.11 sin la marca el HUD no la lista", not lab.texto_hud().contains("playtest.prueba.marca"))
	_pulsar(LabPlaytestEoW3D.TECLA_CARGAR)
	await avanzar(2)
	_ok("0.12 la tecla de cargar la devuelve y el HUD la lista", Flags.i().tiene("playtest.prueba.marca") and lab.texto_hud().contains("playtest.prueba.marca"))
	Flags.i().quitar("playtest.prueba.marca")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LabPlaytestEoW3D.RUTA_GUARDADO))
	# Rutas de los goblins: la tecla las dibuja (de cada goblin vivo hasta el jugador) y la misma tecla las borra.
	lab.ir_a_sala(1)
	await avanzar(2)
	_pulsar(LabPlaytestEoW3D.TECLA_RUTAS)
	await avanzar(2)
	_ok("0.13 la tecla X dibuja la ruta de cada goblin hasta el jugador", lab.rutas_visibles() and lab.marcas_de_ruta() >= 2, "%d marcas" % lab.marcas_de_ruta())
	_ok("0.14 y el HUD lo dice", lab.texto_hud().contains("rutas goblins (SÍ)"))
	_pulsar(LabPlaytestEoW3D.TECLA_RUTAS)
	await avanzar(2)
	_ok("0.15 la misma tecla las borra", not lab.rutas_visibles() and lab.marcas_de_ruta() == 0)


func _pulsar(tecla: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.shift_pressed = shift
	ev.pressed = true
	Input.parse_input_event(ev)
	var suelta := InputEventKey.new()
	suelta.keycode = tecla
	suelta.physical_keycode = tecla
	suelta.shift_pressed = shift
	suelta.pressed = false
	Input.parse_input_event(suelta)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · fuego por contacto (A2)
# ---------------------------------------------------------------------------------------------------------------------

func _sala_1() -> void:
	var q: Dictionary = lab.sala(1)
	var brasero: Reactivo3D = q["brasero"]
	var setos: Array = [q["seto1"], q["seto2"], q["seto3"], q["seto4"]]
	var g: Combate3D = q["guerrero"]
	var arq: Combate3D = q["arquero"]
	_ok("1.1 el goblin guerrero y el arquero existen y el arquero es de verdad un arquero", g != null and arq != null and arq.arquero and not g.arquero)
	_ok("1.2 el brasero de la izquierda y los cuatro setos están apagados; el brasero del arquero arde desde el principio",
		not _arde(brasero) and setos.all(func(s): return is_instance_valid(s) and not _arde(s)) and _arde(q["brasero_arquero"]))
	_ok("1.3 el tercer seto es mojable y los demás no", (setos[2] as Reactivo3D).mojable and not (setos[0] as Reactivo3D).mojable)
	_ok("1.4 el goblin patrulla (no ve al jugador) y no arde", g.estado == "patrulla" and not g.esta_ardiendo())
	# El mundo lleva ~50 s simulados desde que cargó la escena (el velo de precalentado se espera con fotogramas, no con segundos): se parte de cero.
	colocar_jugador(lab.sala(1)["entrada"])
	jugador.set("vida", 100.0)
	await avanzar(2)

	# --- Cortafuegos: agua al tercer seto desde el norte (el goblin está a 3 casillas: no ve al jugador). El agua dura 12 s (Reactivo3D.T_MOJADO) y el fuego tarda ~10 s
	# en llegar a ese seto desde que se enciende el brasero: se moja y SEGUIDO se enciende (con una pausa de más, el seto se seca y arde: medido). ---
	_ok("1.5 agua + flecha al tercer seto sale", lanzar_a_celda("agua", ["flecha"], Vector2i(6, 3), Vector2i(6, 1)))
	await avanzar(3)
	# --- Fuego al brasero apagado (la flecha no llega a 3 casillas: se dispara desde (1,5), a 2,2) y de vuelta al punto de partida, fuera de la vista del goblin ---
	# (Desde (1,5) el goblin ve al jugador al acercarse: en la prueba se vuelve al punto de partida en cuanto sale la flecha, para que el goblin siga PATRULLANDO.)
	_ok("1.8 fuego + flecha al brasero apagado sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(2, 3), Vector2i(1, 5)))
	await avanzar(2)
	colocar_jugador(lab.sala(1)["entrada"])
	await avanzar_s(2.0)
	_ok("1.6 el tercer seto queda MOJADO y no puede arder", (setos[2] as Reactivo3D).esta_mojado() and not (setos[2] as Reactivo3D).can_burn())
	_ok("1.7 la reacción «mojado» llega al HUD", _hud_tiene("mojado"), str(lab.reacciones()))
	_ok("1.9 el brasero arde", _arde(brasero))
	_ok("1.10 la reacción «prendido» llega al HUD (el brasero)", _hud_tiene("prendido"))
	var r: Dictionary = {"goblin": -1.0, "s1": -1.0, "s2": -1.0, "s3": -1.0, "s4": -1.0}
	var vigilar := func(t: float) -> void:
		if float(r["goblin"]) < 0.0 and g.esta_ardiendo():
			r["goblin"] = t
		for i in range(4):
			var clave: String = "s%d" % (i + 1)
			if float(r[clave]) < 0.0 and (not is_instance_valid(setos[i]) or _arde(setos[i])):
				r[clave] = t
	# El fuego llega al tercer seto entre 7 y 12 s después de encender el brasero (según en qué punto de su ronda estuviera el goblin: medido), y el agua dura 12 s
	# desde el disparo: con UN solo disparo a veces se ha secado. Como haría el jugador, se repone el agua cada 5 s mientras el fuego corre.
	var base: Array = [0.0]
	var vigilar_con_base := func(t: float) -> void: vigilar.call(float(base[0]) + t)
	for _vuelta in range(5):
		await avanzar_vigilando(5.0, 0.1, vigilar_con_base)
		base[0] = float(base[0]) + 5.0
		lanzar_a_celda("agua", ["flecha"], Vector2i(6, 3), Vector2i(6, 1))
		await avanzar(2)
		colocar_jugador(lab.sala(1)["entrada"])
	_ok("1.11 el goblin que patrulla pegado al brasero encendido se prende al tocarlo", float(r["goblin"]) > 0.0, "a los %.1f s" % float(r["goblin"]))
	_ok("1.12 el goblin ardiendo prende el primer seto al tocarlo", float(r["s1"]) > 0.0 and float(r["s1"]) >= float(r["goblin"]) - 0.2, "a los %.1f s" % float(r["s1"]))
	_ok("1.13 el fuego corre al segundo seto", float(r["s2"]) > 0.0, "a los %.1f s" % float(r["s2"]))
	_ok("1.14 CORTAFUEGOS: el seto mojado no prende y el cuarto se salva", float(r["s3"]) < 0.0 and float(r["s4"]) < 0.0 and is_instance_valid(setos[2]) and is_instance_valid(setos[3]), str(r))
	_ok("1.15 las reacciones «prendido» del goblin y de los setos llegaron al HUD", lab.total_reacciones() >= 3 and lab.texto_hud().contains("prendido") and lab.texto_hud().contains("goblin"), lab.texto_hud())
	volcar("playtest_s1_contacto", {"goblin": r["goblin"], "s1": r["s1"], "s2": r["s2"]})

	# --- La flecha del arquero cruza el brasero encendido ---
	if is_instance_valid(g):
		g.quieto = true                               # el guerrero (quemado, quizá muerto ya) no persigue al jugador mientras se mira al arquero
	jugador.set("vida", 100.0)
	var a1: Dictionary = await _tiro_del_arquero(arq, 10.0)
	_ok("1.16 el arquero ve al jugador (desde el norte, con su brasero en medio) y dispara", int(a1["flechas"]) >= 1, str(a1))
	_ok("1.17 su flecha cruza el brasero encendido y sale ARDIENDO", int(a1["ardiendo"]) >= 1, str(a1))
	_ok("1.18 y su impacto lleva fuego al jugador (señal flecha_ardiente_impacta)", int(a1["impactos_ardiendo"]) >= 1, str(a1))
	# Lo que pasa con la casilla del brasero BLOQUEADA, como en el juego tal cual (no es contrato: se mide y se enseña).
	Terreno3D.bloquear_celda(LabPlaytestEoW3D.SALA1_BRASERO_ARQUERO)
	colocar_jugador(lab.sala(1)["entrada"])
	await avanzar_s(8.0)                              # que el arquero lo pierda de vista y vuelva
	jugador.set("vida", 100.0)
	var a2: Dictionary = await _tiro_del_arquero(arq, 10.0)
	_aviso("1.19 con la casilla del brasero BLOQUEADA (el juego tal cual)", "flechas %d, ardiendo %d, impactos con fuego %d" % [a2["flechas"], a2["ardiendo"], a2["impactos_ardiendo"]])
	Terreno3D.liberar_celda(LabPlaytestEoW3D.SALA1_BRASERO_ARQUERO)
	colocar_jugador(lab.sala(1)["entrada"])


## Pone al jugador en (6,5) (al norte del brasero del arquero) y cuenta, durante `segundos`, las flechas del arquero, las que van ardiendo y los impactos con fuego.
func _tiro_del_arquero(arq: Combate3D, segundos: float) -> Dictionary:
	colocar_jugador(Vector2i(6, 5))
	var res: Dictionary = {"flechas": 0, "ardiendo": 0, "impactos_ardiendo": 0}
	var vistas: Dictionary = {}                       # instance_id de cada flecha ya contada
	var impactos: Array = [0]
	var cb := func(_o: Node3D) -> void: impactos[0] += 1
	arq.flecha_ardiente_impacta.connect(cb)
	await avanzar_vigilando(segundos, 0.05, func(_t: float) -> void:
		for n in arq.mundo.get_children():
			if n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh and ((n as MeshInstance3D).mesh as BoxMesh).size.is_equal_approx(Vector3(0.05, 0.05, 0.6)):
				if not vistas.has(n.get_instance_id()):
					vistas[n.get_instance_id()] = false
					res["flechas"] = int(res["flechas"]) + 1
				if n.has_meta("ardiendo") and not bool(vistas[n.get_instance_id()]):
					vistas[n.get_instance_id()] = true
					res["ardiendo"] = int(res["ardiendo"]) + 1
	)
	arq.flecha_ardiente_impacta.disconnect(cb)
	res["impactos_ardiendo"] = impactos[0]
	return res


# ---------------------------------------------------------------------------------------------------------------------
#  2 · al agua (A3)
# ---------------------------------------------------------------------------------------------------------------------

func _oros() -> int:
	var n: int = 0
	for c in (maqueta.get("_mundo") as Node).get_children():
		if c.name.begins_with("Oro"):
			n += 1
	return n


## Un viento (flecha) al goblin `g` lanzado desde el sur (misma columna, fila 7) y lo que le pasa en `segundos`: si murió, si se hundió, si pidió el clip «drown» y
## cuántos «hundido» salieron por su señal.
func _empuje_de_viento(g: Combate3D, segundos: float = 3.5) -> Dictionary:
	var c: Vector2i = Terreno3D.celda_de(g.global_position)
	var res: Dictionary = {"muerto": false, "hundido": false, "drown": false, "senal": 0, "x": g.global_position.x, "z": g.global_position.z, "lanzado": false, "anim": ""}
	var cuenta: Array = [0]
	var cb := func(_e: Combate3D) -> void: cuenta[0] += 1
	g.hundido.connect(cb)
	jugador.set("vida", 100.0)
	res["lanzado"] = lanzar_a_celda("viento", ["flecha"], c, Vector2i(c.x, 7))
	var ref: Array = [g]                           # el goblin se libera a los ~2 s de hundirse: una lambda que lo capture directo falla (y el contenedor sí sobrevive)
	await avanzar_vigilando(segundos, 0.05, func(_t: float) -> void:
		var e: Combate3D = ref[0] if is_instance_valid(ref[0]) else null
		if e != null:
			res["muerto"] = res["muerto"] or e.muerto
			res["hundido"] = res["hundido"] or e.se_hundio
			if e.muerto and is_instance_valid(e.pj):
				var s: String = "%s/%s/%s" % [e.pj.estado_anim(), e.pj.animacion_actual, e.pj.clip_actual()]
				if not String(res["anim"]).ends_with(s):
					res["anim"] = String(res["anim"]) + " > " + s
				if e.pj.estado_anim() == "drown":
					res["drown"] = true
			res["x"] = e.global_position.x
			res["z"] = e.global_position.z
	)
	if is_instance_valid(g):
		g.hundido.disconnect(cb)
	res["senal"] = cuenta[0]
	return res

func _sala_2() -> void:
	var q: Dictionary = lab.sala(2)
	var gi: Combate3D = q["orilla_izq"]
	var gc: Combate3D = q["orilla_centro"]
	var gh: Combate3D = q["orilla_hielo"]
	var per: Combate3D = q["perseguidor"]
	_ok("2.1 hay los tres goblins de la orilla y el perseguidor", gi != null and gc != null and gh != null and per != null)
	if gi == null or gc == null or gh == null or per == null:
		return
	var honda: bool = true
	var hielo: bool = true
	for x in [10, 11, 12]:
		for y in [2, 3, 4]:
			var c := Vector2i(x, y)
			honda = honda and Terreno3D.se_nada(c) and (Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(c))
	for x in LabPlaytestEoW3D.SALA2_FRANJA_X:
		for y in LabPlaytestEoW3D.SALA2_FRANJA_Y:
			hielo = hielo and Terreno3D.helada(Vector2i(x, y)) and not Terreno3D.es_agua(Vector2i(x, y))
	_ok("2.2 la parte izquierda de la charca (x 10–12, y 2–4) es agua HONDA de la que se nada (con la simulación)", honda)
	_ok("2.3 la franja de la derecha (x 13–14) empieza helada y ya no cuenta como agua", hielo)
	var prof: float = Terreno3D.agua_sim.profundidad_casilla(Vector2i(11, 3)) if Terreno3D.agua_sim != null else -1.0
	_ok("2.4 hay agua física en la escena (simulación con profundidad en el centro de la charca)", prof > 0.2, "%.2f u" % prof)
	# Quietos mientras se prueba (el perseguidor lo ve todo desde el norte: se suelta más abajo).
	for g in [gi, gc, gh, per]:
		(g as Combate3D).quieto = true
		(g as Combate3D).position = (g as Combate3D).casa          # la patrulla (±2 u) los saca de su casilla durante la carga: se les devuelve a su sitio
		(g as Combate3D).pj.position = (g as Combate3D).casa
	_ok("2.5 ninguno está ya en el agua al empezar", [gi, gc, gh, per].all(func(g): return not (g as Combate3D).muerto and not Terreno3D.es_agua(Terreno3D.celda_de((g as Combate3D).global_position))))

	# --- Empujados con VIENTO REAL (el Lanzador3D llama a Combate3D.push): los dos de la izquierda al agua honda ---
	var oros0: int = _oros()
	var r1: Dictionary = await _empuje_de_viento(gi)
	volcar("playtest_s2_viento_izq", r1)
	_ok("2.6 el viento sale y el goblin de la izquierda, empujado a la parte honda, se HUNDE (muere ahogado)", bool(r1["lanzado"]) and bool(r1["muerto"]) and bool(r1["hundido"]), str(r1))
	_ok("2.7 su señal `hundido` se emite una vez y la reacción «hundido» llega al HUD", int(r1["senal"]) == 1 and _hud_tiene("hundido"), str(lab.reacciones()))
	_ok("2.8 el goblin hundido por la física (sin ningún retoque) queda en el clip de ahogarse, «drown» (antes `_animar()` lo pisaba con `idle`)", bool(r1["drown"]), str(r1))
	var r2: Dictionary = await _empuje_de_viento(gc)
	_ok("2.9b el del centro también queda en «drown»", bool(r2["drown"]), str(r2))
	volcar("playtest_s2_viento_centro", r2)
	_ok("2.9 el del centro también se hunde", bool(r2["muerto"]) and bool(r2["hundido"]) and int(r2["senal"]) == 1, str(r2))
	_ok("2.10 los ahogados no sueltan botín (ni oro)", _oros() == oros0, "oros %d → %d" % [oros0, _oros()])

	# --- Sobre el hielo no ---
	var z0: float = Terreno3D.centro_de(Vector2i(14, 5), 0.0).z
	var r3: Dictionary = await _empuje_de_viento(gh)
	volcar("playtest_s2_viento_hielo", r3)
	_ok("2.11 el goblin empujado a la franja helada NO se hunde y sigue vivo", bool(r3["lanzado"]) and not bool(r3["muerto"]) and not bool(r3["hundido"]) and int(r3["senal"]) == 0 and is_instance_valid(gh) and not gh.muerto, str(r3))
	_ok("2.12 y el empuje lo movió de verdad hacia el norte", float(r3["z"]) < z0 - 0.5, "z %.1f → %.1f" % [z0, float(r3["z"])])

	# --- El perseguidor: ve al jugador desde la otra orilla; no se mete solo en el agua (rodea por la orilla o cruza por el hielo) ---
	per.quieto = false
	gh.quieto = true
	# Control: desde la orilla sur NO lo ve (la charca mide 3 casillas y su radio de detección es de 2,5: RADIO_DETECCION 5,75 u). Hallazgo, no fallo.
	colocar_jugador(Vector2i(12, 5))
	jugador.set("vida", 100.0)
	await avanzar_s(3.0)
	var ve_solo: bool = per.estado == "persigue"
	_aviso("2.13a el goblin de la otra orilla ve solo al jugador a %.1f u" % (per.global_position.distance_to(jugador.global_position)), "sí" if ve_solo else "no (radio de detección %.2f u)" % Combate3D.RADIO_DETECCION)
	# Un golpe suyo lo hace mirar a quien viene (`on_spell_hit`: objetivo = jugador si lo ve a RADIO_SOLTAR, 10 u): se le dispara agua desde la orilla.
	_ok("2.13b un disparo de agua cruza la charca hasta el goblin del otro lado", lanzar_a_celda("agua", ["flecha"], Vector2i(12, 1), Vector2i(12, 5)))
	await avanzar_s(2.5)
	if per.mojado <= 0.0:
		_aviso("2.13c el agua no llegó al goblin del otro lado (a 9,2 u)", "se le fija como objetivo a mano: "+"solo se prueba el rodeo")
		per.objetivo = jugador
	var celdas: Dictionary = {}
	var st: Dictionary = {"dentro": false, "cerca": INF, "persiguio": false}      # un Dictionary: una lambda copia los bool/float sueltos y no los devolvería
	await avanzar_vigilando(25.0, 0.1, func(_t: float) -> void:
		if not is_instance_valid(per):
			return
		jugador.set("vida", 100.0)
		var c: Vector2i = Terreno3D.celda_de(per.global_position)
		celdas[c] = true
		st["dentro"] = st["dentro"] or per.muerto or per.se_hundio or Terreno3D.es_agua(c)
		st["persiguio"] = st["persiguio"] or per.estado == "persigue"
		st["cerca"] = minf(st["cerca"], per.global_position.distance_to(jugador.global_position))
	)
	var dentro: bool = st["dentro"]
	var persiguio: bool = st["persiguio"]
	var cerca: float = st["cerca"]
	var por_hielo: bool = false
	for c in celdas:
		if Terreno3D.helada(c):
			por_hielo = true
	volcar("playtest_s2_perseguidor", {"dentro": dentro, "persiguio": persiguio, "cerca": cerca, "por_hielo": por_hielo, "casillas": celdas.size()})
	_ok("2.13 el goblin del otro lado te persigue", persiguio)
	_ok("2.14 y no se mete solo en el agua honda en 25 s", not dentro and is_instance_valid(per) and not per.se_hundio)
	_ok("2.15 da el rodeo y llega junto al jugador (a menos de 4 u)", cerca < 4.0, "%.1f u" % cerca)
	_aviso("2.16 el perseguidor ha cruzado por el hielo", "sí" if por_hielo else "no (rodeó por la orilla)")
	if is_instance_valid(per):
		per.quieto = true


# ---------------------------------------------------------------------------------------------------------------------
#  3 · escudo (A5)
# ---------------------------------------------------------------------------------------------------------------------

## Un disparo de `elemento` desde la casilla `desde` apuntado a DONDE ESTÁ de verdad el goblin (la maqueta no lo deja justo en el centro de su casilla).
func _apuntado(elemento: String, g: Combate3D, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	var v: Vector3 = g.global_position - jugador.global_position
	v.y = 0.0
	return lanzar(elemento, ["flecha"], v)

func _sala_3() -> void:
	var q: Dictionary = lab.sala(3)
	var g: Combate3D = q["goblin"]
	var e: Escudo3D = q["escudo"]
	_ok("3.1 el goblin existe y lleva escudo activo", g != null and e != null and e.esta_activo())
	if g == null or e == null:
		return
	_ok("3.2 mira hacia la entrada (sur, +Z) y está quieto", g.mirada.z > 0.9 and g.quieto)
	var entrada: Vector2i = Vector2i(20, 6)
	var goblin: Vector2i = LabPlaytestEoW3D.SALA3_GOBLIN
	# La vida se sube para que ningún golpe de la prueba lo mate: lo que se mide es la vida que PIERDE (o no) y el escudo.
	g.vida_max = 100000.0
	g.health = 100000.0
	jugador.set("vida", 100.0)
	var n_bloq0: int = e.bloqueos
	var v0: float = g.health
	# --- De frente: tierra desde la entrada ---
	_ok("3.3 el disparo de frente (tierra) sale", _apuntado("tierra", g, Vector2i(20, 5)))
	await avanzar_s(3.5)
	_ok("3.4 el escudo lo BLOQUEA: el goblin no pierde vida y la reacción «bloqueado» llega al HUD", g.health == v0 and e.bloqueos == n_bloq0 + 1 and _hud_tiene("bloqueado"),
		"vida %.1f → %.1f · bloqueos %d · %s" % [v0, g.health, e.bloqueos, str(lab.reacciones())])
	# --- Por la espalda y por el lado ---
	jugador.set("vida", 100.0)
	_ok("3.5 el disparo por la espalda (desde el norte) sale", _apuntado("tierra", g, Vector2i(20, 1)))
	await avanzar_s(3.5)
	_ok("3.6 por la ESPALDA pasa: el goblin pierde vida y el escudo no bloquea", g.health < v0 and e.bloqueos == n_bloq0 + 1, "vida %.1f → %.1f · bloqueos %d" % [v0, g.health, e.bloqueos])
	var v1: float = g.health
	jugador.set("vida", 100.0)
	# El goblin no está justo en el centro de su casilla (la maqueta desplaza las piezas hasta ±0,35 u): se apunta a donde está de verdad.
	colocar_jugador(Vector2i(18, 3))
	var al_goblin: Vector3 = g.global_position - jugador.global_position
	al_goblin.y = 0.0
	_ok("3.7 el disparo de lado (desde el oeste, a 2 casillas: la tierra no llega más lejos) sale", lanzar("tierra", ["flecha"], al_goblin))
	await avanzar_s(3.5)
	_ok("3.8 de LADO pasa también", g.health < v1 and e.bloqueos == n_bloq0 + 1, "vida %.1f → %.1f · bloqueos %d" % [v1, g.health, e.bloqueos])
	# --- Fuego de frente: arde el escudo, se consume ---
	jugador.set("vida", 100.0)
	g.health = g.vida_max
	_ok("3.9 el fuego de frente sale", _apuntado("fuego", g, entrada))
	var caidas: Array = []                         # [t, vida perdida acumulada, el escudo ya había prendido] cada vez que cambia
	var ultima: Array = [g.health]
	await avanzar_vigilando(3.5, 0.05, func(t: float) -> void:
		if g.health != ultima[0]:
			caidas.append([t, snappedf(g.vida_max - g.health, 0.1), e.estado, g.esta_ardiendo()])
			ultima[0] = g.health
	)
	volcar("playtest_s3_fuego_vida", {"caidas": caidas})
	_ok("3.10 el escudo ARDE («prendido» del escudo en el HUD) y el goblin no se prende", e.estado == "ardiendo" and _hud_tiene_de("prendido", "escudo") and g.quemando <= 0.0 and not g.esta_ardiendo(),
		"escudo %s · quemando %.1f · %s" % [e.estado, g.quemando, str(lab.reacciones())])
	var perdida: float = g.vida_max - g.health
	_ok("3.10b mientras el escudo arde, el goblin que lo lleva NO pierde vida (ni por el campo de llamas del impacto que paró el escudo)", perdida == 0.0, "%.0f de vida en %.1f s · caídas %s" % [perdida, Escudo3D.T_CONSUMO, str(caidas)])
	await avanzar_s(maxf(Escudo3D.T_CONSUMO, 0.0))
	_ok("3.11 a los T_CONSUMO s se consume («consumido» del escudo en el HUD, malla quemada)", e.estado == "quemado" and _hud_tiene_de("consumido", "escudo") and not e.esta_activo(), "escudo %s · %s" % [e.estado, str(lab.reacciones())])
	jugador.set("vida", 100.0)
	var v2: float = g.health
	_ok("3.12 después el disparo de frente sale", _apuntado("tierra", g, Vector2i(20, 5)))
	await avanzar_s(3.5)
	_ok("3.13 y esta vez SÍ llega al goblin", g.health < v2,"vida %.1f → %.1f" % [v2, g.health])

	# --- Lo que pasa con la IA de verdad (SALA3_QUIETO = false): se mide y se enseña ---
	g.quieto = false
	g.estado = "patrulla"
	colocar_jugador(Vector2i(20, 1))
	jugador.set("vida", 100.0)
	await avanzar_s(3.0)
	var d: Vector3 = jugador.global_position - g.global_position
	d.y = 0.0
	_aviso("3.14 con la IA de verdad el goblin se gira hacia un jugador que está a su espalda", "mirada·dirección al jugador = %.2f (1 = de cara) · estado %s" % [g.mirada.normalized().dot(d.normalized()), g.estado])
	g.quieto = true

# ---------------------------------------------------------------------------------------------------------------------
#  4 · caminos (D2)
# ---------------------------------------------------------------------------------------------------------------------

## Devuelve al goblin a su casilla de partida, tranquilo (como recién nacido), para repetir una medida.
func _reponer_goblin(g: Combate3D) -> void:
	g.position = g.casa
	g.pj.position = g.casa
	g.objetivo = null
	g.estado = "patrulla"
	g.vista_perdida = 0.0
	g.health = g.vida_max
	g.quieto = false


## Deja al jugador en `c`, suelta al goblin y espera hasta `max_s` s (o a que llegue a menos de `llega` u). Devuelve lo que ha hecho: casillas pisadas, mínima distancia,
## cuándo llegó (-1 = no), si llegó a estar en el agua / hundido, la casilla más cercana a la meta que tocó y el estado final.
func _recorrido(g: Combate3D, meta: Vector2i, max_s: float, llega: float = 2.6) -> Dictionary:
	colocar_jugador(meta)
	var res: Dictionary = {"celdas": {}, "minima": INF, "llego": -1.0, "agua": false, "niveles": {}, "estado": "", "golpes": 0}
	var t: float = 0.0
	while t < max_s:
		if float(jugador.get("vida")) < 99.9:
			res["golpes"] = int(res["golpes"]) + 1
		jugador.set("vida", 100.0)
		await avanzar_s(0.2)
		t += 0.2
		if not is_instance_valid(g) or g.muerto:
			break
		var c: Vector2i = Terreno3D.celda_de(g.global_position)
		res["celdas"][c] = true
		res["niveles"][Terreno3D.altura_en(c)] = true
		res["agua"] = bool(res["agua"]) or g.se_hundio or Terreno3D.es_agua(c)
		var d: float = Vector2(g.global_position.x - jugador.global_position.x, g.global_position.z - jugador.global_position.z).length()
		res["minima"] = minf(float(res["minima"]), d)
		if d < llega and float(res["llego"]) < 0.0:
			res["llego"] = t
			break
	res["estado"] = g.estado if is_instance_valid(g) else "?"
	return res


func _sala_4() -> void:
	var q: Dictionary = lab.sala(4)
	var g: Combate3D = q["goblin"]
	_ok("4.1 hay goblin (letra W del mapa) y las 2 casillas de terraza (una de 1 nivel, una de 2)", g != null and (q["terrazas"] as Array).size() == 2)
	if g == null:
		return
	var t1c: Vector2i = Vector2i(26, 4)             # terraza de 1 nivel (hueco de la pared)
	var t2c: Vector2i = Vector2i(30, 4)             # terraza de 2 niveles
	var hielo_c: Vector2i = Vector2i(26, 5)         # la casilla del río bajo la terraza de 1 nivel
	_ok("4.2 las terrazas tienen su altura: (26,4) 1 nivel, (30,4) 2 niveles", Terreno3D.altura_en(t1c) == 1 and Terreno3D.altura_en(t2c) == 2)
	var pared: bool = true
	var rio: bool = true
	for x in [25, 27, 28, 29, 31]:
		pared = pared and Terreno3D.bloqueada(Vector2i(x, 4))
	for x in range(25, 32):
		rio = rio and Terreno3D.es_agua(Vector2i(x, 5)) and not Terreno3D.helada(Vector2i(x, 5))
	_ok("4.3 la pared (y=4, salvo las dos terrazas) bloquea y el río (25..31, 5) es agua sin helar", pared and rio, "pared %s río %s" % [str(pared), str(rio)])
	var entrada: Vector2i = LabPlaytestEoW3D.SALAS[3]["entrada"]
	var cg: Vector2i = Terreno3D.celda_de(g.casa)
	colocar_jugador(entrada)
	await avanzar(2)
	var r0: Array[Vector2i] = Caminos3D.camino(cg, entrada)
	_ok("4.4 la recta del goblin al jugador no es andable ni se ve (pared y río de por medio)", not Caminos3D.recta_andable(g.casa, jugador.global_position) and not Terreno3D.linea_libre(g.casa, jugador.global_position))
	_ok("4.5 con el río SIN helar no hay ruta del goblin a la orilla sur (ni por el resto del mapa: la sala está cerrada por el oeste)", r0.is_empty(), str(r0))
	# --- El goblin sin ruta posible: con olfato se pega a la pared y NO cruza ---
	var sin: Dictionary = await _recorrido(g, entrada, 12.0)
	_ok("4.6 sin helar, el goblin (enterado por el olfato) no cruza el río ni se hunde y no llega", float(sin["llego"]) < 0.0 and not bool(sin["agua"]) and not g.se_hundio and g.global_position.z < 5.0 * Terreno3D.casilla, str(sin["celdas"].keys()))
	# --- El juego tal cual (sin olfato): detrás de la pared, a 4,6 u, no se entera de nada ---
	_reponer_goblin(g)
	lab.olfato_s4 = false
	colocar_jugador(Vector2i(28, 5))
	await avanzar_s(8.0)
	var dist_pared: float = Vector2(g.global_position.x - jugador.global_position.x, g.global_position.z - jugador.global_position.z).length()
	var ignora: bool = g.objetivo == null and g.estado == "patrulla"
	lab.olfato_s4 = true
	_aviso("4.7 sin olfato (el juego tal cual) el goblin que está a %.1f u tras la pared (su radio de visión es %.2f u)" % [dist_pared, Combate3D.RADIO_DETECCION], "no se entera (patrulla)" if ignora else "reacciona (estado %s)" % g.estado)
	# --- Hielo: el disparo de verdad ---
	_reponer_goblin(g)
	colocar_jugador(Vector2i(hielo_c.x, 7))               # fuera del agua unos fotogramas (el jugador que nada no lanza)
	await avanzar_s(1.0)
	var salio: bool = lanzar_a_celda("hielo", ["flecha"], hielo_c, Vector2i(hielo_c.x, 7))
	await avanzar_s(2.5)
	var real: bool = Terreno3D.helada(hielo_c)
	var cuantas: int = 0
	for x in range(25, 32):
		if Terreno3D.helada(Vector2i(x, 5)):
			cuantas += 1
	_ok("4.8 el disparo de HIELO al río sale", salio)
	_aviso("4.9 el hielo de verdad hiela la casilla apuntada %s" % str(hielo_c), "%s; casillas heladas en el río: %d" % ["sí" if real else "NO (se hiela a mano con poner_helada)", cuantas])
	if not real:
		Terreno3D.poner_helada(hielo_c, true)
	colocar_jugador(entrada)
	var rh: Array[Vector2i] = Caminos3D.camino(cg, entrada)
	var recto: int = absi(cg.y - entrada.y) + 1
	_ok("4.10 con UNA casilla del río helada hay ruta, que pasa por el hielo", not rh.is_empty() and rh.has(hielo_c), "%d casillas" % rh.size())
	_ok("4.11 la ruta rodea la pared: más larga que la recta y pasa por la terraza de 1 nivel, nunca por la de 2", rh.size() > recto + 3 and rh.has(t1c) and not rh.has(t2c), "%d casillas frente a %d en recta: %s" % [rh.size(), recto, str(rh)])
	_ok("4.12 la terraza de 1 nivel se sube y la de 2 no (desde el suelo)", not Caminos3D.camino(cg, t1c).is_empty() and Caminos3D.camino(cg, t2c).is_empty())
	# --- La tecla X dibuja esa ruta ---
	_pulsar(LabPlaytestEoW3D.TECLA_RUTAS)
	await avanzar(3)
	var marcas: int = lab.marcas_de_ruta()
	_ok("4.13 la tecla X dibuja la ruta del goblin (al menos sus casillas)", lab.rutas_visibles() and marcas >= rh.size(), "%d marcas, ruta de %d" % [marcas, rh.size()])
	_pulsar(LabPlaytestEoW3D.TECLA_RUTAS)
	await avanzar(2)
	# --- El goblin de verdad, siguiendo la ruta: terraza, hielo y llega ---
	Terreno3D.poner_helada(hielo_c, true)             # (el hielo de verdad caduca; así la medida no depende de cuánto dure)
	_reponer_goblin(g)
	var ida: Dictionary = await _recorrido(g, entrada, 60.0)
	volcar("playtest_s4_ida", {"llego": ida["llego"], "minima": ida["minima"], "casillas": (ida["celdas"] as Dictionary).size(), "agua": ida["agua"]})
	_ok("4.14 con el río helado el goblin RODEA la pared, sube la terraza (nivel 1), cruza por el hielo y llega al jugador", float(ida["llego"]) > 0.0 and (ida["celdas"] as Dictionary).has(t1c) and (ida["celdas"] as Dictionary).has(hielo_c) and (ida["niveles"] as Dictionary).has(1),
		"llegó a los %.1f s; %d casillas; mínima %.1f u; niveles %s" % [float(ida["llego"]), (ida["celdas"] as Dictionary).size(), float(ida["minima"]), str((ida["niveles"] as Dictionary).keys())])
	_ok("4.15 y no se hundió ni pisó agua sin helar", not bool(ida["agua"]) and not g.se_hundio)
	# --- Terrazas con el jugador encima ---
	_reponer_goblin(g)
	var t1: Dictionary = await _recorrido(g, t1c, 15.0, 2.0)
	_ok("4.16 con el jugador en la terraza de 1 nivel el goblin llega hasta él", float(t1["llego"]) > 0.0, "llegó a los %.1f s; mínima %.1f u; niveles %s" % [float(t1["llego"]), float(t1["minima"]), str((t1["niveles"] as Dictionary).keys())])
	_reponer_goblin(g)
	var t2: Dictionary = await _recorrido(g, t2c, 12.0, 0.1)
	_ok("4.17 con el jugador en la terraza de 2 niveles el goblin NO la pisa (nunca está en el nivel 2)", not (t2["niveles"] as Dictionary).has(2), "mínima %.1f u; niveles %s" % [float(t2["minima"]), str((t2["niveles"] as Dictionary).keys())])
	_aviso("4.17b el goblin al pie de la terraza de 2 niveles llega a %.1f u del jugador de arriba" % float(t2["minima"]), "le pega: %s (la distancia de ataque es en el plano XZ)" % ("SÍ" if int(t2["golpes"]) > 0 else "no"))
	# --- Tierra: un bloque de 1 nivel NO es muro; uno de 2 sí ---
	_reponer_goblin(g)
	colocar_jugador(entrada)
	Terreno3D.poner_helada(hielo_c, true)
	await avanzar(2)
	var muro: Vector2i = Vector2i(27, 6)             # entre el hielo y el jugador: por aquí baja la ruta (26,5) → (26,6) → (27,6) → (28,6)
	var antes: Array[Vector2i] = Caminos3D.camino(cg, entrada)
	_ok("4.18 con el hielo en (26,5) la ruta pasa por (27,6)", antes.has(muro), str(antes))
	var l1: bool = lanzador.construir_tierra(muro)
	var con1: Array[Vector2i] = Caminos3D.camino(cg, entrada)
	_ok("4.19 un bloque de tierra de 1 nivel (el hechizo normal) NO cambia la ruta: se sube y se baja", l1 and Terreno3D.altura_en(muro) == 1 and con1 == antes, str(con1))
	var mas: bool = lanzador.construir_tierra(muro)
	_aviso("4.20 un segundo hechizo de tierra encima (MAX_TIERRA_APILADA = %d)" % Lanzador3D.MAX_TIERRA_APILADA, "apila: %s" % str(mas))
	var l2: bool = lanzador.construir_tierra(muro, true, {"apilar": 2, "v2": true})
	var con2: Array[Vector2i] = Caminos3D.camino(cg, entrada)
	_ok("4.21 con la tierra a 2 niveles (como la materia V2) la ruta CAMBIA sola (sin avisar a nadie) y da un rodeo más largo", l2 and Terreno3D.altura_en(muro) == 2 and not con2.is_empty() and not con2.has(muro) and con2 != antes, "%d casillas: %s" % [con2.size(), str(con2)])
	var rodeo: Dictionary = await _recorrido(g, entrada, 60.0)
	_ok("4.22 y el goblin de verdad rodea el muro de tierra (nunca pisa su casilla) y llega", float(rodeo["llego"]) > 0.0 and not (rodeo["celdas"] as Dictionary).has(muro) and con2.size() > antes.size(), "llegó a los %.1f s; casillas %s" % [float(rodeo["llego"]), str((rodeo["celdas"] as Dictionary).keys())])
	lab.olfato_s4 = true



# ---------------------------------------------------------------------------------------------------------------------
#  5 · suelo y condiciones (B1 + C2)
# ---------------------------------------------------------------------------------------------------------------------

## Pisa la placa de la casilla `placa` (el jugador se coloca encima, espera a la lectura de presencia y se va a la entrada para que se rearme).
func _pisar(placa: Vector2i) -> void:
	colocar_jugador(placa)
	await avanzar_s(0.5)
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(0.5)


func _estado(c: Vector2i, e: String) -> bool:
	return Terreno3D.estados.tiene(c, e)


## El impacto de un hechizo de `elemento` en el SUELO de la casilla `c`, como lo hacen los hechizos de área (Lanzador3D.marcar_celda → maqueta._al_impactar, una vez por
## casilla). La flecha (lanzar_a_celda) vuela recta y en la prueba sin ventana no deja nada en el suelo —medido con agua y fuego—; el hielo sí, pero solo en la casilla de al lado.
func _disparo_a(elemento: String, c: Vector2i) -> bool:
	lanzador.marcar_celda(elemento, c)
	await avanzar_s(0.4)
	return true


func _abierta(papel: String) -> bool:
	return bool(lab.sala(5)[papel].get("abierta"))


func _sala_5() -> void:
	var q: Dictionary = lab.sala(5)
	var z: Puzle3D = lab.puzle_nodo()
	var br: Reactivo3D = q["brasero"]
	_ok("5.1 están las 4 puertas, las 4 placas, los 4 cofres y el brasero (todo del mapa)", ["puerta_a", "puerta_b", "puerta_c", "puerta_d", "placa_a", "placa_b", "placa_c", "placa_d"].all(func(p): return q[p] != null)
		and ["s5_ca", "s5_cb", "s5_cc", "s5_cd"].all(func(id): return z.nodo(id) != null) and br != null)
	if br == null:
		return
	_ok("5.2 el brasero arranca ENCENDIDO (lo enciende el lab) y las cuatro puertas cerradas", _arde(br) and not _abierta("puerta_a") and not _abierta("puerta_b") and not _abierta("puerta_c") and not _abierta("puerta_d"))
	_ok("5.3 ninguna de las casillas marcadas tiene estado de suelo al empezar", LabPlaytestEoW3D.SALA5_MOJAR.all(func(c): return not _estado(c, "mojada")) and not _estado(Vector2i(2, 14), "helada") and not _estado(Vector2i(6, 14), "quemada"))
	colocar_jugador(Vector2i(4, 14))
	jugador.set("vida", 100.0)
	await avanzar_s(0.5)
	# --- FUEGO (antes que el agua: un agua a menos de 2 casillas de la hierba la deja «mojada» 8 s de reloj de pared y no prende) ---
	var f: Vector2i = LabPlaytestEoW3D.SALA5_FUEGO
	var salio_f: bool = await _disparo_a("fuego", f)
	var t_q: float = 0.0
	while not _estado(f, "quemada") and t_q < 12.0:
		await avanzar_s(0.5)
		t_q += 0.5
	_ok("5.3e el fuego sobre la HIERBA de (6,14) la deja «quemada» (hierba v del mapa; el círculo quemado crece mientras arde)", salio_f and _estado(f, "quemada"), "a los %.1f s" % t_q)
	# En suelo desnudo el fuego no deja nada (solo seca el charco / funde el hielo): se mide con la casilla de al lado.
	var desnudo: Vector2i = Vector2i(7, 14)
	await _disparo_a("fuego", desnudo)
	await avanzar_s(3.0)
	_aviso("5.3f el fuego sobre suelo DESNUDO %s deja la casilla «quemada»" % str(desnudo), "sí" if _estado(desnudo, "quemada") else "NO (solo la hierba se quema)")
	Terreno3D.estados.poner(f, "quemada", false)
	# --- HALLAZGO: sin el puente del lab, el agua de verdad solo moja la imagen de la maqueta, no el dato de Terreno3D.estados que leen las reglas ---
	lab.puente_estados_s5 = false
	var suelta: Vector2i = Vector2i(1, 13)
	var salio0: bool = await _disparo_a("agua", suelta)
	var img: Image = maqueta.get("_img_estado") as Image
	var en_imagen: bool = img != null and img.get_pixelv(suelta).g >= 0.5
	_ok("5.3b SIN el puente (el juego tal cual) el agua de verdad moja la imagen de la maqueta pero Terreno3D.estados NO dice «mojada»: casilla(x,y).mojada nunca se cumpliría", salio0 and en_imagen and not _estado(suelta, "mojada"), "imagen %s · estados %s" % [str(en_imagen), str(_estado(suelta, "mojada"))])
	lab.puente_estados_s5 = true
	await avanzar(3)
	_ok("5.3c con el puente, esa misma casilla queda «mojada» en Terreno3D.estados", _estado(suelta, "mojada"))
	maqueta.call("_poner_canal", suelta, 1, 0.0)
	await avanzar(3)
	_ok("5.3d y al secarse la imagen, también deja de estarlo", not _estado(suelta, "mojada"))
	# --- PUERTA A: tres mojadas Y brasero apagado ---
	await _pisar(Vector2i(1, 11))
	_ok("5.4 placa A con 0 casillas mojadas y el brasero encendido: NO abre, la regla se ignora y el HUD dice por qué", not _abierta("puerta_a") and int(z.puzle("s5_abre_a")["ignoradas"]) == 1 and lab.texto_hud().contains("Puerta A NO abre"), lab.texto_hud())
	var mojadas: Array = LabPlaytestEoW3D.SALA5_MOJAR
	for c in mojadas:
		var salio: bool = await _disparo_a("agua", c as Vector2i)
		_ok("5.5 agua de verdad a %s: el disparo sale y deja la casilla «mojada» (Terreno3D.estados, con el puente del lab)" % str(c), salio and _estado(c as Vector2i, "mojada"))
	await _pisar(Vector2i(1, 11))
	_ok("5.6 con las TRES mojadas pero el brasero ENCENDIDO: NO abre (el NO de la regla)", not _abierta("puerta_a") and int(z.puzle("s5_abre_a")["ignoradas"]) == 2 and lab.texto_hud().contains("brasero ENCENDIDO"))
	# Apagar el brasero con agua de verdad (desde la entrada, a su lado) y ver cómo queda.
	var dos: Vector2i = Vector2i(2, 12)
	var salio_br: bool = lanzar_a_celda("agua", ["flecha"], Vector2i(4, 15), Vector2i(4, 13))
	await avanzar_s(2.0)
	_aviso("5.7 agua de verdad al brasero (4,15) desde (4,13): sale %s y queda %s" % [str(salio_br), "apagado" if not _arde(br) else "ENCENDIDO"])
	if _arde(br):
		br.apagar_llama()
	_ok("5.7b el brasero está apagado", not _arde(br))
	for c in mojadas:
		_ok("5.7c %s sigue mojada tras apagar el brasero (el agua del brasero no la seca)" % str(c), _estado(c as Vector2i, "mojada"))
	await _pisar(Vector2i(1, 11))
	_ok("5.8 tres mojadas Y brasero apagado: la puerta A ABRE", _abierta("puerta_a") and int(z.puzle("s5_abre_a")["veces"]) == 1 and lab.texto_hud().contains("Puerta A ABRE"), lab.texto_hud())
	# Dos mojadas no bastan (cumple_expr directo, con la misma regla del mapa).
	var expr_a: Array = z.puzle("s5_abre_a")["si_expr"]
	Terreno3D.estados.poner(mojadas[1] as Vector2i, "mojada", false)
	_ok("5.9 con DOS casillas mojadas la expresión de la puerta A no se cumple", not z.cumple_expr(expr_a))
	Terreno3D.estados.poner(mojadas[1] as Vector2i, "mojada", true)
	_ok("5.9b con las tres vuelve a cumplirse y con el brasero encendido otra vez no", z.cumple_expr(expr_a) and (func() -> bool:
		br.encender_llama()
		var r: bool = z.cumple_expr(expr_a)
		br.apagar_llama()
		return not r).call())
	# Dos aguas hielan: la segunda deja la casilla helada y YA NO mojada.
	await _disparo_a("agua", dos)
	_ok("5.10 un segundo agua sobre una casilla mojada la HIELA y deja de estar mojada (B1: dos aguas hielan)", _estado(dos, "helada") and not _estado(dos, "mojada") and not z.cumple_expr(expr_a), "helada %s mojada %s" % [str(_estado(dos, "helada")), str(_estado(dos, "mojada"))])
	# --- PUERTA B: O y NO ---
	var expr_b: Array = z.puzle("s5_abre_b")["si_expr"]
	var h: Vector2i = LabPlaytestEoW3D.SALA5_HIELO
	var s: Vector2i = LabPlaytestEoW3D.SALA5_SECA
	for c in [h, f, s]:
		Terreno3D.estados.poner(c as Vector2i, "helada", false)
		Terreno3D.estados.poner(c as Vector2i, "quemada", false)
		Terreno3D.estados.poner(c as Vector2i, "mojada", false)
	_ok("5.11 B: sin hielo ni fuego no se cumple", not z.cumple_expr(expr_b))
	Terreno3D.estados.poner(h, "helada", true)
	_ok("5.12 B: solo HIELO (con el centro seco) se cumple", z.cumple_expr(expr_b))
	Terreno3D.estados.poner(h, "helada", false)
	Terreno3D.estados.poner(f, "quemada", true)
	_ok("5.13 B: solo FUEGO (con el centro seco) se cumple (la O)", z.cumple_expr(expr_b))
	Terreno3D.estados.poner(s, "mojada", true)
	_ok("5.14 B: fuego pero el centro MOJADO: NO se cumple (el NO)", not z.cumple_expr(expr_b))
	Terreno3D.estados.poner(h, "helada", true)
	_ok("5.15 B: hielo y fuego a la vez pero el centro mojado: tampoco", not z.cumple_expr(expr_b))
	Terreno3D.estados.poner(s, "mojada", false)
	Terreno3D.estados.poner(f, "quemada", false)
	Terreno3D.estados.poner(h, "helada", false)
	# La placa B de verdad con el hielo de verdad.
	await _pisar(Vector2i(3, 11))
	_ok("5.16 placa B sin nada: NO abre y el HUD lo dice", not _abierta("puerta_b") and int(z.puzle("s5_abre_b")["ignoradas"]) == 1 and lab.texto_hud().contains("Puerta B NO abre"))
	var salio_h: bool = await _disparo_a("hielo", h)
	_ok("5.17 el hielo de verdad sobre (2,14) deja la casilla «helada» (Terreno3D.estados, con el puente del lab)", salio_h and _estado(h, "helada"))
	await _pisar(Vector2i(3, 11))
	_ok("5.19 placa B con el hielo en su sitio y el centro seco: la puerta B ABRE", _abierta("puerta_b") and int(z.puzle("s5_abre_b")["veces"]) == 1)
	# --- PUERTAS C y D: la MISMA regla con plantilla ---
	var rc: Dictionary = z.puzle("s5_abre_c")
	var rd: Dictionary = z.puzle("s5_abre_d")
	_ok("5.20 C y D se escribieron con la MISMA regla `casilla($x,$y).mojada` y la plantilla puso la casilla de CADA placa", rc["si_expr"][0][0]["celda"] == Vector2i(5, 11) and rd["si_expr"][0][0]["celda"] == Vector2i(7, 11))
	await _pisar(Vector2i(5, 11))
	_ok("5.21 placa C con su casilla seca: NO abre", not _abierta("puerta_c") and int(rc["ignoradas"]) == 1)
	var salio_c: bool = await _disparo_a("agua", Vector2i(5, 11))
	_ok("5.22 agua de verdad sobre la casilla de la placa C (5,11) la deja mojada", salio_c and _estado(Vector2i(5, 11), "mojada"))
	await _pisar(Vector2i(5, 11))
	_ok("5.23 placa C con SU casilla mojada: la puerta C ABRE", _abierta("puerta_c") and int(rc["veces"]) == 1)
	_ok("5.24 y la puerta D sigue cerrada (cada placa mira SU casilla: la de D está seca)", not _abierta("puerta_d"))
	await _pisar(Vector2i(7, 11))
	_ok("5.25 placa D con su casilla seca: NO abre (la de C mojada no le vale)", not _abierta("puerta_d") and int(rd["ignoradas"]) == 1)
	# --- El HUD de la sala ---
	lab.ir_a_sala(5)
	await avanzar_s(0.5)
	_ok("5.26 el HUD de la sala 5 enseña las cuatro puertas y qué falta", lab.texto_hud().contains("SALA 5") and lab.texto_hud().contains("A (3 mojadas Y brasero apagado)") and lab.texto_hud().contains("B (hielo O fuego"), lab.texto_hud())

# func _sala_6() -> void: …  (C3 + C1 sala cerrada)
# func _sala_7() -> void: …  (final integrado)


# ---------------------------------------------------------------------------------------------------------------------
#  D · el clip de ahogarse
# ---------------------------------------------------------------------------------------------------------------------

func _ahogarse() -> void:
	var g: Combate3D = lab.call("_crear_goblin", Vector2i(12, 12), false)
	_ok("D.1 hay un goblin con su modelo de verdad (GLB cargado)", g != null and g.pj != null and g.pj.lista_clips().size() > 0)
	if g == null:
		return
	_ok("D.2 el modelo trae el clip de ahogarse y el rol «drown» lo encuentra", g.pj.duracion("drown") > 0.0, "dura %.2f s; clips: %s" % [g.pj.duracion("drown"), ", ".join(g.pj.lista_clips())])
	_ok("D.3 el grafo reducido de los enemigos admite «drown»", ArbolAnimPj.ESTADOS_REDUCIDO.has("drown") and g.pj.arbol().motivo_prohibida("idle", "drown") == "")
	g._morir(true)
	await avanzar(3)
	_ok("D.4 un goblin que se hunde PIDE el clip de ahogarse (estado «drown»)", g.pj.estado_anim() == "drown" and g.pj.animacion_actual == "drown", "estado «%s», animacion_actual «%s»" % [g.pj.estado_anim(), g.pj.animacion_actual])
	_ok("D.5 y el árbol reproduce el clip «Drowning» (no la pose de muerte)", g.pj.clip_actual().to_lower().contains("drown"), "clip «%s»" % g.pj.clip_actual())
	await avanzar_s(3.0)
