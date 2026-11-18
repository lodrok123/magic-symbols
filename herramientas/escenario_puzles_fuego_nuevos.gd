extends "res://herramientas/escenario_base.gd"
## Escenario · los puzles NUEVOS del LABORATORIO DE FUEGO (18/11/2026, Juego): F10 «Lleva la pólvora» (sala (2,1)), F11 «Tótems que escupen fuego» (2,2) y F12 «Respiraderos de veneno» (3,2).
## Carga laboratorios/LabPuzlesFuego3D.tscn y los juega por código con las piezas de verdad. Igual que `escenario_puzles_fuego`, dos pasadas, porque lo que explota, se rompe o se quema no se deshace:
##   · `natural`  (por defecto): la vía de la jugadora (hechizos, coger y lanzar, esquivar).
##   · `botones`  (escenario_puzles_fuego_nuevos_botones.gd): el botón `!` y la placa `@` de cada sala, que separan «falla el fuego» de «falla el disparador».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_nuevos.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_nuevos_botones.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena", lab != null)
	if lab == null:
		return
	_ok("0 el mapa y las piezas nuevas se montan sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	if modo == "natural":
		await _f10_natural()
	else:
		await _f10_botones()


# ---------------------------------------------------------------------------------------------------------------------

func _puzle3d() -> Puzle3D:
	return lab.get("_puzle_nodo") as Puzle3D


func _nodo(id: String) -> Node:
	return _puzle3d().nodo(id)


func _sala(nombre: String) -> Dictionary:
	return lab.call("nuevo", nombre)


## La jugadora de cara a `dir` en `cel`, con la vida llena.
func _preparar_j(cel: Vector2i, dir: Vector3) -> void:
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(cel)
	j.mirar_hacia(dir)
	(j.pj as Pj3D).mirar(dir, 1.0)
	j.vida = Estado.i().vida_max
	await avanzar_s(0.5)


func _hasta_estado(c: CargarObjeto3D, e: int, max_s: float = 3.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and c.estado != e:
		await process_frame
	return c.estado == e


## Abre un cofre como la jugadora (E): reintenta cada 0,2 s mientras aún está apareciendo y espera a que acabe de abrirse (el botín se da al terminar). true si queda abierto.
func _abrir_cofre(cofre: Variant, max_s: float = 6.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and not bool(cofre.get("es_abierto")):
		cofre.call("abrir")
		await avanzar_s(0.2)
	return bool(cofre.get("es_abierto"))


## Vigila un barril: cuenta sus explosiones y apunta dónde (punto) y cuándo.
func _vigilar(b: Barril3D) -> Dictionary:
	var rec: Dictionary = {"n": 0, "punto": Vector3.ZERO, "t": 0.0}
	b.explota.connect(func(p: Vector3, _r: float) -> void:
		rec["n"] = int(rec["n"]) + 1
		rec["punto"] = p
		rec["t"] = reloj.t)
	return rec


func _espera_rec(rec: Dictionary, max_s: float = 5.0) -> void:
	var t0: float = reloj.t
	while int(rec["n"]) == 0 and reloj.t - t0 < max_s:
		await process_frame


# ---------------------------------------------------------------------------------------------------------------------
#  F10 · Lleva la pólvora
# ---------------------------------------------------------------------------------------------------------------------

func _f10_estado_inicial() -> void:
	var q: Dictionary = _sala("F10")
	var muro: MuroAgrietado3D = q["muro"]
	var cofre: Variant = q["cofre"]
	var peq: Barril3D = q["barril"]
	var grande: Barril3D = _nodo("f6_grande") as Barril3D
	_ok("F10.1 el muro agrietado tapa la entrada del nicho (casilla (18,11) bloqueada) y el cofre del premio aún no existe", muro != null and not muro.roto_ya and Terreno3D.bloqueada(Vector2i(18, 11)) and cofre != null and bool(cofre.get("es_oculto")))
	_ok("F10.2 hay un barril PEQUEÑO lanzable en (18,12) y uno GRANDE en (22,12), los dos enteros", peq != null and peq.pequeno and peq.celda == Vector2i(18, 12) and not peq.encendido and not peq.explotado
		and grande != null and not grande.pequeno and grande.celda == Vector2i(22, 12) and not grande.explotado)
	# Lo que dice el código (Barril3D / MuroAgrietado3D): la explosión llega a lo del grupo `explosionable` que esté a ≤ radio del PUNTO de la explosión (centro a centro).
	_ok("F10.3 el muro es `explosionable` y sabe recibir una explosión: la del barril lo rompe de una vez", muro.is_in_group("explosionable") and muro.has_method("recibir_explosion") and not muro.por_pulso)
	var medio: float = Terreno3D.casilla * 0.5
	var alcance_muro: float = Barril3D.RADIO_PEQUENO + Barril3D.EXTRA_SOLIDO_PEQUENO
	_ok("F10.4 geometría: el alcance del barril pequeño contra lo explosionable (%.2f u) llega al centro del muro desde su borde (a %.2f u) pero NO desde el centro de la casilla de al lado (a %.2f u): hay que LANZARLO contra el muro" % [alcance_muro, medio, Terreno3D.casilla],
		alcance_muro > medio + 0.4 and alcance_muro < Terreno3D.casilla)
	_ok("F10.5 el barril grande, de radio %.1f u, no llega al muro desde donde está (a %.1f u)" % [Barril3D.RADIO, (muro.global_position - grande.global_position).length()], (muro.global_position - grande.global_position).length() > Barril3D.RADIO)


func _f10_natural() -> void:
	await _f10_estado_inicial()
	var q: Dictionary = _sala("F10")
	var muro: MuroAgrietado3D = q["muro"]
	var cofre: Variant = q["cofre"]
	var peq: Barril3D = q["barril"]
	var grande: Barril3D = _nodo("f6_grande") as Barril3D
	var j: Jugador3D = jugador as Jugador3D
	var c: CargarObjeto3D = j.carga
	lanzador.tinta = null
	# 1 · El barril grande es un señuelo: explotarlo no abre nada.
	var rec_g: Dictionary = _vigilar(grande)
	_ok("F10.6 fuego + flecha al barril GRANDE sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(22, 12), Vector2i(20, 12)))
	await _espera_rec(rec_g, 6.0)
	await avanzar_s(0.5)
	_ok("F10.7 el barril grande explota y el muro sigue entero (el señuelo no abre el nicho)", int(rec_g["n"]) == 1 and not muro.roto_ya and Terreno3D.bloqueada(Vector2i(18, 11)))
	# 2 · La vía: coger el pequeño, encenderlo con fuego y lanzarlo contra el muro.
	await _preparar_j(Vector2i(18, 13), Vector3(0.0, 0.0, -1.0))
	var rec: Dictionary = _vigilar(peq)
	_ok("F10.8 fuego + flecha al barril pequeño (a una casilla) sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(18, 12), Vector2i(18, 13)))
	var t_enc: float = reloj.t
	# La jugadora pulsa E en cuanto puede (mientras lanza el hechizo no puede coger): se reintenta cada fotograma.
	var coge: bool = false
	while not coge and reloj.t - t_enc < 2.0 and is_instance_valid(peq) and not peq.explotado:
		coge = c.coger(peq)
		if not coge:
			await process_frame
	var t_coge: float = reloj.t - t_enc
	var en_manos: bool = coge and await _hasta_estado(c, CargarObjeto3D.Estado.CARGANDO)
	var t_manos: float = reloj.t - t_enc
	await avanzar(2)
	var queda: float = peq.mecha_restante() if is_instance_valid(peq) else -1.0
	_ok("F10.9 lo coge ENCENDIDO (E posible a los %.2f s, en las manos a los %.2f s del fuego) y la mecha sigue (le quedaba %.2f)" % [t_coge, t_manos, queda], coge and en_manos and peq.encendido and peq.en_brazos and queda > 0.15, "en_manos %s" % str(en_manos))
	j.mirar_hacia(Vector3(0.0, 0.0, -1.0))
	(j.pj as Pj3D).mirar(Vector3(0.0, 0.0, -1.0), 1.0)
	c.lanzar()
	await _espera_rec(rec, 4.0)
	await avanzar_s(0.3)
	var d_muro: float = (rec["punto"] as Vector3 - muro.global_position).length() if int(rec["n"]) > 0 else -1.0
	_ok("F10.10 explota al chocar con el muro, a %.2f u de su centro (alcance contra muros %.2f)" % [d_muro, Barril3D.RADIO_PEQUENO + Barril3D.EXTRA_SOLIDO_PEQUENO], int(rec["n"]) == 1 and d_muro > 0.0 and d_muro <= Barril3D.RADIO_PEQUENO + Barril3D.EXTRA_SOLIDO_PEQUENO, "t %.2f" % (float(rec["t"]) - t_enc))
	_ok("F10.11 el muro se rompe (`roto`) y libera su casilla", muro.roto_ya and not Terreno3D.bloqueada(Vector2i(18, 11)))
	await avanzar_s(0.5)
	_ok("F10.12 aparece el cofre del nicho (cerrado) y se abre con E: da su botín", not bool(cofre.get("es_oculto")) and bool(cofre.get("es_cerrado")))
	var oro0: int = Estado.i().oro
	await _abrir_cofre(cofre)
	_ok("F10.13 … y al abrirse da 25 de oro", bool(cofre.get("es_abierto")) and Estado.i().oro - oro0 == 25, "oro +%d" % (Estado.i().oro - oro0))


func _f10_botones() -> void:
	await _f10_estado_inicial()
	var q: Dictionary = _sala("F10")
	var muro: MuroAgrietado3D = q["muro"]
	var cofre: Variant = q["cofre"]
	var peq: Barril3D = q["barril"]
	var boton: Pulsador3D = lab.call("pulsador_en", Vector2i(18, 14)) as Pulsador3D
	var placa: Pulsador3D = lab.call("pulsador_en", Vector2i(22, 14)) as Pulsador3D
	_ok("F10.20 el botón `!` (18,14) y la placa `@` (22,14) existen", boton != null and placa != null)
	# El botón enciende el barril pequeño donde está: sin llevarlo, explota en su casilla (a 2,3 u del muro) y NO lo rompe.
	var rec: Dictionary = _vigilar(peq)
	boton.pulsar()
	await avanzar(2)
	_ok("F10.21 el botón enciende el barril pequeño", peq.encendido)
	await _espera_rec(rec, 5.0)
	await avanzar_s(0.5)
	_ok("F10.22 explota en su casilla y NO rompe el muro (hay que llevarlo: a %.1f u del centro, radio %.1f)" % [((rec["punto"] as Vector3) - muro.global_position).length(), Barril3D.RADIO_PEQUENO],
		int(rec["n"]) == 1 and not muro.roto_ya and ((rec["punto"] as Vector3) - muro.global_position).length() > Barril3D.RADIO_PEQUENO)
	# La placa rompe el muro directamente (el control: separa «falla la explosión» de «falla el disparador»).
	colocar_jugador(Vector2i(22, 14))
	await avanzar_s(0.6)
	_ok("F10.23 la placa rompe el muro y hace aparecer el cofre", placa.veces == 1 and muro.roto_ya and not bool(cofre.get("es_oculto")))
