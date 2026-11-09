extends MeshInstance3D

const Cintas = preload("res://presentacion/vfx/toy/rayo_trazos.gd")

var _trazos: Array = []
var _contorno_escudo: MeshInstance3D
var _contorno_tornado: MeshInstance3D
var _cortina: MeshInstance3D
var _ejes_cortina := Vector3.ZERO


func _ready() -> void:
	mesh = ArrayMesh.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentacion/vfx/toy/viento_corriente.gdshader")
	material.set_shader_parameter("claro", Color("#dcffb0"))
	material.set_shader_parameter("sombra", Color("#83be70"))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func dibujar(figura: StringName, ejes: Vector3, tiempo: float, opacidad: float, ancho: float, avance: float = 1.0) -> void:
	_trazos.clear()
	if opacidad > 0.01:
		match figura:
			&"BOLA":
				_rafaga(ejes, tiempo, opacidad, avance)
			&"CARGA":
				_carga(ejes.x, tiempo, opacidad, avance)
			&"SALIDA":
				_salida(ejes.x, opacidad, avance)
			&"HAZ":
				_haz(ejes, tiempo, opacidad)
			&"PILAR":
				_tornado(ejes, tiempo, opacidad)
			&"MURO":
				_muro(ejes, tiempo, opacidad)
			&"BARRERA":
				_escudo(ejes, tiempo, opacidad)
			&"AURA":
				_aura(ejes, tiempo, opacidad, avance)
	if figura == &"BARRERA":
		_borde_escudo(ejes, opacidad)
	elif figura == &"PILAR":
		_borde_tornado(ejes, tiempo, opacidad)
	elif figura == &"MURO":
		_cortina_muro(ejes, tiempo, opacidad)
	Cintas.volcar_cintas(self, _trazos, ancho, false)


func _guardar(puntos: PackedVector3Array, grosor: float, alfa: float, tinte: float = 1.0) -> void:
	_trazos.append({"puntos": puntos, "ancho": grosor, "punta": grosor * 0.35,
		"alfa": alfa, "alfa_punta": alfa * 0.73, "tinte": tinte})


func _rafaga(ejes: Vector3, tiempo: float, alfa: float, estela: float) -> void:
	var radio: float = maxf(0.17, maxf(ejes.x, ejes.z))
	var grosor: float = clampf(radio * 0.20, 0.035, 0.10)
	for i in 5:
		var z: float = (float(i) - 2.0) * radio * 0.26
		var r: float = radio * (0.69 + 0.26 * sin(float(i) / 4.0 * PI))
		var arco: PackedVector3Array = _anillo_rafaga(z, r, tiempo * 10.0 + float(i) * 1.51, 5.25, radio * 0.20)
		_guardar(arco, grosor * 1.9, alfa * 0.24)
		_guardar(arco, grosor, alfa * (0.76 + 0.22 * sin(tiempo * 16.0 + float(i))))
	for i in 3:
		var fase: float = fposmod(tiempo * 3.25 + float(i) / 3.0, 1.0)
		var z: float = radio * (1.2 + 6.8 * fase) * estela
		var arco: PackedVector3Array = _anillo_rafaga(z, radio * (0.88 + 1.5 * fase),
			tiempo * 3.0 + float(i) * 2.2, 5.5, radio * (0.62 + 0.32 * fase))
		_guardar(arco, grosor * 0.86, alfa * estela * sin(PI * fase) * 0.68)
	for i in 4:
		var angulo: float = float(i) * TAU / 4.0 + tiempo * 7.0
		var lado := Vector3(cos(angulo), sin(angulo), 0.0)
		var puntos := PackedVector3Array()
		for j in 9:
			var u: float = float(j) / 8.0
			var deriva: float = 0.16 * sin(u * TAU + tiempo * 12.0 + float(i))
			puntos.append((lado * (lerpf(0.58, 0.24, u) + deriva) + Vector3.BACK * u * 7.5 * estela) * radio)
		_guardar(puntos, grosor * 0.52, alfa * estela * 0.43)


func _anillo_rafaga(z: float, radio: float, angulo: float, arco: float, sesgo: float) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	for j in 28:
		var a: float = angulo + arco * float(j) / 27.0
		puntos.append(Vector3(cos(a) * radio, sin(a) * radio, z + cos(a) * sesgo))
	return puntos


func _carga(radio: float, tiempo: float, alfa: float, progreso: float) -> void:
	var cierre: float = smoothstep(0.0, 0.86, progreso)
	var escala: float = maxf(0.26, radio) * lerpf(3.2, 0.92, cierre)
	for i in 8:
		var fase: float = float(i) * 2.39996 + tiempo * lerpf(5.5, 14.0, cierre)
		var inclinacion: float = sin(float(i) * 2.4) * 0.86
		var puntos := PackedVector3Array()
		for j in 26:
			var u: float = float(j) / 25.0
			var a: float = fase + u * (2.4 + cierre * 2.5)
			var r: float = escala * lerpf(1.27, 0.49, u) * (0.65 + float(i % 3) * 0.19)
			puntos.append(Vector3(cos(a) * r, sin(a) * r, 0.0).rotated(Vector3.RIGHT, inclinacion))
		var grueso: float = clampf(escala * 0.10, 0.032, 0.085)
		_guardar(puntos, grueso * 2.0, alfa * 0.23)
		_guardar(puntos, grueso, alfa * (0.68 + 0.19 * sin(tiempo * 12.0 + float(i))))


func _salida(radio: float, alfa: float, progreso: float) -> void:
	for i in 4:
		var r: float = maxf(radio, 0.22) * (0.8 + progreso * (2.5 + float(i) * 0.44))
		var arco: PackedVector3Array = _anillo_rafaga(-r * float(i) * 0.13, r, float(i) * 1.57, 5.5, r * 0.33)
		_guardar(arco, clampf(r * 0.105, 0.048, 0.13), alfa * (1.0 - progreso) * 0.82)


func _haz(ejes: Vector3, tiempo: float, alfa: float) -> void:
	var radio: float = ejes.z * 0.55
	for i in 11:
		var puntos := PackedVector3Array()
		var giro: float = float(i) * 2.39996
		var fase: float = fposmod(tiempo * 4.8 + float(i) * 0.38197, 1.0)
		var inicio: float = 0.0 if i < 5 else fase * 0.78
		var fin: float = 1.0 if i < 5 else minf(inicio + 0.30, 1.0)
		for j in 57:
			var u: float = lerpf(inicio, fin, float(j) / 56.0)
			var onda: float = u * 29.0 - tiempo * 20.0
			var angulo: float = giro + u * (10.0 + float(i % 4) * 2.7) - tiempo * 18.0
			angulo += sin(onda + giro) * 0.58
			var perfil: float = 0.38 + 0.25 * sin(PI * u) + 0.13 * sin(onda * 0.62 + giro)
			var apertura: float = radio * perfil * (0.54 + 0.19 * float(i % 4))
			var lado := Vector3(cos(angulo), sin(angulo) * 0.78, 0.0)
			var eje := Vector3(sin(onda * 0.49) * radio * 0.10, ejes.y, -u * ejes.x)
			puntos.append(eje + lado * apertura)
		var grosor: float = clampf(radio * (0.10 + 0.04 * float(i % 3)), 0.038, 0.13)
		var fuerza: float = alfa * (0.64 + 0.24 * sin(tiempo * 18.0 + giro)) if i < 5 else alfa * sin(PI * fase)
		_guardar(puntos, grosor * 2.9, fuerza * 0.24)
		_guardar(puntos, grosor, fuerza)
	for i in 7:
		var fase: float = fposmod(tiempo * 3.4 + float(i) / 7.0, 1.0)
		var z: float = -ejes.x * (0.90 + 0.10 * fase) if i < 5 else -ejes.x * fase * 0.12
		var arco := _anillo_rafaga(z, radio * (0.25 + 1.12 * fase), tiempo * 9.0 + float(i) * 2.4,
			2.25 + float(i % 3) * 0.45, radio * 0.26)
		for j in arco.size():
			arco[j].y += ejes.y
		_guardar(arco, clampf(radio * 0.18, 0.04, 0.14), alfa * sin(PI * fase) * 0.90)


func _tornado(ejes: Vector3, tiempo: float, alfa: float) -> void:
	for i in 23:
		var fase: float = fposmod(tiempo * 0.88 + float(i) * 0.38197, 1.0)
		var semilla: float = float(i) * 2.39996
		var angulo: float = tiempo * 7.2 + semilla
		var inicio: float = fase * 0.88
		var subida: float = 0.13 + 0.19 * (0.5 + 0.5 * sin(semilla))
		var arco: float = 3.4 + 5.2 * (0.5 + 0.5 * cos(semilla * 1.7))
		var puntos := PackedVector3Array()
		for j in 42:
			var u: float = float(j) / 41.0
			var giro: float = angulo + u * arco + 0.24 * sin(u * TAU + semilla)
			var ondulacion: float = sin(giro * 1.35 + semilla) * 0.055
			var nivel: float = clampf(inicio + subida * u + ondulacion, 0.0, 1.10)
			var radio: float = lerpf(0.53, 1.64, nivel) + sin(giro * 1.7 + semilla) * 0.15
			radio *= 0.83 + 0.28 * sin(PI * u) + 0.13 * cos(semilla)
			var eje_x: float = sin(nivel * 5.5 - tiempo * 2.4) * ejes.x * (0.13 + nivel * 0.38)
			var eje_z: float = cos(nivel * 4.0 - tiempo * 1.8) * ejes.z * nivel * 0.27
			puntos.append(Vector3(cos(giro) * ejes.x * radio + eje_x,
				0.06 + ejes.y * nivel, sin(giro) * ejes.z * radio + eje_z))
		var es_hilo: bool = i % 3 == 0
		var grueso: float = clampf(ejes.x * (0.13 if es_hilo else 0.43 + 0.19 * sin(semilla)), 0.04, 0.40)
		var fuerza: float = alfa * sin(PI * fase)
		_guardar(puntos, grueso, fuerza * (0.58 if es_hilo else 0.92), 0.82)


func _muro(ejes: Vector3, tiempo: float, alfa: float) -> void:
	for i in 28:
		var velocidad: float = 1.25 if i % 2 == 0 else 1.95
		var fase: float = fposmod(tiempo * velocidad + float(i) * 0.38197, 1.0)
		var x: float = lerpf(-0.96, 0.96, float(i) / 27.0) + sin(float(i) * 2.4) * 0.036
		var puntos := PackedVector3Array()
		for j in 16:
			var u: float = float(j) / 15.0
			var inicio: float = fase * 0.42
			var nivel: float = lerpf(inicio, minf(inicio + 0.65 + 0.15 * sin(float(i)), 1.06), u)
			var deriva: float = sin(nivel * 4.0 + tiempo * 4.0 + float(i)) * 0.04 + nivel * nivel * 0.13
			puntos.append(_punto_muro(ejes, x + deriva, nivel))
		var grosor: float = clampf(ejes.x * (0.075 + 0.04 * float(i % 3)), 0.065, 0.24)
		_guardar(puntos, grosor * 3.0, alfa * sin(PI * fase) * 0.27, 0.5)
		_guardar(puntos, grosor, alfa * sin(PI * fase) * 0.74, 0.5)
	for i in 2:
		var borde := PackedVector3Array()
		for j in 33:
			var u: float = float(j) / 32.0
			var x: float = -1.0 if i == 0 else 1.0
			var deriva: float = u * u * (0.08 if i == 0 else 0.18)
			borde.append(_punto_muro(ejes, x + deriva, u + 0.025 * sin(u * TAU + tiempo * 8.0)))
		_guardar(borde, clampf(ejes.x * 0.14, 0.095, 0.25), alfa * 0.57)
	for i in 5:
		var fase: float = fposmod(tiempo * 1.36 + float(i) / 5.0, 1.0)
		var x: float = -0.91 + float(i) * 0.41 + fase * 0.11
		var puntos := PackedVector3Array()
		for j in 18:
			var u: float = float(j) / 17.0
			var nivel: float = 0.67 + fase * 0.26 + 0.16 * sin(u * PI * 0.72)
			var p: Vector3 = _punto_muro(ejes, x + u * (0.13 + fase * 0.16), nivel)
			p.z += u * u * minf(ejes.y * 0.16, 0.28)
			puntos.append(p)
		_guardar(puntos, clampf(ejes.x * 0.09, 0.042, 0.13), alfa * sin(PI * fase) * 0.65)


func _cortina_muro(ejes: Vector3, tiempo: float, opacidad: float) -> void:
	if _cortina == null:
		var material := ShaderMaterial.new()
		material.shader = preload("res://presentacion/vfx/toy/viento_muro.gdshader")
		material.render_priority = -1
		_cortina = MeshInstance3D.new()
		_cortina.name = "CortinaViento"
		_cortina.material_override = material
		_cortina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cortina)
	if not _ejes_cortina.is_equal_approx(ejes):
		_ejes_cortina = ejes
		var superficie := SurfaceTool.new()
		superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
		const COLUMNAS := 24
		const FILAS := 12
		for fila in FILAS + 1:
			for columna in COLUMNAS + 1:
				var uv := Vector2(float(columna) / COLUMNAS, float(fila) / FILAS)
				superficie.set_uv(uv)
				superficie.add_vertex(_punto_muro(ejes, lerpf(-1.12, 1.12, uv.x), uv.y * 1.12))
		for fila in FILAS:
			for columna in COLUMNAS:
				var a: int = fila * (COLUMNAS + 1) + columna
				var b: int = a + COLUMNAS + 1
				for indice in [a, a + 1, b, a + 1, b + 1, b]:
					superficie.add_index(indice)
		_cortina.mesh = superficie.commit()
	var material := _cortina.material_override as ShaderMaterial
	material.set_shader_parameter("tiempo", tiempo)
	material.set_shader_parameter("opacidad", opacidad)


func _punto_muro(ejes: Vector3, x: float, nivel: float) -> Vector3:
	return Vector3(x * ejes.x * (1.0 + nivel * 0.12), 0.04 + maxf(nivel, 0.0) * ejes.y,
		x * x * minf(ejes.x * 0.23, 0.62) + nivel * minf(ejes.y * 0.29, 0.52))


func _escudo(ejes: Vector3, tiempo: float, alfa: float) -> void:
	for i in 15:
		var fase: float = fposmod(tiempo * 0.92 + float(i) * 0.38197, 1.0)
		var angulo: float = tiempo * 5.0 + float(i) * 2.39996
		var nivel: float = lerpf(0.13, 0.92, fposmod(float(i) * 0.38197, 1.0))
		var puntos := PackedVector3Array()
		for j in 24:
			var u: float = float(j) / 23.0
			var a: float = angulo + u * (1.9 + float(i % 3) * 0.62)
			var h: float = nivel + 0.21 * sin(a * 0.92 + float(i))
			var radio: float = sqrt(maxf(0.10, 1.0 - pow((h - 0.37) / 0.82, 2.0)))
			puntos.append(Vector3(cos(a) * ejes.x * radio, 0.04 + maxf(h, 0.0) * ejes.y,
				sin(a) * ejes.z * radio))
		var grueso: float = clampf(ejes.x * 0.17, 0.065, 0.22)
		_guardar(puntos, grueso * 2.5, alfa * sin(PI * fase) * 0.26)
		_guardar(puntos, grueso, alfa * sin(PI * fase))


func _borde_escudo(ejes: Vector3, opacidad: float) -> void:
	if _contorno_escudo == null:
		var esfera := SphereMesh.new()
		esfera.radial_segments = 48
		esfera.rings = 24
		_contorno_escudo = _crear_contorno(esfera, "ContornoGris")
	_contorno_escudo.position.y = 0.05 + ejes.y * 0.52
	_contorno_escudo.scale = Vector3(ejes.x * 2.04, ejes.y * 1.14, ejes.z * 2.04)
	(_contorno_escudo.material_override as ShaderMaterial).set_shader_parameter("opacidad", opacidad)


func _borde_tornado(ejes: Vector3, tiempo: float, opacidad: float) -> void:
	if _contorno_tornado == null:
		var cilindro := CylinderMesh.new()
		cilindro.height = 1.0
		cilindro.radial_segments = 48
		cilindro.rings = 16
		cilindro.cap_top = false
		cilindro.cap_bottom = false
		_contorno_tornado = _crear_contorno(cilindro, "ContornoTornado")
		_contorno_tornado.custom_aabb = AABB(Vector3(-1.4, -0.5, -1.4), Vector3(2.8, 1.0, 2.8))
		var material := _contorno_tornado.material_override as ShaderMaterial
		material.set_shader_parameter("tornado", true)
		material.set_shader_parameter("color_borde", Color("#c9f3a3"))
	_contorno_tornado.position.y = 0.06 + ejes.y * 0.55
	_contorno_tornado.scale = Vector3(ejes.x * 2.0, ejes.y * 1.1, ejes.z * 2.0)
	var material := _contorno_tornado.material_override as ShaderMaterial
	material.set_shader_parameter("tiempo", tiempo)
	material.set_shader_parameter("opacidad", opacidad * 0.37)


func _crear_contorno(forma: Mesh, nombre: String) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentacion/vfx/toy/viento_contorno.gdshader")
	var contorno := MeshInstance3D.new()
	contorno.name = nombre
	contorno.mesh = forma
	contorno.material_override = material
	contorno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(contorno)
	return contorno


func _aura(ejes: Vector3, tiempo: float, alfa: float, elevacion: float) -> void:
	for i in 5:
		var fase: float = fposmod(tiempo * 2.1 + float(i) / 5.0, 1.0)
		var angulo: float = tiempo * 9.0 + float(i) * 2.39996
		var puntos := PackedVector3Array()
		for j in 32:
			var u: float = float(j) / 31.0
			var a: float = angulo + u * (3.2 + float(i % 3) * 0.7)
			var radio: float = ejes.x * (1.14 + 0.26 * u + 0.13 * sin(a))
			var nivel: float = 0.27 + 0.32 * fase + sin(a + 0.4) * 0.17 + u * (0.11 + 0.20 * elevacion)
			puntos.append(Vector3(cos(a) * radio, nivel * ejes.y, sin(a) * radio))
		var grosor: float = clampf(ejes.x * (0.19 if i % 2 == 0 else 0.095), 0.034, 0.16)
		var fuerza: float = alfa * sin(PI * fase)
		_guardar(puntos, grosor * 2.25, fuerza * 0.25, 0.0)
		_guardar(puntos, grosor, fuerza, 0.0)
