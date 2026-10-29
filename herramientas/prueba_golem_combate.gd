extends "res://herramientas/escenario_base.gd"
## E3 · GÓLEM DE PIEDRA (28/10; enemigos/golem_3d.gd). Sobre la sala real (`PruebaSalaGolem.tscn`: franja de agua que se hiela en (3..8, 4), charca honda en (9..11, 3..5)), con hechizos
## lanzados por el camino de verdad (`Lanzador3D.lanzar_ahora`):
##   · de pie y armado, NADA le hace daño (flecha de cada elemento, golpe F, daño directo) ni lo mueve, ni le pone estados; la previsión dice «Piedra» (mult 0);
##   · el viento sin hielo no lo mueve («Ni se inmuta»); sobre hielo RESBALA a 4,5 u/s, casilla a casilla: para en el último hielo (suelo no helado, pared, otro cuerpo), cae de espaldas
##     y queda TUMBADO 3 s con el núcleo a la vista (×1,5); si el hielo acaba en agua honda se hunde (hundido, +20 de tinta, sin botín); si acaba en lava, muere en ella;
##   · el golpe: aviso rectangular (forma, tiempo y zona = regla de daño), 30 de daño y empuje a la jugadora dentro y 0 fuera, avance de 1,15 u del nodo sin atravesar paredes, y rodar en la
##     ventana final da el tiempo bruja;
##   · tras el golpe queda de rodillas: núcleo expuesto solo entre T_EXPUESTO_ABAJO y T_EXPUESTO_ARRIBA, ×1,5 dentro (también el golpe F, sin moverlo) y 0 fuera; el núcleo brilla;
##   · la previsión del indicador: «Piedra», «Núcleo ×1,5», «Resbala», «Se hunde», «¡Lava!», «Ni se inmuta».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_golem_combate.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"
var _comprobaciones: int = 0
var _creados: Array = []
var _z: Puzle3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _golem(c: Vector2i, quieto: bool = true) -> Golem3D:
	var g: Golem3D = Golem3D.invocar_golem(maqueta, _pos(c), jugador as Jugador3D, lanzador)
	g.quieto = quieto
	_creados.append(g)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
				if lista is Array:
					(lista as Array).erase((n as Combate3D).pj)
				if is_instance_valid((n as Combate3D).pj):
					(n as Combate3D).pj.queue_free()
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()
	Terreno3D.estados.limpiar()                                # el hielo (y la escarcha que deja un hechizo de hielo sobre el suelo) de la prueba anterior
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()
	TiempoBruja.terminar(lanzador)
	Engine.time_scale = 1.0


func _jugadora(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO


func _preparar(c: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	_jugadora(c)
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


func _lanzar(datos: Dictionary, dir: Vector3) -> bool:
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(datos, jugador.position, dir)


## La entrada de la previsión para `g` con lo preparado: {reaccion, mult, extra} o {}.
func _prevista(datos: Dictionary, g: Golem3D, dir: Vector3) -> Dictionary:
	PrevisionHechizo.olvidar()
	for e in PrevisionHechizo.prever(lanzador, datos, jugador.position, dir):
		if e["nodo"] == g:
			return e
	return {}


## Prepara `elemento + flecha` desde `desde`, mira la previsión (devuelve su reacción principal y el multiplicador) y la lanza; espera `espera` s.
func _flecha(g: Golem3D, elemento: String, desde: Vector2i, dir: Vector3, espera: float = 1.5, glifos: Array = ["flecha"]) -> Dictionary:
	var d: Dictionary = _preparar(desde, elemento, glifos)
	var e: Dictionary = _prevista(d, g, dir)
	_lanzar(d, dir)
	await avanzar_s(espera)
	return e


func _celdas_hielo(celdas: Array, si: bool = true) -> void:
	for c in celdas:
		Terreno3D.poner_helada(c as Vector2i, si)


func _escarcha(celdas: Array) -> void:
	for c in celdas:
		Terreno3D.estados.poner(c as Vector2i, EstadosSuelo3D.HELADA, true)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(10)
	await _caso_pieza()
	await _caso_piedra()
	await _caso_golpe_f()
	await _caso_viento_sin_hielo()
	await _caso_resbala_y_tumba()
	await _caso_resbala_al_agua()
	await _caso_resbala_otros_topes()
	await _caso_lava()
	await _caso_ataque()
	await _caso_pared()
	await _caso_nucleo()
	await _caso_esquiva()
	await _caso_muerte()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso_pieza() -> void:
	var a: Golem3D = _z.nodo("golem_a") as Golem3D if _z != null else null
	_ok("0 la pieza `golem` monta el gólem en su casilla", a != null and Terreno3D.celda_de(a.casa) == Vector2i(13, 6))
	if a == null:
		return
	_ok("0 es un Combate3D del grupo de enemigos (vigía, previsión, tinta)", a is Combate3D and a.is_in_group("combate3d"))
	_ok("0 70 de vida (29/10: antes 120), defensa 10, 40 de oro, no empujable por el golpe F, sin colmillo", is_equal_approx(a.health, 70.0) and a.oro == 40 and not a.empujable_golpe and not a.botin_goblin)
	_ok("0 nace armado y el núcleo (pieza de Equipo3D) está montado", a.g_estado == "armado" and a._nucleo_mats.size() >= 1, str(a._nucleo_mats.size()))
	# Se queda para las pruebas de vigía de la escena; el resto crea sus propios gólems.
	a.quieto = true
	a.position = _pos(Vector2i(15, 1))
	a.casa = a.position


const FRANJA: Array = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]
const ESC7: Array = [Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7)]


func _mov(g: Node3D, p0: Vector3) -> float:
	return Vector2(g.position.x - p0.x, g.position.z - p0.z).length()


## 1 · De pie y armado, nada le hace daño ni lo mueve ni le pone estados; la previsión dice «Piedra».
func _caso_piedra() -> void:
	var g: Golem3D = _golem(Vector2i(6, 6))
	await avanzar(3)
	var p0: Vector3 = g.position
	var este := Vector3(-1, 0, 0)
	for el in ["fuego", "agua", "hielo", "rayo", "tierra"]:
		var e: Dictionary = await _flecha(g, el, Vector2i(8, 6), este, 1.6)
		_ok("1 %s: la previsión dice «Piedra» con mult 0" % el, String(e.get("reaccion", "")) == "piedra" and is_zero_approx(float(e.get("mult", -1.0))), str(e.get("reaccion", "")))
		_ok("1 %s: ni un punto de daño ni estados ni empuje" % el, is_equal_approx(g.health, Golem3D.VIDA) and g.quemando <= 0.0 and g.mojado <= 0.0 and g.congelado <= 0.0 and g.stun_timer <= 0.0
			and _mov(g, p0) < 0.01 and g.g_estado == "armado", "vida %.1f · quemando %.1f · mojado %.1f · congelado %.1f · mueve %.3f" % [g.health, g.quemando, g.mojado, g.congelado, _mov(g, p0)])
	await avanzar_s(3.0)                                        # que se apague lo que haya dejado el fuego en el suelo
	_ok("1 y sigue sin arder tras el fuego del suelo", is_equal_approx(g.health, Golem3D.VIDA) and g.quemando <= 0.0)
	var dec: Dictionary = g.decidir_golpe(PrevisionHechizo._hechizo(lanzador, _preparar(Vector2i(10, 6), "fuego", ["flecha"])))
	_ok("1 `decidir_golpe` lo devuelve con mult 0 y sin estados", is_zero_approx(float(dec["mult"])) and is_zero_approx(float(dec["dano"])) and float(dec["quemando"]) <= 0.0 and not bool(dec["aturde"]) and not bool(dec["veneno"]))
	g.receive_damage(50.0)
	_ok("1 el daño directo (pulso de zona, estalagmita…) tampoco pasa", is_equal_approx(g.health, Golem3D.VIDA))
	g.prender_por_contacto()
	_ok("1 y lo que arde y lo toca no lo prende", g.quemando <= 0.0 and not g.puede_prender())
	_limpiar()
	await avanzar(3)


## 2 · El golpe F: de pie «Piedra» (0 de daño, no se mueve ni se le corta nada).
func _caso_golpe_f() -> void:
	var g: Golem3D = _golem(Vector2i(6, 6))
	await avanzar(3)
	var p0: Vector3 = g.position
	var r: Dictionary = g.recibir_golpe_cuerpo(Vector3(1, 0, 0), 5.0, 5000.0)
	_ok("2 golpe F de pie: 0 de daño y sin empuje", is_zero_approx(float(r["dano"])) and is_zero_approx(float(r["v0"])) and is_equal_approx(g.health, Golem3D.VIDA) and _mov(g, p0) < 0.01)
	await avanzar_s(1.0)
	_ok("2 y no se mueve después", _mov(g, p0) < 0.01 and g._empuje.length() < 0.01)
	_limpiar()
	await avanzar(3)


## 3 · El viento sin hielo no lo mueve.
func _caso_viento_sin_hielo() -> void:
	var g: Golem3D = _golem(Vector2i(6, 6))
	await avanzar(3)
	var p0: Vector3 = g.position
	var e: Dictionary = await _flecha(g, "viento", Vector2i(8, 6), Vector3(-1, 0, 0), 1.5)
	_ok("3 viento sin hielo: la previsión dice «Ni se inmuta»", String(e.get("reaccion", "")) == "inmune", str(e.get("reaccion", "")))
	_ok("3 viento sin hielo: no se mueve ni se inmuta (armado)", _mov(g, p0) < 0.01 and g.g_estado == "armado" and g.resbalones == 0 and is_equal_approx(g.health, Golem3D.VIDA))
	_ok("3 y la previsión usa el texto «%s»" % PrevisionReaccion3D._texto("inmune"), PrevisionReaccion3D._texto("inmune") == "Ni se inmuta")
	_limpiar()
	await avanzar(3)


## 4 · Viento sobre hielo: resbala hasta el final del hielo (suelo no helado), cae de espaldas, queda tumbado 3 s (×1,5) y se levanta.
func _caso_resbala_y_tumba() -> void:
	_celdas_hielo(FRANJA)
	await avanzar(3)
	_ok("4 la franja está helada", Terreno3D.helada(Vector2i(3, 4)) and Terreno3D.helada(Vector2i(8, 4)) and not Terreno3D.es_agua(Vector2i(5, 4)))
	var g: Golem3D = _golem(Vector2i(6, 4))
	await avanzar(3)
	_ok("4 está sobre hielo y de pie", g.puede_resbalar() and not g.vulnerable())
	var d: Dictionary = _preparar(Vector2i(8, 4), "viento", ["flecha"])
	var e: Dictionary = _prevista(d, g, Vector3(-1, 0, 0))
	var ex: Dictionary = e.get("extra", {})
	_ok("4 la previsión dice «Resbala» (sin hundirse) y enseña adónde llega", String(e.get("reaccion", "")) == "resbala" and not bool(ex.get("hundira", false)) and (ex.get("destino", Vector3.ZERO) as Vector3).x < g.position.x - 2.0,
		"%s · destino %s" % [e.get("reaccion", ""), ex.get("destino", "")])
	var destino_prev: Vector3 = ex.get("destino", Vector3.ZERO)
	_lanzar(d, Vector3(-1, 0, 0))
	var t0: float = reloj.t
	var x0: float = g.position.x
	var visto: bool = false
	var v_max: float = 0.0
	var x_prev: float = x0
	var t_prev: float = t0
	while reloj.t - t0 < 3.0 and g.g_estado != "tumbado":
		await process_frame
		if g.g_estado == "resbalando":
			visto = true
			var dt: float = reloj.t - t_prev
			if dt > 0.0:
				v_max = maxf(v_max, absf(g.position.x - x_prev) / dt)
		x_prev = g.position.x
		t_prev = reloj.t
	_ok("4 resbala (estado «resbalando») y se para", visto and g.g_estado == "tumbado", g.g_estado)
	_ok("4 a ~4,5 u/s (máx. medida %.2f)" % v_max, v_max > 3.5 and v_max < 5.5)
	_ok("4 se desliza en la dirección del viento y se queda en el ÚLTIMO hielo (celda %s)" % str(Terreno3D.celda_de(g.position)), Terreno3D.celda_de(g.position) == Vector2i(3, 4) and g.position.x < x0 - 2.0)
	_ok("4 la previsión acertó el destino (%.2f u de diferencia)" % g.position.distance_to(destino_prev), g.position.distance_to(destino_prev) < 0.35)
	_ok("4 queda a RADIO_TOPE del borde de la casilla, no dentro del suelo no helado", g.position.x > 3.0 * Terreno3D.casilla + 0.3)
	_ok("4 sin daño: resbalar no hiere", is_equal_approx(g.health, Golem3D.VIDA))
	# Tumbado: núcleo a la vista.
	var tum0: float = reloj.t
	await avanzar_s(0.5)
	_ok("4 tumbado: vulnerable y el núcleo brilla más que armado", g.vulnerable() and g.brillo_nucleo() > Golem3D.BRILLO_REPOSO * 3.0, "brillo %.2f" % g.brillo_nucleo())
	var e2: Dictionary = {}
	var d2: Dictionary = _preparar(Vector2i(5, 4), "tierra", ["flecha"])
	e2 = _prevista(d2, g, Vector3(-1, 0, 0))
	var h: Hechizo = PrevisionHechizo._hechizo(lanzador, d2)
	_ok("4 tumbado: la previsión dice «Núcleo ×1,5»", String(e2.get("reaccion", "")) == "nucleo" and is_equal_approx(float(e2.get("mult", 0.0)), 1.5)
		and PrevisionReaccion3D._texto("nucleo") + PrevisionReaccion3D._sufijo(1.5) == "Núcleo ×1,5", str(e2.get("reaccion", "")))
	var antes: float = g.health
	_lanzar(d2, Vector3(-1, 0, 0))
	await avanzar_s(1.4)
	_ok("4 tumbado: la flecha de tierra hace ×1,5 y resta la defensa 10 (29/10) (%.1f de %.1f)" % [antes - g.health, h.dano], absf((antes - g.health) - Dano.aplicar(h.dano, 1.0, 1.0, 1.5, Dano.DEF_GOLEM)) < 0.6 and g.health < antes)
	_ok("4 y no lo mueve ni le pone estados", g.quemando <= 0.0)
	var rotulos: int = _rotulos("¡Núcleo!")
	_ok("4 «¡Núcleo!» salió (una vez en la ventana)", rotulos >= 1, str(rotulos))
	# Se levanta a los T_TUMBADO s.
	while reloj.t - tum0 < Golem3D.T_TUMBADO - 0.2:
		await process_frame
	await avanzar_s(0.5)
	_ok("4 a los 3 s se levanta (clip `levantarse`) y ya no es vulnerable", g.g_estado == "levantando" and not g.vulnerable(), g.g_estado)
	var n: int = 0
	while g.g_estado == "levantando" and n < 400:
		await process_frame
		n += 1
	_ok("4 acaba de levantarse y vuelve a armado", g.g_estado == "armado" and not g.vulnerable(), g.g_estado)
	_limpiar()
	await avanzar(3)


func _rotulos(txt: String) -> int:
	var n: int = 0
	for l in maqueta.find_children("*", "Label3D", true, false):
		if (l as Label3D).text == txt:
			n += 1
	return n


## 5 · Resbala hasta el agua honda: se hunde (muere, tinta +20, sin botín).
func _caso_resbala_al_agua() -> void:
	_celdas_hielo(FRANJA)
	var g: Golem3D = _golem(Vector2i(5, 4))
	await avanzar(3)
	var d: Dictionary = _preparar(Vector2i(3, 4), "viento", ["flecha"])
	var e: Dictionary = _prevista(d, g, Vector3(1, 0, 0))
	var ex: Dictionary = e.get("extra", {})
	_ok("5 la previsión dice «Se hunde» (hunde + resbala)", String(e.get("reaccion", "")) == "hunde" and bool(ex.get("hundira", false)) and (ex.get("reacciones", []) as Array).has("resbala"), str(ex.get("reacciones", [])))
	var tinta = lanzador.tinta
	tinta.actual = 10.0
	var oro0: int = Estado.i().oro
	var hundidos: Array = []
	var reg: Dictionary = {"antes": tinta.actual, "salto": -1.0}
	g.hundido.connect(func(_x) -> void:
		hundidos.append(1)
		reg["salto"] = tinta.actual - float(reg["antes"]))
	_lanzar(d, Vector3(1, 0, 0))
	var n: int = 0
	while not g.muerto and n < 240:
		tinta.actual = 0.0                                       # la tinta se recupera deprisa fuera de combate: se aguanta a 0 para ver el premio entero
		reg["antes"] = tinta.actual
		await process_frame
		n += 1
	_ok("5 resbala hasta el agua honda y MUERE hundido", g.muerto and g.se_hundio and not g.murio_en_lava, "estado %s" % g.g_estado)
	await avanzar_s(2.5)
	_ok("5 emite `hundido` una vez", hundidos.size() == 1)
	_ok("5 da +20 de tinta (C2: hundido) al caer", float(reg["salto"]) > 19.0 and float(reg["salto"]) < 21.5, "+%.1f" % float(reg["salto"]))
	_ok("5 sin botín (se ahoga)", Estado.i().oro == oro0 and not _hay_oro())
	_limpiar()
	await avanzar(3)


func _hay_oro() -> bool:
	for n in maqueta.get_children():
		if n.name.begins_with("Oro"):
			return true
	return false


## 6 · Topes: pared, otro cuerpo y la escarcha que acaba en suelo normal.
func _caso_resbala_otros_topes() -> void:
	# Pared: escarcha en la fila 7 desde el oeste; viento al oeste lo lleva hasta la pared.
	_escarcha(ESC7)
	var g: Golem3D = _golem(Vector2i(5, 7))
	await avanzar(3)
	_jugadora(Vector2i(9, 7))
	g.push(Vector3(-1, 0, 0), 5000.0)
	var n: int = 0
	while g.g_estado == "resbalando" and n < 200:
		await process_frame
		n += 1
	_ok("6 pared: se para en (1,7) pegado a la pared y no la atraviesa", g.g_estado == "tumbado" and Terreno3D.celda_de(g.position) == Vector2i(1, 7) and g.position.x > Terreno3D.casilla * 1.0, "celda %s x %.2f" % [str(Terreno3D.celda_de(g.position)), g.position.x])
	_limpiar()
	await avanzar(3)
	# Otro cuerpo delante: se para antes de entrar en su casilla.
	_escarcha(ESC7)
	var g2: Golem3D = _golem(Vector2i(5, 7))
	var otro: Golem3D = _golem(Vector2i(2, 7))
	await avanzar(3)
	g2.push(Vector3(-1, 0, 0), 5000.0)
	n = 0
	while g2.g_estado == "resbalando" and n < 200:
		await process_frame
		n += 1
	_ok("6 otro enemigo: se para en la casilla de antes (3,7), sin entrar en la del otro", g2.g_estado == "tumbado" and Terreno3D.celda_de(g2.position) == Vector2i(3, 7), str(Terreno3D.celda_de(g2.position)))
	_ok("6 y el otro ni se entera", otro.g_estado == "armado" and Terreno3D.celda_de(otro.position) == Vector2i(2, 7))
	_limpiar()
	await avanzar(3)
	# El viento a favor de la franja de la fila 4 desde un gólem tumbado no lo vuelve a mover.
	_escarcha(ESC7)
	var g3: Golem3D = _golem(Vector2i(6, 7))
	await avanzar(3)
	g3.push(Vector3(-1, 0, 0), 5000.0)
	await avanzar_s(0.3)
	var p1: Vector3 = g3.position
	g3.push(Vector3(1, 0, 0), 5000.0)                           # resbalando: el segundo soplo no cambia nada
	await avanzar(2)
	_ok("6 un segundo soplo mientras resbala no lo desvía", g3.position.x <= p1.x + 0.05 and g3._res_dir.x < 0.0)
	_limpiar()
	_escarcha_quitar(ESC7)
	await avanzar(3)


func _escarcha_quitar(celdas: Array) -> void:
	for c in celdas:
		Terreno3D.estados.poner(c as Vector2i, EstadosSuelo3D.HELADA, false)


## 7 · Lava: si el hielo acaba en lava, cae dentro y muere.
func _caso_lava() -> void:
	var lava := Lava3D.new()
	lava.name = "LavaPrueba"
	lava.preparar([Vector2i(8, 2)])
	maqueta.add_child(lava)
	_creados.append(lava)
	_escarcha([Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)])
	await avanzar(3)
	var g: Golem3D = _golem(Vector2i(4, 2))
	await avanzar(3)
	_ok("7 la casilla (8,2) es lava", lava.es_lava(Vector2i(8, 2)) and not lava.es_lava(Vector2i(7, 2)))
	var d: Dictionary = _preparar(Vector2i(2, 2), "viento", ["flecha"])
	var e: Dictionary = _prevista(d, g, Vector3(1, 0, 0))
	var ex: Dictionary = e.get("extra", {})
	_ok("7 la previsión dice «¡Lava!»", String(e.get("reaccion", "")) == "lava" and bool(ex.get("lava", false)) and not bool(ex.get("hundira", false)), "%s · %s" % [e.get("reaccion", ""), ex.get("reacciones", "")])
	var tinta = lanzador.tinta
	tinta.actual = 10.0
	var oro0: int = Estado.i().oro
	_lanzar(d, Vector3(1, 0, 0))
	var n: int = 0
	var t_antes: float = tinta.actual
	while not g.muerto and n < 240:
		tinta.actual = 0.0
		t_antes = tinta.actual
		await process_frame
		n += 1
	var t_fin: float = tinta.actual
	_ok("7 resbala y cae en la lava: muere abrasado", g.muerto and g.murio_en_lava, "estado %s" % g.g_estado)
	await avanzar_s(2.5)
	_ok("7 sin botín y sin tinta (ninguna reacción premiada encaja)", Estado.i().oro == oro0 and t_fin - t_antes < 2.0 and not _hay_oro(), "tinta %.1f → %.1f" % [t_antes, t_fin])
	_limpiar()
	_escarcha_quitar([Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)])
	await avanzar(3)


## 8 · El golpe: aviso rectangular, 30 de daño y empuje dentro, 0 fuera, avance; tras él, expuesto.
func _caso_ataque() -> void:
	_jugadora(Vector2i(8, 6))
	var j: Jugador3D = jugador as Jugador3D
	var g: Golem3D = _golem(Vector2i(10, 6), false)
	var vida0: float = j.vida
	var a: AvisoAtaque3D = null
	var n: int = 0
	while a == null and n < 600:
		await process_frame
		n += 1
		for x in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (x as AvisoAtaque3D).dueno == g and not (x as AvisoAtaque3D).cancelado:
				a = x
	_ok("8 al acercarse (persigue a 0,9 u/s) saca el aviso", a != null and g.ataques == 1, "ataques %d · estado %s · pos %s" % [g.ataques, g.g_estado, str(g.position)])
	if a == null:
		_limpiar()
		return
	var d0: float = Vector2(j.position.x - g._pos_ataque0.x, j.position.z - g._pos_ataque0.z).length()
	_ok("8 empezó a RANGO (%.2f u ≤ 1,9)" % d0, d0 <= Golem3D.RANGO + 0.05, "%.2f" % d0)
	_ok("8 el aviso es un rectángulo con el tiempo del impacto del clip (%.2f s)" % a.t_impacto, a.forma == "rect" and absf(a.t_impacto - AnimacionesGolem.INSTANTE_GOLPE) < 0.01)
	_ok("8 mide 2,3 de largo y 1,6 de ancho, desde 0,5 u delante de donde empieza", is_equal_approx(a.largo, Golem3D.ZONA_LARGO) and is_equal_approx(a.ancho, Golem3D.ZONA_ANCHO * 0.5) and is_zero_approx(a.atras)
		and absf((a.centro - g._pos_ataque0).dot(g._dir_ataque) - Golem3D.ZONA_DESDE) < 0.01)
	var malos: int = 0
	var paso: float = 0.15
	var x: float = -4.0
	while x <= 4.0:
		var z: float = -4.0
		while z <= 4.0:
			var p: Vector3 = g._pos_ataque0 + Vector3(x, 0.0, z)
			var rel: Vector3 = p - g._pos_ataque0
			var delante: float = rel.dot(g._dir_ataque)
			var lado: float = absf(rel.dot(Vector3(-g._dir_ataque.z, 0.0, g._dir_ataque.x)))
			var borde: float = minf(minf(absf(delante - Golem3D.ZONA_DESDE), absf(delante - Golem3D.ZONA_DESDE - Golem3D.ZONA_LARGO)), absf(lado - Golem3D.ZONA_ANCHO * 0.5))
			if borde > 0.06 and g.en_zona_golpe(p) != a.contiene(p):
				malos += 1
			z += paso
		x += paso
	_ok("8 la zona del aviso = la regla de daño punto a punto (%d discrepancias)" % malos, malos == 0)
	var p_ini: Vector3 = g._pos_ataque0
	var ta: float = a.t
	while j.vida >= vida0 and a.t < 3.0 and is_instance_valid(a) and g.ataques == 1 and g.g_estado == "atacando":
		await process_frame
	var t_golpe: float = a.t if is_instance_valid(a) else AnimacionesGolem.INSTANTE_GOLPE
	await avanzar(1)
	_ok("8 daño 30 a la jugadora dentro de la zona (%.0f)" % (vida0 - j.vida), is_equal_approx(vida0 - j.vida, Golem3D.DANO), "%.1f" % (vida0 - j.vida))
	_ok("8 el golpe cae al acabar el aviso (%.2f s)" % t_golpe, absf(t_golpe - AnimacionesGolem.INSTANTE_GOLPE) <= 0.12)
	_ok("8 y la empuja fuerte (≈ 8 u/s)", j._empuje.length() >= 6.0, "%.1f" % j._empuje.length())
	_ok("8 golpes_dados = 1 y queda EXPUESTO (de rodillas)", g.golpes_dados == 1 and g.g_estado == "expuesto" and g.exposiciones == 1, g.g_estado)
	var avance: float = Vector2(g.position.x - p_ini.x, g.position.z - p_ini.z).length()
	_ok("8 el nodo avanzó %.2f u (AVANCE_GOLPE 1,15) hacia ella" % avance, absf(avance - AnimacionesGolem.AVANCE_GOLPE) < 0.08)
	_ok("8 el modelo y el nodo coinciden tras el golpe (sin saltos)", g.pj.position.distance_to(g.position) < 0.02, "%.3f" % g.pj.position.distance_to(g.position))
	_limpiar()
	await avanzar(3)
	# Fuera de la zona: 0.
	_jugadora(Vector2i(7, 6))
	j = jugador as Jugador3D
	var g2: Golem3D = _golem(Vector2i(9, 6), false)
	var vida1: float = j.vida
	a = null
	n = 0
	while a == null and n < 600:
		await process_frame
		n += 1
		for y in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (y as AvisoAtaque3D).dueno == g2 and not (y as AvisoAtaque3D).cancelado:
				a = y
	if a != null:
		j.position += Vector3(0, 0, -1.6)                       # se aparta 1,6 u de lado (el rectángulo mide 1,6 de ancho: 0,8 a cada lado)
		var fuera_ok: bool = not g2.en_zona_golpe(j.position)
		while g2.g_estado == "atacando":
			await process_frame
		await avanzar(1)
		_ok("8 fuera de la zona: 0 de daño", fuera_ok and is_equal_approx(j.vida, vida1) and g2.golpes_dados == 0, "vida %.0f → %.0f" % [vida1, j.vida])
		_ok("8 y aun así queda expuesto", g2.g_estado == "expuesto")
	else:
		_ok("8 fuera de la zona: hubo aviso", false)
	_limpiar()
	await avanzar(3)


## 9 · El avance no atraviesa la pared.
func _caso_pared() -> void:
	_jugadora(Vector2i(14, 6))
	var g: Golem3D = _golem(Vector2i(15, 6), true)
	await avanzar(3)
	g.position.x = 16.0 * Terreno3D.casilla - 0.35                 # a 0,35 u de la pared de la derecha
	g.quieto = false
	var j: Jugador3D = jugador as Jugador3D
	j.position = Vector3(g.position.x + 1.5, g.position.y, g.position.z)      # hacia la pared (solo para fijar la dirección del golpe)
	g._empezar_golpe()
	j.position = Vector3(g.position.x - 1.2, g.position.y, g.position.z)
	var n: int = 0
	while g.g_estado == "atacando" and n < 200:
		await process_frame
		n += 1
	_ok("9 el avance topa con la pared: el nodo no sale de su casilla (%s)" % str(Terreno3D.celda_de(g.position)), Terreno3D.celda_de(g.position) == Vector2i(15, 6) and g._adv_hecho < AnimacionesGolem.AVANCE_GOLPE - 0.1, "avance %.2f" % g._adv_hecho)
	_ok("9 y el modelo sigue al nodo (no asoma por la pared)", g.pj.position.distance_to(g.position) < 0.02)
	_limpiar()
	await avanzar(3)


## 10 · Tras el golpe, el núcleo está expuesto SOLO entre T_EXPUESTO_ABAJO y T_EXPUESTO_ARRIBA del clip: ×1,5 dentro, 0 fuera. Brilla y se apaga al morir.
func _caso_nucleo() -> void:
	_jugadora(Vector2i(8, 6))
	var g: Golem3D = _golem(Vector2i(12, 6), true)
	g.health = 5000.0
	g.vida_max = 5000.0
	await avanzar(3)
	g._exponer()                                                   # como al acabar el golpe
	var t0: float = g._t_estado
	var abajo: float = AnimacionesGolem.T_EXPUESTO_ABAJO
	var arriba: float = AnimacionesGolem.T_EXPUESTO_ARRIBA
	_ok("10 ventana expuesta = %.1f s del clip (de %.1f a %.1f)" % [arriba - abajo, abajo, arriba], arriba - abajo >= 2.0 and arriba - abajo <= 3.5)
	_ok("10 al caer de rodillas aún está armado (0 de daño)", not g.vulnerable())
	g.receive_damage(20.0)
	_ok("10 antes de la ventana el daño directo no pasa", is_equal_approx(g.health, 5000.0))
	while g._t_estado < abajo + 0.3:
		await process_frame
	_ok("10 dentro de la ventana es vulnerable", g.vulnerable())
	_ok("10 el núcleo brilla (%.2f > 3 × reposo)" % g.brillo_nucleo(), g.brillo_nucleo() > Golem3D.BRILLO_REPOSO * 3.0)
	var antes: float = g.health
	g.receive_damage(10.0)
	_ok("10 daño directo ×1,5 (10 → %.1f)" % (antes - g.health), is_equal_approx(antes - g.health, 15.0))
	g.receive_damage(10.0)
	_ok("10 «¡Núcleo!» solo la primera vez de la ventana (%d)" % _rotulos("¡Núcleo!"), _rotulos("¡Núcleo!") == 1)
	var p0: Vector3 = g.position
	var antes_f: float = g.health
	var r: Dictionary = g.recibir_golpe_cuerpo(Vector3(1, 0, 0), 5.0, 5000.0)
	_ok("10 el golpe F le hace 5 × 1,5 = 7,5 − defensa 10 → el suelo, 1,5 (29/10), y NO lo mueve", is_equal_approx(float(r["dano"]), 1.5) and is_equal_approx(antes_f - g.health, 1.5) and _mov(g, p0) < 0.01)
	# Con una flecha de verdad: sin debilidades (agua ×1: el hechizo × 1,5), y el rayo no tiene el ×1,5 del mojado.
	for el in ["agua", "rayo"]:
		var d: Dictionary = _preparar(Vector2i(10, 6), el, ["flecha"])
		var h: Hechizo = PrevisionHechizo._hechizo(lanzador, d)
		var e: Dictionary = _prevista(d, g, Vector3(1, 0, 0))
		var vida: float = g.health
		_lanzar(d, Vector3(1, 0, 0))
		await avanzar_s(1.2)
		_ok("10 flecha de %s: ×1,5 sin debilidades y −10 de defensa (29/10) (%.1f de %.1f) y «Núcleo ×1,5»" % [el, vida - g.health, h.dano], absf((vida - g.health) - Dano.aplicar(h.dano, 1.0, 1.0, 1.5, Dano.DEF_GOLEM)) < 0.6 and String(e.get("reaccion", "")) == "nucleo" and is_equal_approx(float(e.get("mult", 0.0)), 1.5))
	# Pasada la ventana: otra vez 0.
	while g._t_estado < arriba + 0.15:
		await process_frame
	_ok("10 pasada la ventana (empieza a levantarse) vuelve la piedra: no es vulnerable", not g.vulnerable())
	var v2: float = g.health
	g.receive_damage(30.0)
	_ok("10 y el daño ya no pasa", is_equal_approx(g.health, v2))
	await avanzar_s(0.5)
	_ok("10 el núcleo vuelve a apagarse (brillo %.2f)" % g.brillo_nucleo(), g.brillo_nucleo() < Golem3D.BRILLO_REPOSO * 2.0)
	while g.g_estado == "expuesto":
		await process_frame
	_ok("10 acaba la animación y vuelve a armado, con descanso", g.g_estado == "armado" and g._descanso > 0.0)
	_limpiar()
	await avanzar(3)


## 11 · Rodar en la ventana final del aviso da el tiempo bruja (C4), como con los demás.
func _caso_esquiva() -> void:
	_jugadora(Vector2i(8, 6))
	var j: Jugador3D = jugador as Jugador3D
	var g: Golem3D = _golem(Vector2i(10, 6), false)
	var a: AvisoAtaque3D = null
	var n: int = 0
	while n < 600:
		await process_frame
		n += 1
		for x in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (x as AvisoAtaque3D).dueno == g and not (x as AvisoAtaque3D).cancelado:
				a = x
		if a != null:
			break
	_ok("11 hay aviso", a != null)
	if a == null:
		_limpiar()
		return
	while is_instance_valid(a) and a.queda() > 0.15:
		await avanzar(1)
	var veces: int = TiempoBruja.veces
	var vida0: float = j.vida
	j._iniciar_voltereta(Vector3(0, 0, 1))                         # de lado, fuera de la zona, en la ventana de esquiva
	_ok("11 rodar en la ventana final del aviso abre el tiempo bruja (C4)", TiempoBruja.activa() and TiempoBruja.veces == veces + 1 and j.esquivas_perfectas >= 1)
	var t: float = 0.0
	while t < 1.5:
		t += await avanzar_s(1.0 / 30.0)
	_ok("11 y el golpe no le hace nada", j.vida >= vida0)
	_limpiar()
	await avanzar(3)


## 12 · Muere (expuesto: con botín normal; el núcleo se apaga).
func _caso_muerte() -> void:
	_jugadora(Vector2i(8, 6))
	var g: Golem3D = _golem(Vector2i(12, 6), true)
	await avanzar(3)
	g._exponer()
	while not g.vulnerable():
		await process_frame
	var sin_colmillo: bool = not g.botin_goblin
	var oro0: int = Estado.i().oro
	g.health = 5.0
	g.receive_damage(10.0)
	_ok("12 muere de rodillas por el núcleo", g.muerto and not g.se_hundio and not g.murio_en_lava)
	_ok("12 el núcleo se apaga (brillo %.2f)" % g.brillo_nucleo() if false else "12 el núcleo se apaga", g._nucleo_mats.is_empty())
	await avanzar_s(0.3)
	_ok("12 suelta oro (botín normal, 40)", _hay_oro())
	await avanzar_s(3.0)
	_ok("12 sin colmillo de goblin (no es un goblin)", sin_colmillo)
	_limpiar()
