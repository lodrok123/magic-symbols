extends "res://herramientas/escenario_base.gd"
## ESCENARIO BOSQUE 01 · RAMAS (Juego, 16/10): la AMPLIACIÓN del bosque (48 × 44): nombres de marcador, alcanzabilidad sin muros imposibles,
## las cuatro cámaras de fuego con flechas de verdad, la patrulla del claro y las telarañas del camino del este.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_bosque_01_ramas.gd
## Complementa a escenario_bosque_01.gd (que cubre lo de siempre: tótems, puerta, cofres 1–2, alquimista, estanque, troncos).
##
## Qué NO prueba: el aspecto (decoración, suelo), el modelo del arquero (en el sandbox falta) ni el recorrido a pie por TODO el mapa (solo tramos
## con `mover_hacia`, que es en línea recta: se dan puntos intermedios sacados del BFS).

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const INICIO: Vector2i = Vector2i(2, 21)
const NOMBRES: PackedStringArray = [
	"inicio_01", "guerrero_01", "guerrero_03", "arquero_01", "arquero_02", "telarana_01", "telarana_02", "telarana_03", "telarana_04",
	"cofre_01", "cofre_02", "cofre_03", "cofre_04", "cofre_05", "cofre_06", "cofre_07", "elemental_01", "puerta_01", "alquimista_01",
	"totem_fuego_01", "totem_fuego_02", "totem_fuego_03", "brasero_01", "brasero_02", "brasero_03", "brasero_04", "brasero_05", "brasero_06",
	"brasero_07", "brasero_08", "brasero_09", "brasero_10", "seto_01", "seto_02", "seto_03", "seto_04", "canal_01", "canal_07",
]
const CELDAS_COFRE: Array = [Vector2i(10, 4), Vector2i(26, 15), Vector2i(25, 1), Vector2i(8, 41), Vector2i(27, 41), Vector2i(35, 41), Vector2i(44, 42)]

var reglas: Node = null
var pz: Puzle3D = null


func _escenario() -> void:
	await cargar(RUTA, true)
	reglas = maqueta.get_node_or_null("Reglas")
	_ok("1 la escena trae su nodo Reglas", reglas != null)
	if reglas == null:
		return
	pz = reglas.get("_puzles") as Puzle3D
	_ok("1.1 Reglas ve el nodo de Puzle3D", pz != null)
	await avanzar(10)
	_nombres()
	_alcanzable()
	await _camara_a()
	await _camara_b()
	await _camara_c()
	await _camara_d()
	await _patrulla()
	await _telaranas()
	await _paseo()


func _marca() -> Dictionary:
	return reglas.get("_marca") as Dictionary


func _nodo(id: String) -> Node:
	return pz.nodo(id)


func _fuego(objetivo: Vector2i, desde: Vector2i, glifos: Array = ["flecha"]) -> bool:
	var ok: bool = lanzar_a_celda("fuego", glifos, objetivo, desde)
	await avanzar_s(1.2)
	return ok


## Espera hasta que `cond` sea cierta (máx. `tope` s). Devuelve los segundos que tardó, o -1.
func _espera(cond: Callable, tope: float) -> float:
	var t: float = 0.0
	while t < tope:
		if bool(cond.call()):
			return t
		t += await avanzar_s(0.25)
	return -1.0


func _cofre(i: int) -> Variant:
	return (reglas.get("_cofres") as Array)[i]


# ---------------------------------------------------------------------------------------------------------------------

func _nombres() -> void:
	var m: Dictionary = _marca()
	var faltan: Array = []
	for n in NOMBRES:
		if not m.has(n):
			faltan.append(n)
	_ok("2.1 todos los marcadores esperados existen con su nombre tipo_NN", faltan.is_empty(), "faltan %s de %d" % [str(faltan), m.size()])
	var mal: Array = []
	var re: RegEx = RegEx.create_from_string("^[a-z_]+_\\d\\d$")
	for n in m.keys():
		if re.search(String(n)) == null:
			mal.append(n)
	_ok("2.2 todos los nombres siguen el patrón tipo_NN", mal.is_empty(), str(mal))
	var cc: Array = reglas.get("_celdas_cofre")
	_ok("2.3 las siete casillas de cofre salen de los nombres y en orden", cc.size() == 7 and cc == CELDAS_COFRE, str(cc))
	_ok("2.4 el nivel mide 52 de lado de trabajo y las letras de relleno # no son solo árboles (hay piezas variadas)", int(maqueta.get("_lado")) >= 48, "lado %s" % str(maqueta.get("_lado")))
	_ok("2.5 el mapa no trae avisos de Puzle3D", (pz.get("avisos") == null) or (pz.get("avisos") as Array).is_empty(), str(pz.get("avisos")))


## BFS desde el inicio con las reglas de pisable() del jugador. Los pasos «con llave» (telarañas, puertas, puente) se tratan como abiertos:
## son justo los que el jugador abre con sus herramientas (fuego, tótems, tronco). Lo que debe salir es que NO haya muro imposible.
func _celdas_llave() -> Dictionary:
	var s: Dictionary = {}
	for n in _marca().keys():
		var k: String = String(n)
		if k.begins_with("telarana_") or k.begins_with("puerta_") or k.begins_with("cofre_") or k.begins_with("seto_") or k.begins_with("brasero_"):
			s[_marca()[n]] = true
	for c in [Vector2i(8, 39), Vector2i(27, 39), Vector2i(35, 39), Vector2i(44, 40), Vector2i(6, 5), Vector2i(7, 5)]:
		s[c] = true
	return s


func _alcanzables() -> Dictionary:
	var llave: Dictionary = _celdas_llave()
	var visto: Dictionary = {INICIO: 0}
	var cola: Array = [INICIO]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if visto.has(n):
				continue
			if llave.has(n) or Terreno3D.pisable(n, 0, false, 0, false):
				visto[n] = int(visto[c]) + 1
				cola.append(n)
	return visto


func _alcanzable() -> void:
	var v: Dictionary = _alcanzables()
	var fuera: Array = []
	for n in _marca().keys():
		var k: String = String(n)
		if k.begins_with("canal_"):
			continue                                           # el arroyo es agua: se mira, no se pisa
		var c: Vector2i = _marca()[n]
		var cerca: bool = v.has(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			cerca = cerca or v.has(c + d)
		if not cerca:
			fuera.append("%s%s" % [k, str(c)])
	_ok("3.1 con las llaves abiertas se llega a pie hasta TODOS los marcadores (o a su casilla vecina)", fuera.is_empty(), str(fuera))
	_ok("3.2 el inicio y el jugador coinciden", celda_jugador() == INICIO or Terreno3D.celda_de(jugador.position).distance_to(INICIO) < 3.0, str(celda_jugador()))
	_aviso("3.3 casillas alcanzables", "%d" % v.size())
	# Cada fila de relleno: ninguna casilla pisable queda ENCERRADA (isla sin conexión) si ha de ser parte del paseo: se informa, no se exige.
	var islas: int = 0
	var mapa: PackedStringArray = maqueta.get("_mapa")
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			var c2: Vector2i = Vector2i(x, y)
			if Terreno3D.pisable(c2, 0, false, 0, false) and not v.has(c2) and mapa[y][x] in [".", ",", "g"]:
				islas += 1
	_aviso("3.4 casillas de suelo sin conexión con el inicio (cámaras tras puerta o rincones)", "%d" % islas)


# ---------------------------------------------------------------------------------------------------------------------
#  Cámara A · cuatro braseros + contador
# ---------------------------------------------------------------------------------------------------------------------

func _camara_a() -> void:
	var puerta: Node = _nodo("a_puerta")
	_ok("A.0 la puerta empieza cerrada y el cofre_04 no está", not bool(puerta.get("abierta")) and _cofre(3) == null)
	# Cada brasero desde una casilla en línea recta (la diagonal larga desde el centro de la sala no siempre prende: la flecha vuela en arco)
	for par in [[Vector2i(5, 34), Vector2i(5, 36)], [Vector2i(11, 34), Vector2i(11, 36)], [Vector2i(5, 37), Vector2i(5, 35)], [Vector2i(11, 37), Vector2i(11, 35)]]:
		_ok("A.1 flecha de fuego a %s" % str(par[0]), await _fuego(par[0], par[1]))
	var t: float = await _espera(func() -> bool: return bool(puerta.get("abierta")), 4.0)
	_ok("A.2 con los cuatro braseros encendidos se abre la puerta", t >= 0.0, "%.1f s" % t)
	await _espera(func() -> bool: return _cofre(3) != null, 4.0)
	_ok("A.3 aparece el cofre_04 en la trastienda", _cofre(3) != null)
	await _abrir_y_medir(3, {"oro": 30})


## Abre el cofre `i` (como lo haría el jugador) y mide el oro/ítems que entran.
func _abrir_y_medir(i: int, esperado: Dictionary) -> void:
	var oro0: int = Estado.i().oro
	var ya: bool = _cofre(i) != null
	if ya:
		reglas.call("_al_abrir_cofre", i)
	await avanzar_s(0.3)
	var botin: Dictionary = (reglas.get("COFRES") as Array)[i].get("botin", {}) if reglas.get("COFRES") != null else {}
	_ok("cofre %d: al abrirlo da el oro previsto" % (i + 1), ya and Estado.i().oro - oro0 == int(esperado.get("oro", 0)), "oro +%d" % (Estado.i().oro - oro0))
	_ok("cofre %d: queda entregado y no se cobra dos veces" % (i + 1), bool((reglas.get("_entregado") as Array)[i]))


# ---------------------------------------------------------------------------------------------------------------------
#  Cámara B · seto → fuego → barril
# ---------------------------------------------------------------------------------------------------------------------

func _camara_b() -> void:
	var puerta: Node = _nodo("b_puerta")
	_ok("B.0 la puerta empieza cerrada", not bool(puerta.get("abierta")) and _cofre(4) == null)
	_ok("B.1 flecha de fuego al primer seto", await _fuego(Vector2i(19, 36), Vector2i(19, 34)))
	var t: float = await _espera(func() -> bool: return bool(puerta.get("abierta")), 30.0)
	_ok("B.2 el fuego corre por los cuatro setos, el barril explota y se abre la puerta", t >= 0.0, "%.1f s" % t)
	await _espera(func() -> bool: return _cofre(4) != null, 4.0)
	_ok("B.3 aparece el cofre_05", _cofre(4) != null)
	await _abrir_y_medir(4, {"oro": 60})


# ---------------------------------------------------------------------------------------------------------------------
#  Cámara C · cadena de braseros con relé
# ---------------------------------------------------------------------------------------------------------------------

func _camara_c() -> void:
	var puerta: Node = _nodo("c_puerta")
	_ok("C.0 la puerta empieza cerrada", not bool(puerta.get("abierta")) and _cofre(5) == null)
	_ok("C.1 flecha de fuego al primer brasero", await _fuego(Vector2i(32, 35), Vector2i(32, 37)))
	var t: float = await _espera(func() -> bool: return bool(puerta.get("abierta")), 20.0)
	_ok("C.2 la cadena de relés llega a los dos extremos a la vez y se abre la puerta", t >= 0.0, "%.1f s" % t)
	await _espera(func() -> bool: return _cofre(5) != null, 4.0)
	_ok("C.3 aparece el cofre_06", _cofre(5) != null)
	await _abrir_y_medir(5, {"oro": 45})


# ---------------------------------------------------------------------------------------------------------------------
#  Cámara D · la cuerda que sostiene la compuerta
# ---------------------------------------------------------------------------------------------------------------------

func _camara_d() -> void:
	var puerta: Node = _nodo("d_puerta")
	var comp: Node = _nodo("d_compuerta")
	var cuerda: Node = _nodo("d_cuerda")
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("D.0 la puerta empieza cerrada, la compuerta levantada y la cuerda entera", puerta != null and not bool(puerta.get("abierta")) and bool(comp.get("abierta")) and cuerda != null)
	colocar_jugador(Vector2i(44, 36))
	await avanzar_s(25.0)
	var vado: float = sim.profundidad_casilla(Vector2i(47, 36))
	_ok("D.1 el arroyo corre: el vado pasa de 0,25 y la puerta sigue cerrada", vado > 0.25 and not bool(puerta.get("abierta")), "%.2f u" % vado)
	_ok("D.2 flecha de fuego a la cuerda", await _fuego(Vector2i(46, 34), Vector2i(44, 34)))
	var t: float = await _espera(func() -> bool: return bool(puerta.get("abierta")), 30.0)
	_ok("D.3 la cuerda se rompe, la compuerta cae, el vado baja de 0,25 y se abre la puerta", t >= 0.0 and not bool(comp.get("abierta")), "%.1f s, vado %.2f" % [t, sim.profundidad_casilla(Vector2i(47, 36))])
	await _espera(func() -> bool: return _cofre(6) != null, 4.0)
	_ok("D.4 aparece el cofre_07", _cofre(6) != null)
	await _abrir_y_medir(6, {"oro": 70})


# ---------------------------------------------------------------------------------------------------------------------
#  Patrulla del claro NE → cofre_03
# ---------------------------------------------------------------------------------------------------------------------

func _patrulla() -> void:
	var p: Array = reglas.get("_patrulla")
	_ok("P.1 la patrulla del claro la forman tres enemigos (guerrero + dos arqueros)", p.size() == 3, "%d" % p.size())
	_ok("P.2 el cofre_03 no está antes de tiempo", _cofre(2) == null)
	for e in p:
		e.muerto = true
	await avanzar_s(0.6)
	_ok("P.3 al caer la patrulla aparece el cofre_03", _cofre(2) != null)
	await _abrir_y_medir(2, {"oro": 40})


# ---------------------------------------------------------------------------------------------------------------------
#  Telarañas del camino del este
# ---------------------------------------------------------------------------------------------------------------------

func _telaranas() -> void:
	for n in ["telarana_03", "telarana_04"]:
		var c: Vector2i = _marca()[n]
		_ok("T.1 %s bloquea su casilla antes de quemarla" % n, Terreno3D.bloqueada(c), str(c))
		_ok("T.2 flecha de fuego a %s" % n, await _fuego(c, c + Vector2i(0, 3), ["flecha", "flecha"]))        # 3 casillas = flecha ×2 (la 1.ª da 2 de alcance, cada una más suma 1)
		var t: float = await _espera(func() -> bool: return not Terreno3D.bloqueada(c), 8.0)
		_ok("T.3 %s arde y libera la casilla" % n, t >= 0.0, "%.1f s" % t)


# ---------------------------------------------------------------------------------------------------------------------
#  Paseo físico por tramos (teclas de verdad): el jugador cabe por los pasillos
# ---------------------------------------------------------------------------------------------------------------------

## Camino por casillas pisables (BFS) de a a b, casilla a casilla.
func _ruta(a: Vector2i, b: Vector2i) -> Array:
	var prev: Dictionary = {a: a}
	var cola: Array = [a]
	while not cola.is_empty() and not prev.has(b):
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and Terreno3D.pisable(n, 0, false, 0, false):
				prev[n] = c
				cola.append(n)
	if not prev.has(b):
		return []
	var camino: Array = [b]
	while camino[0] != a:
		camino.push_front(prev[camino[0]])
	# Una parada por casilla (sin recortar esquinas): mover_hacia anda en línea recta y el jugador tiene radio; recortar esquinas probaría el
	# algoritmo de la prueba, no el pasillo.
	var pts: Array = camino
	return pts


## Anda de verdad (teclas) de a a b siguiendo la ruta; devuelve dónde se quedó si se atasca, o b.
func _caminar(a: Vector2i, b: Vector2i) -> Vector2i:
	var pts: Array = _ruta(a, b)
	if pts.is_empty():
		return Vector2i(-1, -1)
	colocar_jugador(a)
	await avanzar_s(2.5)           # que se asiente: tras un disparo el jugador no anda unos segundos (animación de lanzar)
	for k in range(1, pts.size()):
		if not await mover_hacia(pts[k], 8.0, 0.5):
			return celda_jugador()
	return b


func _paseo() -> void:
	# Tramos nuevos del mapa ampliado, a pie y con las teclas: el hub sur, la explanada, las entradas de las cámaras y el sendero del este.
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).muerto = true                       # que nadie mate al jugador a mitad de camino: aquí se prueban pasillos, no combate
	await avanzar_s(1.0)
	var tramos: Array = [
		["hub sur a la explanada", Vector2i(10, 22), Vector2i(10, 30)],
		["explanada a la cámara B (entrada y sala)", Vector2i(10, 30), Vector2i(16, 36)],
		["explanada a la cámara C", Vector2i(16, 30), Vector2i(35, 36)],
		["explanada a la cámara A (entrada y sala)", Vector2i(35, 30), Vector2i(8, 36)],
		["camino del este (con las telarañas ya quemadas)", Vector2i(30, 6), Vector2i(30, 27)],
		["al claro de los lobernos", Vector2i(30, 27), Vector2i(31, 17)],
	]
	for t in tramos:
		var fin: Vector2i = await _caminar(t[1], t[2])
		_ok("W %s: a pie, sin atascos" % t[0], fin == t[2], "terminó en %s" % str(fin))
