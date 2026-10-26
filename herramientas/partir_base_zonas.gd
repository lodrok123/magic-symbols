extends SceneTree
## PARTE el cuerpo de `jugadora_base.glb` (UNA malla de 43 000 vértices: piel, pelo, chaleco, cinturón, pantalón y botas fundidos) en SUPERFICIES POR ZONAS, con los
## mismos vértices, pesos y huesos (nada se reasigna: solo se reparten los triángulos y cada superficie lleva los vértices que usa). Se guarda como
## `arte/modelos/jugadora_base_zonas.res`, una malla sin material que Ropa3D pone en lugar de la original al vestir al personaje (y ahí apaga las zonas que tapa cada
## prenda, `oculta` en arte/modelos/ropa.json). Sin ventana:
##   godot --headless --path . --script res://herramientas/partir_base_zonas.gd
## Zonas (ZONAS, en este orden): cabeza (cara, orejas y el pelo de delante), pelo (el de atrás: lo que tapa una capucha), torso (piel y lo que no es ropa),
## chaleco y cinturon (la ropa pintada en el torso, que tapa una túnica), brazos, piernas y botas. Se decide por el hueso de mayor peso de cada vértice, la altura
## y, en el torso y en lo alto de los brazos, el color de la textura (piel y mangas claras / cuero marrón del chaleco y del cinturón). El pelo es lo de la cabeza
## que NO SE VE con la capucha y la capa puestas (VISIBILIDAD; por eso lee también ropa_capucha.glb y ropa_capa.glb: hay que volver a pasarlo cuando cambian), más
## las orejas. La malla trae sus coordenadas en 1/100 de unidad del modelo.

const GLB_BASE: String = "res://arte/modelos/jugadora_base.glb"
const SALIDA: String = "res://arte/modelos/jugadora_base_zonas.res"
const ZONAS: Array = ["cabeza", "pelo", "torso", "chaleco", "cinturon", "brazos", "piernas", "botas"]
## Unidades de la malla -> unidades del modelo (1,7 de alto).
const ESCALA_MALLA: float = 100.0
## Orejas (a `pelo` siempre: con la capucha asomaban por la pared lateral). Están a y = +0,05, x = ±0,34, z = 1,33 (la piel llega a |x| 0,343, z 1,30–1,34).
const OREJA_X_MIN: float = 0.29
const OREJA_Z_MIN: float = 1.27
const OREJA_Z_MAX: float = 1.40
const OREJA_ATRAS_MAX: float = 0.12
## VISIBILIDAD (26/10, Pablo: «también una textura rota en la cara»). Hasta hoy el pelo era lo de detrás de un plano más unas cajas junto a las orejas y el
## cuello; la última caja (|x| > 0,18, de z 1,10 a 1,55 y hasta 20 cm por delante de la cara) partía por la mitad los mechones que enmarcan la cara y con la
## capucha quedaban trozos de pelo sueltos y parches de la piel de debajo. Ahora un triángulo de la cabeza es `pelo` si NO SE VE desde fuera con la capucha y la
## capa puestas: desde su centro se lanzan VIS_DIRECCIONES rayos (esfera de Fibonacci, sin los que bajan más de VIS_Y_MIN: la cámara nunca mira desde abajo y
## por dentro de la capa se saldría por el bajo) contra el cuerpo, la capucha y la capa en la pose de reposo del juego (la cabeza, el pelo y la capucha
## encogidos a Pj3D.PROPORCIONES como lo hace ProporcionChibi); si alguno sale a más de VIS_LARGO sin tocar nada, se ve. Quitar lo que no se ve no destapa
## nada (para ver a través de un triángulo hay que verlo). Un mechón se corta, si acaso, por detrás del borde de la capucha. Y es `pelo` también lo que queda
## POR FUERA de la tela (FUERA: hay capucha o capa entre el triángulo y el eje vertical de la cabeza: mechones que la atraviesan junto al cuello, la base de la
## oreja contra la pared lateral), y las MIGAS sueltas que deja todo esto.
const GLB_CAPUCHA: String = "res://arte/modelos/ropa_capucha.glb"
const GLB_CAPA: String = "res://arte/modelos/ropa_capa.glb"
const VIS_DIRECCIONES: int = 96
const VIS_Y_MIN: float = -0.45
## Los rayos salen VIS_SEPARA (u del modelo) por delante del centro (no chocan con el propio triángulo ni con su gemelo de la otra cara de la tira de pelo).
const VIS_SEPARA: float = 0.004
const VIS_LARGO: float = 3.0
const HUESOS_ENCOGEN: PackedStringArray = ["Head", "HeadTop_End", "headfront"]
## Pasadas de `_quitar_migas` (ver MIGAS).
const VIS_MIGAS_PASADAS: int = 2
## Por debajo de esta altura el hueso «Leg» es bota (las botas llegan bajo la rodilla).
const BOTA_Z_MAX: float = 0.43
## Color de la textura: piel y mangas = claras y poco saturadas; el resto del torso es la ropa pintada (cinturón si pesa en la cadera, chaleco si no).
const PIEL_MIN: float = 0.62
const PIEL_SATURACION_MAX: float = 0.33
## Los brazos solo pueden ser chaleco (sisa, tirantes) por encima de esta altura.
const BRAZO_PECHO_Z_MIN: float = 0.90


func _initialize() -> void:
	_partir()


func _partir() -> void:
	var escena: Node = (load(GLB_BASE) as PackedScene).instantiate()
	var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skeleton3D = escena.find_children("*", "Skeleton3D", true, false)[0]
	var malla: ArrayMesh = mi.mesh as ArrayMesh
	var arr: Array = malla.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var n: int = pos.size()
	var por_vert: int = bones.size() / n
	var img := Image.load_from_file(ProjectSettings.globalize_path((mi.get_active_material(0) as BaseMaterial3D).albedo_texture.resource_path))
	# Hueso dominante de cada vértice (por nombre).
	var hueso_de_enlace: Array = []
	for b in mi.skin.get_bind_count():
		var nombre: String = mi.skin.get_bind_name(b)
		if nombre == "" and mi.skin.get_bind_bone(b) >= 0:
			nombre = sk.get_bone_name(mi.skin.get_bind_bone(b))
		hueso_de_enlace.append(nombre.replace("mixamorig_", ""))
	var dominante: PackedStringArray = PackedStringArray()
	dominante.resize(n)
	for v in n:
		var mejor: float = -1.0
		for k in por_vert:
			if pesos[v * por_vert + k] > mejor:
				mejor = pesos[v * por_vert + k]
				dominante[v] = hueso_de_enlace[bones[v * por_vert + k]]
	# 26/10: qué triángulos de la cabeza se ven con la capucha y la capa puestas (ver VISIBILIDAD).
	var visto: PackedByteArray = await _visibles(mi, sk, pos, bones, pesos, por_vert, idx, dominante, hueso_de_enlace)
	# Zona de cada triángulo.
	var zona_tri: PackedInt32Array = PackedInt32Array()
	var cuenta: Array = []
	cuenta.resize(ZONAS.size())
	cuenta.fill(0)
	for t in range(0, idx.size(), 3):
		var z: int = _zona_triangulo(pos, uv, dominante, img, idx[t], idx[t + 1], idx[t + 2], visto[t / 3] == 1)
		zona_tri.append(z)
		cuenta[z] += 1
	for i in ZONAS.size():
		print("ZONA %-9s %6d triángulos" % [ZONAS[i], cuenta[i]])
	# Una superficie por zona con los vértices que usa.
	var salida := ArrayMesh.new()
	for z in ZONAS.size():
		if cuenta[z] == 0:
			continue
		var nuevo_de: Dictionary = {}
		var viejos: PackedInt32Array = PackedInt32Array()
		var indices: PackedInt32Array = PackedInt32Array()
		for t in zona_tri.size():
			if zona_tri[t] != z:
				continue
			for k in 3:
				var vv: int = idx[t * 3 + k]
				if not nuevo_de.has(vv):
					nuevo_de[vv] = viejos.size()
					viejos.append(vv)
				indices.append(nuevo_de[vv])
		var a2: Array = []
		a2.resize(Mesh.ARRAY_MAX)
		for canal in Mesh.ARRAY_MAX:
			if canal == Mesh.ARRAY_INDEX or arr[canal] == null:
				continue
			a2[canal] = _tomar(arr[canal], viejos, n)
		a2[Mesh.ARRAY_INDEX] = indices
		var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if por_vert == 8 else 0
		salida.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, flags)
		salida.surface_set_name(salida.get_surface_count() - 1, ZONAS[z])
	salida.set_meta("vertices_origen", n)
	salida.set_meta("triangulos_origen", idx.size() / 3)
	var err: int = ResourceSaver.save(salida, SALIDA)
	print("GUARDADO %s (err %d): %d superficies" % [SALIDA, err, salida.get_surface_count()])
	escena.free()
	quit(0 if err == OK else 1)


func _es_cabeza(h: String) -> bool:
	return h == "Head" or h == "Neck" or h == "headfront" or h.begins_with("HeadTop")


## VISIBILIDAD: 1 por triángulo de la cabeza que se ve desde fuera con la capucha y la capa puestas (0 si no; el resto de triángulos, 1).
func _visibles(mi: MeshInstance3D, sk: Skeleton3D, pos: PackedVector3Array, bones: PackedInt32Array, pesos: PackedFloat32Array, por_vert: int,
		idx: PackedInt32Array, dominante: PackedStringArray, hueso_de_enlace: Array) -> PackedByteArray:
	var escala_cabeza: float = float((Pj3D.PROPORCIONES.get("jugadora_base", [1.0]) as Array)[0])
	var pivote: Vector3 = _pivote_cabeza(mi.skin, sk)
	var cuerpo: PackedVector3Array = _reposo_juego(pos, bones, pesos, por_vert, hueso_de_enlace, pivote, escala_cabeza)
	var caras := PackedVector3Array()
	for i in idx:
		caras.append(cuerpo[i])
	var caras_ropa := PackedVector3Array()
	for ruta in [GLB_CAPUCHA, GLB_CAPA]:
		caras_ropa.append_array(_caras_prenda(String(ruta), pivote, escala_cabeza))
	# El cuerpo en la capa de colisión 1 y la ropa en la 2 (FUERA mira solo la ropa).
	var cuerpo_fisico := Node3D.new()
	for par in [[caras, 1], [caras_ropa, 2]]:
		var forma := ConcavePolygonShape3D.new()
		forma.backface_collision = true
		forma.set_faces(par[0])
		var col := CollisionShape3D.new()
		col.shape = forma
		var sb := StaticBody3D.new()
		sb.collision_layer = int(par[1])
		sb.add_child(col)
		cuerpo_fisico.add_child(sb)
	root.add_child(cuerpo_fisico)
	var eje := Vector2(pivote.x, pivote.z) * ESCALA_MALLA
	await physics_frame
	await physics_frame
	var espacio: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var dirs: Array = []
	var oro: float = PI * (3.0 - sqrt(5.0))
	for k in VIS_DIRECCIONES:
		var y: float = 1.0 - 2.0 * (k + 0.5) / VIS_DIRECCIONES
		if y < VIS_Y_MIN:
			continue
		var r: float = sqrt(1.0 - y * y)
		dirs.append(Vector3(cos(oro * k) * r, y, sin(oro * k) * r))
	var res := PackedByteArray()
	res.resize(idx.size() / 3)
	res.fill(1)
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = true
	var q_fuera := PhysicsRayQueryParameters3D.new()
	q_fuera.hit_back_faces = true
	q_fuera.collision_mask = 2
	var ocultos: int = 0
	var fuera: int = 0
	var de_cabeza: int = 0
	for t in idx.size() / 3:
		var a: int = idx[t * 3]
		var b: int = idx[t * 3 + 1]
		var c: int = idx[t * 3 + 2]
		var h: String = dominante[a]
		if dominante[b] == dominante[c]:
			h = dominante[b]
		if not _es_cabeza(h):
			continue
		de_cabeza += 1
		var centro: Vector3 = (cuerpo[a] + cuerpo[b] + cuerpo[c]) / 3.0
		# FUERA: lo que atraviesa la ropa (mechones que cuelgan por fuera de la capucha o de la capa junto al cuello, la base de la oreja contra la pared de la
		# capucha) se ve pero no debe: entre el triángulo y el eje vertical de la cabeza, a su misma altura, hay tela.
		q_fuera.from = centro
		q_fuera.to = Vector3(eje.x, centro.y, eje.y)
		if not espacio.intersect_ray(q_fuera).is_empty():
			res[t] = 0
			fuera += 1
			continue
		var sale: bool = false
		for d in dirs:
			q.from = centro + (d as Vector3) * VIS_SEPARA
			q.to = centro + (d as Vector3) * VIS_LARGO
			if espacio.intersect_ray(q).is_empty():
				sale = true
				break
		if not sale:
			res[t] = 0
			ocultos += 1
	root.remove_child(cuerpo_fisico)
	cuerpo_fisico.free()
	ocultos += _quitar_migas(res, pos, idx, dominante)
	print("VISIBILIDAD %d triángulos de la cabeza: %d tapados por la capucha y la capa (%d direcciones), %d por fuera de la tela" % [de_cabeza, ocultos,
			dirs.size(), fuera])
	return res


## MIGAS: un triángulo de la cabeza que se ve pero tiene ocultos al menos 2 de sus 3 vecinos (por arista, vértices soldados por posición) se oculta también,
## VIS_MIGAS_PASADAS veces: sin esto quedaban trocitos sueltos de los rizos que cuelgan sobre la solapa de la capa. Devuelve cuántos.
func _quitar_migas(res: PackedByteArray, pos: PackedVector3Array, idx: PackedInt32Array, dominante: PackedStringArray) -> int:
	var id_pos: Dictionary = {}
	var soldado := PackedInt32Array()
	for p in pos:
		var k := Vector3i((p * 1e6).round())
		if not id_pos.has(k):
			id_pos[k] = id_pos.size()
		soldado.append(int(id_pos[k]))
	var por_arista: Dictionary = {}
	var de_cabeza: Array = []
	for t in idx.size() / 3:
		var h: String = dominante[idx[t * 3]]
		if dominante[idx[t * 3 + 1]] == dominante[idx[t * 3 + 2]]:
			h = dominante[idx[t * 3 + 1]]
		if not _es_cabeza(h):
			continue
		de_cabeza.append(t)
		for e in 3:
			var a: int = soldado[idx[t * 3 + e]]
			var b: int = soldado[idx[t * 3 + (e + 1) % 3]]
			var k := Vector2i(mini(a, b), maxi(a, b))
			if not por_arista.has(k):
				por_arista[k] = []
			(por_arista[k] as Array).append(t)
	var vecinos: Dictionary = {}
	for k in por_arista:
		var l: Array = por_arista[k]
		for t in l:
			for u in l:
				if t != u:
					if not vecinos.has(t):
						vecinos[t] = []
					(vecinos[t] as Array).append(u)
	var total: int = 0
	for _p in VIS_MIGAS_PASADAS:
		var quitar: Array = []
		for t in de_cabeza:
			if res[t] == 0 or not vecinos.has(t):
				continue
			var ocultos: int = 0
			for u in vecinos[t]:
				if res[u] == 0:
					ocultos += 1
			if ocultos >= 2:
				quitar.append(t)
		for t in quitar:
			res[t] = 0
		total += quitar.size()
	return total


## Head en reposo en el espacio de la malla (por su pose de enlace).
func _pivote_cabeza(skin: Skin, sk: Skeleton3D) -> Vector3:
	for b in skin.get_bind_count():
		var nombre: String = skin.get_bind_name(b)
		if nombre == "" and skin.get_bind_bone(b) >= 0:
			nombre = sk.get_bone_name(skin.get_bind_bone(b))
		if nombre.replace("mixamorig_", "") == "Head":
			return skin.get_bind_pose(b).affine_inverse().origin
	return Vector3.ZERO


## Posiciones (u del modelo) con la cabeza escalada `escala` alrededor de `pivote` (espacio de la malla) según el peso de los huesos que encogen con ella.
func _reposo_juego(pos: PackedVector3Array, bones: PackedInt32Array, pesos: PackedFloat32Array, por_vert: int, nombres: Array, pivote: Vector3,
		escala: float) -> PackedVector3Array:
	var res := PackedVector3Array()
	res.resize(pos.size())
	for v in pos.size():
		var h: float = 0.0
		for k in por_vert:
			var b: int = bones[v * por_vert + k]
			if b < nombres.size() and HUESOS_ENCOGEN.has(String(nombres[b]).replace("mixamorig_", "")):
				h += pesos[v * por_vert + k]
		res[v] = pos[v].lerp(pivote + (pos[v] - pivote) * escala, clampf(h, 0.0, 1.0)) * ESCALA_MALLA
	return res


## Triángulos de una prenda (mismo espacio de malla que el cuerpo) en la pose de reposo del juego, u del modelo.
func _caras_prenda(ruta: String, pivote: Vector3, escala: float) -> PackedVector3Array:
	var escena: Node = (load(ruta) as PackedScene).instantiate()
	var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skeleton3D = escena.find_children("*", "Skeleton3D", true, false)[0]
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var p: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var nombres: Array = []
	for b in mi.skin.get_bind_count():
		var nombre: String = mi.skin.get_bind_name(b)
		if nombre == "" and mi.skin.get_bind_bone(b) >= 0:
			nombre = sk.get_bone_name(mi.skin.get_bind_bone(b))
		nombres.append(nombre)
	var reposo: PackedVector3Array = _reposo_juego(p, bn, arr[Mesh.ARRAY_WEIGHTS], bn.size() / p.size(), nombres, pivote, escala)
	var caras := PackedVector3Array()
	for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
		caras.append(reposo[i])
	escena.free()
	return caras


## Copia de `a` con solo los vértices `viejos` (cada canal tiene `a.size() / n` valores por vértice).
func _tomar(a: Variant, viejos: PackedInt32Array, n: int) -> Variant:
	var paso: int = (a as Variant).size() / n
	var res: Variant = a.duplicate()
	res.resize(viejos.size() * paso)
	for i in viejos.size():
		for k in paso:
			res[i * paso + k] = a[viejos[i] * paso + k]
	return res


func _zona_triangulo(pos: PackedVector3Array, uv: PackedVector2Array, dominante: PackedStringArray, img: Image, a: int, b: int, c: int, visible: bool) -> int:
	# Hueso dominante de la mayoría de los vértices (el primero si los tres difieren).
	var h: String = dominante[a]
	if dominante[b] == dominante[c]:
		h = dominante[b]
	var centro: Vector3 = (pos[a] + pos[b] + pos[c]) / 3.0
	var x: float = centro.x * ESCALA_MALLA
	var altura: float = centro.y * ESCALA_MALLA
	var atras: float = -centro.z * ESCALA_MALLA
	if _es_cabeza(h):
		var oreja: bool = absf(x) > OREJA_X_MIN and altura > OREJA_Z_MIN and altura < OREJA_Z_MAX and atras < OREJA_ATRAS_MAX
		if oreja:
			# La capucha también tapa las orejas (se asomaban por la pared lateral): van a `pelo`, que solo se apaga con la capucha puesta.
			return ZONAS.find("pelo")
		# 26/10 (Pablo: «también una textura rota en la cara»): lo demás, por VISIBILIDAD y no por cajas. Las cajas de las hebras (|x| > 0,18 hasta 20 cm por
		# delante del plano de la cara) cortaban por la mitad los mechones que enmarcan la cara: con la capucha se veían trozos de pelo sueltos y la piel de debajo.
		return ZONAS.find("cabeza" if visible else "pelo")
	if h == "Foot" or h.ends_with("Foot") or h.contains("Toe"):
		return ZONAS.find("botas")
	if h.ends_with("Leg") and not h.ends_with("UpLeg"):
		return ZONAS.find("botas" if altura < BOTA_Z_MAX else "piernas")
	if h.ends_with("UpLeg"):
		return ZONAS.find("piernas")
	var brazo: bool = h.contains("Shoulder") or h.contains("Arm") or h.contains("Hand")
	if brazo and altura < BRAZO_PECHO_Z_MIN:
		return ZONAS.find("brazos")
	# Torso (Hips, Spine*) y la parte alta de los brazos, donde el chaleco llega a los hombros y a la sisa: por el color de la textura (la piel y las mangas
	# son claras; el chaleco y el cinturón, de cuero marrón).
	if _es_piel(_color(img, uv[a], uv[b], uv[c])):
		return ZONAS.find("brazos" if brazo else "torso")
	return ZONAS.find("cinturon" if h == "Hips" else "chaleco")


## Color claro y poco saturado: piel (o manga clara).
func _es_piel(col: Color) -> bool:
	var mx: float = maxf(col.r, maxf(col.g, col.b))
	var mn: float = minf(col.r, minf(col.g, col.b))
	var sat: float = (mx - mn) / maxf(mx, 0.001)
	return mn > PIEL_MIN and sat < PIEL_SATURACION_MAX


func _color(img: Image, a: Vector2, b: Vector2, c: Vector2) -> Color:
	var res := Color(0, 0, 0)
	for p in [a, b, c, (a + b + c) / 3.0]:
		var px: int = clampi(int(fposmod(p.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
		var py: int = clampi(int(fposmod(p.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
		res += img.get_pixel(px, py)
	return res / 4.0
