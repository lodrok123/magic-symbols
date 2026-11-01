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


func _halo(padre: Node, nombre: String, lado: float, pos: Vector3, brillo: float, caida: float, billboard: int = 2, color: Color = Color(1.0, 0.55, 0.14), extra: Dictionary = {}) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(lado, lado)
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
	l.light_color = Color(1.0, 0.72, 0.38)
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
	_luz(r, Vector3(0, 0, 0), 1.1, 4.5)
	_particulas(c, "Chispas", 8, 1.3, 0.07, Vector3(0.2, 0.15, 0.2), Vector2(0.3, 0.8), Vector3(0, 1, 0), 40.0, Vector3(0, 0.35, 0),
		[Color(1.0, 0.95, 0.65, 0.0), Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.55, 0.15, 0.0)])
	var est: GPUParticles3D = _particulas(c, "Estela", 18, 0.24, 0.3, Vector3(0.06, 0.06, 0.06), Vector2(0.0, 0.1), Vector3(0, 1, 0), 180.0, Vector3.ZERO,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.18, 0.4), Color(1.0, 0.5, 0.12, 0.0)], "estela", false, 0.0, false)
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
	_halo(e, "Halo", 3.6, Vector3(0, 0.3, 0), 0.5, 3.0)
	_llama(e, "Bola", Vector2(1.9, 2.0), Vector3(0, -0.2, 0), {"radio": 0.4, "punta_h": 1.6, "afilado": 0.8, "radio_bola": 0.75, "blandura": 0.7, "ondulacion": 0.9,
		"transparencia": 0.85, "brillo": 1.0, "semilla": 0.2, "escala_ruido": 2.0, "billboard": 2}, 1)
	_llama(e, "Nucleo", Vector2(1.2, 1.2), Vector3(0, 0.0, 0), {"radio": 0.2, "punta_h": 0.8, "afilado": 0.8, "radio_bola": 0.4, "blandura": 0.7, "ondulacion": 0.5,
		"transparencia": 1.0, "brillo": 1.1, "semilla": 0.7, "base_clara": 1.0, "billboard": 2}, 2)
	var anillo: Node3D = Node3D.new()
	anillo.name = "Anillo"
	c.add_child(anillo)
	_halo(anillo, "Disco", 2.4, Vector3(0, 0.03, 0), 1.0, 1.0, 0, Color(1.0, 0.6, 0.2), {"anillo": 1.0, "latido": 0.0})
	_luz(r, Vector3(0, 0.6, 0), 1.8, 5.0)
	_particulas(c, "Chispas", 14, 0.9, 0.09, Vector3(0.1, 0.05, 0.1), Vector2(1.6, 3.2), Vector3(0, 1, 0), 70.0, Vector3(0, -3.0, 0),
		[Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.7, 0.25, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", true, 0.95, true, Vector3(0, 0.1, 0))
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


func _muro() -> Node3D:
	return Node3D.new()


func _pilar() -> Node3D:
	return Node3D.new()


func _barrera() -> Node3D:
	return Node3D.new()
