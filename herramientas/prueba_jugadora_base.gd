extends SceneTree
## PRUEBA de la jugadora base (arte/modelos/jugadora_base.glb: Meshy «Willow Fernstep» rigueada en Mixamo, 65 huesos con dedos + headfront, sin clips propios)
## y de su ropa por piezas (ropa_capa_capucha.glb y ropa_tunica.glb, Ropa3D): carga como Pj3D, mide lo que debe, trae los 22 clips de la elfa (chibi_elf, vía
## ClipsFamilia) y cada rol se resuelve igual que en la elfa; pies en el suelo y sin deriva de raíz; las prendas cargan, usan EL MISMO esqueleto y siguen al
## hueso; la capa (~20 000 triángulos) acompaña al brazo; el cuerpo va partido en zonas y cada prenda apaga las suyas al ponerse (pelo, chaleco, cinturón). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_jugadora_base.gd
## Cómo se VE se mira en docs/capturas/jugadora_base/ (herramientas/captura_jugadora_base.gd).

const ID: String = "jugadora_base"
const ALTO_ESPERADO: float = 1.0          ## u de juego (el de ALTO_PJ en PruebaTest2)
const TOL_ALTO: float = 0.05              ## ±5 %
const HUESOS: int = 66                    ## los 65 de Mixamo con dedos + `headfront` (el de Meshy)
const HUESOS_DEDOS_MIN: int = 30          ## dedos de las dos manos (Mixamo: 15 por mano; aquí 16 con el cuarto hueso de cada pulgar y dedo)
const CLIPS_ELFA: Array = ["Anim01a0e90d", "ChargedGroundSlam", "ChargedSpellCast001", "ChargedSpellCast002", "CollectObject", "Dead", "FacePunchReaction", "Idle",
	"Idle002", "MageSoellCast001", "MageSoellCast002", "MageSoellCast003", "OpenDoor", "Readandwrite", "RollDodge", "Running", "StandAndDrink", "StandTalkingAngry",
	"SwimForward", "SwimmingToEdge", "Walk002", "Walking"]
## Roles que el Juego pide y que tienen que existir (los de MINIMOS «heroe» + los de lanzar).
const ROLES_HEROE: Array = ["idle", "walk", "run", "cast", "hit", "death", "roll", "leer", "swim", "cast_proyectil", "cast_corro", "cast_columna", "cast_muro",
	"cast_empuje", "talk", "drink", "pick_up", "walk02"]
const PRENDAS: Array = ["tunica", "capa_capucha"]
const RAIZ_MAX: float = 0.12              ## deriva horizontal máxima de la cadera en idle/andar/correr/cast (fracción del alto del modelo)
const SUELO_IDLE_TOL: float = 0.02
const SUELO_MARCHA_MIN: float = 0.04
const SUELO_MARCHA_HUNDE: float = -0.03
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Ropa: cuánto se mueve (u del modelo) un vértice de la capucha al girar la cabeza, y como mucho uno de la túnica (cadera) al girar solo la cabeza.
const GIRO_CABEZA_GRADOS: float = 50.0
const PESO_CASI_TOTAL: float = 0.99
const PESO_CADERA_MIN: float = 0.6        ## en la túnica las piernas se atenúan y su parte pasa a Hips: pocos vértices llegan a 0,99
const CAPUCHA_MUEVE_MIN: float = 0.05
const TUNICA_QUIETA_MAX: float = 0.002
const CADERA_BAJA: float = 0.30           ## cuánto se baja la cadera (u del modelo) para ver que la túnica la sigue
const TUNICA_MUEVE_MIN: float = 0.1
## Tolerancia de las poses de enlace del Skin de la ropa frente a la pose de reposo del esqueleto (u del modelo): con el reposo puesto, cada vértice vuelve a su sitio.
const ENLACE_TOL: float = 0.002
const PESO_MAX_INFLUENCIAS: int = 4
const TRIS_PRENDA_MIN: int = 7000
## La capa lleva ~20 000 triángulos (con menos, al diezmar una malla hueca salían vetas claras en la capucha) y la túnica ~9 000.
const TRIS_PRENDA_MAX: Dictionary = {"tunica": 12000, "capa_capucha": 22000}
## Zonas del cuerpo (Ropa3D, herramientas/partir_base_zonas.gd) y las que tapa cada prenda puesta.
const ZONAS_CUERPO: Array = ["cabeza", "pelo", "torso", "chaleco", "cinturon", "brazos", "piernas", "botas"]
const ZONAS_TAPADAS_TODAS: Array = ["pelo", "chaleco", "cinturon"]
const ZONAS_TAPADAS_TUNICA: Array = ["chaleco", "cinturon"]
## Capa y brazos: peso mínimo en el brazo de algún vértice del hombro de la capa, y cuánto se aparta (u del modelo) un vértice de la capa al levantar el brazo.
const CAPA_PESO_BRAZO_MIN: float = 0.25
const CAPA_BRAZO_ARRIBA_GRADOS: float = 125.0
const CAPA_SE_APARTA_MIN: float = 0.05

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
	_ok(p.cargar(ID), "jugadora_base carga")
	p.set_alto(ALTO_ESPERADO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_ESPERADO) <= ALTO_ESPERADO * TOL_ALTO, "altura en el juego %.3f (esperada %.2f ±5 %%)" % [p.alto_modelo() * p.scale.y, ALTO_ESPERADO])
	_ok(p.rol_visual == "jugadora", "rol visual «jugadora» (rim): %s" % p.rol_visual)
	var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
	_ok(not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("mixamorig_Hips") >= 0, "esqueleto con huesos mixamorig")
	var sk: Skeleton3D = sks[0] as Skeleton3D
	_ok(sks.size() == 1, "un único esqueleto en el personaje vestido (%d)" % sks.size())
	_ok(sk.get_bone_count() == HUESOS, "%d huesos (%d)" % [HUESOS, sk.get_bone_count()])
	var dedos: int = 0
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).contains("Hand") and sk.get_bone_name(i) != "mixamorig_LeftHand" and sk.get_bone_name(i) != "mixamorig_RightHand":
			dedos += 1
	_ok(dedos >= HUESOS_DEDOS_MIN, "tiene dedos (%d huesos de dedos)" % dedos)
	_ok(sk.find_bone("mixamorig_LeftHandIndex1") >= 0 and sk.find_bone("mixamorig_RightHandThumb3") >= 0, "índice izquierdo y pulgar derecho presentes")
	var ap: AnimationPlayer = p._ap
	_ok(ap != null, "AnimationPlayer con los clips de la familia (%d clips)" % (ap.get_animation_list().size() if ap != null else 0))
	if ap == null:
		_acabar()
		return
	_ok(p._arbol != null, "árbol de animación montado")
	for c in CLIPS_ELFA:
		_ok(ap.has_animation(c), "clip de la elfa «%s» (%.2f s)" % [c, ap.get_animation(c).length if ap.has_animation(c) else 0.0])
	# Los roles se resuelven como en la elfa (el mismo nombre de clip).
	var elfa := Pj3D.new()
	mundo.add_child(elfa)
	elfa.cargar("chibi_elf")
	for r in ROLES_HEROE:
		var c_base: String = p.clip_de(r)
		var c_elfa: String = elfa.clip_de(r)
		_ok(c_base != "" and c_base.to_lower() == c_elfa.to_lower() and p.duracion(r) > 0.0, "rol %s -> %s (elfa: %s, %.2f s)" % [r, c_base, c_elfa, p.duracion(r)])
	elfa.queue_free()
	for r in ["idle", "walk", "run", "cast_proyectil", "talk"]:
		p.jugar(r)
		await process_frame
		_ok(p.animacion_actual == r, "jugar(%s) (actual: %s)" % [r, p.animacion_actual])
	p.jugar("idle")
	await process_frame
	# Pies y raíz, con los clips tal como los reproduce el personaje.
	var alto: float = p.alto_modelo()
	var reposo: float = _suela_min_reposo(sk)
	for r in ["idle", "walk", "run"]:
		var clip: String = p.clip_de(r)
		var an: Animation = ap.get_animation(clip)
		var minimo: float = INF
		var maximo: float = -INF
		for k in 24:
			var y: float = _suela_en(p, sk, ap, clip, an.length * float(k) / 24.0) - reposo
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		print("INFO  %s (%s): suela mínima %.1f %%, máxima %.1f %% del alto" % [r, clip, minimo / alto * 100.0, maximo / alto * 100.0])
		if r == "idle":
			_ok(absf(minimo / alto) <= SUELO_IDLE_TOL and absf(maximo / alto) <= SUELO_IDLE_TOL * 3.0, "idle: pies en el suelo (mín %.3f, máx %.3f del alto)" % [minimo / alto, maximo / alto])
		else:
			_ok(minimo / alto <= SUELO_MARCHA_MIN and minimo / alto >= SUELO_MARCHA_HUNDE, "%s: pisa el suelo sin hundirse (mín %.3f del alto)" % [r, minimo / alto])
	for r in ["idle", "walk", "run", "cast", "hit"]:
		var deriva: float = _deriva_cadera(p, sk, ap, p.clip_de(r)) / alto
		_ok(deriva <= RAIZ_MAX, "%s (%s): deriva de raíz %.3f del alto (tope %.2f)" % [r, p.clip_de(r), deriva, RAIZ_MAX])
	# Clips nuevos de la jugadora (24/10): abrir_cofre, agacharse, ofrecer, saludo, empujar (MedidasClipsJugadora).
	MedidasClipsJugadora.comprobar(p, "jugadora_base", _ok)
	_ok(absf(Pj3D.instante_clip("abrir_cofre") / SecuenciaCofreLegendario3D.velocidad_abrir() - SecuenciaCofreLegendario3D.T_ONDA) < 0.01,
		"cofre legendario: las manos llegan abajo (%.2f s del clip a ×%.2f) justo cuando la tapa gira (T_ONDA %.2f s)" % [Pj3D.instante_clip("abrir_cofre"),
		SecuenciaCofreLegendario3D.velocidad_abrir(), SecuenciaCofreLegendario3D.T_ONDA])
	await _prueba_ropa(p, sk)
	_acabar()


## La ropa por piezas: carga, mismo esqueleto, triángulos, pesos y que siga al hueso.
func _prueba_ropa(p: Pj3D, sk: Skeleton3D) -> void:
	# La armadura del GLB va a escala 100 (el FBX en cm): las posiciones del esqueleto y de las mallas están en 1/100 de unidad del modelo.
	var esc: float = (sk.get_parent() as Node3D).scale.y
	_ok(p.ropa_puesta().size() == PRENDAS.size(), "el personaje carga vestido con %s (puestas: %s)" % [PRENDAS, p.ropa_puesta()])
	for id in PRENDAS:
		var mi: MeshInstance3D = Ropa3D.puesta(p, id)
		_ok(mi != null, "prenda %s puesta" % id)
		if mi == null:
			continue
		_ok(mi.get_node(mi.skeleton) == sk, "%s: su `skeleton` es el esqueleto de la base" % id)
		_ok(mi.get_parent() == sk, "%s: colgada del Skeleton3D de la base" % id)
		var tris: int = _tris(mi.mesh)
		_ok(tris >= TRIS_PRENDA_MIN and tris <= int(TRIS_PRENDA_MAX[id]), "%s: %d triángulos (entre %d y %d)" % [id, tris, TRIS_PRENDA_MIN, int(TRIS_PRENDA_MAX[id])])
		var skin: Skin = mi.skin
		_ok(skin != null, "%s: tiene Skin" % id)
		var hueso_de: Array = _huesos_del_skin(skin, sk)
		_ok(not hueso_de.has(-1), "%s: todos los enlaces del Skin son huesos del esqueleto de la base (mismos nombres)" % id)
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var por_vert: int = bones.size() / maxi(n, 1)
		var peor_suma: float = 0.0
		var max_infl: int = 0
		for v in n:
			var s: float = 0.0
			var cuantos: int = 0
			for k in por_vert:
				var w: float = pesos[v * por_vert + k]
				s += w
				if w > 0.0001:
					cuantos += 1
			peor_suma = maxf(peor_suma, absf(s - 1.0))
			max_infl = maxi(max_infl, cuantos)
		_ok(peor_suma < 0.01, "%s: pesos normalizados (peor desvío de la suma %.4f)" % [id, peor_suma])
		_ok(max_infl <= PESO_MAX_INFLUENCIAS, "%s: máximo %d influencias por vértice" % [id, max_infl])
		# Poses de enlace: con el esqueleto en reposo cada vértice se queda donde está.
		sk.reset_bone_poses()
		var peor_enlace: float = 0.0
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in range(0, n, 7):
			peor_enlace = maxf(peor_enlace, (_piel(sk, skin, hueso_de, bones, pesos, por_vert, v, verts[v]) - verts[v]).length())
		_ok(peor_enlace * esc <= ENLACE_TOL, "%s: en reposo la malla vuelve a su sitio (desvío máx %.5f u del modelo)" % [id, peor_enlace * esc])
	# Sigue al hueso: un vértice de la capucha con peso casi total en la cabeza se mueve con ella; uno de la túnica en la cadera no, y sí con la cadera.
	var capucha: MeshInstance3D = Ropa3D.puesta(p, "capa_capucha")
	var tunica: MeshInstance3D = Ropa3D.puesta(p, "tunica")
	if capucha != null and tunica != null:
		var v_cap: Array = _vertice_de(capucha, sk, "mixamorig_Head", PESO_CASI_TOTAL)
		var v_tun: Array = _vertice_de(tunica, sk, "mixamorig_Hips", PESO_CADERA_MIN)
		_ok(not v_cap.is_empty(), "hay un vértice de la capucha con peso casi total en la cabeza")
		_ok(not v_tun.is_empty(), "hay un vértice de la túnica con la mayor parte del peso en la cadera")
		if not v_cap.is_empty() and not v_tun.is_empty():
			sk.reset_bone_poses()
			var cap0: Vector3 = _posicion(capucha, sk, int(v_cap[0]))
			var tun0: Vector3 = _posicion(tunica, sk, int(v_tun[0]))
			var cab: int = sk.find_bone("mixamorig_Head")
			var base_cab: Quaternion = sk.get_bone_pose_rotation(cab)
			sk.set_bone_pose_rotation(cab, base_cab * Quaternion(Vector3.UP, deg_to_rad(GIRO_CABEZA_GRADOS)))
			var cap1: Vector3 = _posicion(capucha, sk, int(v_cap[0]))
			var tun1: Vector3 = _posicion(tunica, sk, int(v_tun[0]))
			_ok((cap1 - cap0).length() * esc >= CAPUCHA_MUEVE_MIN, "un vértice de la capucha se mueve con la cabeza (%.3f u del modelo al girarla %.0f°)" % [(cap1 - cap0).length() * esc, GIRO_CABEZA_GRADOS])
			_ok((tun1 - tun0).length() * esc <= TUNICA_QUIETA_MAX, "un vértice de la túnica (cadera) no se mueve al girar la cabeza (%.5f u)" % ((tun1 - tun0).length() * esc))
			sk.reset_bone_poses()
			var cad: int = sk.find_bone("mixamorig_Hips")
			sk.set_bone_pose_position(cad, sk.get_bone_rest(cad).origin - Vector3(0, CADERA_BAJA / esc, 0))
			var tun2: Vector3 = _posicion(tunica, sk, int(v_tun[0]))
			_ok((tun2 - tun0).length() * esc >= TUNICA_MUEVE_MIN, "un vértice de la túnica se mueve con la cadera (%.3f u del modelo)" % ((tun2 - tun0).length() * esc))
			sk.reset_bone_poses()
	# La capa acompaña al brazo: algún vértice del hombro pesa en el brazo y al levantarlo se aparta; en reposo, nada (comprobado arriba).
	if capucha != null:
		_prueba_capa_brazos(capucha, sk, esc)
	# Quitar y volver a poner.
	p.quitar_ropa("capa_capucha")
	await process_frame
	_ok(not p.ropa_puesta().has("capa_capucha") and p.ropa_puesta().has("tunica"), "quitar_ropa(capa_capucha) deja solo la túnica (%s)" % [p.ropa_puesta()])
	_ok(p.poner_ropa("capa_capucha") and p.ropa_puesta().size() == 2, "poner_ropa(capa_capucha) la vuelve a poner (%s)" % [p.ropa_puesta()])
	_ok(not p.poner_ropa("no_existe"), "una prenda que no existe no se pone")
	_prueba_zonas(p)


## Zonas ocultas: el cuerpo partido conserva todos los triángulos y cada prenda apaga lo suyo al ponerse y lo devuelve al quitarse.
func _prueba_zonas(p: Pj3D) -> void:
	var c: MeshInstance3D = Ropa3D.cuerpo(p)
	_ok(c != null and c.mesh.get_surface_count() == ZONAS_CUERPO.size(), "el cuerpo vestido está partido en %d superficies (%d)" % [ZONAS_CUERPO.size(), c.mesh.get_surface_count() if c != null else 0])
	if c == null:
		return
	var nombres: Array = []
	var tris: int = 0
	for s in c.mesh.get_surface_count():
		nombres.append(c.mesh.surface_get_name(s))
		tris += (c.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_ok(nombres == ZONAS_CUERPO, "zonas del cuerpo: %s" % [nombres])
	_ok(tris == int(c.mesh.get_meta("triangulos_origen", -1)), "la malla partida conserva los %d triángulos del cuerpo (%d)" % [int(c.mesh.get_meta("triangulos_origen", -1)), tris])
	_ok(_mismos(Ropa3D.zonas_apagadas(p), ZONAS_TAPADAS_TODAS), "con la túnica y la capa puestas se apagan %s (apagadas: %s)" % [ZONAS_TAPADAS_TODAS, Ropa3D.zonas_apagadas(p)])
	p.quitar_ropa("capa_capucha")
	_ok(_mismos(Ropa3D.zonas_apagadas(p), ZONAS_TAPADAS_TUNICA), "sin la capa vuelve el pelo y solo la túnica tapa %s (apagadas: %s)" % [ZONAS_TAPADAS_TUNICA, Ropa3D.zonas_apagadas(p)])
	p.quitar_ropa("tunica")
	_ok(Ropa3D.zonas_apagadas(p).is_empty(), "sin prendas no se apaga ninguna zona (apagadas: %s)" % [Ropa3D.zonas_apagadas(p)])
	p.poner_ropa("capa_capucha")
	_ok(_mismos(Ropa3D.zonas_apagadas(p), ["pelo"]), "solo la capa apaga el pelo (apagadas: %s)" % [Ropa3D.zonas_apagadas(p)])
	p.poner_ropa("tunica")
	_ok(_mismos(Ropa3D.zonas_apagadas(p), ZONAS_TAPADAS_TODAS), "volver a vestirse las apaga otra vez (apagadas: %s)" % [Ropa3D.zonas_apagadas(p)])


func _mismos(a: Array, b: Array) -> bool:
	var x: Array = a.duplicate()
	var y: Array = b.duplicate()
	x.sort()
	y.sort()
	return x == y


func _prueba_capa_brazos(capa: MeshInstance3D, sk: Skeleton3D, esc: float) -> void:
	var arr: Array = capa.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var por_vert: int = bones.size() / verts.size()
	var hueso_de: Array = _huesos_del_skin(capa.skin, sk)
	var brazo: int = sk.find_bone("mixamorig_LeftArm")
	var con_peso: int = 0
	var candidato: int = -1
	var mejor: float = 0.0
	for v in verts.size():
		var w: float = 0.0
		for k in por_vert:
			if int(hueso_de[bones[v * por_vert + k]]) == brazo:
				w += pesos[v * por_vert + k]
		if w >= CAPA_PESO_BRAZO_MIN:
			con_peso += 1
		if w > mejor:
			mejor = w
			candidato = v
	_ok(con_peso > 0, "la capa tiene %d vértices con al menos %.2f de peso en el brazo izquierdo (máx %.2f)" % [con_peso, CAPA_PESO_BRAZO_MIN, mejor])
	if candidato < 0:
		return
	sk.reset_bone_poses()
	var antes: Vector3 = _posicion(capa, sk, candidato)
	var b: Quaternion = sk.get_bone_pose_rotation(brazo)
	sk.set_bone_pose_rotation(brazo, b * Quaternion(Vector3.BACK, deg_to_rad(CAPA_BRAZO_ARRIBA_GRADOS)))
	var despues: Vector3 = _posicion(capa, sk, candidato)
	var mueve: float = (despues - antes).length() * esc
	_ok(mueve >= CAPA_SE_APARTA_MIN, "al levantar el brazo %.0f° la capa se aparta %.3f u del modelo (mín %.2f)" % [CAPA_BRAZO_ARRIBA_GRADOS, mueve, CAPA_SE_APARTA_MIN])
	sk.reset_bone_poses()


func _acabar() -> void:
	print("RESULTADO jugadora_base · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _tris(m: Mesh) -> int:
	var t: int = 0
	for s in m.get_surface_count():
		var ar: Array = m.surface_get_arrays(s)
		t += (ar[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return t


## Hueso del esqueleto de cada enlace del Skin (-1 si el nombre no existe).
func _huesos_del_skin(skin: Skin, sk: Skeleton3D) -> Array:
	var res: Array = []
	for b in skin.get_bind_count():
		var nombre: String = skin.get_bind_name(b)
		if nombre == "" and skin.get_bind_bone(b) >= 0:
			res.append(skin.get_bind_bone(b))
		else:
			res.append(sk.find_bone(nombre))
	return res


## Posición del vértice `v` de `mi` con el esqueleto como esté (piel por software con las poses de enlace del Skin).
func _posicion(mi: MeshInstance3D, sk: Skeleton3D, v: int) -> Vector3:
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var por_vert: int = bones.size() / verts.size()
	return _piel(sk, mi.skin, _huesos_del_skin(mi.skin, sk), bones, pesos, por_vert, v, verts[v])


func _piel(sk: Skeleton3D, skin: Skin, hueso_de: Array, bones: PackedInt32Array, pesos: PackedFloat32Array, por_vert: int, v: int, pos: Vector3) -> Vector3:
	var res := Vector3.ZERO
	for k in por_vert:
		var w: float = pesos[v * por_vert + k]
		if w <= 0.0:
			continue
		var b: int = bones[v * por_vert + k]
		var xf: Transform3D = sk.get_bone_global_pose(int(hueso_de[b])) * skin.get_bind_pose(b)
		res += (xf * pos) * w
	return res


## [índice de vértice] del primer vértice de la prenda con peso >= `minimo` en el hueso `hueso`, o [].
func _vertice_de(mi: MeshInstance3D, sk: Skeleton3D, hueso: String, minimo: float) -> Array:
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var por_vert: int = bones.size() / n
	var hueso_de: Array = _huesos_del_skin(mi.skin, sk)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var centro: Vector3 = sk.get_bone_global_rest(sk.find_bone(hueso)).origin
	var mejor: int = -1
	var lejos: float = -1.0
	# El más alejado del eje vertical del hueso: el que más se nota al girarlo.
	for v in n:
		for k in por_vert:
			if pesos[v * por_vert + k] >= minimo and int(hueso_de[bones[v * por_vert + k]]) == sk.find_bone(hueso):
				var d: float = Vector2(verts[v].x - centro.x, verts[v].z - centro.z).length()
				if d > lejos:
					lejos = d
					mejor = v
	return [mejor] if mejor >= 0 else []


func _suela_min_reposo(sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_rest(i).origin.y)
	return m


## Máxima distancia horizontal (u del modelo) de la cadera a su posición en t = 0, a lo largo del clip.
func _deriva_cadera(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	var h: int = sk.find_bone("mixamorig_Hips")
	var largo: float = ap.get_animation(clip).length
	_suela_en(p, sk, ap, clip, 0.0)
	var o: Vector3 = sk.get_bone_global_pose(h).origin
	var m: float = 0.0
	for k in range(1, 25):
		_suela_en(p, sk, ap, clip, largo * float(k) / 25.0)
		var q: Vector3 = sk.get_bone_global_pose(h).origin
		m = maxf(m, Vector2(q.x - o.x, q.z - o.z).length())
	return m


## Altura (espacio del esqueleto, u del modelo) del hueso de suela más bajo con el clip en `t`.
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
				m = minf(m, sk.get_bone_global_pose(i).origin.y)
	return m
