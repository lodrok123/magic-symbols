extends "res://herramientas/escenario_base.gd"
## F1 de PLAN_BASE_DATOS (29/10, Juego): el botín por tablas, con la escena de verdad (PruebaBosque, un trozo llano del campamento sur: filas 18–21, columnas 1–12). Se coloca por código
## una pieza de cada clase y se hace lo que haría la jugadora: se ROMPE un jarrón (de un golpe y con un hechizo de agua), se QUEMA un seto (fuego), se HIELA una telaraña (hielo) y se
## coge con E, se SOPLA una colmena (cae el panal) y un nido (pluma), se QUEMA otra colmena (nube de veneno y nada de panal), se ENFRÍA lava con hielo (obsidiana) y se MATA un limo.
## Cada cosa cae al suelo y se coge pasando cerca; al final se comprueba lo que hay en la bolsa. `Botin.tirada_forzada` fija las tiradas donde hace falta un resultado exacto.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_botin.gd

var _fx: Vfx3D = null


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.name = "r_%s_%d_%d" % [tipo, c.x, c.y]
	r.preparar(tipo, c, "", _fx, null)
	r.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	maqueta.add_child(r)
	return r


## Recoge lo que haya cerca de `c`: pone a la jugadora ahí un momento (el botín se imanta y se coge solo).
func _recoger_en(c: Vector2i, segundos: float = 1.2) -> void:
	colocar_jugador(c)
	await avanzar_s(segundos)


func _suelo_con(nombre_nodo: String) -> int:
	var n: int = 0
	for h in maqueta.find_children(nombre_nodo + "*", "", true, false):
		if is_instance_valid(h) and h.get("recogido") != true and h.get("_vivo") != false:
			n += 1
	return n


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	Botin.olvidar_hierba()
	await cargar()
	if maqueta == null or jugador == null or lanzador == null:
		return
	_fx = maqueta.get("_fx") as Vfx3D
	var nivel: String = "EscenarioBotin"
	(jugador as Jugador3D).vida = 1000.0
	var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	var agua: RuneData = load("res://nucleo/water_rune.tres") as RuneData
	var hielo: RuneData = load("res://nucleo/ice_rune.tres") as RuneData
	var viento: RuneData = load("res://nucleo/wind_rune.tres") as RuneData

	# --- 1 · Jarrones: uno de un golpe (oro) y otro con un hechizo de agua (poción) ---------------------------------------------------------------------
	var j1 := Rompible3D.new()
	j1.name = "jarron_b1"
	var c_j1: Vector2i = Vector2i(2, 19)
	j1.preparar(c_j1, "jarron", "zona", 0, false, nivel, maqueta)
	maqueta.add_child(j1)
	var j2 := Rompible3D.new()
	j2.name = "jarron_b2"
	var c_j2: Vector2i = Vector2i(6, 19)
	j2.preparar(c_j2, "jarron", "zona", 0, false, nivel, maqueta)
	maqueta.add_child(j2)
	await avanzar(3)
	Botin.tirada_forzada = 0.6                        # jarron_bosque: 0,6 = oro (3 + floor(0,6 × 6) = 6)
	j1.golpear(jugador.position)
	await avanzar_s(0.3)
	Botin.tirada_forzada = -1.0
	_ok("1 un golpe rompe el jarrón y su tabla (`%s`, la del bosque) suelta oro" % j1.tabla_usada, j1.roto_ya and j1.tabla_usada == "jarron_bosque" and j1.soltado.size() == 1 and String(j1.soltado[0]["que"]) == "oro" and int(j1.soltado[0]["n"]) == 6, str(j1.soltado))
	_ok("1 el oro cae al suelo (una moneda sin coger todavía)", Estado.i().oro == 0 and _suelo_con("Oro") >= 1)
	await _recoger_en(c_j1 + Vector2i(0, 1))
	_ok("1 y se coge pasando cerca: +6 de oro", Estado.i().oro == 6, "oro %d" % Estado.i().oro)
	Botin.tirada_forzada = 0.95                       # 0,95 = poción
	var salio: bool = lanzar_a_celda("agua", ["flecha"], c_j2, c_j2 + Vector2i(2, 0))
	await avanzar_s(1.4)
	if not j2.roto_ya:
		j2.on_spell_hit(agua)                         # si el proyectil no llegó, el contrato directo (como prueba_mapa_abierto)
		await avanzar_s(0.3)
	Botin.tirada_forzada = -1.0
	_ok("1 un hechizo de agua rompe el otro jarrón (salió=%s) y cae una poción" % salio, j2.roto_ya and j2.soltado.size() == 1 and String(j2.soltado[0]["que"]) == "pocion", str(j2.soltado))
	_ok("1 la poción queda en el suelo como BotinObjeto3D", _suelo_con("Botin_pocion") == 1 and Estado.i().cuenta("pocion") == 0)
	await _recoger_en(c_j2 + Vector2i(0, 1))
	_ok("1 y se coge: +1 poción", Estado.i().cuenta("pocion") == 1, str(Estado.i().items))

	# --- 2 · Seto: fuego → se consume y suelta carbón ------------------------------------------------------------------------------------------------
	var c_seto: Vector2i = Vector2i(10, 19)
	var seto: Reactivo3D = _reactivo("seto", c_seto)
	await avanzar(3)
	Botin.tirada_forzada = 0.9                        # seto_quemado: 0,9 = carbón
	lanzar_a_celda("fuego", ["flecha"], c_seto, c_seto + Vector2i(2, 0))
	await avanzar_s(0.8)
	if seto.estado == Reactivo3D.EstadoObj.SANO:
		seto.on_spell_hit(fuego)
	await avanzar_s(Reactivo3D.COMBUSTIBLES["seto"][0] + 1.5)
	Botin.tirada_forzada = -1.0
	_ok("2 el seto arde y se consume", not is_instance_valid(seto) or seto.estado == Reactivo3D.EstadoObj.CONSUMIDO, "estado %s" % (str(seto.estado) if is_instance_valid(seto) else "liberado"))
	_ok("2 al consumirse suelta carbón (tabla seto_quemado)", _suelo_con("Botin_carbon") == 1, "en el suelo %d" % _suelo_con("Botin_carbon"))
	await _recoger_en(c_seto + Vector2i(0, 1))
	_ok("2 y se coge: +1 carbón", Estado.i().cuenta("carbon") == 1, str(Estado.i().items))

	# --- 3 · Telaraña: hielo → se hiela, deja de bloquear y se coge con E (seda) ---------------------------------------------------------------------
	var c_tela: Vector2i = Vector2i(2, 20)
	var tela: Reactivo3D = _reactivo("telarana", c_tela)
	Terreno3D.bloquear_celda(c_tela)
	await avanzar(3)
	lanzar_a_celda("hielo", ["flecha"], c_tela, c_tela + Vector2i(2, 0))
	await avanzar_s(1.0)
	if not tela.helada:
		tela.on_spell_hit(hielo)
		await avanzar_s(0.2)
	_ok("3 la telaraña se hiela con el hielo", tela.helada and not tela.can_burn())
	_ok("3 deja de bloquear su casilla", not Terreno3D.bloqueada(c_tela))
	colocar_jugador(c_tela + Vector2i(1, 0))
	await avanzar_s(0.3)
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar_s(0.1)
	var por_tecla: bool = Estado.i().cuenta("seda") == 1
	if not por_tecla and is_instance_valid(tela):
		tela.recoger_helado()                         # si la tecla no llegó (el foco de la ventana headless), el atajo
	await avanzar_s(0.6)
	_ok("3 con E se recoge (por la tecla: %s) y da 1 de seda; la pieza desaparece" % por_tecla, Estado.i().cuenta("seda") == 1 and not is_instance_valid(tela), str(Estado.i().items))

	# --- 4 · Colmena + viento: cae el panal; nido + viento: pluma ------------------------------------------------------------------------------------
	var c_col: Vector2i = Vector2i(10, 20)
	var col := Colmena3D.new()
	col.name = "colmena_b1"
	col.preparar(c_col, nivel)
	maqueta.add_child(col)
	var c_nido: Vector2i = Vector2i(6, 20)
	var nido := Nido3D.new()
	nido.name = "nido_b1"
	nido.preparar(c_nido)
	maqueta.add_child(nido)
	await avanzar(3)
	Botin.tirada_forzada = 0.99                        # panal:1-2 → 2
	lanzar_a_celda("viento", ["flecha"], c_col, c_col + Vector2i(2, 0))
	await avanzar_s(1.2)
	if col.estado == "colgada":
		col.on_spell_hit(viento)
		await avanzar_s(0.3)
	Botin.tirada_forzada = -1.0
	_ok("4 el viento descuelga la colmena: cae el panal (2) y apunta su flag", col.estado == "vacia" and _suelo_con("Botin_panal") == 1 and Flags.i().tiene(col.flag()), "%s %s" % [col.estado, str(col.soltado)])
	await _recoger_en(c_col + Vector2i(0, 1))
	_ok("4 se coge el panal: +2", Estado.i().cuenta("panal") == 2, str(Estado.i().items))
	lanzar_a_celda("viento", ["flecha"], c_nido, c_nido + Vector2i(2, 0))
	await avanzar_s(1.2)
	if nido.sacudidas == 0:
		nido.on_spell_hit(viento)
		await avanzar_s(0.3)
	_ok("4 el viento sacude el nido y suelta una pluma", nido.sacudidas == 1 and _suelo_con("Botin_pluma") == 1, "sacudidas %d" % nido.sacudidas)
	await _recoger_en(c_nido + Vector2i(0, 1))
	_ok("4 se coge la pluma: +1", Estado.i().cuenta("pluma") == 1, str(Estado.i().items))
	nido.sacudir()                                      # a los pocos segundos: todavía no
	_ok("4 y otra sacudida enseguida no suelta nada (45 s)", nido.sacudidas == 1)

	# --- 5 · Colmena + fuego: nube de veneno y nada de panal -----------------------------------------------------------------------------------------
	var c_col2: Vector2i = Vector2i(6, 21)
	var col2 := Colmena3D.new()
	col2.name = "colmena_b2"
	col2.preparar(c_col2, nivel)
	maqueta.add_child(col2)
	await avanzar(3)
	lanzar_a_celda("fuego", ["flecha"], c_col2, c_col2 + Vector2i(2, 0))
	await avanzar_s(1.0)
	if col2.estado == "colgada":
		col2.on_spell_hit(fuego)
	colocar_jugador(c_col2)                                # en su misma casilla: dentro del radio de la nube (1,5 u)
	var panales: int = Estado.i().cuenta("panal")
	await avanzar_s(0.8)
	_ok("5 el fuego quema la colmena: nube de veneno, la jugadora dentro se envenena y no cae panal", col2.estado == "ardiendo" and col2.envenenadas > 0 and (jugador as Jugador3D).get("_veneno_t") > 0.0 and _suelo_con("Botin_panal") == 0,
		"estado %s, envenenadas %d" % [col2.estado, col2.envenenadas])
	await avanzar_s(Colmena3D.T_NUBE)
	_ok("5 a los 3 s la nube se disipa y la colmena queda quemada; la flag impide repetir", col2.estado == "quemada" and Flags.i().tiene(col2.flag()) and Estado.i().cuenta("panal") == panales)

	# --- 6 · Lava + hielo → obsidiana (con agua, basalto) -------------------------------------------------------------------------------------------
	var c_lava: Vector2i = Vector2i(2, 21)
	var lava := Lava3D.new()
	lava.name = "lava_b1"
	lava.preparar([c_lava], 0.0)
	maqueta.add_child(lava)
	var roca := Recolectable3D.new()
	roca.name = "basalto_b1"
	roca.preparar(c_lava, "", 0.0, maqueta, "basalto")
	maqueta.add_child(roca)
	await avanzar(3)
	lanzar_a_celda("hielo", ["flecha"], c_lava, c_lava + Vector2i(2, 0))
	await avanzar_s(1.2)
	if lava.es_lava(c_lava):
		lava.on_spell_hit(hielo)
	_ok("6 el hielo enfría la lava en roca que recuerda el frío", lava.es_roca(c_lava) and lava.via_de_roca(c_lava) == Lava3D.VIA_HIELO, lava.via_de_roca(c_lava))
	colocar_jugador(c_lava + Vector2i(0, -1))
	roca.recoger()
	_ok("6 el basalto de esa roca se coge como OBSIDIANA", Estado.i().cuenta("obsidiana") == 1 and Estado.i().cuenta("basalto") == 0, str(Estado.i().items))

	# --- 7 · Un limo: muere y suelta oro + baba ----------------------------------------------------------------------------------------------------
	var c_limo: Vector2i = Vector2i(10, 21)
	var limo: Limo3D = Limo3D.crear(maqueta as Node3D, Terreno3D.centro_de(c_limo, Terreno3D.y_pies(c_limo)), "", false)
	limo.quieto = true
	await avanzar(3)
	var oro_antes: int = Estado.i().oro
	_ok("7 el limo usa la tabla `limo`", limo.tabla_botin == "limo" and limo.oro == Limo3D.ORO_LIMO)
	Botin.tirada_forzada = 0.0                         # limo: 0 = baba (1)
	limo.receive_damage(9999.0)
	var murio: bool = limo.muerto                      # el limo se libera al final de su muerte: se lee ya
	var soltado_limo: Array = limo.botin_soltado.duplicate()
	await avanzar_s(0.5)
	Botin.tirada_forzada = -1.0
	_ok("7 al morir suelta 5 de oro y una baba (tabla `limo`)", murio and _cuenta(soltado_limo, "oro") == 5 and _cuenta(soltado_limo, "baba_limo") == 1, str(soltado_limo))
	await _recoger_en(c_limo, 1.5)
	_ok("7 y se cogen: +5 de oro, +1 baba de limo", Estado.i().oro == oro_antes + 5 and Estado.i().cuenta("baba_limo") == 1, "oro %d, %s" % [Estado.i().oro, str(Estado.i().items)])

	# --- 8 · La bolsa al final -------------------------------------------------------------------------------------------------------------------------
	var esperado: Dictionary = {"pocion": 1, "carbon": 1, "seda": 1, "panal": 2, "pluma": 1, "obsidiana": 1, "baba_limo": 1}
	var igual: bool = true
	for k in esperado:
		if Estado.i().cuenta(String(k)) != int(esperado[k]):
			igual = false
	_ok("8 la bolsa tiene exactamente lo que cayó: poción, carbón, seda, 2 panales, pluma, obsidiana y baba (y %d de oro)" % Estado.i().oro, igual and Estado.i().items.size() == esperado.size() and Estado.i().oro == 11, str(Estado.i().items) + " oro %d" % Estado.i().oro)
	_ok("8 no queda nada suelto en el suelo", _suelo_con("Botin_") == 0 and _suelo_con("Oro") == 0, "objetos %d, oro %d" % [_suelo_con("Botin_"), _suelo_con("Oro")])

	# --- 9 · Las piezas nuevas por la gramática de Puzle3D, el golpe F al árbol, la hierba segada y el cofre con llave -----------------------------------
	Estado.i().items = {}
	Estado.i().oro = 0
	var z := Puzle3D.new()
	z.name = "PuzlesBotin"
	maqueta.add_child(z)
	z.iniciar(maqueta, "EscenarioBotin2", "; pieza col colmena 4 18
; pieza ni nido 8 18
; pieza ar arbol 11 18
; pieza mu musgo 12 21
; pieza cf cofre 1 18 abre_si=tener.llave gasta=si da=tabla:cofre_pequeno")
	await avanzar(8)
	_ok("9 la gramática monta colmena, nido, árbol, musgo y cofre sin avisos", z.nodo("col") is Colmena3D and z.nodo("ni") is Nido3D and z.nodo("ar") is Reactivo3D and z.nodo("mu") is Recolectable3D and z.nodo("cf") != null and z.avisos.is_empty(), str(z.avisos))
	var colz: Colmena3D = z.nodo("col") as Colmena3D
	_ok("9 la colmena de la gramática lleva el nivel de la escena en su flag", colz != null and colz.flag() == "escenariobotin2.colmena.col")
	var arbol: Reactivo3D = z.nodo("ar") as Reactivo3D
	colocar_jugador(Vector2i(11, 19))
	await avanzar_s(0.3)
	Botin.tirada_forzada = 0.5                        # tronco_golpe: 0,5 = resina
	var golpe: Dictionary = GolpeCuerpo.impactar(jugador, Vector3(0.0, 0.0, -1.0))
	Botin.tirada_forzada = -1.0
	_ok("9 el golpe F sacude el árbol (papel sacudible) y suelta resina", int(golpe["sacudidos"]) == 1 and arbol.sacudidas == 1 and _cuenta(arbol.soltado, "resina") == 1, str(golpe) + str(arbol.soltado))
	var golpe2: Dictionary = GolpeCuerpo.impactar(jugador, Vector3(0.0, 0.0, -1.0))
	_ok("9 un segundo golpe enseguida lo sacude pero no suelta más (30 s)", int(golpe2["sacudidos"]) == 1 and arbol.sacudidas == 1)
	await _recoger_en(Vector2i(11, 19), 1.2)
	_ok("9 la resina se coge: +1", Estado.i().cuenta("resina") == 1, str(Estado.i().items))
	# Hierba segada: el estado `segada` del suelo (lo marca quien siega) tira la tabla `hierba_segada`.
	var c_hierba: Vector2i = Vector2i(6, 20)
	var hay_mundo: bool = Mundo3D.actual != null
	Botin.tirada_forzada = 0.9                        # hierba_segada: 0,9 = baya
	Terreno3D.estados.poner(c_hierba, "segada", true)
	await avanzar(3)
	Botin.tirada_forzada = -1.0
	_ok("9 al segar una casilla cae una baya (tabla hierba_segada; hay Mundo3D: %s)" % hay_mundo, hay_mundo and _suelo_con("Botin_baya") == 1, "en el suelo %d" % _suelo_con("Botin_baya"))
	await _recoger_en(c_hierba, 1.2)
	_ok("9 y se coge: +1 baya", Estado.i().cuenta("baya") == 1, str(Estado.i().items))
	Terreno3D.estados.poner(c_hierba, "segada", false)
	Botin.tirada_forzada = 0.9
	Terreno3D.estados.poner(c_hierba, "segada", true)
	await avanzar(3)
	Botin.tirada_forzada = -1.0
	_ok("9 la misma casilla vuelta a segar enseguida (< 60 s) no da nada", _suelo_con("Botin_baya") == 0 and Estado.i().cuenta("baya") == 1)
	# Musgo (planta nueva) por la gramática.
	var musgo: Recolectable3D = z.nodo("mu") as Recolectable3D
	colocar_jugador(Vector2i(12, 21))
	_ok("9 el musgo de la gramática da musgo_cueva", musgo.objeto == "musgo_cueva" and musgo.recoger() and Estado.i().cuenta("musgo_cueva") == 1)
	# Cofre con llave: sellado sin ella; con ella se abre, la gasta y da la tabla.
	var cf: Variant = z.nodo("cf")
	colocar_jugador(Vector2i(2, 19))
	await avanzar_s(0.5)
	var abrio_sin: bool = bool(cf.call("abrir"))
	_ok("9 el cofre `abre_si=tener.llave` no abre sin llave", not abrio_sin and not bool(cf.get("es_abierto")))
	Estado.i().agregar("llave", 1)
	Botin.tirada_forzada = 0.0                        # cofre_pequeno: 0 = oro (10)
	var abrio: bool = bool(cf.call("abrir"))
	await avanzar_s(3.5)
	Botin.tirada_forzada = -1.0
	_ok("9 con la llave abre, la gasta (`gasta=si`) y da la tabla `cofre_pequeno` (10 de oro)", abrio and bool(cf.get("es_abierto")) and Estado.i().cuenta("llave") == 0 and Estado.i().oro == 10, "oro %d, %s" % [Estado.i().oro, str(Estado.i().items)])


func _cuenta(l: Array, que: String) -> int:
	var n: int = 0
	for it in l:
		if String((it as Dictionary)["que"]) == que:
			n += int((it as Dictionary)["n"])
	return n
