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
##   · 5  sala 5 · suelo y condiciones (B1+C2): puerta A (3 mojadas Y brasero apagado), B (O y NO con hielo/fuego), C y D (plantilla `$`), dos aguas hielan; el agua/hielo/fuego de verdad escriben mojada/helada/quemada SIN ayuda del lab (el puente de estados se retiró el 21/10).
##   · 6  sala 6 · sala cerrada (C3+C1): entrar la cierra, tres goblins (uno hundido con viento) la abren y aparece el cofre, E lo abre, M guarda, el lab se RECARGA como con R (partida nueva)
##        y F devuelve el cofre abierto y la sala sin cerrarse.
##   · 7  sala 7 · final integrado: vía limpia (escudo: bloqueado/prendido/consumido; arquero con flecha ardiendo; setos; hundido; el cofre aparece) y vía «quemando la hierba» (el cofre NO aparece).
##        Las salas 6 y 7 recargan el lab (`_recargar`), por eso van detrás de las demás y cada una arranca de partida nueva.
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
	# Las salas 6 y 7 cambian de laboratorio a mitad (recargan, como R) y empiezan siempre de partida nueva, así que van detrás de las demás.
	await _recargar()
	await _sala_6()
	await _sala_7()
	await _ahogarse()


# ---------------------------------------------------------------------------------------------------------------------

func _arde(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and bool((n as Object).get("is_lit"))


## Los nombres de los últimos logros que han llegado al lab (respuesta positiva, `Mundo3D.logro`), el más reciente al final.
func _ln() -> Array:
	return lab.logros().map(func(l): return String((l as Dictionary)["nombre"]))


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
	_ok("0.8 hay un hook de preparación por sala", range(1, 8).all(func(n: int) -> bool: return lab.has_method("_preparar_sala_%d" % n)))
	_ok("0.16 el lab declara sus 7 ayudas (SALAn_*) como activas (ya sin puente de estados), el HUD las cuenta y describe las 7 salas", lab.ajustes_activos().size() == 7 and lab.texto_hud().contains("AYUDAS DEL LAB activas: 7 de 7")
		and lab.texto_hud().contains("6 sala cerrada") and lab.texto_hud().contains("7 final integrado"), str(lab.ajustes_activos()))


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
func _tiro_del_arquero(arq: Combate3D, segundos: float, desde: Vector2i = Vector2i(6, 5)) -> Dictionary:
	colocar_jugador(desde)
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
func _empuje_de_viento(g: Combate3D, segundos: float = 3.5, desde: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var c: Vector2i = Terreno3D.celda_de(g.global_position)
	var res: Dictionary = {"muerto": false, "hundido": false, "drown": false, "senal": 0, "x": g.global_position.x, "z": g.global_position.z, "lanzado": false, "anim": ""}
	var cuenta: Array = [0]
	var cb := func(_e: Combate3D) -> void: cuenta[0] += 1
	g.hundido.connect(cb)
	jugador.set("vida", 100.0)
	res["lanzado"] = lanzar_a_celda("viento", ["flecha"], c, desde if desde.x >= 0 else Vector2i(c.x, 7))      # por defecto: la fila 7, 2 casillas al sur de la orilla de la sala 2
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
	# --- Sin ayuda del lab (el puente de estados se retiró el 21/10): el agua de verdad moja la imagen de la maqueta Y el dato de Terreno3D.estados que leen las reglas ---
	var suelta: Vector2i = Vector2i(1, 13)
	var salio0: bool = await _disparo_a("agua", suelta)
	var img: Image = maqueta.get("_img_estado") as Image
	var en_imagen: bool = img != null and img.get_pixelv(suelta).g >= 0.5
	_ok("5.3b el agua de verdad moja la imagen de la maqueta Y Terreno3D.estados dice «mojada» (sin puente: casilla(x,y).mojada se cumple jugando)", salio0 and en_imagen and _estado(suelta, "mojada"), "imagen %s · estados %s" % [str(en_imagen), str(_estado(suelta, "mojada"))])
	_ok("5.3c la imagen y el estado coinciden: ni mojada ni helada de más", not _estado(suelta, "helada") and img.get_pixelv(suelta).b < 0.5)
	await _disparo_a("fuego", suelta)
	_ok("5.3d el fuego de verdad seca esa casilla: se borra de la imagen Y del estado a la vez", not _estado(suelta, "mojada") and img.get_pixelv(suelta).g < 0.5)
	# --- PUERTA A: tres mojadas Y brasero apagado ---
	await _pisar(Vector2i(1, 11))
	_ok("5.4 placa A con 0 casillas mojadas y el brasero encendido: NO abre, la regla se ignora y el HUD dice por qué", not _abierta("puerta_a") and int(z.puzle("s5_abre_a")["ignoradas"]) == 1 and lab.texto_hud().contains("Puerta A NO abre"), lab.texto_hud())
	var mojadas: Array = LabPlaytestEoW3D.SALA5_MOJAR
	for c in mojadas:
		var salio: bool = await _disparo_a("agua", c as Vector2i)
		_ok("5.5 agua de verdad a %s: el disparo sale y deja la casilla «mojada» (Terreno3D.estados, sin ayuda del lab)" % str(c), salio and _estado(c as Vector2i, "mojada"))
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
	var logros_a: int = lab.total_logros()
	for c in mojadas:
		_ok("5.7c %s sigue mojada tras apagar el brasero (el agua del brasero no la seca)" % str(c), _estado(c as Vector2i, "mojada"))
	await _pisar(Vector2i(1, 11))
	_ok("5.8 tres mojadas Y brasero apagado: la puerta A ABRE", _abierta("puerta_a") and int(z.puzle("s5_abre_a")["veces"]) == 1 and lab.texto_hud().contains("Puerta A ABRE"), lab.texto_hud())
	_ok("5.8b respuesta positiva: abrir la puerta A es UN «puzle_resuelto» que llega al lab (y la línea LOGROS del HUD lo dice); el lab tiene la tabla enganchada",
		lab.enganche_logros_ok() and lab.total_logros() == logros_a + 1 and _ln().back() == "puzle_resuelto" and lab.texto_hud().contains("último «puzle_resuelto»"), "%d → %d · %s" % [logros_a, lab.total_logros(), str(_ln())])
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
	_ok("5.17 el hielo de verdad sobre (2,14) deja la casilla «helada» (Terreno3D.estados, sin ayuda del lab)", salio_h and _estado(h, "helada"))
	await _pisar(Vector2i(3, 11))
	_ok("5.19 placa B con el hielo en su sitio y el centro seco: la puerta B ABRE", _abierta("puerta_b") and int(z.puzle("s5_abre_b")["veces"]) == 1)
	_ok("5.19b y la puerta B también da su «puzle_resuelto» (las placas que NO abren no dieron ninguno: 2 en total, A y B)", _ln().count("puzle_resuelto") == 2 and lab.total_logros() == logros_a + 2, str(_ln()))
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


# ---------------------------------------------------------------------------------------------------------------------
#  6 · sala cerrada (C3 + C1)
# ---------------------------------------------------------------------------------------------------------------------

## Tira el laboratorio y carga uno nuevo como haría R en el juego: partida nueva (`Flags.nuevo`), todo el mapa otra vez. No se puede usar `lab.reiniciar()`: recarga la «escena
## actual» del árbol y este escenario cuelga la maqueta a mano (no hay escena actual).
func _recargar() -> void:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
	await avanzar(3)
	Flags.nuevo()
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	await avanzar_s(1.0)


## ¿Está la casilla bloqueada para andar? (las puertas del cerrojo y el cofre visible bloquean la suya.)
func _bloq(c: Vector2i) -> bool:
	return Terreno3D.bloqueada(c)


func _sala_6() -> void:
	var q: Dictionary = lab.sala(6)
	var v: Puzle3D.VigiaPuzle = q["vigia"] as Puzle3D.VigiaPuzle
	var cj: Puzle3D.CerrojoPuzle = q["cerrojo"] as Puzle3D.CerrojoPuzle
	var cf: Puzle3D.CofrePuzle = q["cofre"] as Puzle3D.CofrePuzle
	var gs: Array = q["goblins"]
	_ok("6.1 están el vigía, el cerrojo, el cofre y los tres goblins (todo del mapa)", v != null and cj != null and cf != null and gs.size() == 3 and q["estanque"] != null)
	if v == null or cj == null or cf == null or gs.size() != 3:
		return
	await avanzar_s(1.0)
	_ok("6.2 el vigía ve a los tres goblins de la sala (la sala 6 no usa ningún ajuste del lab)", v.vistos.size() == 3 and not v.completo and v.restantes() == 3, "vistos %d" % v.vistos.size())
	_ok("6.3 las puertas nacen ABIERTAS (casillas (12,8) y (8,12) libres), el hueco del este (16,12) es muro y el cofre está OCULTO",
		not cj.cerrado and not _bloq(Vector2i(12, 8)) and not _bloq(Vector2i(8, 12)) and _bloq(Vector2i(16, 12)) and cf.es_oculto and not _bloq(Vector2i(14, 15)))
	var honda: bool = true
	for x in [13, 14, 15]:
		for y in [9, 10, 11]:
			honda = honda and Terreno3D.se_nada(Vector2i(x, y)) and (Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(Vector2i(x, y)))
	_ok("6.4 el estanque (13–15, 9–11) es agua HONDA de la que se nada", honda)
	# --- Entrar: desde fuera no cierra; pisar la sala, sí ---
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(7, 12))
	await avanzar_s(1.0)
	_ok("6.5 con el jugador FUERA (sala 5) el cerrojo no cierra", not cj.cerrado)
	colocar_jugador(Vector2i(8, 12))
	await avanzar_s(0.6)
	_ok("6.6 pisar la propia puerta (8,12) no es entrar: no se cierra encima", not cj.cerrado)
	colocar_jugador(Vector2i(9, 12))
	await avanzar_s(0.6)
	_ok("6.7 al pisar la sala el cerrojo se CIERRA y bloquea las dos puertas; el HUD lo dice", cj.cerrado and _bloq(Vector2i(12, 8)) and _bloq(Vector2i(8, 12)) and lab.texto_hud().contains("cerrojo: CERRADO"), lab.texto_hud())
	await avanzar_s(3.0)
	var vivos: Array = gs.filter(func(g): return is_instance_valid(g) and not (g as Combate3D).muerto)
	_aviso("6.8 con la IA de verdad, a los 3 s de entrar los goblins que persiguen al jugador son", "%d de 3 (estados: %s)" % [vivos.filter(func(g): return (g as Combate3D).estado == "persigue").size(), str(vivos.map(func(g): return (g as Combate3D).estado))])
	for g in gs:
		(g as Combate3D).quieto = true                 # quietos: lo que se mide es el vigía y el cerrojo, no la pelea
		(g as Combate3D).position = (g as Combate3D).casa
		(g as Combate3D).pj.position = (g as Combate3D).casa
	var derrotas: Array = [0]
	v.todos_derrotados.connect(func() -> void: derrotas[0] += 1)
	var apariciones: Array = [0]
	cf.aparecido.connect(func() -> void: apariciones[0] += 1)
	# --- Derrotar a los tres: dos por daño, el del estanque HUNDIDO con viento ---
	(gs[0] as Combate3D).receive_damage(100000.0)
	await avanzar_s(1.0)
	_ok("6.9 con uno caído nada se abre y el cofre sigue oculto (quedan 2)", v.restantes() == 2 and cj.cerrado and cf.es_oculto and lab.texto_hud().contains("quedan 2 de 3"), lab.texto_hud())
	(gs[2] as Combate3D).receive_damage(100000.0)
	await avanzar_s(1.0)
	_ok("6.10 con dos caídos, tampoco (queda 1)", v.restantes() == 1 and cj.cerrado and cf.es_oculto and derrotas[0] == 0)
	var estanque: Combate3D = q["estanque"]
	var r: Dictionary = await _empuje_de_viento(estanque, 4.0, Vector2i(14, 14))
	volcar("playtest_s6_viento", r)
	_ok("6.11 el viento del sur empuja al goblin del estanque a la parte honda y se HUNDE (señal, sin botín)", bool(r["lanzado"]) and bool(r["muerto"]) and bool(r["hundido"]) and int(r["senal"]) == 1, str(r))
	await avanzar_s(1.5)
	_ok("6.12 el vigía lo cuenta: UNA señal `todos_derrotados` y la flag playtest.s6.limpia puesta", v.completo and derrotas[0] == 1 and Flags.i().tiene(LabPlaytestEoW3D.SALA6_FLAG_LIMPIA))
	_ok("6.13 la regla `s6_abre` abre el cerrojo: las dos puertas libres", not cj.cerrado and not _bloq(Vector2i(12, 8)) and not _bloq(Vector2i(8, 12)) and int(lab.puzle_nodo().puzle("s6_abre")["veces"]) == 1)
	_ok("6.14 el cofre APARECE (una vez) cerrado, visible y bloqueando su casilla", cf.es_cerrado and not cf.es_oculto and apariciones[0] == 1 and cf.modelo.visible and _bloq(Vector2i(14, 15)))
	_ok("6.15 el HUD muestra «hundido», la sala LIMPIA y el cofre cerrado", _hud_tiene("hundido") and lab.texto_hud().contains("vigía: LIMPIA") and lab.texto_hud().contains("cofre: cerrado"), lab.texto_hud())
	_ok("6.15b respuesta positiva: llegaron «sala_limpia», «puerta_abierta» y «cofre_aparece» (UNA vez, en ese orden) y el HUD enseña el último", _ln() == ["sala_limpia", "puerta_abierta", "cofre_aparece"] and lab.texto_hud().contains("último «cofre_aparece»"), str(_ln()))
	# --- Abrir el cofre con la tecla E, como el jugador ---
	await avanzar_s(1.2)                               # que acabe la animación de aparecer
	colocar_jugador(Vector2i(13, 15))
	await avanzar(2)
	_pulsar(KEY_E)
	await avanzar_s(2.5)
	_ok("6.16 E a una casilla del cofre lo abre y pone su flag playtest.s6.cofre", cf.es_abierto and Flags.i().tiene(LabPlaytestEoW3D.SALA6_FLAG_COFRE) and lab.texto_hud().contains("cofre: ABIERTO"), lab.texto_hud())
	_ok("6.16b al abrirse el cofre llega «cofre_abierto» (UNO más: 4 logros en total)", _ln() == ["sala_limpia", "puerta_abierta", "cofre_aparece", "cofre_abierto"] and lab.total_logros() == 4, str(_ln()))
	colocar_jugador(Vector2i(10, 12))
	await avanzar_s(0.8)
	_ok("6.17 la sala ya vencida no se vuelve a cerrar al reentrar", not cj.cerrado and lab.total_logros() == 4)
	# --- Guardar (M), reiniciar el lab (partida nueva) y cargar (F) ---
	_pulsar(LabPlaytestEoW3D.TECLA_GUARDAR)
	await avanzar(3)
	_ok("6.18 M guarda las flags (limpia y cofre) en el archivo del lab", FileAccess.file_exists(LabPlaytestEoW3D.RUTA_GUARDADO) and lab.texto_hud().contains("flags guardadas (2)"), lab.texto_hud())
	await _recargar()
	q = lab.sala(6)
	v = q["vigia"] as Puzle3D.VigiaPuzle
	cj = q["cerrojo"] as Puzle3D.CerrojoPuzle
	cf = q["cofre"] as Puzle3D.CofrePuzle
	_ok("6.19 el lab nuevo es una partida nueva: sin flags, goblins vivos, cofre oculto y puertas abiertas", Flags.i().nombres().is_empty() and v.restantes() == 3 and cf.es_oculto and not cj.cerrado and (q["goblins"] as Array).all(func(g): return not (g as Combate3D).muerto))
	_pulsar(LabPlaytestEoW3D.TECLA_CARGAR)
	await avanzar_s(1.0)
	_ok("6.20 F carga el guardado: el cofre vuelve ABIERTO (visible, sin efecto de aparecer) y las flags están en el HUD", cf.es_abierto and cf.modelo.visible and Flags.i().tiene(LabPlaytestEoW3D.SALA6_FLAG_COFRE) and lab.texto_hud().contains(LabPlaytestEoW3D.SALA6_FLAG_LIMPIA), lab.texto_hud())
	_ok("6.21 y el cerrojo queda vencido: ya no se cerrará", cj.vencido and not cj.cerrado)
	_ok("6.21b cargar el guardado NO da ninguna fanfarria: la sala y el cofre ya estaban resueltos (0 logros en el lab nuevo)", lab.total_logros() == 0, str(_ln()))
	colocar_jugador(Vector2i(9, 12))
	await avanzar_s(1.0)
	var vive: bool = (q["goblins"] as Array).any(func(g): return is_instance_valid(g) and not (g as Combate3D).muerto)
	_ok("6.22 entrar a la sala (con los goblins vivos otra vez) NO la cierra: bloqueos libres", vive and not cj.cerrado and not _bloq(Vector2i(12, 8)) and not _bloq(Vector2i(8, 12)), "goblins vivos: %s" % str(vive))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LabPlaytestEoW3D.RUTA_GUARDADO))
	Flags.nuevo()


# ---------------------------------------------------------------------------------------------------------------------
#  7 · final integrado
# ---------------------------------------------------------------------------------------------------------------------

## Carga un lab nuevo (partida nueva) y devuelve las piezas de la sala 7 en un diccionario. Comprueba el montaje.
func _montar_sala_7(prefijo: String) -> Dictionary:
	await _recargar()
	var q: Dictionary = lab.sala(7)
	var d: Dictionary = {"v": q["vigia"], "cj": q["cerrojo"], "cf": q["cofre"], "esc": q["goblin_escudo"], "e": q["escudo"], "arq": q["arquero"], "est": q["estanque"], "br": q["brasero"]}
	_ok("%s.1 están las piezas del mapa (vigía, cerrojo, cofre, brasero, setos, paja) y los tres goblins (escudo, arquero, estanque)" % prefijo, d.values().all(func(x): return x != null)
		and q["paja"] != null and q["seto1"] != null and q["seto2"] != null and q["seto3"] != null, str(lab.avisos()))
	return d


func _sala_7() -> void:
	await _sala_7_limpia()
	await _sala_7_quemando()


## VÍA LIMPIA: entrar (se cierra), escudo, arquero con fuego, setos, hundir al del estanque → se abre y aparece el cofre → abrirlo.
func _sala_7_limpia() -> void:
	var d: Dictionary = await _montar_sala_7("7L")
	var v: Puzle3D.VigiaPuzle = d["v"]
	var cj: Puzle3D.CerrojoPuzle = d["cj"]
	var cf: Puzle3D.CofrePuzle = d["cf"]
	var esc: Combate3D = d["esc"]
	var e: Escudo3D = d["e"]
	var arq: Combate3D = d["arq"]
	var est: Combate3D = d["est"]
	var br: Reactivo3D = d["br"]
	var z: Puzle3D = lab.puzle_nodo()
	var seen: Dictionary = {}                        # todas las reacciones que han llegado (el HUD solo guarda las 8 últimas)
	(lab.get("_mundo") as Mundo3D).reaccion.connect(func(nombre: String, _p: Vector3, _n: Node) -> void: seen[nombre] = true)
	await avanzar_s(1.0)
	_ok("7L.2 el escudo está activo, el arquero es un arquero, el brasero arde y el arquero no", e.esta_activo() and arq.arquero and not esc.arquero and _arde(br) and not arq.esta_ardiendo())
	_ok("7L.3 el vigía ve a los tres, el cofre está OCULTO y la hierba (17,14) intacta", v.vistos.size() == 3 and cf.es_oculto and not _estado(LabPlaytestEoW3D.SALA7_HIERBA, "quemada") and not cj.cerrado, "vistos %d" % v.vistos.size())
	_ok("7L.4 el hueco (16,12) es muro, el cofre no bloquea aún su casilla y las puertas (20,8) y (24,12) están libres", _bloq(Vector2i(16, 12)) and not _bloq(Vector2i(19, 15)) and not _bloq(Vector2i(20, 8)) and not _bloq(Vector2i(24, 12)))
	var honda: bool = true
	for x in [17, 18, 19]:
		for y in [9, 10, 11]:
			honda = honda and Terreno3D.se_nada(Vector2i(x, y)) and (Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(Vector2i(x, y)))
	_ok("7L.5 el estanque (17–19, 9–11) es agua HONDA de la que se nada", honda)
	# --- Entrar por el norte: se cierra ---
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(20, 7))
	await avanzar_s(1.0)
	_ok("7L.6 con el jugador fuera (sala 3) no se cierra", not cj.cerrado)
	colocar_jugador(Vector2i(20, 9))
	await avanzar_s(0.6)
	_ok("7L.7 al pisar la sala el cerrojo se CIERRA: puertas (20,8) y (24,12) bloqueadas y el HUD lo dice", cj.cerrado and _bloq(Vector2i(20, 8)) and _bloq(Vector2i(24, 12)) and lab.texto_hud().contains("SALA 7") and lab.texto_hud().contains("cerrojo: CERRADO"), lab.texto_hud())
	# --- ESCUDO (con la IA de verdad: ve al jugador y le planta cara) ---
	esc.vida_max = 100000.0
	esc.health = 100000.0
	est.quieto = true
	est.position = est.casa
	est.pj.position = est.casa
	var bloq0: int = e.bloqueos
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(20, 11))
	await avanzar_s(0.5)
	var salio_t: bool = _apuntado("tierra", esc, Vector2i(20, 11))
	await avanzar_s(3.0)
	_aviso("7L.8 con la IA de verdad el goblin del escudo, tras 3,5 s con el jugador a 2 casillas", "estado %s · mira al jugador %.2f (1 = de cara) · bloqueos %d" % [esc.estado, esc.mirada.normalized().dot((jugador.global_position - esc.global_position).normalized()), e.bloqueos - bloq0])
	_ok("7L.9 la tierra de frente sale y el escudo la BLOQUEA (la reacción «bloqueado» llega al HUD)", salio_t and e.bloqueos > bloq0 and _hud_tiene("bloqueado"), "bloqueos %d · %s" % [e.bloqueos - bloq0, str(lab.reacciones())])
	jugador.set("vida", 100.0)
	var salio_f: bool = _apuntado("fuego", esc, Vector2i(20, 11))
	await avanzar_s(Escudo3D.T_CONSUMO + 1.5)
	_ok("7L.10 el fuego de frente prende el escudo («prendido» de tipo escudo en el HUD) y a los T_CONSUMO s se consume («consumido»)", salio_f and _hud_tiene_de("prendido", "escudo") and e.estado == "quemado" and _hud_tiene_de("consumido", "escudo"), "escudo %s · %s" % [e.estado, str(lab.reacciones())])
	var v0: float = esc.health
	jugador.set("vida", 100.0)
	_apuntado("tierra", esc, Vector2i(20, 11))
	await avanzar_s(3.0)
	_ok("7L.11 consumido el escudo, la tierra de frente ya llega al goblin", esc.health < v0, "vida %.1f → %.1f" % [v0, esc.health])
	esc.receive_damage(1.0e7)
	await avanzar_s(1.0)
	_ok("7L.12 el goblin del escudo cae y el vigía cuenta 2 por caer", esc.muerto and v.restantes() == 2 and cj.cerrado and cf.es_oculto)
	# --- ARQUERO junto al brasero encendido: la flecha cruza la llama y llega ardiendo ---
	jugador.set("vida", 100.0)
	var a1: Dictionary = await _tiro_del_arquero(arq, 10.0, Vector2i(22, 9))
	volcar("playtest_s7_arquero", a1)
	_ok("7L.13 el arquero ve al jugador (con su brasero en medio) y dispara; su flecha cruza la llama y sale ARDIENDO", int(a1["flechas"]) >= 1 and int(a1["ardiendo"]) >= 1, str(a1))
	_ok("7L.14 el impacto de esa flecha lleva fuego al jugador (flecha_ardiente_impacta)", int(a1["impactos_ardiendo"]) >= 1, str(a1))
	# --- SETOS secos: fuego a uno y el fuego corre ---
	jugador.set("vida", 100.0)
	var ss: Array = [lab.sala(7)["seto1"], lab.sala(7)["seto2"], lab.sala(7)["seto3"]]
	_ok("7L.15 los tres setos secos están apagados", ss.all(func(s): return is_instance_valid(s) and not _arde(s)))
	lanzar_a_celda("fuego", ["flecha"], Vector2i(23, 14), Vector2i(21, 14))
	await avanzar_s(3.0)
	_ok("7L.16 el fuego a un seto lo prende (reacción «prendido»)", _arde(ss[1]) or not is_instance_valid(ss[1]), "seto2 arde %s" % str(_arde(ss[1])))
	await avanzar_s(8.0)
	var arden: int = ss.filter(func(s): return not is_instance_valid(s) or _arde(s)).size()
	_aviso("7L.17 a los 11 s del fuego, setos secos que han ardido (de 3)", "%d" % arden)
	arq.receive_damage(1.0e7)
	await avanzar_s(1.0)
	_ok("7L.18 el arquero cae: queda UNO (el del estanque) y la sala sigue cerrada", arq.muerto and v.restantes() == 1 and cj.cerrado and cf.es_oculto)
	# --- ESTANQUE: viento desde el sur ---
	var r: Dictionary = await _empuje_de_viento(est, 4.0, Vector2i(18, 14))
	volcar("playtest_s7_viento", r)
	_ok("7L.19 el viento del sur empuja al goblin del estanque y se HUNDE (señal una vez, sin botín, clip de ahogarse)", bool(r["lanzado"]) and bool(r["muerto"]) and bool(r["hundido"]) and int(r["senal"]) == 1 and bool(r["drown"]), str(r))
	await avanzar_s(1.5)
	_ok("7L.20 el vigía da la sala por limpia: flag playtest.s7.limpia, cerrojo abierto (puertas libres)", v.completo and Flags.i().tiene(LabPlaytestEoW3D.SALA7_FLAG_LIMPIA) and not cj.cerrado and not _bloq(Vector2i(20, 8)) and not _bloq(Vector2i(24, 12)) and int(z.puzle("s7_abre")["veces"]) == 1)
	_ok("7L.21 VÍA LIMPIA: la hierba no se quemó, así que el cofre APARECE cerrado y bloquea su casilla", cf.es_cerrado and not cf.es_oculto and cf.modelo.visible and _bloq(Vector2i(19, 15)) and not _estado(LabPlaytestEoW3D.SALA7_HIERBA, "quemada"))
	_ok("7L.22 durante el recorrido llegaron al HUD (Mundo3D.reaccion) bloqueado, prendido y hundido, y el HUD dice «hierba … intacta» y «vigía: LIMPIA»", seen.has("bloqueado") and seen.has("prendido") and seen.has("hundido")
		and lab.texto_hud().contains("intacta") and lab.texto_hud().contains("vigía: LIMPIA"), "%s · %s" % [str(seen.keys()), lab.texto_hud()])
	await avanzar_s(1.2)
	colocar_jugador(Vector2i(19, 14))
	await avanzar(2)
	_pulsar(KEY_E)
	await avanzar_s(2.5)
	_ok("7L.23 E abre el cofre y pone playtest.s7.cofre", cf.es_abierto and Flags.i().tiene(LabPlaytestEoW3D.SALA7_FLAG_COFRE) and lab.texto_hud().contains("cofre: ABIERTO"), lab.texto_hud())
	_ok("7L.24 respuesta positiva de toda la sala: «sala_limpia», «puerta_abierta», «cofre_aparece» y «cofre_abierto», cada uno una vez y en ese orden", _ln() == ["sala_limpia", "puerta_abierta", "cofre_aparece", "cofre_abierto"], str(_ln()))


## VÍA «QUEMANDO LA HIERBA»: el mismo recorrido, pero se prende la hierba (17,14) y el cofre ya no aparece.
func _sala_7_quemando() -> void:
	var d: Dictionary = await _montar_sala_7("7Q")
	var v: Puzle3D.VigiaPuzle = d["v"]
	var cj: Puzle3D.CerrojoPuzle = d["cj"]
	var cf: Puzle3D.CofrePuzle = d["cf"]
	var h: Vector2i = LabPlaytestEoW3D.SALA7_HIERBA
	var z: Puzle3D = lab.puzle_nodo()
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(20, 9))
	await avanzar_s(0.8)
	_ok("7Q.2 entrar cierra la sala", cj.cerrado)
	var todos: Array = [d["esc"], d["arq"], d["est"]]
	for g in todos:
		(g as Combate3D).quieto = true              # quietos: aquí lo que se mide es el fuego sobre la hierba, no la pelea
		(g as Combate3D).position = (g as Combate3D).casa
		(g as Combate3D).pj.position = (g as Combate3D).casa
	# --- Sin ayuda del lab (puente retirado el 21/10): la hierba quemada de verdad llega a Terreno3D.estados y la condición del cofre la ve ---
	jugador.set("vida", 100.0)
	var img: Image = maqueta.get("_img_estado") as Image
	colocar_jugador(Vector2i(19, 14))
	var salio: bool = await _disparo_a("fuego", h)
	var t_q: float = 0.0
	while t_q < 14.0 and not (img != null and img.get_pixelv(h).r >= 0.5):
		await avanzar_s(0.5)
		t_q += 0.5
	await avanzar_s(0.5)
	var en_imagen: bool = img != null and img.get_pixelv(h).r >= 0.5
	_ok("7Q.3 el fuego de verdad deja la hierba quemada en la imagen de la maqueta Y Terreno3D.estados dice «quemada» (sin puente: la condición del cofre la ve)", salio and en_imagen and _estado(h, "quemada"), "imagen %s (a los %.1f s) · estados %s" % [str(en_imagen), t_q, str(_estado(h, "quemada"))])
	await avanzar(3)
	_ok("7Q.5 esa casilla sigue «quemada» en Terreno3D.estados y el HUD lo dice", _estado(h, "quemada") and lab.texto_hud().contains("QUEMADA"), lab.texto_hud())
	# --- Ahora se derrota a los tres: la sala se abre pero el cofre NO aparece ---
	var apariciones: Array = [0]
	cf.aparecido.connect(func() -> void: apariciones[0] += 1)
	(d["esc"] as Combate3D).receive_damage(1.0e7)
	(d["arq"] as Combate3D).receive_damage(1.0e7)
	await avanzar_s(0.8)
	_ok("7Q.6 con 2 caídos la sala sigue cerrada", v.restantes() == 1 and cj.cerrado)
	var r: Dictionary = await _empuje_de_viento(d["est"], 4.0, Vector2i(18, 14))
	_ok("7Q.7 el del estanque se hunde", bool(r["hundido"]) and bool(r["muerto"]), str(r))
	await avanzar_s(2.0)
	_ok("7Q.8 el vigía da la sala por limpia y el cerrojo abre (puertas libres)", v.completo and Flags.i().tiene(LabPlaytestEoW3D.SALA7_FLAG_LIMPIA) and not cj.cerrado and not _bloq(Vector2i(20, 8)))
	_ok("7Q.9 VÍA QUEMANDO: el cofre NO aparece (oculto, invisible, sin bloquear su casilla), ni siquiera pasados unos segundos", cf.es_oculto and not cf.modelo.visible and not _bloq(Vector2i(19, 15)) and apariciones[0] == 0 and not cf.abrir())
	await avanzar_s(3.0)
	_ok("7Q.10 sigue sin aparecer y el HUD avisa de que la hierba está quemada", cf.es_oculto and apariciones[0] == 0 and lab.texto_hud().contains("QUEMADA: el cofre ya no aparecerá") and not Flags.i().tiene(LabPlaytestEoW3D.SALA7_FLAG_COFRE), lab.texto_hud())
	_ok("7Q.9b respuesta positiva de la vía quemando: «sala_limpia» y «puerta_abierta», y NINGÚN «cofre_aparece» (el cofre no existe)", _ln() == ["sala_limpia", "puerta_abierta"], str(_ln()))
	# Control: la misma expresión SIN la hierba quemada sí se cumpliría (es la condición, no un fallo del vigía).
	Terreno3D.estados.poner(h, "quemada", false)
	_ok("7Q.11 (control) si la hierba no estuviera quemada la condición se cumpliría", z.cumple_expr(cf.expr))
	Terreno3D.estados.poner(h, "quemada", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LabPlaytestEoW3D.RUTA_GUARDADO))


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
