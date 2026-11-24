extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LA VAGONETA (24/11/2026, playtest de Pablo: «las ruedas deben ir paralelas a las vías; anima las ruedas y dales sonido metálico»).
## Carga PtVagonetas con la cámara del juego y saca: la vagoneta en una vía norte-sur (sala 1), la de la curva ya girada al tramo este-oeste
## (sala 2) y la lanzada (sala 3) en marcha. Comprueba además que las ruedas giran al moverse y que suena la rodadura. Necesita ventana:
##   godot --path . --script res://herramientas/captura_vagoneta.gd
## Escribe en docs/capturas/vagoneta/.

const RUTA: String = "res://escenas/PruebaPtVagonetas.tscn"
const DIR: String = "res://docs/capturas/vagoneta"

var _pz: Puzle3D = null


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	root.get_window().size = Vector2i(1600, 900)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	_pz = maqueta.get_node("Puzles") as Puzle3D
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var vags: Array = []
	for id in _pz.piezas_ids() if _pz.has_method("piezas_ids") else []:
		pass
	for n in maqueta.find_children("*", "", true, false):
		if n is Vagoneta3D:
			vags.append(n)
	vags.sort_custom(func(a, b) -> bool: return String(a.name) < String(b.name))
	_ok("hay 4 vagonetas", vags.size() == 4, str(vags.size()))
	if vags.size() < 3:
		return
	# 1 · la de la pista (vía norte-sur): girada 90°.
	var v1: Vagoneta3D = _por_nombre(vags, "cat1_vag")
	_ok("pista: la vagoneta está girada a lo largo de la vía norte-sur (90°)", v1 != null and is_equal_approx(absf(v1.get("_giro").rotation.y), PI * 0.5),
		str(v1.get("_giro").rotation_degrees.y) if v1 != null else "")
	_ok("pista: tiene 6 piezas que giran (4 ruedas y 2 ejes)", v1 != null and (v1.get("_ruedas") as Array).size() == 6, str((v1.get("_ruedas") as Array).size()) if v1 != null else "")
	colocar_jugador(v1.celda + Vector2i(0, 2))           # delante, en el suelo de la pista (de una casilla de ancho)
	await avanzar_s(1.0)
	await _guardar("pista_quieta.png")
	await _de_cerca(v1, "cerca_norte_sur.png")
	# Empujada: las ruedas giran y suena.
	var a0: float = float(v1.get("_angulo_ruedas"))
	colocar_jugador(v1.celda + Vector2i(0, 1))
	await avanzar(3)
	v1.empujar(Vector2i(0, -1), true)
	await avanzar_s(1.0)
	await _guardar("pista_empujada.png")
	var sonando: bool = v1.get("_rodadura") != null and is_instance_valid(v1.get("_rodadura")) and (v1.get("_rodadura") as AudioStreamPlayer3D).playing
	await avanzar_s(2.0)
	_ok("pista: empujada, las ruedas giran", absf(float(v1.get("_angulo_ruedas")) - a0) > 1.0, "%.2f rad" % (float(v1.get("_angulo_ruedas")) - a0))
	_ok("pista: empujada, suena la rodadura metálica", sonando)
	# 2 · la de la curva: dos empujones hacia arriba y ya en la esquina se orienta al tramo este-oeste.
	var v2: Vagoneta3D = _por_nombre(vags, "cat2_vag")
	if v2 != null:
		for i in 2:
			colocar_jugador(v2.celda + Vector2i(0, 1))
			await avanzar(3)
			print("   curva: norte desde %s -> %s" % [str(v2.celda), v2.empujar(Vector2i(0, -1), true)])
			await avanzar_s(3.0)
		colocar_jugador(v2.celda + Vector2i(1, 0))
		await avanzar(3)
		var a: Vector2i = v2.celda + Vector2i(-1, 0)
		print("   curva: destino %s riel %s bloqueada %s bloque %s agua %s alturas %d/%d jugadora %s aguja %s" % [str(a), v2.rieles.has(a), Terreno3D.bloqueada(a),
			str(BloqueEmpujable3D.en(a)), Terreno3D.es_agua(a), Terreno3D.altura_en(a), Terreno3D.altura_en(v2.celda), str(celda_jugador()), str(Aguja3D.en(v2.celda))])
		print("   curva: oeste desde %s -> %s (puede %s)" % [str(v2.celda), v2.empujar(Vector2i(-1, 0), true), v2.puede_moverse(Vector2i(-1, 0))])
		await avanzar_s(3.0)
		print("   curva: queda en %s, giro %.1f" % [str(v2.celda), v2.get("_giro").rotation_degrees.y])
		_ok("curva: en el tramo este-oeste se gira (0°)", is_equal_approx(fmod(absf(v2.get("_giro").rotation.y), PI), 0.0) or absf(fmod(absf(v2.get("_giro").rotation.y), PI) - PI) < 0.01,
			str(v2.get("_giro").rotation_degrees.y))
		colocar_jugador(v2.celda + Vector2i(0, 2))
		await avanzar_s(0.8)
		await _guardar("curva_este_oeste.png")
		await _de_cerca(v2, "cerca_este_oeste.png")
	# 3 · la del botón, lanzada: en marcha.
	var v3: Vagoneta3D = _por_nombre(vags, "cat3_vag")
	if v3 != null:
		colocar_jugador(v3.celda + Vector2i(1, 2))
		await avanzar_s(0.6)
		v3.rodar()
		await avanzar(8)
		await _guardar("lanzada_en_marcha.png")
		# 24/11 (Pablo: «sale demasiado rápido»): lanzada va a la velocidad del empuje. Se mide la punta de velocidad durante el recorrido.
		var punta: float = 0.0
		var t: float = 0.0
		while t < 10.0 and v3.choques < 1:
			punta = maxf(punta, v3.vel)
			t += await avanzar_s(0.1)
		_ok("lanzada: va a la velocidad del empuje (punta %.2f u/s; empuje %.2f)" % [punta, BloqueEmpujable3D.VEL_EMPUJE], punta <= BloqueEmpujable3D.VEL_EMPUJE + 0.01 and punta > 0.5)
		_ok("lanzada: rompe el muro", v3.choques >= 1, "%.1f s" % t)
	# 4 · la aguja: la palanca es el detonador del pack; su asa se inclina hacia el ramal puesto.
	var ag: Aguja3D = null
	for n in maqueta.find_children("*", "", true, false):
		if n is Aguja3D:
			ag = n
	if ag != null:
		_ok("aguja: la palanca es el detonador del pack (con asa)", ag.get("_asa") != null)
		_ok("aguja: los hechizos ya no la cambian (sin capa de colisión)", ag.collision_layer == 0 and not ag.spell_reacts(null))
		await _de_cerca_en(ag.global_position, "aguja_ramal_a.png")
		ag.cambiar()
		await avanzar_s(0.5)
		_ok("aguja: cambiada, el asa se inclina al otro lado", ag.en_b and (ag.get("_asa") as Node3D).rotation.z < 0.0, str((ag.get("_asa") as Node3D).rotation.z))
		await _de_cerca_en(ag.global_position, "aguja_ramal_b.png")


## Se reconocen por su VÍA (los números catN siguen el orden de colocación, no el de las salas): «cat1_vag» = una de vía recta norte-sur (3 casillas, sin muro
## delante), «cat2_vag» = la de la curva (vía en L), «cat3_vag» = la del muro (recta, con un muro agrietado al final).
func _por_nombre(lista: Array, nombre: String) -> Vagoneta3D:
	for v in lista:
		var vv: Vagoneta3D = v
		var xs: Dictionary = {}
		var ys: Dictionary = {}
		for c in vv.rieles:
			xs[(c as Vector2i).x] = true
			ys[(c as Vector2i).y] = true
		var en_l: bool = xs.size() > 1 and ys.size() > 1
		var con_aguja: bool = false
		for c in vv.rieles:
			con_aguja = con_aguja or Aguja3D.en(c) != null
		var con_muro: bool = false
		for n in maqueta.find_children("*", "", true, false):
			if n is MuroAgrietado3D and vv.rieles.has((n as MuroAgrietado3D).celda + Vector2i(0, 1)):
				con_muro = true
		match nombre:
			"cat1_vag":
				if not en_l and not con_aguja and not con_muro:
					return vv
			"cat2_vag":
				if en_l and not con_aguja:
					return vv
			"cat3_vag":
				if con_muro:
					return vv
	return null


## Toma DE CERCA de una vagoneta: cámara propia a 3 casillas, por delante y por encima, y una luz junto a ella (la cueva es oscura).
func _de_cerca(v: Vagoneta3D, nombre: String) -> void:
	await _de_cerca_en(v.global_position, nombre)


func _de_cerca_en(p: Vector3, nombre: String) -> void:
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 40.0
	maqueta.add_child(cam)
	var luz := OmniLight3D.new()
	luz.omni_range = 9.0
	luz.light_energy = 2.5
	maqueta.add_child(luz)
	luz.global_position = p + Vector3(1.5, 3.0, 2.5)
	cam.global_position = p + Vector3(2.6, 3.4, 4.6)
	cam.look_at(p + Vector3(0.0, 0.5, 0.0))
	cam.current = true
	await avanzar(4)
	await _guardar(nombre)
	cam.current = false
	if cam_juego != null:
		cam_juego.current = true
	cam.queue_free()
	luz.queue_free()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	print("captura: ", nombre)
