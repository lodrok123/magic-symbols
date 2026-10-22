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
const BASTON_VERTICAL_MAX_GRADOS: float = 8.0
const BASTON_SUELO_TOL: float = 0.04
const BASTON_SIGUE_MANO_TOL: float = 0.005
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
		var mano: int = sk.find_bone("mixamorig_RightHand")
		var clip_i: String = p.clip_de("idle")
		_suela_en(p, sk, ap, clip_i, 0.0)
		await process_frame
		var pie: Vector3 = p.to_local(baston.global_position)
		var arriba: Vector3 = (baston.global_basis.y).normalized()
		var vertical: float = rad_to_deg(arriba.angle_to(Vector3.UP))
		_ok(vertical <= BASTON_VERTICAL_MAX_GRADOS, "idle: bastón vertical (%.1f° de la vertical, tope %.0f°)" % [vertical, BASTON_VERTICAL_MAX_GRADOS])
		_ok(absf(pie.y - reposo) / alto <= BASTON_SUELO_TOL, "idle: el pie del bastón en el suelo (a %.3f del alto del suelo, tope %.2f)" % [(pie.y - reposo) / alto, BASTON_SUELO_TOL])
		var largo: float = _largo_baston(baston) * baston.global_basis.get_scale().y   # la escala global ya incluye la del personaje
		_ok(largo >= ALTO_ESPERADO * BASTON_ALTO_MIN and largo <= ALTO_ESPERADO * BASTON_ALTO_MAX, "bastón de %.2f u en el juego (de %.2f a %.2f)" % [largo, ALTO_ESPERADO * BASTON_ALTO_MIN, ALTO_ESPERADO * BASTON_ALTO_MAX])
		# Sigue a la mano: la posición del pie del bastón respecto a la mano es la misma en dos instantes distintos del andar.
		var clip_w: String = p.clip_de("walk")
		var largo_w: float = ap.get_animation(clip_w).length
		var rel: Array = []
		for f in [0.1, 0.6]:
			_suela_en(p, sk, ap, clip_w, largo_w * f)
			await process_frame
			var m_glob: Transform3D = sk.global_transform * sk.get_bone_global_pose(mano)
			rel.append(m_glob.affine_inverse() * baston.global_position)
		_ok(((rel[0] as Vector3) - (rel[1] as Vector3)).length() / (alto * p.scale.y) <= BASTON_SIGUE_MANO_TOL, "el bastón sigue a la mano al andar (cambio %.4f)" % (((rel[0] as Vector3) - (rel[1] as Vector3)).length() / (alto * p.scale.y)))
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
