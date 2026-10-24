extends SceneTree
## HORNEAR «BOSQUE 01 v01» (Juego, 24/10): genera mundo/datos_nivel/Nivel_Bosque_01_v01.tscn DESDE mapas/Bosque_01_v01.txt (decisión de Pablo del 24/10) y copia después los RETOQUES del
## Nivel_Bosque_01.tscn (que solo se LEE) en las zonas que no cambian.
##   godot --headless --path . --script res://herramientas/hornear_bosque_01_v01.gd
##
## PASO 1 · HORNEAR. Carga escenas/PruebaBosque01_v01.tscn con `usar_escena = false` (el nivel sale de las LETRAS del .txt; como en `escenario_hornear.gd`), le quita las reglas y los puzles
## (no hay .tscn que leer todavía) y llama a `hornear()`, que es lo que hace la tecla F9. Las líneas `; nombre`, `; marcador` y `; decorado` del .txt las pone HorneadorNivel.leer_extras
## (los marcadores salen con el NOMBRE que las reglas esperan: `totem_fuego_01`, `guerrero_05`, `npc_elfo_01`…).
## PASO 2 · RETOCAR. Un retoque de Pablo es lo que el .tscn viejo tiene distinto de lo que sale de hornear sus letras. Se copia, casilla a casilla, en toda casilla cuya letra NO cambia entre
## Bosque_01.txt y Bosque_01_v01.txt y que no es vecina de una que sí (así no se mezclan paredes viejas con regiones nuevas):
##   · las piezas (Piezas y Borde): las del .tscn viejo sustituyen a las recién horneadas de esa casilla (otro árbol, una roca movida, un cartel que Pablo puso…);
##   · el suelo del GridMap (el tipo de baldosa que Pablo pintó);
##   · el giro y la escala de los marcadores de letra que siguen en su casilla.
## Los marcadores con nombre y las casillas nuevas se quedan como salen del .txt. Lo que se copió sale en consola.
##
## CUIDADO, ESCRIBE EN EL REPO: pisa Nivel_Bosque_01_v01.tscn (si ya existía, HorneadorNivel lo aparta como `..._copia_<hora>.tscn`: se borra solo si lo creó esta ejecución y no tiene ediciones
## nuevas; con `-- conservar` queda). NUNCA toca Nivel_Bosque_01.tscn. No lo lances con Godot abierto sobre el proyecto.

const ESCENA: String = "res://escenas/PruebaBosque01_v01.tscn"
const NIVEL: String = "Bosque_01_v01"
const RUTA_NUEVO: String = "res://mundo/datos_nivel/Nivel_Bosque_01_v01.tscn"
const RUTA_VIEJO: String = "res://mundo/datos_nivel/Nivel_Bosque_01.tscn"
const MAPA_VIEJO: String = "res://mundo/datos_nivel/mapas/Bosque_01.txt"
const FOTOGRAMAS_ESPERA: int = 60
const PARED: String = "#"
const SIN_SUELO: String = " "
const CONTENEDORES: PackedStringArray = ["Piezas", "Borde"]

var _copias_antes: PackedStringArray = []


func _initialize() -> void:
	await process_frame
	_copias_antes = _copias()
	var ok: bool = await _hornear()
	if ok:
		_retocar()
	for f in _copias():
		if not _copias_antes.has(f) and not OS.get_cmdline_user_args().has("conservar"):
			print("  (se borra la copia que apartó el horneado: ", f, ")")
			DirAccess.remove_absolute(HorneadorNivel.NIVELES + f)
	quit(0 if ok else 1)


## Paso 1: lo que hace F9, sin reglas ni puzles.
func _hornear() -> bool:
	var ps: PackedScene = load(ESCENA) as PackedScene
	if ps == null:
		push_error("no carga " + ESCENA)
		return false
	var maqueta: Node = ps.instantiate()
	for n in ["Reglas", "Puzles"]:
		var h: Node = maqueta.get_node_or_null(n)
		if h != null:
			maqueta.remove_child(h)
			h.free()
	maqueta.set("usar_escena", false)
	root.add_child(maqueta)
	for _i in range(FOTOGRAMAS_ESPERA):
		await process_frame
	var ruta: String = String(maqueta.call("hornear"))
	print("PASO 1 · horneado: ", ruta if ruta != "" else "(nada: mira la consola)")
	maqueta.queue_free()
	await process_frame
	return ruta != ""


func _copias() -> PackedStringArray:
	var r: PackedStringArray = []
	var d: DirAccess = DirAccess.open(HorneadorNivel.NIVELES)
	if d != null:
		for f in d.get_files():
			if f.begins_with("Nivel_Bosque_01_v01_copia_"):
				r.append(f)
	r.sort()
	return r


## Filas de un mapa .txt (las que no son comentario), rellenas hasta el ancho máximo.
func _filas(ruta: String) -> PackedStringArray:
	var f := FileAccess.open(ruta, FileAccess.READ)
	var filas: PackedStringArray = []
	for linea in f.get_as_text().split("\n"):
		var l: String = String(linea).replace("\r", "")
		if l.strip_edges() == "" or l.begins_with(";"):
			continue
		filas.append(l)
	var ancho: int = 0
	for l in filas:
		ancho = maxi(ancho, l.length())
	for i in range(filas.size()):
		filas[i] = filas[i] + " ".repeat(ancho - filas[i].length())
	return filas


static func _letra(filas: PackedStringArray, c: Vector2i) -> String:
	if c.y < 0 or c.y >= filas.size() or c.x < 0 or c.x >= filas[c.y].length():
		return SIN_SUELO
	return filas[c.y][c.x]


static func _min_celda(suelo: GridMap) -> Vector2i:
	var mn := Vector2i(1 << 30, 1 << 30)
	for u in suelo.get_used_cells():
		mn = Vector2i(mini(mn.x, u.x), mini(mn.y, u.z))
	return mn


static func _celda_de(p: Vector3, mn: Vector2i) -> Vector2i:
	return Vector2i(int(floor(p.x / HorneadorNivel.S)), int(floor(p.z / HorneadorNivel.S))) - mn


## Las piezas (hijos de Piezas y Borde) de un nivel, por casilla: {Vector2i: [nodo]}.
static func _piezas_por_celda(raiz: Node, mn: Vector2i) -> Dictionary:
	var res: Dictionary = {}
	for nombre in CONTENEDORES:
		var cont: Node = raiz.get_node_or_null(nombre)
		if cont == null:
			continue
		for h in cont.get_children():
			if not (h is Node3D):
				continue
			var c: Vector2i = _celda_de((h as Node3D).position, mn)
			if not res.has(c):
				res[c] = []
			(res[c] as Array).append(h)
	return res


## Paso 2: copia los retoques del nivel viejo en las casillas que no cambian.
func _retocar() -> void:
	var viejo_ps: PackedScene = load(RUTA_VIEJO) as PackedScene
	var nuevo_ps: PackedScene = ResourceLoader.load(RUTA_NUEVO, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if viejo_ps == null or nuevo_ps == null:
		push_error("no se pueden cargar los dos niveles")
		return
	var viejo: Node = viejo_ps.instantiate()
	var nuevo: Node = nuevo_ps.instantiate()
	var suelo_v: GridMap = viejo.get_node("Suelo") as GridMap
	var suelo_n: GridMap = nuevo.get_node("Suelo") as GridMap
	var mn_v: Vector2i = _min_celda(suelo_v)
	var mn_n: Vector2i = _min_celda(suelo_n)
	var mapa_v: PackedStringArray = _filas(MAPA_VIEJO)
	var mapa_n: PackedStringArray = _filas(HorneadorNivel.ruta_mapa(NIVEL))
	var alto: int = maxi(mapa_v.size(), mapa_n.size())
	var ancho: int = maxi(mapa_v[0].length(), mapa_n[0].length())
	# Casillas que cambian y sus vecinas: ahí manda el horneado nuevo.
	var cercanas: Dictionary = {}
	var cambiadas: int = 0
	for y in range(alto):
		for x in range(ancho):
			var c := Vector2i(x, y)
			if _letra(mapa_v, c) != _letra(mapa_n, c):
				cambiadas += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						cercanas[c + Vector2i(dx, dy)] = true
	print("PASO 2 · retoques: %d casillas cambian (%d con sus vecinas); origen viejo %s, nuevo %s" % [cambiadas, cercanas.size(), str(mn_v), str(mn_n)])
	# --- piezas ---
	var viejas: Dictionary = _piezas_por_celda(viejo, mn_v)
	var nuevas: Dictionary = _piezas_por_celda(nuevo, mn_n)
	var celdas_pieza: int = 0
	var quitadas: int = 0
	var puestas: int = 0
	var sin_escena: int = 0
	for y in range(alto):
		for x in range(ancho):
			var c := Vector2i(x, y)
			if cercanas.has(c) or _letra(mapa_v, c) == SIN_SUELO:
				continue
			var antiguas: Array = viejas.get(c, [])
			var recientes: Array = nuevas.get(c, [])
			if antiguas.is_empty() and recientes.is_empty():
				continue
			celdas_pieza += 1
			for r in recientes:
				(r as Node).get_parent().remove_child(r as Node)
				(r as Node).free()
				quitadas += 1
			for a in antiguas:
				var an: Node3D = a as Node3D
				if String(an.scene_file_path) == "":
					sin_escena += 1
					continue
				var copia: Node3D = (load(an.scene_file_path) as PackedScene).instantiate() as Node3D
				copia.name = an.name
				copia.transform = an.transform
				if an.has_meta("bloquea"):
					copia.set_meta("bloquea", an.get_meta("bloquea"))
				var padre: Node = nuevo.get_node(String(an.get_parent().name))
				padre.add_child(copia, true)
				copia.owner = nuevo
				puestas += 1
	print("  piezas: %d casillas retocadas, %d horneadas quitadas, %d del nivel viejo copiadas (%d sin escena, saltadas)" % [celdas_pieza, quitadas, puestas, sin_escena])
	# --- suelo ---
	var suelo_cambiado: int = 0
	for u in suelo_v.get_used_cells():
		var c := Vector2i(u.x, u.z) - mn_v
		if cercanas.has(c) or _letra(mapa_n, c) == SIN_SUELO:
			continue
		var item_v: int = suelo_v.get_cell_item(u)
		var celda_n := Vector3i(c.x + mn_n.x, 0, c.y + mn_n.y)
		if suelo_n.get_cell_item(celda_n) != item_v:
			suelo_n.set_cell_item(celda_n, item_v)
			suelo_cambiado += 1
	print("  suelo: %d casillas pintadas como en el nivel viejo" % suelo_cambiado)
	# --- giro y escala de los marcadores de letra que siguen en su casilla ---
	var marc_v: Dictionary = {}
	for m in viejo.get_node("Marcadores").get_children():
		if m is Marcador3D and (m as Marcador3D).letra != "":
			marc_v[_celda_de((m as Node3D).position, mn_v)] = m
	var marc_cambiados: int = 0
	for m in nuevo.get_node("Marcadores").get_children():
		if not (m is Marcador3D) or (m as Marcador3D).letra == "":
			continue
		var c: Vector2i = _celda_de((m as Node3D).position, mn_n)
		if cercanas.has(c) or not marc_v.has(c) or (marc_v[c] as Marcador3D).letra != (m as Marcador3D).letra:
			continue
		var mv: Node3D = marc_v[c]
		if not mv.basis.is_equal_approx((m as Node3D).basis):
			(m as Node3D).basis = mv.basis
			marc_cambiados += 1
	print("  marcadores: %d con el giro/escala del nivel viejo" % marc_cambiados)
	nuevo.set_meta("retocado", "copiado de Nivel_Bosque_01.tscn: %d casillas con piezas, %d de suelo, %d marcadores" % [celdas_pieza, suelo_cambiado, marc_cambiados])
	var salida := PackedScene.new()
	var e: int = salida.pack(nuevo)
	viejo.free()
	nuevo.free()
	if e != OK:
		push_error("no se pudo empaquetar el nivel retocado (error %d)" % e)
		return
	e = ResourceSaver.save(salida, RUTA_NUEVO)
	print("  guardado ", RUTA_NUEVO, " (error %d)" % e)
