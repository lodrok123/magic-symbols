extends "res://herramientas/escenario_base.gd"
## PRUEBA DE LA HIERBA PROCEDURAL Y EL DETALLE EN BLOQUES (6/11, Pablo: «una hierba más procedural… en vez de esparcir, pequeños bloques; lo mismo con pedruscos»). Headless:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_hierba_bloques.gd
## Carga el Bosque (letras, como los escenarios) y siembra aparte toda la hierba con la función de peso y las matas de la maqueta. Mide lo que es DATO (en headless el
## MultiMesh no guarda las copias, así que se leen las estadísticas que Hierba3D anota al crear cada bloque):
##   1. determinismo: dos siembras con la misma semilla dan la misma huella en todos los bloques; otra semilla, distinta; `rehacer_bloque_en` deja el bloque igual;
##   2. topes: ningún bloque pasa de `Hierba3D.TOPES` (matojos, tarjetas, flores, triángulos) y los topes son datos de la tabla; un bloque forzado por encima se ralea;
##   3. huecos: hay casillas de hierba (`v`) sin ningún matojo (calvas + claros) y la densidad por casilla varía más que con la hierba de antes;
##   4. variación procedural: los matojos no son todos iguales (3 mallas, no solo la de siempre) y con `procedural = false` sale la hierba de antes (una malla);
##   5. adornos en corros: `_prob_adorno` vale 0 en parte del mapa y hasta `prob_max` en otra, los adornos no pasan de `ADORNOS.max_total` y salen igual dos veces;
##   6. lo germinado sigue funcionando por bloque: al germinar una casilla de tierra, `rehacer_bloque_en` pone matojos en ella y las vecinas quedan como estaban.

var _t: Node = null
const S: float = 2.3


func _escenario() -> void:
	await cargar()
	if maqueta == null:
		return
	_t = maqueta
	await _determinismo()
	await _topes()
	await _huecos_y_variacion()
	_adornos()
	_germinar()


func _k(nombre: String) -> Variant:
	return (_t.get_script() as GDScript).get_script_constant_map()[nombre]


func _sembrar(semilla: int, procedural: bool, matas: bool = true) -> Hierba3D:
	var lado: int = int(_t.get("_lado"))
	var h := Hierba3D.new()
	h.brillo = float(_k("OSCURECER_SUELO"))
	h.semilla = semilla
	h.procedural = procedural
	h.casilla = S
	_t.add_child(h)
	h.sembrar(Rect2(0.0, 0.0, float(lado) * S, float(lado) * S), float(_k("ALTO")), Callable(_t, "_peso_hierba"), false, Callable(_t, "_alto_hierba"),
		Callable(_t, "_mata_hierba") if matas else Callable())
	return h


func _huellas(h: Hierba3D) -> Dictionary:
	var r: Dictionary = {}
	for b in h.nodos_bloques():
		var nombre: PackedStringArray = String((b as Node).name).split("_")
		var bb := Vector2i(int(nombre[1]), int(nombre[2]))
		r[bb] = int(h.estadisticas_bloque(bb).get("huella", 0))
	return r


func _determinismo() -> void:
	var h1: Hierba3D = _sembrar(7, true)
	var h2: Hierba3D = _sembrar(7, true)
	var h3: Hierba3D = _sembrar(8, true)
	var a: Dictionary = _huellas(h1)
	var b: Dictionary = _huellas(h2)
	var c: Dictionary = _huellas(h3)
	var iguales: int = 0
	var distintas: int = 0
	var con_hierba: int = 0
	for k in a:
		if b.get(k) == a[k]:
			iguales += 1
		if int(a[k]) != 0:          # los bloques sin hierba (huella 0) no cuentan: el Bosque tiene pocas casillas v
			con_hierba += 1
			if c.get(k) != a[k]:
				distintas += 1
	_ok("1 dos siembras con la misma semilla dan la misma huella en TODOS los bloques", a.size() > 50 and iguales == a.size(), "%d de %d bloques" % [iguales, a.size()])
	_ok("1 con otra semilla cambian (casi) todos los bloques con hierba", con_hierba > 20 and distintas >= con_hierba * 0.9, "%d de %d distintos" % [distintas, con_hierba])
	var e1: Dictionary = h1.estadisticas()
	var e2: Dictionary = h2.estadisticas()
	_ok("1 y los totales coinciden", e1 == e2, "%s" % [e1])
	# rehacer un bloque lo deja igual (lo que hace la maqueta al germinar)
	var bq: Vector2i = a.keys()[a.size() / 2]
	var antes: int = int(a[bq])
	h1.rehacer_bloque_en(Vector3((float(bq.x) + 0.5) * h1.lado_bloque, 0.0, (float(bq.y) + 0.5) * h1.lado_bloque))
	_ok("1 rehacer_bloque_en deja el bloque con la misma huella", int(h1.estadisticas_bloque(bq).get("huella", -1)) == antes, "bloque %s" % bq)
	# la semilla es por casilla: la cuenta de matojos de una casilla no depende del tamaño de bloque
	var h4: Hierba3D = Hierba3D.new()
	h4.brillo = float(_k("OSCURECER_SUELO"))
	h4.semilla = 7
	h4.procedural = true
	h4.casilla = S
	h4.lado_bloque = S * 3.0
	_t.add_child(h4)
	var lado: int = int(_t.get("_lado"))
	h4.sembrar(Rect2(0.0, 0.0, float(lado) * S, float(lado) * S), float(_k("ALTO")), Callable(_t, "_peso_hierba"), false, Callable(_t, "_alto_hierba"), Callable(_t, "_mata_hierba"))
	var mismas: int = 0
	var vistas: int = 0
	for cc in _casillas_de("v,"):
		var n1: int = h1.matojos_en_casilla(cc)
		var n4: int = h4.matojos_en_casilla(cc)
		if n1 < 0 or n4 < 0:
			continue
		vistas += 1
		if n1 == n4:
			mismas += 1
	_ok("1 la semilla es por CASILLA: con bloques de 3 casillas cada casilla tiene los mismos matojos que con bloques de 2 (salvo las que ralea el tope)", vistas > 60 and mismas >= vistas * 0.9,
		"%d de %d casillas de hierba iguales" % [mismas, vistas])
	for h in [h1, h2, h3, h4]:
		(h as Node).queue_free()
	await process_frame


func _topes() -> void:
	var topes: Dictionary = Hierba3D.TOPES
	_ok("2 los topes son datos de la tabla", topes.has("matojos_por_bloque") and topes.has("tarjetas_por_bloque") and topes.has("flores_por_bloque") and topes.has("triangulos_por_bloque") and topes.has("variantes"), str(topes))
	var h: Hierba3D = _sembrar(7, true)
	var e: Dictionary = h.estadisticas()
	var mal: int = 0
	var max_tri: int = 0
	var max_m: int = 0
	for b in h.nodos_bloques():
		var nombre: PackedStringArray = String((b as Node).name).split("_")
		var s: Dictionary = h.estadisticas_bloque(Vector2i(int(nombre[1]), int(nombre[2])))
		max_tri = maxi(max_tri, int(s["triangulos"]))
		max_m = maxi(max_m, int(s["matojos"]))
		if int(s["matojos"]) > int(topes["matojos_por_bloque"]) or int(s["tarjetas"]) > int(topes["tarjetas_por_bloque"]) or int(s["flores"]) > int(topes["flores_por_bloque"]) or int(s["triangulos"]) > int(topes["triangulos_por_bloque"]):
			mal += 1
	_ok("2 ningún bloque pasa de los topes de copias ni de triángulos", mal == 0, "%d bloques fuera; máx %d matojos y %d triángulos por bloque; total %d matojos, %d tarjetas, %d flores, %d triángulos en %d bloques" % [mal, max_m, max_tri, e["matojos"], e["tarjetas"], e["flores"], e["triangulos"], e["bloques"]])
	print("  (todo el mapa: %s)" % [e])
	h.queue_free()
	# un bloque forzado muy por encima del tope (densidad ×6) se ralea al tope exacto, nunca se pasa
	var hd: Hierba3D = Hierba3D.new()
	hd.brillo = float(_k("OSCURECER_SUELO"))
	hd.procedural = true
	hd.casilla = S
	hd.densidad = 30.0
	hd.densidad_tarjetas = 30.0
	hd.flores_por_unidad = 4.0
	_t.add_child(hd)
	hd.sembrar(Rect2(0.0, 0.0, S * 4.0, S * 4.0), 0.0, func(_x: float, _z: float) -> float: return 1.0)
	var peor: int = 0
	var peor_t: int = 0
	var peor_f: int = 0
	var peor_tri: int = 0
	for b in hd.nodos_bloques():
		var nombre: PackedStringArray = String((b as Node).name).split("_")
		var s: Dictionary = hd.estadisticas_bloque(Vector2i(int(nombre[1]), int(nombre[2])))
		peor = maxi(peor, int(s["matojos"]))
		peor_t = maxi(peor_t, int(s["tarjetas"]))
		peor_f = maxi(peor_f, int(s["flores"]))
		peor_tri = maxi(peor_tri, int(s["triangulos"]))
	_ok("2 con densidad ×6 el bloque se ralea a los topes (matojos, tarjetas, flores, triángulos)", peor <= int(topes["matojos_por_bloque"]) and peor_t <= int(topes["tarjetas_por_bloque"]) and peor_f <= int(topes["flores_por_bloque"]) and peor_tri <= int(topes["triangulos_por_bloque"]) and peor_tri > int(topes["triangulos_por_bloque"]) * 0.7,
		"máx %d matojos, %d tarjetas, %d flores, %d triángulos" % [peor, peor_t, peor_f, peor_tri])
	hd.queue_free()
	await process_frame


func _casillas_de(letras: String) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	var lado: int = int(_t.get("_lado"))
	for z in range(lado):
		for x in range(lado):
			if letras.contains(String(_t.call("_letra", Vector2i(x, z)))):
				r.append(Vector2i(x, z))
	return r


func _cv_y_vacias(h: Hierba3D) -> Array:
	var cuentas: Array[float] = []
	var vacias: int = 0
	for c in _casillas_de("v,"):
		var n: int = h.matojos_en_casilla(c)
		if n < 0:
			continue
		cuentas.append(float(n))
		if n == 0:
			vacias += 1
	var media: float = 0.0
	for x in cuentas:
		media += x
	media /= float(maxi(cuentas.size(), 1))
	var va: float = 0.0
	for x in cuentas:
		va += (x - media) * (x - media)
	var cv: float = sqrt(va / float(maxi(cuentas.size(), 1))) / maxf(media, 0.001)
	return [cv, vacias, cuentas.size(), media]


func _huecos_y_variacion() -> void:
	var hp: Hierba3D = _sembrar(7, true)
	var ha: Hierba3D = _sembrar(7, false)
	var p: Array = _cv_y_vacias(hp)
	var a: Array = _cv_y_vacias(ha)
	_ok("3 hay casillas de hierba (v y ,) sin ningún matojo (calvas y claros)", int(p[1]) >= int(float(p[2]) * 0.08), "%d de %d casillas de hierba vacías (antes %d)" % [p[1], p[2], a[1]])
	_ok("3 la densidad por casilla varía más que con la hierba de antes (CV)", float(p[0]) > float(a[0]) * 1.1, "CV %.2f antes → %.2f ahora · media %.1f → %.1f matojos/casilla" % [a[0], p[0], a[3], p[3]])
	var ep: Dictionary = hp.estadisticas()
	var ea: Dictionary = ha.estadisticas()
	_ok("3 y no cuesta más: no hay más copias ni triángulos que antes", int(ep["matojos"]) + int(ep["tarjetas"]) <= int(ea["matojos"]) + int(ea["tarjetas"]) and int(ep["triangulos"]) <= int(ea["triangulos"]) * 1.05,
		"copias %d → %d, triángulos %d → %d" % [int(ea["matojos"]) + int(ea["tarjetas"]), int(ep["matojos"]) + int(ep["tarjetas"]), ea["triangulos"], ep["triangulos"]])
	# variación: con procedural hay MultiMesh de las 3 variantes de matojo; sin él, solo "briznas"
	var variantes_p: Dictionary = {}
	var variantes_a: Dictionary = {}
	for b in hp.nodos_bloques():
		for hijo in (b as Node).get_children():
			if String(hijo.name).begins_with("briznas"):
				variantes_p[hijo.name] = true
	for b in ha.nodos_bloques():
		for hijo in (b as Node).get_children():
			if String(hijo.name).begins_with("briznas"):
				variantes_a[hijo.name] = true
	_ok("4 los matojos salen de %d mallas distintas (TOPES.variantes)" % int(Hierba3D.TOPES["variantes"]), variantes_p.size() == int(Hierba3D.TOPES["variantes"]), str(variantes_p.keys()))
	_ok("4 con procedural = false es la hierba de antes: una sola malla", variantes_a.size() == 1 and variantes_a.has("briznas"), str(variantes_a.keys()))
	_ok("4 el shader de las briznas lleva la fase propia del balanceo (INSTANCE_CUSTOM.a)", Hierba3D.CODIGO_MATOJO.contains("INSTANCE_CUSTOM.a * 6.2832"))
	_ok("4 la tabla AGRUPADO tiene calvas, densidad, alto, ancho, inclinación y tono", ["p_calva", "tam_densidad", "densidad_min", "alto_min", "alto_max", "ancho_min", "ancho_max", "inclinacion_max", "tono"].all(func(k: String) -> bool: return Hierba3D.AGRUPADO.has(k)))
	hp.queue_free()
	ha.queue_free()
	await process_frame


func _adornos() -> void:
	var tabla: Dictionary = _k("ADORNOS")
	var lado: int = int(_t.get("_lado"))
	var ceros: int = 0
	var altos: int = 0
	var n: int = 0
	for z in range(lado):
		for x in range(lado):
			var p: float = float(_t.call("_prob_adorno", Vector2i(x, z)))
			n += 1
			if p <= 0.0:
				ceros += 1
			if p >= float(tabla["prob_max"]) * 0.9:
				altos += 1
	_ok("5 los adornos van en corros: en parte del mapa la probabilidad es 0 y en otra parte llega a prob_max", ceros > n * 0.2 and altos > n * 0.05, "0 en el %.0f %% de las casillas, ≥ 0,9·prob_max en el %.0f %%" % [100.0 * float(ceros) / float(n), 100.0 * float(altos) / float(n)])
	var pos: Array = _t.get("_adornos_pos")
	_ok("5 hay adornos y no pasan del tope ADORNOS.max_total", pos.size() > 0 and pos.size() <= int(tabla["max_total"]), "%d adornos (tope %d)" % [pos.size(), tabla["max_total"]])
	# por casilla ocupada: los adornos caen solo en casillas con probabilidad > 0
	var fuera: int = 0
	for p in pos:
		var c := Vector2i(floori((p as Vector3).x / S), floori((p as Vector3).z / S))
		if float(_t.call("_prob_adorno", c)) <= 0.0:
			# el grupito puede desbordar a la casilla vecina (radio 0,5 u): se mira también la vecindad
			var alguna: bool = false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if float(_t.call("_prob_adorno", c + d)) > 0.0:
					alguna = true
			if not alguna:
				fuera += 1
	_ok("5 ningún adorno fuera de un corro", fuera == 0, "%d fuera" % fuera)
	# con el interruptor apagado vuelve la probabilidad pareja de antes
	_t.set("detalle_en_bloques", false)
	var p0: float = float(_t.call("_prob_adorno", Vector2i(3, 3)))
	_t.set("detalle_en_bloques", true)
	_ok("5 con detalle_en_bloques = false vuelve el reparto parejo (PROB_GRUPO_ADORNO)", is_equal_approx(p0, float(_k("PROB_GRUPO_ADORNO"))), "%.2f" % p0)


## Germinar: la maqueta rehace el bloque y la casilla pasa a tener matojos; sus vecinas no cambian (el bloque se vuelve a crear con la misma semilla por casilla).
func _germinar() -> void:
	var h: Hierba3D = _t.get("_hierba") as Hierba3D
	if h == null:
		_ok("6 la maqueta tiene su Hierba3D", false)
		return
	var tierra: Vector2i = Vector2i(-1, -1)
	var lado: int = int(_t.get("_lado"))
	var bloq: Dictionary = _t.get("_bloqueadas")
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if int(_t.call("_tipo_suelo", c)) == 2 and not Terreno3D.es_agua(c) and not bloq.has(c):
				tierra = c
				break
		if tierra.x >= 0:
			break
	_ok("6 hay una casilla de tierra para germinar", tierra.x >= 0, str(tierra))
	if tierra.x < 0:
		return
	colocar_jugador(tierra + Vector2i(0, 2))
	_t.call("ir_a", tierra + Vector2i(0, 2))
	h.actualizar(Terreno3D.centro_de(tierra + Vector2i(0, 2), 0.0), true)
	var antes: int = h.matojos_en_casilla(tierra)
	var vecina: Vector2i = tierra + Vector2i(1, 0)
	var vecina_antes: int = h.matojos_en_casilla(vecina)
	_ok("6 antes de germinar la casilla de tierra no tiene matojos", antes == 0, "%d" % antes)
	var e: EstadosSuelo3D = Terreno3D.estados
	e.poner(tierra, EstadosSuelo3D.MOJADA, true, 1.0, 60.0)
	var r: Dictionary = e.aplicar(tierra, "brota")
	_ok("6 la naturaleza germina la tierra mojada", bool(r.get("cambio", false)) and e.material_de(tierra) == "hierba")
	var despues: int = h.matojos_en_casilla(tierra)
	_ok("6 tras germinar, el bloque se rehízo y la casilla tiene matojos", despues > 0, "%d matojos" % despues)
	_ok("6 la casilla vecina queda como estaba (misma semilla por casilla)", h.matojos_en_casilla(vecina) == vecina_antes, "%d → %d" % [vecina_antes, h.matojos_en_casilla(vecina)])
	e.poner(tierra, EstadosSuelo3D.MOJADA, false)
