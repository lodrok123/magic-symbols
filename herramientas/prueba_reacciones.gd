extends SceneTree
## A4 de docs/PLAN_EOW.md (21/10, Juego): SEÑALES DE REACCIÓN CON NOMBRE. `Mundo3D.reaccion(nombre, punto, nodo)` + catálogo cerrado `Mundo3D.REACCIONES`.
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reacciones.gd
## Lo que comprueba:
##   0. Sin Mundo3D en el árbol, `Mundo3D.avisar_reaccion` no hace nada ni falla. El catálogo es el mismo que espera el Pipeline (ReaccionesVfx3D.CATALOGO).
##   1. Cada reacción de A1–A3 se emite UNA vez por cambio real, con su nodo y un punto (se cuentan las emisiones; seguir pasando fotogramas no las repite):
##      Reactivo3D: prendido, apagado_agua, consumido, mojado, secado (y la fogata: prendido / apagado_agua).
##      Combate3D: prendido, apagado_agua, consumido (se acaba la quemadura y muere ardiendo), mojado, secado, congelado, derretido, electrocutado, aturdido,
##      empujado, hundido (y el aviso `impacto` «hundido» sigue saliendo: conviven).
##   2. Un nombre fuera del catálogo NO se emite (y avisa con push_warning, que sale como «at: push_warning» en la consola; un script no puede capturarlo).
## NO se emiten hoy (no existen en la lógica): apagado_viento (el viento no apaga, lleva la llama), derretido/congelado/electrocutado en Reactivo3D. «bloqueado» lo emite Escudo3D (A5) y se prueba en prueba_escudo.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const COL_AGUA: Array = [6, 7]
const Y_FILAS: Array = [3, 4, 5, 6, 7, 8]

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fx: Vfx3D = null
var _fallos: int = 0
var _emitidas: Array = []        ## [nombre, punto, nodo] de cada Mundo3D.reaccion
var _impactos: Array = []        ## [punto, elemento, radio] de cada Mundo3D.impacto


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_sin_mundo()
	_montar()
	_catalogo()
	_reactivos()
	_enemigos()
	await _hundimiento()
	_fuera_de_catalogo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			if borde:
				f += "#"
				bloq[Vector2i(x, y)] = true
			elif COL_AGUA.has(x) and Y_FILAS.has(y):
				f += "~"
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.reaccion.connect(func(n: String, p: Vector3, nd: Node) -> void: _emitidas.append([n, p, nd]))
	_mundo.impacto.connect(func(p: Vector3, el: String, r: float) -> void: _impactos.append([p, el, r]))
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 12.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


func _objeto(tipo: String, cx: int, cz: int, papeles: Array = []) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.preparar(tipo, Vector2i(cx, cz), "", _fx, null)
	r.position = _suelo(cx, cz)
	if not papeles.is_empty():
		r.papeles = PackedStringArray(papeles)
	_mundo.add_child(r)
	return r


func _goblin(p: Vector3) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0                         # el agua pega ×2 a un goblin (su debilidad): que los golpes de la prueba no lo maten
	g.vida_max = 100000.0
	return g


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		if is_instance_valid(g):
			g._physics_process(DT)


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


func _runa(tags: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for g in tags:
		t.append(String(g))
	r.tags = t
	return r


## Cuántas veces se emitió `nombre` desde `nodo`.
func _n(nombre: String, nodo: Node) -> int:
	var c: int = 0
	for e in _emitidas:
		if e[0] == nombre and e[2] == nodo:
			c += 1
	return c


## Cuántas emisiones hubo de ese nodo en total (para ver que no se cuela ninguna de más).
func _total(nodo: Node) -> int:
	var c: int = 0
	for e in _emitidas:
		if e[2] == nodo:
			c += 1
	return c


# ---------------------------------------------------------------------------------------------------------------------

func _sin_mundo() -> void:
	_ok("0 sin Mundo3D en el árbol, Mundo3D.actual es null", Mundo3D.actual == null)
	Mundo3D.avisar_reaccion("prendido", Vector3.ZERO, null)           # no debe fallar ni hacer nada
	_ok("0 y avisar_reaccion sin mundo no falla", true)


func _catalogo() -> void:
	_ok("0 con mundo en el árbol, Mundo3D.actual es él", Mundo3D.actual == _mundo)
	var igual: bool = Mundo3D.REACCIONES.size() == ReaccionesVfx3D.CATALOGO.size()
	for i in range(mini(Mundo3D.REACCIONES.size(), ReaccionesVfx3D.CATALOGO.size())):
		if Mundo3D.REACCIONES[i] != ReaccionesVfx3D.CATALOGO[i]:
			igual = false
	_ok("0 el catálogo del Juego es el de la tabla del Pipeline, mismo orden", igual, str(Mundo3D.REACCIONES))
	_ok("0 el Pipeline puede engancharse a la señal (conectar devuelve true)", ReaccionesVfx3D.conectar(_mundo, _fx))
	_emitidas.clear()
	Mundo3D.avisar_reaccion("prendido", Vector3(1, 2, 3), null)
	_ok("0 avisar_reaccion con mundo emite con los tres argumentos", _emitidas.size() == 1 and _emitidas[0][0] == "prendido" and _emitidas[0][1] == Vector3(1, 2, 3) and _emitidas[0][2] == null)


func _reactivos() -> void:
	_emitidas.clear()
	# Un seto: prende, lo apaga el agua, vuelve a prender y se consume.
	var seto := _objeto("seto", 2, 2)
	seto.on_spell_hit(_runa(["calor", "fuego"]))
	_ok("1 seto: prender emite «prendido» una vez", _n("prendido", seto) == 1 and _total(seto) == 1, str(_total(seto)))
	seto._process(0.1)
	seto._process(0.1)
	_ok("1 seto: seguir ardiendo no repite el aviso", _n("prendido", seto) == 1 and _total(seto) == 1)
	seto.on_spell_hit(_runa(["agua", "frio"]))
	_ok("1 seto: el agua lo apaga y emite «apagado_agua» una vez", _n("apagado_agua", seto) == 1 and _total(seto) == 2, str(_emitidas))
	seto.on_spell_hit(_runa(["calor"]))
	seto._process(1000.0)
	_ok("1 seto: arde hasta el final y emite «consumido» una vez", _n("consumido", seto) == 1 and _n("prendido", seto) == 2, str(_emitidas))
	var punto_ok: bool = true
	for e in _emitidas:
		if e[2] == seto and (e[1] as Vector3).distance_to(seto.global_position) > 2.0:
			punto_ok = false
	_ok("1 el punto del aviso está en la pieza", punto_ok)

	# Un seto mojable: el agua lo moja (una vez aunque se riegue dos) y al pasar el tiempo se seca.
	var humedo := _objeto("seto", 4, 2, ["mojable"])
	humedo.on_spell_hit(_runa(["agua"]))
	humedo.on_spell_hit(_runa(["agua"]))
	_ok("1 seto mojable: «mojado» una vez, aunque se riegue dos", _n("mojado", humedo) == 1 and _total(humedo) == 1, str(_total(humedo)))
	humedo._process(Reactivo3D.T_MOJADO + 1.0)
	humedo._process(1.0)
	_ok("1 seto mojable: al pasar T_MOJADO emite «secado» una vez", _n("secado", humedo) == 1 and _total(humedo) == 2, str(_total(humedo)))

	# Una fogata: se enciende con calor y se apaga con frío.
	var fogata := _objeto("fogata", 8, 2)
	fogata.on_spell_hit(_runa(["calor"]))
	_ok("1 fogata: encenderla emite «prendido»", _n("prendido", fogata) == 1 and _total(fogata) == 1)
	fogata.on_spell_hit(_runa(["agua"]))
	_ok("1 fogata: el agua la apaga y emite «apagado_agua»", _n("apagado_agua", fogata) == 1 and _total(fogata) == 2)
	fogata.on_spell_hit(_runa(["calor"]))
	fogata.apagar_llama()
	_ok("1 fogata: apagarla por regla (sin elemento) emite «consumido», no agua", _n("consumido", fogata) == 1 and _n("apagado_agua", fogata) == 1)


func _enemigos() -> void:
	_emitidas.clear()
	# Fuego, luego agua: prende, deja de arder.
	var g := _goblin(_suelo(2, 6))
	g.golpe(_h("fire"), Vector3.ZERO)
	_pasos(g, 30)
	_ok("1 goblin: fuego emite «prendido» una vez (y no se repite al pasar fotogramas)", _n("prendido", g) == 1 and _total(g) == 1, str(_emitidas))
	g.golpe(_h("water"), Vector3.ZERO)
	_ok("1 goblin: el agua que lo apaga emite «apagado_agua» una vez y «mojado» una vez", _n("apagado_agua", g) == 1 and _n("mojado", g) == 1, str(_emitidas))
	g.golpe(_h("fire"), Vector3.ZERO)
	_ok("1 goblin: fuego sobre mojado = vapor: «secado» (y no prende)", _n("secado", g) == 1 and _n("prendido", g) == 1, str(_emitidas))

	# Se le acaba la quemadura: consumido (corta las llamas del cuerpo).
	var h := _goblin(_suelo(3, 6))
	h.quemando = 0.1
	_pasos(h, 20)
	_ok("1 goblin: se acaba la quemadura -> «consumido» una vez", _n("consumido", h) == 1 and _total(h) == 1, str(_emitidas))

	# Muere ardiendo: consumido una sola vez (la muerte y el fin del fuego no se duplican).
	var m := _goblin(_suelo(4, 6))
	m.quemando = 5.0
	m.receive_damage(m.health + 1.0)
	_pasos(m, 5)
	_ok("1 goblin: muere ardiendo -> «consumido» una vez", _n("consumido", m) == 1 and m.muerto, str(_emitidas))

	# Contacto con una llama (A2): también avisa, una vez.
	var c := _goblin(_suelo(5, 6))
	c.prender_por_contacto()
	c.prender_por_contacto()
	_ok("1 goblin: prender por contacto emite «prendido» una vez (la segunda no es un cambio)", _n("prendido", c) == 1, str(_n("prendido", c)))

	# Mojar y secarse.
	var a := _goblin(_suelo(2, 8))
	a.golpe(_h("water"), Vector3.ZERO)
	a.golpe(_h("water"), Vector3.ZERO)
	_ok("1 goblin: agua emite «mojado» una vez aunque le llegue dos veces", _n("mojado", a) == 1 and _total(a) == 1, str(_total(a)))
	a.mojado = 0.05
	_pasos(a, 10)
	_ok("1 goblin: al pasar el tiempo emite «secado» una vez", _n("secado", a) == 1, str(_emitidas))

	# Congelar y derretirse.
	var f := _goblin(_suelo(3, 8))
	f.golpe(_h("ice"), Vector3.ZERO)
	_pasos(f, 5)
	_ok("1 goblin: hielo emite «congelado» una vez", _n("congelado", f) == 1, str(_emitidas))
	f.congelado = 0.05
	_pasos(f, 10)
	_ok("1 goblin: al descongelarse emite «derretido» una vez", _n("derretido", f) == 1, str(_emitidas))

	# Rayo: electrocutado + aturdido (el rayo aturde). Un segundo rayo: otra descarga, pero el aturdimiento ya estaba.
	var r := _goblin(_suelo(4, 8))
	r.golpe(_h("lightning"), Vector3.ZERO)
	_ok("1 goblin: rayo emite «electrocutado» una vez", _n("electrocutado", r) == 1, str(_emitidas))
	_ok("1 goblin: y «aturdido» una vez", _n("aturdido", r) == 1, str(_emitidas))
	r.golpe(_h("lightning"), Vector3.ZERO)
	_ok("1 goblin: un segundo rayo es otra descarga, pero NO otro aturdimiento", _n("electrocutado", r) == 2 and _n("aturdido", r) == 1, str(_emitidas))

	# Empujón.
	var e := _goblin(_suelo(5, 8))
	e.push(Vector3(0, 0, 1), 200.0, true)
	_pasos(e, 40)
	_ok("1 goblin: un empujón emite «empujado» una vez (no por fotograma)", _n("empujado", e) == 1 and _total(e) == 1, str(_total(e)))


func _hundimiento() -> void:
	_emitidas.clear()
	_impactos.clear()
	var g := _goblin(Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S))
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g, 120)
	var hundido: Array = []
	for em in _emitidas:
		if em[0] == "hundido" and em[2] == g:
			hundido.append(em)
	_ok("1 goblin empujado al agua honda: «hundido» una vez", g.muerto and g.se_hundio and hundido.size() == 1, str(_emitidas))
	var en_agua: bool = hundido.size() == 1 and Terreno3D.es_agua(Terreno3D.celda_de(hundido[0][1])) and absf((hundido[0][1] as Vector3).y - Terreno3D.alto_agua) < 0.01
	_ok("1 y el punto es la superficie del agua", en_agua, str(hundido))
	var aviso_impacto: bool = false
	for a in _impactos:
		if a[1] == "hundido":
			aviso_impacto = true
	_ok("1 el aviso antiguo Mundo3D.impacto(«hundido») sigue saliendo (conviven)", aviso_impacto)
	_ok("1 y antes del hundimiento empujó: «empujado» una vez", _n("empujado", g) == 1, str(_n("empujado", g)))
	await process_frame


func _fuera_de_catalogo() -> void:
	_emitidas.clear()
	Mundo3D.avisar_reaccion("explotado", Vector3.ZERO, null)           # debe salir un «at: push_warning» en la consola
	_ok("2 un nombre fuera del catálogo no se emite", _emitidas.is_empty(), str(_emitidas))
	_ok("2 «explotado» no está en el catálogo y «bloqueado» sí", not Mundo3D.REACCIONES.has("explotado") and Mundo3D.REACCIONES.has("bloqueado"))
