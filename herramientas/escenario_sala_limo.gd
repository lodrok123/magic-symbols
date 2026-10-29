extends "res://herramientas/escenario_base.gd"
## LA SALA DEL LIMO (28/10; mapas/SalaLimo.txt, escenas/PruebaSalaLimo.tscn): la pieza `limo` monta los tres limos con sus claves, el vigía los cuenta y, vencidos, aparece el cofre.
## Se dispara desde 2 casillas: el agua y la tierra vuelan en arco y a 1 casilla le pasan por encima al limo (mide 0,6 u).
## Los vence como en el juego: al de la izquierda con fuego (lo tiñe) y luego agua; al de fuego con agua; al grande de agua empujándolo con viento a la charca.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_sala_limo.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaLimo.tscn"
var _z: Puzle3D = null


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _lanzar_a(l: Limo3D, elemento: String, desde: Vector2i, dir: Vector3) -> void:
	l.quieto = true
	colocar_jugador(desde)
	(jugador as Jugador3D).vida = 1000.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	var d: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	lanzador.lanzar_ahora(d, jugador.position, dir)
	await avanzar_s(1.2)


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
	await avanzar(10)
	var neutro: Limo3D = _z.nodo("limo_neutro") as Limo3D
	var fuego: Limo3D = _z.nodo("limo_fuego") as Limo3D
	var grande: Limo3D = _z.nodo("limo_grande") as Limo3D
	_ok("1 la pieza `limo` monta los tres", neutro != null and fuego != null and grande != null)
	if neutro == null or fuego == null or grande == null:
		return
	_ok("1 cada uno con sus claves (sin teñir · fuego · grande de agua)", neutro.elemento == "" and not neutro.grande and fuego.elemento == "fuego" and not fuego.grande
		and grande.elemento == "agua" and grande.grande)
	_ok("1 en su casilla de partida", Terreno3D.celda_de(neutro.casa) == Vector2i(6, 2) and Terreno3D.celda_de(grande.casa) == Vector2i(14, 6))
	_ok("1 la sala aún no está limpia", not Flags.i().tiene("salalimo.sala.limpia"))
	# Al neutro: fuego lo tiñe; agua lo hiere hasta vencerlo.
	neutro.position = _pos(Vector2i(5, 2))
	await _lanzar_a(neutro, "fuego", Vector2i(7, 2), Vector3(-1, 0, 0))
	_ok("2 el fuego tiñe al neutro", neutro.elemento == "fuego")
	var n: int = 0
	while is_instance_valid(neutro) and not neutro.muerto and n < 12:
		neutro.position = _pos(Vector2i(5, 2))              # 29/10 (DANO_Y_TINTA): con 30 de vida y 9,6 por flecha ligera cada golpe lo empuja; se recoloca para el siguiente
		await _lanzar_a(neutro, "agua", Vector2i(7, 2), Vector3(-1, 0, 0))
		n += 1
	_ok("2 el agua lo vence (%d flechas)" % n, not is_instance_valid(neutro) or neutro.muerto)
	# Al de fuego: agua.
	fuego.position = _pos(Vector2i(9, 2))
	n = 0
	while is_instance_valid(fuego) and not fuego.muerto and n < 12:
		fuego.position = _pos(Vector2i(9, 2))
		await _lanzar_a(fuego, "agua", Vector2i(11, 2), Vector3(-1, 0, 0))
		n += 1
	_ok("3 el agua vence al de fuego (%d flechas)" % n, not is_instance_valid(fuego) or fuego.muerto)
	# Al grande de agua: a la charca con viento (desde el este, empujándolo al oeste).
	grande.position = _pos(Vector2i(14, 5))
	await _lanzar_a(grande, "viento", Vector2i(15, 5), Vector3(-1, 0, 0))
	await avanzar_s(1.5)
	_ok("4 el viento empuja al grande de agua a la charca y se hunde", not is_instance_valid(grande) or grande.se_hundio)
	await avanzar_s(1.0)
	_ok("5 el vigía da la sala por limpia", Flags.i().tiene("salalimo.sala.limpia"))
	var cofre: Node = _z.nodo("cofre_limo")
	_ok("5 y aparece el cofre", cofre != null and bool(cofre.get("visible")))
