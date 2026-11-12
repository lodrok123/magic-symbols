extends "res://herramientas/escenario_base.gd"
## 12/11 (Pablo: «los tocones no [se atraviesan]. Revisa que son reactivos al fuego para que un impacto cualquiera de fuego los prenda»). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_tocon_fuego.gd
## Carga el Bosque 02 de verdad (su Nivel_Bosque_02.tscn) y comprueba que TODOS sus tocones (`PruebaTest2.TOCONES`):
##   1. son objetos que arden (Reactivo3D de madera: inflamable), no decorado, lo diga o no el nivel con `bloquea`;
##   2. bloquean su casilla (hechizos, enemigos, rutas) y la jugadora choca con su contorno: en su centro no se puede estar;
##   3. un impacto de fuego (una flecha de fuego desde la casilla de al lado) los prende;
##   4. arden, se consumen y dejan libre su casilla.

const RUTA: String = "res://escenas/PruebaBosque02.tscn"


func _escenario() -> void:
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).muerto = true            # que nadie moleste mientras se dispara
	var n_nivel: int = 0
	var raiz: Node = (load("res://mundo/datos_nivel/Nivel_Bosque_02.tscn") as PackedScene).instantiate()
	for n in raiz.find_children("*", "Node3D", true, false):
		if n.has_meta("id") and (maqueta.get("TOCONES") as Array).has(String(n.get_meta("id"))):
			n_nivel += 1
	raiz.free()
	var tocones: Array = []
	for r in get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if r.has_meta("tocon"):
			tocones.append(r)
	_ok("1 los %d tocones del nivel son objetos que arden y no decorado (hay %d)" % [n_nivel, tocones.size()], n_nivel > 0 and tocones.size() == n_nivel)
	var lotes: Dictionary = maqueta.get("_lotes")
	var en_lotes: int = 0
	for id in (maqueta.get("TOCONES") as Array):
		en_lotes += (lotes.get(id, []) as Array).size()
	_ok("1 ningún tocón queda como decorado (lotes: %d)" % en_lotes, en_lotes == 0)
	var probado: int = 0
	for r in tocones:
		var t: Reactivo3D = r as Reactivo3D
		var c: Vector2i = t.celda
		var donde: String = "tocón (%d,%d)" % [c.x, c.y]
		_ok("1 %s: es inflamable y está sano" % donde, t.can_burn() and not t.is_lit)
		_ok("2 %s: su casilla está bloqueada y en el centro del modelo no se puede estar" % donde,
			Terreno3D.bloqueada(c) and Terreno3D.es_parcial(c, true) and Terreno3D.choca_huella(c, t.global_position))
		# desde una casilla vecina libre, una flecha de fuego
		var desde := Vector2i(-1, -1)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if Terreno3D.pisable(v, Terreno3D.altura_en(c), false, Terreno3D.altura_en(c), false) and not Terreno3D.es_parcial(v):
				desde = v
				break
		if desde.x < 0:
			_aviso("%s: sin casilla vecina libre desde la que disparar; no se prueba el fuego" % donde)
			continue
		probado += 1
		colocar_jugador(desde)
		await avanzar(3)
		var consumido: Array = [false]
		t.consumido.connect(func(_c: Vector2i) -> void: consumido[0] = true)
		var a: Vector3 = t.global_position - jugador.position
		_ok("3 %s: sale la flecha de fuego" % donde, lanzar("fuego", ["flecha"], a))
		var prendio: bool = false
		var t0: float = reloj.t
		while reloj.t - t0 < 3.0 and not prendio:
			await process_frame
			prendio = consumido[0] or (is_instance_valid(t) and t.is_lit)
		_ok("3 %s: el impacto de fuego lo PRENDE (%.2f s)" % [donde, reloj.t - t0], prendio)
		t0 = reloj.t
		while reloj.t - t0 < 12.0 and not consumido[0]:
			await process_frame
		_ok("4 %s: arde y se consume (%.1f s)" % [donde, reloj.t - t0], consumido[0])
		await avanzar(5)
		_ok("4 %s: consumido, su casilla queda libre" % donde, not Terreno3D.bloqueada(c))
	_ok("3 se ha probado el fuego en algún tocón (%d de %d)" % [probado, tocones.size()], probado > 0)
