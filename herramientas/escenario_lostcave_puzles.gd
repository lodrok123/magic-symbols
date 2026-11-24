extends "res://herramientas/escenario_base.gd"
## LOS PUZLES DE LOST CAVE, RESUELTOS EN EL JUEGO (24/11/2026, docs/PUZLES_LOSTCAVE_2026-11-24.md). Carga escenas/PruebaLostCave.tscn (kit «demo»:
## fuego, agua y tierra con flecha, línea, barrera, altura, ᚱ y suelo) y resuelve cada puzle como la jugadora: hechizos de verdad
## (`lanzar_pagina_ya`), empujar rocas andando (teclas) y girar el prisma (lo mismo que hace E). Lo único hecho por código es MATAR a los
## enemigos de la sala del gólem (LC7): aquí se prueba la regla del cerrojo, no el combate.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_lostcave_puzles.gd
## Necesita las piezas lost_* generadas (tools\preparar_lostcave.cmd); sin ellas el mapa carga, pero la solidez del decorado cambia.

const RUTA: String = "res://escenas/PruebaLostCave.tscn"
const T_TINTA_MAX_S: float = 8.0

var _pz: Puzle3D = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D if maqueta != null else null
	_ok("0 Puzle3D monta Lost Cave sin avisos", _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "sin Puzle3D")
	if _pz == null:
		return
	_ok("0 kit demo: fuego, agua, tierra, barrera, línea y ᚱ", Repertoire.element_active("fuego") and Repertoire.element_active("agua")
		and Repertoire.element_active("tierra") and Repertoire.sigil_active("barrera") and Repertoire.sigil_active("linea") and Repertoire.sigil_active("raido"))
	await avanzar_s(0.5)
	await _lc7()
	await _lc5()
	await _lc1()
	await _lc2()
	await _lc4()
	await _lc3()
	await _lc6()


# --- ayudas -----------------------------------------------------------------------------------------------------------

func _n(id: String) -> Node:
	return _pz.nodo(id)


func _esperar(cond: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return bool(cond.call())


## Lanza desde donde está la jugadora hacia `objetivo`. `en_punto`: el hechizo nace en el punto apuntado (la barrera de tierra), recortado al
## alcance de origen, como con el ratón. Rellena la tinta antes (no se prueba el gasto) y reintenta si el libro aún no está listo.
func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i, en_punto: bool = false) -> bool:
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		jugador.tinta.actual = jugador.tinta.maxima
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		var origen: Vector3 = yo
		if en_punto:
			var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
			origen = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, origen, hacia.normalized()):
			return true
		t += await avanzar_s(0.5)
	return false


## La jugadora se pone detrás de la roca y la empuja una casilla hacia `dir` (`BloqueEmpujable3D.empujar`, lo que dispara el empuje andando).
func _empujar(r, dir: Vector2i) -> bool:
	colocar_jugador(r.celda - dir)
	await avanzar(3)
	var cedio: bool = r.empujar(dir, true)
	await _esperar(func() -> bool: return not r.moviendo, 12.0)
	await avanzar(2)
	return cedio


func _en(c: Vector2i) -> void:
	colocar_jugador(c)
	await avanzar_s(0.4)


# --- LC7 · CRUCE · sala del gólem ---------------------------------------------------------------------------------------

func _lc7() -> void:
	var cerrojo = _n("lc7_cerrojo")
	var vigia = _n("lc7_guardia")
	_ok("7 LC7: cerrojo y vigía montados", cerrojo != null and vigia != null)
	if cerrojo == null:
		return
	_ok("7 LC7: las bocas nacen ABIERTAS (se entra a la sala por la boca)", not cerrojo.cerrado and not Terreno3D.bloqueada(Vector2i(15, 16)))
	var llego: bool = await mover_hacia(Vector2i(15, 13), 12.0)
	await _esperar(func() -> bool: return cerrojo.cerrado, 2.0)
	_ok("7 LC7: al entrar al cruce se cierran las bocas (boca, mina y cristales)", llego and cerrojo.cerrado and Terreno3D.bloqueada(Vector2i(7, 11))
		and Terreno3D.bloqueada(Vector2i(23, 11)) and Terreno3D.bloqueada(Vector2i(15, 16)), "llegó %s, cerrado %s" % [llego, cerrojo.cerrado])
	var enemigos: Array = _enemigos_cruce()
	_ok("7 LC7: en la sala hay un gólem y dos limos", enemigos.size() == 3, "%d" % enemigos.size())
	for e in enemigos:
		e.call("_morir")                  # por código: el combate no es lo que se prueba aquí
	var abre: bool = await _esperar(func() -> bool: return not cerrojo.cerrado, 8.0)
	_ok("7 LC7: caídos los tres, las bocas se abren y queda la flag", abre and Flags.i().tiene("lostcave.cruce.limpio") and not Terreno3D.bloqueada(Vector2i(7, 11)))
	jugador.set("vida", jugador.get("vida_max") if jugador.get("vida_max") != null else 100)


func _enemigos_cruce() -> Array:
	var r: Array = []
	for n in maqueta.find_children("*", "", true, false):
		if n is Combate3D and not (n as Combate3D).is_queued_for_deletion():
			var c: Vector2i = Terreno3D.celda_de((n as Node3D).global_position)
			if c.x >= 8 and c.x <= 22 and c.y >= 8 and c.y <= 14:
				r.append(n)
	return r


# --- LC5 · CRUCE · la grieta que suena ----------------------------------------------------------------------------------

func _lc5() -> void:
	var pared = _n("lc5_hueca")
	_ok("5 LC5: la pared hueca está cerrada y tapa (12,15)", pared != null and not pared.abierta and Terreno3D.bloqueada(Vector2i(12, 15)))
	if pared == null:
		return
	await _en(Vector2i(12, 12))
	_ok("5 LC5: fuego + ᚱ sobre la veta que lleva a la pared sale", await _lanzar("fuego", ["raido"], Vector2i(12, 13)))
	var abre: bool = await _esperar(func() -> bool: return pared.abierta, 5.0)
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.3)
	_ok("5 LC5: el pulso de la jugadora la abre y deja ver el nicho con el cofre", abre and not Terreno3D.bloqueada(Vector2i(12, 15)) and Flags.i().tiene("lostcave.cruce.grieta"))


# --- LC1 · MINA · la voladura -------------------------------------------------------------------------------------------

func _lc1() -> void:
	var muro = _n("lc1_muro")
	_ok("1 LC1: el muro tapa la galería (3,17)", muro != null and Terreno3D.bloqueada(Vector2i(3, 17)))
	if muro == null:
		return
	await _en(Vector2i(4, 14))
	_ok("1 LC1: flecha de fuego al barril de la vía (3,16)", await _lanzar("fuego", ["flecha"], Vector2i(3, 16)))
	var roto: bool = await _esperar(func() -> bool: return muro.roto_ya, 5.0)
	await avanzar_s(1.0)
	_ok("1 LC1: el barril explota y rompe el muro: la galería se abre", roto and not Terreno3D.bloqueada(Vector2i(3, 17)))


# --- LC2 · MINA · la balanza --------------------------------------------------------------------------------------------

func _lc2() -> void:
	var reja = _n("lc2_reja")
	var a = _n("lc2_placa_a")
	var b = _n("lc2_placa_b")
	var c = _n("lc2_placa_c")
	var rm = _n("lc2_roca_m")
	var rp = _n("lc2_roca_p")
	_ok("2 LC2: tres placas, dos rocas y la reja cerrada", reja != null and a != null and b != null and c != null and rm != null and rp != null and not reja.abierta)
	if reja == null or rm == null or rp == null:
		return
	# Empujar: la mediana de (4,9) a la placa de 2 (4,7) y la pequeña de (2,9) a la placa de 1 (2,7), dos empujones al norte cada una, con la jugadora
	# detrás (como `prueba_rocas_empujables._empujar_a_pie`: el empuje con teclas ya lo prueba esa batería).
	for i in 2:
		await _empujar(rm, Vector2i(0, -1))
	await avanzar_s(0.6)
	_ok("2 LC2: la roca mediana, empujada al norte, queda sobre la placa de 2", rm.celda == Vector2i(4, 7) and a.activo, "roca en %s, placa %s" % [str(rm.celda), a.activo])
	for i in 2:
		await _empujar(rp, Vector2i(0, -1))
	await avanzar_s(0.6)
	_ok("2 LC2: la pequeña queda sobre la placa de 1", rp.celda == Vector2i(2, 7) and b.activo, "roca en %s, placa %s" % [str(rp.celda), b.activo])
	_ok("2 LC2 [legible]: con dos placas de tres la reja sigue cerrada", not reja.abierta)
	# La tercera, con tierra.
	await _en(Vector2i(6, 8))
	_ok("2 LC2: tierra + barrera (nace donde apuntas) sobre la tercera placa (6,6)", await _lanzar("tierra", ["barrera"], Vector2i(6, 6), true))
	var abre: bool = await _esperar(func() -> bool: return reja.abierta, 4.0)
	_ok("2 LC2: el bloque de tierra pesa 1, las tres placas pisadas abren la reja del nicho", abre, "placa C %s (peso %d)" % [c.activo, c.peso_en_casilla()])


# --- LC4 · CRISTALES · rojo y azul ---------------------------------------------------------------------------------------

func _lc4() -> void:
	var prisma = _n("lc4_prisma")
	var rf = _n("lc4_rec_fuego")
	var ra = _n("lc4_rec_agua")
	var cofre = _n("lc4_cofre")
	_ok("4 LC4: cristal, prisma (mirando al oeste), dos receptores y el cofre oculto", prisma != null and rf != null and ra != null and cofre != null
		and prisma.dir == "o" and cofre.es_oculto)
	if prisma == null or rf == null or ra == null:
		return
	await _en(Vector2i(25, 11))
	_ok("4 LC4: flecha de fuego al cristal dormido", await _lanzar("fuego", ["flecha"], Vector2i(27, 11)))
	await avanzar_s(2.0)
	_ok("4 LC4 [legible]: con el prisma mirando a la entrada no se activa nada", not rf.activo and not ra.activo, "emisiones %d" % prisma.emisiones)
	prisma.girar()                               # lo que hace E: un cuarto de vuelta (oeste -> norte)
	await avanzar_s(0.6)
	_ok("4 LC4: un giro: el prisma mira al norte (fuego)", prisma.dir == "n", prisma.dir)
	await _en(Vector2i(25, 11))
	_ok("4 LC4: fuego al cristal otra vez", await _lanzar("fuego", ["flecha"], Vector2i(27, 11)))
	_ok("4 LC4: el pulso de fuego llega al receptor rojo", await _esperar(func() -> bool: return rf.activo, 4.0), "emisiones %d" % prisma.emisiones)
	for i in 2:
		prisma.girar()
		await avanzar_s(0.6)
	_ok("4 LC4: dos giros más: mira al sur (agua)", prisma.dir == "s", prisma.dir)
	await _en(Vector2i(25, 11))
	_ok("4 LC4: flecha de agua al cristal", await _lanzar("agua", ["flecha"], Vector2i(27, 11)))
	_ok("4 LC4: el pulso de agua llega al receptor azul", await _esperar(func() -> bool: return ra.activo, 4.0))
	_ok("4 LC4: con los dos aparece el cofre épico", await _esperar(func() -> bool: return not cofre.es_oculto, 3.0))


# --- LC3 · el puente caído ----------------------------------------------------------------------------------------------

func _lc3() -> void:
	var huecos: Array[Vector2i] = [Vector2i(15, 6), Vector2i(15, 7)]
	_ok("3 LC3: el pasillo al santuario es precipicio (sin suelo, no se pisa)", Terreno3D.es_vacio(huecos[0]) and Terreno3D.es_vacio(huecos[1]))
	await _en(Vector2i(15, 10))
	var sin_puente: bool = await mover_hacia(Vector2i(15, 4), 4.0)
	_ok("3 LC3 [legible]: andando no se cruza", not sin_puente and celda_jugador().y >= 8, str(celda_jugador()))
	await _en(Vector2i(15, 9))
	_ok("3 LC3: tierra + barrera + 2 líneas desde el borde (15,8) hacia el norte sale",
		await _lanzar("tierra", ["barrera", "linea_x", "linea_z"], Vector2i(15, 8), true))
	await avanzar_s(0.5)
	_ok("3 LC3: el puente de tierra cubre las dos casillas del vacío", Terreno3D.plataformas_tierra.has(huecos[0]) and Terreno3D.plataformas_tierra.has(huecos[1]),
		str(Terreno3D.plataformas_tierra.keys()))
	await avanzar_s(1.0)
	var pasos: Array = []
	for meta in [Vector2i(15, 8), Vector2i(15, 6), Vector2i(15, 4)]:
		pasos.append("%s:%s" % [str(meta), await mover_hacia(meta, 8.0)])
	_ok("3 LC3: se cruza andando al santuario", celda_jugador().y <= 5, "%s en %s, y_pies(15,8)=%.2f y_pies(15,9)=%.2f" % [str(pasos), str(celda_jugador()),
		Terreno3D.y_pies(Vector2i(15, 8)), Terreno3D.y_pies(Vector2i(15, 9))])


# --- LC6 · SANTUARIO · los tres sellos ----------------------------------------------------------------------------------

func _lc6() -> void:
	var est = _n("lc6_estatuas")
	var cofre = _n("lc6_cofre")
	_ok("6 LC6: tres estatuas y el cofre legendario oculto", est != null and cofre != null and cofre.es_oculto)
	if est == null:
		return
	var orden: Array = [["fuego", Vector2i(13, 3)], ["agua", Vector2i(15, 3)], ["tierra", Vector2i(17, 3)]]
	for i in orden.size():
		var el: String = orden[i][0]
		var c: Vector2i = orden[i][1]
		await _en(c + Vector2i(0, 1))
		# Como en escenario_cueva_completa: la tierra lleva flecha (sin ella el hechizo de tierra no sale hacia la casilla de la estatua, que está ocupada).
		_ok("6 LC6: %s + ᚱ a la estatua %d" % [el, i + 1], await _lanzar(el, ["raido", "flecha"] if el == "tierra" else ["raido"], c))
		var ok: bool = await _esperar(func() -> bool: return est.paso >= i + 1, 4.0)
		_ok("6 LC6: la estatua %d (%s) se enciende" % [i + 1, el], ok, "paso %d" % est.paso)
		await avanzar_s(1.0)
	_ok("6 LC6: completa la secuencia (flag) y aparece el cofre legendario delante del portal",
		await _esperar(func() -> bool: return Flags.i().tiene("lostcave.santuario.estatuas") and not cofre.es_oculto, 4.0))
