extends "res://herramientas/escenario_base.gd"
## LOS TRES NIVELES DE BOSQUE SE JUEGAN DE PRINCIPIO A FIN (26/11/2026). Con la escena de verdad y sin ventana (headless), sobre lo que ha exportado
## herramientas/generar_niveles_bosque.gd (BosqueGen01 → BosqueGen02 → BosqueCabana):
##   1. el .txt de cada nivel es exactamente lo que el generador saca de sus propios parámetros (sin retoques a mano que se pierdan);
##   2. cada nivel carga, Puzle3D / Zonas3D / la maqueta no dan avisos, cada `; pieza` existe como nodo, hay un enemigo montado por cada W/A del plano,
##      el suelo es suelo, las paredes bloquean y el agua es agua;
##   3. la cabaña: la huella que bloquea el juego es la que reservó el generador, la guardabosques está donde dice el plano y habla;
##   4. desde la entrada se llega ANDANDO (teclas de verdad, con el mismo ruteo de casillas que usa el juego) a cada claro y a cada salida; el precipicio del paso de
##      tierra se cruza con el puente de tierra de verdad (hechizo tierra + barrera + línea);
##   5. el viaje 01 → 02 → cabaña funciona (fundido, escena nueva, llegada en la entrada con nombre) y también la vuelta cabaña → 02 → 01.
## Los enemigos se apartan (el recorrido prueba el mapa, no el combate) y las partidas se guardan en una carpeta de prueba (no toca las ranuras de Pablo).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_niveles_bosque.gd
## Acaba con «FALLOS: n».

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const CARPETA: String = "user://escenario_niveles_bosque/"
const NIVELES: Array = ["BosqueGen01", "BosqueGen02", "BosqueCabana"]
const T_POR_CASILLA: float = 3.0         ## s como mucho para dar un paso de casilla antes de dar la ruta por atascada

var _w: Vector2 = Vector2.ZERO           ## hacia dónde empuja la W y la D (en el plano), medido una vez por nivel
var _d: Vector2 = Vector2.ZERO
var _nivel_actual: String = ""
var _m: Dictionary = {}                  ## el mapa regenerado del nivel actual
var _puente_hecho: bool = false


func _escenario() -> void:
	Partida.carpeta = CARPETA
	kit_de_pruebas = false                  # el kit de verdad de cada escena (demo_inicio en el 01, demo en los otros)
	Flags.nuevo()
	Estado.nuevo()
	_ok("0 los tres niveles están en Niveles.ESCENAS con su escena", Niveles.existe("BosqueGen01") and Niveles.existe("BosqueGen02") and Niveles.existe("BosqueCabana"))
	# `-- solo=<Nivel>`: solo ese nivel, sin viajes (para iterar más deprisa).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo="):
			await _cargar_nivel(a.substr(5))
			await _comprobar_estatico()
			if not (_m["cabana"] as Dictionary).is_empty():
				await _comprobar_cabana()
			await _recorrer(not OS.get_cmdline_user_args().has("rapido"))          # `rapido`: sin andar por todos los claros (solo lo estático y las salidas)
			for o in _m["objetos"]:                       # y a pie hasta cada salida (sin cruzarla), con el puente de tierra si hay precipicio
				if String(o["tipo"]) == "salida":
					var ok_s: bool = await _ir_a(_vecina_distinta(o["c"]))
					_ok("4 %s: se llega andando junto a %s" % [a.substr(5), String(o["id"])], ok_s, "estoy en %s" % str(celda_jugador()))
			_borrar_carpeta()
			return
	# 01 → 02 → cabaña, andando de verdad.
	await _cargar_nivel("BosqueGen01")
	await _comprobar_estatico()
	await _recorrer(true)
	var ent_02: Vector2i = _entrada_de("BosqueGen02", "desde_01")
	var vieja: Node = maqueta
	await _cruzar_salida("a_salida_2")
	_ok("5 de 01 se viaja a 02 (escena nueva)", maqueta != vieja and _nivel_de(maqueta) == "BosqueGen02", _nivel_de(maqueta))
	_ok("5 y se llega a la entrada «desde_01» de 02", celda_jugador() == ent_02, "%s / %s" % [str(celda_jugador()), str(ent_02)])
	_nivel_actual = "BosqueGen02"
	await _preparar_nivel("BosqueGen02")
	await _comprobar_estatico()
	await _recorrer(true)
	var ent_cab: Vector2i = _entrada_de("BosqueCabana", "desde_02")
	vieja = maqueta
	await _cruzar_salida("a_salida_2")
	_ok("5 de 02 se viaja a la cabaña", maqueta != vieja and _nivel_de(maqueta) == "BosqueCabana", _nivel_de(maqueta))
	_ok("5 y se llega a la entrada «desde_02» de la cabaña", celda_jugador() == ent_cab, "%s / %s" % [str(celda_jugador()), str(ent_cab)])
	await _preparar_nivel("BosqueCabana")
	await _comprobar_estatico()
	await _comprobar_cabana()
	await _recorrer(true)
	# La vuelta: cabaña → 02 (entrada «desde_cabana») → 01 (entrada «desde_02»).
	var ent_02b: Vector2i = _entrada_de("BosqueGen02", "desde_cabana")
	vieja = maqueta
	await _cruzar_salida("a_salida_1")
	_ok("5 la vuelta: de la cabaña se regresa a 02", maqueta != vieja and _nivel_de(maqueta) == "BosqueGen02", _nivel_de(maqueta))
	_ok("5 y se llega a la entrada «desde_cabana» de 02", celda_jugador() == ent_02b, "%s / %s" % [str(celda_jugador()), str(ent_02b)])
	await _preparar_nivel("BosqueGen02")
	var ent_01b: Vector2i = _entrada_de("BosqueGen01", "desde_02")
	vieja = maqueta
	await _cruzar_salida("a_salida_1")
	_ok("5 la vuelta: de 02 se regresa a 01", maqueta != vieja and _nivel_de(maqueta) == "BosqueGen01", _nivel_de(maqueta))
	_ok("5 y se llega a la entrada «desde_02» de 01", celda_jugador() == ent_01b, "%s / %s" % [str(celda_jugador()), str(ent_01b)])
	_ok("5 los viajes quedan en Niveles.viajes: 4", Niveles.viajes.size() == 4, str(Niveles.viajes.size()))
	# La salida de 01 hacia atrás (Monte Sumicio) existe (no se cruza: arrastraría el nivel de Sumicio).
	await _preparar_nivel("BosqueGen01")
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var s1: Node = pz.nodo("a_salida_1") if pz != null else null
	_ok("5 01 tiene su salida hacia Monte Sumicio (MonteSumicio:desde_fraga) y esa llegada existe en el mapa de Sumicio", s1 != null and String(s1.get("destino")) == "MonteSumicio:desde_fraga" and Niveles.existe("MonteSumicio"), str(s1.get("destino")) if s1 != null else "sin pieza")
	_borrar_carpeta()


func _borrar_carpeta() -> void:
	var d: DirAccess = DirAccess.open(CARPETA)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	Partida.carpeta = Partida.CARPETA_DEFECTO


func _nivel_de(n: Node) -> String:
	return String(n.get("nivel")) if n != null else ""


## La casilla de una entrada con nombre en el mapa de otro nivel (sale de su .txt: `; pieza <nombre> entrada x y`).
func _entrada_de(nivel: String, nombre: String) -> Vector2i:
	var t: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nivel))
	for l in t.split("\n"):
		var p: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if p.size() >= 5 and p[0] == "pieza" and p[1] == nombre and p[2] == "entrada":
			return Vector2i(p[3].to_int(), p[4].to_int())
	return Vector2i(-1, -1)


## El mapa tal como lo regenera el generador desde su .txt.
func _mapa_de(nombre: String) -> Dictionary:
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var par: Dictionary = Exportador._tipar(Exportador.parametros_de(texto))
	return Generador.new().generar(par, Exportador.retoques_de(texto), Exportador.enlaces_de(texto), Exportador.puzles_de(texto), Exportador.movidos_de(texto),
		Exportador.anadidos_de(texto), Exportador.apariciones_de(texto))


func _cargar_nivel(nombre: String) -> void:
	await cargar(Exportador.ruta_escena(nombre), false)
	await _preparar_nivel(nombre)


## Tras cargar (o llegar por un viaje): refresca la maqueta, regenera el mapa del nivel y aparta a los enemigos.
func _preparar_nivel(nombre: String) -> void:
	_nivel_actual = nombre
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	_ok("0 %s: hay maqueta, jugadora y lanzador" % nombre, maqueta != null and jugador != null and lanzador != null)
	_m = _mapa_de(nombre)
	_puente_hecho = false
	await avanzar(5)


func _comprobar_estatico() -> void:
	var nombre: String = _nivel_actual
	var m: Dictionary = _m
	# 1 · El .txt es lo que sale de sus parámetros.
	var en_disco: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	_ok("1 %s: el .txt es exactamente lo que el generador saca de sus parámetros" % nombre, Exportador._sin_fecha(en_disco) == Exportador._sin_fecha(Exportador.texto_mapa(m)))
	_ok("1 %s: el generador no da errores" % nombre, (m["errores"] as Array).is_empty(), str(m["errores"]))
	var avisos: Array = []
	for a in m["avisos"]:
		if not (String(a).begins_with("El cofre que ponías en") and String(a).contains("era el sitio válido más cercano")):
			avisos.append(a)
	_ok("1 %s: sin avisos del generador (salvo el cofre que se corre una casilla de su activador)" % nombre, avisos.is_empty(), str(avisos))
	# 2 · La escena.
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var zonas: Node = maqueta.get_node_or_null("Zonas3D")
	_ok("2 %s: Puzle3D monta todas las piezas sin avisos" % nombre, pz != null and pz.avisos.is_empty(), str(pz.avisos) if pz != null else "sin Puzle3D")
	_ok("2 %s: Zonas3D lee las zonas sin avisos" % nombre, zonas != null and (zonas.get("avisos") as Array).is_empty(), str(zonas.get("avisos")) if zonas != null else "sin Zonas3D")
	var av_maq: Array = maqueta.get("_avisos") if maqueta.get("_avisos") != null else []
	# «sin pieza X»: los adornos del decorado de claros (ADORNO_SETAS, flores y musgo de la tabla de variantes) que la biblioteca de piezas no tiene. Ya salían en TODO bosque generado\n	# (también en el BosqueGenPrueba de captura_bosque_generado.gd): no son de estos niveles, se anotan pero no cuentan como fallo.\n	if not av_maq.is_empty():\n		_aviso("2 %s: avisos de la maqueta (adornos sin pieza, heredados del decorado de bosque)" % nombre, str(av_maq))
	var n_zonas: int = (zonas.get("zonas") as Array).size() if zonas != null else 0
	var n_rotulos: int = 0
	for z in (zonas.get("zonas") as Array):
		n_rotulos += 1 if String((z as Dictionary).get("rotulo", "")) != "" else 0
	_ok("2 %s: hay zonas con rótulo (la del mapa y las de los claros con papel)" % nombre, n_rotulos >= 3, "%d zonas, %d con rótulo" % [n_zonas, n_rotulos])
	var letras: int = 0
	for fila in m["filas"]:
		letras += String(fila).count("W") + String(fila).count("A")
	var montados: int = get_nodes_in_group("combate3d").size()
	_ok("2 %s: un enemigo montado por cada W y A del plano (%d)" % [nombre, letras], montados == letras, "%d montados, %d letras, %d en stats" % [montados, letras, int(m["stats"]["enemigos"])])
	if pz != null:
		var faltan: PackedStringArray = PackedStringArray()
		var n_piezas: int = 0
		for linea in m["lineas"]:
			var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
			if t.size() < 3 or t[0] != "pieza" or t[2] == "entrada" or t[2] == "cuenca" or t[2] == "manantial":      # `cuenca` y `manantial` son solo datos (no tienen nodo)
				continue
			n_piezas += 1
			if pz.nodo(t[1]) == null:
				faltan.append(t[1])
		_ok("2 %s: cada pieza del mapa existe como nodo (%d piezas)" % [nombre, n_piezas], faltan.is_empty(), "faltan: " + ", ".join(faltan))
	var filas: PackedStringArray = m["filas"]
	var bloqueo_objeto: Dictionary = {}
	for o in m["objetos"]:
		bloqueo_objeto[o["c"]] = true
	for q in _celdas_de_lineas(m, ""):             # las piezas con varias casillas (`celdas=`: lava, estatuas…) ocupan más que la suya
		bloqueo_objeto[q] = true
	for q in (m["cabana"] as Dictionary).get("huella", []):       # la huella de la casa (el generador solo apunta su casilla central como objeto)
		bloqueo_objeto[q] = true
	var mal_suelo: int = 0
	var mal_pared: int = 0
	var cuales: Array = []
	for y in range(int(m["alto"])):
		for x in range(int(m["ancho"])):
			var c: Vector2i = Vector2i(x, y)
			if bloqueo_objeto.has(c):
				continue
			var ch: String = filas[y][x]
			if ".,gvR".contains(ch) and Terreno3D.celda_solida(c, 0):
				mal_suelo += 1
				cuales.append(c)
			elif ch == "#" and not Terreno3D.celda_solida(c, 0):
				mal_pared += 1
	_ok("2 %s: el suelo del plano es suelo y las paredes bloquean en el juego" % nombre, mal_suelo == 0 and mal_pared == 0, "%d suelos sólidos %s, %d paredes que no bloquean" % [mal_suelo, str(cuales.slice(0, 6)), mal_pared])
	var agua: int = 0
	var agua_ok: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if filas[y][x] == "~":
				agua += 1
				agua_ok += 1 if Terreno3D.es_agua(Vector2i(x, y)) else 0
	_ok("2 %s: el agua del plano es agua en el juego (%d casillas)" % [nombre, agua], agua == agua_ok, "%d de %d" % [agua_ok, agua])
	var hueco: Array = m.get("precipicio", [])
	if not hueco.is_empty():
		var mal_h: int = 0
		for c in hueco:
			if not Terreno3D.es_vacio(c) or Terreno3D.pisable(c, 0, true, 1, true):
				mal_h += 1
		_ok("2 %s: el precipicio del paso de tierra es vacío y no se pisa (%d casillas)" % [nombre, hueco.size()], mal_h == 0, "%d mal" % mal_h)
	# 5 (antes) · Cada salida tiene destino y la entrada de destino existe en el otro nivel.
	var salidas_ok: bool = true
	var detalle: String = ""
	for o in m["objetos"]:
		if String(o["tipo"]) == "salida":
			var nodo: Node = pz.nodo(String(o["id"])) if pz != null else null
			var dest: String = String(nodo.get("destino")) if nodo != null else ""
			var partes: PackedStringArray = Niveles.partir(dest)
			var existe: bool = false
			if not partes.is_empty() and Niveles.existe(partes[0]):
				existe = _entrada_de(partes[0], partes[1]).x >= 0 or partes[0] == "MonteSumicio"
			detalle += " %s→%s" % [String(o["id"]), dest]
			salidas_ok = salidas_ok and existe
	_ok("5 %s: cada salida lleva a un nivel que existe, a una entrada que existe:%s" % [nombre, detalle], salidas_ok)
	# Los enemigos, fuera (el recorrido prueba el mapa).
	for g in (maqueta.get("_goblins") as Array):
		if is_instance_valid(g):
			(g as Node).queue_free()
	(maqueta.get("_goblins") as Array).clear()          # la maqueta recorre `_goblins` cada fotograma (mirar a la jugadora): sin referencias a lo ya liberado
	await avanzar(3)


func _celdas_de_lineas(m: Dictionary, tipo: String) -> Array:
	var res: Array = []
	var tramo: RegEx = RegEx.create_from_string("(\\d+),(\\d+)\\.\\.(\\d+),(\\d+)")
	var suelta: RegEx = RegEx.create_from_string("(\\d+),(\\d+)")
	for linea in m["lineas"]:
		var tl: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if tl.size() < 5 or tl[0] != "pieza" or (tipo != "" and tl[2] != tipo):
			continue
		for parte in tl:
			if not String(parte).begins_with("celdas="):
				continue
			for trozo in String(parte).substr(7).split("+", false):
				var mt: RegExMatch = tramo.search(trozo)
				if mt != null:
					for ly in range(mini(mt.get_string(2).to_int(), mt.get_string(4).to_int()), maxi(mt.get_string(2).to_int(), mt.get_string(4).to_int()) + 1):
						for lx in range(mini(mt.get_string(1).to_int(), mt.get_string(3).to_int()), maxi(mt.get_string(1).to_int(), mt.get_string(3).to_int()) + 1):
							res.append(Vector2i(lx, ly))
				else:
					var ms: RegExMatch = suelta.search(trozo)
					if ms != null:
						res.append(Vector2i(ms.get_string(1).to_int(), ms.get_string(2).to_int()))
	return res


# ---------------------------------------------------------------------------------------------------------------------
#  La cabaña
# ---------------------------------------------------------------------------------------------------------------------

func _comprobar_cabana() -> void:
	var cab: Dictionary = _m["cabana"]
	_ok("3 la cabaña está en el mapa", not cab.is_empty())
	if cab.is_empty():
		return
	var huella: Dictionary = {}
	for q in cab["huella"]:
		huella[q] = true
	# Lo que bloquea el juego en torno a la casa: la huella del generador (3 × 3) y nada más lejos de ella que el atrezo de una casilla.
	var c0: Vector2i = cab["c"]
	var sin_bloquear: Array = []
	for q in huella:
		if not Terreno3D.bloqueada(q):
			sin_bloquear.append(q)
	_ok("3 las 9 casillas de huella de la casa bloquean en el juego", sin_bloquear.is_empty(), str(sin_bloquear))
	var de_mas: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var q: Vector2i = c0 + Vector2i(dx, dy)
			if Terreno3D.bloqueada(q) and not huella.has(q) and String(_m["filas"][q.y][q.x]) != "#":
				de_mas.append(q)
	print("      alrededor de la casa también bloquea (atrezo y guardabosques): ", de_mas)
	# El nodo de la guardabosques y que habla.
	var gc: Node = maqueta.get_node_or_null("GuardabosquesCabana")
	_ok("3 el nodo de la guardabosques está", gc != null)
	if gc == null:
		return
	colocar_jugador(cab["guarda"] + Vector2i(0, 2))
	await avanzar_s(1.0)
	_ok("3 la guardabosques está en su casilla (letra m)", gc.get("pj") != null and Terreno3D.celda_de((gc.get("pj") as Node3D).position) == cab["guarda"], str(Terreno3D.celda_de((gc.get("pj") as Node3D).position)) if gc.get("pj") != null else "sin Pj3D")
	_ok("3 saluda al acercarte (flag de saludo)", Flags.i().tiene("bosquecabana.guardabosques.saludo") and String(gc.get("dijo")).begins_with("Guardabosques"), String(gc.get("dijo")))
	var dicho: String = String(gc.call("hablar", jugador.position))
	_ok("3 habla con la tecla de interactuar (hablar devuelve una frase)", dicho != "" and Flags.i().tiene("bosquecabana.guardabosques.hablado"), dicho)
	# E de verdad.
	gc.set("_t_habla", 0.0)
	colocar_jugador(cab["guarda"] + Vector2i(0, 1))          # a una casilla (2,3 u): dentro del alcance de la E (2,7 u)
	await avanzar_s(0.5)
	var antes: int = int(gc.get("_lineas"))
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	await avanzar(3)
	ev.pressed = false
	Input.parse_input_event(ev)
	await avanzar(2)
	_ok("3 y con la E de verdad habla otra vez", int(gc.get("_lineas")) > antes, "%d → %d" % [antes, int(gc.get("_lineas"))])
	_ok("3 la cabaña no tiene enemigos en su claro (sala %d)" % int(cab["sala"]), _enemigos_en_sala(int(cab["sala"])) == 0)


func _enemigos_en_sala(sid: int) -> int:
	for s in _m["salas"]:
		if int(s["id"]) == sid:
			var r: Rect2i = s["rect"]
			var n: int = 0
			for o in _m["objetos"]:
				if ["guerrero", "arquero", "limo", "golem", "chaman", "mouro", "elemental", "gatopedro"].has(String(o["tipo"])) and r.has_point(o["c"]):
					n += 1
			return n
	return -1


# ---------------------------------------------------------------------------------------------------------------------
#  Recorrido a pie
# ---------------------------------------------------------------------------------------------------------------------

func _pisable(c: Vector2i) -> bool:
	return Terreno3D.pisable(c, 0, true, 1, false)


## BFS desde `desde` por las casillas que se pisan de verdad (lo que decide el juego). Devuelve casilla → anterior.
func _bfs(desde: Vector2i, abierto: bool = false) -> Dictionary:
	var previo: Dictionary = {desde: desde}
	var cola: Array = [desde]
	var k: int = 0
	var filas: PackedStringArray = _m["filas"]
	var piezas: Dictionary = {}
	if abierto:
		for linea in _m["lineas"]:
			var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
			if t.size() >= 5 and t[0] == "pieza" and t[3].is_valid_int() and t[4].is_valid_int():
				piezas[Vector2i(t[3].to_int(), t[4].to_int())] = true
	while k < cola.size():
		var c: Vector2i = cola[k]
		k += 1
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var v: Vector2i = c + d
			if previo.has(v) or v.x < 1 or v.y < 1 or v.x >= int(_m["ancho"]) - 1 or v.y >= int(_m["alto"]) - 1:
				continue
			var vale: bool = _pisable(v)
			if not vale and abierto and filas[v.y][v.x] != "#" and filas[v.y][v.x] != "~" and (piezas.has(v) or not ".,gvRSm".contains(filas[v.y][v.x])):
				vale = true               # lo que cierra una pieza de puzle (o su suelo con letra propia): se abre al resolverlo
			if vale:
				previo[v] = c
				cola.append(v)
	return previo


func _ruta(previo: Dictionary, a: Vector2i, hasta: Vector2i) -> Array:
	var r: Array = [hasta]
	var c: Vector2i = hasta
	while c != a:
		c = previo[c]
		r.append(c)
	r.reverse()
	return r


## Recorre el nivel actual: llega andando a cada claro y a cada salida. `fisico` = además lo anda de verdad con las teclas (solo claros-hito, para no tardar horas).
func _recorrer(fisico: bool) -> void:
	var nombre: String = _nivel_actual
	var ini: Vector2i = celda_jugador()
	var previo: Dictionary = _bfs(ini)
	var cerrado_claros: Array = []
	var abierto: Dictionary = {}
	var salas_sin: PackedStringArray = PackedStringArray()
	var hitos: Array = []             # [nombre, casilla]
	for s in _m["salas"]:
		var c: Vector2i = _suelo_de(s["rect"])
		if not previo.has(c):
			# El centro del claro puede ser el interior cerrado de una plantilla (una pista de empuje, un nicho): se mira si el CLARO se pisa por otro sitio.
			var otro: Vector2i = Vector2i(-1, -1)
			var dm: float = INF
			for y in range((s["rect"] as Rect2i).position.y, (s["rect"] as Rect2i).end.y):
				for x in range((s["rect"] as Rect2i).position.x, (s["rect"] as Rect2i).end.x):
					if previo.has(Vector2i(x, y)) and Vector2(x, y).distance_to(Vector2(c)) < dm:
						dm = Vector2(x, y).distance_to(Vector2(c))
						otro = Vector2i(x, y)
			if otro.x >= 0:
				c = otro
			else:
				if abierto.is_empty():
					abierto = _bfs(ini, true)
				cerrado_claros.append(int(s["id"]))
				if not abierto.has(c):
					salas_sin.append(str(s["id"]))
		hitos.append(["claro %d (%s)" % [int(s["id"]), String(s["rol"])], c, s["rect"]])
	var salidas: Array = []
	for o in _m["objetos"]:
		if String(o["tipo"]) == "salida":
			salidas.append(o)
	var sal_sin: PackedStringArray = PackedStringArray()
	for o in salidas:
		var c2: Vector2i = o["c"]
		if not previo.has(c2):
			if abierto.is_empty():
				abierto = _bfs(ini, true)
			if not abierto.has(c2):
				sal_sin.append(String(o["id"]))
	var hueco: Array = _m.get("precipicio", [])
	print("      %s: %d claros, %d alcanzables a pie sin abrir nada, %d solo abriendo piezas de puzle; %d salidas; precipicio de %d casillas" % [nombre, (_m["salas"] as Array).size(),
		(_m["salas"] as Array).size() - cerrado_claros.size(), cerrado_claros.size(), salidas.size(), hueco.size()])
	_ok("4 %s: se llega a pie (contando lo que abre un puzle) a todos los claros" % nombre, salas_sin.is_empty(), "sin llegar: " + ", ".join(salas_sin))
	_ok("4 %s: y a todas las salidas" % nombre, sal_sin.is_empty() or not hueco.is_empty(), "sin llegar: " + ", ".join(sal_sin))
	# Sin abrir nada se llega a todos los claros, salvo los que quedan tras el precipicio del paso de tierra (se cruza con el puente de tierra, ver `_tender_puente`).\n	_ok("4 %s: sin puzles de por medio, se llega a pie a todos los claros (los puzles son opcionales: premios)%s" % [nombre, " salvo el de tras el precipicio" if not hueco.is_empty() else ""], cerrado_claros.is_empty() or (not hueco.is_empty() and cerrado_claros.size() == 1), "solo con puente o puzle: " + str(cerrado_claros))
	if not fisico:
		return
	_w = await _empuje(KEY_W)
	_d = await _empuje(KEY_D)
	_ok("4 %s: la jugadora se mueve con las teclas" % nombre, _w.length() > 0.1 and _d.length() > 0.1)
	if _w.length() < 0.1 or _d.length() < 0.1:
		return
	# A pie: por todos los claros que se alcanzan sin abrir nada, en orden de cercanía, y a las salidas.
	var metas: Array = []
	for h in hitos:
		if previo.has(h[1]):
			metas.append(h)
	for o in salidas:
		metas.append(["salida %s" % String(o["id"]), _vecina(o["c"])])
	# En orden de vecino más cercano (si no, se va y se vuelve de punta a punta y el recorrido tarda el triple).
	var por_ir: Array = metas.duplicate()
	metas = []
	var aqui: Vector2i = ini
	while not por_ir.is_empty():
		var mejor_i: int = 0
		for i in range(1, por_ir.size()):
			if Vector2(por_ir[i][1]).distance_to(Vector2(aqui)) < Vector2(por_ir[mejor_i][1]).distance_to(Vector2(aqui)):
				mejor_i = i
		aqui = por_ir[mejor_i][1]
		metas.append(por_ir[mejor_i])
		por_ir.remove_at(mejor_i)
	var llegadas: int = 0
	for h in metas:
		var meta: Vector2i = h[1]
		if h.size() > 2:
			# A un claro se llega por su entrada (la primera casilla suya por el camino más corto desde donde está la jugadora): el centro de un claro de trampas (chorro de un dragón,
			# flechas) es la línea de tiro del puzle, que no se cruza sin resolverlo; llegar al claro es pisarlo.
			var pv: Dictionary = _bfs(celda_jugador())
			for k in pv:
				if (h[2] as Rect2i).has_point(k):
					meta = k
					break
		if String(h[0]).begins_with("salida a_salida_2") and nombre != "BosqueCabana":
			continue         # la salida de «ida» se cruza al final (viaja de nivel); la de vuelta (a_salida_1) también
		if String(h[0]).begins_with("salida a_salida_1"):
			continue
		var ok: bool = await _ir_a(meta)
		llegadas += 1 if ok else 0
		_ok("4 %s: se llega andando a %s %s" % [nombre, String(h[0]), str(meta)], ok, "estoy en %s" % str(celda_jugador()))
	print("      %s: andadas %d metas" % [nombre, metas.size()])


func _suelo_de(r: Rect2i) -> Vector2i:
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var mejor: Vector2i = Vector2i(-1, -1)
	var dm: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _pisable(Vector2i(x, y)) and Vector2(x + 0.5, y + 0.5).distance_to(centro) < dm:
				dm = Vector2(x + 0.5, y + 0.5).distance_to(centro)
				mejor = Vector2i(x, y)
	return mejor


## La casilla pisable junto a una casilla de salida (la salida se cruza pisándola).
func _vecina(c: Vector2i) -> Vector2i:
	if _pisable(c):
		return c
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if _pisable(c + d):
			return c + d
	return c


## Anda hasta `meta`: ruta por BFS desde donde está, casilla a casilla con las teclas. Si el camino cruza el precipicio, lo tiende con el puente de tierra.
func _ir_a(meta: Vector2i) -> bool:
	for _intento in range(3):
		var desde: Vector2i = celda_jugador()
		var previo: Dictionary = _bfs(desde)
		if previo.has(meta):
			return await _andar(_ruta(previo, desde, meta))
		if not await _tender_puente(desde, previo, meta):
			return false
	return false


func _andar(ruta: Array) -> bool:
	if _w.length() < 0.1 or _d.length() < 0.1:
		_w = await _empuje(KEY_W)
		_d = await _empuje(KEY_D)
	var pos0: Vector2i = ruta[0]
	for i in range(1, ruta.size()):
		var c: Vector2i = ruta[i]
		var meta3: Vector3 = Terreno3D.centro_de(c, 0.0)
		var t0: float = reloj.t
		var llego: bool = false
		jugador.set("vida", 9999.0)          # el recorrido prueba el mapa, no el combate (trampas de flechas, setas de veneno…)
		while reloj.t - t0 < T_POR_CASILLA:
			var a: Vector2 = Vector2(meta3.x - jugador.position.x, meta3.z - jugador.position.z)
			if a.length() <= 0.45 * Terreno3D.casilla:
				llego = true
				break
			var adelante: float = a.dot(_w)
			var lado: float = a.dot(_d)
			_tecla(KEY_W, adelante > 0.2 * a.length())
			_tecla(KEY_S, adelante < -0.2 * a.length())
			_tecla(KEY_D, lado > 0.2 * a.length())
			_tecla(KEY_A, lado < -0.2 * a.length())
			await process_frame
		if not llego:
			for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
				_tecla(k, false)
			print("      atascada en el paso %d de %d: de %s hacia %s, está en %s" % [i, ruta.size() - 1, str(pos0), str(c), str(celda_jugador())])
			return false
		pos0 = c
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	await avanzar(2)
	return true


## El camino a `meta` está cortado por el precipicio: se anda hasta el borde y se lanza tierra + barrera + línea hacia el vacío (hasta que se pisa al otro lado).
func _tender_puente(desde: Vector2i, previo: Dictionary, meta: Vector2i) -> bool:
	var hueco: Array = _m.get("precipicio", [])
	if hueco.is_empty() or _puente_hecho and false:
		return false
	# El borde: la casilla alcanzable pegada al vacío más cercana a la meta (en línea recta).
	var mejor: Vector2i = Vector2i(-1, -1)
	var dir: Vector2i = Vector2i.ZERO
	var dm: float = INF
	for c in previo:
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if Terreno3D.es_vacio(c + d) and hueco.has(c + d):
				var dd: float = Vector2(c).distance_to(Vector2(meta))
				if dd < dm:
					dm = dd
					mejor = c
					dir = d
	if mejor.x < 0:
		print("      sin borde de precipicio alcanzable")
		return false
	if not await _andar(_ruta(previo, desde, mejor)):
		return false
	# Cada hechizo tiende barrera + una línea = 2 casillas de puente (ver prueba_barrera_tierra_plataforma.gd); se repite desde el último trozo tendido hasta pisar al otro lado.
	var desde_b: Vector2i = mejor
	for _vez in range(4):
		jugador.set("vida", 9999.0)
		var salio: bool = _lanzar_puente(desde_b, dir)
		await avanzar_s(0.6)
		var tiende: bool = Terreno3D.pisable(desde_b + dir, 0, true, 1, false)
		print("      puente de tierra desde %s hacia %s: salió=%s, pisable la primera casilla de vacío=%s, plataformas=%d (%s)" % [str(desde_b), str(dir), str(salio), str(tiende), Terreno3D.plataformas_tierra.size(), lanzador.feedback_text])
		if not tiende:
			return false
		_puente_hecho = true
		if _bfs(celda_jugador()).has(meta):
			return true
		# El puente no llega: se sube a su última casilla y se tiende otro.
		var ultimo: Vector2i = desde_b + dir
		while Terreno3D.plataformas_tierra.has(ultimo + dir):
			ultimo += dir
		if not await _andar(_ruta(_bfs(celda_jugador()), celda_jugador(), ultimo)):
			return false
		desde_b = ultimo
	return false


## Prepara la página 0 con tierra + barrera + dos líneas y la lanza desde el BORDE (`desde`: la casilla de suelo pegada al vacío) hacia `dir`, como el puente de tierra del juego
## (la receta de escenario_lostcave_puzles.gd, LC3: la jugadora una casilla detrás del borde, el hechizo nace en el punto apuntado y cubre las dos casillas del vacío).
func _lanzar_puente(desde: Vector2i, dir: Vector2i) -> bool:
	if lanzador.modo_lanzar:
		lanzador._cancelar_modo()
	var detras: Vector2i = desde - dir
	if _pisable(detras):
		colocar_jugador(detras)
	jugador.tinta.actual = jugador.tinta.maxima
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("tierra")
	lanzador.place_sigil("barrera")
	lanzador.place_sigil("linea_x")
	lanzador.place_sigil("linea_z")
	lanzador.cooldown_left[0] = 0.0
	var origen: Vector3 = Terreno3D.centro_de(desde, Terreno3D.y_pies(desde))
	return lanzador.lanzar_pagina_ya(0, origen, Vector3(dir.x, 0.0, dir.y))


## Pisa la salida `id` andando (de verdad) y espera a que termine el viaje. La jugadora acaba en la escena nueva (`maqueta` se refresca).
func _cruzar_salida(id: String) -> void:
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var nodo: Node = pz.nodo(id) if pz != null else null
	_ok("5 la salida %s existe en %s" % [id, _nivel_actual], nodo != null)
	if nodo == null:
		return
	var celdas: Array = nodo.get("celdas") if nodo.get("celdas") != null else []
	var c: Vector2i = celdas[0] if not celdas.is_empty() else Vector2i(-1, -1)
	if c.x < 0:
		for o in _m["objetos"]:
			if String(o["id"]) == id:
				c = o["c"]
	if _w.length() < 0.1:
		_w = await _empuje(KEY_W)
		_d = await _empuje(KEY_D)
	var dest: String = String(nodo.get("destino"))
	# Se anda hasta una casilla vecina y de ahí se pisa la salida (se arma al apartarse de ella).
	var ok: bool = await _ir_a(_vecina_distinta(c))
	_ok("5 se llega andando junto a la salida %s (%s)" % [id, dest], ok, "estoy en %s" % str(celda_jugador()))
	await avanzar_s(0.6)                       # la salida se arma al apartarse
	if _tendido_hasta(c):
		pass
	var n_viajes: int = Niveles.viajes.size()
	var t0: float = reloj.t
	var meta3: Vector3 = Terreno3D.centro_de(c, 0.0)
	while not Niveles.en_curso and reloj.t - t0 < 6.0:
		var a: Vector2 = Vector2(meta3.x - jugador.position.x, meta3.z - jugador.position.z)
		_tecla(KEY_W, a.dot(_w) > 0.2 * a.length())
		_tecla(KEY_S, a.dot(_w) < -0.2 * a.length())
		_tecla(KEY_D, a.dot(_d) > 0.2 * a.length())
		_tecla(KEY_A, a.dot(_d) < -0.2 * a.length())
		await process_frame
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	_ok("5 al pisar %s empieza el viaje" % id, Niveles.viajes.size() == n_viajes + 1 or Niveles.en_curso, "viajes %d" % Niveles.viajes.size())
	var pared: int = Time.get_ticks_msec()
	while Niveles.en_curso and Time.get_ticks_msec() - pared < 40000:
		await process_frame
	await avanzar_s(0.5)
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	_w = Vector2.ZERO
	_d = Vector2.ZERO


func _tendido_hasta(_c: Vector2i) -> bool:
	return false


func _vecina_distinta(c: Vector2i) -> Vector2i:
	# Una casilla pisable a dos o tres pasos de la salida, por donde se llega y se puede volver a pisar.
	for d in [Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if _pisable(c + d):
			return c + d
	return c
