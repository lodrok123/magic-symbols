extends "res://herramientas/escenario_base.gd"
## BLOQUE B, lado del ENEMIGO y fuego amigo (6/11/2026; docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloque B y §6.2). Sobre la escena real del Bosque, con enemigos reales (`Combate3D`):
##   B1 · ROTO: congelado + tierra, viento, rayo o golpe F = daño ×`Dano.X_ROTO`, se acaba el hielo y cae; con rayo, metralla al vecino a ≤ 2,5 u (el arco del mojado llega a 4,5);
##        aviso `roto` (+20 de tinta una vez por enemigo) y la previsión dice «rompe_x2».
##   B2 · LLAMARADA: el viento sobre quien arde prende al vecino más cercano en el cono de ±45° a ≤ 2,5 u (no al de detrás ni al de más lejos) y refresca la quemadura;
##        CEGADO: el agua sobre quien arde lo apaga y lo ciega 2 s (`_ve` falla: no persigue); la previsión dice «llamarada» y «ciega».
##   B7 · FUEGO AMIGO: la llama de tu propio fuego te quita `DANO_PROPIO_POR_TIC` por tic pasada la gracia (`GRACIA_PROPIA_S`), con `FUEGO_AMIGO = false` nada, y el rayo sobre el agua que pisas también.
##   + `Jugador3D.aplicar_estado` (agua, hielo, fuego, rayo, tierra) y que el limo lo encuentra.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bloque_b_enemigo.gd

const FILA: int = 33
var _creados: Array = []
var _avisos_vistos: Array = []          ## [nombre, nodo] de cada `Mundo3D.reaccion`


func _c(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _h(archivo: String, glifos: Dictionary = {}) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), glifos)


## Un goblin quieto, con vida de sobra, sin debilidad ni resistencia, en `p`.
func _goblin(p: Vector3) -> Combate3D:
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0)
	g.debil = ""
	g.resiste = ""
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
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()
	_avisos_vistos.clear()
	await avanzar(2)                        # que los queue_free hayan salido del grupo antes de crear nada nuevo (si no, el arco o la llamarada los toman por vecinos)


func _n_aviso(nombre: String, nodo: Node = null) -> int:
	var n: int = 0
	for a in _avisos_vistos:
		if a[0] == nombre and (nodo == null or a[1] == nodo):
			n += 1
	return n


func _jugadora(c: Vector2i) -> Jugador3D:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 1000.0
	j._t_inv = 0.0
	j._empuje = Vector3.ZERO
	j._t_est_vel = 0.0
	j._t_quemada = 0.0
	return j


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


func _lanzar(datos: Dictionary, dir: Vector3, origen: Vector3 = Vector3.INF) -> bool:
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(datos, jugador.position if origen == Vector3.INF else origen, dir)


## Todas las reacciones que la previsión dice para `g` con lo preparado (vacío si no hay entrada).
func _previstas(datos: Dictionary, g: Combate3D, dir: Vector3) -> Array:
	for e in PrevisionHechizo.prever(lanzador, datos, jugador.position, dir):
		if e["nodo"] == g:
			return (e["extra"] as Dictionary)["reacciones"]
	return []


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(20)
	if Mundo3D.actual != null:
		Mundo3D.actual.reaccion.connect(func(n: String, _p: Vector3, nodo: Node) -> void: _avisos_vistos.append([n, nodo]))
	_constantes()
	await _b1_roto()
	await _b1_viento_real()
	await _b1_golpe_f()
	await _b1_metralla()
	await _b1_tinta()
	await _b1_prevision()
	await _b2_llamarada()
	await _b2_cegado()
	await _b2_prevision()
	await _b7_fuego_amigo()
	_b7_rayo()
	await _estados()
	await _limpiar()


func _constantes() -> void:
	_ok("0 las constantes del encargo", _c(Dano.X_ROTO, 2.0) and _c(Combate3D.METRALLA_ALCANCE, 2.5) and _c(Combate3D.LLAMARADA_ALCANCE, 2.5) and _c(Combate3D.LLAMARADA_SEMIANGULO, 45.0)
		and _c(Combate3D.CEGADO_S, 2.0) and _c(HechizoVivo.DANO_PROPIO_POR_TIC, 2.0) and _c(HechizoVivo.GRACIA_PROPIA_S, 0.6) and HechizoVivo.FUEGO_AMIGO)
	_ok("0 los avisos están en el catálogo y en el del Pipeline", Mundo3D.REACCIONES.has("roto") and Mundo3D.REACCIONES.has("llamarada") and Mundo3D.REACCIONES.has("cegado")
		and ReaccionesVfx3D.CATALOGO.has("roto") and ReaccionesVfx3D.CATALOGO.has("llamarada") and ReaccionesVfx3D.CATALOGO.has("cegado"))
	_ok("0 roto y llamarada son reacciones premiadas; cegado no", Tinta.REACCIONES_PREMIADAS.has("roto") and Tinta.REACCIONES_PREMIADAS.has("llamarada") and not Tinta.REACCIONES_PREMIADAS.has("cegado"))


# ---------------------------------------------------------------------------------------------------------------- B1

func _b1_roto() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	for par in [["earth", "tierra"], ["wind", "viento"]]:
		var h: Hechizo = _h(par[0])
		var g: Combate3D = _goblin(base)
		var gemelo: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
		gemelo.congelado = 0.0
		var dir := Vector3(1, 0, 0)
		var normal: float = float(gemelo.decidir_golpe(h)["dano"])
		g.congelado = 3.0
		var esperado: float = Dano.aplicar(h.dano, h.potencia, Dano.X_ROTO, g.multiplicador(h.elemento), g.defensa)
		var dec: Dictionary = g.decidir_golpe(h)
		_ok("1 %s sobre congelado: decide ×2 (%.2f, esperado %.2f)" % [par[1], float(dec["dano"]), esperado], _c(float(dec["dano"]), esperado) and bool(dec["roto"]) and float(dec["congelado"]) == 0.0)
		_ok("1 %s: el roto hace más que el golpe sin congelar (%.2f > %.2f)" % [par[1], float(dec["dano"]), normal], float(dec["dano"]) > normal)
		_ok("1 %s: el aviso del golpe lleva «roto»" % par[1], (dec["avisos"] as Array).has(Mundo3D.R_ROTO))
		var v0: float = g.health
		_avisos_vistos.clear()
		g.golpe(h, dir)
		_ok("1 %s: se quita el congelado y quita el daño decidido" % par[1], g.congelado <= 0.0 and _c(v0 - g.health, float(dec["dano"])), "congelado %.1f · quitó %.2f" % [g.congelado, v0 - g.health])
		_ok("1 %s: avisa «roto» una vez" % par[1], _n_aviso("roto", g) == 1)
		await avanzar_s(0.2)
		if par[0] == "earth":     # el empuje del viento lo da `Lanzador3D._golpear` antes del golpe: se mide con un lanzamiento real en `_b1_viento_real`
			_ok("1 %s: cae (se mueve empujado o está en el clip de caer)" % par[1], g.en_empujado() or g._empuje.length() > 0.1 or g.position.distance_to(base) > 0.05, "empuje %.2f" % g._empuje.length())
		# Sin congelar no hay roto ni aviso.
		var s: Combate3D = _goblin(base + Vector3(0, 0, 6.0))
		s.golpe(h, dir)
		_ok("1 %s sobre uno sin congelar: ni roto ni aviso" % par[1], _n_aviso("roto", s) == 0)
		await _limpiar()
	# Rayo sobre congelado Y mojado: el remate manda (×2, no ×2 × ×1,5).
	var hr: Hechizo = _h("lightning")
	var gm: Combate3D = _goblin(base)
	gm.congelado = 3.0
	gm.mojado = 3.0
	var dm: Dictionary = gm.decidir_golpe(hr)
	_ok("1 rayo sobre congelado y mojado: ×2 y no se apila con el ×1,5 del mojado", _c(float(dm["dano"]), Dano.aplicar(hr.dano, hr.potencia, Dano.X_ROTO, 1.0, gm.defensa)) and bool(dm["roto"]))
	# El hielo sobre congelado no rompe (lo congela otra vez) y el fuego tampoco.
	var gh: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	gh.congelado = 3.0
	_ok("1 hielo y agua sobre congelado no lo rompen", not bool(gh.decidir_golpe(_h("ice"))["roto"]) and not bool(gh.decidir_golpe(_h("water"))["roto"]))
	await _limpiar()


## El viento de verdad: lanzado por el camino real sobre un congelado lo rompe (×2, sin hielo) y lo tira hacia atrás.
func _b1_viento_real() -> void:
	var g: Combate3D = _goblin(_pos(Vector2i(10, FILA)))
	g.congelado = 5.0
	var antes: Vector3 = g.position
	var v0: float = g.health
	_avisos_vistos.clear()
	var d: Dictionary = _preparar(Vector2i(12, FILA), "viento", ["flecha"])
	_lanzar(d, Vector3(-1, 0, 0))
	var t: float = 0.0
	while g.congelado > 0.0 and t < 3.0:         # hasta que le llegue el soplo
		t += await avanzar_s(1.0 / 30.0)
	await avanzar_s(0.8)                          # y un rato más para verlo caer
	_ok("1 viento lanzado de verdad sobre un congelado: se rompe (congelado %.1f), pierde vida (%.2f) y avisa «roto» (%d)" % [g.congelado, v0 - g.health, _n_aviso("roto", g)],
		g.congelado <= 0.0 and g.health < v0 and _n_aviso("roto", g) == 1)
	_ok("1 y cae: se ha movido %.2f u hacia atrás" % g.position.distance_to(antes), g.position.distance_to(antes) > 0.1 and g.position.x < antes.x)
	await _limpiar()


func _b1_golpe_f() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var g: Combate3D = _goblin(base)
	var gemelo: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	var dir := Vector3(1, 0, 0)
	var normal: Dictionary = gemelo.recibir_golpe_cuerpo(dir, 5.0, 5000.0)
	g.congelado = 3.0
	_avisos_vistos.clear()
	var r: Dictionary = g.recibir_golpe_cuerpo(dir, 5.0, 5000.0)
	var esperado: float = Dano.tras_defensa(5.0 * Dano.X_ROTO, g.defensa)
	_ok("1 golpe F sobre congelado: ×2 (%.2f, esperado %.2f; sin congelar %.2f)" % [float(r["dano"]), esperado, float(normal["dano"])], bool(r["roto"]) and _c(float(r["dano"]), esperado) and float(r["dano"]) > float(normal["dano"]))
	_ok("1 golpe F: se acaba el hielo, avisa «roto» una vez y sale despedido", g.congelado <= 0.0 and _n_aviso("roto", g) == 1 and float(r["v0"]) > 0.0)
	_ok("1 golpe F sin congelar: roto false", not bool(normal["roto"]))
	await _limpiar()


func _b1_metralla() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var h: Hechizo = _h("lightning")
	var dir := Vector3(1, 0, 0)
	# Vecino a 2,0 u: recibe la metralla (mitad del daño roto).
	var g: Combate3D = _goblin(base)
	var cerca: Combate3D = _goblin(base + Vector3(0, 0, 2.0))
	g.congelado = 3.0
	var v0: float = cerca.health
	var dec: Dictionary = g.decidir_golpe(h)
	g.golpe(h, dir)
	var metralla: float = v0 - cerca.health
	_ok("1 rayo sobre congelado: metralla al vecino a 2 u (%.2f = mitad del daño roto sin defensa)" % metralla, bool(dec["arco"]) and _c(float(dec["alcance_arco"]), 2.5) and metralla > 0.0 and _c(metralla, float(dec["base"]) * 0.5), "base %.2f" % float(dec["base"]))
	await _limpiar()
	# Vecino a 3,0 u: fuera de la metralla (el arco del mojado, 4,5 u, sí lo alcanzaría).
	var g2: Combate3D = _goblin(base)
	var lejos: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	g2.congelado = 3.0
	var v1: float = lejos.health
	g2.golpe(h, dir)
	_ok("1 la metralla no llega a 3 u", _c(lejos.health, v1))
	await _limpiar()
	var g3: Combate3D = _goblin(base)
	var lejos2: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	g3.mojado = 3.0
	var v2: float = lejos2.health
	g3.golpe(h, dir)
	_ok("1 (control) el arco del rayo sobre mojado sí llega a 3 u: sigue siendo de 4,5", lejos2.health < v2)
	await _limpiar()


func _b1_tinta() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var tinta: Tinta = lanzador.tinta
	var h: Hechizo = _h("earth")
	var g: Combate3D = _goblin(base)
	var otro: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	tinta.actual = 0.0
	g.congelado = 3.0
	g.golpe(h, Vector3(1, 0, 0))
	_ok("1 tinta: romper un congelado da +20 (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	g.congelado = 3.0
	g.golpe(h, Vector3(1, 0, 0))
	_ok("1 tinta: romper al MISMO enemigo otra vez no da más (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	otro.congelado = 3.0
	otro.golpe(h, Vector3(1, 0, 0))
	_ok("1 tinta: a OTRO enemigo sí (%.1f)" % tinta.actual, _c(tinta.actual, 40.0))
	await _limpiar()


func _b1_prevision() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var g: Combate3D = _goblin(base)
	g.congelado = 3.0
	var h: Hechizo = _h("earth")
	var pg: Dictionary = g.prever_golpe(h, Vector3(1, 0, 0))
	_ok("1 prever_golpe de tierra sobre congelado lleva el aviso «roto»", (pg["avisos"] as Array).has(Mundo3D.R_ROTO))
	var d: Dictionary = _preparar(Vector2i(12, FILA), "tierra", ["flecha"])
	g.position = _pos(Vector2i(10, FILA))                       # como el limo: disparo al oeste desde 2 casillas (el este de la fila no es seguro que esté libre)
	var rs: Array = _previstas(d, g, Vector3(-1, 0, 0))
	_ok("1 la previsión del indicador dice «rompe_x2» (%s)" % str(rs), rs.has("rompe_x2") and rs[0] == "rompe_x2")
	_ok("1 y esa reacción tiene rótulo «Rompe ×2» y color", PrevisionReaccion3D.ESTILO.has("rompe_x2") and String((PrevisionReaccion3D.ESTILO["rompe_x2"] as Array)[0]) == "Rompe ×2")
	var prior: PackedStringArray = PrevisionHechizo.PRIORIDAD_ENEMIGO
	_ok("1 «rompe_x2» va justo tras «electrocuta» en la prioridad", prior.find("rompe_x2") == prior.find("electrocuta") + 1)
	_ok("1 FeedbackReaccion3D tiene su familia", FeedbackReaccion3D.FAMILIAS.has("roto") and PrevisionReaccion3D.ESTILO.has(String((FeedbackReaccion3D.FAMILIAS["roto"] as Array)[0])))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- B2

func _b2_llamarada() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var viento := Vector3(1, 0, 0)
	var h: Hechizo = _h("wind")
	var a: Combate3D = _goblin(base)
	var delante: Combate3D = _goblin(base + Vector3(2.0, 0, 0))
	var mas_cerca_fuera_cono: Combate3D = _goblin(base + Vector3(0, 0, 1.5))        # a 90° del viento: más cerca que el de delante, pero fuera del cono
	var detras: Combate3D = _goblin(base + Vector3(-1.5, 0, 0))
	var lejos: Combate3D = _goblin(base + Vector3(2.6, 0, 0.6))                     # en el cono pero a > 2,5 u... y detrás del de delante
	a.quemando = 1.0
	var tinta: Tinta = lanzador.tinta
	tinta.actual = 0.0
	_avisos_vistos.clear()
	a.golpe(h, viento)
	_ok("2 llamarada: el vecino de delante (a 2 u, en el cono) prende", delante.quemando > 0.0, "quemando %.2f" % delante.quemando)
	_ok("2 con la misma quemadura que lleva (refrescada al mínimo %.1f s): %.2f" % [Combate3D.LLAMARADA_QUEMA_MIN, delante.quemando], delante.quemando >= Combate3D.LLAMARADA_QUEMA_MIN - 0.01)
	_ok("2 y el que sopla refresca la suya (%.2f)" % a.quemando, a.quemando >= Combate3D.LLAMARADA_QUEMA_MIN - 0.1)
	_ok("2 el de al lado (fuera del cono, aunque más cerca) no prende", mas_cerca_fuera_cono.quemando <= 0.0)
	_ok("2 el de detrás no prende", detras.quemando <= 0.0)
	_ok("2 avisa «llamarada» una vez en el que arde", _n_aviso("llamarada", a) == 1)
	_ok("2 tinta +20 por la llamarada (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	a.quemando = 1.0
	delante.quemando = 0.0
	a.golpe(h, viento)
	_ok("2 la tinta de la llamarada se da una vez por enemigo (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	await _limpiar()
	# Fuera de alcance (3 u) o sin vecino: nada de llamarada, y el viento sigue interrumpiendo como siempre.
	var b: Combate3D = _goblin(base)
	var lejano: Combate3D = _goblin(base + Vector3(3.0, 0, 0))
	b.quemando = 2.0
	_avisos_vistos.clear()
	b.golpe(h, viento)
	_ok("2 a 3 u no hay llamarada: ni contagio ni aviso", lejano.quemando <= 0.0 and _n_aviso("llamarada") == 0)
	_ok("2 sin llamarada el viento interrumpe como siempre", b.interrupcion > 0.0)
	await _limpiar()
	# Un vecino mojado no prende (vapor, no fuego) y se salta al siguiente que sí.
	var c: Combate3D = _goblin(base)
	var mojado: Combate3D = _goblin(base + Vector3(1.0, 0, 0))
	var seco: Combate3D = _goblin(base + Vector3(2.0, 0, 0))
	mojado.mojado = 3.0
	c.quemando = 2.0
	c.golpe(h, viento)
	_ok("2 el vecino mojado no prende y la llamarada salta al siguiente", mojado.quemando <= 0.0 and seco.quemando > 0.0)
	await _limpiar()
	# Viento sobre quien NO arde: nada.
	var d: Combate3D = _goblin(base)
	var e: Combate3D = _goblin(base + Vector3(2.0, 0, 0))
	_avisos_vistos.clear()
	d.golpe(h, viento)
	_ok("2 viento sobre quien no arde: sin llamarada", e.quemando <= 0.0 and _n_aviso("llamarada") == 0)
	await _limpiar()


func _b2_cegado() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var tinta: Tinta = lanzador.tinta
	var h: Hechizo = _h("water")
	var a: Combate3D = _goblin(base)
	a.quemando = 3.0
	_avisos_vistos.clear()
	tinta.actual = 0.0
	a.golpe(h, Vector3(1, 0, 0))
	_ok("2 agua sobre quien arde: lo apaga", a.quemando <= 0.0 and _n_aviso("apagado_agua", a) == 1)
	_ok("2 y lo ciega %.1f s (%.2f)" % [Combate3D.CEGADO_S, a.cegado], _c(a.cegado, Combate3D.CEGADO_S) and _n_aviso("cegado", a) == 1)
	_ok("2 el apagado da +20 y el cegado nada más (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	var b: Combate3D = _goblin(base + Vector3(0, 0, 3.0))
	b.golpe(h, Vector3(1, 0, 0))
	_ok("2 agua sobre quien NO arde: no ciega", b.cegado <= 0.0)
	await _limpiar()
	# Su IA: ciego no ve a la jugadora (ni persigue); pasados los 2 s, sí.
	var j: Jugador3D = _jugadora(Vector2i(11, FILA))
	var c: Combate3D = _goblin(j.position + Vector3(3.5, 0, 0))
	c.quieto = false
	_ok("2 (control) sin cegar, a 3,5 u ve a la jugadora", c._ve(Combate3D.RADIO_DETECCION))
	c.cegado = Combate3D.CEGADO_S                         # a mano: el golpe de agua además lo empuja y lo deja en el clip de caer (sin IA); aquí se mide solo el reloj
	_ok("2 cegado: no ve a la jugadora", not c._ve(Combate3D.RADIO_DETECCION) and not c._ve(Combate3D.RADIO_SOLTAR))
	c.objetivo = null
	c.estado = "patrulla"
	var persiguio: bool = false
	var t: float = 0.0
	while t < Combate3D.CEGADO_S - 0.3:
		t += await avanzar_s(1.0 / 30.0)
		if c.estado == "persigue" or c.objetivo != null:
			persiguio = true
	_ok("2 mientras dura no persigue (estado «%s»)" % c.estado, not persiguio)
	await avanzar_s(0.8)
	_ok("2 pasados los %.0f s vuelve a verla y la persigue (estado «%s»)" % [Combate3D.CEGADO_S, c.estado], c.cegado <= 0.0 and c.estado == "persigue")
	await _limpiar()
	# Uno que ya persigue y se queda ciego la pierde (vuelve a «busca»).
	var j2: Jugador3D = _jugadora(Vector2i(11, FILA))
	var d: Combate3D = _goblin(j2.position + Vector3(3.5, 0, 0))
	d.quieto = false
	await avanzar_s(0.5)
	var perseguia: bool = d.estado == "persigue"
	d.cegado = Combate3D.CEGADO_S
	await avanzar_s(0.3)
	_ok("2 si ya la perseguía y se queda ciego, la pierde: «%s» → «%s»" % ["persigue" if perseguia else d.estado, d.estado], perseguia and d.estado == "busca")
	await _limpiar()


func _b2_prevision() -> void:
	var base: Vector3 = _pos(Vector2i(14, FILA))
	var a: Combate3D = _goblin(base)
	a.quemando = 3.0
	var vecino: Combate3D = _goblin(base + Vector3(2.0, 0, 0))
	var dir := Vector3(1, 0, 0)
	var pw: Dictionary = a.prever_golpe(_h("wind"), dir)
	_ok("2 prever_golpe del viento sobre quien arde lleva «llamarada»", (pw["avisos"] as Array).has(Mundo3D.R_LLAMARADA))
	var pa: Dictionary = a.prever_golpe(_h("water"), dir)
	_ok("2 prever_golpe del agua sobre quien arde lleva «apagado_agua» y «cegado»", (pa["avisos"] as Array).has(Mundo3D.R_APAGADO_AGUA) and (pa["avisos"] as Array).has(Mundo3D.R_CEGADO))
	_ok("2 la previsión no ha aplicado nada (el vecino no arde y el que arde sigue ardiendo, sin ciego)", vecino.quemando <= 0.0 and a.quemando > 0.0 and a.cegado <= 0.0)
	var oeste := Vector3(-1, 0, 0)
	var d: Dictionary = _preparar(Vector2i(12, FILA), "viento", ["flecha"])
	a.position = _pos(Vector2i(10, FILA))
	vecino.position = a.position + Vector3(-2.0, 0, 0)
	var rs: Array = _previstas(d, a, oeste)
	_ok("2 la previsión del indicador dice «llamarada» (%s)" % str(rs), rs.has("llamarada"))
	var d2: Dictionary = _preparar(Vector2i(12, FILA), "agua", ["flecha"])
	var rs2: Array = _previstas(d2, a, oeste)
	_ok("2 la previsión del indicador dice «apaga» y «ciega» (%s)" % str(rs2), rs2.has("apaga") and rs2.has("ciega"))
	_ok("2 ESTILO y FAMILIAS de llamarada y ciega", PrevisionReaccion3D.ESTILO.has("llamarada") and PrevisionReaccion3D.ESTILO.has("ciega") and FeedbackReaccion3D.FAMILIAS.has("llamarada") and FeedbackReaccion3D.FAMILIAS.has("cegado"))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- B7

func _b7_fuego_amigo() -> void:
	for con_fuego_amigo in [true, false]:
		HechizoVivo.FUEGO_AMIGO = con_fuego_amigo
		await _limpiar()
		await avanzar(5)
		var j: Jugador3D = _jugadora(Vector2i(12, FILA))
		var d: Dictionary = _preparar(Vector2i(12, FILA), "fuego", ["barrera"])
		var lanzo: bool = _lanzar(d, Vector3(-1, 0, 0), j.position)
		_ok("7 [fuego amigo %s] se levanta la barrera de fuego sobre ella" % str(con_fuego_amigo), lanzo and not lanzador._zonas_v2.is_empty())
		var vida_ant: float = j.vida
		var primera: float = -1.0
		var bajadas: Array = []
		var t: float = 0.0
		while t < 2.0:
			t += await avanzar_s(1.0 / 30.0)
			if j.vida < vida_ant - 0.0001:
				bajadas.append(snappedf(vida_ant - j.vida, 0.01))
				if primera < 0.0:
					primera = t
			vida_ant = j.vida
		var tic: float = Dano.tras_defensa(HechizoVivo.DANO_PROPIO_POR_TIC, j.defensa_total())
		if con_fuego_amigo:
			var todas_iguales: bool = not bajadas.is_empty()
			for b in bajadas:
				if absf(float(b) - tic) > 0.02:
					todas_iguales = false
			_ok("7 la jugadora en su propia llama pierde %.1f por tic (bajadas %s)" % [tic, str(bajadas)], todas_iguales and bajadas.size() >= 3)
			_ok("7 sin daño durante la gracia (primera bajada a los %.2f s ≥ %.1f)" % [primera, HechizoVivo.GRACIA_PROPIA_S], primera >= HechizoVivo.GRACIA_PROPIA_S - 0.001)
			var avisada: bool = false
			for z in lanzador._zonas_v2:
				if is_instance_valid(z) and (z as Lanzador3D.ZonaV2).avisada_jugadora:
					avisada = true
			_ok("7 el «¡Te quemas!» sale una vez por zona (marcada)", avisada)
		else:
			_ok("7 con FUEGO_AMIGO = false no pierde nada (bajadas %s)" % str(bajadas), bajadas.is_empty() and j.vida >= 1000.0 - 0.0001)
	HechizoVivo.FUEGO_AMIGO = true
	# Invulnerable (voltereta): la atraviesa.
	await _limpiar()
	await avanzar(5)
	var j2: Jugador3D = _jugadora(Vector2i(12, FILA))
	var d3: Dictionary = _preparar(Vector2i(12, FILA), "fuego", ["barrera"])
	_lanzar(d3, Vector3(-1, 0, 0), j2.position)
	var v0: float = j2.vida
	var t2: float = 0.0
	while t2 < 1.5:
		j2._t_inv = 1.0
		t2 += await avanzar_s(1.0 / 30.0)
	_ok("7 invulnerable (voltereta) no pierde nada", _c(j2.vida, v0))
	# `dano_ambiental` no empuja ni corta el gesto.
	j2._t_inv = 0.0
	j2._empuje = Vector3.ZERO
	j2._t_gesto = 0.5
	var quito: float = j2.dano_ambiental(2.0, "fuego")
	_ok("7 dano_ambiental quita sin empujar ni cortar el gesto", quito > 0.0 and j2._empuje.length() < 0.001 and j2._t_gesto > 0.0)
	await _limpiar()


func _b7_rayo() -> void:
	HechizoVivo.FUEGO_AMIGO = true
	var j: Jugador3D = _jugadora(Vector2i(12, FILA))
	var celdas: Dictionary = {Terreno3D.celda_de(j.position): true}
	var v0: float = j.vida
	var pronto: float = HechizoVivo.golpe_propio(lanzador, celdas, "rayo", 0.3)
	_ok("7 rayo: dentro de la gracia no te llega", pronto == 0.0 and _c(j.vida, v0))
	var q: float = HechizoVivo.golpe_propio(lanzador, celdas, "rayo", 1.0)
	_ok("7 rayo sobre el agua que pisas: te quita %.1f pasada la gracia" % q, _c(q, Dano.tras_defensa(HechizoVivo.DANO_PROPIO_POR_TIC, j.defensa_total())) and _c(v0 - j.vida, q))
	var fuera: float = HechizoVivo.golpe_propio(lanzador, {Vector2i(1, 1): true}, "rayo", 1.0)
	_ok("7 rayo en un agua que no pisas: nada", fuera == 0.0)
	HechizoVivo.FUEGO_AMIGO = false
	var apagado: float = HechizoVivo.golpe_propio(lanzador, celdas, "rayo", 1.0)
	HechizoVivo.FUEGO_AMIGO = true
	_ok("7 rayo con FUEGO_AMIGO = false: nada", apagado == 0.0)


# ---------------------------------------------------------------------------------------------------------------- aplicar_estado

func _estados() -> void:
	var j: Jugador3D = _jugadora(Vector2i(12, FILA))
	_ok("E la jugadora tiene aplicar_estado", j.has_method("aplicar_estado") and j.has_method("dano_ambiental"))
	_ok("E agua → mojada, velocidad ×0,8", j.aplicar_estado("agua", 3.0) == "mojada" and _c(j.mult_velocidad_estado(), 0.8))
	j._estados_paso(3.1)
	_ok("E y se acaba: velocidad ×1", _c(j.mult_velocidad_estado(), 1.0))
	_ok("E hielo → ralentizada, velocidad ×0,5", j.aplicar_estado("hielo", 3.0) == "ralentizada" and _c(j.mult_velocidad_estado(), 0.5))
	j._estados_paso(3.1)
	_ok("E rayo → aturdida ×0,3 y solo %.1f s (no los 3 s del limo)" % Jugador3D.RAYO_ATURDE_S, j.aplicar_estado("rayo", 3.0) == "aturdida" and _c(j.mult_velocidad_estado(), 0.3))
	j._estados_paso(Jugador3D.RAYO_ATURDE_S + 0.05)
	_ok("E la descarga pasa en %.1f s" % Jugador3D.RAYO_ATURDE_S, _c(j.mult_velocidad_estado(), 1.0))
	_ok("E mojada y ralentizada a la vez: manda el más lento", j.aplicar_estado("agua", 3.0) == "mojada" and j.aplicar_estado("hielo", 3.0) == "ralentizada" and _c(j.mult_velocidad_estado(), 0.5))
	j._estados_paso(3.1)
	j.vida = 100.0
	_ok("E fuego → quemada", j.aplicar_estado("fuego", 2.0) == "quemada" and j.esta_quemada())
	var antes: float = j.vida
	var tics: int = 0
	for _i in range(4):
		var v: float = j.vida
		j._estados_paso(Jugador3D.QUEMADA_TICK)
		if j.vida < v:
			tics += 1
	var tic: float = Dano.tras_defensa(Jugador3D.QUEMADA_DANO, j.defensa_total())
	_ok("E la quemada quita %.1f cada %.1f s (4 tics: %.1f → %.1f)" % [tic, Jugador3D.QUEMADA_TICK, antes, j.vida], tics == 4 and _c(antes - j.vida, tic * 4.0))
	_ok("E y se acaba tras sus 2 s", not j.esta_quemada())
	j.aplicar_estado("fuego", 5.0)
	j.aplicar_estado("agua", 3.0)
	_ok("E el agua apaga la quemada", not j.esta_quemada())
	j._estados_paso(5.0)
	_ok("E tierra y viento no dejan estado", j.aplicar_estado("tierra", 3.0) == "" and j.aplicar_estado("viento", 3.0) == "" and _c(j.mult_velocidad_estado(), 1.0))
	j.vida = 1.5
	j.aplicar_estado("fuego", 2.0)
	j._estados_paso(Jugador3D.QUEMADA_TICK)
	j._estados_paso(Jugador3D.QUEMADA_TICK)
	_ok("E la quemada no la mata (queda en %.1f)" % j.vida, j.vida >= 1.0 - 0.0001 and not j.muerto)
	j.vida = 1000.0
	j._t_quemada = 0.0
	# El limo la encuentra.
	var limo: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(14, FILA)), "agua", false)
	limo.quieto = true
	_creados.append(limo)
	var r: String = limo._elemento_a_la_jugadora()
	_ok("E el limo de agua encuentra aplicar_estado y devuelve «estado» (%s) · velocidad ×%.2f" % [r, j.mult_velocidad_estado()], r == "estado" and _c(j.mult_velocidad_estado(), 0.8))
	j._t_est_vel = 0.0
	await _limpiar()
