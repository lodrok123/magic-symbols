extends "res://herramientas/escenario_base.gd"
## Escenario del LABORATORIO DE PLAYTEST DE EoW (21/10, Juego). Carga laboratorios/LabPlaytestEoW.tscn (la maqueta con el mapa PlaytestEoW, el jugador, el
## Lanzador3D, el agua y las piezas de verdad) y comprueba la BASE del laboratorio y la sala 1; sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_playtest_eow.gd
## (en Windows: tools\prueba_una.cmd escenario_playtest_eow).
## Estructura: una sección por sala (`_sala_N`). Las salas 2–7 están preparadas como secciones vacías: quien rellene una sala escribe su sección aquí y la
## añade a `_escenario`, sin tocar las demás. Lo que se mide y todavía no es contrato sale como AVISO.
##   · 0  base: el lab cuelga de la escena, el enganche de efectos devolvió true, el HUD existe, las teclas llevan a cada sala, guardar/cargar flags.
##   · 1  sala 1 · fuego por contacto (A2): brasero → goblin → seto, cortafuegos mojado, flecha del arquero a través de una llama, reacciones en el HUD.
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
	# --- Aquí, una línea por sala cuando se rellene: `await _sala_2()` … `await _sala_7()` ---
	await _ahogarse()


# ---------------------------------------------------------------------------------------------------------------------

func _arde(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and bool((n as Object).get("is_lit"))


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
		and lab.texto_hud().contains("REACCIONES") and lab.texto_hud().contains("FLAGS") and lab.texto_hud().contains("1–7 sala"), lab.texto_hud())
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
		_pulsar(LabPlaytestEoW3D.TECLAS_SALA[i])
		await avanzar(2)
		_ok("0.9.%d la tecla %d lleva a la entrada de la sala %d" % [i + 1, i + 1, i + 1], celda_jugador() == entrada and lab.sala_actual() == i + 1, "casilla %s sala %d" % [str(celda_jugador()), lab.sala_actual()])
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


func _pulsar(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = true
	Input.parse_input_event(ev)
	var suelta := InputEventKey.new()
	suelta.keycode = tecla
	suelta.physical_keycode = tecla
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
#  Salas 2–7: secciones vacías, para que cada tarea escriba la suya aquí.
# ---------------------------------------------------------------------------------------------------------------------

# func _sala_2() -> void: …  (A3 al agua)
# func _sala_3() -> void: …  (A5 escudo)
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
