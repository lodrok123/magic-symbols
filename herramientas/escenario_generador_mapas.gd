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

var _nombre: String = ""


func _escenario() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var alg: String = args[0] if args.size() > 0 and Generador.ALGORITMOS.has(args[0]) else "salas"
	_nombre = "ZzGenPrueba" + alg.capitalize()
	_borrar()
	Flags.nuevo()
	Estado.nuevo()
	var m: Dictionary = Generador.new().generar({"algoritmo": alg, "semilla": 3, "nombre": _nombre, "salas_cerradas": 100, "charcas": 60})
	var antes_mapas: int = DirAccess.get_files_at(Exportador.DIR_MAPAS).size()
	var antes_escenas: int = DirAccess.get_files_at(Exportador.DIR_ESCENAS).size()
	var res: Dictionary = Exportador.exportar(m)
	_ok("1 exportar «%s» (%s) va bien" % [_nombre, alg], bool(res["ok"]), String(res["error"]))
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
			if ch == "." and Terreno3D.celda_solida(c, 0):
				mal_suelo += 1
			elif ch == "#" and not Terreno3D.celda_solida(c, 0):
				mal_pared += 1
	_ok("5 el suelo del plano es suelo en el juego", mal_suelo == 0, "%d casillas de suelo salen sólidas (de %d miradas)" % [mal_suelo, miradas])
	_ok("5 las paredes del plano bloquean en el juego", mal_pared == 0, "%d casillas de pared no bloquean" % mal_pared)
	_ok("5 el agua del plano es agua en el juego", _agua_bien(filas), "")
	maqueta.queue_free()
	await avanzar(5)
	_borrar()
	_ok("0 no queda ningún archivo de la prueba en el repo", Exportador.estado_destino(_nombre)["mapa"] == "" and Exportador.estado_destino(_nombre)["escena"] == "")


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
