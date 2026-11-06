extends "res://herramientas/escenario_base.gd"
## B5 · HECHIZO × HECHIZO y C3 · GLIFO «AL IMPACTAR» (6/11/2026; docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloques B y C). Sobre la escena real del Bosque, con goblins reales (`Combate3D`):
##   B5 · un proyectil vivo que ENTRA en la zona viva de otro hechizo se transforma (tabla `HechizoVivo.CRUCES`): fuego × agua = se apaga y deja vapor · viento × fuego = pasa a ser fuego (llamarada) y
##        sigue volando · rayo × agua = descarga sobre toda la zona de agua (daño a quien está dentro, zona electrificada) y se gasta. El agua del MAPA y el suelo mojado NO son zona viva (no apagan la flecha
##        que cruza un río). La previsión lo anuncia («vapor», «llamarada», «descarga») como entrada de suelo, sin cambiar nada.
##   C3 · ⧖ `retardo` ENTRE dos formas deja de ser carga: lo dibujado después es el HIJO (la siguiente forma de la página), que nace donde el proyectil se para (golpe o muro/alcance); sin orden o con ⧖
##        al principio/al final sigue siendo carga. El hijo se cobra con `Dano.K_HIJO` (una vez, aunque esté en dos finales).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bloque_b5_c3.gd

const DT: float = 1.0 / 30.0
const ESTE := Vector3(1, 0, 0)

var _comprobaciones: int = 0
var _creados: Array = []
var _avisos_vistos: Array = []          ## [nombre, nodo] de cada `Mundo3D.reaccion`
var _libre: Vector2i = Vector2i.ZERO


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _c(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


# --- utilidades ----------------------------------------------------------------------------------------------------

func _rune(arch: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % arch)


func _pos(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


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


## Un goblin quieto, con vida de sobra, sin debilidad ni resistencia, en la casilla `c`.
func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
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


## Una zona viva con `celdas`: `en_cruce` = un charco (`Lanzador3D.zonas_cruce`); si no, una zona de pulso (`_zonas_v2`, como la llama del fuego). Sin método de pulso: solo está.
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
	for e in [EstadosSuelo3D.VAPOR, EstadosSuelo3D.ELECTRIFICADA, EstadosSuelo3D.MOJADA, EstadosSuelo3D.QUEMADA]:
		for c in Terreno3D.estados.celdas(String(e)).duplicate():
			Terreno3D.estados.poner(c as Vector2i, String(e), false)
	_avisos_vistos.clear()
	await avanzar(2)                        # que los queue_free hayan salido del grupo antes de crear nada nuevo


func _n_aviso(nombre: String) -> int:
	var n: int = 0
	for a in _avisos_vistos:
		if a[0] == nombre:
			n += 1
	return n


func _hz(arch: String, glifos: Dictionary, dist: float = 3.8) -> Hechizo:       # el claro es llano ≥ 4 casillas a cada lado: con más alcance la flecha acabaría contra un muro
	return Hechizo.construir(_rune(arch), glifos).con({"distancia_max": dist, "gravedad": 0.0})


## Un proyectil a mano (no avanza solo: lo mueve `_volar`) desde la jugadora hacia el este.
func _flecha(h: Hechizo) -> HechizoVivo:
	return HechizoVivo.crear(h, _pos(_libre), ESTE, lanzador, null, {}, true)


func _volar(v: HechizoVivo, max_pasos: int = 400) -> int:
	var n: int = 0
	while v.activo and n < max_pasos:
		v.paso(DT)
		n += 1
	return n


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
	lanzador.cast_page(0)
	return lanzador._preparado


## La previsión de lo preparado hacia el este, y la entrada de suelo con esa reacción en esa casilla ({} si no hay).
func _prevista(reaccion: String, c: Vector2i) -> Dictionary:
	PrevisionHechizo.olvidar()
	for e in PrevisionHechizo.prever(lanzador, lanzador._preparado, jugador.position, ESTE):
		if String(e["que"]) == "suelo" and String(e["reaccion"]) == reaccion and (e["celda"] as Vector2i) == c:
			return e
	return {}


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
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
	_ok("0 los avisos que usa B5 ya estaban en el catálogo (sin reacciones nuevas)", Mundo3D.REACCIONES.has(Mundo3D.R_APAGADO_AGUA) and Mundo3D.REACCIONES.has(Mundo3D.R_LLAMARADA) and Mundo3D.REACCIONES.has(Mundo3D.R_ELECTROCUTADO))
	await _b5_tabla()
	await _b5_vapor()
	await _b5_llamarada()
	await _b5_descarga()
	await _b5_prevision()
	await _b5_real()
	await _c3_puro()
	await _c3_vuelo()
	await _c3_tinta_y_prevision()
	await _limpiar()
	print("Comprobaciones: %d" % _comprobaciones)


# ====================================================================================================================
#  B5
# ====================================================================================================================

func _b5_tabla() -> void:
	var c: Dictionary = HechizoVivo.CRUCES
	_ok("B5 la tabla CRUCES: fuego×agua apaga · viento×fuego enciende · rayo×agua descarga (y nada más)",
		c.size() == 3 and (c["fuego"] as Dictionary).keys() == ["agua"] and String(c["fuego"]["agua"]["accion"]) == "apagar"
		and (c["viento"] as Dictionary).keys() == ["fuego"] and String(c["viento"]["fuego"]["accion"]) == "encender" and String(c["viento"]["fuego"]["a"]) == "fuego"
		and (c["rayo"] as Dictionary).keys() == ["agua"] and String(c["rayo"]["agua"]["accion"]) == "descargar", str(c))
	var previstas_ok: bool = true
	for el in c:
		for otro in c[el]:
			previstas_ok = previstas_ok and PrevisionReaccion3D.ESTILO.has(String(c[el][otro]["previsto"])) and Mundo3D.REACCIONES.has(String(c[el][otro]["aviso"]))
	_ok("B5 cada fila tiene su rótulo en PrevisionReaccion3D.ESTILO y su aviso en el catálogo", previstas_ok)
	_ok("B5 `Lanzador3D.zonas_cruce` existe y empieza vacía", lanzador.zonas_cruce.is_empty())


func _b5_vapor() -> void:
	await _limpiar()
	var c2: Vector2i = _libre + Vector2i(2, 0)
	_zona("agua", [c2], true)
	var zonas_antes: int = lanzador._zonas_v2.size()
	var v: HechizoVivo = _flecha(_hz("fire", {"flecha": 1}))
	_volar(v)
	_ok("B5 fuego×agua: la flecha acaba con causa «cruce»", v.motivo_fin == "cruce", v.motivo_fin)
	_ok("B5 fuego×agua: acaba EN la casilla del charco", Terreno3D.celda_de(v.p) == c2, str(Terreno3D.celda_de(v.p)))
	_ok("B5 fuego×agua: deja VAPOR en esa casilla", Terreno3D.estados.hay_vapor(c2))
	_ok("B5 fuego×agua: avisa «apagado_agua» una vez", _n_aviso(Mundo3D.R_APAGADO_AGUA) == 1, str(_avisos_vistos))
	_ok("B5 fuego×agua: no aplica su materia donde se apaga (ni zona de llama ni suelo quemado)", lanzador._zonas_v2.size() == zonas_antes and not Terreno3D.estados.tiene(c2, EstadosSuelo3D.QUEMADA))
	_ok("B5 fuego×agua: el cruce queda anotado en el proyectil", v.cruces_vistos.size() == 1 and String(v.cruces_vistos[0]["accion"]) == "apagar" and (v.cruces_vistos[0]["celda"] as Vector2i) == c2)
	_ok("B5 fuego×agua: no salta ningún final del hechizo (no «impactó»)", v.finales_vistos.is_empty())
	# Controles: sin charco, lo de siempre; con una llama (mismo elemento), tampoco; con el suelo mojado o el agua del MAPA, tampoco.
	await _limpiar()
	zonas_antes = lanzador._zonas_v2.size()
	var sin: HechizoVivo = _flecha(_hz("fire", {"flecha": 1}))
	_volar(sin)
	_ok("B5 control sin charco: llega a su alcance, deja su zona y no hay vapor ni cruce", sin.motivo_fin == "alcance" and sin.cruces_vistos.is_empty() and lanzador._zonas_v2.size() == zonas_antes + 1
		and Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR) == 0, "%s · zonas %d→%d" % [sin.motivo_fin, zonas_antes, lanzador._zonas_v2.size()])
	await _limpiar()
	_zona("fuego", [c2], true)
	var mismo: HechizoVivo = _flecha(_hz("fire", {"flecha": 1}))
	_volar(mismo)
	_ok("B5 control mismo elemento: el fuego cruza una zona de fuego sin cruce", mismo.cruces_vistos.is_empty() and mismo.motivo_fin == "alcance")
	await _limpiar()
	Terreno3D.estados.poner(c2, EstadosSuelo3D.MOJADA, true)
	var mojado: HechizoVivo = _flecha(_hz("fire", {"flecha": 1}))
	_volar(mojado)
	_ok("B5 control suelo mojado (no es zona de HECHIZO): la flecha de fuego lo cruza sin apagarse", mojado.cruces_vistos.is_empty() and mojado.motivo_fin == "alcance", mojado.motivo_fin)
	await _limpiar()


func _b5_llamarada() -> void:
	await _limpiar()
	var c2: Vector2i = _libre + Vector2i(2, 0)
	var c4: Vector2i = _libre + Vector2i(4, 0)
	var viento0: Hechizo = _hz("wind", {"flecha": 1})
	_zona("fuego", [c2], false)
	var g: Combate3D = _goblin(c4)
	var antes_quema: float = g.quemando
	var v: HechizoVivo = _flecha(viento0)
	_ok("B5 viento×fuego: sale como viento", v.elemento == "viento" and v.h.elemento == "viento" and Objetos.elemento_de(v.data) == "viento")
	_volar(v)
	_ok("B5 viento×fuego: el proyectil pasa a ser FUEGO (elemento, hechizo y runa)", v.elemento == "fuego" and v.h.elemento == "fuego" and Objetos.elemento_de(v.data) == "fuego", "%s/%s" % [v.elemento, v.h.elemento])
	_ok("B5 viento×fuego: sigue con los mismos glifos y hereda la quema del fuego (viento %.2f → fuego %.2f)" % [viento0.quema, v.h.quema], v.h.glifos == {"flecha": 1} and v.h.quema > viento0.quema)
	_ok("B5 viento×fuego: avisa «llamarada» una vez y anota el cruce «encender»", _n_aviso(Mundo3D.R_LLAMARADA) == 1 and v.cruces_vistos.size() == 1 and String(v.cruces_vistos[0]["accion"]) == "encender")
	_ok("B5 viento×fuego: NO se gasta en el cruce: sigue su camino y golpea al goblin de detrás (%.1f s de quemadura)" % g.quemando, v.motivo_fin == "golpe" and g.quemando > antes_quema)
	# Control: el mismo viento sin zona de fuego no quema.
	await _limpiar()
	var g2: Combate3D = _goblin(c4)
	var sin: HechizoVivo = _flecha(viento0)
	_volar(sin)
	_ok("B5 control: el mismo viento SIN zona de fuego sigue siendo viento y no quema", sin.elemento == "viento" and sin.cruces_vistos.is_empty() and g2.quemando <= 0.0)
	await _limpiar()


func _b5_descarga() -> void:
	await _limpiar()
	var c2: Vector2i = _libre + Vector2i(2, 0)
	var c2b: Vector2i = c2 + Vector2i(0, 1)
	_zona("agua", [c2, c2b], true)
	var g_dentro: Combate3D = _goblin(c2b)               # dentro del charco, fuera de la línea de la flecha
	var g_detras: Combate3D = _goblin(_libre + Vector2i(3, 0))   # en la línea, justo después del charco: la flecha ya se gastó
	var g_lejos: Combate3D = _goblin(c2 + Vector2i(0, 3))        # fuera del charco
	await avanzar(2)
	var v_dentro: float = g_dentro.health
	var v_detras: float = g_detras.health
	var v_lejos: float = g_lejos.health
	var v: HechizoVivo = _flecha(_hz("lightning", {"flecha": 1}))
	_volar(v)
	_ok("B5 rayo×agua: la flecha acaba con causa «cruce» en la casilla del charco", v.motivo_fin == "cruce" and Terreno3D.celda_de(v.p) == c2, "%s %s" % [v.motivo_fin, str(Terreno3D.celda_de(v.p))])
	_ok("B5 rayo×agua: hiere al goblin que estaba DENTRO del charco (%.0f → %.0f)" % [v_dentro, g_dentro.health], g_dentro.health < v_dentro)
	_ok("B5 rayo×agua: no hiere al de detrás ni al que está lejos del charco", _c(g_detras.health, v_detras) and _c(g_lejos.health, v_lejos), "detrás %.0f · lejos %.0f" % [g_detras.health, g_lejos.health])
	_ok("B5 rayo×agua: toda la zona queda ELECTRIFICADA", Terreno3D.estados.tiene(c2, EstadosSuelo3D.ELECTRIFICADA) and Terreno3D.estados.tiene(c2b, EstadosSuelo3D.ELECTRIFICADA))
	_ok("B5 rayo×agua: avisa «electrocutado» y anota el cruce «descargar»", _n_aviso(Mundo3D.R_ELECTROCUTADO) >= 1 and v.cruces_vistos.size() == 1 and String(v.cruces_vistos[0]["accion"]) == "descargar")
	# Control: el rayo sin charco llega a su alcance y no electrifica nada.
	await _limpiar()
	var g2: Combate3D = _goblin(_libre + Vector2i(0, 1) + Vector2i(2, 0))
	var sin: HechizoVivo = _flecha(_hz("lightning", {"flecha": 1}))
	_volar(sin)
	_ok("B5 control: el rayo sin charco no cruza nada ni electrifica", sin.cruces_vistos.is_empty() and Terreno3D.estados.cuantas(EstadosSuelo3D.ELECTRIFICADA) == 0 and _c(g2.health, 100000.0))
	await _limpiar()


func _b5_prevision() -> void:
	await _limpiar()
	var c2: Vector2i = _libre + Vector2i(2, 0)
	_zona("agua", [c2], true)
	_preparar("fuego", ["flecha", "flecha"])
	var vivo: Dictionary = HechizoVivo.prever(lanzador.hechizo_de(lanzador._preparado), lanzador, jugador.position, ESTE)
	_ok("B5 previsión (HechizoVivo.prever) lleva los cruces: fuego×agua = «vapor» en la casilla del charco", (vivo["cruces"] as Array).size() == 1 and String(vivo["cruces"][0]["reaccion"]) == "vapor" and (vivo["cruces"][0]["celda"] as Vector2i) == c2, str(vivo["cruces"]))
	var e: Dictionary = _prevista("vapor", c2)
	_ok("B5 previsión: PrevisionHechizo.prever anuncia «vapor» como entrada de suelo en esa casilla", not e.is_empty() and (e["extra"] as Dictionary).get("clase", "") == "cruce", str(e))
	_ok("B5 previsión: no ha cambiado nada (ni vapor, ni zonas nuevas, ni avisos)", Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR) == 0 and lanzador.zonas_cruce.size() == 1 and _n_aviso(Mundo3D.R_APAGADO_AGUA) == 0)
	var cuadros: int = 0
	var rotulo_ok: bool = false
	var vista: PrevisionReaccion3D = PrevisionReaccion3D.new()
	root.add_child(vista)
	vista.mostrar(PrevisionHechizo.prever(lanzador, lanzador._preparado, jugador.position, ESTE))
	for p in vista.pintado:
		if String(p["que"]) == "suelo" and String(p["reaccion"]) == "vapor":
			cuadros += 1
			rotulo_ok = String(p["texto"]) == "Vapor"
	_ok("B5 el indicador (PrevisionReaccion3D) pinta «Vapor» en el suelo", cuadros == 1 and rotulo_ok, str(vista.pintado))
	vista.queue_free()
	lanzador._cancelar_modo()
	await _limpiar()
	# viento × fuego y rayo × agua
	_zona("fuego", [c2], false)
	_preparar("viento", ["flecha", "flecha"])
	_ok("B5 previsión: viento×fuego = «llamarada»", not _prevista("llamarada", c2).is_empty())
	lanzador._cancelar_modo()
	await _limpiar()
	_zona("agua", [c2], true)
	_preparar("rayo", ["flecha", "flecha"])
	_ok("B5 previsión: rayo×agua = «descarga»", not _prevista("descarga", c2).is_empty())
	_ok("B5 previsión: ESTILO de «descarga» es un rótulo y un color (eléctrico, no el del fuego)", String((PrevisionReaccion3D.ESTILO["descarga"] as Array)[0]) == "Descarga" and (PrevisionReaccion3D.ESTILO["descarga"] as Array)[1] is Color)
	lanzador._cancelar_modo()
	await _limpiar()
	# sin zona: la previsión no inventa nada
	_preparar("fuego", ["flecha", "flecha"])
	_ok("B5 previsión: sin zona no anuncia ningún cruce", _prevista("vapor", c2).is_empty() and (HechizoVivo.prever(lanzador.hechizo_de(lanzador._preparado), lanzador, jugador.position, ESTE)["cruces"] as Array).is_empty())
	lanzador._cancelar_modo()
	await _limpiar()


## El camino real: el agua que LANZAS deja un charco de hechizo (zona de cruce, no de pulso), y la flecha de fuego que lo cruza se apaga.
func _b5_real() -> void:
	await _limpiar()
	colocar_jugador(_libre)
	var salio: bool = lanzar("agua", ["flecha", "flecha"], ESTE)
	_ok("B5 real: el agua sale", salio)
	await avanzar_s(3.2)                    # la flecha de agua vuela 3 casillas a 4 u/s y al pararse echa el agua
	var charcos: Array = lanzador.zonas_cruce.filter(func(z: Variant) -> bool: return is_instance_valid(z) and (z as Lanzador3D.ZonaV2).elemento == "agua")
	_ok("B5 real: el agua dejó un charco de hechizo en zonas_cruce (no en _zonas_v2)", charcos.size() >= 1 and lanzador._zonas_v2.is_empty(), "charcos %d · zonas %d" % [charcos.size(), lanzador._zonas_v2.size()])
	if charcos.is_empty():
		return
	var celdas_charco: Array = (charcos[0] as Lanzador3D.ZonaV2).celdas.keys()
	_ok("B5 real: el charco ocupa casillas en el sentido del lanzamiento (a ≥ 2 casillas)", celdas_charco.all(func(c: Vector2i) -> bool: return c.x >= _libre.x + 1), str(celdas_charco))
	colocar_jugador(_libre)
	lanzador.cooldown_left[0] = 0.0
	_avisos_vistos.clear()
	var sale_fuego: bool = lanzar("fuego", ["flecha", "flecha", "flecha"], ESTE)
	_ok("B5 real: el fuego sale", sale_fuego)
	await avanzar_s(3.0)
	_ok("B5 real: la flecha de fuego que cruza el charco lo apaga: aviso «apagado_agua» y vapor en el suelo", _n_aviso(Mundo3D.R_APAGADO_AGUA) >= 1 and Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR) >= 1,
		"avisos %d · vapor %d" % [_n_aviso(Mundo3D.R_APAGADO_AGUA), Terreno3D.estados.cuantas(EstadosSuelo3D.VAPOR)])
	# El charco caduca (y se borra de la lista).
	await avanzar_s(HechizoVivo.ZONA_AGUA_S + 1.2)
	var vivos: int = lanzador.zonas_cruce.filter(func(z: Variant) -> bool: return is_instance_valid(z)).size()
	_ok("B5 real: el charco caduca a los %.0f s y sale de la lista" % HechizoVivo.ZONA_AGUA_S, vivos == 0, "quedan %d" % vivos)
	await _limpiar()


# ====================================================================================================================
#  C3
# ====================================================================================================================

func _c3_puro() -> void:
	var fuego: RuneData = _rune("fire")
	var cont: Dictionary = {"flecha": 1, "retardo": 1, "barrera": 1}
	var h: Hechizo = Hechizo.construir(fuego, cont, 1.0, false, ["flecha", "retardo", "barrera"])
	var sola: Hechizo = Hechizo.construir(fuego, {"flecha": 1}, 1.0, false, ["flecha"])
	_ok("C3 flecha + ⧖ + barrera: el PADRE es solo la flecha (sin barrera, sin carga)", h.glifos == {"flecha": 1} and is_equal_approx(h.retardo, 0.0) and is_equal_approx(h.solidez, 0.0) and h.viaja and h.proyectil,
		"glifos %s · retardo %.1f · solidez %.1f" % [str(h.glifos), h.retardo, h.solidez])
	_ok("C3 y el padre es EXACTAMENTE la flecha sola (mismas cifras de daño, alcance y forma)", is_equal_approx(h.dano, sola.dano) and is_equal_approx(h.distancia_max, sola.distancia_max) and h.forma == sola.forma and h.semiejes.is_equal_approx(sola.semiejes))
	_ok("C3 el hijo es la siguiente forma: la barrera", h.hijo_siguiente.get("glifos", {}) == {"barrera": 1} and h.hijo_siguiente.get("orden", []) == ["barrera"], str(h.hijo_siguiente))
	var fines_ok: bool = true
	for ev in ["al_impactar", "al_detenerse"]:
		var acc: Array = h.eventos.get(ev, []) as Array
		fines_ok = fines_ok and acc.size() == 1 and String(acc[0]["accion"]) == "crear_hijo" and acc[0]["glifos_hijo"] == {"barrera": 1} and (acc[0]["salvo"] as Array).has("retorno")
	_ok("C3 el hijo está en los dos finales (al_impactar y al_detenerse, que no saltan a la vez)", fines_ok, str(h.eventos))
	_ok("C3 y solo UNO cuenta como hijo previsto (K_HIJO una vez)", Dano.hijos_previstos(h) == 1, str(Dano.hijos_previstos(h)))
	_ok("C3 el coste del padre = el de la flecha sola × (1 + K_HIJO) (%.2f contra %.2f)" % [h.coste_tinta, sola.coste_tinta * (1.0 + Dano.K_HIJO)], absf(h.coste_tinta - sola.coste_tinta * (1.0 + Dano.K_HIJO)) < 0.01 and h.coste_tinta > sola.coste_tinta)
	# Todo lo que NO es el disparador: sigue siendo carga, igual que siempre.
	var sin_orden: Hechizo = Hechizo.construir(fuego, cont, 1.0)
	_ok("C3 sin orden de dibujo ⧖ sigue siendo CARGA (la receta es un multiconjunto: flecha+barrera fundidas, +1 s de espera)", is_equal_approx(sin_orden.retardo, 1.0) and sin_orden.hijo_siguiente.is_empty() and sin_orden.eventos.is_empty() and sin_orden.glifos.has("retardo"))
	for caso in [["retardo", "flecha", "barrera"], ["flecha", "barrera", "retardo"], ["flecha", "retardo"], ["retardo", "flecha"], ["barrera", "retardo", "flecha"], ["flecha", "retardo", "altura"], ["flecha", "retardo", "repeticion"]]:
		var cc: Dictionary = {}
		for g in caso:
			cc[g] = int(cc.get(g, 0)) + 1
		var hc: Hechizo = Hechizo.construir(fuego, cc, 1.0, false, caso)
		_ok("C3 %s no es disparador: sigue siendo carga (retardo %.0f) y sin hijo" % [str(caso), hc.retardo], is_equal_approx(hc.retardo, 1.0) and hc.hijo_siguiente.is_empty() and Dano.hijos_previstos(hc) == 0)
	# Variantes que sí lo son.
	var h2: Hechizo = Hechizo.construir(fuego, {"flecha": 2, "retardo": 1, "barrera": 1}, 1.0, false, ["flecha", "flecha", "retardo", "barrera"])
	_ok("C3 flecha + flecha + ⧖ + barrera: el padre lleva las dos flechas (alcance de dos) y el hijo la barrera", h2.glifos == {"flecha": 2} and h2.hijo_siguiente["glifos"] == {"barrera": 1} and is_equal_approx(h2.distancia_max, Hechizo.construir(fuego, {"flecha": 2}).distancia_max))
	var h3: Hechizo = Hechizo.construir(fuego, {"flecha": 2, "retardo": 1}, 1.0, false, ["flecha", "retardo", "flecha"])
	_ok("C3 flecha + ⧖ + flecha: el hijo es otra flecha", h3.glifos == {"flecha": 1} and h3.hijo_siguiente["glifos"] == {"flecha": 1})
	var h4: Hechizo = Hechizo.construir(fuego, {"flecha": 1, "retardo": 1, "barrera": 1, "altura": 1}, 1.0, false, ["flecha", "retardo", "barrera", "levitacion"])
	_ok("C3 el hijo lleva TODO lo que se dibuja después (barrera + altura) y el alias ᛏ se resuelve", h4.hijo_siguiente["glifos"] == {"barrera": 1, "altura": 1} and h4.hijo_siguiente["orden"] == ["barrera", "altura"], str(h4.hijo_siguiente))
	var h5: Hechizo = Hechizo.construir(fuego, {"retardo": 2, "flecha": 1, "barrera": 1}, 1.0, false, ["retardo", "flecha", "retardo", "barrera"])
	_ok("C3 con un ⧖ al principio (carga) y otro entre dos formas: el primero carga al padre y el segundo es el disparador", is_equal_approx(h5.retardo, 1.0) and h5.glifos == {"retardo": 1, "flecha": 1} and h5.hijo_siguiente["glifos"] == {"barrera": 1})
	var h6: Hechizo = Hechizo.construir(fuego, {"flecha": 2, "retardo": 2, "barrera": 1}, 1.0, false, ["flecha", "retardo", "flecha", "retardo", "barrera"])
	var nieto: Hechizo = Hechizo.construir(fuego, h6.hijo_siguiente["glifos"] as Dictionary, 1.0, false, h6.hijo_siguiente["orden"] as Array)
	_ok("C3 encadenado (ᛇ ⧖ ᛇ ⧖ ᛜ): el hijo de la página es otra flecha con SU propio hijo (la barrera): padre → hijo → nieto", h6.glifos == {"flecha": 1} and nieto.glifos == {"flecha": 1} and nieto.hijo_siguiente["glifos"] == {"barrera": 1},
		"%s · %s" % [str(h6.hijo_siguiente), str(nieto.hijo_siguiente)])
	# La receta del lanzador lleva el orden hasta el Hechizo.
	var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in ["flecha", "retardo", "barrera"]:
		receta.apply(g)
	var hr: Hechizo = receta.hechizo(fuego)
	_ok("C3 Receta3D: el orden de dibujo llega hasta el hijo (la caché distingue el orden)", hr.hijo_siguiente.get("glifos", {}) == {"barrera": 1} and receta._clave() != Lanzador3D.Receta3D.new(Vector2.RIGHT)._clave())
	# Una copia independiente (el lanzador copia el hechizo antes de lanzarlo): el hijo viaja con ella.
	_ok("C3 `copiar` conserva el hijo (el lanzador lanza una copia)", h.copiar().hijo_siguiente == h.hijo_siguiente and h.copiar().eventos.get("al_impactar", []).size() == 1)


func _c3_vuelo() -> void:
	await _limpiar()
	var h: Hechizo = Hechizo.construir(_rune("fire"), {"flecha": 1, "retardo": 1, "barrera": 1}, 1.0, false, ["flecha", "retardo", "barrera"]).con({"distancia_max": 3.8, "gravedad": 0.0})
	var c3: Vector2i = _libre + Vector2i(3, 0)
	var nacidos: Array = []              # los HechizoVivo que nacen, medidos al entrar en el árbol (el hijo de una barrera se borra enseguida: su SolidezV2 es la que vive)
	var al_nacer: Callable = func(n: Node) -> void:
		if n is HechizoVivo:
			nacidos.append({"profundidad": (n as HechizoVivo).h.profundidad, "solidez": (n as HechizoVivo).h.solidez, "elemento": (n as HechizoVivo).h.elemento, "viaja": (n as HechizoVivo).h.viaja})
	lanzador.child_entered_tree.connect(al_nacer)
	# (a) la flecha golpea a un goblin: el hijo nace en el punto del golpe
	var g: Combate3D = _goblin(c3)
	await avanzar(2)
	var solideces0: int = lanzador._solideces_v2.size()
	var zonas0: int = lanzador._zonas_v2.size()
	nacidos.clear()
	var v: HechizoVivo = _flecha(h)
	_volar(v)
	var causa_a: String = v.motivo_fin
	var finales_a: Array = v.finales_vistos.duplicate()
	_ok("C3 vuelo: la flecha para por GOLPE y salta al_impactar", causa_a == "golpe" and finales_a == ["al_impactar"], "%s %s" % [causa_a, str(finales_a)])
	await avanzar(2)
	var hijos: Array = nacidos.filter(func(d: Dictionary) -> bool: return int(d["profundidad"]) == 1)
	_ok("C3 vuelo: nace UN hijo, de profundidad 1, y es una BARRERA del elemento del padre (fuego), no otra flecha", hijos.size() == 1 and float(hijos[0]["solidez"]) > 0.0 and String(hijos[0]["elemento"]) == "fuego" and not bool(hijos[0]["viaja"]),
		"nacidos %s" % str(nacidos))
	_ok("C3 vuelo: la barrera del hijo existe de verdad (una SolidezV2 y la llama de la barrera de fuego)", lanzador._solideces_v2.size() == solideces0 + 1 and lanzador._zonas_v2.size() > zonas0, "solideces %d→%d · zonas %d→%d" % [solideces0, lanzador._solideces_v2.size(), zonas0, lanzador._zonas_v2.size()])
	var sol: Lanzador3D.SolidezV2 = lanzador._solideces_v2.back() if not lanzador._solideces_v2.is_empty() else null
	_ok("C3 vuelo: nace en el punto del impacto (la casilla del goblin, o una pegada)", sol != null and (sol.celdas.has(c3) or sol.celdas.has(c3 - Vector2i(1, 0))), str(sol.celdas.keys()) if sol != null else "sin solidez")
	_ok("C3 vuelo: el padre no dejó su propia barrera ni su zona al pararse como flecha de fuego «normal» con barrera fundida (solo UNA solidez en total)", lanzador._solideces_v2.size() == solideces0 + 1)
	await _limpiar()
	# (b) sin golpear a nadie: llega a su alcance y el hijo nace donde acaba (al_detenerse)
	var v2: HechizoVivo = _flecha(h)
	_volar(v2)
	var causa_b: String = v2.motivo_fin
	var finales_b: Array = v2.finales_vistos.duplicate()
	await avanzar(2)
	_ok("C3 vuelo: sin blanco, la flecha acaba por alcance (al_detenerse) y también deja su barrera", causa_b == "alcance" and finales_b == ["al_detenerse"] and lanzador._solideces_v2.size() == 1, "%s %s · solideces %d" % [causa_b, str(finales_b), lanzador._solideces_v2.size()])
	await _limpiar()
	# (c) el padre solo es flecha: sin ⧖ (la misma flecha sin hijo) no deja nada
	var h_sola: Hechizo = Hechizo.construir(_rune("fire"), {"flecha": 1}, 1.0, false, ["flecha"]).con({"distancia_max": 3.8, "gravedad": 0.0})
	var v3: HechizoVivo = _flecha(h_sola)
	_volar(v3)
	await avanzar(2)
	_ok("C3 control: la flecha sola no deja barrera", lanzador._solideces_v2.is_empty())
	await _limpiar()
	# (d) un proyectil que VUELVE a la mano (retorno) no deja el hijo al recogerlo
	var h_ret: Hechizo = Hechizo.construir(_rune("fire"), {"flecha": 1, "retardo": 1, "barrera": 1, "retorno": 1}, 1.0, false, ["flecha", "retorno", "retardo", "barrera"]).con({"distancia_max": 3.0, "gravedad": 0.0})
	var v4: HechizoVivo = _flecha(h_ret)
	var pasos: int = 0
	while v4.activo and pasos < 900:
		v4.paso(DT)
		pasos += 1
	var causa_d: String = v4.motivo_fin
	await avanzar(2)
	_ok("C3 vuelo: con ᛃ retorno el proyectil acaba al volver a la mano y NO deja el hijo allí (causa «retorno» excluida)", causa_d == "retorno" and lanzador._solideces_v2.is_empty(), "%s · solideces %d" % [causa_d, lanzador._solideces_v2.size()])
	await _limpiar()
	# (e) el hijo hereda la potencia (sobrecarga) y el pigmento del padre
	var hp: Hechizo = Hechizo.construir(_rune("fire"), {"flecha": 1, "retardo": 1, "barrera": 1}, 1.0, false, ["flecha", "retardo", "barrera"])
	var base_hijo: float = Hechizo.construir(_rune("fire"), {"barrera": 1}).dano
	hp.dano *= 2.0
	hp.potencia = 1.5
	var vp: HechizoVivo = HechizoVivo.preparar(hp, lanzador)
	var hijo: Hechizo = vp._hijo_de_pagina((hp.eventos["al_impactar"] as Array)[0] as Dictionary)
	_ok("C3 el hijo hereda la potencia (1,5) y la proporción del pigmento de daño (×2: %.1f → %.1f)" % [base_hijo, hijo.dano], hijo != null and is_equal_approx(hijo.potencia, 1.5) and absf(hijo.dano - base_hijo * 2.0) < 0.01)
	vp.free()
	lanzador.child_entered_tree.disconnect(al_nacer)
	await _limpiar()


func _c3_tinta_y_prevision() -> void:
	await _limpiar()
	# Por el camino REAL del libro: la página dibujada en ese orden lanza la flecha y la barrera nace al impactar.
	var salio: bool = lanzar("fuego", ["flecha", "retardo", "barrera"], ESTE)
	_ok("C3 libro: la página flecha + ⧖ + barrera se lanza", salio)
	await avanzar_s(2.0)
	_ok("C3 libro: la barrera del hijo se levantó donde acabó la flecha", lanzador._solideces_v2.size() == 1, "solideces %d" % lanzador._solideces_v2.size())
	await _limpiar()
	# La previsión de esa página no lanza ni crea hijos.
	colocar_jugador(_libre)
	_preparar("fuego", ["flecha", "retardo", "barrera"])
	var nodos_antes: int = lanzador.get_children().filter(func(n: Node) -> bool: return n is HechizoVivo).size()
	PrevisionHechizo.olvidar()
	var prev: Array[Dictionary] = PrevisionHechizo.prever(lanzador, lanzador._preparado, jugador.position, ESTE)
	var nodos_despues: int = lanzador.get_children().filter(func(n: Node) -> bool: return n is HechizoVivo).size()
	_ok("C3 previsión de la página con «al impactar»: no crea nodos ni solideces (en seco) y no revienta", nodos_antes == nodos_despues and lanzador._solideces_v2.is_empty() and prev is Array)
	var h_prev: Hechizo = lanzador.hechizo_de(lanzador._preparado)
	_ok("C3 el Hechizo preparado lleva el hijo y el recargo K_HIJO en su tinta", h_prev.hijo_siguiente.get("glifos", {}) == {"barrera": 1} and Dano.hijos_previstos(h_prev) == 1)
	lanzador._cancelar_modo()
	await _limpiar()
