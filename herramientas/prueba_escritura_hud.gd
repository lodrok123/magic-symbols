extends SceneTree
## Fase 14.3 / 14.4 (Pipeline, 16/10): la mano con pluma y su tinta, los PNG del HUD (bolsa, iconos de objeto, diario) y el rastrojo.
##   godot --headless --path . --script res://herramientas/prueba_escritura_hud.gd
## Prueba la lógica y que los archivos existen y miden lo que dicen: no que «se vea bien» (eso son las capturas, ARTE.md §10).

var _fallos: int = 0
const LAM: String = "res://presentacion/ui/laminas/"


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_pngs()
	_bolsa()
	_tinta()
	await _mano()
	_rastrojo()
	await _maqueta()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _img(nombre: String) -> Image:
	var im := Image.new()
	if im.load(ProjectSettings.globalize_path(LAM + nombre)) != OK:
		return null
	return im


func _cobertura(im: Image) -> float:
	var n: int = 0
	for y in range(0, im.get_height(), 2):
		for x in range(0, im.get_width(), 2):
			if im.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float((im.get_width() / 2) * (im.get_height() / 2))


func _pngs() -> void:
	var mal: Array = []
	for f in ["mano_pluma", "mano_reposo", "mano_escribiendo", "mano_levantada", "sombra_reposo", "sombra_escribiendo", "sombra_levantada"]:
		var im: Image = _img(f + ".png")
		if im == null or im.get_size() != Vector2i(560, 560):
			mal.append(f)
	_ok("A1 las 7 capas de la mano miden 560 × 560 (la punta está en el mismo píxel de todas)", mal.is_empty(), "mal: " + str(mal))
	var pl: Image = _img("mano_pluma.png")
	var p: Vector2i = Vector2i(ManoPluma2D.PUNTA_PX)
	var hay_tinta: bool = false
	if pl != null:
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				hay_tinta = hay_tinta or pl.get_pixel(p.x + dx, p.y + dy).a > 0.5
	_ok("A2 la punta de la pluma está donde dice PUNTA_PX", hay_tinta)
	# Los iconos de TODO objeto del catálogo (menos oro y poción, que ya tienen el suyo de Pablo).
	var sin_icono: Array = []
	var vacios: Array = []
	for id in Objetos.DATOS.keys():
		if id == "oro" or id == "pocion":
			continue            # la moneda y el frasco ya tienen arte de Pablo (mochila_moneda.png, objeto_pocion.png)
		var im: Image = _img("objeto_%s.png" % id)
		if im == null:
			sin_icono.append(id)
		elif im.get_size() != Vector2i(128, 128) or _cobertura(im) < 0.10:
			vacios.append(id)
	_ok("A3 cada objeto del catálogo tiene su icono 128 × 128", sin_icono.is_empty() and vacios.is_empty(), "sin icono: %s, vacíos: %s" % [str(sin_icono), str(vacios)])
	var dia: Array = []
	for f in ["diario_pergamino", "diario_icono_principal", "diario_icono_secundaria", "diario_seguida", "diario_casilla", "diario_casilla_hecha", "bolsa_banda_nombre"]:
		var im: Image = _img(f + ".png")
		if im == null or _cobertura(im) < 0.2:
			dia.append(f)
	_ok("A4 el diario de misiones y la banda del nombre existen y no están vacíos", dia.is_empty(), "mal: " + str(dia))
	var principal: Image = _img("diario_icono_principal.png")
	var secundaria: Image = _img("diario_icono_secundaria.png")
	_ok("A5 los iconos de misión principal y secundaria son de 64 × 64 y distintos", principal != null and secundaria != null and principal.get_size() == Vector2i(64, 64) and secundaria.get_size() == Vector2i(64, 64) and principal.get_data() != secundaria.get_data())


func _bolsa() -> void:
	var f: FileAccess = FileAccess.open(LAM + "bolsa_anclas.json", FileAccess.READ)
	var meta: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {}
	_ok("B1 bolsa_anclas.json existe con los dos tamaños", meta.has("g") and meta.has("p"))
	for k in ["g", "p"]:
		if not meta.has(k):
			continue
		var tam: Array = meta[k]["tam"]
		var sil: Image = _img("bolsa_silueta_%s.png" % k)
		var inte: Image = _img("bolsa_interior_%s.png" % k)
		_ok("B2%s la silueta «%s» mide %dx%d y su máscara interior lo mismo" % [k, k, tam[0], tam[1]], sil != null and inte != null and sil.get_size() == Vector2i(tam[0], tam[1]) and inte.get_size() == sil.get_size())
		var fuera: int = 0
		var total: int = 0
		var filas: Array = meta[k]["filas"]
		for fila in filas:
			for x in fila["x"]:
				total += 1
				if inte == null or inte.get_pixel(int(float(x) * tam[0]), int(float(fila["y"]) * tam[1])).a < 0.5:
					fuera += 1
		_ok("B3%s todas las anclas («%s», %d) caen dentro del interior de la bolsa" % [k, k, total], total >= 12 and fuera == 0, "fuera: %d" % fuera)
		var estrecha: bool = true
		var primera: float = float((filas[0]["x"] as Array).size())
		estrecha = primera <= float((filas[filas.size() - 2]["x"] as Array).size())
		_ok("B4%s las filas se estrechan hacia el cuello (la de arriba tiene menos huecos que la panza)" % k, estrecha)


func _tinta() -> void:
	_ok("T1 el ancho baja con la velocidad y respeta los límites",
		is_equal_approx(TintaPluma2D.ancho_por_velocidad(0.0), TintaPluma2D.ANCHO_MAX)
		and is_equal_approx(TintaPluma2D.ancho_por_velocidad(5000.0), TintaPluma2D.ANCHO_MIN)
		and TintaPluma2D.ancho_por_velocidad(200.0) > TintaPluma2D.ancho_por_velocidad(600.0))
	var t := TintaPluma2D.new()
	root.add_child(t)
	t.empezar(Vector2(0, 0), 0.0)
	# Un tramo despacio (5 px cada 50 ms = 100 px/s) y otro deprisa (60 px cada 16 ms = 3750 px/s).
	for i in range(1, 12):
		t.anadir(Vector2(5.0 * i, 0), 0.05 * i)
	var lento: float = t.anchos()[t.anchos().size() - 1]
	var tiempo: float = 0.6
	var x: float = 55.0
	for i in 12:
		tiempo += 0.016
		x += 60.0
		t.anadir(Vector2(x, 0), tiempo)
	var rapido: float = t.anchos()[t.anchos().size() - 1]
	_ok("T2 el trazo es más fino donde se va deprisa", rapido < lento - 2.0, "lento=%.1f rápido=%.1f" % [lento, rapido])
	_ok("T3 el primer punto lleva el borrón de la pluma al tocar", t.anchos()[0] > TintaPluma2D.ANCHO_MAX)
	var n0: int = t.n_puntos()
	t.anadir(Vector2(x + 0.5, 0), tiempo + 0.016)
	_ok("T4 un punto a menos de 1,5 px del anterior no se añade", t.n_puntos() == n0)
	t.soltar()
	_ok("T5 al soltar salen entre 2 y 6 gotas", t.n_gotas() >= TintaPluma2D.GOTAS_MIN and t.n_gotas() <= TintaPluma2D.GOTAS_MAX, "gotas=%d" % t.n_gotas())
	var u := TintaPluma2D.new()
	root.add_child(u)
	u.empezar(Vector2.ZERO, 0.0)
	for i in range(1, 6):
		u.anadir(Vector2(4.0 * i, 0), 0.05 * i)
	u.soltar()
	_ok("T6 despacio salpica menos que deprisa", u.n_gotas() <= t.n_gotas(), "despacio=%d deprisa=%d" % [u.n_gotas(), t.n_gotas()])
	var v := TintaPluma2D.new()
	root.add_child(v)
	v.soltar()
	_ok("T7 soltar sin trazo no hace nada", v.n_gotas() == 0 and v.n_puntos() == 0)
	t.limpiar()
	_ok("T8 limpiar lo borra todo", t.n_puntos() == 0 and t.n_gotas() == 0)
	var l := PackedVector2Array()
	for i in 20:
		l.append(Vector2(10.0 * i, 0))
	t.dibujar_limpio(l)
	var a: PackedFloat32Array = t.anchos()
	_ok("T9 el trazo limpio adelgaza en las dos puntas y engorda en medio", a.size() == 20 and a[10] > a[0] and a[10] > a[19] and is_equal_approx(a[0], a[19]) or (a.size() == 20 and a[10] > a[0] and a[10] > a[19]))
	t.free()
	u.free()
	v.free()


func _mano() -> void:
	# El retardo de 60 ms: la punta va donde estaba el punto hace 60 ms (interpolado), no donde está.
	var buf: Array = [[0.00, Vector2(0, 0)], [0.05, Vector2(50, 0)], [0.10, Vector2(100, 0)], [0.15, Vector2(150, 0)]]
	var q: Vector2 = ManoPluma2D.punto_con_retardo(buf, 0.15)
	_ok("M1 la punta va 60 ms por detrás: a t=0,15 está donde estaba a t=0,09", absf(q.x - 90.0) < 0.01, "x=%.2f" % q.x)
	_ok("M2 antes de que haya historia suficiente se queda en la primera muestra", ManoPluma2D.punto_con_retardo(buf, 0.03).x == 0.0)
	_ok("M3 sin muestras no falla", ManoPluma2D.punto_con_retardo([], 1.0) == Vector2.ZERO)
	_ok("M4 parada del todo, la punta alcanza el punto", ManoPluma2D.punto_con_retardo([[0.0, Vector2(10, 10)], [1.0, Vector2(10, 10)]], 1.0) == Vector2(10, 10))
	_ok("M5 la inclinación de la pluma está acotada a ±12° y sigue el signo de la velocidad",
		is_equal_approx(ManoPluma2D.inclinacion(Vector2(99999, 0)), ManoPluma2D.INCLINA_MAX)
		and is_equal_approx(ManoPluma2D.inclinacion(Vector2(-99999, 0)), -ManoPluma2D.INCLINA_MAX)
		and ManoPluma2D.inclinacion(Vector2.ZERO) == 0.0)
	var m := ManoPluma2D.new()
	root.add_child(m)
	await process_frame
	var capas: Array = []
	for n in ["sombra", "pluma", "mano"]:
		capas.append(m.get_node("grupo").get_node(n).get_index())
	_ok("M6 las capas van en el orden sombra → pluma → mano (los dedos tapan la pluma)", capas == [0, 1, 2], str(capas))
	_ok("M7 las capas tienen textura (los PNG están importados)", (m.get_node("grupo/mano") as Sprite2D).texture != null and (m.get_node("grupo/pluma") as Sprite2D).texture != null and (m.get_node("grupo/sombra") as Sprite2D).texture != null)
	# Pulsando: pose ESCRIBIENDO y la mano se baja a la página; sin pulsar: LEVANTADA.
	for i in 12:
		m.apuntar(Vector2(100 + 8 * i, 200), true)
		await process_frame
	_ok("M8 pulsando, la pose es ESCRIBIENDO", m.pose == ManoPluma2D.Pose.ESCRIBIENDO)
	var alz_escribiendo: float = m._alzada
	for i in 12:
		m.apuntar(Vector2(200, 200), false)
		await process_frame
	_ok("M9 al soltar, la pose pasa a LEVANTADA y la mano sube (alzada crece)", m.pose == ManoPluma2D.Pose.LEVANTADA and m._alzada > alz_escribiendo, "alzada %.2f → %.2f" % [alz_escribiendo, m._alzada])
	_ok("M10 la punta se coloca en el padre en la posición con retardo", m.punta().distance_to(m.position) < 0.001)
	m.ocultar()
	_ok("M11 ocultar la esconde y mostrar la devuelve", not m.visible)
	m.mostrar()
	_ok("M12 mostrar", m.visible)
	m.free()


func _rastrojo() -> void:
	var r := Rastrojo3D.new()
	root.add_child(r)
	r.poner(Vector2i(3, 4), 1.0, Rastrojo3D.TIPO_CORTADO)
	r.poner(Vector2i(5, 4), 1.0, Rastrojo3D.TIPO_QUEMADO)
	r.reconstruir_ahora()
	_ok("R1 dos casillas: hay, de qué tipo, y cuántas", r.hay(Vector2i(3, 4)) and r.tipo_de(Vector2i(5, 4)) == "quemado" and r.numero() == 2)
	_ok("R2 tres matas y una mancha por casilla", r.n_matas() == 6 and r.n_manchas() == 2)
	var mm: MultiMeshInstance3D = r.get_node_or_null("matas")
	_ok("R3 los dos MultiMesh tienen las instancias que dicen", mm != null and mm.multimesh.instance_count == 6 and (r.get_node("manchas") as MultiMeshInstance3D).multimesh.instance_count == 2)
	# Determinismo y colocación: una mata queda dentro de su casilla.
	var dentro: bool = true
	for i in 6:
		var o: Vector3 = mm.multimesh.get_instance_transform(i).origin
		var c: Vector2i = Vector2i(int(floorf(o.x / r.lado)), int(floorf(o.z / r.lado)))
		dentro = dentro and (c == Vector2i(3, 4) or c == Vector2i(5, 4)) and absf(o.y - 1.0) < 0.001
	_ok("R4 cada mata queda dentro de su casilla y sobre el suelo", dentro)
	var antes: Vector3 = mm.multimesh.get_instance_transform(0).origin
	r.limpiar()
	r.poner(Vector2i(3, 4), 1.0, Rastrojo3D.TIPO_CORTADO)
	r.poner(Vector2i(5, 4), 1.0, Rastrojo3D.TIPO_QUEMADO)
	r.reconstruir_ahora()
	var mm2: MultiMeshInstance3D = r.get_node_or_null("matas")
	_ok("R5 reconstruir da las mismas matas (sin parpadeo)", mm2 != null and mm2.multimesh.get_instance_transform(0).origin.is_equal_approx(antes))
	var c0: Color = mm.multimesh.get_instance_color(0)
	var c3: Color = mm.multimesh.get_instance_color(3)
	_ok("R6 el quemado es más oscuro que el cortado", c3.get_luminance() < c0.get_luminance() * 0.6, "cortado %.2f quemado %.2f" % [c0.get_luminance(), c3.get_luminance()])
	var cambios: int = r.numero()
	r.poner(Vector2i(3, 4), 1.0, Rastrojo3D.TIPO_QUEMADO)
	r.reconstruir_ahora()
	_ok("R7 volver a poner la misma casilla cambia el tipo sin duplicarla", r.numero() == cambios and r.tipo_de(Vector2i(3, 4)) == "quemado")
	r.quitar(Vector2i(3, 4))
	r.quitar(Vector2i(5, 4))
	r.reconstruir_ahora()
	_ok("R8 quitar las casillas deja el nodo vacío", r.numero() == 0 and r.n_matas() == 0)
	var malla: ArrayMesh = Rastrojo3D._malla_mata()
	var aabb: AABB = malla.get_aabb()
	_ok("R9 la mata es baja (menos de 20 cm) y estrecha (menos de 40 cm)", aabb.size.y > 0.03 and aabb.size.y < 0.20 and aabb.size.x < 0.40, str(aabb.size))
	r.free()


func _maqueta() -> void:
	var m: Node3D = (load("res://escenas/PruebaBosque.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 15:
		await process_frame
	var ras: Rastrojo3D = m.get("_rastrojo")
	_ok("S1 el Bosque monta el nodo de rastrojo", ras != null)
	var img: Image = m.get("_img_estado")
	var c := Vector2i(-1, -1)
	var lado: int = int(m.get("_lado"))
	for y in lado:
		for x in lado:
			if c.x < 0 and m._es_hierba(Vector2i(x, y)):
				c = Vector2i(x, y)
	_ok("S2 hay una casilla de hierba para probar", c.x >= 0)
	if ras == null or c.x < 0:
		m.queue_free()
		return
	m.marcar_segada(c, true)
	ras.reconstruir_ahora()
	_ok("S3 marcar_segada dibuja el rastrojo (cortado) y encoge la hierba (canal R = 1)", ras.hay(c) and ras.tipo_de(c) == "cortado" and img.get_pixel(c.x, c.y).r >= 0.99)
	m.call("_apagar", c)
	_ok("S4 apagar una casilla segada no la deja crecer otra vez", img.get_pixel(c.x, c.y).r >= 0.99)
	m.marcar_segada(c, false)
	_ok("S5 quitar la marca quita el rastrojo", not ras.hay(c))
	# La vía normal: el Juego pone el estado y la maqueta lo ve por la señal.
	Terreno3D.estados.cambio.emit(c, "segada", true)
	_ok("S6 la señal EstadosSuelo3D.cambio(«segada») llega a la maqueta", ras.hay(c))
	Terreno3D.estados.cambio.emit(c, "quemada", true)
	_ok("S7 otros estados no tocan el rastrojo", ras.numero() == 1)
	# Una casilla que ardió antes de segarse deja carbón.
	var c2: Vector2i = c + Vector2i(1, 0)
	if m._en_mapa(c2):
		m.call("_poner_canal", c2, 0, 1.0)
		m.marcar_segada(c2, true)
		_ok("S8 si la casilla ardió, el rastrojo es quemado", ras.tipo_de(c2) == "quemado")
	m.queue_free()
