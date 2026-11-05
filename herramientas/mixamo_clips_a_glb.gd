extends SceneTree
## JUNTA varios clips FBX de Mixamo (solo esqueleto, sin malla: los de la carpeta `animation_motion` del dataset Linzhan/Mixamo-Animations-Characters, o los que
## se bajan de mixamo.com «Without Skin») en UN solo .glb con esqueleto y AnimationPlayer, del mismo tipo que arte/meshy/jugadora_carga_clips.glb: una FUENTE
## más para ClipsFamilia (ver jugador/clips_familia.gd FUENTES) o para `traducir_clip`.
##   tools/Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/mixamo_clips_a_glb.gd -- <glb_salida> <clip1.fbx> [<clip2.fbx> ...]
## Cada clip se llama como su archivo sin extensión (Two_Hand_Spell_Casting.fbx -> «Two_Hand_Spell_Casting»); Mixamo los llama a todos «mixamo.com».
## El importador de Godot ya convierte los huesos `mixamorig:X` del FBX en `mixamorig_X` (el prefijo del proyecto): no hay que renombrar nada.
## Imprime los huesos del esqueleto y, por clip, duración y pistas. No toca la escala: el FBX de Mixamo viene en cm (cadera ~100) y ClipsFamilia reescala la
## traslación de la cadera por la relación de alturas de cadera, así que da igual la unidad.

const SUFIJO_FBX: String = ".fbx"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <glb_salida> <clip1.fbx> [<clip2.fbx> ...]")
		quit(2)
		return
	var salida: String = a[0]
	var base: Node = null
	var ruta_sk: String = ""
	var ap_base: AnimationPlayer = null
	var lib := AnimationLibrary.new()
	var n_ok: int = 0
	for k in range(1, a.size()):
		var ruta: String = a[k]
		var esc: Node = _cargar(ruta)
		if esc == null:
			continue
		var sk: Skeleton3D = _esqueleto(esc)
		var ap: AnimationPlayer = _reproductor(esc)
		if sk == null or ap == null:
			push_error("%s: sin esqueleto o sin AnimationPlayer (huesos=%s, clips=%s)" % [ruta, sk != null, ap != null])
			esc.free()
			continue
		var nombre: String = ruta.get_file().trim_suffix(SUFIJO_FBX).trim_suffix(SUFIJO_FBX.to_upper())
		if base == null:
			base = esc
			ruta_sk = str(base.get_path_to(sk))
			ap_base = ap
			print("ESQUELETO huesos=%d ruta=%s cadera_y=%.3f" % [sk.get_bone_count(), ruta_sk, sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin.y if sk.find_bone("mixamorig_Hips") >= 0 else -1.0])
			for i in sk.get_bone_count():
				print("  hueso %2d %s" % [i, sk.get_bone_name(i)])
		else:
			if sk.get_bone_count() != _esqueleto(base).get_bone_count():
				push_warning("%s: %d huesos, el primero tiene %d (las pistas de huesos que no existan se pierden al traducir)" % [ruta, sk.get_bone_count(), _esqueleto(base).get_bone_count()])
		var ruta_sk_este: String = str(esc.get_path_to(sk))
		for viejo in ap.get_animation_list():
			var an: Animation = ap.get_animation(viejo).duplicate(true)
			for t in an.get_track_count():
				var p: String = str(an.track_get_path(t))
				if p.begins_with(ruta_sk_este):
					an.track_set_path(t, NodePath(ruta_sk + p.substr(ruta_sk_este.length())))
			var final: String = nombre if ap.get_animation_list().size() == 1 else nombre + "_" + String(viejo).replace(".", "_")
			lib.add_animation(final, an)
			print("CLIP %-40s %.2f s  pistas=%d  (era «%s», bucle=%d)" % [final, an.length, an.get_track_count(), viejo, an.loop_mode])
			n_ok += 1
		if esc != base:
			esc.free()
	if base == null or n_ok == 0:
		push_error("ningún clip válido")
		quit(1)
		return
	# Una malla mínima con piel: sin `skins` en el GLB, el importador de Godot no crea el Skeleton3D (deja los huesos como Node3D sueltos) y ClipsFamilia
	# no lo encuentra. Es lo mismo que conserva arte/meshy/solo_clips.py. Un triángulo invisible de 3 vértices pegado a la cadera.
	_malla_minima(_esqueleto(base), base)
	# El AnimationPlayer del primero se sustituye por uno limpio con TODOS los clips.
	var padre: Node = ap_base.get_parent()
	padre.remove_child(ap_base)
	ap_base.free()
	var ap_nuevo := AnimationPlayer.new()
	ap_nuevo.name = "AnimationPlayer"
	base.add_child(ap_nuevo)
	ap_nuevo.owner = base
	ap_nuevo.add_animation_library("", lib)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: int = doc.append_from_scene(base, estado)
	if err != OK:
		push_error("append_from_scene falló (%d)" % err)
		quit(1)
		return
	err = doc.write_to_filesystem(estado, salida)
	print("EXPORTADO %s  clips=%d (err %d)" % [salida, n_ok, err])
	quit(0 if err == OK else 1)


func _malla_minima(sk: Skeleton3D, raiz: Node) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0.001, 0, 0), Vector3(0, 0.001, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "PielMinima"
	mi.mesh = m
	var piel: Skin = sk.create_skin_from_rest_transforms()
	for b in piel.get_bind_count():
		piel.set_bind_name(b, sk.get_bone_name(piel.get_bind_bone(b)))
	mi.skin = piel
	sk.add_child(mi)
	mi.owner = raiz
	mi.skeleton = mi.get_path_to(sk)


func _cargar(ruta: String) -> Node:
	var doc := FBXDocument.new()
	var estado := FBXState.new()
	var err: int = doc.append_from_file(ruta, estado)
	if err != OK:
		push_error("no se pudo leer %s (%d)" % [ruta, err])
		return null
	return doc.generate_scene(estado)


func _esqueleto(n: Node) -> Skeleton3D:
	var l: Array[Node] = n.find_children("*", "Skeleton3D", true, false)
	return l[0] as Skeleton3D if not l.is_empty() else null


func _reproductor(n: Node) -> AnimationPlayer:
	var l: Array[Node] = n.find_children("*", "AnimationPlayer", true, false)
	return l[0] as AnimationPlayer if not l.is_empty() else null
