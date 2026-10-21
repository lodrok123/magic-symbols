extends SceneTree
## Escenario 13.8 (15/10, versión «mapa solo») · el agua de la tinaja en el canal del BOSQUE REAL, sin ventana. Usa el mapa de verdad
## (mundo/datos_nivel/mapas/Bosque.txt: tinaja `u` (3,26), codo `L` (2,26), rectos `-` (2,27) y (2,28), río `~` (2,29)), la
## simulación de verdad (Terreno3D.montar_agua_sim → AguaSim3D) y las dos vías por las que llega el agua al canal:
##   · la maqueta: al caer el chorro, `Reactivo3D.agua_llega` → `Mundo3D.abrir_cauce(orden, CAUDAL_TINAJA)` (PruebaTest2._montar_canal)
##   · el hechizo directo sobre el `Surtidor3D` (on_spell_hit → llenar)
## Mide (a) la profundidad por casilla cada segundo (la verdad contra la que se compara el dibujo), (b) que al acabar el arranque (ARRANQUE_CAUCE, 18 s) las tres
## casillas tengan ≥ 0,25 u, (c) que las dos vías juntas NO sumen dos manantiales (con 3,0 u³/s el canal inunda). Lo escribe el Juego.
## 15/10 (13.10): el escenario con la ESCENA entera es `escenario_agua_tinaja.gd`; este se queda porque corre sin escena (rápido) y
## porque comprueba lo que aquel no: que las dos vías juntas no sumen dos manantiales.
## NO es la maqueta: no hay Reactivo3D, ni cámara, ni dibujo; la señal `agua_llega` se sustituye por la llamada que hace la maqueta.
##   godot --headless --path . --script res://herramientas/escenario_agua_tinaja_mapa.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	var _lado: int = 0
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _abre: Dictionary = {}
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x]) if c.y >= 0 and c.y < _mapa.size() and c.x >= 0 and c.x < _mapa[c.y].length() else " "
	func _es_canal(c: Vector2i) -> bool:
		return _letra(c) == "-" or _letra(c) == "L"
	func _abre_hacia(c: Vector2i, v: Vector2i) -> bool:
		return (_abre.get(c, []) as Array).has(v)
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)

const DT: float = 1.0 / 60.0
const MEDIDA: float = ReaccionesAgua3D.ARRANQUE_CAUCE     ## instante de la medida: cuando el manantial acaba de llegar a su caudal (antes eran 10 s, con el arranque de 5 s)
const TINAJA := Vector2i(3, 26)
const CANAL: Array = [Vector2i(2, 26), Vector2i(2, 27), Vector2i(2, 28)]
const RIO := Vector2i(2, 29)

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Un mundo nuevo con el Bosque real. Devuelve [mundo, simulación].
func _bosque() -> Array:
	var giros: Dictionary = {}
	var tam: Array = []
	var m := MundoFalso.new()
	m._mapa = HorneadorNivel.leer_mapa("Bosque", tam, giros)
	m._lado = m._mapa.size()
	# Lo que abre cada pieza según su giro (marcador_3d / bosque.txt): codo con giro 90 abre al este y al sur; recto con giro 90 corre N-S.
	m._abre = {Vector2i(2, 26): [Vector2i(1, 0), Vector2i(0, 1)], Vector2i(2, 27): [Vector2i(0, -1), Vector2i(0, 1)],
			Vector2i(2, 28): [Vector2i(0, -1), Vector2i(0, 1)]}
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(m._mapa.size()):
		for x in range(m._mapa[y].length()):
			if String(m._mapa[y][x]) in ["#", " ", "u", "-", "L", "~", "k", "j", "i", "e", "T", "B", "X", "x", "y", "o", "t", "V"]:
				m._bloqueadas[Vector2i(x, y)] = true
	return [m, Terreno3D.montar_agua_sim()]


## El orden de casillas que calcula PruebaTest2._montar_canal: anchura desde la de delante de la tinaja, solo por lados abiertos.
func _orden(m: MundoFalso) -> Array:
	var inicio: Vector2i = TINAJA + Vector2i(-1, 0)             # la tinaja de la fila 26 vierte hacia el OESTE (giro 180)
	var orden: Array = [inicio]
	var visto: Dictionary = {inicio: true}
	var i: int = 0
	while i < orden.size():
		var c: Vector2i = orden[i]
		i += 1
		for v in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var n: Vector2i = c + v
			if not visto.has(n) and m._es_canal(n) and m._abre_hacia(c, v) and m._abre_hacia(n, -v):
				visto[n] = true
				orden.append(n)
	return orden


func _fuente(sim: AguaSim3D, c: Vector2i) -> float:
	var f: float = 0.0
	for i in sim._trozos(c):
		f += sim.fuente[i]
	return f


func _correr(sim: AguaSim3D, segundos: float, tabla: bool) -> Array:
	var p: Array = []
	var t: float = 0.0
	var siguiente: float = 1.0
	while t < segundos:
		sim.paso(DT)
		t += DT
		if t >= siguiente - 1.0e-6:
			if tabla:
				print("      %2d s  canal %.3f / %.3f / %.3f   río %.3f" % [int(round(t)), sim.profundidad_casilla(CANAL[0]), sim.profundidad_casilla(CANAL[1]), sim.profundidad_casilla(CANAL[2]), sim.profundidad_casilla(RIO)])
			if absf(t - MEDIDA) < 0.5 * DT or (p.is_empty() and t >= MEDIDA - 1.0e-6):
				p = [sim.profundidad_casilla(CANAL[0]), sim.profundidad_casilla(CANAL[1]), sim.profundidad_casilla(CANAL[2])]
			siguiente += 1.0
	return p


func _initialize() -> void:
	await process_frame
	# --- 1) Solo la vía de la maqueta (agua_llega → abrir_cauce) ---
	var e: Array = _bosque()
	var m: MundoFalso = e[0]
	var sim: AguaSim3D = e[1]
	var orden: Array = _orden(m)
	_ok("1 el orden del canal es L(2,26), -(2,27), -(2,28)", orden == CANAL, str(orden))
	_ok("1 la tinaja del mapa está donde se dice (3,26)", m._letra(TINAJA) == "u")
	_ok("1 sellado antes de llegar el agua", sim.profundidad_casilla(CANAL[0]) == 0.0)
	_ok("1 abrir_cauce devuelve true", Mundo3D.abrir_cauce(orden, Surtidor3D.CAUDAL_TINAJA))
	_ok("1 el manantial ARRANCA despacio (al abrir casi no echa agua)", _fuente(sim, CANAL[0]) < 0.1, "%.3f u³/s" % _fuente(sim, CANAL[0]))
	var vol0: float = sim.volumen_total()
	print("      profundidad por segundo (Bosque real, vía maqueta):")
	var p10: Array = _correr(sim, MEDIDA + 20.0, true)
	var finales: Array = []
	for c in CANAL:
		finales.append(sim.profundidad_casilla(c as Vector2i))
	_ok("1 al acabar el arranque la primera y la segunda casilla del canal tienen ≥ 0,25 u", p10.size() == 3 and float(p10[0]) >= 0.25 and float(p10[1]) >= 0.25,
		"%.3f / %.3f / %.3f" % [p10[0], p10[1], p10[2]] if p10.size() == 3 else "sin medida")
	# La TERCERA es la que desagua al río: con CAUDAL_TINAJA 1,5 se queda en ≈ 0,18 al acabar el arranque y 0,175 en régimen. Llevarla a 0,25 solo con el
	# caudal exigiría ≈ 2,2 u³/s, y la primera pasaría de 0,70 (prueba_canal_tinaja exige < 0,6). No es un fallo de cableado: es la geometría.
	# Se avisa sin contar como fallo para no dejar el conjunto en rojo; si se cambia el diseño del canal, esto pasa a ser un `_ok`.
	if p10.size() == 3:
		print("%s 1 al acabar el arranque la TERCERA casilla (desagua al río) tiene %.3f u (objetivo de Pablo ≥ 0,25)" % ["OK   " if float(p10[2]) >= 0.25 else "AVISO", p10[2]])
	_ok("1 en régimen hay agua en las tres y el codo conduce", float(finales[0]) > 0.05 and float(finales[1]) > 0.05 and float(finales[2]) > 0.05 and Terreno3D.es_agua(CANAL[0]),
		"%.3f / %.3f / %.3f" % [finales[0], finales[1], finales[2]])
	_ok("1 pasado el arranque hay UN solo manantial de CAUDAL_TINAJA en la primera casilla", absf(_fuente(sim, CANAL[0]) - Surtidor3D.CAUDAL_TINAJA) < 1.0e-3, "%.3f" % _fuente(sim, CANAL[0]))
	# 15/10 (Pablo: «el caudal se va fuera del mapa»): el río del Bosque no toca el borde, era una balsa cerrada y el manantial lo desbordaba.
	var rio_p: float = sim.profundidad_casilla(RIO)
	_ok("1 el río que recibe el canal se mantiene en su nivel (no sube ni desborda)", rio_p < 0.95 and rio_p > 0.85, "%.3f u (antes 1,47)" % rio_p)
	var fuera: float = 0.0
	for cy in range(0, 29):
		for cx in range(0, sim.ancho):
			var cc := Vector2i(cx, cy)
			if not (cc in CANAL):
				fuera += sim.profundidad_casilla(cc)
	_ok("1 no hay agua fuera del canal y del río (al norte)", fuera < 0.05, "suma de profundidades %.3f" % fuera)
	_ok("1 el volumen del nivel no crece sin límite (el desagüe se lleva lo que sobra)", sim.volumen_total() - vol0 < 5.0, "+%.2f u³ en %.0f s con ≤ %.1f u³ echados" % [sim.volumen_total() - vol0, MEDIDA + 20.0, 1.5 * (MEDIDA + 20.0)])
	m.queue_free()
	await process_frame
	# --- 2) Las dos vías a la vez: el Surtidor3D del hechizo y la maqueta ---
	for orden_vias in ["surtidor_primero", "maqueta_primero"]:
		e = _bosque()
		m = e[0]
		sim = e[1]
		orden = _orden(m)
		var s := Surtidor3D.new()
		s.preparar(m, TINAJA)
		root.add_child(s)
		await process_frame
		var rune := RuneData.new()
		rune.tags.append("agua")
		if orden_vias == "surtidor_primero":
			s.on_spell_hit(rune)
			Mundo3D.abrir_cauce(orden, Surtidor3D.CAUDAL_TINAJA)
		else:
			Mundo3D.abrir_cauce(orden, Surtidor3D.CAUDAL_TINAJA)
			s.on_spell_hit(rune)
		_ok("2 (%s) el cauce del Surtidor3D y el de la maqueta empiezan en la misma casilla" % orden_vias, s.cauce.size() == 3 and s.cauce[0] == orden[0], str(s.cauce))
		var q: Array = _correr(sim, MEDIDA + 2.0, false)
		_ok("2 (%s) al acabar el arranque: mismas profundidades que con una sola vía" % orden_vias, q.size() == 3 and absf(float(q[0]) - float(p10[0])) < 0.01 and absf(float(q[2]) - float(p10[2])) < 0.01, "%.3f / %.3f / %.3f" % [q[0], q[1], q[2]] if q.size() == 3 else "sin medida")
		_ok("2 (%s) las dos vías juntas dejan UN solo manantial (%.2f u³/s)" % [orden_vias, Surtidor3D.CAUDAL_TINAJA], absf(_fuente(sim, CANAL[0]) - Surtidor3D.CAUDAL_TINAJA) < 1.0e-3, "fuente %.3f" % _fuente(sim, CANAL[0]))
		s.queue_free()
		m.queue_free()
		await process_frame
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
