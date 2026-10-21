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
	# --- Aquí, una línea por sala cuando se rellene: `await _sala_4()` … `await _sala_7()` ---
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

# func _sala_4() -> void: …  (D2 caminos)
# func _sala_5() -> void: …  (B1 + C2 suelo y condiciones)
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
