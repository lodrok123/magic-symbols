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
		await _f11_natural()
		await _f12_natural()
	elif modo == "muro":
		await _f10_muro()
	else:
		await _f10_botones()
		await _f11_botones()
		await _f12_botones()


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
	_ok("F10.2 hay un barril PEQUEÑO lanzable en (22,10), al otro lado de la sala, y uno GRANDE en (22,12), los dos enteros", peq != null and peq.pequeno and peq.celda == Vector2i(22, 10) and not peq.encendido and not peq.explotado
		and grande != null and not grande.pequeno and grande.celda == Vector2i(22, 12) and not grande.explotado)
	# Lo que dice el código (Barril3D / MuroAgrietado3D): la explosión llega a lo del grupo `explosionable`. El barril PEQUEÑO mide al punto más cercano de su CASILLA (no a su centro), con radio 1,6 u.
	_ok("F10.3 el muro es `explosionable` y sabe recibir una explosión: la del barril lo rompe de una vez", muro.is_in_group("explosionable") and muro.has_method("recibir_explosion") and not muro.por_pulso)
	# (18/11, cambio de regla) ANTES F10.4 decía: «el alcance del pequeño (1,6 + 0,45) llega al muro desde su borde pero no desde el centro de la casilla de al lado: hay que lanzarlo». Con la regla nueva
	# desde el centro de la casilla de al lado SÍ llega (1,15 u de la cara), y lo que obliga a llevarlo es que nace lejos (F10.4b).
	var c_muro: Vector3 = muro.global_position
	var d_vecina: float = Barril3D.distancia_a_casilla(Terreno3D.centro_de(Vector2i(18, 12)), c_muro)
	var d_diagonal: float = Barril3D.distancia_a_casilla(Terreno3D.centro_de(Vector2i(19, 12)), c_muro)
	_ok("F10.4 geometría: desde el centro de la casilla de al lado del muro el pequeño está a %.2f u de su cara (radio %.1f: lo rompe) y en diagonal a %.2f u (no)" % [d_vecina, Barril3D.RADIO_PEQUENO, d_diagonal],
		d_vecina <= Barril3D.RADIO_PEQUENO and d_diagonal > Barril3D.RADIO_PEQUENO)
	var d_origen: float = Barril3D.distancia_a_casilla(peq.global_position, c_muro)
	_ok("F10.4b el barril pequeño NO nace al alcance del muro: su casilla de origen está a %.1f u de la cara (más de 3 casillas de centro a centro) y hay que llevarlo" % d_origen,
		d_origen > Barril3D.RADIO_PEQUENO and (peq.global_position - c_muro).length() >= 3.0 * Terreno3D.casilla)
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
	await _preparar_j(Vector2i(22, 11), Vector3(0.0, 0.0, -1.0))
	var rec: Dictionary = _vigilar(peq)
	_ok("F10.8 fuego + flecha al barril pequeño (a una casilla) sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(22, 10), Vector2i(22, 11)))
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
	# Lo lleva a la otra punta de la sala (teletransporte: ir andando gastaría la mecha, que aquí no es lo que se prueba) y lo lanza contra el muro.
	colocar_jugador(Vector2i(18, 13))
	j.mirar_hacia(Vector3(0.0, 0.0, -1.0))
	(j.pj as Pj3D).mirar(Vector3(0.0, 0.0, -1.0), 1.0)
	c.lanzar()
	await _espera_rec(rec, 4.0)
	await avanzar_s(0.3)
	var d_muro: float = Barril3D.distancia_a_casilla(rec["punto"] as Vector3, muro.global_position) if int(rec["n"]) > 0 else -1.0
	_ok("F10.10 explota al chocar con el muro, a %.2f u de su casilla (radio %.1f)" % [d_muro, Barril3D.RADIO_PEQUENO], int(rec["n"]) == 1 and d_muro >= 0.0 and d_muro <= Barril3D.RADIO_PEQUENO, "t %.2f" % (float(rec["t"]) - t_enc))
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
	# El botón enciende el barril pequeño donde está (en (22,10), lejos): sin llevarlo, explota en su casilla y NO rompe el muro.
	var rec: Dictionary = _vigilar(peq)
	boton.pulsar()
	await avanzar(2)
	_ok("F10.21 el botón enciende el barril pequeño", peq.encendido)
	await _espera_rec(rec, 5.0)
	await avanzar_s(0.5)
	var d_casilla: float = Barril3D.distancia_a_casilla(rec["punto"] as Vector3, muro.global_position)
	_ok("F10.22 explota en su sitio y NO rompe el muro (hay que llevarlo: a %.1f u de su casilla, radio %.1f)" % [d_casilla, Barril3D.RADIO_PEQUENO],
		int(rec["n"]) == 1 and not muro.roto_ya and d_casilla > Barril3D.RADIO_PEQUENO)
	# La placa rompe el muro directamente (el control: separa «falla la explosión» de «falla el disparador»).
	colocar_jugador(Vector2i(22, 14))
	await avanzar_s(0.6)
	_ok("F10.23 la placa rompe el muro y hace aparecer el cofre", placa.veces == 1 and muro.roto_ya and not bool(cofre.get("es_oculto")))


# --- La regla del barril pequeño contra el muro (18/11): mide al punto más cercano de la CASILLA del muro, con radio 1,6 u. Cada caso rompe (o no) el muro, y lo roto no se deshace: cada caso recarga el laboratorio.
##   godot --headless --fixed-fps 20|30|60 --path . --script res://herramientas/escenario_puzles_fuego_nuevos_muro.gd

func _recargar_lab() -> void:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
		await avanzar(10)
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")


## Un caso: coge el barril pequeño (sin encender) desde `desde` mirando `dir`, lo enciende en las manos y lo `accion`a ("soltar" lo deja delante; "lanzar" lo tira). Comprueba dónde explota y si el muro se rompe.
func _f10_muro_caso(id: String, desde: Vector2i, dir: Vector3, accion: String, celda_esperada: Vector2i, rompe: bool, recargar: bool = true) -> void:
	if recargar:
		await _recargar_lab()
	var q: Dictionary = _sala("F10")
	var muro: MuroAgrietado3D = q["muro"]
	var peq: Barril3D = q["barril"]
	var j: Jugador3D = jugador as Jugador3D
	var c: CargarObjeto3D = j.carga
	lanzador.tinta = null
	var rec: Dictionary = _vigilar(peq)
	await _preparar_j(desde, dir)
	var t0: float = reloj.t
	await avanzar(10)
	var fps: float = 10.0 / maxf(reloj.t - t0, 0.001)
	var coge: bool = false
	var t_coge: float = reloj.t
	while not coge and reloj.t - t_coge < 2.0:
		coge = c.coger(peq)
		if not coge:
			await process_frame
	var en_manos: bool = coge and await _hasta_estado(c, CargarObjeto3D.Estado.CARGANDO)
	_ok("%s.1 coge el barril pequeño (a unos %.0f fps)" % [id, fps], coge and en_manos and not peq.encendido)
	if not en_manos:
		return
	peq.encender()
	j.mirar_hacia(dir)                       # al cogerlo se vuelve hacia el barril: se vuelve a poner de cara a donde va
	(j.pj as Pj3D).mirar(dir, 1.0)
	await avanzar(2)
	var hecho: bool = c.soltar() if accion == "soltar" else c.lanzar()
	_ok("%s.2 lo %s encendido" % [id, accion], hecho and peq.encendido)
	await _espera_rec(rec, 5.0)
	await avanzar_s(0.5)
	var punto: Vector3 = rec["punto"] as Vector3
	var d: float = Barril3D.distancia_a_casilla(punto, muro.global_position)
	var cel: Vector2i = Terreno3D.celda_de(punto)
	_ok("%s.3 explota una sola vez en %s (esperada %s), a %.2f u de la casilla del muro (radio %.1f)" % [id, str(cel), str(celda_esperada), d, Barril3D.RADIO_PEQUENO], int(rec["n"]) == 1 and cel == celda_esperada, "punto (%.2f, %.2f), jugadora en (%.2f, %.2f)" % [punto.x, punto.z, j.position.x, j.position.z])
	_ok("%s.4 el muro %s" % [id, "se rompe y libera su casilla" if rompe else "NO se rompe"], muro.roto_ya == rompe and Terreno3D.bloqueada(Vector2i(18, 11)) != rompe, "roto_ya %s" % str(muro.roto_ya))


func _f10_muro() -> void:
	await _f10_estado_inicial()
	# A · dejado (soltar) ENCENDIDO en la casilla de al lado del muro: lo rompe (1,15 u de su cara).
	await _f10_muro_caso("F10.A", Vector2i(18, 13), Vector3(0.0, 0.0, -1.0), "soltar", Vector2i(18, 12), true, false)
	# B · lanzado y caído en el suelo de esa casilla (3 casillas de alcance desde (21,12) hacia el oeste): lo rompe.
	await _f10_muro_caso("F10.B", Vector2i(21, 12), Vector3(-1.0, 0.0, 0.0), "lanzar", Vector2i(18, 12), true)
	# C · lanzado de frente contra el muro desde (18,13): explota al chocar (donde estaba un fotograma antes) y lo rompe, a cualquier tasa de fotogramas.
	await _f10_muro_caso("F10.C", Vector2i(18, 13), Vector3(0.0, 0.0, -1.0), "lanzar", Vector2i(18, 12), true)
	# D · en diagonal (casilla (19,12), 1,63 u de la cara): no lo rompe.
	await _f10_muro_caso("F10.D", Vector2i(19, 15), Vector3(0.0, 0.0, -1.0), "lanzar", Vector2i(19, 12), false)


# ---------------------------------------------------------------------------------------------------------------------
#  F11 · Tótems que escupen fuego
# ---------------------------------------------------------------------------------------------------------------------

func _f11_totems() -> Array:
	var q: Dictionary = _sala("F11")
	return [q["t1"], q["t2"], q["t3"]]


## Apunta cuándo dispara cada tótem (señal `dispara`): {fila del tótem -> [tiempos]}.
func _vigilar_totems(ts: Array) -> Dictionary:
	var rec: Dictionary = {}
	for t in ts:
		var tf: TrampaFlechas3D = t
		var y: int = tf.celda.y
		rec[y] = []
		tf.dispara.connect(func() -> void: (rec[y] as Array).append(reloj.t))
	return rec


func _golpes_totems(ts: Array) -> int:
	var n: int = 0
	for t in ts:
		n += int((t as TrampaFlechas3D).golpes_jugadora)
	return n


func _f11_estado_inicial() -> void:
	var ts: Array = _f11_totems()
	var celdas: Array = [Vector2i(17, 18), Vector2i(17, 20), Vector2i(17, 22)]
	var bien: bool = true
	var boca_fuera: bool = true
	for i in range(3):
		var tf: TrampaFlechas3D = ts[i]
		bien = bien and tf != null and tf.exenta and tf.celda == celdas[i] and tf.mira == "e" and Terreno3D.letra_de(tf.celda) != "#" and Terreno3D.bloqueada(tf.celda) and tf.elemento == "fuego"
		boca_fuera = boca_fuera and tf != null and Terreno3D.celda_de(tf.boca_mundo()) == tf.celda + Vector2i(1, 0)
	_ok("F11.1 tres tótems EXENTOS: `trampa_flechas` de pie en una casilla de SUELO (no metidos en un muro «#»), que la bloquea, mirando al este y de fuego", bien)
	_ok("F11.2 la boca de cada uno cae en la casilla de delante (la bola no nace dentro del sólido)", boca_fuera)
	var d: Array = [(ts[0] as TrampaFlechas3D).desfase_s, (ts[1] as TrampaFlechas3D).desfase_s, (ts[2] as TrampaFlechas3D).desfase_s]
	_ok("F11.3 los tres están desfasados un segundo (ciclo %.1f s: desfases %s)" % [(ts[0] as TrampaFlechas3D).cada_s, str(d)], absf(float(d[1]) - float(d[0]) - 1.0) < 0.01 and absf(float(d[2]) - float(d[1]) - 1.0) < 0.01)


func _f11_natural() -> void:
	await _f11_estado_inicial()
	var ts: Array = _f11_totems()
	var q: Dictionary = _sala("F11")
	var placa: Pulsador3D = q["placa"]
	var j: Jugador3D = jugador as Jugador3D
	# 1 · El ritmo: en la fila segura (y = 19) se mide cuándo dispara cada uno.
	await _preparar_j(Vector2i(20, 19), Vector3.RIGHT)
	var rec: Dictionary = _vigilar_totems(ts)
	var v0: float = j.vida
	await avanzar_s(10.0)
	var ok_ritmo: bool = true
	var info: String = ""
	for y in [18, 20, 22]:
		var tt: Array = rec[y]
		ok_ritmo = ok_ritmo and tt.size() >= 3
		if tt.size() >= 3:
			ok_ritmo = ok_ritmo and absf(float(tt[1]) - float(tt[0]) - 3.0) < 0.2 and absf(float(tt[2]) - float(tt[1]) - 3.0) < 0.2
		info += "fila %d: %d disparos  " % [y, tt.size()]
	_ok("F11.4 cada tótem dispara cada 3 s (%s)" % info, ok_ritmo)
	var off1: float = fposmod(float((rec[20] as Array)[0]) - float((rec[18] as Array)[0]), 3.0)
	var off2: float = fposmod(float((rec[22] as Array)[0]) - float((rec[20] as Array)[0]), 3.0)
	# (el desfase de cada uno es «en qué punto del ciclo empieza»: el de más desfase dispara antes, así que la ola va de la fila 22 a la 18; lo que importa es el segundo de separación)
	_ok("F11.5 escalonados: un disparo por segundo entre filas contiguas (diferencias %.2f s y %.2f s módulo 3)" % [off1, off2], absf(minf(off1, 3.0 - off1) - 1.0) < 0.25 and absf(minf(off2, 3.0 - off2) - 1.0) < 0.25)
	_ok("F11.6 en la fila de descanso (y = 19) no la toca ninguna bola en 10 s", _golpes_totems(ts) == 0 and j.vida >= v0 - 0.01)
	# 2 · Quedarse en un carril de fuego hiere.
	await _preparar_j(Vector2i(20, 18), Vector3.RIGHT)
	var t0: float = reloj.t
	while reloj.t - t0 < 4.0 and _golpes_totems(ts) == 0:
		await process_frame
	_ok("F11.7 quedarse en el carril (20,18) recibe la bola de fuego en %.1f s y pierde vida" % (reloj.t - t0), _golpes_totems(ts) >= 1 and j.vida < Estado.i().vida_max - 0.5)
	# 3 · Cruzar por turnos: entrar a cada carril justo después de que pase su bola, salir antes de la siguiente.
	await _preparar_j(Vector2i(20, 17), Vector3.RIGHT)
	var golpes0: int = _golpes_totems(ts)
	var vida0: float = j.vida
	var sin_hueco: bool = false
	for y in [18, 20, 22]:
		var espera0: float = reloj.t
		while not (reloj.t - float((rec[y] as Array).back()) >= 1.2 and reloj.t - float((rec[y] as Array).back()) <= 1.8):
			await process_frame
			if reloj.t - espera0 > 8.0:
				sin_hueco = true
				break
		colocar_jugador(Vector2i(20, y))
		await avanzar_s(0.3)
		colocar_jugador(Vector2i(20, y + 1))
		await avanzar_s(0.1)
	await avanzar_s(0.6)
	_ok("F11.8 cruzando por turnos (carril a carril, %.0f s en total) llega a la placa (20,23) sin recibir ninguna bola" % (reloj.t - t0), not sin_hueco and placa.activo and _golpes_totems(ts) == golpes0 and j.vida >= vida0 - 0.01)
	# 4 · El agua apaga un tótem 8 s (T_AGUA_S) y luego vuelve.
	var t2: TrampaFlechas3D = ts[1]
	await _preparar_j(Vector2i(19, 21), Vector3(-2.0, 0.0, -1.0).normalized())
	_ok("F11.9 agua + flecha al tótem del medio sale", lanzar_a_celda("agua", ["flecha"], Vector2i(17, 20), Vector2i(19, 21)))
	await avanzar_s(1.5)
	var d_antes: int = t2.disparos
	_ok("F11.10 el tótem queda apagado por el agua (no dispara)", not t2.activa)
	await avanzar_s(6.0)
	_ok("F11.11 … y sigue sin disparar 7 s después (%d disparos más)" % (t2.disparos - d_antes), t2.disparos == d_antes and not t2.activa)
	await avanzar_s(5.0)
	_ok("F11.12 … y a los 8 s de apagado vuelve a funcionar", t2.activa and t2.disparos > d_antes)


func _f11_botones() -> void:
	await _f11_estado_inicial()
	var ts: Array = _f11_totems()
	var q: Dictionary = _sala("F11")
	var placa: Pulsador3D = q["placa"]
	var boton: Pulsador3D = q["boton"]
	_ok("F11.20 el botón `!` (22,17) y la placa `@` (20,23) existen", boton != null and placa != null and boton.celda == Vector2i(22, 17) and placa.celda == Vector2i(20, 23))
	await _preparar_j(Vector2i(20, 19), Vector3.RIGHT)
	var rec: Dictionary = _vigilar_totems(ts)
	await avanzar_s(4.0)
	_ok("F11.21 antes del botón disparan", int((rec[18] as Array).size()) >= 1)
	boton.pulsar()
	await avanzar(2)
	var apagados: bool = true
	for t in ts:
		apagados = apagados and not (t as TrampaFlechas3D).activa
	var n0: Array = [(rec[18] as Array).size(), (rec[20] as Array).size(), (rec[22] as Array).size()]
	await avanzar_s(6.0)
	var n1: Array = [(rec[18] as Array).size(), (rec[20] as Array).size(), (rec[22] as Array).size()]
	_ok("F11.22 el botón apaga los tres tótems y no disparan en 6 s", apagados and n0 == n1, "%s -> %s" % [str(n0), str(n1)])
	await avanzar_s(3.5)
	var vuelve: bool = true
	for t in ts:
		vuelve = vuelve and (t as TrampaFlechas3D).activa
	_ok("F11.23 pasados los 8 s vuelven a funcionar", vuelve)
	colocar_jugador(Vector2i(20, 23))
	await avanzar_s(0.5)
	_ok("F11.24 la placa del fondo se pisa", placa.veces == 1 and placa.activo)


# ---------------------------------------------------------------------------------------------------------------------
#  F12 · Respiraderos de veneno
# ---------------------------------------------------------------------------------------------------------------------

## Apunta cuándo exhala cada respiradero: {"r1": [t…], "r2": [t…]}.
func _vigilar_respiraderos(r1: Respiradero3D, r2: Respiradero3D) -> Dictionary:
	var rec: Dictionary = {"r1": [], "r2": []}
	r1.exhala.connect(func() -> void: (rec["r1"] as Array).append(reloj.t))
	r2.exhala.connect(func() -> void: (rec["r2"] as Array).append(reloj.t))
	return rec


func _nubes_en_pasillo() -> int:
	var n: int = 0
	for y in [18, 19, 20, 21, 22]:
		if NubeVeneno3D.cubre(Vector2i(28, y)):
			n += 1
	return n


func _f12_estado_inicial() -> void:
	var q: Dictionary = _sala("F12")
	var r1: Respiradero3D = q["r1"]
	var r2: Respiradero3D = q["r2"]
	var lados: bool = true
	for y in range(18, 24):
		lados = lados and Terreno3D.letra_de(Vector2i(27, y)) == "#" and Terreno3D.letra_de(Vector2i(29, y)) == "#"
	_ok("F12.1 pasillo de una casilla (x = 28, y 18–23) entre muros, con dos respiraderos en (28,19) y (28,21)", lados and r1 != null and r2 != null and r1.celda == Vector2i(28, 19) and r2.celda == Vector2i(28, 21))
	# (18/11, arreglo de F12) ANTES F12.2 pedía vida = 8 (2 s limpios por reja); ahora 9 (1 s): con 2 s limpios se cruzaba la zona de la reja 1 y casi la de la 2 sin fuego (ver F12.3b).
	_ok("F12.2 cada uno exhala cada %.0f s una nube de %.0f s y %.0f casilla de radio; los separa 1 s de desfase; no bloquean su casilla; la nube se consume en %.1f s al arder y la reja arde %.0f s" % [r1.cada, r1.vida, r1.radio, r1.quema_s, r1.arde_s],
		r1.cada == 10.0 and r1.vida == 9.0 and r1.radio == 1.0 and absf(r1.desfase_s - r2.desfase_s - 1.0) < 0.01 and not Terreno3D.bloqueada(r1.celda) and not Terreno3D.bloqueada(r2.celda)
		and r1.quema_s == 0.5 and r2.quema_s == 0.5 and r1.arde_s == 6.0 and r2.arde_s == 6.0)
	_ok("F12.3 de serie casi siempre hay nube: %.0f s de vida de cada %.0f s (solo %.0f s limpios)" % [r1.vida, r1.cada, r1.cada - r1.vida], r1.cada - r1.vida <= 2.5)
	# Sin fuego no se cruza sin envenenarse: atravesar la nube de una reja (diámetro = 2 · radio · casilla) a la velocidad máxima de la jugadora (correr, sin rodar) dura MÁS que el rato que la reja está limpia.
	var j0: Jugador3D = jugador as Jugador3D
	var t_atravesar: float = 2.0 * r1.radio * Terreno3D.casilla / float(j0.get("_vel_correr"))
	_ok("F12.3b sin fuego no se cruza: atravesar una nube corriendo tarda %.2f s y la reja solo queda limpia %.1f s (el veneno además dura 3 s tras salir)" % [t_atravesar, r1.cada - r1.vida], t_atravesar > r1.cada - r1.vida and t_atravesar > r2.cada - r2.vida)
	var fuego_r: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	var agua_r: RuneData = load("res://nucleo/water_rune.tres") as RuneData
	_ok("F12.3c la reja reacciona al fuego y al agua (`spell_reacts`)", r1.spell_reacts(fuego_r) and r1.spell_reacts(agua_r))


func _f12_natural() -> void:
	await _f12_estado_inicial()
	var q: Dictionary = _sala("F12")
	var r1: Respiradero3D = q["r1"]
	var r2: Respiradero3D = q["r2"]
	var placa: Pulsador3D = q["placa"]
	var j: Jugador3D = jugador as Jugador3D
	await _preparar_j(Vector2i(28, 17), Vector3(0.0, 0.0, 1.0))
	var rec: Dictionary = _vigilar_respiraderos(r1, r2)
	var ev: Dictionary = {"prende1": [], "prende2": [], "apaga1": [], "apaga2": []}      # cuándo prende y cuándo se apaga la llama de cada reja
	r1.prende.connect(func() -> void: (ev["prende1"] as Array).append(reloj.t))
	r2.prende.connect(func() -> void: (ev["prende2"] as Array).append(reloj.t))
	r1.se_apaga_llama.connect(func() -> void: (ev["apaga1"] as Array).append(reloj.t))
	r2.se_apaga_llama.connect(func() -> void: (ev["apaga2"] as Array).append(reloj.t))
	var t0: float = reloj.t
	while (reloj.t - t0 < 16.0) and ((rec["r1"] as Array).is_empty() or (rec["r2"] as Array).is_empty()):
		await process_frame
	var t_exh: float = reloj.t - t0
	_ok("F12.4 los dos respiraderos exhalan (a los %.1f s) y sale una nube de veneno de cada uno, de 1 casilla, que se consume en %.1f s al arder y avisa a su reja" % [t_exh, r1.quema_s],
		r1.ultima != null and r2.ultima != null and is_instance_valid(r1.ultima) and is_instance_valid(r2.ultima) and r1.ultima.radio == 1.0 and r2.ultima.vida_max == 9.0 and NubeVeneno3D.cubre(Vector2i(28, 19)) and NubeVeneno3D.cubre(Vector2i(28, 21))
		and r1.ultima.consume_propio_s == 0.5 and r1.ultima.respiradero == r1 and r2.ultima.respiradero == r2)
	_ok("F12.5 las dos nubes cubren casi todo el pasillo (%d de 5 casillas)" % _nubes_en_pasillo(), _nubes_en_pasillo() >= 4)
	# 1 · Fuego a la niebla recién exhalada: PRENDE EL GAS. (18/11, arreglo de F12) ANTES la nube se consumía en 4 s (la fila `veneno` de la tabla) y la reja no hacía nada: ahora 0,5 s y las dos rejas arden 6 s.
	_ok("F12.7 fuego + flecha a la niebla sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(28, 19), Vector2i(28, 17)))
	var tf: float = reloj.t
	while reloj.t - tf < 3.0 and not (r1.ardiendo and r2.ardiendo):      # la flecha tarda en llegar a la nube
		await process_frame
	await avanzar_s(0.1)
	_ok("F12.8 el fuego prende el gas de las dos rejas (arden: `prende`) y sus nubes arden", r1.ardiendo and r2.ardiendo and (r1.ultima.ardiendo or not is_instance_valid(r1.ultima)) and (r2.ultima.ardiendo or not is_instance_valid(r2.ultima)) and (ev["prende1"] as Array).size() == 1)
	var t_prende: float = float((ev["prende1"] as Array)[0]) if (ev["prende1"] as Array).size() > 0 else reloj.t
	var n_exh1: int = r1.exhalaciones
	var n_exh2: int = r2.exhalaciones
	var vista: Dictionary = _llama_visible(r1)
	_ok("F12.8b se ve: llama pequeña (visible), de rojo-naranja (nunca amarilla), y la luz cálida en vez de la verde", vista["ok"], str(vista))
	while reloj.t - t_prende < 3.0 and _nubes_en_pasillo() > 0:
		await process_frame
	var t_limpio: float = reloj.t
	_ok("F12.9 la nube desaparece a los %.2f s de prender (≤ 0,6 s; antes 4 s) y el pasillo queda limpio" % (t_limpio - t_prende), _nubes_en_pasillo() == 0 and t_limpio - t_prende <= 0.6)
	# 2 · Cruzar con el gas prendido: las rejas no exhalan mientras arden.
	# La propia flecha de fuego deja una zona de llamas en el punto de impacto (`Lanzador3D.ZonaV2`, pulsos de plasma): quema a la lanzadora que se queda dentro (fuego amigo, no es el gas). Se espera a que se acabe
	# (si no, cruzar justo después hiere) y se cruza deprisa: la llama de la reja dura 6 s.
	var t_zona: float = reloj.t
	while reloj.t - t_zona < 8.0 and _zonas_vivas() > 0:
		await avanzar(3)
	var t_zona_fin: float = reloj.t - t_prende
	var vida1: float = j.vida
	var traza: String = ""
	var t_cruce0: float = reloj.t
	for y in [18, 19, 20, 21, 22, 23]:
		colocar_jugador(Vector2i(28, y))
		await avanzar_s(0.2)
		traza += " y%d:%.0f/v%.1f" % [y, j.vida, float(j.get("_veneno_t"))]
	traza += " | zona de llamas de la flecha viva hasta %.1f s tras prender; cruce %.1f–%.1f s" % [t_zona_fin, t_cruce0 - t_prende, reloj.t - t_prende]
	_ok("F12.10 con las dos rejas ardiendo (%.1f s desde que prendieron) se cruza el pasillo entero hasta la placa (28,23) sin veneno y sin que exhalen" % (reloj.t - t_prende), r1.ardiendo and r2.ardiendo and placa.activo and r1.exhalaciones == n_exh1 and r2.exhalaciones == n_exh2 and j.vida >= vida1 - 0.01 and float(j.get("_veneno_t")) <= 0.0, "vida %.1f→%.1f%s" % [vida1, j.vida, traza])
	_ok("F12.11 ni exhala ni avisa mientras arde (`en_aviso` falso, ninguna nube en el pasillo)", not r1.en_aviso and not r2.en_aviso and _nubes_en_pasillo() == 0)
	# 3 · El agua sobre una reja ARDIENDO apaga la llama y la deja atascada 8 s.
	var n_antes: int = r1.exhalaciones
	_ok("F12.12 agua + flecha a la reja de (28,19), que aún arde, sale (arde desde hace %.1f s)" % (reloj.t - t_prende), r1.ardiendo and lanzar_a_celda("agua", ["flecha"], Vector2i(28, 19), Vector2i(28, 17)))
	await avanzar_s(1.0)
	_ok("F12.13 queda atascada (no exhala), con la llama fuera (`se_apaga_llama`: %d vez) " % (ev["apaga1"] as Array).size(), not r1.activo and not r1.ardiendo and r1.exhalaciones == n_antes and (ev["apaga1"] as Array).size() == 1 and not (r1.get_node("Llama") as Node3D).visible)
	await avanzar_s(6.5)
	_ok("F12.14 … sigue atascado 7,5 s después (el otro respiradero sí sigue a lo suyo: %d exhalaciones más)" % (r2.exhalaciones - n_exh2), not r1.activo and r1.exhalaciones == n_antes)
	await avanzar_s(1.5)
	_ok("F12.15 … y a los 8 s se destapa", r1.activo)
	# 4 · Sin quemar: la nube envenena de verdad (se espera a la siguiente exhalación del respiradero que sigue activo).
	var n_r2: int = r2.exhalaciones
	var tw: float = reloj.t
	while reloj.t - tw < 12.0 and r2.exhalaciones == n_r2:
		await process_frame
	colocar_jugador(Vector2i(28, 21))
	var vida0: float = j.vida
	await avanzar_s(2.0)
	var veneno: float = float(j.get("_veneno_t"))
	_ok("F12.6 quien entra en la niebla se envenena (la nube lo cuenta %d veces; pierde %.1f de vida)" % [r2.ultima.envenenadas, vida0 - j.vida], r2.ultima.envenenadas > 0 and (veneno > 0.0 or j.vida < vida0))
	var a2: Array = ev["apaga2"]
	var e2: Array = rec["r2"]
	var dur_llama: float = float(a2[0]) - float((ev["prende2"] as Array)[0]) if a2.size() > 0 and (ev["prende2"] as Array).size() > 0 else -1.0
	var hasta_exhalar: float = float(e2.back()) - float(a2[0]) if a2.size() > 0 else -1.0
	_ok("F12.14b la reja de (28,21) ardió %.1f s (arde=6), se apagó la llama (`se_apaga_llama`) y volvió a su ciclo DESDE 0: exhaló %.1f s después (cada 10)" % [dur_llama, hasta_exhalar],
		a2.size() == 1 and absf(dur_llama - r2.arde_s) <= 0.15 and absf(hasta_exhalar - r2.cada) <= 0.15 and not r2.ardiendo)
	await _f12_fuego_directo_y_nube_normal()


## Una nube NORMAL (no de respiradero) y el fuego directo a una reja sin nube, con el laboratorio recargado.
func _f12_fuego_directo_y_nube_normal() -> void:
	await _recargar_lab()
	var q: Dictionary = _sala("F12")
	var r1: Respiradero3D = q["r1"]
	var r2: Respiradero3D = q["r2"]
	var j: Jugador3D = jugador as Jugador3D
	var apaga: Array = []
	r1.se_apaga_llama.connect(func() -> void: apaga.append(reloj.t))
	# (el velo de precalentado deja correr un rato de juego al cargar, y a 20 fps ya pudo exhalar: se quitan las nubes que haya)
	for n in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(n):
			(n as NubeVeneno3D).retirar()
	r1._t = r1.cada - 3.0        # a la reja de (28,19) le tocaría exhalar a los 3 s (sin nube viva suya ahora); la otra, lejos de exhalar
	r2._t = 0.0
	await _preparar_j(Vector2i(28, 17), Vector3(0.0, 0.0, 1.0))
	var n0: int = r1.exhalaciones
	_ok("F12.30 la reja de (28,19) no tiene nube viva ni arde, y le faltan unos 3 s para exhalar", not is_instance_valid(r1.ultima) and not r1.ardiendo and NubeVeneno3D.vivas.is_empty() and r1.cada - r1._t > 2.0)
	_ok("F12.31 fuego + flecha a la reja (sin nube) sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(28, 19), Vector2i(28, 17)))
	var tf: float = reloj.t
	while reloj.t - tf < 3.0 and not r1.ardiendo:
		await process_frame
	await avanzar_s(0.1)
	var vista: Dictionary = _llama_visible(r1)
	_ok("F12.32 el fuego directo a la reja sin nube la prende igual: arde y se ve la llama", r1.ardiendo and vista["ok"] and r1.exhalaciones == n0 and not r2.ardiendo, str(vista))
	# Dejar pasar lo que le tocaría exhalar si no ardiera (a los ~3 s de arrancar: ya pasaron 0,5 + las del aviso): ardiendo no sale nada.
	await avanzar_s(3.0)
	_ok("F12.33 ardiendo no exhala aunque le tocara (le faltaban 3 s para exhalar y ya pasaron %.1f desde el arranque)" % (3.5 + 0.3), r1.exhalaciones == n0 and not is_instance_valid(r1.ultima) and r1.ardiendo)
	var t_ard: float = reloj.t
	var t_fin: float = reloj.t
	while reloj.t - t_ard < 8.0 and r1.ardiendo:
		await process_frame
	t_fin = reloj.t
	_ok("F12.34 la llama se acaba (%d `se_apaga_llama`) y no hubo veneno entre medias" % apaga.size(), not r1.ardiendo and apaga.size() == 1 and r1.exhalaciones == n0, "ardió %.1f s más desde F12.23" % (t_fin - t_ard))
	# Una nube de veneno NORMAL (como la del chamán o la pieza `nube_veneno`): el fuego la consume en `consume_s` de la tabla (4 s), no en 0,5 s. Lejos de los respiraderos (sala F10).
	var fila: Dictionary = BD.estado_mundo("veneno")
	var consume: float = float(fila.get("consume_s", 4))
	var nube: NubeVeneno3D = NubeVeneno3D.crear(maqueta, Terreno3D.centro_de(Vector2i(20, 13), Terreno3D.y_pies(Vector2i(20, 13))), 20.0, 1.0)
	_ok("F12.35 una nube normal no lleva tiempo propio ni reja (consume_propio_s %.1f)" % nube.consume_propio_s, nube.consume_propio_s < 0.0 and nube.respiradero == null)
	await _preparar_j(Vector2i(20, 15), Vector3(0.0, 0.0, -1.0))
	_ok("F12.36 fuego + flecha a la nube normal sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(20, 13), Vector2i(20, 15)))
	var t_a: float = -1.0
	var t_d: float = -1.0
	var tt: float = reloj.t
	while reloj.t - tt < 10.0 and t_d < 0.0:
		await process_frame
		if t_a < 0.0 and is_instance_valid(nube) and nube.ardiendo:
			t_a = reloj.t
		if not is_instance_valid(nube) or nube._muerta:
			t_d = reloj.t
	var dt: float = t_d - t_a if t_a >= 0.0 and t_d >= 0.0 else -1.0
	_ok("F12.37 la nube normal tarda %.2f s en consumirse tras arder (tabla: consume_s = %.1f s; la de la reja, 0,5)" % [dt, consume], dt >= consume - 0.3 and dt <= consume + 0.4)


## Cuántas zonas de hechizo con pulsos (llamas de la flecha de fuego...) hay vivas sobre el pasillo de F12 (x = 28, y 18–23). (Las de las trampas de otras salas no cuentan.)
func _zonas_vivas() -> int:
	var n: int = 0
	for z in root.find_children("*", "Node3D", true, false):
		if z is Lanzador3D.ZonaV2 and not (z as Node).is_queued_for_deletion():
			for y in range(18, 24):
				if (z as Lanzador3D.ZonaV2).celdas.has(Vector2i(28, y)):
					n += 1
					break
	return n


## ¿Se ve que arde? La llama es visible, sus lenguas son rojo-naranja (verde ≤ 0,55 y rojo > verde: ninguna amarilla) y la luz es cálida (rojo > verde en vez del verde del gas).
func _llama_visible(r: Respiradero3D) -> Dictionary:
	var llama: Node3D = r.get_node_or_null("Llama") as Node3D
	var luz: OmniLight3D = r.get_node_or_null("Luz") as OmniLight3D
	if llama == null or luz == null:
		return {"ok": false, "motivo": "sin Llama o sin Luz"}
	var colores_ok: bool = llama.get_child_count() >= 3
	for c in llama.get_children():
		var m: StandardMaterial3D = (c as MeshInstance3D).material_override as StandardMaterial3D
		colores_ok = colores_ok and m != null and m.albedo_color.g <= 0.55 and m.albedo_color.r > m.albedo_color.g * 1.8 and m.albedo_color.b < 0.2
	var cal: bool = luz.light_color.r > luz.light_color.g * 1.8 and luz.light_energy > 0.5
	return {"ok": llama.visible and colores_ok and cal, "visible": llama.visible, "lenguas": llama.get_child_count(), "colores_ok": colores_ok, "luz": luz.light_color, "energia": luz.light_energy}


func _esperar_sin_veneno(j: Jugador3D, max_s: float = 6.0) -> void:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and float(j.get("_veneno_t")) > 0.0:
		await process_frame


func _f12_botones() -> void:
	await _f12_estado_inicial()
	var q: Dictionary = _sala("F12")
	var r1: Respiradero3D = q["r1"]
	var r2: Respiradero3D = q["r2"]
	var placa: Pulsador3D = q["placa"]
	var boton: Pulsador3D = q["boton"]
	_ok("F12.20 el botón `!` (30,17) y la placa `@` (28,23) existen", boton != null and placa != null and boton.celda == Vector2i(30, 17) and placa.celda == Vector2i(28, 23))
	await _preparar_j(Vector2i(30, 16), Vector3(0.0, 0.0, 1.0))
	boton.pulsar()
	await avanzar(2)
	var n1: int = r1.exhalaciones
	var n2: int = r2.exhalaciones
	_ok("F12.21 el botón atasca los dos respiraderos", not r1.activo and not r2.activo)
	await avanzar_s(9.0)
	_ok("F12.22 en 9 s no exhalan (y no hay nubes nuevas)", r1.exhalaciones == n1 and r2.exhalaciones == n2)
	await avanzar_s(1.5)
	_ok("F12.23 pasados los 10 s se destapan", r1.activo and r2.activo)
	colocar_jugador(Vector2i(28, 23))
	await avanzar_s(0.5)
	_ok("F12.24 la placa del fondo se pisa", placa.veces == 1 and placa.activo)
