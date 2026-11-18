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
	_ok("F12.2 cada uno exhala cada %.0f s una nube de %.0f s y %.0f casilla de radio; los separa 1 s de desfase; no bloquean su casilla" % [r1.cada, r1.vida, r1.radio],
		r1.cada == 10.0 and r1.vida == 8.0 and r1.radio == 1.0 and absf(r1.desfase_s - r2.desfase_s - 1.0) < 0.01 and not Terreno3D.bloqueada(r1.celda) and not Terreno3D.bloqueada(r2.celda))
	_ok("F12.3 de serie casi siempre hay nube: %.0f s de vida de cada %.0f s (solo %.0f s limpios)" % [r1.vida, r1.cada, r1.cada - r1.vida], r1.cada - r1.vida <= 2.5)


func _f12_natural() -> void:
	await _f12_estado_inicial()
	var q: Dictionary = _sala("F12")
	var r1: Respiradero3D = q["r1"]
	var r2: Respiradero3D = q["r2"]
	var placa: Pulsador3D = q["placa"]
	var j: Jugador3D = jugador as Jugador3D
	await _preparar_j(Vector2i(28, 17), Vector3(0.0, 0.0, 1.0))
	var rec: Dictionary = _vigilar_respiraderos(r1, r2)
	var t0: float = reloj.t
	while (reloj.t - t0 < 16.0) and ((rec["r1"] as Array).is_empty() or (rec["r2"] as Array).is_empty()):
		await process_frame
	var t_exh: float = reloj.t - t0
	_ok("F12.4 los dos respiraderos exhalan (a los %.1f s) y sale una nube de veneno de cada uno, de 1 casilla" % t_exh,
		r1.ultima != null and r2.ultima != null and is_instance_valid(r1.ultima) and is_instance_valid(r2.ultima) and r1.ultima.radio == 1.0 and r2.ultima.vida_max == 8.0 and NubeVeneno3D.cubre(Vector2i(28, 19)) and NubeVeneno3D.cubre(Vector2i(28, 21)))
	_ok("F12.5 las dos nubes cubren casi todo el pasillo (%d de 5 casillas)" % _nubes_en_pasillo(), _nubes_en_pasillo() >= 4)
	# 1 · Fuego a la niebla recién exhalada: se consume en unos 4 s.
	_ok("F12.7 fuego + flecha a la niebla sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(28, 19), Vector2i(28, 17)))
	var t_fuego: float = reloj.t
	await avanzar_s(1.0)
	_ok("F12.8 el fuego prende las dos nubes (arden y se consumen en 1,5 casillas)", (r1.ultima.ardiendo or not is_instance_valid(r1.ultima)) and (r2.ultima.ardiendo or not is_instance_valid(r2.ultima)))
	var n_exh1: int = r1.exhalaciones
	var n_exh2: int = r2.exhalaciones
	while reloj.t - t_fuego < 9.0 and _nubes_en_pasillo() > 0:
		await process_frame
	var t_limpio: float = reloj.t
	_ok("F12.9 el pasillo queda limpio a los %.1f s del fuego (la nube vivía 8 s, quemada 4)" % (t_limpio - t_fuego), _nubes_en_pasillo() == 0 and t_limpio - t_fuego <= 5.5)
	# 2 · El hueco: cruzar con la niebla quemada, antes de la siguiente exhalación.
	var vida1: float = j.vida
	var hueco: float = minf(float(r1.cada) - r1._t, float(r2.cada) - r2._t)       # lo que falta para la próxima exhalación (la primera de las dos)
	for y in [18, 19, 20, 21, 22, 23]:
		colocar_jugador(Vector2i(28, y))
		await avanzar_s(0.35)
	_ok("F12.10 en el hueco (%.1f s hasta la siguiente exhalación) se cruza el pasillo entero hasta la placa (28,23) sin veneno" % hueco, placa.activo and r1.exhalaciones == n_exh1 and r2.exhalaciones == n_exh2 and j.vida >= vida1 - 0.01 and float(j.get("_veneno_t")) <= 0.0, "vida %.1f→%.1f" % [vida1, j.vida])
	_ok("F12.11 el hueco que abre quemar es mayor que el natural: %.1f s frente a %.0f s" % [hueco, r1.cada - r1.vida], hueco + (reloj.t - t_limpio) >= 3.0)
	# 3 · El agua atasca una reja 8 s (se le tira con el pasillo aún limpio: con la nube delante, la nube se traga la flecha).
	var n_antes: int = r1.exhalaciones
	_ok("F12.12 agua + flecha al respiradero de (28,19) sale (a %.1f s de la siguiente exhalación)" % (r1.cada - r1._t), lanzar_a_celda("agua", ["flecha"], Vector2i(28, 19), Vector2i(28, 17)))
	await avanzar_s(1.0)
	_ok("F12.13 queda atascado (no exhala)", not r1.activo and r1.exhalaciones == n_antes)
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
