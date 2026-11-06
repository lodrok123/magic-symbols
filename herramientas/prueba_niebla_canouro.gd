extends "res://herramientas/escenario_base.gd"
## 5/11 · NIEBLA NEGRA DEL CANOURO (NieblaCanouro3D; encargo de Pablo). Sin ventana, a 30 fps fijos, sobre la escena real del Bosque.
##   A  el canouro lleva la niebla (hija del pj, con su nombre y una capa por altura configurada)
##   B  capas: sin sombra, material de shader, la más alta por debajo de la rodilla, radio según la altura
##   C  sigue al animal cuando éste se mueve
##   D  al morir la niebla se apaga
##   E  goblin y loberno no la llevan
##   F  con ACTIVA = false no se monta
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_niebla_canouro.gd

const FILA: int = 33
var _creados: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _enemigo(id: String, c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", [id], p)
	if modelo == null:
		return null
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			(n as Node).queue_free()
	_creados.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()


func _jugadora_lista(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	NieblaCanouro3D.ACTIVA = true
	_jugadora_lista(Vector2i(8, FILA))
	var g: Combate3D = _enemigo("canouro", Vector2i(30, FILA))
	await avanzar(8)
	# A
	var n: NieblaCanouro3D = g._niebla if g != null else null
	_ok("A el canouro lleva niebla (NieblaCanouro3D)", g != null and n != null and n is NieblaCanouro3D)
	if n == null:
		_limpiar()
		return
	_ok("A la niebla es hija del pj y se llama NieblaCanouro3D", n.get_parent() == g.pj and n.name == "NieblaCanouro3D")
	_ok("A tiene %d capas (una por altura configurada)" % n.capas.size(), n.capas.size() == NieblaCanouro3D.ALTURAS_CAPAS.size())
	# B
	var todas: bool = true
	var y_max: float = 0.0
	for c in n.capas:
		todas = todas and c is MeshInstance3D and c.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and c.mesh != null and c.mesh.material is ShaderMaterial
		y_max = maxf(y_max, c.position.y)
	_ok("B todas las capas sin sombra y con ShaderMaterial", todas)
	_ok("B la capa más alta a %.3f u ≤ 0,3 × altura (%.3f)" % [y_max, 0.3 * g.altura], y_max <= 0.3 * g.altura)
	_ok("B radio %.3f = RADIO_ALTURAS × altura (%.3f)" % [n.radio(), NieblaCanouro3D.RADIO_ALTURAS * g.altura], absf(n.radio() - NieblaCanouro3D.RADIO_ALTURAS * g.altura) <= 0.001)
	# C
	await avanzar(5)
	g.position += Vector3(2, 0, 0)
	await avanzar(1)
	var d1: Vector3 = n.global_position - g.pj.global_position
	d1.y = 0.0
	var obj_x: float = g.pj.global_position.x
	if n.global_position.x > obj_x + 0.001:
		_aviso("C la niebla va por delante del animal tras 1 fotograma (%.3f u)" % d1.length(), "no debería adelantarse")
	await avanzar(30)
	var d: Vector3 = n.global_position - g.pj.global_position
	d.y = 0.0
	# El canouro patrulla (~0,6 u/s): el retraso estacionario es v / SUAVIZADO ≈ 0,05 u, de ahí el margen.
	_ok("C 30 fotogramas después la niebla sigue al animal (distancia horizontal %.3f < 0,1)" % d.length(), d.length() < 0.1)
	# G · 2.ª versión: cuerpo negro, humo del cuerpo en los huesos, ojos en la cabeza
	var negro: bool = not n.cuerpo.is_empty()
	for mi in n.cuerpo:
		var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
		negro = negro and m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and m.albedo_color.r < 0.1 and m.albedo_color.g < 0.1 and m.albedo_color.b < 0.1
	_ok("G el cuerpo del canouro va pintado de negro sin luz (%d mallas)" % n.cuerpo.size(), negro)
	var sk: Skeleton3D = g.pj._esqueleto()
	var ok_h: bool = n.emisores.size() == NieblaCanouro3D.HUMO_HUESOS.size() and n.emisores.size() >= 10
	for e in n.emisores:
		# Cuelgan de un BoneAttachment3D (no top_level); las bocanadas quedan en el mundo con local_coords false.
		ok_h = ok_h and e.emitting and not e.local_coords and e.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not e.process_material.get("particle_flag_disable_z")
	var ok_o: bool = n.ojos.size() == 2
	for o in n.ojos:
		ok_o = ok_o and o.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Se mide dentro de `skeleton_updated`: ahí la pose ya lleva los SkeletonModifier3D (MarchaCuadrupedo, ProporcionChibi), que es la que
	# se pinta y la que siguen los BoneAttachment3D; fuera de la señal `get_bone_global_pose` da la pose sin modificar (lomo, cuello, cabeza
	# y patas delanteras salían a 4-7 cm del humo).
	var med: Array = [0.0, 0.0, 0]   # desvío máximo del humo, distancia máxima ojo-cabeza, poses medidas (la lambda no puede reasignar locales)
	var medir := func() -> void:
		med[2] += 1
		for k in n.emisores.size():
			var hueso: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(String(NieblaCanouro3D.HUMO_HUESOS[k][0])))).origin
			med[0] = maxf(med[0], n.emisores[k].global_position.distance_to(hueso))
		var cab: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin
		for o in n.ojos:
			med[1] = maxf(med[1], o.global_position.distance_to(cab))
	sk.skeleton_updated.connect(medir)
	await avanzar(3)
	sk.skeleton_updated.disconnect(medir)
	var lejos: float = med[0]
	var d_ojo: float = med[1]
	ok_h = ok_h and int(med[2]) > 0
	_ok("G %d emisores de humo encendidos, sin sombra y pegados a su hueso (desvío máximo %.3f u < 0,02 en %d poses)" % [n.emisores.size(), lejos, int(med[2])], ok_h and lejos < 0.02)
	_ok("G dos ojos atados a la cabeza (a %.3f u del hueso Head < 0,25 × altura)" % d_ojo, ok_o and d_ojo < 0.25 * g.altura)
	# D
	g._morir()
	await avanzar(2)
	var humo_parado: bool = true
	for e in n.emisores:
		humo_parado = humo_parado and not e.emitting
	_ok("D al morir la niebla queda invisible, el humo deja de salir y los ojos se apagan", not n.visible and humo_parado and n.ojos.size() == 2 and not n.ojos[0].is_visible_in_tree())
	_limpiar()
	await avanzar(3)
	# E
	_jugadora_lista(Vector2i(8, FILA))
	var gob: Combate3D = _enemigo("goblin_warrior_chibi", Vector2i(30, FILA))
	var lob: Combate3D = _enemigo("loberno", Vector2i(30, FILA + 3))
	_ok("E goblin y loberno no llevan niebla", gob != null and lob != null and gob._niebla == null and lob._niebla == null)
	_limpiar()
	await avanzar(3)
	# F
	NieblaCanouro3D.ACTIVA = false
	var g2: Combate3D = _enemigo("canouro", Vector2i(30, FILA))
	_ok("F con ACTIVA = false el canouro no lleva niebla", g2 != null and g2._niebla == null)
	NieblaCanouro3D.ACTIVA = true
	_limpiar()
	await avanzar(2)
