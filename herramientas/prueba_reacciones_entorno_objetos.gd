extends SceneTree
## R2 de docs/REACCIONES_ENTORNO_2026-11-06.md: los objetos (`Reactivo3D`, `Cuerda3D`) reaccionan a lo que antes solo estaba declarado. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reacciones_entorno_objetos.gd
## 1 conduce: un emisor mojado entra en Terreno3D.conductores T_CONDUCE s (30) y el fuego lo seca; la escarcha lo corta.
## 2 congelable: puerta goblin, torre goblin, tótem y árbol; congelados no arden, no se activan ni se sacuden; el calor los descongela; CONGELADO_S los suelta.
## 3 dosis de calor: seto mojado pide dos fuegos, seco uno. 4 magma: prende lo mojado al primero. 5 naturaleza: enreda tótem y árbol, el fuego los libera.
## 6 escarcha: la cuerda helada no cae aunque arda hasta que pasa la escarcha. 7 los datos de Materia.reaccion (magma, naturaleza, hielo sobre metal).
## El tiempo se avanza a mano llamando a `_process` (la prueba no espera fotogramas, así no se cuenta dos veces).

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

var _fallos: int = 0
var _m: MundoFalso = null
var _fx: Vfx3D = null
var _x: float = 100.0
var _celda_n: int = 40
var _senales: Dictionary = {}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_m = MundoFalso.new()
	_m._props = Node3D.new()
	_m.add_child(_m._props)
	root.add_child(_m)
	_fx = Vfx3D.new()
	root.add_child(_fx)
	Lanzador3D.configurar(_m)
	Terreno3D.conductores.clear()
	_conduce()
	_congelable()
	_dosis()
	_magma()
	_naturaleza()
	_cuerda()
	_datos()
	_vapor()
	_cuenco()
	Terreno3D.conductores.clear()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _rune(id: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % id) as RuneData


func _pieza(tipo: String, elemento: String = "") -> Reactivo3D:
	var o: Reactivo3D = Reactivo3D.new()
	_celda_n += 1
	o.preparar(tipo, Vector2i(_celda_n, 1), elemento, _fx, null)
	o.position = Vector3(_x, 0.0, 0.0)
	_x += 10.0
	root.add_child(o)
	return o


## Avanza `s` segundos de juego a pasos de 0,1 s.
func _avanzar(o: Node, s: float) -> void:
	var pasos: int = int(round(s * 10.0))
	for i in range(pasos):
		o._process(0.1)


func _cuenta(o: Object, senal: String) -> void:
	_senales[senal + str(o.get_instance_id())] = []
	o.connect(senal, func(v: bool) -> void: (_senales[senal + str(o.get_instance_id())] as Array).append(v))


func _vistas(o: Object, senal: String) -> Array:
	return _senales.get(senal + str(o.get_instance_id()), []) as Array


func _conduce() -> void:
	var e: Reactivo3D = _pieza("emisor_rayo", "rayo")
	_cuenta(e, "conduce_cambio")
	_ok("1 emisor seco: no conduce y el fuego no le hace nada", not Terreno3D.conductores.has(e.celda) and e.reaccion_a(_rune("fire")) == "" and not e.spell_reacts(_rune("fire")))
	_ok("1 el agua lo moja (previsión «moja» y reacciona)", e.reaccion_a(_rune("water")) == "moja" and e.spell_reacts(_rune("water")))
	e.on_spell_hit(_rune("water"))
	_ok("1 mojado: entra en Terreno3D.conductores", Terreno3D.conductores.has(e.celda) and e.conduce_ahora())
	_ok("1 y emite conduce_cambio(true) una vez", _vistas(e, "conduce_cambio") == [true])
	_avanzar(e, 29.5)
	_ok("1 a los 29,5 s sigue conduciendo", Terreno3D.conductores.has(e.celda))
	_avanzar(e, 1.0)
	_ok("1 a los 30,5 s ya no (T_CONDUCE = 30)", not Terreno3D.conductores.has(e.celda) and _vistas(e, "conduce_cambio") == [true, false])
	e.on_spell_hit(_rune("water"))
	_avanzar(e, 10.0)
	_ok("1 el fuego lo seca antes de tiempo: reacciona «seca» y sale de conductores", e.reaccion_a(_rune("fire")) == "seca" and e.spell_reacts(_rune("fire")))
	e.on_spell_hit(_rune("fire"))
	_ok("1 seco por fuego a los 10 s: no conduce", not Terreno3D.conductores.has(e.celda) and not e.conduce_ahora())
	# la escarcha corta la corriente aunque siga mojado
	e.on_spell_hit(_rune("water"))
	_ok("1 mojado otra vez conduce", Terreno3D.conductores.has(e.celda))
	_ok("1 hielo sobre el metal mojado: escarcha", e.reaccion_a(_rune("ice")) == "escarcha")
	e.on_spell_hit(_rune("ice"))
	_ok("1 con escarcha no conduce", not Terreno3D.conductores.has(e.celda))
	_avanzar(e, Reactivo3D.ESCARCHA_S + 0.2)
	_ok("1 pasada la escarcha vuelve a conducir lo que le quedara de agua", Terreno3D.conductores.has(e.celda))
	e.queue_free()
	_ok("1 la reja/emisor que sale del árbol no deja la corriente pasando", true)


func _congelable() -> void:
	var p: Reactivo3D = _pieza("puerta_goblin")
	_cuenta(p, "congelado_cambio")
	_ok("2 la puerta goblin es congelable y el hielo la congela", p.tiene_papel(Reactivo3D.P_CONGELABLE) and p.reaccion_a(_rune("ice")) == "congela" and p.spell_reacts(_rune("ice")))
	p.on_spell_hit(_rune("ice"))
	_ok("2 congelada: señal, no arde por contagio (can_burn) y no es la telaraña helada", p.esta_congelado() and not p.can_burn() and not p.helada and _vistas(p, "congelado_cambio") == [true])
	_ok("2 el agua o el viento no la tocan congelada", p.reaccion_a(_rune("water")) == "" and p.reaccion_a(_rune("wind")) == "" and not p.spell_reacts(_rune("water")))
	_ok("2 el calor la descongela (y no prende en el mismo golpe)", p.reaccion_a(_rune("fire")) == "derrite")
	p.on_spell_hit(_rune("fire"))
	_ok("2 descongelada, sana y sin arder; señal false", not p.esta_congelado() and p.estado == Reactivo3D.EstadoObj.SANO and _vistas(p, "congelado_cambio") == [true, false])
	p.on_spell_hit(_rune("fire"))
	_ok("2 el segundo fuego ya la prende", p.estado == Reactivo3D.EstadoObj.ARDIENDO)

	var p2: Reactivo3D = _pieza("puerta_goblin")
	p2.on_spell_hit(_rune("ice"))
	_avanzar(p2, Reactivo3D.CONGELADO_S - 0.5)
	_ok("2 sigue congelada a CONGELADO_S - 0,5 s", p2.esta_congelado())
	_avanzar(p2, 1.0)
	_ok("2 pasado CONGELADO_S se suelta sola y vuelve a arder", not p2.esta_congelado() and p2.can_burn())
	var t2: Reactivo3D = _pieza("torre_goblin")
	_ok("2 la torre goblin también es congelable", t2.reaccion_a(_rune("ice")) == "congela")
	_ok("2 pero una puerta ARDIENDO se apaga con el hielo, no se congela", _arde_y_hielo())

	var t: Reactivo3D = _pieza("totem", "agua")
	t.on_spell_hit(_rune("ice"))
	_ok("2 tótem de agua congelado: el agua no lo activa", t.esta_congelado() and t.reaccion_a(_rune("water")) == "" and not t.spell_reacts(_rune("water")))
	t.on_spell_hit(_rune("water"))
	_ok("2 (y de hecho no se activó)", not t.activo)
	_avanzar(t, Reactivo3D.CONGELADO_S + 0.2)
	_ok("2 descongelado, el agua vuelve a activarlo", t.reaccion_a(_rune("water")) == "activa")

	var a: Reactivo3D = _pieza("arbol")
	a.on_spell_hit(_rune("ice"))
	_ok("2 árbol congelado no se sacude", a.esta_congelado() and a.sacudir(5000.0) == [] and a.sacudidas == 0)
	a.on_spell_hit(_rune("fire"))
	a.sacudir(6000.0)
	_ok("2 descongelado por el fuego se sacude (sacudidas = 1)", not a.esta_congelado() and a.sacudidas == 1)

	var s: Reactivo3D = _pieza("seto")
	_ok("2 el seto NO es congelable: el hielo no le hace nada sano", s.reaccion_a(_rune("ice")) == "" and not s.spell_reacts(_rune("ice")))


func _arde_y_hielo() -> bool:
	var q: Reactivo3D = _pieza("puerta_goblin")
	q.on_spell_hit(_rune("fire"))
	return q.estado == Reactivo3D.EstadoObj.ARDIENDO and q.reaccion_a(_rune("ice")) == "apaga"


func _dosis() -> void:
	var s: Reactivo3D = _pieza("seto")
	s.mojable = true
	s.on_spell_hit(_rune("water"))
	_ok("3 seto mojado", s.esta_mojado() and not s.can_burn())
	_ok("3 el primer fuego dice «seca» (reacciona)", s.reaccion_a(_rune("fire")) == "seca" and s.spell_reacts(_rune("fire")))
	s.on_spell_hit(_rune("fire"))
	_ok("3 tras el primer fuego: seco y SIN arder", not s.esta_mojado() and s.estado == Reactivo3D.EstadoObj.SANO)
	s.on_spell_hit(_rune("fire"))
	_ok("3 el segundo fuego lo prende", s.estado == Reactivo3D.EstadoObj.ARDIENDO)

	var seco: Reactivo3D = _pieza("seto")
	seco.mojable = true
	seco.on_spell_hit(_rune("fire"))
	_ok("3 seto seco: prende al primero", seco.estado == Reactivo3D.EstadoObj.ARDIENDO)

	var otra: Reactivo3D = _pieza("seto")
	otra.mojable = true
	otra.on_spell_hit(_rune("water"))
	otra.on_spell_hit(_rune("fire"))
	otra.on_spell_hit(_rune("water"))
	otra.on_spell_hit(_rune("fire"))
	_ok("3 volver a mojarlo reinicia la dosis: otra vez no prende al segundo fuego seguido", otra.estado == Reactivo3D.EstadoObj.SANO)
	otra.on_spell_hit(_rune("fire"))
	_ok("3 y prende al siguiente", otra.estado == Reactivo3D.EstadoObj.ARDIENDO)

	var sin: Reactivo3D = _pieza("seto")
	sin.on_spell_hit(_rune("fire"))
	_ok("3 un seto sin `mojable` prende al primero como siempre", sin.estado == Reactivo3D.EstadoObj.ARDIENDO)


func _magma() -> void:
	var s: Reactivo3D = _pieza("seto")
	s.mojable = true
	s.on_spell_hit(_rune("water"))
	_ok("4 seto mojado: el magma dice «prende» (no «seca»)", s.esta_mojado() and s.reaccion_a(_rune("magma")) == "prende")
	s.on_spell_hit(_rune("magma"))
	_ok("4 el magma lo prende al primero aunque estuviera mojado", s.estado == Reactivo3D.EstadoObj.ARDIENDO and not s.esta_mojado())

	var seco: Reactivo3D = _pieza("tronco")
	seco.on_spell_hit(_rune("magma"))
	_ok("4 el magma prende lo seco también", seco.estado == Reactivo3D.EstadoObj.ARDIENDO)

	var m: Reactivo3D = _pieza("emisor_rayo", "rayo")
	m.papeles = PackedStringArray(["+activable"])
	_ok("4 metal activable: el magma lo calienta", m.material() == "metal" and m.reaccion_a(_rune("magma")) == "calienta")
	_ok("4 antes de calentarlo el rayo lo activa", m.reaccion_a(_rune("lightning")) == "activa")
	m.on_spell_hit(_rune("magma"))
	_ok("4 al rojo: el rayo no lo activa (no activable)", m.reaccion_a(_rune("lightning")) == "" and not m.spell_reacts(_rune("lightning")))
	_avanzar(m, Reactivo3D.CALIENTE_S - 0.5)
	_ok("4 a CALIENTE_S - 0,5 s sigue sin activarse", m.reaccion_a(_rune("lightning")) == "")
	_avanzar(m, 1.0)
	_ok("4 pasados 3 s se puede activar otra vez", m.reaccion_a(_rune("lightning")) == "activa")
	var f: Reactivo3D = _pieza("emisor_rayo", "rayo")
	f.papeles = PackedStringArray(["+activable"])
	_ok("4 el fuego normal NO calienta el metal (solo el magma)", f.reaccion_a(_rune("fire")) == "")


func _naturaleza() -> void:
	var t: Reactivo3D = _pieza("totem", "agua")
	_cuenta(t, "enredado_cambio")
	_ok("5 naturaleza enreda el tótem de agua (y no lo activa como si fuera agua)", t.reaccion_a(_rune("naturaleza")) == "enreda" and t.spell_reacts(_rune("naturaleza")))
	t.on_spell_hit(_rune("naturaleza"))
	_ok("5 enredado: señal true y sin activarse", t.esta_enredado() and not t.activo and _vistas(t, "enredado_cambio") == [true])
	_ok("5 enredado no reacciona al agua, al hielo ni a la naturaleza otra vez", t.reaccion_a(_rune("water")) == "" and t.reaccion_a(_rune("ice")) == "" and t.reaccion_a(_rune("naturaleza")) == "" and not t.spell_reacts(_rune("water")))
	_avanzar(t, Reactivo3D.ENREDADO_S - 0.5)
	_ok("5 sigue enredado a ENREDADO_S - 0,5 s", t.esta_enredado())
	_ok("5 el fuego lo libera", t.reaccion_a(_rune("fire")) == "libera")
	t.on_spell_hit(_rune("fire"))
	_ok("5 liberado: señal false, el agua lo activa de nuevo", not t.esta_enredado() and _vistas(t, "enredado_cambio") == [true, false] and t.reaccion_a(_rune("water")) == "activa")

	var t2: Reactivo3D = _pieza("totem", "agua")
	t2.on_spell_hit(_rune("naturaleza"))
	_avanzar(t2, Reactivo3D.ENREDADO_S + 0.2)
	_ok("5 el enredo se acaba solo pasado ENREDADO_S", not t2.esta_enredado())

	var a: Reactivo3D = _pieza("arbol")
	a.on_spell_hit(_rune("naturaleza"))
	_ok("5 árbol enredado no se sacude", a.esta_enredado() and a.sacudir(9000.0) == [] and a.sacudidas == 0)
	a.on_spell_hit(_rune("magma"))
	a.sacudir(9500.0)
	_ok("5 el magma (calor) también lo libera y se sacude", not a.esta_enredado() and a.sacudidas == 1)

	var ya: Reactivo3D = _pieza("totem", "fuego")
	ya.on_spell_hit(_rune("fire"))
	_ok("5 un tótem ya activado no se enreda", ya.activo and ya.reaccion_a(_rune("naturaleza")) == "")

	var s: Reactivo3D = _pieza("seto")
	_ok("5 el seto (ni activable ni sacudible) no se enreda: la naturaleza no cambia lo de siempre", s.reaccion_a(_rune("naturaleza")) == "")


func _cuerda() -> void:
	var base := Cuerda3D.new()
	base.preparar(Vector2i(2, 4))
	root.add_child(base)
	base.on_spell_hit(_rune("fire"))
	_avanzar(base, 1.2)
	_ok("6 base: la cuerda sin escarcha se rompe al arder T_ARDE", base.rota_ya)

	var c := Cuerda3D.new()
	c.preparar(Vector2i(3, 4))
	root.add_child(c)
	_ok("6 el hielo reacciona sobre la cuerda entera (rigida)", c.spell_reacts(_rune("ice")))
	c.on_spell_hit(_rune("ice"))
	_ok("6 cuerda helada: escarcha puesta", c._escarcha_s > 0.0)
	c.on_spell_hit(_rune("fire"))
	_ok("6 arde", c.estado == Cuerda3D.EstadoCuerda.ARDIENDO)
	_avanzar(c, 2.0)
	_ok("6 a los 2 s (más que T_ARDE) NO ha caído: sigue ardiendo con escarcha", c.estado == Cuerda3D.EstadoCuerda.ARDIENDO and not c.rota_ya)
	_avanzar(c, Reactivo3D.ESCARCHA_S - 2.0 - 0.3)
	_ok("6 un poco antes de acabar la escarcha todavía no cae", not c.rota_ya)
	_avanzar(c, 0.6)
	_ok("6 pasada la escarcha, si sigue ardiendo, cae", c.rota_ya)

	var d := Cuerda3D.new()
	d.preparar(Vector2i(4, 4))
	root.add_child(d)
	d.on_spell_hit(_rune("ice"))
	_avanzar(d, Reactivo3D.ESCARCHA_S + 0.2)
	d.on_spell_hit(_rune("fire"))
	_avanzar(d, 1.2)
	_ok("6 si el fuego llega DESPUÉS de la escarcha, cae como siempre", d.rota_ya)


## 8 hace_vapor: un recipiente (el surtidor) lleno + calor suelta vapor en su casilla y las 8 vecinas, sigue humeando VAPOR_MARCADOS veces y se queda vacío; vacío no hace nada.
func _vapor() -> void:
	var e: EstadosSuelo3D = Terreno3D.estados
	var s: Reactivo3D = _pieza("surtidor")
	var c: Vector2i = s.celda
	_ok("8 el surtidor lleva hace_vapor de serie", s.tiene_papel(Reactivo3D.P_HACE_VAPOR))
	_ok("8 vacío + calor: no reacciona ni deja vapor", s.reaccion_a(_rune("fire")) == "" and not s.spell_reacts(_rune("fire")))
	s.on_spell_hit(_rune("fire"))
	_ok("8 (y en efecto no hay vapor en su casilla)", not e.hay_vapor(c))
	s.on_spell_hit(_rune("water"))
	_ok("8 con agua + agua sigue siendo «brota» (llenar)", s.usado)
	_ok("8 lleno + calor: «vaporiza»", s.reaccion_a(_rune("fire")) == "vaporiza" and s.spell_reacts(_rune("fire")))
	_ok("8 lleno + agua no vaporiza (sigue siendo «brota»)", s.reaccion_a(_rune("water")) == "brota")
	s.on_spell_hit(_rune("fire"))
	var todas: bool = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			todas = todas and e.hay_vapor(c + Vector2i(dx, dy))
	_ok("8 deja vapor en su casilla y en las 8 de alrededor", todas)
	_ok("8 no se pasa de radio 1", not e.hay_vapor(c + Vector2i(2, 0)) and not e.hay_vapor(c + Vector2i(0, -2)))
	_ok("8 queda vacío: otro calor no hace nada", s.reaccion_a(_rune("fire")) == "")
	# La nube se sostiene: 3 marcados (0 · 1,5 · 3,0 s) y cada uno le da VAPOR_S (4 s) a las casillas
	var paso: float = 0.0
	var viva_hasta: float = 0.0
	while paso < 9.0:
		e.avanzar(0.1)
		s._process(0.1)
		paso += 0.1
		if e.hay_vapor(c):
			viva_hasta = paso
	var total: float = float(Reactivo3D.VAPOR_MARCADOS - 1) * Reactivo3D.VAPOR_INTERVALO_S + EstadosSuelo3D.VAPOR_S
	_ok("8 sigue humeando más allá de VAPOR_S (4 s): dura ~%.1f s (medido %.1f s)" % [total, viva_hasta], viva_hasta > EstadosSuelo3D.VAPOR_S + 2.0 and absf(viva_hasta - total) < 0.3)
	_ok("8 pasados los segundos no queda vapor en ninguna casilla", not e.hay_vapor(c) and not e.hay_vapor(c + Vector2i(1, 1)) and not e.hay_vapor(c + Vector2i(-1, -1)))
	_ok("8 respeta el tope de casillas vivas de vapor", Reactivo3D.VAPOR_MARCADOS >= 1 and 9 <= int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["vapor"]))
	s.on_spell_hit(_rune("water"))
	_ok("8 con agua vuelve a estar lleno y el calor lo vuelve a reventar", s.reaccion_a(_rune("fire")) == "vaporiza")
	s.on_spell_hit(_rune("fire"))
	_ok("8 segunda vez: vuelve a haber vapor", e.hay_vapor(c))
	var q: Reactivo3D = _pieza("surtidor")
	q.papeles = PackedStringArray(["-hace_vapor"])
	q.on_spell_hit(_rune("water"))
	_ok("8 con -hace_vapor un surtidor lleno no revienta con el calor", q.reaccion_a(_rune("fire")) == "")
	var w: Reactivo3D = _pieza("seto")
	w.papeles = PackedStringArray(["+hace_vapor"])
	_ok("8 +hace_vapor en otra pieza sin agua: el calor sigue prendiéndola", w.tiene_papel(Reactivo3D.P_HACE_VAPOR) and w.reaccion_a(_rune("fire")) == "prende")


## 9 el cuenco de piedra con agua (7/11, «mucho vapor»): nace lleno y con el agua a la vista; el calor la revienta (desaparece), deja la nube de 9 casillas ~9 s (más que el surtidor, con el mismo radio y bajo el tope),
## queda vacío y el agua lo vuelve a llenar; el fuego no lo quema (es piedra) y la vía del surtidor sigue igual.
func _cuenco() -> void:
	var e: EstadosSuelo3D = Terreno3D.estados
	_celda_n += 30                                  # lejos del vapor que dejó la prueba 8 (el surtidor, que aún humea)
	var k: Reactivo3D = _pieza("cuenco", "agua")
	var c: Vector2i = k.celda
	var avisos: Array = []
	k.activado.connect(func(t: String, el: String) -> void: avisos.append("%s/%s" % [t, el]))
	_ok("9 el cuenco lleva recibe_agua + hace_vapor (y nada de fuego) y es de piedra", k.tiene_papel(Reactivo3D.P_RECIBE_AGUA) and k.tiene_papel(Reactivo3D.P_HACE_VAPOR) and not k.tiene_papel(Reactivo3D.P_INFLAMABLE) and not k.tiene_papel(Reactivo3D.P_FUENTE_FUEGO) and k.material() == "piedra")
	_ok("9 tiene su modelo de cuenco (la pila de piedra, con escala) y no es la laja", k.visual is MeshInstance3D and (k.visual as MeshInstance3D).mesh != null and (k.visual as MeshInstance3D).scale.is_equal_approx(Vector3.ONE * Reactivo3D.CUENCO_ESCALA) and k.visual.name == "cuenco_piedra")
	_ok("9 NACE LLENO: el agua se ve antes del primer golpe", k._lleno_agua and k._agua_pila != null and k._agua_pila.visible)
	_ok("9 el agua cabe dentro del borde del cuenco", k._agua_pila.position.y < 0.38 * Reactivo3D.CUENCO_ESCALA and k._agua_pila.position.y > 0.11 * Reactivo3D.CUENCO_ESCALA and Reactivo3D.CUENCO_AGUA_RADIO < 0.45 * Reactivo3D.CUENCO_ESCALA)
	_ok("9 lleno + calor: «vaporiza»; + agua: «brota» (se puede volver a llenar)", k.reaccion_a(_rune("fire")) == "vaporiza" and k.spell_reacts(_rune("fire")) and k.reaccion_a(_rune("water")) == "brota")
	_ok("9 el fuego no lo prende, ni lo arde: sigue sano y fuera de lo que arde", k.estado == Reactivo3D.EstadoObj.SANO and not k.is_lit and not k.can_burn() and not k.is_in_group(Reactivo3D.GRUPO_ARDE))
	var antes_total: int = 0
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			antes_total += 1 if e.hay_vapor(c + Vector2i(dx, dy)) else 0
	_ok("9 antes del golpe no hay vapor alrededor", antes_total == 0)
	k.on_spell_hit(_rune("fire"))
	_ok("9 el fuego revienta el agua: DESAPARECE del cuenco y queda vacío", not k._lleno_agua and not k._agua_pila.visible and k.reaccion_a(_rune("fire")) == "" and not k.spell_reacts(_rune("fire")))
	_ok("9 y el cuenco sigue sano tras el fuego (no arde, no se consume)", k.estado == Reactivo3D.EstadoObj.SANO and not k.is_lit and is_instance_valid(k.visual))
	var dentro: int = 0
	var fuera: int = 0
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			if e.hay_vapor(c + Vector2i(dx, dy)):
				if absi(dx) <= 1 and absi(dy) <= 1:
					dentro += 1
				else:
					fuera += 1
	_ok("9 deja vapor en las 9 casillas (radio 1) y en ninguna más", dentro == 9 and fuera == 0, "dentro %d fuera %d" % [dentro, fuera])
	_ok("9 las 9 casillas caben en el tope de vapor (%d) con margen para el de la jugadora" % int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["vapor"]), 9 <= int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["vapor"]) - 10 and int(EstadosSuelo3D.MAX_CASILLAS_VIVAS["vapor"]) == 20)
	var paso: float = 0.0
	var viva_hasta: float = 0.0
	var max_vivas: int = 0
	while paso < 13.0:
		e.avanzar(0.1)
		k._process(0.1)
		paso += 0.1
		var n: int = 0
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				n += 1 if e.hay_vapor(c + Vector2i(dx, dy)) else 0
		max_vivas = maxi(max_vivas, n)
		if e.hay_vapor(c):
			viva_hasta = paso
	var total: float = float(Reactivo3D.VAPOR_CUENCO_MARCADOS - 1) * Reactivo3D.VAPOR_CUENCO_INTERVALO_S + EstadosSuelo3D.VAPOR_S
	var del_surtidor: float = float(Reactivo3D.VAPOR_MARCADOS - 1) * Reactivo3D.VAPOR_INTERVALO_S + EstadosSuelo3D.VAPOR_S
	_ok("9 la nube del cuenco dura ~%.1f s (medido %.1f s): entre 8,5 y 10,5 y más que la del surtidor (%.1f s)" % [total, viva_hasta, del_surtidor], absf(viva_hasta - total) < 0.3 and viva_hasta >= 8.5 and viva_hasta <= 10.5 and viva_hasta > del_surtidor + 1.0)
	_ok("9 el pico de casillas vivas es 9 (nunca más)", max_vivas == 9, str(max_vivas))
	_ok("9 pasado el tiempo no queda vapor", not e.hay_vapor(c) and not e.hay_vapor(c + Vector2i(1, 1)) and not e.hay_vapor(c + Vector2i(-1, -1)))
	k.on_spell_hit(_rune("fire"))
	_ok("9 vacío + otro calor: nada (ni vapor ni quemado)", not e.hay_vapor(c) and k.estado == Reactivo3D.EstadoObj.SANO and not k.is_lit)
	k.on_spell_hit(_rune("water"))
	_ok("9 con agua VUELVE: se ve el agua, está lleno y avisa «cuenco/agua» (no «surtidor»)", k._lleno_agua and k._agua_pila.visible and avisos == ["cuenco/agua"], str(avisos))
	_ok("9 lleno otra vez: el calor lo vuelve a reventar", k.reaccion_a(_rune("fire")) == "vaporiza")
	k.on_spell_hit(_rune("fire"))
	_ok("9 segunda vez: vuelve a haber vapor y vuelve a estar vacío", e.hay_vapor(c) and not k._lleno_agua and not k._agua_pila.visible)
	_ok("9 la vía del surtidor no cambió: 3 marcados cada 1,5 s (7 s)", Reactivo3D.VAPOR_MARCADOS == 3 and is_equal_approx(Reactivo3D.VAPOR_INTERVALO_S, 1.5) and is_equal_approx(del_surtidor, 7.0))
	var gorda: Array = Reactivo3D.VAPOR_POR_TIPO["cuenco"] as Array
	_ok("9 la bocanada del cuenco es más gorda que la de serie (escala, radio de emisión y cantidad mayores)", float(gorda[2]) > 1.0 and float(gorda[3]) > 0.4 and int(gorda[4]) > 8)
	_ok("9 el surtidor sigue con la bocanada de serie (sin fila en VAPOR_POR_TIPO)", not Reactivo3D.VAPOR_POR_TIPO.has("surtidor"))


func _datos() -> void:
	var mg: Dictionary = Materia.de(_rune("magma"))
	var na: Dictionary = Materia.de(_rune("naturaleza"))
	var hi: Dictionary = Materia.de(_rune("ice"))
	_ok("7 Materia.reaccion: magma prende_fuerte madera/vegetal/tela", Materia.reaccion(mg, "madera") == "prende_fuerte" and Materia.reaccion(mg, "vegetal", {"mojado": true}) == "prende_fuerte" and Materia.reaccion(mg, "tela") == "prende_fuerte")
	_ok("7 magma calienta metal y piedra (por la tabla de siempre)", Materia.reaccion(mg, "metal") == "calienta" and Materia.reaccion(mg, "piedra") == "calienta")
	_ok("7 naturaleza enreda (cristal no)", Materia.reaccion(na, "madera") == "enreda" and Materia.reaccion(na, "piedra") == "enreda" and Materia.reaccion(na, "cristal") == "")
	_ok("7 hielo sobre tela = rigida (lo que usa la cuerda); sobre metal la tabla sigue en \"\" y la escarcha la decide el Reactivo", Materia.reaccion(hi, "tela") == "rigida" and Materia.reaccion(hi, "metal") == "")
	_ok("7 el fuego normal no cambia: madera prende, metal calienta", Materia.reaccion(Materia.de(_rune("fire")), "madera") == "prende" and Materia.reaccion(Materia.de(_rune("fire")), "metal") == "calienta")
