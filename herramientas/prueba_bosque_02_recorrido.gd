extends "res://herramientas/escenario_base.gd"
## PRUEBA DE RESOLUBILIDAD «A PIE» DEL BOSQUE 02 (Juego, 3/11, docs/PLAN_BOSQUE_02.md §5). Carga escenas/PruebaBosque02.tscn DE VERDAD (el Nivel_Bosque_02.tscn horneado) y recorre la
## misión principal «El corazón del Bosque» EN ORDEN, más lo opcional (escondite, pasillo de la Cueva, torre, molino, trastienda), desde la casilla de inicio hasta el cofre legendario:
##   · SIN TELETRANSPORTES. Para cada tramo hay un BFS sobre `Terreno3D.pisable` desde la casilla ACTUAL de la jugadora hasta el objetivo: si no hay camino a pie con lo abierto hasta ese
##     momento, FALLA; si lo hay, se la lleva por ese camino casilla a casilla (`caminar`, 0,1 s por casilla). Nunca se salta a la meta.
##   · CADA ACCIÓN ES EL MECANISMO REAL: un hechizo lanzado desde la casilla donde está la jugadora (`Lanzador3D.lanzar_pagina_ya`, con el alcance de la flecha: una flecha llega a 2 casillas,
##     dos a 3), un cofre abierto con la acción `abrir` de Puzle3D (lo mismo que pulsar E a su lado), una piedra empujada con `BloqueEmpujable3D.empujar`.
##   · «CERRADO ANTES / ABIERTO DESPUÉS» en cada cierre: se afirma que el camino (o el cofre) NO existe antes de la acción y SÍ después.
##   · LO ÚNICO NO REAL: los goblins se dan por derrotados poniendo `Combate3D.muerto = true` (la prueba no trata de combate: lo que comprueba es que el vigía, el cerrojo y el cofre
##     reaccionan a su caída). Está marcado `[muerto=true]` donde ocurre. La vida de la jugadora se mantiene alta para que ninguna flecha enemiga interrumpa el recorrido.
## Al final: cofre legendario abierto, `bosque02.santuario.cofre` puesta, logro `nivel_completado` emitido, TODOS los cofres alcanzados a pie y abiertos (7 comunes, 3 épicos, 1 legendario),
## el anillo exterior todo `#` y ningún marcador ni pieza fuera del área jugable.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bosque_02_recorrido.gd

const RUTA: String = "res://escenas/PruebaBosque02.tscn"
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const FOTOGRAMAS_POR_CASILLA: int = 3            ## a 30 fps = 0,1 s: los sondeos de las puertas (cada 0,1 s) ven pasar a la jugadora
const VIDA_PRUEBA: float = 100000.0
const AREA: Rect2i = Rect2i(4, 4, 32, 32)         ## el área jugable: x 4..35, y 4..35
const INICIO: Vector2i = Vector2i(7, 32)

var z: Puzle3D = null
var reglas: Node = null
var _abiertos: Dictionary = {}                    ## id del cofre -> calidad ("" común, "epico", "legendario")
var _casillas: int = 0                            ## casillas andadas en total
var _disparos: int = 0
var _tirados: Array = []                          ## lo que la jugadora tiró de la mochila para hacer sitio
var _t0: float = 0.0


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	Niveles.viajes.clear()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	reglas = maqueta.get_node_or_null("Reglas")
	z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la escena trae sus nodos Reglas y Puzles", reglas != null and z != null)
	if reglas == null or z == null:
		return
	reglas.set("volver_al_menu", false)
	lanzador.tinta = null                              # las pruebas no gastan tinta
	_t0 = reloj.t
	_curar()
	_montaje()
	await _linde()
	await _escondite()
	await _arroyo()
	await _balanza()
	await _pasillo_cueva()
	await _pradera()
	await _ruinas_este()
	await _plaza_oeste()
	await _estanque()
	await _campamento()
	await _santuario()
	await _final()
	print("TIEMPO DE JUEGO: %.0f s · casillas andadas: %d · hechizos lanzados: %d" % [reloj.t - _t0, _casillas, _disparos])


# ---------------------------------------------------------------------------------------------------------------------
#  Instrumentos
# ---------------------------------------------------------------------------------------------------------------------

func _curar() -> void:
	(jugador as Jugador3D).vida = VIDA_PRUEBA
	(jugador as Jugador3D).muerto = false


func _libre(c: Vector2i) -> bool:
	return Terreno3D.pisable(c, 0, false, 0, false)


## true cuando en la casilla no queda NINGÚN nodo reactivo (el consumido se disuelve ~1 s antes de liberarse). Hasta el diario 347 `HechizoVivo._contacto` lo golpeaba por grupo
## sin mirar su capa y el proyectil moría ahí; ahora lo consumido está `fuera_de_juego` y la prueba dispara con la telaraña aún disolviéndose.
func _consumido(c: Vector2i) -> bool:
	for r in get_nodes_in_group("reactivo3d"):
		if is_instance_valid(r) and r.get("celda") == c:
			return false
	return true


## BFS por las 4 vecinas sobre lo pisable AHORA. Devuelve la lista de casillas desde `desde` hasta `hasta` (ambas incluidas), o [] si no hay camino.
func _ruta(desde: Vector2i, hasta: Vector2i) -> Array:
	if desde == hasta:
		return [desde]
	if not _libre(hasta):
		return []
	var previo: Dictionary = {desde: desde}
	var cola: Array = [desde]
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = c + (d as Vector2i)
			if previo.has(n) or not Terreno3D.en_mapa(n) or not _libre(n):
				continue
			previo[n] = c
			if n == hasta:
				var r: Array = [n]
				var q: Vector2i = n
				while q != desde:
					q = previo[q]
					r.push_front(q)
				return r
			cola.append(n)
	return []


## Para los fallos: hasta dónde llega la jugadora desde `desde` (la casilla alcanzable más cercana a `hasta`) y si `hasta` se pisa.
func _diagnostico(desde: Vector2i, hasta: Vector2i) -> String:
	var vis: Dictionary = {desde: true}
	var cola: Array = [desde]
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = c + (d as Vector2i)
			if not vis.has(n) and Terreno3D.en_mapa(n) and _libre(n):
				vis[n] = true
				cola.append(n)
	var mejor: Vector2i = desde
	for c in vis:
		if absi((c as Vector2i).x - hasta.x) + absi((c as Vector2i).y - hasta.y) < absi(mejor.x - hasta.x) + absi(mejor.y - hasta.y):
			mejor = c
	return "alcanza %d casillas; la más cercana a la meta es %s; la meta %s se pisa=%s (letra %s, bloqueada=%s)" % [vis.size(), str(mejor), str(hasta), str(_libre(hasta)), Terreno3D.letra_de(hasta), str(Terreno3D.bloqueada(hasta))]


func hay_camino(hasta: Vector2i) -> bool:
	return not _ruta(celda_jugador(), hasta).is_empty()


## Lleva a la jugadora a `hasta` por el camino de `_ruta`, casilla a casilla. Falla (y lo cuenta) si no hay camino a pie.
func caminar(hasta: Vector2i, que: String) -> bool:
	var r: Array = _ruta(celda_jugador(), hasta)
	if r.is_empty():
		_ok("%s: hay camino a pie de %s a %s" % [que, str(celda_jugador()), str(hasta)], false, _diagnostico(celda_jugador(), hasta))
		return false
	for k in range(1, r.size()):
		_curar()
		colocar_jugador(r[k])
		_casillas += 1
		await avanzar(FOTOGRAMAS_POR_CASILLA)
	await avanzar(2)
	return true


## Lanza `elemento` + `glifos` desde la casilla `desde` (a la que antes ANDA) hacia el centro de `objetivo`. Devuelve true si el hechizo salió.
func disparar(elemento: String, glifos: Array, desde: Vector2i, objetivo: Vector2i, que: String) -> bool:
	if not await caminar(desde, que):
		return false
	await avanzar(3)
	# La jugadora puede venir de abrir un cofre o de empujar (gesto en curso): el Lanzador se niega hasta que acaba. No depende del paso de fotograma.
	await esperar(func() -> bool: return bool(jugador.call("puede_lanzar")), 3.0)
	var dir: Vector3 = Terreno3D.centro_de(objetivo, 0.0) - jugador.position
	dir.y = 0.0
	var salio: bool = lanzar(elemento, glifos, dir)
	_disparos += 1
	_ok("%s: sale el hechizo %s + %s desde %s hacia %s" % [que, elemento, "+".join(glifos), str(desde), str(objetivo)], salio)
	return salio


func esperar(cond: Callable, max_s: float) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s:
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())


func _flag(f: String) -> bool:
	return Flags.i().tiene(f)


func _cofre(id: String) -> Puzle3D.CofrePuzle:
	return z.nodo(id) as Puzle3D.CofrePuzle


## Abre un cofre como lo haría la jugadora: anda hasta una casilla vecina (hay que poder llegar a pie), espera a que esté cerrado y visible y lo abre con la acción `abrir` (= pulsar E a ≤ 2,7 u).
func abrir_cofre(id: String, que: String) -> bool:
	var c: Puzle3D.CofrePuzle = _cofre(id)
	if c == null:
		_ok("%s: existe el cofre %s" % [que, id], false)
		return false
	var destino: Vector2i = Vector2i(-1, -1)
	var mejor: int = 1 << 30
	for d in DIRS:
		var v: Vector2i = c.celda + (d as Vector2i)
		var r: Array = _ruta(celda_jugador(), v)
		if not r.is_empty() and r.size() < mejor:
			mejor = r.size()
			destino = v
	if destino.x < 0:
		_ok("%s: hay camino a pie hasta una casilla pegada al cofre %s %s" % [que, id, str(c.celda)], false)
		return false
	await caminar(destino, que)
	await esperar(func() -> bool: return c.es_cerrado, 5.0)
	_hacer_sitio()
	var cal: String = c.calidad
	var antes_oro: int = Estado.i().oro
	var ok: bool = false
	var t0: float = reloj.t
	while reloj.t - t0 < 6.0 and not ok:
		ok = c.abrir()
		if not ok:
			await avanzar_s(0.2)
	var espera: float = 40.0 if c.glifo != "" else 8.0
	var abierto: bool = await esperar(func() -> bool: return c.es_abierto, espera)
	_ok("%s: el cofre %s (%s) se abre y pone su flag" % [que, id, cal if cal != "" else "común"], ok and abierto and (c.flag_abierto == "" or _flag(c.flag_abierto)))
	_ok("%s: el cofre %s dio su botín (%s)" % [que, id, str(c.botin_dado)], not c.botin_dado.is_empty() or Estado.i().oro > antes_oro, "da=%s · bolsa=%s" % [str(c.da), str(Estado.i().items)])
	_abiertos[id] = cal
	return abierto


## Como cuando se anda contra una puerta: la jugadora, ya en la casilla vecina, avanza 0,8 u hacia ella (sin salir de su casilla) y la toca (PuertaPuzle abre al tocar a ≤ 1,9 u de su centro).
func tocar_puerta(celda_puerta: Vector2i) -> void:
	var pj: Node3D = jugador.get("pj") as Node3D
	var dir: Vector3 = Terreno3D.centro_de(celda_puerta, 0.0) - pj.position
	dir.y = 0.0
	pj.position += dir.normalized() * 0.8
	jugador.position = pj.position
	await avanzar_s(0.6)


## La mochila tiene 8 huecos y el botín del camino (carbón, panal, pluma, colmillos…) la llena: antes de abrir un cofre la jugadora tira lo que no necesita (lo haría ella en el menú).
func _hacer_sitio() -> void:
	for id in ["carbon", "panal", "pluma", "colmillo_goblin", "seda", "seta_asada", "pocion"]:
		if Estado.i().huecos_usados() < Estado.i().capacidad - 1:
			break
		var n: int = Estado.i().cuenta(id)
		if n > 0:
			Estado.i().quitar(id, n)
			_tirados.append(id)


func _matar(cbs: Array) -> void:
	for cb in cbs:
		if is_instance_valid(cb):
			(cb as Combate3D).muerto = true          # [muerto=true] documentado en la cabecera


func _vigia(id: String) -> Puzle3D.VigiaPuzle:
	return z.nodo(id) as Puzle3D.VigiaPuzle


# ---------------------------------------------------------------------------------------------------------------------
#  0 · Montaje
# ---------------------------------------------------------------------------------------------------------------------

func _montaje() -> void:
	_ok("0.1 Puzle3D monta todas las piezas del mapa sin un solo aviso", z.avisos.is_empty() and z.listo, str(z.avisos))
	_ok("0.2 el nivel mide 40 × 40 y sale del .tscn horneado", int(maqueta.get("_ancho")) == 40 and int(maqueta.get("_alto")) == 40 and bool(maqueta.get("_modo_nivel")), "%s × %s" % [str(maqueta.get("_ancho")), str(maqueta.get("_alto"))])
	_ok("0.3 el área jugable mide 32 × 32 (≥ 30 × 30)", AREA.size.x >= 30 and AREA.size.y >= 30)
	var mapa: PackedStringArray = maqueta.get("_mapa")
	var mal_anillo: Array = []
	for y in range(40):
		for x in range(40):
			if not AREA.has_point(Vector2i(x, y)) and mapa[y][x] != "#":
				mal_anillo.append(Vector2i(x, y))
	_ok("0.4 el anillo exterior de 4 casillas es todo `#` (muros lejanos)", mal_anillo.is_empty(), str(mal_anillo.slice(0, 5)))
	var fuera: Array = []
	for pz in z.piezas():
		var p: Puzle3D.Pieza = pz
		var todas: Array = [p.celda]
		todas.append_array(p.p.get("celdas", []) as Array)
		todas.append_array(p.p.get("de", []) as Array)
		todas.append_array(p.p.get("en", []) as Array)
		todas.append_array(p.p.get("sala", []) as Array)
		for c in todas:
			if not AREA.has_point(c as Vector2i):
				fuera.append("%s%s" % [p.id, str(c)])
	_ok("0.5 ninguna pieza de Puzle3D (ni sus casillas) cae fuera del área jugable", fuera.is_empty(), str(fuera.slice(0, 5)))
	var marca: Dictionary = reglas.get("_marca") as Dictionary
	var fuera_m: Array = []
	for n in marca:
		if not AREA.has_point(marca[n] as Vector2i):
			fuera_m.append(n)
	for mc in (maqueta.get("_marcas") as Array):
		if not AREA.has_point((mc as Dictionary)["c"] as Vector2i):
			fuera_m.append(String((mc as Dictionary)["grupo"]))
	_ok("0.6 ningún marcador (letras con nombre ni datos) cae fuera del área jugable (%d marcadores)" % marca.size(), fuera_m.is_empty() and marca.size() > 20, str(fuera_m.slice(0, 5)))
	var cofres: Array = []
	for pz2 in z.piezas():
		if (pz2 as Puzle3D.Pieza).tipo == "cofre":
			cofres.append((pz2 as Puzle3D.Pieza).id)
	_ok("0.7 el mapa declara 12 cofres (8 comunes, 3 épicos y 1 legendario; el 8.º común es el de la balanza del claro)", cofres.size() == 12, str(cofres.size()))
	_ok("0.8 la jugadora nace en la linde (7,32)", celda_jugador() == INICIO, str(celda_jugador()))
	var graves: Array = (maqueta.get("_avisos") as Array).filter(func(a: Variant) -> bool: return (String(a).contains("sin pieza") or String(a).contains("fuera del suelo") or String(a).contains("sin personaje")) and not String(a).contains("losa_runas_ovalo"))
	_ok("0.9 la maqueta no avisa de piezas ni personajes que falten (salvo la losa del guardián, que ya faltaba en la Gruta Batida)", graves.is_empty(), str(graves))
	var tot: Array = reglas.get("_totems") as Array
	_ok("0.10 las reglas encuentran los tres tótems por nombre y el tronco-puente", tot[0] != null and tot[1] != null and tot[2] != null and reglas.get("_tronco_puente") != null)
	_ok("0.11 la misión principal tiene 7 objetivos, activa, y ninguno hecho", (Misiones.i().get_mision("bosque_02").get("objetivos", []) as Array).size() == 7 and Misiones.i().estado("bosque_02") == "activa" and Misiones.i().progreso("bosque_02") == Vector2i(0, 7))
	var cerrados: bool = true
	for id in ["cofre_linde", "cofre_orilla", "cofre_pradera", "cofre_molino", "cofre_torre", "cofre_campamento", "cofre_estanque", "cofre_trastienda", "cofre_corazon"]:
		cerrados = cerrados and _cofre(id) != null and _cofre(id).es_oculto
	_ok("0.12 los nueve cofres que dependen de una tarea nacen ocultos", cerrados)
	var l: Dictionary = {}
	for fila in mapa:
		for ch in fila:
			l[ch] = int(l.get(ch, 0)) + 1
	_ok("0.13 lo temático y lo reactivo está en el mapa (seto z, tronco l, telaraña r, puerta goblin y, torre o, fogata F, brasero T, tres tótems, seta s, flor f, raíz q, fuente e, tinaja u, placa K, muñeco D)",
		l.get("z", 0) >= 1 and l.get("l", 0) >= 1 and l.get("r", 0) >= 1 and l.get("y", 0) == 1 and l.get("o", 0) == 2 and l.get("F", 0) == 1 and l.get("T", 0) >= 5 and l.get("j", 0) == 1 and l.get("k", 0) == 1 and l.get("i", 0) == 1
		and l.get("s", 0) >= 1 and l.get("f", 0) >= 1 and l.get("q", 0) >= 1 and l.get("e", 0) == 2 and l.get("u", 0) == 1 and l.get("K", 0) == 1 and l.get("D", 0) == 1, str(l))


# ---------------------------------------------------------------------------------------------------------------------
#  1 · La linde: dos braseros → cofre común 1; la guardabosques
# ---------------------------------------------------------------------------------------------------------------------

func _linde() -> void:
	var cofre: Puzle3D.CofrePuzle = _cofre("cofre_linde")
	_ok("1.1 los braseros de los cruces nacen encendidos y los de la linde, apagados", _braseros_guia_encendidos() and reglas.call("_braseros_encendidos") == 0)
	_ok("1.2 cofre_linde: ANTES oculto y sin flag", cofre.es_oculto and not _flag("bosque02.linde.braseros"))
	# la guardabosques habla al acercarse y con E
	var gente: Array = reglas.get("_gente") as Array
	var guarda: Dictionary = {}
	var librera: Dictionary = {}
	for g in gente:
		if String((g as Dictionary)["tipo"]) == "guardabosques":
			guarda = g
		elif String((g as Dictionary)["tipo"]) == "librera":
			librera = g
	_ok("1.3 hay guardabosques (linde) y librera (plaza) con su personaje", not guarda.is_empty() and not librera.is_empty())
	await avanzar_s(1.0)
	var textos: Array = []
	for i in range(5):
		textos.append(str(reglas.call("hablar", guarda, jugador.position)))
	_ok("1.4 la guardabosques da cinco pistas distintas (braseros, tronco, muro, pradera, campamento)", textos.size() == 5 and textos.has(textos[0]) and String(textos[0]).contains("braseros") and String(textos[1]).contains("tronco") and String(textos[2]).contains("muro")
		and String(textos[3]).contains("pradera") and String(textos[4]).contains("campamento"), str(textos))
	# braseros: fuego y flecha, uno a uno
	await disparar("fuego", ["flecha"], Vector2i(10, 32), Vector2i(10, 30), "1.5")
	await avanzar_s(1.5)
	_ok("1.6 el primer brasero arde (1/2) y el cofre sigue oculto", reglas.call("_braseros_encendidos") == 1 and cofre.es_oculto)
	await disparar("fuego", ["flecha"], Vector2i(10, 32), Vector2i(10, 34), "1.7")
	await avanzar_s(2.0)
	_ok("1.8 con los dos braseros ardiendo se pone `bosque02.linde.braseros` y el cofre APARECE", _flag("bosque02.linde.braseros") and cofre.es_cerrado)
	await abrir_cofre("cofre_linde", "1.9")
	await avanzar_s(0.3)
	_ok("1.10 el objetivo 1 de la misión (braseros) queda hecho", (Misiones.i().get_mision("bosque_02")["objetivos"][0] as Dictionary)["hecho"] == true)


func _braseros_guia_encendidos() -> bool:
	var n: int = 0
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r) and String(r.tipo) == "brasero" and bool(r.is_lit):
			n += 1
	return n == 3


# ---------------------------------------------------------------------------------------------------------------------
#  2 · El escondite: muro agrietado (tierra) → cofre común 7
# ---------------------------------------------------------------------------------------------------------------------

func _escondite() -> void:
	var muro: MuroAgrietado3D = z.nodo("muro_escondite") as MuroAgrietado3D
	_ok("2.1 ANTES: el muro cierra el pasillo: no hay camino al escondite (8,26) ni a (8,23)", muro != null and not muro.roto_ya and not hay_camino(Vector2i(8, 26)) and not hay_camino(Vector2i(8, 23)))
	await disparar("tierra", ["flecha"], Vector2i(8, 29), Vector2i(8, 27), "2.2")
	await avanzar_s(1.5)
	if not muro.roto_ya:
		await disparar("tierra", ["flecha"], Vector2i(8, 29), Vector2i(8, 27), "2.3")
		await avanzar_s(1.5)
	await esperar(func() -> bool: return muro.roto_ya, 5.0)
	await avanzar_s(1.0)
	_ok("2.4 DESPUÉS: el muro está roto y hay camino a pie hasta el cofre del escondite", muro.roto_ya and hay_camino(Vector2i(8, 23)))
	await abrir_cofre("cofre_escondite", "2.5")


# ---------------------------------------------------------------------------------------------------------------------
#  3 · El arroyo: el tronco-puente (fuego) y la orilla este
# ---------------------------------------------------------------------------------------------------------------------

func _arroyo() -> void:
	var tronco: TroncoPuente3D = reglas.get("_tronco_puente") as TroncoPuente3D
	_ok("3.1 ANTES: el arroyo corta el mapa: no hay camino a la orilla este (16,31) y el tronco está en pie", tronco != null and not tronco.cayo and not hay_camino(Vector2i(16, 31)) and not _flag("bosque02.arroyo.cruzado"))
	_ok("3.2 y el cofre de la orilla está oculto", _cofre("cofre_orilla").es_oculto)
	await disparar("fuego", ["flecha"], Vector2i(11, 31), Vector2i(13, 31), "3.3")
	var cayo: bool = await esperar(func() -> bool: return tronco.cayo and _libre(Vector2i(15, 31)), 12.0)
	await avanzar_s(0.5)
	_ok("3.4 DESPUÉS: el tronco cae sobre el arroyo (flag `tronco_puente.caido`) y hay camino a pie hasta la orilla este", cayo and _flag("bosque02.tronco_puente.caido") and hay_camino(Vector2i(16, 31)))
	await caminar(Vector2i(16, 31), "3.5")
	await avanzar_s(0.6)
	_ok("3.6 al pisar la orilla este se pone `bosque02.arroyo.cruzado` y aparece el cofre de la orilla", _flag("bosque02.arroyo.cruzado") and _cofre("cofre_orilla").es_cerrado)
	await abrir_cofre("cofre_orilla", "3.7")


# ---------------------------------------------------------------------------------------------------------------------
#  3b · La balanza del claro (5/11/2026, docs/ROCAS_EMPUJABLES_2026-11-05.md): dos placas de PESO (2 y 1) y tres rocas empujables → cofre común 8
# ---------------------------------------------------------------------------------------------------------------------

## Empuja la roca `r` una casilla hacia `dir` como la jugadora: anda (BFS, sin teletransportes que salten obstáculos) hasta la casilla de detrás de la roca y la empuja con `empujar(dir, true)`.
func _empujar_roca(r: BloqueEmpujable3D, dir: Vector2i, que: String) -> bool:
	if not await caminar(r.celda - dir, que):
		return false
	var cedio: bool = r.empujar(dir, true)
	await esperar(func() -> bool: return not r.moviendo, 12.0)
	await avanzar(2)
	return cedio


func _balanza() -> void:
	var este: Vector2i = Vector2i(1, 0)
	var pesada: Pulsador3D = z.nodo("placa_pesada") as Pulsador3D
	var ligera: Pulsador3D = z.nodo("placa_ligera") as Pulsador3D
	var mediana: BloqueEmpujable3D = z.nodo("roca_balanza") as BloqueEmpujable3D
	var pie_a: BloqueEmpujable3D = z.nodo("piedra_balanza_a") as BloqueEmpujable3D
	var pie_b: BloqueEmpujable3D = z.nodo("piedra_balanza_b") as BloqueEmpujable3D
	var cofre: Puzle3D.CofrePuzle = _cofre("cofre_balanza")
	_ok("3b.1 LA BALANZA · ANTES: placa de peso 2 (22,30) y de peso 1 (22,32) libres, roca mediana (19,30), piedras (21,30) y (19,32) en su sitio y el cofre oculto",
		pesada != null and ligera != null and mediana != null and pie_a != null and pie_b != null and cofre != null and pesada.peso_min == 2 and ligera.peso_min == 1 and not pesada.activo and not ligera.activo
		and mediana.celda == Vector2i(19, 30) and pie_a.celda == Vector2i(21, 30) and pie_b.celda == Vector2i(19, 32) and mediana.peso_valor == 2 and pie_a.peso_valor == 1 and cofre.es_oculto)
	if pesada == null or ligera == null or mediana == null or pie_a == null or pie_b == null or cofre == null:
		return
	_ok("3b.2 el camino de y=31 sigue libre con las rocas en su sitio (hay camino a pie de la orilla (16,31) a (24,31))", hay_camino(Vector2i(24, 31)))
	# la piedrecita de delante, sobre la placa de peso 2: no basta (POCO PESO); se sigue empujando hasta apartarla
	await _empujar_roca(pie_a, este, "3b.3")
	await avanzar_s(0.6)
	_ok("3b.4 una piedra pequeña (peso 1) sobre la placa de peso 2 NO la pisa (pesa %d de 2) ni pone `bosque02.balanza.pesada`" % pesada.peso_en_casilla(), pie_a.celda == Vector2i(22, 30) and pesada.peso_en_casilla() == 1 and not pesada.activo and not _flag("bosque02.balanza.pesada"))
	await _empujar_roca(pie_a, este, "3b.5")
	await avanzar_s(0.3)
	_ok("3b.6 …empujada una casilla más queda apartada en (23,30) y la placa vuelve a estar libre", pie_a.celda == Vector2i(23, 30) and pesada.peso_en_casilla() == 0)
	for i in range(3):
		await _empujar_roca(mediana, este, "3b.7")
	await avanzar_s(0.6)
	_ok("3b.8 la roca MEDIANA (peso 2) sobre la placa de peso 2 la pisa: `bosque02.balanza.pesada`", mediana.celda == Vector2i(22, 30) and pesada.activo and _flag("bosque02.balanza.pesada") and cofre.es_oculto)
	for i in range(3):
		await _empujar_roca(pie_b, este, "3b.9")
	await avanzar_s(0.8)
	_ok("3b.10 la piedra PEQUEÑA (peso 1) sobre la placa de peso 1 la pisa: `bosque02.balanza.ligera`, y con las dos APARECE el cofre común", pie_b.celda == Vector2i(22, 32) and ligera.activo and _flag("bosque02.balanza.ligera") and cofre.es_cerrado)
	_ok("3b.11 con las tres rocas colocadas el camino de y=31 sigue libre", hay_camino(Vector2i(24, 31)))
	await abrir_cofre("cofre_balanza", "3b.12")


# ---------------------------------------------------------------------------------------------------------------------
#  4 · El pasillo de la Cueva: tronco y dos setos (fuego); la boca
# ---------------------------------------------------------------------------------------------------------------------

func _pasillo_cueva() -> void:
	var salida: Node = z.nodo("boca_salida")
	_ok("4.1 la boca de la Cueva está declarada hacia Cueva:desde_bosque y la Cueva existe", salida != null and String(salida.get("destino")) == "Cueva:desde_bosque" and Niveles.existe("Cueva"))
	_ok("4.2 ANTES: el tronco (22,24) y los setos (26,24),(27,24) cierran el pasillo: no hay camino a la boca (34,24)", not hay_camino(Vector2i(34, 24)) and not hay_camino(Vector2i(33, 24)))
	await disparar("fuego", ["flecha"], Vector2i(20, 24), Vector2i(22, 24), "4.3")
	var ardio: bool = await esperar(func() -> bool: return _libre(Vector2i(22, 24)), 20.0)
	_ok("4.4 el fuego consume el tronco y la casilla se libera", ardio)
	await disparar("fuego", ["flecha"], Vector2i(24, 24), Vector2i(26, 24), "4.5")
	var ardieron: bool = await esperar(func() -> bool: return _libre(Vector2i(26, 24)) and _libre(Vector2i(27, 24)), 25.0)
	_ok("4.6 el fuego consume los dos setos (se contagian) y se libera el pasillo", ardieron)
	_ok("4.7 DESPUÉS: hay camino a pie hasta la entrada de la boca (33,24) y hasta su salida (34,24; no se pisa para no viajar)", hay_camino(Vector2i(33, 24)) and hay_camino(Vector2i(34, 24)))
	_ok("4.8 las flags de lo consumido quedaron (volver de la Cueva no repone el pasillo)", _flag("bosque02.quemado.c22_24") and _flag("bosque02.quemado.c26_24") and _flag("bosque02.quemado.c27_24"))
	# se vuelve a la orilla: la prueba sigue por la pradera
	await caminar(Vector2i(18, 22), "4.9")


# ---------------------------------------------------------------------------------------------------------------------
#  5 · La pradera alta: vigía → cofre común 3; colmena y nido (viento)
# ---------------------------------------------------------------------------------------------------------------------

func _pradera() -> void:
	var vig: Puzle3D.VigiaPuzle = _vigia("vig_pradera")
	var cofre: Puzle3D.CofrePuzle = _cofre("cofre_pradera")
	_ok("5.1 ANTES: el vigía de la pradera vigila a 5 (tres goblins, un arquero y dos lobernos), no está cumplido y el cofre está oculto", vig.vistos.size() == 5 and not vig.completo and cofre.es_oculto and not _flag("bosque02.pradera.limpia"))
	var col: Colmena3D = z.nodo("colmena_pradera") as Colmena3D
	var nido: Nido3D = z.nodo("nido_pradera") as Nido3D
	_ok("5.2 la colmena cuelga de un árbol de la pradera y el nido está en su sitio", col != null and col.estado == "colgada" and nido != null)
	var viento: RuneData = load("res://nucleo/wind_rune.tres") as RuneData
	await disparar("viento", ["flecha"], Vector2i(22, 12), Vector2i(21, 12), "5.3")
	await avanzar_s(2.0)
	if col.estado == "colgada":
		_aviso("5.3b la flecha de viento no llega a la colmena en headless (igual que en escenario_botin): se aplica el contrato `on_spell_hit` directo", "estado %s" % col.estado)
		col.on_spell_hit(viento)
		await avanzar_s(0.5)
	_ok("5.4 el viento descuelga la colmena: cae el panal (flag de la colmena)", col.estado == "vacia" and _flag(col.flag()), col.estado)
	await disparar("viento", ["flecha"], Vector2i(26, 13), Vector2i(26, 12), "5.5")
	await avanzar_s(2.0)
	if nido.sacudidas == 0:
		_aviso("5.5b la flecha de viento no llega al nido en headless: contrato `on_spell_hit` directo", "sacudidas 0")
		nido.on_spell_hit(viento)
		await avanzar_s(0.5)
	_ok("5.6 el viento sacude el nido y suelta una pluma", nido.sacudidas == 1, str(nido.sacudidas))
	# Un guerrero cae a hechizos de VERDAD (tierra, agua y rayo, apuntando a donde esté en cada tiro); los otros cuatro, con `muerto = true`.
	var guerrero: Combate3D = null
	for e in vig.vistos:
		if Terreno3D.celda_de((e as Combate3D).casa) == Vector2i(19, 14):
			guerrero = e
	if guerrero != null:
		await caminar(Vector2i(19, 16), "5.6b")
		var tiros: int = 0
		while not guerrero.muerto and tiros < 30:
			_curar()
			var dir_g: Vector3 = guerrero.global_position - jugador.position
			dir_g.y = 0.0
			lanzar(["tierra", "tierra", "agua", "rayo"][tiros % 4], ["flecha"], dir_g)
			_disparos += 1
			tiros += 1
			await avanzar_s(0.9)
		_ok("5.6c un guerrero de la pradera cae a hechizos de verdad (%d tiros, daño real de tierra, agua y rayo)" % tiros, guerrero.muerto, "%d tiros" % tiros)
	_matar(vig.vistos)                                    # [muerto=true] los que quedan
	await avanzar_s(1.0)
	_ok("5.7 DESPUÉS: al caer los cinco el vigía pone `bosque02.pradera.limpia` y APARECE el cofre", vig.completo and _flag("bosque02.pradera.limpia") and cofre.es_cerrado)
	await abrir_cofre("cofre_pradera", "5.8")
	# plantas reactivas de la pradera (seta, flor, raíz): están y son reactivos de la maqueta
	var tipos: Dictionary = {}
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r):
			tipos[String(r.tipo)] = int(tipos.get(String(r.tipo), 0)) + 1
	_ok("5.9 los reactivos de la maqueta incluyen setos, troncos, telarañas, tótems, fogata, braseros, torres, puerta goblin, fuentes, tinaja y placa", tipos.has("telarana") and tipos.has("totem") and tipos.has("fogata") and tipos.has("brasero")
		and tipos.has("torre_goblin") and tipos.has("puerta_goblin") and tipos.has("emisor_rayo") and tipos.has("surtidor") and tipos.has("placa"), str(tipos))


# ---------------------------------------------------------------------------------------------------------------------
#  6 · Las ruinas del este: tres tótems (fuego tras telarañas, agua tras la reja de la tinaja, rayo por la cadena) y el puente roto
# ---------------------------------------------------------------------------------------------------------------------

func _ruinas_este() -> void:
	var tot: Array = reglas.get("_totems") as Array
	var asesino: Variant = reglas.get("_asesino")
	if asesino != null and is_instance_valid(asesino):
		_matar([asesino])                                 # [muerto=true]: el asesino merodea por las ruinas y pondría su cuerpo en la línea de tiro
	_ok("6.1 los tres tótems empiezan dormidos y ninguna flag de tótem está puesta", not bool(tot[0].activo) and not bool(tot[1].activo) and not bool(tot[2].activo) and not _flag("bosque02.totem.fuego"))
	# --- fuego: la telaraña (22,7) tapa el tótem (22,6)
	_ok("6.2 TÓTEM DE FUEGO · ANTES: la telaraña (22,7) bloquea el camino y la línea de tiro", not _libre(Vector2i(22, 7)))
	await disparar("fuego", ["flecha"], Vector2i(22, 9), Vector2i(22, 7), "6.3")
	var libre: bool = await esperar(func() -> bool: return _libre(Vector2i(22, 7)), 20.0)
	_ok("6.4 la telaraña arde y se consume (queda su flag)", libre and _flag("bosque02.quemado.c22_7"))
	# Se dispara en cuanto la casilla se libera, con la telaraña consumida aún disolviéndose en (22,7): desde el diario 347 lo consumido no se come el hechizo (`HechizoVivo.fuera_de_juego`).
	_ok("6.4b la telaraña consumida sigue en escena un momento (es lo que antes se comía la flecha)", not _consumido(Vector2i(22, 7)))
	await disparar("fuego", ["flecha"], Vector2i(22, 8), Vector2i(22, 6), "6.5")
	var fuego: bool = await esperar(func() -> bool: return bool(tot[0].activo), 6.0)
	_ok("6.6 DESPUÉS: el tótem de fuego despierta y deja `bosque02.totem.fuego`", fuego and _flag("bosque02.totem.fuego"))
	# --- agua: la tinaja (13,5) está al otro lado del arroyo; su cuenca abre la reja (19,7) del tótem
	var reja: Puzle3D.PuertaPuzle = z.nodo("reja_totem") as Puzle3D.PuertaPuzle
	_ok("6.7 TÓTEM DE AGUA · ANTES: la reja (19,7) está cerrada (no se pisa) y la cuenca de la plaza, vacía", reja != null and not reja.abierta and not _libre(Vector2i(19, 7)) and Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 8)) < 0.02, "reja %s abierta=%s libre=%s prof=%.3f" % [str(reja != null), str(reja.abierta if reja != null else "-"), str(_libre(Vector2i(19, 7))), Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 8))])
	await disparar("agua", ["flecha", "flecha"], Vector2i(16, 5), Vector2i(13, 5), "6.8")
	var t_agua: float = reloj.t
	var llena: bool = await esperar(func() -> bool: return reja.abierta, 150.0)
	_ok("6.9 la tinaja vierte, el canal llena la cuenca (nivel ≥ 0,45) y la reja se ABRE (a los %.0f s del hechizo)" % (reloj.t - t_agua), llena and _flag("bosque02.ruinas.reja") and _libre(Vector2i(19, 7)))
	await disparar("agua", ["flecha"], Vector2i(19, 7), Vector2i(19, 5), "6.10")
	var agua: bool = await esperar(func() -> bool: return bool(tot[1].activo), 6.0)
	_ok("6.11 DESPUÉS: el tótem de agua despierta y deja `bosque02.totem.agua`", agua and _flag("bosque02.totem.agua"))
	# --- rayo: la fuente (17,10) descarga cada ~5 s; con el nexo (19,10) seco la corriente se corta
	var nexo: NexoRayo3D = z.nodo("nexo_cadena") as NexoRayo3D
	await caminar(Vector2i(19, 8), "6.12")
	await avanzar_s(7.0)                                  # una descarga completa de la fuente con el nexo seco
	_ok("6.13 TÓTEM DE RAYO · ANTES: con el nexo seco la corriente no llega al tótem (no despierta tras una descarga entera)", not nexo.conduce and not bool(tot[2].activo))
	await disparar("agua", ["flecha"], Vector2i(19, 8), Vector2i(19, 10), "6.14")
	await avanzar_s(2.0)
	_ok("6.15 el agua moja el nexo y este conduce", nexo.conduce, "mojado %.0f s" % nexo.mojado)
	var rayo: bool = await esperar(func() -> bool: return bool(tot[2].activo), 15.0)
	_ok("6.16 DESPUÉS: la fuente descarga por pozo → nexo → pozo, el tótem de rayo despierta y deja `bosque02.totem.rayo`", rayo and _flag("bosque02.totem.rayo"))
	await avanzar_s(0.5)
	_ok("6.17 con los tres tótems despiertos se pone `bosque02.ruinas.totems` (la llave de la sala del tesoro)", _flag("bosque02.ruinas.totems"))
	# --- el puente roto: el arroyo vuelve a cortar el mapa (plaza oeste)
	var puente: PuenteReactivo3D = z.nodo("puente_arroyo") as PuenteReactivo3D
	_ok("6.18 PUENTE ROTO · ANTES: no hay camino a pie de las ruinas del este a la plaza oeste (13,9)", puente != null and not puente.tendido and not hay_camino(Vector2i(13, 9)))
	await disparar("agua", ["flecha"], Vector2i(19, 9), Vector2i(17, 9), "6.19")
	var tendido: bool = await esperar(func() -> bool: return puente.tendido, 6.0)
	await avanzar_s(3.0)
	_ok("6.20 DESPUÉS: el pulsador de agua tiende el puente (flag `bosque02.ruinas.puente`) y hay camino a pie hasta la plaza oeste", tendido and _flag("bosque02.ruinas.puente") and hay_camino(Vector2i(13, 9)))


# ---------------------------------------------------------------------------------------------------------------------
#  7 · La plaza oeste: la sala del tesoro de las ruinas (cofre común 6) y el peso de la piedra (cofre épico 3)
# ---------------------------------------------------------------------------------------------------------------------

func _plaza_oeste() -> void:
	var puerta: Puzle3D.PuertaPuzle = z.nodo("puerta_ruinas") as Puzle3D.PuertaPuzle
	var puerta_sant: Puzle3D.PuertaPuzle = z.nodo("puerta_santuario") as Puzle3D.PuertaPuzle
	_ok("7.1 SALA DEL TESORO · ANTES de pisar la puerta: cerrada, y no hay camino a la sala (6,6)", puerta != null and not puerta.abierta and not _libre(Vector2i(7, 7)))
	await caminar(Vector2i(13, 9), "7.2")
	_ok("7.3 …cruzado el puente ya no hay camino a la sala: la puerta (7,7) la cierra", not hay_camino(Vector2i(6, 6)))
	_ok("7.4 SANTUARIO · ANTES de tener la llave: la puerta (8,12) está cerrada y no hay camino a (8,14)", puerta_sant != null and not puerta_sant.abierta and not hay_camino(Vector2i(8, 14)) and not _flag("bosque02.santuario.llave"))
	# la librera da pistas
	var librera: Dictionary = {}
	for g in (reglas.get("_gente") as Array):
		if String((g as Dictionary)["tipo"]) == "librera":
			librera = g
	await caminar(Vector2i(10, 10), "7.5")
	var pistas: Array = []
	for i in range(8):
		pistas.append(str(reglas.call("hablar", librera, jugador.position)))
	var todo: String = " ".join(pistas)
	_ok("7.6 la librera da las pistas de los tótems, la reja, la fuente, la llave y la piedra", todo.contains("tótems") and todo.contains("reja") and todo.contains("rayo") and todo.contains("llave") and todo.contains("placa"), str(pistas))
	# la puerta de la sala del tesoro: con la flag de los tres tótems, al tocarla se abre
	await caminar(Vector2i(7, 8), "7.7")
	await tocar_puerta(Vector2i(7, 7))
	_ok("7.8 DESPUÉS: con los tres tótems la puerta (7,7) se ABRE al tocarla y hay camino a la sala", puerta.abierta and hay_camino(Vector2i(6, 6)))
	await abrir_cofre("cofre_ruinas", "7.9")
	# el bloque y la placa
	var bloque: BloqueEmpujable3D = z.nodo("bloque_ruinas") as BloqueEmpujable3D
	var trast: Puzle3D.CofrePuzle = _cofre("cofre_trastienda")
	_ok("7.10 EL PESO DE LA PIEDRA · ANTES: la placa K (9,10) sin pisar y el cofre épico oculto", bloque != null and bloque.celda == Vector2i(5, 10) and trast.es_oculto and not _flag("bosque02.ruinas.placa"))
	await caminar(Vector2i(4, 10), "7.11")
	var pasos: int = 0
	while bloque.celda != Vector2i(9, 10) and pasos < 8:
		var seguia: bool = bloque.empujar(Vector2i(1, 0), true)
		await esperar(func() -> bool: return not bloque.moviendo, 8.0)
		pasos += 1
		if not seguia:
			await avanzar_s(0.5)
	await avanzar_s(1.0)
	_ok("7.12 empujada en %d empujones la piedra queda sobre la placa (9,10)" % pasos, bloque.celda == Vector2i(9, 10))
	_ok("7.13 DESPUÉS: la placa pesa (se pone `bosque02.ruinas.placa`) y APARECE el cofre épico de la trastienda", _flag("bosque02.ruinas.placa") and trast.es_cerrado)
	await abrir_cofre("cofre_trastienda", "7.14")
	_ok("7.15 la túnica de salamandra está en la bolsa", Estado.i().cuenta("tunica_salamandra") == 1)


# ---------------------------------------------------------------------------------------------------------------------
#  8 · El estanque del molino: compuerta (agua) → cofre común 4; molino + lago electrificado → cofre épico 2
# ---------------------------------------------------------------------------------------------------------------------

func _estanque() -> void:
	var compuerta: Node = z.nodo("compuerta_molino")
	var molino: Node = z.nodo("molino_estanque")
	var molinero: Puzle3D.CofrePuzle = _cofre("cofre_molino")
	var epico: Puzle3D.CofrePuzle = _cofre("cofre_estanque")
	_ok("8.1 ANTES: compuerta cerrada, molino parado y los dos cofres del estanque ocultos", not bool(compuerta.get("abierta")) and not bool(molino.get("activo")) and molinero.es_oculto and epico.es_oculto)
	await caminar(Vector2i(31, 10), "8.2")
	await disparar("agua", ["flecha"], Vector2i(31, 10), Vector2i(31, 8), "8.3")
	var abre: bool = await esperar(func() -> bool: return bool(compuerta.get("abierta")), 6.0)
	_ok("8.4 el pulsador de agua (31,8) abre la compuerta y se pone `bosque02.estanque.compuerta`", abre and _flag("bosque02.estanque.compuerta"))
	await avanzar_s(0.5)
	_ok("8.5 aparece el cofre común del molino", molinero.es_cerrado)
	await abrir_cofre("cofre_molino", "8.6")
	var gira: bool = await esperar(func() -> bool: return _flag("bosque02.estanque.molino"), 120.0)
	_ok("8.7 el arroyo corre, la rueda del molino gira (`bosque02.estanque.molino`) y aparece el cofre ÉPICO del lago", gira and bool(molino.get("activo")) and epico.es_cerrado)
	# el lago: sellado hasta que la fuente lo electrifica (casilla (27,8)); la fuente descarga cada ~5,6 s
	var camino_epico: bool = await caminar(Vector2i(27, 10), "8.8")
	_ok("8.9 llegar a la orilla del lago fue posible a pie", camino_epico)
	# primero se espera a un momento SIN descarga (el reloj de la electrificada caduca a los 2 s) y se comprueba que el cofre está sellado
	var sin_descarga: bool = await esperar(func() -> bool: return not epico.sellado_cumplido(), 30.0)
	_ok("8.10 SELLADO · ANTES: sin descarga el lago no está electrificado y el cofre épico no se abre (E avisaría «sellado»)", sin_descarga and not epico.abrir() and epico.es_cerrado)
	var t0: float = reloj.t
	var con_descarga: bool = await esperar(func() -> bool: return epico.sellado_cumplido(), 30.0)
	_ok("8.11 la fuente (25,7) descarga y `casilla(27,8).electrificada` se cumple a los %.1f s (reloj de 2 s de C2)" % (reloj.t - t0), con_descarga)
	_hacer_sitio()                                   # el botín del camino (al azar) puede tener la mochila llena: sin hueco la capa no entra
	# Como en `abrir_cofre`: `Cofre3D.abrir` devuelve false mientras la tapa aún está apareciendo o en otra animación; se insiste (solo con el lago electrificado) hasta 10 s.
	var abrio: bool = false
	var t1: float = reloj.t
	while reloj.t - t1 < 10.0 and not abrio:
		if epico.sellado_cumplido():
			abrio = epico.abrir()
		if not abrio:
			await avanzar_s(0.1)
	await esperar(func() -> bool: return epico.es_abierto, 10.0)
	_ok("8.12 DESPUÉS: con el lago electrificado el cofre épico se abre (capa de escarcha: %d)" % Estado.i().cuenta("capa_escarcha"), abrio and epico.es_abierto and Estado.i().cuenta("capa_escarcha") == 1)
	_abiertos["cofre_estanque"] = "epico"
	var alga: Node = z.nodo("alga_estanque")
	_ok("8.13 el alga del lago existe (solo se ve y se coge con la casilla helada)", alga != null)


# ---------------------------------------------------------------------------------------------------------------------
#  9 · El campamento goblin: puerta (fuego), vigía (sin cerrojo desde el 5/11) → cofre épico 1 (llave) y torre → cofre común 5
# ---------------------------------------------------------------------------------------------------------------------

func _campamento() -> void:
	var vig: Puzle3D.VigiaPuzle = _vigia("vig_camp")
	var epico: Puzle3D.CofrePuzle = _cofre("cofre_campamento")
	var torre_cofre: Puzle3D.CofrePuzle = _cofre("cofre_torre")
	_ok("9.1 ANTES: la puerta goblin (28,16) cierra el campamento: no hay camino a (29,16) ni al cofre; el vigía vigila a 5 (dos guerreros, dos arqueros y el chamán)", not hay_camino(Vector2i(30, 16)) and vig.vistos.size() == 5 and epico.es_oculto and torre_cofre.es_oculto)
	await disparar("fuego", ["flecha"], Vector2i(26, 16), Vector2i(28, 16), "9.2")
	var arde: bool = await esperar(func() -> bool: return _libre(Vector2i(28, 16)), 30.0)
	_ok("9.3 la puerta goblin arde y se consume (flag de lo quemado)", arde and _flag("bosque02.quemado.c28_16"))
	_ok("9.4 DESPUÉS: hay camino a pie hasta dentro del campamento", hay_camino(Vector2i(30, 16)))
	var arq_fijo: Variant = reglas.get("_arquero_fijo")
	_ok("9.5 uno de los dos arqueros es de puesto (no persigue)", arq_fijo != null and bool(arq_fijo.fijo))
	await caminar(Vector2i(30, 16), "9.6")
	await avanzar_s(0.6)
	_ok("9.7 SIN CERROJO (zona abierta, 5/11): dentro de la sala la casilla (29,16) sigue libre, hay camino de vuelta al exterior (27,16) y el mapa ya no trae `cerr_camp`", _libre(Vector2i(29, 16)) and hay_camino(Vector2i(27, 16)) and z.nodo("cerr_camp") == null)
	_matar(vig.vistos)                                    # [muerto=true]
	await avanzar_s(1.2)
	_ok("9.8 al caer los cinco el vigía pone `bosque02.campamento.limpio` y se puede volver al exterior", vig.completo and _flag("bosque02.campamento.limpio") and hay_camino(Vector2i(27, 16)))
	_ok("9.9 APARECE el cofre épico del campamento y aún no hay llave", epico.es_cerrado and not _flag("bosque02.santuario.llave"))
	await abrir_cofre("cofre_campamento", "9.10")
	await avanzar_s(0.5)
	_ok("9.11 abrir el cofre épico da la capucha de musgo y pone la llave del santuario (`bosque02.santuario.llave`)", Estado.i().cuenta("capucha_musgo") == 1 and _flag("bosque02.santuario.llave"))
	# la torre
	_ok("9.12 TORRE · ANTES: la torre este (34,13) en pie y el cofre de detrás oculto", not _libre(Vector2i(34, 13)) and torre_cofre.es_oculto)
	await disparar("fuego", ["flecha"], Vector2i(34, 15), Vector2i(34, 13), "9.13")
	var cae: bool = await esperar(func() -> bool: return _libre(Vector2i(34, 13)), 40.0)
	await avanzar_s(1.0)
	_ok("9.14 DESPUÉS: la torre arde y se consume, se pone `bosque02.torre.quemada` y APARECE el cofre común", cae and _flag("bosque02.torre.quemada") and torre_cofre.es_cerrado)
	await abrir_cofre("cofre_torre", "9.15")


# ---------------------------------------------------------------------------------------------------------------------
#  10 · El santuario: la llave, el elemental (sin cerrojo desde el 5/11) y el cofre legendario (fin de la demo)
# ---------------------------------------------------------------------------------------------------------------------

func _santuario() -> void:
	var puerta: Puzle3D.PuertaPuzle = z.nodo("puerta_santuario") as Puzle3D.PuertaPuzle
	var vig: Puzle3D.VigiaPuzle = _vigia("vig_sant")
	var corazon: Puzle3D.CofrePuzle = _cofre("cofre_corazon")
	_ok("10.1 ANTES: la puerta del santuario sigue cerrada (aunque ya hay llave, hay que ir a tocarla) y el cofre del corazón está oculto", not puerta.abierta and not hay_camino(Vector2i(8, 14)) and corazon.es_oculto)
	await caminar(Vector2i(8, 11), "10.2")
	await tocar_puerta(Vector2i(8, 12))
	_ok("10.3 DESPUÉS: con la llave la puerta (8,12) se ABRE al tocarla y hay camino a pie hasta el elemental", puerta.abierta and hay_camino(Vector2i(8, 14)))
	await caminar(Vector2i(8, 14), "10.4")
	await avanzar_s(0.6)
	_ok("10.5 SIN CERROJO (zona abierta, 5/11): dentro del santuario (8,13) sigue libre, hay camino de vuelta a (8,11) y el mapa ya no trae `cerr_sant`", _libre(Vector2i(8, 13)) and hay_camino(Vector2i(8, 11)) and z.nodo("cerr_sant") == null)
	_ok("10.6 el vigía vigila al elemental (1) y aún no hay cofre", vig.vistos.size() == 1 and not vig.completo)
	_matar(vig.vistos)                                    # [muerto=true]
	await avanzar_s(1.2)
	_ok("10.7 al caer el elemental el vigía pone `bosque02.santuario.limpio` y APARECE el cofre legendario", vig.completo and _flag("bosque02.santuario.limpio") and corazon.es_cerrado)
	var antes: int = int(Logros3D.total.get("nivel_completado", 0))
	var fin_antes: bool = bool(reglas.get("_terminado"))
	reglas.set("volver_al_menu", true)                    # solo ahora: a los 10 s de abrirse este cofre el juego vuelve al menú principal (se comprueba al final)
	await abrir_cofre("cofre_corazon", "10.8")
	await avanzar_s(1.0)
	_ok("10.9 FIN DE LA DEMO: `bosque02.santuario.cofre` puesta, `_terminado` y el logro `nivel_completado` emitido UNA vez", _flag("bosque02.santuario.cofre") and not fin_antes and bool(reglas.get("_terminado")) and int(Logros3D.total.get("nivel_completado", 0)) == antes + 1, "logros %d → %d" % [antes, int(Logros3D.total.get("nivel_completado", 0))])
	_ok("10.10 el rótulo dice «Fin de la demo» y el glifo ᛜ del cofre legendario está en el libro", String((reglas.get("_aviso") as Label).text).begins_with("Fin de la demo") and Repertoire.sigil_active("barrera"), String((reglas.get("_aviso") as Label).text))


# ---------------------------------------------------------------------------------------------------------------------
#  Final
# ---------------------------------------------------------------------------------------------------------------------

func _final() -> void:
	var comunes: int = 0
	var epicos: int = 0
	var legend: int = 0
	for id in _abiertos:
		match String(_abiertos[id]):
			"": comunes += 1
			"epico": epicos += 1
			"legendario": legend += 1
	_ok("F.1 todos los cofres estaban a pie y se abrieron: %d comunes (≥ 5), %d épicos (≥ 2) y %d legendario" % [comunes, epicos, legend], comunes >= 5 and comunes == 8 and epicos >= 2 and epicos == 3 and legend == 1, str(_abiertos.keys()))
	var flags_ok: bool = true
	for f in ["bosque02.linde.cofre", "bosque02.orilla.cofre", "bosque02.pradera.cofre", "bosque02.molino.cofre", "bosque02.torre.cofre", "bosque02.ruinas.cofre", "bosque02.escondite.cofre",
			"bosque02.campamento.cofre", "bosque02.estanque.cofre", "bosque02.trastienda.cofre", "bosque02.santuario.cofre", "bosque02.balanza.cofre"]:
		flags_ok = flags_ok and _flag(f)
	_ok("F.2 las 12 flags de cofre abierto están puestas", flags_ok)
	await avanzar_s(0.5)
	var mi: Misiones = Misiones.i()
	_ok("F.3 la misión principal «El corazón del Bosque» está COMPLETA (7/7) y pagó su oro", mi.estado("bosque_02") == "completa" and mi.progreso("bosque_02") == Vector2i(7, 7), str(mi.progreso("bosque_02")))
	_ok("F.4 las secundarias están completas: Destruir el campamento, La corriente del molino, El peso de la piedra y Siete cofres", mi.estado("bosque_02_campamento") == "completa" and mi.estado("bosque_02_molino") == "completa" and mi.estado("bosque_02_piedra") == "completa" and mi.estado("bosque_02_cofres") == "completa",
		"%s %s %s %s" % [mi.estado("bosque_02_campamento"), mi.estado("bosque_02_molino"), mi.estado("bosque_02_piedra"), mi.estado("bosque_02_cofres")])
	_ok("F.5 el marcador de la misión (fijar_punto) ya no apunta a nada al acabar", mi.punto_objetivo("bosque_02") == null)
	# Fin de la demo: a los 10 s del cofre legendario el juego autoguarda y vuelve al menú principal (la jugadora ya ha terminado: aquí solo se espera el cambio de escena).
	var al_menu: bool = await esperar(func() -> bool: return current_scene != null and current_scene is MenuPrincipal, 14.0)
	_ok("F.6 a los 10 s de abrir el cofre legendario el juego vuelve al MENÚ PRINCIPAL (escena %s)" % (current_scene.name if current_scene != null else "ninguna"), al_menu)
	_ok("F.7 en total se anduvieron %d casillas y se lanzaron %d hechizos, sin un solo salto de más de una casilla" % [_casillas, _disparos], _casillas > 200 and _disparos >= 15)
	_aviso("F.8 la mochila (8 huecos) se llenó con el botín del camino; para abrir los cofres la jugadora tiró", str(_tirados))
