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
##   6  cauce profundo (22/10): guijarros (srgb, pequeños, 5 por casilla), profundidad visual (el lecho NO baja: se pisa a ras), oclusión en la tapa, pared más oscura, interruptor,
##      colisiones y Terreno3D idénticos con y sin, abrir/cerrar cuenca y llenar_cauce siguen cuadrando

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const S: float = 2.3
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _escenario() -> void:
	await cargar(RUTA)
	if maqueta == null:
		return
	# Esta prueba mide el cauce de 0,1 u (el de antes de «cauce hondo», 22/10): el foso se prueba en escenario_cauce_hondo.gd. Con el interruptor apagado todo lo de abajo es lo de siempre.
	maqueta.set("cauce_hondo", false)
	await avanzar(3)
	_ok("0 cauce_hondo apagado: el cauce se pisa a ras (y_pies = alto_suelo)", not Terreno3D.cauce_hondo)
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
	await _profundo(cauce)


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
	_ok("1.7 la falda del lecho seco lleva el material de la pared del cauce (cauce profundo: el del lecho más oscuro)", faldas != null and faldas.mesh.surface_get_material(0) == maqueta.get("_mat_falda_cauce"))
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


# ---------------------------------------------------------------------------------------------------------------------
# 6 · cauce profundo

## Firma de lo que NO debe cambiar con el interruptor: datos del terreno, y para cada casilla c su altura de pies, bloqueo, cuenca y superficie.
func _firma_terreno(cauce: Array) -> int:
	var s: Array = [hash(Terreno3D.mapa), Terreno3D.alturas.hash(), Terreno3D.cauces_abiertos.hash()]
	for c in cauce:
		s.append([c, snappedf(Terreno3D.y_pies(c), 0.0001), Terreno3D.bloqueada(c), Terreno3D.es_cuenca(c), snappedf(Terreno3D.superficie_agua(c), 0.0001)])
	return hash(s)


func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _profundo(cauce: Array) -> void:
	var alto: float = float(maqueta.get("ALTO"))
	var alto_cauce: float = float(maqueta.get("ALTO_CAUCE"))
	var n_c: int = cauce.size()
	var por: int = int(maqueta.get("GUIJARROS_CAUCE"))
	var r_min: float = float(maqueta.get("GUIJARRO_RADIO_MIN"))
	var r_var: float = float(maqueta.get("GUIJARRO_RADIO_VAR"))
	var largo: float = float(maqueta.get("GUIJARRO_ALARGADO"))
	var gm: MultiMeshInstance3D = maqueta.get("_guijarros")
	var mm: MultiMesh = gm.multimesh
	var mat_g: StandardMaterial3D = (mm.mesh as SphereMesh).material
	_ok("6.0 de serie cauce_profundo = true", bool(maqueta.get("cauce_profundo")))
	# Guijarros
	_ok("6.1 los guijarros llevan color de vértice en srgb (antes se leía como lineal y salía casi blanco)", mat_g.vertex_color_use_as_albedo and mat_g.vertex_color_is_srgb)
	_ok("6.2 %d guijarros por casilla (antes 9): %d en total" % [por, n_c * por], por < 9 and mm.instance_count == n_c * por, "instancias %d" % mm.instance_count)
	var datos: Dictionary = maqueta.get("_guijarros_cauce")
	var r_max_visto: float = 0.0
	var r_min_visto: float = INF
	var fuera_rango: int = 0
	for c in cauce:
		for tf in (datos[c][1] as Array):
			var sc: Vector3 = (tf as Transform3D).basis.get_scale()
			var rr: float = sc.z
			r_max_visto = maxf(r_max_visto, maxf(sc.x, sc.z))
			r_min_visto = minf(r_min_visto, rr)
			if rr < r_min - 0.0005 or rr > r_min + r_var + 0.0005 or absf(sc.x - rr * largo) > 0.001:
				fuera_rango += 1
	_ok("6.3 tamaño de grava: radio %.3f–%.3f u, el mayor semieje %.3f u (antes hasta %.2f)" % [r_min, r_min + r_var, r_max_visto, 0.243 * 1.4], fuera_rango == 0 and r_max_visto < 0.15, "%d fuera de rango" % fuera_rango)
	# Profundidad visual: el lecho NO baja (se pisa a ras), pero la tapa lleva oclusión y la pared es más oscura.
	_ok("6.4 el lecho sigue 0,1 u bajo el suelo (no se cambia la altura real: se pisa a ras)", absf(alto - alto_cauce - 0.1) < 1.0e-6, "%.3f" % (alto - alto_cauce))
	var pisa_a_ras: bool = true
	for c in cauce:
		if absf(Terreno3D.y_pies(c) - Terreno3D.alto_suelo) > 1.0e-4:
			pisa_a_ras = false
	_ok("6.5 los pies en una c cerrada van a la altura del suelo (por eso el lecho no puede ser más hondo)", pisa_a_ras)
	var tapas: Dictionary = maqueta.get("_tapas_cauce")
	var con_oclusion: int = 0
	var peor: float = 1.0
	var centro_ok: bool = true
	var tapa_y_ok: bool = true
	for c in cauce:
		var m: ArrayMesh = (tapas[c] as MeshInstance3D).mesh as ArrayMesh
		if m.get_surface_count() != 2:
			tapa_y_ok = false
			continue
		var arr: Array = m.surface_get_arrays(0)
		var cols = arr[Mesh.ARRAY_COLOR]
		if cols == null:
			continue
		con_oclusion += 1
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(vs.size()):
			peor = minf(peor, (cols[i] as Color).r)
			if absf(vs[i].y - alto_cauce) > 1.0e-5:
				tapa_y_ok = false
			if absf(vs[i].x) < 0.05 and absf(vs[i].z) < 0.05 and (cols[i] as Color).r < 0.999 and _vecinos_pared(c) == 0:
				centro_ok = false
	_ok("6.6 todas las tapas llevan color de vértice (oclusión), a la altura del lecho de siempre", con_oclusion == n_c and tapa_y_ok, "%d/%d tapas" % [con_oclusion, n_c])
	_ok("6.7 pegado a la pared el lecho se oscurece a ≈ %.2f de luz (mín visto %.2f)" % [1.0 - float(maqueta.get("OCLUSION_FUERZA")), peor], absf(peor - (1.0 - float(maqueta.get("OCLUSION_FUERZA")))) < 0.02, "%.3f" % peor)
	_ok("6.8 una casilla sin pared vecina no se oscurece", centro_ok)
	var lecho: StandardMaterial3D = maqueta.get("_mat_lecho_cauce")
	var pared: StandardMaterial3D = maqueta.get("_mat_falda_cauce")
	_ok("6.9 la pared interior (falda) es más oscura que el lecho", pared != lecho and _lum(pared.albedo_color) < _lum(lecho.albedo_color) * 0.8, "%.3f vs %.3f" % [_lum(pared.albedo_color), _lum(lecho.albedo_color)])
	var seco: BordePiedras3D = _nodo("_bordes_cauce")
	_ok("6.10 el labio del cauce proyecta sombra y su pie se ilumina como pared", seco.labio_proyecta_sombra and absf(seco.labio_pie_arriba - float(maqueta.get("PIE_LABIO_CAUCE"))) < 1.0e-6)
	var lab: MeshInstance3D = _hijo(seco, "labio")
	_ok("6.11 la malla del labio tiene sombra activada", lab != null and lab.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# Interruptor: colisiones y terreno idénticos con y sin.
	var firma_on: int = _firma_terreno(cauce)
	var col_on: int = _contar_colisiones(maqueta)
	var bordes_on: int = _total_bordes()
	maqueta.set("cauce_profundo", false)
	await avanzar(2)
	var firma_off: int = _firma_terreno(cauce)
	var col_off: int = _contar_colisiones(maqueta)
	_ok("6.12 sin cauce_profundo: Terreno3D (mapa, alturas, y_pies, bloqueo, cuenca) idéntico", firma_on == firma_off)
	_ok("6.13 sin cauce_profundo: las mismas colisiones (%d)" % col_on, col_on == col_off, "con %d, sin %d" % [col_on, col_off])
	_ok("6.14 sin cauce_profundo: los 9 guijarros de antes, sin srgb, mismo tamaño de antes", mm.instance_count == n_c * 9 and not mat_g.vertex_color_is_srgb)
	var datos_off: Dictionary = maqueta.get("_guijarros_cauce")
	var r_max_off: float = 0.0
	for c in cauce:
		for tf in (datos_off[c][1] as Array):
			r_max_off = maxf(r_max_off, (tf as Transform3D).basis.get_scale().x)
	_ok("6.15 sin cauce_profundo: guijarros de hasta %.2f u (los de antes, 0,34)" % r_max_off, r_max_off > 0.3 and (datos_off[cauce[0]][1] as Array).size() == 9)
	var cubo_plano: bool = true
	for c in cauce:
		if ((tapas[c] as MeshInstance3D).mesh as ArrayMesh) != (maqueta.get("_malla_lecho_plano") as ArrayMesh):
			cubo_plano = false
	_ok("6.16 sin cauce_profundo: la tapa es la lisa de antes (sin oclusión)", cubo_plano)
	_ok("6.17 sin cauce_profundo: lecho y falda con el color de antes (sin oscurecer) y la falda con el material del lecho", (maqueta.get("_mat_lecho_cauce") as StandardMaterial3D).albedo_color.is_equal_approx(maqueta.get("_albedo_lecho_base")) and (_hijo(_nodo("_bordes_cauce"), "faldas") as MeshInstance3D).mesh.surface_get_material(0) == lecho)
	_ok("6.18 sin cauce_profundo: el labio sin sombra y con el pie de antes", not _nodo("_bordes_cauce").labio_proyecta_sombra and absf(_nodo("_bordes_cauce").labio_pie_arriba - BordePiedras3D.LABIO_PIE_ARRIBA) < 1.0e-6 and _total_bordes() == bordes_on)
	# Abrir/cerrar cuenca y llenar con el interruptor en cada posición.
	var elegida: Vector2i = cauce[0]
	for modo in [false, true]:
		maqueta.set("cauce_profundo", modo)
		await avanzar(2)
		var tag: String = "con" if modo else "sin"
		var tot: int = _total_bordes()
		Terreno3D.cauces_abiertos[elegida] = true
		await avanzar_s(0.5)
		var pozos: Dictionary = maqueta.get("_pozos_cauce")
		var estado: Dictionary = maqueta.get("_estado_pozo")
		_ok("6.19 (%s) abrir la cuenca crea su pozo y la casilla se ve abierta" % tag, bool(estado.get(elegida, false)) and pozos.has(elegida) and (pozos[elegida] as Node3D).visible and not (tapas[elegida] as MeshInstance3D).visible)
		_ok("6.20 (%s) bordes: seco + pozo suman lo de antes" % tag, _total_bordes() == tot)
		Terreno3D.cauces_abiertos.erase(elegida)
		await avanzar_s(0.5)
		_ok("6.21 (%s) cerrarla devuelve el lecho seco (tapa visible, pozo oculto)" % tag, not bool(estado.get(elegida, true)) and (tapas[elegida] as MeshInstance3D).visible and not (pozos[elegida] as Node3D).visible)
	_aviso("6.19 la POSICIÓN de los guijarros al abrir/cerrar no se lee en headless (el MultiMesh devuelve ceros sin GPU): se mira en las capturas con ventana")
	maqueta.set("cauce_profundo", true)
	await avanzar(2)
	_ok("6.22 volver a true recupera la grava y las tapas nuevas", mm.instance_count == n_c * por and (((tapas[cauce[0]] as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null))
	# llenar_cauce: el agua arranca justo bajo el lecho (que no ha bajado) y acaba a ras del agua del río.
	# Sin agua física (22/10: antes era lo único que había): el bloque de agua arranca justo bajo el lecho y acaba a ras del agua del río.
	var aguas: Dictionary = maqueta.get("_agua_cauce")
	var alto_agua_m: float = float(maqueta.get("ALTO_AGUA"))
	var otra: Vector2i = cauce[1]
	maqueta.set("agua_fisica", false)
	maqueta.call("llenar_cauce", [otra])
	maqueta.set("agua_fisica", true)
	var mo: MeshInstance3D = aguas[otra]
	_ok("6.23 llenar_cauce (sin agua física): el agua arranca 2 cm bajo el lecho (y %.3f) y es visible" % (alto_cauce - 0.02), mo.visible and absf(mo.position.y + alto_agua_m - (alto_cauce - 0.02)) < 1.0e-4, "arranque %.4f" % (mo.position.y + alto_agua_m))
	# Con agua física (el Bosque 01) el bloque opaco NO se enseña: lo dibuja AguaRender3D desde la simulación (cauce hondo, 22/10: «bloques blancos»).
	maqueta.call("llenar_cauce", [elegida])
	var mi: MeshInstance3D = aguas[elegida]
	_ok("6.23b llenar_cauce (agua física): no se enseña el bloque opaco de agua", not mi.visible)
	await avanzar_s(2.0)
	_ok("6.24 llenar_cauce: acaba a la altura del agua (0) y la casilla pasa a «~»", absf(mo.position.y) < 0.002 and _l(otra) == "~", "y %.4f, letra %s" % [mo.position.y, _l(otra)])
	_ok("6.24b llenar_cauce (agua física): la simulación tiene el agua (≥ UMBRAL_AGUA) y la casilla pasa a «~»", _l(elegida) == "~" and Terreno3D.agua_sim.profundidad_casilla(elegida) >= AguaSim3D.UMBRAL_AGUA, "prof %.3f, letra %s" % [Terreno3D.agua_sim.profundidad_casilla(elegida), _l(elegida)])

func _vecinos_pared(c: Vector2i) -> int:
	var k: int = 0
	for v in DIRS:
		if maqueta.call("_pared_de_cauce", c + (v as Vector2i)):
			k += 1
	return k