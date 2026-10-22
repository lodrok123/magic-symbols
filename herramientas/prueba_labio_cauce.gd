extends "res://herramientas/escenario_base.gd"
## Labio, falda y cantos en el borde del CAUCE SECO (casillas `c`) — «labio cauce» (22/10). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_labio_cauce.gd
## HONESTO: en headless no hay GPU; esto mide la GEOMETRÍA y los interruptores. Cómo SE VE se mira con `captura_labio_cauce.gd` (con ventana).
##
##   1  aristas: una por cada lado de casilla entre suelo normal y `c`; ninguna entre `c` y `c`, ni hacia agua, muro o vacío; la malla del labio está pegada a ellas
##   2  interruptores: `bisel_cauce`, `bisel_suelo` y `bordes_blandos` (solo labio)
##   3  colisiones y datos del terreno idénticos con y sin el labio; ningún nodo de borde colisiona
##   4  abrir una `c` como cuenca y cerrarla: las aristas pasan de seco a orilla y vuelven, sin duplicar ni dejar nada colgando
##   5  coste en triángulos

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const S: float = 2.3
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _escenario() -> void:
	await cargar(RUTA)
	if maqueta == null:
		return
	var cauce: Array = _casillas_cauce()
	_ok("0 el Bosque 01 tiene cauce seco", cauce.size() > 0, "%d casillas c" % cauce.size())
	if cauce.is_empty():
		return
	var esperadas: Array = _aristas_esperadas()
	_aristas(esperadas)
	await _interruptores()
	await _colisiones()
	await _cuenca(cauce)
	_coste()


# ---------------------------------------------------------------------------------------------------------------------

func _l(c: Vector2i) -> String:
	return Terreno3D.letra_de(c)


func _casillas_cauce() -> Array:
	var r: Array = []
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(lado):
		for x in range(lado):
			if _l(Vector2i(x, y)) == "c":
				r.append(Vector2i(x, y))
	return r


func _es_suelo(l: String) -> bool:
	return not (l == "~" or l == "b" or l == "#" or l == " " or l == "c")


## [casilla alta, dirección hacia la c] de cada lado suelo ↔ c.
func _aristas_esperadas() -> Array:
	var r: Array = []
	for c in _casillas_cauce():
		for v in DIRS:
			var n: Vector2i = (c as Vector2i) + (v as Vector2i)
			if _es_suelo(_l(n)) and Terreno3D.altura_en(n) == 0:
				r.append([n, -(v as Vector2i)])
	return r


func _nodo(nombre: String) -> BordePiedras3D:
	return maqueta.get(nombre) as BordePiedras3D


func _total_bordes() -> int:
	var a: BordePiedras3D = _nodo("_bordes_cauce")
	var b: BordePiedras3D = _nodo("_bordes_cauce_abierto")
	return (a.n_bordes() if a != null else 0) + (b.n_bordes() if b != null else 0)


## Al reconstruir, el nodo nuevo se llama «@MeshInstance3D@n» (el viejo aún ocupa el nombre): se distingue por la malla (el labio lleva UV2, la falda no).
func _hijo(b: Node, nombre: String) -> MeshInstance3D:
	for h in b.get_children():
		if h is MeshInstance3D and not h.is_queued_for_deletion() and (h as MeshInstance3D).mesh != null:
			var con_uv2: bool = (((h as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2] != null)
			if con_uv2 == (nombre == "labio"):
				return h as MeshInstance3D
	return null


func _vivos(b: Node) -> int:
	var k: int = 0
	for h in b.get_children():
		if not h.is_queued_for_deletion():
			k += 1
	return k


func _contar_colisiones(n: Node) -> int:
	var k: int = 0
	for h in n.get_children():
		if h is CollisionObject3D or h is CollisionShape3D:
			k += 1
		k += _contar_colisiones(h)
	return k


## Distancia en planta de un punto al segmento de la arista (casilla alta `g`, lado hacia `v`).
func _dist_arista(p: Vector3, g: Vector2i, v: Vector2i) -> float:
	var centro := Vector2((float(g.x) + 0.5) * S + float(v.x) * S * 0.5, (float(g.y) + 0.5) * S + float(v.y) * S * 0.5)
	var a := Vector2(absf(float(v.y)), absf(float(v.x)))
	var t: float = clampf((Vector2(p.x, p.z) - centro).dot(a), -S * 0.5, S * 0.5)
	return (Vector2(p.x, p.z) - (centro + a * t)).length()


func _aristas(esperadas: Array) -> void:
	var seco: BordePiedras3D = _nodo("_bordes_cauce")
	_ok("1.1 la maqueta crea los nodos de borde del cauce", seco != null and _nodo("_bordes_cauce_abierto") != null)
	if seco == null:
		return
	_ok("1.2 hay una arista por cada lado suelo ↔ c (%d)" % esperadas.size(), _total_bordes() == esperadas.size(), "nodos %d" % _total_bordes())
	# Ninguna entre c y c, ni hacia agua/muro/vacío: se comprueba con las esperadas (todas son suelo ↔ c por construcción) y con la malla.
	var mal_cc: int = 0
	for e in esperadas:
		var g: Vector2i = e[0]
		if not _es_suelo(_l(g)) or _l(g + (e[1] as Vector2i)) != "c":
			mal_cc += 1
	_ok("1.3 todas las aristas esperadas separan suelo normal y c (ninguna c↔c, agua, muro o vacío)", mal_cc == 0, "%d malas" % mal_cc)
	var labio: MeshInstance3D = _hijo(seco, "labio")
	_ok("1.4 hay labio en el lecho seco, con 4 triángulos por arista", labio != null and seco.n_triangulos_labio() == 4 * seco.n_bordes(), "%d tris / %d aristas" % [seco.n_triangulos_labio(), seco.n_bordes()])
	if labio == null:
		return
	var vs: PackedVector3Array = labio.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lejos: int = 0
	var y_min: float = INF
	var y_max: float = -INF
	for p in vs:
		var cerca: bool = false
		for e in esperadas:
			if _dist_arista(p, e[0], e[1]) <= 0.26:
				cerca = true
				break
		if not cerca:
			lejos += 1
		y_min = minf(y_min, p.y)
		y_max = maxf(y_max, p.y)
	_ok("1.5 todo vértice del labio está pegado a una arista suelo ↔ c", lejos == 0, "%d de %d lejos" % [lejos, vs.size()])
	var alto: float = float(maqueta.get("ALTO"))
	var alto_cauce: float = float(maqueta.get("ALTO_CAUCE"))
	_ok("1.6 el labio va entre el lecho y 5 cm sobre el suelo", y_min >= alto_cauce - 0.001 and y_max <= alto + 0.06, "y %.3f..%.3f (lecho %.3f, suelo %.3f)" % [y_min, y_max, alto_cauce, alto])
	var faldas: MeshInstance3D = _hijo(seco, "faldas")
	_ok("1.7 la falda del lecho seco lleva el material del lecho", faldas != null and faldas.mesh.surface_get_material(0) == maqueta.get("_mat_lecho_cauce"))
	_ok("1.8 el labio lleva el material del suelo (shader: estado y joints)", labio.mesh.surface_get_material(0) == maqueta.get("_mat_suelo"))
	# Nada duplicado con las orillas de agua: ninguna arista de agua es suelo ↔ c.
	var agua: BordePiedras3D = _nodo("_bordes")
	_ok("1.9 las orillas de agua no cuentan lados hacia c (no hay duplicado)", agua != null)


func _interruptores() -> void:
	var seco: BordePiedras3D = _nodo("_bordes_cauce")
	var n0: int = _total_bordes()
	maqueta.set("bisel_cauce", false)
	maqueta.call("reconstruir_bordes_cauce")
	await avanzar(2)
	_ok("2.1 bisel_cauce = false: sin aristas ni mallas", _total_bordes() == 0 and _vivos(seco) == 0, "%d bordes, %d hijos" % [_total_bordes(), _vivos(seco)])
	maqueta.set("bisel_cauce", true)
	maqueta.call("reconstruir_bordes_cauce")
	_ok("2.2 volver a true las trae de nuevo (%d)" % n0, _total_bordes() == n0)
	maqueta.set("bisel_suelo", false)
	maqueta.call("reconstruir_bordes_cauce")
	_ok("2.3 bisel_suelo = false también lo apaga", _total_bordes() == 0)
	maqueta.set("bisel_suelo", true)
	maqueta.set("bordes_blandos", false)
	maqueta.call("reconstruir_bordes_cauce")
	_ok("2.4 bordes_blandos = false deja solo labio (ni falda ni cantos)", _total_bordes() == n0 and seco.n_piedras() == 0 and _hijo(seco, "faldas") == null and seco.n_triangulos_labio() > 0)
	maqueta.set("bordes_blandos", true)
	maqueta.call("reconstruir_bordes_cauce")
	await avanzar(2)            # los hijos viejos se liberan al fotograma siguiente; mientras tanto el nuevo se llama «@MeshInstance3D@n»
	_ok("2.5 de serie vuelve todo", _total_bordes() == n0 and seco.n_piedras() > 0 and _hijo(seco, "faldas") != null, "bordes %d/%d, cantos %d, faldas %s" % [_total_bordes(), n0, seco.n_piedras(), str(seco.get_children().map(func(h): return str(h.name) + ("(q)" if h.is_queued_for_deletion() else "")))])


func _colisiones() -> void:
	var h_mapa: int = hash(Terreno3D.mapa)
	var h_alt: int = Terreno3D.alturas.hash()
	var con: int = _contar_colisiones(maqueta)
	maqueta.set("bisel_cauce", false)
	maqueta.call("reconstruir_bordes_cauce")
	await avanzar(2)
	var sin: int = _contar_colisiones(maqueta)
	maqueta.set("bisel_cauce", true)
	maqueta.call("reconstruir_bordes_cauce")
	await avanzar(2)
	_ok("3.1 mismas colisiones con y sin labio (%d)" % con, con == sin, "con %d, sin %d" % [con, sin])
	_ok("3.2 ningún nodo de borde del cauce lleva colisión", _contar_colisiones(_nodo("_bordes_cauce")) == 0 and _contar_colisiones(_nodo("_bordes_cauce_abierto")) == 0)
	_ok("3.3 Terreno3D.mapa y alturas intactos", hash(Terreno3D.mapa) == h_mapa and Terreno3D.alturas.hash() == h_alt)


func _cuenca(cauce: Array) -> void:
	# Una c con vecinos de suelo y ninguna otra c abierta alrededor.
	var elegida: Vector2i = cauce[0]
	var mejor: int = -1
	for c in cauce:
		var k: int = 0
		for v in DIRS:
			if _es_suelo(_l((c as Vector2i) + (v as Vector2i))):
				k += 1
		if k > mejor:
			mejor = k
			elegida = c
	var seco: BordePiedras3D = _nodo("_bordes_cauce")
	var abierto: BordePiedras3D = _nodo("_bordes_cauce_abierto")
	var total0: int = _total_bordes()
	var seco0: int = seco.n_bordes()
	var lados: int = mejor
	_ok("4.0 punto de partida: todo seco y nada de orilla de pozo", abierto.n_bordes() == 0 and seco0 == total0)
	Terreno3D.cauces_abiertos[elegida] = true
	await avanzar_s(0.5)
	_ok("4.1 abierta la cuenca %s: sus %d lados pasan a orilla (nodo de pozo)" % [elegida, lados], abierto.n_bordes() == lados and seco.n_bordes() == seco0 - lados, "pozo %d, seco %d" % [abierto.n_bordes(), seco.n_bordes()])
	_ok("4.2 sin duplicar: seco + pozo = el total de antes", _total_bordes() == total0)
	var lab_ab: MeshInstance3D = _hijo(abierto, "labio")
	var faldas_ab: MeshInstance3D = _hijo(abierto, "faldas")
	_ok("4.3 la orilla del pozo lleva labio y su falda baja al fondo del pozo (material del costado)", lab_ab != null and faldas_ab != null and faldas_ab.mesh.surface_get_material(0) == maqueta.get("_mat_lado_suelo"))
	if faldas_ab != null:
		var vs: PackedVector3Array = faldas_ab.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var y_min: float = INF
		for p in vs:
			y_min = minf(y_min, p.y)
		var fondo: float = Terreno3D.alto_agua - Terreno3D.LECHO_AGUA
		_ok("4.4 esa falda llega al fondo del pozo (%.3f), no flota a la altura del lecho seco" % fondo, absf(y_min - fondo) < 0.01, "y mín %.3f" % y_min)
	var viejos: int = _vivos(seco)
	Terreno3D.cauces_abiertos.erase(elegida)
	await avanzar_s(0.5)
	_ok("4.5 cerrada otra vez: todo vuelve a seco (%d) y el nodo del pozo queda vacío" % total0, seco.n_bordes() == seco0 and abierto.n_bordes() == 0 and _vivos(abierto) == 0, "seco %d, pozo %d, hijos pozo %d" % [seco.n_bordes(), abierto.n_bordes(), _vivos(abierto)])
	_ok("4.6 abrir y cerrar no acumula nodos (hijos vivos %d → %d)" % [viejos, _vivos(seco)], _vivos(seco) == viejos)
	var n_nodos: int = 0
	for h in maqueta.get_children():
		if String(h.name).begins_with("BordesCauce") and not h.is_queued_for_deletion():
			n_nodos += 1
	_ok("4.7 siguen siendo solo dos nodos BordesCauce en la maqueta", n_nodos == 2, str(n_nodos))
	# Dos cuencas vecinas: la arista entre ellas no existe (c↔c) y las demás se reparten.
	var vecina: Vector2i = Vector2i(-1, -1)
	for v in DIRS:
		if _l(elegida + (v as Vector2i)) == "c":
			vecina = elegida + (v as Vector2i)
			break
	if vecina.x >= 0:
		Terreno3D.cauces_abiertos[elegida] = true
		Terreno3D.cauces_abiertos[vecina] = true
		await avanzar_s(0.5)
		_ok("4.8 dos cuencas vecinas: seco + pozo sigue sumando el total", _total_bordes() == total0, "%d vs %d" % [_total_bordes(), total0])
		Terreno3D.cauces_abiertos.erase(elegida)
		Terreno3D.cauces_abiertos.erase(vecina)
		await avanzar_s(0.5)
		_ok("4.9 y al cerrarlas, todo seco", _nodo("_bordes_cauce").n_bordes() == seco0 and _nodo("_bordes_cauce_abierto").n_bordes() == 0)
	else:
		_aviso("4.8 la casilla elegida no tiene c vecina: no se probó la pareja de cuencas")


func _coste() -> void:
	var seco: BordePiedras3D = _nodo("_bordes_cauce")
	var n: int = seco.n_bordes()
	var tri_labio: int = seco.n_triangulos_labio()
	var tri_falda: int = 2 * n
	var canto: ArrayMesh = BordePiedras3D._malla_canto()
	var tri_canto: int = (canto.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var tri_piedras: int = seco.n_piedras() * tri_canto
	var nodos: int = 0
	for h in seco.get_children():
		if not h.is_queued_for_deletion():
			nodos += 1
	_ok("5.1 coste: %d aristas · labio %d + falda %d + %d cantos × %d = %d triángulos extra en %d nodos (no uno por casilla)" % [n, tri_labio, tri_falda, seco.n_piedras(), tri_canto, tri_labio + tri_falda + tri_piedras, nodos], nodos <= 3)
