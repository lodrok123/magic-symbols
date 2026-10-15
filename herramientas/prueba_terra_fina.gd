extends SceneTree
## Terra Fina (14/10): el mapa del tutorial es válido y sus reglas hacen lo que dicen, sobre una maqueta falsa.
##   1) el mapa mide 19×30, solo lleva letras conocidas y tiene S, E, 2 C y los H esperados;
##   2) sin quemar el seto z NO se llega a los gatopedros ni a la salida; quemándolo SÍ (búsqueda en anchura);
##   3) las reglas ponen el titán (pies en su fila, sin colisión), una casa por H (bloqueando), dos gatopedros y el sello;
##   4) la salida se abre al caer el SEGUNDO gatopedro y no antes; un muerto que no es gatopedro no cuenta.
## Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_terra_fina.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	var _mapa: PackedStringArray = []
	var _lado: int = 30
	var _ancho: int = 19
	var _alto: int = 30
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _goblins: Array = []
	var _props: Node3D = null
	var _jugador: Pj3D = null
	var liberadas: Array[Vector2i] = []
	func _centro_celda(c: Vector2i, y: float) -> Vector3:
		return Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
	func _pos_marca(c: Vector2i, y: float) -> Vector3:
		return _centro_celda(c, y)
	func _celda_de(p: Vector3) -> Vector2i:
		return Vector2i(int(floor(p.x / S)), int(floor(p.z / S)))
	func _liberar(c: Vector2i) -> void:
		liberadas.append(c)
		_bloqueadas.erase(c)
	func _personaje(_ids: Array, pos: Vector3) -> Pj3D:
		var p := Pj3D.new()
		p.position = pos
		add_child(p)
		return p
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var tam: Array = []
	var mapa: PackedStringArray = HorneadorNivel.leer_mapa("TerraFina", tam)
	_mapa_valido(mapa, tam)
	_alcance(mapa)
	await _reglas(mapa)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _caja_total(t: Titan3D) -> AABB:
	var total := AABB()
	var primero: bool = true
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
		var p: Node = mi.get_parent()
		while p != null and p != t:
			a = (p as Node3D).transform * a
			p = p.get_parent()
		total = a if primero else total.merge(a)
		primero = false
	return total


func _cuenta(mapa: PackedStringArray, l: String) -> int:
	var n: int = 0
	for f in mapa:
		n += f.count(l)
	return n


func _mapa_valido(mapa: PackedStringArray, tam: Array) -> void:
	_ok("1 el mapa mide 19×30", tam == [19, 30], str(tam))
	var conocidas: String = HorneadorNivel.LETRAS_SUELO + "SCHETDzb"
	var raras: String = ""
	for f in mapa:
		for ch in f:
			if ch != " " and not conocidas.contains(ch) and not Marcador3D.LETRAS.has(ch):
				raras += ch
	_ok("1 solo letras conocidas", raras == "", "raras: «%s»" % raras)
	_ok("1 una S, una E, dos C, 15 casas H", _cuenta(mapa, "S") == 1 and _cuenta(mapa, "E") == 1 and _cuenta(mapa, "C") == 2 and _cuenta(mapa, "H") == 15,
		"S%d E%d C%d H%d" % [_cuenta(mapa, "S"), _cuenta(mapa, "E"), _cuenta(mapa, "C"), _cuenta(mapa, "H")])
	_ok("1 el azar de suelo no toca las letras (sigue habiendo 3 setos, 2 braseros)", _cuenta(mapa, "z") == 3 and _cuenta(mapa, "T") == 2)


func _alcance(mapa: PackedStringArray) -> void:
	# Se camina por casillas y se SUBE saltando un nivel (como Jugador3D con tope 2); bajar es gratis. Las alturas salen del propio mapa.
	var alturas: Dictionary = {}
	for r in TerraFina3D.leer_alturas("TerraFina"):
		for y in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				alturas[Vector2i(x, y)] = maxi(int(alturas.get(Vector2i(x, y), 0)), int(r[4]))
	var inicio := Vector2i(-1, -1)
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "S":
				inicio = Vector2i(x, y)
	for quemando in [false, true]:
		var vistas: Dictionary = {inicio: true}
		var cola: Array[Vector2i] = [inicio]
		while not cola.is_empty():
			var c: Vector2i = cola.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if n.y < 0 or n.y >= mapa.size() or n.x < 0 or n.x >= mapa[n.y].length() or vistas.has(n):
					continue
				var l: String = mapa[n.y][n.x]
				if l in ["#", "H", "T", "D", "~", " "] or (l == "z" and not quemando):
					continue
				if int(alturas.get(n, 0)) > int(alturas.get(c, 0)) + 1 or int(alturas.get(n, 0)) > 2:
					continue
				vistas[n] = true
				cola.append(n)
		var llega: int = 0
		for y in range(mapa.size()):
			for x in range(mapa[y].length()):
				if mapa[y][x] in ["C", "E"] and vistas.has(Vector2i(x, y)):
					llega += 1
		if quemando:
			_ok("2 quemando el seto se llega a los dos gatopedros y a la salida (subiendo de nivel en nivel)", llega == 3, "llegan %d de 3" % llega)
		else:
			_ok("2 sin quemar el seto NO se llega a ninguno (el fuego es obligatorio)", llega == 0, "llegan %d de 3" % llega)
	_ok("2 tres alturas: 0, 1 y 2", alturas.values().has(1) and alturas.values().has(2) and not alturas.values().has(3))
	# Sin el salto del muro de la fila 8 (si el tope fuera 1) no se llegaría al pecho: la altura 2 exige tope 2.
	_ok("2 el pecho (altura 2) no se alcanza desde los pies de un salto", int(alturas.get(Vector2i(9, 4), 0)) == 2 and int(alturas.get(Vector2i(9, 20), 0)) == 0)


func _reglas(mapa: PackedStringArray) -> void:
	var w := MundoFalso.new()
	w._mapa = mapa
	w._props = Node3D.new()
	w.add_child(w._props)
	root.add_child(w)
	Lanzador3D.configurar(w)
	var j := Jugador3D.new()
	w.add_child(j)
	w._jugador = Pj3D.new()
	w._jugador.position = w._centro_celda(Vector2i(3, 28), MundoFalso.ALTO)
	w.add_child(w._jugador)
	var r := TerraFina3D.new()
	w.add_child(r)
	for i in 3:
		await process_frame
	_ok("3 el titán está puesto y sin colisiones", r._titan != null and r._titan.find_children("*", "CollisionObject3D", true, false).is_empty())
	var ancho: float = 19.0 * MundoFalso.S
	_ok("3 el titán, centrado en el mapa", absf(r._titan.global_position.x - ancho * 0.5) < 0.01, "x %.2f, centro %.2f" % [r._titan.global_position.x, ancho * 0.5])
	var pies_z: float = r._titan.global_position.z + TerraFina3D.PIES_LOCAL_Z
	_ok("3 sus pies acaban en la fila 1,5 del mapa", absf(pies_z - 1.5 * MundoFalso.S) < 0.01, "z de los pies %.2f" % pies_z)
	# Medido, no la constante: la punta de los dedos del titán (caja de todas sus mallas) cae en la fila 1,5 ± 1 u.
	var punta: float = r._titan.position.z + _caja_total(r._titan).end.z
	_ok("3 MEDIDO: la punta de los pies está en la fila 1,5 (±1 u)", absf(punta - 1.5 * MundoFalso.S) < 1.0, "punta z %.2f, fila 1,5 = %.2f" % [punta, 1.5 * MundoFalso.S])
	var casas: int = 0
	for h in w.get_children():
		if String(h.name).begins_with("casa_cueva"):
			casas += 1
	_ok("3 una casa-cueva por cada H (15) y todas bloquean", casas == 15 and w._bloqueadas.has(Vector2i(3, 1)) and w._bloqueadas.has(Vector2i(17, 16)), "casas %d" % casas)
	_ok("3 dos gatopedros creados", r._gatopedros.size() == 2, str(r._gatopedros.size()))
	_ok("3 la salida E (18,4) empieza bloqueada y selladа" .replace("а", "a"), w._bloqueadas.has(Vector2i(18, 4)) and r._sello != null and not r._salida_abierta)
	# 3b) las tres alturas
	var alto0: float = Terreno3D.alto_suelo
	_ok("3b alturas fijadas: pecho 2, pelvis 1, pies 0", Terreno3D.altura_en(Vector2i(9, 4)) == 2 and Terreno3D.altura_en(Vector2i(9, 12)) == 1 and Terreno3D.altura_en(Vector2i(9, 25)) == 0)
	_ok("3b el hueco de la fila 8 es del pecho y el muro de la 18 no se eleva", Terreno3D.altura_en(Vector2i(9, 8)) == 2 and Terreno3D.altura_en(Vector2i(2, 18)) == 0)
	_ok("3b Jugador3D sube hasta 2 mientras dura el nivel", Jugador3D.tope_niveles_nivel == 2)
	var terr: MeshInstance3D = w.get_node_or_null("Terrazas") as MeshInstance3D
	_ok("3b las terrazas están dibujadas (tapas + muros)", terr != null and terr.mesh != null and terr.mesh.get_surface_count() == 1)
	var y_pecho: float = alto0 + 2.0 * Terreno3D.ALTO_NIVEL
	_ok("3b el titán se sienta en la meseta del pecho", absf(r._titan.position.y - y_pecho) < 0.01, "y %.3f, meseta %.3f" % [r._titan.position.y, y_pecho])
	var casa_p: Node3D = w.get_node("casa_cueva_1_10") as Node3D
	var casa_a: Node3D = w.get_node("casa_cueva_3_1") as Node3D
	_ok("3b las casas están a la altura de su terraza", absf(casa_p.position.y - (alto0 + Terreno3D.ALTO_NIVEL)) < 0.01 and absf(casa_a.position.y - y_pecho) < 0.01)
	var g0: Gatopedro3D = r._gatopedros[0]
	_ok("3b los gatopedros nacen sobre el pecho", absf(g0.position.y - y_pecho) < 0.01, "y %.3f" % g0.position.y)
	var pieza := Node3D.new()                                  # el portal de la maqueta, a ras de suelo en la casilla E
	pieza.position = w._centro_celda(Vector2i(18, 4), alto0)
	w._props.add_child(pieza)
	r._subir_piezas_de_la_salida(MundoFalso.S)
	_ok("3b las piezas de la salida suben a la altura de su terraza", absf(pieza.position.y - y_pecho) < 0.01, "y %.3f" % pieza.position.y)
	_ok("3b el sello de la salida, sobre la terraza", absf(r._sello.position.y - (y_pecho + 1.3)) < 0.01)
	# visión y movimiento de un gatopedro en la terraza alta (lo que se parcheó en Terreno3D y Combate3D)
	_ok("3b en la terraza se ve a través de casillas del mismo nivel", Terreno3D.linea_libre(w._centro_celda(Vector2i(4, 3), y_pecho), w._centro_celda(Vector2i(12, 3), y_pecho)))
	Terreno3D.fijar_altura(Vector2i(9, 26), 2)
	_ok("3b una torre más alta que quien mira SÍ corta la vista", not Terreno3D.linea_libre(w._centro_celda(Vector2i(9, 25), alto0), w._centro_celda(Vector2i(9, 27), alto0)))
	Terreno3D.fijar_altura(Vector2i(9, 26), 0)
	g0.set_physics_process(false)
	_ok("3b el gatopedro camina por su terraza", g0._puede_estar(g0.position + Vector3(MundoFalso.S, 0.0, 0.0)))
	var pos_g: Vector3 = g0.position
	g0.position = w._centro_celda(Vector2i(7, 7), y_pecho)
	_ok("3b y no baja del pecho a los pies por el borde (un nivel de caída)", not g0._puede_estar(w._centro_celda(Vector2i(7, 8), alto0)))
	g0.position = pos_g
	var jp: Vector3 = g0.position + Vector3(-5.0, 0.0, 0.0)
	j.position = jp
	var x_ini: float = g0.position.x
	for i in range(int(4.0 / (1.0 / 60.0))):
		if g0.muerto:
			break
		g0._physics_process(1.0 / 60.0)
	var c_fin: Vector2i = w._celda_de(g0.position)
	_ok("3b detecta al jugador en la terraza y huye de él", g0.position.x > x_ini + 2.0, "x de %.2f a %.2f" % [x_ini, g0.position.x])
	_ok("3b y sigue en la terraza alta, a su altura", Terreno3D.altura_en(c_fin) == 2 and absf(g0.position.y - y_pecho) < 0.1, "casilla %s y %.2f" % [str(c_fin), g0.position.y])
	# 4) la salida
	Estado.i().enemigo_muerto.emit(Vector2.ZERO, "Goblin")
	_ok("4 un goblin muerto no cuenta", r._caidos == 0 and not r._salida_abierta)
	Estado.i().enemigo_muerto.emit(Vector2.ZERO, "Gatopedro")
	_ok("4 con un gatopedro caído la salida sigue sellada", r._caidos == 1 and not r._salida_abierta and w.liberadas.is_empty())
	Estado.i().enemigo_muerto.emit(Vector2.ZERO, "Gatopedro")
	_ok("4 con los dos caídos la salida se libera", r._salida_abierta and w.liberadas == [Vector2i(18, 4)] and not w._bloqueadas.has(Vector2i(18, 4)))
	# avisos: el primero sale al avanzar
	w._jugador.position = w._centro_celda(Vector2i(3, 26), MundoFalso.ALTO)
	await process_frame
	await process_frame
	_ok("5 al avanzar sale el primer aviso", r._aviso_dado[0] and r._aviso.text != "")
	w._jugador.position = w._centro_celda(Vector2i(18, 4), MundoFalso.ALTO)
	await process_frame
	await process_frame
	_ok("5 pisar la salida libre completa el nivel", r._terminado)
	_ok("5 sin tope propio, el pecho (2) no se pisa desde la pelvis; con tope 2 sí", not Terreno3D.pisable(Vector2i(9, 7), 1, true, 1, true) and Terreno3D.pisable(Vector2i(9, 7), 1, true, 2, true))
	_ok("5 de los pies no se salta al pecho (2 niveles)", not Terreno3D.pisable(Vector2i(9, 7), 0, true, 2, true))
	w.queue_free()
	await process_frame
	await process_frame
	_ok("5 al salir del nivel el tope de Jugador3D vuelve a 0", Jugador3D.tope_niveles_nivel == 0)
