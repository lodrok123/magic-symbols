extends SceneTree
## MONTA una prenda de la jugadora base como .glb con EL MISMO esqueleto: toma lo que escribe `herramientas/rig/encajar_ropa.py` (geometría y pesos en .json,
## texturas en .png) y lo pone sobre una copia de la escena de `jugadora_base.glb` en lugar de su malla, con el Skin de la base (mismos huesos, mismas poses
## de enlace). Así no hay una reexportación de Blender que reoriente huesos. Sin ventana:
##   godot --headless --path . --script res://herramientas/montar_ropa_glb.gd -- <carpeta_blender> <prenda> <glb_salida> [<nombre_malla> [muelles]]
## Con `muelles` (la capa) añade al esqueleto exportado las cadenas de CapaMuelles3D y les pasa el peso de la mitad baja (ver `_muelles`).
## <prenda> = nombre del .json (capa, tunica). Las texturas son las comunes a las dos prendas: ropa_basecolor.png, ropa_normal.png y ropa_rm.png.

const GLB_BASE: String = "res://arte/modelos/jugadora_base.glb"
const CALIDAD_JPEG: float = 0.9
const LADO_TEXTURAS: int = 1024
## Rugosidad en el canal verde y metálico en el azul (como el `_rm` de goblin_base).
const ROUGHNESS_MIN: float = 0.0
## 5.º argumento: la prenda lleva las cadenas de muelles de la capa (CapaMuelles3D).
const MUELLES: String = "muelles"


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
	var skin: Skin = viejo.skin.duplicate() as Skin
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
	if a.size() > 4 and a[4] == MUELLES:
		_muelles(sk, skin, enlace_de, al_enlace, pos, jn, pe, idx)
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


## Capa con muelles (CapaMuelles3D): añade al esqueleto que se exporta las cadenas `capa_<sector>_1/2/3` (hijas de Spine2, en reposo sobre la malla), mete sus
## binds en el Skin (por nombre: en el juego Ropa3D copia los huesos al esqueleto del cuerpo antes de colgar la malla) y pasa a ellas el peso de la mitad baja
## de la capa (`CapaMuelles3D.pesos_cadena`): el borde, casi entero en `_2`. Reescribe `al_enlace`, `jn` y `pe` (4 influencias, normalizadas).
## 24/10 (segunda versión, ver CapaMuelles3D «REPARTO DE PESOS»): antes de repartir, todo el peso de hombros, brazos, antebrazos y manos que traía Blender pasa a
## Spine2 (en TODA la capa, no solo abajo), y al final se suavizan los pesos con los vecinos (`idx`, soldados por posición) SUAVIZADO_PASADAS veces.
## 25/10 (ver CapaMuelles3D «SIN CABEZA» y «NUCA»): antes de las cadenas se hornea la cabeza encogida y se pega la nuca (reescribe también `pos`), y la capa no
## lleva peso de Head: lo de Head y Neck pasa a Spine2, salvo el anillo del cierre (algo de Neck).
func _muelles(sk: Skeleton3D, skin: Skin, enlace_de: Dictionary, al_enlace: Array, pos: Array, jn: Array, pe: Array, idx: Array) -> void:
	var escala: float = (sk.get_parent() as Node3D).scale.y
	var b_padre: int = int(enlace_de[CapaMuelles3D.HUESO_PADRE])
	var malla_a_esqueleto: Transform3D = sk.get_bone_global_rest(sk.find_bone(CapaMuelles3D.HUESO_PADRE)) * skin.get_bind_pose(b_padre)
	var verts := PackedVector3Array()
	for p in pos:
		verts.append(Vector3(p[0], p[1], p[2]))
	# 0. 25/10 (CapaMuelles3D «SIN CABEZA» y «NUCA»): ANTES de calcular las cadenas, la forma de la parte alta: la cabeza encogida de Pj3D.PROPORCIONES
	# horneada con el peso de Head de Blender y la nuca pegada a la espalda (lo mismo que herramientas/repesar_capa.gd sobre una capa ya montada)
	var nombre_base: Dictionary = {}
	for n in enlace_de:
		nombre_base[int(enlace_de[n])] = String(n)
	var cuello: Vector3 = sk.get_bone_global_rest(sk.find_bone(CapaMuelles3D.HUESO_CUELLO)).origin * escala
	var cabeza: Vector3 = sk.get_bone_global_rest(sk.find_bone("mixamorig_Head")).origin * escala
	var escala_cabeza: float = float((Pj3D.PROPORCIONES.get("jugadora_base", [1.0]) as Array)[0])
	var forma := PackedVector3Array()
	for i in verts.size():
		var h: float = 0.0
		for k in 4:
			var nb: String = String(nombre_base.get(int(al_enlace[int(jn[i][k])]), ""))
			if CapaMuelles3D.es_hueso_cabeza(nb) and nb != CapaMuelles3D.HUESO_CUELLO:
				h += float(pe[i][k])
		forma.append(CapaMuelles3D.encoger_con_cabeza(malla_a_esqueleto * verts[i] * escala, h, cabeza, escala_cabeza))
	forma = CapaMuelles3D.ajustar_nuca(forma, Vector2(cuello.x, cuello.z))
	for i in verts.size():
		verts[i] = malla_a_esqueleto.affine_inverse() * (forma[i] / escala)
		pos[i] = [verts[i].x, verts[i].y, verts[i].z]
	var globales: Dictionary = {}
	for c in CapaMuelles3D.cadenas(sk, verts, malla_a_esqueleto, escala):
		var j: int = sk.get_bone_count()
		sk.add_bone(String(c["nombre"]))
		var padre: int = sk.find_bone(String(c["padre"]))
		sk.set_bone_parent(j, padre)
		var g_padre: Transform3D = globales.get(String(c["padre"]), sk.get_bone_global_rest(padre))
		sk.set_bone_rest(j, g_padre.affine_inverse() * (c["global"] as Transform3D))
		globales[String(c["nombre"])] = c["global"]
		skin.add_named_bind(String(c["nombre"]), (c["global"] as Transform3D).affine_inverse() * malla_a_esqueleto)
		enlace_de[String(c["nombre"])] = skin.get_bind_count() - 1
	sk.reset_bone_poses()
	var pts := PackedVector3Array()
	for v in verts:
		pts.append(malla_a_esqueleto * v * escala)
	var borde: float = INF
	for p in pts:
		borde = minf(borde, p.y)
	var centro: Vector2 = CapaMuelles3D._centro(pts, borde)
	var nombre_de_bind: Dictionary = {}
	for n in enlace_de:
		nombre_de_bind[int(enlace_de[n])] = String(n)
	var bind_cuerpo: int = int(enlace_de[CapaMuelles3D.HUESO_CUERPO_CAPA])
	# 1. pesos por vértice como diccionario {bind: peso}: los de Blender con los brazos pasados a Spine2, mezclados con las cadenas
	var pesos: Array = []
	var hechos: int = 0
	var quitado_brazo: float = 0.0
	for i in verts.size():
		var w: Dictionary = {}
		for k in 4:
			var bind: int = int(al_enlace[int(jn[i][k])])
			var v: float = float(pe[i][k])
			if v <= 0.0:
				continue
			if CapaMuelles3D.es_hueso_brazo(String(nombre_de_bind.get(bind, ""))):
				quitado_brazo += v
				bind = bind_cuerpo
			w[bind] = float(w.get(bind, 0.0)) + v
		# sin cabeza: Head (y Neck) a Spine2, salvo el anillo del cierre, que lleva algo de Neck (CapaMuelles3D.pesos_sin_cabeza)
		var por_nombre: Dictionary = {}
		for bind in w:
			por_nombre[String(nombre_de_bind[bind])] = w[bind]
		por_nombre = CapaMuelles3D.pesos_sin_cabeza(por_nombre, pts[i], cuello)
		w = {}
		for n in por_nombre:
			w[int(enlace_de[n])] = por_nombre[n]
		var r: Dictionary = CapaMuelles3D.pesos_cadena(pts[i], centro, borde)
		var parte: float = float(r["parte"])
		if parte > 0.0:
			for bind in w:
				w[bind] = float(w[bind]) * (1.0 - parte)
			for nombre in (r["pesos"] as Dictionary):
				var bind: int = int(enlace_de[nombre])
				w[bind] = float(w.get(bind, 0.0)) + float(r["pesos"][nombre])
			hechos += 1
		pesos.append(w)
	# 2. suavizado con los vecinos (vértices soldados por posición, aristas de los triángulos)
	var grupo_pos: Dictionary = {}
	var id_de: PackedInt32Array = PackedInt32Array()
	id_de.resize(verts.size())
	for i in verts.size():
		var key: Vector3i = Vector3i((verts[i] * 1e5).round())
		if not grupo_pos.has(key):
			grupo_pos[key] = i
		id_de[i] = int(grupo_pos[key])
	var vecinos: Dictionary = {}
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a: int = id_de[int(idx[t + e])]
			var c: int = id_de[int(idx[t + (e + 1) % 3])]
			if a == c:
				continue
			if not vecinos.has(a):
				vecinos[a] = {}
			if not vecinos.has(c):
				vecinos[c] = {}
			vecinos[a][c] = true
			vecinos[c][a] = true
	for _pasada in CapaMuelles3D.SUAVIZADO_PASADAS:
		var nuevo: Dictionary = {}
		for g in vecinos:
			var media: Dictionary = {}
			var n: int = 0
			for h in vecinos[g]:
				for bind in pesos[h]:
					media[bind] = float(media.get(bind, 0.0)) + float(pesos[h][bind])
				n += 1
			var w: Dictionary = {}
			for bind in pesos[g]:
				w[bind] = float(pesos[g][bind]) * (1.0 - CapaMuelles3D.SUAVIZADO_MEZCLA)
			for bind in media:
				w[bind] = float(w.get(bind, 0.0)) + float(media[bind]) / maxf(n, 1) * CapaMuelles3D.SUAVIZADO_MEZCLA
			nuevo[g] = w
		for g in nuevo:
			pesos[g] = nuevo[g]
	# 3. a 4 influencias, normalizadas; los vértices soldados comparten los pesos de su grupo
	for i in verts.size():
		var w: Dictionary = pesos[id_de[i]]
		var orden: Array = w.keys()
		orden.sort_custom(func(x, y): return float(w[x]) > float(w[y]))
		var js2: Array = []
		var ws: Array = []
		var tot: float = 0.0
		for k in 4:
			js2.append(int(orden[k]) if k < orden.size() else 0)
			ws.append(float(w[orden[k]]) if k < orden.size() else 0.0)
			tot += float(ws[k])
		for k in 4:
			ws[k] = float(ws[k]) / maxf(tot, 1e-9)
		jn[i] = js2
		pe[i] = ws
	# a partir de aquí jn lleva índices de enlace directamente
	al_enlace.clear()
	for b in skin.get_bind_count():
		al_enlace.append(b)
	print("MUELLES %d huesos de capa, %d vértices con peso en las cadenas (borde %.3f), peso de brazo pasado a Spine2: %.0f" % [globales.size(), hechos, borde, quitado_brazo])


func _textura(ruta: String) -> Texture2D:
	var img := Image.load_from_file(ruta)
	if img == null:
		return null
	if img.get_width() > LADO_TEXTURAS:
		img.resize(LADO_TEXTURAS, LADO_TEXTURAS, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	return ImageTexture.create_from_image(img)
