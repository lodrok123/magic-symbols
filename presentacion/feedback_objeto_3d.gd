extends Node3D
## Presentación reutilizable. Nunca cambia masa, colisiones, tiempos ni botín.
## Los materiales comunes existentes se conservan: sus controladores mantienen
## las referencias que usan para quemado, tintes y disolución.
var materiales: Array[ShaderMaterial] = []
var valores: Dictionary = {"mojado":0.0,"hielo":0.0,"calor":0.0,"energia":0.0,"agotado":0.0}
var color_energia: Color = Color(0.85,0.78,0.24)
var caja: AABB
var _arcos: MeshInstance3D
var _reloj: float = 0.0
var _fase: float = 0.0
var copiar_materiales: bool = false

static func instalar(dueno: Node3D, visual: Node3D, copiar: bool = false) -> Node3D:
	var f = load("res://presentacion/feedback_objeto_3d.gd").new()
	dueno.add_child(f)
	f.copiar_materiales = copiar
	f.montar(visual)
	return f

func montar(visual: Node3D) -> void:
	Ocluso3D.preparar()
	var mallas: Array[Node] = visual.find_children("*","MeshInstance3D",true,false)
	if visual is MeshInstance3D: mallas.append(visual)
	var primera: bool = true
	for mi in mallas:
		if mi.mesh == null: continue
		var ab: AABB = mi.mesh.get_aabb()
		var tf: Transform3D = global_transform.affine_inverse()*mi.global_transform
		if ab.size.y > 0.001:
			for esquina in 8:
				var p: Vector3 = tf*ab.get_endpoint(esquina)
				if primera:
					caja = AABB(p,Vector3.ZERO)
					primera = false
				else: caja = caja.expand(p)
		var activos: Array[Material] = []
		for s in mi.mesh.get_surface_count(): activos.append(mi.get_active_material(s))
		# Agua y materiales especializados siguen bajo su controlador. Cambiarles
		# material_override rompería las referencias de BrilloPulso/NexoRayo.
		var especializado: bool = false
		for m in activos:
			if m is ShaderMaterial and not Ocluso3D.es_comun(m): especializado = true
			if m is StandardMaterial3D and m.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]: especializado = true
		if especializado: continue
		mi.material_override = null
		for s in mi.mesh.get_surface_count():
			var m: Material = activos[s]
			if m is StandardMaterial3D: m = Ocluso3D.convertir(m.duplicate())
			elif copiar_materiales and m != null: m = m.duplicate()
			mi.set_surface_override_material(s,m)
			if Ocluso3D.es_comun(m):
				Ocluso3D.poner_caja(m,mi.mesh)
				materiales.append(m)
	set_process(false)

func estado(mojado: float = 0.0, hielo: float = 0.0, calor: float = 0.0, energia: float = 0.0, agotado: float = 0.0) -> void:
	var entradas := [mojado,hielo,calor,energia,agotado]
	var claves := ["mojado","hielo","calor","energia","agotado"]
	for i in claves.size():
		valores[claves[i]] = clampf(entradas[i],0.0,1.0)
		for m in materiales: m.set_shader_parameter("obj_"+claves[i],valores[claves[i]])
	if energia > 0.0 and _arcos == null:
		_arcos = MeshInstance3D.new()
		_arcos.name = "DescargasObjeto"
		_arcos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = color_energia
		m.emission_enabled = true
		m.emission = color_energia
		m.emission_energy_multiplier = 0.8
		_arcos.material_override = m
		add_child(_arcos)
	if _arcos != null:
		_arcos.visible = energia > 0.0
		_arcos.material_override.albedo_color = color_energia*(0.25+0.75*sqrt(valores.energia))
		_arcos.material_override.emission_energy_multiplier = 0.8*sqrt(valores.energia)
	set_process(energia>0.0)

func marcar_frutos_vacios() -> void:
	for m in materiales: m.set_shader_parameter("obj_frutos_vacios",1.0)

func _process(delta: float) -> void:
	_fase += delta
	_reloj -= delta
	if _arcos == null or valores.energia <= 0.0 or _reloj>0.0: return
	_reloj = lerpf(0.32,0.12,valores.energia)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro: Vector3 = caja.get_center()
	var tam: float = maxf(caja.size.length()*0.35,0.12)
	for arco in (3 if valores.energia>0.25 else 1):
		var angulo: float = _fase*3.1+arco*TAU/3.0
		var a: Vector3 = centro+Vector3(cos(angulo)*tam,caja.size.y*0.25,sin(angulo)*tam)
		for i in 5:
			var b: Vector3 = a+Vector3(sin(i*5.0+_fase*17.0)*tam*0.18,-tam*0.16,cos(i*4.0+arco)*tam*0.15)
			var lateral: Vector3 = (b-a).cross(Vector3.FORWARD).normalized()*maxf(0.004,tam*0.012)
			for v in [a-lateral,a+lateral,b+lateral,a-lateral,b+lateral,b-lateral]: mesh.surface_add_vertex(v)
			a = b
	mesh.surface_end()
	_arcos.mesh = mesh

static func sacudir(visual: Node3D, fuerza: float = 0.10) -> void:
	var anterior: Variant = visual.get_meta("feedback_sacudida") if visual.has_meta("feedback_sacudida") else null
	if anterior is Tween and anterior.is_valid(): anterior.kill()
	if not visual.has_meta("feedback_rotacion"): visual.set_meta("feedback_rotacion",visual.rotation)
	var base: Vector3 = visual.get_meta("feedback_rotacion")
	var tw := visual.create_tween()
	visual.set_meta("feedback_sacudida",tw)
	tw.tween_property(visual,"rotation",base+Vector3(0,0,fuerza),0.07)
	tw.tween_property(visual,"rotation",base-Vector3(0,0,fuerza*0.65),0.10)
	tw.tween_property(visual,"rotation",base,0.16)

static func brotar(visual: Node3D) -> void:
	var escala: Vector3 = visual.scale
	visual.scale = escala*Vector3(0.35,0.08,0.35)
	visual.create_tween().tween_property(visual,"scale",escala,0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func asentar(visual: Node3D) -> void:
	# Solo el hijo visual: la raíz física ya está en su posición de reposo.
	var base: Vector3 = visual.position
	var tw := visual.create_tween()
	tw.tween_property(visual,"position",base+Vector3.UP*0.06,0.08)
	tw.tween_property(visual,"position",base,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

static func quitar_colisiones(n: Node) -> void:
	if n is CollisionObject3D:
		n.collision_layer = 0
		n.collision_mask = 0
	for h in n.get_children(): quitar_colisiones(h)

static func rafaga(padre: Node3D, punto: Vector3, tipo: String, color: Color = Color(0.65,0.61,0.52), cantidad: int = 8, escala: float = 1.0) -> Node3D:
	if padre == null: return null
	var f := Rafaga.new()
	f.name = "Feedback_"+tipo
	f.tipo = tipo
	f.color = color
	f.cantidad = clampi(cantidad,1,16)
	f.escala = escala
	padre.add_child(f)
	f.top_level = true
	f.global_position = punto
	f.montar()
	return f

class Rafaga extends Node3D:
	var tipo: String
	var color: Color
	var cantidad: int
	var escala: float
	var edad: float = 0.0
	var piezas: Array[Node3D] = []
	var mats: Array[StandardMaterial3D] = []
	func _pluma() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in 8:
			var t0: float = float(j)/8.0
			var t1: float = float(j+1)/8.0
			for lado in [-1.0,1.0]:
				var centro0 := Vector3(sin(t0*PI)*0.012,t0*0.14,0)
				var centro1 := Vector3(sin(t1*PI)*0.012,t1*0.14,0)
				var borde0: Vector3 = centro0+Vector3(lado*sin(t0*PI)*0.032,-0.005,0.001)
				var borde1: Vector3 = centro1+Vector3(lado*sin(t1*PI)*0.032,-0.005,0.001)
				for v in [centro0,borde0,borde1,centro0,borde1,centro1]:
					st.set_normal(Vector3.FORWARD)
					st.set_color(Color(0.7,0.68,0.56) if v==centro0 or v==centro1 else Color.WHITE)
					st.add_vertex(v*escala)
		return st.commit()
	func montar() -> void:
		for i in cantidad:
			var mi := MeshInstance3D.new()
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.7
			if tipo == "onda":
				var aro := TorusMesh.new()
				aro.inner_radius = 0.14
				aro.outer_radius = 0.15
				aro.rings = 24
				aro.ring_segments = 6
				mi.mesh = aro
			elif tipo == "pluma":
				mi.mesh = _pluma()
				m.vertex_color_use_as_albedo = true
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			elif tipo in ["gota","burbuja","polvo"]:
				var b := SphereMesh.new()
				b.radius = 0.018*escala
				b.height = b.radius*2.0
				b.radial_segments = 8
				b.rings = 4
				mi.mesh = b
				if tipo == "polvo": m.albedo_color.a = 0.4
			else:
				var b := BoxMesh.new()
				b.size = (Vector3(0.035,0.12,0.005) if tipo in ["pluma","hoja"] else Vector3.ONE*0.025)*escala
				if tipo == "gota": b.size *= Vector3(0.6,1.7,0.6)
				mi.mesh = b
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			piezas.append(mi)
			mats.append(m)
	func _process(delta: float) -> void:
		edad += delta
		for i in piezas.size():
			var angulo: float = i*2.399963
			if tipo == "onda":
				piezas[i].scale = Vector3.ONE*(0.7+edad*2.0+float(i)*0.4)*escala
			else:
				var altura: float = (0.55*edad-0.65*edad*edad) if tipo != "gota" else -0.5*edad*edad
				piezas[i].position = Vector3(cos(angulo)*edad*0.25,altura+float(i%3)*0.035,sin(angulo)*edad*0.25)*escala
				piezas[i].rotation = Vector3(edad+i,angulo+edad*1.5,edad*0.5)
			mats[i].albedo_color.a = maxf(0.0,1.0-edad/1.1)*(0.4 if tipo=="polvo" else 1.0)
		if edad >= 1.1: queue_free()
