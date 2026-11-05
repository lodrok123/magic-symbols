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
##   E · ENGANCHADOS (5/11): jugadora_base, cargada por Pj3D como en el juego, trae los clips de ClipsFamilia.FUENTE_CLIPS_MIXAMO con su nombre (Mixamo_*); con la «referencia» (Idle de
##       Mixamo) y «centrar», en Mixamo_CastDosManos y Mixamo_Flotar la suela más baja queda a ≤ SUELA_E del alto del suelo en los tres instantes y la cadera a ≤ CADERA_E alturas de cadera del
##       centro en el plano del suelo (media del clip). Necesita el GLB importado por Godot (tools/Godot… --headless --editor --quit, o abrir el editor).
##   F · OTROS MODELOS (5/11): goblin_archer_chibi, goblin_warrior_chibi, marimanta, alchemist_elf (por ClipsFamilia.EXTRAS) y goblin_chaman (por FUENTES), cargados por Pj3D, traen
##       sus alternativas Mixamo_* (OTROS) con ≥ 1 pista de rotación por hueso común, sin NaN, y sus roles de siempre (idle, walk, hit…) siguen resolviendo al MISMO clip que antes
##       de añadirlas (ROLES_ANTES): las alternativas no pisan ningún rol.

const GLB_CLIPS: String = "res://arte/meshy/mixamo_clips.glb"
## Otros modelos: id de Pj3D -> alternativas que debe traer.
const OTROS: Dictionary = {
	"goblin_archer_chibi": ["Mixamo_TensarArco", "Mixamo_Disparar", "Mixamo_GritoGuerra"],
	"goblin_warrior_chibi": ["Mixamo_TensarArco", "Mixamo_Disparar", "Mixamo_GritoGuerra"],
	"marimanta": ["Mixamo_Rezar"],       # 5/11: Old_Man_Idle/Walk retirados (no sujetan el bastón)
	"goblin_chaman": ["Mixamo_Rezar"],
	"alchemist_elf": ["Mixamo_Tabernero"],
}
## Rol -> clip al que resolvía cada modelo ANTES de las alternativas (en minúsculas, como lo devuelve Pj3D.clip_de).
const ROLES_ANTES: Dictionary = {
	"goblin_archer_chibi": {"idle": "idle", "walk": "walking", "attack": "archeryshot", "hit": "hitreaction", "death": "dead"},
	"goblin_warrior_chibi": {"idle": "idle", "walk": "walking", "attack": "leftslash", "hit": "slapreaction", "death": "die"},
	"marimanta": {"idle": "idle_02", "walk": "elderly_shaky_walk_inplace", "talk": "talk_with_left_hand_on_hip"},
	"goblin_chaman": {"idle": "idle_02", "walk": "walking", "talk": "talk_with_left_hand_on_hip", "hit": "hit", "death": "death"},
	"alchemist_elf": {"idle": "idle", "walk": "walking", "talk": "standtalkingangry"},
}
const ID_DESTINO: String = "jugadora_base"
const FRACS: Array = [0.1, 0.5, 0.9]
const HUESOS_MIN: int = 60
const TOL: float = 10.0
## La línea cadera→cabeza tiene más margen: la columna de jugadora_base no se alinea al reposo de la fuente (ClipsFamilia.ALINEAR_REPOSO, a propósito) y queda ~9° más erguida que la
## fuente en todos los clips (lo compensa Pj3D.POSTURAS); en los que doblan mucho el tronco (Getting_Up, Stand_To_Roll, Standing_2H_Magic_Area_Attack_01, Old_Man_Idle) llega a 10–14°.
const TOL_LINEA: float = 15.0
const CADERA_XZ_MAX: float = 0.35      ## alturas de cadera
## Clips que avanzan a propósito (la cadera se desplaza): C se imprime como INFO. Push empuja andando (1,17 alturas), Standing_React_Large_From_Front_2 la echa atrás (1,09),
## Bartending se mueve por la barra (0,39). Two_Hand_Spell_Casting (0,68) y Magic_Heal (0,56) dan un paso al conjurar y vuelven: en el juego van centrados (ClipsFamilia «centrar») y
## E comprueba que la cadera queda a ≤ CADERA_E del centro de media.
const AVANZAN: Array = ["Swimming", "Stand_To_Roll", "Old_Man_Walk", "Falling_Back_Death", "Getting_Up", "Push", "Standing_React_Large_From_Front_2", "Bartending",
	"Two_Hand_Spell_Casting", "Magic_Heal"]
const ALTO: float = 1.0
## Clips de arco: el cuerpo gira 90° para apuntar y el brazo del arco va extendido hacia el blanco; la «apertura» lateral cambia de eje (fuente +85°, destino −4° con el brazo
## en el mismo sitio: docs/capturas/mixamo_prueba/Standing_Aim_Recoil.png) y no se compara, como boca abajo.
const DE_PERFIL: Array = ["Standing_Draw_Arrow", "Standing_Aim_Recoil"]
const ENGANCHADOS: Array = ["Mixamo_CastDosManos", "Mixamo_Nadar", "Mixamo_Flotar", "Mixamo_Voltereta", "Mixamo_CastArea1", "Mixamo_CastArea2", "Mixamo_Curar",
	"Mixamo_GolpeGrande", "Mixamo_MorirAtras", "Mixamo_Incorporarse", "Mixamo_EmpujePesado", "Mixamo_Beber", "Mixamo_AbrirTapa"]
## Solo los clips de pie y en el sitio: Mixamo_Flotar lleva las piernas encogidas pataleando (la suela queda 0,14 del alto por encima del suelo: es un clip de agua, no de suelo), Mixamo_Nadar
## y Mixamo_Voltereta avanzan, Mixamo_MorirAtras acaba tumbada y Mixamo_Incorporarse empieza tumbada (y se desplazan), Mixamo_GolpeGrande la echa atrás y Mixamo_EmpujePesado
## empuja andando (de puntillas: la suela sube 0,08).
const EN_SUELO: Array = ["Mixamo_CastDosManos", "Mixamo_CastArea1", "Mixamo_CastArea2", "Mixamo_Curar", "Mixamo_Beber", "Mixamo_AbrirTapa"]
## 5 % del alto: con la «referencia» Idle los clips de pie quedan a 0,03–0,04 (Beber 0,043: se balancea sobre los talones).
const SUELA_E: float = 0.05
const CADERA_E: float = 0.12
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
			var boca_abajo: bool = absf(float(ms["linea"])) > 90.0 or DE_PERFIL.has(String(nombre))
			var d_bra: float = absf(float(md["brazo_sag"]) - float(ms["brazo_sag"]))
			if not boca_abajo:
				d_bra = maxf(d_bra, absf(float(md["brazo_lat"]) - float(ms["brazo_lat"])))
			ok(d_lin <= TOL_LINEA, "B %s@%.1f: línea cadera→cabeza %+.1f° contra %+.1f° de la fuente (dif. %.1f, tope %.0f)" % [nombre, f, md["linea"], ms["linea"], d_lin, TOL_LINEA])
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
	# E · los clips enganchados por FUENTES (con referencia y centrar), tal como los carga el juego.
	var cad_d: int = sk_d.find_bone("mixamorig_Hips")
	var cad_rest_d: Vector3 = sk_d.get_bone_rest(cad_d).origin
	for nombre_e in ENGANCHADOS:
		var hay: bool = ap_d.has_animation(nombre_e)
		ok(hay, "E jugadora_base trae «%s» por ClipsFamilia.FUENTES" % nombre_e)
		if not hay or not EN_SUELO.has(nombre_e):
			continue
		var an_e: Animation = ap_d.get_animation(nombre_e)
		var peor: float = 0.0
		for f in FRACS:
			var m: Dictionary = await _pose_destino(pj, sk_d, ap_d, nombre_e, an_e.length * float(f))
			peor = maxf(peor, absf(float(m["suela"])))
		ok(peor <= SUELA_E, "E %s: la suela más baja se aleja del suelo como mucho %.3f del alto (tope %.3f)" % [nombre_e, peor, SUELA_E])
		var media := Vector2.ZERO
		var n_k: int = 0
		for tt in an_e.get_track_count():
			if an_e.track_get_type(tt) == Animation.TYPE_POSITION_3D and String(an_e.track_get_path(tt)).ends_with("mixamorig_Hips"):
				for k in an_e.track_get_key_count(tt):
					var p: Vector3 = an_e.track_get_key_value(tt, k)
					media += Vector2(p.x - cad_rest_d.x, p.z - cad_rest_d.z) / maxf(cad_rest_d.y, 0.000001)
					n_k += 1
		if n_k > 0:
			media /= float(n_k)
		ok(media.length() <= CADERA_E, "E %s: la cadera queda a %.2f alturas de cadera del centro (x %+.2f, z %+.2f; tope %.2f)" % [nombre_e, media.length(), media.x, media.y, CADERA_E])
	# E2 · (5/11, Pablo) la voltereta y beber de la jugadora son ya los de Mixamo (Pj3D.CLIPS_DE), y la voltereta dura lo que la de la elfa (≤ 1 s, el tope de Jugador3D).
	ok(pj.clip_de("roll").to_lower() == "mixamo_voltereta", "E2 jugadora_base: el rol roll es «%s»" % pj.clip_de("roll"))
	ok(pj.clip_de("drink").to_lower() == "mixamo_beber", "E2 jugadora_base: el rol drink es «%s»" % pj.clip_de("drink"))
	ok(pj.duracion("roll") > 0.0 and pj.duracion("roll") <= 1.0, "E2 jugadora_base: la voltereta dura %.2f s a su velocidad (tope 1,0)" % pj.duracion("roll"))
	# F · los otros modelos: traen sus alternativas y sus roles no cambian.
	for id_o in OTROS.keys():
		var pj_o := Pj3D.new()
		root.add_child(pj_o)
		if not pj_o.cargar(String(id_o)) or pj_o._ap == null:
			ok(false, "F Pj3D no cargó " + String(id_o))
			pj_o.queue_free()
			continue
		for i in 2:
			await process_frame
		var l_so: Array[Node] = pj_o.find_children("*", "Skeleton3D", true, false)
		var sk_o: Skeleton3D = l_so[0] as Skeleton3D if not l_so.is_empty() else null
		var comunes_o: int = 0
		if sk_o != null:
			for i in sk_o.get_bone_count():
				if sk_s.find_bone(sk_o.get_bone_name(i)) >= 0:
					comunes_o += 1
		print("INFO  F %s: %d huesos, %d comunes con la fuente; clips %s" % [id_o, sk_o.get_bone_count() if sk_o != null else 0, comunes_o, pj_o._ap.get_animation_list()])
		for alt in (OTROS[id_o] as Array):
			var hay_o: bool = pj_o._ap.has_animation(String(alt))
			if not hay_o:
				ok(false, "F %s trae «%s»" % [id_o, alt])
				continue
			var an_o: Animation = pj_o._ap.get_animation(String(alt))
			var rot_o: int = 0
			var nan_o: bool = false
			for t in an_o.get_track_count():
				if an_o.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					rot_o += 1
				for k in an_o.track_get_key_count(t):
					var v = an_o.track_get_key_value(t, k)
					if (v is Quaternion and not (v as Quaternion).is_finite()) or (v is Vector3 and not (v as Vector3).is_finite()):
						nan_o = true
			ok(rot_o >= comunes_o - 1 and not nan_o, "F %s trae «%s»: %.2f s, %d pistas de rotación (huesos comunes %d), NaN=%s" % [id_o, alt, an_o.length, rot_o, comunes_o, nan_o])
		for rol in (ROLES_ANTES[id_o] as Dictionary).keys():
			var ahora: String = pj_o.clip_de(String(rol)).to_lower()
			var antes: String = String((ROLES_ANTES[id_o] as Dictionary)[rol])
			ok(ahora == antes, "F %s: el rol «%s» sigue resolviendo a «%s» (ahora «%s»)" % [id_o, rol, antes, ahora])
		pj_o.queue_free()
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
