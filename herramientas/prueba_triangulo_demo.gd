extends "res://herramientas/escenario_base.gd"
## TRIÁNGULO DE LA DEMO (21/11/2026; docs/DEBILIDADES_ELEMENTOS_2026-11-21.md §5.1). Reacciones contra enemigos con solo fuego, agua y tierra, sobre la escena real del Bosque y con goblins reales:
##   COSTRA   fuego sobre un ralentizado deja costra `Combate3D.COSTRA_S` s; tierra o golpe F encima = ROTO (×`Dano.X_ROTO`, aviso «roto»); el agua no la rompe; el magma no la crea; caduca sola.
##   SOFOCADO tierra sobre quien arde: lo apaga (aviso «apagado_agua» una vez) y lo aturde `SOFOCADO_ATURDE_S` s.
##   EMPAPADO tierra sobre un mojado: `lento` ×`LENTO_MOJADO_MULT`.
##   VAPOR    fuego sobre un mojado deja vapor en su casilla (el golpe real; la decisión sola no escribe nada).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_triangulo_demo.gd

const FILA: int = 33
var _creados: Array = []
var _avisos_vistos: Array = []
const DIR: Vector3 = Vector3(1, 0, 0)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


## Goblin quieto, sin defensa (para que el ×2 se lea limpio), sin debilidad y con vida de sobra.
func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.debil = ""
	g.resiste = ""
	g.defensa = 0.0
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	_avisos_vistos.clear()
	await avanzar(2)


func _n_aviso(nombre: String, nodo: Node) -> int:
	var n: int = 0
	for a in _avisos_vistos:
		if a[0] == nombre and a[1] == nodo:
			n += 1
	return n


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	await avanzar(20)
	colocar_jugador(Vector2i(4, FILA))
	if Mundo3D.actual != null:
		Mundo3D.actual.reaccion.connect(func(n: String, _p: Vector3, nodo: Node) -> void: _avisos_vistos.append([n, nodo]))
	await _costra()
	await _sofocado()
	await _empapado()
	await _vapor()
	await _limpiar()


func _costra() -> void:
	var tierra: Hechizo = _h("earth")
	var fuego: Hechizo = _h("fire")
	_ok("0 la tierra ralentiza (%.2f s)" % tierra.ralentiza, tierra.ralentiza > 0.0)

	var g: Combate3D = _goblin(Vector2i(10, FILA))
	_ok("1 fuego sin ralentizar: no hay costra", float(g.decidir_golpe(fuego)["costra"]) <= 0.0)
	g.golpe(tierra, DIR)
	_ok("1 la tierra lo deja lento (%.2f)" % g.lento, g.lento > 0.0)
	g.golpe(fuego, DIR)
	_ok("1 fuego sobre ralentizado: costra %.2f s (= COSTRA_S)" % g.costra, is_equal_approx(g.costra, Combate3D.COSTRA_S))
	_ok("1 y además arde", g.quemando > 0.0)

	# Roto: el mismo golpe de tierra con y sin costra (DEF 0: el cociente es X_ROTO limpio).
	g.quemando = 0.0
	var con: Dictionary = g.decidir_golpe(tierra)
	var c_guardada: float = g.costra
	g.costra = 0.0
	var sin: Dictionary = g.decidir_golpe(tierra)
	g.costra = c_guardada
	_ok("2 tierra sobre costra = roto", bool(con["roto"]) and not bool(sin["roto"]))
	_ok("2 daño ×%.1f (%.1f frente a %.1f)" % [Dano.X_ROTO, float(con["dano"]), float(sin["dano"])], float(sin["dano"]) > 0.0 and is_equal_approx(float(con["dano"]) / float(sin["dano"]), Dano.X_ROTO))
	_ok("2 el aviso lleva «roto»", (con["avisos"] as Array).has(Mundo3D.R_ROTO))
	_ok("2 el agua no rompe la costra", not bool(g.decidir_golpe(_h("water"))["roto"]))
	_ok("2 el fuego tampoco", not bool(g.decidir_golpe(fuego)["roto"]))
	g.golpe(tierra, DIR)
	_ok("2 tras romperla, la costra se acaba (%.2f)" % g.costra, g.costra <= 0.0)
	_ok("2 aviso «roto» una vez", _n_aviso(Mundo3D.R_ROTO, g) == 1)

	# Golpe F sobre la costra.
	var gf: Combate3D = _goblin(Vector2i(10, FILA - 3))
	gf.costra = Combate3D.COSTRA_S
	var rf: Dictionary = gf.recibir_golpe_cuerpo(DIR, 5.0, 0.0)
	_ok("3 golpe F sobre costra = roto", bool(rf["roto"]) and gf.costra <= 0.0)

	# El magma no se cuece a sí mismo.
	var gm: Combate3D = _goblin(Vector2i(10, FILA + 3))
	gm.lento = 2.0
	_ok("4 magma sobre ralentizado: sin costra", float(gm.decidir_golpe(_h("magma"))["costra"]) <= 0.0)

	# Caduca sola.
	var gc: Combate3D = _goblin(Vector2i(14, FILA))
	gc.costra = Combate3D.COSTRA_S
	await avanzar_s(Combate3D.COSTRA_S + 0.3)
	_ok("5 la costra caduca sola (%.2f)" % gc.costra, gc.costra <= 0.0)
	await _limpiar()


func _sofocado() -> void:
	var g: Combate3D = _goblin(Vector2i(10, FILA))
	g.quemando = 3.0
	var d: Dictionary = g.decidir_golpe(_h("earth"))
	_ok("6 la decisión: sofocado y aturde", bool(d["sofocado"]) and bool(d["aturde"]))
	g.golpe(_h("earth"), DIR)
	_ok("6 tierra sobre quien arde: apagado (%.2f)" % g.quemando, g.quemando <= 0.0)
	_ok("6 y aturdido %.2f s (≥ SOFOCADO_ATURDE_S)" % g.stun_timer, g.stun_timer >= Combate3D.SOFOCADO_ATURDE_S - 0.001)
	_ok("6 aviso «apagado_agua» una vez (premia tinta)", _n_aviso(Mundo3D.R_APAGADO_AGUA, g) == 1)
	var g2: Combate3D = _goblin(Vector2i(10, FILA - 3))
	_ok("6 sin fuego no hay sofocado", not bool(g2.decidir_golpe(_h("earth"))["sofocado"]))
	await _limpiar()


func _empapado() -> void:
	var tierra: Hechizo = _h("earth")
	var g: Combate3D = _goblin(Vector2i(10, FILA))
	var seco: float = float(g.decidir_golpe(tierra)["lento"])
	g.mojado = 3.0
	var d: Dictionary = g.decidir_golpe(tierra)
	_ok("7 tierra sobre mojado: lento ×%.1f (%.2f frente a %.2f)" % [Combate3D.LENTO_MOJADO_MULT, float(d["lento"]), seco],
		is_equal_approx(float(d["lento"]), seco * Combate3D.LENTO_MOJADO_MULT) and bool(d["lento_mojado"]))
	await _limpiar()


func _vapor() -> void:
	var est: EstadosSuelo3D = Terreno3D.estados
	var c: Vector2i = Vector2i(10, FILA)
	var g: Combate3D = _goblin(c)
	var celda: Vector2i = Terreno3D.celda_de(g.position)
	est.poner(celda, EstadosSuelo3D.VAPOR, false)
	g.mojado = 3.0
	g.decidir_golpe(_h("fire"))
	_ok("8 decidir (previsión) no escribe vapor", not est.hay_vapor(celda))
	g.golpe(_h("fire"), DIR)
	_ok("8 fuego sobre mojado: vapor en su casilla", est.hay_vapor(celda))
	est.poner(celda, EstadosSuelo3D.VAPOR, false)
	await _limpiar()
