extends SceneTree
## RETARGET HIENA -> CANOURO (prueba, primer pase; 20/10, Pipeline).
## Lee los 27 clips de la hiena (Hyenas_A3_AllMotion.fbx) y los reescribe sobre el esqueleto del canouro (51 huesos «Wolf»),
## en una AnimationLibrary que se guarda aparte. NO toca canouro.glb: si la prueba no gusta, se borra el .res y no ha pasado nada.
##
## Uso (desde la raíz del repo; el FBX no se versiona, pesa 34 MB; déjalo en arte/origen/ e impórtalo antes con --import):
##   godot --headless --path . -s res://herramientas/retargetear_hiena.gd
##   godot --headless --path . -s res://herramientas/retargetear_hiena.gd -- <hiena.fbx> <canouro.glb> <salida.res>
##
## Por qué «delta global»: los dos modelos miran a +Z con Y arriba, así que el giro que una pieza de la hiena hace respecto a su
## postura de reposo, medido en el espacio del modelo, se puede aplicar tal cual a la pieza equivalente del canouro:
##   G_canouro_anim = (G_hiena_anim · G_hiena_reposo⁻¹) · G_canouro_reposo ; local = G_padre_anim⁻¹ · G_canouro_anim
## Así no importa que los huesos locales de cada rig tengan ejes distintos. Posiciones: solo el bote vertical de la pelvis (× K_ESCALA,
## porque la hiena es ~1,75 veces más grande) sobre el hueso raíz «Body»; el avance lo decide el juego, no el clip.
##
## Límites conocidos (por eso es «prueba»): la hiena tiene patas más largas, así que en Run/Walk las patas del canouro se ven algo
## estiradas; los pies/dedos (toe, finger) y los huesos IK/PoleTarget del canouro no se tocan; Tail7/8 y Neck3 siguen a su padre;
## las orejas solo reciben el giro del primer hueso. Los clips cortos se muestrean a 30 fps hasta la última clave real (el FBX
## declara 16,52 s en todos, pero cada clip acaba antes).
const FPS: float = 30.0
const K_ESCALA: float = 0.57
const PREFIJO_POR_DEFECTO: String = "AnimalArmature/Skeleton3D"   ## ruta de pista de los clips del canouro; se lee del propio GLB
const MAPA: Dictionary = {   ## hueso del canouro -> hueso equivalente de la hiena
	"Back": "bip01_pelvis", "Torso": "bip01_spine", "Torso2": "bip01_spine1", "Torso3": "bip01_spine2",
	"Neck1": "bip01_neck", "Neck2": "bip01_neck1", "Head": "bip01_head",
	"Ear1.R": "bip01_ponytail1", "Ear1.L": "bip01_ponytail2",
	"FrontShoulder.L": "bip01_l_clavicle", "FrontUpperLeg.L": "bip01_l_upperarm", "FrontLowerLeg.L": "bip01_l_forearm",
	"FrontShoulder.R": "bip01_r_clavicle", "FrontUpperLeg.R": "bip01_r_upperarm", "FrontLowerLeg.R": "bip01_r_forearm",
	"BackLeg.L": "bip01_l_thigh", "BackUpperLeg.L": "bip01_l_calf", "BackLowerLeg.L": "bip01_l_horselink",
	"BackLeg.R": "bip01_r_thigh", "BackUpperLeg.R": "bip01_r_calf", "BackLowerLeg.R": "bip01_r_horselink",
	"Tail1": "bone01", "Tail2": "bone02", "Tail3": "bone03", "Tail4": "bone04", "Tail5": "bone05", "Tail6": "bone06"}


func _init() -> void:
	# Un fotograma antes de tocar nada: en _init el árbol aún no ha arrancado y los esqueletos no actualizan sus poses globales
	# (medido: sin esta espera todas las claves salían idénticas, es decir, un retarget que no se mueve).
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ruta_fbx: String = args[0] if args.size() > 0 else "res://arte/origen/Hyenas_A3_AllMotion.fbx"
	var ruta_glb: String = args[1] if args.size() > 1 else "res://arte/modelos/canouro.glb"
	var ruta_out: String = args[2] if args.size() > 2 else "res://arte/modelos/canouro_hiena.res"
	if not ResourceLoader.exists(ruta_fbx) or not ResourceLoader.exists(ruta_glb):
		push_error("retargetear_hiena: no encuentro " + ruta_fbx + " o " + ruta_glb + " (¿falta --import?)")
		quit(1)
		return
	var h: Node = (load(ruta_fbx) as PackedScene).instantiate()
	var c: Node = (load(ruta_glb) as PackedScene).instantiate()
	root.add_child(h)
	root.add_child(c)
	var hs: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
	var cs: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
	var hap: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
	var cap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
	var prefijo: String = PREFIJO_POR_DEFECTO
	var primero: Animation = cap.get_animation(cap.get_animation_list()[0])
	if primero.get_track_count() > 0:
		prefijo = String(primero.track_get_path(0)).get_slice(":", 0)
	var pares: Dictionary = {}        # índice del hueso del canouro -> índice del hueso de la hiena
	for cn in MAPA:
		var ci: int = cs.find_bone(cn)
		var hi: int = hs.find_bone(MAPA[cn])
		if ci < 0 or hi < 0:
			push_warning("retargetear_hiena: falta el hueso " + String(cn) + " / " + String(MAPA[cn]))
			continue
		pares[ci] = hi
	hs.reset_bone_poses()
	var hrest: Array[Transform3D] = []
	for i in hs.get_bone_count():
		hrest.append(hs.get_bone_global_rest(i))
	var crest: Array[Transform3D] = []
	for i in cs.get_bone_count():
		crest.append(cs.get_bone_global_rest(i))
	var i_pelvis: int = hs.find_bone("bip01_pelvis")
	var i_body: int = cs.find_bone("Body")
	var lib := AnimationLibrary.new()
	for nombre in hap.get_animation_list():
		var an: Animation = hap.get_animation(nombre)
		var largo: float = 0.0       # la longitud declarada miente (16,52 s): vale la última clave real
		for t in an.get_track_count():
			var n: int = an.track_get_key_count(t)
			if n > 0:
				largo = maxf(largo, an.track_get_key_time(t, n - 1))
		var out := Animation.new()
		out.length = maxf(largo, 0.05)
		out.loop_mode = Animation.LOOP_LINEAR
		var pasos: int = maxi(2, int(ceil(largo * FPS)) + 1)
		var t_rot: Dictionary = {}
		for ci in pares.keys():
			var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(tr, NodePath("%s:%s" % [prefijo, cs.get_bone_name(ci)]))
			t_rot[ci] = tr
		var t_body: int = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(t_body, NodePath("%s:Body" % prefijo))
		var pistas: Array = []
		for t in an.get_track_count():
			var tp: int = an.track_get_type(t)
			if tp == Animation.TYPE_ROTATION_3D or tp == Animation.TYPE_POSITION_3D:
				var b: int = hs.find_bone(String(an.track_get_path(t)).get_slice(":", 1))
				if b >= 0:
					pistas.append([t, tp, b])
		var g_anim: Array[Basis] = []
		g_anim.resize(cs.get_bone_count())
		for p in pasos:
			var tt: float = float(p) / FPS if p < pasos - 1 else largo
			tt = minf(tt, largo)
			hs.reset_bone_poses()
			for pi_ in pistas:
				if pi_[1] == Animation.TYPE_ROTATION_3D:
					hs.set_bone_pose_rotation(pi_[2], an.rotation_track_interpolate(pi_[0], tt))
				else:
					hs.set_bone_pose_position(pi_[2], an.position_track_interpolate(pi_[0], tt))
			var dy: float = (hs.get_bone_global_pose(i_pelvis).origin.y - hrest[i_pelvis].origin.y) * K_ESCALA
			out.position_track_insert_key(t_body, tt, cs.get_bone_rest(i_body).origin + Vector3(0.0, dy, 0.0))
			for ci in cs.get_bone_count():           # los padres van antes que los hijos en los dos rigs
				var par: int = cs.get_bone_parent(ci)
				var base_padre: Basis = g_anim[par] if par >= 0 else Basis.IDENTITY
				if pares.has(ci):
					var hi: int = pares[ci]
					var delta: Basis = hs.get_bone_global_pose(hi).basis * hrest[hi].basis.inverse()
					var g: Basis = delta * crest[ci].basis
					out.rotation_track_insert_key(t_rot[ci], tt, (base_padre.inverse() * g).get_rotation_quaternion())
					g_anim[ci] = g
				else:
					g_anim[ci] = base_padre * cs.get_bone_rest(ci).basis
		lib.add_animation(StringName(String(nombre).replace("Hyenas_A15_", "Hiena_")), out)
		print("  ", nombre, "  ", snappedf(largo, 0.01), " s  ", pasos, " fotogramas")
	var err: int = ResourceSaver.save(lib, ruta_out)
	print("retargetear_hiena: ", lib.get_animation_list().size(), " clips -> ", ruta_out, " (error ", err, ")")
	quit(0 if err == OK else 1)
