extends SceneTree
## Prueba de la clase `Hechizo` (HC1, 18/10; docs/HECHIZO_CLASE.md), sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_hechizo.gd
## HC1 es refactorización: para TODAS las combinaciones de hasta 4 glifos (con repetición) × los 7 elementos × 2 calidades,
## `Hechizo.construir` da los MISMOS números que el camino de hoy (Sigils.aplicar_v2 + RuneData + Receta3D), con tolerancia 1e-4:
## semiejes, propiedades, persiste, daño, empuje, estado, coste, recarga, forma, cast point y niveles. Además comprueba que las
## duraciones de estado son las que Combate3D.golpe tenía escritas a mano, que el .tres puede ajustar campos con `modificadores`
## (sin tocar el recurso compartido), que los glifos desconocidos se ignoran y que Sigils.GLIFOS y Sigils.GLIFOS_V2 dicen lo mismo.

const MAX_GLIFOS: int = 4
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]       ## 20/10: seis; «time» es cinemática (ver _cinematica)
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
	_espec_e1(runes)
	_cinematica()
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
const EPS_L: float = 0.000001
## Los campos que el ELEMENTO puede tocar según la ESPEC §2 (gravedad, densidad, temperatura, humedad, conductividad): el Hechizo debe traer lo que dice el `.tres` (op `fija`:
## su valor; si el `.tres` no los menciona, el defecto del Hechizo). Los que ningún elemento ni glifo toca (aceleración, retorna, busca, perfora…) siguen en su defecto (`_igual_que_hoy`).
const CAMPOS_DEL_ELEMENTO: PackedStringArray = ["gravedad", "densidad", "temperatura", "humedad", "conductividad"]
## (Que cada `.tres` diga lo que dice la ESPEC §2 lo comprueba `_espec_e1`, elemento por elemento, más abajo.)


## Lo que el `.tres` da a un campo: su modificador (fija / suma / multiplica sobre el defecto del Hechizo) o, si no lo menciona, el defecto.
func _valor_del_tres(rune: RuneData, campo: String) -> float:
	var base: float = float(Hechizo.new().get(campo))
	var m: Variant = rune.modificadores.get(campo, null)
	if not (m is Dictionary):
		return base
	var v: float = float((m as Dictionary).get("valor", 0.0))
	match String((m as Dictionary).get("op", "fija")):
		"suma":
			return base + v
		"multiplica":
			return base * v
	return v


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
	# `persiste` es la vida natural del elemento (× calidad). La barrera suma 1 s de PERMANENCIA por cada glifo SUCESIVO al 1.º (también × calidad): ESPEC §0.3
	var persiste: float = rune.persiste * (Sigils.quality_factor(calidad) if rune.persiste > 0.0 else 1.0)
	_ok(_casi(h.persiste, persiste), "%s: persiste %.3f ≠ %.3f" % [et, h.persiste, persiste])
	var perm_base: float = float(maxi(int(c.get("barrera", 0)) - 1, 0)) + float(props.get("permanencia", 0.0))      # la barrera suma 1 s por glifo sucesivo y ᛉ 2 s por glifo
	var perm: float = perm_base * (Sigils.quality_factor(calidad) if perm_base > 0.0 else 1.0)
	_ok(_casi(h.permanencia, perm), "%s: permanencia %.3f ≠ %.3f" % [et, h.permanencia, perm])
	var n_g: int = 0
	for k in c:
		if Sigils.cuenta_dano(String(k)):         # H3: ᛁ y ᛏ no suman al daño
			n_g += int(c[k])
	_ok(_casi(h.dano, Dano.base_elemental(n_g, h.elemento, rune.damage)) and _casi(h.empuje, rune.empuje) and h.estado_materia == rune.estado and h.pisable == rune.pisable and h.deja == rune.deja, "%s: daño, empuje, estado, pisable o deja" % et)
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
	_ok(_casi(h.coste, r.tamano_relativo()) and _casi(h.coste, Sigils.coste_v2(g, props)), "%s: tamaño relativo %.4f ≠ %.4f" % [et, h.coste, r.tamano_relativo()])
	_ok(_casi(h.coste_tinta, r.coste_tinta()) and _casi(h.coste_tinta, Dano.tinta_de(h)), "%s: coste en tinta (29/10: por potencia, no por volumen)" % et)
	_ok(_casi(h.recarga, r.cooldown), "%s: recarga %.3f ≠ %.3f" % [et, h.recarga, r.cooldown])
	# los límites globales de la ESPEC §1.9 no los supera NINGUNA combinación (ni con 4 glifos de cualquier tipo)
	_ok(h.semieje_x <= Hechizo.LIM_SEMIEJE_HORIZONTAL + EPS_L and h.semieje_z <= Hechizo.LIM_SEMIEJE_HORIZONTAL + EPS_L and h.semieje_y <= Hechizo.LIM_SEMIEJE_ALTO + EPS_L \
		and h.elevacion <= Hechizo.LIM_ELEVACION and h.distancia_max <= Hechizo.LIM_DISTANCIA and h.persiste + h.permanencia <= Hechizo.LIM_VIDA_S + EPS_L and h.copias <= Hechizo.LIM_COPIAS \
		and h.semieje_x >= h.grosor_min and h.semieje_y >= h.grosor_min and h.semieje_z >= h.grosor_min, "%s: supera un límite de la ESPEC §1.9" % et)
	# los campos nuevos (HC4) siguen en su defecto
	var vel_esperada: float = Sigils.velocidad_flecha() if int(c.get("flecha", 0)) > 0 else 0.0     # la flecha pone la velocidad; sin flecha, 0
	# en_punto: la barrera (glifo) o, desde el 24/10, un sólido quieto (tierra/hielo que ni es haz ni flecha: no puede nacer en la casilla de quien lo lanza)
	var lineas_c: int = int(c.get("linea_x", 0)) + int(c.get("linea_z", 0))
	var haz_c: bool = lineas_c > 0 and int(c.get("barrera", 0)) == 0 and int(c.get("flecha", 0)) == 0 and h.estado_materia != "solido"     # 29/10: un sólido con ᛁ no es haz
	var solido_quieto_c: bool = h.estado_materia == "solido" and int(c.get("flecha", 0)) == 0 and not haz_c
	_ok(h.en_punto == (int(c.get("barrera", 0)) > 0 or solido_quieto_c), "%s: en_punto solo con barrera o con un sólido quieto" % et)
	_ok(h.velocidad == vel_esperada and h.aceleracion == 0.0 and not h.retorna and h.busca == 0.0 and h.perfora == 0 and h.radio_explosion == 0.0 \
		and not h.golpea_lanzador and h.veneno == 0.0 and h.choca_con == 0 and h.estela == "" and h.efecto_impacto == "", "%s: un campo de HC4 se movió de su defecto" % et)
	# los campos que el elemento toca (ESPEC §2) valen lo que dice su .tres (sin glifos que los muevan: ninguno toca estos)
	var del_elemento: bool = true
	for campo in CAMPOS_DEL_ELEMENTO:
		del_elemento = del_elemento and _casi(float(h.get(campo)), _valor_del_tres(rune, campo))
	_ok(del_elemento, "%s: gravedad, densidad, temperatura, humedad o conductividad no valen lo que dice el .tres" % et)
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
	# 29/10 (DANO_Y_TINTA): el daño de fuego/agua/tierra/viento sale de la potencia (nº de glifos) y pisa al modificador `dano` del .tres; los demás modificadores siguen valiendo.
	_ok(_casi(h.dano, Dano.base_elemental(0, "fuego")), "modificadores: el daño del fuego lo fija la potencia (ligera 13,2), no el .tres (%.1f)" % h.dano)
	_ok(_casi(h.quema, 4.0) and _casi(h.fuerza_golpe, 500.0), "modificadores: quema fija 4 y la fuerza de siempre (%.1f, %.0f)" % [h.quema, h.fuerza_golpe])
	_ok(_casi(h.empuje, 1.0), "modificadores: empuje ×10 con tope 1 (%.2f)" % h.empuje)
	_ok(_casi(h.velocidad, 7.0), "modificadores: velocidad fija 7")
	_ok(_casi(h.persiste, fuego.persiste * 2.0), "modificadores: persiste ×2 (%.2f)" % h.persiste)
	_ok(String(h.origen["dano"]) == "potencia" and String(h.origen["quema"]) == "elemento", "modificadores: el origen del daño es la potencia (29/10) y el de la quema, el elemento")
	_ok(fuego.modificadores.size() == 8 and _casi(fuego.damage, 50.0), "el recurso compartido no se toca")
	var hf: Hechizo = Hechizo.construir(fuego, {})
	_ok(_casi(hf.dano_periodico * hf.intervalo, 10.0), "fuego: dano_periodico × intervalo = 10 por pulso, el de siempre (29/10: ya NO es el 20 %% del daño, que bajó; ver docs/DANO_Y_TINTA.md §8) (%.1f)" % (hf.dano_periodico * hf.intervalo))
	# ᛉ Permanencia (E3): +2 s por glifo; el límite global recorta persiste + permanencia a 25 s
	var perm1: Hechizo = Hechizo.construir(fuego, {"permanencia": 1})
	var perm3: Hechizo = Hechizo.construir(fuego, {"permanencia": 3})
	var perm_max: Hechizo = Hechizo.construir(fuego, {"permanencia": 20})
	_ok(_casi(perm1.permanencia, 2.0) and _casi(perm3.permanencia, 6.0) and perm1.anclado and not hf.anclado, "permanencia: +2 s por glifo (1 → %.1f, 3 → %.1f) y activa «anclado»" % [perm1.permanencia, perm3.permanencia])
	_ok(_casi(perm1.persiste, fuego.persiste), "permanencia: no toca la `persiste` del elemento (%.1f)" % perm1.persiste)
	_ok(_casi(perm_max.persiste + perm_max.permanencia, 25.0), "permanencia: con muchos glifos persiste + permanencia topa en 25 s (%.1f + %.1f)" % [perm_max.persiste, perm_max.permanencia])
	_ok(Sigils.GLIFOS.has("permanencia") and Sigils.GLIFOS_V2.has("permanencia") and GestureLibrary.SIGILS.has("permanencia") and GestureLibrary.RECORDABLE.has("permanencia") and not GestureLibrary.RECORDABLE.has("algiz") and String(GestureLibrary.BIBLIA["permanencia"]["uso"]) == "sello", "permanencia: dada de alta en Sigils (GLIFOS y GLIFOS_V2), GestureLibrary (SIGILS, RECORDABLE, BIBLIA ᛉ sello)")


func _casos_sueltos(runes: Dictionary) -> void:
	# un glifo desconocido no rompe nada y se anota; el alias de ᛏ (levitacion) cuenta como altura
	var h: Hechizo = Hechizo.construir(runes["fire"], {"nada_conocido": 3, "levitacion": 2, "linea_x": -1})
	_ok(h.ignorados == PackedStringArray(["nada_conocido"]), "glifo desconocido anotado en ignorados: %s" % str(h.ignorados))
	_ok(_casi(h.semiejes.y, Sigils.RADIO_BASE_V2 + 2.0 * Sigils.PASO_ALTURA_V2) and _casi(h.semiejes.x, Sigils.RADIO_BASE_V2), "levitacion×2 = altura×2 y un contador negativo no hace nada")
	# sin elemento (null): defectos y glifos, sin romper
	var sin: Hechizo = Hechizo.construir(null, {"linea_z": 2})
	_ok(sin.elemento == "" and _casi(sin.semiejes.z, Sigils.RADIO_BASE_V2 + 2.0 * Sigils.PASO_FONDO_V2) and sin.dano == 1.0 and sin.gravedad == 1.0, "sin elemento: solo los glifos y las bases de la ESPEC (daño 1, gravedad 1)")
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
	_ok(barrera.en_punto and _casi(barrera.persiste, runes["earth"].persiste * Sigils.quality_factor(1.0)) and barrera.permanencia == 0.0, "barrera ×1: en_punto, persiste del elemento y sin permanencia")
	var barrera3: Hechizo = Hechizo.construir(runes["earth"], {"barrera": 3, "linea_x": 2})
	_ok(_casi(barrera3.persiste, runes["earth"].persiste * Sigils.quality_factor(1.0)) and _casi(barrera3.permanencia, 2.0 * Sigils.quality_factor(1.0)) and _casi(barrera3.semiejes.x, Sigils.RADIO_BASE_V2 + 2.0 * Sigils.PASO_ANCHO_V2), "barrera ×3: permanencia +2 s y la anchura solo la dan los ejes (%.2f s, x %.2f)" % [barrera3.permanencia, barrera3.semiejes.x])
	_ok(not Hechizo.construir(runes["fire"], {"linea_x": 2}).en_punto and Hechizo.construir(runes["earth"], {"linea_x": 2}).en_punto, "sin barrera: el fuego no nace en el punto; la tierra con ᛁ sí (29/10: es un sólido quieto, no un haz)")
	# 24/10: un SÓLIDO QUIETO (tierra/hielo con solo ᛏ, ᚢ o ᚱ) nace donde apuntas; una flecha, un haz o un elemento que no es sólido, no
	for elem in ["earth", "ice"]:
		for g in [{"altura": 1}, {"rebote": 1}, {"raido": 1}, {"pulso": 1}]:
			var q: Hechizo = Hechizo.construir(runes[elem], g)
			_ok(q.solido_quieto and q.en_punto and String(q.origen.get("en_punto", "")) == Hechizo.ORIGEN_EN_PUNTO_SOLIDO, "%s %s: sólido quieto → en_punto (origen «derivado:solido», fue «%s»)" % [elem, str(g), String(q.origen.get("en_punto", ""))])
		_ok(not Hechizo.construir(runes[elem], {"flecha": 1}).en_punto, "%s + flecha: viaja, no nace en el punto" % elem)
	_ok(not Hechizo.construir(runes["fire"], {"altura": 1}).en_punto and not Hechizo.construir(runes["water"], {"altura": 1}).en_punto, "fuego y agua quietos (no sólidos): no nacen en el punto")
	_ok(String(Hechizo.construir(runes["earth"], {"barrera": 1}).origen.get("en_punto", "")) == "glifo:barrera", "la barrera de tierra conserva su origen «glifo:barrera»")
	var lab_off: Hechizo = Hechizo.construir(runes["earth"], {"altura": 1}).con({"en_punto": false})
	_ok(not lab_off.en_punto, "el laboratorio puede apagar en_punto de un sólido quieto (la regla respeta el origen «lab»)")
	var lab_viaja: Hechizo = Hechizo.construir(runes["earth"], {"altura": 1}).con({"distancia_max": 3.0})
	_ok(not lab_viaja.en_punto and not lab_viaja.origen.has("en_punto"), "si el laboratorio lo hace viajar, deja de ser en_punto (se retira lo que puso la regla)")
	# la flecha: 1.er glifo = velocidad 4 y 2 casillas; cada sucesivo +1 casilla y la velocidad NO cambia
	for k in range(1, 6):
		var fl: Hechizo = Hechizo.construir(runes["earth"], {"flecha": k})
		_ok(fl.velocidad == Sigils.velocidad_flecha() and _casi(fl.distancia_max, minf(1.0 + float(k), 6.0)), "flecha ×%d: velocidad %.1f, alcance %.1f" % [k, fl.velocidad, fl.distancia_max])
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
	_ok(String(por["dano"]["tipo_origen"]) == "potencia" and bool(por["dano"]["difiere"]) and _casi(float(por["dano"]["valor"]), h.dano), "tabla: el daño viene de la potencia (29/10) y difiere del defecto")
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


# --- 20/10 (Pablo): la runa del tiempo es CINEMÁTICA: existe (el .tres, el estado «campo»), pero el jugador no la lanza ni la reconoce ---
func _cinematica() -> void:
	var t: RuneData = load("res://nucleo/time_rune.tres")
	_ok(t != null and t.cinematico, "time_rune.tres está marcado como cinemático")
	_ok(t.estado == "campo" and t.tags.has("cinematico"), "…y conserva su estado «campo» y la etiqueta")
	_ok(Hechizo.construir(t, {}) == null and Hechizo.construir(t, {"flecha": 2}, 0.5) == null, "Hechizo.construir lo rechaza si no se le pide expresamente (devuelve null)")
	var c: Hechizo = Hechizo.construir(t, {"flecha": 1}, 1.0, true)
	_ok(c != null and c.estado_materia == "campo" and c.elemento == Objetos.elemento_de(t), "con permitir_cinematico = true sí lo construye, en estado «campo»")
	for e in ELEMENTOS:
		_ok(not (load("res://nucleo/%s_rune.tres" % e) as RuneData).cinematico, "%s no es cinemático" % e)
	_ok(not GestureLibrary.ELEMENTS.has("tiempo") and not GestureLibrary.RECORDABLE.has("tiempo"), "el libro no lo ofrece ni se puede grabar («tiempo» fuera de ELEMENTS y RECORDABLE)")
	_ok(GestureLibrary.ELEMENTS.size() == 6 and ELEMENTOS.size() == 6, "los elementos del jugador son 6")
	var g := Grimorio.new()
	_ok(not g.rune_database.has(Runes.Type.ELEMENT_TIME) and not Grimorio.GESTURE_TO_RUNE.has("tiempo"), "el Grimorio no tiene la runa del tiempo en su tabla ni la reconoce")
	g.free()


# --- E1 (19/10, docs/ESPEC_HECHIZO.md): bases, derivados, límites y elementos ---
func _espec_e1(runes: Dictionary) -> void:
	var vacio: Hechizo = Hechizo.construir(null, {})
	# 24/10 (diario 249): base 0,10 y +0,10 por glifo de eje; las cifras salen de las constantes.
	var base: float = Sigils.RADIO_BASE_V2
	_ok(_casi(base, 0.10) and _casi(vacio.semieje_x, base) and _casi(vacio.semieje_y, base) and _casi(vacio.semieje_z, base), "base: semiejes %.2f" % base)
	_ok(vacio.gravedad == 1.0 and vacio.dano == 1.0 and _casi(vacio.grosor_min, base) and _casi(vacio.escala_nace, 0.3) and _casi(vacio.intervalo, 0.25), "bases: gravedad 1, daño 1, grosor_min = base, escala_nace 0,3, intervalo 0,25")
	_ok(vacio.densidad == 1.0 and vacio.elasticidad == 0.2 and vacio.potencia == 1.0 and vacio.intensidad_estado == 1.0 and vacio.separacion == 0.5 and vacio.dispersion == 15.0, "bases: densidad 1, elasticidad 0,2, potencia 1, intensidad 1, separación 0,5, dispersión 15")
	_ok(vacio.elevacion == 0.0 and vacio.permanencia == 0.0 and vacio.retardo == 0.0 and vacio.dano_periodico == 0.0 and vacio.temperatura == 0.0 and vacio.humedad == 0.0 and vacio.conductividad == 0.0, "bases: el resto en 0")
	_ok(_casi(vacio.altura_salida, Hechizo.ALTURA_MANO_U / Terreno3D.casilla), "altura_salida en metros: la mano (0,9 u) ÷ casilla = %.3f m" % vacio.altura_salida)
	# un eje: cada glifo suma el paso de SU eje (ancho 0,25 · fondo 0,10 · altura 0,30) y topa en 3 (X, Z) y en 1 (Y)
	var x3: Hechizo = Hechizo.construir(null, {"linea_x": 3})
	_ok(_casi(x3.semieje_x, base + 3.0 * Sigils.PASO_ANCHO_V2), "linea_x ×3: base + 3 · paso de ancho (%.2f)" % x3.semieje_x)
	_ok(_casi(Hechizo.construir(null, {"linea_z": 3}).semieje_z, base + 3.0 * Sigils.PASO_FONDO_V2) and _casi(Hechizo.construir(null, {"altura": 3}).semieje_y, base + 3.0 * Sigils.PASO_ALTURA_V2) and Hechizo.construir(null, {"altura": Sigils.GLIFOS_ALTURA_DOS_NIVELES_V2}).niveles == 2, "linea_z ×3 y altura ×3: el paso de su eje; 3 ᛏ = 2 niveles")
	_ok(Hechizo.construir(null, {"barrera": 1, "linea_x": Sigils.GLIFOS_ANCHO_MURO_3_V2}).semieje_x >= 1.0 and Hechizo.construir(null, {"barrera": 1, "linea_x": Sigils.GLIFOS_ANCHO_MURO_3_V2 - 1}).semieje_x < 1.0, "ᛜ + 4 ᛁ llega a semieje 1,0 (muro de 3 casillas) y con 3 no")
	_ok(_casi(Hechizo.construir(null, {"linea_x": 99}).semieje_x, 3.0) and _casi(Hechizo.construir(null, {"altura": 99}).semieje_y, 1.0), "topes: X 3,0 y Y 1,0")
	# derivados
	var h: Hechizo = Hechizo.construir(runes["earth"], {"linea_x": 2, "barrera": 3, "repeticion": 2, "pulso": 1, "rebote": 1, "flecha": 1})
	var v: float = 4.0 / 3.0 * PI * h.semieje_x * h.semieje_y * h.semieje_z
	_ok(_casi(h.volumen, v) and _casi(h.masa, h.densidad * v) and h.densidad == 2.0, "derivados: volumen y masa = densidad × volumen")
	_ok(_casi(h.resistencia, 30.0 * h.solidez) and h.superficie > 0.0, "derivados: resistencia = 30 × solidez y superficie > 0")
	var esfera: Hechizo = Hechizo.construir(null, {})
	_ok(absf(esfera.superficie - 4.0 * PI * base * base) < 0.01,"superficie de la esfera base ≈ 4πr² (%.4f)" % esfera.superficie)
	_ok(h.viaja and h.anclado and h.protege and h.se_expande and h.se_repite and h.rebota and not h.flota, "estados de activación (viaja, anclado, protege, se_expande, se_repite, rebota; no flota)")
	_ok(not esfera.viaja and not esfera.anclado and not esfera.protege and not esfera.se_expande and not esfera.se_repite and not esfera.rebota and not esfera.flota, "sin glifos no hay ningún estado activo")
	_ok(h.copiar().con({"elevacion": 1.0}).flota, "elevacion > 0 → flota")
	# límites en con(): el laboratorio tampoco puede saltárselos
	var lab: Hechizo = Hechizo.construir(runes["fire"], {}).con({"semiejes.x": 5.0, "semiejes.y": 3.0, "semiejes.z": 0.01, "elevacion": 9.0, "distancia_max": 20.0, "persiste": 20.0, "permanencia": 20.0, "copias": 50})
	_ok(lab.semieje_x == 3.0 and lab.semieje_y == 1.0 and _casi(lab.semieje_z, lab.grosor_min) and lab.elevacion == 2.0 and lab.distancia_max == 8.0 and lab.copias == 8, "con(): topa en los límites de §1.9 y ningún semieje baja de grosor_min")
	_ok(_casi(lab.persiste + lab.permanencia, 25.0) and _casi(lab.persiste, 20.0), "con(): persiste + permanencia ≤ 25 s (la vida natural primero)")
	for campo in Hechizo.EDITABLES:                                    # el rango del lab nunca pasa de un límite
		var r: Dictionary = Hechizo.EDITABLES[campo]
		if campo == "semiejes.x" or campo == "semiejes.z":
			_ok(float(r["max"]) <= Hechizo.LIM_SEMIEJE_HORIZONTAL, "EDITABLES %s ≤ límite" % campo)
		elif campo == "semiejes.y":
			_ok(float(r["max"]) <= Hechizo.LIM_SEMIEJE_ALTO, "EDITABLES %s ≤ límite" % campo)
		elif campo == "distancia_max":
			_ok(float(r["max"]) <= Hechizo.LIM_DISTANCIA, "EDITABLES %s ≤ límite" % campo)
		elif campo == "copias":
			_ok(float(r["max"]) <= float(Hechizo.LIM_COPIAS), "EDITABLES %s ≤ límite" % campo)
		elif campo == "persiste" or campo == "permanencia":
			_ok(float(r["max"]) <= Hechizo.LIM_VIDA_S, "EDITABLES %s ≤ límite" % campo)
	# la velocidad de la flecha: la de ayer (4 u/s) dicha en metros
	_ok(_casi(Sigils.velocidad_flecha() * Terreno3D.casilla, 4.0) and Hechizo.construir(runes["fire"], {"flecha": 1}).velocidad == Sigils.velocidad_flecha(), "flecha: 4 u/s de la escala antigua = %.3f m/s" % Sigils.velocidad_flecha())
	# lo que aporta cada elemento (§2)
	var esperado: Dictionary = {"fire": [0.0, 0.2, 1.0, 0.0, 0.0], "water": [0.5, 1.0, 0.0, 1.0, 0.3], "earth": [1.0, 2.0, 0.0, 0.2, 0.0], "ice": [1.0, 0.9, -1.0, 0.5, 0.0], "lightning": [0.0, 0.0, 0.0, 0.0, 1.0], "wind": [0.0, 0.1, 0.0, 0.0, 0.0]}
	for e in esperado:
		var he: Hechizo = Hechizo.construir(runes[e], {})
		var t: Array = esperado[e]
		_ok(_casi(he.gravedad, t[0]) and _casi(he.densidad, t[1]) and _casi(he.temperatura, t[2]) and _casi(he.humedad, t[3]) and _casi(he.conductividad, t[4]), "%s: gravedad, densidad, temperatura, humedad y conductividad de §2" % e)
	# copiar() no copia los derivados de solo lectura (no tienen setter) y deja el original intacto
	var cp: Hechizo = h.copiar()
	_ok(_casi(cp.volumen, h.volumen) and cp.permanencia == h.permanencia and cp.elevacion == h.elevacion, "copiar(): mismos campos y derivados")
