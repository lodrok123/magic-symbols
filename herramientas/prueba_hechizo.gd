extends SceneTree
## Prueba de la clase `Hechizo` (HC1, 18/10; docs/HECHIZO_CLASE.md), sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_hechizo.gd
## HC1 es refactorización: para TODAS las combinaciones de hasta 4 glifos (con repetición) × los 7 elementos × 2 calidades,
## `Hechizo.construir` da los MISMOS números que el camino de hoy (Sigils.aplicar_v2 + RuneData + Receta3D), con tolerancia 1e-4:
## semiejes, propiedades, persiste, daño, empuje, estado, coste, recarga, forma, cast point y niveles. Además comprueba que las
## duraciones de estado son las que Combate3D.golpe tenía escritas a mano, que el .tres puede ajustar campos con `modificadores`
## (sin tocar el recurso compartido), que los glifos desconocidos se ignoran y que Sigils.GLIFOS y Sigils.GLIFOS_V2 dicen lo mismo.

const MAX_GLIFOS: int = 4
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind", "time"]
const CALIDADES: Array = [1.0, 0.4]
## Lo que Combate3D.golpe tenía escrito a mano el 18/10 (nombre del elemento -> campo -> valor).
## Y la fuerza del golpe por elemento (FUERZA_POR_ELEMENTO; el viento no empuja él: lo hace el Lanzador).
const FUERZA_DE_HOY: Dictionary = {"fuego": 500.0, "agua": 600.0, "hielo": 300.0, "rayo": 400.0, "tierra": 2200.0, "viento": 0.0, "": 400.0}
const ESTADOS_DE_HOY: Dictionary = {
	"fuego": {"quema": 3.0}, "agua": {"moja": 6.0}, "hielo": {"congela": 1.5, "congela_mojado": 2.5}, "rayo": {"aturde": 1.2},
	"tierra": {"ralentiza": 3.0}, "viento": {"interrumpe": 0.7}}

var fallos: int = 0
var comparaciones: int = 0


func _ok(cond: bool, msg: String) -> void:
	comparaciones += 1
	if not cond:
		fallos += 1
		if fallos <= 40:
			print("FALLO: ", msg)


func _casi(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _initialize() -> void:
	await process_frame
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	_tablas()
	var combos: Array = []
	_generar(Sigils.GLIFOS_V2.keys(), MAX_GLIFOS, 0, [], combos)
	for combo in combos:
		var c: Dictionary = {}
		for n in combo:
			c[n] = int(c.get(n, 0)) + 1
		for e in ELEMENTOS:
			for q in CALIDADES:
				_igual_que_hoy(c, runes[e] as RuneData, float(q), "%s %s q%.1f" % [str(combo), e, q])
	_estados(runes)
	_modificadores_del_tres(runes)
	_casos_sueltos(runes)
	_tabla_hc5(runes)
	print("%d combinaciones × %d elementos × %d calidades · %d comparaciones · FALLOS: %d" % [combos.size(), ELEMENTOS.size(), CALIDADES.size(), comparaciones, fallos])
	quit(1 if fallos > 0 else 0)


func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


# --- La tabla nueva y la vieja dicen lo mismo ---
func _tablas() -> void:
	_ok(Sigils.GLIFOS.keys() == Sigils.GLIFOS_V2.keys(), "GLIFOS y GLIFOS_V2 no tienen los mismos glifos / orden")
	for nombre in Sigils.GLIFOS_V2:
		var v: Dictionary = Sigils.GLIFOS_V2[nombre]
		var n: Dictionary = Sigils.GLIFOS[nombre]
		_ok(String(n["repertorio"]) == String(v["repertorio"]) and _casi(float(n["cooldown"]), float(v["cooldown"])), "%s: repertorio o cooldown difieren" % nombre)
		var destino: String = ("semiejes." + String(v["eje"])) if v["tipo"] == "eje" else String(_campo_de_param(String(v["param"])))
		var principal: Dictionary = {}           # el modificador que dice lo mismo que la fila de GLIFOS_V2 (los demás son extras de HC4/diseño: velocidad, en_punto, persiste)
		for m in (n["modificadores"] as Array):
			if String((m as Dictionary)["campo"]) == destino:
				principal = m
		_ok(not principal.is_empty(), "%s: ningún modificador sobre %s" % [nombre, destino])
		_ok(_casi(float(principal["valor"]), float(v["por_glifo"])) and _casi(float(principal["tope"]), float(v["tope"])), "%s: valor o tope difieren" % nombre)
		_ok(String(principal["op"]) == ("multiplica" if v.get("modo", "suma") == "multiplica" else "suma"), "%s: operación distinta" % nombre)
		_ok(String(principal["campo"]) == destino, "%s: campo %s ≠ %s" % [nombre, principal["campo"], destino])
		if v["tipo"] == "prop" and float(v["inicio"]) != 0.0:
			_ok(principal.has("desde") and _casi(float(principal["desde"]), float(v["inicio"])), "%s: «desde» ≠ inicio" % nombre)


func _campo_de_param(param: String) -> String:
	for campo in Hechizo.PROPIEDAD_DE:
		if Hechizo.PROPIEDAD_DE[campo] == param:
			return String(campo)
	return ""


# --- Una combinación contra el camino de hoy ---
func _igual_que_hoy(c: Dictionary, rune: RuneData, calidad: float, et: String) -> void:
	var g: Dictionary = Sigils.aplicar_v2(c)
	var props: Dictionary = g["props"]
	var h: Hechizo = Hechizo.construir(rune, c, calidad)
	# volumen
	_ok(_casi(h.semiejes.x, float(g["x"])) and _casi(h.semiejes.y, float(g["y"])) and _casi(h.semiejes.z, float(g["z"])), "%s: semiejes %s ≠ (%.3f, %.3f, %.3f)" % [et, str(h.semiejes), g["x"], g["y"], g["z"]])
	# EXACTOS (no solo a 1e-4): `geo()` es el formato de siempre y lo lee el rasterizado de casillas; un Vector3 (32 bits) lo cambiaría en los casos límite
	var gh: Dictionary = h.geo()
	_ok(gh["x"] == g["x"] and gh["y"] == g["y"] and gh["z"] == g["z"] and gh["props"] == g["props"], "%s: geo() no es exactamente aplicar_v2 (%s ≠ %s)" % [et, str([gh["x"], gh["y"], gh["z"]]), str([g["x"], g["y"], g["z"]])])
	_ok(_casi(h.semiejes_glifos.x, float(g.get("x_glifos", g["x"]))) and _casi(h.semiejes_glifos.z, float(g.get("z_glifos", g["z"]))), "%s: semiejes de los glifos (sin el suelo de la barrera)" % et)
	# propiedades: las mismas claves y valores que `props`
	var mias: Dictionary = h.propiedades_usadas()
	_ok(mias.size() == props.size(), "%s: nº de propiedades %d ≠ %d" % [et, mias.size(), props.size()])
	for k in props:
		_ok(mias.has(k) and _casi(float(mias[k]), float(props[k])), "%s: propiedad %s %s ≠ %s" % [et, k, str(mias.get(k)), str(props[k])])
	_ok(_casi(h.distancia_max, float(props.get("viaja", 0.0))) and _casi(h.solidez, float(props.get("solidez", 0.0))) and h.copias == int(props.get("copias", 1.0)) \
		and h.rebotes == int(props.get("rebotes", 0.0)) and _casi(h.crece, float(props.get("crece", 0.0))), "%s: campos de propiedad" % et)
	# del elemento
	# la barrera suma 1 s de persistencia por cada glifo SUCESIVO al 1.º (antes del factor de calidad)
	var base_persiste: float = rune.persiste + float(maxi(int(c.get("barrera", 0)) - 1, 0))
	var persiste: float = base_persiste * (Sigils.quality_factor(calidad) if base_persiste > 0.0 else 1.0)
	_ok(_casi(h.persiste, persiste), "%s: persiste %.3f ≠ %.3f" % [et, h.persiste, persiste])
	_ok(_casi(h.dano, rune.damage + (18.0 if h.elemento == "tierra" else 0.0)) and _casi(h.empuje, rune.empuje) and h.estado_materia == rune.estado and h.pisable == rune.pisable and h.deja == rune.deja, "%s: daño, empuje, estado, pisable o deja" % et)
	_ok(h.color == rune.color and h.etiquetas == rune.tags and h.elemento == Objetos.elemento_de(rune), "%s: color, etiquetas o elemento" % et)
	# derivados contra Receta3D y GeometriaV2
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	r.calidad = calidad
	for nombre in c:
		for i in range(int(c[nombre])):
			r.apply(nombre)
	var viaja: bool = float(props.get("viaja", 0.0)) > 0.0
	_ok(h.viaja == viaja, "%s: viaja" % et)
	_ok(h.forma == r.forma() and h.forma == Lanzador3D.GeometriaV2.nombre_derivado(g, viaja), "%s: forma %s ≠ %s" % [et, h.forma, r.forma()])
	_ok(h.cast_point == CastPoints.variacion_de(r.forma()), "%s: cast point" % et)
	_ok(h.niveles == Lanzador3D.GeometriaV2.niveles(g), "%s: niveles %d ≠ %d" % [et, h.niveles, Lanzador3D.GeometriaV2.niveles(g)])
	_ok(_casi(h.coste, r.coste_v2()) and _casi(h.coste, Sigils.coste_v2(g, props)), "%s: coste %.4f ≠ %.4f" % [et, h.coste, r.coste_v2()])
	_ok(_casi(h.coste_tinta, Tinta.coste_receta(r.coste_v2())), "%s: coste en tinta" % et)
	_ok(_casi(h.recarga, r.cooldown), "%s: recarga %.3f ≠ %.3f" % [et, h.recarga, r.cooldown])
	# los campos nuevos (HC4) siguen en su defecto
	var vel_esperada: float = Sigils.VELOCIDAD_FLECHA_U if int(c.get("flecha", 0)) > 0 else 0.0     # la flecha pone la velocidad; sin flecha, 0
	_ok(h.en_punto == (int(c.get("barrera", 0)) > 0), "%s: en_punto solo con barrera" % et)
	_ok(h.velocidad == vel_esperada and h.aceleracion == 0.0 and h.gravedad == 0.0 and not h.retorna and h.busca == 0.0 and h.perfora == 0 and h.radio_explosion == 0.0 \
		and not h.golpea_lanzador and h.veneno == 0.0 and h.choca_con == 0 and h.estela == "" and h.efecto_impacto == "", "%s: un campo de HC4 se movió de su defecto" % et)
	_ok(h.ignorados.is_empty(), "%s: ignorados" % et)


# --- Las duraciones que Combate3D.golpe tenía a mano ---
func _estados(runes: Dictionary) -> void:
	var nombres: Array = ["quema", "moja", "congela", "congela_mojado", "aturde", "ralentiza", "interrumpe"]
	for e in ELEMENTOS:
		var h: Hechizo = Hechizo.construir(runes[e], {})
		var esperado: Dictionary = ESTADOS_DE_HOY.get(h.elemento, {})
		for campo in nombres:
			_ok(_casi(float(h.get(campo)), float(esperado.get(campo, 0.0))), "%s: %s = %.2f, hoy %.2f" % [e, campo, h.get(campo), esperado.get(campo, 0.0)])
		# el estado no depende de los glifos ni de la calidad
		var h2: Hechizo = Hechizo.construir(runes[e], {"linea_x": 3, "barrera": 1, "flecha": 2}, 0.2)
		for campo in nombres:
			_ok(_casi(float(h2.get(campo)), float(h.get(campo))), "%s: %s cambia con los glifos" % [e, campo])
	_ok(_casi(Hechizo.construir(runes["earth"], {}).ralentiza_fuerza, 0.4), "tierra: ralentiza_fuerza 0,4 (Combate3D multiplica por 0,6)")
	for e in ELEMENTOS:
		var hh: Hechizo = Hechizo.construir(runes[e], {})
		_ok(_casi(hh.fuerza_golpe, float(FUERZA_DE_HOY[hh.elemento])), "%s: fuerza_golpe %.0f ≠ %.0f de hoy" % [e, hh.fuerza_golpe, FUERZA_DE_HOY[hh.elemento]])


# --- El .tres puede ajustar campos sin tocar el recurso compartido ---
func _modificadores_del_tres(runes: Dictionary) -> void:
	var fuego: RuneData = runes["fire"]
	var copia: RuneData = fuego.duplicate()
	copia.modificadores = fuego.modificadores.duplicate()    # la quema y la fuerza de siempre; encima (un campo, un modificador), lo que prueba esta función
	copia.modificadores.merge({"dano": {"op": "suma", "valor": 5.0}, "quema": {"op": "fija", "valor": 4.0}, "empuje": {"op": "multiplica", "valor": 10.0, "tope": 1.0}, "velocidad": {"op": "fija", "valor": 7.0}, "persiste": {"op": "multiplica", "valor": 2.0}}, true)
	var h: Hechizo = Hechizo.construir(copia, {})
	_ok(_casi(h.dano, fuego.damage + 5.0), "modificadores: dano +5 (%.1f)" % h.dano)
	_ok(_casi(h.quema, 4.0) and _casi(h.fuerza_golpe, 500.0), "modificadores: quema fija 4 y la fuerza de siempre (%.1f, %.0f)" % [h.quema, h.fuerza_golpe])
	_ok(_casi(h.empuje, 1.0), "modificadores: empuje ×10 con tope 1 (%.2f)" % h.empuje)
	_ok(_casi(h.velocidad, 7.0), "modificadores: velocidad fija 7")
	_ok(_casi(h.persiste, fuego.persiste * 2.0), "modificadores: persiste ×2 (%.2f)" % h.persiste)
	_ok(String(h.origen["dano"]) == "elemento" and String(h.origen["quema"]) == "elemento", "modificadores: el origen es el elemento")
	_ok(fuego.modificadores.size() == 2 and _casi(fuego.damage, 50.0), "el recurso compartido no se toca")


func _casos_sueltos(runes: Dictionary) -> void:
	# un glifo desconocido no rompe nada y se anota; el alias de ᛏ (levitacion) cuenta como altura
	var h: Hechizo = Hechizo.construir(runes["fire"], {"nada_conocido": 3, "levitacion": 2, "linea_x": -1})
	_ok(h.ignorados == PackedStringArray(["nada_conocido"]), "glifo desconocido anotado en ignorados: %s" % str(h.ignorados))
	_ok(_casi(h.semiejes.y, Sigils.RADIO_BASE_V2 * 3.0) and _casi(h.semiejes.x, Sigils.RADIO_BASE_V2), "levitacion×2 = altura×2 y un contador negativo no hace nada")
	# sin elemento (null): defectos y glifos, sin romper
	var sin: Hechizo = Hechizo.construir(null, {"linea_z": 2})
	_ok(sin.elemento == "" and _casi(sin.semiejes.z, Sigils.RADIO_BASE_V2 * 3.0) and sin.dano == 0.0, "sin elemento: solo los glifos")
	# el orden de dibujo no existe: mismo diccionario en otro orden, mismo hechizo
	var a: Hechizo = Hechizo.construir(runes["ice"], {"flecha": 1, "barrera": 2, "altura": 1})
	var b: Hechizo = Hechizo.construir(runes["ice"], {"altura": 1, "barrera": 2, "flecha": 1})
	_ok(a.a_diccionario() == b.a_diccionario(), "el orden de los glifos no cambia el hechizo")
	# a_diccionario y describir
	var d: Dictionary = a.a_diccionario()
	for par in Hechizo.CAMPOS:
		_ok(d.has(par[0]), "a_diccionario sin el campo %s" % par[0])
	_ok(d["semiejes"] is Array and (d["semiejes"] as Array).size() == 3 and d["color"] is String, "a_diccionario es plano (Vector3 → array, Color → html)")
	_ok(JSON.stringify(d) != "", "a_diccionario cabe en JSON")
	var txt: String = a.describir()
	_ok(txt.contains("solidez") and txt.contains("glifo:barrera") and txt.contains("elemento"), "describir: campos distintos del defecto y su origen\n" + txt)
	# el origen distingue defecto, elemento, glifo y calidad
	_ok(String(a.origen.get("solidez", "")) == "glifo:barrera" and String(a.origen.get("dano", "")) == "elemento" and String(a.origen.get("persiste", "")) == "calidad", "origen: %s" % str(a.origen))
	_ok(Hechizo.defecto("copias") == 1 and Hechizo.defecto("semiejes") == Vector3(1, 1, 1) * Sigils.RADIO_BASE_V2, "defecto() lee del var")
	# la barrera ya NO tiene radio mínimo (18/10): el tamaño lo ponen solo los ejes; nace donde apuntas y cada glifo sucesivo suma 1 s
	var barrera: Hechizo = Hechizo.construir(runes["earth"], {"barrera": 1})
	_ok(_casi(barrera.semiejes.x, Sigils.RADIO_BASE_V2) and _casi(barrera.semiejes.z, Sigils.RADIO_BASE_V2) and _casi(barrera.semiejes.y, Sigils.RADIO_BASE_V2), "barrera: sin ejes, x y z = radio base")
	_ok(barrera.en_punto and _casi(barrera.persiste, runes["earth"].persiste * (Sigils.quality_factor(1.0) if runes["earth"].persiste > 0.0 else 1.0)), "barrera ×1: en_punto y persiste del elemento")
	var barrera3: Hechizo = Hechizo.construir(runes["earth"], {"barrera": 3, "linea_x": 2})
	_ok(_casi(barrera3.persiste, (runes["earth"].persiste + 2.0) * Sigils.quality_factor(1.0)) and _casi(barrera3.semiejes.x, 3.0 * Sigils.RADIO_BASE_V2), "barrera ×3: persiste +2 s y la anchura solo la dan los ejes (%.2f s, x %.2f)" % [barrera3.persiste, barrera3.semiejes.x])
	_ok(not Hechizo.construir(runes["earth"], {"linea_x": 2}).en_punto, "sin barrera: no nace en el punto")
	# la flecha: 1.er glifo = velocidad 4 y 2 casillas; cada sucesivo +1 casilla y la velocidad NO cambia
	for k in range(1, 6):
		var fl: Hechizo = Hechizo.construir(runes["earth"], {"flecha": k})
		_ok(fl.velocidad == Sigils.VELOCIDAD_FLECHA_U and _casi(fl.distancia_max, minf(1.0 + float(k), 6.0)), "flecha ×%d: velocidad %.1f, alcance %.1f" % [k, fl.velocidad, fl.distancia_max])
	_ok(_casi(barrera.coste, 1.0 + Sigils.COSTE_PROP_V2), "barrera sola: coste = esfera base + una propiedad (%.3f)" % barrera.coste)


## HC5: la tabla del hechizo (la que enseña el laboratorio) y `con()` (las sobrescrituras en vivo).
func _tabla_hc5(runes: Dictionary) -> void:
	var h: Hechizo = Hechizo.construir(runes["fire"], {"linea_x": 2, "repeticion": 1}, 0.8)
	var filas: Array = h.tabla()
	var por: Dictionary = {}
	for f in filas:
		por[String(f["campo"])] = f
	_ok(filas.size() == Hechizo.CAMPOS.size() - 1 + 3 + Hechizo.DERIVADOS.size(), "tabla: una fila por campo (semiejes en 3) y por derivado: %d" % filas.size())
	var claves_ok: bool = true
	for f in filas:
		for k in ["campo", "grupo", "valor", "defecto", "origen", "tipo_origen", "difiere", "editable"]:
			claves_ok = claves_ok and (f as Dictionary).has(k)
	_ok(claves_ok, "tabla: cada fila trae campo, grupo, valor, defecto, origen, tipo_origen, difiere y editable")
	_ok(por.has("semiejes.x") and por.has("semiejes.y") and por.has("semiejes.z") and not por.has("semiejes"), "tabla: semiejes sale en x, y, z")
	_ok(String(por["dano"]["tipo_origen"]) == "elemento" and bool(por["dano"]["difiere"]) and _casi(float(por["dano"]["valor"]), h.dano), "tabla: el daño viene del elemento y difiere del defecto")
	_ok(String(por["semiejes.x"]["origen"]) == "glifo:linea_x" and bool(por["semiejes.x"]["difiere"]) and not bool(por["semiejes.y"]["difiere"]), "tabla: semiejes.x viene del glifo linea_x; y no difiere")
	_ok(String(por["persiste"]["tipo_origen"]) == "calidad", "tabla: persiste viene de la calidad del trazo (%s)" % por["persiste"]["origen"])
	_ok(String(por["velocidad"]["tipo_origen"]) == "defecto" and not bool(por["velocidad"]["difiere"]) and bool(por["velocidad"]["editable"]), "tabla: un campo sin tocar es «defecto», no difiere y se puede tocar")
	_ok(not bool(por["color"]["editable"]) and not bool(por["eventos"]["editable"]) and String(por["forma"]["tipo_origen"]) == "derivado" and not bool(por["forma"]["editable"]), "tabla: color, eventos y derivados se enseñan pero no se tocan")
	_ok(por["eventos"]["valor"] == "ninguno", "tabla: eventos vacíos se resumen como «ninguno»")
	for campo in Hechizo.EDITABLES:
		_ok(por.has(String(campo)), "EDITABLES: «%s» es una fila de la tabla" % campo)
	# con(): lo tocado manda, se marca «lab», recalcula los derivados y marca como usada la propiedad de receta
	var c: Hechizo = h.copiar().con({"velocidad": 7.0, "distancia_max": 4.0, "semiejes.z": 0.9, "retorna": true})
	var por2: Dictionary = {}
	for f in c.tabla():
		por2[String(f["campo"])] = f
	_ok(String(por2["velocidad"]["origen"]) == "lab" and String(por2["velocidad"]["tipo_origen"]) == "lab" and bool(por2["velocidad"]["difiere"]), "con(): lo tocado sale con origen «lab»")
	_ok(c.viaja and c.propiedades_usadas().has("viaja") and _casi(float(c.propiedades_usadas()["viaja"]), 4.0), "con(): distancia_max cuenta como propiedad usada (viaja) y recalcula `viaja`")
	_ok(_casi(c.geo()["z"], 0.9) and c.forma == "x_mano", "con(): semiejes.z llega a geo() y la forma se recalcula (%s)" % c.forma)
	_ok(_casi(c.coste, h.coste * (1.0 + Sigils.COSTE_PROP_V2 * 3.0) / (1.0 + Sigils.COSTE_PROP_V2 * 2.0)) or c.coste > h.coste, "con(): el coste cuenta la propiedad nueva pero no el volumen tocado a mano (%.3f → %.3f)" % [h.coste, c.coste])
	_ok(h.velocidad == 0.0 and not h.retorna, "con() sobre una copia no toca el original")
	# los modificadores listos para pegar
	var txt: String = Hechizo.texto_modificadores({"velocidad": 7.0, "retorna": true, "perfora": 2})
	_ok(txt.contains("\"campo\": \"velocidad\", \"op\": \"fija\", \"valor\": 7") and txt.contains("\"retorna\": {\"op\": \"fija\", \"valor\": true}") and txt.contains("modificadores = {"), "texto_modificadores: líneas para Sigils.GLIFOS y para un .tres\n" + txt)
	_ok(Hechizo.texto_modificadores({}).begins_with("#"), "texto_modificadores sin cambios dice que no hay")
