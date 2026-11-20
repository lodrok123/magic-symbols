extends Node3D

## Prototipo visual aislado. No deposita agua ni modifica AguaSim3D.
## El reloj es externo: pausa, camara lenta y scrubbing usan la misma evaluacion.
const T_SUELTA: float = 1.4
const T_CHOQUE: float = 2.4
const DURACION: float = 11.0
const SH_AGUA = preload("res://laboratorios/vfx_revision/agua_flecha.gdshader")
const SH_CHARCO = preload("res://laboratorios/vfx_revision/agua_deposito.gdshader")
const SH_DESTELLO = preload("res://laboratorios/vfx_revision/agua_destello.gdshader")
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const N_DESTELLOS: int = 7
const N_GOTAS: int = 130
const SEG_COPA: int = 128
const ANILLOS_COPA: int = 12
var oblicuo: bool = false
var horizontal: bool = false
var radio: float = 0.4
var bola: MeshInstance3D
var corona: MeshInstance3D
var charco: MeshInstance3D
var gotas: MultiMeshInstance3D
var estela: MultiMeshInstance3D
var destellos: MultiMeshInstance3D
var mat_destello: ShaderMaterial
var mat_agua: ShaderMaterial
var mat_corona: ShaderMaterial
var mat_charco: ShaderMaterial
var ultimo_estado: Dictionary = {}

static func evaluar(t: float, diagonal: bool, r: float = 0.4, lateral: bool = false) -> Dictionary:
	var origen := Vector3(-2.6, 2.8, 0.0) if diagonal else Vector3(0.0, 3.6, 0.0)
	var destino := Vector3(0.0, r, 0.0)
	if lateral:
		origen = Vector3(-3.2, 1.1, 0.0)
		destino = Vector3(0.0, 1.1, 0.0)
	var u := clampf((t - T_SUELTA) / (T_CHOQUE - T_SUELTA), 0.0, 1.0)
	var carga := smoothstep(0.08, 1.2, t)
	var edad := t - T_CHOQUE
	var aplasta := smoothstep(0.0, 0.12, edad)
	var pos := origen.lerp(destino, u)
	if edad >= 0.0: pos.y = lerpf(r, 0.035, aplasta)
	if lateral and edad >= 0.0:
		pos = Vector3((r - 0.035) * aplasta, 1.1, 0.0)
	var extension := sqrt(1.65) if diagonal else 1.0
	# Misma area para ambos angulos y radio proporcional a sqrt(volumen).
	var base := 1.35 * pow(r / 0.4, 1.5)
	var escala := Vector3(1.0 + aplasta * 1.4, 1.0 - aplasta * 0.94, 1.0 + aplasta * 1.4) * r * maxf(carga, 0.001)
	if lateral: escala = Vector3(escala.y, escala.x, escala.z)
	var deposito := edad - (0.22 if lateral else 0.0)
	return {"pos": pos, "origen": origen, "dir": (destino - origen).normalized(),
		"carga": carga, "edad": edad, "vuelo": u,
		"escala": escala,
		"bola_visible": t > 0.02 and edad < 0.16,
		"corona_visible": edad > 0.015 and edad < 0.55,
		"charco_visible": deposito >= 0.0 and edad < 8.5,
		"expansion": lerpf(0.13, 1.0, smoothstep(0.0, 0.85, deposito)),
		"vida": 1.0 - smoothstep(7.0, 8.5, edad),
		"ejes_charco": Vector2(base * extension, base / extension),
		"fase": "FORMACION" if t < 1.2 else ("SOSTEN" if t < T_SUELTA else ("VUELO" if edad < 0.0 else ("IMPACTO" if edad < 0.65 else "CHARCO")))}

func _ready() -> void:
	mat_agua = AguaMallas.material(SH_AGUA.resource_path, {"suave_prof": 0.035})
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 48
	esfera.rings = 24
	bola = _malla("MasaAgua", esfera, mat_agua)
	mat_corona = AguaMallas.material(SH_AGUA.resource_path, {"suave_prof": 0.035})
	mat_corona.set_shader_parameter("corona", true)
	mat_corona.set_shader_parameter("radio", radio)
	mat_corona.set_shader_parameter("oblicuo", 1.0 if oblicuo else 0.0)
	mat_corona.set_shader_parameter("pared", 1.0 if horizontal else 0.0)
	corona = _malla("SalpicaduraContinua", _copa(), mat_corona)
	corona.custom_aabb = AABB(Vector3(-5, -0.1, -5), Vector3(10, 4, 10))
	if horizontal: corona.rotation.z = PI * 0.5
	bola.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 7))
	mat_charco = AguaMallas.material(SH_CHARCO.resource_path)
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.0, 2.0)
	charco = _malla("DepositoVisual", plano, mat_charco)
	charco.position.y = 0.018
	gotas = _multimalla("Gotas", N_GOTAS)
	estela = _multimalla("Estela", 9)
	_crear_destellos()
	avanzar_a(0.0)

func _crear_destellos() -> void:
	destellos = MultiMeshInstance3D.new()
	destellos.name = "Destellos"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	destellos.multimesh = MultiMesh.new()
	destellos.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	destellos.multimesh.mesh = quad
	destellos.multimesh.instance_count = N_DESTELLOS
	mat_destello = AguaMallas.material(SH_DESTELLO.resource_path)
	destellos.material_override = mat_destello
	destellos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	destellos.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
	add_child(destellos)

func _malla(nombre: String, m: Mesh, mat: Material) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = m
	nodo.material_override = mat
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	return nodo

func _multimalla(nombre: String, n: int) -> MultiMeshInstance3D:
	var nodo := MultiMeshInstance3D.new()
	nodo.name = nombre
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 12
	m.rings = 6
	nodo.multimesh = MultiMesh.new()
	nodo.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	nodo.multimesh.mesh = m
	nodo.multimesh.instance_count = n
	var material := AguaMallas.material(SH_AGUA.resource_path, {"deformacion": 0.08})
	nodo.material_override = material
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	return nodo

func _copa() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var col := SEG_COPA + 1
	for j in ANILLOS_COPA + 1:
		for i in col:
			var a := float(i) / float(SEG_COPA) * TAU
			vertices.append(Vector3(cos(a) * radio, float(j) / float(ANILLOS_COPA) * radio, sin(a) * radio))
			normales.append(Vector3(cos(a), 0, sin(a)))
			uv.append(Vector2(float(i) / float(SEG_COPA), float(j) / float(ANILLOS_COPA)))
	for j in ANILLOS_COPA:
		for i in SEG_COPA:
			var k := j * col + i
			indices.append_array(PackedInt32Array([k, k + col, k + 1, k + 1, k + col, k + col + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func avanzar_a(t: float) -> void:
	ultimo_estado = evaluar(t, oblicuo, radio, horizontal)
	var e := ultimo_estado
	var edad: float = e.edad
	bola.visible = e.bola_visible
	bola.position = e.pos
	# Restablecer orientacion: la compresion siempre actua contra el suelo,
	# incluso al retroceder desde un fotograma de vuelo.
	bola.basis = Basis.IDENTITY.scaled(e.escala)
	if t >= T_SUELTA and edad < 0.0:
		var redondeo := smoothstep(0.85, 1.0, float(e.vuelo))
		var ancho := lerpf(0.85, 1.0, redondeo) * radio
		var largo := lerpf(1.25, 1.0, redondeo) * radio
		bola.basis = Basis.looking_at(e.dir, Vector3.FORWARD if not oblicuo else Vector3.UP).scaled(Vector3(ancho, ancho, largo))
	mat_agua.set_shader_parameter("reloj", t)
	mat_agua.set_shader_parameter("aparicion", e.carga)
	mat_agua.set_shader_parameter("deformacion", lerpf(0.23, 0.13, float(e.carga)))
	var cola: float = 3.2 * smoothstep(T_SUELTA, T_SUELTA + 0.12, t) * (1.0 - smoothstep(T_CHOQUE - 0.12, T_CHOQUE, t))
	mat_agua.set_shader_parameter("cola", cola)
	# Cabeza clara durante el vuelo y aclarado breve en el primer contacto.
	var cabeza: float = smoothstep(T_SUELTA, T_SUELTA + 0.10, t) * (1.0 - smoothstep(T_CHOQUE - 0.06, T_CHOQUE + 0.02, t))
	var flash: float = (1.0 - smoothstep(0.0, 0.14, edad)) if edad >= 0.0 else 0.0
	mat_agua.set_shader_parameter("cabeza", cabeza)
	mat_agua.set_shader_parameter("destello", flash)
	mat_corona.set_shader_parameter("destello", flash)
	corona.visible = e.corona_visible
	corona.position.x = maxf(edad, 0.0) * 0.9 if oblicuo else 0.0
	if horizontal: corona.position = Vector3(radio - 0.015, 1.1, 0.0)
	mat_corona.set_shader_parameter("edad", maxf(edad, 0.0))
	mat_corona.set_shader_parameter("reloj", t)
	charco.visible = e.charco_visible
	var ejes: Vector2 = e.ejes_charco
	charco.scale = Vector3(ejes.x, 1.0, ejes.y) * 1.3
	charco.position.x = 0.23 * e.expansion if oblicuo else 0.0
	if horizontal: charco.position.x = -0.25 * e.expansion
	mat_charco.set_shader_parameter("limite_x", global_position.x + radio if horizontal else 1000.0)
	mat_charco.set_shader_parameter("expansion", e.expansion)
	mat_charco.set_shader_parameter("vida", e.vida)
	mat_charco.set_shader_parameter("reloj", t)
	mat_charco.set_shader_parameter("edad", maxf(edad, 0.0))
	_actualizar_gotas(t, e)
	_actualizar_estela(t, e)
	_actualizar_destellos(t, e)

func _poner(mm: MultiMesh, i: int, p: Vector3, tam: Vector3, orientacion: Basis = Basis.IDENTITY) -> void:
	mm.set_instance_transform(i, Transform3D(orientacion.scaled(tam), p))

func _actualizar_gotas(t: float, e: Dictionary) -> void:
	var n: int = 0
	for i in N_GOTAS:
		# El suelo y el vuelo siguen con 48; solo la nube contra pared usa todos.
		if i >= 48 and not (horizontal and t >= T_CHOQUE): continue
		var a := float(i) * 2.3999632
		var f := fposmod(sin(float(i) * 127.1 + 7.5) * 43758.5453, 1.0)
		var g := fposmod(sin(float(i) * 311.7 + 2.1) * 19578.1234, 1.0)
		var p := Vector3.ZERO
		var s := 0.018 + f * 0.023
		var tam := Vector3(s, s * 1.4, s) * (radio / 0.4)
		var orientacion := Basis.IDENTITY
		if t < T_SUELTA:
			if i >= 10: continue
			# Goteo desprendido del volumen al formarse; no un anillo de carga.
			var dt := fposmod(t + f * 0.7, 0.7)
			var r: float = radio * e.carga
			p = e.origen + Vector3(cos(a) * r * 0.45, -r * 0.85 - dt * dt * 1.3, sin(a) * r * 0.45)
			tam *= sin(dt / 0.7 * PI) * smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(1.2, T_SUELTA, t)) * 0.8
		else:
			var dt: float = e.edad - 0.035 - f * 0.065
			if horizontal: dt = e.edad - 0.012 - f * 0.10
			if dt < 0.0: continue
			var v := Vector3(cos(a) * (0.9 + g * 2.0), 1.2 + f * 2.5, sin(a) * (0.9 + g * 2.0)) * (radio / 0.4)
			if oblicuo: v.x += 1.2
			p = Vector3(cos(a) * radio * 0.6, 0.04, sin(a) * radio * 0.6) + v * dt + Vector3.DOWN * 4.9 * dt * dt
			if horizontal:
				# Contra una pared el agua no se extiende como una copa: revienta en una nube de
				# fragmentos hacia todo el hemisferio frente a la pared (referencia del usuario,
				# 19/11) y cae por gravedad.
				# Mas denso cerca del impacto: la mayoria sale despacio y pocos llegan lejos.
				var ct := 0.08 + 0.92 * pow(f, 0.75)
				var st := sqrt(1.0 - ct * ct)
				var vel := (0.8 + 3.8 * pow(g, 1.7)) * (radio / 0.4)
				var dir := Vector3(-ct, st * cos(a * 1.7), st * sin(a * 1.7))
				v = dir * vel + Vector3.UP * 0.5
				p = Vector3(radio - 0.02, 1.1, 0.0) + dir * radio * 0.22 + v * dt + Vector3.DOWN * 4.9 * dt * dt
				# Tamano en dos grupos (muchos pequenos, pocos gruesos) y se encogen al final
				# en vez de desaparecer de golpe.
				var h2 := fposmod(sin(float(i) * 78.233 + 1.7) * 12543.853, 1.0)
				tam *= (1.7 if h2 > 0.9 else 0.55 + h2 * 0.5) * 0.95
				tam *= 1.0 - smoothstep(0.55, 1.1, dt)
			if p.y < 0.025 or dt > 1.1: continue
			if horizontal:
				var vf := v + Vector3.DOWN * 9.8 * dt
				var rapidez := vf.length()
				if i % 3 == 0:
					# Esquirla aplanada que gira.
					tam *= Vector3(2.4, 0.30, 1.6)
					orientacion = Basis(Vector3(0.4, 1.0, 0.2).normalized(), a + dt * 5.0)
				else:
					# Gota alargada en la direccion real del movimiento (3D completo).
					tam.y *= 1.0 + rapidez * 0.45
					orientacion = Basis(Quaternion(Vector3.UP, vf.normalized()))
			elif i % 6 == 0:
				tam *= Vector3(3.0, 0.30, 2.2)
				orientacion = Basis(Vector3(0.4, 1.0, 0.2).normalized(), a + dt * 4.0)
			else:
				tam.y *= 1.0 + absf(v.y - 9.8 * dt) * 0.18
				orientacion = Basis(Quaternion(Vector3.UP, (v + Vector3.DOWN * 9.8 * dt).normalized()))
		if tam.length_squared() < 0.00000001: continue
		_poner(gotas.multimesh, n, p, tam, orientacion)
		n += 1
	gotas.multimesh.visible_instance_count = n
	(gotas.material_override as ShaderMaterial).set_shader_parameter("reloj", t)

## Brillos puntuales sobre la lamina: nacen en un instante del impacto, duran 3-7 fotogramas
## a 30 fps y pulsan. Posicion y tiempos salen de un hash por indice (sin azar de ejecucion).
func _actualizar_destellos(t: float, e: Dictionary) -> void:
	var n: int = 0
	var edad: float = e.edad
	if edad >= 0.0 and edad < 0.5:
		for i in N_DESTELLOS:
			var f := fposmod(sin(float(i) * 91.7 + 3.3) * 43758.5453, 1.0)
			var g := fposmod(sin(float(i) * 57.3 + 8.1) * 19578.1234, 1.0)
			var a := float(i) * 2.3999632 + g * 0.6
			var inicio := 0.012 + f * 0.11
			var vida_d := 0.10 + g * 0.13
			var u := (edad - inicio) / vida_d
			if u < 0.0 or u > 1.0: continue
			var alcance := radio * (0.35 + 0.9 * g) * (0.5 + 0.8 * smoothstep(0.0, 0.3, edad))
			var alto := radio * (0.15 + 0.55 * f) * sin(clampf(edad / 0.35, 0.0, 1.0) * PI * 0.8)
			var p := Vector3(cos(a) * alcance, 0.05 + alto, sin(a) * alcance)
			if oblicuo: p.x += 0.35 * radio + edad * 0.9
			if horizontal:
				p = Vector3(radio - 0.04 - alto * 0.6, 1.1 + cos(a) * alcance * 0.8, sin(a) * alcance)
			var tam := radio * (0.28 + 0.20 * f) * sin(u * PI) * (1.0 + 0.25 * sin(u * 18.0 + float(i)))
			_poner(destellos.multimesh, n, p, Vector3(tam, tam, tam))
			n += 1
	destellos.multimesh.visible_instance_count = n
	mat_destello.set_shader_parameter("reloj", t)

func _actualizar_estela(t: float, e: Dictionary) -> void:
	var n: int = 0
	if t >= T_SUELTA and t < T_CHOQUE + 0.12:
		for i in 3:
			# Solo las gotas que se desprenden de la punta de la cola continua.
			var previo := t - 0.26 - 0.045 * float(i)
			if previo < T_SUELTA or previo >= T_CHOQUE: continue
			var p: Vector3 = evaluar(previo, oblicuo, radio, horizontal).pos
			var s := radio * (0.10 - float(i) * 0.022)
			_poner(estela.multimesh, n, p, Vector3(s, s * 1.5, s))
			n += 1
	estela.multimesh.visible_instance_count = n
	(estela.material_override as ShaderMaterial).set_shader_parameter("reloj", t)
