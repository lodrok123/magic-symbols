extends "res://herramientas/escenario_base.gd"
## R3 · REACCIONES CON EL ENTORNO, lado del ENEMIGO y de los CRUCES (6/11/2026; docs/REACCIONES_ENTORNO_2026-11-06.md §1.5, §1.6 y §2 «R3 enemigo y cruces»). Sobre la escena real del Bosque, con goblins reales:
##   · MAGMA: quema (como el fuego) + `lento` MAGMA_LENTO_S; sobre congelado lo derrite SIN «roto» (y sin el ×X_ROTO).
##   · NATURALEZA: además del veneno de la runa, ENRAIZADO (ENRAIZADO_S, ×2 si está mojado): no se mueve ni se deja empujar, sigue atacando y viendo; el fuego y el magma lo liberan; quien ya arde no se
##     enraíza; el elemental (vegetal) y el gólem (piedra) son inmunes. Aviso `enraizado` (+20 de tinta una vez por enemigo) y la previsión dice «enraiza» / «derrite».
##   · CRUCES: magma × agua = vapor + costra (escombro) en la casilla, el proyectil se gasta, aviso `apagado_agua`.
##   · `_descarga`: el rayo no electrifica más de MAX_NODOS_DESCARGA casillas conectadas fuera de su volumen (un lago entero no).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reacciones_entorno_enemigo.gd

const DT: float = 1.0 / 30.0
const ESTE := Vector3(1, 0, 0)

var _creados: Array = []
var _avisos_vistos: Array = []          ## [nombre, nodo] de cada `Mundo3D.reaccion`
var _libre: Vector2i = Vector2i.ZERO
var _libro_previo: String = ""


func _c(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _pos(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _h(archivo: String, glifos: Dictionary = {}) -> Hechizo:
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


## Un goblin quieto, con vida de sobra, sin debilidad ni resistencia, en la casilla `c` (más un `desvio` en metros, para no estar siempre en el centro).
func _goblin(c: Vector2i, desvio: Vector3 = Vector3.ZERO) -> Combate3D:
	var p: Vector3 = _pos(c) + desvio
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


func _zona(elemento: String, celdas: Array, en_cruce: bool) -> Lanzador3D.ZonaV2:
	var z := Lanzador3D.ZonaV2.new()
	z.lanz = lanzador
	z.elemento = elemento
	z.vida = 60.0
	for c in celdas:
		z.celdas[c] = true
	lanzador.mundo.add_child(z)
	(lanzador.zonas_cruce if en_cruce else lanzador._zonas_v2).append(z)
	z.tree_exited.connect(HechizoVivo._olvidar.bind(weakref(lanzador), z))
	_creados.append(z)
	return z


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	for lista in [lanzador._zonas_v2, lanzador.zonas_cruce, lanzador._solideces_v2]:
		for z in (lista as Array).duplicate():
			if is_instance_valid(z):
				(z as Node).queue_free()
	for n in lanzador.get_children():
		if n is HechizoVivo:
			(n as Node).queue_free()
	for e in [EstadosSuelo3D.VAPOR, EstadosSuelo3D.ELECTRIFICADA, EstadosSuelo3D.MOJADA, EstadosSuelo3D.QUEMADA, EstadosSuelo3D.ESCOMBRO]:
		for c in Terreno3D.estados.celdas(String(e)).duplicate():
			Terreno3D.estados.poner(c as Vector2i, String(e), false)
	Terreno3D.conductores.clear()
	_avisos_vistos.clear()
	await avanzar(2)                        # que los queue_free hayan salido del grupo antes de crear nada nuevo


func _n_aviso(nombre: String, nodo: Node = null) -> int:
	var n: int = 0
	for a in _avisos_vistos:
		if a[0] == nombre and (nodo == null or a[1] == nodo):
			n += 1
	return n


func _hz(arch: String, glifos: Dictionary, dist: float = 3.8) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % arch), glifos).con({"distancia_max": dist, "gravedad": 0.0})


func _flecha(h: Hechizo) -> HechizoVivo:
	return HechizoVivo.crear(h, _pos(_libre), ESTE, lanzador, null, {}, true)


func _volar(v: HechizoVivo, max_pasos: int = 400) -> int:
	var n: int = 0
	while v.activo and n < max_pasos:
		v.paso(DT)
		n += 1
	return n


func _preparar(elemento: String, glifos: Array, segundo: String = "") -> Dictionary:
	Repertoire.libro = "avanzado" if segundo != "" else _libro_previo          # los sellos dobles solo existen en el libro avanzado
	colocar_jugador(_libre)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	if segundo != "":
		lanzador.place_element(segundo)          # sello doble (libro avanzado): fuego+tierra = magma, agua+tierra = naturaleza
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


## Todas las reacciones que la previsión del indicador dice para `g` con lo preparado (vacío si no hay entrada).
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
	if Mundo3D.actual != null:
		Mundo3D.actual.reaccion.connect(func(n: String, _p: Vector3, nodo: Node) -> void: _avisos_vistos.append([n, nodo]))
	_constantes()
	await _magma()
	await _naturaleza()
	await _libera_e_inmunes()
	await _ia_enraizado()
	await _tinta()
	await _prevision()
	await _cruce_magma_agua()
	await _descarga_tope()
	Repertoire.libro = _libro_previo
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- catálogo y constantes

func _constantes() -> void:
	_ok("0 ENRAIZADO_S vale 1,5 s y MAGMA_LENTO_S 2 s", _c(Combate3D.ENRAIZADO_S, 1.5) and _c(Combate3D.MAGMA_LENTO_S, 2.0))
	_ok("0 MAX_NODOS_DESCARGA vale 16", HechizoVivo.MAX_NODOS_DESCARGA == 16)
	_ok("0 el catálogo de reacciones tiene `enraizado`", Mundo3D.REACCIONES.has(Mundo3D.R_ENRAIZADO) and Mundo3D.R_ENRAIZADO == "enraizado")
	var cat: Array = ReaccionesVfx3D.CATALOGO
	var igual: bool = cat.size() == Mundo3D.REACCIONES.size()
	for i in range(mini(cat.size(), Mundo3D.REACCIONES.size())):
		igual = igual and String(cat[i]) == String(Mundo3D.REACCIONES[i])
	_ok("0 ReaccionesVfx3D.CATALOGO sigue siendo el mismo, en el mismo orden", igual)
	_ok("0 la fila `enraizado` apunta a un efecto que existe (raíces del elemental)", ReaccionesVfx3D.EFECTOS.has("raices") and String(ReaccionesVfx3D.resolver("enraizado")["vfx"]) == "raices")
	_ok("0 FeedbackReaccion3D tiene la familia de `enraizado`", FeedbackReaccion3D.FAMILIAS.has("enraizado") and String((FeedbackReaccion3D.FAMILIAS["enraizado"] as Array)[0]) == "enraiza")
	if PrevisionReaccion3D.ESTILO.has("enraiza"):
		var estilo: Array = PrevisionReaccion3D.ESTILO.get("enraiza") as Array      # .get y no [""]: la clave puede no existir aún y un índice constante inexistente no compila
		_ok("0 PrevisionReaccion3D.ESTILO tiene `enraiza` (rótulo y color)", String(estilo[0]) != "" and estilo[1] is Color)
	else:
		_aviso("0 PENDIENTE POR CONFLICTO: falta ESTILO[\"enraiza\"] en presentacion/prevision_reaccion_3d.gd (no cuenta como fallo hasta que se pegue)")
	_ok("0 `derrite` (magma sobre congelado) ya tiene rótulo en ESTILO", PrevisionReaccion3D.ESTILO.has("derrite"))
	_ok("0 los hechizos de magma y naturaleza traen su elemento", _h("magma").elemento == "magma" and _h("naturaleza").elemento == "naturaleza", "%s / %s" % [_h("magma").elemento, _h("naturaleza").elemento])
	_ok("0 `Tinta.REACCIONES_PREMIADAS` premia `enraizado`", Tinta.REACCIONES_PREMIADAS.has("enraizado"))
	_ok("0 la previsión conoce los avisos nuevos", PrevisionHechizo.DE_AVISO.get(Mundo3D.R_ENRAIZADO, "") == "enraiza" and PrevisionHechizo.DE_AVISO.get(Mundo3D.R_DERRETIDO, "") == "derrite"
		and PrevisionHechizo.PRIORIDAD_ENEMIGO.has("enraiza") and PrevisionHechizo.PRIORIDAD_ENEMIGO.has("derrite"))


# ---------------------------------------------------------------------------------------------------------------- MAGMA

func _magma() -> void:
	var h: Hechizo = _h("magma")
	var fuego: Hechizo = _h("fire")
	var a: Combate3D = _goblin(_libre + Vector2i(2, 0))
	var base_v: float = a.vel_mult()
	a.golpe(h, ESTE)
	_ok("M magma: quema como el fuego (%.1f s, la runa dice %.1f)" % [a.quemando, h.quema], a.quemando > 0.0 and _c(a.quemando, h.quema))
	_ok("M magma: lo ralentiza %.1f s (`lento` %.2f)" % [Combate3D.MAGMA_LENTO_S, a.lento], _c(a.lento, Combate3D.MAGMA_LENTO_S))
	_ok("M magma: y se nota en la velocidad (×%.2f de %.2f)" % [a.vel_mult(), base_v], a.vel_mult() < base_v - 0.001)
	_ok("M magma: no enraíza ni suelta raíces", a.enraizado <= 0.0 and _n_aviso("enraizado") == 0)
	var b: Combate3D = _goblin(_libre + Vector2i(2, 2))
	b.golpe(fuego, ESTE)
	_ok("M (control) el fuego quema pero NO ralentiza", b.quemando > 0.0 and b.lento <= 0.0)
	await _limpiar()
	# Sobre congelado: lo derrite, sin «roto», sin ×X_ROTO y sin metralla.
	var c: Combate3D = _goblin(_libre + Vector2i(2, 0))
	var control: Combate3D = _goblin(_libre + Vector2i(2, 3))
	c.congelado = 3.0
	var v0: float = c.health
	var vc: float = control.health
	_avisos_vistos.clear()
	c.golpe(h, ESTE)
	control.golpe(h, ESTE)
	_ok("M magma sobre congelado: lo derrite (congelado %.2f)" % c.congelado, c.congelado <= 0.0)
	_ok("M ... avisa «derretido» una vez y NO «roto»", _n_aviso(Mundo3D.R_DERRETIDO, c) == 1 and _n_aviso(Mundo3D.R_ROTO) == 0, str(_avisos_vistos))
	_ok("M ... y sigue ardiendo y lento", c.quemando > 0.0 and c.lento > 0.0)
	_ok("M ... el daño es el de siempre, sin ×%.1f (%.2f contra %.2f del control)" % [Dano.X_ROTO, v0 - c.health, vc - control.health], _c(v0 - c.health, vc - control.health) and v0 - c.health > 0.0)
	await avanzar(3)
	_ok("M ... y `_efectos` no lo avisa dos veces", _n_aviso(Mundo3D.R_DERRETIDO, c) == 1)
	await _limpiar()
	# Sobre mojado: vapor y lo seca, pero lento igual.
	var d: Combate3D = _goblin(_libre + Vector2i(2, 0))
	d.mojado = 3.0
	d.golpe(h, ESTE)
	_ok("M magma sobre mojado: lo seca (vapor) y lo frena igual", d.mojado <= 0.0 and d.quemando <= 0.0 and _c(d.lento, Combate3D.MAGMA_LENTO_S))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- NATURALEZA

func _naturaleza() -> void:
	var h: Hechizo = _h("naturaleza")
	var g: Combate3D = _goblin(_libre + Vector2i(2, 0))
	var base_v: float = g.vel_mult()
	_avisos_vistos.clear()
	g.golpe(h, ESTE)
	_ok("N naturaleza: lo enraíza ENRAIZADO_S (%.2f)" % g.enraizado, _c(g.enraizado, Combate3D.ENRAIZADO_S))
	_ok("N ... y deja el veneno de la runa (%.1f s)" % g.envenenado, g.envenenado > 0.0 and _c(g.envenenado, h.veneno))
	_ok("N ... avisa «enraizado» una vez", _n_aviso(Mundo3D.R_ENRAIZADO, g) == 1, str(_avisos_vistos))
	_ok("N ... no se mueve: vel_mult 0 (era %.2f)" % base_v, _c(g.vel_mult(), 0.0) and base_v > 0.0)
	var p0: Vector3 = g.position
	g.push(ESTE, 5000.0, true)
	await avanzar_s(0.5)
	_ok("N ... ni se deja empujar: %.3f u de desplazamiento" % g.position.distance_to(p0), g.position.distance_to(p0) < 0.01)
	_ok("N ... y el empujón rechazado no avisa «empujado»", _n_aviso(Mundo3D.R_EMPUJADO, g) == 0)
	# Control: un goblin sin raíces sí se desplaza con el mismo empujón.
	var libre_g: Combate3D = _goblin(_libre + Vector2i(2, 3))
	var q0: Vector3 = libre_g.position
	libre_g.push(ESTE, 5000.0, true)
	await avanzar_s(0.5)
	_ok("N (control) sin raíces el mismo empujón lo mueve %.2f u" % libre_g.position.distance_to(q0), libre_g.position.distance_to(q0) > 0.3)
	# Se acaba solo: 1,5 s después ya se mueve.
	var antes: float = g.enraizado
	await avanzar_s(1.2)
	_ok("N las raíces se acaban solas: %.2f → %.2f → 0" % [antes, g.enraizado], g.enraizado <= 0.0 and g.vel_mult() > 0.0)
	await _limpiar()
	# Mojado: el doble. Y no pierde lo mojado (la naturaleza no es agua).
	var m: Combate3D = _goblin(_libre + Vector2i(2, 0))
	m.mojado = 5.0
	m.golpe(h, ESTE)
	_ok("N mojado: raíces ×2 (%.2f)" % m.enraizado, _c(m.enraizado, Combate3D.ENRAIZADO_S * 2.0))
	_ok("N ... y sigue mojado (%.2f): ni lo seca ni lo moja más" % m.mojado, _c(m.mojado, 5.0))
	await avanzar_s(1.7)
	_ok("N mojado: a los 1,7 s siguen (%.2f) y a los 3 s no" % m.enraizado, m.enraizado > 1.0)
	await avanzar_s(1.7)
	_ok("N ... pasados los 3 s se suelta (%.2f)" % m.enraizado, m.enraizado <= 0.0)
	await _limpiar()
	# Quien ya arde: las raíces no prenden. Nada de enraizado, y sigue ardiendo (la naturaleza no es agua: no lo apaga).
	var a: Combate3D = _goblin(_libre + Vector2i(2, 0))
	a.quemando = 3.0
	_avisos_vistos.clear()
	a.golpe(h, ESTE)
	_ok("N sobre quien arde: no se enraíza", a.enraizado <= 0.0 and _n_aviso(Mundo3D.R_ENRAIZADO) == 0)
	_ok("N ... y la naturaleza no lo apaga (%.2f)" % a.quemando, a.quemando > 2.5 and _n_aviso(Mundo3D.R_APAGADO_AGUA) == 0)
	await _limpiar()
	# Sobre congelado: se enraíza igual (y el hielo no se toca).
	var f: Combate3D = _goblin(_libre + Vector2i(2, 0))
	f.congelado = 4.0
	f.golpe(h, ESTE)
	_ok("N sobre congelado: se enraíza y el hielo sigue (%.2f)" % f.congelado, f.enraizado > 0.0 and f.congelado > 3.5 and _n_aviso(Mundo3D.R_ROTO) == 0)
	await _limpiar()
	# Otro golpe de naturaleza refresca sin avisar de nuevo.
	var r: Combate3D = _goblin(_libre + Vector2i(2, 0))
	_avisos_vistos.clear()
	r.golpe(h, ESTE)
	r.enraizado = 0.5
	r.golpe(h, ESTE)
	_ok("N otro golpe refresca a %.2f y no avisa dos veces" % r.enraizado, _c(r.enraizado, Combate3D.ENRAIZADO_S) and _n_aviso(Mundo3D.R_ENRAIZADO) == 1)
	await _limpiar()


func _libera_e_inmunes() -> void:
	var nat: Hechizo = _h("naturaleza")
	for par in [["fire", "fuego"], ["magma", "magma"]]:
		var g: Combate3D = _goblin(_libre + Vector2i(2, 0))
		g.golpe(nat, ESTE)
		_ok("L [%s] antes: enraizado" % par[1], g.enraizado > 0.0)
		g.golpe(_h(String(par[0])), ESTE)
		_ok("L %s lo libera y lo prende (enraizado %.2f, quemando %.2f)" % [par[1], g.enraizado, g.quemando], g.enraizado <= 0.0 and g.quemando > 0.0 and g.vel_mult() > 0.0)
		await _limpiar()
	# El agua no lo libera (no es calor) y el hielo tampoco.
	var w: Combate3D = _goblin(_libre + Vector2i(2, 0))
	w.golpe(nat, ESTE)
	w.golpe(_h("water"), ESTE)
	_ok("L el agua no lo libera (%.2f)" % w.enraizado, w.enraizado > 0.0)
	await _limpiar()
	# Inmunes: el elemental de bosque (vegetal) y el gólem (piedra).
	var e: Combate3D = Combate3D.invocar_elemental(maqueta, jugador as Jugador3D, lanzador, _pos(_libre + Vector2i(3, 0)))
	_creados.append(e)
	await avanzar(2)
	_ok("I el elemental declara la inmunidad a las raíces", e != null and e.inmune_a("raices"))
	var dec: Dictionary = e.decidir_golpe(nat)
	e.golpe(nat, ESTE)
	_ok("I el elemental no se enraíza (decisión %.2f · estado %.2f)" % [float(dec["enraizado"]), e.enraizado], float(dec["enraizado"]) <= 0.0 and e.enraizado <= 0.0)
	var golem := Golem3D.new()
	_ok("I el gólem declara la inmunidad a las raíces", golem.inmune_a("raices") and golem.inmune_a("calor") and golem.inmune_a("veneno"))
	golem.free()
	var gb: Combate3D = _goblin(_libre + Vector2i(2, 0))
	_ok("I (control) el goblin no es inmune", not gb.inmune_a("raices"))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- IA

func _ia_enraizado() -> void:
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	var h: Hechizo = _h("naturaleza")
	# Lejos (3,5 u): persigue y avanza si no está enraizado; enraizado ve pero no se mueve.
	colocar_jugador(_libre)
	var sujeto: Combate3D = _goblin(_libre, Vector3(3.5, 0.0, 0.0))
	var suelto: Combate3D = _goblin(_libre, Vector3(0.0, 0.0, 3.5))
	sujeto.quieto = false
	suelto.quieto = false
	sujeto.golpe(h, ESTE)
	sujeto.enraizado = 6.0                  # que no se acabe a mitad de la prueba: aquí se mide la IA, no el reloj
	var s0: Vector3 = sujeto.position
	var l0: Vector3 = suelto.position
	_ok("A enraizado sigue VIENDO a la jugadora (`_ve` no cambia)", sujeto._ve(Combate3D.RADIO_DETECCION))
	await avanzar_s(1.0)
	_ok("A enraizado no avanza hacia ella: %.3f u (estado «%s»)" % [sujeto.position.distance_to(s0), sujeto.estado], sujeto.position.distance_to(s0) < 0.05 and sujeto.estado == "persigue")
	_ok("A (control) el que no lo está sí avanza: %.2f u" % suelto.position.distance_to(l0), suelto.position.distance_to(l0) > 0.2)
	await _limpiar()
	# Al alcance sigue atacando: la jugadora a ~0,9 u de un goblin enraizado.
	colocar_jugador(_libre)
	var pegador: Combate3D = _goblin(_libre, Vector3(0.9, 0.0, 0.0))
	pegador.quieto = false
	pegador.golpe(h, ESTE)
	pegador.enraizado = 6.0
	# El veneno de la runa interrumpe el ataque en cada pulso (INTERRUPCION_DANO > TICK_VENENO, comportamiento previo de TODO envenenado): se quita para medir solo lo que hace el enraizado.
	var interrumpido_por_veneno: bool = pegador.envenenado > 0.0
	pegador.envenenado = 0.0
	pegador._dps_veneno = 0.0
	var vida0: float = j.vida
	var atacó: bool = false
	var t: float = 0.0
	while t < 3.0 and not atacó:
		t += await avanzar_s(DT)
		atacó = pegador._ataque > 0.0 or pegador._golpe_pendiente or j.vida < vida0
	pegador._cancelar_ataque()               # su aviso de ataque (AvisoAtaque3D) sobreviviría al goblin liberado y `Sensacion3D.punta_flecha` evalúa `a.dueno is Node3D` sobre una instancia liberada
	_ok("A enraizado con ella al alcance SIGUE atacando (%.1f s · ataque %s · vida %.0f → %.0f · estado %s rango %s carga %.2f descanso %.2f interr %.2f stun %.2f)" % [t, str(atacó), vida0, j.vida, pegador.estado, str(pegador._en_rango), pegador._carga, pegador._descanso, pegador.interrupcion, pegador.stun_timer], atacó)
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- TINTA

func _tinta() -> void:
	var tinta: Tinta = lanzador.tinta
	var h: Hechizo = _h("naturaleza")
	var a: Combate3D = _goblin(_libre + Vector2i(2, 0))
	var b: Combate3D = _goblin(_libre + Vector2i(2, 3))
	tinta.actual = 0.0
	a.golpe(h, ESTE)
	_ok("T tinta: enraizar da +20 (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	a.enraizado = 0.0
	a.golpe(h, ESTE)
	_ok("T tinta: enraizar al MISMO enemigo otra vez no da más (%.1f)" % tinta.actual, _c(tinta.actual, 20.0))
	b.golpe(h, ESTE)
	_ok("T tinta: a OTRO enemigo sí (%.1f)" % tinta.actual, _c(tinta.actual, 40.0))
	var c: Combate3D = _goblin(_libre + Vector2i(2, 5))
	c.quemando = 3.0
	tinta.actual = 0.0
	c.golpe(h, ESTE)
	_ok("T tinta: sobre quien arde no se enraíza, no hay premio (%.1f)" % tinta.actual, _c(tinta.actual, 0.0))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- PREVISIÓN

func _prevision() -> void:
	var nat: Hechizo = _h("naturaleza")
	var mag: Hechizo = _h("magma")
	var g: Combate3D = _goblin(_libre + Vector2i(2, 0))
	var pn: Dictionary = g.prever_golpe(nat, ESTE)
	_ok("P prever_golpe de naturaleza lleva «enraizado» y no aplica nada", (pn["avisos"] as Array).has(Mundo3D.R_ENRAIZADO) and g.enraizado <= 0.0 and g.envenenado <= 0.0, str(pn["avisos"]))
	g.congelado = 3.0
	var pm: Dictionary = g.prever_golpe(mag, ESTE)
	_ok("P prever_golpe de magma sobre congelado lleva «derretido», NO «roto»", (pm["avisos"] as Array).has(Mundo3D.R_DERRETIDO) and not (pm["avisos"] as Array).has(Mundo3D.R_ROTO), str(pm["avisos"]))
	_ok("P ... y no ha derretido nada de verdad (%.1f)" % g.congelado, _c(g.congelado, 3.0))
	g.congelado = 0.0
	# El indicador: «enraiza» con naturaleza, «derrite» con magma sobre congelado, «lento»/«prende» con magma.
	var oeste := Vector3(-1, 0, 0)
	g.position = _pos(_libre + Vector2i(-2, 0))
	var d: Dictionary = _preparar("agua", ["flecha"], "tierra")
	if d.is_empty():
		_aviso("P no se pudo preparar «naturaleza» en el lanzador (el libro avanzado no la ofrece aquí)")
	else:
		var rs: Array = _previstas(d, g, oeste)
		_ok("P el indicador dice «enraiza» con naturaleza (%s)" % str(rs), rs.has("enraiza"))
		if rs.has("enraiza") and rs.has("prende"):
			_ok("P ... y «enraiza» manda sobre «prende»", rs.find("enraiza") < rs.find("prende"))
	lanzador._cancelar_modo()
	g.congelado = 3.0
	g.position = jugador.position + oeste * 1.5            # el magma llega menos lejos que la naturaleza (alcance 2 u con una flecha)
	var d2: Dictionary = _preparar("fuego", ["flecha"], "tierra")
	if d2.is_empty():
		_aviso("P no se pudo preparar «magma» en el lanzador (el libro avanzado no la ofrece aquí)")
	else:
		var rs2: Array = _previstas(d2, g, oeste)
		_ok("P el indicador dice «derrite» con magma sobre congelado y no «rompe_x2» (%s)" % str(rs2), rs2.has("derrite") and not rs2.has("rompe_x2") and rs2[0] == "derrite")
	lanzador._cancelar_modo()
	var prior: PackedStringArray = PrevisionHechizo.PRIORIDAD_ENEMIGO
	_ok("P «derrite» y «enraiza» van tras «congela» y antes de «prende» en la prioridad", prior.find("congela") < prior.find("derrite") and prior.find("derrite") < prior.find("enraiza") and prior.find("enraiza") < prior.find("prende"))
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- CRUCE magma × agua

func _cruce_magma_agua() -> void:
	await _limpiar()
	var cr: Dictionary = HechizoVivo.CRUCES
	_ok("C la tabla CRUCES tiene magma×agua = costra (y conserva las otras tres)", cr.has("magma") and (cr["magma"] as Dictionary).keys() == ["agua"] and String(cr["magma"]["agua"]["accion"]) == "costra"
		and cr.has("fuego") and cr.has("viento") and cr.has("rayo") and cr.size() == 4, str(cr.keys()))
	_ok("C su aviso está en el catálogo y su rótulo en ESTILO", Mundo3D.REACCIONES.has(String(cr["magma"]["agua"]["aviso"])) and PrevisionReaccion3D.ESTILO.has(String(cr["magma"]["agua"]["previsto"])))
	var c2: Vector2i = _libre + Vector2i(2, 0)
	_zona("agua", [c2], true)
	var v: HechizoVivo = _flecha(_hz("magma", {"flecha": 1}))
	_ok("C el proyectil sale como magma", v.elemento == "magma", v.elemento)
	_volar(v)
	_ok("C magma×agua: acaba con causa «cruce» en la casilla del charco", v.motivo_fin == "cruce" and Terreno3D.celda_de(v.p) == c2, "%s %s" % [v.motivo_fin, str(Terreno3D.celda_de(v.p))])
	_ok("C ... deja VAPOR", Terreno3D.estados.hay_vapor(c2))
	_ok("C ... y deja ESCOMBRO (la costra)", Terreno3D.estados.tiene(c2, EstadosSuelo3D.ESCOMBRO))
	_ok("C ... avisa «apagado_agua» una vez", _n_aviso(Mundo3D.R_APAGADO_AGUA) == 1, str(_avisos_vistos))
	_ok("C ... el cruce queda anotado como «costra»", v.cruces_vistos.size() == 1 and String(v.cruces_vistos[0]["accion"]) == "costra")
	_ok("C ... no deja llama ni suelo quemado donde se apaga", not Terreno3D.estados.tiene(c2, EstadosSuelo3D.QUEMADA))
	_ok("C ... y la costra frena a quien la pisa (×%.2f)" % Terreno3D.estados.factor_velocidad(c2), Terreno3D.estados.factor_velocidad(c2) < 1.0)
	await _limpiar()
	# Control: sin charco, el magma sigue su camino y no deja costra.
	var sin: HechizoVivo = _flecha(_hz("magma", {"flecha": 1}))
	_volar(sin)
	_ok("C (control) sin charco: sin cruce, sin vapor y sin costra", sin.cruces_vistos.is_empty() and Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR) == 0 and Terreno3D.estados.cuantas(EstadosSuelo3D.ESCOMBRO) == 0)
	await _limpiar()
	# Control: el agua DEL MAPA o el suelo mojado no son zona viva.
	Terreno3D.estados.poner(c2, EstadosSuelo3D.MOJADA, true)
	var mj: HechizoVivo = _flecha(_hz("magma", {"flecha": 1}))
	_volar(mj)
	_ok("C (control) suelo mojado no es zona de hechizo: no hay cruce", mj.cruces_vistos.is_empty())
	await _limpiar()
	# Previsión: lo anuncia como «vapor» en la casilla del charco, sin cambiar nada.
	var c1: Vector2i = _libre + Vector2i(1, 0)
	_zona("agua", [c1], true)                              # más cerca que el c2 de arriba: el magma vuela poco
	_preparar("fuego", ["flecha", "flecha"], "tierra")
	if lanzador._preparado.is_empty():
		_aviso("C no se pudo preparar «magma» para la previsión del cruce")
	else:
		var vivo: Dictionary = HechizoVivo.prever(lanzador.hechizo_de(lanzador._preparado), lanzador, jugador.position, ESTE)
		_ok("C previsión: magma×agua = «vapor» en la casilla del charco", (vivo["cruces"] as Array).size() == 1 and String(vivo["cruces"][0]["reaccion"]) == "vapor" and (vivo["cruces"][0]["celda"] as Vector2i) == c1, str(vivo["cruces"]))
		_ok("C previsión: no ha escrito vapor ni costra", Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR) == 0 and Terreno3D.estados.cuantas(EstadosSuelo3D.ESCOMBRO) == 0 and _n_aviso(Mundo3D.R_APAGADO_AGUA) == 0)
	lanzador._cancelar_modo()
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------- tope de la descarga

func _descarga_tope() -> void:
	await _limpiar()
	var j: Jugador3D = jugador as Jugador3D
	j._t_inv = 0.0
	# Un «lago» de 9×9 casillas que conducen, conectado al centro del claro.
	var lado: int = 4
	for dy in range(-lado, lado + 1):
		for dx in range(-lado, lado + 1):
			Terreno3D.conductores[_libre + Vector2i(dx, dy)] = true
	var lago: int = (2 * lado + 1) * (2 * lado + 1)
	var v: HechizoVivo = _flecha(_hz("lightning", {"flecha": 1}))
	var area: Dictionary = {}
	var n: int = v._descarga({"data": v.data, "elemento": "rayo", "celdas": [_libre], "tocados": {}, "dir": ESTE, "origen": v.p}, area)
	_ok("D el rayo sobre un lago de %d casillas recorre como mucho 1 + %d (%d)" % [lago, HechizoVivo.MAX_NODOS_DESCARGA, area.size()], area.size() <= 1 + HechizoVivo.MAX_NODOS_DESCARGA and n == 1, "area %d" % area.size())
	_ok("D ... pero sí llega a esas %d (no se queda corto: %d)" % [HechizoVivo.MAX_NODOS_DESCARGA, area.size()], area.size() == 1 + HechizoVivo.MAX_NODOS_DESCARGA)
	var electrificadas: int = Terreno3D.estados.cuantas(EstadosSuelo3D.ELECTRIFICADA)
	_ok("D ... y solo esas quedan ELECTRIFICADAS (%d)" % electrificadas, electrificadas <= 1 + HechizoVivo.MAX_NODOS_DESCARGA and electrificadas >= HechizoVivo.MAX_NODOS_DESCARGA)
	# Es por anillos: lo que entra es lo más cercano a la zona (el centro y su vecindad, no una esquina del lago).
	var lejana: Vector2i = _libre + Vector2i(lado, lado)
	_ok("D ... las más cercanas primero: la esquina del lago (a %d casillas) se queda fuera" % (2 * lado), not area.has(lejana))
	# Un enemigo en el lago, lejos del tope: no le llega.
	await _limpiar()
	for dy in range(-lado, lado + 1):
		for dx in range(-lado, lado + 1):
			Terreno3D.conductores[_libre + Vector2i(dx, dy)] = true
	var cerca: Combate3D = _goblin(_libre + Vector2i(1, 0))
	var lejos: Combate3D = _goblin(_libre + Vector2i(lado, lado))
	var hc: float = cerca.health
	var hl: float = lejos.health
	var v2: HechizoVivo = _flecha(_hz("lightning", {"flecha": 1}))
	v2._descarga({"data": v2.data, "elemento": "rayo", "celdas": [_libre], "tocados": {}, "dir": ESTE, "origen": v2.p}, {})
	_ok("D el goblin pegado a la zona recibe la descarga (%.0f → %.0f)" % [hc, cerca.health], cerca.health < hc)
	_ok("D el del otro extremo del lago, fuera del tope, no (%.0f → %.0f)" % [hl, lejos.health], _c(lejos.health, hl))
	await _limpiar()
	# Control: bajo el tope se electrifica TODO el agua conectada (3×3 = 9 casillas).
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			Terreno3D.conductores[_libre + Vector2i(dx, dy)] = true
	var v3: HechizoVivo = _flecha(_hz("lightning", {"flecha": 1}))
	var area3: Dictionary = {}
	v3._descarga({"data": v3.data, "elemento": "rayo", "celdas": [_libre], "tocados": {}, "dir": ESTE, "origen": v3.p}, area3)
	_ok("D (control) un charco de 9 casillas se electrifica entero (%d)" % area3.size(), area3.size() == 9 and Terreno3D.estados.cuantas(EstadosSuelo3D.ELECTRIFICADA) == 9)
	await _limpiar()
