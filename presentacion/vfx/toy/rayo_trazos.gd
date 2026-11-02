extends RefCounted

## TRAZOS Y DESTELLOS DEL RAYO «TOY» (2/11/2026, rama claude/b1-hielo-rayo). Se usa con `const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")` (sin class_name, como agua_mallas.gd).
## El rayo no es una malla: es una LÍNEA QUEBRADA que se redibuja cada pocos fotogramas. `camino` saca los puntos (punto medio desplazado al azar, con la desviación nula en los extremos), `trazar` los convierte en
## tramos (con su ancho y su opacidad, hasta una fracción `hasta` del camino: así el rayo «cae» o se extiende en lugar de aparecer entero) y `volcar` los escribe en un MultiMesh (rayo_trazo.gdshader, aditivo) que
## mueve la CPU: no es un GPUParticles3D (no cuenta en el presupuesto de partículas) y se puede medir en las pruebas. Los destellos (rayo_destello.gdshader) son otro MultiMesh, igual.

const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_TRAZO: String = DIR + "rayo_trazo.gdshader"                         ## capa ADITIVA: hilo blanco y halo azul
const SH_TRAZO_CUERPO: String = DIR + "rayo_trazo_cuerpo.gdshader"           ## capa de MEZCLA NORMAL (debajo): el cuerpo amarillo
const SH_DESTELLO: String = DIR + "rayo_destello.gdshader"
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")


## ShaderMaterial del rayo con la textura y la paleta del rayo del juego (rayo_paleta.gd), más `p`.
static func material(shader: String, p: Dictionary = {}, prioridad: int = 0) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prioridad
	m.set_shader_parameter("tex", load(TEX + "T_flare8_vfx.png"))
	var pal: Dictionary = RayoPaleta.uniforms()
	for k in pal:
		m.set_shader_parameter(k, pal[k])
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## Un MultiMesh de `n` quads (trazos o destellos) con su material de rayo. `custom_aabb` enorme: la CPU los mueve por todo el mundo.
static func _crear_mm(nombre: String, n: int, shader: String, p: Dictionary, prioridad: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = maxi(n, 1)
	for i in mm.instance_count:
		ocultar(mm, i)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(shader, p, prioridad)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


static func crear_trazos(nombre: String, n: int, prioridad: int = 1) -> MultiMeshInstance3D:
	var mi: MultiMeshInstance3D = _crear_mm(nombre, n, SH_TRAZO_CUERPO, {}, prioridad)       # primero el cuerpo amarillo (mezcla normal)...
	(mi.material_override as ShaderMaterial).next_pass = material(SH_TRAZO, {}, prioridad)    # ...y encima el hilo blanco y el halo azul (aditivo)
	return mi


static func crear_destellos(nombre: String, n: int, prioridad: int = 2) -> MultiMeshInstance3D:
	return _crear_mm(nombre, n, SH_DESTELLO, {"instancias": 1.0}, prioridad)


static func ocultar(mm: MultiMesh, i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	mm.set_instance_custom_data(i, Color(1, 0, 0, 0))


## Pone el tramo `i` de `a` a `b` (en el espacio del MultiMeshInstance3D): `ancho` en m, `alfa` 0..1, `halo` = grosor del halo (1 tronco, 0,5 rama), `parpadeo` 0..1.
static func poner_trazo(mm: MultiMesh, i: int, a: Vector3, b: Vector3, ancho: float, alfa: float, halo: float = 1.0, parpadeo: float = 0.4, fase: float = 0.0) -> void:
	var v: Vector3 = b - a
	if v.length() < 0.0005 or alfa < 0.001 or ancho <= 0.0:
		ocultar(mm, i)
		return
	var y: Vector3 = v
	var x: Vector3 = v.normalized().cross(Vector3.FORWARD)
	if x.length() < 0.001:
		x = v.normalized().cross(Vector3.RIGHT)
	x = x.normalized() * ancho
	var z: Vector3 = x.normalized().cross(y.normalized()) * ancho
	mm.set_instance_transform(i, Transform3D(Basis(x, y, z), (a + b) * 0.5))
	mm.set_instance_custom_data(i, Color(halo, clampf(alfa, 0.0, 1.0), parpadeo, fase))


## Pone el destello `i` en `pos` con `tam` m, `alfa` 0..1, `estrella` 0..1 (0 = solo halo redondo) y `giro` (rad).
static func poner_destello(mm: MultiMesh, i: int, pos: Vector3, tam: float, alfa: float, estrella: float = 0.8, giro: float = 0.0, fase: float = 0.0) -> void:
	if tam <= 0.0005 or alfa < 0.001:
		ocultar(mm, i)
		return
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(tam, tam, tam)), pos))
	mm.set_instance_custom_data(i, Color(estrella, clampf(alfa, 0.0, 1.0), giro, fase))


## Línea quebrada de `a` a `b` con `n` tramos: punto medio desplazado al azar (hasta `amp` m) en el plano perpendicular, con la desviación nula en los extremos. Devuelve n + 1 puntos.
static func camino(a: Vector3, b: Vector3, n: int, amp: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	var d: Vector3 = (b - a)
	var dn: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.UP
	var p1: Vector3 = dn.cross(Vector3.UP)
	if p1.length() < 0.01:
		p1 = dn.cross(Vector3.RIGHT)
	p1 = p1.normalized()
	var p2: Vector3 = dn.cross(p1).normalized()
	var m: int = maxi(n, 1)
	var sesgo: float = rng.randf_range(-1.0, 1.0)
	for i in m + 1:
		var u: float = float(i) / float(m)
		var env: float = pow(sin(PI * u), 0.6)
		var off: Vector3 = (p1 * (rng.randf_range(-1.0, 1.0) + 0.4 * sesgo) + p2 * rng.randf_range(-1.0, 1.0)) * amp * env
		pts.append(a.lerp(b, u) + off)
	return pts


## Añade a `lista` los tramos del camino `pts` hasta la fracción `hasta` (0..1) de su recorrido (el último tramo se corta). Cada tramo: {a, b, ancho, alfa, halo, parpadeo, fase}. Devuelve los tramos añadidos.
static func trazar(lista: Array, pts: PackedVector3Array, ancho: float, alfa: float, hasta: float = 1.0, halo: float = 1.0, parpadeo: float = 0.4, fase: float = 0.0) -> int:
	var n: int = pts.size() - 1
	var tope: float = clampf(hasta, 0.0, 1.0) * float(n)
	var k: int = 0
	for i in n:
		var u0: float = float(i)
		if tope <= u0:
			break
		var f: float = clampf(tope - u0, 0.0, 1.0)
		var b: Vector3 = pts[i].lerp(pts[i + 1], f)
		lista.append({"a": pts[i], "b": b, "ancho": ancho, "alfa": alfa, "halo": halo, "parpadeo": parpadeo, "fase": fase + float(i) * 0.37})
		k += 1
	return k


## Ramas cortas (`cuantas`) que salen de puntos del camino principal `pts` (no de los extremos), con `n_seg` tramos de `largo` m cada una, hacia un lado al azar y algo hacia delante.
static func ramas(lista: Array, pts: PackedVector3Array, cuantas: int, largo: float, ancho: float, alfa: float, hasta: float, rng: RandomNumberGenerator, n_seg: int = 3) -> int:
	var k: int = 0
	var n: int = pts.size() - 1
	if n < 4:
		return 0
	for r in cuantas:
		var i: int = rng.randi_range(1, n - 2)
		if float(i) / float(n) > hasta:
			continue
		var fw: Vector3 = (pts[i + 1] - pts[i - 1]).normalized()
		var lado: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var dir: Vector3 = (fw * 0.55 + lado * 0.85).normalized()
		var fin: Vector3 = pts[i] + dir * largo * rng.randf_range(0.6, 1.0)
		k += trazar(lista, camino(pts[i], fin, n_seg, largo * 0.35, rng), ancho, alfa, 1.0, 0.5, 0.7, float(r) * 1.9)
	return k


## Escribe `lista` (los tramos) en el MultiMesh `mm`; lo que sobra se oculta. Devuelve cuántos tramos se dibujan (los que caben).
static func volcar(mm: MultiMesh, lista: Array) -> int:
	var n: int = mini(lista.size(), mm.instance_count)
	for i in n:
		var s: Dictionary = lista[i]
		poner_trazo(mm, i, s["a"], s["b"], float(s["ancho"]), float(s["alfa"]), float(s["halo"]), float(s["parpadeo"]), float(s["fase"]))
	for i in range(n, mm.instance_count):
		ocultar(mm, i)
	return n
