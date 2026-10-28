extends "res://herramientas/escenario_base.gd"
## LA SALA DEL GÓLEM (28/10; mapas/SalaGolem.txt, escenas/PruebaSalaGolem.tscn): la pieza `golem` monta el gólem y el vigía lo cuenta; vencido el último, aparece el cofre.
## Juega las DOS formas de vencerlo, con hechizos lanzados por el camino de verdad (`Lanzador3D.lanzar_ahora`), y que la flecha directa no le hace nada:
##   · FORMA 1 · ESQUIVAR Y CASTIGAR EL NÚCLEO. Un gólem persigue, saca su aviso, ella rueda en la ventana final (tiempo bruja), el golpe cae en vacío, queda de rodillas con el núcleo a la vista
##     y dos rayos (55 × 1,5 cada uno) lo matan dentro de la ventana.
##   · FORMA 2 · HIELO + VIENTO. Un hechizo de hielo hiela la franja de agua (3..8, 4); el gólem sobre el hielo recibe un viento y resbala hasta la charca honda: se hunde (+20 de tinta).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_sala_golem.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"
var _z: Puzle3D = null


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _preparar(desde: Vector2i, elemento: String) -> Dictionary:
	colocar_jugador(desde)
	(jugador as Jugador3D).vida = 100000.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _disparar(desde: Vector2i, elemento: String, dir: Vector3, espera: float = 1.2) -> void:
	var d: Dictionary = _preparar(desde, elemento)
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	lanzador.lanzar_ahora(d, jugador.position, dir)
	await avanzar_s(espera)


func _aviso_de(dueno: Node) -> AvisoAtaque3D:
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		if (a as AvisoAtaque3D).dueno == dueno and not (a as AvisoAtaque3D).cancelado:
			return a as AvisoAtaque3D
	return null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la sala tiene sus puzles", _z != null)
	if _z == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(10)
	var j: Jugador3D = jugador as Jugador3D
	var a: Golem3D = _z.nodo("golem_a") as Golem3D
	_ok("1 la pieza `golem` monta el gólem en (13,6)", a != null and Terreno3D.celda_de(a.casa) == Vector2i(13, 6))
	_ok("1 la sala aún no está limpia", not Flags.i().tiene("salagolem.sala.limpia"))
	if a == null:
		return
	a.quieto = true

	# --- La flecha directa no hace daño ---
	for el in ["fuego", "rayo", "tierra"]:
		await _disparar(Vector2i(11, 6), el, Vector3(1, 0, 0), 1.4)
	_ok("2 la flecha directa (fuego, rayo, tierra) no le hace daño: vida %.0f de 120" % a.health, is_equal_approx(a.health, 120.0) and a.g_estado == "armado")

	# --- FORMA 2 · hielo + viento hasta hundirlo ---
	await _disparar(Vector2i(1, 4), "hielo", Vector3(1, 0, 0), 2.0)
	var heladas: Array = []
	for x in range(3, 12):
		if Terreno3D.helada(Vector2i(x, 4)):
			heladas.append(x)
	_ok("3 un hechizo de hielo sobre la franja la hiela (casillas %s)" % str(heladas), heladas.size() >= 1)
	# El resto de la franja se hiela del todo (el hechizo hiela unas casillas; se completa para asegurar el camino) y la charca se queda honda.
	var franja: Array = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]
	var a_mano: int = 0
	for c in franja:
		if not Terreno3D.helada(c as Vector2i):
			Terreno3D.poner_helada(c as Vector2i, true)
			a_mano += 1
	for x in range(9, 12):
		for y in range(3, 6):
			if Terreno3D.helada(Vector2i(x, y)):
				Terreno3D.poner_helada(Vector2i(x, y), false)
	if a_mano > 0:
		_aviso("3 el hechizo de hielo no heló toda la franja: %d casillas se completaron a mano" % a_mano)
	_ok("3 la franja (3..8, 4) está helada y la charca (9, 4) sigue honda", Terreno3D.helada(Vector2i(3, 4)) and Terreno3D.helada(Vector2i(8, 4)) and not Terreno3D.helada(Vector2i(9, 4)))
	# El gólem sube al hielo (se coloca: aquí no se le atrae) y le llega el viento desde el oeste.
	a.position = _pos(Vector2i(6, 4))
	a.casa = a.position
	await avanzar(4)
	_ok("4 está sobre el hielo, de pie y armado", a.puede_resbalar())
	var tinta = lanzador.tinta
	var reg: Dictionary = {"antes": 0.0, "salto": -1.0}
	a.hundido.connect(func(_x) -> void: reg["salto"] = tinta.actual - float(reg["antes"]))
	var d: Dictionary = _preparar(Vector2i(4, 4), "viento")
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	lanzador.lanzar_ahora(d, jugador.position, Vector3(1, 0, 0))
	var n: int = 0
	while not a.muerto and n < 300:
		tinta.actual = 0.0
		reg["antes"] = tinta.actual
		await process_frame
		n += 1
	_ok("4 el viento lo hace resbalar por el hielo hasta la charca y se hunde", a.muerto and a.se_hundio and a.resbalones == 1, a.g_estado)
	_ok("4 y da +20 de tinta (C2)", float(reg["salto"]) > 19.0 and float(reg["salto"]) < 21.5, "+%.1f" % float(reg["salto"]))
	await avanzar_s(2.5)

	# --- FORMA 1 · esquivar y castigar el núcleo ---
	Terreno3D.estados.limpiar()
	colocar_jugador(Vector2i(8, 6))
	j.vida = 100000.0
	j._t_inv = 0.0
	var b: Golem3D = Golem3D.invocar_golem(maqueta, _pos(Vector2i(10, 6)), j, lanzador)
	_ok("5 aparece otro gólem", b != null)
	if b == null:
		return
	var av: AvisoAtaque3D = null
	n = 0
	while av == null and n < 600:
		await process_frame
		n += 1
		av = _aviso_de(b)
	_ok("5 persigue y, a 1,9 u, saca su aviso rojo", av != null and b.ataques == 1)
	if av == null:
		return
	while is_instance_valid(av) and av.queda() > 0.15:
		await avanzar(1)
	var veces: int = TiempoBruja.veces
	var vida0: float = j.vida
	j._iniciar_voltereta(Vector3(0, 0, -1))                                   # rueda de lado en la ventana final
	_ok("5 rodar en la ventana final abre el tiempo bruja", TiempoBruja.activa() and TiempoBruja.veces == veces + 1)
	n = 0
	while b.g_estado == "atacando" and n < 600:
		await process_frame
		n += 1
	_ok("5 el golpe cae en vacío: ni un punto de daño", j.vida >= vida0 and b.golpes_dados == 0, "vida %.0f → %.0f" % [vida0, j.vida])
	_ok("5 y queda de rodillas con el núcleo expuesto", b.g_estado == "expuesto")
	while not b.vulnerable():
		await process_frame
	# La jugadora se coloca a 2 casillas, detrás del gólem, y le dispara dos rayos.
	var cb: Vector2i = Terreno3D.celda_de(b.position)
	colocar_jugador(Vector2i(cb.x - 2, cb.y))
	await avanzar_s(0.3)
	_ok("5 el núcleo brilla: %.1f (reposo %.2f)" % [b.brillo_nucleo(), Golem3D.BRILLO_REPOSO], b.brillo_nucleo() > Golem3D.BRILLO_REPOSO * 3.0)
	var vida_b: float = b.health
	await _disparar(Vector2i(cb.x - 2, cb.y), "rayo", Vector3(1, 0, 0), 0.0)
	await _disparar(Vector2i(cb.x - 2, cb.y), "rayo", Vector3(1, 0, 0), 1.6)
	var murio: bool = not is_instance_valid(b) or b.muerto
	_ok("5 dos rayos (55 × 1,5 = 82,5 cada uno) lo vencen dentro de la ventana del núcleo (vida %.0f → %.0f)" % [vida_b, b.health if is_instance_valid(b) else 0.0], murio and (not is_instance_valid(b) or not b.se_hundio))
	await avanzar_s(2.5)
	# --- La sala ---
	await avanzar_s(1.5)
	_ok("6 con los dos vencidos, el vigía da la sala por limpia", Flags.i().tiene("salagolem.sala.limpia"))
	var cofre: Node = _z.nodo("cofre_golem")
	_ok("6 y aparece el cofre", cofre != null and bool(cofre.get("visible")))
