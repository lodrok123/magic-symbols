extends "res://herramientas/escenario_base.gd"
## ᛒ SUELO (18/11/2026, diseño de Pablo; magia/glifo_suelo.gd). Sobre la escena real del Bosque, con goblins reales:
##   · el glifo existe (tabla, biblioteca, trazo, PNG, texto) y se RECONOCE dibujado; un hechizo con ᛒ lleva `suelo` y `en_punto`;
##   · HIELO sobre AGUA: plataforma (la casilla se pisa) que, al acabar, vuelve a ser agua; HIELO sobre suelo: capa de escarcha que hace PATINAR al enemigo pequeño y no al grande;
##   · TIERRA sobre VACÍO: plataforma (se pisa) que, al acabar, devuelve el vacío; TIERRA sobre AGUA: no crea nada; TIERRA sobre suelo: capa que RALENTIZA;
##   · FUEGO y AGUA (los demás): TRAMPA, quieta hasta que un enemigo entra; entonces se ilumina con el color del elemento, golpea con el hechizo (daño y estado) a lo del radio y desaparece;
##     sin pisar, desaparece a los 20 s (más con ᛉ permanencia); como mucho MAX_VIVOS suelos plantados.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_glifo_suelo.gd

const ESTE := Vector3(1, 0, 0)

var _creados: Array = []
var _libre: Vector2i = Vector2i.ZERO
var _libro_previo: String = ""


func _c(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _pos(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _h(archivo: String, glifos: Dictionary = {"suelo": 1}) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), glifos)


func _suelo_llano(c: Vector2i, n0: int) -> bool:
	return Terreno3D.en_mapa(c) and not Terreno3D.es_agua(c) and not Terreno3D.bloqueada(c) and Terreno3D.altura_en(c) == n0


func _buscar_claro(r: int) -> bool:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(r, alto - r):
		for x in range(r, ancho - r):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if not _suelo_llano(c + Vector2i(dx, dy), n0):
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	if mejor.x < 0:
		return false
	colocar_jugador(mejor)
	_libre = mejor
	return true


## La casilla de agua (de verdad: `es_agua`, a nivel 0) con más agua alrededor (las ocho de al lado): la más «adentro» del río o del lago.
func _buscar_agua() -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	var mejor := Vector2i(-1, -1)
	var n_mejor: int = -1
	for y in range(1, lado - 1):
		for x in range(1, lado - 1):
			var c := Vector2i(x, y)
			if Terreno3D.altura_en(c) != 0 or not Terreno3D.es_agua(c) or Terreno3D.agua_sim.profundidad_casilla(c) < 0.1:
				continue
			var n: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and Terreno3D.es_agua(c + Vector2i(dx, dy)):
						n += 1
			if n > n_mejor:
				n_mejor = n
				mejor = c
	return mejor


func _poner_letra(c: Vector2i, l: String) -> void:
	if Terreno3D.datos_propios:
		Terreno3D.poner_letra(c, l)
		return
	var m: PackedStringArray = maqueta.get("_mapa")
	m[c.y] = m[c.y].substr(0, c.x) + l + m[c.y].substr(c.x + 1)
	maqueta.set("_mapa", m)


## Un goblin quieto, con vida de sobra, sin debilidad ni resistencia, en la casilla `c`.
func _goblin(c: Vector2i, desvio: Vector3 = Vector3.ZERO) -> Combate3D:
	var p: Vector3 = _pos(c) + desvio
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = ESTE
	g.debil = ""
	g.resiste = ""
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	for s in lanzador.suelos_vivos():
		(s as GlifoSuelo).retirar("prueba")
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	for n in lanzador.get_children():
		if n is HechizoVivo:
			(n as Node).queue_free()
	for e in [EstadosSuelo3D.VAPOR, EstadosSuelo3D.ELECTRIFICADA, EstadosSuelo3D.MOJADA, EstadosSuelo3D.QUEMADA, EstadosSuelo3D.ESCOMBRO]:
		for c in Terreno3D.estados.celdas(String(e)).duplicate():
			Terreno3D.estados.poner(c as Vector2i, String(e), false)
	await avanzar(2)


## Prepara la página 0 con `elemento` y los glifos dados, por el libro (como el juego), sin entrar en el modo de apuntar. Devuelve `_preparado` (vacío si se negó).
func _preparar(elemento: String, glifos: Array) -> Dictionary:
	colocar_jugador(_libre)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	if not lanzador._preparar_pagina(0):
		return {}
	return lanzador._preparado.duplicate()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	_libro_previo = Repertoire.libro
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	var hay: bool = _buscar_claro(5)
	if not hay:
		hay = _buscar_claro(4)
	_ok("0 hay un claro llano donde probar", hay)
	if not hay:
		return
	await avanzar(40)
	_glifo()
	await _hielo_agua()
	await _hielo_suelo()
	await _tierra_vacio()
	await _tierra_agua()
	await _tierra_suelo()
	await _trampas()
	await _caducidad_trampa()
	await _tope()
	Repertoire.libro = _libro_previo
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- el glifo

## Un dibujo sin ruido de un gesto de la tabla («D|DR,DL,DR,DL»): los vértices unidos por puntos cada 4 px.
func _dibujo(texto: String) -> Array:
	var trazos: Array = []
	var k: int = 0
	for sec in TrazosRectos.texto_a_gesto(texto):
		var v: Array = [Vector2(100.0, 100.0 + float(k) * 150.0)]
		for d in (sec as Array):
			v.append((v[v.size() - 1] as Vector2) + TrazosRectos.vector_de(int(d)) * 60.0)
		var puntos: Array = []
		for i in range(v.size() - 1):
			var a: Vector2 = v[i]
			var b: Vector2 = v[i + 1]
			var n: int = maxi(int(a.distance_to(b) / 4.0), 1)
			for j in range(n):
				puntos.append(a.lerp(b, float(j) / float(n)))
		puntos.append(v[v.size() - 1])
		trazos.append(puntos)
		k += 1
	return trazos


func _glifo() -> void:
	_ok("G1 ᛒ está en la tabla de glifos, la biblioteca (SIGILS y RECORDABLE) y la BIBLIA como sello", Sigils.GLIFOS.has("suelo") and GestureLibrary.SIGILS.has("suelo") and GestureLibrary.RECORDABLE.has("suelo")
		and String(GestureLibrary.BIBLIA["suelo"]["uso"]) == "sello" and String(GestureLibrary.BIBLIA["suelo"]["futhark"]) == "ᛒ" and String(GestureLibrary.BIBLIA["suelo"]["nombre_runa"]) == "berkana")
	_ok("G2 «berkana» ya no es una runa libre suelta de la BIBLIA ni se graba con ese nombre", not GestureLibrary.BIBLIA.has("berkana") and not GestureLibrary.RECORDABLE.has("berkana"))
	_ok("G3 tiene su PNG (berkana.png), su texto y su nombre visible «suelo»", Sigils.GLYPHS.has("suelo") and TextosObjetos.GLIFO.has("suelo") and String(TextosObjetos.GLIFO["suelo"]) != "" and Sigils.nombre_visible("suelo") == "suelo")
	_ok("G4 el repertorio del banco de pruebas (kits `todo` y `pruebas`) lo incluye", (Lanzador3D.PROGRESIONES["todo"]["glifos"] as Array).has("suelo") and (Lanzador3D.PROGRESIONES["pruebas"]["glifos"] as Array).has("suelo"))
	_ok("G5 la tabla de trazos lo tiene (palo + dos picos)", String(TrazosRectos.SELLOS["suelo"]) == "D|DR,DL,DR,DL")
	var res: Dictionary = TrazosRectos.reconocer(_dibujo(String(TrazosRectos.SELLOS["suelo"])), TrazosRectos.SELLOS)
	_ok("G6 un ᛒ dibujado se RECONOCE como suelo", bool(res["accepted"]) and String(res["name"]) == "suelo", str(res))
	var h: Hechizo = _h("fire")
	_ok("G7 un hechizo con ᛒ lleva `suelo` y nace donde apuntas, y no viaja", h != null and h.suelo and h.en_punto and not h.viaja and h.glifos.has("suelo"))
	_ok("G8 sin ᛒ no hay `suelo`", not Hechizo.construir(load("res://nucleo/fire_rune.tres"), {"flecha": 1}).suelo)
	_ok("G9 los pasos de la regla: hielo y tierra distinguen casilla; el resto es trampa en suelo", GlifoSuelo.decidir("fuego", _libre) == GlifoSuelo.Caso.TRAMPA and GlifoSuelo.decidir("hielo", _libre) == GlifoSuelo.Caso.CAPA_HIELO
		and GlifoSuelo.decidir("tierra", _libre) == GlifoSuelo.Caso.CAPA_TIERRA)
	_ok("G10 los colores de la trampa son los del juego (fuego y agua distintos)", GlifoSuelo.color_de(_h("fire")) == Combate3D.COLORES["fuego"] and GlifoSuelo.color_de(_h("water")) == Combate3D.COLORES["agua"]
		and GlifoSuelo.color_de(_h("fire")) != GlifoSuelo.color_de(_h("water")))
	var cuesta: Hechizo = _h("fire", {"suelo": 1, "permanencia": 1})
	_ok("G11 la trampa dura TRAMPA_VIDA_S + la permanencia del hechizo (%.1f s)" % GlifoSuelo.vida_de(GlifoSuelo.Caso.TRAMPA, cuesta), _c(GlifoSuelo.TRAMPA_VIDA_S, 20.0) and GlifoSuelo.vida_de(GlifoSuelo.Caso.TRAMPA, cuesta) > 20.0
		and _c(GlifoSuelo.vida_de(GlifoSuelo.Caso.TRAMPA, _h("fire")), 20.0))


# ---------------------------------------------------------------------------------------------------------------- hielo

func _hielo_agua() -> void:
	var agua: Vector2i = _buscar_agua()
	_ok("H0 hay una casilla de agua de verdad donde probar", agua.x >= 0)
	if agua.x < 0:
		return
	var h: Hechizo = _h("ice")
	var vida: float = h.persiste + h.permanencia
	_ok("H1 el hielo sobre agua es una PLATAFORMA (según la regla)", GlifoSuelo.decidir("hielo", agua) == GlifoSuelo.Caso.PLATAFORMA_HIELO and GlifoSuelo.rechazo(lanzador, h, Terreno3D.centro_de(agua)) == "")
	_ok("H2 antes de plantar, el agua es agua: no se pisa", Terreno3D.es_agua(agua) and not Terreno3D.hielo_fisico(agua) and not Terreno3D.pisable(agua, 0, false, 1, false))
	var n: int = lanzador.lanzar_hechizo(h, Terreno3D.centro_de(agua, Terreno3D.alto_agua), ESTE)
	_ok("H3 el hechizo se planta (ocupa 1 casilla)", n == 1)
	await avanzar(4)
	_ok("H4 la superficie se hiela: hay hielo físico, ya no es agua y SE PISA", Terreno3D.hielo_fisico(agua) and not Terreno3D.es_agua(agua) and Terreno3D.pisable(agua, 0, false, 1, false))
	var vivos: Array = lanzador.suelos_vivos()
	_ok("H5 queda anotada como plataforma de hielo, dibujada con la placa de hielo (HieloToy.Figura.SUELO)", vivos.size() == 1 and (vivos[0] as GlifoSuelo).caso == GlifoSuelo.Caso.PLATAFORMA_HIELO
		and (vivos[0] as GlifoSuelo)._vfx is HieloToy and ((vivos[0] as GlifoSuelo)._vfx as HieloToy).figura == HieloToy.Figura.SUELO)
	await avanzar_s(vida * 0.5)
	_ok("H6 a la mitad de lo que dura (%.1f s) sigue pisable" % (vida * 0.5), Terreno3D.hielo_fisico(agua) and Terreno3D.pisable(agua, 0, false, 1, false))
	await avanzar_s(vida * 0.5 + 1.5)
	_ok("H7 al acabar, la casilla VUELVE A SER AGUA (no se pisa) y la plataforma se ha ido", Terreno3D.es_agua(agua) and not Terreno3D.hielo_fisico(agua) and not Terreno3D.pisable(agua, 0, false, 1, false) and lanzador.suelos_vivos().is_empty())
	await _limpiar()


func _hielo_suelo() -> void:
	var c: Vector2i = _libre + Vector2i(1, 1)
	var fuera: Vector2i = _libre + Vector2i(-2, 1)
	var h: Hechizo = _h("ice")
	_ok("S1 el hielo sobre suelo es una CAPA de escarcha (según la regla)", GlifoSuelo.decidir("hielo", c) == GlifoSuelo.Caso.CAPA_HIELO)
	var chico: Combate3D = _goblin(c, Vector3(0.3, 0.0, 0.0))
	var grande: Combate3D = _goblin(c, Vector3(-0.3, 0.0, 0.3))
	grande.masa = 3.3                      # el peso del elemental (el gólem, 6): lo grande
	var aparte: Combate3D = _goblin(fuera)
	_ok("S2 el criterio de tamaño es la masa: goblin %.1f, limo y gato por debajo; elemental y gólem por encima de %.1f" % [chico.masa, Combate3D.MASA_MAX_PATINA], chico.masa <= Combate3D.MASA_MAX_PATINA and grande.masa > Combate3D.MASA_MAX_PATINA
		and chico.puede_patinar() and not grande.puede_patinar())
	_ok("S3 se planta la capa de escarcha (1 casilla)", lanzador.lanzar_hechizo(h, _pos(c), ESTE) == 1 and lanzador.suelos_vivos().size() == 1)
	var x0: float = chico.position.x
	var xg: float = grande.position.x
	await avanzar(3)
	_ok("S4 el pequeño PATINA (%.2f s) y el grande no" % chico.patina, chico.patina > 0.0 and grande.patina <= 0.0)
	await avanzar_s(0.8)
	_ok("S5 el pequeño desliza hacia donde miraba (%.2f u) y el grande se queda donde estaba (%.2f u)" % [chico.position.x - x0, grande.position.x - xg], chico.position.x - x0 > 0.3 and absf(grande.position.x - xg) < 0.05)
	_ok("S6 el de fuera de la capa no patina", aparte.patina <= 0.0 and aparte.position.is_equal_approx(_pos(fuera)))
	await avanzar_s(1.0)
	_ok("S7 deja de patinar tras T_PATINA y no se queda deslizando sin fin (agarre posterior)", chico.patina <= 0.0)
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- tierra

func _tierra_vacio() -> void:
	var v: Vector2i = _libre + Vector2i(3, 0)
	var antes: String = Terreno3D.letra_de(v)
	_poner_letra(v, " ")
	_ok("V0 la casilla es un VACÍO (no hay suelo)", Terreno3D.es_vacio(v) and not Terreno3D.pisable(v, 0, false, 1, false))
	var h: Hechizo = _h("earth")
	var vida: float = h.persiste + h.permanencia
	_ok("V1 la tierra sobre un vacío es una PLATAFORMA (según la regla)", GlifoSuelo.decidir("tierra", v) == GlifoSuelo.Caso.PLATAFORMA_TIERRA and GlifoSuelo.rechazo(lanzador, h, Terreno3D.centro_de(v, Terreno3D.alto_suelo)) == "")
	_ok("V2 se planta (1 casilla)", lanzador.lanzar_hechizo(h, Terreno3D.centro_de(v, Terreno3D.alto_suelo), ESTE) == 1)
	await avanzar(3)
	_ok("V3 la casilla SE PISA mientras dura (cota %.2f sobre un suelo de %.2f)" % [Terreno3D.y_pies(v), Terreno3D.alto_suelo], Terreno3D.plataformas_tierra.has(v) and Terreno3D.pisable(v, 0, false, 1, false)
		and _c(Terreno3D.y_pies(v), Terreno3D.alto_suelo + Lanzador3D.ALTO_PLATAFORMA_TIERRA))
	lanzador._avanzar_caducidades(vida - 0.5)
	_ok("V4 a falta de medio segundo sigue ahí", Terreno3D.plataformas_tierra.has(v))
	lanzador._avanzar_caducidades(1.0)
	_ok("V5 al acabar (%.0f s) VUELVE EL VACÍO: ni plataforma ni se pisa" % vida, not Terreno3D.plataformas_tierra.has(v) and Terreno3D.es_vacio(v) and not Terreno3D.pisable(v, 0, false, 1, false))
	_poner_letra(v, antes)
	await _limpiar()


func _tierra_agua() -> void:
	var agua: Vector2i = _buscar_agua()
	if agua.x < 0:
		_ok("A0 hay agua donde probar", false)
		return
	var h: Hechizo = _h("earth")
	_ok("A1 la tierra sobre agua no hace NADA (según la regla) y se rechaza antes de cobrar: «%s»" % GlifoSuelo.rechazo(lanzador, h, Terreno3D.centro_de(agua)), GlifoSuelo.decidir("tierra", agua) == GlifoSuelo.Caso.NADA
		and GlifoSuelo.rechazo(lanzador, h, Terreno3D.centro_de(agua)) != "")
	var plataformas: int = Terreno3D.plataformas_tierra.size()
	var bloques: int = lanzador.bloques_de_tierra()
	_ok("A2 lanzar_hechizo no crea nada", lanzador.lanzar_hechizo(h, Terreno3D.centro_de(agua, Terreno3D.alto_agua), ESTE) == 0 and lanzador.suelos_vivos().is_empty()
		and Terreno3D.plataformas_tierra.size() == plataformas and lanzador.bloques_de_tierra() == bloques)
	await avanzar(3)
	_ok("A3 el agua sigue siendo agua", Terreno3D.es_agua(agua) and not Terreno3D.pisable(agua, 0, false, 1, false) and not Terreno3D.plataformas_tierra.has(agua))
	var datos: Dictionary = _preparar("tierra", ["suelo"])
	_ok("A4 la página se prepara por el libro (el glifo entra en la receta)", not datos.is_empty() and (datos["hechizo"] as Hechizo).suelo)
	if not datos.is_empty():
		var tinta_antes: float = lanzador.tinta.actual if lanzador.tinta != null else 0.0
		_ok("A5 lanzado al agua por el camino del juego se niega SIN cobrar tinta", not lanzador.lanzar_ahora(datos, Terreno3D.centro_de(agua), ESTE) and (lanzador.tinta == null or _c(lanzador.tinta.actual, tinta_antes)))
	await _limpiar()


func _tierra_suelo() -> void:
	var c: Vector2i = _libre + Vector2i(1, 1)
	var h: Hechizo = _h("earth")
	_ok("T1 la tierra sobre suelo es una CAPA que ralentiza (según la regla)", GlifoSuelo.decidir("tierra", c) == GlifoSuelo.Caso.CAPA_TIERRA)
	var g: Combate3D = _goblin(c)
	var control: Combate3D = _goblin(_libre + Vector2i(-2, 1))
	var base: float = g.vel_mult()
	_ok("T2 se planta (1 casilla)", lanzador.lanzar_hechizo(h, _pos(c), ESTE) == 1)
	await avanzar(3)
	_ok("T3 el que la pisa va LENTO (lento %.2f s, velocidad ×%.2f de %.2f)" % [g.lento, g.vel_mult(), base], g.lento > 0.0 and g.vel_mult() < base - 0.001)
	_ok("T4 el de fuera no", control.lento <= 0.0 and _c(control.vel_mult(), base))
	_ok("T5 la capa no hace daño ni lo empuja", g.health >= 100000.0 and g.position.is_equal_approx(_pos(c)))
	g.position = _pos(_libre + Vector2i(1, -3))
	await avanzar_s(1.0)
	_ok("T6 al salir de la capa se le pasa la lentitud (%.2f s)" % g.lento, g.lento <= 0.0)
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- trampas

func _trampa(elemento: String, archivo: String, estado: Callable) -> void:
	var c: Vector2i = _libre + Vector2i(1, 1)
	var h: Hechizo = _h(archivo)
	var g: Combate3D = _goblin(_libre + Vector2i(-2, 1))
	var cerca: Combate3D = _goblin(c + Vector2i(1, 0))          # a una casilla de la trampa: dentro del radio
	var lejos: Combate3D = _goblin(c + Vector2i(4, 0))          # a cuatro: fuera
	_ok("%s1 el %s sobre suelo es una TRAMPA (según la regla)" % [elemento, elemento], GlifoSuelo.decidir(elemento, c) == GlifoSuelo.Caso.TRAMPA)
	var datos: Dictionary = _preparar(elemento, ["suelo"])
	_ok("%s2 la página se prepara por el libro y se lanza por el camino del juego" % elemento, not datos.is_empty() and lanzador.lanzar_ahora(datos, _pos(c), ESTE))
	var vivos: Array = lanzador.suelos_vivos()
	_ok("%s3 queda UNA trampa plantada en la casilla" % elemento, vivos.size() == 1 and (vivos[0] as GlifoSuelo).caso == GlifoSuelo.Caso.TRAMPA and (vivos[0] as GlifoSuelo).celda == c)
	if vivos.is_empty():
		await _limpiar()
		return
	var s: GlifoSuelo = vivos[0]
	var mats: Array = s._vfx.get_meta("mats")
	var espera: StandardMaterial3D = mats[0]
	var color: Color = GlifoSuelo.color_de(h)
	_ok("%s4 mientras espera el símbolo es DISCRETO (alpha %.2f, sin mezcla aditiva)" % [elemento, espera.albedo_color.a], espera.albedo_color.a < 0.45 and espera.blend_mode != BaseMaterial3D.BLEND_MODE_ADD)
	var vida0: float = g.health
	var cerca0: float = cerca.health
	await avanzar_s(1.5)
	_ok("%s5 no hace nada hasta que entra un enemigo (los de fuera de la casilla, intactos)" % elemento, s.activo and not s.disparada and g.health >= vida0 and cerca.health >= cerca0)
	g.position = _pos(c)
	await avanzar(1)
	_ok("%s6 entra un enemigo: EXPLOTA y se gasta (un solo uso)" % elemento, s.disparada and not s.activo and lanzador.suelos_vivos().is_empty())
	var lit: StandardMaterial3D = (s._vfx.get_meta("mats") as Array)[0]
	_ok("%s7 el símbolo se ilumina con el COLOR del elemento (mezcla aditiva, tono %s)" % [elemento, str(color)], lit.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
		and (lit.albedo_color.r - lit.albedo_color.b) * (color.r - color.b) > 0.0 and lit.albedo_color.r >= color.r and lit.albedo_color.b >= color.b)
	_ok("%s8 le llega el golpe del hechizo: daño %.1f y su estado" % [elemento, vida0 - g.health], g.health < vida0 and estado.call(g))
	_ok("%s9 también al de la casilla de al lado (radio %.1f casilla) y NO al de cuatro casillas" % [elemento, GlifoSuelo.RADIO_TRAMPA_CAS], cerca.health < cerca0 and lejos.health >= 100000.0)
	await avanzar_s(2.0)
	var otra: Combate3D = _goblin(c)
	var otra0: float = otra.health
	await avanzar(3)
	_ok("%s10 desaparecida: otro enemigo que entre después ya no recibe nada" % elemento, otra.health >= otra0 and lanzador.suelos_vivos().is_empty())
	await _limpiar()


func _trampas() -> void:
	await _trampa("fuego", "fire", func(g: Combate3D) -> bool: return g.quemando > 0.0)
	await _trampa("agua", "water", func(g: Combate3D) -> bool: return g.mojado > 0.0)
	await _trampa("rayo", "lightning", func(g: Combate3D) -> bool: return g.stun_timer > 0.0 or g.health < 100000.0)


func _caducidad_trampa() -> void:
	var c: Vector2i = _libre + Vector2i(1, 1)
	var h: Hechizo = _h("fire")
	var g: Combate3D = _goblin(_libre + Vector2i(-2, 1))
	_ok("C1 se planta una trampa de fuego", lanzador.lanzar_hechizo(h, _pos(c), ESTE) == 1)
	var s: GlifoSuelo = lanzador.suelos_vivos()[0]
	var vida0: float = g.health
	lanzador._avanzar_caducidades(19.0)
	_ok("C2 a los 19 s sigue ahí", s.activo and not s.disparada)
	lanzador._avanzar_caducidades(1.5)
	_ok("C3 a los 20 s sin que nadie la pise DESAPARECE, sin explotar", not s.activo and not s.disparada and lanzador.suelos_vivos().is_empty() and g.health >= vida0)
	await _limpiar()
	# con ᛉ permanencia dura más
	var hp: Hechizo = _h("fire", {"suelo": 1, "permanencia": 1})
	_ok("C4 con ᛉ la trampa sigue a los 20,5 s y se va a los %.1f s" % GlifoSuelo.vida_de(GlifoSuelo.Caso.TRAMPA, hp), lanzador.lanzar_hechizo(hp, _pos(c), ESTE) == 1)
	var sp: GlifoSuelo = lanzador.suelos_vivos()[0]
	lanzador._avanzar_caducidades(20.5)
	var sigue: bool = sp.activo
	lanzador._avanzar_caducidades(hp.permanencia + 0.5)
	_ok("C5 ... (a los 20,5 s seguía: %s; pasados los %.1f s se fue)" % [str(sigue), GlifoSuelo.vida_de(GlifoSuelo.Caso.TRAMPA, hp)], sigue and not sp.activo)
	await _limpiar()


func _tope() -> void:
	var antes: int = lanzador.suelos_vivos().size()
	var plantados: Array = []
	for i in range(GlifoSuelo.MAX_VIVOS + 2):
		var c: Vector2i = _libre + Vector2i(-3 + (i % 5), -4 + (i / 5) * 2)
		if lanzador.lanzar_hechizo(_h("fire"), _pos(c), ESTE) == 1:
			plantados.append(lanzador.suelos_vivos().back())
	_ok("P1 como mucho %d suelos plantados a la vez (hay %d de %d plantados)" % [GlifoSuelo.MAX_VIVOS, lanzador.suelos_vivos().size(), plantados.size()], antes == 0 and plantados.size() == GlifoSuelo.MAX_VIVOS + 2 and lanzador.suelos_vivos().size() == GlifoSuelo.MAX_VIVOS)
	_ok("P2 se retira el más ANTIGUO", plantados.size() > 0 and not (plantados[0] as GlifoSuelo).activo and (plantados.back() as GlifoSuelo).activo)
	var c0: Vector2i = _libre + Vector2i(1, 1)
	await _limpiar()
	var a: GlifoSuelo = null
	if lanzador.lanzar_hechizo(_h("fire"), _pos(c0), ESTE) == 1:
		a = lanzador.suelos_vivos()[0]
	lanzador.lanzar_hechizo(_h("water"), _pos(c0), ESTE)
	_ok("P3 una casilla, un suelo: el nuevo sustituye al anterior", a != null and not a.activo and lanzador.suelos_vivos().size() == 1 and (lanzador.suelos_vivos()[0] as GlifoSuelo).elemento == "agua")
	await _limpiar()
