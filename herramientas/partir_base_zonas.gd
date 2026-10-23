extends SceneTree
## PARTE el cuerpo de `jugadora_base.glb` (UNA malla de 43 000 vértices: piel, pelo, chaleco, cinturón, pantalón y botas fundidos) en SUPERFICIES POR ZONAS, con los
## mismos vértices, pesos y huesos (nada se reasigna: solo se reparten los triángulos y cada superficie lleva los vértices que usa). Se guarda como
## `arte/modelos/jugadora_base_zonas.res`, una malla sin material que Ropa3D pone en lugar de la original al vestir al personaje (y ahí apaga las zonas que tapa cada
## prenda, `oculta` en arte/modelos/ropa.json). Sin ventana:
##   godot --headless --path . --script res://herramientas/partir_base_zonas.gd
## Zonas (ZONAS, en este orden): cabeza (cara, orejas y el pelo de delante), pelo (el de atrás: lo que tapa una capucha), torso (piel y lo que no es ropa),
## chaleco y cinturon (la ropa pintada en el torso, que tapa una túnica), brazos, piernas y botas. Se decide por el hueso de mayor peso de cada vértice, la altura
## y, en el torso y en lo alto de los brazos, el color de la textura (piel y mangas claras / cuero marrón del chaleco y del cinturón). El pelo es lo de la cabeza
## detrás de las orejas. La malla trae sus coordenadas en 1/100 de unidad del modelo.

const GLB_BASE: String = "res://arte/modelos/jugadora_base.glb"
const SALIDA: String = "res://arte/modelos/jugadora_base_zonas.res"
const ZONAS: Array = ["cabeza", "pelo", "torso", "chaleco", "cinturon", "brazos", "piernas", "botas"]
## Unidades de la malla -> unidades del modelo (1,7 de alto).
const ESCALA_MALLA: float = 100.0
## Pelo = lo de la cabeza que queda DETRÁS de este plano (u del modelo, +atrás desde el eje de la cabeza), salvo las orejas: la capucha lo tapa y por la
## unión con la capa asomaba. Las orejas están a y = +0,05, x = ±0,34, z = 1,33.
const PELO_Y_MIN: float = 0.02
const OREJA_X_MIN: float = 0.29
const OREJA_Z_MIN: float = 1.27
const OREJA_Z_MAX: float = 1.40
const OREJA_ATRAS_MAX: float = 0.12
## Dentro de la caja de la oreja, el pelo (lo que no es piel) pasa a la zona `pelo` si está por detrás de esta distancia al plano de la cara (u del modelo, +atrás).
const PELO_HEBRA_ATRAS_MIN: float = -0.06
## ...y por debajo de esta altura (la caja de la oreja llega a OREJA_Z_MAX; las hebras que asomaban junto a ella subían algo más).
const PELO_HEBRA_Z_MAX: float = 1.55
## Por debajo de esta altura el hueso «Leg» es bota (las botas llegan bajo la rodilla).
const BOTA_Z_MAX: float = 0.43
## Color de la textura: piel y mangas = claras y poco saturadas; el resto del torso es la ropa pintada (cinturón si pesa en la cadera, chaleco si no).
const PIEL_MIN: float = 0.62
const PIEL_SATURACION_MAX: float = 0.33
## Los brazos solo pueden ser chaleco (sisa, tirantes) por encima de esta altura.
const BRAZO_PECHO_Z_MIN: float = 0.90


func _initialize() -> void:
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
	# Zona de cada triángulo.
	var zona_tri: PackedInt32Array = PackedInt32Array()
	var cuenta: Array = []
	cuenta.resize(ZONAS.size())
	cuenta.fill(0)
	for t in range(0, idx.size(), 3):
		var z: int = _zona_triangulo(pos, uv, dominante, img, idx[t], idx[t + 1], idx[t + 2])
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


## Copia de `a` con solo los vértices `viejos` (cada canal tiene `a.size() / n` valores por vértice).
func _tomar(a: Variant, viejos: PackedInt32Array, n: int) -> Variant:
	var paso: int = (a as Variant).size() / n
	var res: Variant = a.duplicate()
	res.resize(viejos.size() * paso)
	for i in viejos.size():
		for k in paso:
			res[i * paso + k] = a[viejos[i] * paso + k]
	return res


func _zona_triangulo(pos: PackedVector3Array, uv: PackedVector2Array, dominante: PackedStringArray, img: Image, a: int, b: int, c: int) -> int:
	# Hueso dominante de la mayoría de los vértices (el primero si los tres difieren).
	var h: String = dominante[a]
	if dominante[b] == dominante[c]:
		h = dominante[b]
	var centro: Vector3 = (pos[a] + pos[b] + pos[c]) / 3.0
	var x: float = centro.x * ESCALA_MALLA
	var altura: float = centro.y * ESCALA_MALLA
	var atras: float = -centro.z * ESCALA_MALLA
	if h == "Head" or h == "Neck" or h == "headfront" or h.begins_with("HeadTop"):
		var oreja: bool = absf(x) > OREJA_X_MIN and altura > OREJA_Z_MIN and altura < OREJA_Z_MAX and atras < OREJA_ATRAS_MAX
		var junto_oreja: bool = absf(x) > OREJA_X_MIN and altura > OREJA_Z_MIN and altura < PELO_HEBRA_Z_MAX and atras < OREJA_ATRAS_MAX
		if junto_oreja and not _es_piel(_color(img, uv[a], uv[b], uv[c])) and atras > PELO_HEBRA_ATRAS_MIN:
			# En la caja de la oreja solo la oreja es piel: las hebras de pelo (color de pelo) que hay ahí son del pelo de atrás, y con la capucha asomaban sueltas junto a ella.
			return ZONAS.find("pelo")
		if atras > PELO_Y_MIN and not oreja and altura > 1.05:
			return ZONAS.find("pelo")
		return ZONAS.find("cabeza")
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
