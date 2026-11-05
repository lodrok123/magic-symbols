extends SceneTree
## PRUEBA · CLIPS DE MIXAMO SOBRE jugadora_base (5/11). ¿Se pueden traer clips de la librería de Mixamo (dataset Linzhan/Mixamo-Animations-Characters, esqueleto Y Bot
## de 65 huesos `mixamorig`) a la jugadora con el retarget de ClipsFamilia, sin tocar el GLB de la jugadora? Sin ventana:
##   tools/Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path . --script res://herramientas/prueba_mixamo_clips.gd [-- <glb_de_clips>]
## El GLB de clips lo genera herramientas/mixamo_clips_a_glb.gd (por defecto, GLB_CLIPS). Se lee con GLTFDocument (no hace falta que Godot lo haya importado).
## Para cada clip, al 10/50/90 %, con Pj3D real y el clip a pelo (sin SkeletonModifier3D):
##   A · el retarget produce un clip con una pista de rotación por hueso común (≥ HUESOS_MIN) y sin NaN;
##   B · la figura es la del clip de la fuente: la inclinación cadera→cabeza (sagital, + = adelante) y la flexión de rodillas del destino a ≤ TOL grados de las
##       de la fuente medidas con la cinemática directa del esqueleto de la fuente (mismo método que prueba_rigging_postura: de articulación a articulación, en el mundo);
##   C · la cadera destino no se va del sitio en el plano del suelo más de CADERA_XZ_MAX alturas de cadera (en el espacio del esqueleto, que en jugadora_base va en cm con la
##       armadura a escala 0,01: por eso se mide en alturas de cadera y no en metros). Los clips de Mixamo «in place» se quedan quietos; los de AVANZAN se desplazan a propósito y se
##       imprime cuánto, sin fallar.
## La apertura lateral del brazo no se compara cuando la figura está boca abajo (|línea| > 90°, el medio de una voltereta): el signo de «abierto» depende de dónde queda el lateral
## y con el cuerpo invertido la misma pose da signos opuestos (se imprime como INFO).
## Y para cada clip imprime, para mirar a ojo: duración, pistas, inclinación y rodillas al 50 %.

const GLB_CLIPS: String = "res://arte/meshy/mixamo_prueba_clips.glb"
const ID_DESTINO: String = "jugadora_base"
const FRACS: Array = [0.1, 0.5, 0.9]
const HUESOS_MIN: int = 60
const TOL: float = 10.0
const CADERA_XZ_MAX: float = 0.35      ## alturas de cadera
## Clips que avanzan a propósito (la cadera se desplaza): C se imprime como INFO.
const AVANZAN: Array = ["Swimming", "Stand_To_Roll"]
const ALTO: float = 1.0
const Medir := preload("res://herramientas/prueba_rigging_postura.gd")

var _fallos: int = 0


func _initialize() -> void:
	_correr()


func ok(c: bool, msg: String) -> void:
	if c:
		print("OK    ", msg)
	else:
		_fallos += 1
		print("FALLO ", msg)


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	var ruta: String = args[0] if args.size() > 0 else GLB_CLIPS
	var fuente: Node3D = _abrir_glb(ProjectSettings.globalize_path(ruta))
	if fuente == null:
		ok(false, "no se pudo leer " + ruta)
		_fin()
		return
	root.add_child(fuente)
	var l_sk: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
	var l_ap: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
	if l_sk.is_empty() or l_ap.is_empty():
		ok(false, "el GLB de clips no trae esqueleto o AnimationPlayer (%d / %d)" % [l_sk.size(), l_ap.size()])
		_fin()
		return
	var sk_s: Skeleton3D = l_sk[0]
	var ap_s: AnimationPlayer = l_ap[0]
	print("INFO  fuente %s: %d huesos, clips %s" % [ruta, sk_s.get_bone_count(), ap_s.get_animation_list()])
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar(ID_DESTINO)
	pj.set_alto(ALTO)
	for i in 3:
		await process_frame
	var l_sd: Array[Node] = pj.find_children("*", "Skeleton3D", true, false)
	if l_sd.is_empty():
		ok(false, "Pj3D no cargó " + ID_DESTINO)
		_fin()
		return
	var sk_d: Skeleton3D = l_sd[0]
	if pj._arbol != null:
		pj._arbol.active = false
	var ap_d: AnimationPlayer = pj._ap
	ap_d.active = true
	print("INFO  destino %s: %d huesos, alto del modelo %.3f" % [ID_DESTINO, sk_d.get_bone_count(), pj.alto_modelo()])
	var comunes: int = 0
	for i in sk_d.get_bone_count():
		if sk_s.find_bone(sk_d.get_bone_name(i)) >= 0:
			comunes += 1
	print("INFO  huesos con el mismo nombre en los dos: %d" % comunes)
	# Retarget con el mismo contexto que ClipsFamilia.traducir_clip (alineando el reposo como para jugadora_base).
	var c := ClipsFamilia._Ctx.new()
	c.preparar(fuente, sk_s, pj._modelo, sk_d, ClipsFamilia.alinear_de(ID_DESTINO))
	print("INFO  escala de cadera fuente→destino %.4f (cadera fuente %.2f, destino %.3f)" % [c.escala_cadera, sk_s.get_bone_rest(sk_s.find_bone("mixamorig_Hips")).origin.y, sk_d.get_bone_rest(sk_d.find_bone("mixamorig_Hips")).origin.y])
	var lib: AnimationLibrary = ap_d.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		ap_d.add_animation_library("", lib)
	var prefijo: String = String(pj._modelo.get_path_to(sk_d)) + ":"
	for nombre in ap_s.get_animation_list():
		var an_s: Animation = ap_s.get_animation(nombre)
		var r: Array = c.traducir(an_s, prefijo)
		var an_d: Animation = r[0]
		var clave: String = "mx_" + String(nombre)
		lib.add_animation(clave, an_d)
		# A · pistas y NaN
		var rot: int = 0
		var nan: bool = false
		for t in an_d.get_track_count():
			if an_d.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot += 1
			for k in an_d.track_get_key_count(t):
				var v = an_d.track_get_key_value(t, k)
				if (v is Quaternion and not (v as Quaternion).is_finite()) or (v is Vector3 and not (v as Vector3).is_finite()):
					nan = true
		ok(rot >= HUESOS_MIN and not nan, "A %s: %.2f s, %d pistas de rotación (mín. %d), NaN=%s" % [nombre, an_d.length, rot, HUESOS_MIN, nan])
		# B · figura contra la fuente
		var cad_rest: Vector3 = sk_d.get_bone_rest(sk_d.find_bone("mixamorig_Hips")).origin
		var xz_max: float = 0.0
		for f in FRACS:
			var t: float = an_d.length * float(f)
			var md: Dictionary = await _pose_destino(pj, sk_d, ap_d, clave, t)
			var ms: Dictionary = _pose_fuente(pj, sk_s, an_s, t)
			var d_lin: float = absf(float(md["linea"]) - float(ms["linea"]))
			var d_rod: float = maxf(absf(float(md["rod_l"]) - float(ms["rod_l"])), absf(float(md["rod_r"]) - float(ms["rod_r"])))
			var boca_abajo: bool = absf(float(ms["linea"])) > 90.0
			var d_bra: float = absf(float(md["brazo_sag"]) - float(ms["brazo_sag"]))
			if not boca_abajo:
				d_bra = maxf(d_bra, absf(float(md["brazo_lat"]) - float(ms["brazo_lat"])))
			ok(d_lin <= TOL, "B %s@%.1f: línea cadera→cabeza %+.1f° contra %+.1f° de la fuente (dif. %.1f, tope %.0f)" % [nombre, f, md["linea"], ms["linea"], d_lin, TOL])
			ok(d_rod <= TOL, "B %s@%.1f: rodillas %.1f/%.1f° contra %.1f/%.1f° (dif. %.1f, tope %.0f)" % [nombre, f, md["rod_l"], md["rod_r"], ms["rod_l"], ms["rod_r"], d_rod, TOL])
			ok(d_bra <= TOL, "B %s@%.1f: brazo %+.1f° delante / %+.1f° abierto contra %+.1f / %+.1f (dif. %.1f, tope %.0f%s)" % [nombre, f, md["brazo_sag"], md["brazo_lat"], ms["brazo_sag"], ms["brazo_lat"], d_bra, TOL,
				"; boca abajo: la apertura no se compara" if boca_abajo else ""])
			print("INFO  %s@%.1f: suela destino %+.3f del alto respecto al suelo del modelo" % [nombre, f, md["suela"]])
		# C · cadera en el sitio: el RECORRIDO en el plano del suelo (máximo menos mínimo a lo largo del clip). Aparte se imprime el desvío medio respecto al reposo:
		# los clips «in place» de Mixamo traen la cadera puesta a un lado (Two_Hand_Spell_Casting, 0,65 alturas de cadera hacia atrás), que es lo que ClipsFamilia corrige con «centrar».
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var media := Vector2.ZERO
		var n_k: int = 0
		for tt in an_d.get_track_count():
			if an_d.track_get_type(tt) == Animation.TYPE_POSITION_3D:
				for k in an_d.track_get_key_count(tt):
					var p: Vector3 = an_d.track_get_key_value(tt, k)
					var v := Vector2(p.x - cad_rest.x, p.z - cad_rest.z) / maxf(cad_rest.y, 0.000001)
					lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
					hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
					media += v
					n_k += 1
		if n_k > 0:
			media /= float(n_k)
			xz_max = (hi - lo).length()
		var msg_c: String = "C %s: la cadera recorre %.2f alturas de cadera en el plano del suelo (tope %.2f); desvío medio respecto al reposo %.2f (x %+.2f, z %+.2f)" % [nombre, xz_max, CADERA_XZ_MAX, media.length(), media.x, media.y]
		if AVANZAN.has(String(nombre)):
			print("INFO  ", msg_c, " · avanza a propósito")
		else:
			ok(xz_max <= CADERA_XZ_MAX, msg_c)
	_fin()


func _fin() -> void:
	print("RESULTADO mixamo_clips · FALLOS: %d" % _fallos)
	quit(_fallos)


## Pose global del destino con el clip `clave` quieto en `t`, medida con prueba_rigging_postura.medir.
func _pose_destino(pj: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clave: String, t: float) -> Dictionary:
	ap.play(clave)
	ap.seek(t, true)
	ap.pause()
	await process_frame
	await process_frame
	var g: Dictionary = {}
	for i in sk.get_bone_count():
		g[i] = sk.get_bone_global_pose(i)
	return Medir.medir(pj, sk, g)


## Pose global de la FUENTE en `t` por cinemática directa (sin reproducir: el esqueleto de la fuente no cuelga de ningún Pj3D), llevada al espacio del Pj3D
## destino para medirla con el mismo `medir` (solo usa ángulos y la altura relativa, así que la escala no importa; la suela se da respecto al propio alto).
func _pose_fuente(pj: Pj3D, sk: Skeleton3D, an: Animation, t: float) -> Dictionary:
	var rot: Dictionary = {}
	var p_cad: Vector3 = sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin
	for tr in an.get_track_count():
		var b: int = sk.find_bone(String(an.track_get_path(tr)).get_slice(":", 1))
		if b < 0:
			continue
		if an.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			rot[b] = an.rotation_track_interpolate(tr, t)
		elif an.track_get_type(tr) == Animation.TYPE_POSITION_3D and sk.get_bone_name(b) == "mixamorig_Hips":
			p_cad = an.position_track_interpolate(tr, t)
	var g: Dictionary = {}
	for i in ClipsFamilia._Ctx._orden(sk):
		var q: Quaternion = rot.get(i, ClipsFamilia._Ctx._quat(sk.get_bone_rest(i).basis))
		var loc := Transform3D(Basis(q), p_cad if sk.get_bone_name(i) == "mixamorig_Hips" else sk.get_bone_rest(i).origin)
		var p: int = sk.get_bone_parent(i)
		g[i] = loc if p < 0 else (g[p] as Transform3D) * loc
	return Medir.medir(pj, sk, g)


func _abrir_glb(ruta: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ruta, estado) != OK:
		return null
	return doc.generate_scene(estado) as Node3D
