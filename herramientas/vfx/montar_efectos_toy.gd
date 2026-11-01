extends SceneTree

## MONTAJE DE LAS ESCENAS DE FUEGO «TOY» (prueba 3 de VFX, 1/11/2026). De un solo uso: escribe las .tscn de presentacion/vfx/toy/ y después se editan en el editor.
##   godot --headless --path . --script res://herramientas/vfx/montar_efectos_toy.gd -- bola muro pilar barrera impacto   (sin argumentos: todas)
## Nada de lo que hay aquí corre en el juego: el aspecto lo llevan los shaders (llama_toy, halo_toy, barrera_toy) y EfectoToy.

const DIR: String = "res://presentacion/vfx/toy/"
const SH_LLAMA: String = "res://presentacion/vfx/toy/llama_toy.gdshader"
const SH_HALO: String = "res://presentacion/vfx/toy/halo_toy.gdshader"
const SH_BARRERA: String = "res://presentacion/vfx/toy/barrera_toy.gdshader"
const EFECTO_TOY: String = "res://presentacion/vfx/toy/efecto_toy.gd"

var _blob: GradientTexture2D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var todo: bool = a.is_empty()
	if todo or "impacto" in a:
		_guardar(_impacto(), "ImpactoBolaToy.tscn")
	if todo or "bola" in a:
		_guardar(_bola(), "BolaFuegoToy.tscn")
	if todo or "muro" in a:
		_guardar(_muro(), "MuroFuegoToy.tscn")
	if todo or "pilar" in a:
		_guardar(_pilar(), "PilarFuegoToy.tscn")
	if todo or "barrera" in a:
		_guardar(_barrera(), "BarreraFuegoToy.tscn")
	quit()


# ---------------------------------------------------------------- ladrillos ----------------------------------------------------------------

func _raiz(nombre: String) -> Node3D:
	var r: Node3D = Node3D.new()
	r.name = nombre
	r.set_script(load(EFECTO_TOY))
	var c: Node3D = Node3D.new()
	c.name = "Cuerpo"
	r.add_child(c)
	return r


func _mat_llama(p: Dictionary, prioridad: int = 0) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_LLAMA)
	m.render_priority = prioridad
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


func _llama(padre: Node, nombre: String, tam: Vector2, pos: Vector3, p: Dictionary, prioridad: int = 0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = tam
	q.center_offset = Vector3(0, tam.y * 0.5, 0)
	mi.mesh = q
	p["tam"] = tam
	mi.material_override = _mat_llama(p, prioridad)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


func _halo(padre: Node, nombre: String, lado: float, pos: Vector3, brillo: float, caida: float, billboard: int = 2, color: Color = Color(1.0, 0.28, 0.06), extra: Dictionary = {}, alto: float = -1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(lado, lado if alto < 0.0 else alto)
	if billboard == 0:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HALO)
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("caida", caida)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("semilla", randf())
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	m.render_priority = -1
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


func _luz(raiz: Node, pos: Vector3, energia: float, rango: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "Luz"
	l.position = pos
	l.light_color = Color(1.0, 0.5, 0.22)
	l.light_energy = energia
	l.omni_range = rango
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	raiz.add_child(l)
	return l


func _textura_blanda() -> GradientTexture2D:
	if _blob != null:
		return _blob
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_blob = GradientTexture2D.new()
	_blob.gradient = g
	_blob.fill = GradientTexture2D.FILL_RADIAL
	_blob.fill_from = Vector2(0.5, 0.5)
	_blob.fill_to = Vector2(1.0, 0.5)
	_blob.width = 64
	_blob.height = 64
	return _blob


## Partículas blandas y pequeñas. `rampa`: colores de nacer a morir (el alfa baja a 0 al final).
func _particulas(padre: Node, nombre: String, cantidad: int, vida_s: float, tam: float, caja: Vector3, vel: Vector2, dir: Vector3, abierto: float,
		gravedad: Vector3, colores: Array, grupo: String = "chispas", una_vez: bool = false, explosivo: float = 0.0, local: bool = true,
		pos: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.position = pos
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.one_shot = una_vez
	gp.explosiveness = explosivo
	gp.local_coords = local
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 12, 12))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = dir
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravedad
	pm.scale_min = 0.7
	pm.scale_max = 1.2
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
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.0))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1, 0.15))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _textura_blanda()
	sm.disable_receive_shadows = true
	q.material = sm
	gp.draw_pass_1 = q
	gp.add_to_group(grupo, true)
	padre.add_child(gp)
	return gp


## Trocitos de llama que se desprenden de las puntas: 2-6 por segundo (cantidad / vida), con la rampa roja-naranja-amarilla, suben y se apagan.
func _trocitos(c: Node, cantidad: int, caja: Vector3, pos: Vector3) -> void:
	_particulas(c, "Trocitos", cantidad, 0.5, 0.2, caja, Vector2(0.7, 1.4), Vector3(0, 1, 0), 15.0, Vector3(0, 0.4, 0),
		[Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.38, 0.08, 0.8), Color(0.85, 0.15, 0.04, 0.0)], "trocitos", false, 0.0, true, pos)


func _anim(raiz: Node, dura_nacer: float = 0.3, dura_morir: float = 0.5, extra: Dictionary = {}) -> void:
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "Anim"
	raiz.add_child(ap)
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:aparicion"))
		match nom:
			"nacer":
				an.length = dura_nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, dura_nacer, 1.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 1.0)
			"morir":
				an.length = dura_morir
				an.track_insert_key(pista, 0.0, 1.0)
				an.track_insert_key(pista, dura_morir, 0.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
		if extra.has(nom):
			extra[nom].call(an)
		lib.add_animation(nom, an)
	ap.add_animation_library("", lib)


func _duenos(n: Node, raiz: Node) -> void:
	for h in n.get_children():
		h.owner = raiz
		if h.scene_file_path == "":
			_duenos(h, raiz)


func _guardar(raiz: Node3D, archivo: String) -> void:
	_duenos(raiz, raiz)
	var ps: PackedScene = PackedScene.new()
	var e: int = ps.pack(raiz)
	if e != OK:
		push_error("no se pudo empaquetar " + archivo)
		return
	var r: int = ResourceSaver.save(ps, DIR + archivo)
	print("guardada %s (%d)" % [archivo, r])
	raiz.free()


# ---------------------------------------------------------------- efectos ----------------------------------------------------------------

## Bola de fuego: r 0,4 m, el origen de la escena es el CENTRO de la bola. Cuerpo gordo y redondo con una puntita que ondula, núcleo blanco-amarillo,
## capa exterior tenue más grande, halo aditivo, luz con titileo, pocas chispas. Con `proyectil` activo suelta una estela corta.
func _bola() -> Node3D:
	var r: Node3D = _raiz("BolaFuegoToy")
	r.set("tam_referencia", Vector3(0.8, 0.8, 0.8))
	r.set("escena_impacto", load(DIR + "ImpactoBolaToy.tscn") if ResourceLoader.exists(DIR + "ImpactoBolaToy.tscn") else null)
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Halo", 2.6, Vector3(0, 0.1, 0), 0.32, 3.0)
	# capa exterior: más grande, tenue, más lenta
	_llama(c, "Exterior", Vector2(1.7, 2.1), Vector3(0, -0.52, 0), {"radio": 0.4, "punta_h": 1.15, "afilado": 0.6, "radio_bola": 0.52, "blandura": 0.6, "ondulacion": 0.7,
		"transparencia": 0.35, "brillo": 0.95, "velocidad": 0.8, "semilla": 0.31, "borde_claro": 0.2, "base_clara": 0.2, "escala_ruido": 2.0, "billboard": 2}, 0)
	# cuerpo: la bola gorda
	_llama(c, "Bola", Vector2(1.3, 1.7), Vector3(0, -0.4, 0), {"radio": 0.3, "punta_h": 0.98, "afilado": 0.5, "radio_bola": 0.4, "blandura": 0.22, "ondulacion": 0.6,
		"transparencia": 0.95, "brillo": 1.0, "semilla": 0.62, "base_clara": 0.5, "escala_ruido": 2.4, "billboard": 2}, 1)
	# núcleo: más pequeño y casi blanco
	_llama(c, "Nucleo", Vector2(0.9, 1.1), Vector3(0, -0.24, 0), {"radio": 0.14, "punta_h": 0.5, "afilado": 0.9, "radio_bola": 0.22, "blandura": 0.4, "ondulacion": 0.35,
		"transparencia": 1.0, "brillo": 1.05, "semilla": 0.9, "base_clara": 1.0, "borde_claro": 0.1, "escala_ruido": 3.0, "velocidad": 1.3, "billboard": 2}, 2)
	_trocitos(c, 2, Vector3(0.1, 0.05, 0.1), Vector3(0, 0.45, 0))
	_luz(r, Vector3(0, 0, 0), 1.1, 4.5)
	_particulas(c, "Chispas", 8, 1.3, 0.07, Vector3(0.2, 0.15, 0.2), Vector2(0.3, 0.8), Vector3(0, 1, 0), 40.0, Vector3(0, 0.35, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.62, 0.22, 1.0), Color(1.0, 0.55, 0.15, 0.0)])
	var est: GPUParticles3D = _particulas(c, "Estela", 18, 0.24, 0.3, Vector3(0.06, 0.06, 0.06), Vector2(0.0, 0.1), Vector3(0, 1, 0), 180.0, Vector3.ZERO,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.4, 0.1, 0.4), Color(1.0, 0.5, 0.12, 0.0)], "estela", false, 0.0, false)
	est.emitting = false
	_anim(r)
	return r


## Impacto de la bola: estallido redondo que crece, anillo en el suelo, resplandor y un puñado de chispas. Se apaga solo (`vida`).
func _impacto() -> Node3D:
	var r: Node3D = _raiz("ImpactoBolaToy")
	r.set("vida", 0.9)
	r.set("titileo", 0.0)
	var c: Node3D = r.get_node("Cuerpo")
	var e: Node3D = Node3D.new()
	e.name = "Estallido"
	c.add_child(e)
	_halo(e, "Halo", 3.2, Vector3(0, 0.3, 0), 0.3, 3.0)
	for i in 7:
		var ang: float = TAU * float(i) / 7.0 + 0.3
		var hh: float = 0.85 + 0.35 * fmod(float(i) * 0.618, 1.0)
		_llama(e, "Petalo%d" % i, Vector2(1.1, hh * 1.25), Vector3(cos(ang) * 0.38, -0.1, sin(ang) * 0.38), {"radio": 0.3, "punta_h": hh, "afilado": 0.8, "blandura": 0.3,
			"ondulacion": 0.9, "transparencia": 0.8, "brillo": 1.0, "velocidad": 1.4, "semilla": 0.13 * float(i), "borde_claro": 0.5, "base_clara": 0.6, "escala_ruido": 2.4}, 1)
	_llama(e, "Bola", Vector2(1.9, 2.0), Vector3(0, -0.2, 0), {"radio": 0.4, "punta_h": 1.6, "afilado": 0.8, "radio_bola": 0.6, "blandura": 0.5, "ondulacion": 0.9,
		"transparencia": 0.7, "brillo": 1.0, "semilla": 0.2, "escala_ruido": 2.0, "billboard": 2}, 1)
	_llama(e, "Nucleo", Vector2(1.2, 1.2), Vector3(0, 0.0, 0), {"radio": 0.2, "punta_h": 0.8, "afilado": 0.8, "radio_bola": 0.4, "blandura": 0.7, "ondulacion": 0.5,
		"transparencia": 1.0, "brillo": 1.1, "semilla": 0.7, "base_clara": 1.0, "billboard": 2}, 2)
	var anillo: Node3D = Node3D.new()
	anillo.name = "Anillo"
	c.add_child(anillo)
	_halo(anillo, "Disco", 2.4, Vector3(0, 0.03, 0), 1.0, 1.0, 0, Color(1.0, 0.28, 0.06), {"anillo": 1.0, "latido": 0.0})
	_luz(r, Vector3(0, 0.6, 0), 1.3, 4.5)
	_particulas(c, "Chispas", 14, 0.9, 0.09, Vector3(0.1, 0.05, 0.1), Vector2(1.6, 3.2), Vector3(0, 1, 0), 70.0, Vector3(0, -3.0, 0),
		[Color(1.0, 0.75, 0.35, 1.0), Color(1.0, 0.45, 0.12, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", true, 0.95, true, Vector3(0, 0.1, 0))
	var f_est: Callable = func(an: Animation) -> void:
		var p: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(p, NodePath("Cuerpo/Estallido:scale"))
		an.track_insert_key(p, 0.0, Vector3(0.35, 0.35, 0.35))
		an.track_insert_key(p, an.length, Vector3(1.0, 1.0, 1.0))
		an.track_set_interpolation_type(p, Animation.INTERPOLATION_CUBIC)
		var q: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(q, NodePath("Cuerpo/Anillo:scale"))
		an.track_insert_key(q, 0.0, Vector3(0.3, 0.3, 0.3))
		an.track_insert_key(q, an.length, Vector3(1.4, 1.4, 1.4))
		an.track_set_interpolation_type(q, Animation.INTERPOLATION_CUBIC)
	_anim(r, 0.2, 0.55, {"nacer": f_est})
	return r


## Muro de fuego: 6,9 × 1,5 m. Dos filas de lenguas gordas (nueve atrás, más altas y tenues; ocho delante, más bajas y brillantes) que se solapan, un charco de luz
## alargado en el suelo, una luz, pocas chispas. Las lenguas cuelgan del plano del muro (su X); el billboard en Y las gira hacia la cámara.
func _muro() -> Node3D:
	var r: Node3D = _raiz("MuroFuegoToy")
	r.set("tam_referencia", Vector3(6.9, 1.5, 0.3))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Charco", 7.6, Vector3(0, 0.04, 0), 0.5, 1.6, 0, Color(1.0, 0.28, 0.06), {"latido": 0.05}, 2.4)
	_halo(c, "Resplandor", 7.2, Vector3(0, 0.55, 0), 0.22, 2.6, 2, Color(1.0, 0.28, 0.06), {}, 2.2)
	var alt_atras: Array = [1.45, 1.1, 1.6, 1.25, 1.5, 1.05, 1.55, 1.2, 1.4]
	for i in 9:
		var x: float = -3.3 + float(i) * 0.825 + (0.1 if i % 2 == 0 else -0.08)
		var h: float = alt_atras[i]
		_llama(c, "Atras%d" % i, Vector2(1.9, h * 1.25), Vector3(x, 0.0, 0.05), {"radio": 0.55, "punta_h": h, "afilado": 0.85, "radio_bola": 0.0, "blandura": 0.3,
			"ondulacion": 0.85, "transparencia": 0.5, "brillo": 0.95, "velocidad": 0.85 + 0.05 * float(i % 4), "semilla": 0.07 * float(i) + 0.03, "borde_claro": 0.45,
			"base_clara": 0.5, "escala_ruido": 2.0, "lobulos": 0.4}, 0)
	var alt_delante: Array = [0.95, 1.2, 0.85, 1.1, 1.3, 0.9, 1.15, 0.8]
	for i in 8:
		var x: float = -3.0 + float(i) * 0.86 + (0.06 if i % 2 == 0 else -0.1)
		var h: float = alt_delante[i]
		_llama(c, "Delante%d" % i, Vector2(1.5, h * 1.25), Vector3(x, 0.0, -0.05), {"radio": 0.42, "punta_h": h, "afilado": 0.8, "blandura": 0.28, "ondulacion": 0.8,
			"transparencia": 0.78, "brillo": 1.0, "velocidad": 1.0 + 0.06 * float(i % 3), "semilla": 0.5 + 0.09 * float(i), "borde_claro": 0.5, "base_clara": 0.8,
			"escala_ruido": 2.4, "lobulos": 0.35}, 1)
	_trocitos(c, 3, Vector3(3.0, 0.05, 0.15), Vector3(0, 1.0, 0))
	_luz(r, Vector3(0, 0.7, 0), 1.6, 6.5)
	_particulas(c, "Chispas", 14, 1.4, 0.07, Vector3(3.2, 0.1, 0.2), Vector2(0.3, 0.9), Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.5, 0))
	_anim(r)
	return r


## Pilar: r 0,5 × 4 m. Una columna ancha casi de la misma anchura hasta arriba, de lóbulos gordos como bolas apiladas (la trampa de Link's Awakening),
## con tres capas (exterior tenue, cuerpo, núcleo estrecho y claro), anillo de luz en el suelo y chispas que suben.
func _pilar() -> Node3D:
	var r: Node3D = _raiz("PilarFuegoToy")
	r.set("tam_referencia", Vector3(1.0, 4.0, 1.0))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Charco", 2.6, Vector3(0, 0.04, 0), 0.45, 1.8, 0, Color(1.0, 0.28, 0.06), {"anillo": 0.5})
	_halo(c, "Resplandor", 3.4, Vector3(0, 1.4, 0), 0.2, 2.8, 2, Color(1.0, 0.28, 0.06), {}, 4.2)
	_llama(c, "Exterior", Vector2(2.1, 5.0), Vector3(0, 0.0, 0), {"radio": 0.62, "punta_h": 4.3, "afilado": 0.32, "blandura": 0.35, "ondulacion": 1.0, "lobulos": 0.55,
		"transparencia": 0.45, "brillo": 0.95, "velocidad": 0.9, "semilla": 0.11, "borde_claro": 0.4, "base_clara": 0.4, "escala_ruido": 1.5, "bultos": 0.22, "bultos_freq": 5.0}, 0)
	_llama(c, "Cuerpo", Vector2(1.7, 4.8), Vector3(0, 0.0, 0), {"radio": 0.5, "punta_h": 4.0, "afilado": 0.3, "blandura": 0.28, "ondulacion": 0.9, "lobulos": 0.5,
		"transparencia": 0.8, "brillo": 1.0, "velocidad": 1.1, "semilla": 0.52, "borde_claro": 0.5, "base_clara": 0.7, "escala_ruido": 1.8, "bultos": 0.3, "bultos_freq": 6.5}, 1)
	_llama(c, "Nucleo", Vector2(1.1, 3.6), Vector3(0, 0.0, 0), {"radio": 0.28, "punta_h": 3.0, "afilado": 0.4, "blandura": 0.35, "ondulacion": 0.7, "lobulos": 0.4,
		"transparencia": 0.9, "brillo": 1.05, "velocidad": 1.35, "semilla": 0.83, "borde_claro": 0.1, "base_clara": 1.0, "escala_ruido": 2.2, "bultos": 0.25, "bultos_freq": 7.5}, 2)
	_trocitos(c, 3, Vector3(0.3, 0.1, 0.3), Vector3(0, 3.0, 0))
	_luz(r, Vector3(0, 1.3, 0), 2.0, 7.0)
	_particulas(c, "Chispas", 16, 1.8, 0.07, Vector3(0.3, 0.1, 0.3), Vector2(0.6, 1.5), Vector3(0, 1, 0), 20.0, Vector3(0, 0.5, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.3, 0))
	_anim(r, 0.4, 0.6)
	return r


## Barrera: esfera r 1,5 m centrada en el jugador (el origen es el suelo: la esfera sube 0,6). Cáscara translúcida con borde de resplandor y lenguas que
## suben girando; se ve a la jugadora dentro. Dos pasadas (cara de atrás y cara de delante) para que las mezclas salgan en orden.
func _barrera() -> Node3D:
	var r: Node3D = _raiz("BarreraFuegoToy")
	r.set("tam_referencia", Vector3(3.0, 3.0, 3.0))
	var c: Node3D = r.get_node("Cuerpo")
	_halo(c, "Anillo", 3.9, Vector3(0, 0.03, 0), 0.8, 1.0, 0, Color(1.0, 0.28, 0.06), {"anillo": 1.0, "latido": 0.04})
	var esf: MeshInstance3D = MeshInstance3D.new()
	esf.name = "Cascara"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.5
	sm.height = 3.0
	sm.radial_segments = 64
	sm.rings = 32
	esf.mesh = sm
	esf.position = Vector3(0, 0.6, 0)
	esf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_p: Dictionary = {"y_suelo": -0.6, "radio_esfera": 1.5}
	var m_atras: ShaderMaterial = ShaderMaterial.new()
	m_atras.shader = load("res://presentacion/vfx/toy/barrera_toy_trasera.gdshader")
	var m_delante: ShaderMaterial = ShaderMaterial.new()
	m_delante.shader = load(SH_BARRERA)
	for k in base_p:
		m_atras.set_shader_parameter(k, base_p[k])
		m_delante.set_shader_parameter(k, base_p[k])
	m_atras.render_priority = 0
	m_delante.render_priority = 1
	m_atras.next_pass = m_delante
	esf.material_override = m_atras
	c.add_child(esf)
	_trocitos(c, 3, Vector3(1.0, 0.1, 1.0), Vector3(0, 1.8, 0))
	_luz(r, Vector3(0, 0.7, 0), 1.5, 5.5)
	_particulas(c, "Chispas", 14, 1.6, 0.07, Vector3(1.2, 0.1, 1.2), Vector2(0.3, 0.9), Vector3(0, 1, 0), 25.0, Vector3(0, 0.5, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", false, 0.0, true, Vector3(0, 0.2, 0))
	_anim(r, 0.5, 0.6)
	return r
