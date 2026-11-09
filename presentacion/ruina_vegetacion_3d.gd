extends RefCounted
## Enredaderas pequeñas proyectadas sobre la malla del arco. La piedra decide la profundidad de cada hoja.

static func enredaderas(partes: Array) -> ArrayMesh:
	var caras := PackedVector3Array()
	var caja := AABB()
	for parte in partes:
		var malla: Mesh = parte[0]
		var local: Transform3D = parte[1]
		for vertice in malla.get_faces():
			var punto: Vector3 = local * vertice
			caja = AABB(punto, Vector3.ZERO) if caras.is_empty() else caja.expand(punto)
			caras.append(punto)
	if caras.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	st.set_material(Ocluso3D.convertir(material))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4183
	for lado in [-1.0, 1.0]:
		_trepadora(st, caras, caja, lado, 0.90 if lado < 0.0 else 0.58, rng)
	st.generate_normals()
	return st.commit()

static func _trepadora(st: SurfaceTool, caras: PackedVector3Array, caja: AABB, cara: float, altura: float, rng: RandomNumberGenerator) -> void:
	var lleva_racimo: bool = false
	var previo: Variant = null
	const PASOS: int = 22
	for i in range(PASOS + 1):
		var t: float = float(i) / PASOS
		var x: float = caja.get_center().x + cara * caja.size.x * (0.29 - 0.12 * smoothstep(0.65, 1.0, t))
		x += sin(t * 12.0) * caja.size.x * 0.038
		var y: float = caja.position.y + caja.size.y * lerpf(0.045, altura, t)
		var hit: Variant = _cara_piedra(caras, caja, Vector2(x, y), cara)
		if hit == null:
			previo = null
			continue
		var raiz: Vector3 = (hit as Vector3) + Vector3(0.0, 0.0, cara * 0.024)
		if previo != null:
			var a: Vector3 = previo
			var ala: Vector3 = Vector3(-1.0, 0.0, 0.0) * lerpf(0.026, 0.009, t)
			_triangulo(st, a - ala, a + ala, raiz + ala, Color("58643D"))
			_triangulo(st, a - ala, raiz + ala, raiz - ala, Color("58643D"))
		previo = raiz
		var ancho: float = rng.randf_range(0.095, 0.155) * lerpf(1.15, 0.73, t)
		var sentido: float = 1.0 if i % 2 == 0 else -1.0
		var punta := Vector2(x + sentido * ancho * 1.8, y - ancho * rng.randf_range(0.45, 1.1))
		var apoyo: Variant = _cara_piedra(caras, caja, punta, cara)
		if apoyo == null or absf((apoyo as Vector3).z - raiz.z) > 0.23:
			continue
		var fin: Vector3 = (apoyo as Vector3) + Vector3(0.0, 0.0, cara * 0.035)
		var verde: Color = Color("83984E").lerp(Color("4C6940"), rng.randf())
		# Solo cambia este racimo del pilar visto desde el santuario. El tallo y el resto de hojas se dibujan igual.
		if cara < 0.0 and i >= 8 and i <= 10:
			if not lleva_racimo:
				_racimo_con_relieve(st, caras, caja, raiz, cara)
				lleva_racimo = true
			continue
		_hoja(st, raiz, fin, cara, ancho, verde)


static func _racimo_con_relieve(st: SurfaceTool, caras: PackedVector3Array, caja: AABB, raiz: Vector3, cara: float) -> void:
	var frente := Vector3(0.0, 0.0, cara)
	var ejes: Array[Vector2] = [Vector2(-0.94, 0.35), Vector2(0.66, 0.72), Vector2(0.61, -0.79)]
	var largos: Array[float] = [0.32, 0.39, 0.30]
	var tonos: Array[Color] = [Color("7F9B51"), Color("9AB05C"), Color("68864A")]
	for i in ejes.size():
		var xy := Vector2(raiz.x, raiz.y) + ejes[i].normalized() * largos[i]
		var apoyo: Variant = _cara_piedra(caras, caja, xy, cara)
		var profundidad: float = raiz.z
		if apoyo != null and absf((apoyo as Vector3).z - raiz.z) < 0.19:
			profundidad = (apoyo as Vector3).z
		var punta := Vector3(xy.x, xy.y, profundidad) + frente * (0.065 + 0.028 * float(i))
		_hoja(st, raiz, punta, cara, largos[i] * 0.42, tonos[i], 0.63)


## Perfil lobulado de hiedra. El nervio central eleva el limbo y separa sus dos caras.
static func _hoja(st: SurfaceTool, raiz: Vector3, punta: Vector3, cara: float, ancho: float, verde: Color, relieve: float = 0.33) -> void:
	var eje: Vector3 = punta - raiz
	var lateral := Vector3(-eje.y, eje.x, 0.0).normalized() * ancho
	var frente := Vector3(0.0, 0.0, cara)
	var centro: Vector3 = raiz.lerp(punta, 0.49) + frente * ancho * relieve
	var nervio: Color = verde.lerp(Color("BCC585"), 0.48)
	var lobulos: Array[Vector2] = [
		Vector2(0.09, 0.64), Vector2(0.21, 0.92), Vector2(0.38, 0.59),
		Vector2(0.55, 0.88), Vector2(0.66, 0.40), Vector2(0.85, 0.23),
	]
	for lado in [-1.0, 1.0]:
		var contorno: Array[Vector3] = [raiz]
		for forma in lobulos:
			contorno.append(raiz + eje * forma.x + lateral * forma.y * lado)
		contorno.append(punta)
		var tono: Color = verde.darkened(0.15) if lado < 0.0 else verde
		for i in range(contorno.size() - 1):
			var a: Vector3 = contorno[i]
			var b: Vector3 = contorno[i + 1]
			if (a - centro).cross(b - centro).dot(frente) > 0.0:
				_triangulo(st, centro, b, a, tono)
			else:
				_triangulo(st, centro, a, b, tono)
		for lobulo in [2, 4]:
			var fin: Vector3 = centro.lerp(contorno[lobulo], 0.76)
			_nervadura(st, centro, fin, frente, ancho * 0.023, tono.lerp(nervio, 0.50))
	_nervadura(st, raiz, centro, frente, ancho * 0.052, nervio)
	_nervadura(st, centro, centro.lerp(punta, 0.91), frente, ancho * 0.031, nervio)


static func _nervadura(st: SurfaceTool, desde: Vector3, hasta: Vector3, frente: Vector3, grosor: float, color: Color) -> void:
	var lado: Vector3 = frente.cross(hasta - desde).normalized() * grosor
	var a: Vector3 = desde + frente * 0.004
	var b: Vector3 = hasta + frente * 0.004
	_triangulo(st, a + lado, a - lado, b, color)


static func _cara_piedra(caras: PackedVector3Array, caja: AABB, punto: Vector2, cara: float) -> Variant:
	var centro: float = caja.get_center().z
	var margen: float = caja.size.z * 0.5 + 0.1
	var origen := Vector3(punto.x, punto.y, centro + margen * cara)
	var fin := Vector3(punto.x, punto.y, centro - margen * cara)
	var mejor: Variant = null
	for i in range(0, caras.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(origen, fin, caras[i], caras[i + 1], caras[i + 2])
		if hit != null and (mejor == null or ((hit as Vector3).z - (mejor as Vector3).z) * cara > 0.0):
			mejor = hit
	return mejor


static func _triangulo(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	for punto in [a, b, c]:
		st.add_vertex(punto)