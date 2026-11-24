extends "res://herramientas/escenario_base.gd"
## GENERADOR: EL BARRIL DE PÓLVORA Y EL GATOPEDRO AÑADIDOS A MANO (24/11/2026). Pablo: «¿cómo añado un barril aquí?» (el escondite del muro
## agrietado en una cueva generada) y «para la cueva añade los gatopedros (acuérdate de su mecánica)».
## 1. Genera un mapa de salas con el puzle «Escondite tras el muro agrietado» a mano, un barril PEGADO al muro (por el lado de la sala) y un
##    gatopedro en la sala más grande: el barril queda en la casilla pedida y los dos salen como `; pieza`.
## 2. Un gatopedro en un rincón estrecho da el aviso de «poco sitio para huir».
## 3. Lo exporta, lo carga en el juego y: Puzle3D sin avisos; el gatopedro es un Gatopedro3D y HUYE al ver a la jugadora; una flecha de fuego
##    al barril lo hace explotar y rompe el muro: el cofre del escondite queda a la vista.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_generador_gatopedro_barril.gd

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "ZzGatoBarril"

var _pz: Puzle3D = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	var par: Dictionary = {"algoritmo": "salas", "semilla": 3, "nombre": NOMBRE, "enemigos": 0.0, "puzles": 0, "barreras": 0, "salas_cerradas": 0, "estilo": "cueva"}
	# La primera sala que admita el escondite.
	var a_mano: Dictionary = {}
	var base: Dictionary = Generador.new().generar(par)
	for sala in base["salas"]:
		if String(sala["rol"]) != "inicio":
			var prueba: Dictionary = Generador.new().generar(par, {}, {}, {int(sala["id"]): "escondite_muro"})
			if (prueba["puzles"] as Dictionary).get(int(sala["id"]), "") == "escondite_muro":
				a_mano = {int(sala["id"]): "escondite_muro"}
				break
	_ok("1 el escondite del muro cabe en una sala", not a_mano.is_empty())
	if a_mano.is_empty():
		return
	var m0: Dictionary = Generador.new().generar(par, {}, {}, a_mano)
	var muro: Vector2i = _celda_de_pieza(m0, " muro ")
	var cofre: Vector2i = _celda_de_pieza(m0, " cofre ")
	_ok("1 el escondite trae muro y cofre", muro.x >= 0 and cofre.x >= 0, "muro %s cofre %s" % [str(muro), str(cofre)])
	# El barril, pegado al muro por el lado contrario al cofre (el de la sala).
	var junto: Vector2i = muro + (muro - cofre)
	# El gatopedro, en el centro de la sala más grande que no sea la del escondite ni la del inicio.
	var grande: Rect2i = Rect2i()
	for sala in m0["salas"]:
		var r: Rect2i = sala["rect"]
		if String(sala["rol"]) == "" and not a_mano.has(int(sala["id"])) and r.get_area() > grande.get_area():
			grande = r
	var centro: Vector2i = grande.get_center()
	var anadidos: Array = [{"que": "objeto", "tipo": "barril", "c": junto}, {"que": "enemigo", "tipo": "gatopedro", "c": centro}]
	var m: Dictionary = Generador.new().generar(par, {}, {}, a_mano, {}, anadidos)
	var hechos: Array = m["anadidos"]
	_ok("1 el barril queda en la casilla pedida, pegada al muro (no en diagonal)", hechos.size() == 2 and (hechos[0]["c"] as Vector2i) == junto,
		"pedida %s, puesta %s" % [str(junto), str(hechos[0]["c"]) if hechos.size() > 0 else "-"])
	var lineas: String = "\n".join(m["lineas"])
	_ok("1 salen las líneas `; pieza … barril` y `; pieza … gatopedro`", lineas.contains(" barril %d %d" % [junto.x, junto.y]) and lineas.contains(" gatopedro "), lineas.right(300))
	_ok("1 el gatopedro en una sala grande no da el aviso de poco sitio", not "\n".join(m["avisos"]).contains("poco sitio"), str(m["avisos"]))
	# 2 · Un gatopedro en el rincón de la sala del escondite (la casilla de delante del barril): estrecho.
	var m2: Dictionary = Generador.new().generar(par, {}, {}, a_mano, {}, [{"que": "enemigo", "tipo": "gatopedro", "c": muro + (muro - cofre) * 2}])
	_ok("2 un gatopedro en el rincón del escondite avisa de que tiene poco sitio para huir", "\n".join(m2["avisos"]).contains("poco sitio"), str(m2["avisos"]))
	# 3 · En el juego.
	_ok("3 se exporta", bool(Exportador.exportar(m)["ok"]))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		_borrar()
		return
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("3 Puzle3D sin avisos", _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "")
	await avanzar_s(0.5)
	var gato: Node = _pz.nodo("enemigo_m1") if _pz != null else null
	_ok("3 el gatopedro está y es un Gatopedro3D", gato is Gatopedro3D, str(gato))
	if gato is Gatopedro3D:
		var g: Gatopedro3D = gato as Gatopedro3D
		var cg: Vector2i = Terreno3D.celda_de(g.global_position)
		var cerca: Vector2i = cg + Vector2i(2, 0) if Terreno3D.pisable(cg + Vector2i(2, 0), 0, true, 1, false) else cg + Vector2i(-2, 0)
		colocar_jugador(cerca)
		var d0: float = g.global_position.distance_to(jugador.position)
		var huye: bool = false
		var t: float = 0.0
		while t < 4.0 and not huye:
			t += await avanzar_s(0.1)
			huye = String(g.estado) == "huye"
		await avanzar_s(1.0)
		var d1: float = g.global_position.distance_to(jugador.position)
		_ok("3 el gatopedro ve a la jugadora y HUYE (se aleja)", huye and d1 > d0 + 0.5, "estado %s, distancia %.1f -> %.1f" % [String(g.estado), d0, d1])
	var muro_n = _pz.nodo("cat1_muro") if _pz != null else null
	if muro_n == null:
		for k in ["muro"]:
			for id in _ids_con(k):
				muro_n = _pz.nodo(id)
	_ok("3 el muro del escondite está entero", muro_n != null and not muro_n.roto_ya)
	await _fuego_a(junto)
	var roto: bool = false
	var t2: float = 0.0
	while t2 < 5.0 and not roto:
		t2 += await avanzar_s(0.1)
		roto = muro_n != null and muro_n.roto_ya
	_ok("3 fuego al barril: explota y rompe el muro pegado (el cofre queda a la vista)", roto and not Terreno3D.bloqueada(muro))
	_borrar()


func _celda_de_pieza(m: Dictionary, tipo_con_espacios: String) -> Vector2i:
	for l in m["lineas"]:
		var s: String = String(l)
		if s.begins_with("; pieza ") and s.contains(tipo_con_espacios):
			var t: PackedStringArray = s.substr(8).split(" ", false)
			if t.size() >= 4:
				return Vector2i(t[2].to_int(), t[3].to_int())
	return Vector2i(-1, -1)


func _ids_con(tipo: String) -> Array:
	var r: Array = []
	for l in FileAccess.get_file_as_string(Exportador.ruta_mapa(NOMBRE)).split("\n"):
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if String(l).begins_with(";") and t.size() >= 3 and t[0] == "pieza" and t[2] == tipo:
			r.append(t[1])
	return r


## Flecha de fuego a la casilla `c` desde 2-3 casillas en línea recta con el paso libre.
func _fuego_a(c: Vector2i) -> void:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		for dist in [3, 2]:
			var s: Vector2i = c + d * dist
			var libre: bool = true
			for i in range(1, dist + 1):
				var q: Vector2i = c + d * i
				if Terreno3D.bloqueada(q) or not Terreno3D.pisable(q, 0, true, 1, false):
					libre = false
			if libre:
				colocar_jugador(s)
				await avanzar_s(0.5)
				jugador.tinta.actual = jugador.tinta.maxima
				var dir: Vector3 = Terreno3D.centro_de(c, 0.0) - (jugador as Node3D).position
				dir.y = 0.0
				_ok("3 sale la flecha de fuego al barril desde %s" % str(s), lanzar("fuego", ["flecha"], dir))
				await avanzar_s(0.3)
				colocar_jugador(s + d * 2 if Terreno3D.pisable(s + d * 2, 0, true, 1, false) else s)   # que la explosión no la pille
				return
	_ok("3 hay sitio en línea para disparar al barril %s" % str(c), false)


func _borrar() -> void:
	for r in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
