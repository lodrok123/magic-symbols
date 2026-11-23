extends "res://herramientas/escenario_base.gd"
## G2 de docs/PLAN_COMBATE_2026-11-22.md (22/11): COORDINAR LOS ENCUENTROS. En la ArenaCombate, dos guerreros y un arquero van a por la jugadora a la vez.
## Comprueba, durante 14 s de pelea:
##   · nunca hay más de `CoordinadorEncuentro.MAX_ATACANTES` (2) preparando o dando un ataque a la vez;
##   · alguno se quedó sin ficha y, mientras esperaba, se RECOLOCÓ (se movió) en vez de quedarse quieto;
##   · las fichas rotan: los tres llegan a atacar.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_coordinar.gd

const RUTA_ARENA: String = "res://escenas/PruebaArenaCombate.tscn"


func _receta(id: String, c: Vector2i) -> Dictionary:
	return {"clase": "combate", "id": id, "casa": Terreno3D.centro_de(c, Terreno3D.y_pies(c)), "nombre_nodo": "Coord_%d_%d" % [c.x, c.y], "nombre": id, "debil": "", "resiste": "",
		"fijo": false, "quieto": false, "premia_tinta": true, "suelta_recogibles": false, "puestos_disparo": [], "puesto_cubierto": Vector3.ZERO, "escudo": false, "coraza": ""}


func _atacando(c: Combate3D) -> bool:
	return is_instance_valid(c) and not c.muerto and (c._carga > 0.0 or c._golpe_pendiente)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_ARENA, true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	# Fuera de en medio los goblins y el limo de la arena (la Santa Compaña y el mouro se quedan: no entran en el reparto y están lejos)
	for id in ["escudo_a", "escudo_b", "coraza_arena", "limo_brasa_arena"]:
		var n: Node = z.nodo(id) if z != null else null
		if n is Combate3D:
			(n as Combate3D).retirar()
	await avanzar(5)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1.0e9
	var centro := Vector2i(11, 10)
	colocar_jugador(centro)
	CoordinadorEncuentro.reiniciar()
	var g1: Combate3D = Combate3D.recrear(_receta("goblin_warrior_chibi", centro + Vector2i(-1, 0)), maqueta as Node3D, j, lanzador)
	var g2: Combate3D = Combate3D.recrear(_receta("goblin_warrior_chibi", centro + Vector2i(1, 0)), maqueta as Node3D, j, lanzador)
	var ar: Combate3D = Combate3D.recrear(_receta("goblin_archer_chibi", centro + Vector2i(0, 3)), maqueta as Node3D, j, lanzador)
	_ok("0 hay dos guerreros y un arquero", g1 != null and g2 != null and ar != null and ar.arquero and not g1.arquero)
	if g1 == null or g2 == null or ar == null:
		return
	await avanzar(3)
	var todos: Array = [g1, g2, ar]
	for c in todos:
		(c as Combate3D).health = 1.0e6
		(c as Combate3D).vida_max = 1.0e6
		(c as Combate3D).objetivo = j
		(c as Combate3D).estado = "persigue"
	var pico: int = 0
	var atacaron: Dictionary = {}
	var movido_esperando: Dictionary = {}
	var prev: Dictionary = {}
	for c in todos:
		prev[c] = (c as Node3D).position
	var t: float = 0.0
	while t < 14.0:
		colocar_jugador(centro)                              # quieta en medio (que no la empujen fuera)
		j._t_inv = 1.0e9                                     # y que no la tumben los golpes
		t += await avanzar_s(1.0 / 30.0)
		var n: int = 0
		for c in todos:
			if _atacando(c):
				n += 1
				atacaron[c] = true
			elif not CoordinadorEncuentro.tiene(c) and (c as Combate3D).recolocaciones > 0:
				var d: float = (c as Node3D).position.distance_to(prev[c])
				movido_esperando[c] = float(movido_esperando.get(c, 0.0)) + d
			prev[c] = (c as Node3D).position
		pico = maxi(pico, n)
	_ok("G2 nunca hay más de %d atacando a la vez" % CoordinadorEncuentro.MAX_ATACANTES, pico <= CoordinadorEncuentro.MAX_ATACANTES, "pico %d · fichas negadas %d" % [pico, CoordinadorEncuentro.negadas])
	var recolocados: int = 0
	for c in movido_esperando:
		if float(movido_esperando[c]) > 0.3:          # (22/11, C25: con el golpe seco los ataques duran menos, las fichas rotan antes y se espera menos rato)
			recolocados += 1
	_ok("G2 alguno se quedó sin ficha y se recolocó (se movió) mientras esperaba", CoordinadorEncuentro.negadas > 0 and recolocados >= 1,
		"recolocados %d · recorrido %s" % [recolocados, str(movido_esperando.values().map(func(x): return snappedf(x, 0.1)))])
	_ok("G2 las fichas rotan: los tres llegan a atacar", atacaron.size() == 3, "%d de 3" % atacaron.size())
