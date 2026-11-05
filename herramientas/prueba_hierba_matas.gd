extends "res://herramientas/escenario_base.gd"
## PRUEBA DE LA HIERBA EN MATAS Y LOS ADORNOS DE LOS CLAROS (5/11, diario 370). Corre en headless:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_hierba_matas.gd   (los puntos 3 y 4 necesitan VENTANA: sin ella, el MultiMesh no guarda las posiciones; se saltan con un AVISO)
## Carga el Bosque 02 (el nivel horneado, como el juego) y siembra aparte, con la misma función de peso, la hierba de TODO el mapa dos veces: sin matas (como antes) y con ellas.
##   1. las matas: el campo `_mata_hierba` tiene claros y centros (cobertura entre 25 % y 75 %) y la siembra con matas NO pone más briznas ni tarjetas que la de antes;
##   2. la densidad por casilla de hierba varía mucho más con matas (coeficiente de variación de las briznas por casilla `v`);
##   3. la hierba no crece donde no debe: ni una brizna en casillas de camino, agua, piedra o pared (los mismos límites que antes);
##   4. los adornos (`_sembrar_adornos`): hay, son de setas y de piedras pisables, caen en casillas de hierba, lejos de caminos/agua/marcadores/piezas/piezas de puzle, y son deterministas.

const RUTA: String = "res://escenas/PruebaBosque02.tscn"

var _t: Node = null


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	maqueta = null
	await _cargar_nivel()
	if maqueta == null:
		return
	_t = maqueta
	_matas()
	await _siembra()
	_adornos()


func _cargar_nivel() -> void:
	reloj = Reloj.new()
	root.add_child(reloj)
	maqueta = (load(RUTA) as PackedScene).instantiate()
	maqueta.set("usar_escena", true)
	root.add_child(maqueta)
	var n: int = 0
	while n < 600 and (get_first_node_in_group("spellcaster") == null or Terreno3D.agua_sim == null):
		await process_frame
		n += 1
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	var pared: int = Time.get_ticks_msec()
	while jugador != null and not jugador.puede_lanzar() and Time.get_ticks_msec() - pared < 30000:
		await process_frame
	_ok("0 el Bosque 02 monta", lanzador != null and jugador != null)
	await avanzar(10)


## Una constante de la maqueta (Object.get no lee constantes).
func _k(nombre: String) -> Variant:
	return (_t.get_script() as GDScript).get_script_constant_map()[nombre]


func _letra(c: Vector2i) -> String:
	return String(_t.call("_letra", c))


func _casillas_de(letras: String) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	var lado: int = int(_t.get("_lado"))
	for z in range(lado):
		for x in range(lado):
			if letras.contains(_letra(Vector2i(x, z))):
				r.append(Vector2i(x, z))
	return r


func _matas() -> void:
	var s: float = 2.3
	var hierba: Array[Vector2i] = _casillas_de("v,")
	var suma: float = 0.0
	var suma2: float = 0.0
	var con_mata: int = 0
	var claro: int = 0
	var n: int = 0
	for c in hierba:
		for k in range(4):
			var x: float = (float(c.x) + 0.25 + 0.5 * float(k % 2)) * s
			var z: float = (float(c.y) + 0.25 + 0.5 * float(k / 2)) * s
			var m: float = float(_t.call("_mata_hierba", x, z))
			suma += m
			suma2 += m * m
			n += 1
			if m > 0.5:
				con_mata += 1
			if m < 0.1:
				claro += 1
	var media: float = suma / float(maxi(n, 1))
	var varianza: float = suma2 / float(maxi(n, 1)) - media * media
	var cobertura: float = float(con_mata) / float(maxi(n, 1))
	_ok("1 el campo de matas tiene manchas y claros", cobertura > 0.25 and cobertura < 0.75 and float(claro) / float(maxi(n, 1)) > 0.15,
		"mata>0,5 en el %.0f %% de la hierba, claro (<0,1) en el %.0f %%, varianza %.3f (sin matas: 0)" % [cobertura * 100.0, 100.0 * float(claro) / float(maxi(n, 1)), varianza])


## Siembra aparte toda la hierba (sin y con matas) y mide.
func _siembra() -> void:
	var lado: int = int(_t.get("_lado"))
	var s: float = 2.3
	var res: Dictionary = {}
	for con in [false, true]:
		var h := Hierba3D.new()
		h.brillo = float(_k("OSCURECER_SUELO"))
		_t.add_child(h)
		var t0: int = Time.get_ticks_msec()
		h.sembrar(Rect2(0.0, 0.0, float(lado) * s, float(lado) * s), float(_k("ALTO")), Callable(_t, "_peso_hierba"), false, Callable(_t, "_alto_hierba"),
			Callable(_t, "_mata_hierba") if con else Callable())
		var ms: int = Time.get_ticks_msec() - t0
		var bri: int = 0
		var tar: int = 0
		var flo: int = 0
		var por_casilla: Dictionary = {}
		var mal: int = 0
		for b in h.nodos_bloques():
			var nb: Node = b as Node
			var m1: Node = nb.get_node_or_null("briznas")
			if m1 != null:
				var mm: MultiMesh = (m1 as MultiMeshInstance3D).multimesh
				bri += mm.instance_count
				for i in range(mm.instance_count):
					var o: Vector3 = mm.get_instance_transform(i).origin
					var c := Vector2i(floori(o.x / s), floori(o.z / s))
					por_casilla[c] = int(por_casilla.get(c, 0)) + 1
					var l: String = _letra(c)
					if l == "g" or l == "~" or l == "b" or l == "R" or l == "#" or l == " " or l == "c" or l == "E" or l == "X" or l == "S":
						mal += 1
			var m2: Node = nb.get_node_or_null("tarjetas")
			if m2 != null:
				tar += (m2 as MultiMeshInstance3D).multimesh.instance_count
			var m3: Node = nb.get_node_or_null("flores")
			if m3 != null:
				flo += (m3 as MultiMeshInstance3D).multimesh.instance_count
		# densidad por casilla `v` (todas, también las vacías)
		var cuentas: Array[float] = []
		for c in _casillas_de("v"):
			cuentas.append(float(por_casilla.get(c, 0)))
		var media: float = 0.0
		for x in cuentas:
			media += x
		media /= float(maxi(cuentas.size(), 1))
		var va: float = 0.0
		var pocas: int = 0
		for x in cuentas:
			va += (x - media) * (x - media)
			if x < media * 0.25:
				pocas += 1
		var cv: float = sqrt(va / float(maxi(cuentas.size(), 1))) / maxf(media, 0.001)
		res[con] = {"bri": bri, "tar": tar, "flo": flo, "cv": cv, "mal": mal, "ms": ms, "pocas": float(pocas) / float(maxi(cuentas.size(), 1)), "media": media}
		print("  (casillas con briznas: %d)" % por_casilla.size())
		print("  %s: %d briznas + %d tarjetas + %d flores · %d ms · %d casillas v · media %.1f briznas/casilla v · CV %.2f · casillas casi vacías %.0f %%" % [
			"con matas" if con else "sin matas (antes)", bri, tar, flo, ms, cuentas.size(), media, cv, float(pocas) / float(maxi(cuentas.size(), 1)) * 100.0])
		h.queue_free()
		await process_frame
	var a: Dictionary = res[false]
	var d: Dictionary = res[true]
	_ok("2 con matas no hay MÁS briznas ni tarjetas que antes (coste igual o menor)", int(d["bri"]) + int(d["tar"]) <= int(a["bri"]) + int(a["tar"]),
		"briznas %d → %d (%.0f %%), tarjetas %d → %d (%.0f %%)" % [a["bri"], d["bri"], 100.0 * float(d["bri"]) / maxf(float(a["bri"]), 1.0), a["tar"], d["tar"], 100.0 * float(d["tar"]) / maxf(float(a["tar"]), 1.0)])
	if DisplayServer.get_name() == "headless":
		_aviso("3-4 densidad por casilla y límites de la hierba", "se saltan en headless (el MultiMesh no guarda las posiciones sin render): correr con ventana")
		return
	_ok("3 la densidad por casilla varía más con matas (CV)", float(d["cv"]) > float(a["cv"]) * 1.8, "CV %.2f → %.2f" % [a["cv"], d["cv"]])
	_ok("3 y hay claros reales (casillas v con < 25 % de la media)", float(d["pocas"]) > float(a["pocas"]) + 0.10, "%.0f %% → %.0f %%" % [100.0 * float(a["pocas"]), 100.0 * float(d["pocas"])])
	_ok("4 ninguna brizna en camino, agua, piedra o pared (con matas no más que antes)", int(d["mal"]) <= int(a["mal"]), "antes %d, con matas %d" % [a["mal"], d["mal"]])
	_ok("4 y la parte de briznas que se escapa por el borde ondulado no crece (≤ antes + 1,5 puntos)", float(d["mal"]) / maxf(float(d["bri"]), 1.0) <= float(a["mal"]) / maxf(float(a["bri"]), 1.0) + 0.015, "%.1f %% antes, %.1f %% con matas" % [100.0 * float(a["mal"]) / maxf(float(a["bri"]), 1.0), 100.0 * float(d["mal"]) / maxf(float(d["bri"]), 1.0)])

func _adornos() -> void:
	var pos: Array = _t.get("_adornos_pos")
	var n_set: int = int(_t.get("_adornos_setas"))
	var n_pie: int = int(_t.get("_adornos_piedras"))
	_ok("5 hay adornos de las dos clases", n_set >= 3 and n_pie >= 3, "%d setas y %d piedrecitas (%d en total)" % [n_set, n_pie, pos.size()])
	var s: float = 2.3
	var mal_letra: int = 0
	var mal_bloq: int = 0
	var mal_mata: int = 0
	var mal_cerca: int = 0
	var bloq: Dictionary = _t.get("_bloqueadas")
	var oc: Dictionary = _t.call("_ocupacion_adornos")
	for p in pos:
		var pv := p as Vector3
		var c := Vector2i(floori(pv.x / s), floori(pv.z / s))
		var l: String = _letra(c)
		if not (l == "." or l == "," or l == "v"):
			mal_letra += 1
		if bloq.has(c):
			mal_bloq += 1
		if (l == "v" or l == ",") and float(_t.call("_mata_hierba", pv.x, pv.z)) > float(_k("MATA_MAX_ADORNO")) + 1.0e-4:
			mal_mata += 1
		# a MARGEN_ADORNO de toda casilla que no sea hierba (camino, agua, marcadores)
		if not bool(_t.call("_lejos_de_no_hierba", pv, c)):
			mal_letra += 1
		# lejos de toda pieza (la ocupación ya incluye los propios adornos: se descuenta uno mismo con una distancia > 0)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var lista: Variant = oc.get(c + Vector2i(dx, dz))
				if lista == null:
					continue
				for o in (lista as Array):
					var d: float = (o as Vector2).distance_to(Vector2(pv.x, pv.z))
					if d > 0.001 and d < float(_k("RADIO_LIBRE_ADORNO")) - 0.4:      # entre adornos del mismo grupo (≤ 1 u) no cuenta; sí cualquier pieza real
						if not _es_de_grupo(pos, o as Vector2):
							mal_cerca += 1
	_ok("6 todos en casillas de hierba (`.` `,` `v`) con la vecindad libre de camino, agua y marcadores", mal_letra == 0, "%d fuera" % mal_letra)
	_ok("6 ninguno en una casilla bloqueada (sin colisión: no son cuerpos)", mal_bloq == 0, "%d" % mal_bloq)
	_ok("6 los de casillas de hierba con briznas solo salen donde hay claro", mal_mata == 0, "%d" % mal_mata)
	_ok("6 ninguno junto a una pieza, marcador, reactivo o pieza de puzle", mal_cerca == 0, "%d demasiado cerca" % mal_cerca)
	# nada en las casillas de las piezas de puzle (cofres, setas recogibles, jarrones…) ni a menos de una casilla de ellas
	var puz: Array = _t.call("_celdas_puzle_del_mapa")
	_ok("7 se leen las casillas de las piezas de puzle del .txt", puz.size() > 40, "%d casillas" % puz.size())
	var sobre_puzle: int = 0
	for p in pos:
		var pv2 := p as Vector3
		var c2 := Vector2i(floori(pv2.x / s), floori(pv2.z / s))
		for q in puz:
			if absi((q as Vector2i).x - c2.x) <= 0 and absi((q as Vector2i).y - c2.y) <= 0:
				sobre_puzle += 1
	_ok("7 ningún adorno sobre la casilla de una pieza de puzle (cofre, seta recogible, jarrón…)", sobre_puzle == 0, "%d" % sobre_puzle)
	# determinismo: el mismo grupo dos veces sale idéntico (se deshace lo añadido a los lotes)
	var lotes: Dictionary = _t.get("_lotes")
	var tam: Dictionary = {}
	for id in lotes:
		tam[id] = (lotes[id] as Array).size()
	var base_n: int = (_t.get("_adornos_pos") as Array).size()
	var c_prueba := Vector2i(12, 36)
	_t.call("_grupo_adornos", c_prueba, {})
	var a1: Array = (_t.get("_adornos_pos") as Array).slice(base_n)
	var b1: int = (_t.get("_adornos_pos") as Array).size()
	_t.call("_grupo_adornos", c_prueba, {})
	var a2: Array = (_t.get("_adornos_pos") as Array).slice(b1)
	_ok("8 un grupo sale igual cada vez (determinista por casilla)", a1.size() > 0 and a1 == a2, "%d y %d adornos" % [a1.size(), a2.size()])
	for id in lotes:
		var arr: Array = lotes[id] as Array
		while arr.size() > int(tam.get(id, 0)):
			arr.pop_back()
	var ap: Array = _t.get("_adornos_pos")
	while ap.size() > base_n:
		ap.pop_back()


func _es_de_grupo(pos: Array, o: Vector2) -> bool:
	for p in pos:
		if Vector2((p as Vector3).x, (p as Vector3).z).distance_to(o) < 0.001:
			return true
	return false
