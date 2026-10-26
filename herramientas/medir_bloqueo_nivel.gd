extends "res://herramientas/escenario_bosque_01_ramas.gd"
## MEDIDA (no es una prueba): qué casillas de Bosque 01 están bloqueadas y por qué cuerpo, si el jugador puede dar un paso desde
## INICIO en las cuatro direcciones y quién bloquea la casilla de la telaraña 03 antes y después de quemarla.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medir_bloqueo_nivel.gd -- <etiqueta>
## Escribe /tmp/bloqueo_<etiqueta>.json (para comparar dos copias del proyecto: hoy y con las colisiones del 19/10).

var _salida: Dictionary = {}


var _piezas: Array = []        ## [id, posición en el mundo]


func _cargar_piezas() -> void:
	_piezas.clear()
	var raiz: Node = (load("res://mundo/datos_nivel/Nivel_Bosque_01.tscn") as PackedScene).instantiate()
	var lista: Array = []
	maqueta.call("_piezas_de", raiz, lista)
	var desplaza: Vector3 = maqueta.get("_desplaza")
	for n in lista:
		var t: Transform3D = maqueta.call("_transform_en", n, raiz)
		_piezas.append([String(n.get_meta("id")), t.origin + desplaza])
	raiz.free()


## id de pieza del nivel más cercano (en planta) al cuerpo `b`
func _id_de_cuerpo(b: Node3D) -> String:
	if _piezas.is_empty():
		_cargar_piezas()
	var mejor: String = "?"
	var d_mejor: float = 0.1
	for e in _piezas:
		var o: Vector3 = e[1]
		var d: float = Vector2(o.x - b.position.x, o.z - b.position.z).length()
		if d < d_mejor:
			d_mejor = d
			mejor = "%s@%d,%d" % [String(e[0]), Terreno3D.celda_de(o).x, Terreno3D.celda_de(o).y]
	return mejor


## Los cuerpos sólidos (id de pieza) que tocan la casilla `c`, con la misma consulta que usa FuenteNodos.reconstruir.
func _cuerpos_en(c: Vector2i) -> Array:
	var espacio: PhysicsDirectSpaceState3D = maqueta.get_world_3d().direct_space_state
	var caja := BoxShape3D.new()
	caja.size = Vector3(Terreno3D.casilla * 0.9, 4.0, Terreno3D.casilla * 0.9)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = caja
	q.collision_mask = Terreno3D.CAPA_SOLIDO
	q.transform = Transform3D(Basis(), Terreno3D.centro_de(c, Terreno3D.alto_suelo + 2.0))
	var res: Array = []
	for h in espacio.intersect_shape(q, 32):
		var b: Node3D = h["collider"] as Node3D
		if b == null:
			continue
		var rotulo: String = _id_de_cuerpo(b)
		if not res.has(rotulo):
			res.append(rotulo)
	return res


func _escenario() -> void:
	await cargar(RUTA, true)
	reglas = maqueta.get_node_or_null("Reglas")
	pz = reglas.get("_puzles") as Puzle3D
	await avanzar(10)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).muerto = true
	var f: Variant = Terreno3D.fuente
	_salida["fuente"] = f.get_script().get_global_name() if f != null and f.get_script() != null else str(f)
	var lado: int = int(maqueta.get("_lado"))
	var celdas: Array = []
	var dic: Dictionary = maqueta.get("_bloqueadas")
	var muro: Dictionary = maqueta.get("_celdas_muro")
	var de_pieza: Dictionary = maqueta.get("_celdas_pieza")
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if Terreno3D.bloqueada(c):
				var nodos: bool = f != null and "celdas" in f and ((f.cubiertas as Dictionary).has(c) if "cubiertas" in f else (f.celdas as Dictionary).has(c))
				var extra: bool = f != null and "extras" in f and (f.extras as Dictionary).has(c)
				celdas.append({"c": [x, y], "nodos": nodos, "extra": extra, "dic": dic.has(c), "muro": muro.has(c), "pieza": de_pieza.has(c),
					"letra": Terreno3D.letra_de(c), "cuerpos": _cuerpos_en(c) if nodos else []})
	_salida["bloqueadas"] = celdas
	print("MEDIDA bloqueadas: ", celdas.size(), " (de ", lado * lado, ")  fuente=", _salida["fuente"])
	# --- 2. un paso desde INICIO en las cuatro direcciones
	colocar_jugador(INICIO)
	await avanzar_s(1.0)
	var pasos: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		colocar_jugador(INICIO)
		await avanzar(3)
		var destino: Vector3 = Terreno3D.centro_de(INICIO + d, Terreno3D.y_pies(INICIO + d))
		var origen: Vector3 = jugador.position
		var dir: Vector3 = (destino - origen)
		var cab: bool = bool(jugador.call("_puede_estar", origen + dir.normalized() * 0.4))     # un paso corto
		var cab_casilla: bool = bool(jugador.call("_puede_estar", destino))                   # la casilla vecina entera
		var c2: Vector2i = INICIO + d
		pasos.append({"dir": [d.x, d.y], "paso_corto": cab, "centro_vecina": cab_casilla, "vecina_bloqueada": Terreno3D.bloqueada(c2),
			"parcial": Terreno3D.es_parcial(c2), "choca_huella": Terreno3D.choca_huella(c2, destino), "pisable": Terreno3D.pisable(c2, 0, true, 3, false),
			"cuerpos": _cuerpos_en(c2), "letra": Terreno3D.letra_de(c2)})
	_salida["pasos_inicio"] = pasos
	for p in pasos:
		print("MEDIDA paso ", p)
	# con teclas de verdad: cuánto se desplaza el jugador en 0,6 s con cada tecla
	var teclas: Array = []
	for t in [KEY_W, KEY_A, KEY_S, KEY_D]:
		colocar_jugador(INICIO)
		await avanzar_s(0.5)
		var antes: Vector3 = jugador.position
		_tecla(t, true)
		await avanzar_s(0.6)
		_tecla(t, false)
		await avanzar(2)
		teclas.append({"tecla": OS.get_keycode_string(t), "desplazamiento": snappedf(Vector2(jugador.position.x - antes.x, jugador.position.z - antes.z).length(), 0.01)})
	_salida["teclas_inicio"] = teclas
	print("MEDIDA teclas ", teclas)
	# --- 2b. ¿llega a pie el JUGADOR (que solo choca con la forma real de lo parcial) a todos los marcadores? BFS por casillas:
	# una casilla bloqueada pero parcial se pisa si su centro no está dentro de la forma. (El BFS del escenario 3.1 usa casilla entera.)
	var llave: Dictionary = _celdas_llave()
	for modo in ["casilla entera (como 3.1)", "forma real (como el jugador)"]:
		var visto: Dictionary = {INICIO: 0}
		var cola: Array = [INICIO]
		while not cola.is_empty():
			var cc: Vector2i = cola.pop_front()
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nn: Vector2i = cc + dd
				if visto.has(nn):
					continue
				var libre: bool = llave.has(nn) or Terreno3D.pisable(nn, 0, false, 0, false)
				if not libre and modo.begins_with("forma"):
					var parc: bool = Terreno3D.es_parcial(nn)
					libre = parc and not Terreno3D.choca_huella(nn, Terreno3D.centro_de(nn, Terreno3D.y_pies(nn))) and Terreno3D.pisable(nn, 0, false, 0, false, true)
				if libre:
					visto[nn] = int(visto[cc]) + 1
					cola.append(nn)
		var fuera: Array = []
		for n in _marca().keys():
			var k: String = String(n)
			if k.begins_with("canal_"):
				continue
			var mc: Vector2i = _marca()[n]
			var cerca: bool = visto.has(mc)
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				cerca = cerca or visto.has(mc + dd)
			if not cerca:
				fuera.append("%s%s" % [k, str(mc)])
		_salida["alcance " + modo] = {"casillas": visto.size(), "marcadores_fuera": fuera, "visto": visto.keys().map(func(v): return [v.x, v.y])}
		print("MEDIDA alcance ", modo, ": ", visto.size(), " casillas; sin llegar a ", fuera.size(), " marcadores: ", fuera)
	# la flecha hacia la telaraña 03 desde el sur: ¿qué casillas del camino están bloqueadas?
	var c3b: Vector2i = _marca()["telarana_03"]
	var camino: Array = []
	for yy in range(c3b.y, c3b.y + 4):
		camino.append("(%d,%d)=%s" % [c3b.x, yy, str(Terreno3D.bloqueada(Vector2i(c3b.x, yy)))])
	_salida["camino_flecha"] = camino
	print("MEDIDA camino de la flecha (30,8)..(30,11): ", camino, "  linea_libre ", Terreno3D.linea_libre(Terreno3D.centro_de(c3b + Vector2i(0, 3), 1.0), Terreno3D.centro_de(c3b, 1.0)))
	# --- 3. telaraña 03
	var c3: Vector2i = _marca()["telarana_03"]
	var antes_t: Dictionary = {"c": [c3.x, c3.y], "bloqueada": Terreno3D.bloqueada(c3), "nodos": (f.celdas as Dictionary).has(c3) if f != null and "celdas" in f else false,
		"extra": (f.extras as Dictionary).has(c3) if f != null and "extras" in f else false, "dic": dic.has(c3), "cuerpos": _cuerpos_en(c3)}
	_salida["telarana_03_antes"] = antes_t
	print("MEDIDA telarana_03 antes ", antes_t)
	var ok_f: bool = await _fuego(c3, c3 + Vector2i(0, 3), ["flecha", "flecha"])
	await avanzar_s(8.0)
	var despues: Dictionary = {"flecha": ok_f, "c": [c3.x, c3.y], "bloqueada": Terreno3D.bloqueada(c3), "nodos": (f.celdas as Dictionary).has(c3) if f != null and "celdas" in f else false,
		"extra": (f.extras as Dictionary).has(c3) if f != null and "extras" in f else false, "dic": (maqueta.get("_bloqueadas") as Dictionary).has(c3), "cuerpos": _cuerpos_en(c3),
		"pieza": (maqueta.get("_celdas_pieza") as Dictionary).has(c3), "muro": (maqueta.get("_celdas_muro") as Dictionary).has(c3)}
	var vivos: Array = []
	for r in get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		var ro: Reactivo3D = r as Reactivo3D
		if ro != null and Terreno3D.celda_de(ro.global_position) == c3:
			vivos.append("%s@%s en_arbol=%s" % [ro.tipo, str(ro.global_position), str(ro.is_inside_tree())])
	despues["reactivos_en_la_casilla"] = vivos
	_salida["telarana_03_despues"] = despues
	print("MEDIDA telarana_03 despues ", despues)
	var etiqueta: String = "x"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		etiqueta = args[0]
	var fa := FileAccess.open("/tmp/bloqueo_%s.json" % etiqueta, FileAccess.WRITE)
	fa.store_string(JSON.stringify(_salida, "  "))
	fa.close()
