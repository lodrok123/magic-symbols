extends SceneTree
## CONVIERTE un personaje FBX de Meshy (el riggeado + el FBX de animaciones fusionadas) a un único .glb, como el resto de personajes de arte/modelos.
##   godot --headless --path . --script res://herramientas/convertir_fbx_a_glb.gd -- <fbx_personaje> <fbx_animaciones> <glb_salida> [<lado_texturas>]
## Carga los dos FBX con FBXDocument (FBXState), le pasa al personaje TODOS los clips del segundo y exporta con GLTFDocument.
## Lo que arregla por el camino (Meshy exporta así):
##   - Los huesos del personaje se llaman `smartrig_*` y las pistas de los clips `mixamorig_*` (el prefijo que usa el proyecto): se renombran los huesos a `mixamorig_*`.
##   - Las pistas apuntan a `target_character/Skeleton3D`, que en el personaje se llama `SmartRigArmature/Skeleton3D`: se reescriben las rutas.
##   - Las texturas vienen a 2048 en PNG (5 MB la de color): se reducen a `lado_texturas` (1024 por defecto, como goblin_warrior_chibi) y metálico+rugosidad
##     se funden en una sola imagen (canal G rugosidad, B metálico, como el `_rm` de goblin_base). Todo se incrusta como JPEG.
## Imprime huesos, altura y clips (nombre, duración). El .glb sale con escala de armadura 100 (la del FBX en cm); Pj3D mide y escala solo.

const PREFIJO_VIEJO: String = "smartrig_"
const PREFIJO_NUEVO: String = "mixamorig_"
const RAIZ_PISTAS_VIEJA: String = "target_character/"
const SUFIJO_FBX_PERSONAJE: String = "_Character_output.fbx"
const SUFIJO_TEXTURA: String = "_texture_0"
const SUFIJO_RUGOSIDAD: String = "_roughness.png"
const SUFIJO_METALICO: String = "_metallic.png"
const LADO_TEXTURAS: int = 1024
const CALIDAD_JPEG: float = 0.9


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <fbx_personaje> <fbx_animaciones> <glb_salida> [<lado_texturas>]")
		quit(2)
		return
	var lado: int = int(a[3]) if a.size() > 3 else LADO_TEXTURAS
	var raiz_p: Node = _cargar(a[0])
	var raiz_a: Node = _cargar(a[1])
	if raiz_p == null or raiz_a == null:
		quit(1)
		return
	var sk: Skeleton3D = _esqueleto(raiz_p)
	var ruta_sk: String = str(raiz_p.get_path_to(sk))
	print("PERSONAJE huesos=%d esqueleto=%s" % [sk.get_bone_count(), ruta_sk])
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i)
		if n.begins_with(PREFIJO_VIEJO):
			sk.set_bone_name(i, PREFIJO_NUEVO + n.substr(PREFIJO_VIEJO.length()))
	_enderezar(sk, raiz_p.find_children("*", "MeshInstance3D", true, false))
	var ap_a: AnimationPlayer = _reproductor(raiz_a)
	var ap_p := AnimationPlayer.new()
	ap_p.name = "AnimationPlayer"
	raiz_p.add_child(ap_p)
	ap_p.owner = raiz_p
	var lib := AnimationLibrary.new()
	for nombre in ap_a.get_animation_list():
		var an: Animation = ap_a.get_animation(nombre).duplicate(true)
		for i in an.get_track_count():
			var ruta: String = str(an.track_get_path(i))
			if ruta.begins_with(RAIZ_PISTAS_VIEJA + "Skeleton3D"):
				an.track_set_path(i, NodePath(ruta_sk + ruta.substr((RAIZ_PISTAS_VIEJA + "Skeleton3D").length())))
		lib.add_animation(nombre, an)
		print("CLIP %s  %.2f s  pistas=%d" % [nombre, an.length, an.get_track_count()])
	ap_p.add_animation_library("", lib)
	for m in raiz_p.find_children("*", "MeshInstance3D", true, false):
		_reducir_materiales(m as MeshInstance3D, lado, a[0].trim_suffix(SUFIJO_FBX_PERSONAJE) + SUFIJO_TEXTURA)
	var doc := GLTFDocument.new()
	doc.image_format = "JPEG"
	doc.lossy_quality = CALIDAD_JPEG
	var estado := GLTFState.new()
	var err: int = doc.append_from_scene(raiz_p, estado)
	if err != OK:
		push_error("append_from_scene falló (%d)" % err)
		quit(1)
		return
	err = doc.write_to_filesystem(estado, a[2])
	print("EXPORTADO %s (err %d)" % [a[2], err])
	quit(0 if err == OK else 1)


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


## Reduce las texturas del material a `lado` y funde metálico+rugosidad en una sola.
func _reducir_materiales(mi: MeshInstance3D, lado: int, base_png: String) -> void:
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null:
			continue
		print("MATERIAL ", mat.resource_name, " albedo=", mat.albedo_texture, " normal=", mat.normal_texture, " rough=", mat.roughness_texture, " metal=", mat.metallic_texture)
		if mat.albedo_texture != null:
			mat.albedo_texture = _pequena(mat.albedo_texture, lado)
		if mat.normal_texture != null:
			mat.normal_texture = _pequena(mat.normal_texture, lado)
		# El importador de FBX no trae rugosidad ni metálico: se leen de los PNG hermanos del FBX.
		var rug: Image = _imagen(mat.roughness_texture if mat.roughness_texture != null else _desde_disco(base_png + SUFIJO_RUGOSIDAD), lado)
		var met: Image = _imagen(mat.metallic_texture if mat.metallic_texture != null else _desde_disco(base_png + SUFIJO_METALICO), lado)
		if rug != null or met != null:
			var base: Image = rug if rug != null else met
			var rm := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGB8)
			for y in base.get_height():
				for x in base.get_width():
					var r: float = rug.get_pixel(x, y).r if rug != null else 1.0
					var m: float = met.get_pixel(x, y).r if met != null else 0.0
					rm.set_pixel(x, y, Color(1.0, r, m))
			var tex := ImageTexture.create_from_image(rm)
			mat.roughness_texture = tex
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.metallic_texture = tex
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE


## El FBX del personaje trae la armadura girada -90° en X (esqueleto y malla con Z hacia arriba) y el de animaciones la trae sin girar (Y hacia arriba): los clips
## del hueso raíz están escritos para el segundo, y Pj3D mide y supone la cadera con Y hacia arriba como en el resto de GLB. Se endereza el personaje:
##   - la armadura pasa a no llevar giro y ese giro (inverso) se mete en el reposo del hueso raíz (los demás huesos son locales);
##   - los vértices (posición, normal, tangente) de la malla se giran igual, y a cada pose de enlace del Skin se le añade el giro inverso
##     (inversa de enlace' = inversa de enlace · giro⁻¹), de modo que en reposo todo queda como estaba pero de pie.
func _enderezar(sk: Skeleton3D, mallas: Array[Node]) -> void:
	var armadura := sk.get_parent() as Node3D
	var giro := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(armadura.rotation_degrees.x)), Vector3.ZERO)
	armadura.rotation_degrees = Vector3.ZERO
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) >= 0:
			continue
		var reposo: Transform3D = giro * sk.get_bone_rest(i)
		sk.set_bone_rest(i, reposo)
		sk.set_bone_pose_position(i, reposo.origin)
		sk.set_bone_pose_rotation(i, reposo.basis.get_rotation_quaternion())
		sk.set_bone_pose_scale(i, reposo.basis.get_scale())
	for m in mallas:
		var mi := m as MeshInstance3D
		var nueva := ArrayMesh.new()
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var vert: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for k in vert.size():
				vert[k] = giro.basis * vert[k]
			arrays[Mesh.ARRAY_VERTEX] = vert
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for k in nor.size():
					nor[k] = giro.basis * nor[k]
				arrays[Mesh.ARRAY_NORMAL] = nor
			if arrays[Mesh.ARRAY_TANGENT] != null:
				var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for k in range(0, tan.size(), 4):
					var t: Vector3 = giro.basis * Vector3(tan[k], tan[k + 1], tan[k + 2])
					tan[k] = t.x
					tan[k + 1] = t.y
					tan[k + 2] = t.z
				arrays[Mesh.ARRAY_TANGENT] = tan
			nueva.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(s), arrays)
			nueva.surface_set_material(s, mi.mesh.surface_get_material(s))
		mi.mesh = nueva
		if mi.skin != null:
			var skin: Skin = mi.skin.duplicate()
			for b in skin.get_bind_count():
				skin.set_bind_pose(b, skin.get_bind_pose(b) * giro.affine_inverse())
			mi.skin = skin


func _desde_disco(ruta: String) -> Texture2D:
	var img := Image.load_from_file(ruta)
	return ImageTexture.create_from_image(img) if img != null else null


func _imagen(t: Texture2D, lado: int) -> Image:
	if t == null:
		return null
	var img: Image = t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() > lado:
		img.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
	return img


func _pequena(t: Texture2D, lado: int) -> Texture2D:
	return ImageTexture.create_from_image(_imagen(t, lado))
