extends RefCounted
## PAREDES DE CUEVA CON LAS ROCAS DEL PACK «Stylized Lost Cave» (24/11/2026). Variante de las paredes del estilo «cueva» de la maqueta: con
## `paredes_cueva = "lostcave"` (PruebaTest2), cada casilla `#` que toca suelo se viste con rocas del pack (arte/lostcave/piezas/lost_*.tscn) en vez
## del kit de Tripo (`_pared_cueva`). Lo usan los mapas del GENERADOR (opción «Paredes» al exportar) y el nivel de prueba PruebaLostCave.
## Sin `class_name`: se carga con preload (como el generador), así no obliga a reimportar.
##
## Cómo decide (`rocas(c, es_suelo)`):
##   · una roca por cada lado de la casilla que da a suelo, MIRANDO a ese suelo (su frente +Z hacia él), con su cara delantera un poco dentro
##     de la casilla de suelo (`ASOMA`), así no queda rendija entre la pared y el suelo;
##   · cada roca se ESCALA por su fondo real (medido de su malla) hasta `PROF[lado]` casillas, sin pasar de `ALTO_MAX[lado]`; todas miden al
##     menos 1 casilla de ancho, así que con una por casilla de muro no hay huecos entre rocas;
##   · el lado manda la paleta: pared NORTE de una sala (el suelo está al sur) = alta, salvo que detrás haya otra sala a menos de `CERCA_DETRAS`
##     casillas (taparía esa sala a la cámara): baja; pared SUR (delante de la cámara) = losas bajas; ESTE/OESTE = roquedales medianos;
##   · casilla `#` que solo toca suelo en DIAGONAL (esquina interior): una roca mediana mirando a esa diagonal, para cerrar el rincón.
## Las rocas llevan su propio cuerpo (capa 1024) para los hechizos; la casilla `#` ya está bloqueada para quien camina.
## Si una pieza no existe (el pack no se ha generado en esta máquina), se salta sin avisar: la casilla sigue siendo muro.

const RUTA: String = "res://arte/lostcave/piezas/"
const S: float = 2.3

## [pieza, peso] por lado. «n» = pared norte (fondo), «n_baja» = pared norte con otra sala detrás, «lado» = este/oeste, «s» = pared sur.
const PALETAS: Dictionary = {
	"n": [["lost_largewall_6x9", 4], ["lost_stonearray_b", 2], ["lost_rockarray_a", 2], ["lost_stalagmite_b", 2], ["lost_largewall_b", 2]],
	"n_baja": [["lost_stonearray_b", 3], ["lost_stonearray_a", 2], ["lost_flatstone_b", 2], ["lost_stalagmite_a", 1]],
	"lado": [["lost_stonearray_b", 3], ["lost_rockarray_a", 3], ["lost_totemrock_b", 1], ["lost_stalagmite_a", 2], ["lost_largewall_6x9", 2]],
	"s": [["lost_flatstone_a", 3], ["lost_stonearray_a", 3], ["lost_flatstone_b", 2]],
	"rincon": [["lost_stonearray_b", 2], ["lost_stalagmite_a", 1], ["lost_rockarray_a", 1]],
}
const PROF: Dictionary = {"n": 2.2, "n_baja": 1.6, "lado": 1.8, "s": 1.2, "rincon": 1.6}          ## fondo (casillas)
const ALTO_MAX: Dictionary = {"n": 4.5, "n_baja": 1.4, "lado": 2.2, "s": 0.9, "rincon": 2.0}    ## tope de alto (casillas)
const ASOMA: float = 0.15            ## casillas que la cara de la roca entra en la casilla de suelo (tapa la rendija)
const CERCA_DETRAS: int = 5          ## pared norte baja si hay suelo a 1..CERCA_DETRAS casillas detrás
const VARIA_ESCALA: float = 0.08     ## ± en la escala, por casilla
const VARIA_GIRO: float = 12.0       ## ± grados

const DIRS: Array = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]     ## hacia donde está el suelo: S, E, N, O
const GIROS: Array = [0.0, 90.0, 180.0, 270.0]                                             ## giro en Y que lleva el +Z de la pieza a esa dirección
const DIAG: Array = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1)]

static var _medidas: Dictionary = {}     ## pieza -> Vector3(ancho, alto, fondo) en casillas a escala 1 ([] si no existe)


## ¿Está el pack generado en esta máquina? (Si no, la maqueta vuelve a las paredes del kit.)
static func disponible() -> bool:
	return ResourceLoader.exists(RUTA + "lost_stonearray_b.tscn")


## Las rocas de la casilla de muro `c`: Array de [id, Transform3D] (origen = base de la pieza). `es_suelo` es un Callable(Vector2i) -> bool.
## `y` es la altura del suelo (ALTO de la maqueta).
static func rocas(c: Vector2i, es_suelo: Callable, y: float) -> Array:
	var res: Array = []
	var alguno: bool = false
	for i in range(4):
		var d: Vector2i = DIRS[i]
		if not es_suelo.call(c + d):
			continue
		alguno = true
		var lado: String = "lado"
		if d == Vector2i(0, 1):
			lado = "n_baja" if _sala_detras(c, es_suelo) else "n"
		elif d == Vector2i(0, -1):
			lado = "s"
		var r: Array = _roca(c, lado, Vector2(d), float(GIROS[i]), i, y)
		if not r.is_empty():
			res.append(r)
	if not alguno:
		for i in range(4):
			var dg: Vector2i = DIAG[i]
			if es_suelo.call(c + dg):
				var hacia: Vector2 = Vector2(dg).normalized()
				var r2: Array = _roca(c, "rincon", hacia, rad_to_deg(atan2(hacia.x, hacia.y)), 7 + i, y)     # +Z hacia (dx, dz): giro = atan2(dx, dz)
				if not r2.is_empty():
					res.append(r2)
				break
	var limpio: Array = []
	for e in res:
		limpio.append([e[0], e[1]])
	return limpio


## ¿Hay suelo de otra sala detrás de esta pared norte (1..CERCA_DETRAS casillas más al norte)?
static func _sala_detras(c: Vector2i, es_suelo: Callable) -> bool:
	for k in range(1, CERCA_DETRAS + 1):
		if es_suelo.call(c + Vector2i(0, -k)):
			return true
	return false


## [id, Transform3D, escala] de una roca de la paleta `lado` en la casilla `c`, mirando hacia `hacia` (vector de casillas hacia el suelo).
static func _roca(c: Vector2i, lado: String, hacia: Vector2, giro: float, sal: int, y: float) -> Array:
	var id: String = _elegir(PALETAS[lado], c, sal)
	var m: Vector3 = _medida(id)
	if m == Vector3.ZERO:
		return []
	var esc: float = minf(float(PROF[lado]) / m.z, float(ALTO_MAX[lado]) / m.y) * (1.0 + _jitter(c, sal + 3) * VARIA_ESCALA)
	var prof: float = m.z * esc
	# cara delantera = centro + hacia * prof/2; se quiere en el borde de la casilla + ASOMA: centro = c + hacia * (0,5 + ASOMA - prof/2)
	var k: float = 0.5 + ASOMA - prof * 0.5
	var centro := Vector3((float(c.x) + 0.5 + hacia.x * k) * S, y, (float(c.y) + 0.5 + hacia.y * k) * S)
	var b := Basis(Vector3.UP, deg_to_rad(giro + _jitter(c, sal + 5) * VARIA_GIRO)).scaled(Vector3.ONE * esc)
	return [id, Transform3D(b, centro), esc]


static func _elegir(paleta: Array, c: Vector2i, sal: int) -> String:
	var total: int = 0
	for e in paleta:
		total += int(e[1])
	var r: int = _hash(c, sal) % total
	for e in paleta:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return String(paleta[0][0])


## Ancho, alto y fondo (casillas) de la pieza a escala 1, medidos sobre su malla (con el giro que ya trae horneado). ZERO si no existe.
static func _medida(id: String) -> Vector3:
	if _medidas.has(id):
		return _medidas[id]
	var v := Vector3.ZERO
	if ResourceLoader.exists(RUTA + id + ".tscn"):
		var n: Node3D = (load(RUTA + id + ".tscn") as PackedScene).instantiate() as Node3D
		var mi: MeshInstance3D = n.get_node_or_null("modelo/malla") as MeshInstance3D
		if mi != null and mi.mesh != null:
			var caja: AABB = mi.transform * mi.mesh.get_aabb()
			v = Vector3(caja.size.x, caja.size.y, caja.size.z) / S
		n.free()
	_medidas[id] = v
	return v


static func _hash(c: Vector2i, sal: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ (sal * 83492791))


## -1..1 estable por casilla.
static func _jitter(c: Vector2i, sal: int) -> float:
	return float(_hash(c, sal) % 2001) / 1000.0 - 1.0
