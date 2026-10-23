extends SceneTree
## MONTA una prenda de la jugadora base como .glb con EL MISMO esqueleto: toma lo que escribe `herramientas/rig/encajar_ropa.py` (geometría y pesos en .json,
## texturas en .png) y lo pone sobre una copia de la escena de `jugadora_base.glb` en lugar de su malla, con el Skin de la base (mismos huesos, mismas poses
## de enlace). Así no hay una reexportación de Blender que reoriente huesos. Sin ventana:
##   godot --headless --path . --script res://herramientas/montar_ropa_glb.gd -- <carpeta_blender> <prenda> <glb_salida> [<nombre_malla>]
## <prenda> = nombre del .json (capa, tunica). Las texturas son las comunes a las dos prendas: ropa_basecolor.png, ropa_normal.png y ropa_rm.png.

const GLB_BASE: String = "res://arte/modelos/jugadora_base.glb"
const CALIDAD_JPEG: float = 0.9
const LADO_TEXTURAS: int = 1024
## Rugosidad en el canal verde y metálico en el azul (como el `_rm` de goblin_base).
const ROUGHNESS_MIN: float = 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <carpeta_blender> <prenda> <glb_salida> [<nombre_malla>]")
		quit(2)
		return
	var carpeta: String = a[0]
	var f := FileAccess.open("%s/%s.json" % [carpeta, a[1]], FileAccess.READ)
	if f == null:
		push_error("no se pudo abrir el json de la prenda")
		quit(1)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var escena: Node = (load(GLB_BASE) as PackedScene).instantiate()
	var sk: Skeleton3D = escena.find_children("*", "Skeleton3D", true, false)[0]
	var viejo: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = viejo.skin
	# Índice de enlace del Skin de cada hueso (los .json llevan los huesos por nombre).
	var enlace_de: Dictionary = {}
	for b in skin.get_bind_count():
		var nombre: String = skin.get_bind_name(b)
		if nombre == "" and skin.get_bind_bone(b) >= 0:
			nombre = sk.get_bone_name(skin.get_bind_bone(b))
		enlace_de[nombre] = b
	var huesos: Array = d["huesos"]
	var al_enlace: Array = []
	for h in huesos:
		if not enlace_de.has(String(h)):
			push_error("el Skin de la base no tiene el hueso %s" % h)
			quit(1)
			return
		al_enlace.append(int(enlace_de[String(h)]))
	var pos: Array = d["pos"]
	var nor: Array = d["nor"]
	var uv: Array = d["uv"]
	var jn: Array = d["joints"]
	var pe: Array = d["weights"]
	var idx: Array = d["idx"]
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pos.size():
		st.set_normal(Vector3(nor[i][0], nor[i][1], nor[i][2]))
		st.set_uv(Vector2(uv[i][0], uv[i][1]))
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for k in 4:
			bones.append(int(al_enlace[int(jn[i][k])]))
			weights.append(float(pe[i][k]))
		st.set_bones(bones)
		st.set_weights(weights)
		st.add_vertex(Vector3(pos[i][0], pos[i][1], pos[i][2]))
	# Godot tiene por cara delantera el sentido horario; Blender y glTF, el antihorario: se invierte cada triángulo.
	for t in range(0, idx.size(), 3):
		st.add_index(int(idx[t]))
		st.add_index(int(idx[t + 2]))
		st.add_index(int(idx[t + 1]))
	st.generate_tangents()
	var malla: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.resource_name = "ropa"
	mat.albedo_texture = _textura("%s/ropa_basecolor.png" % carpeta)
	mat.normal_enabled = true
	mat.normal_texture = _textura("%s/ropa_normal.png" % carpeta)
	var rm: Texture2D = _textura("%s/ropa_rm.png" % carpeta)
	mat.roughness_texture = rm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic_texture = rm
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 1.0
	mat.roughness = 1.0
	malla.surface_set_material(0, mat)
	var nuevo := MeshInstance3D.new()
	nuevo.name = a[3] if a.size() > 3 else a[1]
	nuevo.mesh = malla
	nuevo.skin = skin
	var padre: Node = viejo.get_parent()
	padre.add_child(nuevo)
	nuevo.owner = escena
	nuevo.skeleton = NodePath("..")
	nuevo.transform = viejo.transform
	padre.remove_child(viejo)
	viejo.free()
	var doc := GLTFDocument.new()
	doc.image_format = "JPEG"
	doc.lossy_quality = CALIDAD_JPEG
	var estado := GLTFState.new()
	var err: int = doc.append_from_scene(escena, estado)
	if err == OK:
		err = doc.write_to_filesystem(estado, a[2])
	print("EXPORTADO %s (err %d): %d vértices, %d triángulos, %d huesos con peso" % [a[2], err, pos.size(), idx.size() / 3, huesos.size()])
	quit(0 if err == OK else 1)


func _textura(ruta: String) -> Texture2D:
	var img := Image.load_from_file(ruta)
	if img == null:
		return null
	if img.get_width() > LADO_TEXTURAS:
		img.resize(LADO_TEXTURAS, LADO_TEXTURAS, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	return ImageTexture.create_from_image(img)
