extends "res://herramientas/escenario_base.gd"
## LA ARENA DE COMBATE (21/11; mapas/ArenaCombate.txt, escenas/PruebaArenaCombate.tscn): la sala reutilizable para probar enemigos a mano. Comprueba que sus piezas
## salen montadas y juega lo esencial de cada enemigo con hechizos lanzados por el camino de verdad (`Lanzador3D.lanzar_ahora`):
##   · GOBLIN CON ESCUDO: una flecha de tierra de frente choca con el ESCUDO (su caja de choque) y no con el goblin; una de fuego lo prende y el goblin se queda quemándose el brazo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_arena_combate.gd

const RUTA_ARENA: String = "res://escenas/PruebaArenaCombate.tscn"
var _z: Puzle3D = null


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _preparar(desde: Vector2i, elemento: String, glifos: Array = ["flecha"]) -> Dictionary:
	colocar_jugador(desde)
	(jugador as Jugador3D).vida = 100000.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _disparar(desde: Vector2i, elemento: String, dir: Vector3, espera: float = 1.2, glifos: Array = ["flecha"]) -> void:
	var d: Dictionary = _preparar(desde, elemento, glifos)
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	var ok: bool = not d.is_empty() and lanzador.lanzar_ahora(d, jugador.position, dir)
	if not ok:
		print("  NO SE LANZÓ ", elemento, " preparado=", not d.is_empty(), " motivo=", lanzador.rechazo_de_construccion(d, jugador.position, dir) if not d.is_empty() else "-")
	await avanzar_s(espera)


## Gira al enemigo (su mirada y su modelo) hacia `dir` de golpe.
func _mirar(c: Combate3D, dir: Vector3) -> void:
	c.mirada = dir
	if c.pj != null:
		c.pj.mirar(dir, 1.0)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_ARENA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la arena tiene sus piezas", _z != null)
	if _z == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(10)
	await _escudo()
	await _mouro()


## MOURO (6,7) y su MÁMOA (4,4). Vuelve siempre; una flecha de agua que pasa POR ENCIMA del pozo no lo tapa; el suelo mojado en su casilla lo inunda y entonces muere de verdad.
## Su aura envenena a la jugadora si se le acerca.
func _mouro() -> void:
	var mo: MouroEspectro3D = _z.nodo("mouro_arena") as MouroEspectro3D
	var m: Mamoa3D = _z.nodo("tumba_arena") as Mamoa3D
	_ok("2 el mouro sale enlazado a su mámoa", mo != null and m != null and mo.mamoa == m)
	if mo == null or m == null:
		return
	mo.quieto = true
	await avanzar(5)
	_ok("2 lleva su aura de veneno", mo.aura != null and is_instance_valid(mo.aura))
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(Terreno3D.celda_de(mo.global_position))            # dentro de su aura (radio 1 casilla)
	j.vida = 1000.0
	var v0: float = j.vida
	await avanzar_s(2.0)
	_ok("2 cerca de él la jugadora se envenena", j.vida < v0, "vida %.1f → %.1f" % [v0, j.vida])
	colocar_jugador(Vector2i(2, 2))
	j.vida = 1000.0
	for i in range(4):
		mo.receive_damage(100000.0)
		await avanzar_s(MouroEspectro3D.T_REBROTE + 0.4)
	_ok("2 cuatro muertes, cuatro vueltas (sin límite)", not mo.muerto and not mo.latente and mo.rebrotes_gastados == 4, "rebrotes %d" % mo.rebrotes_gastados)
	# Una flecha de agua que cruza por encima del pozo (de oeste a este por la fila 4) no moja su casilla.
	await _disparar(Vector2i(2, 4), "agua", Vector3(1, 0, 0), 1.2)
	_ok("2 la flecha de agua que pasa por encima NO tapa la tumba", m.abierta and not m.inundada)
	# Un charco: el suelo de su casilla mojado (lo que deja el agua al caer al suelo).
	Terreno3D.estados.aplicar(m.celda, "agua")
	await avanzar_s(0.5)
	_ok("2 con su casilla mojada el pozo se inunda (tapado)", not m.abierta and m.inundada)
	mo.receive_damage(100000.0)
	await avanzar_s(1.0)
	_ok("2 ahora el mouro muere de verdad", mo.muerto)


## GOBLIN CON ESCUDO (escudo_a en 13,4). Ella dispara desde el oeste (8,4) hacia el este: el goblin mira al oeste, el disparo le llega de frente.
func _escudo() -> void:
	var a: Combate3D = _z.nodo("escudo_a") as Combate3D
	var b: Combate3D = _z.nodo("escudo_b") as Combate3D
	_ok("1 las dos piezas `goblin_escudo` montan un goblin CON escudo", a != null and b != null and a.escudo != null and b.escudo != null)
	if a == null or a.escudo == null:
		return
	a.quieto = true
	if b != null:
		# El de abajo (13,9) recibe AGUA de frente: la para el escudo (lo moja), sin daño, y lo empuja un poco con el clip de bloqueo.
		b.quieto = true
		_mirar(b, Vector3(-1, 0, 0))
		await avanzar(3)
		b.health = 1000.0
		var bloq_b: int = b.escudo.bloqueos
		await _disparar(Vector2i(11, 9), "agua", Vector3(1, 0, 0), 1.5)
		_ok("1 el agua de frente choca con el escudo: bloqueo, sin daño y un empujón leve", b.escudo.bloqueos > bloq_b and b.health == 1000.0 and b.escudo.empujes_bloqueo >= 1,
			"bloqueos %d → %d · vida %.0f · empujes %d" % [bloq_b, b.escudo.bloqueos, b.health, b.escudo.empujes_bloqueo])
	# El de arriba (13,4) recibe FUEGO de frente: arde y se queda quemándose el brazo.
	_mirar(a, Vector3(-1, 0, 0))
	await avanzar(3)
	a.health = 1000.0
	await _disparar(Vector2i(11, 4), "fuego", Vector3(1, 0, 0), 1.5)
	_ok("1 el fuego no le hace daño a él: lo recibe el escudo", a.health == 1000.0, "vida %.0f" % a.health)
	_ok("1 la de fuego lo prende y el goblin se queda quemándose el brazo", a.escudo.esta_ardiendo() and a.escudo.ocupa_al_goblin(), a.escudo.estado)
	await avanzar_s(Escudo3D.T_CONSUMO + 0.5)
	_ok("1 consumido: el goblin pelea sin escudo y sin su defensa", a.escudo.estado == "quemado" and a.defensa < Dano.DEF_ESCUDO, "%s · def %.1f" % [a.escudo.estado, a.defensa])
