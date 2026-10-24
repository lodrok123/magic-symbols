extends SceneTree
## PRUEBA de la forma de la capa y la capucha de la jugadora base (arte/modelos/ropa_capa.glb, ropa_capucha.glb; salen de herramientas/rig/encajar_ropa.py con
## herramientas/rig/ropa_jugadora_base.json y herramientas/montar_ropa_glb.gd). El concept y arte/meshy/PROMPTS_JUGADORA_BASE.md §2a piden una capelina que cubre
## hombros y brazos, TERMINA EN EL CODO y abre hacia abajo, y una capucha pegada a la cabeza. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ropa_capa.gd
## Todas las medidas en unidades del modelo (la coronilla a 1,70; las mallas y el esqueleto del .glb van en centésimas: se multiplican por la escala de la armadura).
## (a) el borde de la capa a la altura del codo en los 8 sectores de ángulo (delante, lados y detrás); (b) el borde, más ancho que los brazos a esa altura; (c) la capa abre hacia abajo (más ancha en el borde que
## a la altura del hueso Neck); (d) la capucha no sobresale por encima ni por detrás de la cabeza;
## (e) en reposo ningún vértice de la capa ni de la capucha queda dentro del cuerpo SIN EL PELO (la zona `pelo` de Ropa3D, que la capucha apaga): el cuerpo se pasa
## a vóxeles y se rellena desde fuera; un vértice en un vóxel cerrado está dentro, y uno junto a la superficie si su distancia con signo al triángulo más cercano
## (normal interpolada de los vértices) es negativa. Las orejas atraviesan la capucha a propósito (OREJA_X / OREJA_Z de encajar_ropa.py). Con el pelo (vóxeles del
## cuerpo entero y el lado de dentro de las tiras) solo se informa: el pelo son tiras dobles y el signo de su normal no dice dentro o fuera; y en las poses de
## docs/PLAN_RIGGING.md §3 (las de captura_jugadora_base.gd) y en 3 fotogramas de cada clip de RODAJE, con los clips reales del personaje (Pj3D), el borde de la
## capa no atraviesa ningún antebrazo (distancia con signo a la piel del antebrazo puesta en la pose), con los muelles de la capa apagados (en reposo);
## (f) con los muelles (CapaMuelles3D) en marcha y los clips reproduciéndose: el borde no entra más de 5 mm en el cuerpo, se mece al correr y vuelve a su sitio
## en idle, y el coste por fotograma. Cuesta ~40 s sin ventana.

const CAPTURA := preload("res://herramientas/captura_jugadora_base.gd")
const GLB_CAPA: String = "res://arte/modelos/ropa_capa.glb"
const GLB_CAPUCHA: String = "res://arte/modelos/ropa_capucha.glb"
const GLB_BASE: String = "res://arte/modelos/jugadora_base.glb"
const ZONAS: String = "res://arte/modelos/jugadora_base_zonas.res"
## (a) el borde de la capa, a la altura del codo (LeftForeArm a 0,896) en TODO el contorno: en cada uno de los 8 sectores de ángulo (el centro es el de la banda
## de BANDA_CENTRO por encima del punto más bajo).
## Abajo, 0,86: con la cámara del juego el borde tiene que quedar sobre el cinturón (Hips a 0,867) sin taparlo (Pablo, 24/10).
const BORDE_MIN: float = 0.86
const BORDE_MAX: float = 0.91
const SECTORES: Array = ["delante", "delante-izquierda", "izquierda", "detrás-izquierda", "detrás", "detrás-derecha", "derecha", "delante-derecha"]
const BANDA_CENTRO: float = 0.06
## (b) la banda del borde son los 4 cm por encima del punto más bajo (lo que va de un sector a otro).
const BANDA_BORDE: float = 0.04
const HOLGURA_BRAZOS: float = 0.02
## (c) la anchura a la altura del cuello se mide en ±1 cm alrededor del hueso Neck.
const MEDIA_BANDA_CUELLO: float = 0.01
## (d) capucha.
const CAPUCHA_CIMA_MAX: float = 1.73
const CAPUCHA_NUCA_Z_MIN: float = -0.36
## (e) en reposo: vóxeles de 1 cm, zona del pelo y orejas (ejes de Godot: la Z de Blender es aquí la Y).
const VOXEL: float = 0.01
const ZONA_PELO: String = "pelo"
const OREJA_X: float = 0.27
const OREJA_Y: float = 1.30
## Rejilla de triángulos para el más cercano.
const CELDA: float = 0.03
## Capas de celdas que se miran como mucho alrededor de un punto (×CELDA = 1,2 u del modelo: más que cualquier distancia de la ropa al cuerpo).
const CAPAS_MAX: int = 40
## Bandas de altura del informe de vértices dentro.
const BANDA_INFORME: float = 0.05
## (e) en movimiento: la piel del antebrazo son los triángulos del cuerpo cuyos tres vértices pesan al menos PESO_ANTEBRAZO en ForeArm; un vértice del borde de
## la capa está dentro si su distancia con signo a esa piel es negativa y está a menos de RADIO_ANTEBRAZO_MAX (más lejos, el signo de un parche abierto no vale).
const PESO_ANTEBRAZO: float = 0.5
const RADIO_ANTEBRAZO_MAX: float = 0.07
## Vértices del borde de la capa que se miran: hasta 8 cm por encima del punto más bajo (de la espalda a la delantera).
const ALTO_HEM: float = 0.08
const LADOS: Array = ["Left", "Right"]
## Poses de PLAN_RIGGING §3 (en captura_jugadora_base.gd) y clips reales del personaje, 3 fotogramas cada uno (el cast es el de lanzar al frente).
const POSES_PLAN: Array = ["brazos_arriba", "sentadilla", "zancada", "giro_cintura", "cabeza_izquierda", "cabeza_derecha"]
const RODAJE: Array = ["cast_proyectil", "idle", "walk", "run"]
const FOTOGRAMAS: Array = [0.2, 0.5, 0.8]
## (f) muelles de la capa (CapaMuelles3D) con los clips reproduciéndose a FPS.
const CLIPS_MUELLES: Array = ["idle", "walk", "run", "cast_proyectil", "roll"]
const MUESTRAS_CLIP: int = 5
const FPS: float = 30.0
const ZONAS_CHOQUE: Array = ["torso", "chaleco", "cinturon", "brazos", "piernas"]
const PENETRACION_MAX: float = 0.005
const MECE_MIN: float = 0.01
const IDLE_ASENTAR: float = 2.0
const REPOSO_TOL: float = 0.01
const MEDIR_FOTOGRAMAS: int = 60

var _fallos: int = 0
## Triángulos del cuerpo (u del modelo): vértices, normales de los vértices (hacia fuera), zona; y la rejilla celda -> índices de triángulo.
var _rejilla: Dictionary = {}
var _ta := PackedVector3Array()
var _tb := PackedVector3Array()
var _tc := PackedVector3Array()
var _na := PackedVector3Array()
var _nb := PackedVector3Array()
var _nc := PackedVector3Array()
var _tzona := PackedStringArray()
var _visto := PackedInt32Array()
var _sello: int = 0
## (f) dónde está el vértice que más entra en el cuerpo (para el mensaje).
var _peor_donde: String = ""
## Vóxeles del cuerpo: 0 cerrado (dentro), 1 superficie, 2 fuera.
var _vox := PackedByteArray()
var _vox_origen := Vector3.ZERO
var _vox_n := Vector3i.ZERO


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	var base: Node = (load(GLB_BASE) as PackedScene).instantiate()
	var sk_b: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var esc: float = (sk_b.get_parent() as Node3D).scale.y
	var capa: PackedVector3Array = _vertices(GLB_CAPA, esc)
	var capucha: PackedVector3Array = _vertices(GLB_CAPUCHA, esc)
	var zonas: ArrayMesh = load(ZONAS) as ArrayMesh
	var cuerpo := PackedVector3Array()
	for s in zonas.get_surface_count():
		for v in (zonas.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			cuerpo.append(v * esc)
	_ok(capa.size() > 0 and capucha.size() > 0 and cuerpo.size() > 0, "cargan la capa (%d vértices), la capucha (%d) y el cuerpo por zonas (%d)" % [capa.size(), capucha.size(), cuerpo.size()])
	if capa.is_empty() or capucha.is_empty() or cuerpo.is_empty():
		_acabar()
		return
	# (a) el borde, a la altura del codo en todo el contorno: el punto más bajo de la capa en cada sector de ángulo alrededor del centro del borde
	var borde: float = INF
	for v in capa:
		borde = minf(borde, v.y)
	var codo: float = (sk_b.get_bone_global_rest(sk_b.find_bone("mixamorig_LeftForeArm")).origin * esc).y
	var alturas: Array = _borde_por_sector(capa, borde)
	for s in SECTORES.size():
		_ok(float(alturas[s]) >= BORDE_MIN and float(alturas[s]) <= BORDE_MAX, "(a) borde de la capa %s a %.3f (entre %.2f y %.2f; codo a %.3f)" % [SECTORES[s],
			float(alturas[s]), BORDE_MIN, BORDE_MAX, codo])
	# (b) borde frente a los brazos
	var ancho_borde: float = _ancho(capa, borde, borde + BANDA_BORDE)
	var ancho_brazos: float = _ancho(cuerpo, borde, borde + BANDA_BORDE)
	_ok(ancho_borde >= ancho_brazos + HOLGURA_BRAZOS, "(b) borde de la capa %.3f de ancho, brazos %.3f a esa altura (+%.2f): sobra %.3f" % [ancho_borde, ancho_brazos,
		HOLGURA_BRAZOS, ancho_borde - ancho_brazos])
	# (c) abre hacia abajo
	var y_cuello: float = (sk_b.get_bone_global_rest(sk_b.find_bone("mixamorig_Neck")).origin * esc).y
	var ancho_cuello: float = _ancho(capa, y_cuello - MEDIA_BANDA_CUELLO, y_cuello + MEDIA_BANDA_CUELLO)
	_ok(ancho_borde > ancho_cuello, "(c) la capa abre hacia abajo: %.3f en el borde > %.3f a la altura del cuello (y %.3f)" % [ancho_borde, ancho_cuello, y_cuello])
	# (d) capucha
	var cima: float = -INF
	var nuca: float = INF
	for v in capucha:
		cima = maxf(cima, v.y)
		nuca = minf(nuca, v.z)
	var coronilla: float = (sk_b.get_bone_global_rest(sk_b.find_bone("mixamorig_HeadTop_End")).origin * esc).y
	_ok(cima <= CAPUCHA_CIMA_MAX, "(d) cima de la capucha %.3f (máx %.2f; coronilla %.3f)" % [cima, CAPUCHA_CIMA_MAX, coronilla])
	_ok(nuca >= CAPUCHA_NUCA_Z_MIN, "(d) la capucha llega por detrás a z %.3f (mín %.2f)" % [nuca, CAPUCHA_NUCA_Z_MIN])
	# (e) en reposo, nada dentro del cuerpo
	var t0: int = Time.get_ticks_msec()
	# Sin el pelo (lo apaga la capucha): es lo que se ve con el traje completo. Cuenta.
	_montar_rejilla(zonas, esc, [ZONA_PELO])
	_voxelizar()
	for par in [["capa", capa], ["capucha", capucha]]:
		var r: Dictionary = _dentro(par[1] as PackedVector3Array)
		_ok(int(r["hondo"]) + int(r["piel"]) == 0, "(e) %s en reposo: %d vértices dentro del cuerpo sin el pelo (%d en vóxeles cerrados, %d bajo la piel; distancia con signo mínima junto a la piel %.4f; %d junto a las orejas, fuera de la cuenta)" % [
			par[0], int(r["hondo"]) + int(r["piel"]), int(r["hondo"]), int(r["piel"]), float(r["minima"]), int(r["orejas"])])
		if int(r["hondo"]) + int(r["piel"]) > 0:
			print("INFO  %s: vértices dentro por altura (bandas de %.2f): %s; por la zona más cercana: %s" % [par[0], BANDA_INFORME, r["por_altura"], r["por_zona"]])
	# Con el pelo: el volumen cerrado del pelo y la cabeza, y el lado de dentro de las tiras. Solo aviso (el pelo son tiras dobles y la capucha lo apaga).
	_montar_rejilla(zonas, esc, [])
	_voxelizar()
	for par in [["capa", capa], ["capucha", capucha]]:
		var r: Dictionary = _dentro(par[1] as PackedVector3Array)
		print("INFO  %s con el pelo: %d vértices en vóxeles cerrados (por altura %s) y %d por el lado de dentro de una tira de pelo (aviso, no cuenta)" % [par[0],
			int(r["hondo"]), r["por_altura"], int(r["pelo"])])
	print("INFO  vóxeles y distancias con signo en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	base.free()
	await _prueba_antebrazos()
	_acabar()


## (e) en movimiento: con el personaje vestido (Pj3D), el borde de la capa no se mete en ningún antebrazo en las poses del plan ni en los clips.
func _prueba_antebrazos() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar("jugadora_base") and Ropa3D.puesta(p, "capa") != null, "jugadora_base carga vestida con la capa")
	await process_frame
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var esc: float = (sk.get_parent() as Node3D).scale.y
	var capa: MeshInstance3D = Ropa3D.puesta(p, "capa")
	var cuerpo: MeshInstance3D = Ropa3D.cuerpo(p)
	var muelles: CapaMuelles3D = Ropa3D.muelles(p, "capa")
	_ok(muelles != null, "la capa lleva su simulador de muelles (CapaMuelles3D)")
	# (e) es la capa con el muelle en reposo (las cadenas en su pose de enlace): el simulador se apaga y se enciende para (f).
	if muelles != null:
		muelles.active = false
	_quieto(p, sk)
	var casos: Array = [["reposo"]]
	for pose in CAPTURA.POSES:
		if POSES_PLAN.has(String(pose[0])):
			casos.append(["pose", pose])
	for rol in RODAJE:
		for f in FOTOGRAMAS:
			casos.append(["clip", rol, f])
	var malla_capa: Dictionary = _malla_con_piel(capa, sk, 0)
	var verts: PackedVector3Array = malla_capa["v"]
	var borde: float = INF
	for v in verts:
		borde = minf(borde, v.y * esc)
	var hem := PackedInt32Array()
	for v in verts.size():
		if verts[v].y * esc <= borde + ALTO_HEM:
			hem.append(v)
	# Piel de los antebrazos: triángulos del cuerpo con los tres vértices en ForeArm.
	var antebrazos: Array = []
	for s in cuerpo.mesh.get_surface_count():
		var m: Dictionary = _malla_con_piel(cuerpo, sk, s)
		var tris := PackedInt32Array()
		for lado in LADOS:
			var fa: int = sk.find_bone("mixamorig_%sForeArm" % lado)
			var idx: PackedInt32Array = m["i"]
			for t in range(0, idx.size(), 3):
				if _peso_en(m, idx[t], fa) >= PESO_ANTEBRAZO and _peso_en(m, idx[t + 1], fa) >= PESO_ANTEBRAZO and _peso_en(m, idx[t + 2], fa) >= PESO_ANTEBRAZO:
					tris.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if not tris.is_empty():
			m["tris"] = tris
			antebrazos.append(m)
	var n_tris: int = 0
	for m in antebrazos:
		n_tris += (m["tris"] as PackedInt32Array).size() / 3
	_ok(n_tris > 0, "piel de los antebrazos: %d triángulos; %d vértices del borde de la capa (hasta %.2f por encima de %.3f)" % [n_tris, hem.size(), ALTO_HEM, borde])
	var t0: int = Time.get_ticks_msec()
	for caso in casos:
		var nombre: String = "reposo"
		if caso[0] == "reposo":
			_quieto(p, sk)
		elif caso[0] == "pose":
			_quieto(p, sk)
			_aplicar_pose(sk, caso[1] as Array)
			nombre = "pose %s" % caso[1][0]
		else:
			var clip: String = p.clip_de(String(caso[1]))
			p._ap.active = true
			p._ap.play(clip)
			p._ap.seek(p._ap.get_animation(clip).length * float(caso[2]), true)
			p._ap.pause()
			nombre = "clip %s (%s) al %d %%" % [caso[1], clip, int(float(caso[2]) * 100.0)]
		sk.force_update_all_bone_transforms()
		# la piel de los antebrazos puesta en la pose, en u del modelo
		_limpiar_triangulos()
		for m in antebrazos:
			var xf: Array = _transformadas(m, sk)
			var idx: PackedInt32Array = m["tris"]
			for t in range(0, idx.size(), 3):
				var pa: Vector3 = _posar(m, xf, idx[t]) * esc
				var pb: Vector3 = _posar(m, xf, idx[t + 1]) * esc
				var pc: Vector3 = _posar(m, xf, idx[t + 2]) * esc
				_anadir_triangulo(pa, pb, pc, _posar_normal(m, xf, idx[t]), _posar_normal(m, xf, idx[t + 1]), _posar_normal(m, xf, idx[t + 2]), "antebrazo")
		_preparar_busqueda()
		var xf_capa: Array = _transformadas(malla_capa, sk)
		var dentro: int = 0
		var peor: float = INF
		var peor_v: int = -1
		for v in hem:
			var q: Vector3 = _posar(malla_capa, xf_capa, v) * esc
			var r: Array = _mas_cercano(q, RADIO_ANTEBRAZO_MAX)
			if int(r[1]) < 0:
				continue
			var s: float = (q - (r[0] as Vector3)).dot(_normal_en(int(r[1]), r[0]))
			if s < peor:
				peor = s
				peor_v = v
			if s < 0.0:
				dentro += 1
		_ok(dentro == 0, "(e) %s: el borde de la capa no entra en los antebrazos (%d vértices dentro; distancia con signo mínima a su piel %s%s)" % [nombre, dentro,
			"%.3f" % peor if peor < INF else "> %.2f" % RADIO_ANTEBRAZO_MAX, ", el vértice está en reposo en %s" % (verts[peor_v] * esc) if dentro > 0 else ""])
	print("INFO  %d poses y fotogramas en %.1f s" % [casos.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if muelles != null:
		await _prueba_muelles(p, sk, muelles, malla_capa, hem, cuerpo, esc)
	p.queue_free()


## (f) con los muelles en marcha y los clips reproduciéndose de verdad (fotogramas a 30 por segundo): (i) el borde no entra más de PENETRACION_MAX en el cuerpo
## (sin cabeza, pelo ni botas: brazos, torso, chaleco, cinturón y piernas); (ii) al correr el borde se mece respecto a Spine2 al menos MECE_MIN entre
## fotogramas mirados; (iii) tras IDLE_ASENTAR s de idle vuelve a ±REPOSO_TOL del reposo. Y el coste del simulador por fotograma.
func _prueba_muelles(p: Pj3D, sk: Skeleton3D, muelles: CapaMuelles3D, malla_capa: Dictionary, hem: PackedInt32Array, cuerpo: MeshInstance3D, esc: float) -> void:
	var zonas: Array = []
	for s in cuerpo.mesh.get_surface_count():
		if ZONAS_CHOQUE.has(String(cuerpo.mesh.surface_get_name(s))):
			var mz: Dictionary = _malla_con_piel(cuerpo, sk, s)
			mz["zona"] = String(cuerpo.mesh.surface_get_name(s))
			zonas.append(mz)
	var spine2: int = sk.find_bone("mixamorig_Spine2")
	_quieto(p, sk)
	muelles.active = false
	sk.force_update_all_bone_transforms()
	var reposo: PackedVector3Array = _borde_en_spine2(sk, spine2, malla_capa, hem, esc)
	muelles.active = true
	for rol in CLIPS_MUELLES:
		var clip: String = p.clip_de(String(rol))
		if clip == "":
			_ok(false, "(f) el rol %s tiene clip" % rol)
			continue
		_quieto(p, sk)
		muelles.reset()
		p._ap.active = true
		p._ap.play(clip)
		var largo: float = p._ap.get_animation(clip).length
		var fotos: int = maxi(1, int(largo * FPS))
		var peor_pen: float = 0.0
		var donde: String = ""
		var mece: float = 0.0
		var anterior := PackedVector3Array()
		for k in MUESTRAS_CLIP:
			var hasta: int = int(float(fotos) * float(k + 1) / float(MUESTRAS_CLIP + 1))
			while int(p._ap.current_animation_position * FPS) < hasta and p._ap.is_playing():
				await process_frame
			# los modificadores del esqueleto solo valen durante su actualización: se mide al emitir skeleton_updated
			await sk.skeleton_updated
			var pen: float = _penetracion(sk, zonas, malla_capa, hem, esc)
			if pen > peor_pen:
				peor_pen = pen
				donde = "%s, al %d %%" % [_peor_donde, int(100.0 * float(k + 1) / float(MUESTRAS_CLIP + 1))]
			var ahora: PackedVector3Array = _borde_en_spine2(sk, spine2, malla_capa, hem, esc)
			if not anterior.is_empty():
				var media: float = 0.0
				for i in ahora.size():
					media += (ahora[i] - anterior[i]).length()
				mece = maxf(mece, media / ahora.size())
			anterior = ahora
		_ok(peor_pen <= PENETRACION_MAX, "(f-i) %s (%s), %d fotogramas: el borde entra como mucho %.4f en el cuerpo y los brazos (máx %.3f)%s" % [rol, clip, MUESTRAS_CLIP,
			peor_pen, PENETRACION_MAX, ": " + donde if peor_pen > PENETRACION_MAX else ""])
		if rol == "run":
			_ok(mece >= MECE_MIN, "(f-ii) al correr el borde se mece respecto a Spine2: %.4f de media entre fotogramas (mín %.2f)" % [mece, MECE_MIN])
	# (iii) idle un rato y comparar con el reposo
	_quieto(p, sk)
	muelles.reset()
	p._ap.active = true
	p._ap.play(p.clip_de("idle"))
	for i in int(IDLE_ASENTAR * FPS):
		await process_frame
	var t_con: float = await _ms_por_fotograma(MEDIR_FOTOGRAMAS)
	var desvio: float = 0.0
	await sk.skeleton_updated
	var en_idle: PackedVector3Array = _borde_en_spine2(sk, spine2, malla_capa, hem, esc)
	# el idle mueve los brazos: se compara con el idle sin muelles en el mismo instante
	var t_clip: float = p._ap.current_animation_position
	muelles.active = false
	p._ap.seek(t_clip, true)
	await sk.skeleton_updated
	var sin_muelles: PackedVector3Array = _borde_en_spine2(sk, spine2, malla_capa, hem, esc)
	var t_sin: float = await _ms_por_fotograma(MEDIR_FOTOGRAMAS)
	for i in en_idle.size():
		desvio = maxf(desvio, (en_idle[i] - sin_muelles[i]).length())
	_ok(desvio <= REPOSO_TOL, "(f-iii) tras %.0f s de idle el borde está a %.4f de su sitio sin muelles (máx %.2f)" % [IDLE_ASENTAR, desvio, REPOSO_TOL])
	print("INFO  coste: %.3f ms por fotograma con los muelles y %.3f sin ellos (diferencia %.3f ms)" % [t_con, t_sin, t_con - t_sin])
	muelles.active = true


func _ms_por_fotograma(n: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in n:
		await process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / n


## Posiciones (u del modelo) de los vértices del borde en el espacio de Spine2.
func _borde_en_spine2(sk: Skeleton3D, spine2: int, malla_capa: Dictionary, hem: PackedInt32Array, esc: float) -> PackedVector3Array:
	var inv: Transform3D = sk.get_bone_global_pose(spine2).affine_inverse()
	var xf: Array = _transformadas(malla_capa, sk)
	var res := PackedVector3Array()
	for v in hem:
		res.append((inv * _posar(malla_capa, xf, v)) * esc)
	return res


## Lo más que entra un vértice del borde en el cuerpo puesto en la pose (distancia con signo negativa a menos de RADIO_ANTEBRAZO_MAX de la piel).
func _penetracion(sk: Skeleton3D, zonas: Array, malla_capa: Dictionary, hem: PackedInt32Array, esc: float) -> float:
	var xf_capa: Array = _transformadas(malla_capa, sk)
	var pts := PackedVector3Array()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in hem:
		var q: Vector3 = _posar(malla_capa, xf_capa, v) * esc
		pts.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	lo -= Vector3.ONE * RADIO_ANTEBRAZO_MAX
	hi += Vector3.ONE * RADIO_ANTEBRAZO_MAX
	_limpiar_triangulos()
	for m in zonas:
		var xf: Array = _transformadas(m, sk)
		var vs: PackedVector3Array = m["v"]
		var puesto := PackedVector3Array()
		puesto.resize(vs.size())
		var cerca := PackedByteArray()
		cerca.resize(vs.size())
		for i in vs.size():
			puesto[i] = _posar(m, xf, i) * esc
			cerca[i] = 1 if (puesto[i].x >= lo.x and puesto[i].y >= lo.y and puesto[i].z >= lo.z and puesto[i].x <= hi.x and puesto[i].y <= hi.y and puesto[i].z <= hi.z) else 0
		var idx: PackedInt32Array = m["i"]
		for t in range(0, idx.size(), 3):
			if cerca[idx[t]] == 0 and cerca[idx[t + 1]] == 0 and cerca[idx[t + 2]] == 0:
				continue
			_anadir_triangulo(puesto[idx[t]], puesto[idx[t + 1]], puesto[idx[t + 2]], _posar_normal(m, xf, idx[t]), _posar_normal(m, xf, idx[t + 1]),
				_posar_normal(m, xf, idx[t + 2]), String(m["zona"]))
	_preparar_busqueda()
	var peor: float = 0.0
	for i in pts.size():
		var r: Array = _mas_cercano(pts[i], RADIO_ANTEBRAZO_MAX)
		if int(r[1]) < 0:
			continue
		var s: float = (pts[i] - (r[0] as Vector3)).dot(_normal_en(int(r[1]), r[0]))
		if -s > peor:
			peor = -s
			_peor_donde = "vértice %d (reposo %s) en %s" % [hem[i], (malla_capa["v"] as PackedVector3Array)[hem[i]] * esc, _tzona[int(r[1])]]
	return peor


## Reposo del esqueleto sin árbol ni clips (como captura_jugadora_base.gd).
func _quieto(p: Pj3D, sk: Skeleton3D) -> void:
	if p._arbol != null:
		p._arbol.active = false
	p._ap.active = false
	p._ap.stop()
	if p.proporcion != null:
		p.proporcion.set_process(false)
	sk.reset_bone_poses()


## Los giros de una pose de captura_jugadora_base.gd, igual que allí (espacio del modelo, de la raíz a las hojas; bajada de cadera en centésimas).
func _aplicar_pose(sk: Skeleton3D, pose: Array) -> void:
	for g in (pose[1] as Array):
		var i: int = sk.find_bone("mixamorig_" + String(g[0]))
		if i < 0:
			continue
		var eje: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[String(g[1])]
		var actual: Basis = sk.get_bone_global_pose(i).basis
		var padre: int = sk.get_bone_parent(i)
		var padre_b: Basis = sk.get_bone_global_pose(padre).basis if padre >= 0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(i, (padre_b.inverse() * Basis(Quaternion(eje, deg_to_rad(float(g[2])))) * actual).orthonormalized().get_rotation_quaternion())
	var h: int = sk.find_bone("mixamorig_Hips")
	if float(pose[2]) > 0.0:
		sk.set_bone_pose_position(h, sk.get_bone_rest(h).origin - Vector3(0, float(pose[2]) / (sk.get_parent() as Node3D).scale.y, 0))


## Una superficie de una malla con piel: vértices, normales, índices, huesos, pesos y a qué hueso del esqueleto va cada enlace del Skin.
func _malla_con_piel(mi: MeshInstance3D, sk: Skeleton3D, s: int) -> Dictionary:
	var arr: Array = mi.mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	return {"v": v, "n": arr[Mesh.ARRAY_NORMAL], "i": arr[Mesh.ARRAY_INDEX], "b": bones, "w": arr[Mesh.ARRAY_WEIGHTS],
		"por": bones.size() / maxi(v.size(), 1), "skin": mi.skin, "hueso": _huesos_del_skin(mi.skin, sk)}


func _peso_en(m: Dictionary, v: int, hueso: int) -> float:
	var w: float = 0.0
	for k in int(m["por"]):
		if int((m["hueso"] as Array)[(m["b"] as PackedInt32Array)[v * int(m["por"]) + k]]) == hueso:
			w += (m["w"] as PackedFloat32Array)[v * int(m["por"]) + k]
	return w


func _transformadas(m: Dictionary, sk: Skeleton3D) -> Array:
	var xf: Array = []
	var skin: Skin = m["skin"]
	for b in skin.get_bind_count():
		xf.append(sk.get_bone_global_pose(int((m["hueso"] as Array)[b])) * skin.get_bind_pose(b))
	return xf


func _posar(m: Dictionary, xf: Array, v: int) -> Vector3:
	var res := Vector3.ZERO
	var por: int = m["por"]
	for k in por:
		var w: float = (m["w"] as PackedFloat32Array)[v * por + k]
		if w > 0.0:
			res += ((xf[(m["b"] as PackedInt32Array)[v * por + k]] as Transform3D) * (m["v"] as PackedVector3Array)[v]) * w
	return res


func _posar_normal(m: Dictionary, xf: Array, v: int) -> Vector3:
	var res := Vector3.ZERO
	var por: int = m["por"]
	for k in por:
		var w: float = (m["w"] as PackedFloat32Array)[v * por + k]
		if w > 0.0:
			res += ((xf[(m["b"] as PackedInt32Array)[v * por + k]] as Transform3D).basis * (m["n"] as PackedVector3Array)[v]) * w
	return res.normalized()


func _vertices(ruta: String, esc: float) -> PackedVector3Array:
	var res := PackedVector3Array()
	var n: Node = (load(ruta) as PackedScene).instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				res.append(v * esc)
	n.free()
	return res


## Altura del borde en cada sector de SECTORES (el vértice más bajo de la capa en ese ángulo), alrededor del centro en X/Z de la banda del borde.
func _borde_por_sector(pts: PackedVector3Array, borde: float) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		if p.y <= borde + BANDA_CENTRO:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	var centro: Vector2 = (lo + hi) * 0.5
	var res: Array = []
	res.resize(SECTORES.size())
	res.fill(INF)
	for p in pts:
		# 0 = delante (+Z), creciendo hacia la izquierda del personaje (+X)
		var ang: float = fposmod(atan2(p.x - centro.x, p.z - centro.y) + PI / SECTORES.size(), TAU)
		var s: int = int(ang / TAU * SECTORES.size()) % SECTORES.size()
		res[s] = minf(float(res[s]), p.y)
	return res


## Anchura en X de los puntos con y en [y0, y1].
func _ancho(pts: PackedVector3Array, y0: float, y1: float) -> float:
	var x0: float = INF
	var x1: float = -INF
	for p in pts:
		if p.y >= y0 and p.y <= y1:
			x0 = minf(x0, p.x)
			x1 = maxf(x1, p.x)
	return x1 - x0 if x1 >= x0 else 0.0


func _limpiar_triangulos() -> void:
	_rejilla.clear()
	_ta.clear()
	_tb.clear()
	_tc.clear()
	_na.clear()
	_nb.clear()
	_nc.clear()
	_tzona.clear()


func _anadir_triangulo(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, zona: String) -> void:
	if (b - a).cross(c - a).length() < 1e-12:
		return
	var i: int = _ta.size()
	_ta.append(a)
	_tb.append(b)
	_tc.append(c)
	_na.append(na)
	_nb.append(nb)
	_nc.append(nc)
	_tzona.append(zona)
	var lo: Vector3i = _celda(a.min(b).min(c))
	var hi: Vector3i = _celda(a.max(b).max(c))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var k := Vector3i(x, y, z)
				# los Packed*Array se copian al sacarlos del diccionario: se añade y se vuelve a guardar
				var lista: PackedInt32Array = _rejilla.get(k, PackedInt32Array())
				lista.append(i)
				_rejilla[k] = lista


func _preparar_busqueda() -> void:
	_visto.resize(_ta.size())
	_visto.fill(0)
	_sello = 0


## Los triángulos del cuerpo por zonas (u del modelo), sin las zonas de `sin`.
func _montar_rejilla(zonas: ArrayMesh, esc: float, sin: Array) -> void:
	_limpiar_triangulos()
	for s in zonas.get_surface_count():
		if sin.has(String(zonas.surface_get_name(s))):
			continue
		var arr: Array = zonas.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var zona: String = String(zonas.surface_get_name(s))
		for t in range(0, idx.size(), 3):
			_anadir_triangulo(vs[idx[t]] * esc, vs[idx[t + 1]] * esc, vs[idx[t + 2]] * esc, ns[idx[t]], ns[idx[t + 1]], ns[idx[t + 2]], zona)
	_preparar_busqueda()
	print("INFO  cuerpo%s: %d triángulos" % ["" if sin.is_empty() else " sin %s" % [sin], _ta.size()])


## Vóxeles del cuerpo entero: cada triángulo marca los vóxeles que toca (muestreado a menos de medio vóxel) y luego se rellena desde el borde de la caja (vecinos
## por cara); lo que no se alcanza ni es superficie queda cerrado: dentro.
func _voxelizar() -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in _ta.size():
		lo = lo.min(_ta[i]).min(_tb[i]).min(_tc[i])
		hi = hi.max(_ta[i]).max(_tb[i]).max(_tc[i])
	_vox_origen = lo - Vector3.ONE * VOXEL * 2.0
	_vox_n = Vector3i(((hi - lo) / VOXEL).ceil()) + Vector3i(5, 5, 5)
	_vox.resize(_vox_n.x * _vox_n.y * _vox_n.z)
	_vox.fill(0)
	for i in _ta.size():
		var a: Vector3 = _ta[i]
		var ab: Vector3 = _tb[i] - a
		var ac: Vector3 = _tc[i] - a
		var pasos: int = maxi(1, ceili(maxf(ab.length(), maxf(ac.length(), (_tc[i] - _tb[i]).length())) / (VOXEL * 0.4)))
		for u in pasos + 1:
			for w in pasos + 1 - u:
				var k: int = _indice_voxel(a + ab * (float(u) / pasos) + ac * (float(w) / pasos))
				if k >= 0:
					_vox[k] = 1
	var cola := PackedInt32Array()
	for x in _vox_n.x:
		for y in _vox_n.y:
			for z in _vox_n.z:
				if x == 0 or y == 0 or z == 0 or x == _vox_n.x - 1 or y == _vox_n.y - 1 or z == _vox_n.z - 1:
					var k: int = (x * _vox_n.y + y) * _vox_n.z + z
					if _vox[k] == 0:
						_vox[k] = 2
						cola.append(k)
	var paso_x: int = _vox_n.y * _vox_n.z
	var cab: int = 0
	while cab < cola.size():
		var k: int = cola[cab]
		cab += 1
		var x: int = k / paso_x
		var y: int = (k / _vox_n.z) % _vox_n.y
		var z: int = k % _vox_n.z
		if x > 0 and _vox[k - paso_x] == 0:
			_vox[k - paso_x] = 2
			cola.append(k - paso_x)
		if x < _vox_n.x - 1 and _vox[k + paso_x] == 0:
			_vox[k + paso_x] = 2
			cola.append(k + paso_x)
		if y > 0 and _vox[k - _vox_n.z] == 0:
			_vox[k - _vox_n.z] = 2
			cola.append(k - _vox_n.z)
		if y < _vox_n.y - 1 and _vox[k + _vox_n.z] == 0:
			_vox[k + _vox_n.z] = 2
			cola.append(k + _vox_n.z)
		if z > 0 and _vox[k - 1] == 0:
			_vox[k - 1] = 2
			cola.append(k - 1)
		if z < _vox_n.z - 1 and _vox[k + 1] == 0:
			_vox[k + 1] = 2
			cola.append(k + 1)
	var cerrados: int = 0
	for b in _vox:
		if b == 0:
			cerrados += 1
	print("INFO  vóxeles del cuerpo: %s de %.2f, %d cerrados" % [_vox_n, VOXEL, cerrados])


func _indice_voxel(p: Vector3) -> int:
	var c := Vector3i(((p - _vox_origen) / VOXEL).floor())
	if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= _vox_n.x or c.y >= _vox_n.y or c.z >= _vox_n.z:
		return -1
	return (c.x * _vox_n.y + c.y) * _vox_n.z + c.z


func _celda(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELDA), floori(p.y / CELDA), floori(p.z / CELDA))


## {hondo: en vóxeles cerrados, piel: junto a la superficie con distancia con signo negativa (triángulo que no es pelo), pelo: lo mismo junto al pelo (aviso),
## orejas: junto a las orejas (no cuentan), minima: distancia con signo mínima junto a la piel, por_altura: {banda: vértices dentro}}.
func _dentro(pts: PackedVector3Array) -> Dictionary:
	var r: Dictionary = {"hondo": 0, "piel": 0, "pelo": 0, "orejas": 0, "minima": INF, "por_altura": {}, "por_zona": {}}
	for p in pts:
		var k: int = _indice_voxel(p)
		if k < 0 or _vox[k] == 2:
			continue
		var c: Array = _mas_cercano(p, INF)
		var q: Vector3 = c[0]
		if absf(q.x) > OREJA_X and q.y > OREJA_Y:
			r["orejas"] = int(r["orejas"]) + 1
			continue
		var cuenta: String = ""
		if _vox[k] == 0:
			cuenta = "hondo"
		else:
			var s: float = (p - q).dot(_normal_en(int(c[1]), q))
			if _tzona[int(c[1])] == ZONA_PELO:
				if s < 0.0:
					r["pelo"] = int(r["pelo"]) + 1
				continue
			r["minima"] = minf(float(r["minima"]), s)
			if s < 0.0:
				cuenta = "piel"
		if cuenta != "":
			r[cuenta] = int(r[cuenta]) + 1
			(r["por_zona"] as Dictionary)[_tzona[int(c[1])]] = int((r["por_zona"] as Dictionary).get(_tzona[int(c[1])], 0)) + 1
			var banda: float = snappedf(floorf(p.y / BANDA_INFORME) * BANDA_INFORME, 0.01)
			(r["por_altura"] as Dictionary)[banda] = int((r["por_altura"] as Dictionary).get(banda, 0)) + 1
	return r


## Normal en el punto q del triángulo i, interpolando las normales de sus vértices: en las aristas y esquinas convexas (la punta del codo) la de la cara engaña.
func _normal_en(i: int, q: Vector3) -> Vector3:
	var bc: Vector3 = Geometry3D.get_triangle_barycentric_coords(q, _ta[i], _tb[i], _tc[i])
	var n: Vector3 = _na[i] * bc.x + _nb[i] * bc.y + _nc[i] * bc.z
	return n.normalized() if n.length() > 1e-9 else _na[i]


## [punto más cercano, triángulo] (triángulo -1 si no hay ninguno a menos de `hasta`): por capas de celdas alrededor de `p` hasta que la distancia hallada queda
## dentro del radio ya mirado.
func _mas_cercano(p: Vector3, hasta: float) -> Array:
	_sello += 1
	var c: Vector3i = _celda(p)
	var mejor: float = INF
	var punto := Vector3.ZERO
	var tri: int = -1
	var r: int = 0
	while true:
		for x in range(c.x - r, c.x + r + 1):
			for y in range(c.y - r, c.y + r + 1):
				for z in range(c.z - r, c.z + r + 1):
					if maxi(maxi(absi(x - c.x), absi(y - c.y)), absi(z - c.z)) != r:
						continue
					var k := Vector3i(x, y, z)
					if not _rejilla.has(k):
						continue
					for i in (_rejilla[k] as PackedInt32Array):
						if _visto[i] == _sello:
							continue
						_visto[i] = _sello
						var q: Vector3 = _punto_en_triangulo(p, _ta[i], _tb[i], _tc[i])
						var d: float = p.distance_squared_to(q)
						if d < mejor:
							mejor = d
							punto = q
							tri = i
		if (tri >= 0 and sqrt(mejor) <= float(r) * CELDA) or r >= CAPAS_MAX or float(r - 1) * CELDA > hasta:
			break
		r += 1
	if tri >= 0 and sqrt(mejor) > hasta:
		tri = -1
	return [punto, tri]


## Punto del triángulo abc más cercano a p (Ericson, «Real-Time Collision Detection» §5.1.5).
func _punto_en_triangulo(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)


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


func _acabar() -> void:
	print("RESULTADO ropa_capa · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
