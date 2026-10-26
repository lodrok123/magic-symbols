extends SceneTree
## PRUEBA DEL RIGGING · POSTURA Y PIES (24/10, Pipeline, diario 255). Un personaje cuyos clips vienen de OTRO esqueleto (ClipsFamilia) contra esa fuente, con Pj3D real:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_rigging_postura.gd [-- antes]
## (`antes` = sin alinear el reposo, ClipsFamilia.alinear_activo = false, y sin la fila de POSTURAS del destino: para ver lo que la prueba encuentra en el retarget de antes.)
## Todas las medidas son geométricas (de articulación a articulación, en el mundo, el personaje a 1 u de alto mirando a +Z): no dependen de cómo orientó
## Meshy o Mixamo el eje local de cada hueso. Inclinación sagital en grados, + = hacia delante.
##   A · RETARGET (clip a pelo, sin SkeletonModifier3D): en idle, walk, run y cast_proyectil al 10/50/90 %, la flexión de cada rodilla del destino a ≤ RODILLA_TOL de
##       la de la fuente y el brazo (sagital y apertura) a ≤ BRAZO_TOL. Una rodilla de más es el reposo de la fuente colándose en el destino.
##   B · POSTURA FINAL (con ProporcionChibi, la capa...), idle y walk: la columna (cadera→Spine2, Spine2→cuello y la línea cadera→cabeza) a ≤ COLUMNA_TOL de la
##       de la fuente con SU postura final; en idle además rodillas ≤ RODILLA_IDLE_MAX, la cabeza (Head→HeadTop_End) a ≤ CABEZA_IDLE_MAX de la vertical y la
##       línea cadera→cabeza a ≤ LINEA_IDLE_MAX («erguida como el concept»).
##   C · PIES EN EL SUELO: en idle la suela más baja (huesos Foot/ToeBase/Toe_End) no baja más de SUELA_HUNDE_MAX ni sube más de SUELA_FLOTA_MAX respecto al
##       reposo; en walk y run la suela más baja del ciclo no flota más de SUELA_FLOTA_CICLO_MAX (algún pie toca el suelo) ni se hunde más de SUELA_HUNDE_CICLO_MAX.
##   D · PIES QUE PATINAN: en walk y run, el pie de apoyo (el más bajo, a ≤ APOYO_ALTO de la suela mínima del ciclo) va hacia atrás a la velocidad a la que el
##       juego mueve al personaje (Jugador3D: VEL_ANDAR / VEL_CORRER, 1 u de alto): la razón (velocidad del pie hacia atrás / velocidad del juego) en
##       [ZANCADA_MIN, ZANCADA_MAX]. Por debajo, el pie resbala hacia delante (patina); por encima, la zancada es más larga que lo que avanza.
## La fuente se mide igual (INFO) y con la misma prueba D, para separar lo que viene del clip de lo que pone el retarget.

const PARES: Array = [["jugadora_base", "chibi_elf"]]
const ROLES_A: Array = ["idle", "walk", "run", "cast_proyectil"]
const ROLES_B: Array = ["idle", "walk"]
const FRACS: Array = [0.1, 0.5, 0.9]
const RODILLA_TOL: float = 10.0
const BRAZO_TOL: float = 10.0
const COLUMNA_TOL: float = 5.0
const RODILLA_IDLE_MAX: float = 10.0
const CABEZA_IDLE_MAX: float = 8.0
const LINEA_IDLE_MAX: float = 8.0
const SUELA_HUNDE_MAX: float = 0.012
const SUELA_FLOTA_MAX: float = 0.01
const SUELA_FLOTA_CICLO_MAX: float = 0.015
const SUELA_HUNDE_CICLO_MAX: float = 0.04     ## la de MedidasClipsJugadora.SUELA_HUNDE_MAX (los clips de Meshy hunden la punta del pie al apoyar)
const VEL_JUEGO: Dictionary = {"walk": 1.6, "run": 3.0}       ## u/s (Jugador3D._vel_andar / _vel_correr, PruebaTest2.VEL_ANDAR / VEL_CORRER)
const MUESTRAS_CICLO: int = 30
const APOYO_ALTO: float = 0.012
const ZANCADA_MIN: float = 0.75
const ZANCADA_MAX: float = 1.25
const ALTO: float = 1.0

var _fallos: int = 0
var _final: Dictionary = {}
var _sk: Skeleton3D = null
var _antes: bool = false


func _initialize() -> void:
	_correr()


func ok(c: bool, msg: String) -> void:
	if c:
		print("OK    ", msg)
	else:
		_fallos += 1
		print("FALLO ", msg)


func _correr() -> void:
	_antes = OS.get_cmdline_user_args().has("antes")
	if _antes:
		ClipsFamilia.alinear_activo = false
		ClipsFamilia.vaciar_cache()
		print("INFO  modo «antes»: sin alinear el reposo y sin la postura del destino")
	var t0: int = Time.get_ticks_msec()
	for par in PARES:
		var d: Dictionary = await _medir_pj(String(par[0]), true)
		var s: Dictionary = await _medir_pj(String(par[1]), false)
		var et: String = "%s←%s" % [par[0], par[1]]
		# A · retarget
		for rol in ROLES_A:
			for f in FRACS:
				var k: String = "%s@%.1f" % [rol, f]
				if not (d["crudo"] as Dictionary).has(k) or not (s["crudo"] as Dictionary).has(k):
					ok(false, "A %s %s: falta el clip en uno de los dos" % [et, k])
					continue
				var md: Dictionary = d["crudo"][k]
				var ms: Dictionary = s["crudo"][k]
				var dr: float = maxf(absf(md["rod_l"] - ms["rod_l"]), absf(md["rod_r"] - ms["rod_r"]))
				ok(dr <= RODILLA_TOL, "A %s %s: rodillas %.1f/%.1f° contra %.1f/%.1f° de la fuente (diferencia %.1f, tope %.0f)" % [et, k, md["rod_l"], md["rod_r"], ms["rod_l"], ms["rod_r"], dr, RODILLA_TOL])
				var db: float = maxf(absf(md["brazo_sag"] - ms["brazo_sag"]), absf(md["brazo_lat"] - ms["brazo_lat"]))
				ok(db <= BRAZO_TOL, "A %s %s: brazo %+.1f° delante / %+.1f° abierto contra %+.1f / %+.1f de la fuente (diferencia %.1f, tope %.0f)" % [et, k, md["brazo_sag"], md["brazo_lat"], ms["brazo_sag"], ms["brazo_lat"], db, BRAZO_TOL])
		# B · postura final
		for rol in ROLES_B:
			for f in FRACS:
				var k2: String = "%s@%.1f" % [rol, f]
				var fd: Dictionary = d["final"][k2]
				var fs: Dictionary = s["final"][k2]
				var dc: float = 0.0
				for seg in ["lumbar", "pecho", "linea"]:
					dc = maxf(dc, absf(float(fd[seg]) - float(fs[seg])))
				ok(dc <= COLUMNA_TOL, "B %s %s: columna lumbar %+.1f pecho %+.1f línea %+.1f contra %+.1f %+.1f %+.1f de la fuente (diferencia máx. %.1f, tope %.0f)" % [et, k2,
					fd["lumbar"], fd["pecho"], fd["linea"], fs["lumbar"], fs["pecho"], fs["linea"], dc, COLUMNA_TOL])
				if rol == "idle":
					# 25/10: la rodilla final se compara con la de la FUENTE con su postura (± RODILLA_TOL), no con un tope absoluto: chibi_elf en idle flexiona 12–16°, y
					# exigir ≤ 10° obligaba a estirar 22° de más, lo que giraba la espinilla y adelantaba el tobillo 4 cm (Pablo: «los pies están muy adelantados»).
					var dr2: float = maxf(absf(float(fd["rod_l"]) - float(fs["rod_l"])), absf(float(fd["rod_r"]) - float(fs["rod_r"])))
					ok(dr2 <= RODILLA_TOL, "B %s %s: rodillas %.1f/%.1f° contra %.1f/%.1f° de la fuente (diferencia %.1f, tope %.0f)" % [et, k2, fd["rod_l"], fd["rod_r"], fs["rod_l"], fs["rod_r"], dr2, RODILLA_TOL])
					ok(absf(fd["cabeza"]) <= CABEZA_IDLE_MAX, "B %s %s: cabeza a %+.1f° de la vertical (tope ±%.0f; la fuente, %+.1f)" % [et, k2, fd["cabeza"], CABEZA_IDLE_MAX, fs["cabeza"]])
					ok(absf(fd["linea"]) <= LINEA_IDLE_MAX, "B %s %s: línea cadera→cabeza a %+.1f° de la vertical (tope ±%.0f)" % [et, k2, fd["linea"], LINEA_IDLE_MAX])
		# C · pies en el suelo
		for e in [[par[0], d], [par[1], s]]:
			var m: Dictionary = e[1]
			var es_dest: bool = e[0] == par[0]
			var r: float = float(m["suela_reposo"])
			var lo: float = INF
			var hi: float = -INF
			for f in FRACS:
				var y: float = float(m["final"]["idle@%.1f" % f]["suela"]) - r
				lo = minf(lo, y)
				hi = maxf(hi, y)
			var msg: String = "C %s idle: la suela respecto al reposo va de %+.3f a %+.3f del alto (tope −%.3f / +%.3f)" % [e[0], lo, hi, SUELA_HUNDE_MAX, SUELA_FLOTA_MAX]
			if es_dest:
				ok(lo >= -SUELA_HUNDE_MAX and hi <= SUELA_FLOTA_MAX, msg)
			else:
				print("INFO  ", msg)
			for rol in VEL_JUEGO:
				var ciclo: Dictionary = m["ciclo"][rol]
				var flota: float = float(ciclo["suela_min"]) - r
				# La velocidad del clip en juego es la del clip × el multiplicador de la tabla (Pj3D.VEL_CLIP_PJ): ese es el ajuste anti-patinaje por personaje.
				var factor_clip: float = float(Pj3D.VEL_CLIP_PJ.get(e[0], {}).get(rol, 1.0))
				var msg2: String = "C %s %s: la suela más baja del ciclo queda a %+.3f del reposo (tope +%.3f)" % [e[0], rol, flota, SUELA_FLOTA_CICLO_MAX]
				var msg3: String = "D %s %s: el pie de apoyo va hacia atrás a %.2f u/s y el juego avanza a %.2f (razón %.2f, de %d fotogramas de apoyo; entre %.2f y %.2f)" % [
					e[0], rol, float(ciclo["vel_pie"]) * factor_clip, VEL_JUEGO[rol], float(ciclo["vel_pie"]) * factor_clip / float(VEL_JUEGO[rol]), ciclo["apoyos"], ZANCADA_MIN, ZANCADA_MAX]
				var razon: float = float(ciclo["vel_pie"]) * factor_clip / float(VEL_JUEGO[rol])
				# Otra cuenta, sin depender de qué fotogramas son de apoyo: el pie recorre `recorrido` hacia atrás en medio ciclo como mínimo.
				print("INFO  %s %s: clip de %.2f s, el pie recorre %.3f u de delante atrás; para no patinar a %.1f u/s el clip tendría que ir a ×%.2f (VEL_CLIP_PJ)" % [e[0], rol,
					ciclo["largo"], ciclo["recorrido"], VEL_JUEGO[rol], float(VEL_JUEGO[rol]) / maxf(float(ciclo["vel_pie"]), 0.001)])
				var hunde: float = -flota
				if es_dest:
					ok(hunde <= SUELA_HUNDE_CICLO_MAX, "C %s %s: la suela más baja del ciclo no se hunde más de %.2f del alto bajo el reposo (%+.3f)" % [e[0], rol, SUELA_HUNDE_CICLO_MAX, flota])
					ok(flota <= SUELA_FLOTA_CICLO_MAX, msg2)
					ok(razon >= ZANCADA_MIN and razon <= ZANCADA_MAX, msg3)
				else:
					print("INFO  ", msg2)
					print("INFO  ", msg3)
	print("INFO  tiempo %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("RESULTADO rigging_postura · FALLOS: %d" % _fallos)
	quit(_fallos)


## Carga el personaje `id` (vestido como en el juego) y mide: reposo, cada rol de ROLES_A al 10/50/90 % a pelo y con los modificadores, y los ciclos de walk y run.
func _medir_pj(id: String, es_destino: bool) -> Dictionary:
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar(id)
	pj.set_alto(ALTO)
	if _antes and es_destino:
		pj.set_postura(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	for i in 3:
		await process_frame
	_sk = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_sk.skeleton_updated.connect(_al_actualizar)
	if pj._arbol != null:
		pj._arbol.active = false
	var ap: AnimationPlayer = pj._ap
	ap.active = true
	var res: Dictionary = {"crudo": {}, "final": {}, "ciclo": {}}
	var reposo: Dictionary = {}
	for i in range(_sk.get_bone_count()):
		reposo[i] = _sk.get_bone_global_rest(i)
	res["suela_reposo"] = float(medir(pj, _sk, reposo)["suela"])
	for rol in ROLES_A:
		var clip: String = pj.clip_de(rol)
		if clip == "":
			continue
		var largo: float = ap.get_animation(clip).length
		for f in FRACS:
			var par: Array = await _pose(pj, ap, clip, largo * float(f))
			res["crudo"]["%s@%.1f" % [rol, f]] = medir(pj, _sk, par[0])
			res["final"]["%s@%.1f" % [rol, f]] = medir(pj, _sk, par[1])
	for rol in VEL_JUEGO:
		res["ciclo"][rol] = await _ciclo(pj, ap, pj.clip_de(rol))
	_sk.skeleton_updated.disconnect(_al_actualizar)
	pj.queue_free()
	await process_frame
	return res


## El clip `clip` quieto en `t`: [globales a pelo, globales con los modificadores] (espacio del esqueleto).
func _pose(pj: Pj3D, ap: AnimationPlayer, clip: String, t: float) -> Array:
	ap.play(clip)
	ap.seek(t, true)
	ap.pause()
	_final = {}
	await process_frame
	await process_frame
	var crudo: Dictionary = {}
	for i in range(_sk.get_bone_count()):
		crudo[i] = _sk.get_bone_global_pose(i)
	return [crudo, _final.duplicate() if not _final.is_empty() else crudo]


## Un ciclo entero del clip con los modificadores: la suela más baja y la velocidad media hacia atrás (−Z) del pie de apoyo.
func _ciclo(pj: Pj3D, ap: AnimationPlayer, clip: String) -> Dictionary:
	var largo: float = ap.get_animation(clip).length
	var dt: float = largo / float(MUESTRAS_CICLO)
	var pies: Array = []      # por muestra: [pos pie izq, pos pie der] (mundo)
	var suela_min: float = INF
	for k in range(MUESTRAS_CICLO + 1):
		var par: Array = await _pose(pj, ap, clip, minf(dt * float(k), largo - 0.001))
		var w: Transform3D = _sk.global_transform
		var fila: Array = []
		for lado in ["Left", "Right"]:
			var b: int = _sk.find_bone("mixamorig_%sToeBase" % lado)
			if b < 0:
				b = _sk.find_bone("mixamorig_%sFoot" % lado)
			fila.append(w * ((par[1] as Dictionary)[b] as Transform3D).origin)
		pies.append(fila)
		suela_min = minf(suela_min, float(medir(pj, _sk, par[1])["suela"]))
	var suma: float = 0.0
	var n: int = 0
	var y_min: float = INF
	for fila in pies:
		for p in fila:
			y_min = minf(y_min, (p as Vector3).y)
	var fwd: Vector3 = pj.global_transform.basis.z.normalized()
	for k in range(MUESTRAS_CICLO):
		for lado in 2:
			var a: Vector3 = pies[k][lado]
			var b2: Vector3 = pies[k + 1][lado]
			var otro: Vector3 = pies[k][1 - lado]
			# apoyo: este pie es el más bajo y está pegado al suelo del ciclo
			if a.y <= otro.y and a.y - y_min <= APOYO_ALTO and b2.y - y_min <= APOYO_ALTO:
				suma += -(b2 - a).dot(fwd) / dt
				n += 1
	var recorrido: float = 0.0
	for lado in 2:
		var zmin: float = INF
		var zmax: float = -INF
		for fila in pies:
			zmin = minf(zmin, (fila[lado] as Vector3).dot(fwd))
			zmax = maxf(zmax, (fila[lado] as Vector3).dot(fwd))
		recorrido = maxf(recorrido, zmax - zmin)
	return {"suela_min": suela_min, "vel_pie": suma / float(maxi(n, 1)), "apoyos": n, "recorrido": recorrido, "largo": largo}


func _al_actualizar() -> void:
	for i in range(_sk.get_bone_count()):
		_final[i] = _sk.get_bone_global_pose(i)


## Medidas en el mundo de una pose global `g` (espacio del esqueleto). Adelante = +Z del Pj3D. Ver la cabecera.
static func medir(pj: Pj3D, sk: Skeleton3D, g: Dictionary) -> Dictionary:
	var w: Transform3D = sk.global_transform
	var up := Vector3.UP
	var fwd: Vector3 = pj.global_transform.basis.z.normalized()
	var lat: Vector3 = up.cross(fwd).normalized()
	var pos: Dictionary = {}
	for i in range(sk.get_bone_count()):
		pos[sk.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("mixamorig:")] = (w * (g[i] as Transform3D)).origin
	var res: Dictionary = {}
	var sag := func(a: String, b: String) -> float:
		var v: Vector3 = (pos.get(b, Vector3.ZERO) as Vector3) - (pos.get(a, Vector3.ZERO) as Vector3)
		return rad_to_deg(atan2(v.dot(fwd), v.dot(up)))
	res["lumbar"] = sag.call("Hips", "Spine2")
	res["pecho"] = sag.call("Spine2", "Neck")
	res["cabeza"] = sag.call("Head", "HeadTop_End")
	res["linea"] = sag.call("Hips", "Head")
	var brazo_sag: float = 0.0
	var brazo_lat: float = 0.0
	for lado in ["Left", "Right"]:
		var a: Vector3 = pos.get(lado + "UpLeg", Vector3.ZERO)
		var b: Vector3 = pos.get(lado + "Leg", Vector3.ZERO)
		var c: Vector3 = pos.get(lado + "Foot", Vector3.ZERO)
		res["rod_" + ("l" if lado == "Left" else "r")] = rad_to_deg((b - a).angle_to(c - b))
		var fuera: float = signf(((pos.get(lado + "Arm", Vector3.ZERO) as Vector3) - (pos.get("Spine2", Vector3.ZERO) as Vector3)).dot(lat))
		var br: Vector3 = (pos.get(lado + "ForeArm", Vector3.ZERO) as Vector3) - (pos.get(lado + "Arm", Vector3.ZERO) as Vector3)
		brazo_sag += rad_to_deg(atan2(br.dot(fwd), -br.dot(up))) * 0.5
		brazo_lat += rad_to_deg(atan2(br.dot(lat) * fuera, -br.dot(up))) * 0.5
	res["brazo_sag"] = brazo_sag
	res["brazo_lat"] = brazo_lat
	var suela: float = INF
	for k in pos.keys():
		var n: String = String(k)
		if n.ends_with("Foot") or n.ends_with("ToeBase") or n.ends_with("Toe_End"):
			suela = minf(suela, (pos[k] as Vector3).y)
	var alto: float = maxf(pj.alto_modelo() * pj.scale.y, 0.0001)
	res["suela"] = (suela - pj.global_position.y) / alto
	return res
