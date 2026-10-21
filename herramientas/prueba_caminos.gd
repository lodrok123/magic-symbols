extends SceneTree
## D2 de docs/PLAN_EOW.md (21/10, Juego): CAMINOS DE ENEMIGO SOBRE CASILLAS (Caminos3D). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_caminos.gd
## Lo que comprueba:
##   1. Un muro de tierra recién creado (bloquear_celda): la ruta cambia TRAS EL AVISO (sin llamar a nadie a mano) y el goblin lo rodea de verdad.
##   2. Lo mismo con un muro de dos niveles (fijar_altura): rodea; al quitarlo vuelve la ruta recta.
##   3. Un puente de hielo (poner_helada): sin helar no hay ruta ni cruza (A3 sigue en pie); helada una casilla, cruza por ella aunque esté lejos de la recta.
##   4. Altura: sube/baja UN nivel, no dos (ni en el A* ni andando).
##   5. Sin ruta (muro de borde a borde) el goblin no hace nada raro y no recalcula en cada fotograma.
##   6. Coste: un cambio de casilla + recalcular la ruta en 40x40 < 1 ms (medido, media y máximo).

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const L40: int = 40
const LIMITE_US: float = 1000.0

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar(LADO)
	_muro_bloqueo()
	_muro_altura()
	_puente_hielo()
	_alturas()
	_sin_ruta()
	_montar(L40)
	_coste()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Terreno vacío de `lado` x `lado` con borde de piedra. Se reinicia todo (alturas, hielo, caminos) y se cuelga un Mundo3D nuevo (= otro nivel).
func _montar(lado: int) -> void:
	if _mundo != null:
		_mundo.free()
	if _jugador != null:
		_jugador.free()
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(lado):
		var f: String = ""
		for x in range(lado):
			if x == 0 or y == 0 or x == lado - 1 or y == lado - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.estados = EstadosSuelo3D.new()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


func _letra(c: Vector2i, l: String) -> void:
	Terreno3D.poner_letra(c, l)


## Un goblin guerrero en la casilla `c`, con IA, que ya ha perdido de vista al jugador y va a su última posición (estado «busca»: es el mismo
## camino de código que «persigue» para moverse, y no ataca ni se rinde por sí solo aunque la vista esté cortada).
func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.position = p
	g.casa = p
	return g


func _quitar(g: Combate3D) -> void:
	if is_instance_valid(g):
		if is_instance_valid(g.pj):
			g.pj.free()
		g.free()


## Manda al goblin a `meta` (casilla). Devuelve cuántos fotogramas tardó en llegar a menos de 1,2 u del centro (-1 si no llegó en `max_pasos`).
func _ir(g: Combate3D, meta: Vector2i, max_pasos: int) -> int:
	var objetivo: Vector3 = Terreno3D.centro_de(meta)
	_jugador.position = objetivo
	g.objetivo = _jugador
	g.ultima_pos = objetivo
	for i in range(max_pasos):
		g.vista_perdida = 0.0                    # no se rinde: lo que se prueba es el camino, no la memoria
		g.estado = "busca"
		g._physics_process(DT)
		g._ajustar_al_suelo(DT)
		if Vector2(g.position.x - objetivo.x, g.position.z - objetivo.z).length() < 1.2:
			return i
	return -1


func _ruta_pasa_por(r: Array[Vector2i], c: Vector2i) -> bool:
	return r.has(c)


# ---------------------------------------------------------------------------------------------------------------------
#  1. Muro bloqueado
# ---------------------------------------------------------------------------------------------------------------------
func _muro_bloqueo() -> void:
	var a := Vector2i(3, 6)
	var b := Vector2i(10, 6)
	var antes: Array[Vector2i] = Caminos3D.camino(a, b)
	_ok("1 sin muro: ruta recta (8 casillas)", antes.size() == 8 and antes[0] == a and antes[antes.size() - 1] == b, str(antes.size()))
	var cc: Caminos3D = Caminos3D.compartido()
	var ref0: int = cc.refrescos
	var g := _goblin(a)
	var pasos_recta: int = _ir(g, b, 900)
	_ok("1 sin muro: el goblin llega y NO pidió ninguna ruta (recta libre, como antes)", pasos_recta > 0 and g.rutas_calculadas == 0, "pasos %d rutas %d" % [pasos_recta, g.rutas_calculadas])
	_quitar(g)
	# El muro: columna 6, filas 3..10 (de cuatro casillas por arriba y por abajo se rodea).
	for y in range(3, 11):
		Terreno3D.bloquear_celda(Vector2i(6, y))
	_ok("1 los avisos «bloqueo» refrescaron las casillas (sin llamada a mano)", cc.refrescos - ref0 == 8, "refrescos %d" % (cc.refrescos - ref0))
	var despues: Array[Vector2i] = Caminos3D.camino(a, b)
	var cruza: bool = false
	for c in despues:
		if c.x == 6 and c.y >= 3 and c.y <= 10:
			cruza = true
	_ok("1 con muro: la ruta cambia, es más larga y no atraviesa el muro", not despues.is_empty() and not cruza and despues.size() > antes.size(), "%d casillas" % despues.size())
	var g2 := _goblin(a)
	var pasos: int = _ir(g2, b, 2400)
	_ok("1 con muro: el goblin lo rodea y llega", pasos > 0 and g2.rutas_calculadas > 0, "pasos %d rutas %d" % [pasos, g2.rutas_calculadas])
	# «Con moderación»: a 60 fps, medio segundo entre rutas → como mucho 2 por segundo (más alguna por cambiar de casilla la meta, que aquí no cambia).
	var segundos: float = float(maxi(pasos, 1)) * DT
	_ok("1 no recalcula cada fotograma", float(g2.rutas_calculadas) <= segundos / Combate3D.PERIODO_CAMINO + 2.0, "%d rutas en %.1f s" % [g2.rutas_calculadas, segundos])
	_quitar(g2)
	for y in range(3, 11):
		Terreno3D.liberar_celda(Vector2i(6, y))
	_ok("1 al derribar el muro (liberar_celda + aviso) vuelve la ruta recta", Caminos3D.camino(a, b).size() == 8)


# ---------------------------------------------------------------------------------------------------------------------
#  2. Muro de tierra de dos niveles
# ---------------------------------------------------------------------------------------------------------------------
func _muro_altura() -> void:
	var a := Vector2i(3, 6)
	var b := Vector2i(10, 6)
	for y in range(3, 11):
		Terreno3D.fijar_altura(Vector2i(6, y), 2)
	var cc: Caminos3D = Caminos3D.compartido()
	var propias0: int = cc.rutas_propias
	var r: Array[Vector2i] = Caminos3D.camino(a, b)
	var cruza: bool = false
	for c in r:
		if c.x == 6 and c.y >= 3 and c.y <= 10:
			cruza = true
	_ok("2 muro de 2 niveles: la ruta lo rodea (el A* nativo la cruzaba, la arista de altura la corrige)", not r.is_empty() and not cruza and cc.rutas_propias > propias0, "%d casillas, A* propio x%d" % [r.size(), cc.rutas_propias - propias0])
	var g := _goblin(a)
	var pasos: int = _ir(g, b, 2400)
	_ok("2 el goblin rodea el muro de tierra y llega", pasos > 0, "pasos %d" % pasos)
	_quitar(g)
	for y in range(3, 11):
		Terreno3D.fijar_altura(Vector2i(6, y), 0)
	_ok("2 al quitar la tierra (aviso «altura») vuelve la ruta recta", Caminos3D.camino(a, b).size() == 8)


# ---------------------------------------------------------------------------------------------------------------------
#  3. Río y puente de hielo
# ---------------------------------------------------------------------------------------------------------------------
func _puente_hielo() -> void:
	# Río en la columna 6 de borde a borde (filas 1..12). El goblin y su presa en la fila 3; el puente, en la fila 10.
	for y in range(1, LADO - 1):
		_letra(Vector2i(6, y), "~")
	var a := Vector2i(3, 3)
	var b := Vector2i(9, 3)
	_ok("3 río sin helar: no hay ruta", Caminos3D.camino(a, b).is_empty())
	var g := _goblin(a)
	var pasos: int = _ir(g, b, 900)
	_ok("3 sin helar el goblin NO cruza (ni se mete en el agua)", pasos == -1 and g.position.x < 6.0 * S and not g.se_hundio and not g.muerto, "x %.2f (río en %.2f..%.2f)" % [g.position.x, 6.0 * S, 7.0 * S])
	_quitar(g)
	var cc: Caminos3D = Caminos3D.compartido()
	var ref0: int = cc.refrescos
	Terreno3D.poner_helada(Vector2i(6, 10), true)
	_ok("3 el aviso «hielo» refrescó la casilla", cc.refrescos > ref0)
	var r: Array[Vector2i] = Caminos3D.camino(a, b)
	_ok("3 helada UNA casilla: aparece la ruta y pasa por ella", not r.is_empty() and r.has(Vector2i(6, 10)), "%d casillas" % r.size())
	var g2 := _goblin(a)
	var pasos2: int = _ir(g2, b, 3000)
	_ok("3 el goblin da el rodeo hasta el puente de hielo y cruza", pasos2 > 0 and g2.rutas_calculadas > 0 and not g2.se_hundio, "pasos %d" % pasos2)
	_quitar(g2)
	Terreno3D.poner_helada(Vector2i(6, 10), false)
	_ok("3 derretido el hielo (aviso) vuelve a no haber ruta", Caminos3D.camino(a, b).is_empty())
	for y in range(1, LADO - 1):
		_letra(Vector2i(6, y), ".")
	_ok("3 el río se seca (aviso «letra»): ruta recta otra vez", Caminos3D.camino(a, b).size() == 7)


# ---------------------------------------------------------------------------------------------------------------------
#  4. Alturas
# ---------------------------------------------------------------------------------------------------------------------
func _alturas() -> void:
	var a := Vector2i(3, 6)
	for y in range(1, LADO - 1):
		Terreno3D.fijar_altura(Vector2i(6, y), 1)
	var r1: Array[Vector2i] = Caminos3D.camino(a, Vector2i(9, 6))
	_ok("4 un escalón de un nivel (arriba y abajo) se pasa: hay ruta", not r1.is_empty(), "%d casillas" % r1.size())
	var g := _goblin(a)
	var pasos: int = _ir(g, Vector2i(9, 6), 1500)
	_ok("4 el goblin sube un nivel, lo cruza y baja", pasos > 0 and absf(g.position.y - Terreno3D.y_pies(Vector2i(9, 6))) < 0.2, "pasos %d y %.2f" % [pasos, g.position.y])
	_quitar(g)
	for y in range(1, LADO - 1):
		Terreno3D.fijar_altura(Vector2i(6, y), 2)
	_ok("4 un muro de dos niveles de borde a borde: no hay ruta", Caminos3D.camino(a, Vector2i(9, 6)).is_empty())
	var g2 := _goblin(a)
	var p2: int = _ir(g2, Vector2i(9, 6), 900)
	_ok("4 y el goblin no lo escala", p2 == -1 and g2.position.x < 6.0 * S, "x %.2f" % g2.position.x)
	_quitar(g2)
	# Escalera: 0 -> 1 -> 2 se sube peldaño a peldaño; pero 2 -> 0 no se baja de golpe.
	for y in range(1, LADO - 1):
		Terreno3D.fijar_altura(Vector2i(5, y), 1)
		Terreno3D.fijar_altura(Vector2i(6, y), 2)
	_ok("4 escalera 0-1-2: se sube peldaño a peldaño", not Caminos3D.camino(Vector2i(3, 6), Vector2i(6, 6)).is_empty())
	_ok("4 pero de 2 a 0 (bajar dos de golpe) no", Caminos3D.camino(Vector2i(6, 6), Vector2i(8, 6)).is_empty())
	_ok("4 y bajar con peldaño sí (2 -> 1 -> 0)", not Caminos3D.camino(Vector2i(6, 6), Vector2i(3, 6)).is_empty())
	for y in range(1, LADO - 1):
		Terreno3D.fijar_altura(Vector2i(5, y), 0)
		Terreno3D.fijar_altura(Vector2i(6, y), 0)
	# Diagonal: no corta una esquina bloqueada.
	Terreno3D.bloquear_celda(Vector2i(8, 8))
	var d: Array[Vector2i] = Caminos3D.camino(Vector2i(7, 7), Vector2i(9, 9))
	_ok("4 sin diagonales que corten esquinas: rodea la casilla bloqueada sin pasar en diagonal junto a ella", not d.is_empty() and not d.has(Vector2i(8, 8)) and _sin_esquina_cortada(d), str(d))
	Terreno3D.liberar_celda(Vector2i(8, 8))


## ¿Algún paso en diagonal de la ruta roza una casilla no transitable?
func _sin_esquina_cortada(r: Array[Vector2i]) -> bool:
	for i in range(r.size() - 1):
		var a: Vector2i = r[i]
		var b: Vector2i = r[i + 1]
		if a.x != b.x and a.y != b.y:
			if not Caminos3D.transitable(Vector2i(b.x, a.y)) or not Caminos3D.transitable(Vector2i(a.x, b.y)):
				return false
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  5. Sin ruta
# ---------------------------------------------------------------------------------------------------------------------
func _sin_ruta() -> void:
	for y in range(1, LADO - 1):
		Terreno3D.bloquear_celda(Vector2i(6, y))
	var a := Vector2i(3, 6)
	var g := _goblin(a)
	var pasos: int = _ir(g, Vector2i(9, 6), 600)
	_ok("5 pared de borde a borde: no llega, y no atraviesa", pasos == -1 and g.position.x < 6.0 * S, "x %.2f" % g.position.x)
	# 600 fotogramas = 10 s: con PERIODO_CAMINO de 0,5 s, unas 20 consultas como mucho (no 600).
	_ok("5 sin ruta tampoco recalcula cada fotograma", g.rutas_calculadas <= 23, "%d rutas en 600 fotogramas" % g.rutas_calculadas)
	_quitar(g)
	for y in range(1, LADO - 1):
		Terreno3D.liberar_celda(Vector2i(6, y))


# ---------------------------------------------------------------------------------------------------------------------
#  6. Coste (40x40)
# ---------------------------------------------------------------------------------------------------------------------
func _estadisticas(nombre: String, us: Array, limite: bool) -> void:
	var suma: float = 0.0
	var mx: float = 0.0
	for v in us:
		suma += float(v)
		mx = maxf(mx, float(v))
	var media: float = suma / float(us.size())
	print("AVISO %s: media %.1f us, maximo %.1f us (%d repeticiones)" % [nombre, media, mx, us.size()])
	if limite:
		_ok("6 %s: media < 1 ms" % nombre, media < LIMITE_US, "%.1f us" % media)
		_ok("6 %s: máximo < 1 ms" % nombre, mx < LIMITE_US, "%.1f us" % mx)


func _coste() -> void:
	# Un laberinto suave: tres muros con hueco alternado, para que la ruta de esquina a esquina tenga que serpentear.
	for k in range(3):
		var x: int = 10 + k * 10
		for y in range(1, L40 - 1):
			var hueco: bool = (y >= L40 - 6) if k % 2 == 0 else (y <= 5)
			if not hueco:
				Terreno3D.bloquear_celda(Vector2i(x, y))
	var a := Vector2i(1, 1)
	var b := Vector2i(L40 - 2, L40 - 2)
	var ruta: Array[Vector2i] = Caminos3D.camino(a, b)       # calienta (y construye la rejilla) fuera de la medida
	_ok("6 el laberinto tiene ruta serpenteante", ruta.size() > 60, "%d casillas" % ruta.size())
	var reps: int = 300
	var solo_cambio: Array = []
	var cambio_y_ruta: Array = []
	var ruta_sola: Array = []
	var casilla := Vector2i(20, 20)                          # lejos de la ruta: el cambio y la consulta son independientes
	for i in range(reps):
		var t0: int = Time.get_ticks_usec()
		Terreno3D.bloquear_celda(casilla)                    # cambio + aviso + refresco de UNA casilla
		var t1: int = Time.get_ticks_usec()
		Caminos3D.camino(a, b)
		var t2: int = Time.get_ticks_usec()
		Terreno3D.liberar_celda(casilla)
		var t3: int = Time.get_ticks_usec()
		solo_cambio.append(t1 - t0)
		ruta_sola.append(t2 - t1)
		cambio_y_ruta.append((t1 - t0) + (t2 - t1))
		solo_cambio.append(t3 - t2)
	_estadisticas("refrescar una casilla (cambio + aviso)", solo_cambio, true)
	_estadisticas("ruta de esquina a esquina (serpenteante)", ruta_sola, true)
	_estadisticas("recalcular tras un cambio (casilla + ruta)", cambio_y_ruta, true)
	# Con una arista de altura inservible en la ruta (cae al A* propio): se mide y se cuenta, no se afloja el 1 ms.
	for y in range(1, L40 - 1):
		Terreno3D.fijar_altura(Vector2i(5, y), 2)
	var cc: Caminos3D = Caminos3D.compartido()
	var propias0: int = cc.rutas_propias
	var con_alturas: Array = []
	for i in range(60):
		var t0: int = Time.get_ticks_usec()
		Caminos3D.camino(Vector2i(1, 20), Vector2i(L40 - 2, 20))
		con_alturas.append(Time.get_ticks_usec() - t0)
	_ok("6 con una pared de 2 niveles de lado a lado en medio: el A* propio resuelve (sin ruta, claro)", cc.rutas_propias > propias0)
	_estadisticas("ruta con aristas de altura (A* propio, sin ruta posible = peor caso)", con_alturas, false)
