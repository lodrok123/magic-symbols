## Caminos3D · D2 de docs/PLAN_EOW.md (21/10, Juego): rutas de los enemigos sobre las CASILLAS del mapa.
##
## Por qué casillas y no malla: la navegación de EoW es una rejilla de columnas, y con altura entera A* sobre casillas basta y se recalcula barato
## cuando la magia cambia el terreno (un muro de tierra, un puente de hielo).
##
## CÓMO SE MODELA LA ALTURA (AStarGrid2D no tiene aristas con regla propia, solo casillas sólidas):
##   · La SOLIDEZ por casilla va en el AStarGrid2D nativo: bloqueo de Terreno3D, agua (`es_agua`: de verdad, sin helar) y fuera de mapa. Es la misma regla de
##     quien camina (`Terreno3D.pisable`). Sin diagonales que corten esquinas (DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES).
##   · La ALTURA es una propiedad de la ARISTA (pasar de a a b solo si |nivel(a) - nivel(b)| <= 1), no de la casilla, así que no cabe en la rejilla. Se
##     resuelve en dos tiempos: (1) se pide la ruta al A* nativo (rapidísimo); (2) se comprueba cada paso con `arista_ok`. Si todos valen (lo normal: el
##     terreno casi nunca tiene escalones de 2+), esa es la ruta. Si alguno no vale, se busca con un A* PROPIO pequeño que sí conoce las aristas (más lento,
##     por eso solo se usa cuando hace falta). Si el nativo no halla ruta, tampoco la habrá con la regla de altura (solo la restringe más).
##   · La altura NO se guarda: se lee de Terreno3D al comprobar, así que un cambio de «altura» solo ha de refrescar la solidez de esa casilla (por si pasó
##     a ser sólida o dejó de serlo), no reconstruir nada.
##
## INVALIDACIÓN: escucha `Mundo3D.casilla_cambio` («bloqueo», «altura», «agua», «hielo», «letra») y refresca SOLO esa casilla. Se reconstruye entera al
## cambiar de nivel (otro Mundo3D, otro lado de mapa o otra maqueta) o con `reiniciar()`. Sin Mundo3D en el árbol nadie avisa: en ese caso quien cambie
## el terreno por su cuenta debe llamar a `avisar_cambio(c)` (las pruebas sin mundo lo hacen).
##
## USO: una instancia compartida por nivel (`Caminos3D.compartido()`), no una por goblin. Las funciones estáticas `camino`, `transitable`... la usan.
class_name Caminos3D
extends RefCounted

## Qué avisos de `casilla_cambio` pueden cambiar si una casilla se pisa.
const AVISOS: PackedStringArray = ["bloqueo", "altura", "agua", "hielo", "letra"]
## Diferencia máxima de nivel entre dos casillas vecinas por la que se puede pasar (como el jugador: sube/baja un escalón, no dos).
const SALTO_MAX: int = 1
const COSTE_DIAGONAL: float = 1.4142135

static var _yo: Caminos3D = null

var _a: AStarGrid2D = null
var _lado: int = 0
var _id_mundo: int = 0                 ## instance_id del Mundo3D al que escucha (0 = ninguno)
var _id_maqueta: int = 0               ## instance_id de Terreno3D.mundo_s cuando se construyó (otro = otro nivel)
var reconstrucciones: int = 0          ## cuántas veces se ha reconstruido entera (para las pruebas)
var refrescos: int = 0                 ## cuántas casillas se han refrescado por aviso (para las pruebas)
var rutas_propias: int = 0             ## cuántas veces hizo falta el A* propio por una arista de altura


# ---------------------------------------------------------------------------------------------------------------------
#  API estática (la que usa la IA)
# ---------------------------------------------------------------------------------------------------------------------

## La instancia compartida; la reconstruye si el nivel cambió desde la última vez.
static func compartido() -> Caminos3D:
	if _yo == null:
		_yo = Caminos3D.new()
	_yo._asegurar()
	return _yo


## Olvida lo construido (cambio de nivel explícito, o una prueba que monta otro terreno).
static func reiniciar() -> void:
	if _yo != null:
		_yo._desconectar()
	_yo = null


## Ruta de casilla a casilla, INCLUYENDO la de salida y la de llegada (`desde == hasta` → solo esa). Vacía si no hay.
static func camino(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	return compartido().buscar(desde, hasta)


## ¿Se puede estar de pie en esta casilla? (la regla de la IA para andar, sin empuje.)
## 22/10 (cauce hondo): un foso (`Terreno3D.es_cauce_hondo`, 0,94 u de caída) NO se rutea: los goblins lo RODEAN, como el agua. Lo mismo que ya hacen en `_puede_estar`
## (un salto de más de 0,6 u de suelo no se pisa de un paso); así no se tiran al foso en mitad de una persecución. Quien ya esté dentro (empujado) sale, que la casilla de
## salida sí vale (ver `buscar`).
static func transitable(c: Vector2i) -> bool:
	return Terreno3D.en_mapa(c) \
			and Terreno3D.pisable(c, 99, false, 99, false) \
			and not Terreno3D.es_agua(c) \
			and not Terreno3D.es_cauce_hondo(c)


## ¿Se puede ANDAR en línea recta de `a` a `b`? (distinto de ver: el río o un escalón no cortan la vista pero sí el paso.) Recorre las casillas que atraviesa
## la recta: cada una debe poder pisarse y estar al mismo nivel que la de salida. Las casillas bloqueadas con forma conocida («parcial»: un barril, un arbusto)
## NO cuentan como obstáculo: el goblin las roza deslizando, como siempre, y no merece la pena rodearlas con una ruta.
static func recta_andable(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	d.y = 0.0
	var largo: float = d.length()
	if largo < 0.01:
		return true
	var ini: Vector2i = Terreno3D.celda_de(a)
	var fin: Vector2i = Terreno3D.celda_de(b)
	var nivel: int = Terreno3D.altura_en(ini)
	var previa: Vector2i = ini
	var paso: float = Terreno3D.casilla * 0.25
	var rec: float = paso
	while true:
		var c: Vector2i = fin if rec >= largo else Terreno3D.celda_de(a + d / largo * rec)
		if c != previa:
			if not transitable(c) and not Terreno3D.es_parcial(c):
				return false
			if Terreno3D.altura_en(c) != nivel:
				return false
			previa = c
		if rec >= largo:
			return true
		rec += paso
	return true


## ¿Se puede pasar de `a` a `b` (vecinas, en ocho direcciones)? Solo mira la altura y, en diagonal, que no corte una esquina: la solidez de
## `b` y de las dos casillas del lado la pone `transitable`.
static func arista_ok(a: Vector2i, b: Vector2i) -> bool:
	if absi(Terreno3D.altura_en(a) - Terreno3D.altura_en(b)) > SALTO_MAX:
		return false
	if a.x != b.x and a.y != b.y:
		# Diagonal: el paso por cualquiera de las dos casillas del lado ha de ser también posible (no se rasca una esquina).
		for m: Vector2i in [Vector2i(b.x, a.y), Vector2i(a.x, b.y)]:
			if not transitable(m) \
					or absi(Terreno3D.altura_en(a) - Terreno3D.altura_en(m)) > SALTO_MAX \
					or absi(Terreno3D.altura_en(m) - Terreno3D.altura_en(b)) > SALTO_MAX:
				return false
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  Instancia
# ---------------------------------------------------------------------------------------------------------------------

## Reconstruye la rejilla entera. Cuesta ~lado² comprobaciones de casilla: solo al cambiar de nivel.
func reconstruir() -> void:
	reconstrucciones += 1
	_lado = Terreno3D.lado_del_mapa()
	if _lado <= 0:
		_a = null
		return
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, _lado, _lado)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES     # sin cortar esquinas bloqueadas
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.update()
	for y in range(_lado):
		for x in range(_lado):
			if not transitable(Vector2i(x, y)):
				a.set_point_solid(Vector2i(x, y), true)
	_a = a


## Refresca SOLO esta casilla. Devuelve true si su solidez cambió.
func avisar_cambio(c: Vector2i) -> bool:
	if _a == null or not _a.region.has_point(c):
		return false
	refrescos += 1
	var solida: bool = not transitable(c)
	if _a.is_point_solid(c) == solida:
		return false
	_a.set_point_solid(c, solida)
	return true


## Ruta de `desde` a `hasta` (incluidas ambas). Vacía si no hay o si alguna de las dos no se puede pisar... salvo la de salida: quien ya está
## encima (un goblin empujado a una casilla rara) puede salir de ella.
func buscar(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	var vacia: Array[Vector2i] = []
	if _a == null or not _a.region.has_point(desde) or not _a.region.has_point(hasta) or _a.is_point_solid(hasta):
		return vacia
	if desde == hasta:
		return [desde]
	var salida_solida: bool = _a.is_point_solid(desde)
	if salida_solida:
		_a.set_point_solid(desde, false)
	var p: Array[Vector2i] = _a.get_id_path(desde, hasta)
	if salida_solida:
		_a.set_point_solid(desde, true)
	if p.is_empty():
		return p
	for i in range(p.size() - 1):
		if not arista_ok(p[i], p[i + 1]):
			rutas_propias += 1
			return _buscar_con_alturas(desde, hasta)
	return p


## A* propio con la regla de altura en cada arista. Montón binario con ids lineales y/x; ~lado² nodos como mucho. Solo se llama si la ruta nativa
## pisó un escalón de 2+ niveles.
func _buscar_con_alturas(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	var vacia: Array[Vector2i] = []
	var n: int = _lado * _lado
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var padre := PackedInt32Array()
	padre.resize(n)
	padre.fill(-1)
	var cerrado := PackedByteArray()
	cerrado.resize(n)
	var h_ids := PackedInt32Array()
	var h_pri := PackedFloat32Array()
	var i0: int = desde.y * _lado + desde.x
	var i1: int = hasta.y * _lado + hasta.x
	g[i0] = 0.0
	_monton_poner(h_ids, h_pri, i0, _octil(desde, hasta))
	while not h_ids.is_empty():
		var u: int = _monton_sacar(h_ids, h_pri)
		if cerrado[u] == 1:
			continue
		cerrado[u] = 1
		if u == i1:
			break
		var cu := Vector2i(u % _lado, u / _lado)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var cv := Vector2i(cu.x + dx, cu.y + dy)
				if not _a.region.has_point(cv) or _a.is_point_solid(cv):
					continue
				if not arista_ok(cu, cv):
					continue
				var v: int = cv.y * _lado + cv.x
				var ng: float = g[u] + (COSTE_DIAGONAL if dx != 0 and dy != 0 else 1.0)
				if ng < g[v]:
					g[v] = ng
					padre[v] = u
					_monton_poner(h_ids, h_pri, v, ng + _octil(cv, hasta))
	if padre[i1] == -1:
		return vacia
	var r: Array[Vector2i] = []
	var k: int = i1
	while k != -1:
		r.push_front(Vector2i(k % _lado, k / _lado))
		k = padre[k]
	return r


static func _octil(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return float(maxi(dx, dy)) + (COSTE_DIAGONAL - 1.0) * float(mini(dx, dy))


static func _monton_poner(ids: PackedInt32Array, pri: PackedFloat32Array, id: int, p: float) -> void:
	ids.append(id)
	pri.append(p)
	var i: int = ids.size() - 1
	while i > 0:
		var padre: int = (i - 1) / 2
		if pri[padre] <= pri[i]:
			break
		var ti: int = ids[i]
		var tp: float = pri[i]
		ids[i] = ids[padre]
		pri[i] = pri[padre]
		ids[padre] = ti
		pri[padre] = tp
		i = padre


static func _monton_sacar(ids: PackedInt32Array, pri: PackedFloat32Array) -> int:
	var r: int = ids[0]
	var ult: int = ids.size() - 1
	ids[0] = ids[ult]
	pri[0] = pri[ult]
	ids.resize(ult)
	pri.resize(ult)
	var i: int = 0
	while true:
		var l: int = 2 * i + 1
		var m: int = i
		if l < ult and pri[l] < pri[m]:
			m = l
		if l + 1 < ult and pri[l + 1] < pri[m]:
			m = l + 1
		if m == i:
			break
		var ti: int = ids[i]
		var tp: float = pri[i]
		ids[i] = ids[m]
		pri[i] = pri[m]
		ids[m] = ti
		pri[m] = tp
		i = m
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  Vigilar el nivel
# ---------------------------------------------------------------------------------------------------------------------

## Reconstruye (y se reengancha a los avisos) si el nivel es otro que el de la última vez.
func _asegurar() -> void:
	var mundo: Mundo3D = Mundo3D.actual
	var id_m: int = mundo.get_instance_id() if mundo != null else 0
	var id_q: int = Terreno3D.mundo_s.get_instance_id() if Terreno3D.mundo_s != null and is_instance_valid(Terreno3D.mundo_s) else 0
	if _a != null and _lado == Terreno3D.lado_del_mapa() and id_m == _id_mundo and id_q == _id_maqueta:
		return
	_desconectar()
	_id_mundo = id_m
	_id_maqueta = id_q
	if mundo != null:
		mundo.casilla_cambio.connect(_al_cambiar)
	reconstruir()


func _desconectar() -> void:
	if _id_mundo != 0 and is_instance_id_valid(_id_mundo):
		var viejo: Object = instance_from_id(_id_mundo)
		if viejo is Mundo3D and (viejo as Mundo3D).casilla_cambio.is_connected(_al_cambiar):
			(viejo as Mundo3D).casilla_cambio.disconnect(_al_cambiar)
	_id_mundo = 0


func _al_cambiar(c: Vector2i, que: String) -> void:
	if AVISOS.has(que):
		avisar_cambio(c)
