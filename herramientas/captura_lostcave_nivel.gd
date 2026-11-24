extends "res://herramientas/escenario_base.gd"

## CAPTURAS (24/11/2026) del NIVEL DE PRUEBA del pack Stylized Lost Cave (escenas/PruebaLostCave.tscn, mapa mundo/datos_nivel/mapas/LostCave.txt) con la escena de
## verdad y la cámara del juego. Hecho a partir de captura_mapa_provencal.gd. Comprueba que Puzle3D carga el mapa sin avisos, que están todas las piezas y que la
## solidez es la esperada (columnas, vagonetas y cristales cierran su casilla; arcos y losas se cruzan); luego una vista general desde arriba, una por sala desde
## arriba y una por sala con la cámara del juego y la jugadora dentro. Para MIRARLO. Necesita ventana (sin --headless) y las piezas generadas:
##   godot --path . --script res://herramientas/captura_lostcave_nivel.gd
## Escribe en arte/lostcave/capturas/nivel/ (fuera de git, como el pack).

const RUTA: String = "res://escenas/PruebaLostCave.tscn"
const MAPA: String = "res://mundo/datos_nivel/mapas/LostCave.txt"
const S: float = 2.3
const TAM_VENTANA: Vector2i = Vector2i(1600, 900)
const DIR: String = "res://arte/lostcave/capturas/nivel"
## Casillas que tienen que quedar cerradas (pieza sólida) y casillas que se tienen que poder pisar (arco, losas, paso libre).
const CERRADAS: Array = ["d_stonecolumn_a", "d_trolley_a", "d_crystal_blue_a", "d_totem_a", "d_stalagmite_a", "d_cart"]
const LIBRES: Array = ["d_arch", "d_largearch", "d_shrinearch", "d_stair_c", "d_minearch", "d_clover_cluster"]
## Arcos: casilla de una pata respecto al centro (la otra, la opuesta). El arco del cruce y el del santuario miran al sur (patas en X); el de la mina va girado.
const PATAS: Dictionary = {"d_arch": Vector2i(1, 0), "d_shrinearch": Vector2i(1, 0), "d_minearch": Vector2i(0, 1)}

var _dir: String = ""
var _piezas: Dictionary = {}       ## id de pieza -> Vector2i (casilla)
var _rects: Dictionary = {}        ## sala -> Rect2i
var _cam: Camera3D = null


func _escenario() -> void:
	_dir = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM_VENTANA
	_leer_mapa()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	var pz: Puzle3D = maqueta.get_node("Puzles") as Puzle3D
	var n_avisos: int = pz.avisos.size() if pz != null else -1
	_ok("1 Puzle3D carga el mapa sin avisos", n_avisos == 0, "%d avisos %s" % [n_avisos, str(pz.avisos.slice(0, 5)) if pz != null else ""])
	var puestas: int = 0
	var faltan: Array = []
	for id in _piezas.keys():
		if maqueta.find_child(String(id), true, false) != null:
			puestas += 1
		else:
			faltan.append(id)
	_ok("2 están todas las piezas colocadas", puestas == _piezas.size(), "%d de %d %s" % [puestas, _piezas.size(), str(faltan.slice(0, 6))])
	for id in CERRADAS:
		if _piezas.has(id):
			_ok("3 cierra su casilla: %s" % id, Terreno3D.bloqueada(_piezas[id]))
	for id in LIBRES:
		if _piezas.has(id):
			_ok("3 se pisa: %s" % id, not Terreno3D.bloqueada(_piezas[id]))
	# 24/11: las PATAS de los arcos cierran su casilla (antes se atravesaban); el centro, de arriba, sigue libre.
	for id in PATAS:
		if _piezas.has(id):
			var c0: Vector2i = _piezas[id]
			var lado: Vector2i = PATAS[id]
			_ok("3 las patas cierran su casilla: %s" % id, Terreno3D.bloqueada(c0 + lado) and Terreno3D.bloqueada(c0 - lado),
				"%s %s / %s %s" % [str(c0 + lado), str(Terreno3D.bloqueada(c0 + lado)), str(c0 - lado), str(Terreno3D.bloqueada(c0 - lado))])
	# 24/11: las paredes del pack (paredes_cueva = "lostcave") salen de los «#» (una roca por cada lado de muro que da a suelo).
	var rocas: int = 0
	for n in maqueta.find_children("*", "Node3D", true, false):
		var id_n: String = String((n as Node).get_meta("id", ""))
		if id_n.begins_with("lost_") and not _es_pieza_mapa(n):
			rocas += 1
	_ok("5 hay paredes del pack", rocas > 50, "%d rocas" % rocas)
	# Recorrido: desde la casilla de inicio, andando por casillas no bloqueadas, se llega al centro de cada sala.
	var inicio: Vector2i = Terreno3D.celda_de(jugador.global_position)
	var vistas: Dictionary = {inicio: true}
	var cola: Array = [inicio]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if not vistas.has(v) and v.x >= 0 and v.y >= 0 and v.x < 32 and v.y < 30 and not Terreno3D.bloqueada(v):
				vistas[v] = true
				cola.append(v)
	var plano: String = "plano de paso (o = se llega, x = cerrada, . = libre sin llegar):\n"
	for y in range(0, 24):
		for x in range(0, 32):
			var q := Vector2i(x, y)
			plano += "o" if vistas.has(q) else ("x" if Terreno3D.bloqueada(q) else ".")
		plano += "\n"
	print(plano)
	for sala in _rects.keys():
		var r0: Rect2i = _rects[sala]
		var llega: int = 0
		for y in range(r0.position.y, r0.end.y):
			for x in range(r0.position.x, r0.end.x):
				if vistas.has(Vector2i(x, y)):
					llega += 1
		_ok("4 se llega andando a %s" % sala, llega > 0, "%d casillas alcanzables desde %s" % [llega, str(inicio)])
	_cam = root.get_viewport().get_camera_3d()
	for cl in root.find_children("*", "CanvasLayer", true, false):       # sin HUD en las capturas
		(cl as CanvasLayer).visible = false
	await avanzar(30)
	_guardar("inicio.png")                 # lo primero que se ve al abrir el nivel (24/11: tiene que verse la salida de la boca)

	# --- vista general y una por sala desde arriba (cámara propia ortogonal a plomo; norte arriba) ---
	var arriba := Camera3D.new()
	arriba.projection = Camera3D.PROJECTION_ORTHOGONAL
	arriba.far = 400.0
	maqueta.add_child(arriba)
	var filas: int = 0
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		if l.strip_edges() != "" and not l.begins_with(";"):
			filas += 1
	await _arriba(arriba, Rect2i(0, 0, 32, filas), 2000, "nivel_general.png")
	for sala in _rects.keys():
		var r: Rect2i = _rects[sala]
		await _arriba(arriba, r.grow(1), 1600, "arriba_%s.png" % String(sala).to_lower())
	arriba.current = false
	_cam.current = true
	root.get_window().size = TAM_VENTANA
	arriba.queue_free()

	# --- una por sala con la cámara del juego y la jugadora en el centro (algo al sur, para ver la sala por delante de ella) ---
	for sala in _rects.keys():
		var r2: Rect2i = _rects[sala]
		_poner_jugadora(Vector2i(r2.position.x + r2.size.x / 2, r2.position.y + r2.size.y - 2))
		await avanzar(60)
		_guardar("juego_%s.png" % String(sala).to_lower())


## Foto desde arriba (norte arriba) del rectángulo de casillas `r`, con la ventana a `ancho_px` de ancho y el alto que toque.
func _arriba(cam: Camera3D, r: Rect2i, ancho_px: int, nombre: String) -> void:
	var alto_px: int = clampi(int(round(float(ancho_px) * float(r.size.y) / float(r.size.x))), 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro: Vector3 = Terreno3D.centro_de(r.position, 0.0) + Vector3(float(r.size.x - 1) * 0.5 * S, 0.0, float(r.size.y - 1) * 0.5 * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(25)
	_guardar(nombre)


## ¿Es una de las piezas que pone el mapa (`; pieza d_...`) y no una roca de pared de la maqueta?
func _es_pieza_mapa(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if _piezas.has(String(p.name)):
			return true
		p = p.get_parent()
	return false


func _poner_jugadora(c: Vector2i) -> void:
	jugador.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if "velocity" in jugador:
		jugador.set("velocity", Vector3.ZERO)


func _leer_mapa() -> void:
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		var p: PackedStringArray = l.split(" ")
		if l.begins_with("; pieza ") and p.size() >= 6:
			_piezas[p[2]] = Vector2i(int(p[4]), int(p[5]))
		elif l.begins_with("; rect ") and p.size() >= 7:
			_rects[p[2]] = Rect2i(int(p[3]), int(p[4]), int(p[5]), int(p[6]))


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura: ", _dir.path_join(nombre), " ", img.get_size())
