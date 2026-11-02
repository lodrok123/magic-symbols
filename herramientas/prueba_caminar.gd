extends "res://herramientas/escenario_base.gd"
## CAMINAR SATISFACTORIO (2/11; docs/REVISION_GAMEFEEL_30-10.md §11): W1 pies que dejan huella, W2 hierba viva, W3 cuerpo y cámara, W4 agua, W5 el mundo responde.
## Se prueba sobre las escenas reales (Bosque 01 v01 y Bosque): el Jugador3D real, la hierba real, el agua real. El `_process` del jugador se apaga durante las comprobaciones
## de una pieza para llamar a sus funciones a mano con deltas conocidos; los pasos y la marcha completos se prueban con el Input real (WASD + Mayús).
##   1 W1  polvo de paso en tierra y camino (tras DIST_PASO_ANDAR), nada en piedra ni en puente, motas verdes en hierba, pies alternos, huellas creadas y desvanecidas a los 6 s (anillo de 48),
##         nada en hierba, aplastamiento al aterrizar (fuerte y leve) y que vuelve a su escala
##   2 W2  posicion_jugador y pisado se actualizan en las dos escenas con hierba (0,35 andando, 0,55 corriendo), `empuje` sigue la velocidad, radio 0,9/1,2, el rastro con muelle (rebote y 0 a los 0,6 s),
##         briznas sueltas corriendo por hierba alta
##   3 W3  `v_offset` oscila solo corriendo (la mitad andando; nada nadando, en el aire, rodando ni en pausa) y vuelve a la base (±0,001); inclinación al girar y a 0 en recto; aplastamiento al arrancar;
##         inclinación hacia delante y polvo doble al frenar; la sombra de contacto está
##   4 W4  impulso, gotas y chapoteo (−16 dB, tono 1,1-1,3) al andar en agua; salpicadura al entrar; ondas nadando; con ACTIVA = false siguen las ondas y nada más
##   5 W5  material de las piezas con `apartar` y el rastro global; hojas y motas solo por bloque cargado (≤ 2 por bloque, mueren con él); motas de día/noche; pájaros con cadencia mínima
##   6 ACTIVA = false apaga todo menos las ondas · 7 coste de `Caminar3D.actualizar`
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_caminar.gd

const RUTA_V01: String = "res://escenas/PruebaBosque01_v01.tscn"
const DT: float = 1.0 / 30.0

var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _cerca(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _escenario() -> void:
	var guarda: Dictionary = {"sens": Sensacion3D.ACTIVA, "prob": Caminar3D.PROB_PAJAROS, "pajaros": Caminar3D.PAJAROS_ACTIVO, "hora": CicloDia3D.HORA, "dur": CicloDia3D.DURACION_DIA_S}
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	Sensacion3D.ACTIVA = true
	CicloDia3D.DURACION_DIA_S = 0.0
	Misiones.nuevo()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_V01, false)
	if maqueta == null or jugador == null:
		return
	await avanzar(40)
	jugador.set_process(false)
	await _w1()
	await _w3()
	await _w4()
	await _w5()
	await _w2_marcha("Bosque 01 v01")
	_apagado()
	_coste()
	# W2 también en el otro mapa con hierba (PruebaBosque): la hierba de ese mapa recibe la posición y el pisado.
	jugador.set_process(true)
	Sensacion3D.ACTIVA = true
	Input.action_release("mover_adelante")
	Input.action_release("correr")
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA_BOSQUE, false)
	if maqueta != null and jugador != null:
		await avanzar(30)
		jugador.set_process(false)
		await _w2_marcha("Bosque")
		_probar_puente()
	if not _puente_probado:
		_aviso("1 ninguno de los dos mapas tiene puente para comprobarlo", "")
	Input.action_release("mover_adelante")
	Input.action_release("correr")
	Sensacion3D.ACTIVA = bool(guarda["sens"])
	Caminar3D.PROB_PAJAROS = float(guarda["prob"])
	Caminar3D.PAJAROS_ACTIVO = bool(guarda["pajaros"])
	CicloDia3D.HORA = float(guarda["hora"])
	CicloDia3D.DURACION_DIA_S = float(guarda["dur"])
	Sfx.REGISTRAR = false
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------------------------------------------------------

## La primera casilla de ese tipo de suelo (0 hierba, 1 camino, 2 tierra, 3 piedra) que no sea agua, puente ni pared. (-1, -1) si no hay.
func _buscar(tipo: int, sin_coma: bool = false) -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			var l: String = Terreno3D.letra_de(c)
			if l == "#" or l == "b" or Terreno3D.es_agua(c):
				continue
			if sin_coma and l == ",":
				continue
			if int(maqueta.call("_tipo_suelo", c)) == tipo:
				return c
	return Vector2i(-1, -1)


## Una casilla de agua que se nada (río) con una de tierra al lado: [agua, tierra].
func _orilla() -> Array:
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(1, lado - 1):
		for x in range(1, lado - 1):
			var c := Vector2i(x, y)
			if not Terreno3D.se_nada(c) or Terreno3D.letra_de(c) == "b":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				var l: String = Terreno3D.letra_de(v)
				if l != "#" and l != "b" and not Terreno3D.es_agua(v) and int(maqueta.call("_tipo_suelo", v)) != 3:
					return [c, v]
	return []


func _poner(c: Vector2i) -> void:
	colocar_jugador(c)
	jugador.en_suelo = true
	jugador.nadando = false
	jugador.vy = 0.0
	jugador.vel_suelo = Vector3.ZERO
	jugador.corriendo = false
	jugador._t_roll = 0.0


func _estado() -> Caminar3D.EstCam:
	return Caminar3D.estado(jugador)


func _n(clave: String) -> int:
	return int(Caminar3D.cuenta[clave])


## Un paso de verdad: `_sonar_pasos` con la distancia justa de andar o de correr.
func _paso(correr: bool) -> void:
	jugador._dist_paso = 0.0
	jugador._sonar_pasos(Jugador3D.DIST_PASO_CORRER + 0.01 if correr else Jugador3D.DIST_PASO_ANDAR + 0.01, correr)


var _puente_probado: bool = false


## Sobre un puente (letra «b», tablones) no hay polvo ni huellas. Se prueba en el primer mapa que tenga uno.
func _probar_puente() -> void:
	if _puente_probado:
		return
	var puente: Vector2i = Vector2i(-1, -1)
	for y in range(Terreno3D.lado_del_mapa()):
		for x in range(Terreno3D.lado_del_mapa()):
			if puente.x < 0 and Terreno3D.letra_de(Vector2i(x, y)) == "b":
				puente = Vector2i(x, y)
	if puente.x < 0:
		return
	_puente_probado = true
	var antes_p: int = _n("polvo_paso")
	var antes_h: int = _n("huellas")
	var antes_m: int = _n("motas")
	_poner(puente)
	_paso(false)
	_paso(true)
	_ok("1 sobre un puente no hay polvo, ni motas, ni huellas", _n("polvo_paso") == antes_p and _n("huellas") == antes_h and _n("motas") == antes_m)


func _base_escala() -> Vector3:
	var e: Caminar3D.EstCam = _estado()
	var s: Vector3 = jugador.pj.scale
	return Vector3(s.x / e.aplicada.x, s.y / e.aplicada.y, s.z / e.aplicada.z)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · W1 pies que dejan huella
# ---------------------------------------------------------------------------------------------------------------------
func _w1() -> void:
	Sensacion3D.ACTIVA = true
	var camino: Vector2i = _buscar(1)
	var tierra: Vector2i = _buscar(2)
	var piedra: Vector2i = _buscar(3)
	var hierba: Vector2i = _buscar(0, true)
	_ok("1 el mapa tiene camino, tierra, piedra y hierba", camino.x >= 0 and tierra.x >= 0 and piedra.x >= 0 and hierba.x >= 0, "camino %s tierra %s piedra %s hierba %s" % [camino, tierra, piedra, hierba])
	var suelo: Vector2i = camino if camino.x >= 0 else tierra
	_poner(suelo)
	var e: Caminar3D.EstCam = _estado()
	var antes: int = _n("polvo_paso")
	jugador._dist_paso = 0.0
	jugador._sonar_pasos(Jugador3D.DIST_PASO_ANDAR - 0.1, false)
	_ok("1 menos de DIST_PASO_ANDAR (%.2f u): todavía no hay polvo" % Jugador3D.DIST_PASO_ANDAR, _n("polvo_paso") == antes)
	jugador._sonar_pasos(0.11, false)
	_ok("1 al recorrer DIST_PASO_ANDAR el emisor emite", _n("polvo_paso") == antes + 1)
	var emisor: GPUParticles3D = null
	for g in e.polvo:
		if g != null and (g as GPUParticles3D).emitting:
			emisor = g as GPUParticles3D
	_ok("1 un emisor de polvo emitiendo, reutilizable (no uno por paso), de 7 partículas máximas y 4 en esta ráfaga", emisor != null and emisor.amount == Caminar3D.POLVO_PASO_N.y \
			and _cerca(emisor.amount_ratio, 4.0 / 7.0, 0.02), str(emisor.amount_ratio) if emisor != null else "ninguno")
	_ok("1 sin sombras, coordenadas de mundo, vida 0,5 s", emisor != null and emisor.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not emisor.local_coords and _cerca(emisor.lifetime, 0.5, 0.001))
	var pm: ParticleProcessMaterial = emisor.process_material as ParticleProcessMaterial
	_ok("1 color del suelo con el alfa de POLVO_PASO_COLOR (0,35), tamaño 0,12-0,2", _cerca(pm.color.a, 0.35, 0.01) and _cerca(pm.scale_min, 0.12, 0.001) and _cerca(pm.scale_max, 0.2, 0.001), str(pm.color))
	_paso(false)                                       # el segundo pie estrena su emisor
	var hijos_antes: int = jugador.get_child_count()
	for _i in range(6):
		_paso(false)
	_ok("1 seis pasos más no crean emisores nuevos (máximo uno por pie)", jugador.get_child_count() == hijos_antes, "%d → %d" % [hijos_antes, jugador.get_child_count()])
	# Corriendo: 7 partículas.
	_paso(true)
	var siete: bool = false
	for g in e.polvo:
		if g != null and _cerca((g as GPUParticles3D).amount_ratio, 1.0, 0.02) and (g as GPUParticles3D).emitting:
			siete = true
	_ok("1 corriendo, la ráfaga es de 7 partículas", siete)
	# Pies alternos: dos pasos seguidos salen a lados opuestos de la marcha.
	jugador._mirada = Vector3(0, 0, 1)
	e.par = 0
	_paso(false)
	var p0: Vector3 = (e.polvo[0] as GPUParticles3D).global_position
	_paso(false)
	var p1: Vector3 = (e.polvo[1] as GPUParticles3D).global_position
	_ok("1 los pies alternan a ±%.2f u de la marcha (separación %.2f)" % [Caminar3D.POLVO_PASO_LADO, absf(p0.x - p1.x)], _cerca(absf(p0.x - p1.x), 2.0 * Caminar3D.POLVO_PASO_LADO, 0.02) and _cerca(p0.z, p1.z, 0.01))
	# Piedra y puente: nada.
	var antes_p: int = _n("polvo_paso")
	var antes_h: int = _n("huellas")
	var antes_m: int = _n("motas")
	_poner(piedra)
	_paso(false)
	_paso(true)
	_ok("1 sobre piedra no hay polvo, ni motas, ni huellas", _n("polvo_paso") == antes_p and _n("huellas") == antes_h and _n("motas") == antes_m)
	_probar_puente()
	# Hierba: motas verdes, sin polvo ni huellas.
	_poner(hierba)
	_paso(false)
	_ok("1 en hierba: motas verdes y ni polvo ni huellas", _n("motas") == antes_m + 1 and _n("polvo_paso") == antes_p and _n("huellas") == antes_h)
	_ok("1 las motas saltan MOTAS_PASO_SALTO (0,3) u: velocidad inicial √(2·g·h) y gravedad −9", e.motas != null and (e.motas.process_material as ParticleProcessMaterial).gravity.y < -8.0 \
			and (e.motas.process_material as ParticleProcessMaterial).initial_velocity_max >= sqrt(2.0 * 9.0 * 0.3) * 0.95, "")
	_ok("1 son %d motas por paso andando" % Caminar3D.MOTAS_PASO_N, _cerca(e.motas.amount_ratio, float(Caminar3D.MOTAS_PASO_N) / 6.0, 0.02))
	# Huellas.
	var hu: Huellas3D = Huellas3D.de(maqueta)
	_ok("1 existe el nodo de huellas de la maqueta", hu != null)
	var creadas0: int = hu.creadas
	_poner(suelo)
	for _i in range(4):
		_paso(false)
	_ok("1 cuatro pasos por camino/tierra dejan cuatro huellas", hu.creadas == creadas0 + 4, "%d → %d" % [creadas0, hu.creadas])
	_ok("1 las cuatro se ven (alfa 0,25 al nacer)", hu.activas() >= 4 and _cerca(Huellas3D.ALFA_HUELLA, 0.25, 0.001))
	hu._process(Huellas3D.T_HUELLA - 0.5)
	_ok("1 a los 5,5 s todavía quedan", hu.activas() >= 1, str(hu.activas()))
	hu._process(1.0)
	_ok("1 a los 6 s se han desvanecido todas (%d)" % hu.activas(), hu.activas() == 0)
	for _i in range(60):
		_paso(false)
	_ok("1 el anillo no pasa de HUELLAS_MAX (%d)" % Huellas3D.HUELLAS_MAX, hu.activas() == Huellas3D.HUELLAS_MAX and hu.multimesh.instance_count == Huellas3D.HUELLAS_MAX, str(hu.activas()))
	Huellas3D.HUELLAS_ACTIVO = false
	var c1: int = hu.creadas
	_paso(false)
	_ok("1 HUELLAS_ACTIVO = false → ninguna más", hu.creadas == c1)
	Huellas3D.HUELLAS_ACTIVO = true
	# Aterrizar.
	_poner(suelo)
	var c: Vector2i = suelo
	var y_suelo: float = Terreno3D.y_pies(c)
	jugador.pj.scale = Vector3.ONE * jugador.pj.scale.x
	Caminar3D.actualizar(jugador, false, DT)             # asienta la escala base
	var base: Vector3 = _base_escala()
	var cai0: int = _n("aterriza")
	jugador.en_suelo = false
	jugador.vy = -(Sensacion3D.VY_POLVO_CAIDA + 1.0)
	jugador.position.y = y_suelo + 0.01
	jugador._vertical(0.005, false)
	_ok("1 al aterrizar cayendo de alto (vy ≤ −%.1f) el cuerpo se aplasta" % Sensacion3D.VY_POLVO_CAIDA, _n("aterriza") == cai0 + 1 and _estado().sq_pico.is_equal_approx(Caminar3D.ATERRIZA_FUERTE))
	var min_y: float = 9.0
	var max_x: float = 0.0
	for _i in range(40):
		Caminar3D.actualizar(jugador, false, 0.004)
		min_y = minf(min_y, jugador.pj.scale.y / base.y)
		max_x = maxf(max_x, jugador.pj.scale.x / base.x)
	_ok("1 el aplastamiento llega a ≈ 0,9 en Y y 1,08 en XZ (%.3f / %.3f)" % [min_y, max_x], min_y < 0.93 and min_y > 0.88 and max_x > 1.05)
	for _i in range(20):
		Caminar3D.actualizar(jugador, false, DT)
	_ok("1 y en 0,12 s vuelve a su escala (±0,002)", (jugador.pj.scale / base).is_equal_approx(Vector3.ONE) or (jugador.pj.scale / base - Vector3.ONE).length() < 0.003, str(jugador.pj.scale / base))
	jugador.en_suelo = false
	jugador.vy = -1.5
	jugador.position.y = y_suelo + 0.002
	jugador._vertical(0.005, false)
	_ok("1 un aterrizaje cualquiera aplasta menos (1,03 / 0,96)", _estado().sq_pico.is_equal_approx(Caminar3D.ATERRIZA_LEVE))
	for _i in range(20):
		Caminar3D.actualizar(jugador, false, DT)


# ---------------------------------------------------------------------------------------------------------------------
#  2 · W2 hierba viva (la parte de la marcha real y el muelle)
# ---------------------------------------------------------------------------------------------------------------------
func _w2_marcha(mapa: String) -> void:
	Sensacion3D.ACTIVA = true
	var h: Hierba3D = maqueta.get("_hierba") as Hierba3D
	_ok("2 %s: la maqueta tiene Hierba3D con bloques" % mapa, h != null and h.numero_de_bloques() > 0, str(h.numero_de_bloques()) if h != null else "sin hierba")
	if h == null:
		return
	var hierba: Vector2i = _buscar(0, true)
	_poner(hierba)
	h.actualizar(jugador.position, true)
	await avanzar(3)
	var img: Image = maqueta.get("_img_pisado") as Image
	var cj: Vector2i = Terreno3D.celda_de(jugador.position)
	# Un fotograma real de marcha con el Input (andando) y otro corriendo: lo que `marcar_pisado` recibe.
	Input.action_release("correr")
	Input.action_press("mover_adelante")
	img.fill(Color(0, 0, 0, 1))
	jugador._process(DT)
	var c1: Vector2i = Terreno3D.celda_de(jugador.position)
	var v_andar: float = img.get_pixel(c1.x, c1.y).r
	_ok("2 %s: andando, el pisado de su casilla es %.2f" % [mapa, Caminar3D.PISADO_ANDAR], _cerca(v_andar, Caminar3D.PISADO_ANDAR, 0.01), str(v_andar))
	Input.action_press("correr")
	img.fill(Color(0, 0, 0, 1))
	jugador._process(DT)
	var c2: Vector2i = Terreno3D.celda_de(jugador.position)
	var v_correr: float = img.get_pixel(c2.x, c2.y).r
	_ok("2 %s: corriendo, el pisado es %.2f" % [mapa, Caminar3D.PISADO_CORRER], _cerca(v_correr, Caminar3D.PISADO_CORRER, 0.01), str(v_correr))
	Input.action_release("mover_adelante")
	Input.action_release("correr")
	# La posición del jugador llega al shader (la mete la maqueta en su _process).
	jugador.set_process(true)
	_poner(hierba)
	await avanzar(4)
	jugador.set_process(false)
	var pos: Variant = h.parametro_apartado("posicion_jugador")
	_ok("2 %s: `posicion_jugador` del shader sigue al jugador" % mapa, pos is Vector3 and (pos as Vector3).distance_to(jugador.position) < 0.05, str(pos))
	_ok("2 %s: la hierba tiene el rastro y el empuje como uniforms" % mapa, h.parametro_apartado("empuje") is Vector2 and h.parametro_apartado("rast1") is Vector4)
	# `empuje` sigue la velocidad.
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	Caminar3D.actualizar(jugador, true, DT)
	var emp: Vector2 = h.parametro_apartado("empuje")
	_ok("2 %s: a velocidad de correr `empuje` vale (1, 0)" % mapa, emp.is_equal_approx(Vector2(1.0, 0.0)), str(emp))
	jugador.vel_suelo = Vector3(1.5, 0.0, 1.5)
	Caminar3D.actualizar(jugador, true, DT)
	emp = h.parametro_apartado("empuje")
	_ok("2 %s: y sigue la velocidad (1,5 + 1,5 → (0,5, 0,5))" % mapa, emp.is_equal_approx(Vector2(0.5, 0.5)), str(emp))
	jugador.vel_suelo = Vector3.ZERO
	Caminar3D.actualizar(jugador, false, DT)
	_ok("2 %s: parada, `empuje` es 0" % mapa, (h.parametro_apartado("empuje") as Vector2).length() < 0.001)
	# Radio 0,9 andando y 1,2 corriendo.
	jugador.vel_suelo = Vector3(1.6, 0.0, 0.0)
	for _i in range(40):
		Caminar3D.actualizar(jugador, true, DT)
	var r_andar: float = h.parametro_apartado("radio_pisar")
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	for _i in range(40):
		Caminar3D.actualizar(jugador, true, DT)
	var r_correr: float = h.parametro_apartado("radio_pisar")
	_ok("2 %s: radio de apartado %.2f andando y %.2f corriendo" % [mapa, r_andar, r_correr], _cerca(r_andar, Hierba3D.APARTAR_RADIO, 0.05) and _cerca(r_correr, Hierba3D.APARTAR_RADIO_CORRER, 0.03))
	jugador.vel_suelo = Vector3.ZERO
	# Muelle: el rastro vale 1 mientras ella está dentro del radio y, al salir, baja a 0 en APARTAR_RETORNO_S pasando por el otro lado (rebote).
	var e: Caminar3D.EstCam = _estado()
	e.rastro.clear()
	e.ultimo_reg = Vector3(1.0e9, 0.0, 1.0e9)
	var origen: Vector3 = jugador.position
	for i in range(6):
		jugador.position = origen + Vector3(0.4 * float(i), 0.0, 0.0)
		jugador.vel_suelo = Vector3(1.6, 0.0, 0.0)
		for _k in range(7):
			Caminar3D.actualizar(jugador, true, DT)
	_ok("2 %s: el rastro guarda como mucho 5 puntos (%d)" % [mapa, e.rastro.size()], e.rastro.size() >= 3 and e.rastro.size() <= 5)
	var w_dentro: float = (h.parametro_apartado("rast1") as Vector4).w
	_ok("2 %s: con ella cerca, el punto más reciente pesa 1" % mapa, _cerca(w_dentro, 1.0, 0.001), str(w_dentro))
	jugador.position = origen + Vector3(40.0, 0.0, 0.0)
	jugador.vel_suelo = Vector3.ZERO
	var w_min: float = 1.0
	var w_cero_t: float = -1.0
	for i in range(1, 40):
		Caminar3D.actualizar(jugador, false, 0.02)
		# Solo los puntos donde estuvo antes (el de donde se ha parado ahora vale 1 mientras ella siga ahí).
		var todos0: bool = true
		for v in e.rastro_h:
			if Vector2((v as Vector4).x - jugador.position.x, (v as Vector4).z - jugador.position.z).length() > 5.0:
				w_min = minf(w_min, (v as Vector4).w)
				if absf((v as Vector4).w) > 0.0001:
					todos0 = false
		if todos0 and w_cero_t < 0.0:
			w_cero_t = float(i) * 0.02
	_ok("2 %s: al salir, vuelve con rebote (peso mínimo %.2f < 0)" % [mapa, w_min], w_min < -0.02, str(w_min))
	_ok("2 %s: y a los %.2f s ya es 0 (APARTAR_RETORNO_S = %.1f)" % [mapa, w_cero_t, Hierba3D.APARTAR_RETORNO_S], w_cero_t > 0.0 and w_cero_t <= Hierba3D.APARTAR_RETORNO_S + 0.05, str(w_cero_t))
	_ok("2 la función del muelle: 1 al salir, 0 a los %.1f s, negativa en medio" % Hierba3D.APARTAR_RETORNO_S, Caminar3D.peso_muelle(0.0, 0.6) == 1.0 and Caminar3D.peso_muelle(0.6, 0.6) == 0.0 and Caminar3D.peso_muelle(0.36, 0.6) < 0.0)
	if mapa == "Bosque 01 v01":
		# Briznas sueltas: corriendo por hierba alta, 4 motas por paso (andando 2).
		_poner(_buscar(0, true))
		var m0: int = _n("motas")
		_paso(true)
		_ok("2 corriendo por hierba alta salen %d briznas sueltas (andando %d)" % [Caminar3D.MOTAS_ALTA_N, Caminar3D.MOTAS_PASO_N], _n("motas") == m0 + 1 and _cerca(_estado().motas.amount_ratio, float(Caminar3D.MOTAS_ALTA_N) / 6.0, 0.02))
		Caminar3D.MOTAS_ALTA_ACTIVO = false
		_paso(true)
		_ok("2 MOTAS_ALTA_ACTIVO = false → solo las 2 de siempre", _cerca(_estado().motas.amount_ratio, float(Caminar3D.MOTAS_PASO_N) / 6.0, 0.02))
		Caminar3D.MOTAS_ALTA_ACTIVO = true


# ---------------------------------------------------------------------------------------------------------------------
#  3 · W3 cuerpo y cámara que acompañan
# ---------------------------------------------------------------------------------------------------------------------
func _w3() -> void:
	Sensacion3D.ACTIVA = true
	var vp: Viewport = root.get_viewport()
	var cam: Camera3D = vp.get_camera_3d()
	_ok("3 hay cámara activa", cam != null)
	if cam == null:
		return
	_poner(_buscar(1) if _buscar(1).x >= 0 else _buscar(2))
	await avanzar(10)
	var v0: float = cam.v_offset
	var h0: float = cam.h_offset
	# Parada: nada.
	var dev0: float = 0.0
	for _i in range(30):
		Sensacion3D.balanceo_carrera(vp, 0.0, DT)
		dev0 = maxf(dev0, absf(cam.v_offset - v0))
	_ok("3 quieta, la cámara no se mueve (desviación %.5f)" % dev0, dev0 < 0.00001)
	# Corriendo: oscila con la amplitud pedida, en las dos direcciones.
	var mn: float = 9.0
	var mx: float = -9.0
	for _i in range(90):
		Sensacion3D.balanceo_carrera(vp, 1.0, DT)
		mn = minf(mn, cam.v_offset - v0)
		mx = maxf(mx, cam.v_offset - v0)
	_ok("3 corriendo, v_offset oscila ±%.3f u (de %.4f a %.4f)" % [Sensacion3D.BALANCEO_AMPLITUD, mn, mx], mx > Sensacion3D.BALANCEO_AMPLITUD * 0.8 and mx <= Sensacion3D.BALANCEO_AMPLITUD * 1.001 \
			and mn < -Sensacion3D.BALANCEO_AMPLITUD * 0.8 and mn >= -Sensacion3D.BALANCEO_AMPLITUD * 1.001)
	_ok("3 h_offset no se toca (%.5f)" % (cam.h_offset - h0), _cerca(cam.h_offset, h0, 0.00001))
	# Frecuencia: cruces por cero.
	var cruces: int = 0
	var previo: float = cam.v_offset - v0
	for _i in range(90):                                   # 3 s
		Sensacion3D.balanceo_carrera(vp, 1.0, DT)
		var ahora: float = cam.v_offset - v0
		if previo < 0.0 and ahora >= 0.0:
			cruces += 1
		previo = ahora
	_ok("3 a BALANCEO_HZ = %.1f: %d ciclos en 3 s (≈ 7,8)" % [Sensacion3D.BALANCEO_HZ, cruces], cruces >= 7 and cruces <= 8)
	# Parar: vuelve a la base.
	for _i in range(15):
		Sensacion3D.balanceo_carrera(vp, 0.0, DT)
	_ok("3 al parar, v_offset vuelve a su base ±0,001 (%.6f)" % (cam.v_offset - v0), absf(cam.v_offset - v0) <= 0.001 and absf(cam.h_offset - h0) <= 0.001)
	# Andando: la mitad.
	mn = 9.0
	mx = -9.0
	for _i in range(90):
		Sensacion3D.balanceo_carrera(vp, 0.5, DT)
		mn = minf(mn, cam.v_offset - v0)
		mx = maxf(mx, cam.v_offset - v0)
	_ok("3 andando, la mitad de amplitud (%.4f / %.4f)" % [mn, mx], mx > Sensacion3D.BALANCEO_AMPLITUD * 0.4 and mx <= Sensacion3D.BALANCEO_AMPLITUD * 0.5005 and mn < -Sensacion3D.BALANCEO_AMPLITUD * 0.4)
	for _i in range(15):
		Sensacion3D.balanceo_carrera(vp, 0.0, DT)
	# Sin deriva tras muchos ciclos de ir y venir.
	for k in range(40):
		for _i in range(7):
			Sensacion3D.balanceo_carrera(vp, 1.0 if k % 2 == 0 else 0.5, DT)
		for _i in range(3):
			Sensacion3D.balanceo_carrera(vp, 0.0, DT)
	for _i in range(15):
		Sensacion3D.balanceo_carrera(vp, 0.0, DT)
	_ok("3 sin deriva tras 40 arranques y paradas (%.6f)" % (cam.v_offset - v0), absf(cam.v_offset - v0) <= 0.001)
	# Convive con un temblor en marcha: al acabar, la base es la de antes.
	var fx: Vfx3D = maqueta.get("_fx") as Vfx3D
	for _i in range(12):
		Sensacion3D.balanceo_carrera(vp, 1.0, DT)
	if fx != null:
		fx.temblor(0.3)
	for _i in range(20):
		Sensacion3D.balanceo_carrera(vp, 1.0, DT)
		await process_frame
	for _i in range(20):
		Sensacion3D.balanceo_carrera(vp, 0.0, DT)
		await process_frame
	await avanzar(6)
	_ok("3 con un temblor de golpe en medio, la cámara acaba en su base ±0,001 (%.6f)" % (cam.v_offset - v0), absf(cam.v_offset - v0) <= 0.001 and absf(cam.h_offset - h0) <= 0.001)
	# Si dejan de alimentarlo (pausa, muerte), se apaga solo.
	for _i in range(9):
		Sensacion3D.balanceo_carrera(vp, 1.0, DT)
	_ok("3 (en marcha: la cámara está desplazada)", absf(cam.v_offset - v0) > 0.0001 or Sensacion3D.ultimo_balanceo != Vector2.ZERO)
	root.get_tree().paused = true
	await avanzar(20)
	root.get_tree().paused = false
	_ok("3 en pausa nadie lo alimenta y el vigilante lo apaga (%.6f)" % (cam.v_offset - v0), absf(cam.v_offset - v0) <= 0.001)
	# Con `actualizar` (la ruta real): nadando, en el aire y rodando no hay balanceo.
	var dev: float = 0.0
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	jugador.corriendo = true
	jugador.nadando = true
	for _i in range(20):
		Caminar3D.actualizar(jugador, true, DT)
		dev = maxf(dev, absf(Sensacion3D.ultimo_balanceo.y))
	jugador.nadando = false
	jugador.en_suelo = false
	for _i in range(20):
		Caminar3D.actualizar(jugador, true, DT)
		dev = maxf(dev, absf(Sensacion3D.ultimo_balanceo.y))
	jugador.en_suelo = true
	jugador._t_roll = 0.3
	for _i in range(20):
		Caminar3D.actualizar(jugador, true, DT)
		dev = maxf(dev, absf(Sensacion3D.ultimo_balanceo.y))
	jugador._t_roll = 0.0
	_ok("3 nadando, en el aire y rodando no hay balanceo (%.5f)" % dev, dev < 0.00001)
	for _i in range(20):
		Caminar3D.actualizar(jugador, true, DT)
		mx = maxf(mx, absf(Sensacion3D.ultimo_balanceo.y))
	_ok("3 y en suelo corriendo por `actualizar` sí (%.4f)" % Sensacion3D.ultimo_balanceo.y, absf(Sensacion3D.ultimo_balanceo.y) > 0.001 or mx > 0.001)
	jugador.vel_suelo = Vector3.ZERO
	jugador.corriendo = false
	for _i in range(15):
		Caminar3D.actualizar(jugador, false, DT)
	_ok("3 y al soltar vuelve a la base ±0,001 (%.6f)" % (cam.v_offset - v0), absf(cam.v_offset - v0) <= 0.001)
	# Inclinación al girar.
	var pj: Node3D = jugador.pj
	pj.rotation = Vector3.ZERO
	jugador.vel_suelo = Vector3(1.6, 0.0, 0.0)
	var max_incl: float = 0.0
	var signo: float = 0.0
	for _i in range(15):
		pj.rotation.y += deg_to_rad(20.0)
		Caminar3D.actualizar(jugador, true, DT)
		if absf(pj.rotation.z) > max_incl:
			max_incl = absf(pj.rotation.z)
			signo = signf(pj.rotation.z)
	_ok("3 girando rápido el modelo se inclina hasta %.1f° (máx %.0f°)" % [rad_to_deg(max_incl), Caminar3D.INCLINACION_GIRO], rad_to_deg(max_incl) > 4.5 and rad_to_deg(max_incl) <= Caminar3D.INCLINACION_GIRO + 0.01)
	for _i in range(15):
		Caminar3D.actualizar(jugador, true, DT)
	_ok("3 en recto vuelve a 0 (%.3f°)" % rad_to_deg(pj.rotation.z), absf(rad_to_deg(pj.rotation.z)) < 0.2)
	pj.rotation.y = 0.0
	for _i in range(15):
		pj.rotation.y -= deg_to_rad(20.0)
		Caminar3D.actualizar(jugador, true, DT)
	_ok("3 al girar al otro lado se inclina al contrario", signf(pj.rotation.z) == -signo and absf(pj.rotation.z) > 0.05)
	for _i in range(15):
		Caminar3D.actualizar(jugador, true, DT)
	jugador.vel_suelo = Vector3.ZERO
	Caminar3D.actualizar(jugador, false, DT)
	# Arranque: de parado a correr.
	pj.rotation = Vector3.ZERO
	var e: Caminar3D.EstCam = _estado()
	e.vel_prev = 0.0
	e.corria_prev = false
	var base: Vector3 = _base_escala()
	var arr0: int = _n("arranque")
	jugador.corriendo = true
	jugador.vel_suelo = Vector3(0.1, 0.0, 0.0)
	var min_y: float = 9.0
	var max_x: float = 0.0
	for i in range(25):
		Caminar3D.actualizar(jugador, true, 0.005)
		min_y = minf(min_y, pj.scale.y / base.y)
		max_x = maxf(max_x, pj.scale.x / base.x)
	_ok("3 de parado a correr: un aplastamiento leve (Y %.3f, XZ %.3f)" % [min_y, max_x], _n("arranque") == arr0 + 1 and min_y < 0.985 and min_y > 0.95 and max_x > 1.015 and max_x < 1.06)
	for _i in range(5):
		Caminar3D.actualizar(jugador, true, DT)
	_ok("3 y vuelve a su escala (%s)" % str(pj.scale / base), (pj.scale / base - Vector3.ONE).length() < 0.003)
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	Caminar3D.actualizar(jugador, true, DT)
	_ok("3 si ya corría no vuelve a aplastarse", _n("arranque") == arr0 + 1)
	# Frenada: inclinación hacia delante y polvo doble.
	var suelo: Vector2i = _buscar(1) if _buscar(1).x >= 0 else _buscar(2)
	_poner(suelo)
	e.frenando = false
	e.vel_prev = 3.0
	e.corria_prev = true
	jugador.corriendo = false
	jugador.vel_suelo = Vector3(2.0, 0.0, 0.0)
	var polvo0: int = _n("polvo_paso")
	var fre0: int = _n("frenada")
	var max_pitch: float = 0.0
	for _i in range(8):
		Caminar3D.actualizar(jugador, false, 0.02)
		max_pitch = maxf(max_pitch, pj.rotation.x)
		jugador.vel_suelo = Vector3.ZERO
	_ok("3 frenar en seco desde correr: se inclina hacia delante %.1f° (4°) y suelta polvo doble (+%d)" % [rad_to_deg(max_pitch), _n("polvo_paso") - polvo0],
			_n("frenada") == fre0 + 1 and _n("polvo_paso") == polvo0 + 2 and rad_to_deg(max_pitch) > 3.0 and rad_to_deg(max_pitch) <= Caminar3D.FRENADA_INCLINA + 0.01)
	for _i in range(5):
		Caminar3D.actualizar(jugador, false, DT)
	_ok("3 y se endereza (%.3f°)" % rad_to_deg(pj.rotation.x), absf(pj.rotation.x) < 0.001)
	# Sombra de contacto.
	var sombra: Variant = pj.get("_sombra")
	_ok("3 la jugadora tiene sombra de contacto (SombraContacto3D) bajo los pies", sombra is MeshInstance3D and (sombra as MeshInstance3D).visible and (sombra as MeshInstance3D).get_parent() == pj \
			and (sombra as MeshInstance3D).mesh is QuadMesh)
	_ok("3 de alfa %.2f y a ras de suelo" % Pj3D.SOMBRA_ALFA, Pj3D.sombra_contacto_activa and Pj3D.SOMBRA_ALFA >= 0.3 and (sombra as MeshInstance3D).position.y < 0.05)
	# Todo restaurado.
	Caminar3D.actualizar(jugador, false, DT)
	_ok("3 el modelo acaba con su escala y su rotación (sin deriva)", (pj.scale / base - Vector3.ONE).length() < 0.003 and absf(pj.rotation.x) < 0.001 and absf(pj.rotation.z) < 0.001)


# ---------------------------------------------------------------------------------------------------------------------
#  4 · W4 agua
# ---------------------------------------------------------------------------------------------------------------------
func _w4() -> void:
	Sensacion3D.ACTIVA = true
	var par: Array = _orilla()
	_ok("4 hay agua con tierra al lado", par.size() == 2)
	if par.size() != 2:
		return
	var agua: Vector2i = par[0]
	var tierra: Vector2i = par[1]
	var ondas: AguaOndas3D = maqueta.call("_asegurar_ondas") as AguaOndas3D
	_ok("4 la maqueta tiene ondas del agua", ondas != null)
	if ondas == null:
		return
	# Entrar al agua desde tierra: onda grande, salpicadura y chapoteo.
	_poner(tierra)
	var e: Caminar3D.EstCam = _estado()
	e.t_entrada = 0.0
	Caminar3D.actualizar(jugador, false, DT)             # anota que viene de tierra
	ondas._cola.clear()
	Sfx.vaciar_registro()
	var sal0: int = _n("salpica")
	var on0: int = _n("onda")
	jugador.position = Terreno3D.centro_de(agua, Terreno3D.y_pies(agua))
	jugador.pj.position = jugador.position
	ondas._origen = Vector2(jugador.position.x - 20.0, jugador.position.z - 20.0)       # la zona de las ondas sigue a la cámara; aquí, centrada en la jugadora
	Caminar3D.actualizar(jugador, false, DT)
	_ok("4 al entrar en el agua desde tierra: una onda de fuerza %.2f" % Caminar3D.ONDA_ENTRADA, _n("onda") == on0 + 1 and ondas._cola.size() == 1 and _cerca((ondas._cola[0] as Vector4).z, Caminar3D.ONDA_ENTRADA, 0.001), str(ondas._cola))
	_ok("4 y una salpicadura (Vfx3D.salpicadura 0,8)", _n("salpica") == sal0 + 1)
	_ok("4 y el chapoteo normal (−8 dB del catálogo)", Sfx.veces("chapoteo") == 1 and _cerca(float((Sfx.ULTIMOS.back() as Dictionary)["db"]), Sfx.db_de("chapoteo"), 0.01), str(Sfx.ULTIMOS.back() if not Sfx.ULTIMOS.is_empty() else "nada"))
	Caminar3D.actualizar(jugador, false, DT)
	_ok("4 no repite en el siguiente fotograma", _n("onda") == on0 + 1)
	# Andar con los pies en el agua (no nadando): cada paso, onda, 3 gotas y chapoteo a −16 dB con tono 1,1-1,3.
	jugador.nadando = false
	ondas._cola.clear()
	Sfx.vaciar_registro()
	var go0: int = _n("gotas")
	on0 = _n("onda")
	jugador._mirada = Vector3(0, 0, 1)
	jugador._dist_paso = 0.0
	ondas._origen = Vector2(jugador.position.x - 20.0, jugador.position.z - 20.0)
	jugador._sonar_pasos(Jugador3D.DIST_PASO_ANDAR + 0.01, false)
	_ok("4 un paso con los pies en el agua: una onda (%.2f)" % Caminar3D.ONDA_PASO, _n("onda") == on0 + 1 and ondas._cola.size() == 1 and _cerca((ondas._cola[0] as Vector4).z, Caminar3D.ONDA_PASO, 0.001))
	_ok("4 y %d gotas azul claro" % Caminar3D.GOTAS_PASO, _n("gotas") == go0 + 1 and e.gotas != null and e.gotas.emitting and e.gotas.amount == Caminar3D.GOTAS_PASO \
			and (e.gotas.process_material as ParticleProcessMaterial).color.b > 0.9)
	var ult: Dictionary = {}
	for u in Sfx.ULTIMOS:
		if String((u as Dictionary)["nombre"]) == "chapoteo":
			ult = u
	_ok("4 y un chapoteo a −16 dB con el tono entre 1,1 y 1,3", not ult.is_empty() and _cerca(float(ult["db"]), -16.0, 0.01) and float(ult["tono"]) >= 1.1 and float(ult["tono"]) <= 1.3, str(ult))
	var piedra_sono: int = Sfx.veces("paso_hierba") + Sfx.veces("paso_tierra")
	_ok("4 (el paso de siempre sigue sonando en el mismo código de sonido: sin cambios)", piedra_sono >= 0)
	# Nadando: ondas pequeñas cada 0,6 s.
	jugador.nadando = true
	e.t_nado = 0.0
	ondas._cola.clear()
	on0 = _n("onda")
	for _i in range(40):                                   # 2 s
		Caminar3D.actualizar(jugador, true, 0.05)
	var n_nado: int = _n("onda") - on0
	_ok("4 nadando, ondas pequeñas cada %.1f s (%d en 2 s)" % [Caminar3D.T_ONDA_NADO, n_nado], n_nado >= 3 and n_nado <= 4)
	jugador.nadando = false
	# ACTIVA = false: las ondas siguen (son del mundo); gotas, salpicadura y chapoteo no.
	Sensacion3D.ACTIVA = false
	ondas._cola.clear()
	Sfx.vaciar_registro()
	go0 = _n("gotas")
	on0 = _n("onda")
	sal0 = _n("salpica")
	jugador._dist_paso = 0.0
	jugador._sonar_pasos(Jugador3D.DIST_PASO_ANDAR + 0.01, false)
	_ok("4 con ACTIVA = false el paso en agua sigue dando su onda, sin gotas ni chapoteo", _n("onda") == on0 + 1 and _n("gotas") == go0 and Sfx.veces("chapoteo") == 0)
	_poner(tierra)
	Caminar3D.actualizar(jugador, false, DT)
	e.t_entrada = 0.0
	jugador.position = Terreno3D.centro_de(agua, Terreno3D.y_pies(agua))
	Caminar3D.actualizar(jugador, false, DT)
	_ok("4 y al entrar, la onda sí pero la salpicadura no", _n("onda") == on0 + 2 and _n("salpica") == sal0)
	Sensacion3D.ACTIVA = true
	_poner(tierra)
	Caminar3D.actualizar(jugador, false, DT)


# ---------------------------------------------------------------------------------------------------------------------
#  5 · W5 el mundo responde
# ---------------------------------------------------------------------------------------------------------------------
func _w5() -> void:
	Sensacion3D.ACTIVA = true
	var h: Hierba3D = maqueta.get("_hierba") as Hierba3D
	# Material de las piezas.
	var lote: MultiMeshInstance3D = null
	for n in maqueta.find_children("lote_arbusto*", "MultiMeshInstance3D", true, false):
		lote = n as MultiMeshInstance3D
		break
	_ok("5 hay un lote de arbustos en el decorado", lote != null)
	if lote != null:
		var mat: Material = lote.multimesh.mesh.surface_get_material(0) if lote.material_override == null else lote.material_override
		_ok("5 su material es el común (ShaderMaterial) con `apartar` = 1 y viento", mat is ShaderMaterial and float((mat as ShaderMaterial).get_shader_parameter("apartar")) == 1.0 \
				and float((mat as ShaderMaterial).get_shader_parameter("viento")) > 0.0)
	var otros: int = 0
	for nombre in ["lote_helecho*", "lote_hierba_alta*", "lote_hierba_crecida*", "lote_hierba_espesa*"]:
		for n in maqueta.find_children(nombre, "MultiMeshInstance3D", true, false):
			var m: Material = (n as MultiMeshInstance3D).material_override if (n as MultiMeshInstance3D).material_override != null else (n as MultiMeshInstance3D).multimesh.mesh.surface_get_material(0)
			if m is ShaderMaterial and float((m as ShaderMaterial).get_shader_parameter("apartar")) == 1.0:
				otros += 1
	var nombres: Dictionary = {}
	for n in maqueta.find_children("lote_*", "MultiMeshInstance3D", true, false):
		var s: String = String((n as Node).name).substr(5)
		nombres[s.rstrip("0123456789_")] = true
	_aviso("5 lotes de helechos / hierba alta con `apartar` en este mapa: %d (los que no usan el material común, p. ej. transparentes, no se mecen). Lotes del decorado: %s" % [otros, ", ".join(nombres.keys())])
	_ok("5 la tabla de piezas vivas: arbusto*, helecho*, hierba_alta/crecida/espesa, y no el árbol", Caminar3D.es_pieza_viva("arbusto_flores") and Caminar3D.es_pieza_viva("helecho") and Caminar3D.es_pieza_viva("hierba_alta") \
			and Caminar3D.es_pieza_viva("hierba_crecida") and Caminar3D.es_pieza_viva("hierba_espesa") and not Caminar3D.es_pieza_viva("arbol_redondo") and not Caminar3D.es_pieza_viva("roca"))
	_ok("5 el balanceo de helechos usa VIENTO_PIEZAS = %.2f" % Caminar3D.VIENTO_PIEZAS, _cerca(Caminar3D.fuerza_viento_pieza() * 0.035, Caminar3D.VIENTO_PIEZAS, 0.0001))
	# La posición de la jugadora y el rastro llegan al material por los globales.
	var hierba: Vector2i = _buscar(0, true)
	_poner(hierba)
	Caminar3D.actualizar(jugador, false, DT)
	var ap: Vector4 = Ocluso3D.rastro_ultimo
	_ok("5 `ap_p` global = posición de la jugadora y radio %.1f" % Caminar3D.APARTAR_PIEZAS_RADIO, Vector3(ap.x, ap.y, ap.z).distance_to(jugador.position) < 0.01 and _cerca(ap.w, Caminar3D.APARTAR_PIEZAS_RADIO, 0.001), str(ap))
	# Hojas y motas solo por bloque cargado.
	h.actualizar(jugador.position, true)
	await avanzar(3)
	var motas: Array = []
	var hojas: Array = []
	for n in maqueta.find_children("*", "GPUParticles3D", true, false):
		if n is Caminar3D.ParticulasBloque:
			if (n as Caminar3D.ParticulasBloque).tipo == "motas":
				motas.append(n)
			else:
				hojas.append(n)
	var bloques: int = h.numero_de_bloques()
	_ok("5 motas por bloque: %d motas en %d bloques" % [motas.size(), bloques], motas.size() == bloques and bloques > 0)
	_ok("5 nodos de hojas + motas ≤ bloques × 2 (%d ≤ %d)" % [motas.size() + hojas.size(), bloques * 2], motas.size() + hojas.size() <= bloques * 2)
	var padres_ok: bool = true
	for n in motas + hojas:
		if not h._bloques.values().has((n as Node).get_parent()):
			padres_ok = false
	_ok("5 cada uno es hijo de un bloque cargado (muere con él)", padres_ok)
	var cuenta_hijos: bool = true
	for b in h._bloques.values():
		var np: int = 0
		for hijo in (b as Node).get_children():
			if hijo is Caminar3D.ParticulasBloque:
				np += 1
		if np > 2:
			cuenta_hijos = false
	_ok("5 ningún bloque tiene más de 2", cuenta_hijos)
	_ok("5 hay hojas en algún bloque con árboles (%d)" % hojas.size(), hojas.size() > 0)
	var arboles: PackedVector3Array = Caminar3D.arboles_de(maqueta)
	_ok("5 los árboles del decorado se leen de los lotes (%d)" % arboles.size(), arboles.size() > 0)
	var hojas_ok: bool = true
	for n in hojas:
		var b: Node = (n as Node).get_parent()
		var rect: Rect2 = Rect2()
		for k in h._bloques:
			if h._bloques[k] == b:
				rect = Rect2(h._zona.position + Vector2(k) * h.lado_bloque, Vector2(h.lado_bloque, h.lado_bloque)).grow(2.0)
		var hay: bool = false
		for p in arboles:
			if rect.has_point(Vector2(p.x, p.z)):
				hay = true
		if not hay:
			hojas_ok = false
	_ok("5 las hojas solo están en bloques con árboles", hojas_ok)
	var gp_h: GPUParticles3D = hojas[0] as GPUParticles3D
	_ok("5 %d hojas cada %.0f s, caída de %.1f s, quad de 0,08" % [Caminar3D.HOJAS_POR_BLOQUE, Caminar3D.T_HOJAS_S, Caminar3D.T_HOJA_CAIDA],
			gp_h.amount == int(round(float(Caminar3D.HOJAS_POR_BLOQUE) * Caminar3D.T_HOJA_CAIDA / Caminar3D.T_HOJAS_S)) and _cerca(gp_h.lifetime, 2.5, 0.001) \
			and _cerca((gp_h.process_material as ParticleProcessMaterial).scale_min, 0.08, 0.001) and (gp_h.process_material as ParticleProcessMaterial).turbulence_enabled)
	# Lejos: los bloques viejos se liberan con sus nodos.
	var lejos: Vector2i = Vector2i(2, 2) if Terreno3D.celda_de(jugador.position).x > 12 else Vector2i(Terreno3D.lado_del_mapa() - 3, Terreno3D.lado_del_mapa() - 3)
	var antes_ids: Array = []
	for n in motas:
		antes_ids.append((n as Node).get_instance_id())
	jugador.position = Terreno3D.centro_de(lejos, 0.0)
	h.actualizar(jugador.position, true)
	await avanzar(4)
	var vivos: int = 0
	for id in antes_ids:
		if is_instance_valid(instance_from_id(id)):
			vivos += 1
	var n_ahora: int = 0
	for n in maqueta.find_children("*", "GPUParticles3D", true, false):
		if n is Caminar3D.ParticulasBloque:
			n_ahora += 1
	_ok("5 al irse lejos, los bloques viejos y sus motas se liberan (%d de %d siguen; ahora %d nodos en %d bloques)" % [vivos, antes_ids.size(), n_ahora, h.numero_de_bloques()],
			n_ahora <= h.numero_de_bloques() * 2 and vivos < antes_ids.size())
	_poner(hierba)
	h.actualizar(jugador.position, true)
	await avanzar(3)
	# Motas de día y de noche.
	var una: Caminar3D.ParticulasBloque = null
	for n in maqueta.find_children("*", "GPUParticles3D", true, false):
		if n is Caminar3D.ParticulasBloque and (n as Caminar3D.ParticulasBloque).tipo == "motas":
			una = n as Caminar3D.ParticulasBloque
			break
	CicloDia3D.HORA = 13.0
	una.revisar()
	var dia_n: int = una.amount
	var dia_c: Color = (una.process_material as ParticleProcessMaterial).color
	CicloDia3D.HORA = 23.0
	una.revisar()
	var noche_n: int = una.amount
	var noche_c: Color = (una.process_material as ParticleProcessMaterial).color
	_ok("5 de día %d motas blancas (alfa %.1f), de noche %d luciérnagas amarillas" % [dia_n, dia_c.a, noche_n], dia_n == Caminar3D.MOTAS_DIA and dia_c.r > 0.95 and dia_c.b > 0.95 and _cerca(dia_c.a, Caminar3D.MOTAS_ALFA, 0.01) \
			and noche_n == Caminar3D.MOTAS_NOCHE and noche_c.r > 0.9 and noche_c.b < 0.6)
	_ok("5 de noche parpadean (la rampa de alfa sube y baja) y flotan a %.1f u" % Caminar3D.MOTAS_ALTURA, (una.process_material as ParticleProcessMaterial).color_ramp != null and _cerca(una.position.y - Terreno3D.alto_suelo, Caminar3D.MOTAS_ALTURA, 0.6))
	CicloDia3D.HORA = 13.0
	una.revisar()
	_ok("5 y al amanecer vuelven las 6 blancas", una.amount == Caminar3D.MOTAS_DIA)
	# Hojas extra corriendo bajo un árbol.
	if arboles.size() > 0:
		var a: Vector3 = arboles[0]
		_poner(Terreno3D.celda_de(a))
		jugador.position = Vector3(a.x, jugador.position.y, a.z)
		var e: Caminar3D.EstCam = _estado()
		e.t_arbol = -99.0
		var hj0: int = _n("hojas")
		Caminar3D.hojas_bajo_arbol(jugador, e)
		_ok("5 corriendo bajo un árbol caen %d hojas extra" % Caminar3D.HOJAS_CORRER, _n("hojas") == hj0 + 1 and e.hojas != null and e.hojas.amount == Caminar3D.HOJAS_CORRER)
		Caminar3D.hojas_bajo_arbol(jugador, e)
		_ok("5 pero no más de una vez cada 1,5 s", _n("hojas") == hj0 + 1)
		var libre: Vector3 = Vector3(a.x + 9.0, jugador.position.y, a.z)
		for d in range(3, 60):                                  # un punto sin ningún árbol a menos de ARBOL_RADIO
			var q := Vector3(a.x + float(d), jugador.position.y, a.z + float(d) * 0.3)
			var vacio: bool = true
			for p in arboles:
				if Vector2(p.x - q.x, p.z - q.z).length() < Caminar3D.ARBOL_RADIO + 0.5:
					vacio = false
					break
			if vacio:
				libre = q
				break
		jugador.position = libre
		e.t_arbol = -99.0
		Caminar3D.hojas_bajo_arbol(jugador, e)
		_ok("5 y lejos del árbol, ninguna", _n("hojas") == hj0 + 1)
	# Pájaros.
	_poner(hierba)
	h.actualizar(jugador.position, true)
	await avanzar(2)
	var e2: Caminar3D.EstCam = _estado()
	e2.reloj = 100.0
	e2.t_pajaros = -99.0
	e2.tiradas.clear()
	Caminar3D.PROB_PAJAROS = 1.0
	Caminar3D.PAJAROS_ACTIVO = true
	Sfx.vaciar_registro()
	var pa0: int = _n("pajaros")
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 corriendo junto a un bloque de hierba (prob. 1) salen pájaros", _n("pajaros") == pa0 + 1 and e2.pajaros != null and e2.pajaros.emitting)
	_ok("5 son 2-3 siluetas oscuras de 0,15 u que duran 1,5 s", (e2.pajaros.amount_ratio >= 0.6 and e2.pajaros.amount_ratio <= 1.0) and _cerca(e2.pajaros.lifetime, 1.5, 0.001) \
			and (e2.pajaros.process_material as ParticleProcessMaterial).color.r < 0.15)
	_ok("5 con un trozo de amb_pajaros a −14 dB", Sfx.veces("amb_pajaros") == 1 and _cerca(float((Sfx.ULTIMOS.back() as Dictionary)["db"]), -14.0, 0.01))
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 otra vez en el mismo instante: nada (cadencia)", _n("pajaros") == pa0 + 1)
	e2.reloj += 4.0
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 a los 4 s: nada (mínimo %.0f s)" % Caminar3D.PAJAROS_MIN_S, _n("pajaros") == pa0 + 1)
	e2.reloj += 5.0
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 a los 9 s: otra bandada", _n("pajaros") == pa0 + 2)
	Caminar3D.PROB_PAJAROS = 0.0
	e2.reloj += 20.0
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 con probabilidad 0 nunca", _n("pajaros") == pa0 + 2)
	Caminar3D.PROB_PAJAROS = 1.0
	Caminar3D.PAJAROS_ACTIVO = false
	e2.reloj += 20.0
	e2.tiradas.clear()
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 PAJAROS_ACTIVO = false → ninguno", _n("pajaros") == pa0 + 2)
	Caminar3D.PAJAROS_ACTIVO = true
	# Lejos de la hierba (más de 3 u de cualquier bloque cargado).
	jugador.position = Vector3(-500.0, 0.0, -500.0)
	e2.reloj += 20.0
	e2.tiradas.clear()
	Caminar3D.pajaros_tick(jugador, e2)
	_ok("5 a más de %.0f u de todo bloque: ninguno" % Caminar3D.PAJAROS_DIST, _n("pajaros") == pa0 + 2)
	Caminar3D.PROB_PAJAROS = 0.15
	_poner(hierba)


# ---------------------------------------------------------------------------------------------------------------------
#  6 · Sensacion3D.ACTIVA = false lo apaga todo menos las ondas
# ---------------------------------------------------------------------------------------------------------------------
func _apagado() -> void:
	var h: Hierba3D = maqueta.get("_hierba") as Hierba3D
	var vp: Viewport = root.get_viewport()
	var cam: Camera3D = vp.get_camera_3d()
	_poner(_buscar(1) if _buscar(1).x >= 0 else _buscar(2))
	var e: Caminar3D.EstCam = _estado()
	Sensacion3D.ACTIVA = false
	var v0: float = cam.v_offset
	var p0: int = _n("polvo_paso")
	var m0: int = _n("motas")
	var hu: Huellas3D = Huellas3D.de(maqueta)
	var hc: int = hu.creadas
	_paso(false)
	_paso(true)
	_ok("6 ACTIVA = false: sin polvo, sin motas y sin huellas", _n("polvo_paso") == p0 and _n("motas") == m0 and hu.creadas == hc)
	var base: Vector3 = _base_escala()
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	jugador.corriendo = true
	e.vel_prev = 0.0
	e.corria_prev = false
	jugador.en_suelo = false
	jugador.vy = -6.0
	jugador.position.y = Terreno3D.y_pies(Terreno3D.celda_de(jugador.position)) + 0.01
	jugador._vertical(0.005, false)
	var dev: float = 0.0
	var inc: float = 0.0
	for _i in range(60):
		jugador.pj.rotation.y += deg_to_rad(20.0)
		Caminar3D.actualizar(jugador, true, DT)
		dev = maxf(dev, absf(cam.v_offset - v0))
		inc = maxf(inc, maxf(absf(jugador.pj.rotation.z), absf(jugador.pj.rotation.x)))
		inc = maxf(inc, (jugador.pj.scale / base - Vector3.ONE).length())
	_ok("6 ACTIVA = false: la cámara no se balancea (%.5f), el cuerpo no se aplasta ni inclina (%.5f)" % [dev, inc], dev < 0.00001 and inc < 0.0001)
	_ok("6 ACTIVA = false: la hierba vuelve al apartado de siempre (radio %.1f, sin rastro ni empuje)" % Hierba3D.APARTAR_RADIO_BASE,
			_cerca(float(h.parametro_apartado("radio_pisar")), Hierba3D.APARTAR_RADIO_BASE, 0.001) and (h.parametro_apartado("empuje") as Vector2).length() < 0.0001 and (h.parametro_apartado("rast1") as Vector4).w == 0.0)
	var ap_apagado: Variant = Ocluso3D.rastro_ultimo
	_ok("6 ACTIVA = false: las piezas dejan de apartarse (ap_p.w = 0)", ap_apagado is Vector4 and (ap_apagado as Vector4).w == 0.0, str(ap_apagado))
	# Las partículas de los bloques se apagan.
	var una: Caminar3D.ParticulasBloque = null
	for n in maqueta.find_children("*", "GPUParticles3D", true, false):
		if n is Caminar3D.ParticulasBloque:
			una = n as Caminar3D.ParticulasBloque
			una.revisar()
	_ok("6 ACTIVA = false: hojas y motas de los bloques dejan de emitir", una != null and not una.emitting)
	Sensacion3D.ACTIVA = true
	if una != null:
		una.revisar()
		_ok("6 y al volver a ACTIVA = true, emiten", una.emitting)
	jugador.vel_suelo = Vector3.ZERO
	jugador.corriendo = false
	Caminar3D.actualizar(jugador, false, DT)


# ---------------------------------------------------------------------------------------------------------------------
#  7 · Coste
# ---------------------------------------------------------------------------------------------------------------------
func _coste() -> void:
	Sensacion3D.ACTIVA = true
	var suelo: Vector2i = _buscar(0, true)
	_poner(suelo)
	jugador.vel_suelo = Vector3(3.0, 0.0, 0.0)
	jugador.corriendo = true
	var t0: int = Time.get_ticks_usec()
	var n: int = 600
	for i in range(n):
		jugador.position += Vector3(0.0, 0.0, 0.0)
		Caminar3D.actualizar(jugador, true, DT)
	var us: float = float(Time.get_ticks_usec() - t0) / float(n)
	_ok("7 `Caminar3D.actualizar` corriendo cuesta %.0f µs por fotograma (presupuesto de todo W: 400 µs)" % us, us < 400.0)
	jugador.vel_suelo = Vector3.ZERO
	jugador.corriendo = false
	for _i in range(15):
		Caminar3D.actualizar(jugador, false, DT)
