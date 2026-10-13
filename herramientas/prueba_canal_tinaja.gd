extends SceneTree
## Canal de la tinaja con agua a la altura de la piedra (12/10) sin ventana: montar_agua_sim con canal de ruinas estrecho, la tinaja
## (Surtidor3D) con manantial permanente, y que el agua se vea por encima de la hierba y del fondo de la pieza. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_canal_tinaja.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _abre: Dictionary = {}              ## Vector2i -> Array de Vector2i (lados que abre cada pieza)
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_canal(c: Vector2i) -> bool:
		return _en(c) and (_letra(c) == "-" or _letra(c) == "L")
	func _en(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < 6 and c.y < 6
	func _abre_hacia(c: Vector2i, v: Vector2i) -> bool:
		return (_abre.get(c, []) as Array).has(v)
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)
	func _poner_canal(_c: Vector2i, _canal: int, _valor: float) -> void:
		pass

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	await _tinaja()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _tinaja() -> void:
	# La tinaja «u», un recto, un codo (oeste y sur), otro recto (norte-sur) y el río que se lleva lo que sobra.
	var m := MundoFalso.new()
	m._mapa = ["######", "#u-L##", "###-##", "###~##", "###~##", "###~##"]
	m._abre = {Vector2i(2, 1): [Vector2i(-1, 0), Vector2i(1, 0)], Vector2i(3, 1): [Vector2i(-1, 0), Vector2i(0, 1)],
			Vector2i(3, 2): [Vector2i(0, -1), Vector2i(0, 1)]}
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if m._letra(Vector2i(x, y)) in ["#", "u", "~", "-", "L"]:
				m._bloqueadas[Vector2i(x, y)] = true
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var canal: Array = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)]
	var fondo: float = Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL
	# 1: el fondo y la forma estrecha.
	var i_c: int = sim._trozos(Vector2i(2, 1))[4]
	_ok("1 el fondo del canal está en alto_suelo + FONDO_CANAL (no en el lecho)", absf(sim.suelo[i_c] - fondo) < 1.0e-4, "%.3f (esperado %.3f)" % [sim.suelo[i_c], fondo])
	_ok("1 el río sigue en su lecho", absf(sim.suelo[sim._trozos(Vector2i(3, 3))[4]] - (Terreno3D.alto_agua - Terreno3D.LECHO_AGUA)) < 1.0e-4)
	_ok("1 sellado hasta que se abre", sim.profundidad_casilla(Vector2i(2, 1)) == 0.0 and sim.cerrado[i_c] == 1)
	var s := Surtidor3D.new()
	s.preparar(m, Vector2i(1, 1))
	root.add_child(s)
	await process_frame
	_ok("2 el cauce son las 3 casillas del canal", s.cauce.size() == 3, str(s.cauce))
	var rune := RuneData.new()
	rune.tags.append("agua")
	s.on_spell_hit(rune)
	# 3: tras abrir, solo están abiertos el centro y los lados de la pieza.
	var t_rec: PackedInt32Array = sim._trozos(Vector2i(2, 1))
	var abiertos_rec: Array = []
	for k in range(9):
		if sim.cerrado[t_rec[k]] == 0:
			abiertos_rec.append(k)
	_ok("3 recto: abiertos centro, oeste y este (4, 3, 5)", abiertos_rec == [3, 4, 5], str(abiertos_rec))
	var t_cod: PackedInt32Array = sim._trozos(Vector2i(3, 1))
	var abiertos_cod: Array = []
	for k in range(9):
		if sim.cerrado[t_cod[k]] == 0:
			abiertos_cod.append(k)
	_ok("3 codo: abiertos centro, oeste y sur (3, 4, 7)", abiertos_cod == [3, 4, 7], str(abiertos_cod))
	# 4: 40 s.
	var t: float = 0.0
	while t < 35.0:   # en régimen: a los 40 s T_MAX fuerza la tercera casilla (fondo + 0,3) y falsea la medida
		await physics_frame
		sim.paso(1.0 / 60.0)
		t += 1.0 / 60.0
	var p: Array = []
	for c in canal:
		p.append(sim.profundidad_casilla(c as Vector2i))
	print("      profundidades en régimen (%.0f s): %.3f / %.3f / %.3f   (gemelo: 0,33 / 0,25 / 0,13)" % [t, p[0], p[1], p[2]])
	# Lo esperado sale de CAUDAL_TINAJA (L2.0, 13/10): el gemelo midió 0,33 / 0,25 / 0,13 con 1,0 u³/s, y en régimen la lámina crece
	# casi lineal con el caudal (1,05 → 0,344 / 0,256; 1,1 → 0,359 / 0,267). Se escala por Q/1,0 con ±12 % (mínimo 0,03).
	var q: float = Surtidor3D.CAUDAL_TINAJA
	var esperado: Array = [0.329 * q, 0.246 * q, 0.127 * q]
	var cerca: bool = true
	for k in range(3):
		cerca = cerca and absf(float(p[k]) - float(esperado[k])) < maxf(0.03, 0.12 * float(esperado[k]))
	_ok("4 las profundidades siguen al caudal (Q %.2f: esperado %.2f / %.2f / %.2f)" % [q, esperado[0], esperado[1], esperado[2]], cerca)
	var f: float = 0.0
	for i in sim._trozos(Vector2i(2, 1)):
		f += sim.fuente[i]
	_ok("4 la tinaja es un manantial permanente de CAUDAL_TINAJA (%.2f)" % Surtidor3D.CAUDAL_TINAJA, absf(f - Surtidor3D.CAUDAL_TINAJA) < 1.0e-4, "fuente %.3f" % f)
	var arriba: bool = true
	for c in canal:
		var pc: float = sim.profundidad_casilla(c as Vector2i)
		arriba = arriba and pc > 0.05
	_ok("4 hay agua en las tres casillas", arriba)
	var y_sup: float = fondo + float(p[0])
	_ok("4 la superficie está por encima del fondo de la piedra y de la hierba (1,035)", y_sup > Terreno3D.alto_suelo + 0.11, "superficie %.3f" % y_sup)
	_ok("4 no se desborda (< fondo + 0,6)", float(p[0]) < 0.6 and float(p[1]) < 0.6 and float(p[2]) < 0.6)
	# El diseño del canal: el codo es agua (conduce el rayo) y ninguna casilla desborda. Con CAUDAL_TINAJA 1,0 el codo quedaba en 0,246, a
	# 0,004 del umbral; con 1,5 queda holgado. Si un cambio de caudal lo vuelve a acercar al umbral, esta prueba debe fallar, no aflojarse.
	_ok("4 el codo es agua (conduce) con margen ≥ 0,05 sobre UMBRAL_AGUA", sim.es_agua_casilla(Vector2i(3, 1)) and Terreno3D.es_agua(Vector2i(3, 1)) and float(p[1]) >= AguaSim3D.UMBRAL_AGUA + 0.05, "codo %.3f, umbral %.2f" % [p[1], AguaSim3D.UMBRAL_AGUA])
	_ok("4 la tercera casilla (la que desagua al río) no desborda", float(p[2]) < Surtidor3D.SOBRE_FONDO_FORZADO, "%.3f" % p[2])
	# Sin agua fuera del canal: ni en la tinaja ni en las paredes.
	var fuera: float = 0.0
	for y in range(6):
		for x in range(6):
			var c := Vector2i(x, y)
			if canal.has(c) or m._letra(c) == "~":
				continue
			for i in sim._trozos(c):
				fuera += sim.prof[i]
	_ok("4 sin agua fuera del canal", fuera < 1.0e-6, "%.6f" % fuera)
	_ok("4 el canal conserva su letra", m._letra(Vector2i(2, 1)) == "-" and m._letra(Vector2i(3, 1)) == "L")
	s.queue_free()
	m.queue_free()
