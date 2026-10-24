extends SceneTree
## REPESA LA CAPA SIN CABEZA (25/10, ver CapaMuelles3D «SIN CABEZA»): lee arte/modelos/ropa_capa.glb tal cual está montado (geometría, Skin, huesos de las cadenas
## y texturas), pasa a Spine2 todo el peso de Head/Neck que le copió Blender (`CapaMuelles3D.pesos_sin_cabeza`: solo el anillo del cierre conserva algo de Neck),
## deja como estaban los pesos de las cadenas `capa_*` y del resto, y lo vuelve a escribir. No necesita Blender ni el .json de encajar_ropa.py (que vive en un
## scratchpad); si la capa se vuelve a montar desde Blender, `montar_ropa_glb.gd … muelles` ya aplica la misma regla. Además arregla la FORMA de la parte alta:
## HORNEA la cabeza encogida de `Pj3D.PROPORCIONES` (`CapaMuelles3D.encoger_con_cabeza`, con el peso de Head que traía cada vértice), PEGA la nuca a la espalda
## (`CapaMuelles3D.ajustar_nuca`) y recoloca sobre la capa nueva los huesos de las cadenas de los muelles (reposo y pose de enlace, con `CapaMuelles3D.cadenas`).
## La entrada tiene que ser la capa CON los pesos de Blender: sobre una capa ya repesada (sin peso de Head) no escribe nada, porque pegar la nuca otra vez la
## encogería más. Para rehacerla (otra proporción de cabeza, otra regla) se parte de la del commit 35fdf7b3, la última con los pesos de Blender:
##   git show 35fdf7b3:arte/modelos/ropa_capa.glb > <tmp>/ropa_capa_blender.glb
##   godot --headless --path . --script res://herramientas/repesar_capa.gd -- <tmp>/ropa_capa_blender.glb res://arte/modelos/ropa_capa.glb
## (sin argumentos, entrada = salida = arte/modelos/ropa_capa.glb). Después hay que reimportar (`godot --headless --import --path .`).
## Medir antes y después: herramientas/pesos_capa.gd.

const GLB: String = "res://arte/modelos/ropa_capa.glb"
const ID: String = "jugadora_base"
const CALIDAD_JPEG: float = 0.9


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var entrada: String = ProjectSettings.globalize_path(a[0] if a.size() > 0 else GLB)
	var salida: String = ProjectSettings.globalize_path(a[1] if a.size() > 1 else (a[0] if a.size() > 0 else GLB))
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: int = doc.append_from_file(entrada, estado)
	if err != OK:
		push_error("no se pudo leer %s (%d)" % [entrada, err])
		quit(1)
		return
	var escena: Node = doc.generate_scene(estado)
	var sk: Skeleton3D = escena.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var escala: float = (sk.get_parent() as Node3D).scale.y
	var skin: Skin = mi.skin
	var nombre_de: Array = []
	var bind_de: Dictionary = {}
	var xf: Array = []
	for b in skin.get_bind_count():
		var n: String = skin.get_bind_name(b)
		if n == "" and skin.get_bind_bone(b) >= 0:
			n = sk.get_bone_name(skin.get_bind_bone(b))
		nombre_de.append(n)
		bind_de[n] = b
		var i: int = sk.find_bone(n)
		xf.append(sk.get_bone_global_rest(i) * skin.get_bind_pose(b) if i >= 0 else Transform3D.IDENTITY)
	if not bind_de.has(CapaMuelles3D.HUESO_CUELLO) or not bind_de.has(CapaMuelles3D.HUESO_CUERPO_CAPA):
		push_error("el Skin de la capa no tiene %s o %s" % [CapaMuelles3D.HUESO_CUELLO, CapaMuelles3D.HUESO_CUERPO_CAPA])
		quit(1)
		return
	var cuello: Vector3 = sk.get_bone_global_rest(sk.find_bone(CapaMuelles3D.HUESO_CUELLO)).origin * escala
	var cabeza: Vector3 = sk.get_bone_global_rest(sk.find_bone("mixamorig_Head")).origin * escala
	var escala_cabeza: float = float((Pj3D.PROPORCIONES.get(ID, [1.0]) as Array)[0])
	var a_malla: Transform3D = (xf[int(bind_de[CapaMuelles3D.HUESO_CUERPO_CAPA])] as Transform3D).affine_inverse()
	var movido: float = 0.0
	var peso_head: float = 0.0
	var malla: ArrayMesh = mi.mesh as ArrayMesh
	var nueva := ArrayMesh.new()
	var quitado_cabeza: float = 0.0
	var al_cuello: float = 0.0
	var recortado: float = 0.0
	var vertices: int = 0
	for s in malla.get_surface_count():
		var arr: Array = malla.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var por: int = bones.size() / verts.size()
		# 1. posición en reposo (u del modelo) y pesos por nombre de cada vértice; la forma: hornear la cabeza encogida (ver CapaMuelles3D «SIN CABEZA»)
		var pts := PackedVector3Array()
		var ws: Array = []
		for v in verts.size():
			var w: Dictionary = {}
			var p := Vector3.ZERO
			var h: float = 0.0
			for k in por:
				var x: float = pesos[v * por + k]
				if x <= 0.0:
					continue
				var b: int = bones[v * por + k]
				p += ((xf[b] as Transform3D) * verts[v]) * x
				w[nombre_de[b]] = float(w.get(nombre_de[b], 0.0)) + x
				if CapaMuelles3D.es_hueso_cabeza(String(nombre_de[b])):
					quitado_cabeza += x
					if String(nombre_de[b]) != CapaMuelles3D.HUESO_CUELLO:
						h += x
						peso_head += x
			p *= escala
			if h > 0.0 and not is_equal_approx(escala_cabeza, 1.0):
				p = CapaMuelles3D.encoger_con_cabeza(p, h, cabeza, escala_cabeza)
			pts.append(p)
			ws.append(w)
		# 2. pegar la nuca (ver CapaMuelles3D «NUCA»)
		var pegados: PackedVector3Array = CapaMuelles3D.ajustar_nuca(pts, Vector2(cuello.x, cuello.z))
		for v in verts.size():
			var p: Vector3 = pegados[v]
			var p_viejo: Vector3 = (xf[int(bind_de[CapaMuelles3D.HUESO_CUERPO_CAPA])] as Transform3D) * verts[v] * escala
			if not p.is_equal_approx(p_viejo):
				movido = maxf(movido, (p - p_viejo).length())
				verts[v] = a_malla * (p / escala)
			var w: Dictionary = ws[v]
			var w2: Dictionary = CapaMuelles3D.pesos_sin_cabeza(w, p, cuello)
			al_cuello += float(w2.get(CapaMuelles3D.HUESO_CUELLO, 0.0))
			var orden: Array = w2.keys()
			orden.sort_custom(func(x, y): return float(w2[x]) > float(w2[y]))
			var tot: float = 0.0
			for k in mini(por, orden.size()):
				tot += float(w2[orden[k]])
			for k in range(por, orden.size()):
				recortado += float(w2[orden[k]])
			for k in por:
				if k < orden.size():
					bones[v * por + k] = int(bind_de[orden[k]])
					pesos[v * por + k] = float(w2[orden[k]]) / maxf(tot, 1e-9)
				else:
					bones[v * por + k] = 0
					pesos[v * por + k] = 0.0
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = pesos
		vertices += verts.size()
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nueva.surface_set_material(s, malla.surface_get_material(s))
		nueva.surface_set_name(s, malla.surface_get_name(s))
	if peso_head <= 0.0:
		# ya repesada (sin peso de Head): la forma no se vuelve a tocar, que pegar la nuca otra vez la encogería más
		print("REPESADA: %s no lleva peso de Head (ya está repesada); no se escribe nada" % entrada)
		escena.free()
		quit(0)
		return
	mi.mesh = nueva
	# 3. las cadenas de los muelles, recolocadas sobre la capa nueva (la nuca pegada mueve la raíz `_1`, a ALTO_RAIZ): reposo del hueso y pose de enlace, como
	# las pone montar_ropa_glb.gd, así cada vértice con peso de cadena sigue en su sitio en reposo
	var todos := PackedVector3Array()
	for s in nueva.get_surface_count():
		todos.append_array(nueva.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	var malla_a_esqueleto: Transform3D = xf[int(bind_de[CapaMuelles3D.HUESO_PADRE])]
	var globales: Dictionary = {}
	var raiz_movida: float = 0.0
	var antes: Dictionary = {}
	for j in sk.get_bone_count():
		antes[sk.get_bone_name(j)] = sk.get_bone_global_rest(j).origin
	for c in CapaMuelles3D.cadenas(sk, todos, malla_a_esqueleto, escala):
		var nombre: String = String(c["nombre"])
		var j: int = sk.find_bone(nombre)
		if j < 0 or not bind_de.has(nombre):
			continue
		var padre: int = sk.get_bone_parent(j)
		var g_padre: Transform3D = globales.get(sk.get_bone_name(padre), sk.get_bone_global_rest(padre))
		raiz_movida = maxf(raiz_movida, ((c["global"] as Transform3D).origin - (antes[nombre] as Vector3)).length() * escala)
		sk.set_bone_rest(j, g_padre.affine_inverse() * (c["global"] as Transform3D))
		globales[nombre] = c["global"]
		skin.set_bind_pose(int(bind_de[nombre]), (c["global"] as Transform3D).affine_inverse() * malla_a_esqueleto)
	sk.reset_bone_poses()
	print("CADENAS recolocadas: %d huesos, el que más se mueve %.3f u" % [globales.size(), raiz_movida])
	var doc2 := GLTFDocument.new()
	doc2.image_format = "JPEG"
	doc2.lossy_quality = CALIDAD_JPEG
	var estado2 := GLTFState.new()
	err = doc2.append_from_scene(escena, estado2)
	if err == OK:
		err = doc2.write_to_filesystem(estado2, salida)
	print("REPESADA %s -> %s (err %d): %d vértices; peso de cabeza/cuello pasado a Spine2: %.1f; a Neck (cierre): %.1f; recortado a 4 influencias: %.3f; Neck en y %.3f; cabeza a %.2f horneada y nuca pegada (vértice más movido %.3f u)" % [
		entrada, salida, err, vertices, quitado_cabeza, al_cuello, recortado, cuello.y, escala_cabeza, movido])
	escena.free()
	quit(0 if err == OK else 1)
