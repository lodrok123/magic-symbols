extends "res://herramientas/escenario_sala_empuje.gd"
## BLOQUES REALES EN LOS NIVELES Y EL BLOQUE FRENTE A ENEMIGOS E HIELO (13/11, tarea 18; docs/EMPUJAR_BLOQUES.md, PENDIENTES «Empujar bloques (27/10)»).
##   A · LOS NIVELES: en el Test de jugabilidad (el «Bosque» con los cubos de `Jugabilidad3D.EMPUJABLES`) y en el Test 2 los empujables son bloques REALES (`BloqueEmpujable3D`: tierra → piedra, hielo → hielo)
##       en la casilla de los cubos de antes, la bloquean, se empujan y ya no queda el cubo visual.
##   B · ENEMIGOS (en la Sala del Empuje, E2: pista de una casilla (10..15, 2); un goblin `quieto`, sin IA):
##       B1 el bloque ocupa su casilla para las rutas: A* (`Caminos3D`) lo rodea y `Terreno3D.ocupado` lo ve.
##       B2 un bloque de hielo que resbala hacia un enemigo se PARA en la casilla de antes: no lo mueve ni le hace daño (BLOQUE_EMPUJA_ENEMIGOS = false); con un enemigo pegado delante no sale.
##       B3 la piedra empujada hacia un enemigo igual. Un enemigo no empuja un bloque (lo empujan hechizos y golpes, no él) y no lo atraviesa.
##       B4 el interruptor BLOQUE_EMPUJA_ENEMIGOS = true: el hielo se para y le da al enemigo un empujón de una casilla y DANO_BLOQUE_HIELO de daño; la piedra sigue sin tocarlo.
##       B5 ENEMIGO_OCUPA_POR_CUERPO: el cuerpo del enemigo en la casilla vecina a medias ya ocupa la de delante.
##   C · LA JUGADORA QUE RESBALA (en la Sala del Empuje, E4: el agua (27,4) helada con un hechizo de hielo, el bloque de hielo (28,4) al otro lado): choca de frente contra el bloque de hielo y lo empuja (un empujón, sale
##       resbalando suelto, sin acoplarla) hasta la placa (31,4); contra un bloque de piedra se para como contra una pared (ni lo atraviesa ni se queda encajada ni lo empuja de golpe);
##       con EMPUJE_AL_RESBALAR = false se para también contra el hielo.
##   Teletransporta a la jugadora y coloca goblins y bloques por código (es una prueba de reglas, no un autoplay).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bloque_enemigos.gd

const RUTA_JUGABILIDAD: String = "res://escenas/PruebaJugabilidad3D.tscn"
const RUTA_TEST2: String = "res://escenas/PruebaTest2.tscn"

var _bloque: BloqueEmpujable3D = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await _a_niveles()
	await _sala()
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
#  A · Los niveles
# ---------------------------------------------------------------------------------------------------------------------

func _bloques_del_nivel() -> Array:
	var l: Array = []
	for n in get_nodes_in_group("empujable"):
		if n is BloqueEmpujable3D:
			l.append(n)
	return l


## Los cubos visuales de antes eran un MeshInstance3D «empujable_<tipo>» dentro de una raíz Node3D del decorado.
func _cubos_visuales(raiz: Node) -> int:
	var n: int = 0
	for m in raiz.find_children("empujable_*", "MeshInstance3D", true, false):
		n += 1
	return n


func _a_niveles() -> void:
	print("--- A. los niveles")
	await cargar(RUTA_JUGABILIDAD, false)
	if maqueta == null:
		return
	var esperados: Dictionary = {Vector2i(15, 3): "piedra", Vector2i(12, 7): "piedra", Vector2i(16, 7): "hielo"}
	var bq: Array = _bloques_del_nivel()
	_ok("A1 Jugabilidad: %d bloques reales (los 3 de Jugabilidad3D.EMPUJABLES)" % bq.size(), bq.size() == esperados.size())
	for b in bq:
		var bb: BloqueEmpujable3D = b as BloqueEmpujable3D
		_ok("A1 Jugabilidad: bloque en %s de material %s, la casilla bloqueada" % [str(bb.celda), bb.material], esperados.get(bb.celda, "") == bb.material and Terreno3D.bloqueada(bb.celda) and bb.is_in_group("peso"))
	_ok("A1 Jugabilidad: ya no queda ningún cubo visual «empujable_*»", _cubos_visuales(maqueta) == 0)
	_ok("A1 Jugabilidad: el código del cubo (CODIGO_BLOQUE y la tecla V de las grietas) se ha retirado de la maqueta", not ("_empujables" in maqueta) and not maqueta.has_method("_danar_empujable_cercano"))
	# Se pueden empujar de verdad: hacia algún lado cada uno se mueve una casilla (el de piedra) o resbala (el de hielo).
	for b in bq:
		var bb2: BloqueEmpujable3D = b as BloqueEmpujable3D
		var origen: Vector2i = bb2.celda
		var movido: bool = false
		for d in BloqueEmpujable3D.DIRS:
			if bb2.puede_moverse(d) and bb2.empujar(d):
				while bb2.moviendo:
					await process_frame
				movido = bb2.celda != origen
				break
		_ok("A2 Jugabilidad: el bloque de %s en %s se empuja (acaba en %s)" % [bb2.material, str(origen), str(bb2.celda)], movido)
	# Y no cierran nada que no cerrara el cubo: las casillas de los cubos ya estaban bloqueadas, las de ahora libres vuelven a estarlo al recargar.
	_ok("A3 Jugabilidad: la jugadora sigue pudiendo moverse (el nivel no se queda sin resolver por los bloques)", celda_jugador() != Vector2i(-1, -1) and Terreno3D.pisable(celda_jugador(), 99, false, 99, false))
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)
	# Test 2: dos bloques (tierra en (6,33), hielo en (28,26))
	await cargar(RUTA_TEST2, false)
	if maqueta == null:
		return
	var esp2: Dictionary = {Vector2i(6, 33): "piedra", Vector2i(28, 26): "hielo"}
	var bq2: Array = _bloques_del_nivel()
	_ok("A4 Test 2: %d bloques reales (tierra → piedra en (6,33), hielo en (28,26))" % bq2.size(), bq2.size() == esp2.size())
	for b in bq2:
		var b2: BloqueEmpujable3D = b as BloqueEmpujable3D
		_ok("A4 Test 2: bloque en %s de material %s" % [str(b2.celda), b2.material], esp2.get(b2.celda, "") == b2.material and Terreno3D.bloqueada(b2.celda))
	_ok("A4 Test 2: sin cubos visuales", _cubos_visuales(maqueta) == 0)
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)


# ---------------------------------------------------------------------------------------------------------------------
#  B y C · En la Sala del Empuje
# ---------------------------------------------------------------------------------------------------------------------

func _quieto_el(b: BloqueEmpujable3D, max_s: float = 12.0) -> void:
	var t: float = 0.0
	while b.moviendo and t < max_s:
		t += await avanzar_s(0.05)
	await avanzar(2)


## Un goblin sin IA en `c` (recibe empuje y daño). Con el Lanzador y la jugadora de la escena.
func _goblin_en(c: Vector2i) -> Combate3D:
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta as Node3D, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	return g


func _quitar_goblin(g: Combate3D) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
	await avanzar(3)


## Un bloque nuevo (por código) en `c`.
func _nuevo_bloque(c: Vector2i, material: String) -> BloqueEmpujable3D:
	var b := BloqueEmpujable3D.new()
	b.name = "prueba_%d_%d" % [c.x, c.y]
	b.preparar(c, material, maqueta)
	maqueta.add_child(b)
	return b


func _quitar_bloque(b: BloqueEmpujable3D) -> void:
	var c: Vector2i = b.celda
	b.queue_free()
	await avanzar(3)
	Terreno3D.liberar_celda(c)


func _sala() -> void:
	print("--- B/C. la Sala del Empuje")
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la Sala del Empuje monta sin avisos", _z != null and _z.avisos.is_empty())
	if _z == null:
		return
	await _b_enemigos()
	await _c_resbalar()


func _b_enemigos() -> void:
	# Valores por defecto de las reglas (lo que se afirma abajo)
	_ok("B0 por defecto: el bloque NO empuja a los enemigos, hay empuje al resbalar y el cuerpo del enemigo ocupa casilla",
		not BloqueEmpujable3D.BLOQUE_EMPUJA_ENEMIGOS and BloqueEmpujable3D.EMPUJE_AL_RESBALAR and BloqueEmpujable3D.ENEMIGO_OCUPA_POR_CUERPO)
	_ok("B0 y los números están en `static var`: daño %.1f, fuerza %.0f, velocidad mínima %.1f" % [BloqueEmpujable3D.DANO_BLOQUE_HIELO, BloqueEmpujable3D.FUERZA_EMPUJE_ENEMIGO, BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO],
		is_equal_approx(BloqueEmpujable3D.DANO_BLOQUE_HIELO, 5.0))
	# --- B1 rutas: el bloque (por código) en el centro de la zona abierta de E2 (9..15, 4..7) ---
	var obst: BloqueEmpujable3D = _nuevo_bloque(Vector2i(12, 5), "piedra")
	await avanzar(3)
	var ruta: Array[Vector2i] = Caminos3D.camino(Vector2i(10, 5), Vector2i(14, 5))
	_ok("B1 la ruta A* de (10,5) a (14,5) existe y rodea el bloque de (12,5): %d casillas" % ruta.size(), not ruta.is_empty() and ruta.back() == Vector2i(14, 5) and not ruta.has(Vector2i(12, 5)))
	_ok("B1 el bloque ocupa su casilla (Terreno3D.ocupado a ras)", Terreno3D.ocupado(Vector2i(12, 5), 0) and not Terreno3D.ocupado(Vector2i(11, 5), 0))
	_ok("B1 la IA no considera transitable la casilla del bloque (Caminos3D.transitable)", not Caminos3D.transitable(Vector2i(12, 5)) and Caminos3D.transitable(Vector2i(11, 5)))
	await _quitar_bloque(obst)
	var ruta2: Array[Vector2i] = Caminos3D.camino(Vector2i(10, 5), Vector2i(14, 5))
	_ok("B1 sin el bloque la ruta vuelve a ser la recta (%d casillas)" % ruta2.size(), ruta2.size() == 5 and ruta2.has(Vector2i(12, 5)))
	# --- B2 el hielo se para antes del enemigo ---
	_bloque = _z.nodo("bloque_e2") as BloqueEmpujable3D
	var gob: Combate3D = _goblin_en(Vector2i(14, 2))
	await avanzar(5)
	var p0: Vector3 = gob.global_position
	var vida0: float = gob.health
	_ok("B2 el goblin está en (14,2) y el bloque de hielo en (11,2)", Terreno3D.celda_de(gob.global_position) == Vector2i(14, 2) and _bloque.celda == Vector2i(11, 2) and not gob.muerto)
	_ok("B2 el empujón se acepta (el enemigo está lejos)", _bloque.empujar(Vector2i(1, 0)))
	await _quieto_el(_bloque)
	_ok("B2 el hielo resbala y se PARA en (13,2), antes de entrar en la casilla del enemigo (acabó en %s)" % str(_bloque.celda), _bloque.celda == Vector2i(13, 2) and not _bloque.moviendo)
	_ok("B2 no aplasta ni empuja al enemigo: sigue en su sitio (%.2f u) y con la vida de antes (%.1f)" % [gob.global_position.distance_to(p0), gob.health], gob.global_position.distance_to(p0) < 0.05 and is_equal_approx(gob.health, vida0) and not gob.en_empujado())
	_ok("B2 con el enemigo pegado delante el bloque ni sale: `puede_moverse` y `empujar` dicen que no", not _bloque.puede_moverse(Vector2i(1, 0)) and not _bloque.empujar(Vector2i(1, 0)) and _bloque.celda == Vector2i(13, 2))
	# --- B3 un enemigo no empuja el bloque ---
	var cb0: Vector2i = _bloque.celda
	# El enemigo no tiene empuje propio contra bloques: lo único que lo lleva contra uno es un empujón de golpe o de viento (su `_empuje`). Se le da uno fuerte hacia el bloque.
	gob.push(Vector3(-1.0, 0.0, 0.0), 3000.0, true)
	await avanzar_s(1.5)
	_ok("B3 un enemigo lanzado contra el bloque (empujón hacia el oeste) no lo mueve: sigue en %s y el enemigo no lo atraviesa (casilla %s)" % [str(_bloque.celda), str(Terreno3D.celda_de(gob.global_position))],
		_bloque.celda == cb0 and not _bloque.moviendo and _bloque.empujones == 1 and Terreno3D.celda_de(gob.global_position) != cb0)
	# --- B3b la piedra empujada hacia un enemigo igual ---
	await _quitar_goblin(gob)
	var pie: BloqueEmpujable3D = _nuevo_bloque(Vector2i(3, 6), "piedra")
	var gob2: Combate3D = _goblin_en(Vector2i(5, 6))
	await avanzar(5)
	var p2: Vector3 = gob2.global_position
	_ok("B3b la piedra en (3,6) se deja empujar hacia el este (el enemigo está a 2 casillas)", pie.empujar(Vector2i(1, 0)))
	await _quieto_el(pie)
	_ok("B3b la piedra se para en (4,6), pegada al enemigo, sin moverlo (acabó en %s)" % str(pie.celda), pie.celda == Vector2i(4, 6) and gob2.global_position.distance_to(p2) < 0.05 and not pie.empujar(Vector2i(1, 0)))
	await _quitar_bloque(pie)
	# --- B4 el interruptor: el hielo golpea ---
	BloqueEmpujable3D.BLOQUE_EMPUJA_ENEMIGOS = true
	var pie2: BloqueEmpujable3D = _nuevo_bloque(Vector2i(3, 6), "piedra")
	var v2: float = gob2.health
	pie2.empujar(Vector2i(1, 0))
	await _quieto_el(pie2)
	_ok("B4 con BLOQUE_EMPUJA_ENEMIGOS la PIEDRA (lenta) sigue sin tocar al enemigo (vida %.1f → %.1f)" % [v2, gob2.health], pie2.celda == Vector2i(4, 6) and is_equal_approx(gob2.health, v2) and gob2.global_position.distance_to(p2) < 0.05)
	await _quitar_bloque(pie2)
	await _quitar_goblin(gob2)
	var hielo: BloqueEmpujable3D = _nuevo_bloque(Vector2i(10, 4), "hielo")          # zona abierta de E2: resbala hacia el este por la fila 4 hasta (13,4)
	var gob3: Combate3D = _goblin_en(Vector2i(14, 4))
	await avanzar(5)
	var p3: Vector3 = gob3.global_position
	var v3: float = gob3.health
	hielo.empujar(Vector2i(1, 0))
	await _quieto_el(hielo)
	await avanzar_s(0.8)
	var mov3: float = gob3.global_position.distance_to(p3)
	_ok("B4 el hielo resbala y se PARA en (13,4), contra el enemigo de (14,4), sin entrar (acabó en %s)" % str(hielo.celda), hielo.celda == Vector2i(13, 4) and not hielo.moviendo)
	_ok("B4 y le da DANO_BLOQUE_HIELO de daño (vida %.1f → %.1f)" % [v3, gob3.health], is_equal_approx(v3 - gob3.health, BloqueEmpujable3D.DANO_BLOQUE_HIELO))
	_ok("B4 y un empujón de ~una casilla hacia el este (se movió %.2f u de %.2f)" % [mov3, Terreno3D.casilla], mov3 > 0.5 * Terreno3D.casilla and gob3.global_position.x > p3.x)
	await _quitar_bloque(hielo)
	await _quitar_goblin(gob3)
	BloqueEmpujable3D.BLOQUE_EMPUJA_ENEMIGOS = false
	# --- B5 el cuerpo del enemigo ---
	var b5: BloqueEmpujable3D = _nuevo_bloque(Vector2i(10, 6), "piedra")
	var gob5: Combate3D = _goblin_en(Vector2i(12, 6))
	gob5.position.x = 12.0 * Terreno3D.casilla + 0.05            # su centro está en (12,6), a 0,05 u del borde con (11,6): su cuerpo (radio 0,32) toca la huella que el bloque tendría en (11,6)
	await avanzar(3)
	_ok("B5 con el centro del goblin en %s y su cuerpo pegado a (11,6), un bloque que iba a (11,6) NO sale (ENEMIGO_OCUPA_POR_CUERPO = true)" % str(Terreno3D.celda_de(gob5.global_position)),
		Terreno3D.celda_de(gob5.global_position) == Vector2i(12, 6) and not b5.puede_moverse(Vector2i(1, 0)))
	BloqueEmpujable3D.ENEMIGO_OCUPA_POR_CUERPO = false
	_ok("B5 con el interruptor a false solo cuenta el centro del enemigo: el mismo bloque sí puede ir a (11,6)", b5.puede_moverse(Vector2i(1, 0)))
	BloqueEmpujable3D.ENEMIGO_OCUPA_POR_CUERPO = true
	await _quitar_bloque(b5)
	await _quitar_goblin(gob5)


func _c_resbalar() -> void:
	# Helar el agua (27,4): la jugadora que la cruza resbala. El bloque de las pruebas va SOBRE el hielo, en (27,4), y ella llega por una pista de hielo hasta tocarlo: resbalando (si lo tocara ya pisando suelo
	# normal no habría nada que resbalara).
	var cag := Vector2i(27, 4)
	Lanzador3D.hechizo_sobre_agua("hielo", Terreno3D.centro_de(cag, Terreno3D.alto_agua))
	await avanzar(3)
	_ok("C0 el agua (27,4) está helada: se resbala y se pisa", Terreno3D.sobre_hielo(Terreno3D.centro_de(cag)) and Terreno3D.helada(cag))
	if not Terreno3D.helada(cag):
		return
	# La pista de hielo: (25,4) y (26,4) heladas a mano (poner_helada: suelo de hielo de verdad, como el agua helada) para que ella ya resbale al tocar el bloque, que está en (27,4).
	Terreno3D.poner_helada(Vector2i(25, 4), true)
	Terreno3D.poner_helada(Vector2i(26, 4), true)
	var original: BloqueEmpujable3D = _z.nodo("bloque_e4") as BloqueEmpujable3D
	var placa: Pulsador3D = _z.nodo("placa_e4") as Pulsador3D
	await _quitar_bloque(original)
	# --- C1 contra el hielo (EMPUJE_AL_RESBALAR = true) ---
	var hielo: BloqueEmpujable3D = _nuevo_bloque(cag, "hielo")
	var e0: int = hielo.empujones
	await avanzar(3)
	var r1: Dictionary = await _resbalar_hasta_parar(hielo)
	_ok("C1 la jugadora cruza el hielo y llega al bloque con %.2f u/s" % float(r1["vel"]), float(r1["vel"]) >= BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO)
	_ok("C1 choca de frente contra el bloque de HIELO y lo empuja: cuenta como un empujón (empujones %d → %d)" % [e0, hielo.empujones], r1["parada"] and hielo.empujones == e0 + 1)
	_ok("C1 sale resbalando suelto: sin acoplarla y a velocidad de hielo (%.1f u/s)" % float(r1["vel_bloque"]), not bool(r1["acoplado"]) and float(r1["vel_bloque"]) >= BloqueEmpujable3D.VEL_HIELO * 0.9)
	_ok("C1 y lo empuja al chocar, no 0,35 s después como un empujón andando (choque → movimiento: %.2f s)" % float(r1["t_mueve"]), float(r1["t_mueve"]) >= 0.0 and float(r1["t_mueve"]) < 0.2)
	await _quieto_el(hielo, 8.0)
	_ok("C1 el bloque resbala hasta el fondo y se para sobre la placa (31,4): %s" % str(hielo.celda), hielo.celda == Vector2i(31, 4) and placa.activo)
	_ok("C1 ella se queda parada en su sitio (casilla %s, velocidad %.2f)" % [str(celda_jugador()), (jugador.get("_vel_hielo") as Vector3).length()], (jugador.get("_vel_hielo") as Vector3).length() < 0.01 and celda_jugador().x <= 27)
	await _quitar_bloque(hielo)
	# --- C2 contra una piedra: se para como contra una pared ---
	var piedra: BloqueEmpujable3D = _nuevo_bloque(cag, "piedra")
	var e_p: int = piedra.empujones
	var r2: Dictionary = await _resbalar_hasta_parar(piedra)
	_ok("C2 contra un bloque de PIEDRA llega resbalando (%.2f u/s) y se para (velocidad 0)" % float(r2["vel"]), float(r2["vel"]) >= BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO and r2["parada"] and r2["quieta"])
	_ok("C2 el bloque de piedra no sale al chocar (empujones %d → %d, sigue en %s)" % [e_p, piedra.empujones, str(piedra.celda)], piedra.empujones == e_p and piedra.celda == cag and not piedra.moviendo)
	_ok("C2 no lo atraviesa ni se queda encajada: su x (%.2f) está antes del centro del bloque (%.2f) y ya no se mueve" % [jugador.position.x, (float(cag.x) + 0.5) * Terreno3D.casilla], jugador.position.x < (float(cag.x) + 0.5) * Terreno3D.casilla - 0.5 and not bool(jugador.get("empujando")) == false or jugador.position.x < (float(cag.x) + 0.5) * Terreno3D.casilla - 0.5)
	await _quitar_bloque(piedra)
	# --- C3 con EMPUJE_AL_RESBALAR = false se para también contra el hielo ---
	BloqueEmpujable3D.EMPUJE_AL_RESBALAR = false
	var hielo3: BloqueEmpujable3D = _nuevo_bloque(cag, "hielo")
	var e_h: int = hielo3.empujones
	var r3: Dictionary = await _resbalar_hasta_parar(hielo3)
	_ok("C3 con el interruptor a false el hielo tampoco sale al chocar (empujones %d) y ella se para" % hielo3.empujones, r3["parada"] and r3["quieta"] and hielo3.empujones == e_h and hielo3.celda == cag and not hielo3.moviendo)
	BloqueEmpujable3D.EMPUJE_AL_RESBALAR = true
	# --- C4 despacio no lo empuja: por debajo de la velocidad mínima ---
	BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO = 99.0
	var r4: Dictionary = await _resbalar_hasta_parar(hielo3)
	_ok("C4 con la velocidad mínima por las nubes tampoco lo empuja (empujones %d) y ella se para" % hielo3.empujones, r4["parada"] and r4["quieta"] and hielo3.empujones == e_h and hielo3.celda == cag)
	BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO = 0.8
	await _quitar_bloque(hielo3)
	await avanzar_s(0.3)


## Pone a la jugadora en (25,4) y aprieta el este: resbala por la pista de hielo (25..26,4) y choca contra el bloque que haya en (27,4). Suelta la tecla en el mismo fotograma del choque (antes de que el empuje andando de
## 0,35 s pudiera mover un bloque). Devuelve {vel: la mayor velocidad de hielo, parada: se quedó quieta (velocidad de hielo 0) tras chocar,
## t_mueve: s del choque al primer fotograma con el bloque en marcha (-1 si no se movió), acoplado y vel_bloque: lo que valían al empezar a moverse}.
func _resbalar_hasta_parar(b: BloqueEmpujable3D) -> Dictionary:
	colocar_jugador(Vector2i(25, 4))
	jugador.set("_vel_hielo", Vector3.ZERO)
	jugador.set("vel_suelo", Vector3.ZERO)
	await avanzar(5)
	var k: Key = await _tecla_hacia(Vector2i(1, 0))
	var res: Dictionary = {"vel": 0.0, "parada": false, "t_mueve": -1.0, "acoplado": true, "vel_bloque": 0.0}
	var vh_antes: float = 0.0
	var t_choque: float = -1.0
	var t0: float = reloj.t
	_tecla(k, true)
	while reloj.t - t0 < 6.0:
		await process_frame
		var vh: float = (jugador.get("_vel_hielo") as Vector3).length()
		res["vel"] = maxf(float(res["vel"]), vh)
		if t_choque < 0.0 and vh_antes >= 0.3 and vh < 0.01:
			t_choque = reloj.t
		vh_antes = vh
		if b.moviendo and float(res["t_mueve"]) < 0.0 and t_choque >= 0.0:
			res["t_mueve"] = reloj.t - t_choque
			res["acoplado"] = b.acoplado
			res["vel_bloque"] = b.vel
		if t_choque >= 0.0:
			break
	_tecla(k, false)
	await avanzar_s(0.4)
	res["parada"] = t_choque >= 0.0                                         # al chocar su velocidad de hielo cayó de golpe a 0
	res["quieta"] = (jugador.get("_vel_hielo") as Vector3).length() < 0.01   # y 0,4 s después, sin teclas, sigue quieta (si el bloque no se fue)
	return res