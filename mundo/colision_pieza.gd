class_name ColisionPieza
extends RefCounted
## Colisión de una pieza MEDIDA SOBRE SU MODELO, no sobre la cuadrícula ni sobre una caja (20/10, Juego).
##
## Por qué existe: el casco convexo de TODO el modelo rellena lo que está vacío (el hueco de un arco o de una puerta, el
## espacio entre dos pilares, el interior de una empalizada en U) y deja «muros invisibles» donde se ve camino. Y la caja
## del 80 % del AABB hace lo mismo con cualquier forma que no sea un bloque.
##
## Qué hace: mira SOLO la franja de altura donde puede tocar el cuerpo de un personaje (la esfera del jugador va de 0,3
## a 0,9 sobre el suelo; los goblins algo más; arriba se pasa por debajo: copas, dinteles) y construye un casco por cada
## trozo de modelo que de verdad esté ahí:
##   1. recorta los triángulos a la franja [BANDA_MIN, BANDA_MAX];
##   2. mira qué casillas finas (CELDA) de la planta quedan cubiertas por ese recorte;
##   3. separa los trozos que no se tocan (los dos pilares de un arco: el hueco queda libre);
##   4. si el casco de un trozo ocupa mucho más que lo que cubre (una L, un anillo), lo parte por la mitad y repite.
## No usa ninguna API de descomposición de Godot: es geometría simple, igual en cualquier versión y en sandbox sin GPU.
##
## Quién lo llama: `Pieza3D.forma_colision` (cajas de la maqueta, medidas aquí) y, cuando el Pipeline lo enganche, el
## horneado de las escenas de pieza (`GeneradorPiezas._formas`): ver la entrada del diario. NO toca hechizos, flechas ni
## línea de visión: esos siguen por casillas.

## Franja de altura que cuenta. Por debajo de BANDA_MIN suelen estar la peana plana y el césped que el Meshy deja
## pegados a la pieza (no son obstáculo); por encima de BANDA_MAX se pasa por debajo.
const BANDA_MIN: float = 0.12
const BANDA_MAX: float = 1.6
## Piezas más bajas que esto no son obstáculo (se pisan): losas, hojas, nenúfares.
const ALTO_MIN_SOLIDO: float = 0.25
## Lado de la casilla fina con la que se mira la planta (m). 0,1 distingue un hueco de paso (≥ 0,6) de un poro del modelo.
const CELDA: float = 0.10
## Dos trozos a menos de este número de celdas se consideran el mismo (cierra poros de la malla, no huecos de paso).
const PUENTE_CELDAS: int = 2
## Un casco que ocupa más de SOBRA_MAX veces lo que realmente cubre se parte en dos.
const SOBRA_MAX: float = 1.35
const PROFUNDIDAD_MAX: int = 3
## Trozos de planta menores que esto (m²) se descartan (una ramita suelta no es un muro).
const AREA_MIN: float = 0.02
const TROZOS_MAX: int = 16

## Modo de cada pieza:
##   "contorno" → cascos medidos en la franja completa (lo normal: rocas, vallas, arcos, puestos, tocones…)
##   "tronco"   → solo el tronco (árboles: franja TRONCO_BAJO..TRONCO_ALTO y el trozo más cercano al eje)
##   "tronco_bajo" → como "tronco" pero solo la franja baja TRONCO_BANDAS_BAJO (el pino, cuyas ramas llegan al suelo)
##   "ninguna"  → se pisa (decorado, plantas, losas, nenúfares)
## Las piezas que no salen aquí se tratan como «ninguna», igual que `GeneradorPiezas.COLISION`.
const MODO: Dictionary = {
	# --- ya horneadas (mismos ids y misma intención que GeneradorPiezas.COLISION; "convexa" y "mesa" pasan a "contorno") ---
	"arbol_redondo": "tronco", "arbol_redondo_2": "tronco_bajo", "pino": "tronco_bajo", "pino_2": "tronco",
	"arbusto": "contorno", "arbusto_flores": "contorno", "arbusto_otono": "contorno", "seto_seco": "contorno",
	"roca_cristal": "contorno", "roca_grande": "contorno", "piedras": "contorno", "tocon": "contorno", "tronco": "contorno",
	"valla": "contorno", "cartel": "contorno", "totem_runico": "contorno", "brasero": "contorno", "fogata": "contorno",
	"puesto": "contorno", "puesto_mercado": "contorno", "dummy": "contorno", "caja_pequena": "contorno", "caja": "contorno",
	"barril": "contorno", "pilar": "contorno", "seta_reactiva": "contorno", "flor_reactiva": "contorno", "raiz_reactiva": "contorno",
	"tinaja_ruina": "contorno", "tienda_goblin": "contorno", "torre_goblin": "contorno", "puerta_goblin": "contorno",
	"empalizada_goblin": "contorno", "estandarte_goblin": "contorno",
	"campamento_tienda": "contorno", "campamento_cazo": "contorno", "campamento_rocas": "contorno", "campamento_cofre": "contorno",
	"roca_musgosa": "contorno", "seta_quemada": "contorno", "tronco_resina": "contorno", "tronco_sin_resina": "contorno",
	"tronco_musgoso": "contorno", "troncos_apilados": "contorno",
	# arcos: hasta hoy sin entrada (sin cuerpo, se atravesaban). Con el contorno medido quedan dos pilares y el paso libre.
	"arco_ruina": "contorno", "arco_puerta": "contorno",
	# --- las 43 nuevas (diario 213). Bloquean las que propuso el Pipeline; el resto es decorado que se pisa. ---
	"abedul_amarillo": "tronco", "arbol_viejo": "tronco", "sauce": "tronco",
	"tocon_alto": "contorno", "tocon_hueco": "contorno", "tocon_roca": "contorno", "tocon_seco": "contorno",
	"tronco_enredadera": "contorno", "tronco_seco": "contorno", "roca_hueca": "contorno", "cuenco_piedra": "contorno",
	"valla_lianas": "contorno", "arbusto_bayas": "contorno",
	"bloque_runa_roja": "contorno", "bloque_runa_naranja": "contorno", "bloque_runa_verde": "contorno",
	"bloque_runa_azul": "contorno", "bloque_runa_amarilla": "contorno", "bloque_runa_cian": "contorno",
	"cartel_runa_roja": "contorno", "cartel_runa_naranja": "contorno", "cartel_runa_verde": "contorno",
	"cartel_runa_azul": "contorno", "cartel_runa_amarilla": "contorno", "cartel_runa_cian": "contorno",
	"bloque_hierba": "contorno", "cubo_hielo": "contorno",
}

## Árboles: solo el tronco. Franjas candidatas (alto de 0,45 a 1,4) y, en cada una, solo el trozo más cercano al eje; se
## elige la franja de planta más estrecha. Por debajo de 0,45 están las raíces que se abren en estrella (≤ 0,4 de alto:
## se pasan por encima) y el césped pegado; por encima de 1,4 la copa. Medido en la planta de los 7 árboles. En el pino
## las ramas llegan al suelo y se ven sólidas: ahí el «tronco» es el cono de ramas, que sí es obstáculo.
const TRONCO_BANDAS: Array = [[0.45, 0.95], [0.7, 1.2], [0.9, 1.4]]
## Modo "tronco_bajo" (pino y arbol_redondo_2, 21/10, diario 227; en el redondo_2 la franja 0,45-0,95 medía r=1,03 con un lóbulo de raíz/rama que cerraba (6,15) de Bosque 01): sus ramas arrancan en y ≈ 0,45 y bajan en cono (radio ≈ 1,59), así que
## ninguna franja de TRONCO_BANDAS da un tronco: da el cono, que cerraba pasillos de una casilla. Por debajo de la rama baja sí
## hay tronco (radio ≈ 0,65 en la planta; por encima de 0,45 las ramas se unen a él en el casco). Se mide solo ahí y el casco se
## sube como columna hasta ALTO_TRONCO_BAJO, para que el cuerpo del jugador (0,3-0,9) no pueda trepar por un borde de 0,45.
const TRONCO_BANDAS_BAJO: Array = [[0.2, 0.45]]
const ALTO_TRONCO_BAJO: float = 1.4


## Modo de colisión de la pieza `id` ("ninguna" si no está en la tabla).
static func modo(id: String) -> String:
	return String(MODO.get(id, "ninguna"))


## Cascos de la pieza ya construida (`vis` = lo que devuelve `Pieza3D.crear_visual`, base en y = 0, centrada, a escala).
## Devuelve una lista de nubes de puntos (cada una es un casco convexo) en el espacio de la pieza. Vacía = sin cuerpo.
static func cascos(vis: Node3D, modo_pieza: String) -> Array:
	if vis == null or modo_pieza == "ninguna":
		return []
	var tris: PackedVector3Array = _triangulos(vis, Transform3D.IDENTITY)
	if tris.is_empty():
		return []
	var ymax_modelo: float = -INF
	for p in tris:
		ymax_modelo = maxf(ymax_modelo, p.y)
	if ymax_modelo < ALTO_MIN_SOLIDO:
		return []
	var res: Array = []
	if modo_pieza == "tronco" or modo_pieza == "tronco_bajo":
		# el tronco no está a la misma altura en todos los árboles (en el redondo_2 la copa baja desde 0,9): de las franjas
		# candidatas se queda con la que da el trozo central más estrecho, que es donde de verdad solo hay tronco
		var mejor: float = INF
		for banda in (TRONCO_BANDAS_BAJO if modo_pieza == "tronco_bajo" else TRONCO_BANDAS):
			var cand: Array = _cascos_banda(tris, banda[0], banda[1], true)
			var area: float = 0.0
			for nube in cand:
				area += _area_planta(nube as PackedVector3Array)
			if area >= AREA_MIN and area < mejor:
				mejor = area
				res = cand
	else:
		res = _cascos_banda(tris, BANDA_MIN, BANDA_MAX, false)
	# fuera lo diminuto y, si son demasiados, se quedan los de mayor planta
	var buenos: Array = []
	for nube in res:
		if _area_planta(nube as PackedVector3Array) >= AREA_MIN:
			buenos.append(nube)
	buenos.sort_custom(func(a, b): return _area_planta(a) > _area_planta(b))
	if buenos.size() > TROZOS_MAX:
		buenos.resize(TROZOS_MAX)
	var salida: Array = []
	for nube in buenos:
		var pts_n: PackedVector3Array = nube as PackedVector3Array
		if modo_pieza == "tronco_bajo":
			var arriba := PackedVector3Array(pts_n)
			for p in pts_n:
				arriba.append(Vector3(p.x, ALTO_TRONCO_BAJO, p.z))
			pts_n = arriba
		salida.append(_con_base(pts_n))
	return salida


## Nubes de puntos (una por trozo) de la franja [base, tope].
static func _cascos_banda(tris: PackedVector3Array, base: float, tope: float, solo_central: bool) -> Array:
	var recorte: PackedVector3Array = _recortar(tris, base, tope)
	var res: Array = []
	if recorte.is_empty():
		return res
	var por_celda: Dictionary = _planta(recorte)
	var trozos: Array = _componentes(por_celda)
	if solo_central:
		trozos = _solo_eje(trozos)
	# el tronco es macizo: su malla es una cáscara (anillo en la planta) y partirlo por «sobra de hueco» lo trocearía en
	# pedazos sueltos; se deja como un solo casco
	var prof0: int = PROFUNDIDAD_MAX if solo_central else 0
	for celdas in trozos:
		_trocear(celdas as Array, por_celda, prof0, res)
	return res


## Huella resumida de los cascos para el que solo sabe de cajas (la maqueta): caja que envuelve TODOS los cascos,
## con la altura real de lo medido. {"cilindro":false,"tam","alto","centro","cascos":n}. Vacía si no hay cuerpo.
static func caja_de(lista: Array) -> Dictionary:
	if lista.is_empty():
		return {}
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for nube in lista:
		for p in (nube as PackedVector3Array):
			lo = lo.min(p)
			hi = hi.max(p)
	var tam: Vector3 = hi - lo
	return {"cilindro": false, "tam": tam, "alto": hi.y, "centro": (lo + hi) * 0.5, "cascos": lista.size()}


# ---------------------------------------------------------------------------------------------------------------------
# Geometría
# ---------------------------------------------------------------------------------------------------------------------

## Todos los triángulos de las mallas visibles, en el espacio de la pieza (3 puntos seguidos por triángulo).
static func _triangulos(n: Node, acum: Transform3D) -> PackedVector3Array:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := PackedVector3Array()
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		for v in (n as MeshInstance3D).mesh.get_faces():
			res.append(t * v)
	for h in n.get_children():
		res.append_array(_triangulos(h, t))
	return res


## Recorta cada triángulo a y ∈ [y0, y1] (Sutherland-Hodgman contra los dos planos) y devuelve los triángulos resultantes.
## Hace falta recortar y no filtrar vértices: un triángulo grande de 0 a 3 m tiene vértices fuera de la franja y, sin
## recortar, la franja quedaría vacía justo donde el modelo tiene pared.
static func _recortar(tris: PackedVector3Array, y0: float, y1: float) -> PackedVector3Array:
	var res := PackedVector3Array()
	var i: int = 0
	while i + 2 < tris.size():
		var poli: Array = [tris[i], tris[i + 1], tris[i + 2]]
		i += 3
		poli = _recortar_plano(poli, y0, true)
		if poli.size() < 3:
			continue
		poli = _recortar_plano(poli, y1, false)
		if poli.size() < 3:
			continue
		for k in range(1, poli.size() - 1):
			res.append(poli[0])
			res.append(poli[k])
			res.append(poli[k + 1])
	return res


static func _recortar_plano(poli: Array, y: float, mantener_arriba: bool) -> Array:
	var sal: Array = []
	var n: int = poli.size()
	for k in range(n):
		var a: Vector3 = poli[k]
		var b: Vector3 = poli[(k + 1) % n]
		var a_dentro: bool = (a.y >= y) if mantener_arriba else (a.y <= y)
		var b_dentro: bool = (b.y >= y) if mantener_arriba else (b.y <= y)
		if a_dentro:
			sal.append(a)
		if a_dentro != b_dentro:
			var u: float = (y - a.y) / (b.y - a.y)
			sal.append(a.lerp(b, u))
	return sal


static func _celda(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELDA)), int(floor(p.z / CELDA)))


## Planta cubierta: por cada casilla fina, los puntos del recorte que caen en ella (vértices y muestras del interior de
## cada triángulo, para que un triángulo grande marque todas las casillas que cruza).
static func _planta(recorte: PackedVector3Array) -> Dictionary:
	var res: Dictionary = {}
	var i: int = 0
	while i + 2 < recorte.size():
		var a: Vector3 = recorte[i]
		var b: Vector3 = recorte[i + 1]
		var c: Vector3 = recorte[i + 2]
		i += 3
		var lado: float = maxf(maxf(Vector2(a.x - b.x, a.z - b.z).length(), Vector2(b.x - c.x, b.z - c.z).length()),
			Vector2(c.x - a.x, c.z - a.z).length())
		var n: int = clampi(int(ceil(lado / (CELDA * 0.5))), 1, 60)
		for u in range(n + 1):
			for v in range(n + 1 - u):
				var p: Vector3 = a + (b - a) * (float(u) / n) + (c - a) * (float(v) / n)
				var k: Vector2i = _celda(p)
				# los Packed* son valores: hay que reasignar, `(res[k] as ...).append` añadiría a una copia
				var lista: PackedVector3Array = res.get(k, PackedVector3Array())
				lista.append(p)
				res[k] = lista
	return res


## Trozos de planta que no se tocan (vecindad de PUENTE_CELDAS). Cada uno es una lista de Vector2i.
static func _componentes(por_celda: Dictionary) -> Array:
	var visto: Dictionary = {}
	var res: Array = []
	for k in por_celda.keys():
		if visto.has(k):
			continue
		var grupo: Array = []
		var pila: Array = [k]
		visto[k] = true
		while not pila.is_empty():
			var c: Vector2i = pila.pop_back()
			grupo.append(c)
			for dx in range(-PUENTE_CELDAS, PUENTE_CELDAS + 1):
				for dz in range(-PUENTE_CELDAS, PUENTE_CELDAS + 1):
					var v := Vector2i(c.x + dx, c.y + dz)
					if por_celda.has(v) and not visto.has(v):
						visto[v] = true
						pila.append(v)
		res.append(grupo)
	return res


## Árboles: de todos los trozos, el que contiene la casilla más cercana al eje (el tronco), y solo ese.
static func _solo_eje(trozos: Array) -> Array:
	var mejor: Array = []
	var mejor_d: float = INF
	for g in trozos:
		var d: float = INF
		for c in (g as Array):
			var cc: Vector2i = c
			d = minf(d, Vector2((cc.x + 0.5) * CELDA, (cc.y + 0.5) * CELDA).length())
		if d < mejor_d:
			mejor_d = d
			mejor = g
	return [] if mejor.is_empty() else [mejor]


static func _puntos_de(celdas: Array, por_celda: Dictionary) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for c in celdas:
		pts.append_array(por_celda[c] as PackedVector3Array)
	return pts


static func _area_planta(pts: PackedVector3Array) -> float:
	var p2 := PackedVector2Array()
	for p in pts:
		p2.append(Vector2(p.x, p.z))
	var h: PackedVector2Array = Geometry2D.convex_hull(p2)
	var a: float = 0.0
	for k in range(h.size() - 1):          # convex_hull cierra el polígono repitiendo el primer punto
		a += h[k].x * h[k + 1].y - h[k + 1].x * h[k].y
	return absf(a) * 0.5


## Casco del trozo; si sobra demasiado hueco lo parte por la mitad (por el eje más largo) y repite.
static func _trocear(celdas: Array, por_celda: Dictionary, prof: int, salida: Array) -> void:
	var pts: PackedVector3Array = _puntos_de(celdas, por_celda)
	if pts.size() < 4:
		return
	var cubierto: float = celdas.size() * CELDA * CELDA
	var casco: float = _area_planta(pts)
	if prof < PROFUNDIDAD_MAX and celdas.size() >= 8 and casco > SOBRA_MAX * cubierto:
		var minx: int = 1 << 30
		var maxx: int = -(1 << 30)
		var minz: int = 1 << 30
		var maxz: int = -(1 << 30)
		for c in celdas:
			var cc: Vector2i = c
			minx = mini(minx, cc.x)
			maxx = maxi(maxx, cc.x)
			minz = mini(minz, cc.y)
			maxz = maxi(maxz, cc.y)
		var por_x: bool = (maxx - minx) >= (maxz - minz)
		var ejes: Array = []
		for c in celdas:
			ejes.append((c as Vector2i).x if por_x else (c as Vector2i).y)
		ejes.sort()
		var corte: int = int(ejes[ejes.size() / 2])
		var izq: Array = []
		var der: Array = []
		for c in celdas:
			var v: int = (c as Vector2i).x if por_x else (c as Vector2i).y
			if v < corte:
				izq.append(c)
			else:
				der.append(c)
		if not izq.is_empty() and not der.is_empty():
			# cada mitad puede haberse separado en varios trozos sueltos
			for mitad in [izq, der]:
				var sub: Dictionary = {}
				for c in (mitad as Array):
					sub[c] = por_celda[c]
				for g in _componentes(sub):
					_trocear(g as Array, por_celda, prof + 1, salida)
			return
	salida.append(pts)


## Baja el casco hasta el suelo (y = 0): la franja no empieza en el suelo (BANDA_MIN, o más arriba en los árboles) y el
## cuerpo no debe quedar flotando. Solo se proyectan al suelo los puntos de la parte más baja del propio trozo, así un
## casco que se estrecha hacia arriba (una roca) sigue estrechándose.
static func _con_base(pts: PackedVector3Array) -> PackedVector3Array:
	var ymin: float = INF
	for p in pts:
		ymin = minf(ymin, p.y)
	var todo := PackedVector3Array(pts)
	for p in pts:
		if p.y <= ymin + 0.1:
			todo.append(Vector3(p.x, 0.0, p.z))
	return compactar(todo)


## Casco convexo COMPACTO de una nube de puntos (los vértices del casco ya calculado, a 1 mm): así no se guardan
## miles de puntos en el .tscn. Mismo método que `GeneradorPiezas._casco`, para que den lo mismo.
static func compactar(pts: PackedVector3Array) -> PackedVector3Array:
	var tmp := ConvexPolygonShape3D.new()
	tmp.points = pts
	var dbg: ArrayMesh = tmp.get_debug_mesh()
	var unicos: Dictionary = {}
	for s in range(dbg.get_surface_count()):
		var arr: Array = dbg.surface_get_arrays(s)
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			unicos[Vector3(snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001))] = true
	var lista := PackedVector3Array()
	for k in unicos.keys():
		lista.append(k)
	return lista if lista.size() >= 4 else pts
