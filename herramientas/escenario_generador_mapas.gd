extends "res://herramientas/escenario_base.gd"
## UN MAPA GENERADO SE JUEGA (17/11/2026). Con la escena de verdad, sin ventana: exporta un nivel con el generador de mapas
## (herramientas/generador_mapas), lo carga en la maqueta como cualquier otro y comprueba que el juego lo entiende.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_generador_mapas.gd -- salas
## El último argumento elige el algoritmo (salas | cueva | pagina; sin él, salas). Hay que lanzarlo una vez por algoritmo.
## 1. Exportar escribe el .txt y la escena, y solo esos dos archivos.
## 2. La escena carga y monta jugadora, Lanzador3D y agua; la jugadora nace en la S del mapa.
## 3. Puzle3D y Zonas3D leen todas las líneas del mapa sin un solo aviso (puerta con llave, cofres, vigías, cerrojos, jarrones, braseros, entrada).
## 4. Hay tantos enemigos montados como letras W y A tiene el plano, y cada pieza del mapa existe como nodo.
## 5. El suelo que el generador da por pisable lo es en el juego (Terreno3D) y las paredes bloquean.
## 6. Volver a exportar el mismo mapa no deja copias; exportarlo tras retocar el .txt a mano sí guarda una.
## Al acabar BORRA los archivos que escribió (el nivel se llama ZzGenPrueba<Algoritmo>): no deja nada en el repo.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const CamaraSalas = preload("res://presentacion/camara_salas.gd")

var _nombre: String = ""


func _escenario() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var alg: String = args[0] if args.size() > 0 and Generador.ALGORITMOS.has(args[0]) else "salas"
	_nombre = "ZzGenPrueba" + alg.capitalize()
	_borrar()
	Flags.nuevo()
	Estado.nuevo()
	var par: Dictionary = {"algoritmo": alg, "semilla": 3, "nombre": _nombre, "salas_cerradas": 100, "charcas": 60, "barreras": 4, "puzles": 4, "salida_a": "Cueva:desde_bosque, Bosque_02:boca_cueva"}
	if alg == "bosque":
		# 24/11: la forma del Bosque 01 de Pablo, con el paso de tierra (precipicio) en la salida 2.
		par.merge({"ancho": 48, "alto": 42, "salida_a": "CuevaTerrafina:a_bosque=desde_cueva, Precipicio:inicio, Ruinas:inicio, Bosque_02:desde_bosque01",
			"lados_salida": "s, o, s, e", "paso_tierra": 2, "estilo": "bosque", "luz": "bosque", "salas_cerradas": 0}, true)
	var m: Dictionary = Generador.new().generar(par)
	var antes_mapas: int = DirAccess.get_files_at(Exportador.DIR_MAPAS).size()
	var antes_escenas: int = DirAccess.get_files_at(Exportador.DIR_ESCENAS).size()
	var res: Dictionary = Exportador.exportar(m)
	_ok("1 exportar «%s» (%s) va bien, con %d barreras y puzles %s" % [_nombre, alg, int(m["barreras"]), str((m["puzles"] as Dictionary).values())], bool(res["ok"]), String(res["error"]))
	if not bool(res["ok"]):
		return
	_ok("1 escribe el .txt y la escena, y nada más", (res["escritos"] as Array).size() == 2 and String(res["copia"]) == ""
		and DirAccess.get_files_at(Exportador.DIR_MAPAS).size() == antes_mapas + 1 and DirAccess.get_files_at(Exportador.DIR_ESCENAS).size() == antes_escenas + 1, str(res["escritos"]))
	# 6 · Reexportar lo mismo: sin copia. Retocado a mano: con copia.
	var res2: Dictionary = Exportador.exportar(m)
	_ok("6 volver a exportar el mismo mapa no deja copia", bool(res2["ok"]) and String(res2["copia"]) == "", str(res2))
	var ruta: String = Exportador.ruta_mapa(_nombre)
	var original: String = FileAccess.get_file_as_string(ruta)
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(original + "; pieza jarron_a_mano jarron 2 2\n")
	f.close()
	var res3: Dictionary = Exportador.exportar(m)
	_ok("6 exportar sobre un .txt retocado a mano guarda antes una copia", bool(res3["ok"]) and String(res3["copia"]) != ""
		and FileAccess.get_file_as_string(String(res3["copia"])).contains("jarron_a_mano"), str(res3))
	_ok("6 y el archivo vuelve a ser el generado", FileAccess.get_file_as_string(ruta) == original)
	# 2 · La escena de verdad.
	await cargar(Exportador.ruta_escena(_nombre), true)
	if maqueta == null or jugador == null:
		_borrar()
		return
	await avanzar(20)
	var ini: Vector2i = m["inicio"]
	_ok("2 la jugadora nace en la S del mapa", celda_jugador() == ini, "está en %s y la S en %s" % [celda_jugador(), ini])
	# 3 · Sin avisos.
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var zonas: Node = maqueta.get_node_or_null("Zonas3D")
	_ok("3 Puzle3D monta todas las piezas sin avisos", pz != null and pz.avisos.is_empty(), str(pz.avisos) if pz != null else "sin Puzle3D")
	_ok("3 Zonas3D lee la zona sin avisos", zonas != null and (zonas.get("avisos") as Array).is_empty(), str(zonas.get("avisos")) if zonas != null else "sin Zonas3D")
	# 4 · Enemigos y piezas.
	var letras: int = 0
	for fila in m["filas"]:
		letras += String(fila).count("W") + String(fila).count("A")
	var montados: int = get_nodes_in_group("combate3d").size()
	_ok("4 hay un enemigo montado por cada W y A del plano", montados == letras and letras == int(m["stats"]["enemigos"]), "%d montados, %d letras" % [montados, letras])
	if pz != null:
		var faltan: PackedStringArray = PackedStringArray()
		var n_piezas: int = 0
		for linea in m["lineas"]:
			var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
			if t[0] != "pieza" or t[2] == "entrada":
				continue
			n_piezas += 1
			if pz.nodo(t[1]) == null:
				faltan.append(t[1])
		_ok("4 cada pieza del mapa existe como nodo (%d piezas)" % n_piezas, faltan.is_empty(), "faltan: " + ", ".join(faltan))
	# 5 · Lo pisable se pisa y las paredes bloquean.
	var filas: PackedStringArray = m["filas"]
	var bloqueo_objeto: Dictionary = {}
	for o in m["objetos"]:
		bloqueo_objeto[o["c"]] = true
	var mal_suelo: int = 0
	var mal_pared: int = 0
	var miradas: int = 0
	for y in range(int(m["alto"])):
		for x in range(int(m["ancho"])):
			var c: Vector2i = Vector2i(x, y)
			if bloqueo_objeto.has(c):
				continue
			var ch: String = filas[y][x]
			miradas += 1
			if ".gR".contains(ch) and Terreno3D.celda_solida(c, 0):       # suelo, tierra pisada o losas: todo se pisa
				mal_suelo += 1
			elif ch == "#" and not Terreno3D.celda_solida(c, 0):
				mal_pared += 1
	_ok("5 el suelo del plano es suelo en el juego", mal_suelo == 0, "%d casillas de suelo salen sólidas (de %d miradas)" % [mal_suelo, miradas])
	_ok("5 las paredes del plano bloquean en el juego", mal_pared == 0, "%d casillas de pared no bloquean" % mal_pared)
	_ok("5 el agua del plano es agua en el juego", _agua_bien(filas), "")
	# 5b · El precipicio del paso de tierra (bosque): en el juego es vacío y no se pisa.
	var hueco: Array = m.get("precipicio", [])
	if alg == "bosque":
		var mal_hueco: int = 0
		for c in hueco:
			if not Terreno3D.es_vacio(c) or Terreno3D.pisable(c, 0, true, 1, true):
				mal_hueco += 1
		_ok("5 el precipicio del paso de tierra es vacío y no se pisa en el juego (%d casillas)" % hueco.size(), not hueco.is_empty() and mal_hueco == 0, "%d mal" % mal_hueco)
	# 5c · Su aspecto (Precipicio3D): paredes y fondo en el mapa con precipicio; nada en los demás.
	var pr: Precipicio3D = maqueta.get_node_or_null("Precipicio") as Precipicio3D
	if hueco.is_empty():
		_ok("5 sin precipicio la maqueta no monta paredes de precipicio", pr == null)
	else:
		_ok("5 la maqueta monta las paredes y el fondo del precipicio", pr != null and pr.n_caras > 0 and pr.n_huecos == hueco.size(),
			"%d caras, %d huecos" % [pr.n_caras, pr.n_huecos] if pr != null else "sin nodo")
	await _camara_por_sala(m)
	maqueta.queue_free()
	await avanzar(5)
	_borrar()
	_ok("0 no queda ningún archivo de la prueba en el repo", Exportador.estado_destino(_nombre)["mapa"] == "" and Exportador.estado_destino(_nombre)["escena"] == "")


## 7 · Cámara por sala (20/11): la maqueta lee las salas de cámara; en la sala más pequeña el encuadre no se sale de ella y el zoom
## baja al que cabe; al pasar de la sala más grande a la más pequeña (sin teletransporte de cámara) el zoom baja POCO A POCO, sin
## saltos, y la jugadora se ve entera en todos los fotogramas.
func _camara_por_sala(m: Dictionary) -> void:
	var cam_salas: Array = m["salas_camara"]
	get_root().size = Vector2i(1280, 720)      # sin ventana el visor es cuadrado; el juego va en 16:9
	await avanzar(2)
	_ok("7 la escena enciende la cámara por sala", bool(maqueta.get("camara_por_sala")))
	_ok("7 la maqueta lee las salas de cámara del mapa", (maqueta.get("_salas_camara") as Array).size() == cam_salas.size(), "%d de %d" % [(maqueta.get("_salas_camara") as Array).size(), cam_salas.size()])
	var camara: Camera3D = maqueta.get("_camara") as Camera3D
	var pedido: float = float(maqueta.get("_tam_camara"))
	if cam_salas.is_empty():
		await avanzar(10)
		_ok("7 sin salas (cueva) el zoom es el pedido", absf(camara.size - pedido) < 0.01, "%.2f / %.2f" % [camara.size, pedido])
		return
	var chica: int = 0
	var grande: int = 0
	for i in range(cam_salas.size()):
		var a: int = (cam_salas[i] as Rect2i).get_area()
		if a < (cam_salas[chica] as Rect2i).get_area():
			chica = i
		if a > (cam_salas[grande] as Rect2i).get_area():
			grande = i
	var celda_chica: Vector2i = _suelo_cerca(m, cam_salas[chica])
	var celda_grande: Vector2i = _suelo_cerca(m, cam_salas[grande])
	# La más grande, de golpe (teletransporte).
	maqueta.call("ir_a", celda_grande)
	colocar_jugador(celda_grande)
	await avanzar_s(2.5)
	var z_grande: float = camara.size
	# A la pequeña sin teletransporte de cámara: el zoom tiene que bajar poco a poco.
	colocar_jugador(celda_chica)
	var cambios: Array = []
	var fuera: int = 0
	var anterior: float = camara.size
	var t0: float = reloj.t
	while reloj.t - t0 < 4.0:
		await process_frame
		cambios.append(camara.size - anterior)
		anterior = camara.size
		if not _jugadora_en_pantalla(camara):
			fuera += 1
	var objetivo: float = minf(pedido, maxf(CamaraSalas.ZOOM_MINIMO_SALA, float(CamaraSalas.zoom_que_cabe(camara_tam(camara, pedido), _rect_mundo(cam_salas[chica])))))
	camara.size = anterior
	var max_salto: float = 0.0
	for d in cambios:
		max_salto = maxf(max_salto, absf(float(d)))
	print("      cámara: sala grande %s zoom %.2f · sala pequeña %s zoom %.2f (objetivo %.2f) · máximo cambio por fotograma %.3f" % [cam_salas[grande], z_grande, cam_salas[chica], camara.size, objetivo, max_salto])
	_ok("7 en la sala pequeña el zoom llega al que cabe", absf(camara.size - objetivo) < 0.05, "%.2f / %.2f" % [camara.size, objetivo])
	if absf(z_grande - objetivo) > 0.3:
		_ok("7 el zoom cambia poco a poco (ningún fotograma cambia más de 0,15)", max_salto < 0.15, "%.3f" % max_salto)
		_ok("7 y tarda: a los 5 fotogramas aún no ha llegado", cambios.size() > 5 and absf(z_grande + _suma(cambios, 5) - objetivo) > 0.1)
	else:
		_aviso("7 las dos salas piden casi el mismo zoom: no se mide lo gradual", "%.2f / %.2f" % [z_grande, objetivo])
	_ok("7 la jugadora se ve entera en todos los fotogramas", fuera == 0, "%d fotogramas con parte fuera" % fuera)
	# El encuadre no se sale de la sala (con su margen) una vez asentado.
	var alto_suelo: float = float(maqueta.get_script().get_script_constant_map()["ALTO"])
	var vista: Rect2 = CamaraSalas.huella(camara, alto_suelo)
	var centro: Variant = Plane(Vector3.UP, alto_suelo).intersects_ray(camara.project_ray_origin(camara.get_viewport().get_visible_rect().size * 0.5), camara.project_ray_normal(camara.get_viewport().get_visible_rect().size * 0.5))
	var limite: Rect2 = CamaraSalas.rect_sala(cam_salas[chica], 2.3, Rect2(Vector2.ZERO, Vector2(int(m["ancho"]), int(m["alto"])) * 2.3).grow(-0.15))
	var en_suelo: Rect2 = Rect2(vista.position + Vector2((centro as Vector3).x, (centro as Vector3).z), vista.size)
	# Por eje: donde la sala cabe, el encuadre queda dentro; donde no (sala más pequeña que el zoom mínimo), centrado en ella.
	var bien: bool = true
	for eje in [0, 1]:
		var l0: float = limite.position[eje]
		var l1: float = limite.end[eje]
		var v0: float = en_suelo.position[eje]
		var v1: float = en_suelo.end[eje]
		if l1 - l0 >= v1 - v0 - 0.05:
			bien = bien and v0 >= l0 - 0.3 and v1 <= l1 + 0.3
		else:
			bien = bien and v0 <= l0 + 0.3 and v1 >= l1 - 0.3      # se ve la sala entera en ese eje
	_ok("7 el encuadre no enseña lo que hay fuera de la sala (o se centra en ella si no cabe)", bien, "%s en %s" % [en_suelo, limite])


func camara_tam(camara: Camera3D, tam: float) -> Camera3D:
	camara.size = tam
	return camara


func _rect_mundo(r: Rect2i) -> Rect2:
	return CamaraSalas.rect_sala(r, 2.3, Rect2(-Vector2.ONE * 1.0e4, Vector2.ONE * 2.0e4))


func _suma(a: Array, n: int) -> float:
	var s: float = 0.0
	for i in range(mini(n, a.size())):
		s += float(a[i])
	return s


## Una casilla de suelo de la sala, lo más cerca de su centro.
func _suelo_cerca(m: Dictionary, r: Rect2i) -> Vector2i:
	var filas: PackedStringArray = m["filas"]
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var mejor: Vector2i = r.position
	var d_mejor: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if ".gR".contains(filas[y][x]) and Vector2(x + 0.5, y + 0.5).distance_to(centro) < d_mejor:
				d_mejor = Vector2(x + 0.5, y + 0.5).distance_to(centro)
				mejor = Vector2i(x, y)
	return mejor


func _jugadora_en_pantalla(camara: Camera3D) -> bool:
	var pj: Node3D = maqueta.get("_jugador") as Node3D
	var tam: Vector2 = camara.get_viewport().get_visible_rect().size
	var alto: float = float(pj.call("alto_modelo")) * pj.scale.y
	for p in [pj.position, pj.position + Vector3(0.0, alto, 0.0)]:
		var s: Vector2 = camara.unproject_position(p)
		if s.x < 0.0 or s.y < 0.0 or s.x > tam.x or s.y > tam.y:
			return false
	return true


func _agua_bien(filas: PackedStringArray) -> bool:
	var agua: int = 0
	var bien: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if filas[y][x] == "~":
				agua += 1
				if Terreno3D.es_agua(Vector2i(x, y)):
					bien += 1
	print("      agua: %d de %d casillas" % [bien, agua])
	return agua == bien


func _borrar() -> void:
	for carpeta in [Exportador.DIR_MAPAS, Exportador.DIR_ESCENAS]:
		for f in DirAccess.get_files_at(carpeta):
			if f.begins_with(_nombre) or f.begins_with("Prueba" + _nombre):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(carpeta + f))
