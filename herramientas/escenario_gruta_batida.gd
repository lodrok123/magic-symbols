extends "res://herramientas/escenario_cueva_resonante.gd"
## LA GRUTA BATIDA, AUTOPLAY DE PRINCIPIO A FIN (27/10; diseño en docs/GRUTA_BATIDA.md, mapa mundo/datos_nivel/mapas/GrutaBatida.txt).
## Las mismas reglas que el autoplay de la Cueva Resonante (de él salen `_andar_a`, `_ruta`, `_lanzar`, `_pulsar_e`): se anda con WASD, se lanza con la receta real y con gravedad
## (la barrera nace en el punto apuntado, dentro del anillo de 3 casillas, como con el ratón), se usa con E y nunca se teletransporta a nadie. Única ayuda: en las peleas
## con los arqueros de G5 y G6 se repone la vida (las flechas pegan de verdad; esto no prueba el combate). Lo que se mide de daño se mide ANTES de curar.
##
##   1 G1 · la placa abre la puerta y bajarse la cierra; tierra + ᛜ sobre la placa la sujeta y se pasa.
##   2 G2 · la flecha no llega al brasero tras la reja; fuego + ᛜ sí; con solo el brasero no se abre; tierra + ᛜ tras la otra reja pisa la placa y se pasa.
##   3 G3 · el arquero de puesto hace daño a quien se queda en la galería; tras una barrera de tierra + ᛜ + ᛁ, ninguno.
##   4 G4 · el agua no se pisa; hielo + ᛜ la hiela y se cruza.
##   5 G5 · hielo + ᛜ + ᛁ es a la vez puente y escudo: se cruza el río bajo los dos arqueros y se les tumba.
##   6 G6 · se cruza, la flecha no enciende los braseros tras sus rejas, fuego + ᛜ sí: la puerta se abre, el cofre da ᛉ; con tierra + ᛜ + ᛉ ᛉ la placa del atajo aguanta
##          lo que se tarda en llegar a la puerta, y se vuelve a G1. FIN.
##   7 · recarga: lo resuelto sigue resuelto y los arqueros vencidos no vuelven.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_gruta_batida.gd

const RUTA_GRUTA: String = "res://escenas/PruebaGrutaBatida.tscn"
const T_PELEA_MAX_S: float = 70.0


## Los arqueros vivos cuya casilla de partida está en `celdas`.
func _arqueros(celdas: Array) -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and celdas.has(Terreno3D.celda_de((n as Combate3D).casa)):
			res.append(n)
	return res


## Tumba a flechazos de fuego a los de `celdas`, acercándose a tiro sin salir de `zona` (se cura entre medias). true si caen todos.
func _tumbar(celdas: Array, zona: Rect2i) -> bool:
	var t0: float = reloj.t
	while not _arqueros(celdas).is_empty() and reloj.t - t0 < T_PELEA_MAX_S:
		_curar()
		var obj: Combate3D = null
		var dmin: float = INF
		for n in _arqueros(celdas):
			var d: float = (n as Combate3D).global_position.distance_to(jugador.position)
			if d < dmin:
				dmin = d
				obj = n as Combate3D
		var c_obj: Vector2i = Terreno3D.celda_de(obj.global_position)
		var yo: Vector2i = celda_jugador()
		var libre: bool = (yo.x == c_obj.x or yo.y == c_obj.y) and Terreno3D.linea_libre(jugador.position, obj.global_position)
		if dmin > (ALCANCE_FLECHA_CAS - 0.3) * Terreno3D.casilla or not libre:
			# A una casilla libre de la zona pegada al arquero y en su MISMA FILA O COLUMNA y con línea libre (la más cercana a la jugadora): en diagonal, la esquina de una pared para la flecha.
			var mejor: Vector2i = celda_jugador()
			var dm: float = INF
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var c: Vector2i = c_obj + Vector2i(dx, dy)
					if zona.has_point(c) and not Terreno3D.bloqueada(c) and Vector2(c - c_obj).length() <= 2.0 and (c.x == c_obj.x or c.y == c_obj.y) and Terreno3D.linea_libre(Terreno3D.centro_de(c, obj.global_position.y), obj.global_position):
						var dd: float = Vector2(c - celda_jugador()).length()
						if dd < dm:
							dm = dd
							mejor = c
			await _andar_a(mejor, 6.0, 0.4)
			continue
		if await _lanzar("fuego", ["flecha"], c_obj):
			await avanzar_s(0.8)
		else:
			await avanzar_s(1.0)
	return _arqueros(celdas).is_empty()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_GRUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_t0 = reloj.t
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 Puzle3D monta la Gruta Batida sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	_ok("0 el mapa mide 25 × 19 y la jugadora nace en G1 (4,15)", maqueta.get("_ancho") == 25 and maqueta.get("_alto") == 19 and celda_jugador() == Vector2i(4, 15), str(celda_jugador()))
	_ok("0 kit «barrera»: fuego, tierra y hielo; flecha, barrera y línea; sin ᛉ ni ᚱ", Repertoire.element_active("fuego") and Repertoire.element_active("tierra") and Repertoire.element_active("hielo")
		and Repertoire.sigil_active("barrera") and Repertoire.sigil_active("linea") and not Repertoire.sigil_active("permanencia") and not Repertoire.sigil_active("raido"))
	for paso in [_g1, _g2, _g3, _g4, _g5, _g6]:
		if not await (paso as Callable).call():
			_ok("FIN: el recorrido se cortó (ver el primer FALLO)", false)
			return
	print("TIEMPO DE JUEGO: %.0f s" % (reloj.t - _t0))
	await _recargar_gruta()


# ---------------------------------------------------------------------------------------------------------------------
#  1 · G1 · La boca: la placa y lo poco que dura
# ---------------------------------------------------------------------------------------------------------------------

func _g1() -> bool:
	var placa: Pulsador3D = _z.nodo("placa_g1") as Pulsador3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_g1") as Puzle3D.PuertaPuzle
	_ok("1 G1: la placa y la puerta están; la puerta cerrada", placa != null and puerta != null and not puerta.abierta)
	if placa == null or puerta == null:
		return false
	if not await _ruta("1 G1", [Vector2i(5, 13), [Vector2i(6, 12), TOL_EXACTA]]):
		return false
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("1 G1 [legible]: pisar la placa ABRE la puerta del norte", placa.activo and puerta.abierta)
	if not await _ruta("1 G1", [[Vector2i(5, 12), TOL_EXACTA]]):
		return false
	await _esperar(func() -> bool: return not puerta.abierta, 2.0)
	_ok("1 G1 [legible]: al bajarse de la placa la puerta se CIERRA (no da tiempo a llegar)", not placa.activo and not puerta.abierta)
	_ok("1 G1: tierra + ᛜ sobre la placa (6,12) sale", await _lanzar("tierra", ["barrera"], Vector2i(6, 12), true))
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("1 G1: el bloque PISA la placa y la puerta se abre", placa.activo and puerta.abierta)
	if not await _ruta("1 G1", [Vector2i(4, 11), Vector2i(4, 9), Vector2i(4, 8)]):
		return false
	_ok("1 G1: se cruza la puerta antes de que la barrera se deshaga", celda_jugador().y <= 8)
	await _esperar(func() -> bool: return not puerta.abierta, 12.0)
	_ok("1 G1 [legible]: al deshacerse la barrera la puerta se cierra sola", not puerta.abierta)
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  2 · G2 · Las rejas: peso y fuego a distancia
# ---------------------------------------------------------------------------------------------------------------------

func _g2() -> bool:
	var br: Reactivo3D = _z.nodo("br_g2") as Reactivo3D
	var placa: Pulsador3D = _z.nodo("placa_g2") as Pulsador3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_g2") as Puzle3D.PuertaPuzle
	_ok("2 G2: brasero, placa, rejas y puerta están", br != null and placa != null and puerta != null and Terreno3D.bloqueada(Vector2i(2, 2)) and Terreno3D.bloqueada(Vector2i(6, 2)))
	if br == null or placa == null or puerta == null:
		return false
	if not await _ruta("2 G2", [Vector2i(3, 5), [Vector2i(2, 4), TOL_EXACTA]]):
		return false
	_ok("2 G2: fuego + flecha al brasero tras la reja sale", await _lanzar("fuego", ["flecha"], Vector2i(2, 1)))
	await avanzar_s(2.0)
	_ok("2 G2 [legible]: la flecha NO llega al brasero (la reja la para)", not br.is_lit)
	_ok("2 G2: fuego + ᛜ donde apuntas, al otro lado de la reja, sale", await _lanzar("fuego", ["barrera"], Vector2i(2, 1), true))
	await _esperar(func() -> bool: return br.is_lit, 3.0)
	_ok("2 G2: la barrera de fuego nace tras la reja y ENCIENDE el brasero", br.is_lit)
	_ok("2 G2 [legible]: con solo el brasero la puerta sigue cerrada (falta la placa)", not puerta.abierta)
	if not await _ruta("2 G2", [Vector2i(4, 4), [Vector2i(6, 3), TOL_EXACTA]]):
		return false
	_ok("2 G2: tierra + ᛜ sobre la placa tras la reja (6,1) sale", await _lanzar("tierra", ["barrera"], Vector2i(6, 1), true))
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("2 G2: el bloque pisa la placa que no se puede pisar y, con el brasero encendido, se abre la puerta del este", placa.activo and puerta.abierta)
	return await _ruta("2 G2", [Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3)])


# ---------------------------------------------------------------------------------------------------------------------
#  3 · G3 · La galería: el escudo
# ---------------------------------------------------------------------------------------------------------------------

func _g3() -> bool:
	var arq: Array = _arqueros([Vector2i(12, 8)])
	_ok("3 G3: hay un arquero de PUESTO al otro lado del agua", arq.size() == 1 and (arq[0] as Combate3D).fijo and (arq[0] as Combate3D).arquero)
	if not await _ruta("3 G3", [[Vector2i(12, 3), TOL_EXACTA]]):
		return false
	var v0: float = float(jugador.get("vida"))
	await avanzar_s(7.0)
	var sin: float = v0 - float(jugador.get("vida"))
	_ok("3 G3 [legible]: quieta en la galería, las flechas del arquero hacen daño (%.0f en 7 s) y él está fuera del alcance de las suyas" % sin, sin > 0.5 and (arq[0] as Combate3D).global_position.distance_to(jugador.position) > ALCANCE_FLECHA_CAS * Terreno3D.casilla)
	_curar()
	_ok("3 G3: tierra + ᛜ + ᛁ entre la jugadora y el arquero (12,4) sale", await _lanzar("tierra", ["barrera", "linea"], Vector2i(12, 4), true))
	await avanzar_s(0.5)
	v0 = float(jugador.get("vida"))
	await avanzar_s(7.0)
	var con: float = v0 - float(jugador.get("vida"))
	_ok("3 G3: tras la barrera ninguna flecha llega (%.0f de daño en 7 s)" % con, con < 0.5)
	_curar()
	return await _ruta("3 G3", [Vector2i(13, 3), Vector2i(15, 3), Vector2i(17, 3)])


# ---------------------------------------------------------------------------------------------------------------------
#  4 · G4 · La charca: el puente
# ---------------------------------------------------------------------------------------------------------------------

func _g4() -> bool:
	if not await _ruta("4 G4", [Vector2i(19, 3), [Vector2i(20, 4), TOL_EXACTA]]):
		return false
	_ok("4 G4 [legible]: el agua corta la sala: (20,5) y (20,6) no se pisan", Terreno3D.bloqueada(Vector2i(20, 5)) and Terreno3D.bloqueada(Vector2i(20, 6)))
	_ok("4 G4: hielo + ᛜ sobre el agua (20,5) sale", await _lanzar("hielo", ["barrera"], Vector2i(20, 5), true))
	await avanzar_s(0.6)
	if Terreno3D.bloqueada(Vector2i(20, 6)):
		await avanzar_s(3.0)                       # la recarga de la barrera
		_ok("4 G4: hielo + ᛜ sobre la segunda casilla (20,6) sale", await _lanzar("hielo", ["barrera"], Vector2i(20, 6), true))
	await _esperar(func() -> bool: return Terreno3D.hielo_fisico(Vector2i(20, 5)) and Terreno3D.hielo_fisico(Vector2i(20, 6)), 3.0)
	_ok("4 G4: el agua se HIELA y se pisa", Terreno3D.hielo_fisico(Vector2i(20, 5)) and Terreno3D.hielo_fisico(Vector2i(20, 6)) and not Terreno3D.bloqueada(Vector2i(20, 6)))
	return await _ruta("4 G4", [Vector2i(20, 5), Vector2i(20, 6), Vector2i(20, 8), Vector2i(20, 10), Vector2i(20, 11)])


# ---------------------------------------------------------------------------------------------------------------------
#  5 · G5 · El paso batido: puente y escudo a la vez
# ---------------------------------------------------------------------------------------------------------------------

func _g5() -> bool:
	var celdas: Array = [Vector2i(18, 17), Vector2i(22, 17)]
	_ok("5 G5: dos arqueros de puesto en la otra orilla", _arqueros(celdas).size() == 2)
	if not await _ruta("5 G5", [[Vector2i(20, 12), TOL_EXACTA]]):
		return false
	var v_antes: float = float(jugador.get("vida"))
	await avanzar_s(6.0)
	_ok("5 G5 [legible]: en la orilla, sin escudo, los arqueros de la otra orilla aciertan (%.0f de daño en 6 s)" % (v_antes - float(jugador.get("vida"))), v_antes - float(jugador.get("vida")) > 0.5)
	_curar()
	var v0: float = float(jugador.get("vida"))
	_ok("5 G5: hielo + ᛜ + ᛁ sobre el río (20,13) sale: puente y escudo", await _lanzar("hielo", ["barrera", "linea"], Vector2i(20, 13), true))
	await avanzar_s(3.2)
	_ok("5 G5: hielo + ᛜ + ᛁ sobre la segunda fila (20,14) sale", await _lanzar("hielo", ["barrera", "linea"], Vector2i(20, 14), true))
	await _esperar(func() -> bool: return Terreno3D.hielo_fisico(Vector2i(20, 13)) and Terreno3D.hielo_fisico(Vector2i(20, 14)), 3.0)
	_ok("5 G5: las dos filas del río se pisan", Terreno3D.hielo_fisico(Vector2i(20, 13)) and Terreno3D.hielo_fisico(Vector2i(20, 14)))
	if not await _ruta("5 G5", [Vector2i(20, 13), Vector2i(20, 14), Vector2i(20, 15)]):
		return false
	var dano: float = v0 - float(jugador.get("vida"))
	_ok("5 G5: se cruza el río bajo los arqueros (daño recibido: %.0f, de 100)" % dano, celda_jugador().y >= 15 and dano < 60.0)
	_ok("5 G5: en su orilla, los dos arqueros caen a flechazos de fuego", await _tumbar(celdas, Rect2i(17, 15, 7, 3)))
	await _esperar(func() -> bool: return Flags.i().tiene("gruta.g5.arqueros"), 2.0)
	_ok("5 G5: el vigía lo apunta (flag gruta.g5.arqueros)", Flags.i().tiene("gruta.g5.arqueros"))
	_curar()
	return await _ruta("5 G5", [Vector2i(18, 16), Vector2i(16, 16), Vector2i(15, 16)])


# ---------------------------------------------------------------------------------------------------------------------
#  6 · G6 · El santuario: los cuatro usos, el glifo y el atajo
# ---------------------------------------------------------------------------------------------------------------------

func _g6() -> bool:
	var celdas: Array = [Vector2i(9, 11), Vector2i(15, 11)]
	var br_a: Reactivo3D = _z.nodo("br_g6a") as Reactivo3D
	var br_b: Reactivo3D = _z.nodo("br_g6b") as Reactivo3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_g6") as Puzle3D.PuertaPuzle
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var placa: Pulsador3D = _z.nodo("placa_atajo") as Pulsador3D
	var atajo: Puzle3D.PuertaPuzle = _z.nodo("atajo") as Puzle3D.PuertaPuzle
	_ok("6 G6: braseros, puerta, cofre legendario, placa y atajo están; dos arqueros", br_a != null and br_b != null and puerta != null and tesoro != null and placa != null and atajo != null and _arqueros(celdas).size() == 2)
	if br_a == null or br_b == null or puerta == null or tesoro == null or placa == null or atajo == null:
		return false
	_ok("6 G6: el cofre está tras su puerta cerrada y el atajo cerrado", not puerta.abierta and tesoro.es_cerrado and not atajo.abierta)
	# Cruzar el agua (dos filas) sobre hielo, que también para las flechas.
	if not await _ruta("6 G6", [Vector2i(13, 16), [Vector2i(12, 16), TOL_EXACTA]]):
		return false
	_ok("6 G6: hielo + ᛜ + ᛁ sobre el agua (12,15) sale", await _lanzar("hielo", ["barrera", "linea"], Vector2i(12, 15), true))
	await avanzar_s(3.2)
	_ok("6 G6: hielo + ᛜ + ᛁ sobre (12,14) sale", await _lanzar("hielo", ["barrera", "linea"], Vector2i(12, 14), true))
	await _esperar(func() -> bool: return Terreno3D.hielo_fisico(Vector2i(12, 15)) and Terreno3D.hielo_fisico(Vector2i(12, 14)), 3.0)
	if not await _ruta("6 G6", [Vector2i(12, 15), Vector2i(12, 14), Vector2i(12, 13)]):
		return false
	_ok("6 G6: se llega a la orilla norte, frente a las rejas", celda_jugador().y == 13)
	# Los arqueros de las esquinas quedan a tiro: se les tumba antes de ponerse a encender.
	_ok("6 G6: en la orilla norte, los dos arqueros de las esquinas caen", await _tumbar(celdas, Rect2i(9, 13, 7, 1)))
	_curar()
	# Los dos braseros, cada uno tras su reja.
	if not await _ruta("6 G6", [[Vector2i(11, 13), TOL_EXACTA]]):
		return false
	_ok("6 G6: fuego + flecha al brasero de la izquierda sale", await _lanzar("fuego", ["flecha"], Vector2i(11, 11)))
	await avanzar_s(2.0)
	_ok("6 G6 [legible]: la flecha no pasa la reja", not br_a.is_lit)
	_ok("6 G6: fuego + ᛜ tras la reja izquierda sale", await _lanzar("fuego", ["barrera"], Vector2i(11, 11), true))
	await _esperar(func() -> bool: return br_a.is_lit, 3.0)
	_ok("6 G6: el brasero izquierdo arde; la puerta aún no", br_a.is_lit and not puerta.abierta)
	if not await _ruta("6 G6", [[Vector2i(13, 13), TOL_EXACTA]]):
		return false
	await avanzar_s(3.0)                           # la recarga de la barrera
	_ok("6 G6: fuego + ᛜ tras la reja derecha sale", await _lanzar("fuego", ["barrera"], Vector2i(13, 11), true))
	await _esperar(func() -> bool: return br_b.is_lit and puerta.abierta, 4.0)
	_ok("6 G6: los DOS braseros arden y se abre la puerta del cofre", br_b.is_lit and puerta.abierta and not Terreno3D.bloqueada(Vector2i(12, 12)))
	if not await _ruta("6 G6", [[Vector2i(12, 12), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	_ok("6 G6: con E arranca la secuencia del cofre legendario", tesoro.secuencia != null and tesoro.secuencia.activa)
	await _esperar(func() -> bool: return tesoro.secuencia != null and tesoro.secuencia.hecha, 14.0)
	_ok("6 G6: EL GLIFO: el cofre da ᛉ permanencia y queda en el libro", Repertoire.sigil_active("permanencia") and tesoro.es_abierto and Flags.i().tiene("gruta.g6.glifo"))
	await avanzar_s(1.0)
	# El atajo: de vuelta a la orilla sur (el hielo de antes ya se ha fundido: se vuelve a tender).
	if not await _ruta("6 G6", [[Vector2i(12, 13), TOL_EXACTA]]):
		return false
	for c in [Vector2i(12, 14), Vector2i(12, 15)]:
		if not Terreno3D.hielo_fisico(c):
			await avanzar_s(3.2)
			await _lanzar("hielo", ["barrera"], c, true)
			await _esperar(func() -> bool: return Terreno3D.hielo_fisico(c), 3.0)
	if not await _ruta("6 G6", [Vector2i(12, 14), Vector2i(12, 15), Vector2i(12, 16), [Vector2i(13, 17), TOL_EXACTA]]):
		return false
	# Sin ᛉ: la barrera normal se deshace antes de llegar andando y la puerta se cierra delante.
	_ok("6 G6: tierra + ᛜ (sin ᛉ) sobre la placa del atajo (15,17) sale", await _lanzar("tierra", ["barrera"], Vector2i(15, 17), true))
	await _esperar(func() -> bool: return atajo.abierta, 2.0)
	var t_abre: float = reloj.t
	for c in [Vector2i(12, 16), Vector2i(10, 16), Vector2i(9, 16)]:
		await _andar_a(c, 14.0)
	await _esperar(func() -> bool: return not atajo.abierta, 6.0)
	_ok("6 G6 [legible]: SIN ᛉ la barrera se deshace (%.1f s) antes de llegar andando: el atajo se cierra delante" % (reloj.t - t_abre), not atajo.abierta and celda_jugador().x >= 9)
	# Con ᛉ ᛉ: el primer uso del glifo del cofre.
	if not await _ruta("6 G6", [Vector2i(11, 16), Vector2i(12, 16), [Vector2i(13, 17), TOL_EXACTA]]):
		return false
	await _esperar(func() -> bool: return not placa.activo, 4.0)
	_ok("6 G6: PRIMER USO de ᛉ: tierra + ᛜ + ᛉ ᛉ sobre la placa del atajo sale", await _lanzar("tierra", ["barrera", "permanencia", "permanencia"], Vector2i(15, 17), true))
	await _esperar(func() -> bool: return atajo.abierta, 2.0)
	t_abre = reloj.t
	_ok("6 G6: la placa se pisa y el atajo se abre", placa.activo and atajo.abierta)
	if not await _ruta("6 G6", [Vector2i(12, 16), Vector2i(10, 16), Vector2i(9, 16), Vector2i(8, 16), Vector2i(7, 16)]):
		return false
	_ok("6 G6: con ᛉ ᛉ se cruza el atajo a G1 a pie antes de que se cierre (%.1f s desde que se abrió)" % (reloj.t - t_abre), celda_jugador().x <= 7)
	_ok("FIN: de la boca al glifo ᛉ y de vuelta a G1 por el atajo, a pie y con hechizos reales", celda_jugador().x <= 7 and Repertoire.sigil_active("permanencia"))
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  7 · Volver a entrar: lo resuelto sigue resuelto
# ---------------------------------------------------------------------------------------------------------------------

func _recargar_gruta() -> void:
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA_GRUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	await avanzar_s(1.0)
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_g6") as Puzle3D.PuertaPuzle
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	_ok("7 recarga: la puerta del santuario nace abierta y el cofre abierto; ᛉ sigue en el libro", puerta != null and puerta.abierta and tesoro != null and tesoro.es_abierto and Repertoire.sigil_active("permanencia"))
	_ok("7 recarga: los arqueros vencidos de G5 y G6 no vuelven", _arqueros([Vector2i(18, 17), Vector2i(22, 17), Vector2i(9, 11), Vector2i(15, 11)]).is_empty())
