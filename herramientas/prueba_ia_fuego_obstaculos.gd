extends "res://herramientas/escenario_base.gd"
## IA QUE LEE EL MUNDO (21/11/2026; Combate3D: MIEDO_FUEGO, RODEA_MUROS, atasco). Sobre la escena real del Bosque con goblins reales:
##   1 quién teme al fuego (no el elemental, ni el arquero de puesto, ni quien es inmune al calor) y el interruptor MIEDO_FUEGO
##   2 una zona viva de fuego cerca → huye (se aleja, «¡Fuego!» en el diario) y no pisa sus casillas; empujado sí entra
##   3 persiguiendo con un muro de fuego en medio → llega sin pisar el fuego (lo rodea con la ruta)
##   4 el suelo quemado es FUENTE: no asusta, pero no lo pisa (y con RODEA_SUELO_QUEMADO = false, sí)
##   5 las barreras de la jugadora (SolidezV2): no las pisa con RODEA_MUROS; con false, como antes
##   6 atasco: apenas avanzar ATASCO_S s obliga a seguir la ruta ATASCO_RUTA_S s
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ia_fuego_obstaculos.gd

const FILA: int = 33
var _creados: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i, quieto: bool = false) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = quieto
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0)
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


## Zona viva de fuego sin pulso (no hace daño: solo es fuego para la IA) en `celdas`.
func _zona_fuego(celdas: Array, vida: float = 30.0) -> Node:
	var z := Lanzador3D.ZonaV2.new()
	z.lanz = lanzador
	z.elemento = "fuego"
	z.vida = vida
	for c in celdas:
		z.celdas[c] = true
	lanzador.add_child(z)
	lanzador._zonas_v2.append(z)
	_creados.append(z)
	Combate3D.olvidar_fuego()
	return z


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	lanzador._zonas_v2 = lanzador._zonas_v2.filter(func(z: Variant) -> bool: return is_instance_valid(z) and not (z as Node).is_queued_for_deletion())
	Combate3D.olvidar_fuego()
	await avanzar(2)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	await avanzar(20)
	colocar_jugador(Vector2i(2, FILA - 12))           # lejos: que nadie la persiga salvo en la parte 3
	await _quien_teme()
	await _huye()
	await _rodea_persiguiendo()
	await _suelo_quemado()
	await _barreras()
	await _atasco()
	await _limpiar()


func _quien_teme() -> void:
	var g: Combate3D = _goblin(Vector2i(10, FILA), true)
	_ok("1 un goblin teme al fuego", g.teme_fuego())
	g.fijo = true
	_ok("1 el arquero de puesto no", not g.teme_fuego())
	g.fijo = false
	g.inmune_estados = ["calor"]
	_ok("1 quien es inmune al calor no (gólem)", not g.teme_fuego())
	g.inmune_estados = []
	g.elemental = true
	_ok("1 el elemental no", not g.teme_fuego())
	g.elemental = false
	Combate3D.MIEDO_FUEGO = false
	_ok("1 con MIEDO_FUEGO = false, nadie", not g.teme_fuego())
	Combate3D.MIEDO_FUEGO = true
	await _limpiar()


func _huye() -> void:
	var cg: Vector2i = Vector2i(10, FILA)
	var g: Combate3D = _goblin(cg)
	g.position.x += 0.8                                # pegado al borde del fuego (a 1,5 u de su centro, dentro de RADIO_MIEDO_FUEGO)
	var cf: Vector2i = Vector2i(11, FILA)
	_zona_fuego([cf])
	var g_lejos: Combate3D = _goblin(Vector2i(9, FILA), true)
	_ok("2 a dos casillas no hay miedo (%.1f u > RADIO_MIEDO_FUEGO)" % (Terreno3D.casilla * 2.0), g_lejos.direccion_huida() == Vector3.ZERO)
	var centro: Vector3 = Terreno3D.centro_de(cf)
	var d0: float = Vector2(g.position.x - centro.x, g.position.z - centro.z).length()
	var dir: Vector3 = g.direccion_huida()
	_ok("2 hay dirección de huida y se aleja del fuego (%s)" % str(dir), dir != Vector3.ZERO and dir.x < 0.0)
	var pisadas: Dictionary = {}
	for _i in range(30):
		await avanzar(1)
		pisadas[Terreno3D.celda_de(g.position)] = true
	var d1: float = Vector2(g.position.x - centro.x, g.position.z - centro.z).length()
	_ok("2 en 1 s se ha alejado (%.2f → %.2f u)" % [d0, d1], d1 > d0 + 0.5)
	_ok("2 no ha pisado el fuego", not pisadas.has(cf))
	_ok("2 con sus piernas no entra en la casilla con fuego", not g._puede_estar(centro))
	_ok("2 empujado, sí", g._puede_estar_desde(_pos(Vector2i(10, FILA)), centro, true))
	await _limpiar()


## Esquina (x, y) de un claro de 5 × 5 casillas transitables y a la misma altura, o (-1, -1).
func _claro() -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(2, lado - 7):
		for x in range(2, lado - 7):
			var nivel: int = Terreno3D.altura_en(Vector2i(x, y))
			var bien: bool = true
			for dy in range(5):
				for dx in range(5):
					var c := Vector2i(x + dx, y + dy)
					if not Caminos3D.transitable(c) or Terreno3D.es_parcial(c) or Terreno3D.altura_en(c) != nivel:
						bien = false
						break
				if not bien:
					break
			if bien:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _rodea_persiguiendo() -> void:
	# Pasillo: el fuego tapa el único paso → espera (no anda hacia el fuego ni huye en bucle).
	var cjp: Vector2i = Vector2i(14, FILA)
	colocar_jugador(cjp)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	var gp: Combate3D = _goblin(Vector2i(10, FILA))
	var fp: Array = [Vector2i(12, FILA - 1), Vector2i(12, FILA), Vector2i(12, FILA + 1)]
	_zona_fuego(fp)
	var obstp: Dictionary = {}
	for c in fp:
		obstp[c] = true
	print("DATO  3 en la fila %d, ruta con el fuego en medio: %d casillas" % [FILA, Caminos3D.camino(Vector2i(10, FILA), cjp, obstp).size()])
	gp.objetivo = j
	gp.estado = "persigue"
	gp.ultima_pos = j.position
	var huidas: int = 0
	var huia: bool = false
	for _i in range(30 * 4):
		await avanzar(1)
		if gp._huida > 0.0 and not huia:
			huidas += 1
		huia = gp._huida > 0.0
	_ok("3 sin paso: espera junto al fuego sin huir en bucle (%d huidas, en %s)" % [huidas, str(Terreno3D.celda_de(gp.position))], huidas == 0 and Terreno3D.celda_de(gp.position).x < 12)
	await _limpiar()

	# Claro abierto: un muro de fuego de tres casillas entre el goblin y la jugadora → lo rodea.
	var o: Vector2i = _claro()
	_ok("3 (mapa) hay un claro de 5 × 5 en el Bosque", o.x >= 0)
	if o.x < 0:
		return
	var cj: Vector2i = o + Vector2i(4, 2)
	colocar_jugador(cj)
	j.vida = 100000.0
	var g: Combate3D = _goblin(o + Vector2i(0, 2))
	var fuego: Array = [o + Vector2i(2, 1), o + Vector2i(2, 2), o + Vector2i(2, 3)]
	_zona_fuego(fuego)
	g.objetivo = j                                     # ya la ha visto (a 9,2 u, más allá de RADIO_DETECCION, pero dentro de RADIO_SOLTAR: la sigue)
	g.estado = "persigue"
	g.ultima_pos = j.position
	var pisadas: Dictionary = {}
	var llego: bool = false
	var huyo: bool = false
	print("DATO  3 claro en %s: goblin %s, fuego %s, jugadora %s" % [str(o), str(Terreno3D.celda_de(g.position)), str(fuego), str(cj)])
	for _i in range(30 * 12):
		await avanzar(1)
		if _i % 15 == 0 and OS.has_environment("TRAZA_IA"):
			var ob: Dictionary = g._obstaculos_ruta(j.position)
			print("TRAZA %d pos %s celda %s huida %.2f ruta %s mov %d dist %.2f | obst %s | camino %s | jug %s" % [_i, str(g.position), str(Terreno3D.celda_de(g.position)), g._huida, str(g._ruta), g.moviendo, Vector2(g.position.x - j.position.x, g.position.z - j.position.z).length(),
				str(ob.keys()), str(Caminos3D.camino(Terreno3D.celda_de(g.position), Terreno3D.celda_de(j.position), ob)), str(Terreno3D.celda_de(j.position))])
		pisadas[Terreno3D.celda_de(g.position)] = true
		huyo = huyo or g._huida > 0.0
		if Vector2(g.position.x - j.position.x, g.position.z - j.position.z).length() <= Combate3D.RANGO_ATAQUE + 0.6:
			llego = true
			break
	var piso_fuego: bool = false
	for c in fuego:
		piso_fuego = piso_fuego or pisadas.has(c)
	_ok("3 persiguiendo, no pisa el muro de fuego", not piso_fuego, str(pisadas.keys()))
	_ok("3 y llega a la jugadora rodeándolo (en ≤ 12 s)", llego, "termina en %s" % str(Terreno3D.celda_de(g.position)))
	print("DATO  3 ¿huyó en algún momento al pasar cerca? %s" % str(huyo))
	colocar_jugador(Vector2i(2, FILA - 12))
	await _limpiar()


func _suelo_quemado() -> void:
	var est: EstadosSuelo3D = Terreno3D.estados
	var cq: Vector2i = Vector2i(11, FILA)
	var g: Combate3D = _goblin(Vector2i(10, FILA), true)
	est.poner(cq, EstadosSuelo3D.QUEMADA, true)
	Combate3D.olvidar_fuego()
	_ok("4 el suelo quemado es fuente", int(Combate3D.celdas_de_fuego(g.get_tree(), lanzador).get(cq, 0)) == Combate3D.FUEGO_FUENTE)
	_ok("4 no asusta (sin dirección de huida)", g.direccion_huida() == Vector3.ZERO)
	_ok("4 pero no lo pisa", not g._puede_estar(Terreno3D.centro_de(cq)))
	Combate3D.RODEA_SUELO_QUEMADO = false
	Combate3D.olvidar_fuego()
	_ok("4 con RODEA_SUELO_QUEMADO = false, sí lo pisa", g._puede_estar(Terreno3D.centro_de(cq)))
	Combate3D.RODEA_SUELO_QUEMADO = true
	est.poner(cq, EstadosSuelo3D.QUEMADA, false)
	Combate3D.olvidar_fuego()
	await _limpiar()


func _barreras() -> void:
	var cm: Vector2i = Vector2i(11, FILA)
	var g: Combate3D = _goblin(Vector2i(10, FILA), true)
	var s := Lanzador3D.SolidezV2.new()
	s.celdas = {cm: true}
	s.niveles = 1
	s.vida = 30.0
	lanzador.add_child(s)
	lanzador._solideces_v2.append(s)
	_creados.append(s)
	_ok("5 la barrera cuenta como muro táctico", lanzador.muros_tacticos().has(cm))
	_ok("5 con RODEA_MUROS no la pisa", not g._puede_estar(Terreno3D.centro_de(cm)))
	Combate3D.RODEA_MUROS = false
	_ok("5 con RODEA_MUROS = false la pisa (como antes)", g._puede_estar(Terreno3D.centro_de(cm)))
	Combate3D.RODEA_MUROS = true
	lanzador._solideces_v2.erase(s)
	await _limpiar()


func _atasco() -> void:
	var g: Combate3D = _goblin(Vector2i(10, FILA), true)
	var paso := Vector3(0.1, 0.0, 0.0)
	g._medir_atasco(g.position, paso, Combate3D.ATASCO_S * 0.5)
	_ok("6 medio atasco aún no fuerza la ruta", g._forzar_ruta <= 0.0)
	g._medir_atasco(g.position, paso, Combate3D.ATASCO_S * 0.6)
	_ok("6 atascado ATASCO_S s: sigue la ruta %.1f s" % g._forzar_ruta, is_equal_approx(g._forzar_ruta, Combate3D.ATASCO_RUTA_S))
	var g2: Combate3D = _goblin(Vector2i(10, FILA + 3), true)
	var antes: Vector3 = g2.position
	g2.position += paso
	g2._medir_atasco(antes, paso, 1.0)
	_ok("6 avanzando lo pedido no hay atasco", g2._forzar_ruta <= 0.0 and g2._t_atasco <= 0.0)
	await _limpiar()
