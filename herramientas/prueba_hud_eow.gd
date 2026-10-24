extends SceneTree

## PRUEBA DEL HUD ESTILO ECHOES OF WISDOM (24/10, Juego), sin ventana. `tools\prueba_una.cmd prueba_hud_eow`.
## 1) Frascos de reserva de la tinta (nucleo/tinta.gd): gastar con la barra vacía vacía un frasco y la rellena, el tónico recarga, rellenar().
## 2) Los cuatro consumibles (nucleo/consumibles.gd) con sus números: poción, tónico de tinta, bálsamo protector, infusión de brezo.
## 3) El HUD (presentacion/ui/hud_eow.gd): Q usa el equipado, R pasa al siguiente, rótulos de vida y tinta.
## 4) El menú con pestañas (presentacion/ui/menu_pestanas.gd): abre en Inventario, cambia de pestaña, detalle del objeto elegido, equipar, Misiones.

var fallos: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


## Un jugador de mentira con lo que lee `Consumibles` / `HudEoW` (vida, muerto, bloqueado, tinta, mundo, lanz, curar, usar_pocion).
class JugadorFalso extends Node:
	var vida: float = 100.0
	var muerto: bool = false
	var bloqueado: bool = false
	var tinta: Tinta = null
	var mundo: Node = null
	var lanz: Node = null
	var bebidas: int = 0
	var puede_beber: bool = true

	func curar(c: float) -> void:
		vida = minf(Estado.i().vida_max, vida + c)

	func usar_pocion() -> bool:
		if not puede_beber:
			return false
		bebidas += 1
		return true


func _tecla(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev


func _init() -> void:
	_frascos()
	await _consumibles()
	await _hud()
	await _menu()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


## --- 1) Frascos ---
func _frascos() -> void:
	print("== Frascos de reserva")
	Estado.nuevo()
	var t := Tinta.new()
	t.partida = Estado.new()
	_ok(t.frascos == Tinta.FRASCOS_INICIALES and Tinta.FRASCOS_INICIALES == 3 and Tinta.FRASCOS_MAX == 3, "se empieza con 3 frascos llenos de 3")
	var gastados: Array = [0]
	t.frasco_gastado.connect(func() -> void: gastados[0] += 1)
	_ok(t.gastar("proyectil") and is_equal_approx(t.actual, 90.0) and t.frascos == 3, "con barra de sobra un gasto no toca los frascos (100 -> 90)")
	t.actual = 5.0
	_ok(t.puede_pagar("corro"), "con la barra a 5 y un frasco, una barrera (25) se puede pagar")
	_ok(t.gastar("corro") and t.frascos == 2 and is_equal_approx(t.actual, 75.0) and gastados[0] == 1, "no llegaba: se vacía UN frasco, la barra vuelve a 100 y se cobra 25 (queda 75, 2 frascos)")
	t.actual = 25.0
	_ok(t.gastar("corro") and t.frascos == 1 and is_equal_approx(t.actual, 100.0) and gastados[0] == 2, "un gasto que deja la barra en 0 gasta otro frasco y la rellena (100, 1 frasco)")
	t.actual = 0.0
	t.frascos = 0
	var avisos: Array = [0]
	t.insuficiente.connect(func(_f: String, _c: float, _h: float) -> void: avisos[0] += 1)
	_ok(not t.puede_pagar("proyectil") and not t.gastar("proyectil") and avisos[0] == 1 and is_equal_approx(t.actual, 0.0), "sin frascos y sin tinta no se paga, no se toca nada y avisa")
	t.frascos = 3
	_ok(not t.gastar("x", 150.0) and t.frascos == 3 and avisos[0] == 2, "un hechizo más caro que la barra entera no se paga ni con frasco (no se gasta ninguno en balde)")
	t.frascos = 0
	t.actual = 50.0
	_ok(t.recargar_frasco() == 1 and t.frascos == 1, "recargar_frasco() recarga 1 (el Tónico de tinta)")
	_ok(t.recargar_frasco(5) == 2 and t.frascos == 3, "recargar de más se queda en el máximo y devuelve los que entraron")
	_ok(t.recargar_frasco() == 0, "con todos llenos no recarga nada")
	t.frascos = 0
	t.actual = 10.0
	t.rellenar_barra()
	_ok(is_equal_approx(t.actual, 100.0) and t.frascos == 0, "rellenar_barra() solo llena la barra")
	t.actual = 10.0
	t.rellenar()
	_ok(is_equal_approx(t.actual, 100.0) and t.frascos == 3, "rellenar() (fuente, descanso, reaparecer) llena la barra y los frascos")
	t.frascos = 2
	t.actual = 100.0
	for _i in range(int(Tinta.REGEN * 60.0)):
		t.actualizar(1.0 / 60.0, false)
	_ok(t.frascos == 2, "los frascos vacíos NO se recargan solos")
	# Viajan con la partida: la Tinta nueva (otra sala) los recoge del Estado.
	Estado.nuevo()
	var t1 := Tinta.new()
	t1.actual = 0.0
	t1.gastar("corro")
	_ok(Estado.i().frascos_tinta == 2 and Tinta.new().frascos == 2, "los frascos viajan con la partida (Estado.frascos_tinta): una Tinta nueva empieza con los que quedaban")


## --- 2) Consumibles ---
func _consumibles() -> void:
	print("== Los cuatro consumibles")
	Estado.nuevo()
	var e: Estado = Estado.i()
	for id in ["pocion", "tonico_tinta", "balsamo_protector", "infusion_brezo"]:
		_ok(Objetos.existe(id) and Objetos.es_consumible(id) and Objetos.categoria(id) == "pociones" and not Objetos.es_ingrediente(id), "%s existe como consumible de la categoría pociones" % id)
		_ok(not Objetos.usos(id).is_empty() and not Objetos.efecto(id).is_empty(), "%s lleva usos y efecto en Objetos" % id)
	_ok(is_equal_approx(float(Objetos.efecto("pocion")["cura"]), 40.0) and int(Objetos.efecto("tonico_tinta")["frascos"]) == 1 \
		and is_equal_approx(float(Objetos.efecto("balsamo_protector")["dura"]), 20.0) \
		and is_equal_approx(float(Objetos.efecto("infusion_brezo")["tasa"]), 3.0) and is_equal_approx(float(Objetos.efecto("infusion_brezo")["dura"]), 12.0), "valores: poción 40 · tónico 1 frasco · bálsamo 20 s · infusión 3/s durante 12 s")
	var j := JugadorFalso.new()
	root.add_child(j)
	j.tinta = Tinta.new()
	j.tinta.partida = Estado.new()
	var c := Consumibles.new()
	c.jugador = j
	var avisos: Array = []
	c.aviso.connect(func(txt: String, _col: Color) -> void: avisos.append(txt))
	_ok(c.equipado() == "" and c.disponibles().is_empty() and not c.usar_equipado() and avisos.size() == 1, "sin consumibles no hay equipado y Q avisa")
	e.agregar("pocion", 2)
	e.agregar("tonico_tinta", 1)
	e.agregar("balsamo_protector", 1)
	e.agregar("infusion_brezo", 1)
	c.al_cambiar_mochila()
	_ok(c.equipado() == "pocion" and c.disponibles() == ["pocion", "tonico_tinta", "balsamo_protector", "infusion_brezo"], "al tener consumibles se equipa el primero (la poción)")
	var orden: Array = []
	for _i in range(5):
		orden.append(c.siguiente())
	_ok(orden == ["tonico_tinta", "balsamo_protector", "infusion_brezo", "pocion", "tonico_tinta"], "R recorre los que tienes y da la vuelta: %s" % str(orden))
	_ok(c.equipar("pocion") and not c.equipar("seta") and not c.equipar("nada"), "equipar solo acepta consumibles que tengas")

	# Poción: la bebe el jugador (animación propia); aquí solo se decide si se puede.
	j.vida = 60.0
	_ok(c.usar("pocion") and j.bebidas == 1, "poción con vida a medias: manda beber al jugador")
	j.puede_beber = false
	_ok(not c.usar("pocion") and j.bebidas == 1, "si el jugador no puede beber (ocupado) no pasa nada")
	j.puede_beber = true
	j.vida = 100.0
	_ok(c.motivo_no("pocion") == "Ya tienes la vida llena" and not c.usar("pocion") and j.bebidas == 1 and e.cuenta("pocion") == 2, "con la vida llena no se bebe y no se gasta")

	# Tónico: recarga UN frasco; con todos llenos no se gasta.
	_ok(not c.usar("tonico_tinta") and e.cuenta("tonico_tinta") == 1, "tónico con los frascos llenos: no se gasta")
	j.tinta.frascos = 1
	_ok(c.usar("tonico_tinta") and j.tinta.frascos == 2 and e.cuenta("tonico_tinta") == 0, "tónico: +1 frasco (1 -> 2) y se gasta la unidad")
	_ok(c.equipado() != "tonico_tinta", "al acabarse el equipado pasa solo a otro consumible (%s)" % c.equipado())

	# Bálsamo: absorbe el próximo golpe, caduca a los 20 s.
	_ok(c.usar("balsamo_protector") and c.escudo_activo() and is_equal_approx(c.escudo_t, 20.0) and e.cuenta("balsamo_protector") == 0, "bálsamo: escudo de 20 s y se gasta la unidad")
	_ok(not c.absorber(0.0) and c.escudo_activo(), "un golpe de 0 no consume el escudo")
	_ok(c.absorber(30.0) and not c.escudo_activo(), "el primer golpe lo absorbe entero y el escudo se acaba")
	_ok(not c.absorber(30.0), "el segundo golpe ya no se absorbe")
	e.agregar("balsamo_protector", 2)
	c.usar("balsamo_protector")
	for _i in range(int(19.0 * 60.0)):
		c.actualizar(1.0 / 60.0)
	_ok(c.escudo_activo() and c.escudo_t < 1.5, "a los 19 s al bálsamo le queda ~1 s (%.2f)" % c.escudo_t)
	for _i in range(120):
		c.actualizar(1.0 / 60.0)
	_ok(not c.escudo_activo() and not c.absorber(30.0), "a los 20 s caduca y ya no absorbe")
	_ok(c.usar("balsamo_protector") and c.escudo_activo(), "(con otro bálsamo se puede volver a poner)")
	e.agregar("balsamo_protector", 1)
	c.escudo_t = 5.0
	_ok(c.motivo_no("balsamo_protector") == "Ya llevas el bálsamo puesto", "con el bálsamo puesto no se pone otro encima")
	c.escudo_t = 0.0

	# Infusión: 3 de vida por segundo durante 12 s = 36.
	j.vida = 100.0
	_ok(c.motivo_no("infusion_brezo") == "Ya tienes la vida llena", "infusión con la vida llena: no se gasta")
	j.vida = 40.0
	_ok(c.usar("infusion_brezo") and c.regen_activa() and e.cuenta("infusion_brezo") == 0, "infusión: empieza a regenerar y se gasta la unidad")
	for _i in range(int(6.0 * 60.0)):
		c.actualizar(1.0 / 60.0)
	_ok(absf(j.vida - (40.0 + 18.0)) < 1.6, "a los 6 s lleva ~+18 de vida (%.1f)" % j.vida)
	for _i in range(int(7.0 * 60.0)):
		c.actualizar(1.0 / 60.0)
	_ok(not c.regen_activa() and absf(j.vida - 76.0) < 0.6, "a los 12 s acaba con +36 en total (%.1f)" % j.vida)
	j.vida = 90.0
	e.agregar("infusion_brezo", 1)
	c.usar("infusion_brezo")
	for _i in range(int(13.0 * 60.0)):
		c.actualizar(1.0 / 60.0)
	_ok(is_equal_approx(j.vida, 100.0), "la infusión no pasa de la vida máxima (%.1f)" % j.vida)
	j.free()


## --- 3) HUD: Q y R ---
func _hud() -> void:
	print("== HUD: Q usa, R cambia")
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.agregar("tonico_tinta", 2)
	e.agregar("balsamo_protector", 1)
	var j := JugadorFalso.new()
	root.add_child(j)
	j.tinta = Tinta.new()
	j.tinta.partida = Estado.new()
	j.vida = 50.0
	var hud := HudEoW.new()
	hud.jugador = j
	root.add_child(hud)
	await process_frame
	_ok(hud.consumibles.equipado() == "tonico_tinta", "el HUD equipa al montarse el primero que haya (%s)" % hud.consumibles.equipado())
	_ok(hud._vida.rotulo == "Vida 50/100" and is_equal_approx(hud._vida.fraccion, 0.5), "la barra de vida dice «%s»" % hud._vida.rotulo)
	_ok(hud._tinta.rotulo.begins_with("Tinta 100/100") and hud._frascos.llenos == 3, "tinta «%s» y 3 frascos llenos" % hud._tinta.rotulo)
	j.tinta.frascos = 1
	j.tinta.actual = 40.0
	await process_frame
	_ok(hud._frascos.llenos == 1 and hud._tinta.rotulo.begins_with("Tinta 40/100"), "al gastar frascos y tinta el HUD se actualiza (%d frascos, «%s»)" % [hud._frascos.llenos, hud._tinta.rotulo])
	hud._input(_tecla(KEY_Q))
	_ok(j.tinta.frascos == 2 and e.cuenta("tonico_tinta") == 1, "Q usa el equipado: el tónico recarga un frasco")
	hud._input(_tecla(KEY_R))
	_ok(hud.consumibles.equipado() == "balsamo_protector", "R pasa al siguiente que tengas (bálsamo)")
	hud._input(_tecla(KEY_R))
	_ok(hud.consumibles.equipado() == "tonico_tinta", "R da la vuelta")
	hud._input(_tecla(KEY_Q))
	_ok(j.tinta.frascos == 3 and e.cuenta("tonico_tinta") == 0 and hud.consumibles.equipado() == "balsamo_protector", "Q otra vez: el último tónico; el equipado pasa solo al bálsamo")
	paused = true
	hud._input(_tecla(KEY_Q))
	_ok(e.cuenta("balsamo_protector") == 1 and not hud.consumibles.escudo_activo(), "con el juego en pausa (menú abierto) Q no hace nada")
	paused = false
	j.bloqueado = true
	hud._input(_tecla(KEY_Q))
	_ok(e.cuenta("balsamo_protector") == 1, "con el jugador bloqueado Q no hace nada")
	j.bloqueado = false
	hud._input(_tecla(KEY_Q))
	_ok(hud.consumibles.escudo_activo() and e.cuenta("balsamo_protector") == 0, "Q con el bálsamo equipado lo activa")
	await process_frame
	_ok(hud._circulo != null and hud.consumibles.equipado() == "balsamo_protector", "el círculo del HUD existe y muestra el equipado")
	hud.queue_free()
	j.free()
	await process_frame


## --- 4) Menú ---
func _menu() -> void:
	print("== Menú con pestañas")
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.oro = 137
	e.agregar("seta", 3)
	e.agregar("pocion", 2)
	e.agregar("nucleo_eco", 1)
	e.agregar("lavanda", 1)
	var M: Misiones = Misiones.nuevo()
	M.definir({"id": "a", "titulo": "Las cuatro tareas", "tipo": "principal", "texto": "El guardabosques pide ayuda.", "origen": "Guardabosques", "objetivos": ["Pisar la baldosa", "Hablar"]})
	M.activar("a")
	var m := MenuPestanas.new()
	root.add_child(m)
	await process_frame
	_ok(not m.abierta and not paused, "cerrado no pausa")
	m.abrir()
	await process_frame
	_ok(m.abierta and paused and m.pestana == 0 and m.pestana_id() == "inventario", "abrir pausa el mundo y abre en Inventario")
	var ids: Array = []
	for p in m.pilas():
		ids.append(p[0])
	_ok(ids == ["lavanda", "nucleo_eco", "seta", "pocion"], "la rejilla va en orden de categoría y nombre: %s" % str(ids))
	_ok(m._huecos.size() == 20 and m.hueco(0).id == "lavanda" and m.hueco(0).cantidad == 1 and m.hueco(2).cantidad == 3, "20 huecos, cada uno con su objeto y su contador")
	var bloq: int = 0
	for h in m._huecos:
		if (h as BolsaUI.Hueco).bloqueado:
			bloq += 1
	_ok(bloq == 12, "con capacidad 8, 12 huecos salen bloqueados (%d)" % bloq)
	_ok(m.hueco(1).calidad == "epico" and m.hueco(0).calidad == "comun", "cada hueco lleva el marco de su calidad (el núcleo de eco, épico)")
	var d: Dictionary = m.detalle()
	_ok(m.elegido() == 0 and d["id"] == "lavanda" and d["nombre"] == "Lavanda" and d["tipo"] == "Material común" and d["cantidad"] == 1, "el detalle del primero: %s · %s" % [d["nombre"], d["tipo"]])
	_ok((d["usos"] as Array).size() == 2 and String(d["desc"]) != "", "el detalle lleva descripción y «Usos conocidos» (%d)" % (d["usos"] as Array).size())
	m.mover(Vector2.RIGHT)
	d = m.detalle()
	_ok(m.elegido() == 1 and d["id"] == "nucleo_eco" and d["tipo"] == "Material épico", "→ elige el siguiente y el detalle cambia: %s · %s" % [d["nombre"], d["tipo"]])
	m.mover(Vector2.LEFT)
	m.mover(Vector2.LEFT)
	_ok(m.elegido() == 0, "← en el borde no se sale")
	m.mover(Vector2.DOWN)
	_ok(m.elegido() == 3 or m.elegido() == 0, "↓ con una sola fila de objetos no se pierde (%d)" % m.elegido())
	m._elegir(2)
	m.mover(Vector2.RIGHT)
	_ok(m.elegido() == 3 and m.detalle()["tipo"] == "Consumible", "la poción es «Consumible»")
	_ok(not bool(m.detalle()["equipado"]) and e.consumible_equipado == "", "antes de equiparla no lo está")
	m.accion()
	await process_frame
	_ok(e.consumible_equipado == "pocion" and bool(m.detalle()["equipado"]), "Enter sobre un consumible lo equipa (y el detalle lo dice)")
	var sin_uso: Dictionary = {}
	e.agregar("baya", 1)
	await process_frame
	for i in range(m.pilas().size()):
		if String(m.pilas()[i][0]) == "baya":
			m._elegir(i)
	sin_uso = m.detalle()
	_ok(String(sin_uso["id"]) == "baya" and not (sin_uso["usos"] as Array).is_empty(), "al llegar un objeto la rejilla se recoloca y se puede elegir")
	# Pestañas
	m.cambiar_pestana(1)
	_ok(m.pestana_id() == "grimorio" and not m.funcional(1) and m._pag_prox.visible and not m._pag_inv.visible, "pestaña 2 = Grimorio con su «Próximamente»")
	for i in [2, 3, 5]:
		m.cambiar_pestana(i)
		_ok(not m.funcional(i) and m._pag_prox.visible and String(MenuPestanas.PESTANAS[i]["prox"]) != "", "pestaña %s = «Próximamente» con su texto" % m.pestana_id())
	m.cambiar_pestana(MenuPestanas.INDICE_MISIONES)
	_ok(m.pestana_id() == "misiones" and m.funcional(4) and m._pag_mis.visible and not m._pag_prox.visible, "Misiones es funcional y enseña su página")
	_ok(m._diario.filas().size() == 1 and m._diario.seleccionada == "a" and m._diario.ficha("a")["titulo"] == "Las cuatro tareas", "la lista y la ficha son las del diario de misiones")
	m.cambiar_pestana(0)
	m.siguiente_pestana(-1)
	_ok(m.pestana_id() == "ajustes", "Q desde la primera da la vuelta a la última")
	m.siguiente_pestana(1)
	_ok(m.pestana_id() == "inventario", "E desde la última vuelve a la primera")
	# Teclas
	m._input(_tecla(KEY_E))
	_ok(m.pestana_id() == "grimorio", "la tecla E pasa a la pestaña siguiente")
	m._input(_tecla(KEY_Q))
	m._input(_tecla(KEY_Q))
	_ok(m.pestana_id() == "ajustes", "la tecla Q vuelve a la anterior")
	m._input(_tecla(KEY_J))
	_ok(m.abierta and m.pestana_id() == "misiones", "J con el menú abierto salta a Misiones")
	m._input(_tecla(KEY_I))
	_ok(m.abierta and m.pestana_id() == "inventario", "I con el menú en otra pestaña vuelve a Inventario")
	m._input(_tecla(KEY_ESCAPE))
	await process_frame
	_ok(not m.abierta and not paused, "Esc cierra y reanuda el mundo")
	m._input(_tecla(KEY_J))
	await process_frame
	_ok(m.abierta and m.pestana_id() == "misiones" and paused, "J cerrado abre el menú en Misiones")
	m.cerrar()
	m._input(_tecla(KEY_I))
	await process_frame
	_ok(m.abierta and m.pestana_id() == "inventario", "I cerrado abre el menú en Inventario")
	m.cerrar()
	await process_frame
	_ok(not paused, "cerrar reanuda")
	m.queue_free()
	await process_frame
