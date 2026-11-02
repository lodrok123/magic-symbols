extends "res://herramientas/vfx/montar_efectos_toy.gd"

## MONTAJE DE LAS ESCENAS DE FUEGO «TOY», RONDA 3 (método del tutorial de Le Lu, texturas de assets/vfx/lelu_noise/). De un solo uso: reescribe BolaFuegoToy,
## MuroFuegoToy, PilarFuegoToy y BarreraFuegoToy en presentacion/vfx/toy/ (las de la ronda 2 están guardadas como *_r2.tscn) y el impacto de la ronda 2 se queda.
##   godot --headless --path . --script res://herramientas/vfx/montar_efectos_lelu.gd -- bola muro pilar barrera
## Hereda las piezas (halo, luz, chispas, trocitos, animación) de montar_efectos_toy.gd; aquí solo cambia el cuerpo: mallas de revolución abiertas con
## UV (U alrededor, V = 0 abajo y 1 arriba) y el shader fuego_lelu.

const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_LELU: String = "res://presentacion/vfx/toy/fuego_lelu.gdshader"
const SH_ATRAS: String = "res://presentacion/vfx/toy/fuego_lelu_atras.gdshader"
const SH_DELANTE: String = "res://presentacion/vfx/toy/fuego_lelu_delante.gdshader"

var _rampa_fuego: GradientTexture1D = null
var _rampa_azul: GradientTexture1D = null
var _meshes: Dictionary = {}


func _rampa(colores: Array, offsets: Array) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	var cs: PackedColorArray = PackedColorArray()
	for c in colores:
		cs.append(c)
	g.colors = cs
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


func _rampas() -> void:
	if _rampa_fuego != null:
		return
	# borde rojo-anaranjado -> naranja saturado -> amarillo -> blanco crema solo en el núcleo
	_rampa_fuego = _rampa([Color(0.85, 0.12, 0.03), Color(1.0, 0.32, 0.03), Color(1.0, 0.52, 0.08), Color(1.0, 0.74, 0.2), Color(1.0, 0.93, 0.62)], [0.0, 0.22, 0.62, 0.9, 1.0])
	_rampa_azul = _rampa([Color(0.05, 0.2, 0.85), Color(0.15, 0.4, 1.0), Color(0.3, 0.65, 1.0), Color(0.55, 0.85, 1.0), Color(0.9, 0.98, 1.0)], [0.0, 0.22, 0.62, 0.9, 1.0])


## Interpola unas claves (V, radio, y) en `n` anillos con curva suave.
func _anillos(claves: Array, n: int) -> Array:
	var r: Array = []
	for i in n:
		var v: float = float(i) / float(n - 1)
		var k: int = 0
		while k < claves.size() - 2 and v > (claves[k + 1] as Vector3).x:
			k += 1
		var a: Vector3 = claves[k]
		var b: Vector3 = claves[k + 1]
		var u: float = clampf((v - a.x) / maxf(b.x - a.x, 0.0001), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		r.append(Vector3(v, lerpf(a.y, b.y, u), lerpf(a.z, b.z, u)))
	return r


## Malla de revolución ABIERTA (sin tapas): U = vuelta (0 a 1), V = 0 abajo y 1 arriba. `esfera`: las normales apuntan desde el centro (si no, radiales).
func _malla(anillos: Array, seg: int, esfera: bool = false, centro_y: float = 0.0) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in anillos:
		for i in seg + 1:
			var u: float = float(i) / float(seg)
			var ang: float = u * TAU
			var p: Vector3 = Vector3(cos(ang) * a.y, a.z, sin(ang) * a.y)
			var nor: Vector3 = (p - Vector3(0, centro_y, 0)).normalized() if esfera else Vector3(cos(ang), 0, sin(ang))
			st.set_uv(Vector2(u, a.x))
			st.set_normal(nor)
			st.add_vertex(p)
	for j in anillos.size() - 1:
		for i in seg:
			var a0: int = j * (seg + 1) + i
			var a1: int = a0 + 1
			var b0: int = a0 + seg + 1
			var b1: int = b0 + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(b1)
	return st.commit()


func _cilindro(r_base: float, r_alto: float, alto: float, y0: float = 0.0, seg: int = 32) -> ArrayMesh:
	var clave: String = "c%s_%s_%s_%s" % [r_base, r_alto, alto, y0]
	if not _meshes.has(clave):
		_meshes[clave] = _malla(_anillos([Vector3(0, r_base, y0), Vector3(0.6, lerpf(r_base, r_alto, 0.6), y0 + alto * 0.6), Vector3(1, r_alto, y0 + alto)], 14), seg)
	return _meshes[clave]


func _mat_fuego(shader: String, p: Dictionary, prio: int = 0) -> ShaderMaterial:
	_rampas()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prio
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	m.set_shader_parameter("ruido_a", load(TEX + "T_PerlinNoise_Tiled.png"))
	m.set_shader_parameter("ruido_v", load(TEX + "T_CloudNoise_Tiled.png"))
	m.set_shader_parameter("ruido_fino", load(TEX + "T_Noise1_tiled.png"))
	m.set_shader_parameter("rampa", _rampa_fuego)
	m.set_shader_parameter("rampa_azul", _rampa_azul)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## Malla de revolución con sección RECTANGULAR REDONDEADA (superelipse de semiejes a × b y exponente n), abierta arriba y abajo. U sigue la longitud del contorno
## (así la textura no se estira en los lados largos); `vueltas` es el nº de repeticiones de la textura que caben (tiene que ser entero para que cierre la costura).
func _malla_lazo(a: float, b: float, alto: float, s_alto: float, n: float = 6.0, seg: int = 120) -> ArrayMesh:
	var pts: Array = []
	var acum: Array = [0.0]
	for i in seg + 1:
		var t: float = TAU * float(i) / float(seg)
		var c: float = cos(t)
		var s: float = sin(t)
		pts.append(Vector2(a * signf(c) * pow(absf(c), 2.0 / n), b * signf(s) * pow(absf(s), 2.0 / n)))
		if i > 0:
			acum.append(float(acum[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
	var total: float = acum[seg]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: int = 14
	for j in anillos:
		var v: float = float(j) / float(anillos - 1)
		var esc: float = lerpf(1.0, s_alto, v)
		for i in seg + 1:
			var p: Vector2 = pts[i]
			st.set_uv(Vector2(float(acum[i]) / total, v))
			st.set_normal(Vector3(p.x / (a * a), 0, p.y / (b * b)).normalized())
			st.add_vertex(Vector3(p.x * esc, v * alto, p.y * esc))
	for j in anillos - 1:
		for i in seg:
			var a0: int = j * (seg + 1) + i
			var b0: int = a0 + seg + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


func _fuego(padre: Node, nombre: String, malla: Mesh, pos: Vector3, p: Dictionary, prio: int = 0, escala: Vector3 = Vector3.ONE, shader: String = SH_LELU) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.material_override = _mat_fuego(shader, p, prio)
	mi.position = pos
	mi.scale = escala
	mi.extra_cull_margin = 0.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


## Partículas de la bola EN VUELO (ronda 7): jirones de llama que se sueltan por detrás y chispas con estela larga y fina y cabeza en estrella de cuatro puntas.
## Solo emiten con `proyectil` activo (grupo `vuelo`); quedan en el mundo (local_coords falso) y se quedan atrás de la bola.
func _vuelo(c: Node3D) -> void:
	_rampas()
	var jir: GPUParticles3D = _particulas_vuelo(c, "Jirones", 5, 0.45, Vector3(0.12, 0.12, 0.05), Vector2(1.0, 2.0), 30.0, Vector2(0.28, 0.55),
		[Color(1.0, 0.55, 0.12, 0.95), Color(0.95, 0.28, 0.06, 0.7), Color(0.8, 0.12, 0.03, 0.0)], QuadMesh.new(), "res://presentacion/vfx/toy/jiron_toy.gdshader", Vector2(1.0, 1.0))
	var q: QuadMesh = QuadMesh.new()
	var ch: GPUParticles3D = _particulas_vuelo(c, "ChispasEstela", 6, 0.7, Vector3(0.28, 0.28, 0.05), Vector2(0.5, 1.4), 38.0, Vector2(0.5, 1.2),
		[Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(1.0, 0.35, 0.08, 0.0)], q, "res://presentacion/vfx/toy/chispa_toy.gdshader", Vector2(0.05, 1.0))
	# cabeza en estrella de cuatro puntas (segunda pasada de dibujo de las mismas partículas)
	var cab: QuadMesh = QuadMesh.new()
	cab.size = Vector2(0.26, 0.26)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	cab.material = sm
	ch.draw_passes = 2
	ch.draw_pass_2 = cab


func _particulas_vuelo(c: Node3D, nombre: String, cantidad: int, vida_s: float, caja: Vector3, vel: Vector2, abierto: float, escala: Vector2, colores: Array,
		malla: QuadMesh, shader: String, tam: Vector2) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.local_coords = false
	gp.emitting = false
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3(0, 0, 1)
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3.ZERO
	pm.scale_min = escala.x
	pm.scale_max = escala.y
	var g: Gradient = Gradient.new()
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for i in colores.size():
		offs.append(float(i) / float(maxi(colores.size() - 1, 1)))
		cols.append(colores[i])
	g.offsets = offs
	g.colors = cols
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	malla.size = tam if tam.y > 0.0 else Vector2(0.3, 0.3)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	malla.material = m
	gp.draw_pass_1 = malla
	gp.add_to_group("vuelo", true)
	c.add_child(gp)
	return gp


## Bola (ronda 6): un QUAD con billboard y el shader fuego_lelu_bola (método de Le Lu en 2D con gradiente radial): una sola silueta de gota, sin malla 3D (sin polos, facetas ni tapas).
## En modo proyectil el eje de la llama se alinea con la velocidad y se alarga hacia atrás (la estela); ver EfectoToy.
func _bola() -> Node3D:
	var r: Node3D = _raiz("BolaFuegoToy")
	r.set("tam_referencia", Vector3(0.8, 0.8, 0.8))
	r.set("escena_impacto", load(DIR + "ImpactoBolaToy.tscn") if ResourceLoader.exists(DIR + "ImpactoBolaToy.tscn") else null)
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Halo", 2.0, Vector3(0, 0.05, 0), 0.3, 3.0)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Llama"
	mi.mesh = q
	mi.material_override = _mat_fuego("res://presentacion/vfx/toy/fuego_lelu_bola.gdshader", {"semilla": 0.3}, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	# ronda 7: FRENTE = cabeza redonda y brillante (blanco -> amarillo -> naranja fino) + halo muy brillante + destello de 4 puntas; en vuelo se adelanta por -Z
	var fr: Node3D = Node3D.new()
	fr.name = "Frente"
	c.add_child(fr)
	_halo(fr, "Destello", 0.8, Vector3(0, 0.0, 0), 0.9, 2.4, 2, Color(1.0, 0.7, 0.35), {"latido": 0.12})
	var cab: MeshInstance3D = MeshInstance3D.new()
	cab.name = "Cabeza"
	var cq: QuadMesh = QuadMesh.new()
	cq.size = Vector2(1.0, 1.0)
	cab.mesh = cq
	var cm: ShaderMaterial = ShaderMaterial.new()
	cm.shader = load("res://presentacion/vfx/toy/cabeza_toy.gdshader")
	cm.render_priority = 2
	cm.set_shader_parameter("ruido", load(TEX + "T_PerlinNoise_Tiled.png"))
	cm.set_shader_parameter("radio", 0.22)
	cab.material_override = cm
	cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(cab)
	var flare: MeshInstance3D = MeshInstance3D.new()
	flare.name = "Estrella"
	var fq: QuadMesh = QuadMesh.new()
	fq.size = Vector2(1.05, 1.05)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	fm.albedo_color = Color(1.0, 0.92, 0.75, 0.85)
	fm.render_priority = 3
	fq.material = fm
	flare.mesh = fq
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(flare)
	_vuelo(c)
	_trocitos(c, 2, Vector3(0.1, 0.05, 0.1), Vector3(0, 0.55, 0))
	_luz(r, Vector3(0, 0, 0), 1.1, 4.5)
	_particulas(c, "Chispas", 8, 1.3, 0.07, Vector3(0.2, 0.15, 0.2), Vector2(0.3, 0.8), Vector3(0, 1, 0), 40.0, Vector3(0, 0.35, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.62, 0.22, 1.0), Color(1.0, 0.55, 0.15, 0.0)])
	_anim(r)
	return r


## Muro: siete cilindros (escala X 1,3 → elipses) solapados a lo largo de 6,9 m, cada uno con su desfase de UV y su velocidad, más siete interiores más pequeños y calientes.
func _muro() -> Node3D:
	var r: Node3D = _raiz("MuroFuegoToy")
	r.set("tam_referencia", Vector3(6.9, 1.5, 0.3))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Charco", 7.6, Vector3(0, 0.04, 0), 0.5, 1.6, 0, Color(1.0, 0.28, 0.06), {"latido": 0.05}, 2.4)
	_halo(c, "Resplandor", 7.2, Vector3(0, 0.55, 0), 0.22, 2.6, 2, Color(1.0, 0.28, 0.06), {}, 2.2)
	# ronda 4: una sola malla con sección rectangular redondeada (6,9 x 0,6 m): la banda es continua y las lenguas salen del rectángulo entero, sin aros ni huecos.
	var banda: ArrayMesh = _malla_lazo(3.45, 0.3, 1.5, 0.78)
	var banda_in: ArrayMesh = _malla_lazo(3.3, 0.12, 1.05, 0.7)
	_fuego(c, "Banda", banda, Vector3.ZERO, {"repeticion": Vector2(5.0, 0.9), "rep_ruido": Vector2(6.0, 1.6), "semilla": 0.05, "velocidad": 1.0, "umbral": 0.27, "desfase": 0.45, "fuerza_grad": 1.05}, 0)
	_fuego(c, "Interior", banda_in, Vector3.ZERO, {"repeticion": Vector2(6.0, 0.9), "rep_ruido": Vector2(7.0, 1.6), "semilla": 0.4, "velocidad": 1.5, "umbral": 0.27, "desfase": 0.45, "fuerza_grad": 1.0,
		"calor_extra": 0.3, "brillo": 1.1}, 1)
	_trocitos(c, 3, Vector3(3.0, 0.05, 0.15), Vector3(0, 1.0, 0))
	_luz(r, Vector3(0, 0.7, 0), 1.6, 6.5)
	_particulas(c, "Chispas", 14, 1.4, 0.07, Vector3(3.2, 0.1, 0.2), Vector2(0.3, 0.9), Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.5, 0))
	_anim(r)
	return r


## Pilar: cilindro exterior de r 0,5 y 4 m y otro interior más estrecho y brillante, a dos velocidades, con el anillo de luz en el suelo.
func _pilar() -> Node3D:
	var r: Node3D = _raiz("PilarFuegoToy")
	r.set("tam_referencia", Vector3(1.0, 4.0, 1.0))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Charco", 2.6, Vector3(0, 0.04, 0), 0.45, 1.8, 0, Color(1.0, 0.28, 0.06), {"anillo": 0.5})
	_halo(c, "Resplandor", 3.4, Vector3(0, 1.4, 0), 0.2, 2.8, 2, Color(1.0, 0.28, 0.06), {}, 4.2)
	_fuego(c, "Exterior", _cilindro(0.5, 0.36, 4.0), Vector3.ZERO, {"repeticion": Vector2(1.0, 1.6), "rep_ruido": Vector2(2.0, 2.0), "umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0,
		"pot_grad": 1.6, "semilla": 0.2, "velocidad": 0.9, "amplitud_vert": 0.2}, 0)
	_fuego(c, "Nucleo", _cilindro(0.3, 0.16, 3.1), Vector3.ZERO, {"repeticion": Vector2(1.0, 1.4), "rep_ruido": Vector2(2.0, 2.0), "umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0,
		"pot_grad": 1.6, "semilla": 0.6, "velocidad": 1.5, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.12}, 1)
	_trocitos(c, 3, Vector3(0.3, 0.1, 0.3), Vector3(0, 3.0, 0))
	_luz(r, Vector3(0, 1.3, 0), 2.0, 7.0)
	_particulas(c, "Chispas", 16, 1.8, 0.07, Vector3(0.3, 0.1, 0.3), Vector2(0.6, 1.5), Vector3(0, 1, 0), 20.0, Vector3(0, 0.5, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.3, 0))
	_anim(r, 0.4, 0.6)
	return r


## Barrera: esfera de r 1,5 m con el mismo shader (UV esférica: las lenguas suben por los meridianos y giran), sin cilindro. Dos pasadas (atrás y delante).
func _barrera() -> Node3D:
	var r: Node3D = _raiz("BarreraFuegoToy")
	r.set("tam_referencia", Vector3(3.0, 3.0, 3.0))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Anillo", 3.9, Vector3(0, 0.03, 0), 0.8, 1.0, 0, Color(1.0, 0.28, 0.06), {"anillo": 1.0, "latido": 0.04})
	var anillos: Array = []
	for i in 25:
		var v: float = float(i) / 24.0
		anillos.append(Vector3(v, 1.5 * sin(PI * v), -1.5 * cos(PI * v)))
	var esfera: ArrayMesh = _malla(anillos, 48, true, 0.0)
	var p: Dictionary = {"repeticion": Vector2(3.0, 1.4), "rep_ruido": Vector2(5.0, 2.0), "v_base": 0.3, "umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.15, "pot_grad": 1.1,
		"giro": 0.25, "resplandor_borde": 0.45, "escala_rampa": 1.3, "calor_extra": 0.05, "amplitud_vert": 0.1, "velocidad": 1.0, "transparencia": 0.92}
	var mi: MeshInstance3D = _fuego(c, "Cascara", esfera, Vector3(0, 0.6, 0), p, 0, Vector3.ONE, SH_ATRAS)
	var delante: ShaderMaterial = _mat_fuego(SH_DELANTE, p, 1)
	(mi.material_override as ShaderMaterial).next_pass = delante
	_trocitos(c, 3, Vector3(1.0, 0.1, 1.0), Vector3(0, 1.8, 0))
	_luz(r, Vector3(0, 0.7, 0), 1.5, 5.5)
	_particulas(c, "Chispas", 14, 1.6, 0.07, Vector3(1.2, 0.1, 1.2), Vector2(0.3, 0.9), Vector3(0, 1, 0), 25.0, Vector3(0, 0.5, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.2, 0))
	_anim(r, 0.5, 0.6)
	return r
