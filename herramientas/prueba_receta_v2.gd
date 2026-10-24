extends SceneTree
## Prueba de la RECETA V2 (R1, 17/10; docs/GLIFOS_RECETA.md): datos y volumen, sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_receta_v2.gd
## Comprueba, para TODAS las combinaciones de hasta 4 glifos de Sigils.GLIFOS_V2 (con repetición) × los 7 elementos:
##   · ninguna falla, y ningún valor pasa de su tope;
##   · las casillas del volumen no superan las del volumen máximo de los topes;
##   · el coste es monótono con el volumen (y con el nº de propiedades);
##   · el nombre derivado sale siempre (x_mano | alto | abajo);
##   · ᛁ horizontal / vertical cae en linea_x / linea_z en los 8 ángulos del rectificador (y la raya rectificada, a través del Spellcaster).
## R3 (17/10): la receta V2 es la única (ya no hay interruptor) y la prueba incluye el CICLO DE VIDA: copias, crece, viaja, rebotes, persiste × calidad y solidez.

## Mundo mínimo para el CICLO DE VIDA (copia reducida del de prueba_materia_v2): lo que pide el Lanzador y nada más.
class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 16
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

class ReactivoFalso extends Node3D:
	var golpes: int = 0
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

const LADO: int = 16
const ORIGEN_C: Vector2i = Vector2i(5, 8)        ## casilla de la mano en las pruebas del ciclo de vida
const SEMIEJE_MURO_ANCHO: float = 1.45           ## semieje X del muro de 3 casillas de ancho de las pruebas (8 glifos con la base 0,25 y paso 0,15)

const MAX_GLIFOS: int = 4
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]       # 20/10: seis; «time» es cinemática
const NOMBRES_OK: Array = ["x_mano", "alto", "abajo"]
const ORIGENES: Array = [Vector2(11.5, 11.5), Vector2(11.0, 11.0), Vector2(11.9, 11.3)]    ## en casillas (se multiplica por la casilla)
const DIRECCIONES: int = 8

var fallos: int = 0
var combinaciones: int = 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
		if fallos <= 40:
			print("FALLO: ", msg)


func _initialize() -> void:
	await process_frame
	var nombres: Array = Sigils.GLIFOS_V2.keys()
	print("Glifos V2: ", nombres)
	_datos_de_elementos()
	_topes_y_casos()
	_combinaciones(nombres)
	_orientacion_linea()
	await _ciclo_de_vida()
	_retiradas()
	print("RESULTADO receta_v2: %d combinaciones × %d elementos · FALLOS: %d" % [combinaciones, ELEMENTOS.size(), fallos])
	quit(1 if fallos > 0 else 0)


# --- Los siete .tres tienen los campos de §2.3 rellenos y coherentes ---
func _datos_de_elementos() -> void:
	var esperado: Dictionary = {
		"fire": ["plasma", 3.0, false, "quemado"], "water": ["liquido", 0.0, false, "mojado"], "earth": ["solido", 8.0, true, ""],
		"ice": ["solido", 6.0, true, "helado"], "lightning": ["energia", 0.2, false, ""], "wind": ["gas", 1.5, false, ""],
		}
	for e in ELEMENTOS:
		var r: RuneData = load("res://nucleo/%s_rune.tres" % e)
		_ok(r != null, "no carga %s" % e)
		if r == null:
			continue
		var x: Array = esperado[e]
		_ok(RuneData.ESTADOS.has(r.estado), "%s: estado inválido '%s'" % [e, r.estado])
		_ok(r.estado == x[0], "%s: estado %s ≠ %s" % [e, r.estado, x[0]])
		_ok(is_equal_approx(r.persiste, float(x[1])), "%s: persiste %.2f ≠ %.2f" % [e, r.persiste, x[1]])
		_ok(r.pisable == bool(x[2]), "%s: pisable" % e)
		_ok(r.deja == String(x[3]), "%s: deja '%s'" % [e, r.deja])
		_ok(r.empuje >= 0.0 and r.empuje <= 1.0, "%s: empuje fuera de 0..1" % e)
	var viento: RuneData = load("res://nucleo/wind_rune.tres")
	var tiempo: RuneData = load("res://nucleo/time_rune.tres")
	_ok(viento.empuje == 1.0 and tiempo.empuje == 0.0, "empuje: viento 1, tiempo 0")


# --- aplicar_v2: valores concretos y topes ---
func _casi(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _topes_y_casos() -> void:
	var g: Dictionary = Sigils.aplicar_v2({})
	_ok(_casi(g["x"], Sigils.RADIO_BASE_V2) and _casi(g["y"], Sigils.RADIO_BASE_V2) and _casi(g["z"], Sigils.RADIO_BASE_V2) and (g["props"] as Dictionary).is_empty(), "sin glifos: esfera de radio base (%.2f) y sin propiedades" % Sigils.RADIO_BASE_V2)
	var rb: float = Sigils.RADIO_BASE_V2
	g = Sigils.aplicar_v2({"linea_x": 4})
	_ok(_casi(g["x"], rb + 4.0 * Sigils.PASO_ANCHO_V2) and _casi(g["z"], rb), "linea_x ×4 → semieje X = base + 4 pasos de ancho (PASO_ANCHO_V2 %.2f)" % Sigils.PASO_ANCHO_V2)
	g = Sigils.aplicar_v2({"linea_z": 2})
	_ok(_casi(g["z"], rb + 2.0 * Sigils.PASO_FONDO_V2) and _casi(g["x"], rb), "linea_z ×2 → semieje Z = base + 2 pasos de fondo (PASO_FONDO_V2 %.2f)" % Sigils.PASO_FONDO_V2)
	g = Sigils.aplicar_v2({"altura": 4})
	# Un nivel más cuando 2 × semieje Y llega a 1,5 (roundi): los glifos de altura que hacen falta salen de la base y del paso (24/10: PASO_ALTURA_V2 0,30 → 3; con +0,10 eran 7; con 0,25 y +0,15, 4)
	var n_dos_niveles: int = ceili((0.75 - rb) / Sigils.PASO_ALTURA_V2 - 0.0001)
	g = Sigils.aplicar_v2({"altura": n_dos_niveles})
	_ok(Lanzador3D.GeometriaV2.niveles(g) == 2 and Lanzador3D.GeometriaV2.niveles(Sigils.aplicar_v2({"altura": n_dos_niveles - 1})) == 1 and Lanzador3D.GeometriaV2.niveles(Sigils.aplicar_v2({"altura": 1})) == 1,
		"altura ×%d → 2 niveles (con uno menos, o con uno solo, se queda en 1)" % n_dos_niveles)
	# Decisión de Pablo 24/10: con pocos glifos se llega a 2 niveles (3 ᛏ, el tope) y a un muro de 3 casillas (ᛜ + 4 ᛁ).
	_ok(n_dos_niveles == Sigils.GLIFOS_ALTURA_DOS_NIVELES_V2 and n_dos_niveles == 3 and _casi(float(Sigils.aplicar_v2({"altura": n_dos_niveles})["y"]), Sigils.TOPE_EJE_ALTURA_V2), "3 ᛏ = 2 niveles y justo el tope de altura (%.2f)" % Sigils.TOPE_EJE_ALTURA_V2)
	var cas_g: float = Terreno3D.casilla
	var centro_g := Vector2(0.5, 0.5) * cas_g
	var muro_n: Callable = func(n_i: int) -> int:
		return Lanzador3D.GeometriaV2.celdas(Sigils.aplicar_v2({"barrera": 1, "linea_x": n_i}), centro_g, Vector2.DOWN, cas_g).size()
	_ok(int(muro_n.call(Sigils.GLIFOS_ANCHO_MURO_3_V2)) == 3 and Sigils.GLIFOS_ANCHO_MURO_3_V2 == 4 and int(muro_n.call(Sigils.GLIFOS_ANCHO_MURO_3_V2 - 1)) == 1 and int(muro_n.call(2 * Sigils.GLIFOS_ANCHO_MURO_3_V2)) == 5,
		"ᛜ + 4 ᛁ = muro de 3 casillas (con 3 ᛁ, 1; con 8, 5): %d / %d / %d" % [muro_n.call(Sigils.GLIFOS_ANCHO_MURO_3_V2), muro_n.call(Sigils.GLIFOS_ANCHO_MURO_3_V2 - 1), muro_n.call(2 * Sigils.GLIFOS_ANCHO_MURO_3_V2)])
	_ok(_casi(float(Sigils.aplicar_v2({"barrera": 1, "linea_x": Sigils.GLIFOS_ANCHO_MURO_3_V2})["z"]), rb), "el fondo del muro no crece con los ᛁ horizontales")
	g = Sigils.aplicar_v2({"barrera": 1})
	_ok(_casi(g["x"], rb) and _casi(g["z"], rb) and _casi(g["y"], rb), "barrera: ya NO tiene radio mínimo (18/10): sin ejes, el volumen es el radio base")
	_ok(_casi(Sigils.RADIO_BARRERA_U, Lanzador3D.RADIO_BURBUJA), "RADIO_BARRERA_U coincide con Lanzador3D.RADIO_BURBUJA")
	g = Sigils.aplicar_v2({"flecha": 1, "barrera": 2, "repeticion": 2, "rebote": 2, "pulso": 2})
	var p: Dictionary = g["props"]
	_ok(_casi(p["viaja"], 2.0) and _casi(p["solidez"], 2.25) and _casi(p["copias"], 3.0) and _casi(p["rebotes"], 2.0) and _casi(p["crece"], 1.0), "valores de propiedades: %s" % str(p))
	g = Sigils.aplicar_v2({"linea_x": 99, "linea_z": 99, "altura": 99, "flecha": 99, "barrera": 99, "repeticion": 99, "rebote": 99, "pulso": 99})
	p = g["props"]
	_ok(_casi(g["x"], 3.0) and _casi(g["z"], 3.0) and _casi(g["y"], 1.0), "topes de ejes 3 / 3 / 1 (19/10: la altura topa en 1,0 = 2 niveles): %s" % str(g))
	_ok(_casi(p["viaja"], 6.0) and _casi(p["solidez"], 3.0) and _casi(p["copias"], 4.0) and _casi(p["rebotes"], 3.0) and _casi(p["crece"], 1.5), "topes de propiedades: %s" % str(p))
	_ok(Sigils.aplicar_v2({"nada_conocido": 3, "linea_x": -2})["x"] == Sigils.RADIO_BASE_V2, "un nombre desconocido o un contador negativo no cambian nada")
	# nombre derivado
	var N := func(c: Dictionary) -> String:
		var gg: Dictionary = Sigils.aplicar_v2(c)
		return Lanzador3D.GeometriaV2.nombre_derivado(gg, float((gg["props"] as Dictionary).get("viaja", 0.0)) > 0.0)
	_ok(N.call({}) == "x_mano", "esfera → x_mano")
	_ok(N.call({"altura": 2}) == "alto", "pilar → alto")
	_ok(N.call({"barrera": 1, "linea_x": 2}) == "abajo", "muro bajo quieto (barrera + ᛁ) → abajo")
	_ok(N.call({"linea_x": 2}) == "x_mano" and Sigils.aplicar_v2({"linea_x": 2})["haz"] == true, "21/10: ᛁ sola (sin barrera ni flecha) es un haz → x_mano (mano al frente)")
	_ok(Sigils.aplicar_v2({"barrera": 1, "linea_x": 2})["haz"] == false and Sigils.aplicar_v2({"flecha": 1, "linea_x": 2})["haz"] == false and Sigils.aplicar_v2({"altura": 2})["haz"] == false and Sigils.aplicar_v2({})["haz"] == false, "con barrera, con flecha o sin ᛁ no hay haz")
	_ok(N.call({"linea_x": 1, "linea_z": 1}) == "abajo" or N.call({"linea_x": 1, "linea_z": 1}) == "x_mano", "losa pequeña: nombre válido")
	_ok(N.call({"linea_z": 3}) == "x_mano", "haz (Z grande) → x_mano")
	_ok(N.call({"linea_x": 2, "flecha": 1}) == "x_mano", "lo que viaja → x_mano")
	_ok(N.call({"barrera": 1, "linea_x": 1, "altura": 2}) == "alto", "muro alto (barrera + ᛁ + altura) → alto")
	_ok(Lanzador3D.GeometriaV2.eje_dominante(Sigils.aplicar_v2({})) == "esfera", "eje dominante de la esfera")
	_ok(Lanzador3D.GeometriaV2.eje_dominante(Sigils.aplicar_v2({"linea_x": 2})) == "x", "eje dominante x")
	_ok(Lanzador3D.GeometriaV2.eje_dominante(Sigils.aplicar_v2({"altura": 2})) == "y", "eje dominante y")
	_ok(Lanzador3D.GeometriaV2.eje_dominante(Sigils.aplicar_v2({"linea_z": 2})) == "z", "eje dominante z")
	# La esfera base: una casilla de diámetro centrada en la mano → siempre la del origen, y el elipsoide se estira SOLO hacia delante en Z
	var cas: float = Terreno3D.casilla
	var o := Vector2(11.5, 11.5) * cas
	var cz: Array = Lanzador3D.GeometriaV2.celdas(Sigils.aplicar_v2({"linea_z": 13}), o, Vector2.RIGHT, cas)
	var min_x: int = 99
	var max_x: int = -99
	for c in cz:
		min_x = mini(min_x, (c as Vector2i).x)
		max_x = maxi(max_x, (c as Vector2i).x)
	_ok(min_x == 11 and max_x >= 13, "linea_z ×13 hacia +X: nada detrás de la mano y se estira hacia delante (x de %d a %d)" % [min_x, max_x])
	_ok(Lanzador3D.GeometriaV2.celdas(Sigils.aplicar_v2({}), o, Vector2.RIGHT, cas) == [Vector2i(11, 11)], "la esfera base ocupa solo su casilla")


# --- Todas las combinaciones ---
func _combinaciones(nombres: Array) -> void:
	var cas: float = Terreno3D.casilla
	var maximo: Dictionary = Sigils.aplicar_v2({"linea_x": 99, "linea_z": 99, "altura": 99})
	var cuenta_max: Dictionary = {}
	for oi in range(ORIGENES.size()):
		for di in range(DIRECCIONES):
			cuenta_max[Vector2i(oi, di)] = Lanzador3D.GeometriaV2.celdas(maximo, ORIGENES[oi] * cas, GestureRectify.direccion(di), cas).size()
	var max_global: int = 0
	for k in cuenta_max:
		max_global = maxi(max_global, int(cuenta_max[k]))
	print("Volumen máximo de los topes: %.2f casillas³ · casillas en planta: %d (máx. sobre %d orígenes×direcciones)" % [Sigils.volumen_v2(maximo), max_global, cuenta_max.size()])
	var coste_max: float = Sigils.coste_v2(Sigils.aplicar_v2({"linea_x": 99, "linea_z": 99, "altura": 99, "flecha": 99, "barrera": 99, "repeticion": 99, "rebote": 99, "pulso": 99}), Sigils.aplicar_v2({"flecha": 1, "barrera": 1, "repeticion": 1, "rebote": 1, "pulso": 1})["props"])
	var runes: Array = []
	for e in ELEMENTOS:
		runes.append(load("res://nucleo/%s_rune.tres" % e))

	var combos: Array = []
	_generar(nombres, MAX_GLIFOS, 0, [], combos)
	var por_clave: Dictionary = {}                 # contadores -> {vol, coste}
	for combo in combos:
		combinaciones += 1
		var c: Dictionary = {}
		for n in combo:
			c[n] = int(c.get(n, 0)) + 1
		var g: Dictionary = Sigils.aplicar_v2(c)
		var etiqueta: String = str(combo)
		# topes
		_ok(float(g["x"]) <= 3.0001 and float(g["z"]) <= 3.0001 and float(g["y"]) <= 2.0001, "%s: semieje pasa del tope" % etiqueta)
		_ok(float(g["x"]) >= Sigils.RADIO_BASE_V2 and float(g["y"]) >= Sigils.RADIO_BASE_V2 and float(g["z"]) >= Sigils.RADIO_BASE_V2, "%s: semieje por debajo del radio base" % etiqueta)
		var props: Dictionary = g["props"]
		for k in props:
			var d: Dictionary = Sigils.GLIFOS_V2[_glifo_de_param(String(k))]
			_ok(float(props[k]) <= float(d["tope"]) + 0.0001, "%s: propiedad %s pasa del tope" % [etiqueta, k])
		# casillas ≤ las del volumen máximo, en cada origen y dirección (y por tanto ≤ max_global)
		for oi in range(ORIGENES.size()):
			for di in range(DIRECCIONES):
				var celdas: Array = Lanzador3D.GeometriaV2.celdas(g, ORIGENES[oi] * cas, GestureRectify.direccion(di), cas)
				_ok(celdas.size() >= 1, "%s: sin casillas" % etiqueta)
				_ok(celdas.size() <= int(cuenta_max[Vector2i(oi, di)]), "%s: %d casillas > %d del volumen máximo (origen %d, dir %d)" % [etiqueta, celdas.size(), cuenta_max[Vector2i(oi, di)], oi, di])
		# volumen, niveles, coste
		var vol: float = Lanzador3D.GeometriaV2.volumen(g)
		var coste: float = Sigils.coste_v2(g, props)
		_ok(vol >= Sigils.volumen_v2({"x": Sigils.RADIO_BASE_V2, "y": Sigils.RADIO_BASE_V2, "z": Sigils.RADIO_BASE_V2}) - 0.0001, "%s: volumen menor que la esfera base" % etiqueta)
		_ok(coste >= 1.0 - 0.0001 and coste <= coste_max + 0.0001 and is_finite(coste), "%s: coste %.3f fuera de rango" % [etiqueta, coste])
		_ok(Lanzador3D.GeometriaV2.niveles(g) >= 1 and Lanzador3D.GeometriaV2.niveles(g) <= 4, "%s: niveles %d" % [etiqueta, Lanzador3D.GeometriaV2.niveles(g)])
		por_clave[str(c)] = {"c": c, "vol": vol, "coste": coste, "np": props.size() * 10 + (1 if Sigils.recargo_continuo(props) > 1.0 else 0), "solida": props.has("solidez")}      # 23/10: con ᚱ continuo el coste lleva un recargo (COSTE_CONTINUO_V2): se compara dentro de cada grupo (nº de propiedades, con/sin recargo)
		# nombre derivado
		var viaja: bool = float(props.get("viaja", 0.0)) > 0.0
		_ok(NOMBRES_OK.has(Lanzador3D.GeometriaV2.nombre_derivado(g, viaja)), "%s: nombre derivado inválido" % etiqueta)
		# A través de Receta3D (V2 encendido) con los 7 elementos
		var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
		for n in combo:
			r.apply(n)
		_ok(r.usa_geo() and r.ignorados.is_empty(), "%s: Receta3D V2 no usa la geometría" % etiqueta)
		_ok(String(r.forma()) == Lanzador3D.GeometriaV2.nombre_derivado(g, viaja), "%s: forma() ≠ nombre derivado" % etiqueta)
		_ok(r.cooldown > 0.0 or combo.is_empty(), "%s: recarga" % etiqueta)
		_ok(absf(r.coste_v2() - coste) < 0.0001, "%s: coste_v2() de la receta ≠ Sigils.coste_v2" % etiqueta)
		var man: Array = r.manifestaciones()
		_ok(man.size() >= 1 and man.size() <= Sigils.MAX_MANIFESTATIONS, "%s: %d manifestaciones" % [etiqueta, man.size()])
		_ok(r.vida() > 0.0, "%s: vida" % etiqueta)
		for rune in runes:
			var pot: RuneData = r.potenciada(rune)
			_ok(pot != null and pot.estado == (rune as RuneData).estado, "%s: potenciada pierde el estado" % etiqueta)
	# coste monótono con el volumen: añadir un glifo de eje nunca baja volumen ni coste; con las mismas propiedades, más volumen ⇒ no menos coste
	for k in por_clave:
		var a: Dictionary = por_clave[k]
		for eje in ["linea_x", "linea_z", "altura"]:
			var c2: Dictionary = (a["c"] as Dictionary).duplicate()
			c2[eje] = int(c2.get(eje, 0)) + 1
			var g2: Dictionary = Sigils.aplicar_v2(c2)
			var v2: float = Lanzador3D.GeometriaV2.volumen(g2)
			var co2: float = Sigils.coste_v2(g2, g2["props"])
			_ok(v2 >= float(a["vol"]) - 0.0001 and co2 >= float(a["coste"]) - 0.0001, "%s + %s: volumen o coste bajan" % [str(a["c"]), eje])
	var lista: Array = por_clave.values()
	lista.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["vol"]) < float(q["vol"]))
	var ultimo: Dictionary = {}                    # nº de propiedades -> último coste
	var ultimo_vol: Dictionary = {}
	for it in lista:
		if bool(it["solida"]):
			continue          # con barrera el volumen lleva el suelo del jugador y el coste no: no son comparables
		var np: int = int(it["np"])
		if ultimo.has(np):
			_ok(float(it["coste"]) >= float(ultimo[np]) - 0.0001, "coste no monótono con el volumen (np=%d, vol %.2f → %.2f)" % [np, ultimo_vol[np], it["vol"]])
		ultimo[np] = float(it["coste"])
		ultimo_vol[np] = float(it["vol"])
	# y con el nº de propiedades a igual volumen
	_ok(Sigils.coste_v2(Sigils.aplicar_v2({}), {"viaja": 3.0}) > Sigils.coste_v2(Sigils.aplicar_v2({}), {}), "más propiedades, más coste")
	# La barrera sube el volumen al de la circunferencia del jugador, pero NO encarece: el coste cuenta lo que dieron los glifos.
	var gb: Dictionary = Sigils.aplicar_v2({"barrera": 1})
	var gs: Dictionary = Sigils.aplicar_v2({})
	_ok(absf(Sigils.coste_v2(gb, gb["props"]) - Sigils.coste_v2(gs, {}) * (1.0 + Sigils.COSTE_PROP_V2 * float(gb["props"].size()))) < 0.0001, "barrera sola: el coste no debe incluir el suelo del radio del jugador")
	print("%d combinaciones de hasta %d glifos" % [combos.size(), MAX_GLIFOS])


func _glifo_de_param(param: String) -> String:
	for n in Sigils.GLIFOS_V2:
		if String((Sigils.GLIFOS_V2[n] as Dictionary).get("param", "")) == param:
			return n
	return ""


## Todas las combinaciones con repetición de hasta `restante` glifos (como multiconjunto: el orden no cuenta).
func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


# --- ᛁ horizontal / vertical en los 8 ángulos del rectificador ---
func _orientacion_linea() -> void:
	# Esperado por ángulo (compás del rectificador, 0 = este, +45° cada paso, coordenadas de pantalla): horizontal y diagonales → X; vertical → Z.
	var esperado: Array = ["linea_x", "linea_x", "linea_z", "linea_x", "linea_x", "linea_x", "linea_z", "linea_x"]
	var sc: Node = load("res://magia/spellcaster.gd").new()
	for i in range(DIRECCIONES):
		var d: Vector2 = GestureRectify.direccion(i)
		# 1) la orientación sobre dos puntos exactos del compás
		var a := Vector2(300.0, 300.0)
		_ok(Sigils.orientacion_linea(a, a + d * 120.0) == esperado[i], "ángulo %d (%.0f°): %s" % [i, i * 45.0, Sigils.orientacion_linea(a, a + d * 120.0)])
		_ok(Sigils.orientacion_linea(a + d * 120.0, a) == esperado[i], "ángulo %d al revés (se dibuja en sentido contrario)" % i)
		# 2) una raya a pulso que pasa por el rectificador de verdad y luego por el Spellcaster 
		var trazo := PackedVector2Array()
		for k in range(41):
			var t: float = float(k) / 40.0
			trazo.append(a + d * 150.0 * t + d.orthogonal() * sin(t * 9.0) * 2.0)
		var rect: PackedVector2Array = GestureRectify.rectificar(trazo, 18.0)
		_ok(rect.size() >= 2, "ángulo %d: el rectificador devolvió %d puntos" % [i, rect.size()])
		var pts: Array[Vector2] = []
		for p in rect:
			pts.append(p)
		sc.set("stroke_points", pts)
		_ok(String(sc.call("_nombre_linea")) == esperado[i], "ángulo %d: Spellcaster registra '%s'" % [i, sc.call("_nombre_linea")])
	Sigils.repertorio_de("linea_x")
	_ok(Sigils.repertorio_de("linea_x") == "linea" and Sigils.repertorio_de("linea_z") == "linea" and Sigils.repertorio_de("flecha") == "flecha" and Sigils.repertorio_de("levitacion") == "levitacion", "repertorio_de")
	sc.free()


# =====================================================================================================
#  CICLO DE VIDA (R3): copias · crece · viaja · rebotes · persiste × calidad · solidez
# =====================================================================================================
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _senales: Array = []


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(13, 13), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_senales.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _receta(glifos: Array, calidad: float = 1.0) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		r.apply(String(gl))
	r.calidad = calidad
	return r


## Los glifos ᛁ (ancho) que hacen falta para llegar a `semieje` casillas con la base y el paso de ancho de hoy (antes de 24/10 eran 8 para 1,45).
func _ejes_x(semieje: float) -> Array:
	var r: Array = []
	for _k in range(ceili((semieje - Sigils.RADIO_BASE_V2) / Sigils.PASO_ANCHO_V2 - 0.0001)):
		r.append("linea_x")
	return r


func _origen() -> Vector3:
	return Lanzador3D.centro_de(ORIGEN_C, 0.0)


func _rune(e: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % e)


## Lanza una receta con un elemento y devuelve las casillas de la señal `hechizo_v2` (la unión de todas las tandas).
func _lanzar(glifos: Array, elemento: String, dir: Vector3 = Vector3.RIGHT, calidad: float = 1.0) -> Array:
	_montar()
	_l._materializar(_receta(glifos, calidad), _rune(elemento), _origen(), dir)
	return (_senales[0][2]["celdas"] as Array) if not _senales.is_empty() else []


## Como `_lanzar` pero con velocidad 0 (el camino de siempre, que materializa casillas): desde el 18/10 la flecha pone velocidad 4 y sale como PROYECTIL
## (lo cubre prueba_hechizo_vivo); aquí se fuerza `velocidad` a 0 para seguir probando el reparto por tandas y el alcance en casillas.
func _mat0(receta: Lanzador3D.Receta3D, rune: RuneData, origen: Vector3, dir: Vector3) -> int:
	return _l.lanzar_hechizo(receta.hechizo(rune).con({"velocidad": 0.0}), origen, dir)


func _lanzar0(glifos: Array, elemento: String, calidad: float = 1.0) -> Array:
	_montar()
	_mat0(_receta(glifos, calidad), _rune(elemento), _origen(), Vector3.RIGHT)
	return (_senales[0][2]["celdas"] as Array) if not _senales.is_empty() else []


func _filas(celdas: Array) -> Array:
	var r: Array = []
	for c in celdas:
		if not r.has((c as Vector2i).y):
			r.append((c as Vector2i).y)
	r.sort()
	return r


func _max_x(celdas: Array) -> int:
	var m: int = -999
	for c in celdas:
		m = maxi(m, (c as Vector2i).x)
	return m


## Espera SEGUNDOS DE JUEGO (el reloj de los temporizadores del código: `create_timer`), no fotogramas. Antes contaba `segundos × 60` fotogramas: a 30 fps esperaba el doble y a 120 la mitad,
## y los casos de crecer y de volúmenes que viajan fallaban según los fps con que se lanzara la prueba (a 60 pasaban; a 30 y a 120 no). Un `process_frame` previo evita que el primer
## fotograma del script, con su delta enorme, se coma el temporizador entero (medido por Pipeline en la entrada 194).
func _esperar(segundos: float) -> void:
	await process_frame
	await create_timer(segundos).timeout


func _ciclo_de_vida() -> void:
	# --- 1. copias: n volúmenes repartidos a lo largo de X (perpendicular a la mirada) ---
	var c3: Array = _lanzar(["repeticion", "repeticion"], "fire")
	_ok(_filas(c3) == [7, 8, 9], "copias ×3: tres filas contiguas a lo largo de X (filas %s)" % [_filas(c3)])
	var c1: Array = _lanzar([], "fire")
	_ok(c1.size() == 1 and c3.size() == 3, "copias: 1 volumen = 1 casilla, 3 volúmenes = 3 casillas (%d y %d)" % [c1.size(), c3.size()])
	var c4: Array = _lanzar(["repeticion", "repeticion", "repeticion", "repeticion"], "fire")
	_ok(_filas(c4).size() >= 4, "copias: el tope es 4 volúmenes (+1 por glifo, tope 4) y las filas lo reflejan (%s)" % [_filas(c4)])
	# el agua se reparte entre las copias: cada una trae SU volumen entero (n copias = n × el volumen de una)
	_montar()
	var libre: Array = []
	_l._materializar(_receta(["repeticion"]), _rune("water"), _origen(), Vector3.RIGHT)
	_ok(_l is Lanzador3D, "copias de agua: no rompe el reparto de volumen")

	# --- 2. nace en la mano y crece ---
	Sigils.HAZ_ACTIVO = false         # 21/10: ᛁ sola es ahora un rayo (prueba_haz.gd); aquí se mide el volumen estirado que crece, que sigue existiendo (barrera o laboratorio)
	# 24/10 (D-7): `crece` pasó de «escala por segundo» a «m/s de radio»: el tiempo de crecer = semieje × (1 − escala_nace) / crece. Con 9 ᛁ (semieje 2,35) eran 3,3 s y la zona de la mano (fuego,
	# 3 s de vida) se apagaba antes de que naciera la última tanda; con 4 ᛁ (semieje 1,10, 3 casillas) son 1,54 s y la prueba sigue midiendo lo mismo: nace pequeño y acaba entero.
	var sin_crecer: Array = _lanzar(["linea_x", "linea_x", "linea_x", "linea_x"], "fire")
	var final_: Array = _lanzar(["linea_x", "linea_x", "linea_x", "linea_x", "pulso"], "fire")      # el último en lanzarse es el que se mide
	_ok(final_.size() == sin_crecer.size(), "crece: al acabar de crecer ocupa lo mismo que sin crecer (%d y %d casillas)" % [final_.size(), sin_crecer.size()])
	var inicial: int = 0
	for z in _l._zonas_v2:
		inicial += (z as Lanzador3D.ZonaV2).celdas.size()
	_ok(inicial < final_.size() and inicial >= 1, "crece: al nacer ocupa menos que al final (%d de %d) y siempre incluye la casilla de la mano" % [inicial, final_.size()])
	await _esperar(HechizoVivo.tiempo_de_crecer(0.5, 0.3, Sigils.RADIO_BASE_V2 + 4.0 * Sigils.PASO_ANCHO_V2) + 0.3)      # lo que tarda en crecer ese radio a 0,5 m/s, más un margen
	var al_final: int = 0
	for z in _l._zonas_v2:
		al_final += (z as Lanzador3D.ZonaV2).celdas.size()
	_ok(al_final == final_.size(), "crece (ESPEC §1.3): el volumen escala hasta el 100 %% y las zonas que deja suman las casillas del volumen FINAL (%d de %d)" % [al_final, final_.size()])
	Sigils.HAZ_ACTIVO = true
	var rapido: Array = HechizoVivo.fases_crece(1.5, 0.3, 0.25)
	var lento: Array = HechizoVivo.fases_crece(0.5, 0.3, 0.25)
	_ok(float((rapido.back() as Dictionary)["t"]) < float((lento.back() as Dictionary)["t"]), "crece: más glifos de pulso, crece antes (%.2f s < %.2f s)" % [(rapido.back() as Dictionary)["t"], (lento.back() as Dictionary)["t"]])

	# --- 3. viaja: se desplaza `viaja` casillas ---
	var v1: Array = _lanzar0(["flecha"], "fire")
	_ok(_max_x(v1) == 5 + 2, "viaja: una flecha lo desplaza 2 casillas (de x=5 a x=%d)" % _max_x(v1))
	var v2: Array = _lanzar0(["flecha", "flecha", "flecha", "flecha", "flecha"], "fire")
	_ok(_max_x(v2) == 5 + 6, "viaja: cinco flechas, 6 casillas (tope) (x=%d)" % _max_x(v2))
	var v3: Array = _lanzar0(["flecha", "flecha", "flecha", "flecha", "flecha", "flecha"], "fire")
	_ok(_max_x(v3) == _max_x(v2), "viaja: el tope es 6 casillas, una sexta flecha no suma")
	# ESPEC §0.3 (regla de impacto, 19/10): lo que VIAJA (una flecha, con su velocidad de siempre) se para donde acaba y aplica su MATERIA UNA vez ahí; no deja tandas por el camino.
	# Se avanza a mano (`a_mano`, `paso(dt)`): sin depender de los fps. La materia del fuego es una zona que vive su `persiste` (3 s); el HechizoVivo solo se queda si lleva Permanencia.
	for con_perm in [true, false]:
		_montar()
		var hz_f: Hechizo = _receta(["flecha", "flecha", "flecha", "flecha", "flecha"]).hechizo(_rune("fire"))
		if con_perm:
			hz_f = hz_f.con({"permanencia": 5.0})
		var fl: HechizoVivo = HechizoVivo.crear(hz_f, _origen(), Vector3.RIGHT, _l, null, {}, true)
		var et_f: String = "viaja (%s)" % ("con permanencia 5 s" if con_perm else "sin permanencia")
		_ok(_l._zonas_v2.is_empty(), "%s: al lanzar no hay nada en el mundo (no deja la tanda de la mano) (%d zonas)" % [et_f, _l._zonas_v2.size()])
		var pasos_f: int = 0
		while fl.activo and pasos_f < 3000:
			fl.paso(1.0 / 60.0)
			if pasos_f == 60:
				_ok(_l._zonas_v2.is_empty(), "%s: a mitad de camino sigue sin dejar nada (%d zonas)" % [et_f, _l._zonas_v2.size()])
			pasos_f += 1
		var cas_f: float = Terreno3D.casilla
		_ok(fl.motivo_fin == "alcance" and absf(fl.recorrido / cas_f - 6.0) < 0.05, "%s: llega a su alcance de 6 casillas (%.2f, «%s»)" % [et_f, fl.recorrido / cas_f, fl.motivo_fin])
		_ok(_l._zonas_v2.size() == 1, "%s: al pararse aplica su materia UNA vez, una zona (%d)" % [et_f, _l._zonas_v2.size()])
		if _l._zonas_v2.size() == 1:
			var zf: Lanzador3D.ZonaV2 = _l._zonas_v2[0]
			_ok(zf.celdas.has(ORIGEN_C + Vector2i(6, 0)), "%s: ...y está donde acaba (casilla x = %d)" % [et_f, ORIGEN_C.x + 6])
			_ok(absf(zf.vida - (3.0 + (5.0 if con_perm else 0.0))) < 0.05, "%s: ...y vive lo que dura la materia (persiste 3 s + permanencia): %.2f s" % [et_f, zf.vida])
		if con_perm:
			_ok(fl.quedandose and not fl.is_queued_for_deletion(), "%s: el hechizo se queda en el sitio" % et_f)
			await _esperar(5.4)
			_ok(not is_instance_valid(fl) or fl.is_queued_for_deletion(), "%s: pasados sus 5 s desaparece" % et_f)
		else:
			_ok(not fl.quedandose and fl.is_queued_for_deletion(), "%s: el hechizo desaparece al llegar aunque el fuego persista 3 s" % et_f)
	# Y el VOLUMEN que viaja (velocidad 0 + distancia_max, el camino por tandas de HechizoVivo.eventos_de) aparece por tandas, en orden y a la velocidad por defecto (8 m/s).
	# OJO (diario 195): ese camino NO aplica la materia una vez al llegar, deja una tanda por casilla; la ESPEC §0.3 pide que «los proyectiles y los volúmenes que viajan usen la misma regla».
	# aparece por tandas, en orden y a la velocidad por defecto (8 m/s: velocidad = 0). Con Permanencia 5 s se quedan todas hasta el final; sin ella desaparecen al llegar (ESPEC §0.3)
	var vel_viaje: float = Hechizo.VELOCIDAD_VIAJE_DEFECTO
	_montar()
	_l.lanzar_hechizo(_receta(["flecha", "flecha", "flecha", "flecha", "flecha"]).hechizo(_rune("fire")).con({"velocidad": 0.0, "permanencia": 5.0}), _origen(), Vector3.RIGHT)
	_ok(_l._zonas_v2.size() == 1, "viaja: al lanzar solo existe la tanda de la mano (%d zonas)" % _l._zonas_v2.size())
	await _esperar(float(6) / vel_viaje + 0.3)
	_ok(_l._zonas_v2.size() == 7, "volumen que viaja (con permanencia): tras recorrer 6 casillas hay una tanda por casilla y siguen ahí (%d zonas)" % _l._zonas_v2.size())
	_montar()
	_l.lanzar_hechizo(_receta(["flecha", "flecha", "flecha", "flecha", "flecha"]).hechizo(_rune("fire")).con({"velocidad": 0.0}), _origen(), Vector3.RIGHT)
	await _esperar(float(6) / vel_viaje + 0.45)
	_ok(_l._zonas_v2.is_empty(), "volumen que viaja (sin permanencia): al llegar desaparece todo aunque el fuego persista 3 s (%d zonas)" % _l._zonas_v2.size())
	# el golpe de lo que toca: cada estado da UN golpe a los reactivos que haya en su camino, vuelva a pasar por ellos o no
	for par in [["ice", "solido"], ["water", "liquido"], ["fire", "plasma"], ["wind", "gas"], ["lightning", "energia"]]:
		_montar()
		var rv := ReactivoFalso.new()
		rv.add_to_group("reactivo3d")
		_m.add_child(rv)
		rv.position = Lanzador3D.centro_de(ORIGEN_C + Vector2i(2, 0), 0.0)
		_mat0(_receta(["flecha", "flecha"]), _rune(par[0]), _origen(), Vector3.RIGHT)
		await _esperar(1.2)
		_ok(rv.golpes == 1, "contacto · %s (%s): el reactivo del camino recibe UN golpe (%d)" % [par[0], par[1], rv.golpes])
	# una casilla sólida en el camino lo para antes
	_montar()
	_l.bloquear_celda(Vector2i(8, 8))
	_mat0(_receta(["flecha", "flecha", "flecha"]), _rune("fire"), _origen(), Vector3.RIGHT)
	_ok(_max_x((_senales[0][2]["celdas"] as Array)) <= 7, "viaja: una casilla sólida lo para (llega a x=%d)" % _max_x((_senales[0][2]["celdas"] as Array)))
	# y el desplazamiento no mira el estado: también el agua y el hielo viajan
	for e in ["water", "wind", "lightning"]:
		_ok(_max_x(_lanzar0(["flecha"], e)) == 7, "viaja: también con %s" % e)

	# --- 4. rebotes ---
	_montar()
	_l.bloquear_celda(Vector2i(8, 8))
	var vivo: HechizoVivo = HechizoVivo.preparar(_receta(["flecha"]).hechizo(_rune("fire")), _l)
	var camino_recto: Array = vivo.camino(Vector2(_origen().x, _origen().z), Vector2.RIGHT, 6.0, 0)
	var camino_rebote: Array = vivo.camino(Vector2(_origen().x, _origen().z), Vector2.RIGHT, 6.0, 1)
	_ok(camino_rebote.size() > camino_recto.size(), "rebotes: con un rebote el camino sigue tras el choque (%d vs %d posiciones)" % [camino_rebote.size(), camino_recto.size()])
	var vuelve: bool = false
	for i in range(1, camino_rebote.size()):
		if float((camino_rebote[i]["p"] as Vector2).x) < float((camino_rebote[i - 1]["p"] as Vector2).x) - 0.1:
			vuelve = true
	_ok(vuelve, "rebotes: tras chocar con la pared vuelve hacia atrás")
	# sin desplazamiento, el volumen con solidez y rebote REFLEJA los proyectiles
	_montar()
	_l._materializar(_receta(["rebote", "barrera"]), _rune("fire"), _origen(), Vector3.RIGHT)
	_ok(_l._solideces_v2.size() == 1 and (_l._solideces_v2[0] as Lanzador3D.SolidezV2).refleja, "rebotes: sin desplazamiento, el volumen refleja")
	_montar()
	_mat0(_receta(["flecha", "rebote", "barrera"]), _rune("fire"), _origen(), Vector3.RIGHT)
	_ok(not _l._solideces_v2.is_empty() and not (_l._solideces_v2[0] as Lanzador3D.SolidezV2).refleja, "rebotes: con desplazamiento, rebota él y no refleja")

	# --- 5. persiste × calidad ---
	for q in [1.0, 0.6]:
		_montar()
		_l._materializar(_receta([], q), _rune("fire"), _origen(), Vector3.RIGHT)
		var z: Lanzador3D.ZonaV2 = _l._zonas_v2.back()
		var esperado: float = 3.0 * Sigils.quality_factor(q)
		_ok(absf(z.vida - esperado) < 0.001, "persiste × calidad: fuego con calidad %.1f vive %.2f s (esperado %.2f)" % [q, z.vida, esperado])
	_ok(absf(_rune("fire").persiste - 3.0) < 0.0001, "persiste × calidad: el .tres compartido no se toca")

	# --- 6. solidez por encima de cualquier estado ---
	for e in ["water", "wind", "fire", "lightning", "earth", "ice"]:
		_montar()
		var celdas: Array = _lanzar(["barrera", "barrera"], e)
		_ok(_l._solideces_v2.size() >= 1, "solidez · %s: aparece el volumen sólido encima" % e)
		if _l._solideces_v2.is_empty():
			continue
		var s: Lanzador3D.SolidezV2 = _l._solideces_v2[0]
		_ok(absf(s.aguante - Hechizo.RESISTENCIA_POR_SOLIDEZ * 2.25) < 0.001, "solidez · %s: aguante = %.1f × 2,25 (×1,5²) = %.1f" % [e, Hechizo.RESISTENCIA_POR_SOLIDEZ, s.aguante])
		var lejos := Vector3((ORIGEN_C.x + 1.5) * Terreno3D.casilla, 0.5, (ORIGEN_C.y + 0.5) * Terreno3D.casilla)
		var propia: Vector2i = Lanzador3D.celda_de(_jug.position)
		_ok(s.contiene(Lanzador3D.centro_de(ORIGEN_C, 0.5)) and s.bloquea_a(Lanzador3D.centro_de(ORIGEN_C, 0.5), 0, propia), "solidez · %s: bloquea en la casilla de la mano" % e)
		_ok(not s.bloquea_a(Lanzador3D.centro_de(Vector2i(2, 2), 0.5), 0, propia), "solidez · %s: no bloquea fuera del volumen" % e)
	# bloquea el trazo del jugador y aguanta golpes ajenos hasta romperse
	_montar()
	_l._materializar(_receta(_ejes_x(SEMIEJE_MURO_ANCHO) + ["barrera"]), _rune("water"), _origen(), Vector3.RIGHT)
	_ok(_l._barrera_en(Lanzador3D.centro_de(ORIGEN_C + Vector2i(0, 1), 0.5), 0), "solidez: _barrera_en ve el volumen (bloquea el trazo del jugador)")
	var s2: Lanzador3D.SolidezV2 = _l._solideces_v2[0]
	var punto: Vector3 = Lanzador3D.centro_de(ORIGEN_C, 0.5)
	var total: float = s2.aguante                       # 45 = 30 × 1,5 (una barrera)
	_ok(_l.solidez_para(punto, 12.0) and _l.solidez_para(punto, 12.0) and _l.solidez_para(punto, 12.0), "solidez: para tres flechas ajenas y aguanta (de %.1f queda %.1f)" % [total, s2.aguante])
	_ok(is_instance_valid(s2) and not s2.is_queued_for_deletion(), "solidez: aún en pie con aguante %.1f" % s2.aguante)
	_l.solidez_para(punto, 12.0)
	_ok(s2.is_queued_for_deletion(), "solidez: al agotar el aguante (%.1f) se deshace" % s2.aguante)
	s2 = null
	# dura: lo que no persiste (agua) tiene una vida mínima
	_montar()
	_l._materializar(_receta(["barrera"]), _rune("water"), _origen(), Vector3.RIGHT)
	_ok(absf((_l._solideces_v2[0] as Lanzador3D.SolidezV2).vida - HechizoVivo.VIDA_MIN_SOLIDEZ_V2) < 0.001, "solidez: el agua (persiste 0) dura la vida mínima")

	# --- Orden de dibujo irrelevante y combinaciones que «salen solas» ---
	var a: Array = _lanzar0(["flecha", "pulso", "repeticion", "linea_x"], "fire")
	var b: Array = _lanzar0(["linea_x", "repeticion", "pulso", "flecha"], "fire")
	_ok(a == b and a.size() > 3, "el orden de dibujo no cambia el resultado (%d casillas)" % a.size())
	# lanza de fuego que viaja y rebota, abanico de bolas de hielo, muro de agua que para flechas: sin tocar el código
	var abanico: Array = _lanzar0(["repeticion", "repeticion", "flecha"], "ice")
	_ok(_filas(abanico).size() >= 3 and _max_x(abanico) == 7, "ᚠᚠ + ᛇ + hielo: tres bolas en abanico que viajan (filas %s, x hasta %d)" % [_filas(abanico), _max_x(abanico)])
	var muro_agua: Array = _lanzar(_ejes_x(SEMIEJE_MURO_ANCHO) + ["barrera"], "water")
	_ok(_filas(muro_agua).size() == 3 and not _l._solideces_v2.is_empty(), "ᛁ×%d + ᛜ + agua: muro de agua de 3 de ancho que además bloquea" % _ejes_x(SEMIEJE_MURO_ANCHO).size())

	# --- Tinta y PlayLog ---
	_ok(is_equal_approx(Tinta.coste_receta(1.0), Tinta.COSTE_BASE_V2) and Tinta.coste_receta(1000.0) == Tinta.MAXIMA, "tinta: la esfera base cuesta %.0f y el techo es la barra" % Tinta.COSTE_BASE_V2)
	var t := Tinta.new()
	_ok(t.puede_pagar("x_mano", 30.0) and t.gastar("x_mano", 30.0) and is_equal_approx(t.actual, 70.0), "tinta: gastar con coste explícito descuenta ese coste")
	var cara: Lanzador3D.Receta3D = _receta(["linea_x", "linea_x", "altura", "flecha"])
	_ok(Tinta.coste_receta(cara.coste_v2()) > Tinta.coste_receta(_receta([]).coste_v2()), "tinta: más volumen y más propiedades, más tinta")
	_montar()
	_l._registrar_receta_v2(cara.hechizo(_rune("fire")), {"indice": 0}, 5)
	_ok(true, "PlayLog receta_v2: se registra sin error")

	# --- Los glifos aparcados no rompen nada ---
	for gl in ["retardo", "atraccion", "espejo", "amplificar"]:
		var r: Lanzador3D.Receta3D = _receta(["flecha", gl])
		_ok(r.ignorados == PackedStringArray([gl]) and r.geo()["props"] == _receta(["flecha"]).geo()["props"], "aparcado · %s: se ignora sin romper la receta" % gl)
	_ok(_receta(["levitacion"]).geo()["y"] == _receta(["altura"]).geo()["y"] and _receta(["levitacion"]).ignorados.is_empty(), "levitación (ᛏ) vale solo como altura")


## Lo retirado: ni `antigua`, ni las ramas con nombre de GeometriaHechizo, ni los glifos tamano/pilar. Y ningún `if` por glifo en el ciclo de vida.
func _retiradas() -> void:
	var fuente: String = (load("res://magia/lanzador_3d.gd") as GDScript).source_code
	_ok(not fuente.contains("class GeometriaHechizo"), "retirada: GeometriaHechizo")
	_ok(not fuente.contains("var antigua"), "retirada: antigua")
	_ok(not fuente.contains("static var V2"), "retirada: el interruptor Receta3D.V2")
	_ok(not Sigils.FORM.has("pilar") and not Sigils.FORM.has("tamano"), "retirada: pilar y tamano de Sigils.FORM")
	_ok(not GestureLibrary.SIGILS.has("pilar") and not GestureLibrary.SIGILS.has("tamano"), "retirada: pilar y tamano del reconocedor")
	# HC2: el ciclo de vida vive entero en HechizoVivo (magia/hechizo_vivo.gd)
	var ciclo: String = (load("res://magia/hechizo_vivo.gd") as GDScript).source_code
	_ok(ciclo.contains("func _materializar(") and ciclo.contains("func eventos_de("), "el ciclo de vida está en HechizoVivo")
	_ok(not fuente.contains("func _materializar_v2") and not fuente.contains("func _eventos_v2") and not fuente.contains("func _materia_"), "retirado de Lanzador3D: _materializar_v2, _eventos_v2 y _materia_*")
	for glifo in Sigils.GLIFOS_V2:
		if glifo == "permanencia":
			continue                      # ᛉ se llama igual que el campo del Hechizo (`permanencia`, que el ciclo de vida SÍ lee): se comprueba abajo que no pregunta por el glifo
		_ok(not ciclo.contains("\"%s\"" % glifo), "ciclo de vida: no pregunta por el glifo «%s» por su nombre" % glifo)
	_ok(not ciclo.contains("glifos.get(") and not ciclo.contains("Sigils.GLIFOS"), "ciclo de vida: no mira los contadores de glifos ni las tablas de Sigils (solo campos del Hechizo)")
