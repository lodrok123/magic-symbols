extends SceneTree
## PRUEBA de Marimanta (arte/modelos/marimanta.glb, Meshy «Crimson Goblin Duchess», esqueleto Mixamo de 66 huesos con dedos, 7 clips propios, convertido del FBX con
## herramientas/convertir_fbx_a_glb.gd): carga como Pj3D, mide lo que debe, resuelve los roles de NPC a sus clips, tiene los pies en el suelo, no desplaza la
## cadera y lleva el bastón en la mano derecha. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_marimanta.gd
## Cómo se VE se mira en docs/capturas/marimanta/ (herramientas/captura_marimanta.gd).

const ID: String = "marimanta"
const ALTO_ESPERADO: float = 0.8          ## u de juego (el de ALTO_PJ en PruebaTest2: más baja que el goblin, 0,85)
const TOL_ALTO: float = 0.05              ## ±5 %
const HUESOS_ESPERADOS: int = 66          ## 65 de Mixamo con dedos + `headfront`, el hueso de la cara que añade el autorig de Meshy
## Clips propios del GLB (Meshy, 23/10) y el rol que debe resolver a cada uno.
const CLIPS_PROPIOS: Array = ["Elderly_Shaky_Walk", "Elderly_Shaky_Walk_inplace", "Idle_02", "Running", "Scheming_Hand_Rub", "Talk_with_Left_Hand_on_Hip", "Walking"]
const ROLES_PROPIOS: Dictionary = {"idle": "Idle_02", "walk": "Elderly_Shaky_Walk_inplace", "talk": "Talk_with_Left_Hand_on_Hip", "pensar": "Scheming_Hand_Rub", "run": "Running"}
## Roles de un enemigo que una NPC no tiene: solo se informa.
const ROLES_AUSENTES: Array = ["attack", "cast", "hit", "death", "roll", "swim"]
## Cuánto puede alejarse la cadera de donde empieza el clip en horizontal (fracción del alto del modelo): sin movimiento de raíz que desplace al NPC.
const RAIZ_MAX: float = 0.08
## Los clips de gesto (hablar, tramar) cargan el peso de un pie al otro: la cadera se mueve con los pies en el suelo. Es balanceo, no deriva.
const BALANCEO_MAX: float = 0.2
## Cuánto puede separarse del suelo el hueso de suela más bajo en idle y andar (fracción del alto del modelo). Al andar un pie siempre está en el aire.
const SUELO_IDLE_TOL: float = 0.02
const SUELO_MARCHA_MIN: float = 0.04      ## pisa: el pie más bajo, en el punto más bajo del ciclo, queda a menos de esto
const SUELO_MARCHA_HUNDE: float = -0.03   ## y no atraviesa el suelo más de esto
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Bastón: pieza de Equipo3D colgada de la mano derecha. En idle, vertical (desvío máximo de la vertical, grados) y con el pie a menos de esto del suelo (fracción
## del alto del modelo); y sigue a la mano (la distancia mano-bastón no cambia más de esto, fracción del alto, entre dos instantes del andar).
const PIEZA_BASTON: String = "baston_marimanta"
const BASTON_SUELO_TOL_U: float = 0.02    ## u de juego: lo que puede separarse del suelo la punta de abajo
const BASTON_LEJOS: float = 500.0         ## en el espacio del hueso: se suma al punto de agarre para simular la mano muy lejos
const BASTON_MUESTRAS: int = 16          ## instantes de cada clip en los que se mide
const BASTON_ALTO_MIN: float = 0.5        ## el bastón mide, en el juego, entre esta fracción y esta de la altura de ella
const BASTON_ALTO_MAX: float = 1.0

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar(ID), "marimanta carga")
	p.set_alto(ALTO_ESPERADO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_ESPERADO) <= ALTO_ESPERADO * TOL_ALTO, "altura en el juego %.3f (esperada %.2f ±5 %%)" % [p.alto_modelo() * p.scale.y, ALTO_ESPERADO])
	_ok(p.rol_visual == "npc", "rol visual NPC (%s)" % p.rol_visual)
	_ok(Pj3D.tipo_de(ID) == "npc", "tipo de personaje npc")
	var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
	_ok(not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("mixamorig_Hips") >= 0, "esqueleto con huesos mixamorig")
	var sk: Skeleton3D = sks[0] as Skeleton3D
	_ok(sk.get_bone_count() == HUESOS_ESPERADOS, "%d huesos (%d)" % [HUESOS_ESPERADOS, sk.get_bone_count()])
	_ok(sk.find_bone("mixamorig_LeftHandIndex1") >= 0 and sk.find_bone("mixamorig_RightHand") >= 0, "tiene manos y dedos")
	var ap: AnimationPlayer = p._ap
	_ok(ap != null, "AnimationPlayer con los clips propios del GLB (%d clips)" % (ap.get_animation_list().size() if ap != null else 0))
	if ap == null:
		_acabar()
		return
	for c in CLIPS_PROPIOS:
		_ok(ap.has_animation(c), "clip propio «%s» (%.2f s)" % [c, ap.get_animation(c).length if ap.has_animation(c) else 0.0])
	for r in ROLES_PROPIOS.keys():
		_ok(p.clip_de(r) == String(ROLES_PROPIOS[r]) and p.duracion(r) > 0.0, "rol %s -> %s (%.2f s)" % [r, p.clip_de(r), p.duracion(r)])
	for r in ROLES_AUSENTES:
		print("INFO  rol %s -> %s (una NPC no lo necesita)" % [r, p.clip_de(r) if p.clip_de(r) != "" else "(sin clip)"])
	_ok(p._arbol != null, "árbol de animación montado")
	for c in CLIPS_PROPIOS:
		if ap.has_animation(c):
			_ok(ap.get_animation(c).loop_mode != Animation.LOOP_NONE, "%s: en bucle" % c)
	for r in ["walk", "run", "talk", "pensar", "idle"]:
		p.jugar(r)
		await process_frame
		_ok(p.animacion_actual == r, "jugar(%s) sin error (actual: %s)" % [r, p.animacion_actual])
	# Pies y cadera en espacio del MODELO (el esqueleto tiene la armadura girada -90° y a escala 100: su Y no es la vertical).
	var alto: float = p.alto_modelo()
	var reposo: float = _suela_reposo(p, sk)
	_ok(true, "suela más baja en reposo: %.4f u del modelo" % reposo)
	for r in ["idle", "walk", "run", "talk", "pensar"]:
		var clip2: String = p.clip_de(r)
		var an: Animation = ap.get_animation(clip2)
		var pasos: int = 24
		var minimo: float = INF
		var maximo: float = -INF
		for k in range(pasos):
			var y: float = _suela_en(p, sk, ap, clip2, an.length * float(k) / float(pasos)) - reposo
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		var rel_min: float = minimo / alto
		var rel_max: float = maximo / alto
		print("INFO  %s (%s): suela mínima %.1f %% , máxima %.1f %% del alto" % [r, clip2, rel_min * 100.0, rel_max * 100.0])
		if r == "idle":
			_ok(absf(rel_min) <= SUELO_IDLE_TOL and absf(rel_max) <= SUELO_IDLE_TOL * 3.0, "idle: pies en el suelo (mín %.3f, máx %.3f del alto)" % [rel_min, rel_max])
		elif r == "walk" or r == "run":
			_ok(rel_min <= SUELO_MARCHA_MIN and rel_min >= SUELO_MARCHA_HUNDE, "%s: pisa el suelo sin hundirse (mín %.3f del alto)" % [r, rel_min])
		else:
			_ok(rel_min >= SUELO_MARCHA_HUNDE, "%s: no atraviesa el suelo (mín %.3f del alto)" % [r, rel_min])
	# Raíz: la cadera no se aleja en horizontal (el Juego es quien mueve al personaje) en ningún clip que el Juego pueda pedir.
	for r in ROLES_PROPIOS.keys():
		var c: String = p.clip_de(r)
		var deriva: float = _deriva_cadera(p, sk, ap, c) / alto
		var tope: float = RAIZ_MAX if (r == "walk" or r == "run" or r == "idle") else BALANCEO_MAX
		_ok(deriva <= tope, "%s (%s): sin movimiento de raíz (deriva %.3f del alto, tope %.2f)" % [r, c, deriva, tope])
	print("INFO  el clip Elderly_Shaky_Walk (con avance) deriva %.3f del alto; el rol walk usa el inplace" % (_deriva_cadera(p, sk, ap, "Elderly_Shaky_Walk") / alto))
	# Bastón.
	var baston: Node3D = null
	for e in p._equipo:
		if is_instance_valid(e) and String(e.get_meta("equipo_id", "")) == PIEZA_BASTON:
			baston = e
	_ok(baston != null, "lleva la pieza %s de Equipo3D" % PIEZA_BASTON)
	if baston != null:
		var at: Node = baston.get_parent()
		_ok(at is BoneAttachment3D and (at as BoneAttachment3D).bone_name.ends_with("RightHand"), "colgado de la mano derecha (%s)" % (at as BoneAttachment3D).bone_name)
		var apoyo: PiezaApoyada3D = at.get_node_or_null("Apoyo") as PiezaApoyada3D
		_ok(apoyo != null, "el bastón va en modo apoyado en el suelo (PiezaApoyada3D, por datos de EQUIPO)")
		var largo: float = _largo_baston(baston) * baston.global_basis.get_scale().y   # la escala global ya incluye la del personaje
		_ok(largo >= ALTO_ESPERADO * BASTON_ALTO_MIN and largo <= ALTO_ESPERADO * BASTON_ALTO_MAX, "bastón de %.2f u en el juego (de %.2f a %.2f)" % [largo, ALTO_ESPERADO * BASTON_ALTO_MIN, ALTO_ESPERADO * BASTON_ALTO_MAX])
		# En cada clip, a lo largo del ciclo: vertical (≤ inclinación máxima), la punta de abajo en el suelo del personaje y, mientras la sostiene, cerca de la mano.
		if apoyo != null:
			var suelo_y: float = p.global_position.y
			for r2 in ["idle", "walk", "talk", "pensar", "run"]:
				var clip_r: String = p.clip_de(r2)
				var largo_r: float = ap.get_animation(clip_r).length
				var peor_incl: float = 0.0
				var peor_suelo: float = 0.0
				var peor_mano: float = 0.0
				var sueltos: int = 0
				for k2 in range(BASTON_MUESTRAS):
					_suela_en(p, sk, ap, clip_r, largo_r * float(k2) / float(BASTON_MUESTRAS))
					apoyo.actualizar(0.0, true)
					peor_incl = maxf(peor_incl, rad_to_deg(baston.global_basis.y.normalized().angle_to(Vector3.UP)))
					peor_suelo = maxf(peor_suelo, absf(baston.global_position.y - suelo_y))
					if apoyo.suelta:
						sueltos += 1
					else:
						peor_mano = maxf(peor_mano, apoyo.distancia_mano)
				print("INFO  %s: inclinación máx %.1f°, punta a %.4f del suelo, mano a %.3f del palo, suelto en %d/%d muestras" % [r2, peor_incl, peor_suelo, peor_mano, sueltos, BASTON_MUESTRAS])
				_ok(peor_incl <= PiezaApoyada3D.INCLINACION_MAX + 0.1, "%s: bastón vertical (%.1f°, tope %.0f°)" % [r2, peor_incl, PiezaApoyada3D.INCLINACION_MAX])
				_ok(peor_suelo <= BASTON_SUELO_TOL_U, "%s: la punta de abajo en el suelo (a %.4f u, tope %.2f)" % [r2, peor_suelo, BASTON_SUELO_TOL_U])
				_ok(peor_mano <= PiezaApoyada3D.DISTANCIA_SUELTA + 0.001, "%s: cerca de la mano mientras la sostiene (%.3f u, tope %.2f)" % [r2, peor_mano, PiezaApoyada3D.DISTANCIA_SUELTA])
				if r2 == "idle":
					_ok(sueltos == 0, "idle: lo sostiene siempre")
			# Modo suelto: con la palma lejísimos (se simula alejando el punto de agarre) el bastón se queda plantado y vertical junto a ella, sin seguir a la mano.
			_suela_en(p, sk, ap, p.clip_de("idle"), 0.0)
			apoyo.actualizar(0.0, true)
			var pie_antes: Vector3 = baston.global_position
			var agarre_ok: Vector3 = apoyo.agarre_local
			apoyo.agarre_local += Vector3(BASTON_LEJOS, 0.0, 0.0)
			apoyo.actualizar(0.0, true)
			_ok(apoyo.suelta, "con la mano lejos el bastón pasa a modo suelto")
			_ok(baston.global_position.distance_to(pie_antes) <= 0.001 and rad_to_deg(baston.global_basis.y.normalized().angle_to(Vector3.UP)) <= 0.1, "suelto: plantado en su sitio y vertical (se movió %.4f u)" % baston.global_position.distance_to(pie_antes))
			apoyo.agarre_local = agarre_ok
			apoyo.actualizar(0.0, true)
			_ok(not apoyo.suelta, "al volver la mano lo vuelve a agarrar")
			# El bastón suelto o no sigue al personaje: si el personaje se mueve, el palo va con él.
			p.global_position.x += 1.0
			_suela_en(p, sk, ap, p.clip_de("idle"), 0.0)
			apoyo.actualizar(0.0, true)
			_ok(Vector2(baston.global_position.x - p.global_position.x, baston.global_position.z - p.global_position.z).length() <= 0.5, "si el personaje se mueve (otra x), el bastón va con él")
			p.global_position.x -= 1.0
			# En una terraza (el personaje 0,3 u más alto) el bastón se apoya en su suelo.
			p.global_position.y += 0.3
			_suela_en(p, sk, ap, p.clip_de("idle"), 0.0)
			apoyo.actualizar(0.0, true)
			_ok(absf(baston.global_position.y - p.global_position.y) <= BASTON_SUELO_TOL_U, "en una terraza, la punta apoya en la y del personaje (%.3f)" % (baston.global_position.y - p.global_position.y))
			p.global_position.y -= 0.3
	# Postura del idle: cabeza por encima del pecho (en espacio del modelo).
	var an_i: Animation = ap.get_animation(p.clip_de("idle"))
	var min_sobre: float = INF
	for k in range(8):
		_suela_en(p, sk, ap, p.clip_de("idle"), an_i.length * float(k) / 8.0)
		var cabeza: float = _y_modelo(p, sk, "mixamorig_Head")
		var pecho: float = _y_modelo(p, sk, "mixamorig_Spine2")
		min_sobre = minf(min_sobre, (cabeza - pecho) / alto)
	_ok(min_sobre >= 0.05, "idle: la cabeza por encima del pecho (mín %.3f del alto)" % min_sobre)
	_acabar()


func _acabar() -> void:
	print("RESULTADO marimanta · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Y (espacio del modelo, u del modelo) de un hueso en la pose actual.
func _y_modelo(p: Pj3D, sk: Skeleton3D, hueso: String) -> float:
	return p.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(hueso)).origin).y


func _suela_reposo(p: Pj3D, sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, p.to_local(sk.global_transform * sk.get_bone_global_rest(i).origin).y)
	return m


## Máxima distancia horizontal (u del modelo) de la cadera a su posición en t = 0, a lo largo del clip.
func _deriva_cadera(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	var h: int = sk.find_bone("mixamorig_Hips")
	var largo: float = ap.get_animation(clip).length
	_suela_en(p, sk, ap, clip, 0.0)
	var o: Vector3 = p.to_local(sk.global_transform * sk.get_bone_global_pose(h).origin)
	var m: float = 0.0
	for k in range(1, 25):
		_suela_en(p, sk, ap, clip, largo * float(k) / 25.0)
		var q: Vector3 = p.to_local(sk.global_transform * sk.get_bone_global_pose(h).origin)
		m = maxf(m, Vector2(q.x - o.x, q.z - o.z).length())
	return m


## Altura (espacio del modelo, u del modelo) del hueso de suela más bajo con el clip en `t`.
func _suela_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> float:
	if p._arbol != null:
		p._arbol.active = false          # el árbol manda sobre el reproductor: se apaga para mirar el clip a pelo
	ap.active = true
	ap.play(clip)
	ap.seek(t, true)
	sk.force_update_all_bone_transforms()
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, p.to_local(sk.global_transform * sk.get_bone_global_pose(i).origin).y)
	return m


## Largo del bastón en las unidades de su GLB (alto de la malla), sin la escala de la pieza.
func _largo_baston(pieza: Node3D) -> float:
	var m: float = 0.0
	for mi in pieza.find_children("*", "MeshInstance3D", true, false):
		m = maxf(m, (mi as MeshInstance3D).get_aabb().size.y)
	return m
