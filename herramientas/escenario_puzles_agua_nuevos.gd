extends "res://herramientas/escenario_base.gd"
## Escenario · los puzles NUEVOS del LABORATORIO DE AGUA (18/11/2026, Juego): Q11 «Dos riegos a la vez» (sala (3,2)) y Q12 «Foso con cofre flotante» (sala (3,3), la fila de salas que se añadió debajo).
## Carga laboratorios/LabPuzlesAgua3D.tscn y los juega por código con las piezas de verdad. Dos pasadas, como los demás escenarios de laboratorio (lo que se abre o se llena no se deshace):
##   · `natural`  (por defecto): la vía de la jugadora (hechizos de agua: flechas y línea).
##   · `botones`  (escenario_puzles_agua_nuevos_botones.gd): el botón `!` y la placa `@`, que separan «falla el agua» de «falla el disparador».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_nuevos.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_nuevos_botones.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"

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
		await _q11_natural()
		await _q12_natural()
	else:
		await _q11_botones()
		await _q12_botones()


# ---------------------------------------------------------------------------------------------------------------------

func _sala(nombre: String) -> Dictionary:
	return lab.call("nuevo", nombre)


# ---------------------------------------------------------------------------------------------------------------------
#  Q11 · Dos riegos a la vez
# ---------------------------------------------------------------------------------------------------------------------

func _q11_estado_inicial() -> void:
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var puerta: Node = q["puerta"]
	_ok("Q11.1 dos pulsadores de AGUA con rearme corto (%.2f s y %.2f s), a 2 casillas en la misma fila, y la puerta cerrada" % [a.rearme, b.rearme],
		a.modo == "agua" and b.modo == "agua" and a.rearme > 0.0 and a.rearme <= 0.5 and b.rearme == a.rearme and a.celda.y == b.celda.y and absi(a.celda.x - b.celda.x) == 2 and not bool(puerta.get("abierta")))


func _q11_natural() -> void:
	await _q11_estado_inicial()
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var control: Pulsador3D = q["control"]
	var puerta: Node = q["puerta"]
	lanzador.tinta = null
	# 1 · Una flecha de agua a A: lo pulsa, pero la puerta no abre (B está libre).
	_ok("Q11.2 agua + flecha a A (desde el sur de su columna) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(26, 19), Vector2i(26, 21)))
	var recarga: float = lanzador.cooldown_left[0]
	await avanzar_s(1.2)
	_ok("Q11.3 A se pulsa y con B libre la puerta sigue cerrada", a.veces == 1 and b.veces == 0 and not bool(puerta.get("abierta")))
	_ok("Q11.4 la página que lanzó queda en recarga %.2f s: otra flecha de la MISMA página no puede salir dentro del rearme (%.2f s)" % [recarga, b.rearme], recarga > b.rearme)
	# 2 · Una flecha de agua a B, un segundo después: A ya se ha rearmado (0,35 s), así que tampoco abre.
	_ok("Q11.5 agua + flecha a B (desde el sur de su columna) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(28, 19), Vector2i(28, 21)))
	await avanzar_s(1.2)
	_ok("Q11.6 B se pulsa, A ya estaba libre otra vez, y la puerta sigue cerrada: dos flechas sueltas no abren", b.veces == 1 and not a.activo and not bool(puerta.get("abierta")))
	# 3 · El botón de control no abre nada.
	_ok("Q11.7 fuego + flecha al botón de control sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(26, 22), Vector2i(26, 20)))
	await avanzar_s(1.2)
	_ok("Q11.8 el botón de control se pulsa con cualquier magia y no abre la puerta", control.veces >= 1 and not bool(puerta.get("abierta")))
	# 4 · Una LÍNEA de agua desde el oeste de la fila los moja a los dos en el mismo golpe.
	colocar_jugador(Vector2i(25, 19))
	await avanzar_s(0.5)
	var va: int = a.veces
	var vb: int = b.veces
	_ok("Q11.9 agua + línea hacia el este sale", lanzar("agua", ["linea_x", "linea_x"], Vector3.RIGHT))
	await avanzar_s(1.0)
	_ok("Q11.10 la línea pulsa A y B en el mismo golpe (pulsaciones +%d y +%d)" % [a.veces - va, b.veces - vb], a.veces == va + 1 and b.veces == vb + 1)
	_ok("Q11.11 … y la puerta se abre", bool(puerta.get("abierta")))


func _q11_botones() -> void:
	await _q11_estado_inicial()
	var q: Dictionary = _sala("Q11")
	var a: Pulsador3D = q["a"]
	var b: Pulsador3D = q["b"]
	var control: Pulsador3D = q["control"]
	var puerta: Node = q["puerta"]
	var placa: Pulsador3D = lab.call("pulsador_en", Vector2i(30, 22)) as Pulsador3D
	_ok("Q11.20 la placa `@` (30,22) existe", placa != null)
	# Sin hechizos: A y, un segundo después, B (A ya se rearmó): no abre.
	a.pulsar()
	await avanzar_s(1.0)
	b.pulsar()
	await avanzar_s(0.5)
	_ok("Q11.21 A y 1 s después B (rearme %.2f s): la puerta sigue cerrada" % a.rearme, a.veces == 1 and b.veces == 1 and not bool(puerta.get("abierta")))
	control.pulsar()
	await avanzar_s(0.5)
	_ok("Q11.22 el botón de control pulsado no abre la puerta", control.veces == 1 and not bool(puerta.get("abierta")))
	colocar_jugador(Vector2i(30, 22))
	await avanzar_s(0.6)
	_ok("Q11.23 la placa abre la puerta", placa.veces == 1 and bool(puerta.get("abierta")))


# ---------------------------------------------------------------------------------------------------------------------
#  Q12 · Foso con cofre flotante
# ---------------------------------------------------------------------------------------------------------------------

const FOSO: Array = [Vector2i(26, 27), Vector2i(26, 28), Vector2i(26, 29), Vector2i(26, 30), Vector2i(27, 30), Vector2i(28, 30), Vector2i(29, 30), Vector2i(30, 30),
	Vector2i(30, 29), Vector2i(30, 28), Vector2i(30, 27), Vector2i(30, 26), Vector2i(29, 26)]
## Casillas por las que se anda en la sala (entrada, pasarela e isla): desde ninguna se alcanza el cofre en reposo con E.
const PISABLES: Array = [Vector2i(28, 25), Vector2i(27, 25), Vector2i(29, 25), Vector2i(30, 25), Vector2i(27, 26), Vector2i(28, 26), Vector2i(27, 27), Vector2i(28, 27), Vector2i(29, 27),
	Vector2i(27, 28), Vector2i(28, 28), Vector2i(29, 28), Vector2i(27, 29), Vector2i(28, 29), Vector2i(29, 29)]


func _puzle3d() -> Puzle3D:
	return lab.get("_puzle_nodo") as Puzle3D


func _foso_max() -> float:
	var m: float = 0.0
	for c in FOSO:
		m = maxf(m, Terreno3D.agua_sim.profundidad_casilla(c as Vector2i))
	return m


func _foso_min() -> float:
	var m: float = INF
	for c in FOSO:
		m = minf(m, Terreno3D.agua_sim.profundidad_casilla(c as Vector2i))
	return m


## Abre un cofre como la jugadora (E): reintenta cada 0,2 s mientras aún está apareciendo y espera a que acabe de abrirse (el botín se da al terminar).
func _abrir_cofre(cofre: Variant, max_s: float = 6.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and not bool(cofre.get("es_abierto")):
		cofre.call("abrir")
		await avanzar_s(0.2)
	return bool(cofre.get("es_abierto"))


func _q12_estado_inicial() -> void:
	var q: Dictionary = _sala("Q12")
	var balsa: Balsa3D = q["balsa"]
	var cofre: Variant = q["cofre"]
	_ok("Q12.1 la balsa descansa en (26,30), con una ruta de %d casillas hasta el muelle (29,26); el foso (13 casillas) está seco" % balsa.ruta.size(),
		balsa.celda_actual() == Vector2i(26, 30) and balsa.ruta.size() == 10 and balsa.ruta.back() == Vector2i(29, 26) and not balsa.flota and not balsa.atracada and _foso_max() == 0.0)
	_ok("Q12.2 el cofre va encima de la balsa (hijo suyo), abajo, en el fondo del foso (%.2f u bajo el suelo)" % (Terreno3D.y_pies(Vector2i(28, 26)) - (cofre as Node3D).global_position.y),
		(cofre as Node3D).get_parent() == balsa and (cofre as Node3D).global_position.y < Terreno3D.y_pies(Vector2i(28, 26)) - 0.5)
	var cerca: float = INF
	for c in PISABLES:
		cerca = minf(cerca, Vector2(Terreno3D.centro_de(c as Vector2i, 0.0).x - (cofre as Node3D).global_position.x, Terreno3D.centro_de(c as Vector2i, 0.0).z - (cofre as Node3D).global_position.z).length())
	_ok("Q12.3 en reposo el cofre queda LEJOS: la casilla de la sala más cercana está a %.2f u y E alcanza %.1f u" % [cerca, Puzle3D.ALCANCE_COFRE], cerca > Puzle3D.ALCANCE_COFRE)
	_ok("Q12.4 y está SELLADO (abre_si = balsa atracada): E no lo abre", bool(cofre.get("es_cerrado")) and not bool(cofre.call("sellado_cumplido")) and not bool(cofre.call("abrir")))
	var muelle: float = Vector2(Terreno3D.centro_de(Vector2i(29, 26), 0.0).x - Terreno3D.centro_de(Vector2i(28, 26), 0.0).x, Terreno3D.centro_de(Vector2i(29, 26), 0.0).z - Terreno3D.centro_de(Vector2i(28, 26), 0.0).z).length()
	_ok("Q12.5 el muelle (29,26) queda pegado a la pasarela (28,26): a %.2f u, dentro del alcance de E" % muelle, muelle <= Puzle3D.ALCANCE_COFRE)


func _q12_natural() -> void:
	await _q12_estado_inicial()
	var q: Dictionary = _sala("Q12")
	var balsa: Balsa3D = q["balsa"]
	var cofre: Variant = q["cofre"]
	lanzador.tinta = null
	var y_reposo: float = balsa.global_position.y
	await avanzar_s(4.0)
	_ok("Q12.6 con el foso vacío la balsa no se mueve (4 s)", not balsa.flota and balsa.indice == 0 and absf(balsa.global_position.y - y_reposo) < 0.02)
	# La vía: agua a la tinaja, desde la casilla del este de su fila.
	_ok("Q12.7 agua + flecha a la tinaja (27,25) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(27, 25), Vector2i(29, 25)))
	var r: Dictionary = {"t_agua": -1.0, "t_flota": -1.0, "t_atraca": -1.0, "sellado_en_ruta": true, "vio_ruta": false, "prof_flota": 0.0, "y_flota": 0.0, "min_prof_ruta": INF}
	var t0: float = reloj.t
	await avanzar_vigilando(150.0, 0.5, func(t: float) -> void:
		if float(r["t_agua"]) < 0.0 and _foso_max() > 0.02:
			r["t_agua"] = t
		if float(r["t_flota"]) < 0.0 and balsa.flota:
			r["t_flota"] = t
			r["prof_flota"] = Terreno3D.agua_sim.profundidad_casilla(balsa.celda_actual())
		if balsa.flota and balsa.indice > 0 and not balsa.atracada:
			r["vio_ruta"] = true
			r["y_flota"] = maxf(float(r["y_flota"]), balsa.global_position.y - y_reposo)
			r["min_prof_ruta"] = minf(float(r["min_prof_ruta"]), Terreno3D.agua_sim.profundidad_casilla(balsa.celda_actual()))
			if bool(cofre.call("sellado_cumplido")):
				r["sellado_en_ruta"] = false
		if float(r["t_atraca"]) < 0.0 and balsa.atracada:
			r["t_atraca"] = t
	)
	_ok("Q12.8 el agua de la tinaja llega al foso (a los %.1f s)" % float(r["t_agua"]), float(r["t_agua"]) > 0.0)
	_ok("Q12.9 la balsa empieza a FLOTAR cuando el agua de su casilla llega a %.2f u (a los %.1f s, con %.2f u)" % [balsa.calado, float(r["t_flota"]), float(r["prof_flota"])], float(r["t_flota"]) > 0.0 and float(r["prof_flota"]) >= balsa.calado - 0.01)
	_ok("Q12.10 flotando SUBE con el agua (%.2f u sobre el fondo) y DERIVA por el foso" % float(r["y_flota"]), bool(r["vio_ruta"]) and float(r["y_flota"]) > 0.1)
	_ok("Q12.11 mientras deriva el cofre sigue sellado", bool(r["sellado_en_ruta"]) and bool(r["vio_ruta"]))
	_ok("Q12.12 en la ruta siempre hubo agua de calado bajo la balsa (mínimo %.2f u)" % float(r["min_prof_ruta"]), float(r["min_prof_ruta"]) >= balsa.calado * 0.5)
	_ok("Q12.13 la balsa ATRACA en el muelle (29,26) a los %.1f s (%.1f s de deriva)" % [float(r["t_atraca"]), float(r["t_atraca"]) - float(r["t_flota"])], float(r["t_atraca"]) > 0.0 and balsa.atracada and balsa.celda_actual() == Vector2i(29, 26))
	var celda_cofre: Vector2i = cofre.get("celda")
	colocar_jugador(Vector2i(28, 26))
	await avanzar_s(0.5)
	var d: float = ((cofre as Node3D).global_position - jugador.global_position).length()
	_ok("Q12.14 el cofre queda en el muelle (casilla %s, a %.2f u de la jugadora en la pasarela) y deja de estar sellado" % [str(celda_cofre), Vector2((cofre as Node3D).global_position.x - jugador.global_position.x, (cofre as Node3D).global_position.z - jugador.global_position.z).length()],
		celda_cofre == Vector2i(29, 26) and bool(cofre.call("sellado_cumplido")) and Vector2((cofre as Node3D).global_position.x - jugador.global_position.x, (cofre as Node3D).global_position.z - jugador.global_position.z).length() <= Puzle3D.ALCANCE_COFRE, "3D %.2f" % d)
	var oro0: int = Estado.i().oro
	var abierto: bool = await _abrir_cofre(cofre)
	_ok("Q12.15 se abre con E desde la pasarela y da su botín (40 de oro)", abierto and Estado.i().oro - oro0 == 40, "oro +%d" % (Estado.i().oro - oro0))


func _q12_botones() -> void:
	await _q12_estado_inicial()
	var q: Dictionary = _sala("Q12")
	var balsa: Balsa3D = q["balsa"]
	var boton: Pulsador3D = q["boton"]
	var placa: Pulsador3D = q["placa"]
	_ok("Q12.20 el botón `!` (29,25) y la placa `@` (30,25) existen", boton != null and placa != null and boton.celda == Vector2i(29, 25) and placa.celda == Vector2i(30, 25))
	boton.pulsar()
	var r: Dictionary = {"t_agua": -1.0, "t_flota": -1.0}
	await avanzar_vigilando(90.0, 0.5, func(t: float) -> void:
		if float(r["t_agua"]) < 0.0 and _foso_max() > 0.02:
			r["t_agua"] = t
		if float(r["t_flota"]) < 0.0 and balsa.flota:
			r["t_flota"] = t
	)
	_ok("Q12.21 el botón moja la tinaja: llega agua al foso (a los %.1f s) y la balsa flota (a los %.1f s)" % [float(r["t_agua"]), float(r["t_flota"])], float(r["t_agua"]) > 0.0 and float(r["t_flota"]) > 0.0)
	colocar_jugador(Vector2i(30, 25))
	await avanzar_s(0.5)
	var regla: Variant = _puzle3d().puzle("q12_moja_placa")
	_ok("Q12.22 la placa dispara su regla (moja la tinaja)", placa.veces == 1 and regla != null and int(regla["veces"]) == 1)
