extends "res://herramientas/escenario_base.gd"
## Escenario · los puzles de la SEGUNDA TANDA del LABORATORIO DE FUEGO (20/11/2026, Juego): F13 «Dragón que enciende + barrera», F14 «Choque térmico», F15 «Braseros en orden con mural» y F16 «Brasero bajo la gotera»
## (la fila de salas de abajo: (0,3), (1,3), (2,3) y (3,3)). Carga laboratorios/LabPuzlesFuego3D.tscn y los juega por código con las piezas de verdad. Dos pasadas, como los demás escenarios de laboratorio:
##   · `natural`  (por defecto): la vía de la jugadora (hechizos de fuego y de agua).
##   · `botones`  (escenario_puzles_fuego_tanda2_botones.gd): el botón `!` y la placa `@`, que separan «falla el hechizo» de «falla el disparador».
## Lo que se abre, se quema o se llena no se deshace, así que cada vía que necesita la sala intacta RECARGA la escena (`_recargar`: libera la maqueta y vuelve a cargarla).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_tanda2.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_tanda2_botones.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null


func _escenario() -> void:
	await _recargar()
	_ok("0 el mapa y las piezas de la segunda tanda se montan sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	await _f13()
	await _f14()


# ---------------------------------------------------------------------------------------------------------------------

## Carga el laboratorio de cero (si ya había uno, lo libera antes). Deja `lab` apuntando a su nodo de reglas.
func _recargar() -> void:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena", lab != null)
	lanzador.tinta = null


func _sala(nombre: String) -> Dictionary:
	return lab.call("nuevo", nombre)


func _arde(nd: Variant) -> bool:
	return is_instance_valid(nd) and bool((nd as Object).get("is_lit"))


## Un seto que ya ardió del todo se libera (se consume): `consumido` = ardió (o ardía) alguna vez.
func _ardio(nd: Variant) -> bool:
	return not is_instance_valid(nd) or bool((nd as Object).get("is_lit"))


func _abierta(nd: Variant) -> bool:
	return bool((nd as Object).get("abierta"))


func _tecla_sala(tecla: Key, alt: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.pressed = true
	ev.alt_pressed = alt
	lab.call("_unhandled_input", ev)


func _puzle3d() -> Puzle3D:
	return lab.get("_puzle_nodo") as Puzle3D


# ---------------------------------------------------------------------------------------------------------------------
#  F13 · Dragón que enciende + barrera
# ---------------------------------------------------------------------------------------------------------------------

## Los setos de F13 que han llegado a arder alguna vez (los lee `_vigila_f13` cada lectura).
func _f13_estado(q: Dictionary, quemados: Dictionary) -> void:
	for i in range(1, 6):
		if _ardio(q["s%d" % i]):
			quemados[i] = true


## Avanza `segundos` vigilando los setos y el barril de F13. Devuelve {t_s1, t_barril, quemados: {i: true}}.
func _f13_vigilar(q: Dictionary, segundos: float, parar_si_explota: bool = false) -> Dictionary:
	var r: Dictionary = {"t_s1": -1.0, "t_barril": -1.0, "quemados": {}}
	var barril: Barril3D = q["barril_grande"]
	var t0: float = reloj.t
	while reloj.t - t0 < segundos:
		await process_frame
		var t: float = reloj.t - t0
		_f13_estado(q, r["quemados"])
		if float(r["t_s1"]) < 0.0 and _ardio(q["s1"]):
			r["t_s1"] = t
		if float(r["t_barril"]) < 0.0 and barril.explotado:
			r["t_barril"] = t
			if parar_si_explota:
				break
	return r


func _f13_inicio() -> Dictionary:
	await _recargar()
	var q: Dictionary = _sala("F13")
	_ok("F13.0 la sala existe en el lab", not q.is_empty())
	return q


func _f13() -> void:
	# --- vía 0 · sin hacer nada: el dragón escupe a los 6 s, la fila arde y el barril revienta y sella el cofre ---
	var q: Dictionary = await _f13_inicio()
	if q.is_empty():
		return
	var dragon: TrampaDragon3D = q["dragon"]
	var barril: Barril3D = q["barril_grande"]
	var cofre: Variant = q["cofre"]
	_tecla_sala(KEY_KP_1)
	_ok("F13.1 la tecla 1 del teclado numérico lleva a la sala (4,25)", celda_jugador() == Vector2i(4, 25), str(celda_jugador()))
	colocar_jugador(Vector2i(20, 12))
	_tecla_sala(KEY_1, true)
	_ok("F13.2 Alt+1 también (y no a F1)", celda_jugador() == Vector2i(4, 25), str(celda_jugador()))
	_ok("F13.3 estado inicial: el dragón (6,24) mira al sur con alcance 3, cinco setos secos, barril entero y el cofre abrible",
		dragon.celda == Vector2i(6, 24) and dragon.mira == "s" and dragon.alcance == 3 and dragon.activa and not barril.explotado and not barril.encendido
		and not _ardio(q["s1"]) and not _ardio(q["s5"]) and not bool(q["s3"].call("esta_mojado")) and bool(cofre.call("sellado_cumplido")) and bool(cofre.get("es_cerrado")))
	if modo == "natural":
		var r0: Dictionary = await _f13_vigilar(q, 45.0, true)
		_ok("F13.4 sin hacer nada: el primer chorro prende el seto (6,26) a los %.1f s" % float(r0["t_s1"]), float(r0["t_s1"]) > 4.0 and float(r0["t_s1"]) < 12.0)
		_ok("F13.5 … el fuego corre por los cinco setos (%d ardieron) y el barril REVIENTA a los %.1f s" % [(r0["quemados"] as Dictionary).size(), float(r0["t_barril"])], (r0["quemados"] as Dictionary).size() == 5 and float(r0["t_barril"]) > float(r0["t_s1"]))
		await avanzar_s(1.0)
		colocar_jugador(Vector2i(2, 27))
		await avanzar_s(0.5)
		_ok("F13.6 con el barril reventado el cofre queda SELLADO: E no lo abre", not bool(cofre.call("sellado_cumplido")) and not bool(cofre.call("abrir")) and not bool(cofre.get("es_abierto")))
	else:
		# Botones: la placa @ (5,30) prende el primer seto a mano y el fuego corre igual hasta el barril; el botón ! apaga al dragón 8 s.
		var placa: Pulsador3D = q["placa"]
		var boton: Pulsador3D = q["boton"]
		boton.pulsar()
		await avanzar_s(0.5)
		_ok("F13.20 el botón ! (3,30) apaga al dragón (activa = %s)" % str(dragon.activa), not dragon.activa and boton.veces == 1)
		var r1: Dictionary = await _f13_vigilar(q, 7.5)
		_ok("F13.21 con el dragón apagado 8 s no se prende ningún seto en 7,5 s", (r1["quemados"] as Dictionary).is_empty())
		colocar_jugador(Vector2i(5, 30))
		await avanzar_s(0.5)
		_ok("F13.22 la placa @ (5,30) prende el primer seto por su regla", placa.veces == 1 and _ardio(q["s1"]))
		var r2: Dictionary = await _f13_vigilar(q, 40.0, true)
		_ok("F13.23 el fuego corre por la fila y el barril revienta (a los %.1f s de la placa) aunque el dragón siga apagado" % float(r2["t_barril"]), float(r2["t_barril"]) > 0.0)
		colocar_jugador(Vector2i(2, 27))
		await avanzar_s(0.5)
		_ok("F13.24 … y el cofre queda sellado", not bool(cofre.call("sellado_cumplido")) and not bool(cofre.call("abrir")))
		return
	# --- vía 1 · agua a la cabeza del dragón (la apaga 8 s): no sale chorro y el cofre se abre ---
	q = await _f13_inicio()
	dragon = q["dragon"]
	barril = q["barril_grande"]
	cofre = q["cofre"]
	_tecla_sala(KEY_KP_1)
	await avanzar_s(2.0)
	_ok("F13.10 agua + flecha a la cabeza (6,24) desde (6,25) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(6, 24), Vector2i(6, 25)))
	await avanzar_s(0.8)
	_ok("F13.11 el agua apaga al dragón (activa = %s)" % str(dragon.activa), not dragon.activa)
	var rb: Dictionary = await _f13_vigilar(q, 12.0)
	_ok("F13.12 durante los 12 s siguientes no se prende ningún seto ni revienta el barril (8 s apagado + 6 s de descanso al volver)", (rb["quemados"] as Dictionary).is_empty() and not barril.explotado)
	colocar_jugador(Vector2i(2, 27))
	await avanzar_s(0.5)
	_ok("F13.13 el cofre sigue abrible (no hay barril reventado)", bool(cofre.call("sellado_cumplido")) and bool(cofre.call("abrir")))
	await avanzar_s(4.0)
	_ok("F13.14 se abre del todo con E", bool(cofre.get("es_abierto")))
	# --- vía 2 · cortafuegos: agua a un seto del medio ---
	q = await _f13_inicio()
	dragon = q["dragon"]
	barril = q["barril_grande"]
	cofre = q["cofre"]
	_tecla_sala(KEY_KP_1)
	await avanzar_s(1.0)
	_ok("F13.15 agua + flecha al seto del medio (4,26) desde (4,28) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(4, 26), Vector2i(4, 28)))
	await avanzar_s(1.0)
	_ok("F13.16 el seto del medio queda MOJADO y el resto seco", bool(q["s3"].call("esta_mojado")) and not bool(q["s2"].call("esta_mojado")) and not bool(q["s4"].call("esta_mojado")))
	colocar_jugador(Vector2i(4, 25))
	var rc: Dictionary = await _f13_vigilar(q, 35.0)
	_ok("F13.17 el dragón prende el primero (a los %.1f s) y el fuego corre hasta el seto mojado y se para: arden %s y no %s; el barril sigue entero a los 35 s" % [float(rc["t_s1"]), str((rc["quemados"] as Dictionary).keys()), "(3), (4), (5)"],
		float(rc["t_s1"]) > 0.0 and (rc["quemados"] as Dictionary).has(1) and (rc["quemados"] as Dictionary).has(2) and not (rc["quemados"] as Dictionary).has(3) and not (rc["quemados"] as Dictionary).has(4) and not (rc["quemados"] as Dictionary).has(5) and not barril.explotado)
	colocar_jugador(Vector2i(2, 27))
	await avanzar_s(0.5)
	_ok("F13.18 con el cortafuegos el cofre se abre", bool(cofre.call("sellado_cumplido")) and bool(cofre.call("abrir")))
	# --- vía 3 · barrera de agua entre la boca y los setos: la barrera dura 2 s (Lanzador/HechizoVivo.VIDA_MIN_SOLIDEZ_V2, sin permanencia), así que se levanta cuando el dragón avisa (5,5 s) y para ESE chorro ---
	q = await _f13_inicio()
	dragon = q["dragon"]
	barril = q["barril_grande"]
	cofre = q["cofre"]
	_tecla_sala(KEY_KP_1)
	await avanzar_s(5.2)
	_ok("F13.30 agua + barrera desde (6,25) (nace en la casilla de la jugadora, justo delante de la boca) sale, cuando el dragón va a avisar", lanzar_a_celda("agua", ["barrera"], Vector2i(6, 26), Vector2i(6, 25)))
	await avanzar_s(0.1)
	colocar_jugador(Vector2i(4, 25))                                     # la barrera no cierra el paso a su propia lanzadora: hay que salirse de su casilla
	var muros: int = 0
	var celdas_muro: Array = []
	for sd in lanzador._solideces_v2:
		if is_instance_valid(sd):
			muros += 1
			celdas_muro.append_array(sd.celdas.keys())
	_ok("F13.31 la barrera está viva en %s (solideces: %d)" % [str(celdas_muro), muros], muros >= 1 and celdas_muro.has(Vector2i(6, 25)))
	var rd: Dictionary = await _f13_vigilar(q, 3.0)
	_ok("F13.32 el chorro de los 6 s (dragón: %d haces) se para en la barrera: no prende el seto (ardió alguno: %s)" % [dragon.ticks, str((rd["quemados"] as Dictionary).keys())], (rd["quemados"] as Dictionary).is_empty() and dragon.ticks >= 1 and not barril.explotado)
	var re: Dictionary = await _f13_vigilar(q, 9.0)
	_ok("F13.33 pero es solo UN chorro: la barrera se va a los 2 s y el siguiente (a los 13 s) sí prende el primer seto (a los %.1f s de ahí)" % float(re["t_s1"]), float(re["t_s1"]) > 0.0)

# ---------------------------------------------------------------------------------------------------------------------
#  F14 · Choque térmico
# ---------------------------------------------------------------------------------------------------------------------

## El valor del uniforme `calor` que se está pintando (la capa de grietas del modelo o el shader de la caja).
func _calor_pintado(m: MuroAgrietado3D) -> float:
	var mat: ShaderMaterial = m.get("_capa") as ShaderMaterial
	if mat == null:
		mat = m.get("_mat") as ShaderMaterial
	return float(mat.get_shader_parameter("calor")) if mat != null else -1.0


func _f14() -> void:
	await _recargar()
	var q: Dictionary = _sala("F14")
	_ok("F14.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var muro: MuroAgrietado3D = q["muro"]
	var cofre: Variant = q["cofre"]
	var boton: Pulsador3D = q["boton"]
	var placa: Pulsador3D = q["placa"]
	var cuenta: Dictionary = {"calienta": 0, "se_enfria": 0}
	muro.calienta.connect(func() -> void: cuenta["calienta"] = int(cuenta["calienta"]) + 1)
	muro.se_enfria.connect(func() -> void: cuenta["se_enfria"] = int(cuenta["se_enfria"]) + 1)
	_tecla_sala(KEY_KP_2)
	_ok("F14.1 la tecla 2 del teclado numérico lleva a la sala (12,25)", celda_jugador() == Vector2i(12, 25), str(celda_jugador()))
	colocar_jugador(Vector2i(20, 12))
	_tecla_sala(KEY_2, true)
	_ok("F14.2 Alt+2 también (y no a F2)", celda_jugador() == Vector2i(12, 25), str(celda_jugador()))
	_ok("F14.3 estado inicial: una roca TÉRMICA en (10,27), fría e intacta, que tapa el nicho: el cofre (9,25) sigue oculto y la casilla bloqueada",
		muro.termica and muro.celda == Vector2i(10, 27) and not muro.caliente and not muro.roto_ya and muro.calor_dura >= 5.0 and bool(cofre.get("es_oculto")) and Terreno3D.bloqueada(Vector2i(10, 27)) and _calor_pintado(muro) == 0.0)
	_ok("F14.4 el color del calor es rojo-naranja, nunca amarillo: (%.2f, %.2f, %.2f)" % [MuroAgrietado3D.COLOR_CALOR.r, MuroAgrietado3D.COLOR_CALOR.g, MuroAgrietado3D.COLOR_CALOR.b],
		MuroAgrietado3D.COLOR_CALOR.r >= 0.9 and MuroAgrietado3D.COLOR_CALOR.g <= 0.45 and MuroAgrietado3D.COLOR_CALOR.b <= 0.15)
	if modo == "natural":
		# 1 · Fría, el agua no le hace nada.
		_ok("F14.5 agua + flecha a la roca (10,27) desde (10,28) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(10, 27), Vector2i(10, 28)))
		await avanzar_s(1.2)
		_ok("F14.6 el agua en FRÍO no le hace nada: ni se parte ni se calienta", not muro.roto_ya and not muro.caliente and bool(cofre.get("es_oculto")))
		# 2 · Los golpes de tierra y las explosiones no la rompen.
		for i in range(3):
			lanzar_a_celda("tierra", ["flecha"], Vector2i(10, 27), Vector2i(10, 28))
			await avanzar_s(1.2)
		muro.recibir_explosion(muro.global_position)
		await avanzar_s(0.5)
		_ok("F14.7 tres golpes de tierra y una explosión (barril) no la rompen (golpes recibidos: %d de %d)" % [muro.recibidos, muro.golpes], not muro.roto_ya and muro.recibidos == 0 and not muro.is_in_group("explosionable"))
		# 3 · El fuego la pone al rojo.
		_ok("F14.8 fuego + flecha a la roca sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(10, 27), Vector2i(10, 28)))
		await avanzar_s(0.8)
		_ok("F14.9 el fuego la pone AL ROJO (calor %.1f s, pintado %.2f, luz %.2f) pero no la parte" % [muro.calor_s, _calor_pintado(muro), (muro.get("_luz_calor") as OmniLight3D).light_energy],
			muro.caliente and muro.calor_s > muro.calor_dura - 1.5 and _calor_pintado(muro) > 0.9 and not muro.roto_ya and int(cuenta["calienta"]) == 1 and (muro.get("_luz_calor") as OmniLight3D).light_energy > 0.5)
		# 4 · Se enfría sola: pasados los segundos de calor, el agua ya no hace nada.
		await avanzar_s(muro.calor_dura + 0.5)
		_ok("F14.10 pasados %.0f s se ha enfriado sola (se_enfria x%d, pintado %.2f)" % [muro.calor_dura, int(cuenta["se_enfria"]), _calor_pintado(muro)], not muro.caliente and int(cuenta["se_enfria"]) == 1 and _calor_pintado(muro) < 0.05)
		lanzar_a_celda("agua", ["flecha"], Vector2i(10, 27), Vector2i(10, 28))
		await avanzar_s(1.2)
		_ok("F14.11 agua cuando ya se enfrió: nada (la ventana pasó)", not muro.roto_ya and bool(cofre.get("es_oculto")))
		# 5 · El fuego otra vez renueva el calor; con ella al rojo, el agua la parte.
		lanzar_a_celda("fuego", ["flecha"], Vector2i(10, 27), Vector2i(10, 28))
		await avanzar_s(4.0)
		var restante: float = muro.calor_s
		lanzar_a_celda("fuego", ["flecha"], Vector2i(10, 27), Vector2i(10, 28))
		await avanzar_s(0.6)
		_ok("F14.12 otro fuego a los 4 s RENUEVA el calor (de %.1f s a %.1f s)" % [restante, muro.calor_s], muro.calor_s > restante + 2.0 and muro.calentamientos >= 3)
		_ok("F14.13 agua + flecha a la roca al rojo sale", lanzar_a_celda("agua", ["flecha"], Vector2i(10, 27), Vector2i(10, 28)))
		await avanzar_s(0.6)
		_ok("F14.14 el CHOQUE TÉRMICO la parte (roto = %s) y libera su casilla" % str(muro.roto_ya), muro.roto_ya and not Terreno3D.bloqueada(Vector2i(10, 27)))
		await avanzar_s(1.2)
		_ok("F14.15 aparece el cofre del nicho (oculto %s, cerrado %s)" % [str(bool(cofre.get("es_oculto"))), str(bool(cofre.get("es_cerrado")))], not bool(cofre.get("es_oculto")) and bool(cofre.get("es_cerrado")))
	else:
		boton.pulsar()
		await avanzar_s(0.8)
		_ok("F14.20 el botón ! (13,30) calienta la roca (al rojo %s, calor %.1f s) sin partirla" % [str(muro.caliente), muro.calor_s], boton.veces == 1 and muro.caliente and not muro.roto_ya and bool(cofre.get("es_oculto")))
		colocar_jugador(Vector2i(11, 30))
		await avanzar_s(0.8)
		_ok("F14.21 la placa @ (11,30) la parte por su regla y aparece el cofre", placa.veces == 1 and muro.roto_ya and not Terreno3D.bloqueada(Vector2i(10, 27)))
		await avanzar_s(1.2)
		_ok("F14.22 … el cofre del nicho está a la vista", not bool(cofre.get("es_oculto")))