extends MeshInstance3D

const Cintas = preload("res://presentacion/vfx/toy/rayo_trazos.gd")

var _trazos: Array = []
var _contorno_escudo: MeshInstance3D
var _contorno_tornado: MeshInstance3D
var _cortina: MeshInstance3D
var _ejes_cortina := Vector3.ZERO
## CAMPO DE VIENTO (11/11, CampoViento; null = las cintas de siempre). Si lo hay, los PUNTOS de cada cinta se desplazan con lo que el campo desvía respecto al viento de la figura
## (turbulencia sin divergencia + rodeo de los sólidos): `campo_tau` s de recorrido en la punta de la cinta. Y ningún punto queda dentro de un sólido.
## RODEO VISIBLE (11/11, «no veo diferencia en viento»): con 0,3 m de tope y los puntos sacados a la piel más cercana, las cintas se aplastaban contra la cara de la cápsula (y la
## propia cápsula las tapaba desde la cámara del juego). Ahora, cerca de un sólido, los puntos se apartan HACIA EL LADO respecto al viento de la figura (la componente de la normal
## perpendicular al viento) hasta pasar a `campo_holgura` m de la piel: la cinta se abre antes de llegar, lo rodea y se vuelve a cerrar detrás (a `campo_alcance` m ya no se toca).
var campo: CampoViento = null
var campo_tau: float = 0.3
var campo_max: float = 0.45           ## m: tope del desvío de la TURBULENCIA en un punto (el rodeo de los sólidos va aparte y no lo lleva)
var campo_holgura: float = 0.26       ## m: a qué distancia de la piel pasa la cinta que rodea un sólido
var campo_alcance: float = 0.6        ## m: desde qué distancia a la piel empieza a apartarse
var campo_rodeo_max: float = 1.1      ## m: lo más que se aparta un punto para rodear (una cápsula de 0,38 m de radio cogida de frente pide ~0,65)
var puntos_desviados: int = 0          ## (las pruebas) puntos movidos en el último dibujo
var _ult_in := PackedVector3Array()
var _ult_out := PackedVector3Array()
var _offs_cache: Array = []            ## desvíos de los puntos de control de cada cinta (se rehacen la mitad por dibujo, alternas)
var _emp_cache: Array = []             ## empujes del rodeo de cada cinta (ídem)
var _justos_cache: Array = []
var _ult_d: float = 1000.0             ## distancia a la piel de la última muestra tras _rodeo
var _n_cinta: int = 0
var _paridad: int = 0


func _ready() -> void:
	mesh = ArrayMesh.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentacion/vfx/toy/viento_corriente.gdshader")
	# El aire no lleva color propio (ver viento_corriente.gdshader): la paleta fria del toy, no verde. El verde es de las hojas.
	material.set_shader_parameter("claro", VientoToy.CLARO)
	material.set_shader_parameter("sombra", VientoToy.SOMBRA)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func dibujar(figura: StringName, ejes: Vector3, tiempo: float, opacidad: float, ancho: float, avance: float = 1.0) -> void:
	_trazos.clear()
	puntos_desviados = 0
	_ult_in = PackedVector3Array()
	_n_cinta = 0
	_paridad = 1 - _paridad
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
	if campo != null and is_inside_tree():
		puntos = _desviar(puntos)
	_trazos.append({"puntos": puntos, "ancho": grosor, "punta": grosor * 0.35,
		"alfa": alfa, "alfa_punta": alfa * 0.73, "tinte": tinte})


func _rafaga(ejes: Vector3, tiempo: float, alfa: float, estela: float) -> void:
	var radio: float = maxf(0.17, maxf(ejes.x, ejes.z))
	var grosor: float = clampf(radio * 0.22, 0.055, 0.11)
	# VOLUMEN: tres cintas ORBITALES en planos distintos (como un astrolabio) que se cruzan y se solapan. Una sola lamina vista de canto es una raya; tres planos
	# que no coinciden dan silueta de esfera desde cualquier angulo. La cabeza de cada cinta va por delante (ancha) y la cola se afina.
	var centro := Vector3(0.0, 0.0, -radio * 0.68 * smoothstep(0.0, 0.5, estela))   # la envoltura se adelanta al arrancar (ver _process en viento_toy.gd)
	var giro_global: Basis = Basis(Vector3.BACK, tiempo * 1.7)                           # todo el conjunto gira sobre el eje del vuelo
	for i in 3:
		var plano: Basis = giro_global * Basis(Vector3.BACK, float(i) * TAU / 3.0) * Basis(Vector3.RIGHT, deg_to_rad(58.0))   # tres planos a 58 grados del eje y repartidos a 120: ninguno queda de canto
		var cabeza: float = tiempo * (9.0 + float(i) * 2.0) * (1.0 if i != 1 else -1.0) + float(i) * 2.1
		var arco := PackedVector3Array()
		for j in 26:
			var a: float = cabeza - 5.0 * float(j) / 25.0 * (1.0 if i != 1 else -1.0)
			var r: float = radio * (0.98 + 0.07 * sin(a * 2.0 + float(i)))
			arco.append(centro + plano * Vector3(cos(a) * r, sin(a) * r, 0.0))
		_guardar(arco, grosor * 2.7, alfa * 0.30, 0.0)
		_guardar(arco, grosor * 1.7, alfa * (0.80 + 0.18 * sin(tiempo * 14.0 + float(i))), 0.0)
	for i in 3:
		var fase: float = fposmod(tiempo * 3.25 + float(i) / 3.0, 1.0)
		var z: float = radio * (1.1 + 3.4 * fase) * estela
		var arco: PackedVector3Array = _anillo_rafaga(z, radio * (0.88 + 0.7 * fase),
			tiempo * 3.0 + float(i) * 2.2, 5.5, radio * (0.62 + 0.32 * fase))
		_guardar(arco, grosor * 0.86, alfa * estela * sin(PI * fase) * 0.68)
	for i in 4:
		var angulo: float = float(i) * TAU / 4.0 + tiempo * 7.0
		var lado := Vector3(cos(angulo), sin(angulo), 0.0)
		var puntos := PackedVector3Array()
		for j in 9:
			var u: float = float(j) / 8.0
			var deriva: float = 0.16 * sin(u * TAU + tiempo * 12.0 + float(i))
			puntos.append((lado * (lerpf(0.58, 0.24, u) + deriva) + Vector3.BACK * u * 4.0 * estela) * radio)
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


## HAZ = LANZA DE AIRE que apunta hacia -Z: nace en un punto en la mano, se ensancha hasta el primer tercio y se cierra en una PUNTA al frente (como la lanza del fuego, y
## no un aro). Las cintas largas son las lineas de corriente; las cortas son cometas que viajan hacia delante con la cabeza gruesa por delante y la cola afinada; los
## CHEVRONES (V con el vertice al frente, en dos planos cruzados) recorren el haz de la mano a la punta y son lo que hace que se lea la direccion sin pensar.
## El haz arranca un poco DETRÁS del origen (la mano): las cintas entran con alfa desde su primer punto y, empezando justo en la mano, quedaba un hueco entre la jugadora y el primer trazo.
const HAZ_ATRAS: float = 0.14

func _z_haz(u: float, largo: float) -> float:
	return (u * (1.0 + HAZ_ATRAS) - HAZ_ATRAS) * largo


func _haz(ejes: Vector3, tiempo: float, alfa: float) -> void:
	var radio: float = ejes.z * 0.8
	var largo: float = ejes.x
	for i in 12:
		var giro: float = float(i) * 2.39996
		var fase: float = fposmod(tiempo * 3.6 + float(i) * 0.38197, 1.0)
		var larga: bool = i < 6
		var inicio: float = 0.0 if larga else fase * 0.58
		var fin: float = 1.0 if larga else minf(inicio + 0.42, 1.0)
		var puntos := PackedVector3Array()
		for j in 44:
			var t: float = float(j) / 43.0
			var u: float = lerpf(inicio, fin, t if larga else 1.0 - t)   # las cometas van cabeza (delante) primero
			var onda: float = u * 17.0 - tiempo * 14.0
			var angulo: float = giro + u * (1.5 + float(i % 4) * 0.5) - tiempo * 4.0 + sin(onda + giro) * 0.25   # poco giro: lineas de corriente, no un muelle
			var perfil: float = (0.10 + 0.90 * smoothstep(0.0, 0.35, u)) * (1.0 - pow(u, 1.8)) * (1.0 + 0.14 * sin(onda * 0.62 + giro))
			var apertura: float = radio * perfil * (0.45 + 0.17 * float(i % 4))
			var lado := Vector3(cos(angulo), sin(angulo) * 0.78, 0.0)
			puntos.append(Vector3(0.0, ejes.y, -_z_haz(u, largo)) + lado * apertura)
		var grosor: float = clampf(radio * (0.20 + 0.08 * float(i % 3)), 0.042, 0.10)
		var fuerza: float = alfa * (0.68 + 0.22 * sin(tiempo * 15.0 + giro)) if larga else alfa * sin(PI * fase)
		_guardar(puntos, grosor * 2.6, fuerza * 0.24)
		_guardar(puntos, grosor, fuerza)
	# El asta de la lanza: dos cintas rectas y gruesas por el eje que se afinan hasta la PUNTA del frente, siempre por delante de todo lo demas.
	for k in 2:
		var asta := PackedVector3Array()
		for j in 20:
			var u: float = lerpf(0.04, 1.0, float(j) / 19.0)
			var perfil_a: float = (0.10 + 0.90 * smoothstep(0.0, 0.35, u)) * (1.0 - pow(u, 1.8))
			var vaiven: float = sin(tiempo * 9.0 + u * 7.0 + float(k) * PI) * radio * 0.12 * perfil_a
			asta.append(Vector3(vaiven, ejes.y + (float(k) - 0.5) * radio * 0.18 * perfil_a, -_z_haz(u, largo)))
		_guardar(asta, clampf(radio * 0.55, 0.09, 0.22) * 1.7, alfa * 0.30, 0.0)
		_guardar(asta, clampf(radio * 0.55, 0.09, 0.22), alfa * 0.95, 0.0)
	# Los chevrones: V que se abren hacia atras, con el vertice al frente.
	for i in 5:
		var fase: float = fposmod(tiempo * 1.9 + float(i) / 5.0, 1.0)
		var perfil: float = (0.10 + 0.90 * smoothstep(0.0, 0.35, fase)) * (1.0 - pow(fase, 1.8))
		var abre: float = radio * (0.45 + 0.9 * perfil)
		for plano in 2:
			var giro_v := Basis(Vector3.BACK, float(i) * 0.9 + float(plano) * PI * 0.5 + tiempo * 1.3)
			var uve := PackedVector3Array()
			for j in 11:
				var s: float = lerpf(-1.0, 1.0, float(j) / 10.0)
				uve.append(Vector3(0.0, ejes.y, -_z_haz(fase, largo)) + giro_v * Vector3(s * abre, 0.0, absf(s) * abre * 1.15))
			_guardar(uve, clampf(radio * 0.40, 0.07, 0.16), alfa * sin(PI * fase), 0.0)

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
		material.set_shader_parameter("color_borde", VientoToy.CLARO.lerp(VientoToy.SOMBRA, 0.35))
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


## Desplaza los puntos de una cinta con el CAMPO (ver `campo`): se muestrea en K puntos de control (el desvío crece hacia la punta de la cinta; la mitad de las cintas se
## remuestrea en cada dibujo, alternas) y se interpola entre ellos. Si la cinta pasa cerca de un sólido, uno de cada PASO_PIEL puntos se aparta de lado para rodearlo (_rodeo) y el
## empuje se reparte entre ellos; al final, solo los puntos junto a uno empujado miran la SDF. El brillo y el núcleo de una cinta comparten polilínea.
const PASO_PIEL: int = 4

func _desviar(puntos: PackedVector3Array) -> PackedVector3Array:
	var n: int = puntos.size()
	if n < 2:
		return puntos
	if puntos == _ult_in:
		return _ult_out
	var xf: Transform3D = global_transform
	var inv: Transform3D = xf.affine_inverse()
	var k: int = mini(n, 5)
	var paso_k: float = float(n - 1) / float(k - 1)
	var offs := PackedVector3Array()
	offs.resize(k)
	var centro := Vector3.ZERO
	var mundo := PackedVector3Array()
	mundo.resize(k)
	var cual: int = _n_cinta
	_n_cinta += 1
	var rehacer: bool = cual >= _offs_cache.size() or (_offs_cache[cual] as PackedVector3Array).size() != k or (cual + _paridad) % 2 == 0
	for m in k:
		var j: int = int(round(float(m) * paso_k))
		var pw: Vector3 = xf * puntos[j]
		mundo[m] = pw
		centro += pw
		if rehacer:
			# solo la TURBULENCIA (11/11): la piel del campo, vista en 5 puntos de control, daba picos de 0,45 m que no rodeaban; el rodeo lo hace _rodeo
			offs[m] = inv.basis * ((campo.turbulencia_libre(pw) if campo.parte_turbulencia else Vector3.ZERO) * campo_tau * (0.3 + 0.7 * float(j) / float(n - 1))).limit_length(campo_max)
	if rehacer:
		while _offs_cache.size() <= cual:
			_offs_cache.append(PackedVector3Array())
		_offs_cache[cual] = offs
	else:
		offs = _offs_cache[cual]
	centro /= float(k)
	var r: float = 0.0
	for m in k:
		r = maxf(r, mundo[m].distance_to(centro))
	var esferas: PackedVector4Array = campo.esferas_cerca(centro, r + campo_alcance + 0.1)
	var ne: int = esferas.size()
	var out := PackedVector3Array()
	out.resize(n)
	var inv_k: float = 1.0 / paso_k
	if ne == 0:
		for j in n:
			out[j] = puntos[j] + _suave(offs, float(j) * inv_k)       # curva (Catmull-Rom), no quebrada: con más turbulencia los codos se veían
	else:
		var nc: int = (n - 1) / PASO_PIEL + 2
		var empujes := PackedVector3Array()
		var justos := PackedByteArray()                     # 1 = tras apartarse, la muestra sigue a menos de 0,15 m de la piel: sus vecinos miran la SDF
		# como los desvíos, el rodeo de cada cinta se rehace en dibujos alternos (la mitad de las cintas cada vez); el contener final cubre el fotograma de retraso
		var rehacer_e: bool = rehacer or cual >= _emp_cache.size() or (_emp_cache[cual] as PackedVector3Array).size() != nc
		if rehacer_e:
			empujes.resize(nc)
			justos.resize(nc)
			var lado_cinta: float = 0.0
			for c in nc:
				var jc: int = mini(c * PASO_PIEL, n - 1)
				var fcc: float = float(jc) * inv_k
				var mc: int = mini(int(fcc), k - 2)
				var pwc: Vector3 = xf * (puntos[jc] + offs[mc].lerp(offs[mc + 1], fcc - float(mc)))
				var rd: Vector4 = _rodeo(pwc, lado_cinta, cual)
				lado_cinta = rd.w
				empujes[c] = inv.basis * Vector3(rd.x, rd.y, rd.z)
				justos[c] = 1 if _ult_d < 0.22 else 0
			empujes = _ensanchar(_ensanchar(empujes))           # se abre antes de llegar y se cierra después (sin bajar el pico)
			while _emp_cache.size() <= cual:
				_emp_cache.append(PackedVector3Array())
				_justos_cache.append(PackedByteArray())
			_emp_cache[cual] = empujes
			_justos_cache[cual] = justos
		else:
			empujes = _emp_cache[cual]
			justos = _justos_cache[cual]
		var inv_p: float = 1.0 / float(PASO_PIEL)
		for j in n:
			var fc: float = float(j) * inv_p
			var c0: int = mini(int(fc), nc - 2)
			var p: Vector3 = puntos[j] + _suave(offs, float(j) * inv_k) + _suave(empujes, fc)
			if justos[c0] == 1 or justos[c0 + 1] == 1:
				# entre dos muestras que han quedado rozando la piel: este punto también puede rozarla
				var pw2: Vector3 = xf * p
				var pc: Vector3 = campo.contener(pw2, 0.06)
				if not pc.is_equal_approx(pw2):
					p = inv * pc
			out[j] = p
	puntos_desviados += n
	_ult_in = puntos
	_ult_out = out
	return out

## Interpolación Catmull-Rom de `a` en el índice fraccionario `f` (extremos repetidos).
static func _suave(a: PackedVector3Array, f: float) -> Vector3:
	var m: int = a.size()
	var i: int = clampi(int(f), 0, m - 2)
	var t: float = clampf(f - float(i), 0.0, 1.0)
	var p0: Vector3 = a[maxi(i - 1, 0)]
	var p1: Vector3 = a[i]
	var p2: Vector3 = a[i + 1]
	var p3: Vector3 = a[mini(i + 2, m - 1)]
	var t2: float = t * t
	return 0.5 * (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t2 * t)


## Un filtro 1-2-1 que conserva el pico: cada empuje se queda con el mayor entre el suyo y la media con sus vecinos.
static func _ensanchar(e: PackedVector3Array) -> PackedVector3Array:
	var m: int = e.size()
	var o := PackedVector3Array()
	o.resize(m)
	for c in m:
		var s: Vector3 = e[maxi(c - 1, 0)] * 0.25 + e[c] * 0.5 + e[mini(c + 1, m - 1)] * 0.25
		o[c] = e[c] if e[c].length_squared() >= s.length_squared() else s
	return o


## El empuje (mundo, xyz) que aparta el punto `p` de una cinta para RODEAR el sólido más cercano, y en w el lado elegido para esa cinta (−1 / +1; 0 = aún sin elegir).
## Lejos (a `campo_alcance` m de la piel o más) no toca nada. Más cerca, la distancia d pasa a d + holgura·(1 − d/alcance)² (dentro, a la holgura): se abre suave antes y se cierra
## suave después. Se aparta por la componente de la normal PERPENDICULAR al viento de la figura (rodea en vez de frenar contra la cara); de frente o justo detrás, donde esa
## componente se anula, hacia el lado que la cinta ya traía (o el de su paridad), y el MISMO lado para toda la cinta (si no, se partiría en zigzag). Hasta 3 pasos cortos
## (cada uno mira la SDF otra vez), así no se pasa de largo; nunca más de `campo_rodeo_max` m.
func _rodeo(p: Vector3, lado_cinta: float, cual: int) -> Vector4:
	var d: float = campo.sdf(p)
	_ult_d = d
	if d >= campo_alcance:
		return Vector4(0.0, 0.0, 0.0, lado_cinta)
	var s: float = clampf(d / campo_alcance, 0.0, 1.0)
	var meta: float = (d + campo_holgura * (1.0 - s) * (1.0 - s)) if d > 0.0 else campo_holgura
	var w: Vector3 = campo.viento_base(p)
	var hay_w: bool = w.length() > 0.05
	var wn: Vector3 = w.normalized() if hay_w else Vector3.ZERO
	var e: Vector3 = Vector3.ZERO
	if hay_w:
		e = wn.cross(Vector3.UP)
		if e.length() < 0.2:
			e = wn.cross(Vector3.RIGHT)
		e = e.normalized()
	var q: Vector3 = p
	var dq: float = d
	for it in 3:
		if dq >= meta - 0.01:
			break
		var nq: Vector3 = campo.normal(q)
		var dirp: Vector3 = nq
		if hay_w:
			var perp: Vector3 = nq - wn * nq.dot(wn)
			var pe: float = perp.dot(e)
			if lado_cinta == 0.0:
				lado_cinta = signf(pe) if absf(pe) > 0.08 else (1.0 if cual % 2 == 0 else -1.0)
			if pe * lado_cinta < 0.0:
				perp -= e * (2.0 * pe)                       # al lado elegido
			dirp = perp + e * lado_cinta * maxf(0.0, 0.7 - perp.length())
			dirp = dirp.normalized() if dirp.length() > 0.001 else nq
		q += dirp * (meta - dq)
		if q.distance_to(p) > campo_rodeo_max:
			q = p + (q - p).normalized() * campo_rodeo_max
			dq = -1.0                                        # no se sabe: que los vecinos miren la SDF
			break
		dq = campo.sdf(q)
	_ult_d = dq
	var emp: Vector3 = q - p
	return Vector4(emp.x, emp.y, emp.z, lado_cinta)