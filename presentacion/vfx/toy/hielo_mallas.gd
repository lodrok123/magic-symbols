extends RefCounted

## GEOMETRÍA DEL HIELO «TOY» (2/11/2026, rama claude/b1-hielo-rayo). Se usa con `const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")` (sin class_name, como agua_mallas.gd).
## Todo son facetas PLANAS (una normal por cara): un cristal es un prisma de 6 lados con la punta de pirámide, una esquirla es un tetraedro alargado, el bloque de la bola es una icosfera de 80 caras
## con los vértices movidos un poco. Reutiliza FuegoToyMallas para lo que ya existe (perímetro de la elipse, haz) y las texturas de assets/vfx/lelu_noise/ (uso libre).
## También reparte los cristales de cada figura (`capa_*`: listas de diccionarios, deterministas con la semilla, para poder medirlas en las pruebas).

const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_CRISTAL: String = DIR + "hielo_cristal.gdshader"
const SH_ESCARCHA: String = DIR + "hielo_escarcha.gdshader"
const SH_DESTELLO: String = DIR + "hielo_destello.gdshader"
const HieloPaleta = preload("res://presentacion/vfx/toy/hielo_paleta.gd")

const PUNTA: float = 0.28                  ## fracción del alto que ocupa la pirámide de la punta
const MAX_CRISTALES: int = 64              ## tope de cristales de una figura (presupuesto de partículas)


## ShaderMaterial del hielo con las texturas y la paleta del hielo del mundo (hielo_paleta.gd), más `p`.
static func material(shader: String, p: Dictionary = {}, prioridad: int = 0) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prioridad
	m.set_shader_parameter("grietas", load(TEX + "T_Cracks336.png"))
	m.set_shader_parameter("ruido", load(TEX + "T_Noise_Wf4.png"))
	m.set_shader_parameter("tex", load(TEX + "T_VFX_hit22.jpg"))
	var pal: Dictionary = HieloPaleta.uniforms()
	for k in pal:
		m.set_shader_parameter(k, pal[k])
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


static func _hash(a: float) -> float:
	return fposmod(sin(a * 12.9898) * 43758.5453, 1.0)


## Un triángulo plano con su normal hacia fuera de `centro`. uv = [a, b, c] (Vector2); altura = COLOR.r de cada vértice (0..1).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centro: Vector3, uv: Array, ha: float, hb: float, hc: float) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centro) < 0.0:
		n = -n
	var vs: Array = [a, b, c]
	var hs: Array = [ha, hb, hc]
	for i in 3:
		st.set_normal(n)
		st.set_color(Color(float(hs[i]), 0.0, 0.0, 1.0))
		st.set_uv(uv[i])
		st.add_vertex(vs[i])


## Cristal unidad: prisma de `lados` lados de radio 1 en la base y 0,92 en el hombro, alto 1, punta de pirámide (PUNTA del alto) algo torcida. Base en y = 0 (sin tapa: no se ve).
static func cristal(lados: int = 6, semilla: float = 1.0) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yh: float = 1.0 - PUNTA
	var base: Array = []
	var hombro: Array = []
	for i in lados:
		var a: float = TAU * float(i) / float(lados)
		var rb: float = 1.0 + 0.07 * (_hash(semilla * 3.1 + float(i)) - 0.5)
		base.append(Vector3(cos(a) * rb, 0.0, sin(a) * rb))
		var rs: float = 0.92 + 0.06 * (_hash(semilla * 7.7 + float(i)) - 0.5)
		hombro.append(Vector3(cos(a) * rs, yh, sin(a) * rs))
	var punta: Vector3 = Vector3(0.10 * (_hash(semilla) - 0.5), 1.0, 0.10 * (_hash(semilla + 4.0) - 0.5))
	var centro: Vector3 = Vector3(0, 0.5, 0)
	for i in lados:
		var j: int = (i + 1) % lados
		var b0: Vector3 = base[i]
		var b1: Vector3 = base[j]
		var s0: Vector3 = hombro[i]
		var s1: Vector3 = hombro[j]
		_tri(st, b0, b1, s1, centro, [Vector2(0, 0), Vector2(1, 0), Vector2(1, yh)], 0.0, 0.0, yh)
		_tri(st, b0, s1, s0, centro, [Vector2(0, 0), Vector2(1, yh), Vector2(0, yh)], 0.0, yh, yh)
		_tri(st, s0, s1, punta, centro, [Vector2(0, yh), Vector2(1, yh), Vector2(0.5, 1)], yh, yh, 1.0)
	return st.commit()


## Esquirla unidad: tetraedro alargado (punta arriba en y = 1, base en y = -0,35, radio 0,5).
static func esquirla() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p: Vector3 = Vector3(0.05, 1.0, 0.0)
	var q: Array = []
	for i in 3:
		var a: float = TAU * float(i) / 3.0 + 0.4
		q.append(Vector3(cos(a) * 0.5, -0.35, sin(a) * 0.5))
	var c: Vector3 = Vector3(0, 0.2, 0)
	for i in 3:
		var j: int = (i + 1) % 3
		_tri(st, q[i], q[j], p, c, [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)], 0.0, 0.0, 1.0)
	_tri(st, q[0], q[1], q[2], c, [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)], 0.0, 0.0, 0.0)
	return st.commit()


## Icosfera de radio 1 con 80 caras planas y los vértices movidos ±`rugosidad` (un bloque de hielo, no una pelota).
static func bloque(rugosidad: float = 0.09, semilla: float = 1.0) -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = (v[i] as Vector3).normalized()
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in f:
		var a: Vector3 = v[tri[0]]
		var b: Vector3 = v[tri[1]]
		var c: Vector3 = v[tri[2]]
		var ab: Vector3 = ((a + b) * 0.5).normalized()
		var bc: Vector3 = ((b + c) * 0.5).normalized()
		var ca: Vector3 = ((c + a) * 0.5).normalized()
		for q in [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]:
			var p: Array = []
			for w in q:
				var d: Vector3 = w
				var k: float = 1.0 + rugosidad * (_hash(d.x * 91.7 + d.y * 37.3 + d.z * 17.1 + semilla) - 0.5) * 2.0
				p.append(d * k)
			_tri(st, p[0], p[1], p[2], Vector3.ZERO, [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)], (p[0].y + 1.0) * 0.5, (p[1].y + 1.0) * 0.5, (p[2].y + 1.0) * 0.5)
	return st.commit()


## MultiMesh de `n` cristales (o esquirlas: `malla`) con el material del hielo para instancias. Lo mueve la CPU con `poner`.
static func crear_mm(nombre: String, n: int, malla: Mesh, opacidad: float = 0.62, prioridad: int = 0) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = maxi(n, 1)
	for i in mm.instance_count:
		ocultar(mm, i)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(SH_CRISTAL, {"instancias": 1.0, "opacidad": opacidad}, prioridad)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


static func ocultar(mm: MultiMesh, i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	mm.set_instance_custom_data(i, Color(0, 0, 0, 0))


## Pone la instancia `i`: base en `pos`, orientación `rot`, tamaño (radio x, alto, radio z).
static func poner(mm: MultiMesh, i: int, pos: Vector3, rot: Basis, ancho_x: float, alto: float, ancho_z: float, claridad: float, alfa: float, fase: float) -> Transform3D:
	var vivo: bool = alto > 0.0005 and ancho_x > 0.0005 and alfa > 0.001
	var tr: Transform3D = Transform3D(rot * Basis.from_scale(Vector3(ancho_x, alto, ancho_z)), pos) if vivo else Transform3D(Basis.from_scale(Vector3.ZERO), pos)
	mm.set_instance_transform(i, tr)
	mm.set_instance_custom_data(i, Color(clampf(claridad, 0.0, 1.0), clampf(alfa, 0.0, 1.0) if vivo else 0.0, 0.0, fase))
	return tr


## Quad tumbado de escarcha (FACE_Y, 1 m) con su material.
static func escarcha(nombre: String, opacidad: float = 0.7, semilla: float = 0.0) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = q
	mi.material_override = material(SH_ESCARCHA, {"u": 0.0, "vida": 1.0, "opacidad": opacidad, "semilla": semilla}, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Quad billboard del destello (el tamaño, con la escala del nodo).
static func destello(nombre: String) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = q
	mi.material_override = material(SH_DESTELLO, {"vida": 0.0}, 3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.001
	return mi


# ------------------------------------------------------------------ reparto de los cristales de cada figura ------------------------------------------------------------------
## Cada cristal: {pos, rot (Basis), wx, h, wz, retraso (0..0.15, cuándo empieza a crecer), rompe (0..0.6, cuándo se rompe al morir), esq (esquirlas que suelta), claro, fase}.

static func _c(pos: Vector3, rot: Basis, wx: float, h: float, wz: float, retraso: float, rng: RandomNumberGenerator, esq: int) -> Dictionary:
	return {"pos": pos, "rot": rot, "wx": wx, "h": h, "wz": wz, "retraso": retraso, "rompe": rng.randf_range(0.0, 0.55), "esq": esq, "claro": rng.randf(), "fase": rng.randf()}


## Base que inclina el eje Y hacia `d` (horizontal, unitaria) `ang` rad, después girada `yaw` sobre Y.
static func _inclinar(d: Vector3, ang: float, yaw: float) -> Basis:
	var eje: Vector3 = Vector3(d.z, 0.0, -d.x)
	var b: Basis = Basis(Vector3.UP, yaw)
	if eje.length() > 0.001 and absf(ang) > 0.0001:
		b = Basis(eje.normalized(), ang) * b
	return b


## PILAR: una espiga central alta, dos medianas pegadas y una corona de cristales más bajos y torcidos hacia fuera.
static func capa_pilar(rx: float, rz: float, alto: float, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 11
	var res: Array = []
	var rm: float = (rx + rz) * 0.5
	res.append(_c(Vector3.ZERO, Basis(Vector3.UP, rng.randf() * TAU), rx * 0.9, alto, rz * 0.9, 0.0, rng, 4))
	for k in 2:
		var a: float = rng.randf() * TAU + float(k) * PI
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		res.append(_c(Vector3(d.x * rx * 0.62, 0.0, d.z * rz * 0.62), _inclinar(d, rng.randf_range(0.05, 0.16), rng.randf() * TAU), rx * 0.5, alto * (0.62 - 0.14 * float(k)), rz * 0.5, 0.03 + 0.03 * float(k), rng, 3))
	var perim: float = FuegoToyMallas.perimetro_elipse(rx, rz)
	var n: int = clampi(int(round(perim / 0.85)), 6, 14)
	for i in n:
		var a2: float = TAU * float(i) / float(n) + rng.randf_range(-0.2, 0.2)
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		var rk: float = rng.randf_range(1.0, 1.3)
		var w: float = clampf(rm * 0.4, 0.09, 0.4) * rng.randf_range(0.7, 1.2)
		var hh: float = alto * rng.randf_range(0.2, 0.46)
		res.append(_c(Vector3(d2.x * rx * rk, 0.0, d2.z * rz * rk), _inclinar(d2, rng.randf_range(0.2, 0.5), rng.randf() * TAU), w, hh, w, rng.randf_range(0.0, 0.1), rng, 2))
	return res


## MURO: dos filas de cristales a lo largo de x (la de delante más baja), más altos hacia el centro.
static func capa_muro(a: float, b: float, alto: float, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 23
	var res: Array = []
	var por_fila: int = clampi(int(round(2.0 * a / 0.55)), 4, MAX_CRISTALES / 2)
	var w: float = clampf(b * 0.9 + 0.12, 0.14, 0.5)
	for fila in 2:
		for i in por_fila:
			var f: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(por_fila)
			var x: float = lerpf(-a * 0.97, a * 0.97, f)
			var env: float = 1.0 - 0.3 * pow(absf(x) / a, 3.0)
			var hh: float = alto * rng.randf_range(0.5, 1.0) * env * (1.0 if fila == 0 else 0.62)
			var z: float = (-0.5 if fila == 1 else 0.35) * b + rng.randf_range(-0.15, 0.15) * b
			var d: Vector3 = Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
			var ww: float = w * rng.randf_range(0.7, 1.2) * (1.0 if fila == 0 else 0.8)
			res.append(_c(Vector3(x, 0.0, z), _inclinar(d, rng.randf_range(0.03, 0.2), rng.randf() * TAU), ww, hh, ww, rng.randf_range(0.0, 0.12), rng, 2 if hh > alto * 0.6 else 1))
	return res


## BARRERA: una jaula de cristales sobre la elipse del suelo, inclinados hacia dentro hasta casi cerrarse arriba; un segundo anillo más bajo y más cerrado.
static func capa_barrera(x: float, y: float, z: float, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 37
	var res: Array = []
	var perim: float = FuegoToyMallas.perimetro_elipse(x, z)
	var n: int = clampi(int(round(perim / 0.75)), 8, 22)
	var rm: float = (x + z) * 0.5
	for i in n:
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var w: float = clampf(rm * 0.13, 0.1, 0.32) * rng.randf_range(0.8, 1.2)
		var hh: float = y * rng.randf_range(0.95, 1.25)
		res.append(_c(Vector3(d.x * x * 0.94, 0.0, d.z * z * 0.94), _inclinar(-d, rng.randf_range(0.42, 0.62), rng.randf() * TAU), w, hh, w, rng.randf_range(0.0, 0.1), rng, 2))
	var n2: int = maxi(n / 2, 4)
	for i in n2:
		var a2: float = TAU * (float(i) + 0.5) / float(n2)
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		var w2: float = clampf(rm * 0.09, 0.07, 0.22)
		res.append(_c(Vector3(d2.x * x * 0.6, 0.0, d2.z * z * 0.6), _inclinar(-d2, rng.randf_range(0.25, 0.4), rng.randf() * TAU), w2, y * rng.randf_range(0.55, 0.8), w2, rng.randf_range(0.04, 0.14), rng, 1))
	return res


## HAZ: una lanza larga que sale del origen hacia -Z y, a lo largo, cristales-púa que apuntan hacia delante y a los lados. `retraso` crece con la distancia: salen detrás de la punta.
static func capa_haz(largo: float, radio: float, alto_eje: float, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 41
	var res: Array = []
	var eje: Basis = Basis(Vector3.RIGHT, -PI * 0.5)          # el eje Y del cristal pasa a -Z
	var w: float = maxf(radio * 0.32, 0.05)
	res.append(_c(Vector3(0, alto_eje, 0), eje, w, largo, w, 0.0, rng, 6))
	var n: int = clampi(int(round(largo / 0.36)), 4, 16)
	for i in n:
		var f: float = (float(i) + rng.randf_range(0.2, 0.8)) / float(n)
		var lado: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 1.0), 0.0).normalized()
		var dd: Vector3 = (lado * sin(0.75) + Vector3(0, 0, -1) * cos(0.75)).normalized()
		var ww: float = w * rng.randf_range(0.35, 0.6)
		res.append(_c(Vector3(lado.x * w * 0.5, alto_eje + lado.y * w * 0.5, -f * largo * 0.96), Basis(Quaternion(Vector3.UP, dd)), ww, radio * rng.randf_range(1.4, 2.4) * (1.1 - 0.5 * f), ww, f * 0.55, rng, 1))
	return res


## BOLA: púas de cristal repartidas por la esfera (fibonacci), apuntando hacia fuera.
static func puas_bola(r: float, n: int = 7, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 53
	var res: Array = []
	for i in n:
		var yy: float = 1.0 - 2.0 * (float(i) + 0.5) / float(n)
		var rr: float = sqrt(maxf(1.0 - yy * yy, 0.0))
		var ph: float = float(i) * 2.399963 + rng.randf() * 0.4
		var d: Vector3 = Vector3(cos(ph) * rr, yy, sin(ph) * rr)
		var w: float = r * rng.randf_range(0.2, 0.3)
		res.append(_c(d * r * 0.78, Basis(Quaternion(Vector3.UP, d)), w, r * rng.randf_range(0.55, 0.95), w, 0.0, rng, 1))
	return res


## Estela de la bola en vuelo: cristales largos y finos que apuntan hacia atrás (+Z), algo abiertos.
static func estela_bola(r: float, n: int = 4, semilla: float = 1.0) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(semilla * 1000.0) + 67
	var res: Array = []
	for i in n:
		var lado: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.8, 0.8), 0.0).normalized() * rng.randf_range(0.12, 0.4)
		var dd: Vector3 = (Vector3(0, 0, 1) + lado).normalized()
		var w: float = r * rng.randf_range(0.14, 0.24)
		res.append(_c(Vector3(lado.x * r, lado.y * r, r * 0.7), Basis(Quaternion(Vector3.UP, dd)), w, r * rng.randf_range(1.7, 3.0), w, 0.0, rng, 0))
	return res
